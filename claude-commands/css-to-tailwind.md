# CSS to Tailwind — Zero-CSS Refactorizador

## Vision: Only-Tailwind / Zero-CSS

Este comando NO es un traductor de propiedades CSS a clases Tailwind. Es un **refactorizador** que investiga como Tailwind v4 elimina la necesidad de CSS raw por completo.

Cuando encuentres CSS raw, no busques "la clase equivalente" — investiga como la comunidad Tailwind **resuelve ese problema de manera idiomatica**. A veces la respuesta no es una clase sino un cambio de estructura:

- Un `::before` con content se reemplaza con un `<span>` + utilidades
- Un `@keyframes` custom se reemplaza con `animate-spin`, `animate-pulse`, etc.
- Un `@media (max-width: 768px)` se reemplaza con variantes responsive (`md:`, `lg:`) en el markup
- Un `:hover` en CSS se reemplaza con `hover:` directamente en la clase
- Un `.dark .element` se reemplaza con `dark:` en el elemento

**Si la refactorizacion requiere varios niveles** (CSS + markup + componente), proponlo como plan al usuario antes de aplicar. Usa `WebSearch` para investigar patrones only-Tailwind cuando no tengas certeza.

El objetivo es que cada archivo CSS tienda a cero lineas. No mañana — pero cada ronda debe acercarnos.

---

## Instrucciones

### Fase 1: Descubrir archivos

1. Usa `Glob` para encontrar archivos `.css` en `src/VHouse.UI/wwwroot/css/` (excluyendo `dist/` y `output.css`).
2. Si el usuario especifico un directorio o archivo, limitar el scope a eso.
3. Si no especifico nada, usar los archivos **modificados recientemente** (git diff o mtime).

### Fase 2: Leer y convertir por lotes

1. Lee archivos en lotes de **5-8 archivos** en paralelo (Read tool).
2. Para cada archivo, analiza el CSS con criterio: que se puede convertir directo, que requiere refactorizacion multinivel, que son valores magicos.
3. Aplica conversiones directas usando el Edit tool.
4. Reporta un resumen por lote: `N conversiones en M archivos`.
5. Si hay propuestas multinivel, listarlas como plan para el usuario.
6. Pregunta si continuar al siguiente lote.

### Fase 3: Verificar build

Despues de aplicar TODOS los lotes:

```bash
npm run css:build && dotnet build src/VHouse.UI/VHouse.UI.csproj
```

---

## Que Convertir

Usa tu conocimiento de Tailwind CSS. No necesitas tabla — aplica criterio:

### Convertir con confianza (directo a @apply)

Propiedades donde el mapping CSS -> Tailwind es 1:1:

- **Layout**: display, position, float, clear, box-sizing
- **Flexbox**: flex-direction, flex-wrap, flex-grow, flex-shrink, align-items, justify-content, align-self, order
- **Grid**: place-items, place-content, grid-auto-flow, align-self
- **Spacing**: margin/padding cuando el valor es `0` o `auto`
- **Sizing**: width/height con valores keyword (`100%`, `auto`, `100vh`, `min-content`, `max-content`, `fit-content`)
- **Typography**: text-align, text-transform, text-decoration, font-style, font-weight, white-space, text-overflow
- **Visual**: overflow, visibility, opacity, cursor, pointer-events, user-select, appearance, resize, object-fit, list-style
- **Position values**: top/right/bottom/left/inset cuando el valor es `0`
- **Borders**: border `0`/`none`, border-radius `0`/`9999px`/`50%`
- **Background**: `transparent`, `none`
- **Z-index**: valores estandar de Tailwind (0, 10, 20, 30, 40, 50, auto)
- **Transitions**: transition-property, transition-duration, transition-timing-function, will-change
- **Misc**: outline `none`/`0`, transform `none`

### Proponer como refactorizacion multinivel (no aplicar sin plan)

Estas requieren cambios en CSS + markup + posiblemente el componente Razor:

