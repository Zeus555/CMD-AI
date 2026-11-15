#requires -Version 5.1
<#
.SYNOPSIS
    PRC AI 2.0 - cliente de chat para OpenAI, xAI, Ollama y llama-server.
.DESCRIPTION
    Dos modos, un solo nucleo:
      AI                        -> REPL interactivo con memoria e historial
      AI "pregunta"             -> una respuesta y sale (para tuberias)
      type f.txt | AI "resume"  -> la entrada estandar entra como contexto
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Question,
    [Alias('p')][string]$Provider,
    [Alias('m')][string]$Model,
    [Alias('s')][string]$System,
    [Alias('c')][string]$Context,
    [double]$Temp = 0.7,
    [switch]$NoStream,
    [switch]$Plain,
    [switch]$NoWeb,
    [switch]$NoEquipo,
    [string]$SetKey,
    [switch]$Check,
    [switch]$Help,
    # Recoge los trozos sueltos que "powershell -File" genera cuando la
    # pregunta lleva comillas dobles internas. Sin esto, el enlace de
    # parametros falla con "A positional parameter cannot be found".
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest
)

# La lanzadera pasa la pregunta intacta por variable de entorno; argv solo
# sirve para las opciones. Este es el arreglo de raiz del bug de comillas.
if (-not [string]::IsNullOrEmpty($env:AI_QUESTION)) { $Question = $env:AI_QUESTION }
# Sin la lanzadera, "powershell -File" parte una pregunta con comillas dobles
# internas en trozos posicionales sueltos que caen en $Rest. Antes se
# descartaban y la pregunta llegaba truncada EN SILENCIO; ahora se pegan de
# vuelta en su orden. Los trozos con pinta de opcion (-algo) no se pegan:
# o son una opcion mal escrita o una pregunta que conviene pasar por AI.bat.
if ($Rest -and [string]::IsNullOrEmpty($env:AI_QUESTION)) {
    $sueltos = @($Rest | Where-Object { $_ -and -not $_.StartsWith('-') })
    if ($sueltos.Count -gt 0) {
        $Question = ((@($Question) + $sueltos) -join ' ').Trim()
    }
    $dudosos = @($Rest | Where-Object { $_ -and $_.StartsWith('-') })
    if ($dudosos.Count -gt 0) {
        Write-Warning ("argumentos no reconocidos ignorados: {0}" -f ($dudosos -join ' '))
    }
}
# AI_PROVIDER permite fijar el proveedor por defecto desde el entorno, util
# para un .bat propio o para una sesion concreta. Una opcion -Provider
# explicita siempre gana, y si no hay ninguna de las dos manda settings.json.
if (-not $Provider -and -not [string]::IsNullOrEmpty($env:AI_PROVIDER)) {
    $Provider = $env:AI_PROVIDER
}

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

. (Join-Path $root 'lib\providers.ps1')
. (Join-Path $root 'lib\core.ps1')
. (Join-Path $root 'lib\ui.ps1')
. (Join-Path $root 'lib\web.ps1')
. (Join-Path $root 'lib\equipo.ps1')

Initialize-AIConsole

$DataDir  = Join-Path $env:LOCALAPPDATA 'PRC-CMD-AI'
$HistFile = Join-Path $DataDir 'chat_history.txt'
$ConfFile = Join-Path $DataDir 'settings.json'

# ---- Configuracion opcional (todo tiene valor por defecto) -----------------
$conf = @{ provider = 'xai'; system = 'Eres un asistente util. Responde en espanol, breve y al grano.' }
if (Test-Path $ConfFile) {
    try {
        $j = [IO.File]::ReadAllText($ConfFile, [Text.Encoding]::UTF8) | ConvertFrom-Json
        foreach ($k in 'provider', 'system', 'model') { if ($j.$k) { $conf[$k] = $j.$k } }
        # "web": false se lee aparte: con el "if ($j.$k)" de arriba un false
        # no se distingue de una clave ausente.
        if ($j.PSObject.Properties['web']) { $conf.web = [bool]$j.web }
        if ($j.PSObject.Properties['equipo']) { $conf.equipo = [bool]$j.equipo }
    } catch { Write-AIError "settings.json ilegible, se usan los valores por defecto." }
}

