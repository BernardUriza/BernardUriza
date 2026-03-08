# /modify-command - Wizard Interactivo para Crear y Modificar Comandos de Claude Code

## Contexto

Este comando lanza un **wizard interactivo** que guia al usuario paso a paso para crear un comando nuevo o modificar uno existente en `.claude/commands/`. Usa `AskUserQuestion` en cada paso para recopilar contexto, preferencias y restricciones antes de generar el archivo `.md` final.

**Directorio de comandos**: `.claude/commands/`
**Formato de archivo**: Markdown (`.md`)
**Invocacion**: `/nombre-del-comando` en Claude Code

---

## Instrucciones de Ejecucion

### IMPORTANTE: Flujo Obligatorio

1. **NUNCA** generar un comando sin completar TODAS las preguntas
2. **SIEMPRE** usar `AskUserQuestion` para cada paso — no asumir respuestas
3. **SIEMPRE** mostrar un preview del comando generado ANTES de escribir el archivo
4. **SIEMPRE** verificar que el nombre del comando no colisione con uno existente (al crear)
5. **SIEMPRE** leer el comando existente completo antes de modificarlo

---

## PASO 0: Descubrimiento — Inventario de Comandos Existentes

Antes de la primera pregunta, Claude DEBE:

1. Listar todos los archivos en `.claude/commands/`:
   ```bash
   ls -la .claude/commands/*.md
   ```

2. Leer el contenido de cada comando para tener contexto completo de lo que ya existe.

3. Construir un inventario mental:
   - Nombre del comando
   - Proposito (primera linea del archivo)
   - Cantidad de lineas (LOC)
   - Si tiene `ARGUMENTS` o no
   - Tono/personalidad (formal, agresivo, tecnico, etc.)

Este inventario se usa en las preguntas posteriores para ofrecer opciones informadas.

---

## PASO 1: Pregunta Inicial — Crear o Modificar

```
AskUserQuestion:
  question: "Quieres crear un comando nuevo o modificar uno existente?"
  header: "Accion"
  options:
    - label: "Crear nuevo comando"
      description: "Disenar un comando desde cero con nombre, proposito y comportamiento personalizado"
    - label: "Modificar comando existente"
      description: "Editar un comando que ya existe — cambiar su comportamiento, agregar fases, ajustar tono"
    - label: "Duplicar y adaptar"
      description: "Tomar un comando existente como base y crear una variante con cambios"
    - label: "Eliminar comando"
      description: "Revisar y confirmar eliminacion de un comando que ya no se usa"
```

### Comportamiento segun respuesta:

**Crear nuevo comando** -> Ir a PASO 2A (Nombre)
**Modificar existente** -> Ir a PASO 2B (Seleccion)
**Duplicar y adaptar** -> Ir a PASO 2C (Seleccion + Nombre nuevo)
**Eliminar comando** -> Ir a PASO 2D (Confirmacion)

---

## PASO 2A: Nombre del Comando (solo para creacion)

```
AskUserQuestion:
  question: "Como quieres que se llame el comando? (sera invocado como /nombre)"
  header: "Nombre"
  options:
    - label: "Sugerir nombres"
      description: "Claude sugiere 3-4 nombres basados en el proposito que describas a continuacion"
    - label: "Ya tengo nombre"
      description: "Escribire el nombre exacto que quiero usar"
```

### Validaciones del nombre:
- Solo letras minusculas, numeros y guiones: `[a-z0-9-]+`
- No puede empezar ni terminar con guion
- No puede colisionar con comandos existentes
- No puede colisionar con comandos built-in de Claude Code (`help`, `clear`, `compact`, `config`, etc.)
- Maximo 30 caracteres
- Debe ser descriptivo (no `cmd1` o `test123`)

### Comandos built-in reservados (NO usar estos nombres):
- `help`, `clear`, `compact`, `config`, `cost`, `doctor`, `fast`
- `init`, `login`, `logout`, `memory`, `model`, `permissions`
- `review`, `status`, `terminal-setup`, `vim`, `bug`

