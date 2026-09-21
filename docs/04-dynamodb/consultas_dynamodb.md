# Consultar DynamoDB

Cubre cómo consultar la tabla `package_tracking` una vez que los datos ya
están cargados (ver
[guia_ejecucion_lab_storage.md](../guia_ejecucion_lab_storage.md), paso 6.3)
y los ejercicios de la sección 13
([laboratorio_sesion_03_storage.md](../01-contexto/laboratorio_sesion_03_storage.md)).

A diferencia de RDS, DynamoDB no usa un cliente SQL — se consulta con la
AWS CLI (`aws dynamodb ...`), con boto3 desde Python, o directamente
desde la consola web de AWS. No necesitas instalar nada adicional: la
AWS CLI ya la usan los scripts del laboratorio, y la consola no requiere
ninguna herramienta.

Cada ejercicio de este documento trae ambas formas — CLI y consola — son
equivalentes, usa la que te resulte más cómoda.

---

## 1. Diseño de la tabla

```
Tabla: package_tracking

Partition key (hash_key): package_id   (String)
Sort key (range_key):     timestamp    (String)
```

Ejemplo de filas para un mismo paquete:

```
PKG-000001 | 2026-09-21T10:00:00
PKG-000001 | 2026-09-21T11:30:00
PKG-000001 | 2026-09-21T14:20:00
```

