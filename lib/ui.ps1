#requires -Version 5.1
# ============================================================================
#  ui.ps1 - Presentacion: ANSI, markdown y entrada de linea.
#  Windows 11 ya trae ENABLE_VIRTUAL_TERMINAL_PROCESSING activo (modo 0x0007),
#  asi que no hace falta tocar el registro ni llamar a SetConsoleMode.
# ============================================================================

# PowerShell 5.1 NO entiende la secuencia `e (llego en PowerShell 6).
$ESC = [char]27

$AI_COLOR = @{
    Dim = "$ESC[38;5;244m"; User = "$ESC[38;5;110m"; Bot  = "$ESC[38;5;150m"
    Err = "$ESC[1;38;5;203m"; Head = "$ESC[1;38;5;213m"
    Code = "$ESC[48;5;236m$ESC[38;5;222m"; Bullet = "$ESC[38;5;117m"
    Bold = "$ESC[1m"; Off = "$ESC[0m"
}

function Initialize-AIConsole {
    <#  La consola arranca en IBM437: hay que forzar UTF-8 o el espanol sale
        roto. Se envuelve en try porque con la salida redirigida puede fallar. #>
    try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch { }
    try { $global:OutputEncoding    = New-Object System.Text.UTF8Encoding $false } catch { }
}

function Write-AIError {
    param([string]$Message)
    # Los errores van a stderr para que NO contaminen una tuberia.
    # OJO: Write-Host NO sirve aqui. Comprobado en PS 5.1: con stdout
    # redirigido la salida de Write-Host acaba dentro del fichero, asi que
    #   Grok "pregunta" > salida.txt
    # escribiria el texto del error 429 dentro de salida.txt.
    [Console]::Error.WriteLine("$($AI_COLOR.Err)ERROR$($AI_COLOR.Off) $Message")
}

# ---------------------------------------------------------------------------
#  Renderizador incremental
#  Los tokens se pintan segun llegan (sensacion de escritura en vivo) y, al
#  cerrarse la linea, se reescribe ya formateada. En PS 5.1 no existe
#  ConvertFrom-Markdown / Show-Markdown, asi que va a mano con regex.
# ---------------------------------------------------------------------------

function New-AIRenderer {
    param([switch]$Plain, [int]$PrefixWidth = 0)
    return [pscustomobject]@{
        Line = ''; InFence = $false; Plain = [bool]$Plain
        Pending = ''            # mitad alta de un par suplente aun sin pareja
        PrefixWidth = $PrefixWidth  # ancho del rotulo "ia > " ya impreso
        FirstLine = $true
    }
}

function Get-AIDisplayWidth {
    <#  Ancho aproximado en columnas. Un emoji son dos [char] pero ocupa dos
        columnas, asi que se suma uno por cada par suplente. #>
    param([string]$s)
    $w = $s.Length
    foreach ($c in $s.ToCharArray()) { if ([char]::IsHighSurrogate($c)) { $w++ } }
    return $w
}

function Format-AIMarkdownLine {
    param([string]$s, [pscustomobject]$R)

    if ($s -match '^\s*```') {
        $R.InFence = -not $R.InFence
        return "$($AI_COLOR.Dim)$('-' * 52)$($AI_COLOR.Off)"
    }
    if ($R.InFence) { return "$($AI_COLOR.Code)$s$($AI_COLOR.Off)" }

    $t = $s
    $t = $t -replace '^(#{1,6})\s+(.+)$', "$($AI_COLOR.Head)`$2$($AI_COLOR.Off)"
    $t = $t -replace '\*\*([^*]+)\*\*',   "$($AI_COLOR.Bold)`$1$($AI_COLOR.Off)$($AI_COLOR.Bot)"
    $t = $t -replace '`([^`]+)`',         "$($AI_COLOR.Code)`$1$($AI_COLOR.Off)$($AI_COLOR.Bot)"
    $t = $t -replace '^(\s*)[-*]\s+',     "`$1$($AI_COLOR.Bullet)*$($AI_COLOR.Off)$($AI_COLOR.Bot) "
    return $t
}