Si el nombre colisiona, informar al usuario y pedir otro.

---

## PASO 2B: Seleccion de Comando Existente (solo para modificacion)

Presentar los comandos existentes como opciones:

```
AskUserQuestion:
  question: "Cual comando quieres modificar?"
  header: "Comando"
  options:
    - label: "/work"
      description: "Inicio de sesion de trabajo con mentor exigente (75 lineas)"
    - label: "/ux-polish"
      description: "Rondas de UX quick wins para pages/features (83 lineas)"
    - label: "/insult"
      description: "Revisor agresivo con personalidad vulgar mexicana (93 lineas)"
    - label: "/css-to-tailwind"
      description: "Convertidor batch de CSS raw a Tailwind @apply (187 lineas)"
```

Las opciones se generan DINAMICAMENTE del inventario del PASO 0.
Incluir LOC y descripcion corta para cada uno.

---

## PASO 2C: Duplicar y Adaptar

Misma seleccion que PASO 2B, pero despues preguntar el nombre nuevo (PASO 2A).
Leer el contenido completo del comando fuente como base.

---

## PASO 2D: Eliminacion

Mostrar el contenido del comando a eliminar y pedir confirmacion explicita.
Si el usuario confirma, eliminar con `rm` y reportar.

---

## PASO 3: Proposito y Alcance

```
AskUserQuestion:
  question: "Cual es el proposito principal de este comando? Describe en 1-2 oraciones que deberia hacer cuando se invoque."
  header: "Proposito"
  options:
    - label: "Automatizacion de codigo"
      description: "Refactorizar, limpiar, convertir, migrar codigo automaticamente"
    - label: "Auditoria / Revision"
      description: "Analizar codigo/UI y reportar hallazgos clasificados por severidad"
    - label: "Personalidad / Modo"
      description: "Activar un modo de interaccion especifico (tono, idioma, actitud)"
    - label: "Workflow / Proceso"
      description: "Guiar un flujo de trabajo con pasos definidos (deploy, testing, onboarding)"
```

### Seguimiento automatico:

Despues de la seleccion, Claude DEBE preguntar en texto libre:
> "Describeme en tus propias palabras que deberia hacer exactamente este comando. Cuanto mas detalle, mejor queda."

Esto se captura como el `Other` de AskUserQuestion o como un mensaje de seguimiento.

---

## PASO 4: Tono y Personalidad

```
AskUserQuestion:
  question: "Que tono debe tener el comando cuando se ejecute?"
  header: "Tono"
  options:
    - label: "Profesional directo"
      description: "Sin adornos, instrucciones ejecutables, como un manual tecnico. Ejemplo: /work"
    - label: "Agresivo mexicano"
      description: "Vulgar, energico, ataca el codigo malo. Leal al usuario. Ejemplo: /insult"
    - label: "Mentor paciente"
      description: "Explicativo, didactico, guia paso a paso sin presion"
    - label: "Silencioso eficiente"
      description: "Minimo texto, maximo accion. Solo reporta resultados, no explica. Ejemplo: /css-to-tailwind"
```

### Notas por tono:

**Profesional directo**:
- Estructura: Contexto -> Diagnostico -> Accion -> Cierre
- Sin emojis a menos que el usuario los pida
- Lenguaje imperativo: "Haz X", "Verifica Y", "Reporta Z"

**Agresivo mexicano**:
- Idioma: Espanol vulgar mexicano SIEMPRE
- Insultos van al CODIGO, nunca al usuario
- Autocritica cuando Claude se equivoca
- Metaforas coloridas y tecnicas

**Mentor paciente**:
- Explica el POR QUE de cada paso
- Ofrece alternativas cuando hay trade-offs
- Celebra progreso, no solo resultado final
- Pregunta antes de asumir

