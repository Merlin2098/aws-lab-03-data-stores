# Guía de ejecución — Laboratorio Sesión 03 (S3, RDS, DynamoDB, Athena)

Esta guía es el paso a paso práctico para desplegar y ejecutar el
laboratorio descrito en
[laboratorio_sesion_03_storage.md](01-contexto/laboratorio_sesion_03_storage.md).
Sigue el orden de las secciones; cada una depende de la anterior.

Si vas a usar RDS, revisa primero
[requisitos_rds.md](03-rds/requisitos_rds.md) — tiene los prerequisitos
específicos (IP pública, contraseña) que necesitas antes del paso 2.

---

## 0. Prerrequisitos

- Cuenta AWS con credenciales propias (Access Key ID + Secret Access Key)
  y permisos para crear recursos S3, RDS, DynamoDB, Glue y Athena.
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6.0
- Python gestionado con [`uv`](https://docs.astral.sh/uv/) (el proyecto no
  usa pip/venv manual).
- Un cliente SQL para conectarte a RDS — ver
  [clientes_sql.md](03-rds/clientes_sql.md) si no tienes uno instalado.
- Git Bash como terminal (según AGENTS.md, es el terminal por defecto del
  proyecto).

---

## 1. Preparar el entorno Python

Desde la raíz del repo:

```bash
uv sync
```

Esto crea/actualiza `.venv` con todas las dependencias declaradas en
`pyproject.toml` (incluye `faker`, `boto3`, `psycopg2-binary`, `pyarrow`,
necesarios para este laboratorio).

---

## 2. Configurar credenciales AWS

Tienes dos formas de dar tus credenciales a Terraform y a los scripts
Python. Elige una — no necesitas las dos.

### Opción A — Archivo `.env.credentials` (recomendada, persiste entre sesiones)

Copia la plantilla y complétala con tus propias credenciales:

```bash
cp .env.example .env.credentials
```

Edita `.env.credentials` y completa:

```
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_DEFAULT_REGION=us-east-1
```

Las variables `RDS_*` las completas más adelante, en el paso 5, una vez
que RDS esté desplegado.

`.env.credentials` está en `.gitignore` y los scripts lo cargan
automáticamente (`scripts/lab_storage_common.py`). No necesitas repetir
este paso cada vez que abres una terminal nueva.

### Opción B — Cargar `.env.credentials` en el entorno de la sesión

Igual que la Opción A, primero copia y completa `.env.credentials`
(`cp .env.example .env.credentials`, luego edítalo). La diferencia es
que en vez de dejar que cada script lo lea por su cuenta, cargas tú
mismo todas sus variables al entorno de la terminal — útil para que
Terraform (que no lee `.env.credentials`, solo variables de entorno) vea
las mismas credenciales sin duplicarlas en `terraform.tfvars`.

Esto se pierde al cerrar la terminal — repite el paso en cada sesión
nueva.

**Git Bash:**

```bash
set -a
source .env.credentials
set +a
```

`set -a` marca como exportable toda variable que se defina a partir de
ahí; `source` carga el archivo línea por línea (equivalente a ejecutarlo
en la sesión actual); `set +a` vuelve al comportamiento normal para no
seguir auto-exportando todo lo que declares después.

**PowerShell:**

```powershell
Get-Content .env.credentials | ForEach-Object {
    if ($_ -match '^\s*([^#=][^=]*)=(.*)$') {
        Set-Item -Path "env:$($matches[1].Trim())" -Value $matches[2].Trim()
    }
}
```

No existe un `source` equivalente en PowerShell para archivos `.env`, así
que el one-liner anterior lee el archivo línea por línea y define cada
variable con `$env:`, ignorando líneas vacías o que empiecen con `#`.

Verifica que cargó correctamente:

```powershell
echo $env:AWS_ACCESS_KEY_ID
```

Con cualquiera de las dos, tanto Terraform como los scripts Python
(`scripts/lab_storage_common.py`, que primero intenta leer
`.env.credentials` del disco y si no existe cae a las variables ya
presentes en el entorno) quedan funcionando con las mismas credenciales.

`.env.credentials` está en `.gitignore` — nunca se commitea. No compartas
este archivo ni lo subas a ningún lado.

---

## 3. Desplegar la infraestructura con Terraform

Toda la infraestructura vive en `infra/`, organizada en módulos por
servicio (`infra/modules/{s3-artifacts,s3-datalake,rds,dynamodb,athena,iam}`).

