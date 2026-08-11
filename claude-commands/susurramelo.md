# /susurramelo — Claude habla en voz alta por las bocinas de esta máquina

ARGUMENTS: $ARGUMENTS

Convierte texto en voz con **Susurro** (`https://sus.bernarduriza.com`, el gateway
STT/TTS propiedad de Bernard) y lo reproduce aquí mismo. También canjea el claim
code que la página emite, para mintear/rotar el token.

## Modos

| Invocación | Qué hace |
|---|---|
| `/susurramelo <texto>` | Dice ese texto tal cual. |
| `/susurramelo` (sin args) | Claude redacta 2–4 frases con el estado real de lo último que se hizo en la sesión y lo dice. |
| `/susurramelo claim <claim-code \| URL>` | Canjea el código en `POST /v1/claim` y guarda el token nuevo. |
| `/susurramelo check` | Diagnóstico: token presente, gateway vivo, cadena TTS→audio. |

## Instructions

### `/susurramelo <texto>` y `/susurramelo` sin args

Manda el texto por **stdin** (así sobreviven comillas, saltos de línea y acentos):

```bash
printf '%s' "TEXTO AQUÍ" | bash ~/.claude/scripts/susurro-say.sh -
```

También acepta el texto como argumento directo (`susurro-say.sh "texto"`), pero
stdin es lo preferible para textos largos o con comillas.

El script imprime `mp3=<ruta> bytes=<n> voice=onyx` y luego
`played_s=<segundos> duration_s=<segundos>`. **Las dos líneas juntas son la
evidencia de que sonó** — sin `played_s` no se reporta como reproducido, se
reporta como "mp3 generado, reproducción falló". Si no hay reproductor
disponible, el script **falla con exit≠0** en vez de mentir.

Sin argumentos, Claude escribe el texto él mismo: hechos verificados de la sesión,
2–4 frases, nada de relleno. Si no hay nada verificado que decir, dilo en voz alta
en una frase en vez de inventar avance.

### `/susurramelo claim <claim-code>`

```bash
bash ~/.claude/scripts/susurro-claim.sh "claim-xxxxxxxx"
```

Acepta también la URL completa (`https://sus.bernarduriza.com/claim#claim-xxxx`) —
el script se queda con el fragmento. Imprime `stored=... app=... token_len=43
prefix=sk-susurro-`, **nunca el token**. El archivo anterior queda en `.bak`.

De dónde sale el código: Bernard entra a `https://sus.bernarduriza.com/admin` con su
admin token y crea un claim (`name` + `daily_limit`). Un claim code se quema al
primer uso.

### `/susurramelo check`

```bash
curl -s -o /dev/null -w 'discovery=%{http_code}\n' -m 20 https://sus.bernarduriza.com/v1/discovery
grep -c '^SUSURRO_\(TOKEN\|KEY\)=' ~/.secrets/susurro-token.txt
printf '%s' "Prueba de sonido." | bash ~/.claude/scripts/susurro-say.sh -
```

## Rules

- **El token NUNCA se imprime, ni completo ni parcial, ni en logs ni en el reporte.**
  Vive sólo en `~/.secrets/susurro-token.txt` (invariante de `00-invariants.md`:
  los secretos viven en `~/.secrets/` y nada más). Para diagnosticar se reporta
  longitud y prefijo, jamás el valor.
- **Nada de PII de inmigración por las bocinas.** A-Number, pasaporte, DOB, nombres
  de clientes, números de caso: no se vocalizan. La voz es para estado de trabajo,
  no para leer expedientes.
- **En español mexicano, tono de terminal.** Es Bernard quien escucha, no un cliente.
- **Corto.** Máximo ~1200 caracteres por tirada; arriba de eso pártelo o resume.
  Cada llamada cuesta cuota (ver rate limit abajo).
- **Nunca se reporta "ya te hablé" sin `played_s` en la salida.** Bernard's Law
  aplica igual aquí: sin la línea del reproductor, no hubo audio.
- Si el gateway responde **429**, el token es de tier onboarding (**50 req/día**).
  No reintentes en bucle: díselo a Bernard para que mintee un project key ilimitado
  en `/admin`.

