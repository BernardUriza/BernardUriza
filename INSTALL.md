# Claude Code Commands + Skills — Installer & Sync

> **Para Claude Code**: ejecuta estas instrucciones cuando Bernard (u otro usuario)
> pida instalar/sincronizar sus commands o skills globales.
> **Para humanos**: pega este archivo en Claude Code o dile "instala mis commands y
> skills del profile repo".

## Qué hace

Este repo (`BernardUriza/BernardUriza`) es el **source of truth** de tus slash
commands Y tus skills de Claude Code. La instalación crea DOS symlinks:

| Symlink | Apunta a | Contenido |
|---|---|---|
| `~/.claude/commands` | `<repo>/claude-commands/` | slash commands (`.md`) |
| `~/.claude/skills`   | `<repo>/claude-skills/`  | skills (carpetas con `SKILL.md`) |

Resultado: todos tus commands y skills quedan disponibles globalmente en cualquier
proyecto, **versionados en git** (respaldados, sincronizables entre máquinas).

## Direcciones del sync

- **Bajada (instalar / actualizar)**: `git clone` + symlinks + `git pull`. Esta sección.
- **Subida (respaldar cambios locales)**: editaste un command/skill → `/sync-commands`
  (commit + push). Como son symlinks, editar en cualquier proyecto edita el repo directo.

## Instrucciones para Claude Code (instalar)

### 1. Detectar plataforma y paths

```
SOURCE_CMDS   = <ruta absoluta de este repo>/claude-commands
SOURCE_SKILLS = <ruta absoluta de este repo>/claude-skills
TARGET_CMDS   = ~/.claude/commands
TARGET_SKILLS = ~/.claude/skills
```

- **Mac/Linux**: `~` es `$HOME`
- **Windows**: `~` es `%USERPROFILE%` (típicamente `C:\Users\<username>`)

### 2. Verificar que las SOURCE existen

Si `claude-commands/` o `claude-skills/` no existen en este repo, PARAR y reportar.

### 3. Respaldar cada TARGET si ya existe como directorio real (no symlink)

Para cada target (`commands`, `skills`): si existe y es un directorio real (no symlink):
- Renombrarlo a `~/.claude/<nombre>-backup-<fecha>`
- Reportar al usuario que se hizo backup

Si ya es un symlink al lugar correcto, reportar "ya instalado" y saltar ese target.

### 4. Crear los symlinks

**Mac/Linux:**
```bash
mkdir -p ~/.claude
ln -sf "<SOURCE_CMDS>"   "<TARGET_CMDS>"
ln -sf "<SOURCE_SKILLS>" "<TARGET_SKILLS>"
```

**Windows (PowerShell como admin):**
```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude" | Out-Null
New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.claude\commands" -Target "<SOURCE_CMDS>"
New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.claude\skills"   -Target "<SOURCE_SKILLS>"
```

> En Windows, crear symlinks requiere permisos de administrador o Developer Mode activado.

### 5. Verificar

Listar `~/.claude/commands` y `~/.claude/skills` para confirmar que los symlinks
funcionan. Reportar la lista de commands y skills disponibles.

### 6. Reportar al usuario

```
Instalado:
  ~/.claude/commands -> <SOURCE_CMDS>   (N commands)
  ~/.claude/skills   -> <SOURCE_SKILLS> (M skills)

Para actualizar (bajar cambios de otra máquina):
  cd <este-repo> && git pull

Para respaldar cambios locales (subir):
  /sync-commands   (o: git add claude-commands/ claude-skills/ && git commit && git push)

Para instalar en otra máquina:
  git clone https://github.com/BernardUriza/BernardUriza.git
  cd BernardUriza
  # Pedirle a Claude Code: "instala mis commands y skills globales"
```

## One-liner (Mac/Linux) — instalar en una PC nueva

```bash
curl -fsSL https://raw.githubusercontent.com/BernardUriza/BernardUriza/main/install.sh | bash
```

`install.sh` es idempotente: clona (o hace `git pull` si ya existe), respalda
cualquier `~/.claude/commands` o `~/.claude/skills` que sea un directorio real, y
deja los symlinks apuntando al repo. Re-correrlo en una máquina ya instalada solo
actualiza y reporta "ya enlazado". Ruta de clone configurable con
`CLAUDE_PROFILE_DIR=/otra/ruta`.

## Para humanos (manual)

### Mac/Linux
```bash
git clone https://github.com/BernardUriza/BernardUriza.git ~/Documents/BernardUriza
ln -sf ~/Documents/BernardUriza/claude-commands ~/.claude/commands
ln -sf ~/Documents/BernardUriza/claude-skills   ~/.claude/skills
```

### Windows (PowerShell como admin)
```powershell
git clone https://github.com/BernardUriza/BernardUriza.git "$env:USERPROFILE\Documents\BernardUriza"
New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.claude\commands" -Target "$env:USERPROFILE\Documents\BernardUriza\claude-commands"
New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.claude\skills"   -Target "$env:USERPROFILE\Documents\BernardUriza\claude-skills"
```

### Actualizar (bajar)
```bash
cd ~/Documents/BernardUriza && git pull
```
Los symlinks ya apuntan ahí — los cambios se reflejan inmediatamente en todos los proyectos.

### Respaldar (subir)
```bash
cd ~/Documents/BernardUriza
git add claude-commands/ claude-skills/ .gitignore
git commit -m "chore: sync commands + skills" && git push
```
O simplemente `/sync-commands` dentro de Claude Code.

## Nota de seguridad

Este repo es **PÚBLICO**. Ningún command ni skill debe hardcodear secrets, tokens ni
URLs privadas — los valores van por variable de entorno (`.env`, `~/.secrets/`), nunca
en el archivo `.md`. `/sync-commands` lo verifica antes de pushear.