function Close-AILine {
    param([pscustomobject]$R)

    $raw = $R.Line
    $R.Line = ''

    if (-not $R.Plain) {
        $fmt = Format-AIMarkdownLine $raw $R
        $w = 0
        try { $w = [Console]::WindowWidth } catch { }

        # La primera linea de la respuesta comparte fila con el rotulo "ia > "
        # que el REPL ya imprimio. Por eso NO se puede usar ESC[2K + \r: eso
        # borraria la fila entera y la respuesta se comeria su propio rotulo.
        # Se salta el cursor a la columna correcta y se borra SOLO de ahi en
        # adelante (ESC[0K), dejando el rotulo intacto.
        $col = 1
        if ($R.FirstLine) { $col = $R.PrefixWidth + 1 }

        # Solo se reescribe en el sitio si la linea cruda NO hizo salto de
        # linea automatico; si envolvio, el reposicionado solo alcanzaria la
        # ultima fila y quedarian restos. En ese caso se deja tal cual: peor
        # formato, nunca basura en pantalla.
        $anchoUsado = (Get-AIDisplayWidth $raw) + $col - 1
        if ($fmt -ne $raw -and $w -gt 0 -and $anchoUsado -lt ($w - 1)) {
            [Console]::Out.Write("$ESC[${col}G$ESC[0K" + $fmt)
        }
    }
    $R.FirstLine = $false
    [Console]::Out.Write("`r`n")
}

function Add-AIToken {
    <#  Se llama por cada fragmento que llega del modelo.

        CUIDADO con los pares suplentes: un emoji son DOS [char]. Si un
        fragmento SSE corta el par por la mitad y se escribe cada mitad por
        separado, el codificador emite dos caracteres de reemplazo y el emoji
        se pierde para siempre. Aqui la mitad alta se retiene hasta que llega
        su pareja. #>
    param([pscustomobject]$R, [string]$Token)

    $s = $R.Pending + $Token
    $R.Pending = ''
    if ($s.Length -gt 0 -and [char]::IsHighSurrogate($s[$s.Length - 1])) {
        $R.Pending = $s.Substring($s.Length - 1)
        $s = $s.Substring(0, $s.Length - 1)
    }
    if ($s.Length -eq 0) { return }

    if ($R.Plain) { [Console]::Out.Write($s); return }

    for ($i = 0; $i -lt $s.Length; $i++) {
        $ch = $s[$i]
        if ($ch -eq "`n") { Close-AILine $R; continue }
        if ($ch -eq "`r") { continue }
        # El par suplente se escribe entero, de una sola vez.
        if ([char]::IsHighSurrogate($ch) -and ($i + 1) -lt $s.Length) {
            $par = $s.Substring($i, 2)
            $i++
            $R.Line += $par
            [Console]::Out.Write($par)
            continue
        }
        $R.Line += $ch
        [Console]::Out.Write($ch)
    }
}

function Close-AIRenderer {
    param([pscustomobject]$R)
    # Si quedo una mitad suelta, se suelta tal cual antes de cerrar.
    if ($R.Pending) { [Console]::Out.Write($R.Pending); $R.Pending = '' }
    if ($R.Plain) { [Console]::Out.Write("`r`n"); return }
    if ($R.Line.Length -gt 0) { Close-AILine $R } else { [Console]::Out.Write("`r`n") }
}

# ---------------------------------------------------------------------------
#  Entrada de linea
# ---------------------------------------------------------------------------

function Initialize-AIReadLine {
    <#  PSReadLine 2.0.0 viene de serie con Windows PowerShell 5.1.
        CRITICO: hay que desviar el fichero de historial. Por defecto es el
        historial REAL de la consola del usuario, asi que el chat lo leeria
        (mezclando sus comandos de git y pm2 en las flechas) y lo ensuciaria. #>
    param([string]$HistoryPath)

    try {
        Import-Module PSReadLine -ErrorAction Stop
        $dir = Split-Path -Parent $HistoryPath
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Set-PSReadLineOption -HistorySavePath $HistoryPath -HistorySaveStyle SaveIncrementally
        # Sin esto PSReadLine colorea lo tecleado como si fuera codigo PowerShell.
        Set-PSReadLineOption -Colors @{
            String = 'White'; Command = 'White'; Parameter = 'White'
            Operator = 'White'; Number = 'White'; Variable = 'White'
            Type = 'White'; Member = 'White'; Comment = 'White'; Keyword = 'White'
        }
        return $true
    } catch { return $false }
}

function Read-AILine {
    <#  Devuelve $null si se acabo la entrada (Ctrl+Z / fin de tuberia).  #>
    param([string]$Prompt, [bool]$UsePSReadLine)

    if ($UsePSReadLine) {
        [Console]::Out.Write($Prompt)
        # Mismo metodo que usa el prompt interactivo real, asi que se heredan
        # flechas arriba/abajo, Ctrl+R, F8... sin escribir una sola linea.
        return [Microsoft.PowerShell.PSConsoleReadLine]::ReadLine($Host.Runspace, $ExecutionContext)
    }
    # Con stdin o stdout redirigidos PSConsoleReadLine lanza
    # "Specified method is not supported." Aqui esta el plan B.
    [Console]::Out.Write($Prompt)
    return [Console]::In.ReadLine()
}
