# /brutal-advance — Avance brutal del checklist con enjambre de agentes

ARGUMENTS: $ARGUMENTS

## Contexto

Nacido de la sesión 2026-07-19 en discord-bot: 5 agentes Fable en paralelo
cerraron en una tarde lo que sesiones enteras dejaron tirado (95 tests nuevos,
un fix de producción, docs purgadas, CVEs revisados), y de paso cacharon al
checklist mintiendo en AMBAS direcciones. El patrón es repetible en cualquier
repo que tenga un checklist/roadmap vivo (HTML, backlog, README de fases).

El principio: **el checklist es la fuente del QUÉ, pero nunca de la VERDAD.**
Cada ítem se verifica contra el estado real antes de trabajarlo, y cada avance
regresa al checklist con receipts en el mismo turno.

`$ARGUMENTS` (opcional): scope hint — una sección del checklist, un área del
código, o un path a un checklist distinto al canónico del proyecto.

## Instructions

### Fase 0: Recon con desconfianza (NO trabajes todavía)

1. **Resuelve el checklist canónico** del proyecto: primero lo que digan
   `.claude/rules/workflow.md` / CLAUDE.md del repo; si nada lo nombra, busca
   `~/Desktop/*checklist*.html` y `.claude/backlog/README.md`. Léelo COMPLETO.
2. **Estado git en vivo**: `git status -sb`, `git log --oneline -8`,
   `git stash list`. El snapshot del arranque de sesión MIENTE — otra sesión
   pudo commitear hace 30 segundos.
3. **Detecta sesiones paralelas**: archivos modificados que no tocaste, commits
   nuevos mid-sesión, locks de build. Si hay WIP vivo ajeno, sus archivos son
   INTOCABLES (Art. 5) — trabaja superficies disjuntas.

### Fase 1: Auditoría del checklist — en AMBAS direcciones

Por cada ítem relevante al scope, verifica con comandos (grep/ls/test/az/gh),
nunca con la prosa del ítem:

- **Sin palomear pero YA HECHO**: tests que ya existen, gates ya levantados,
  prompts ya restaurados. Palomearlo con receipt es avance gratis.
- **Palomeado pero MENTIRA**: celebrado sin commit, "vivo como código" pero
  jamás cableado al flujo, verificado solo por proxy. Despalomearlo con receipt.

Reporta el resultado de la auditoría al usuario ANTES de repartir chamba.

### Fase 2: Selección de trabajo

Elige los ítems que cumplan TODOS:

1. **Estructuralmente pesados** — lo que las sesiones anteriores esquivaron
   por grandes, no lo cosmético.
2. **NO gateados al dueño** — jamás toques: decisiones de gasto/infra
   destructiva, secciones marcadas GATED, credenciales, lo explícitamente
   suyo. Esos se REPORTAN con el análisis listo, no se ejecutan.
3. **Paralelizables en archivos disjuntos** — si dos ítems tocan el mismo
   archivo, van al mismo worker o en secuencia.

### Fase 3: El enjambre

Lanza los agentes EN PARALELO (una sola tanda de llamadas). Contrato de cada
agente, sin excepciones:

- **Deliverable exacto**: qué archivos puede crear/editar (allowlist cerrada) y
  qué debe devolver en su reporte.
- **Contexto del repo**: arquitectura viva en 2 líneas, comando de test real
  (el interpreter del proyecto, no el del PATH), archivos de referencia de
  estilo a leer primero.
- **Verificación por mutación obligatoria**: romper temporalmente la lógica
  cubierta, confirmar rojo, revertir EXACTO, reportarlo. Un test que nunca se
  vio rojo no probó nada.
- **Bug hallado fuera de su scope → xfail(strict=True) + repro en el reporte**,
  nunca un fix fuera de su allowlist.
- **PROHIBIDO git add/commit** — la integración es del hilo principal.

### Fase 4: La costura delicada es TUYA

Mientras el enjambre corre, el hilo principal trabaja el ítem que toca el path
vivo de producción (el fix de comportamiento, la costura de delivery, el
recableo). Eso no se delega: exige el contexto completo de la sesión. Tu propio
trabajo también se verifica por mutación — y si tu mutación usa un script,
revisa DOS VECES que no lleve un `git checkout` suicida dentro.

### Fase 5: Integración

1. Suite COMPLETA con el interpreter del proyecto + lint. Verde total o no hay
   commit.
2. **Commits por superficie** (fix ≠ tests ≠ docs), version bump según la regla
   del repo, staging por paths EXACTOS — jamás `git add -A` con sesiones
   paralelas vivas. Lee `git diff --cached --name-status` antes de cada commit.
3. **Push inmediato**: `git fetch` + `git rev-list --count HEAD..origin/main`
   primero; rebase si hay commits ajenos. Trabajo sin pushear = trabajo
   invisible.

### Fase 6: El checklist se actualiza EN ESTE TURNO

Por cada avance y cada mentira detectada, edita el checklist:

- **Receipt, nunca prosa**: commit SHA + comando de verificación en el ítem.
- Palomea lo cerrado, corrige lo stale (ambas direcciones), actualiza el
  header de estado con la sesión.
- Un turno que avanza el roadmap sin tocar el checklist es un turno incompleto.

### Fase 7: Verificación en la superficie real

- Lo deployable se verifica en la superficie REAL (el canal, el navegador, el
  round-trip) — no en el proxy que puede mentir.
- Si el deploy tarda: arma el watch en background (CI→CD→deploy), repórtalo
  como **pendiente honesto**, y ejecuta el E2E cuando despierte. Jamás "quedó
  verificado" sin el receipt de la superficie.

## Reglas duras

1. **Receipts o no pasó.** Cada claim de avance lleva su comando/SHA.
2. **El checklist se audita antes de obedecerse.** Trabajar un ítem ya resuelto
   o confiar en un palomeo falso son el mismo error: creerle a la prosa.
3. **Lo gateado al dueño se reporta con análisis listo, jamás se ejecuta.**
4. **Archivos disjuntos entre workers.** Colisión detectada = rediseña el
   reparto, no "esperemos que no choque".
5. **Mutación obligatoria** para todo test nuevo (del enjambre y tuyo).
6. **Cero celebraciones sin deletions/receipts en el diff** — un reporte
   convincente que cierra el loop de verificación del usuario es parte del bug.
7. **Compón, no dupliques**: el tono lo pone la skill de persona activa
   (/insult, /work); este comando es el workflow, no la personalidad.

## Cierre de sesión

Reporte final con: commits pusheados (SHA + qué), mentiras del checklist
corregidas, hallazgos para decisión del dueño (con análisis, sin ejecutar),
y lo que quedó armado en background con su señal de despertar.
