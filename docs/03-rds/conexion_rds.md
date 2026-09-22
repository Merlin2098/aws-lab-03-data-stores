# Conectarse a RDS y ejecutar queries

Cubre cómo conectarte a la instancia PostgreSQL del laboratorio con
`psql` y las queries de la sección 12
([laboratorio_sesion_03_storage.md](../01-contexto/laboratorio_sesion_03_storage.md))
una vez que los datos ya están cargados
(ver [guia_ejecucion_lab_storage.md](../guia_ejecucion_lab_storage.md), paso
6.2).

Si no tienes `psql` instalado o no está en tu `PATH`, ver
[clientes_sql.md](clientes_sql.md) primero. Si prefieres una interfaz
visual en vez de la terminal, ver [pgadmin.md](pgadmin.md).

---

## 1. Datos de conexión

Los cuatro valores que necesitas viven en tu `.env.credentials`
(gitignored, nunca se commitea):

| Variable         | Origen                                                                               |
| ---------------- | ------------------------------------------------------------------------------------ |
| `RDS_ENDPOINT` | `terraform output rds_endpoint` (incluye `host:puerto`)                          |
| `RDS_DB_NAME`  | `terraform output rds_db_name`                                                     |
| `RDS_USERNAME` | el que definiste en`terraform.tfvars` (`rds_db_username`, default `lab_admin`) |
| `RDS_PASSWORD` | el mismo valor que pusiste en`rds_db_password`                                     |

Carga esas variables a tu sesión de terminal (Git Bash):

```bash
set -a
source .env.credentials
set +a
```

---

## 2. Conectarte con `psql`

`RDS_ENDPOINT` viene como `host:puerto` en una sola cadena — sepáralos o
pásalos directamente en la cadena de conexión:

```bash
psql "host=${RDS_ENDPOINT%%:*} port=5432 dbname=$RDS_DB_NAME user=$RDS_USERNAME password=$RDS_PASSWORD"
```

`${RDS_ENDPOINT%%:*}` recorta todo desde el primer `:` en adelante,
dejando solo el host.

Si prefieres escribir los valores directamente (más simple de leer, pero
tienes que pegarlos a mano):

```bash
psql "host=<tu-endpoint>.rds.amazonaws.com port=5432 dbname=logistics user=lab_admin password=<tu-password>"
```

`dbname=logistics` y `user=lab_admin` son los valores por defecto de
`rds_db_name`/`rds_db_username` en
[infra/variables.tf](../../infra/variables.tf) — si no los cambiaste en
tu `terraform.tfvars`, solo necesitas reemplazar `<tu-endpoint>` y
`<tu-password>` en el comando de arriba. Si sí los cambiaste, usa los
valores que definiste ahí en vez de `logistics`/`lab_admin`.

Al conectar, el prompt cambia a `<db>=>` (ej. `logistics=>`) — ya estás
dentro.

### No puedo conectarme

- **`connection timed out`** — tu IP pública cambió desde que
  desplegaste, o `student_ip_cidr` está mal. Ver
  [requisitos_rds.md](requisitos_rds.md).
- **`fe_sendauth: no password supplied` / conecta a `localhost`** —
  `RDS_ENDPOINT`/`RDS_PASSWORD` no se cargaron en tu sesión. Repite el
  paso 1, o abre una terminal nueva y vuelve a hacer `source`.
- **`password authentication failed`** — la contraseña en
  `.env.credentials` no coincide con la que usaste en
  `TF_VAR_rds_db_password` / `terraform.tfvars` al crear la instancia.

---

## 3. Explorar la base (meta-comandos de `psql`)

Comandos que empiezan con `\` — no son SQL, son propios de `psql`:

```
\dt              -- listar tablas
\d customers     -- estructura de la tabla customers (columnas, tipos, PK/FK)
\d orders        -- estructura de la tabla orders
\x               -- alternar modo expandido (útil si las columnas no caben en pantalla)
\q               -- salir
```

---

## 4. Ejercicios — Sección 12 del laboratorio

Estas son las queries de la sección "12. Ejercicios con RDS" del
documento del laboratorio. Cada una termina en `;` y se ejecuta
directamente en el prompt de `psql`.

### Consulta 1 — Clientes

```sql
SELECT *
FROM customers
LIMIT 10;
```

### Consulta 2 — Órdenes por cliente

```sql
SELECT
    c.customer_id,
    c.name,
    COUNT(o.order_id) AS total_orders
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.name
ORDER BY total_orders DESC;
```

### Consulta 3 — Ventas por ciudad

```sql
SELECT
    c.city,
    SUM(o.total_amount) AS revenue
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
GROUP BY c.city
ORDER BY revenue DESC;
```

**Pregunta de discusión del laboratorio:** ¿por qué esta información se
modeló en RDS y no directamente en DynamoDB?

---

## 5. Verificación rápida (post-carga)

Después de correr `scripts/load_rds.py`, para confirmar que los datos
llegaron:

```sql
SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM orders;
```

Deberías ver los mismos conteos que imprimió el script al cargar (por
defecto ~100 clientes, ~500 órdenes, salvo que hayas cambiado
`--customers`/`--orders` en `generate_data.py`).

Si no tienes `psql` a mano en ese momento, hay una forma equivalente
de verificar desde Python sin salir del venv del proyecto:

```bash
uv run python -c "
import sys; sys.path.insert(0, 'scripts')
import psycopg2
from lab_storage_common import get_rds_connection_params

conn = psycopg2.connect(**get_rds_connection_params())
with conn.cursor() as cur:
    cur.execute('SELECT COUNT(*) FROM customers;')
    print('customers:', cur.fetchone()[0])
    cur.execute('SELECT COUNT(*) FROM orders;')
    print('orders:', cur.fetchone()[0])
conn.close()
"
```