if (-not $Provider) { $Provider = $conf.provider }
if (-not $System)   { $System   = $conf.system }
# Buscar en internet: encendido salvo -NoWeb o "web": false. Aun encendido,
# solo se ofrece al modelo si en ese momento hay salida (Test-AIInternet).
$script:Web = (-not $NoWeb) -and ($conf.web -ne $false)
# Datos del equipo (bateria, red, discos...): encendido salvo -NoEquipo o
# "equipo": false. No depende de internet: se leen de la propia laptop.
$script:Equipo = (-not $NoEquipo) -and ($conf.equipo -ne $false)
# Proveedores que rechazaron la herramienta con un HTTP 4xx: no se les vuelve
# a ofrecer en esta sesion.
$script:SinHerramientas = @{}
$rotulo = 'ia > '

# ---- Salida limpia automatica cuando alguien nos entuba --------------------
# Si la salida va a un fichero o a otro programa, nadie quiere secuencias ANSI.
if ([Console]::IsOutputRedirected) { $Plain = $true }
# Vaciar la paleta apaga el color en TODO el programa de una sola vez.
if ($Plain) { foreach ($k in @($AI_COLOR.Keys)) { $AI_COLOR[$k] = '' } }

# ===========================================================================
#  Subcomandos
# ===========================================================================
function Show-AIHelp {
    $c = $AI_COLOR
    @"
$($c.Head)PRC AI 2.0$($c.Off)  - OpenAI / xAI / Ollama / llama-server sobre PowerShell puro.

$($c.Bullet)USO$($c.Off)
  AI                          modo interactivo
  AI "pregunta"               una respuesta y sale
  type notas.txt | AI "resume esto"

$($c.Bullet)OPCIONES$($c.Off)
  -Provider  openai|xai|ollama|gemma|gemma3|qwen   (alias: gpt, grok, deepseek, llama, e4b)
             gemma (Gemma 4 E4B), gemma3 (Gemma 3 4B) y qwen son locales:
             un mismo llama-server, varios modelos
  -Model     nombre del modelo
  -System    instruccion de sistema
  -Context   fichero que se adjunta como contexto
  -Temp      temperatura (por defecto 0.7)
  -NoStream  pide la respuesta completa en vez de token a token
  -Plain     sin color ni markdown (automatico al redirigir)
  -NoWeb     no buscar en internet (por defecto el modelo busca cuando hace
             falta, solo si hay conexion)
  -NoEquipo  no leer datos de este equipo (por defecto el modelo puede leer
             bateria, red, Windows, procesador, memoria, discos y grafica)
  -SetKey    VAR    guarda una clave de forma interactiva
  -Check     diagnostico de los proveedores

$($c.Bullet)EN EL MODO INTERACTIVO$($c.Off)
  bye / exit     salir             cls          limpiar pantalla
  /new           olvidar memoria   /model X     cambiar de modelo
  /provider X    cambiar proveedor /save [ruta] guardar la conversacion
  /buscar X      buscar X en internet y contestar con lo encontrado
  /web on|off    dejar o no que el modelo busque cuando lo necesite
  /equipo [X]    ensenar los datos de este equipo sin preguntar al modelo
                 (X: bateria red equipo sistema procesador memoria disco grafica)
  /equipo on|off dejar o no que el modelo lea los datos de este equipo
"@ | Write-Host
}

if ($Help) { Show-AIHelp; exit 0 }

if ($SetKey) {
    & (Join-Path $root 'tools\Set-AIKey.ps1') -Name $SetKey
    exit $LASTEXITCODE
}

