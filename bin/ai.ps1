#requires -Version 5.1
<#
.SYNOPSIS
    PRC AI 2.0 - cliente de chat para OpenAI, xAI y Ollama.
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
    } catch { Write-AIError "settings.json ilegible, se usan los valores por defecto." }
}

if (-not $Provider) { $Provider = $conf.provider }
if (-not $System)   { $System   = $conf.system }
if (-not $Model -and $conf.model) { $Model = $conf.model }

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
$($c.Head)PRC AI 2.0$($c.Off)  - OpenAI / xAI / Ollama sobre PowerShell puro.

$($c.Bullet)USO$($c.Off)
  AI                          modo interactivo
  AI "pregunta"               una respuesta y sale
  type notas.txt | AI "resume esto"

$($c.Bullet)OPCIONES$($c.Off)
  -Provider  openai|xai|ollama   (alias: gpt, grok, deepseek)
  -Model     nombre del modelo
  -System    instruccion de sistema
  -Context   fichero que se adjunta como contexto
  -Temp      temperatura (por defecto 0.7)
  -NoStream  pide la respuesta completa en vez de token a token
  -Plain     sin color ni markdown (automatico al redirigir)
  -SetKey    VAR    guarda una clave de forma interactiva
  -Check     diagnostico de los tres proveedores

$($c.Bullet)EN EL MODO INTERACTIVO$($c.Off)
  bye / exit     salir             cls          limpiar pantalla
  /new           olvidar memoria   /model X     cambiar de modelo
  /provider X    cambiar proveedor /save ruta   guardar la conversacion
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
        $col = if ($r.Estado -eq 'OK') { $AI_COLOR.Bot } else { $AI_COLOR.Err }
        Write-Host ("  {0,-16} {1,-18} {2,-24} {3}{4}{5}" -f `
            $r.Proveedor, $r.Variable, $r.Clave, $col, $r.Estado, $AI_COLOR.Off)
    }
    Write-Host ""
    exit 0
}

# ===========================================================================
#  Estado de la conversacion
# ===========================================================================
try { $prov = Resolve-AIProvider $Provider }
catch { Write-AIError $_.Exception.Message; exit 1 }

if (-not $Model) { $Model = $prov.Model }

# La memoria vive aqui: se acumulan los turnos y se mandan enteros.
$messages = New-Object System.Collections.ArrayList
[void]$messages.Add(@{ role = 'system'; content = $System })

function Invoke-AITurn {
    <#  Un turno completo: manda, pinta y guarda en memoria.  #>
    param([string]$UserText, [int]$PrefixWidth = 0)

    [void]$messages.Add(@{ role = 'user'; content = $UserText })

    $rend = New-AIRenderer -Plain:$Plain -PrefixWidth $PrefixWidth
    $cb   = { param($t) Add-AIToken $rend $t }.GetNewClosure()

    $res = Invoke-AIChat -Provider $prov -Messages $messages.ToArray() `
                         -Model $Model -Temperature $Temp `
                         -OnToken $cb -NoStream:$NoStream

    if (-not $res.Ok) {
        # El turno fallido se retira para no envenenar la memoria.
        # RemoveAt es el idioma seguro aqui: un rango 0..($n-2) con $n=1 da
        # 0..-1, que en PowerShell devuelve el array invertido, no vacio.
        $messages.RemoveAt($messages.Count - 1)
        Write-AIError $res.Error
        return $false
    }

    Close-AIRenderer $rend
    [void]$messages.Add(@{ role = 'assistant'; content = $res.Text })
    if ($res.Model) { $script:LastModel = $res.Model }
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
Write-Host "  $($c.Head)PRC AI 2.0$($c.Off)  $($c.Dim)$($prov.Label) / $Model$($c.Off)"
Write-Host "  $($c.Dim)bye para salir  -  /help para los comandos$($c.Off)"
Write-Host ""

# .Substring(0,1).ToUpper() y punto. La sustitucion de cadenas de CMD es
# insensible a mayusculas, por eso el bucle a..z/A..Z de antes convertia
# cualquier inicial en 'A' (solo parecia funcionar con un nombre que ya
# empezaba por 'a').
$user = $env:USERNAME
if ($user.Length -gt 0) { $user = $user.Substring(0, 1).ToUpper() + $user.Substring(1) }

$rotulo = 'ia > '

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
        [void](Invoke-AITurn $line $rotulo.Length)
        [Console]::Out.Write("$($c.Off)")
        # El modelo REAL puede no ser el pedido: xAI sustituye en silencio los
        # nombres retirados (grok-3-mini se sirve como grok-4.3). Esto es el
        # sensor que faltaba y que dejo pasar el bug del desplazamiento 179.
        if ($script:LastModel -and $script:LastModel -ne $Model) {
            Write-Host "$($c.Dim)   [servido por $($script:LastModel)]$($c.Off)"
            $Model = $script:LastModel
        }
    }
}
exit 0
