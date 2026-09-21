# Consola de AWS vs. Terraform — qué causa diff de state

Este laboratorio gestiona la tabla `package_tracking` con Terraform
([infra/modules/dynamodb/main.tf](../../infra/modules/dynamodb/main.tf)).
La consola de AWS y la AWS CLI permiten hacer casi cualquier cosa
directamente sobre la tabla, pero **no todo lo que permiten es seguro de
hacer** si la tabla está gestionada por Terraform — algunas acciones
generan un desfase entre lo que Terraform cree que existe (su
`terraform.tfstate`) y lo que realmente existe en AWS.

Esto se conoce como *drift*: cuando el estado real en AWS diverge del
estado que Terraform tiene registrado. El siguiente `terraform plan`
detecta la diferencia e intenta "corregirla" — a veces revirtiendo tu
cambio manual, a veces con consecuencias más serias (ver sección 2).

---

## 1. Operaciones seguras — no tocan el schema, no generan diff

Estas operaciones actúan sobre los **datos** (ítems) de la tabla, no
sobre su definición. Terraform no rastrea el contenido de una tabla, así
que no le importan y **nunca aparecen en un `terraform plan`**:

| Operación | CLI | Consola |
|---|---|---|
| Insertar/actualizar un ítem | `put-item`, `batch-write-item` | Explore table items → Create item |
| Leer un ítem por clave | `get-item` | Explore table items → buscar por clave |
| Query (filtro por partition key) | `query` | Explore table items → Query |
| Scan (recorrer toda la tabla) | `scan` | Explore table items → Scan |
| Borrar un ítem | `delete-item` | Explore table items → seleccionar → Delete |
| PartiQL `SELECT`/`INSERT`/`UPDATE`/`DELETE` sobre ítems | `execute-statement` | PartiQL editor |

Puedes usar cualquiera de estas libremente, desde la consola o CLI, sin
preocuparte por Terraform. Es exactamente lo que hacen
`scripts/load_dynamodb.py` y los ejercicios de
[consultas_dynamodb.md](consultas_dynamodb.md).

---

## 2. Operaciones que SÍ generan diff — tocan el schema

Estas cambian la **definición** de la tabla (su schema), que es
justamente lo que `aws_dynamodb_table` en Terraform declara y controla.
Modificarlas desde la consola/CLI hace que Terraform detecte drift en el
próximo `plan`.

| Cambio | ¿Se puede hacer desde consola/CLI? | Qué pasa con Terraform |
|---|---|---|
| Agregar/quitar un **GSI** | Sí, en caliente (`UpdateTable`) | `terraform plan` detecta el GSI nuevo como "recurso a destruir" (porque no está en tu `.tf`) — si aplicas ese plan, **Terraform borra el GSI que creaste a mano**. |
| Agregar/quitar un **LSI** | No — un LSI solo se define al crear la tabla, es inmutable | N/A — no aplica, ni siquiera la consola lo permite después de creada |
| Cambiar `billing_mode` (PAY_PER_REQUEST ↔ PROVISIONED) | Sí | `terraform plan` revierte al valor declarado en el `.tf` en el siguiente apply |
| Cambiar `hash_key`/`range_key` | No, ni siquiera manualmente — requiere recrear la tabla | Cambiarlo en el `.tf` hace que Terraform proponga destruir y recrear la tabla completa (pérdida de todos los datos) |
| Cambiar tags | Sí | `terraform plan` revierte al valor declarado, o los marca para actualizar |
| Eliminar la tabla completa | Sí (con confirmación) | El siguiente `plan`/`apply` de Terraform intenta **recrearla desde cero** — pierdes todos los datos igual que si la hubieras destruido con `terraform destroy` |

**La regla práctica:** si la acción aparece en la definición del recurso
`aws_dynamodb_table` en [infra/modules/dynamodb/main.tf](../../infra/modules/dynamodb/main.tf)
(`hash_key`, `range_key`, `attribute`, `billing_mode`, `tags`, o un
futuro `global_secondary_index`/`local_secondary_index`), tocarlo desde
la consola genera drift. Si no aparece ahí (es decir, es un ítem/fila),
no genera drift.

---

## 3. Qué hacer si necesitas un GSI (Reto 3 del laboratorio)

El GSI para consultar por `city` es intencionalmente el ejercicio del
**Reto 3** (ver [consultas_dynamodb.md](consultas_dynamodb.md), sección
"Consulta 3"). La forma correcta de agregarlo es:

1. Editar `infra/modules/dynamodb/main.tf` y agregar un bloque
   `global_secondary_index` al recurso `aws_dynamodb_table`, más el
   `attribute` correspondiente para la nueva clave.
2. Correr `terraform plan` desde `infra/` — deberías ver un *update
   in-place* de la tabla (agregar el GSI), no una destrucción.
3. `terraform apply`.

**No lo crees primero desde la consola "para probar" y luego lo repliques
en Terraform** — si ya existe en AWS cuando corres `terraform plan`,
Terraform lo verá como un recurso no gestionado, y dependiendo de cómo
declares el bloque, puede intentar recrearlo (interrupción momentánea del
GSI) en vez de simplemente adoptarlo. Si ya lo creaste manualmente y
quieres que Terraform lo adopte sin recrearlo, usa `terraform import`
(mismo mecanismo que se usó para el log group de RDS — ver
[guia_ejecucion_lab_storage.md](../guia_ejecucion_lab_storage.md),
sección 3.2).

---

## 4. Cómo detectar si ya hay drift

Antes de cualquier `terraform apply`, corre:

```bash
terraform -chdir=infra plan
```

Si el plan muestra cambios que **tú no hiciste** en el código
Terraform (por ejemplo, "destroy" sobre un GSI, o un cambio de tag que
no editaste), es señal de que alguien —tú mismo u otra persona con
acceso a la cuenta— modificó el recurso desde la consola o CLI
directamente. Revisa el plan con cuidado antes de aplicar: en drift de
GSI o schema, aplicar sin revisar puede destruir datos o índices que sí
querías conservar.
