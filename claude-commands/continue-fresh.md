# /continue-fresh - Retomar fresco con los últimos 10 mensajes del chat anterior

## Context

Después de un `/clear` o de abrir una sesión nueva, el contexto del chat previo se pierde.
Este comando NO recarga toda la sesión anterior (eso quema contexto): lee **nada más los
últimos 10 mensajes** del último chat y sintetiza dónde quedó la cosa, para arrancar fresco
sabiendo el siguiente paso.

Es la versión ligera de `/resume-context` — un solo vistazo, sin ceremonia. Funciona en
cualquier repo: deriva el directorio de transcripts del proyecto actual (el cwd), no
hardcodea ninguna ruta.

## Instructions

### Single pass

1. **Identifica el chat anterior y extrae sus últimos 10 mensajes.** El `.jsonl` más reciente
   por mtime es la sesión EN CURSO (esta) — el "último chat" es el **segundo** más reciente.
   El directorio de transcripts del proyecto se deriva del cwd (`/` → `-`), así que el
   extractor sirve en cualquier repo. Córrelo:

   ```bash
   python3 - <<'PY'
   import json, glob, os
   proj = os.path.expanduser("~/.claude/projects/" + os.getcwd().replace("/", "-"))
   files = sorted(glob.glob(f"{proj}/*.jsonl"), key=os.path.getmtime, reverse=True)
   if not files:
       print(f"No hay transcripts en {proj}."); raise SystemExit
   prev = files[1] if len(files) > 1 else files[0]   # [0] = sesión actual; [1] = chat anterior
   msgs = []
   with open(prev) as f:
       for line in f:
           try: o = json.loads(line)
           except Exception: continue
           if o.get("type") not in ("user", "assistant"): continue
           c = o.get("message", {}).get("content")
           if isinstance(c, str):
               text = c
           elif isinstance(c, list):
               text = "\n".join(b.get("text", "") for b in c
                                if isinstance(b, dict) and b.get("type") == "text")
           else:
               text = ""
           text = text.strip()
           if not text: continue
           if text.startswith("<local-command") or text.startswith("Caveat:"): continue
           if text.startswith("<command-name>") or text.startswith("<system-reminder>"): continue
           msgs.append((o["type"], text))
   last10 = msgs[-10:]
   print(f"# Último chat: {os.path.basename(prev)}  ({len(msgs)} msgs totales — últimos {len(last10)})\n")
   for role, text in last10:
       print(f"## {role.upper()}\n{text[:2000]}\n")
   PY
   ```

2. **Lee los 10 mensajes** que imprimió el extractor.

3. **Sintetiza para continuar fresco** en un bloque corto:
   - **Dónde quedó:** 1-2 líneas del tema/tarea del chat anterior.
   - **Último estado:** qué se hizo de último, qué quedó verificado vs pendiente.
   - **Siguiente paso:** la acción concreta para retomar (no una lista, UNA acción).

4. **Para.** No ejecutes el siguiente paso todavía — espera el OK de Bernard, salvo que él ya
   lo haya pedido en el mismo mensaje.

## Rules

- **Solo lectura del transcript** — el comando jamás escribe ni borra el `.jsonl`.
- **Nada más 10 mensajes** — no leer el transcript completo aunque "falte contexto"; si de
  veras falta, dilo y ofrece `/resume-context` para el barrido completo.
- **El #1 por mtime es la sesión actual** — siempre saltarlo; el anterior es el #2. Si solo
  hay un transcript, se lee ese mismo y se avisa que no hay chat previo.
- **El directorio de transcripts se deriva del cwd** — nunca hardcodear una ruta de proyecto;
  el comando es global y debe funcionar en cualquier repo.
- **Síntesis honesta** — si los 10 mensajes no alcanzan para saber dónde quedó, dilo ("no
  alcanzo a inferir el estado con 10 msgs"), no inventes continuidad (Art. 2).
- **Un solo siguiente paso**, no un menú de opciones (Art. 4 — decide, no preguntes de más).
- **No emojis.**