if ($Check) {
    Write-Host ""
    foreach ($id in $AI_PROVIDERS.Keys) {
        $r = Test-AIProvider (Resolve-AIProvider $id)
        $col = if ($r.Estado -like 'OK*') { $AI_COLOR.Bot } else { $AI_COLOR.Err }
        Write-Host ("  {0,-20} {1,-18} {2,-24} {3}{4}{5}" -f `
            $r.Proveedor, $r.Variable, $r.Clave, $col, $r.Estado, $AI_COLOR.Off)
    }
    $net = Test-AIInternet -Force
    $col = if ($net) { $AI_COLOR.Bot } else { $AI_COLOR.Err }
    $est = if ($net) { 'OK (el modelo puede buscar)' } else { 'sin salida: se contesta sin buscar' }
    if (-not $script:Web) { $est += ' - busqueda apagada (-NoWeb o settings.json)' }
    Write-Host ("  {0,-20} {1,-18} {2,-24} {3}{4}{5}" -f 'Internet', $AI_WEB_HOST, 'no hace falta', $col, $est, $AI_COLOR.Off)
    $eq  = Get-AIEquipoText $AI_EQUIPO_GRUPOS
    $col = if ($eq.Fallidos.Count -eq 0) { $AI_COLOR.Bot } else { $AI_COLOR.Err }
    $est = "OK ($($eq.Leidos.Count) de $($AI_EQUIPO_GRUPOS.Count) lecturas)"
    if ($eq.Fallidos.Count) { $est = "$($eq.Leidos.Count) de $($AI_EQUIPO_GRUPOS.Count) lecturas; Windows no dio: $($eq.Fallidos -join ', ')" }
    if (-not $script:Equipo) { $est += ' - apagado (-NoEquipo o settings.json)' }
    Write-Host ("  {0,-20} {1,-18} {2,-24} {3}{4}{5}" -f 'Datos del equipo', 'este equipo', 'no hace falta', $col, $est, $AI_COLOR.Off)
    Write-Host ""
    exit 0
}

# ===========================================================================
#  Estado de la conversacion
# ===========================================================================
try { $prov = Resolve-AIProvider $Provider }
catch { Write-AIError $_.Exception.Message; exit 1 }

# El "model" de settings.json es el modelo del "provider" de settings.json.
# Con otro proveedor (-Provider, AI_PROVIDER) no se arrastra: 'grok-4.3' no
# existe en un servidor local, y llama-server en modo router lo rechaza con
# HTTP 400 "model 'grok-4.3' not found".
if (-not $Model -and $conf.model) {
    $confId = $null
    try { $confId = (Resolve-AIProvider $conf.provider).Id } catch { }
    if ($confId -eq $prov.Id) { $Model = $conf.model }
}
if (-not $Model) { $Model = $prov.Model }

# La memoria vive aqui: se acumulan los turnos y se mandan enteros.
$messages = New-Object System.Collections.ArrayList
[void]$messages.Add(@{ role = 'system'; content = $System })

function Write-AINote {
    <#  Avisos de la busqueda ("buscando: ...", las fuentes). En el modo
        interactivo van a la pantalla; con una sola respuesta, a stderr, para
        que una tuberia reciba solo la respuesta.
        Con -Reprefix (el aviso sale en la fila del rotulo "ia > " antes de
        que llegue la respuesta) se vuelve a escribir el rotulo en la fila
        siguiente: el renderizador cuenta con que la respuesta empieza a su
        derecha.  #>
    param([string]$Text, [int]$PrefixWidth = 0, [switch]$Reprefix)
    $c = $AI_COLOR
    if ($PrefixWidth -gt 0) {
        $s = "$($c.Off)$($c.Dim)$Text$($c.Off)`r`n"
        if ($Reprefix) { $s += "$($c.Dim)$rotulo$($c.Off)$($c.Bot)" }
        [Console]::Out.Write($s)
    } else {
        [Console]::Error.WriteLine("$($c.Dim)$Text$($c.Off)")
    }
}

function Get-AITurnMessages {
    <#  La memoria tal cual, con una nota al final de la instruccion de
        sistema: la fecha y la hora del reloj del equipo (sin ellas "hoy" y
        "ahora" no significan nada para el modelo), si puede buscar y si puede
        leer los datos del equipo. La nota no se guarda: se recalcula en cada
        peticion porque el reloj avanza y la conexion va y viene.
        Con -Anexo, lo que el programa ya leyo del equipo para esta pregunta
        viaja pegado al mensaje del usuario (el de la posicion -Indice), solo
        en la peticion: en la memoria queda la pregunta tal como se escribio.
        Va en el mensaje y no como herramienta para que sirva igual con los
        modelos que no saben pedirlas.  #>
    param([bool]$Ofrece, [bool]$Red, [bool]$OfreceEquipo, [string]$Anexo, [int]$Indice = -1, [bool]$SinHerramientas)
    $arr  = $messages.ToArray()
    $nota = Get-AIClockNote
    if ($OfreceEquipo) {
        $nota += ' Tienes la herramienta datos_equipo, que lee los datos del equipo del usuario y de su red local (bateria, internet, wifi, direccion IP, Windows, procesador, memoria, discos, grafica). Usala cuando el usuario pregunte por los datos de su propio equipo: esos no te los sabes, asi que no los des de memoria. Lo demas, incluidos los datos de cualquier otro aparato, se contesta como siempre.'
    }
    if ($Ofrece) {
        $nota += ' Tienes la herramienta buscar_web para buscar en internet. Usala cuando la pregunta necesite datos actuales o que no conoces con seguridad. Cuando la uses, contesta con lo que digan los resultados y no inventes lo que no digan.'
    }
    elseif ($script:Web -and -not $Red) {
        $nota += ' Este equipo no tiene conexion a internet ahora mismo: no puedes buscar. Si te piden datos actuales, dilo y contesta con lo que sepas avisando de que puede estar desactualizado.'
    }
    elseif ($SinHerramientas) {
        # Un modelo al que no se le ofrecen herramientas (campo Tools de
        # providers.ps1, o un servidor que las rechazo): que lo sepa, para
        # que no conteste como si hubiera buscado.
        $nota += ' No puedes buscar en internet ni consultar nada fuera de esta conversacion. Si te piden datos actuales (precios, clima, noticias, resultados), di que no puedes buscarlos y no los inventes.'
    }
    $sys = @{ role = 'system'; content = ([string]$arr[0].content + "`n" + $nota).Trim() }
    $resto = @($arr | Select-Object -Skip 1)
    if ($Anexo -and $Indice -ge 1 -and $Indice -lt $arr.Count) {
        $resto[$Indice - 1] = @{ role = 'user'; content = ([string]$arr[$Indice].content + "`n`n" + $Anexo) }
    }
    return @($sys) + $resto
}

function Invoke-AITurn {
    <#  Un turno completo: manda, pinta y guarda en memoria.
        Si el modelo pide buscar_web, se busca, se le pasan los resultados y
        se le vuelve a preguntar (como mucho dos busquedas por turno). Si pide
        datos_equipo, se lee de la laptop y se le pasa lo leido (como mucho
        dos lecturas por turno); esa no necesita internet. Con -ForceQuery
        (/buscar) se busca antes de preguntarle.  #>
    param([string]$UserText, [int]$PrefixWidth = 0, [string]$ForceQuery)

    [void]$messages.Add(@{ role = 'user'; content = $UserText })
    $base = $messages.Count            # lo que se anada detras es del turno

    # Retira el turno entero (pregunta incluida) para no envenenar la memoria.
    # RemoveAt es el idioma seguro aqui: un rango 0..($n-2) con $n=1 da
    # 0..-1, que en PowerShell devuelve el array invertido, no vacio.
    $retirar = { while ($messages.Count -ge $base) { $messages.RemoveAt($messages.Count - 1) } }

    $red     = if ($script:Web -or $ForceQuery) { Test-AIInternet } else { $false }
    # Sin herramientas: el servidor las rechazo en esta sesion, o el modelo
    # no sabe pedirlas (Tools = $false en providers.ps1).
    $sinHerr = [bool]$script:SinHerramientas[$prov.Id] -or ($prov.Tools -eq $false)
    $ofrece  = $script:Web -and $red -and -not $sinHerr
    # Los datos del equipo se ofrecen haya o no internet: no salen a ningun
    # sitio. Salvo si la pregunta es sobre otro aparato (ver $AI_EQUIPO_AJENO).
    $ofreceEq = $script:Equipo -and -not $sinHerr -and -not (Test-AIEquipoAjeno $UserText)
    $fuentes = @()
    $buscas  = 0
    $lecturas = 0      # lecturas del equipo en este turno (la del atajo cuenta)
    $rondas  = 0       # vueltas con herramienta: tope para no dar vueltas sin fin
    $avisoEnFila = $PrefixWidth -gt 0   # el primer aviso sale en la fila de "ia > "

    # El atajo: si la pregunta pide a las claras datos de este equipo, se leen
    # ya y viajan con ella. Ni espera a que el modelo los pida ni depende de
    # que sepa pedirlos.
    $anexo = ''
    if ($script:Equipo -and -not $ForceQuery) {
        $pre = Find-AIEquipoGroups $UserText
        if ($pre.Count) {
            Write-AINote "leyendo de este equipo: $($pre -join ', ')" $PrefixWidth -Reprefix:$avisoEnFila
            $avisoEnFila = $false
            $anexo = (Get-AIEquipoText $pre -ParaModelo).Text
            $lecturas = 1
            # Ya esta leido: en este turno no se ofrece ademas la herramienta.
            # Ofrecida, Gemma 4 E4B la pedia a veces igual y el turno
            # costaba el doble para leer lo mismo.
            $ofreceEq = $false
        }
    }

    if ($ForceQuery) {
        if (-not $red) {
            & $retirar
            if ($PrefixWidth -gt 0) { [Console]::Out.Write("`r`n") }
            Write-AIError 'no hay conexion a internet: no se puede buscar ahora.'
            return $false
        }
        Write-AINote "buscando: $ForceQuery" $PrefixWidth -Reprefix:$avisoEnFila
        $avisoEnFila = $false
        $w = Invoke-AIWebSearch $ForceQuery
        $fuentes += $w.Sources
        # Se presenta como si el modelo hubiera pedido la busqueda: es la
        # forma en que todos los proveedores entienden "esto viene de fuera".
        [void]$messages.Add(@{ role = 'assistant'; content = ''; tool_calls = @(@{
            id = 'busqueda_1'; type = 'function'
            function = @{ name = 'buscar_web'; arguments = (@{ consulta = $ForceQuery } | ConvertTo-Json -Compress) } }) })
        [void]$messages.Add(@{ role = 'tool'; tool_call_id = 'busqueda_1'; content = $w.Text })
        $buscas = 1
    }

    while ($true) {
        $daWeb = $ofrece -and $buscas -lt 2 -and $rondas -lt 4
        $daEq  = $ofreceEq -and $lecturas -lt 2 -and $rondas -lt 4
        $herr  = @()
        if ($daWeb) { $herr += $AI_WEB_TOOL }
        if ($daEq)  { $herr += $AI_EQUIPO_TOOL }
        if ($herr.Count -eq 0) { $herr = $null }
        $rend = New-AIRenderer -Plain:$Plain -PrefixWidth $PrefixWidth
        $cb   = { param($t) Add-AIToken $rend $t }.GetNewClosure()

        # Tras una busqueda o una lectura del equipo se contesta con lo
        # leido: temperatura baja, para que copie cifras y fechas en vez de
        # adornarlas. (Ojo
        # al comprobar: hay paginas que fechan en UTC, y en Nicaragua desde
        # las 18:00 ya dicen "manana".)
        $tempo = if (($buscas + $lecturas) -gt 0) { [Math]::Min($Temp, 0.2) } else { $Temp }
        $res = Invoke-AIChat -Provider $prov -Messages (Get-AITurnMessages $daWeb $red $daEq $anexo ($base - 1) $sinHerr) `
                             -Model $Model -Temperature $tempo `
                             -OnToken $cb -NoStream:$NoStream -Tools $herr

        # Un proveedor (o un servidor viejo) que no acepta "tools" contesta
        # 400/422 antes de escribir nada: se repite sin la herramienta y no se
        # le vuelve a ofrecer en esta sesion.
        if (-not $res.Ok -and $herr -and -not $res.Text -and $res.Error -match '^HTTP 4\d\d') {
            $script:SinHerramientas[$prov.Id] = $true
            $sinHerr = $true
            $ofrece = $false
            $ofreceEq = $false
            continue
        }

        if (-not $res.Ok) {
            # Si el flujo se corto a medias ya hay texto pintado: se cierra la
            # linea para que el ERROR no se pegue a la respuesta parcial.
            if ($res.Text) { Close-AIRenderer $rend }
            & $retirar
            Write-AIError $res.Error
            return $false
        }

        if ($herr -and @($res.ToolCalls).Count -gt 0) {
            if ($res.Text) { Close-AIRenderer $rend; $avisoEnFila = $false }
            $tcs = @($res.ToolCalls | Select-Object -First 2)
            [void]$messages.Add(@{ role = 'assistant'; content = [string]$res.Text; tool_calls = @($tcs | ForEach-Object {
                @{ id = $_.Id; type = 'function'; function = @{ name = $_.Name; arguments = $_.Arguments } } }) })
            $rondas++
            foreach ($tc in $tcs) {
                if ($tc.Name -eq 'datos_equipo' -and $daEq) {
                    $lecturas++
                    $grupos = ConvertTo-AIEquipoGroups $tc.Arguments
                    Write-AINote "leyendo de este equipo: $($grupos -join ', ')" $PrefixWidth -Reprefix:$avisoEnFila
                    $avisoEnFila = $false
                    $txt = (Get-AIEquipoText $grupos -ParaModelo).Text
                }
                elseif ($tc.Name -ne 'buscar_web' -or -not $daWeb) {
                    $txt = if ($tc.Name -eq 'buscar_web') { 'Ahora no se puede buscar en internet. Dilo y contesta con lo que sepas.' }
                           else { "La herramienta '$($tc.Name)' no esta disponible." }
                } else {
                    $buscas++
                    $q = ''
                    try { $q = [string]($tc.Arguments | ConvertFrom-Json).consulta } catch { }
                    if (-not $q.Trim()) { $q = $UserText }
                    Write-AINote "buscando: $q" $PrefixWidth -Reprefix:$avisoEnFila
                    $avisoEnFila = $false
                    $w = Invoke-AIWebSearch $q
                    $fuentes += $w.Sources
                    $txt = $w.Text
                }
                [void]$messages.Add(@{ role = 'tool'; tool_call_id = $tc.Id; content = $txt })
            }
            # Tras la busqueda la respuesta empieza en una fila nueva, con su
            # rotulo ya escrito por Write-AINote.
            continue
        }

        Close-AIRenderer $rend
        break
    }

    # La memoria guarda la pregunta y la respuesta, no las paginas leidas: con
    # 4096 tokens de contexto en el servidor local, dos busquedas lo llenarian.
    while ($messages.Count -gt $base) { $messages.RemoveAt($messages.Count - 1) }
    [void]$messages.Add(@{ role = 'assistant'; content = $res.Text })
    $vistas = @($fuentes | Where-Object { $_ } | Select-Object -Unique -First 3)
    if ($vistas.Count) { Write-AINote ('   fuentes: ' + ($vistas -join '  ')) $PrefixWidth }
    # Sin condicion: si este servidor no dice que modelo sirvio, LastModel
    # tiene que quedar vacio y no con el nombre de un turno anterior.
    $script:LastModel = $res.Model
    return $true
}

# ===========================================================================
#  MODO UNA SOLA RESPUESTA
# ===========================================================================
$stdin = ''
if ([Console]::IsInputRedirected -and $Question) { $stdin = [Console]::In.ReadToEnd() }
if ($Context) {
    if (-not (Test-Path -LiteralPath $Context)) { Write-AIError "no existe el fichero '$Context'"; exit 1 }
    $stdin += "`n" + [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Context), [Text.Encoding]::UTF8)
}

if ($Question) {
    $q = $Question
    if ($stdin.Trim()) { $q = "$Question`n`n--- contexto ---`n$($stdin.Trim())" }
    $ok = Invoke-AITurn $q
    exit $(if ($ok) { 0 } else { 2 })
}

# ---- Entrada entubada SIN pregunta ----------------------------------------
# "type fichero | AI" sin pregunta: sin este bloque, el REPL de abajo leeria
# el fichero linea a linea y mandaria CADA linea como una peticion
# independiente (N llamadas facturables con la memoria compartida). Toda la
# entrada estandar se trata como UNA sola pregunta.
if ([Console]::IsInputRedirected) {
    $todo = [Console]::In.ReadToEnd().Trim()
    if ($stdin.Trim()) { $todo = "$todo`n`n--- contexto ---`n$($stdin.Trim())" }
    if (-not $todo) {
        Write-AIError 'entrada estandar vacia y sin pregunta. Uso: AI "pregunta"   o   type fichero.txt | AI "resume esto"'
        exit 1
    }
    $ok = Invoke-AITurn $todo
    exit $(if ($ok) { 0 } else { 2 })
}

# ===========================================================================
#  MODO INTERACTIVO
# ===========================================================================
$interactive = (-not [Console]::IsInputRedirected) -and (-not [Console]::IsOutputRedirected)
$usePRL = $false
if ($interactive) { $usePRL = Initialize-AIReadLine $HistFile }

Clear-Host
$c = $AI_COLOR
Write-Host ""
$estadoWeb = if (-not $script:Web) { 'busqueda apagada' }
             elseif ($prov.Tools -eq $false) { 'este modelo no busca solo: usa /buscar' }
             elseif (Test-AIInternet) { 'busca en internet si hace falta' }
             else { 'sin internet: contesta sin buscar' }
Write-Host "  $($c.Head)PRC AI 2.0$($c.Off)  $($c.Dim)$($prov.Label) / $Model  -  $estadoWeb$($c.Off)"
Write-Host "  $($c.Dim)bye para salir  -  /help para los comandos$($c.Off)"
Write-Host ""

# .Substring(0,1).ToUpper() y punto. La sustitucion de cadenas de CMD es
# insensible a mayusculas, por eso el bucle a..z/A..Z de antes convertia
# cualquier inicial en 'A' (solo parecia funcionar con un nombre que ya
# empezaba por 'a').
$user = $env:USERNAME
if ($user.Length -gt 0) { $user = $user.Substring(0, 1).ToUpper() + $user.Substring(1) }

while ($true) {
    $line = Read-AILine "$($c.User)$user$($c.Off) $($c.Dim)>$($c.Off) " $usePRL
    if ($null -eq $line) { break }            # Ctrl+Z / fin de entrada
    $line = $line.Trim()
    if (-not $line) { continue }

    # OJO: aqui NO se usa "switch -Regex" con "continue". En PowerShell 5.1
    # el continue sale del switch pero NO reinicia el while, asi que el flujo
    # caeria hasta Invoke-AITurn y "cls" acabaria enviandose al modelo.
    # Por eso el despacho va con if/elseif explicito.
    if ($line -match '^(bye|exit|salir|quit)$') {
        Write-Host "$($c.Dim)hasta luego$($c.Off)"; exit 0
    }
    elseif ($line -match '^(cls|clear)$') { Clear-Host }
    elseif ($line -match '^/help$')       { Show-AIHelp }
    elseif ($line -match '^/new$') {
        $messages.Clear()
        [void]$messages.Add(@{ role = 'system'; content = $System })
        Write-Host "$($c.Dim)memoria vaciada$($c.Off)"
    }
    elseif ($line -match '^/model\s+(\S+)$') {
        $Model = $Matches[1]; Write-Host "$($c.Dim)modelo -> $Model$($c.Off)"
    }
    elseif ($line -match '^/provider\s+(\S+)$') {
        try {
            $prov  = Resolve-AIProvider $Matches[1]
            $Model = $prov.Model
            Write-Host "$($c.Dim)proveedor -> $($prov.Label) / $Model$($c.Off)"
        } catch { Write-AIError $_.Exception.Message }
    }
    elseif ($line -match '^/web\s+(on|off|si|no)$') {
        $script:Web = $Matches[1] -in 'on', 'si'
        $msg = if (-not $script:Web) { 'busqueda apagada: el modelo no buscara' }
               elseif (Test-AIInternet -Force) { 'busqueda encendida: el modelo buscara cuando haga falta' }
               else { 'busqueda encendida, pero ahora no hay conexion a internet' }
        Write-Host "$($c.Dim)$msg$($c.Off)"
    }
    elseif ($line -match '^/equipo\s+(on|off|si|no)$') {
        $script:Equipo = $Matches[1] -in 'on', 'si'
        $msg = if ($script:Equipo) { 'datos del equipo encendidos: el modelo puede leerlos cuando haga falta' }
               else { 'datos del equipo apagados: el modelo no los leera (/equipo los sigue ensenando)' }
        Write-Host "$($c.Dim)$msg$($c.Off)"
    }
    elseif ($line -match '^/equipo(\s+(.+))?$') {
        # Sin modelo: lo leido, tal cual. Funciona sin servidor y sin internet.
        Write-Host "$($c.Bot)$((Get-AIEquipoText (ConvertTo-AIEquipoGroups ([string]$Matches[2])) -Reloj).Text)$($c.Off)"
    }
    elseif ($line -match '^/buscar\s+(.+)$') {
        $q = $Matches[1].Trim()
        [Console]::Out.Write("$($c.Dim)$rotulo$($c.Off)$($c.Bot)")
        $null = Invoke-AITurn $q $rotulo.Length -ForceQuery $q
        [Console]::Out.Write("$($c.Off)")
    }
    elseif ($line -match '^/save(\s+(.+))?$') {
        $dest = if ($Matches[2]) { $Matches[2].Trim() }
                else { Join-Path $DataDir ('chat_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.json') }
        $dir = Split-Path -Parent $dest
        if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        # Set-Content escribe en cp1252 por defecto y se come los emojis.
        # WriteAllText con UTF8Encoding($false) guarda exacto y sin BOM.
        [IO.File]::WriteAllText($dest,
            ($messages.ToArray() | ConvertTo-Json -Depth 10),
            (New-Object System.Text.UTF8Encoding $false))
        Write-Host "$($c.Dim)guardado en $dest$($c.Off)"
    }
    else {
        # El rotulo comparte fila con la primera linea de la respuesta, por eso
        # se le pasa su ancho al renderizador: al reformatear debe saltar a esa
        # columna en vez de borrar la fila entera.
        [Console]::Out.Write("$($c.Dim)$rotulo$($c.Off)$($c.Bot)")
        $bien = Invoke-AITurn $line $rotulo.Length
        [Console]::Out.Write("$($c.Off)")
        # El modelo REAL puede no ser el pedido: xAI sustituye en silencio los
        # nombres retirados (grok-3-mini se sirve como grok-4.3). Esto es el
        # sensor que faltaba y que dejo pasar el bug del desplazamiento 179.
        # Solo se mira tras un turno BUENO: si fallo, LastModel es el de un
        # turno anterior (quiza de otro proveedor) y copiarlo a $Model mandaria
        # 'grok-4.3' al servidor local en la pregunta siguiente.
        if ($bien -and $script:LastModel -and $script:LastModel -ne $Model) {
            Write-Host "$($c.Dim)   [servido por $($script:LastModel)]$($c.Off)"
            $Model = $script:LastModel
        }
    }
}
exit 0
