# /purge-github — Limpieza de rama, commit y evaluación de merge a main

ARGUMENTS: opcional — si se pasa un mensaje de commit, lo usa; si no, lo genera automáticamente.

## Context

El worktree acumula basura entre sesiones: screenshots de debug, archivos de estado de sesión,
artefactos temporales que no deben llegar a GitHub. Este comando los borra, commitea el trabajo
real, y evalúa si la rama puede ir a main — o lo hace de una vez si los criterios se cumplen.
También propone borrar ramas remotas sucias.

Corre sin confirmación para todo lo que es reversible o claramente basura. Pide confirmación
solo para acciones irreversibles (force push, borrar main, merge sin CI).

## Instructions

### Phase 0: Diagnóstico completo

Correr en paralelo:
```bash
git status --short             # untracked + modificados
git log --oneline main..HEAD   # commits adelante de main
git branch -a                  # ramas locales y remotas
```

Clasificar lo que hay en el worktree en 3 cubetas:
- **BASURA** — borrar sin preguntar (ver tabla al final)
- **TRABAJO REAL** — commitear
- **AMBIGUO** — preguntar una sola vez antes de actuar

### Phase 1: Purge de basura

Borrar automáticamente cualquier untracked que matchee estos patrones:

**Siempre basura (borrar sin confirmar):**
- `*.jpeg`, `*.jpg`, `*.png` en directorios de apps o raíz que no sean assets/public/images
- `SESSION_STATE.md`, `HANDOFF.md`
- `*.tmp`, `*.log` (fuera de node_modules)
- Archivos que matcheen el `.gitignore` existente y están sin trackear

**Nunca borrar sin confirmar:**
- Archivos `.ts`, `.tsx`, `.py`, `.js`, `.css`, `.html`, `.json` con código
- Documentos `.md` que no sean SESSION_STATE.md / HANDOFF.md
- Directorios con múltiples archivos (leer antes de actuar)

```bash
# Ejecución: rm -f <archivo> uno por uno (NUNCA rm -rf)
# Reportar: "Borrados: N archivos (X KB)"
```

### Phase 2: Commit del trabajo real

Si quedan cambios sin commitear (tracked modified + untracked no-basura):

1. Agrupar por área (fi-glass, fi-runner, og118, backend, .claude/, etc.)
2. Generar un mensaje de commit descriptivo basado en los diffs
3. `git add` de cada grupo por separado si mezclan áreas distintas, o uno solo si son coherentes
4. `git commit` con el mensaje generado (usar Conventional Commits)
5. Reportar: commits creados, archivos incluidos

Si ARGUMENTS contiene un mensaje de commit, usarlo en lugar del generado.

### Phase 3: Evaluación main-readiness

Correr diagnóstico en paralelo:

```bash
# Tests (detectar el runner del proyecto)
pnpm test 2>&1 | tail -5      # o `make test` si no hay pnpm

# TypeScript
pnpm exec tsc --noEmit 2>&1 | tail -10

# Commits adelante de main
git log --oneline main..HEAD | wc -l

# PR existente
gh pr list --head $(git branch --show-current) 2>/dev/null

# CI status (si hay PR)
gh pr checks 2>/dev/null | tail -5
```

Generar un scorecard:

| Criterio | Estado | Detalle |
|----------|--------|---------|
| Tests | ✅/❌ | N passed / M failed |
| TypeScript | ✅/❌ | 0 errores / N errores |
| Worktree limpio | ✅/❌ | clean / N modificados |
| Commits coherentes | ✅/⚠️ | N commits (feature único / mezcla) |
| PR abierta | ✅/—/❌ | URL / sin PR / CI falla |

**Veredicto posible:**

- 🟢 **LISTO PARA MAIN** — todos los criterios verdes → crear PR o mergear si hay aprobación
- 🟡 **CASI LISTO** — 1-2 criterios amarillos → reportar qué falta exactamente
- 🔴 **NO LISTO** — tests rojos / TS errors → no tocar main, reportar bloqueadores

### Phase 4: Merge a main (solo si veredicto = LISTO)

```bash
# Si no hay PR: crear una
gh pr create --title "<título del feature>" --body "<scorecard como resumen>"

# Si hay PR aprobada con CI verde:
gh pr merge --squash --auto
```

**SIEMPRE pedir confirmación antes de:**
- `git push --force` o `--force-with-lease`
- Merge directo a main sin PR
- `gh pr merge` en ramas con branch protection

### Phase 5: Limpieza de ramas obsoletas

```bash
# Ramas remotas ya mergeadas a main:
git branch -r --merged main | grep -v 'main\|HEAD\|dev\|staging' | sed 's/origin\///'

# Ramas locales sin remote tracking:
git branch -vv | grep ': gone]' | awk '{print $1}'
```

Para cada rama candidata:
- Mostrar: nombre + fecha último commit + autor
- NO tocar: main, dev, staging, nunca
- Pedir UNA sola confirmación global: "¿Borrar estas N ramas? [lista]"
- Ejecutar: `git push origin --delete <rama>` + `git branch -d <rama>`

## Rules

- **No `rm -rf` nunca** — solo `rm -f` archivo por archivo
- **No force push sin confirmación explícita** — siempre preguntar
- **No tocar main directamente** — solo vía PR o con confirmación explícita del usuario
- **No borrar código fuente sin confirmar** — la basura son screenshots/sessions, no `.ts`/`.py`
- **Reportar honestamente** — si los tests fallan, decirlo; no declarar "listo" con rojo
- **Un commit = una área coherente** — no mezclar fi-glass con backend en el mismo commit
- **Preservar historial** — no squash sin permiso del usuario
- **Verificar antes de borrar ramas** — confirmar que está mergeada en main primero

## Patrones de basura (referencia rápida)

| Patrón | Ejemplo | Borrar? |
|--------|---------|---------|
| `*.jpeg / *.jpg` en apps/ | `.figlass10-draft.jpeg` | ✅ Siempre |
| `*.png` en apps/ raíz de app | `.smoke-test.png` | ✅ Siempre |
| `SESSION_STATE.md` | `.claude/SESSION_STATE.md` | ✅ Siempre |
| `HANDOFF.md` | `HANDOFF.md` raíz | ✅ Siempre |
| `*.png` en assets/public/ | `public/logo.png` | ❌ Nunca |
| `.md` con reglas | `.claude/rules/foo.md` | ❌ Nunca |
| `.md` técnico | `BOOTSTRAP.md`, `CHAT_STT_TODO.md` | ❌ Nunca |
| Directorios de docs/ | `docs/fi-glass-planning/` | ❌ Nunca sin leer |
| `.auritypng` en aurity raíz | `.aurity-local-chat-widget.png` | ✅ Siempre |