**Silencioso eficiente**:
- Cero explicaciones innecesarias
- Tablas de resumen en vez de parrafos
- Solo habla cuando hay error o decision requerida
- Output minimo: "N cambios en M archivos. Build limpio."

---

## PASO 5: Estructura y Fases

```
AskUserQuestion:
  question: "Como debe estar estructurado el flujo del comando?"
  header: "Estructura"
  options:
    - label: "Fases secuenciales"
      description: "Fase 1 -> Fase 2 -> Fase 3. Cada fase completa antes de avanzar. Ejemplo: /ux-polish (Auditoria -> Implementacion -> Verificacion)"
    - label: "Rondas iterativas"
      description: "Lotes de N cambios, build, reportar, preguntar si continuar. Ejemplo: /css-to-tailwind"
    - label: "Una sola pasada"
      description: "Ejecutar todo de principio a fin sin pausas intermedias"
    - label: "Interactivo continuo"
      description: "Preguntar al usuario en cada decision clave, como un wizard"
```

### Seguimiento para fases secuenciales:

```
AskUserQuestion:
  question: "Cuantas fases deberia tener?"
  header: "Fases"
  options:
    - label: "2 fases"
      description: "Analisis + Ejecucion"
    - label: "3 fases"
      description: "Analisis + Ejecucion + Verificacion"
    - label: "4+ fases"
      description: "Describire las fases que necesito"
```

### Seguimiento para rondas iterativas:

```
AskUserQuestion:
  question: "Cuantos cambios por ronda?"
  header: "Tamano ronda"
  options:
    - label: "5-8 cambios"
      description: "Lotes pequenos, mas control"
    - label: "8-12 cambios"
      description: "Balance entre velocidad y control (recomendado)"
    - label: "12-20 cambios"
      description: "Lotes grandes, menos interrupciones"
    - label: "Sin limite"
      description: "Aplicar todo lo que encuentre de una vez"
```

---

## PASO 6: Argumentos del Comando

```
AskUserQuestion:
  question: "El comando necesita argumentos del usuario al invocarlo?"
  header: "Argumentos"
  options:
    - label: "Si, un argumento libre"
      description: "El usuario escribe texto libre despues del comando. Ejemplo: /ux-polish POS"
    - label: "Si, argumentos con formato"
      description: "El usuario pasa flags o parametros estructurados. Ejemplo: /deploy --env staging"
    - label: "No, sin argumentos"
      description: "El comando se ejecuta tal cual, sin input adicional. Ejemplo: /work"
    - label: "Opcional"
      description: "Funciona sin argumentos pero acepta uno para limitar scope"
```

### Si tiene argumentos:

Claude DEBE incluir en el archivo generado:
```markdown
ARGUMENTS: $ARGUMENTS
```

Y referenciar `$ARGUMENTS` en las instrucciones donde se use el input del usuario.

---

## PASO 7: Reglas y Restricciones

```
AskUserQuestion:
  question: "Que restricciones criticas debe respetar el comando?"
  header: "Reglas"
  multiSelect: true
  options:
    - label: "No cambiar logica de negocio"
      description: "Solo cambios visuales, UX, cleanup — nunca tocar comportamiento funcional"
    - label: "Verificar build despues"
      description: "Correr dotnet build y/o npm run css:build para validar 0 errores"
    - label: "Respetar design tokens"
      description: "Usar variables CSS del design system, nunca hardcodear colores/sizes"
    - label: "Pedir confirmacion antes de borrar"
      description: "Nunca eliminar archivos o codigo sin confirmacion explicita del usuario"
```

### Reglas adicionales que SIEMPRE se incluyen (no se preguntan):

1. **DRY**: No repetir codigo de ningun tipo
2. **.NET 10 moderno**: Collection expressions, file-scoped namespaces, primary constructors
3. **Imports en _Imports.razor**: A menos que haya conflicto documentado
4. **CRLF line endings**: Proyecto Windows
5. **Sin emojis**: A menos que el usuario los pida explicitamente
6. **Verificar antes de celebrar**: Nunca decir "listo" sin haber comprobado que funciona

