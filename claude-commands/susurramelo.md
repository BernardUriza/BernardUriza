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

El script imprime `mp3=<ruta> bytes=<n> voice=onyx` y luego `played_s=<duración>`.
**Las dos líneas juntas son la evidencia de que sonó** — sin `played_s` no se
reporta como reproducido, se reporta como "mp3 generado, reproducción falló".

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

## Trampas ya verificadas (2026-08-04) — no las re-derives

1. **`curl -d '{"input":"..."}'` inline → HTTP 400** `Body is not valid JSON`. El
   gateway recibe las comillas simples literales desde este entorno Windows. Por eso
   el script **siempre** postea un archivo (`-d @body.json`). El propio error del
   gateway lo dice.
2. **Acentos.** El body se serializa con `json.dumps(ensure_ascii=True)` → los
   acentos viajan como `\uXXXX` y el payload queda ASCII puro, inmune al codepage de
   Windows PowerShell 5.1.
3. **La variable del archivo de secretos es `SUSURRO_TOKEN=`**, aunque el
   `/v1/discovery` documenta `SUSURRO_KEY=`. Los scripts aceptan las dos.
4. **`MediaPlayer` abre asíncrono**: en el primer tick `NaturalDuration` todavía no
   existe (aquí tardó 800 ms). Hay que poll-earla antes de confiar en la duración, o
   el audio se corta. `susurro-play.ps1` ya lo hace.
5. **`python3` no existe en esta máquina; el binario es `python`** (3.14). `jq`
   tampoco está instalado.
6. **En `A=1 printf ... | python`, la asignación se queda en `printf`** y el intérprete
   nunca la ve. Los scripts usan `export`. Este bug ya costó un run.

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

- `~/.claude/scripts/susurro-say.sh` — TTS + reproducción
- `~/.claude/scripts/susurro-play.ps1` — reproductor bloqueante (PresentationCore)
- `~/.claude/scripts/susurro-claim.sh` — canje del claim code
- `~/.secrets/susurro-token.txt` — el token (jamás se imprime)

> Renombrado desde `/hablame` el 2026-08-04. Si encuentras una referencia a `/hablame`
> en cualquier lado, es de la versión previa a ese rename.
