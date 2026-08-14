#!/bin/bash
# Dispara al subir un .ics a Google Calendar.
#
# Por que existe (2026-08-14): la regla `cerrar-sesion-con-el-calendario.md` ya
# documentaba tres candados de importacion, se leyo entera, y el fallo paso igual.
# El .ics quedo perfecto en disco, --check y auditar-cifras.py en verde, el SEQUENCE
# correctamente subido de 42 a 43 — y Google contesto "Imported 0 out of 37 events"
# sin aplicar NADA, ni siquiera el evento con UID que nunca habia visto. Los mismos
# eventos subidos SOLOS entraron "2 out of 2". La regla-en-contexto no basta porque
# el mensaje de fallo esta redactado como confirmacion: un 0 se lee como "ya estaban".
INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.filePath // ""')

case "$TOOL" in
  *upload_file*) ;;
  *) exit 0 ;;
esac

case "$FILE" in
  *.ics) ;;
  *) exit 0 ;;
esac

emit() { jq -n --arg m "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$m}}'; }

LEER_DIALOGO="Y LEE EL DIALOGO ENTERO antes de reportar nada: tiene que decir 'Imported N out of N'. Un 'Imported 0 out of N' NO significa 'ya estaban todos' — significa que no entro NADA y el calendario sigue igual. Es un fallo redactado como confirmacion. Despues de importar, VERIFICA en el calendario que el cambio esta ahi (Art. 2): el dialogo no es la prueba, el evento si."

case "$FILE" in
  # El glob lleva el comodin del final porque --delta escribe UN ARCHIVO POR
  # CALENDARIO DESTINO: `.import-delta.ics` para el principal y
  # `.import-delta-<Calendario>.ics` para cada secundario. Con el nombre exacto, el
  # hook gritaba "estas subiendo el .ics completo" justo sobre el delta de un
  # calendario secundario — un falso positivo en el caso que mas cuidado necesita,
  # porque importar ahi al calendario equivocado DUPLICA el evento.
  *.import-delta.ics|*.import-delta-*.ics)
    emit "Subiendo un DELTA, correcto. ⚠️ Si el archivo trae sufijo de calendario (.import-delta-<Nombre>.ics), el desplegable 'Add to calendar' TIENE que decir ESE calendario, no el principal: importar al equivocado no da error, DUPLICA el evento. Verifica el desplegable DENTRO de la misma llamada que hace click en Import. $LEER_DIALOGO"
    ;;
  *)
    emit "ALTO — vas a subir un .ics COMPLETO a Google Calendar y eso NO APLICA NADA. Medido el 2026-08-14 con el mismo contenido y los mismos UID: el archivo entero devolvio 'Imported 0 out of 37 events' (ni siquiera entro el evento con UID nuevo), y los mismos eventos subidos solos entraron 'Imported 1 out of 1' y 'Imported 2 out of 2'. La unica variable fue si el archivo traia ademas los eventos que NO cambiaron. Arma el delta primero: baja el export de Google (Settings -> Import & export -> Export) y corre 'python3 build-ics.py --delta <export.zip>', que escribe .import-delta.ics con solo lo nuevo o cambiado, y de paso lista los UID que estan en Google y en ningun .ics (asi se cazo una serie huerfana que duplicaba el gasto de Azure cada dia 15 sin UNTIL). $LEER_DIALOGO"
    ;;
esac
exit 0