- **Media queries** (`@media`): En Tailwind se resuelven con variantes responsive (`sm:`, `md:`, `lg:`, `xl:`, `2xl:`) directamente en el markup. Convertir requiere mover la logica del CSS al `.razor`
- **Pseudo-clases** (`:hover`, `:focus`, `:active`, `:disabled`, `:first-child`): En Tailwind son variantes (`hover:`, `focus:`, `active:`, `disabled:`, `first:`). Requiere mover al markup
- **Pseudo-elementos** (`::before`, `::after`): En Tailwind v4 son `before:` y `after:` con `content-['']`, pero a veces es mejor reemplazar con un `<span>` real
- **Dark mode** (`prefers-color-scheme: dark`, `.dark`): En Tailwind es la variante `dark:`. Requiere mover al markup
- **Selectores complejos** (`.parent > .child:nth-child(2)`, `.foo + .bar`): No tienen equivalente en Tailwind. Evaluar si el componente se puede reestructurar o si es CSS que debe quedarse

### NO convertir — dejar como esta

- Propiedades con `var()`, `calc()`, `color-mix()`, `clamp()` — dependen del design system
- Propiedades dentro de `@keyframes` — pero proponer reemplazo con `animate-*` si existe
- Shorthand ambiguos con multiples valores (ej: `margin: 10px 20px 30px`)
- Lineas que ya tienen `@apply`

### Reportar como deuda tecnica

Valores magicos — numeros, colores, sizes hardcodeados que no pertenecen a ningun token. **Reportar al final de cada ronda** en tabla:

| Archivo | Linea | Propiedad | Valor magico | Sugerencia |
|---------|-------|-----------|--------------|------------|
| `_header.css` | 42 | `color` | `#3b82f6` | Deberia ser `var(--brand-primary)` o token |
| `_grid.css` | 18 | `padding` | `13px` | No esta en escala Tailwind, definir token |

---

## Reglas

1. **NUNCA** convertir propiedades dentro de `@keyframes` — pero si el keyframe tiene equivalente en Tailwind (`animate-spin`, `animate-pulse`, `animate-bounce`, `animate-ping`), proponer el reemplazo completo
2. **NUNCA** convertir propiedades que usan `var()`, `calc()`, `color-mix()`, `clamp()`
3. **NUNCA** tocar lineas que ya tienen `@apply`
4. **NUNCA** convertir shorthand ambiguos (ej: `margin: 10px 20px 30px`)
5. Si una regla CSS ya tiene un `@apply` existente, **agregar** las clases al `@apply` existente en vez de crear uno nuevo
6. Si un `@apply` crece a **12+ clases**, es senal de que el selector hace demasiado — proponer dividir en sub-componentes o repensar la estructura
7. Preservar comentarios, orden de propiedades no-convertidas, y whitespace/indentacion
8. Si el archivo tiene menos de 3 propiedades convertibles, **skip** — no vale la pena el churn
9. **Cuidado con `!important`**: Si la propiedad original tiene `!important`, la conversion a `@apply` lo pierde. Marcar con `!` en Tailwind (`@apply !border-0`) o reportar como caso especial
10. **Selectores complejos** (combinadores `>`, `+`, `~`, pseudo-selectors `:nth-child`, `:not`) NO se pueden expresar en `@apply` — evaluar si el componente se puede reestructurar para eliminar la dependencia del selector, o dejarlo como CSS
11. **SIEMPRE** reportar valores magicos encontrados (colores hex, pixels custom, numeros sueltos) como deuda tecnica — no convertirlos, no ignorarlos

---

## Cierre: Build y Verificacion

Al terminar TODO el trabajo del comando, pregunta con `AskUserQuestion`:

- **"Build + Chrome DevTools"**: Correr `dotnet build`, reportar warnings/errores, abrir Chrome DevTools, tomar screenshot y verificar visualmente, reportar errores de consola
- **"Solo build"**: Correr `dotnet build` y reportar warnings/errores sin abrir Chrome
- **"Yo lo hago con /build-check"**: Terminar sin verificar — el usuario correra `/build-check` manualmente
