# Historial de cambios de PRC AI 2.0

Qué cambió, por qué y qué se aprendió en cada paso. El cómo se usa está en el
[README](README.md); aquí queda la razón de cada decisión, para no volver a
discutirla sin datos nuevos.

Las fechas son las de los commits. Lo más nuevo va arriba.

---

## 2026-11-15 — Gemma por defecto

**Commit:** `636d930`

**Qué cambia.** Sin `-Provider`, sin `AI_PROVIDER` y sin `settings.json`, `AI`
arranca con `gemma` (Gemma 4 E4B en el llama-server local de
`http://127.0.0.1:8080`). Antes arrancaba con `xai` (Grok).

**Por qué.** Lo pidió el dueño. Además `xai` sin `XAI_API_KEY` no arrancaba y
mandaba la conversación a la nube. `gemma` no pide clave y nada sale de la
laptop, salvo las búsquedas en internet cuando hacen falta.

**Qué no cambia.** El orden de precedencia sigue siendo `-Provider`,
`AI_PROVIDER`, `settings.json` y, si no hay nada, el de fábrica. Grok sigue
disponible con `-Provider grok`.

---

## 2026-11-15 — Guardar un comando conversando

**Commits:** `26f0b63` (el diálogo) y `d67fcd6` (la guía del modelo).

**Qué cambia.** Basta pedirlo en el chat («agrégame un comando para ver mi IP
pública») y se abre un diálogo de preguntas fijas:

1. Si no se da el comando, el chat pregunta qué dato se quiere y el modelo
   propone uno. Lo propuesto pasa por las mismas reglas que lo tecleado; si no
   las pasa, se le dice por qué y se le dan dos intentos más.
2. Se enseña el comando, el veredicto de las reglas, a qué servidor sale y la
   explicación del modelo, y se pregunta si vale o qué cambiarle.
3. Se piden el nombre y para qué sirve, con una sugerencia que se acepta con
   Enter.
4. Las preguntas se cierran con un resumen y **una** confirmación.
5. Se prueba el comando y se enseña el resultado. Solo se guarda si la prueba
   funciona y devuelve algo.

«cancelar» corta el diálogo en cualquier momento.

**Decisiones.**
- **Las preguntas son fijas**, no las redacta el modelo, para que el diálogo
  no dependa de que el modelo se acuerde de pedir confirmación.
- **Una prueba que no devuelve nada cuenta como fallo.** Antes se guardaba un
  comando que no servía para nada.
- **Lo abren las frases que empiezan por «agrega», «añade», «guarda» o
  «registra» y nombran un comando.** «Crea un comando de git para...» no lo
  abre, porque pide que se escriba uno, no que se guarde.
- **El nombre que propone el modelo se limpia** de verbos y relleno y se deja
  en dos palabras, porque es lo que dispara el atajo. Con `ip-publica-obtener`,
  «¿cuál es mi IP pública?» no lo habría disparado.
- **La guía del modelo pide el dato por su propiedad, no buscando un texto.**
  Para «cuánto lleva encendido el equipo», Gemma 4 E4B proponía
  `systeminfo | Select-String "Fecha de último arranque"`, que en un Windows
  en inglés no devuelve nada (3 de 3). La guía dice ahora que ese texto cambia
  con el idioma y trae ejemplos con `Get-CimInstance`. Con eso propone
  `Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty LastBootUpTime`
  (3 de 3).

**Cómo se probó.** Once conversaciones con el modelo de verdad y las
respuestas del usuario ya escritas: dato sin comando, cambios, comando y
nombre dados, petición dañina, comando dañino pegado, «no» final, cancelar a
mitad, prueba que falla, prueba vacía y nombre repetido. Además, 23 frases
para comprobar qué abre el diálogo y qué no. Todas terminaron como debían.
El dueño lo probó después tecleando en la consola y funcionó.

---

## 2026-11-15 — Comandos de solo lectura guardados

**Commit:** `a7b4b1b`

**El problema.** «¿Cuál es mi IP pública?» no tenía respuesta. No está en el
equipo: hay que preguntársela a un servidor de fuera (por ejemplo
`Invoke-RestMethod -Uri https://api.ipify.org`).

**Qué cambia.** El usuario guarda comandos de PowerShell de solo lectura
(`/comando agregar <nombre> <comando>`, y desde `26f0b63` también
conversando) y el modelo los pide por su nombre con la herramienta
`comando_guardado`.

