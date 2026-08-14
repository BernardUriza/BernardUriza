#!/bin/bash
INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')
KEY=$(printf '%s' "$INPUT" | jq -r '.tool_input.key // ""')
FN=$(printf '%s' "$INPUT" | jq -r '.tool_input.function // ""')

RULE18="P0 RULE 18 — envio saliente detectado. PROHIBIDO enviarlo sin haber releido las ultimas burbujas del hilo EN ESTE MISMO TICK, posterior a cualquier interrupcion o cambio de chat. Checa: (1) si un mensaje equivalente ya esta en el hilo es un DUPLICADO — aborta; (2) si contestaron desde que redactaste, reescribe; (3) identifica el delta NUEVO que este envio debe cargar (un PDF, una pregunta) — no repitas texto ya dicho. Tu plan interno miente; el hilo es la verdad. RULE 21.1: el navegador es COMPARTIDO — verifica destinatario Y contenido del composer DENTRO de la misma llamada JS que hace click en Enviar, y aborta si no coinciden. Si esto no envia ningun mensaje a un humano, ignora el recordatorio."

DESTINO="RULE 21.2 — el CANAL tambien es un destinatario y '#general' no identifica nada. Verifica el par guild_id/channel_id, NO solo el channel_id ni el nombre. IDs canonicos de Discord: Khimeras (Alex, Insult, la clase, TODO lo de trabajo) = 1488419218302042223/1489180895264116736 · #general PERSONAL de Bernard (camara del celular, NO es para trabajo) = 1505214330206158858/1505214330788905002. El assert dentro del script de envio debe incluir el GUILD. Y la prueba final no es el id sino el CONTENIDO: si abres el canal y no esta la gente que esperas, ese no es el canal."

PERSONAL="ALTO — estas apuntando al guild 1505214330206158858, el Discord PERSONAL de Bernard (el canal cableado a la camara de su celular). Casi nunca es el destino correcto: la clase con Alex, los prompts, los avisos de trabajo y cualquier cosa donde deba enterarse Insult van al server Khimeras 1488419218302042223/1489180895264116736. Si de verdad querias el personal (pedir una foto de algo fisico), ignora esto; si no, CAMBIA EL CANAL antes de enviar. El 2026-08-12 dos mensajes de la clase de Alex se fueron aqui y ella nunca los recibio."

INSERTTEXT="P0 — insertText SE COME LOS SALTOS DE LINEA en composers tipo Lexical (WhatsApp Web). Un mensaje con lista o cifras sale PEGADO y llega ilegible al humano. Usa un ClipboardEvent con DataTransfer('text/plain'), y ANTES de enviar cuenta los saltos del composer y compara su texto contra el original; si no coinciden, limpia el composer y aborta. Verificado el 2026-08-11: a la tia de Bernard le llego un muro de 2,480 caracteres con los montos del IRS pegados unos con otros."

emit() { jq -n --arg m "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$m}}'; }

MENSAJES=""
add() { if [ -z "$MENSAJES" ]; then MENSAJES="$1"; else MENSAJES="$MENSAJES

$1"; fi; }

case "$TOOL" in
  *press_key*)
    case "$KEY" in
      *Enter*) add "$RULE18" ;;
    esac
    ;;
  *evaluate_script*)
    if printf '%s' "$FN" | grep -qiE 'data-icon=.?(wds-ic-)?send|send-filled|aria-label=.?(Send|Enviar)|ClipboardEvent|contenteditable|#main footer'; then
      add "$RULE18"
    fi
    if printf '%s' "$FN" | grep -q "insertText"; then
      add "$INSERTTEXT"
    fi
    if printf '%s' "$FN" | grep -qE 'discord\.com|/[0-9]{17,20}/[0-9]{17,20}|guildsnav|data-list-id=.?chat-messages'; then
      add "$DESTINO"
    fi
    if printf '%s' "$FN" | grep -q '1505214330206158858'; then
      add "$PERSONAL"
    fi
    ;;
esac

[ -n "$MENSAJES" ] && emit "$MENSAJES"
exit 0
