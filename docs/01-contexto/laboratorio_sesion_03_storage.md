# Laboratorio --- Diseño de Data Stores para una plataforma logística

## Sesión 03 --- S3, RDS, DynamoDB y Athena

### Objetivo

Construir con Terraform una arquitectura pequeña de Data Stores para una
plataforma logística ficticia.

El laboratorio busca que el alumno:

-   despliegue infraestructura con Terraform;
-   genere y cargue datos sintéticos;
-   almacene datos en S3;
-   consulte datos analíticos con Athena;
-   almacene información relacional en RDS;
-   ejecute consultas SQL;
-   modele un caso de uso NoSQL en DynamoDB;
-   interactúe con DynamoDB mediante consultas;
-   compare las decisiones de almacenamiento;
-   modifique la infraestructura mediante Terraform;
-   justifique técnicamente sus decisiones.

> **Principio del laboratorio:** no construir una aplicación. El
> objetivo es interactuar directamente con los Data Stores y comprender
> por qué cada servicio existe en la arquitectura.

------------------------------------------------------------------------

# 1. Caso de negocio

Una empresa de logística administra:

-   clientes;
-   órdenes;
-   paquetes;
-   eventos de tracking;
-   información histórica de operaciones.

La empresa necesita almacenar diferentes tipos de información:

### Información transaccional

Clientes y órdenes:

``` text
Customer
   │
   └── Order
          │
          └── Order Items
```

Necesita:

-   relaciones;
-   integridad;
-   SQL;
-   transacciones.

**Servicio:** Amazon RDS.

### Información de tracking operacional

Cada paquete genera múltiples eventos:

``` text
PKG-000001
    │
    ├── RECEIVED
    ├── IN_TRANSIT
    ├── OUT_FOR_DELIVERY
    └── DELIVERED
```

Necesita:

-   consultas rápidas;
-   baja latencia;
-   patrón de acceso conocido;
-   historial por paquete.

**Servicio:** Amazon DynamoDB.

### Información histórica para analytics

Los eventos operacionales también deben conservarse como datos
históricos para análisis.

``` text
events/
├── year=2026/
│   └── month=09/
│       └── day=21/
│           └── events.parquet
```

**Servicio:** Amazon S3.

Las consultas analíticas se realizarán mediante:

**Amazon Athena.**

------------------------------------------------------------------------

# 2. Arquitectura

``` text
                         PYTHON
                    Synthetic Dataset
                           │
             ┌─────────────┼─────────────┐
             │             │             │
             ▼             ▼             ▼
          Amazon S3       Amazon RDS   DynamoDB
          Data Lake       Relational   Tracking
             │             │             │
             ▼             ▼             ▼
           Athena          SQL         Query
             │
             └──────────────┬──────────────┘
                            ▼
                    Business Questions
```

Terraform será responsable de crear la infraestructura.

------------------------------------------------------------------------

# 3. Estructura del proyecto

Propuesta:

``` text
session-03-storage/
│
├── terraform/
│   ├── provider.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── s3.tf
│   ├── rds.tf
│   ├── dynamodb.tf
│   ├── athena.tf
│   └── iam.tf
│
├── data/
│   ├── customers.csv
│   ├── orders.csv
│   ├── tracking_events.json
│   └── tracking_events.parquet
│
├── scripts/
│   ├── generate_data.py
│   ├── upload_s3.py
│   └── load_dynamodb.py
│
└── README.md
```

No es obligatorio mantener exactamente esta estructura; el objetivo es
separar:

-   infraestructura;
-   datos;
-   scripts;
-   documentación.

------------------------------------------------------------------------

# 4. Dataset sintético

Crear un script Python que genere datos ficticios.

## 4.1. Customers

Ejemplo:

``` text
customer_id,name,city,segment
C001,Customer 001,Lima,Enterprise
C002,Customer 002,Ica,SMB
C003,Customer 003,Arequipa,Enterprise
```

Generar aproximadamente:

-   100 clientes.

