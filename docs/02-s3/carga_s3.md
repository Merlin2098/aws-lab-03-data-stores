# Cargar datos al data lake S3

Cubre cómo subir el dataset Parquet generado al bucket S3 del
laboratorio (ver
[guia_ejecucion_lab_storage.md](../guia_ejecucion_lab_storage.md), paso
6), y cómo verificar la carga.

---

## 1. Subir el dataset

```bash
uv run python scripts/upload_s3.py
# o una versión específica:
uv run python scripts/upload_s3.py --version 20260920-143000
```

Sube el dataset Parquet particionado
(`data/s3/tracking_events_<timestamp>.parquet/`) a
`s3://<datalake_bucket_name>/raw/events/...`, preservando la estructura
de particiones `year=/month=/day=` generada por
`scripts/generate_data.py`.

Por defecto sube la versión (timestamp) más reciente encontrada en
`data/s3/`. Pasa `--version <timestamp>` para subir una corrida
específica en vez de la última — útil para demostrar cargas
incrementales.

---

## 2. Verificar la carga

```bash
aws s3 ls s3://<datalake_bucket_name>/raw/events/ --recursive
```

Deberías ver una lista de archivos `.parquet`, uno o más por cada
combinación de `year=/month=/day=` presente en los datos generados —
normalmente varias decenas de archivos si generaste eventos distribuidos
en una ventana de 30 días. Esto es el comportamiento esperado del
particionado Hive-style, no un error: cada partición se sube como su
propio archivo.

---

## 3. Ejercicios con S3 + Athena

Las consultas analíticas sobre estos datos se ejecutan con Amazon
Athena, no directamente sobre S3 — Athena lee los archivos Parquet vía
el Glue Data Catalog. Ver [consultas_athena.md](consultas_athena.md)
para el paso a paso completo (incluye un paso obligatorio de registro de
particiones antes de la primera consulta) y las queries de ejercicio de
la sección 11 del laboratorio.

---

## 4. Problemas comunes

- **`terraform apply` falla por nombre de bucket duplicado** — los
  nombres de bucket son globalmente únicos en S3; el proyecto ya incluye
  el account ID en el nombre para evitar colisiones entre alumnos, así
  que esto normalmente indica que ya desplegaste antes y el bucket sigue
  existiendo (revisa si olvidaste un `terraform destroy` anterior).
- **`upload_s3.py` falla con `FileNotFoundError`** — no generaste datos
  todavía, o generaste una versión distinta a la que pasaste en
  `--version`. Corre `uv run python scripts/generate_data.py` primero.
- **Veo muchos más archivos `.parquet` de los que esperaba** — es
  normal: cada día distinto presente en los eventos generados produce su
  propia partición/archivo. No es un error de la carga.
