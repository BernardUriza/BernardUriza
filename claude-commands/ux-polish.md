# /ux-polish - Refactorización UX y Patrones para cualquier page/feature

ARGUMENTS: $ARGUMENTS

## Instrucciones

Ejecuta rondas iterativas de refactorización UX/patrones en el area que el usuario especifique: **$ARGUMENTS**

El enfoque principal es **detectar anti-patrones estructurales** y reemplazarlos con los componentes compartidos del sistema (FormField, FormSection, BaseModal, DataTableCard, etc.). Las mejoras visuales cosméticas son secundarias.

### Fase 1: Auditoría Exhaustiva (NO modificar nada todavía)

1. **Encontrar TODOS los archivos** del feature/page indicado:
   - `.razor` components (markup)
   - `.razor.cs` code-behinds
   - `.css` stylesheets en `wwwroot/css/`
   - Partials y sub-componentes relacionados
   - Design tokens relevantes (`_tokens.css`, `_variables.css`)

2. **Leer CADA archivo completo** — no adivinar, no asumir.

3. **Clasificar hallazgos** en estas categorías (de mayor a menor impacto):

| Categoría | Ejemplo | Prioridad |
|-----------|---------|-----------|
| Form HTML crudo sin FormField | `<input>` + `<label>` manuales que deberían ser `<FormField>` | CRITICA |
| Form sin FormSection | Grupos de campos sin estructura, divs genéricos en vez de `<FormSection>` con Layout | CRITICA |
| Modal sin BaseModal | `<div class="modal-*">` hecho a mano en vez de `<BaseModal>` | CRITICA |
| Componente monolítico (300+ líneas) | Archivo .razor con todo mezclado, sin sub-componentes | ALTA |
| DRY violation (HTML repetido) | Mismo bloque HTML/CSS copy-pasteado en 3+ archivos | ALTA |
| @using redundante | Import que ya está en `_Imports.razor` | ALTA |
| @namespace redundante | `@namespace` en archivo que ya está en la carpeta correcta | ALTA |
| Select/dropdown sin VhSelect | `<select>` HTML crudo que debería usar `FormField Type="FormInputType.Select"` | ALTA |
| Checkbox sin FormField Check | `<input type="checkbox">` crudo que debería ser `FormField Type="FormInputType.Check"` | MEDIA |
| Código viejo .NET | `new List<>()` en vez de `[]`, namespace con llaves, constructor boilerplate | MEDIA |
| Ilegible/invisible | Texto < 11px, color invisible en dark bg | BAJA |
| Touch target insuficiente | Botón < 44px | BAJA |
| Empty state pobre | Icono 16px, sin hint text | BAJA |
| CSS huérfano | Keyframes sin referencia, clases muertas | BAJA |

### Fase 2: Implementar por Rondas

Ejecuta rondas de ~8-12 cambios cada una. Cada ronda:

