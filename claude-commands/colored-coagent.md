# /colored-coagent - Tiñe un chat de ChatGPT con el color de fondo de ESTA terminal

ARGUMENTS: la URL del chat de ChatGPT a teñir (ej. https://chatgpt.com/c/<uuid> o https://chatgpt.com/g/<gizmo>/c/<uuid>). Opcional: si no se pasa, el coagent resuelve el chat así: (1) `COAGENT_CHATGPT_URL` del `.env` del proyecto actual, (2) si no hay, rankea las tabs abiertas por similitud con el contexto de la sesión. Cuando SÍ se pasa URL, se persiste en el `.env` del proyecto para no volver a pedirla.

## Context

Lee el color de fondo de la terminal donde corre Claude Code y lo inyecta como
fondo del área de conversación de un chat de ChatGPT, vía el Chrome de debug y
el MCP `chrome-devtools`. El color se lee **dinámicamente cada vez** — si cambias
el tema de la terminal, el comando matchea el nuevo color sin editar nada.

La terminal correcta se identifica por el **TTY de ESTA sesión** (Phase 1), no
por la ventana que está al frente: con varias sesiones de Claude Code abiertas,
"la del frente" suele ser otra y el color saldría equivocado.

Hallazgo que sustenta el mecanismo (DOM real de chatgpt.com, tema oscuro): la
columna de mensajes es **transparente**; el color lo pinta `body`/`html` vía la
variable CSS `--main-surface-primary`. Las burbujas del usuario usan otra
variable (`--message-surface`), así que cambiar el fondo **no rompe su contraste**.

## Instructions

### Phase 1: Leer el color de ESTA terminal (anclado al TTY de la sesión)

> **CRÍTICO — por qué NO usar `front window`/`current window`:** si hay **varias
> ventanas/sesiones de Claude Code abiertas**, `selected tab of front window`
> (Terminal.app) o `current session of current window` (iTerm2) leen la ventana
> que está **al frente en pantalla**, que casi nunca es la que corre ESTA sesión.
> Resultado: tiñes ChatGPT con el color de OTRA terminal. Esto YA falló
> (2026-06-09: dos sesiones, una en `#0C081A` y la del frente en otro tono; el
> comando leyó la frontal y pintó el color equivocado). **La sesión se identifica
> por su TTY, no por el foco de pantalla.**

1. Detectar el emulador con `echo $TERM_PROGRAM`.
2. **Resolver el TTY de ESTA sesión de Claude Code.** El Bash tool corre detached
   (`tty` directo da `??`), pero un **ancestro** (`claude`/`login`) sí tiene el
   TTY controlador. Subir por la cadena de padres hasta el primer TTY real:
   ```bash
   cur=$$
   SESSION_TTY=""
   for i in $(seq 1 16); do
     line="$(ps -o ppid=,tty= -p "$cur" 2>/dev/null)" || break
     ppid="$(echo "$line" | awk '{print $1}')"
     tty="$(echo "$line"  | awk '{print $2}')"
     if [ -n "$tty" ] && [ "$tty" != "??" ]; then SESSION_TTY="$tty"; break; fi
     case "$ppid" in ""|0|1) break;; esac
     cur="$ppid"
   done
   echo "SESSION_TTY=$SESSION_TTY"   # ej. ttys000  (vacío = no resuelto)
   ```
3. Obtener el color de fondo **de la pestaña cuyo `tty` == `/dev/$SESSION_TTY`** y
   convertirlo a HEX:

   **Terminal.app** (`TERM_PROGRAM=Apple_Terminal`) — componentes 0-65535, match por TTY:
   ```bash
   osascript - "$SESSION_TTY" <<'EOF'
   on run argv
     set wantTTY to "/dev/" & (item 1 of argv)
     tell application "Terminal"
       repeat with w in windows
         repeat with t in tabs of w
           if (tty of t) is wantTTY then
             set bg to background color of t
             set {r, g, b} to bg
             return (do shell script "printf '#%02X%02X%02X' " & (r div 257) & " " & (g div 257) & " " & (b div 257))
           end if
         end repeat
       end repeat
     end tell
     return "NOTFOUND"
   end run
   EOF
   ```

   **iTerm2** (`TERM_PROGRAM=iTerm.app`) — las sesiones exponen `tty`, match por TTY:
   ```bash
   osascript - "$SESSION_TTY" <<'EOF'
   on run argv
     set wantTTY to "/dev/" & (item 1 of argv)
     tell application "iTerm2"
       repeat with w in windows
         repeat with t in tabs of w
           repeat with s in sessions of t
             if (tty of s) is wantTTY then
               set bg to background color of s
               set {r, g, b} to bg
               return (do shell script "printf '#%02X%02X%02X' " & (r div 257) & " " & (g div 257) & " " & (b div 257))
             end if
           end repeat
         end repeat
       end repeat
     end tell
     return "NOTFOUND"
   end run
   EOF
   ```

   Otros emuladores (Warp, kitty, Ghostty, etc.): si no hay path por AppleScript,
   leer el color del perfil/config del emulador o pedir el HEX al usuario UNA vez.
4. **Validar el resultado.** Si el `osascript` devuelve `NOTFOUND` (o `SESSION_TTY`
   quedó vacío), NO caer en silencio a la ventana frontal: reportar al usuario que
   no se pudo anclar el TTY y, solo como fallback explícito y **avisando**, leer la
   ventana frontal con la advertencia de que puede ser otra terminal. Nunca pintar
   sin avisar cuando el match por TTY falla.
5. Guardar el HEX resultante en una variable `COLOR` (ej. `#191D27`). Reportarlo
   junto al `SESSION_TTY` desde el que se leyó (ej. `COLOR=#261926 (ttys000)`).

### Phase 2: Localizar el Chrome de debug (NUNCA matar Chrome)

Sigue la regla dura de `~/CLAUDE.md` (Chrome Remote Debugging). Diagnóstico
ANTES de tocar nada — no `pkill`, no relanzar a ciegas:

1. Leer el puerto del debug desde la config del MCP (no asumir 9222):
   ```bash
   grep -A6 '"chrome-devtools"' ~/.claude.json | grep -oE 'http://127\.0\.0\.1:[0-9]+|http://localhost:[0-9]+'
   ```
   Verificar que responde:
   ```bash
   curl -s -o /dev/null -w '%{http_code}\n' <browserUrl>/json/version   # 200 = vivo
   ```
2. Si no hay endpoint vivo, NO relanzar Chrome desde aquí. Reportar al usuario el
   estado real y el camino (toggle `chrome://inspect/#remote-debugging` o lanzar
   Chrome con `--remote-debugging-port` sobre un `--user-data-dir` aparte) según
   `~/CLAUDE.md`. Detener el comando.

### Phase 3: Resolver el chat objetivo (URL del proyecto persistida)

Casi siempre hay UN chat de ChatGPT asociado al proyecto. La fuente de verdad es
la variable `COAGENT_CHATGPT_URL` en el `.env` del repo donde corres el comando.
Resolver el `TARGET_URL` en este orden:

1. **¿Se pasó `ARGUMENTS`?** → ese es el `TARGET_URL`. Además **persistirlo**:
   - Si el `.env` del cwd ya tiene `COAGENT_CHATGPT_URL=...` → actualizar esa línea.
   - Si no existe la clave → append `COAGENT_CHATGPT_URL=<url>` al `.env` (créalo si falta).
   - `.env` suele estar gitignored — confirmar que sigue así (no commitear nada).
2. **¿Sin `ARGUMENTS` pero hay `COAGENT_CHATGPT_URL` en `./.env`?** → usar ese valor.
   ```bash
   grep -E '^COAGENT_CHATGPT_URL=' .env 2>/dev/null | head -1 | cut -d= -f2-
   ```
3. **¿Sin URL y sin `.env`?** → caer al ranking por contexto (Phase 3B).

El **UUID** es la parte estable del path para matchear/identificar un chat, en
cualquiera de los dos formatos: `…/c/<uuid>` y `…/g/<gizmo>/c/<uuid>`. Extraerlo con
`grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'`.

### Phase 3B: Seleccionar el tab de ChatGPT

Vía herramientas MCP `chrome-devtools`:

**Caso A — hay `TARGET_URL` (de ARGUMENTS o del `.env`):**
1. `list_pages` → buscar el tab cuyo URL contenga el mismo `<uuid>` (ignora query
   string y el segmento `/g/<gizmo>/`).
2. Si existe → `select_page` con su `pageId`.
3. Si NO existe → `new_page`/`navigate_page` a `TARGET_URL`, esperar carga, y seleccionarla.

**Caso B — sin `TARGET_URL` → el coagent elige por contexto:**

El comando NO toma "el primer tab" a la fuerza. Elige el chat de ChatGPT cuyo
tema más se parece a lo que se está trabajando en ESTA sesión de Claude Code.

1. `list_pages` → quedarse solo con tabs de `chatgpt.com` que sean chats (`/c/<uuid>`).
2. Si hay **0** → reportar que no hay chats abiertos y detener.
3. Si hay **1** → usarlo directo (no hay nada que rankear).
4. Si hay **2+** → extraer la "huella" de cada tab y rankear por similitud:
   - Para cada `pageId`: `select_page` + `evaluate_script` que devuelva el título
     del chat y un extracto del contenido, p.ej.:
     ```js
     () => ({
       title: document.title,
       heading: document.querySelector('h1, [data-testid="conversation-title"]')?.innerText || '',
       firstUserMsg: document.querySelector('[data-message-author-role="user"]')?.innerText?.slice(0, 400) || '',
       lastMsgs: [...document.querySelectorAll('[data-message-author-role]')].slice(-4).map(m => m.innerText?.slice(0, 200)).join(' · ')
     })
     ```
   - Construir el **contexto de la sesión actual**: de qué trata este turno —
     repo/cwd actual, ramas/archivos tocados, lo que el usuario está pidiendo,
     términos recurrentes de la conversación de Claude Code.
   - Puntuar cada tab por solape semántico (proyecto, nombres propios, jerga,
     tarea) contra ese contexto. Elegir el de mayor puntaje.
5. **Reportar la elección y el porqué ANTES de teñir**, en 1 línea:
   `Sin URL → elijo el tab "<título>" (pageId N) por matchear <razón>.`
   Si hay empate o ningún tab se parece de forma clara al contexto, NO adivinar:
   listar los candidatos con su título y preguntar al usuario cuál.
6. **Persistir el ganador** (cierra el loop): tras elegir por ranking, guardar su
   URL como `COAGENT_CHATGPT_URL` en el `.env` del proyecto, para que la próxima
   corrida sea resolución directa (Phase 3, paso 2) sin volver a rankear.

### Phase 4: ¿Ya están sincronizados? (short-circuit, NO re-teñir)

Antes de inyectar nada, comprobar si el chat YA tiene el color de la terminal.
Si ya coinciden, no se toca el DOM — solo se reporta. `evaluate_script`:

```js
(color) => {
  // normaliza cualquier formato CSS a "r,g,b" usando el motor del navegador
  const norm = (c) => {
    const d = document.createElement('div');
    d.style.color = c; document.body.appendChild(d);
    const rgb = getComputedStyle(d).color; d.remove();
    return rgb; // p.ej. "rgb(25, 29, 39)"
  };
  const target = norm(color);
  const current = getComputedStyle(document.body).backgroundColor;
  const override = document.getElementById('cgpt-bg-override');
  return {
    inSync: norm(current) === target,   // mismo RGB renderizado
    hasOverride: !!override,
    target, current,
  };
}
```

- Si `inSync === true` → **NO inyectar**. Reportar en 1 línea y terminar:
  `Ya sincronizados: <chat> ya está en <COLOR> (= color de la terminal). Nada que hacer.`
- Si `inSync === false` → continuar a Phase 5 (inyectar).

Esto hace el comando idempotente a nivel de estado: correrlo dos veces seguidas
no repinta ni parpadea; y si cambiaste el tema de la terminal, detecta el desfase
(`current ≠ target`) y re-sincroniza.

### Phase 5: Inyectar el fondo (idempotente y reversible)

`evaluate_script` con esta función, pasando el `COLOR` de la Phase 1:

```js
(color) => {
  const ID = 'cgpt-bg-override';
  document.getElementById(ID)?.remove();          // idempotente
  const s = document.createElement('style');
  s.id = ID;
  s.textContent = `
    :root, html.dark, .dark {
      --main-surface-primary: ${color} !important;
      --bg-primary: ${color} !important;
    }
    html, body, main { background-color: ${color} !important; }
  `;
  document.head.appendChild(s);
  return { applied: color, bodyBg: getComputedStyle(document.body).backgroundColor };
}
```

### Phase 6: Verificar y reportar

1. Confirmar que `bodyBg` devuelto equivale al `COLOR` (mismo RGB).
2. Opcional: `take_screenshot` (jpeg, calidad ~70) para evidencia visual.
3. Reporte de cierre, breve:
   `ChatGPT teñido a <COLOR> (leído de <emulador>). Recarga la página revierte.`
4. Dar al usuario el snippet de **revertir** sin recargar:
   ```js
   document.getElementById('cgpt-bg-override')?.remove();
   ```

## Rules

- **No tocar lógica/negocio de ChatGPT** — solo inyección de CSS visual, por sesión.
- **NUNCA matar ni relanzar Chrome a ciegas** — diagnóstico primero (regla `~/CLAUDE.md`).
  Si el flag `--remote-debugging-port` fue rechazado en el perfil default (Chrome 136+),
  NO reintentar variaciones; reportar el camino correcto.
- **Color dinámico, nunca hardcodear** — leer el fondo real de la terminal en cada corrida.
- **Anclar al TTY de la sesión, NUNCA a la ventana frontal** — resolver `SESSION_TTY`
  subiendo por los ancestros de `$$` y leer el color de la pestaña cuyo `tty` matchee.
  `front window` / `current window` leen el foco de pantalla, que con multi-sesión
  es OTRA terminal → color equivocado. Si el match por TTY falla, AVISAR antes de
  cualquier fallback; nunca pintar en silencio con el color de la ventana frontal.
- **Chequear sincronía ANTES de teñir** — comparar el `background-color` renderizado del
  chat contra el color de la terminal (mismo RGB normalizado). Si ya coinciden, NO tocar
  el DOM: reportar "ya sincronizados" y terminar. Solo re-teñir si hay desfase real
  (cambiaste el tema de la terminal o el chat nunca se tiñó).
- **Sin URL = elegir por contexto, no por orden** — rankear las tabs de ChatGPT por
  similitud con el tema de la sesión y reportar el porqué. Si ningún tab matchea de
  forma clara (o hay empate), listar candidatos y preguntar — NUNCA teñir a ciegas
  el primero que aparece.
- **Persistir el chat del proyecto en `.env`** — la fuente de verdad es
  `COAGENT_CHATGPT_URL` en el `.env` del repo. Pasar URL o elegir por ranking debe
  guardarla ahí; el caso común (proyecto ya configurado) es resolución directa sin
  rankear. NUNCA commitear `.env` ni mezclar la URL con secrets (solo append/update
  de esa clave; mantener el archivo gitignored).
- **No tocar `--message-surface`** ni la sidebar — preservar contraste de las burbujas.
  (Teñir la sidebar es opt-in: el usuario lo pide explícitamente.)
- **Idempotente** — reemplazar el `<style id="cgpt-bg-override">` si ya existe, no duplicar.
- **Verificar antes de cantar victoria** — confirmar `bodyBg` real, no asumir.
- **No emojis** en el reporte salvo que el usuario los pida.

## Notas

- El cambio es **por sesión**: recargar la página lo borra (es CSS inyectado, no
  toca la cuenta de ChatGPT).
- Para hacerlo **permanente** sin recargar cada vez, el mismo CSS vive como
  userstyle de **Stylus** o script de **Tampermonkey** sobre `chatgpt.com`.
- Para que **también la sidebar** tome el color, añadir dentro del `textContent`:
  `#stage-slideover-sidebar, [class*="surface-secondary"] { background-color: ${color} !important; }`
