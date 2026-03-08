# /build-check - Build rapido + reporte de warnings + fix opcional

## Instrucciones

Comando de diagnostico y limpieza. Detecta zombies, corre build, reporta warnings en tabla, y opcionalmente los arregla pidiendo confirmacion.

### Paso 1: Matar Zombies

Verificar procesos dotnet antes de buildear:

```bash
ps aux | grep -E "dotnet" | grep -v grep
```

- Si hay 3+ procesos dotnet corriendo: reportar en tabla y matarlos automaticamente
- Si hay procesos `dotnet watch` o `dotnet build` zombie: matarlos
- Si el puerto 5000/5001 esta ocupado por un proceso zombie: matarlo
- Reportar: "N zombies eliminados" o "Sin zombies"

### Paso 2: Build

```bash
dotnet build 2>&1
```

Reportar en tabla agrupada por archivo:

| Archivo | Linea | Tipo | Mensaje |
|---------|-------|------|---------|
| ProductService.cs | 42 | Warning CS8602 | Dereference of possibly null reference |
| OrderHandler.cs | 15 | Warning CS0168 | Variable declared but never used |

Resumen: "Build exitoso: 0 errores, N warnings en M archivos"

Si hay ERRORES: PARAR. Reportar errores y no continuar.

### Paso 3: CSS Build

```bash
npm run css:build 2>&1
```

Reportar si hubo errores. Si fue limpio: "CSS build limpio."

### Paso 4: Verificacion de Server

Verificar estado del server de desarrollo:

```bash
lsof -i :5000 -i :5001 2>/dev/null
ps aux | grep "dotnet watch" | grep -v grep
```

Reportar:
- **Server corriendo**: "dotnet watch activo en puerto XXXX (PID YYYY)"
- **Server NO corriendo**: "No hay server corriendo. Quieres que lo lance?"
- **Server zombie**: "Proceso en puerto 5000 pero no es dotnet watch — posible zombie"

### Paso 5: Pregunta de accion

Usar `AskUserQuestion` con opciones basadas en lo encontrado:

- **"Arreglar warnings"**: Claude lee cada warning, propone fix, y pregunta con `AskUserQuestion` por cada grupo:
  - "Arreglar todos" — aplica todos los fixes del grupo
  - "Arreglar solo estos" — el usuario indica cuales
  - "Saltar grupo" — no tocar ese archivo
  Despues de arreglar, re-correr build para verificar 0 warnings.

- **"Chrome DevTools quick test"**: Verificar que Chrome responde (`list_pages`), tomar screenshot, reportar errores de consola (`list_console_messages`), abrir screenshot con `open`

- **"Relanzar server"**: Matar procesos dotnet, relanzar `dotnet watch run --project src/VHouse.Web/VHouse.Web.csproj --non-interactive` en background, esperar 5s, verificar que responde

- **"Todo limpio, terminar"**: Cerrar sin mas acciones

## Reglas

1. **Formato tabla SIEMPRE** para warnings y errores — nunca wall of text
2. **Agrupar warnings por archivo** — no listar uno por uno sin contexto
3. **Si hay 0 errores y 0 warnings**: "Build inmaculado. Nada que reportar."
4. **Si Chrome no responde**: Decirlo y ofrecer relanzar, no colgarse intentando
5. **Al arreglar warnings**: Leer el archivo completo antes de proponer fix, nunca adivinar
6. **Re-build despues de fixes**: Siempre verificar que el fix no introdujo nuevos warnings/errores
7. **No tocar logica de negocio** al arreglar warnings — solo null checks, unused vars, type annotations
8. **Warnings de terceros** (NuGet packages, generated code): Reportar pero NO intentar arreglar
9. **Matar zombies automaticamente** si hay 3+ procesos — no preguntar, solo informar que los mato
