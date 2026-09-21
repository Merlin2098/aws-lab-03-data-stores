# Conectarse a RDS con pgAdmin

Alternativa visual a [conexion_rds.md](conexion_rds.md) para explorar la
instancia PostgreSQL del laboratorio sin usar la terminal. Útil si
prefieres navegar tablas con clicks, ver los datos en una grilla, o
correr SQL en un editor con autocompletado.

pgAdmin viene incluido con el instalador de PostgreSQL (ver
[clientes_sql.md](clientes_sql.md), Opción A) — si ya instalaste
PostgreSQL con el componente "pgAdmin 4" marcado, ya lo tienes.

---

## 1. Datos de conexión

Los mismos cuatro valores que usa `psql`, desde tu `.env.credentials`:

| Campo en pgAdmin | Variable | Origen |
|---|---|---|
| Host name/address | `RDS_ENDPOINT` (solo la parte antes de `:`) | `terraform output rds_endpoint` |
| Port | `5432` | parte después de `:` en `RDS_ENDPOINT` |
| Maintenance database | `RDS_DB_NAME` | `terraform output rds_db_name` |
| Username | `RDS_USERNAME` | `rds_db_username` en `terraform.tfvars` (default `lab_admin`) |
| Password | `RDS_PASSWORD` | el mismo valor que `rds_db_password` |

`RDS_ENDPOINT` en tu `.env.credentials` viene como `host:puerto` en una
sola cadena (ej.
`data-platform-dev-lab-db.xxxxx.us-east-1.rds.amazonaws.com:5432`) — en
pgAdmin el host y el puerto van en campos separados, recorta el `:5432`
del final al copiar el host.

---

## 2. Abrir pgAdmin

Búscalo en el menú de inicio como **pgAdmin 4**. La primera vez pedirá
una contraseña maestra — es solo para proteger pgAdmin localmente
(cifra las contraseñas de tus conexiones guardadas), no tiene relación
con la contraseña de RDS.

---

## 3. Registrar el servidor

1. En el panel izquierdo, click derecho en **Servers** → **Register** →
   **Server...**
2. Pestaña **General**:
   - **Name**: cualquier nombre descriptivo, ej. `lab-storage RDS`
3. Pestaña **Connection**:
   - **Host name/address**: tu `RDS_ENDPOINT` sin el puerto (ej.
     `data-platform-dev-lab-db.xxxxx.us-east-1.rds.amazonaws.com`)
   - **Port**: `5432`
   - **Maintenance database**: tu `RDS_DB_NAME` (ej. `logistics`)
   - **Username**: tu `RDS_USERNAME` (ej. `lab_admin`)
   - **Password**: tu `RDS_PASSWORD`
   - Marca **Save password** si no quieres reingresarla cada vez que
     abras pgAdmin
4. Click **Save**.

Si los datos son correctos, el servidor aparece en el árbol izquierdo ya
conectado (ícono sin la "x" roja).

### No puedo conectarme

Los mismos problemas que con `psql` (mismo endpoint, mismo security
group) — ver [conexion_rds.md](conexion_rds.md#no-puedo-conectarme):

- **Se queda cargando o falla por timeout** — tu IP pública cambió desde
  que desplegaste, o `student_ip_cidr` está mal. Ver
  [requisitos_rds.md](requisitos_rds.md).
- **`password authentication failed`** — la contraseña no coincide con
  la que usaste al crear la instancia (`TF_VAR_rds_db_password` /
  `terraform.tfvars`).
- **No encuentra el host** — revisa que copiaste el host sin el `:5432`
  al final; pgAdmin lo rechaza si queda pegado al nombre de host.

---

## 4. Explorar las tablas visualmente

En el árbol izquierdo, navega:

```
lab-storage RDS
  └── Databases
        └── logistics
              └── Schemas
                    └── public
                          └── Tables
                                ├── customers
                                └── orders
```

- Click derecho sobre `customers` → **View/Edit Data** → **All Rows** —
  muestra los datos en una grilla editable, sin escribir SQL.
- Click derecho sobre `customers` → **Properties** → pestaña
  **Columns** — muestra tipos de datos y constraints, equivalente a
  `\d customers` en `psql`.

---

## 5. Ejecutar SQL con el Query Tool

Para correr las queries de la sección 12 del laboratorio (las mismas de
[conexion_rds.md](conexion_rds.md), sección 4), usa el editor SQL en vez
del prompt de `psql`:

1. Click derecho sobre la base `logistics` → **Query Tool** (o el ícono
   de rayo ⚡ en la barra superior).
2. Pega la query en el editor y ejecuta con el botón ▶ o `F5`.

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

Los resultados aparecen en una grilla debajo del editor, con la opción
de exportarlos a CSV desde el botón de descarga — útil si quieres
llevarte los resultados fuera de pgAdmin.

---

## 6. Verificación rápida (post-carga)

Después de correr `scripts/load_rds.py`, en el Query Tool:

```sql
SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM orders;
```

Deberías ver los mismos conteos que imprimió el script al cargar (por
defecto ~100 clientes, ~500 órdenes).

---

## 7. Problemas comunes

- **El árbol de tablas aparece vacío bajo `public`** — no corriste
  `scripts/load_rds.py` todavía, o pgAdmin cacheó una vista antigua del
  schema. Click derecho en `Tables` → **Refresh**.
- **pgAdmin se congela unos segundos al conectar** — normal en la
  primera conexión a una instancia remota; AWS RDS no está en tu red
  local, la latencia inicial es esperada.
- **Quiero volver a la terminal en vez de pgAdmin** — ambos apuntan al
  mismo servidor; puedes alternar libremente entre pgAdmin y `psql`
  ([conexion_rds.md](conexion_rds.md)) sin ningún conflicto, ninguno
  bloquea al otro.