## Trampas ya verificadas — no las re-derives

Universales (aplican en cualquier máquina):

1. **`curl -d '{"input":"..."}'` inline → HTTP 400** `Body is not valid JSON`. Por
   eso el script **siempre** postea un archivo (`-d @body.json`). El propio error
   del gateway lo dice.
2. **Acentos.** El body se serializa con `json.dumps(ensure_ascii=True)` → los
   acentos viajan como `\uXXXX` y el payload queda ASCII puro, inmune a cualquier
   codepage.
3. **La variable del archivo de secretos es `SUSURRO_TOKEN=`**, aunque el
   `/v1/discovery` documenta `SUSURRO_KEY=`. Los scripts aceptan las dos, y
   además caen a `~/.secrets/susurro-gateway-key.txt` si no existe
   `susurro-token.txt`.
4. **En `A=1 printf ... | python3`, la asignación se queda en `printf`** y el
   intérprete nunca la ve. Los scripts pasan las variables por el entorno del
   propio `python3`. Este bug ya costó un run.
5. **La respuesta puede ser HTTP 200 y NO ser audio** (un JSON de error, un
   cuerpo vacío). El script verifica bytes y magic bytes antes de reproducir —
   nunca asume que 200 = sonido.

Específicas de la Mac (2026-08-10, este entorno):

6. **El binario es `python3`, NO `python`.** Al revés que en la máquina Windows.
   `jq`, `ffprobe` y `afplay` sí están.
7. **El reproductor es `afplay`** (nativo, bloqueante — no hay que poll-ear
   duración como con el `MediaPlayer` de PowerShell). El script cae a `ffplay` y
   luego a `mpg123` si no hubiera `afplay`.

Histórico de la máquina Windows (no aplica aquí, se conserva por si se vuelve a
usar ese equipo): el `MediaPlayer` de PresentationCore abre asíncrono y en el
primer tick `NaturalDuration` todavía no existe (~800 ms), por eso
`susurro-play.ps1` la poll-ea antes de confiar en ella.

## Contrato del gateway (verificado contra `/v1/discovery`)

- `POST /v1/tts` — body `{"input","voice","format"}`, auth `Authorization: Bearer <token>`,
  devuelve bytes `audio/mpeg`. Voz por defecto: `onyx`.
- `POST /v1/claim` — body `{"claim_code","name"}` → `{"token","name"}`. El token se
  muestra **una sola vez**.
- `POST /v1/stt`, `POST /v1/refine`, `POST /v1/diarize` — el resto de la superficie,
  fuera del alcance de este comando.
- Admin (sólo Bernard): `GET/POST /admin/claims`, `GET /admin/keys`, `GET /admin/usage`,
  `POST /revoke`.

## Archivos

Los scripts viven **versionados en este mismo repo** (`claude-commands/scripts/`)
y `~/.claude/scripts` es un symlink a esa carpeta — una sola fuente de verdad,
igual que `~/.claude/commands`. Si en una máquina nueva falta el symlink:

```bash
ln -s ~/Documents/BernardUriza/claude-commands/scripts ~/.claude/scripts
```

- `scripts/susurro-say.sh` — TTS + reproducción (bash; `afplay`/`ffplay`/`mpg123`)
- `scripts/susurro-claim.sh` — canje del claim code
- `~/.secrets/susurro-token.txt` — el token (jamás se imprime). Fallback:
  `~/.secrets/susurro-gateway-key.txt`

Overrides por entorno: `SUSURRO_TOKEN`, `SUSURRO_GATEWAY`, `SUSURRO_VOICE`,
`SUSURRO_FORMAT`.

**Verificado end-to-end en esta Mac el 2026-08-10:** texto por stdin y por
argumento (`played_s=5` / `played_s=3` con audio real), y los tres caminos de
error — sin args, texto vacío, y token inválido (`HTTP 401`, sin filtrar el
token).

> Renombrado desde `/hablame` el 2026-08-04. Si encuentras una referencia a `/hablame`
> en cualquier lado, es de la versión previa a ese rename.
