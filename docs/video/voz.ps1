#requires -Version 5.1
# ---------------------------------------------------------------------------
#  Pone voz a la narracion del video (narracion.txt -> assets\voz\<id>.mp3).
#
#  La misma via que los videos de D:\PRC Channel Linkedin:
#    - voz: gpt-4o-mini-tts, voz "cedar", con instrucciones de estilo;
#    - se quita el silencio de los bordes y se ajusta el tempo (atempo),
#      con compresion y volumen normalizado (ffmpeg);
#    - comprobacion: whisper-1 transcribe la toma y se compara con el guion.
#      Si no dice lo que pone (menos del 90 % de las palabras, o no se oyen
#      las ultimas), se repite la toma; tres veces como mucho.
#
#  Necesita OPENAI_API_KEY en el entorno y ffmpeg/ffprobe en el PATH.
#  Solo rehace las lineas que cambiaron (assets\voz\voz.json guarda una
#  huella de cada una); -Todo las rehace todas y -Solo id1,id2 rehace solo
#  esas (por ejemplo, una toma que suena mal aunque diga el guion).
#  Cuesta unos centimos de dolar: 0,015 USD por minuto de voz y 0,006 por
#  minuto de transcripcion.
#  Comentarios y expresiones regulares en ASCII (ver tools\build.ps1).
# ---------------------------------------------------------------------------
param([string]$Dir, [double]$Tempo = 1.1, [switch]$Todo, [string[]]$Solo, [ValidateSet('es', 'en')][string]$Idioma = 'es')
$ErrorActionPreference = 'Stop'
if (-not $Dir) { $Dir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$utf8 = New-Object Text.UTF8Encoding $false
Add-Type -AssemblyName System.Net.Http

$MODELO = 'gpt-4o-mini-tts'
$VOZ    = 'cedar'
$ESTILO = 'Habla en español latinoamericano neutro. Eres el narrador de un video corto que presenta un programa: voz cálida, clara y segura, con ritmo ágil pero sin prisa y con naturalidad, como quien enseña algo que conoce bien. Lee cada palabra exactamente como está escrita, sin añadir ni cambiar nada.'
# En ingles, la misma voz y el mismo tono, en ingles de EE. UU. (el video en
# ingles va en docsideoen, con su propia narracion.txt).
if ($Idioma -eq 'en') {
    $ESTILO = 'Speak in neutral American English. You are the narrator of a short video that presents a program: a warm, clear and confident voice, at a brisk but unhurried pace, natural, like someone showing something they know well. Read every word exactly as written, adding and changing nothing.'
}
$MIN_COBERTURA = 0.9
$TOMAS = 3

$clave = $env:OPENAI_API_KEY
if (-not $clave) { throw 'Falta OPENAI_API_KEY en el entorno.' }
foreach ($p in 'ffmpeg', 'ffprobe') { if (-not (Get-Command $p -ErrorAction SilentlyContinue)) { throw "Falta $p en el PATH." } }

$salida = Join-Path $Dir 'assets\voz'
New-Item -ItemType Directory -Path $salida -Force | Out-Null
$trabajo = Join-Path ([IO.Path]::GetTempPath()) ('voz-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $trabajo -Force | Out-Null

# ---- La narracion -------------------------------------------------------------
$lineas = [ordered]@{}
foreach ($l in [IO.File]::ReadAllLines((Join-Path $Dir 'narracion.txt'), [Text.Encoding]::UTF8)) {
    if ($l -match '^\s*#' -or -not $l.Trim()) { continue }
    if ($l -notmatch '^\s*([a-z0-9-]+)\s*:\s*(.+)$') { throw "Linea sin formato «id: texto»: $l" }
    $lineas[$Matches[1]] = $Matches[2].Trim()
}

$fichMeta = Join-Path $salida 'voz.json'
$meta = @{}
if (Test-Path -LiteralPath $fichMeta) {
    $j = [IO.File]::ReadAllText($fichMeta, [Text.Encoding]::UTF8) | ConvertFrom-Json
    foreach ($p in $j.PSObject.Properties) { $meta[$p.Name] = $p.Value }
}

function Get-Huella([string]$texto) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $b = $sha.ComputeHash($utf8.GetBytes("$MODELO|$VOZ|$Tempo|$ESTILO|$texto"))
    return -join ($b[0..7] | ForEach-Object { $_.ToString('x2') })
}

# ---- Comparar lo dicho con lo escrito ----------------------------------------------
function ConvertTo-Palabras([string]$t) {
    $t = $t.ToLowerInvariant().Normalize([Text.NormalizationForm]::FormD)
    $t = -join ($t.ToCharArray() | Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' })
    # Whisper escribe cifras y siglas; el guion en espanol las lleva en
    # letras. El ingles se escribe con cifras, como lo escribe Whisper.
    if ($Idioma -eq 'en') { return @($t -split '[^a-z0-9]+' | Where-Object { $_ }) }
    $t = $t -replace 'c\$\s*650|650', ' seiscientos cincuenta '
    $t = $t -replace '\b2[.,]0\b', ' dos punto cero '
    $t = $t -replace '\bp\.?\s?r\.?\s?c\.?(?=\W|$)', ' pe erre ce '
    $t = $t -replace '\b(ai|ia|a\.i\.)(?=\W|$)', ' a i '
    $t = $t -replace '\b4\b', ' cuatro '
    # Y a veces deletrea: "P-R-C-A-I".
    $letra = @{ p = 'pe'; r = 'erre'; c = 'ce' }
    return @($t -split '[^a-z0-9]+' | Where-Object { $_ } | ForEach-Object { if ($letra.ContainsKey($_)) { $letra[$_] } else { $_ } })
}
# Tablas planas (fila * ancho + columna): en PowerShell 5.1 un indice [i, k]
# dentro de los argumentos de un metodo no se analiza bien.
function Get-Distancia([string]$a, [string]$b) {
    $w = $b.Length + 1
    $d = New-Object int[] (($a.Length + 1) * $w)
    for ($i = 0; $i -le $a.Length; $i++) { $d[$i * $w] = $i }
    for ($k = 0; $k -le $b.Length; $k++) { $d[$k] = $k }
    for ($i = 1; $i -le $a.Length; $i++) {
        for ($k = 1; $k -le $b.Length; $k++) {
            $c = if ($a[$i - 1] -eq $b[$k - 1]) { 0 } else { 1 }
            $arriba = $d[($i - 1) * $w + $k] + 1
            $izq = $d[$i * $w + $k - 1] + 1
            $diag = $d[($i - 1) * $w + $k - 1] + $c
            $d[$i * $w + $k] = [Math]::Min([Math]::Min($arriba, $izq), $diag)
        }
    }
    return $d[$a.Length * $w + $b.Length]
}
function Test-Parecida([string]$a, [string]$b) {
    if ($a -eq $b) { return $true }
    return (Get-Distancia $a $b) / [Math]::Max([Math]::Max($a.Length, $b.Length), 1) -le 0.34
}
# Subsecuencia comun mas larga: que palabras del guion se oyen, en orden.
function Get-Cobertura([string[]]$guion, [string[]]$oido) {
    $n = $guion.Count; $m = $oido.Count; $w = $m + 1
    $L = New-Object int[] (($n + 1) * $w)
    $igual = New-Object bool[] (($n + 1) * $w)
    for ($i = $n - 1; $i -ge 0; $i--) {
        for ($k = $m - 1; $k -ge 0; $k--) {
            $p = $i * $w + $k
            if (Test-Parecida $guion[$i] $oido[$k]) { $igual[$p] = $true; $L[$p] = $L[$p + $w + 1] + 1 }
            else { $L[$p] = [Math]::Max($L[$p + $w], $L[$p + 1]) }
        }
    }
    $oidas = New-Object bool[] $n
    $i = 0; $k = 0
    while ($i -lt $n -and $k -lt $m) {
        $p = $i * $w + $k
        if ($igual[$p] -and $L[$p] -eq $L[$p + $w + 1] + 1) { $oidas[$i] = $true; $i++; $k++ }
        elseif ($L[$p + $w] -ge $L[$p + 1]) { $i++ } else { $k++ }
    }
    $cola = @($oidas[([Math]::Max(0, $n - 4))..($n - 1)])
    return @{ Tasa = $L[0] / [Math]::Max($n, 1); Cola = @($cola | Where-Object { $_ }).Count -ge [Math]::Ceiling($cola.Count / 2) }
}

# ---- OpenAI -----------------------------------------------------------------------
$http = New-Object System.Net.Http.HttpClient
$http.Timeout = [TimeSpan]::FromSeconds(180)
$http.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue('Bearer', $clave)

function Send-Peticion([scriptblock]$hacer) {
    for ($n = 1; ; $n++) {
        # Un corte de la red (sin respuesta HTTP) tambien se reintenta.
        try { $r = $http.SendAsync((& $hacer)).GetAwaiter().GetResult() }
        catch {
            if ($n -ge 3) { throw "OpenAI: $($_.Exception.InnerException.Message)" }
            Start-Sleep -Seconds (4 * $n); continue
        }
        if ($r.IsSuccessStatusCode) { return $r }
        $codigo = [int]$r.StatusCode
        $cuerpo = $r.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        if ($n -ge 3 -or ($codigo -lt 500 -and $codigo -ne 429)) { throw "OpenAI HTTP ${codigo}: $($cuerpo.Substring(0, [Math]::Min(200, $cuerpo.Length)))" }
        Start-Sleep -Seconds (4 * $n)
    }
}

function Invoke-Voz([string]$texto, [string]$fichero) {
    $cuerpo = @{ model = $MODELO; voice = $VOZ; input = $texto; instructions = $ESTILO; response_format = 'wav' } | ConvertTo-Json -Compress
    $r = Send-Peticion {
        $m = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Post, 'https://api.openai.com/v1/audio/speech')
        $m.Content = New-Object System.Net.Http.StringContent($cuerpo, [Text.Encoding]::UTF8, 'application/json')
        $m
    }
    [IO.File]::WriteAllBytes($fichero, $r.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult())
}

function Invoke-Transcripcion([string]$fichero) {
    $bytes = [IO.File]::ReadAllBytes($fichero)
    $r = Send-Peticion {
        $f = New-Object System.Net.Http.MultipartFormDataContent
        $a = New-Object System.Net.Http.ByteArrayContent -ArgumentList (, $bytes)
        $a.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue('audio/mpeg')
        $f.Add($a, 'file', 'toma.mp3')
        $f.Add((New-Object System.Net.Http.StringContent('whisper-1')), 'model')
        $f.Add((New-Object System.Net.Http.StringContent($Idioma)), 'language')
        $m = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Post, 'https://api.openai.com/v1/audio/transcriptions')
        $m.Content = $f
        $m
    }
    return ($r.Content.ReadAsStringAsync().GetAwaiter().GetResult() | ConvertFrom-Json).text
}

