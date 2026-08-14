#!/bin/bash
# Rule 21.1.b — un clic real de desktop-control aterriza en la ventana que este
# AL FRENTE en ese instante, no en la que mirabas hace una llamada. En esta Mac
# corren varias sesiones de Claude y sus terminales se levantan solas.
#
# El hook no bloquea: inyecta el DATO que decide todo — que app esta al frente
# ahora mismo y cuantas sesiones pares hay. Si dice "Terminal" y querias hacer
# clic en Chrome, ya sabes donde iba a caer.
INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')
ACCION=$(printf '%s' "$INPUT" | jq -r '.tool_input.action // ""')

case "$TOOL" in *desktop-control*) ;; *) exit 0 ;; esac

# Solo acciones que MUTAN la pantalla. Un screenshot o un mouse_move no hacen dano.
case "$ACCION" in
  left_click|right_click|middle_click|double_click|left_click_drag|type|key) ;;
  *) exit 0 ;;
esac

FRENTE=$(osascript -e 'tell application "System Events" to name of first application process whose frontmost is true' 2>/dev/null)
PARES=$(pgrep -x claude 2>/dev/null | wc -l | tr -d ' ')
PARES=$((PARES > 0 ? PARES - 1 : 0))

MSG="RULE 21.1.b — clic/tecleo REAL sobre la pantalla. Al frente AHORA: **${FRENTE:-desconocido}**"
[ "$PARES" -gt 0 ] && MSG="$MSG · sesiones Claude pares corriendo: $PARES (sus terminales roban el foco entre una llamada y otra)"
MSG="$MSG. Si esa app no es donde querias hacer clic, ABORTA: el evento va a la ventana frontmost, no a la que viste en tu ultimo screenshot. Verificar solo 'Chrome esta al frente' NO basta — tambien la PESTANA activa puede haber cambiado. Diagnostico de 10s cuando un clic 'no hizo nada': mouse_move al objetivo + get_screenshot y mira donde cae la cruz roja; si esta sobre otra ventana, los clics anteriores tambien fueron ahi. Para algo irreversible (pago, submit, borrado) con pares ocupados: pausa las otras sesiones o pasale ese clic a Bernard."

jq -n --arg m "$MSG" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$m}}'
exit 0
