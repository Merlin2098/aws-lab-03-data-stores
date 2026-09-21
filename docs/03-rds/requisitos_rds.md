# Requisitos para usar RDS en el laboratorio

El módulo `infra/modules/rds` despliega una instancia PostgreSQL pensada
específicamente para este laboratorio, no para producción. Este documento
explica qué necesitas antes de desplegarla, por qué está configurada así,
y qué implicaciones tiene.

Para el paso a paso de ejecución completo, ver
[guia_ejecucion_lab_storage.md](../guia_ejecucion_lab_storage.md).

---

## 1. Qué necesitas antes de desplegar

### 1.1. Tu IP pública, en formato CIDR

RDS solo acepta conexiones desde la IP que declares en
`terraform.tfvars` (variable `student_ip_cidr`). Obtén tu IP pública
actual:

```bash
curl -s https://checkip.amazonaws.com
```

Y escríbela en `terraform.tfvars` como `/32` (una sola IP):

```hcl
student_ip_cidr = "203.0.113.5/32"
```

Si tu IP cambia (redes domésticas suelen ser dinámicas, o cambias de
red/VPN), las conexiones a RDS empiezan a fallar con timeout. Solución:
actualiza `student_ip_cidr` con la nueva IP y corre `terraform apply` de
nuevo — solo se actualiza la regla del security group, no se recrea la
base de datos.

### 1.2. Una contraseña para el usuario maestro

RDS requiere una contraseña para el usuario `lab_admin` (o el que
definas en `rds_db_username`). No la pongas en `terraform.tfvars` ni en
ningún archivo del repo, ni siquiera uno gitignored — expórtala como
variable de entorno antes de `terraform apply`:

```bash
export TF_VAR_rds_db_password="una-contraseña-fuerte-y-única"
```

Requisitos de PostgreSQL/RDS para la contraseña: 8-128 caracteres, sin
`/`, `"`, `@`, ni espacios.

Guarda esta misma contraseña en tu `.env.credentials` local
(`RDS_PASSWORD=...`) — los scripts de carga (`scripts/load_rds.py`) la
necesitan para conectarse.

### 1.3. Un cliente SQL

Necesitas algún cliente para conectarte y explorar la base manualmente
(más allá de lo que hacen los scripts): DBeaver, TablePlus, psql, o la
extensión de PostgreSQL de tu editor. La cadena de conexión usa:

- Host/puerto: output `rds_endpoint` de Terraform (formato
  `host:puerto`)
- Base de datos: output `rds_db_name`
- Usuario: el que definiste en `rds_db_username` (default `lab_admin`)
- Contraseña: la que exportaste en `TF_VAR_rds_db_password`

---

## 2. Por qué está configurada así

### 2.1. `publicly_accessible = true` + security group restringido

Esta es la desviación más importante respecto a las políticas de
seguridad por defecto del proyecto (AGENTS.md exige recursos privados
por defecto). Se documenta explícitamente como excepción de laboratorio:

- **Qué hace:** la instancia RDS recibe una IP pública, pero el security
  group solo permite tráfico entrante al puerto 5432 desde la IP exacta
  que declaraste en `student_ip_cidr`. Nadie más puede conectarse.
- **Por qué:** el objetivo del laboratorio es que te conectes
  directamente con un cliente SQL desde tu máquina, sin levantar un
  bastion host ni configurar SSM Session Manager — infraestructura que
  el laboratorio no cubre y que distraería del objetivo pedagógico
  (entender RDS, no aprender a administrar acceso privado a VPC).
- **Qué no hacer:** replicar este patrón (`publicly_accessible = true`)
  en cualquier infraestructura real. En producción, RDS debe vivir en
  subnets privadas, accesible solo desde dentro de la VPC o vía bastion/
  SSM.

### 2.2. `db.t3.micro`, single-AZ, sin Multi-AZ

Configuración mínima para mantener el costo bajo durante el laboratorio.
Multi-AZ, tipos de instancia mayores, y mayor `backup_retention_period`
son justamente el contenido del **Reto 2** del laboratorio (sección 16
de `laboratorio_sesion_03_storage.md`) — se modifican después,
intencionalmente, como ejercicio.

### 2.3. `skip_final_snapshot = true`, `backup_retention_period = 1`

Permite destruir la instancia rápido y sin fricción al terminar la
sesión (`terraform destroy` no queda bloqueado esperando un snapshot
final). No es apropiado para producción, donde normalmente querrías un
snapshot final y una retención de backups mayor.

### 2.4. VPC y subnets default de la cuenta

El módulo usa `data "aws_vpc" "default"` y `data "aws_subnets" "default"`
en vez de crear una VPC dedicada. Esto asume que tu cuenta AWS tiene una
VPC default (la mayoría de cuentas nuevas la tienen). Si tu cuenta no
tiene VPC default, `terraform plan` fallará al resolver esos data
sources — en ese caso, avisa antes de intentar crear una VPC manualmente
para el lab.

---

## 3. Costo e implicaciones

RDS es el **único** recurso del laboratorio que genera costo mientras
está desplegado, incluso sin uso — a diferencia de S3, DynamoDB
(`PAY_PER_REQUEST`) y Athena, que cobran por uso real.

Con `db.t3.micro` y 20 GB de almacenamiento, el costo es bajo pero no
cero, y puede calificar para el Free Tier de tu cuenta AWS según
antigüedad y elegibilidad. No asumas que es gratis — revisa tu Free Tier
usage en la consola de Billing.

**Recomendación:** al terminar cada sesión de trabajo, corre
`terraform destroy` (ver sección 9 de la guía de ejecución). Vuelve a
desplegar con `terraform apply` cuando retomes — el `db_name` y schema se
recrean en segundos con `scripts/load_rds.py`.

---

## 4. Qué pasa si no cumples estos requisitos

| Situación | Síntoma | Solución |
|---|---|---|
| No configuraste `student_ip_cidr` | `terraform plan` falla: variable requerida sin valor | Complétala en `terraform.tfvars` |
| Tu IP cambió después de desplegar | Timeout al conectar con el cliente SQL | Actualiza `student_ip_cidr` y corre `terraform apply` de nuevo |
| No exportaste `TF_VAR_rds_db_password` | `terraform plan`/`apply` falla: variable sensible sin valor | Expórtala antes de correr Terraform |
| Contraseña no cumple reglas de RDS | `terraform apply` falla en la creación de `aws_db_instance` | Usa una contraseña de 8-128 caracteres sin `/`, `"`, `@` ni espacios |
| Cuenta AWS sin VPC default | `terraform plan` falla resolviendo `data.aws_vpc.default` | Avisa antes de crear una VPC manualmente — no es el flujo esperado del lab |