### 3.1. Configurar variables

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
```

Edita `terraform.tfvars` y completa como mínimo:

- `student_ip_cidr` — tu IP pública en formato CIDR (`x.x.x.x/32`).
  Obtenla con:

  ```bash
  curl -s https://checkip.amazonaws.com
  ```

  Ver [requisitos_rds.md](03-rds/requisitos_rds.md) para más detalle sobre por
  qué se necesita y qué hacer si tu IP cambia.

No pongas `rds_db_password` en este archivo. Expórtalo como variable de
entorno para no dejarlo en un archivo, ni siquiera uno gitignored:

```bash
export TF_VAR_rds_db_password="una-contraseña-fuerte"
```

### 3.2. Inicializar, validar y desplegar

```bash
terraform init
terraform fmt
terraform validate
terraform plan
```

Revisa el plan con cuidado: deberías ver la creación de ~20-25 recursos
(dos buckets S3, una instancia RDS, una tabla DynamoDB, recursos de Glue/
Athena, IAM, CloudWatch log groups). Si algo no coincide con lo esperado,
pregunta antes de continuar.

```bash
terraform apply
```

Confirma con `yes` cuando el plan se vea correcto.

**RDS tarda en aprovisionarse.** `aws_db_instance.lab` puede quedarse en
"Still creating..." por 5-10 minutos — es el tiempo normal de AWS para
levantar una instancia RDS, no un error. Espera a que termine.

**Error `ResourceAlreadyExistsException` en el log group de RDS.** Si
`apply` falla así:

```
Error: creating CloudWatch Logs Log Group (/aws/rds/instance/<id>/postgresql):
... ResourceAlreadyExistsException: The specified log group already exists
```

Es una condición de carrera conocida entre RDS y Terraform: la instancia
tiene `enabled_cloudwatch_logs_exports = ["postgresql"]`
([infra/modules/rds/main.tf](../infra/modules/rds/main.tf)), lo que hace
que **RDS cree su propio log group automáticamente** en cuanto empieza a
exportar logs — apenas termina de aprovisionarse, en paralelo a
Terraform. Cuando Terraform intenta crear su propio
`aws_cloudwatch_log_group` para ese mismo nombre, AWS rechaza la creación
porque ya existe.

No es un bug del código: el log group *debe* declararse explícitamente
(ver AGENTS.md, guardrails de AWS/Terraform) para fijar `retention_in_days`
y tags — el que crea RDS por su cuenta no trae ninguno de los dos.
Solución: importar el recurso ya creado al estado de Terraform, en vez de
dejar que Terraform intente crearlo:

```bash
terraform import module.rds.aws_cloudwatch_log_group.rds_postgresql \
  "/aws/rds/instance/<name_prefix>-lab-db/postgresql"
```

Sustituye `<name_prefix>` por `${project_name}-${environment}` (ver
`locals.name_prefix` en `infra/main.tf`; con los valores por defecto del
`.example` sería `data-platform-dev-lab-db`).

**Si usas Git Bash y el import falla con un `InvalidParameterException`
mencionando una ruta de Windows** (algo como
`C:/Program Files/Git/aws/rds/instance/...`), es MSYS/Git Bash
reinterpretando el `/aws/...` inicial como una ruta de filesystem antes
de pasarlo a Terraform — un problema conocido de Git Bash en Windows con
cualquier argumento que empiece con `/`, no específico de Terraform.
Evítalo desactivando esa conversión solo para este comando:

```bash
MSYS_NO_PATHCONV=1 terraform import module.rds.aws_cloudwatch_log_group.rds_postgresql \
  "/aws/rds/instance/<name_prefix>-lab-db/postgresql"
