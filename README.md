# Laboratorio Sesión 03 — S3, RDS, DynamoDB y Athena

Laboratorio del bootcamp de Data Engineering: construir con Terraform una
arquitectura pequeña de Data Stores para una plataforma logística
ficticia, y aprender a elegir el servicio de almacenamiento correcto
según el caso de uso (relacional, NoSQL, data lake).

> **Principio del laboratorio:** no se construye una aplicación. El
> objetivo es interactuar directamente con los Data Stores (S3, RDS,
> DynamoDB, Athena) y entender por qué cada servicio existe en la
> arquitectura.

El caso de negocio completo, el diseño de cada servicio, y los
ejercicios están en
[docs/01-contexto/laboratorio_sesion_03_storage.md](docs/01-contexto/laboratorio_sesion_03_storage.md)
— léelo antes de empezar a ejecutar nada.

---

## Empieza aquí

**[docs/guia_ejecucion_lab_storage.md](docs/guia_ejecucion_lab_storage.md)**
es el paso a paso completo: desde `uv sync` hasta desplegar Terraform,
generar datos, cargarlos a los tres servicios, y correr los ejercicios.
Sigue sus secciones en orden — cada una depende de la anterior.

---

## Estructura del proyecto

```
.
├── docs/                  Documentación del laboratorio (ver mapa abajo)
├── infra/                 Infraestructura Terraform, organizada en módulos por servicio
│   └── modules/
│       ├── s3-datalake/   Bucket S3 para el data lake (raw/ + curated/)
│       ├── s3-artifacts/  Bucket de artefactos para jobs Glue/Lambda (desactivado, fuera de alcance de esta sesión)
│       ├── rds/           Instancia PostgreSQL
│       ├── dynamodb/      Tabla package_tracking
│       ├── athena/        Glue Catalog + workgroup de Athena
│       └── iam/           Roles y políticas compartidas
├── scripts/               Scripts Python del laboratorio (generar datos, cargar a cada servicio)
├── src/
│   ├── config/            lab_storage_config.yaml — nombres de recursos (rellenado con `terraform output`)
│   └── transformations/   Schema SQL para RDS
├── data/                  Datos generados localmente (gitignored, no se commitea)
├── tests/                 Tests del proyecto (pytest)
└── .env.credentials       Tus credenciales AWS + conexión RDS (gitignored, no se commitea)
```

---

## Mapa de la documentación (`docs/`)

La documentación está numerada en el orden en que la vas a necesitar:
primero contexto y decisiones de diseño, luego un documento por
servicio, en el mismo orden en que los usa la guía de ejecución (S3 →
RDS → DynamoDB).

### `01-contexto/` — qué se construye y por qué

- [laboratorio_sesion_03_storage.md](docs/01-contexto/laboratorio_sesion_03_storage.md)
  — el documento del laboratorio: caso de negocio, diseño de cada
  servicio, todos los ejercicios y retos.

### `02-s3/` — data lake

- [carga_s3.md](docs/02-s3/carga_s3.md) — subir el dataset Parquet
  generado al bucket S3.
- [consultas_athena.md](docs/02-s3/consultas_athena.md) — consultar esos
  datos con Athena (incluye un paso obligatorio de registro de
  particiones antes de la primera query).

### `03-rds/` — base relacional (PostgreSQL)

- [requisitos_rds.md](docs/03-rds/requisitos_rds.md) — qué necesitas
  antes de desplegar RDS (tu IP pública, una contraseña) y por qué está
  configurado así.
- [clientes_sql.md](docs/03-rds/clientes_sql.md) — instalar un cliente
  SQL (`psql`, pgAdmin, DBeaver...) si no tienes uno.
- [conexion_rds.md](docs/03-rds/conexion_rds.md) — conectarte con `psql`
  y correr las queries del laboratorio.
- [pgadmin.md](docs/03-rds/pgadmin.md) — lo mismo, pero con pgAdmin
  (interfaz visual en vez de terminal).

### `04-dynamodb/` — NoSQL

- [consultas_dynamodb.md](docs/04-dynamodb/consultas_dynamodb.md) —
  Query y Scan sobre la tabla `package_tracking`, con CLI y consola de
  AWS.
- [consola_vs_terraform.md](docs/04-dynamodb/consola_vs_terraform.md) —
  qué operaciones puedes hacer desde la consola de AWS sin riesgo, y
  cuáles generan *drift* con el estado de Terraform (importante antes de
  intentar el Reto 3 del laboratorio).

### `internal/` — documentación técnica del proyecto

No es material del alumno — son registros de decisiones de arquitectura
(ADRs) para quien mantenga este repo como plantilla.

---

## Flujo resumido

```
uv sync
        │
        ▼
terraform apply (infra/)  ───────────────►  S3, RDS, DynamoDB, Athena creados
        │
        ▼
generate_data.py  ─────►  data/{s3,rds,dynamodb}/*_<timestamp>.*
        │
        ├──► upload_s3.py       ──► S3 (raw/events/)
        ├──► load_rds.py        ──► RDS (customers, orders)
        └──► load_dynamodb.py   ──► DynamoDB (package_tracking)
        │
        ▼
Ejercicios de consulta (Athena / psql-pgAdmin / CLI DynamoDB)
        │
        ▼
terraform destroy (al terminar la sesión — RDS genera costo mientras está desplegado)
```

El paso a paso detallado de cada flecha está en
[docs/guia_ejecucion_lab_storage.md](docs/guia_ejecucion_lab_storage.md).

---

## Reglas del proyecto

Este repo sigue el contrato de agentes en [AGENTS.md](AGENTS.md) —
resumen relevante para el alumno:

- **No hardcodear valores** — nombres de bucket, tablas, endpoints
  siempre vienen de `terraform output` hacia `src/config/lab_storage_config.yaml`
  y `.env.credentials`, nunca escritos directamente en el código.
- **Nunca commitear secretos** — `.env.credentials` y `terraform.tfvars`
  están gitignored; la contraseña de RDS no va en ningún archivo del
  repo salvo esos dos.
- **Terraform es la única fuente de verdad de la infraestructura** — no
  modifiques recursos (tablas, buckets, índices) desde la consola de AWS
  sin luego reflejarlo en Terraform (ver
  [consola_vs_terraform.md](docs/04-dynamodb/consola_vs_terraform.md)
  para el caso concreto de DynamoDB).