---

## PASO 8: Ejemplos de Interaccion (para comandos con personalidad)

Solo si el tono elegido en PASO 4 fue "Agresivo mexicano" o "Mentor paciente":

```
AskUserQuestion:
  question: "Quieres incluir ejemplos de como debe responder Claude cuando use este comando?"
  header: "Ejemplos"
  options:
    - label: "Si, generar ejemplos"
      description: "Claude genera 3-4 ejemplos de interacciones tipicas basados en el tono elegido"
    - label: "Si, yo doy ejemplos"
      description: "Voy a escribir frases de ejemplo que Claude debe usar como referencia"
    - label: "No, solo instrucciones"
      description: "El tono se describe en las instrucciones, sin ejemplos explicitos"
```

### Plantilla de ejemplos por tono:

**Agresivo mexicano**:
```markdown
## Ejemplos de Interacciones
- **Ataque**: "Que chingadera es este archivo de 500 lineas? Ni un pinche componente separado. Lo voy a destrozar, jefe."
- **Mejora**: [Codigo refactorizado con explicaciones]
- **Autocritica**: "La cague con esa regex, pero ya lo arregle. Perdon jefe."
- **Cuestionario**: "Este servicio inyecta 8 dependencias. Es un god object o hay razon? Dime y lo parto."
```

**Mentor paciente**:
```markdown
## Ejemplos de Interacciones
- **Explicacion**: "Voy a usar el patron Repository aqui porque nos permite cambiar la base de datos sin tocar la logica de negocio."
- **Alternativa**: "Podemos resolver esto con un Mediator o con inyeccion directa. El Mediator agrega una capa pero da mas flexibilidad. Tu que prefieres?"
- **Celebracion**: "Excelente — con este cambio el POS carga 40% mas rapido. Buen trabajo."
```

---

## GENERACION DEL ARCHIVO

Despues de completar TODAS las preguntas, Claude DEBE:

### 1. Mostrar Preview

Presentar el contenido COMPLETO del archivo generado en un bloque de codigo:

```
Aqui esta el comando generado. Revisa y dime si quieres ajustar algo antes de guardarlo:

[contenido completo del .md]
```

### 2. Pedir Confirmacion

```
AskUserQuestion:
  question: "El comando se ve bien? Lo guardo en .claude/commands/[nombre].md?"
  header: "Confirmar"
  options:
    - label: "Guardar tal cual"
      description: "Escribir el archivo y listo"
    - label: "Ajustar algo"
      description: "Quiero cambiar una parte antes de guardar"
    - label: "Empezar de nuevo"
      description: "Descartar y volver a hacer las preguntas desde el inicio"
```

### 3. Escribir Archivo

Usar la herramienta `Write` para crear/sobreescribir el archivo:
```
Write: .claude/commands/[nombre].md
```

### 4. Verificar

Confirmar que el archivo existe y tiene el contenido correcto:
```bash
wc -l .claude/commands/[nombre].md
head -3 .claude/commands/[nombre].md
```

Reportar: "Comando `/nombre` guardado — N lineas. Invocalo con `/nombre` en cualquier sesion."

---

## PLANTILLAS DE ESTRUCTURA

Segun el tipo de comando, usar estas plantillas como esqueleto:

### Plantilla: Automatizacion de Codigo

```markdown
# /nombre - Descripcion corta

ARGUMENTS: $ARGUMENTS

## Instrucciones

### Fase 1: Descubrimiento

1. Encontrar archivos relevantes usando Glob/Grep
2. Leer archivos en lotes de 5-8 en paralelo
3. Identificar patrones a modificar

### Fase 2: Ejecucion por Lotes

1. Aplicar cambios usando Edit tool
2. Reportar resumen por lote
3. Preguntar si continuar

### Fase 3: Verificacion

```bash
dotnet build && npm run css:build
```

## Reglas

- [reglas del PASO 7]

## Tabla de [Conversiones/Patrones/etc.]

| Antes | Despues |
|-------|---------|
| ... | ... |
```