Este diseño responde eficientemente a un único access pattern: "dame
todo el historial de un paquete concreto" — porque `package_id` es la
partition key. Cualquier otro patrón de consulta (ej. "todos los
paquetes de una ciudad") no está soportado por esta clave — ver sección
4 más abajo.

---

## 2. Preparar el acceso

### Opción A — AWS CLI

Carga tus credenciales AWS en la sesión:

```bash
set -a
source .env.credentials
set +a
```

La AWS CLI (`aws dynamodb ...`) lee `AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY` y `AWS_DEFAULT_REGION` directamente del entorno.

### Opción B — Consola de AWS

Inicia sesión en la [consola de AWS](https://console.aws.amazon.com/)
con el mismo usuario/cuenta cuyas credenciales están en
`.env.credentials`, y ve a **DynamoDB** → **Tables** → selecciona
`package_tracking`. Verifica en la esquina superior derecha que la
región coincida con `AWS_DEFAULT_REGION` (`us-east-1` por defecto en
este laboratorio) — si consultas desde la región equivocada, la consola
mostrará la tabla como inexistente.

Dentro de la tabla, la pestaña **Explore table items** trae dos formas
de consultar:

- **Scan/Query (formulario)** — un editor visual con desplegables para
  elegir `Scan` o `Query`, y campos para las claves. Es el más directo
  para los ejercicios de abajo.
- **PartiQL editor** — un editor de texto tipo SQL sobre DynamoDB.
  Útil si prefieres escribir la condición en vez de usar el formulario.

---

## 3. Ejercicios — Sección 13 del laboratorio

### Consulta 1 — Obtener un paquete (Query)

Un `Query` filtra por partition key — es la forma eficiente de
consultar DynamoDB, porque solo lee las particiones que coinciden en vez
de escanear toda la tabla.

```bash
aws dynamodb query \
  --table-name package_tracking \
  --key-condition-expression "package_id = :pid" \
  --expression-attribute-values '{":pid": {"S": "PKG-000001"}}'
```

Esto devuelve todo el historial de eventos de `PKG-000001`, ordenado por
`timestamp` (la sort key).

Si generaste tus datos con `generate_data.py` sin `--seed` fijo, los IDs
de paquete van de `PKG-000001` a `PKG-0000<packages>` (150 por defecto) —
ajusta el ID según lo que hayas cargado.

**Desde la consola:**

En **Explore table items**, selecciona **Query**, elige `package_id` como
partition key e ingresa `PKG-000001` como valor, luego **Run**.

O con PartiQL:

```sql
SELECT * FROM "package_tracking" WHERE "package_id" = 'PKG-000001'
```

**Importante:** PartiQL no tiene comandos separados para `Query` y
`Scan` como sí existen en la API/CLI nativa — solo escribes `SELECT`, y
DynamoDB decide internamente cuál de los dos ejecuta, según el `WHERE`.
Si la condición es una igualdad (`=`) sobre la partition key completa
(como arriba), DynamoDB lo traduce a un `Query` real, eficiente. Si el
`WHERE` filtra por cualquier otro atributo (ej. `city`, que no es
clave), DynamoDB ejecuta un `Scan` completo por debajo, aunque la
sintaxis parezca una consulta SQL normal — el costo es el mismo que un
`Scan` explícito, solo que menos obvio a simple vista. Ejemplo de lo
segundo (ver Consulta 3 más abajo, por qué falla o es ineficiente):

```sql
SELECT * FROM "package_tracking" WHERE "city" = 'Lima'
```

### Consulta 2 — Inspección mediante Scan

Un `Scan` recorre **toda la tabla**, ítem por ítem, sin usar ninguna
clave — es la forma menos eficiente de consultar DynamoDB, y su costo
crece linealmente con el tamaño de la tabla.

```bash
aws dynamodb scan \
  --table-name package_tracking \
  --max-items 10
```

**Desde la consola:**

En **Explore table items**, selecciona **Scan** (en vez de Query, sin
especificar ninguna clave) y **Run**. La consola pagina los resultados
automáticamente si hay más ítems de los que caben en una página.

O con PartiQL:

```sql
SELECT * FROM "package_tracking"
```

**Pregunta de discusión:** ¿por qué un `Scan` no debería ser la
estrategia habitual para consultar una tabla grande?

Pista: `Scan` consume capacidad de lectura proporcional a *todos* los
ítems de la tabla, no solo a los que te interesan — a diferencia de
`Query`, que solo lee la(s) partición(es) que pediste. En una tabla con
millones de ítems, un `Scan` es lento y caro; se usa solo para
inspección puntual o tablas pequeñas, no como patrón de acceso de una
aplicación.

### Consulta 3 — Access Pattern nuevo (sin implementar)

Requerimiento planteado por el laboratorio:

> "El área de operaciones necesita consultar rápidamente todos los
> paquetes asociados a una determinada ciudad."

Antes de tocar Terraform, responde (no implementes todavía):

1. ¿La tabla actual (`package_id` + `timestamp`) permite esta consulta
   de forma eficiente?
2. ¿Qué clave usarías para este nuevo patrón?
3. ¿Necesitas un Global Secondary Index (GSI)?
4. ¿Cómo cambiaría el modelo de datos?

Este ejercicio es intencionalmente de diseño, no de código — la
implementación real (agregar el GSI en Terraform) es el **Reto 3** de la
sección 16 del laboratorio (ver
[guia_ejecucion_lab_storage.md](../guia_ejecucion_lab_storage.md), paso 8).
El módulo actual (`infra/modules/dynamodb/main.tf`) lo deja explícito:
no se crea ningún GSI en el despliegue inicial a propósito, para que sea
el alumno quien lo diseñe y agregue.

**Verifica en la consola** que no hay ningún GSI todavía: en la tabla
`package_tracking`, pestaña **Indexes** — debería estar vacía. Intentar
un `Query` filtrando por `city` (sin GSI) fallará con
`ValidationException`, tanto en CLI como en el formulario de la consola
— es la evidencia práctica de por qué se necesita un índice nuevo para
este access pattern.

**Antes de crear el GSI (a mano o por Terraform):** lee
[consola_vs_terraform.md](consola_vs_terraform.md) — agregar un GSI
directamente desde la consola, sin pasar por Terraform, genera un
desfase (*drift*) entre AWS y el `terraform.tfstate` que puede terminar
borrando el índice que acabas de crear en el siguiente `apply`.

---

## 4. Comandos adicionales útiles

```bash
# Ver la definición completa de la tabla (claves, throughput, GSIs si los hay)
aws dynamodb describe-table --table-name package_tracking

# Contar ítems totales (aproximado — DynamoDB no da un COUNT exacto barato,
# usa Select COUNT sobre un Scan)
aws dynamodb scan --table-name package_tracking --select COUNT

# Obtener un ítem exacto por sus dos claves
aws dynamodb get-item \
  --table-name package_tracking \
  --key '{"package_id": {"S": "PKG-000001"}, "timestamp": {"S": "2026-09-21T10:00:00"}}'
```

`--select COUNT` en un `Scan` sigue leyendo toda la tabla para contar —
sirve para verificar que la carga funcionó, pero no es gratis; no lo
uses como reemplazo de `describe-table` para ver metadata.

---

## 5. Problemas comunes

- **`ResourceNotFoundException: Requested resource not found`** — el
  nombre de tabla no coincide, o no desplegaste el módulo `dynamodb` de
  Terraform. Verifica con `terraform output dynamodb_table_name`.
- **`query` no devuelve nada pero `scan` sí muestra datos** — revisa que
  el `package_id` en `--expression-attribute-values` (CLI) o en el
  formulario/PartiQL (consola) exista exactamente como está en la tabla
  (sensible a mayúsculas, sin espacios extra).
- **La tabla no aparece en la consola** — revisa la región seleccionada
  en la esquina superior derecha; debe coincidir con
  `AWS_DEFAULT_REGION` (`us-east-1` en este laboratorio). DynamoDB es un
  servicio regional, la consola solo muestra tablas de la región activa.
- **PartiQL devuelve un error de tipo** — en PartiQL para DynamoDB los
  valores string van entre comillas simples (`'PKG-000001'`), no dobles;
  a diferencia de SQL estándar, DynamoDB no hace conversión implícita de
  tipos entre `S` (string) y `N` (number).
