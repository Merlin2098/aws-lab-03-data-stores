# Consultar S3 con Athena

Cubre cómo ejecutar las queries de la sección 11 del laboratorio
([laboratorio_sesion_03_storage.md](../01-contexto/laboratorio_sesion_03_storage.md))
sobre el dataset Parquet subido a S3 (ver
[carga_s3.md](carga_s3.md)), usando Amazon Athena.

A diferencia de RDS/DynamoDB, no hay cliente que instalar ni CLI local
necesaria — Athena se consulta desde la consola de AWS (o vía
`aws athena` si prefieres CLI, ver sección 5).

---

## 1. Paso obligatorio antes de la primera consulta: registrar las particiones

El dataset se subió particionado por `year=/month=/day=` (ver
[carga_s3.md](carga_s3.md)), y la tabla del Glue Data Catalog
(`aws_glue_catalog_table.tracking_events` en
[infra/modules/athena/main.tf](../../infra/modules/athena/main.tf))
declara esas particiones como parte de su schema. Pero **Athena no
detecta las particiones automáticamente** solo porque los archivos ya
estén en S3 — hay que decirle explícitamente qué carpetas existen.

Sin este paso, cualquier query sobre `tracking_events` devuelve **0
filas silenciosamente** (no un error) — es la causa más común de "subí
los datos pero Athena no ve nada".

### Ejecutar el repair

En la consola de AWS, ve a **Athena** → selecciona el workgroup
`<athena_workgroup_name>` y la base `<athena_database_name>` (ver
[guia_ejecucion_lab_storage.md](../guia_ejecucion_lab_storage.md),
sección 7, para dónde obtener esos nombres) → en el editor de queries:

```sql
MSCK REPAIR TABLE tracking_events;
```

Este comando escanea el prefijo S3 de la tabla y registra en el catálogo
cada carpeta `year=.../month=.../day=...` que encuentre como una
partición nueva. Tarda unos segundos; el resultado indica cuántas
particiones se agregaron.

**Vuelve a correr `MSCK REPAIR TABLE tracking_events;` cada vez que
subas una nueva versión de datos** (`upload_s3.py`) que agregue días
nuevos — si no, las queries seguirán sin ver los archivos más
recientes aunque ya estén en S3.

---

## 2. Preparar el acceso

