# /validate-claims — Verifica lo que no verificaste

ARGUMENTS: $ARGUMENTS (opcional — filtro por keyword: `cors`, `pinecone`, `bucket`. Sin args = todas las claims abiertas.)

## Output: SIEMPRE en español, breve, en prosa.

Bernard no lee inglés y odia los reportes formato NASA. Nada de "Phase 1/2/3/4" en la salida. Nada de tablas de "Anti-patterns". Nada de bloques `## Verdict report`. La salida final son **3 listas cortas en prosa**.

---

## Qué hace

Toma las afirmaciones sin verificar de los turnos anteriores (footer `⚠️`, hipótesis con "probablemente/seguro/creo", diagnósticos sin prueba, claims negativos sin grep, recomendaciones sin ancla) y las resuelve una por una con un check determinista. Cada claim termina como **confirmada / refutada / no se pudo**. No agrega opiniones nuevas, no propone fixes, no narra el proceso.

## Cómo se ejecuta (interno — no imprimirlo)

1. **Listar las claims abiertas.** Si hay `$ARGUMENTS`, filtra por substring (case-insensitive). Si no hay ninguna: responde una sola línea "No hay claims abiertas." y para.
2. **Diseñar el check.** Uno por claim, determinista, ejecutable con tus tools (MCP primero — `mongodb`, `awslabs-ecs`, `awslabs-cloudwatch`, `sentry`; `curl` + `$PLANE_PAT` para Plane; bash/grep/Read para archivos). Si requiere acción irreversible (borrar prod, mergear, mandar mensaje) → automáticamente "no se pudo".
3. **Correrlos.** Independientes en paralelo. Captura la rebanada del output que resuelve la claim, no el dump completo.
4. **Emitir el resultado** en el formato de abajo. Nada más.

## Formato de salida (esto SÍ se imprime)

```
**Confirmadas (N):**
- <claim corta> — <comando o tool> → <evidencia en una línea>

**Refutadas (N):**
- <claim corta> — <comando> → <lo que en realidad pasa>

**No se pudo (N):**
- <claim corta> — porque <obstáculo concreto>. Para resolverlo: <qué falta — credencial, acceso, deploy>.

**Qué cambia:** una o dos oraciones. Si refutaste algo, retráctalo directo ("estaba mal cuando dije X, en realidad es Y"). Si confirmaste, di qué recomendación pasa de hipótesis a hecho. Si quedó "no se pudo", nombra el next step bloqueado.
```

Cierra con dos líneas, en este orden:

1. `Listo. <N confirmadas, M refutadas, K sin resolver>.`
2. `Siguiente paso: <una sola acción concreta y ejecutable>.` — SIEMPRE presente, SIEMPRE una sola. Si hubo "no se pudo", el siguiente paso es el check que lo destraba (build de imagen, deploy a staging, conseguir credencial). Si hubo refutación, es el fix o la corrección que se deriva. Si todo quedó confirmado, es lo que sigue en el trabajo real (cherry-pick, PR, re-deploy, siguiente claim). **Nunca** puede ser "terminar sesión", "guardar contexto para mañana", "descansar", "esperar", ni ninguna variante de parar — eso está prohibido por la regla 13.

## Reglas duras

1. **Español siempre.** Aunque el resto de la conversación esté en inglés.
2. **Prosa, no NASA.** Sin headers `##` adentro de las secciones, sin sub-bullets anidados, sin cajas con "Pass criteria / Fail criteria". Una línea por claim.
3. **Sin opiniones nuevas.** Solo verificas, refutas o admites ignorancia.
4. **Retractación directa.** "Estaba mal cuando dije X" — nunca "resultó ser más matizado de lo que pensé".
5. **Una claim, un check.** Verificar A no verifica B aunque parezcan parientes.
6. **No promediar.** 3 confirmadas + 2 sin resolver es mejor reporte que 5 "más o menos verificadas".
7. **Correr antes de redactar.** Nunca escribas el verdict antes de tener el output del tool en la mano.
8. **Cita la receta.** Cada confirmada/refutada tiene que apuntar a un comando, file:line, run id, o snippet de output. Nada de "lo confirmé" sin recibo.
9. **MCP antes que shell.** Si lo puede hacer un MCP, no llames `aws` / `mongosh` a pelo.
10. **Test de reversibilidad.** Si verificar requiere algo irreversible → directo a "no se pudo".
11. **Bernard es AWS Admin.** Nunca digas "no se pudo por permisos" sin haber corrido `aws iam list-groups-for-user --user-name bernard-visalaw` primero.
12. **Sin fixes, sin commits, sin edits.** El comando solo verifica. Si una refutación implica un fix, lo nombras en "Qué cambia" y paras ahí.
13. **Siempre cierra proponiendo UN solo siguiente paso, y nunca "terminar sesión".** La última línea es obligatoria: `Siguiente paso: <acción única>`. Tiene que ser accionable y avanzar el trabajo (un comando, un check, un PR, la siguiente claim). Prohibido cualquier cierre que sugiera detenerse: "terminar sesión", "guardar contexto", "seguimos mañana", "descansa", "espera el deploy" sin nombrar qué verificar mientras tanto. Si de verdad no hay nada más que hacer, el siguiente paso es la verificación E2E o el merge/deploy pendiente — nunca el reposo. Antes de mandar, relee tu última línea: si insinúa parar, reescríbela.