## 4.2. Orders

Ejemplo:

``` text
order_id,customer_id,order_date,status,total_amount
O001,C001,2026-09-20,DELIVERED,450.50
O002,C003,2026-09-21,IN_TRANSIT,120.00
```

Generar aproximadamente:

-   500 órdenes.

## 4.3. Tracking events

Ejemplo:

``` json
{
  "package_id": "PKG-000001",
  "timestamp": "2026-09-21T10:00:00",
  "status": "RECEIVED",
  "city": "Lima"
}
```

Generar múltiples eventos por paquete.

------------------------------------------------------------------------

# 5. Terraform --- S3

Crear un bucket privado para el Data Lake.

Requisitos mínimos:

-   bucket;
-   Block Public Access;
-   versioning;
-   encryption;
-   lifecycle básico.

Estructura lógica:

``` text
s3://<bucket>/
│
├── raw/
│   └── events/
│
└── curated/
    └── events/
```

Para el laboratorio, los datos analíticos deben terminar en formato
Parquet.

------------------------------------------------------------------------

# 6. Terraform --- RDS

Crear una instancia RDS para PostgreSQL.

Objetivo didáctico:

-   comprender cómo Terraform representa una base relacional;
-   conectarse a la base;
-   crear tablas;
-   cargar datos;
-   ejecutar SQL.

Tablas mínimas:

``` sql
CREATE TABLE customers (
    customer_id VARCHAR(20) PRIMARY KEY,
    name VARCHAR(100),
    city VARCHAR(100),
    segment VARCHAR(50)
);

CREATE TABLE orders (
    order_id VARCHAR(20) PRIMARY KEY,
    customer_id VARCHAR(20),
    order_date DATE,
    status VARCHAR(30),
    total_amount DECIMAL(12,2),
    FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
);
```

> El objetivo del laboratorio no es enseñar administración de
> PostgreSQL. La base existe para demostrar el caso de uso relacional y
> practicar consultas.

------------------------------------------------------------------------

# 7. Terraform --- DynamoDB

Crear una tabla para tracking.

Diseño propuesto:

``` text
Table: package_tracking

Partition Key:
    package_id

Sort Key:
    timestamp
```

Ejemplo:

``` text
PKG-000001 | 2026-09-21T10:00:00
PKG-000001 | 2026-09-21T11:30:00
PKG-000001 | 2026-09-21T14:20:00
```

Esto permite consultar eficientemente:

> "Dame todo el historial del paquete PKG-000001."

------------------------------------------------------------------------

# 8. Terraform --- Athena

Crear los recursos necesarios para ejecutar consultas sobre S3.

Conceptualmente:

``` text
S3
 │
 ▼
Glue Data Catalog
 │
 ▼
Athena
```

El laboratorio puede utilizar una base de datos y tabla externas que
apunten al dataset Parquet almacenado en S3.

La infraestructura debe permitir ejecutar SQL desde Athena sin mover los
datos a una base de datos relacional.

------------------------------------------------------------------------

# 9. Despliegue

Desde la carpeta de Terraform:

``` bash
terraform init
```

Validar:

``` bash
terraform fmt
terraform validate
```

Revisar:

``` bash
terraform plan
```

Desplegar:

``` bash
terraform apply
```

Después del despliegue:

``` bash
terraform output
```

Los outputs deberían proporcionar los identificadores necesarios para
interactuar con los recursos.

------------------------------------------------------------------------

# 10. Carga de datos

## 10.1. S3

Cargar los datos:

``` bash
aws s3 cp ...
```

o mediante un script Python/boto3.

Verificar:

``` bash
aws s3 ls s3://<bucket>/raw/events/
```

------------------------------------------------------------------------

## 10.2. RDS

Conectarse a PostgreSQL mediante un cliente SQL.

Crear las tablas:

``` sql
CREATE TABLE ...
```

Cargar los CSV.

Validar:

``` sql
SELECT COUNT(*) FROM customers;

SELECT COUNT(*) FROM orders;
```