**La decisión principal: las reglas deciden, el modelo solo explica.** El
dueño pidió que «el chat verifique» si un comando es peligroso. Se acordó que
el veredicto no lo dé el modelo, porque un modelo de 4B se puede equivocar o
dejarse convencer, sino unas reglas fijas en `lib/comandos.ps1`:

- **El texto se analiza con el analizador de PowerShell**
  (`Parser::ParseInput`). Tiene que ser una sola canalización con argumentos
  constantes, y la lista de nodos permitidos es cerrada: fuera variables,
  sustituciones, paréntesis, bloques, métodos, tipos, redirecciones,
  comentarios, `;`, `&` y `.`.
- **Cada cmdlet sale de una lista cerrada** (`$AI_CMD_CMDLETS`), con su nombre
  completo y desde un módulo de la carpeta de Windows. Los programas
  (`$AI_CMD_EXES`) tienen que estar en System32, firmados por Microsoft y con
  formas de argumentos permitidas.
- **Cada parámetro sale de la lista de su comando.** Las abreviaturas y los
  posicionales los resuelve `StaticParameterBinder` antes de comparar.
- **Lo que sale a internet:** https, dirección fija, servidor público, GET,
  sin redirecciones y solo como primer comando.
- **Fuera a propósito:** leer ficheros, el registro, el portapapeles y los
  sucesos, y `ForEach-Object` (llamaría a métodos).

**El texto no se ejecuta nunca.** De la validación sale un plan, y lo que se
ejecuta es el plan, pieza a pieza (`AddCommand` / `AddParameter`), en un
espacio de ejecución aparte, con plazo de 15 s y un tope de 4.000 caracteres
de salida. Cada ejecución vuelve a pasar las reglas, así que un
`comandos.json` cambiado a mano no cuela nada. Al arrancar, los comandos se
cargan sin validar (costaba 0,8 s); se validan al usarlos.

**Otros detalles.**
- Tras la salida de un comando guardado no se ofrecen más herramientas en ese
  turno.
- El atajo se dispara cuando todas las palabras del nombre aparecen en la
  pregunta, en cualquier orden.
- La salida va al modelo con la indicación de no añadirle unidades: con los
  segundos de procesador, el modelo les ponía «%».

**Cómo se probó.** 158 comandos contra las reglas (29 pasan y 129 se
rechazan; 239 comprobaciones contando la red), la ejecución, el guardado y un
`comandos.json` manipulado. En vivo, con Gemma 4 E4B, Gemma 3 4B y Qwen3 8B.

**Para ampliar lo permitido** se añaden entradas a `$AI_CMD_CMDLETS` o a
`$AI_CMD_EXES`. Nada más.

---

## 2026-11-15 — Lo que el equipo ya sabe

**Commit:** `8aa6224`

**El problema.** El dueño preguntó en la terminal por su IP y el modelo le
contestó que no podía saberla. La misma función ya existía en la interfaz web
de Gemma Portable, pero **las dos aplicaciones tienen código separado**: lo
hecho en una no llega a la otra.

**Qué cambia.** `lib/equipo.ps1`, con tres piezas:

1. **El reloj** va en la instrucción de sistema de cada petición: hora, fecha
   y zona horaria del equipo.
2. **El atajo:** si la pregunta pide a las claras un dato de este equipo, se
   lee antes de preguntar al modelo y viaja pegado a la pregunta, solo en esa
   petición.
3. **La herramienta `datos_equipo`**, para lo que el atajo no reconoce.

Son ocho lecturas fijas y de solo lectura: batería, red, equipo, sistema,
procesador, memoria, disco y gráfica. Del modelo llega el nombre de una
lectura, nunca una orden, y ninguna lectura sale a internet. Lo que Windows
no da se dice que no se pudo leer.

**Errores encontrados y corregidos.**
- **El atajo dio un dato falso.** «¿Qué procesador trae la Lenovo Legion 5?»
  se contestó con el procesador de esta laptop. Ahora el atajo exige el tema
  **y** una marca de «este equipo» («mi», «tengo», «esta laptop»), y se
  anula si el mensaje nombra otro aparato, una marca, a otra persona o una
  computadora cualquiera, o si pide una explicación, un cómo se hace, código o
  una compra.
