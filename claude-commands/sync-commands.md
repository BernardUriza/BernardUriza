# /sync-commands — Push local commands + skills up to the profile repo

Sincroniza tus slash commands Y skills locales hacia GitHub. A diferencia de
`/sync-rules` (que COPIA entre dos repos distintos), aquí `~/.claude/commands` y
`~/.claude/skills` son **symlinks** a este repo (`BernardUriza/BernardUriza`), así
que "sync" = commit + push directo. Editaste un command/skill en cualquier proyecto →
este comando lo respalda en GitHub y lo deja disponible en todas tus máquinas.

> Dirección inversa (instalar/actualizar en una máquina nueva): ver `INSTALL.md`
> (`git clone` + symlinks + `git pull`). Este comando es el lado de SUBIDA.

ARGUMENTS: opcional — mensaje de commit. Si está vacío, se autogenera listando los
archivos cambiados.

## Instructions

### 1. Resolver el repo (canónico, vía el symlink — nunca asumir el path)

```bash
REPO=$(readlink -f ~/.claude/commands | xargs dirname)   # .../BernardUriza
cd "$REPO"
```

Verificar que es el repo correcto: `git remote get-url origin` debe contener
`BernardUriza/BernardUriza`. Si no, PARAR y reportar (los symlinks pueden apuntar a
otro lado en una máquina distinta).

### 2. Asegurar el .gitignore (basura macOS fuera — root fix)

Si `.gitignore` no existe o no cubre la basura, crearlo/actualizarlo:

```
.DS_Store
Icon?
*.swp
```

Nunca commitear `.DS_Store` ni el archivo `Icon^M` de macOS.

### 3. Pull --rebase primero (evitar conflictos con otra máquina)

```bash
git pull --rebase origin main
```

Si hay conflicto, PARAR y reportar — no forzar.

### 4. Diff antes de commitear (reportar qué cambió)

```bash
git status --short claude-commands/ claude-skills/
```

Reportar una tabla: archivo | estado (nuevo / modificado / borrado). Si NO hay cambios
en `claude-commands/` ni `claude-skills/`, reportar "Todo en sync" y terminar.

### 5. Stage SOLO commands + skills + .gitignore (no la basura)

```bash
git add claude-commands/ claude-skills/ .gitignore
git status --short   # verificar el closure — que no se cuele basura
```

### 6. Commit + push

```bash
git commit -m "chore(commands): sync ${ARGUMENTS:-<lista autogenerada de archivos>}

Co-Authored-By: Claude <noreply@anthropic.com>"
git push origin main
```

### 7. Reportar

```
Sincronizado a BernardUriza/BernardUriza (commit <hash>):
  Commands: <N nuevos/modificados>
  Skills:   <M nuevos/modificados>
Pusheado a origin/main. Disponible en todas tus máquinas tras `git pull`.
```

## Rules

- El repo (vía symlink) es SIEMPRE el source of truth — esto es una subida one-way,
  no una copia entre ubicaciones (eso es `/sync-rules`, otro flujo).
- Resolver el repo por el symlink (`readlink`), nunca hardcodear el path absoluto.
- `git pull --rebase` ANTES del push — otra máquina pudo haber pusheado.
- Stagear SOLO `claude-commands/` + `claude-skills/` + `.gitignore`. Nunca la basura
  macOS, nunca archivos fuera de esos dirs.
- Siempre commit+push — un cambio local-only es invisible en GitHub y en otras máquinas.
- Si `git pull --rebase` da conflicto: PARAR y reportar, nunca forzar (no perder trabajo
  de otra máquina — Art. 5).
- Antes de pushear una skill/command NUEVO: verificar que no hardcodea secrets/tokens/URLs
  privadas — el repo es PÚBLICO (Art. 8). Los valores van por env var, nunca en el archivo.