------------------------------------------------------------------------

## 10.3. DynamoDB

Cargar los eventos de tracking.

Validar mediante CLI:

``` bash
aws dynamodb scan \
  --table-name package_tracking
```

El `scan` se utiliza aquí únicamente para inspección inicial.

------------------------------------------------------------------------

# 11. Ejercicios con S3 + Athena

## Consulta 1 --- Total de eventos

``` sql
SELECT COUNT(*)
FROM tracking_events;
```

### Pregunta

¿Qué cantidad de datos necesita procesar Athena para responder esta
consulta?

------------------------------------------------------------------------

## Consulta 2 --- Eventos por estado

``` sql
SELECT
    status,
    COUNT(*) AS total
FROM tracking_events
GROUP BY status;
```

------------------------------------------------------------------------

## Consulta 3 --- Eventos por ciudad

``` sql
SELECT
    city,
    COUNT(*) AS total
FROM tracking_events
GROUP BY city
ORDER BY total DESC;
```

------------------------------------------------------------------------

## Consulta 4 --- Uso de particiones

Consultar únicamente un día:

``` sql
SELECT COUNT(*)
FROM tracking_events
WHERE year = '2026'
  AND month = '09'
  AND day = '21';
```

### Pregunta

¿Por qué esta consulta puede ser más eficiente que consultar todo el
dataset?

------------------------------------------------------------------------

# 12. Ejercicios con RDS

## Consulta 1 --- Clientes

``` sql
SELECT *
FROM customers
LIMIT 10;
```

## Consulta 2 --- Órdenes por cliente

``` sql
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

## Consulta 3 --- Ventas por ciudad

``` sql
SELECT
    c.city,
    SUM(o.total_amount) AS revenue
FROM customers c
JOIN orders o
    ON c.customer_id = o.customer_id
