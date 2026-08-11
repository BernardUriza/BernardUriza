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

### 4.5 🔴 ESCANEO ANTI-FUGA — OBLIGATORIO, ANTES DE STAGEAR

**Este repo es PÚBLICO y ya se filtró una vez.** El 2026-08-11 se encontró que 18
archivos publicaban, bajo el nombre de Bernard: su correo de trabajo, su usuario de
IAM de AWS, un nombre de bucket S3, dos clusters de ECS, el slug del workspace de
Plane de su empleador, los hosts de staging y producción, seis repos privados y su
handle de GitHub del trabajo. No fue malicia: `/sync-commands` subió sus commands
locales tal cual, y esa es la ruta que este paso cierra.

La denylist **vive fuera de todo repo**, en `~/.secrets/employer-denylist.txt`. Eso es
a propósito: una lista de nombres de empleadores escrita *dentro* de este archivo sería
ella misma la fuga — publicaría de golpe a los cuatro. Este archivo nunca los nombra.

```bash
test -f ~/.secrets/employer-denylist.txt || { echo "FALTA la denylist — PARAR"; exit 1; }
grep -rinE -f <(grep -v '^#' ~/.secrets/employer-denylist.txt) claude-commands/ claude-skills/ \
  | grep -v 'register-rule/secrets\.md'   # ese archivo DOCUMENTA formas de token a propósito
```

**Si devuelve CUALQUIER cosa, PARAR.** Por cada hallazgo, decidir con esta regla:

- **¿El command sólo FUNCIONA contra infra privada de un empleador?** (queries con
  `--owner=<org>`, clusters de ECS, slugs de workspace, correos de trabajo, usuarios
  de IAM) → **no se publica.** Se agrega a `.gitignore` y se saca del índice con
  `git rm --cached`. **NO se borra del disco**: los symlinks de `~/.claude` lo siguen
  viendo y el command sigue sirviendo localmente.
- **¿Sólo lo MENCIONA como ejemplo?** → se redacta con marcadores (`<ORG>`,
  `<gen-backend>`, `<org>.github.io`) y sí se publica.

El bloque de `.gitignore` con los 12 commands ya excluidos trae la explicación; no
quitar esas líneas.

**Costo aceptado:** esos 12 no se sincronizan entre máquinas. Es el precio correcto —
la infraestructura de un empleador no vive en un repo público. Si algún día hace falta
sincronizarlos, el destino tiene que ser un repo PRIVADO, nunca éste.

### 5. Stage SOLO commands + skills + .gitignore (no la basura)

```bash
git add claude-commands/ claude-skills/ .gitignore
git status --short   # verificar el closure — que no se cuele basura
```

`git add` respeta `.gitignore`, así que los commands excluidos no se re-agregan solos.
Aun así, releer el `git diff --cached --name-status` y confirmar que ninguno de los 12
aparece.

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
- **El paso 4.5 (escaneo anti-fuga) NO es opcional y no se salta "porque el cambio es
  chico".** Es el único paso que impide republicar infraestructura de un empleador. La
  fuga del 2026-08-11 existió justamente porque esta regla estaba escrita como consejo
  ("verificar que no hardcodea…") en vez de como un comando que corre y bloquea.
- Antes de pushear una skill/command NUEVO: verificar que no hardcodea secrets/tokens/URLs
  privadas — el repo es PÚBLICO (Art. 8). Los valores van por env var, nunca en el archivo.
- **Nombres de empleador, hosts, buckets, clusters, slugs de workspace, correos de
  trabajo y usuarios de IAM cuentan como datos privados**, no sólo los tokens. Un token
  se rota; el mapa de la infraestructura de alguien más, no.