Inicia sesión en la [consola de AWS](https://console.aws.amazon.com/)
con el mismo usuario/cuenta cuyas credenciales están en
`.env.credentials`, y ve a **Athena** → **Query editor**.

Verifica en la esquina superior derecha que la región coincida con
`AWS_DEFAULT_REGION` (`us-east-1` por defecto en este laboratorio).

**Selecciona el workgroup correcto** en el desplegable superior:
`<athena_workgroup_name>` (obtenido con `terraform output
athena_workgroup_name`). Si usas el workgroup `primary` por defecto de
Athena en vez del creado por este laboratorio, no se aplican las reglas
de `enforce_workgroup_configuration` declaradas en
[infra/modules/athena/main.tf](../../infra/modules/athena/main.tf), y
los resultados de las queries no se guardarán en el bucket esperado
(`s3://<bucket>/athena-results/`).

**Selecciona la base de datos** `<athena_database_name>` (`terraform
output athena_database_name`) en el panel izquierdo, donde debería
aparecer la tabla `tracking_events`.

---

## 3. Ejercicios — Sección 11 del laboratorio

### Consulta 1 — Total de eventos

```sql
SELECT COUNT(*)
FROM tracking_events;
```

**Pregunta del laboratorio:** ¿qué cantidad de datos necesita procesar
Athena para responder esta consulta?

Pista: sin filtro de partición, Athena escanea **todos** los archivos
Parquet bajo el prefijo de la tabla — el costo de Athena se calcula por
bytes escaneados, así que esta consulta procesa el dataset completo. Tras
correrla, revisa el panel de resultados: Athena muestra cuántos datos
escaneó cada query ejecutada.

### Consulta 2 — Eventos por estado

```sql
SELECT
    status,
    COUNT(*) AS total
FROM tracking_events
GROUP BY status;
```

Deberías ver un conteo por cada valor de `status`
(`RECEIVED`/`IN_TRANSIT`/`OUT_FOR_DELIVERY`/`DELIVERED`, ver
`scripts/generate_data.py`).

### Consulta 3 — Eventos por ciudad

```sql
SELECT
    city,
    COUNT(*) AS total
FROM tracking_events
GROUP BY city
ORDER BY total DESC;
```

### Consulta 4 — Uso de particiones

Consultar únicamente un día concreto (ajusta la fecha a un día que
realmente exista en tus datos — revisa con la Consulta 3 o
`aws s3 ls s3://<bucket>/raw/events/ --recursive` qué particiones tienes
disponibles):

```sql
SELECT COUNT(*)
FROM tracking_events
WHERE year = '2026'
  AND month = '09'
  AND day = '21';
```

**Pregunta del laboratorio:** ¿por qué esta consulta puede ser más
eficiente que consultar todo el dataset?

Pista: al filtrar por las columnas de partición (`year`/`month`/`day`),
Athena hace *partition pruning* — solo lee los archivos de las carpetas
que coinciden con el filtro, en vez de escanear todo el bucket. Compara
los bytes escaneados de esta consulta contra los de la Consulta 1 en el
panel de resultados; la diferencia es la evidencia concreta del ahorro.

---

## 4. Ejemplos adicionales — CTE y HAVING

Estas dos no forman parte de la sección 11 del laboratorio — son
ejemplos extra sobre el mismo dataset para practicar patrones SQL más
avanzados que las 4 consultas base no cubren.

### Ejemplo A — CTE: último estado conocido por paquete

Cada paquete genera varios eventos de tracking (uno por cada cambio de
`status`). Para saber en qué estado está *ahora mismo* cada paquete,
necesitas el evento más reciente por `package_id` — un CTE (`WITH`)
ayuda a separar el cálculo intermedio (el timestamp máximo por paquete)
de la consulta final que lo usa:

```sql
WITH ultimo_evento AS (
    SELECT
        package_id,
        MAX(timestamp) AS ultimo_timestamp
    FROM tracking_events
    GROUP BY package_id
)
SELECT
    t.package_id,
    t.status AS estado_actual,
    t.city,
    t.timestamp
FROM tracking_events t
JOIN ultimo_evento u
    ON t.package_id = u.package_id
    AND t.timestamp = u.ultimo_timestamp
ORDER BY t.package_id;
```

El CTE `ultimo_evento` calcula, para cada paquete, cuál es su timestamp
más reciente. La consulta principal hace `JOIN` contra la tabla original
para recuperar la fila completa (incluyendo `status` y `city`) que
corresponde a ese timestamp — sin el CTE tendrías que anidar la misma
subconsulta dentro de un `WHERE`, menos legible.

**Pregunta de práctica:** ¿por qué no basta con
`SELECT package_id, MAX(status) ...` para obtener el estado actual?

Pista: `MAX()` sobre `status` ordenaría alfabéticamente los valores del
texto (`DELIVERED` > `IN_TRANSIT` alfabéticamente), no cronológicamente
— daría el estado "mayor" en orden de string, no el más reciente en el
tiempo. Por eso se necesita `MAX(timestamp)` y luego recuperar el
`status` correspondiente a ese momento.

### Ejemplo B — HAVING: ciudades con alto volumen de eventos

`HAVING` filtra sobre el resultado de una agregación (`GROUP BY`),
después de calcularla — a diferencia de `WHERE`, que filtra las filas
*antes* de agrupar. Útil para preguntas tipo "solo quiero los grupos que
superan cierto umbral":

```sql
SELECT
    city,
    COUNT(*) AS total_eventos
FROM tracking_events
GROUP BY city
HAVING COUNT(*) > 20
ORDER BY total_eventos DESC;
```

Con los volúmenes por defecto del laboratorio (150 paquetes × 4 eventos
= 600 eventos repartidos entre 6 ciudades), la mayoría de ciudades
debería superar el umbral de 20 — ajústalo según cuántos paquetes
generaste (`--packages` en `scripts/generate_data.py`) si quieres ver el
filtro excluir alguna ciudad.

**Pregunta de práctica:** ¿por qué esta condición no puede escribirse
como `WHERE COUNT(*) > 20`?

Pista: en el orden de ejecución lógico de SQL, `WHERE` se evalúa antes
de que exista el resultado agregado (`COUNT(*)` todavía no tiene un
valor por grupo en ese punto) — por eso cualquier filtro sobre una
función de agregación debe ir en `HAVING`, que se ejecuta después del
`GROUP BY`.

---

## 5. Verificación rápida (post-repair)

Si después de `MSCK REPAIR TABLE` quieres confirmar qué particiones
quedaron registradas:

```sql
SHOW PARTITIONS tracking_events;
```

Deberías ver una fila por cada combinación `year=.../month=.../day=...`
presente en tus datos — coincide con la cantidad de archivos `.parquet`
que viste al verificar la carga en [carga_s3.md](carga_s3.md).

---

## 6. Alternativa — AWS CLI

Si prefieres no usar la consola, puedes correr las mismas queries con
`aws athena`, aunque es más verboso (Athena CLI es asíncrono: se inicia
la query, se consulta su estado, y luego se leen los resultados):

```bash
QUERY_ID=$(aws athena start-query-execution \
  --query-string "SELECT COUNT(*) FROM tracking_events" \
  --work-group "<athena_workgroup_name>" \
  --query-execution-context Database="<athena_database_name>" \
  --output text --query 'QueryExecutionId')

aws athena get-query-execution --query-execution-id "$QUERY_ID" \
  --query 'QueryExecution.Status.State' --output text

aws athena get-query-results --query-execution-id "$QUERY_ID"
```

Para el laboratorio, la consola es más directa — usa la CLI solo si
necesitas automatizar las consultas en un script.

---

## 7. Problemas comunes

- **Todas las queries devuelven 0 filas** — no corriste
  `MSCK REPAIR TABLE tracking_events;` después de subir los datos. Ver
  sección 1.
- **`HIVE_METASTORE_ERROR` o la tabla no aparece en el panel** — no
  desplegaste el módulo `athena` de Terraform, o seleccionaste la base
  de datos equivocada. Verifica con `terraform output
  athena_database_name`.
- **Los resultados no coinciden con lo que cargaste** — subiste una
  nueva versión de datos con `upload_s3.py --version ...` después del
  último `MSCK REPAIR TABLE`; vuelve a correr el repair para que Athena
  vea las particiones nuevas.
- **La query tarda mucho o falla por timeout en un dataset pequeño** —
  poco común con los volúmenes de este laboratorio (cientos de eventos),
  pero si ocurre, revisa que el workgroup seleccionado sea el correcto
  (`enforce_workgroup_configuration` puede estar limitando algo si se
  configuró un límite de datos escaneados).