GROUP BY c.city
ORDER BY revenue DESC;
```

### Pregunta de discusión

¿Por qué esta información se modeló en RDS y no directamente en
DynamoDB?

------------------------------------------------------------------------

# 13. Ejercicios con DynamoDB

## Consulta 1 --- Obtener un paquete

Realizar un `Query` utilizando:

``` text
package_id = PKG-000001
```

El objetivo es recuperar todo el historial del paquete.

------------------------------------------------------------------------

## Consulta 2 --- Inspección mediante Scan

Ejecutar un `Scan`.

Después responder:

> ¿Por qué un Scan no debería ser la estrategia habitual para consultar
> una tabla grande?

------------------------------------------------------------------------

## Consulta 3 --- Access Pattern

Nuevo requerimiento:

> "El área de operaciones necesita consultar rápidamente todos los
> paquetes asociados a una determinada ciudad."

El alumno debe determinar:

1.  ¿La tabla actual permite realizar esta consulta eficientemente?
2.  ¿Qué clave utilizaría?
3.  ¿Necesita un GSI?
4.  ¿Cómo cambiaría el modelo?

No implementar inicialmente la solución. Primero justificarla.

------------------------------------------------------------------------

# 14. Actividad de comparación

Presentar los siguientes requerimientos y pedir al alumno que seleccione
el servicio:

### Caso A

> Almacenar millones de archivos históricos y consultarlos
> ocasionalmente con SQL.

**Servicio esperado:** S3 + Athena.

### Caso B

> Sistema transaccional con clientes, órdenes y relaciones.

**Servicio esperado:** RDS.

### Caso C

> Obtener el historial de un paquete mediante su identificador con baja
> latencia.

**Servicio esperado:** DynamoDB.

### Caso D

> Guardar documentos PDF recibidos diariamente.

**Servicio esperado:** S3.

### Caso E

> Consultar datos relacionales utilizando JOIN.

**Servicio esperado:** RDS.

------------------------------------------------------------------------

# 15. Parte de deconstrucción

Después del laboratorio, revisar el Terraform recurso por recurso.

## S3

Preguntar:

-   ¿Por qué bucket?
-   ¿Por qué privado?
-   ¿Por qué versioning?
-   ¿Por qué encryption?
-   ¿Qué problema resuelve lifecycle?
-   ¿Por qué Parquet?
-   ¿Por qué particionar?

## RDS

Preguntar:

-   ¿Por qué PostgreSQL?
-   ¿Por qué una base relacional?
-   ¿Qué aporta Multi-AZ?
-   ¿Qué diferencia existe entre backup y snapshot?
-   ¿Qué diferencia existe entre Multi-AZ y Read Replica?

## DynamoDB

Preguntar:

-   ¿Cuál es la partition key?
-   ¿Cuál es la sort key?
-   ¿Qué access pattern permite?
-   ¿Qué ocurre si necesitamos otro patrón de consulta?
-   ¿Cuándo utilizaríamos un GSI?
-   ¿Por qué un Scan puede ser problemático?

## Athena

Preguntar:

-   ¿Dónde están físicamente los datos?
-   ¿Qué hace Athena?
-   ¿Qué hace Glue Data Catalog?
-   ¿Qué determina el costo de una consulta?
-   ¿Cómo reduciríamos los datos procesados?

------------------------------------------------------------------------

# 16. Reto para el fin de semana

El alumno debe modificar el laboratorio utilizando Terraform.

## Reto 1 --- S3

Agregar/modificar:

-   lifecycle rule;
-   configuración de versioning;
-   estructura de particiones;
-   configuración de encryption.

Debe explicar:

> ¿Qué hace cada cambio y qué problema resuelve?

------------------------------------------------------------------------

## Reto 2 --- RDS

Modificar alguna configuración relacionada con:

-   backups;
-   retention;
-   disponibilidad;
-   almacenamiento.

Debe explicar:

> ¿Qué impacto tiene la configuración modificada?

------------------------------------------------------------------------

## Reto 3 --- DynamoDB

Diseñar una solución para este nuevo access pattern:

> "El área comercial necesita consultar todos los paquetes por ciudad."

El alumno debe:

1.  analizar el patrón de acceso;
2.  determinar si necesita un GSI;
3.  definir las claves;
4.  modificar Terraform;
5.  cargar datos de prueba;
6.  ejecutar una consulta;
7.  explicar la decisión.

------------------------------------------------------------------------

# 17. Entrega

El alumno puede entregar:

-   video corto; **o**
-   documento Word/PDF con screenshots.

Debe incluir:

``` text
1. Objetivo
2. Problema planteado
3. Cambio realizado
4. Terraform utilizado
5. Evidencia del deployment
6. Evidencia de funcionamiento
7. Explicación de cada configuración
8. Justificación técnica
9. Resultado obtenido
10. ¿Qué trade-off introduce el cambio?
```

------------------------------------------------------------------------

# 18. Criterios de evaluación

  Criterio                      Peso
  --------------------------- ------
  Implementación                 30%
  Uso correcto de Terraform      20%
  Comprensión de AWS             25%
  Justificación técnica          15%
  Evidencia/documentación        10%

La solución no debe evaluarse únicamente por "funciona/no funciona".

Se debe valorar que el alumno pueda explicar:

> **qué configuró, por qué lo configuró y qué consecuencias tiene esa
> decisión.**

------------------------------------------------------------------------

# 19. Resultado esperado del laboratorio

Al finalizar, el alumno debería poder explicar la arquitectura:

``` text
                 DATA SOURCES
                      │
                      ▼
                Synthetic Data
                      │
          ┌───────────┼───────────┐
          │           │           │
          ▼           ▼           ▼
         S3          RDS       DynamoDB
       Data Lake   Relational   NoSQL
          │           │           │
          ▼           ▼           ▼
       Athena        SQL         Query
          │
          └───────────┬───────────┘
                      ▼
                 ANALYTICS
```

Y, sobre todo, responder:

> **¿Por qué cada dato está almacenado en ese servicio y no en otro?**

Ese es el objetivo principal del laboratorio.