```

Después de un import exitoso, corre `terraform plan` — debería mostrar
solo un *update in-place* de `retention_in_days`/tags sobre el log group
ya existente, nunca una creación. Aplica ese plan y continúa; este
problema solo ocurre la primera vez que la instancia arranca con
exports de CloudWatch activos.

### 3.3. Guardar los outputs

```bash
terraform output -json > ../lab_storage_outputs.json
terraform output
```

Vas a necesitar varios de estos valores en el siguiente paso.

---

## 4. Completar la configuración de los scripts

Vuelve a la raíz del repo y edita `src/config/lab_storage_config.yaml`.
Reemplaza cada placeholder `REPLACE-WITH-terraform-output-...` con el
valor correspondiente que arrojó `terraform output` en el paso anterior:

| Campo en el YAML          | Output de Terraform       |
| ------------------------- | ------------------------- |
| `datalake_bucket_name`  | `datalake_bucket_name`  |
| `rds_endpoint`          | `rds_endpoint`          |
| `rds_db_name`           | `rds_db_name`           |
| `dynamodb_table_name`   | `dynamodb_table_name`   |
| `athena_database_name`  | `athena_database_name`  |
| `athena_table_name`     | `athena_table_name`     |
| `athena_workgroup_name` | `athena_workgroup_name` |

Luego completa en `.env.credentials` las variables de conexión a RDS:

```
RDS_ENDPOINT=<valor de rds_endpoint, ej. mi-db.xxxxx.us-east-1.rds.amazonaws.com:5432>
RDS_DB_NAME=<valor de rds_db_name>
RDS_USERNAME=lab_admin
RDS_PASSWORD=<la misma contraseña que usaste en TF_VAR_rds_db_password>
```

---

## 5. Generar los datos sintéticos

```bash
uv run python scripts/generate_data.py
```

Por defecto genera ~100 clientes, ~500 órdenes y eventos de tracking para
150 paquetes. Puedes ajustar cantidades:

```bash
uv run python scripts/generate_data.py --customers 100 --orders 500 --packages 150 --seed 42
```

`--seed` es opcional — úsalo si quieres datos reproducibles entre
corridas.

Cada corrida queda marcada con el mismo timestamp (`YYYYMMDD-HHMMSS`) y
crea una nueva versión en `data/` (gitignored), organizada por servicio
de destino:

- `data/rds/customers_<timestamp>.csv`
- `data/rds/orders_<timestamp>.csv`
- `data/dynamodb/tracking_events_<timestamp>.json`
- `data/s3/tracking_events_<timestamp>.parquet/` (particionado por
  `year=/month=/day=`)

Puedes correr `generate_data.py` varias veces para simular cargas
incrementales — cada corrida queda con su propio timestamp sin
sobrescribir las anteriores.

---

## 6. Cargar los datos

Cada script es independiente; ejecútalos en cualquier orden. Por defecto,
cada uno carga la versión (timestamp) más reciente generada en su
subcarpeta de `data/`. Pasa `--version <timestamp>` para cargar una
corrida específica en vez de la última — útil para demostrar cargas
incrementales corriendo `generate_data.py` varias veces y cargando cada
versión por separado.

### 6.1. S3 (data lake)

```bash
uv run python scripts/upload_s3.py
```

Para subir una versión específica, verificar la carga, y correr los
ejercicios de Athena, ver [carga_s3.md](02-s3/carga_s3.md).

### 6.2. RDS

```bash
uv run python scripts/load_rds.py
```

Crea las tablas `customers`/`orders` (DDL en
`src/transformations/lab_storage_schema.sql`) y carga los CSV generados
desde `data/rds/customers_<timestamp>.csv` y `data/rds/orders_<timestamp>.csv`.

Para conectarte con un cliente SQL, verificar la carga, y correr los
ejercicios de consultas del laboratorio, ver
[conexion_rds.md](03-rds/conexion_rds.md) (`psql`) o
[pgadmin.md](03-rds/pgadmin.md) (interfaz visual con pgAdmin).

### 6.3. DynamoDB

```bash
uv run python scripts/load_dynamodb.py
```

Carga los eventos de tracking desde
`data/dynamodb/tracking_events_<timestamp>.json` a la tabla
`package_tracking`.

Para verificar la carga, consultar la tabla, y correr los ejercicios de
Query/Scan del laboratorio, ver
[consultas_dynamodb.md](04-dynamodb/consultas_dynamodb.md). Si vas a
modificar la tabla (agregar un GSI, cambiar su schema) desde la consola
de AWS en algún momento, revisa antes
[consola_vs_terraform.md](04-dynamodb/consola_vs_terraform.md) — algunas
acciones generan drift con el state de Terraform.

---

## 7. Ejecutar los ejercicios del laboratorio

Con los tres data stores poblados, continúa con las secciones 11-14 de
[laboratorio_sesion_03_storage.md](01-contexto/laboratorio_sesion_03_storage.md):
consultas Athena sobre S3 (ver
[consultas_athena.md](02-s3/consultas_athena.md)), consultas SQL sobre RDS
(ver [conexion_rds.md](03-rds/conexion_rds.md) para el paso a paso),
consultas Query/Scan sobre DynamoDB (ver
[consultas_dynamodb.md](04-dynamodb/consultas_dynamodb.md)), y la actividad de
comparación de servicios.

---

## 8. Retos del fin de semana

Sección 16 del documento del laboratorio. Modifica los módulos de
Terraform correspondientes (`infra/modules/s3-datalake`,
`infra/modules/rds`, `infra/modules/dynamodb`) directamente — son tuyos
para experimentar. Recuerda `terraform plan` antes de cada `apply` para
entender el impacto del cambio.

---

## 9. Apagar el laboratorio

**Importante:** RDS genera costo mientras esté desplegado, incluso sin
uso (a diferencia de S3, DynamoDB y Athena, que son pay-per-use). Cuando
termines la sesión de trabajo:

```bash
cd infra
terraform destroy
```

Revisa el plan de destrucción antes de confirmar. Si solo quieres pausar
RDS sin perder el resto de la infraestructura, puedes eliminar únicamente
el módulo `rds` de `infra/main.tf` temporalmente y aplicar — pero lo más
simple y predecible para un laboratorio es destruir todo y volver a
desplegar cuando retomes.

### 9.1. Log group de RDS: bórralo manualmente, no esperes que `destroy` lo haga

Por la misma condición de carrera descrita en la sección 3.2, el log
group `/aws/rds/instance/<name_prefix>-lab-db/postgresql` casi nunca
termina gestionado por Terraform: RDS lo crea por su cuenta apenas
empieza a exportar logs, antes de que Terraform pueda crear el suyo. Esto
es cierto tanto si hiciste el `terraform import` de la sección 3.2 como
si no — en ambos casos, `terraform destroy` no se puede confiar para
eliminarlo (si nunca lo importaste, ni siquiera está en el state y
`destroy` lo ignora por completo; si lo importaste, sí lo borra, pero
solo por esa única vez).

En la práctica, para este laboratorio el log group siempre queda como un
recurso manual: trátalo como tal en vez de depender de Terraform para
limpiarlo. Después de `terraform destroy`, bórralo a mano si ya
terminaste con el laboratorio:

```bash
aws logs delete-log-group \
  --log-group-name "/aws/rds/instance/<name_prefix>-lab-db/postgresql"
