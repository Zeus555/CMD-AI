# PRC AI 2.0

Cliente de chat para **OpenAI**, **xAI (Grok)** y **Ollama (local)** escrito en
PowerShell puro para la consola de Windows. Sin dependencias externas: nada de
curl, nada de Python, nada de Node. Un `AI` en cualquier CMD y a conversar.

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
- **Diagnóstico** con `AI -Check`: estado de clave y conectividad de los tres
  proveedores sin gastar tokens.

## Requisitos

- Windows 10/11.
- Windows PowerShell **5.1 o superior** (el que trae Windows; también funciona
  en PowerShell 7).
- Opcional: [PSReadLine](https://github.com/PowerShell/PSReadLine) para
  historial persistente en el modo interactivo (viene de serie en Windows 10/11).
- Para el proveedor local: [Ollama](https://ollama.com) escuchando en
  `http://localhost:11434`.

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

Para borrar una clave: `powershell -File tools\Set-AIKey.ps1 -Name XAI_API_KEY -Remove`.

Ollama no necesita clave.

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
AI "pregunta" -m gpt-4o -Temp 0.2 -NoStream -Plain
AI -Check                       diagnostico de los tres proveedores
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

La configuración por defecto (proveedor, modelo, instrucción de sistema) se
puede fijar en `%LOCALAPPDATA%\PRC-CMD-AI\settings.json`:

```json
{ "provider": "xai", "model": "grok-4.3", "system": "Responde breve y al grano." }
```

También sirven las variables de entorno `AI_PROVIDER` (proveedor por defecto)
y `AI_QUESTION` (la usa internamente `AI.bat` para pasar la pregunta intacta).

## Proveedores soportados

| Proveedor        | Variable de clave | Modelo por defecto | Alias                  |
| ---------------- | ----------------- | ------------------ | ---------------------- |
| OpenAI           | `OPENAI_API_KEY`  | `gpt-4o-mini`      | `gpt`, `chatgpt`, `oai`|
| xAI              | `XAI_API_KEY`     | `grok-4.3`         | `grok`, `x`            |
| Ollama (local)   | *(no necesita)*   | `qwen3:4b`         | `deepseek`, `local`, `ds` |

Los tres hablan el mismo dialecto (`POST /v1/chat/completions`), así que
añadir un proveedor compatible es añadir una entrada a la tabla de
`lib/providers.ps1`. Nada más.

## Estructura del código

```
AI.bat              lanzadera CMD: separa pregunta de opciones y pasa la
                    pregunta por la variable AI_QUESTION (esquiva el bug de
                    comillas de "powershell -File")
bin/ai.ps1          CLI principal: REPL, modo una-respuesta, subcomandos
lib/core.ps1        nucleo HTTP (HttpWebRequest), streaming SSE, filtro de
                    <think>, parser de errores de las tres APIs
lib/providers.ps1   tabla declarativa de proveedores y alias
lib/ui.ps1          colores ANSI, render incremental de Markdown, PSReadLine
tools/Set-AIKey.ps1 guardado seguro de claves en HKCU\Environment
tools/build.ps1     normaliza codificacion: UTF-8 con BOM en .ps1, CRLF en .bat
```

Si editas cualquier `.ps1` o `.bat`, pasa después `tools/build.ps1`: Windows
PowerShell 5.1 decide la codificación de un script por su BOM, y un `.ps1`
sin BOM con acentos se lee como cp1252 y acaba en mojibake (o directamente no
parsea).

## Limitaciones conocidas

- Pensado para Windows; no se ha probado en PowerShell para Linux/macOS.
- Sin soporte de imágenes, herramientas/función-calling ni ficheros adjuntos
  más allá del contexto por stdin / `-Context`.
- El coste de la memoria del REPL crece con la conversación (se envía entera
  en cada turno): usa `/new` en conversaciones largas.

## Licencia

[MIT](LICENSE).
