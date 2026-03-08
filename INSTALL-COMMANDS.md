# Claude Code Commands — Global Installer

> **Para Claude Code**: Ejecuta estas instrucciones cuando Bernard (u otro usuario) pida instalar los commands globales.
> **Para humanos**: Pega este archivo en Claude Code o dile "instala los commands de mi profile repo".

## Que hace

Crea un symlink de `~/.claude/commands/` apuntando a la carpeta `claude-commands/` de este repo. Resultado: todos los slash commands quedan disponibles globalmente en cualquier proyecto.

## Instrucciones para Claude Code

### 1. Detectar plataforma y paths

```
SOURCE = <ruta absoluta de este repo>/claude-commands
TARGET = ~/.claude/commands
```

- **Mac/Linux**: `~` es `$HOME`
- **Windows**: `~` es `%USERPROFILE%` (tipicamente `C:\Users\<username>`)

### 2. Verificar que SOURCE existe

Si `claude-commands/` no existe en este repo, PARAR y reportar error.

### 3. Respaldar TARGET si ya existe como directorio (no symlink)

Si `~/.claude/commands/` existe y es un directorio real (no symlink):
- Renombrarlo a `~/.claude/commands-backup-<fecha>`
- Reportar al usuario que se hizo backup

Si ya es un symlink apuntando al lugar correcto, reportar "ya instalado" y terminar.

### 4. Crear symlink

**Mac/Linux:**
```bash
mkdir -p ~/.claude
ln -s "<SOURCE>" "<TARGET>"
```

**Windows (PowerShell como admin):**
```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude" | Out-Null
New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.claude\commands" -Target "<SOURCE>"
```

**Windows (cmd como admin):**
```cmd
mkdir "%USERPROFILE%\.claude" 2>nul
mklink /D "%USERPROFILE%\.claude\commands" "<SOURCE>"
```

> En Windows, crear symlinks requiere permisos de administrador o Developer Mode activado.

### 5. Verificar

Listar los archivos en TARGET para confirmar que el symlink funciona. Reportar la lista de commands disponibles.

### 6. Reportar al usuario

```
Instalado: ~/.claude/commands/ -> <SOURCE>
Commands disponibles: /build-check, /cruel-critic, /css-to-tailwind, ...

Para actualizar en el futuro:
  cd <este-repo> && git pull

Para instalar en otra maquina:
  git clone https://github.com/BernardUriza/BernardUriza.git
  cd BernardUriza
  # Pedirle a Claude Code: "instala los commands globales"
```

## Para humanos (manual)

### Mac/Linux
```bash
git clone https://github.com/BernardUriza/BernardUriza.git ~/Documents/BernardUriza
ln -sf ~/Documents/BernardUriza/claude-commands ~/.claude/commands
```

### Windows (PowerShell como admin)
```powershell
git clone https://github.com/BernardUriza/BernardUriza.git "$env:USERPROFILE\Documents\BernardUriza"
New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.claude\commands" -Target "$env:USERPROFILE\Documents\BernardUriza\claude-commands"
```

### Actualizar
```bash
cd ~/Documents/BernardUriza && git pull
```
El symlink ya apunta ahi — los cambios se reflejan inmediatamente en todos los proyectos.