function Invoke-Ffmpeg([string[]]$argumentos) {
    & ffmpeg -hide_banner -loglevel error -y @argumentos
    if ($LASTEXITCODE) { throw "ffmpeg fallo ($LASTEXITCODE): $($argumentos -join ' ')" }
}
function Get-Duracion([string]$fichero) {
    $s = & ffprobe -v error -show_entries format=duration -of csv=p=0 $fichero
    return [Math]::Round([double]::Parse(($s | Select-Object -First 1), [Globalization.CultureInfo]::InvariantCulture), 3)
}

# ---- Una toma por linea ---------------------------------------------------------------
$filtro = "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.04,areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.08,areverse," +
          "atempo=$($Tempo.ToString([Globalization.CultureInfo]::InvariantCulture)),acompressor=threshold=-20dB:ratio=3:attack=5:release=90:makeup=3,loudnorm=I=-16:TP=-2:LRA=11"
try {
    foreach ($id in $lineas.Keys) {
        $texto = $lineas[$id]
        $huella = Get-Huella $texto
        $mp3 = Join-Path $salida "$id.mp3"
        $hecha = $meta.ContainsKey($id) -and $meta[$id].huella -eq $huella -and (Test-Path -LiteralPath $mp3)
        if ($Solo -and $Solo -notcontains $id) { continue }
        if ($hecha -and -not $Todo -and -not $Solo) { Write-Host ("  {0,-13} {1,6} s  (ya estaba)" -f $id, $meta[$id].duracion); continue }
        $guion = ConvertTo-Palabras $texto
        for ($toma = 1; ; $toma++) {
            $wav = Join-Path $trabajo "$id.wav"
            Invoke-Voz $texto $wav
            Invoke-Ffmpeg @('-i', $wav, '-af', $filtro, '-ar', '48000', '-ac', '1', '-c:a', 'libmp3lame', '-b:a', '128k', $mp3)
            $oido = Invoke-Transcripcion $mp3
            $c = Get-Cobertura $guion (ConvertTo-Palabras $oido)
            if ($c.Tasa -ge $MIN_COBERTURA -and $c.Cola) { break }
            $porque = "coincide el $([Math]::Round($c.Tasa * 100)) %" + $(if (-not $c.Cola) { ', no se oye el final' } else { '' })
            if ($toma -ge $TOMAS) { throw "La toma «$id» no dice lo que el guion ($porque). Oído: $oido" }
            Write-Host "  $id, toma ${toma}: $porque; se repite."
        }
        $dur = Get-Duracion $mp3
        $meta[$id] = [pscustomobject]@{ huella = $huella; duracion = $dur; cobertura = [Math]::Round($c.Tasa, 3); toma = $toma; texto = $texto; oido = $oido }
        Write-Host ("  {0,-13} {1,6} s  {2,4} %  toma {3}" -f $id, $dur, [Math]::Round($c.Tasa * 100), $toma)
        Write-Host "                oído: $oido"
    }
} finally {
    Remove-Item -LiteralPath $trabajo -Recurse -Force -ErrorAction SilentlyContinue
    $orden = [ordered]@{}
    foreach ($id in $lineas.Keys) { if ($meta.ContainsKey($id)) { $orden[$id] = $meta[$id] } }
    [IO.File]::WriteAllText($fichMeta, ($orden | ConvertTo-Json -Depth 4), $utf8)
}
