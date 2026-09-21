# Clientes SQL para conectarte a RDS

Este laboratorio no incluye una aplicación — te conectas directamente a
la instancia RDS con un cliente SQL. Este documento cubre qué opciones
hay, cómo instalarlas, y cómo dejar `psql` disponible en tu terminal
(`PATH`) para no repetir la ruta completa cada vez.

Para los comandos de conexión y las queries del laboratorio, ver
[conexion_rds.md](conexion_rds.md) (con `psql`) o
[pgadmin.md](pgadmin.md) (con pgAdmin, interfaz visual).

---

## 1. Opciones de cliente

| Cliente | Tipo | Cuándo usarlo |
|---|---|---|
| `psql` | Línea de comandos | Viene con la instalación de PostgreSQL. Rápido para queries puntuales, scripts, o cuando ya estás en la terminal. |
| pgAdmin | GUI | Viene con la instalación de PostgreSQL en Windows. Útil para explorar tablas visualmente sin escribir SQL. |
| DBeaver | GUI | Cliente universal (soporta Postgres, MySQL, etc.), gratis, multiplataforma. |
| Azure Data Studio | GUI | Alternativa de Microsoft, con soporte de extensiones para Postgres. |

No necesitas instalar los cuatro — con `psql` alcanza para todo lo que
pide el laboratorio. El resto son alternativas si prefieres una interfaz
visual.

---

## 2. Verificar si ya tienes alguno instalado

Antes de instalar nada, revisa si ya está en tu equipo:

**Git Bash:**

```bash
command -v psql
ls "/c/Program Files" | grep -iE "dbeaver|postgres|pgadmin"
ls "$LOCALAPPDATA/Programs" | grep -iE "dbeaver|azure data studio"
ls "$APPDATA" | grep -iE "pgadmin"
```

Si `psql` aparece en la primera línea, ya está instalado y solo falta
añadirlo al `PATH` (sección 4). Si no aparece nada, instala uno de los
siguientes.

---

## 3. Instalación

### Opción A — PostgreSQL (incluye `psql` + pgAdmin)

Descarga el instalador desde
[postgresql.org/download/windows](https://www.postgresql.org/download/windows/)
(usa el instalador de EDB). Durante la instalación:

- No necesitas correr un servidor PostgreSQL local — el laboratorio se
  conecta a la instancia RDS en AWS, no a una base local. Puedes
  desmarcar "Stack Builder" al final.
- Elige los componentes "Command Line Tools" (trae `psql`) y "pgAdmin 4"
  si quieres ambos.

Por defecto se instala en `C:\Program Files\PostgreSQL\<versión>\`.

### Opción B — DBeaver

Descarga desde [dbeaver.io](https://dbeaver.io/) (Community Edition,
gratis) e instala con el asistente. No requiere configuración de `PATH`
— se abre como cualquier aplicación de escritorio.

### Opción C — Azure Data Studio

Descarga desde
[Microsoft](https://learn.microsoft.com/en-us/azure-data-studio/download-azure-data-studio).
Requiere instalar la extensión "PostgreSQL" desde el marketplace interno
una vez abierto.

---

## 4. Añadir `psql` al `PATH` (Git Bash)

Si instalaste PostgreSQL pero `psql` no responde en tu terminal
(`command not found`), es porque el instalador no lo agrega
automáticamente al `PATH` de Git Bash (solo al de `cmd`/PowerShell en
algunos casos).

### 4.1. Encuentra la ruta del binario

Normalmente es:

```
C:\Program Files\PostgreSQL\<versión>\bin\psql.exe
```

Verifica la versión exacta:

```bash
ls "/c/Program Files/PostgreSQL/"
```

### 4.2. Agrega la ruta a `~/.bashrc`

Edita `~/.bashrc` (tu perfil de Git Bash) y agrega, ajustando la versión:

```bash
export PATH="/c/Program Files/PostgreSQL/18/bin:$PATH"
```

### 4.3. Recarga el perfil

```bash
source ~/.bashrc
```

### 4.4. Verifica

```bash
command -v psql
psql --version
```

Deberías ver la ruta del binario y la versión instalada. Esta
configuración persiste — no necesitas repetirla en futuras sesiones de
Git Bash, solo en terminales nuevas que abras después de este cambio (o
tras `source ~/.bashrc` en la actual).

---

## 5. Problemas comunes

- **`psql` funciona en PowerShell pero no en Git Bash (o viceversa)** —
  cada shell tiene su propio `PATH`; agregarlo en `~/.bashrc` solo
  afecta a Git Bash. Para PowerShell, agrega la carpeta `bin` a la
  variable de entorno `Path` del sistema o del usuario (Panel de
  Control → Variables de entorno).
- **Instalaste una versión nueva de PostgreSQL y `psql --version` sigue
  mostrando la anterior** — puede haber más de una ruta de PostgreSQL en
  el `PATH`; revisa `~/.bashrc` por líneas duplicadas o el orden en que
  se agregan (la primera coincidencia en `PATH` gana).
- **No quieres tocar el `PATH`** — puedes seguir usando la ruta completa
  cada vez: `"/c/Program Files/PostgreSQL/18/bin/psql.exe" "..."`. Es más
  largo de escribir pero funciona igual sin modificar tu perfil de
  shell.