```

Sustituye `<name_prefix>` igual que en la sección 3.2
(`${project_name}-${environment}`, p. ej. `data-platform-dev-lab-db` con
los valores del `.example`). Es un borrado manual fuera de Terraform —
según AGENTS.md, el borrado de CloudWatch log groups requiere
confirmación explícita, así que confirma antes de correr el comando que
es el log group correcto (y que no lo necesitas para revisar una corrida
anterior).

Si vas a volver a desplegar pronto, no hace falta borrarlo: el log group
huérfano no estorba, y al recrear la instancia RDS, esta reutiliza (o
recrea) el mismo log group por su cuenta — no requiere ninguna acción de
tu parte ni un nuevo `terraform import` a menos que quieras que Terraform
gestione `retention_in_days`/tags sobre él otra vez.

---

## Referencia rápida — comandos `uv`

Todos los comandos `uv` de esta guía, en orden, listos para copiar y
pegar. Asume que ya completaste `terraform apply` (sección 3),
`src/config/lab_storage_config.yaml` y `.env.credentials` (sección 4).

```bash
# Sincronizar dependencias (paso 1)
uv sync

# Generar datos sintéticos (paso 5)
uv run python scripts/generate_data.py --customers 100 --orders 500 --packages 150 --seed 42

# Cargar a S3, RDS y DynamoDB (paso 6) — usa la versión más reciente generada
uv run python scripts/upload_s3.py
uv run python scripts/load_rds.py
uv run python scripts/load_dynamodb.py
```

Para cargar una versión específica en vez de la más reciente (demostrar
cargas incrementales), agrega `--version <timestamp>` — el timestamp lo
imprime `generate_data.py` al correr (`version: 20260920-143000`):

```bash
uv run python scripts/generate_data.py --seed 43
uv run python scripts/upload_s3.py --version 20260920-143000
uv run python scripts/load_rds.py --version 20260920-143000
uv run python scripts/load_dynamodb.py --version 20260920-143000
```

Herramientas de desarrollo (opcional, no forman parte del flujo del lab):

```bash
uv run python scripts/testing/run_pytest.py
uv run python scripts/testing/run_ruff_check.py
uv run python scripts/testing/run_ruff_format.py --check
```

---

## Problemas comunes

- **No puedo conectarme a RDS ("connection timed out")** — tu IP pública
  cambió desde que desplegaste, o `student_ip_cidr` está mal escrito. Ver
  [requisitos_rds.md](03-rds/requisitos_rds.md).
- **`terraform apply` falla por nombre de bucket duplicado** — ver
  [carga_s3.md](02-s3/carga_s3.md), sección "Problemas comunes".
- **Los scripts fallan con `KeyError` leyendo `.env.credentials` o el
  YAML** — revisa que completaste todos los placeholders de los pasos 2 y
  4; los scripts no tienen valores por defecto para estos campos a
  propósito, para evitar que apunten a recursos equivocados.
