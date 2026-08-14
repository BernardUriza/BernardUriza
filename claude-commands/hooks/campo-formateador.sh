#!/bin/bash
# Dispara cuando se escribe un MONTO en un campo web via chrome-devtools.
# Motivo (2026-08-12): el campo de monto de Mercado Pago Wallet convirtio 4589 en
# 589, y tras el reintento en 5,894,589. Un formateador en vivo reescribe lo que
# mandas. Ver engineering-playbook/rules/agent-autonomy.md.
INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')
VAL=$(printf '%s' "$INPUT" | jq -r '.tool_input.value // ""')

case "$TOOL" in
  mcp__chrome-devtools__fill|mcp__chrome-devtools__fill_form) ;;
  *) exit 0 ;;
esac

# solo montos: 3+ digitos, opcionalmente con comas o punto decimal
if printf '%s' "$VAL" | grep -Eq '^[0-9]{3,}([,.][0-9]+)*$'; then
  jq -n --arg m "CAMPO CON FORMATEADOR — estas escribiendo un monto ($VAL) por chrome-devtools. Un campo de moneda reescribe lo que mandas: puede comerse el primer digito o concatenar sobre lo anterior. (1) LEE el valor de vuelta en la PANTALLA renderizada, no en input.value. (2) Si difiere UNA sola vez, no reintentes por CDP: cambia a desktop-control (teclado real del OS), digito por digito. (3) Nunca aprietes el boton irreversible sin haber visto el monto correcto renderizado. El 2026-08-12 un fill de 4589 quedo en 589 y el reintento en 5,894,589." '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$m}}'
fi
exit 0