- **Con la herramienta a la vista, E4B dejó de buscar** «¿cuánta batería
  tiene el iPhone 15?» (3 de 3). Si se nombra otro aparato no se lee nada ni
  se ofrece la herramienta.
- **E4B volvía a pedir la herramienta** después del atajo. Ya no se le
  ofrece si el atajo ya leyó.
- **El modelo repetía la nota del reloj** («No hace falta internet.»). Se
  reescribió la nota.
- **La IP pública:** la línea dice que no está en el equipo, porque la
  asigna el proveedor de internet, y que la de arriba es la local.

**Gemma 3 4B se queda sin herramientas** (`Tools = $false` en
`lib/providers.ps1`). No sabe pedirlas: con `buscar_web` a la vista no
buscaba y contestaba «Según búsqueda web, el dólar está a 37 córdobas» sin
haber buscado (3 de 3), y con `datos_equipo` inventaba una IP y un porcentaje
de batería. Sin herramientas dice que no puede buscar, y `/buscar` y el atajo
le siguen sirviendo.

**Cómo se probó.** En vivo, con Gemma 4 E4B (34 preguntas, con y sin
internet), Gemma 3 4B (18) y Qwen3 8B (3). Además, 60 frases para el
reconocimiento del atajo.

---

## 2026-11-14 — Búsqueda en internet

**Commit:** `5ceef78`

El modelo puede llamar a `buscar_web` (DuckDuckGo HTML y las dos primeras
páginas legibles), pero solo si en ese momento hay salida a internet. Si no
la hay, contesta sin buscar y lo avisa. Las fuentes se enseñan al final.
Nuevos: `/buscar`, `/web on|off`, `-NoWeb`, `"web": false` y la línea
Internet en `-Check`.

---

## 2026-11-14 — `gemma` pasa a ser Gemma 4 E4B

**Commit:** `3f6ca2b`

La evaluación de Gemma Portable comparó los modelos sobre 181 preguntas con
respuesta libre. Gemma 4 E4B acertó el 96,7 % con 1 dato falso, y Gemma 3 4B
el 63,5 % con 57, a cambio de unos 7,6 s por turno en vez de 4–5. El
proveedor `gemma` pide desde entonces `gemma-4-e4b` (alias `gemma4`, `e4b`,
`llama`, `llamacpp`), y Gemma 3 4B queda como la entrada `gemma3`.

---

## 2026-10-08 — Modelos locales sobre llama-server

**Commit:** `d496be4`

Entradas `gemma` y `qwen` contra un mismo llama-server en modo router
(`127.0.0.1:8080`), con plazo de espera por proveedor (`Timeout`) y un texto
de ayuda cuando el servidor está parado (`Hint`). Un flujo que se corta sin
terminar es un error, no una respuesta válida. El `model` de `settings.json`
solo se aplica a su proveedor: `grok-4.3` no existe en un servidor local.

---

## 2026-09-03 — PRC AI 2.0

**Commits:** `72d4517`, `3da8c4b` y `373b2fc`

Reescritura completa sobre PowerShell 5.1, con un núcleo HTTP propio y
streaming SSE, una tabla de proveedores (OpenAI, xAI, Ollama), README, claves
en `HKCU\Environment` con `Set-AIKey` y licencia MIT.

---

## Reglas de trabajo que salieron de todo esto

- **Ningún dato falso.** Ante la duda, el programa dice que no lo sabe o que
  no lo pudo leer. Un atajo que pega datos a la pregunta tiene que exigir una
  marca de «este equipo».
- **Lo que decide la seguridad es código fijo, no el modelo.** El modelo
  explica y propone; las reglas aceptan o rechazan.
- **Cada `.ps1` necesita BOM.** Después de editar hay que pasar
  `tools/build.ps1`. Los comentarios y las expresiones regulares van en ASCII;
  las frases para el usuario pueden llevar acentos en minúscula.
- **Las dos aplicaciones (la web y esta terminal) no comparten código.** Una
  función nueva de cara al usuario hay que pensarla para las dos.
- **Para probar el modo una-respuesta desde Bash** hay que pasar `</dev/null`;
  si no, se queda esperando la entrada estándar.

## Lo que sigue sin probar

- OpenAI, xAI y Ollama con las herramientas nuevas (búsqueda, datos del
  equipo y comandos guardados).
- PowerShell fuera de Windows.