1. **Lista los cambios** ANTES de aplicarlos (tabla con #, descripción, archivo, categoría)
2. **Prioriza**: CRITICA primero, luego ALTA, luego MEDIA, BAJA al final
3. **Aplica todos los cambios** del lote
4. **Corre `dotnet build`** para verificar 0 errores
5. **Reporta** un resumen de la ronda

### Fase 3: Siguiente Ronda

Después de cada ronda, pregunta: "Ronda N completada — X cambios, build limpio. ¿Sigo?"

---

## Patrones de Reemplazo

### HTML Form → FormField + FormSection

**Antes (anti-patrón):**
```razor
<div class="form-group">
    <label for="name">Nombre</label>
    <input type="text" id="name" @bind="Model.Name" placeholder="Ingresa nombre" />
</div>
<div class="form-group">
    <label for="price">Precio</label>
    <input type="number" id="price" @bind="Model.Price" />
</div>
```

**Después (correcto):**
```razor
<FormSection Title="Datos del Producto" Icon="package" Layout="FormLayout.TwoColumn">
    <FormField TValue="string" Id="name" Label="Nombre" Type="FormInputType.Text"
               @bind-Value="Model.Name" Placeholder="Ingresa nombre" Required />
    <FormField TValue="decimal" Id="price" Label="Precio" Type="FormInputType.Number"
               @bind-Value="Model.Price" Required />
</FormSection>
```

### HTML Select → FormField Select

**Antes:**
```razor
<select @bind="Model.Category">
    <option value="">Seleccionar...</option>
    @foreach (var cat in _categories)
    {
        <option value="@cat.Id">@cat.Name</option>
    }
</select>
```

**Después:**
```razor
<FormField TValue="Guid" Id="category" Label="Categoría" Type="FormInputType.Select"
           @bind-Value="Model.Category" Options="_categoryOptions" Required />
```

**Nota**: Las opciones deben ser `IEnumerable<VhSelectOption<T>>`. Si el código actual usa un loop `@foreach` para `<option>`, convertir a `VhSelectOption` list.

### HTML Checkbox → FormField Check

**Antes:**
```razor
<label>
    <input type="checkbox" @bind="Model.IsActive" /> Activo
</label>
```

**Después:**
```razor
<FormField TValue="bool" Id="is-active" Label="Activo" Type="FormInputType.Check"
           @bind-Value="Model.IsActive" />
```

### Div Modal → BaseModal

**Antes:**
```razor
@if (_showModal)
{
    <div class="modal-backdrop" @onclick="CloseModal">
        <div class="modal-container">
            <div class="modal-header">
                <h3>Título</h3>
                <button @onclick="CloseModal">×</button>
            </div>
            <div class="modal-body">@* contenido *@</div>
            <div class="modal-footer">
                <button @onclick="SaveAsync">Guardar</button>
            </div>
        </div>
    </div>
}
```

**Después:**
```razor
<BaseModal Visible="@_showModal" Title="Título" HeaderIcon="edit"
           Size="ModalSize.Medium" IsProcessing="@_saving"
           CloseOnBackdrop="true" OnClose="@(() => _showModal = false)">
    <ChildContent>@* contenido *@</ChildContent>
    <FooterContent>
        <button class="btn-save" @onclick="SaveAsync">Guardar</button>
    </FooterContent>
</BaseModal>
```

### Componente Monolítico → Split

**Señales de split necesario:**
- Archivo > 200 líneas de markup
- `@code` block > 100 líneas → extraer a `.razor.cs`
- 3+ secciones visuales distintas → cada una = sub-componente
- 10+ `@inject` → demasiadas responsabilidades

---

## Reglas Estrictas

- **NUNCA cambiar lógica de negocio** — solo estructura, UX, patrones, cleanup
- **NUNCA romper el build** — verificar después de cada ronda
- **Respetar design tokens** — usar `var(--pos-*)` / `var(--text-*)`, no hardcodear colores
- **`@using` van en `_Imports.razor`** a menos que haya conflicto documentado
- **`@namespace` es redundante** si el archivo está en la carpeta correcta — eliminarlo
- **`.NET 10 moderno`**: `[]` en vez de `new()`, file-scoped namespaces, collection expressions
- **FormField es el estándar** — todo `<input>`, `<select>`, `<textarea>` crudo debe migrar
- **FormSection agrupa campos** — todo grupo de FormFields debe estar en un FormSection con Layout apropiado
- **BaseModal es el estándar** — todo modal hecho a mano debe migrar
- **Si un FormField Type no existe para el caso**, usar `FormInputType.Custom` con `ChildContent`
- **Al migrar selects**, crear la lista de `VhSelectOption<T>` donde se carguen los datos
- **Keyboard shortcuts**: overlays/modals deben cerrarse con Escape

### Checklist por Archivo

**Razor:**
- [ ] Sin `<input>`, `<select>`, `<textarea>` crudos (usar FormField)
- [ ] Sin `<label>` + `<input>` manuales (FormField incluye label)
- [ ] Sin `<div class="modal-*">` manuales (usar BaseModal)
- [ ] Campos agrupados en FormSection con Layout correcto
- [ ] Sin `@namespace` redundante
- [ ] Sin `@using` que ya esté en `_Imports.razor`
- [ ] `[]` en vez de `new()` para defaults de Parameters
- [ ] Archivo < 300 líneas (si no, split)
- [ ] `@implements IDisposable` si hay timers/subscriptions

**CSS:**
- [ ] Usa tokens del design system
- [ ] Sin clases huérfanas
- [ ] Sin keyframes sin referencia

**Code-behind (.cs):**
- [ ] Sin dead injections (servicios inyectados pero nunca usados)
- [ ] Timers con Dispose correcto
- [ ] Primary constructors donde aplique

---

## Cierre: Build y Verificacion

Al terminar TODO el trabajo del comando, pregunta con `AskUserQuestion`:

- **"Build + Chrome DevTools"**: Correr `dotnet build`, reportar warnings/errores, abrir Chrome DevTools, tomar screenshot y verificar visualmente, reportar errores de consola
- **"Solo build"**: Correr `dotnet build` y reportar warnings/errores sin abrir Chrome
- **"Yo lo hago con /build-check"**: Terminar sin verificar — el usuario correra `/build-check` manualmente