### Plantilla: Auditoria / Revision

```markdown
# /nombre - Descripcion corta

ARGUMENTS: $ARGUMENTS

## Instrucciones

### Fase 1: Auditoria Exhaustiva (NO modificar nada todavia)

1. Encontrar TODOS los archivos del scope indicado
2. Leer CADA archivo completo
3. Clasificar hallazgos por severidad:

| Categoria | Ejemplo | Prioridad |
|-----------|---------|-----------|
| [critica] | ... | CRITICA |
| [alta] | ... | ALTA |
| [media] | ... | MEDIA |
| [baja] | ... | BAJA |

### Fase 2: Implementar por Rondas

Rondas de ~N cambios. Cada ronda:
1. Lista cambios ANTES de aplicar
2. Aplica cambios
3. Build verify
4. Reportar resumen

### Fase 3: Siguiente Ronda

Preguntar: "Ronda N completada — X cambios, build limpio. Sigo?"

## Reglas

- [reglas del PASO 7]

## Checklist por Tipo de Archivo

**[tipo1]:**
- [ ] ...
- [ ] ...

**[tipo2]:**
- [ ] ...
```

### Plantilla: Personalidad / Modo

```markdown
# Titulo descriptivo

## Introduccion

Descripcion del rol y personalidad que Claude debe adoptar.

## Rol y Personalidad

- **[rasgo 1]**: Descripcion
- **[rasgo 2]**: Descripcion
- **[rasgo 3]**: Descripcion

## Comportamiento

### Fases Principales

1. **[fase 1]**: Que hace Claude primero
2. **[fase 2]**: Que hace Claude despues

### Reglas Clave

- **Idioma**: ...
- **Tono**: ...
- **Restricciones**: ...

## Ejemplos de Interacciones

- **[tipo1]**: "Ejemplo de respuesta"
- **[tipo2]**: "Ejemplo de respuesta"
- **[tipo3]**: "Ejemplo de respuesta"
```

### Plantilla: Workflow / Proceso

```markdown
# /nombre - Descripcion corta

## Contexto

Descripcion del flujo de trabajo y cuando usarlo.

## Formato Operativo

### Inicio

1. Verificar estado (git status, procesos, etc.)
2. Pregunta inicial al usuario

### Durante la Sesion

1. Enfoque en tarea actual
2. Retroalimentacion continua
3. Documentar decisiones

### Cierre

1. Resumen de lo logrado
2. Tareas pendientes
3. Siguiente paso sugerido

## Conexion con la Mision VHouse

- Como esto ayuda a los animales
- Como esto ayuda a los clientes reales
```

---

## REGLAS DE CALIDAD PARA COMANDOS GENERADOS

### Minimos obligatorios:

| Criterio | Minimo | Ideal |
|----------|--------|-------|
| Lineas de codigo (LOC) | 50 | 100+ |
| Secciones con `##` | 3 | 5+ |
| Reglas/restricciones | 3 | 6+ |
| Ejemplos (si aplica) | 2 | 4+ |

### Estructura obligatoria:

Todo comando DEBE tener estas secciones (en orden):

1. **Titulo** — `# /nombre - Descripcion` (linea 1)
2. **Argumentos** — `ARGUMENTS: $ARGUMENTS` (si aplica, linea 3)
3. **Instrucciones** — `## Instrucciones` (el corazon del comando)
4. **Reglas** — `## Reglas` o `## Reglas Estrictas` (restricciones)

Secciones opcionales pero recomendadas:

5. **Contexto** — Por que existe este comando
6. **Ejemplos** — Como se ve en accion
7. **Checklist** — Verificaciones por tipo de archivo
8. **Tablas de referencia** — Mappings, conversiones, etc.

### Anti-patterns en comandos:

| Anti-pattern | Problema | Solucion |
|--------------|----------|----------|
| Instrucciones vagas | "Mejora el codigo" — que significa eso? | Especificar: "Convierte `new List<>()` a `[]`" |
| Sin reglas | Claude improvisa y puede romper cosas | Minimo 3 reglas explicitas |
| Sin verificacion | No se sabe si funciono | Incluir paso de build/test |
| Monolitico | Un bloque de texto sin estructura | Dividir en Fases/Pasos con headers |
| Sin ejemplos (para tonos) | Claude interpreta mal la personalidad | Minimo 3 ejemplos de interaccion |
| Reglas contradictorias | "Nunca cambiar logica" + "Refactorizar todo" | Revisar coherencia antes de guardar |

---

## FLUJO PARA MODIFICACION DE COMANDOS EXISTENTES

Cuando el usuario elige "Modificar existente":

### 1. Leer comando completo

```bash
cat .claude/commands/[nombre].md
```

### 2. Mostrar resumen

"El comando `/nombre` tiene N lineas con estas secciones: [lista]. Que quieres cambiar?"

### 3. Preguntar que modificar

```
AskUserQuestion:
  question: "Que aspecto del comando quieres modificar?"
  header: "Modificar"
  multiSelect: true
  options:
    - label: "Agregar nueva fase/seccion"
      description: "Insertar un paso o seccion que no existe"
    - label: "Cambiar tono/personalidad"
      description: "Ajustar como responde Claude cuando usa este comando"
    - label: "Agregar/cambiar reglas"
      description: "Modificar las restricciones y validaciones"
    - label: "Expandir contenido"
      description: "Hacer el comando mas detallado, agregar tablas, checklists, ejemplos"
```

### 4. Iterar con preguntas especificas

Segun lo seleccionado, hacer preguntas de seguimiento para cada area a modificar.

### 5. Aplicar cambios

Usar `Edit` tool para modificaciones quirurgicas (no reescribir todo el archivo).
Si los cambios son mayores al 50% del archivo, usar `Write` para reescritura completa.

### 6. Verificar

Mostrar diff o contenido final al usuario antes de confirmar.

---

## METRICAS DE COMANDOS EXISTENTES (referencia)

| Comando | LOC | Secciones | Reglas | Tiene Args | Tono |
|---------|-----|-----------|--------|------------|------|
| /work | 75 | 6 | 3 | No | Profesional |
| /ux-polish | 83 | 7 | 12 | Si ($ARGUMENTS) | Silencioso |
| /insult | 93 | 8 | 6 | Si ($ARGUMENTS) | Agresivo MX |
| /css-to-tailwind | 187 | 12 | 7 | No | Silencioso |

Esta tabla se actualiza DINAMICAMENTE al ejecutar el PASO 0.

---

## NOTAS FINALES

### Iteracion rapida

Si el usuario no esta satisfecho con el resultado, ofrecer:
1. "Quieres ajustar solo una seccion?"
2. "Quieres cambiar el tono completamente?"
3. "Quieres agregar mas reglas?"

Cada ajuste es una ronda de `AskUserQuestion` + `Edit`.

### Consistencia con el ecosistema

Todo comando generado DEBE:
- Respetar las reglas de `.claude/rules/` (DRY, .NET 10, imports, etc.)
- Conectar con la mision VHouse ("Como esto ayuda a los animales?")
- Ser invocable inmediatamente despues de crearlo (sin setup adicional)
- Usar `AskUserQuestion` en vez de preguntas en texto plano cuando hay opciones claras

### Sobre el tamanho

- Comandos cortos (<50 LOC) son sospechosos — probablemente les falta detalle
- Comandos largos (>300 LOC) son normales si tienen tablas de referencia (como /css-to-tailwind)
- La longitud debe ser proporcional a la complejidad del comportamiento deseado
- Nunca inflar artificialmente — cada linea debe aportar valor

---

_Documentado: 2026-03-07 | Meta-comando para gobernarlos a todos_
