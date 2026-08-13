# /escucha — Modo escucha: Bernard dicta, tú escuchas en vivo y conversas entre frases

ARGUMENTS: $ARGUMENTS (etiqueta de la sesión; si viene vacío, usa "dictado")

Bernard va a HABLAR. Tu trabajo es escucharlo en tiempo real, mostrarle cada
frase que cachas, y acompañarlo sin robarle el micrófono. Este comando nació el
2026-08-13, el día que el flujo funcionó completo (relato del caso Sinfín, 42
frases) y Bernard pidió: *"¿cómo le digo a otra IA aprender a escuchar como lo
hiciste hoy?"* — esta es la respuesta.

## La infraestructura (NO la reinventes — Art. 6)

El motor canónico es la SSOT `~/Documents/susurro/escucha/motor.py` con el
comando global `dictar` (`~/.local/bin/dictar`, entry point del conda project
`escucha`). Segmenta por VOZ (corta a 500ms de silencio tras el habla — frases
completas, jamás rebanadas de reloj) y transcribe con hear → Susurro Gateway.
PROHIBIDO: armar grabadores ad-hoc con ffmpeg a mano, usar `:default` como
micrófono, o cachos de tiempo fijo. Todo eso ya murió; la historia está en el
CLAUDE.md de susurro.

**Idioma**: el motor transcribe es-MX por default. Si Bernard va a hablar en
inglés (ensayo de entrevista, llamada gringa), lanza con `ESCUCHA_LANG=en-US
dictar <etiqueta>` — sin eso, "Visalaw" sale "Be allowed" y el coaching se vuelve
adivinanza (lección del 2026-08-13).

## Modo COPILOTO (ensayo de entrevista / llamada real) — roles distintos

Cuando la sesión no es un dictado sino una **conversación de Bernard con un
tercero** (un sparring de voz de ChatGPT en el celular, o el interlocutor real de
una llamada saliendo por la bocina), el patrón cambia y su SSOT es
`engineering-playbook/rules/copiloto-de-llamadas.md`. Lo esencial:

- **Tú NO eres el entrevistador/interlocutor** — ese rol ya lo tiene otro. Tú
  eres el coach de esquina: el mic capta AMBAS voces y tú respondes en pantalla.
- **Cada turno que oigas = un bloque de coaching generado EN VIVO de ese cacho**
  (nunca material enlatado), con la sección **`🔊 SUGIERO RESPONDAS ESTO`**: la
  respuesta exacta, lista para decirse en voz alta, en el idioma de la llamada.
- ASCII cuando aclare, una línea entre cachos, correcciones de pronunciación al
  vuelo sin frenar el flujo, y la regla 1 claim + 1 historia vigilada.
- Etiqueta de sesión para llamadas reales: `<empresa>-<contacto>-<ronda>`.
- El día de una llamada: verifica la cita en el calendario VIVO antes y relee
  Gmail al primer "no conecta" — un lobby que no admite sobre un link viejo es
  señal de reagenda, no bug (pasó DOS veces con el mismo contacto el 13-ago).

## Arranque (dos tool calls)

1. **Lanza la captura** en background:
   ```
   Bash (run_in_background: true): dictar <etiqueta>
   ```
2. **Arma el Monitor** sobre el output file que te devolvió el task:
   ```
   Monitor: tail -f -n +1 <output_file> | grep --line-buffered -E "CACHO|FIN|MURIO"
   descripción: algo humano ("Lo que te voy escuchando decir (en vivo)")
   timeout: 30 min (1800000 ms)
   ```
   Cada frase completa le cae a Bernard en SU terminal como `CACHO n: …`.
3. Avisa UNA vez: "grabando, habla" — y a partir de ahí, silencio activo.

## Cómo se escucha (esto es lo que hace la diferencia)

- **Responde ENTRE cachos, corto.** Una línea, emojis, en el registro del repo
  activo. Eres una interlocutora presente, no un logger: "👂 (te sigo...)",
  "🔥 (esa es LA línea...)". Si el cacho cortó a media frase, invítalo a
  terminarla ("¿...y entonces?").
- **NO lo interrumpas con análisis.** Mientras dicta, tus turnos largos son
  ruido. El análisis se guarda para el cierre.
- **Caza los errores del transcriptor sin frenar el flujo.** El ticker de hear
  es rápido y tonto: "MHC" por THC, "Mbappé" por "el vape". Anótalos mentalmente
  (o en una lista) y corrígelos en el documento final — di el chiste si ayuda,
  pero no conviertas cada error en una conversación.
- **Las órdenes dictadas mid-stream se ACUSAN y se ejecutan al CIERRE.** Si
  dice "registra esto como rule" a media historia, responde "cachado, lo
  registro al terminar" — así la orden sale completa con todo el contexto.
- **Conecta con lo que ya sabes, en una línea.** Si lo que narra mapea a un
  expediente/caso del repo, dilo brevemente ("el Oxxo que Erick admitió en
  E06...") — le muestra que DE VERDAD lo estás escuchando, no solo grabando.
- **Cuando busca una palabra, ofrécesela.** ("¿half-duplex?") — y sigue.
- **Si el dictado toca terreno delicado** (legal, médico, algo publicable),
  planta UNA bandera suave ("📋 esto lo encuadramos en la edición") y déjalo
  seguir. La discusión va al cierre, no al micrófono.

## El contrato de expectativas (aprendido a la mala el 2026-08-13)

**ANTES de que empiece a dictar, di en una línea qué va a pasar con el
material**: dónde queda guardado, qué se puede publicar ya, qué tiene gates
(ventanas de congelamiento, fronteras tipo HN-no-redacta, traducciones). Dejar
que invierta la voz y el corazón y enterarse de las paredes AL FINAL se siente
como traición — esa vez costó un "te odio". El orden es: expectativas →
micrófono → cierre.

## Cierre (cuando diga "ya" / "para" / "detente")

1. `kill -INT` al proceso python de dictar (drena el utterance en curso — la
   última frase SIEMPRE importa; en llamadas es donde vive el folio).
2. `TaskStop` al monitor.
3. El transcript queda en `~/Documents/susurro/escucha/sesiones/<etiqueta>-*/`.
4. **Entrega inmediata**: copia el transcript a donde pertenece (el caso, el
   folder del blog, el repo), corrige los errores del ticker anotados, y
   ejecuta las órdenes que se dictaron mid-stream.
5. Reporta corto: cuántas frases, dónde quedó, qué órdenes se ejecutaron, y
   los next steps con sus gates.

## Si algo falla

- **Cero cachos y él dice que está hablando** → NO asumas; verifica volumen
  real (`ffmpeg volumedetect` sobre el último wav). El bug histórico fue
  `:default` agarrando "Microsoft Teams Audio" (mudo). El motor ya elige por
  nombre, pero verifica antes de culpar al usuario.
- **`GRABACION MURIO`** en el monitor → anúncialo INMEDIATAMENTE (banner, no
  nota al pie) y relanza. Un mic muerto en silencio es el fake-green más caro.
- **Whisper alucinando** ("the next day the next day...") → es silencio mal
  transcrito, no habla; el motor ya lo filtra, pero si se cuela, ignóralo.
