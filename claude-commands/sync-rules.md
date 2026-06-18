# /sync-rules — Push local engineering-playbook rules up to GitHub

Sincroniza tus rules del **engineering-playbook** hacia GitHub. Es el counterpart
simétrico de `/sync-commands`: tus rules viven en `~/Documents/engineering-playbook/rules/`
(repo `BernardUriza/engineering-playbook`), expuestas globalmente vía el symlink
`~/.claude/rules/playbook`. Editaste una rule en cualquier proyecto → este comando la
respalda en GitHub y la deja disponible en todas tus máquinas.

> Como `~/.claude/rules/playbook` es un symlink al repo, editar una rule en cualquier
> lado edita el repo directo. "Sync" = commit + push, no una copia entre ubicaciones.

ARGUMENTS: opcional — mensaje de commit. Si está vacío, se autogenera listando los
archivos cambiados.

## Instructions

### 1. Resolver el repo (canónico, vía el symlink — nunca hardcodear el path)

```bash
REPO=$(readlink -f ~/.claude/rules/playbook | xargs dirname)   # .../engineering-playbook
cd "$REPO"
BRANCH=$(git branch --show-current)                            # es master, no main — resolver dinámico
```

Verificar que es el repo correcto: `git remote get-url origin` debe contener
`BernardUriza/engineering-playbook`. Si no, PARAR y reportar.

### 2. Asegurar el .gitignore (basura macOS fuera)

Si `.gitignore` no cubre la basura, añadir:

```
.DS_Store
Icon?
*.swp
```

### 3. Pull --rebase primero (evitar conflictos con otra máquina)

```bash
git pull --rebase origin "$BRANCH"
```

Si hay conflicto, PARAR y reportar — no forzar (no perder trabajo de otra máquina, Art. 5).

### 4. Diff antes de commitear

```bash
git status --short rules/
```

Reportar una tabla: archivo | estado (nuevo / modificado / borrado). Si NO hay cambios
en `rules/`, reportar "Todo en sync" y terminar.

### 5. Stage SOLO rules + .gitignore (no la basura)

```bash
git add rules/ .gitignore
git status --short   # verificar el closure
```

### 6. Commit + push

```bash
git commit -m "chore(rules): sync ${ARGUMENTS:-<lista autogenerada>}

Co-Authored-By: Claude <noreply@anthropic.com>"
git push origin "$BRANCH"
```

### 7. Reportar

```
Sincronizado a BernardUriza/engineering-playbook (commit <hash>, branch <branch>):
  Rules: <N nuevas/modificadas>
Pusheado. Disponible en todas tus máquinas tras `git pull`.
```

## Rules

- El repo (vía symlink `~/.claude/rules/playbook`) es SIEMPRE el source of truth —
  subida one-way, no una copia entre ubicaciones.
- Resolver repo Y branch dinámicamente (`readlink` + `git branch --show-current`) —
  nunca hardcodear el path ni asumir `main` (el playbook está en `master`).
- `git pull --rebase` ANTES del push — otra máquina pudo haber pusheado.
- Stagear SOLO `rules/` + `.gitignore`. Nunca basura macOS, nunca archivos fuera de ahí.
- Si el rebase da conflicto: PARAR y reportar, nunca forzar (Art. 5).
- Siempre commit+push — un cambio local-only es invisible en GitHub y en otras máquinas.

> Hermano de `/sync-commands` (sube commands + skills del repo de profile). Este sube
> las rules del playbook. Ver `INSTALL.md` en el repo de profile para el lado de bajada.
