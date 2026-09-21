# ADR 0001: Infraestructura modular para el laboratorio de Storage (S3, RDS, DynamoDB, Athena)

Status: accepted
Date: 2026-09-20

## Context

El laboratorio de Sesión 03 (`docs/laboratorio_sesion_03_storage.md`) exige
desplegar cuatro servicios de storage (S3 data lake, RDS Postgres,
DynamoDB, Athena/Glue) que hoy no existen en `infra/`. El único recurso
Terraform actual es un bucket de artifacts genérico para packaging de
jobs Glue, declarado como un único `main.tf` plano.

Añadir cuatro servicios nuevos directamente en ese `main.tf` plano
mezclaría el propósito original del stack (soporte de ejecución de jobs)
con el propósito nuevo (recursos de un laboratorio educativo), dificultando
razonar sobre cada servicio de forma aislada — algo relevante en un
contexto donde el alumno debe poder leer y explicar cada recurso
individualmente (sección 15, "Parte de deconstrucción", del documento).

## Decision

Reestructurar `infra/` a un layout de root + módulos
(`infra/modules/<servicio>/`), con un módulo por servicio: `s3-artifacts`
(migración sin cambios funcionales del bucket actual), `s3-datalake`,
`rds`, `dynamodb`, `athena`, e `iam` (mínimo, solo para roles sin home
natural en otro módulo).

Detalle completo de cada módulo en
`docs/superpowers/specs/2026-09-20-lab-storage-infra-design.md`.

## Consequences

- Cada módulo puede desplegarse, leerse y explicarse de forma aislada,
  alineado con el objetivo pedagógico de "revisar el Terraform recurso por
  recurso" del documento.
- Se mantiene un único Terraform state (root module único que instancia
  los módulos hijos) — no se introduce complejidad de múltiples stacks/
  backends para este alcance.
- RDS introduce el único recurso de costo fijo continuo del laboratorio;
  se documenta explícitamente en el spec y el README la necesidad de
  `terraform destroy` al finalizar.
- `publicly_accessible = true` en RDS es una excepción documentada a la
  política "security by default" del AGENTS.md, mitigada con un security
  group restringido a la IP del alumno, y justificada por el objetivo
  didáctico de conexión directa sin bastion/SSM.
