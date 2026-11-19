#requires -Version 5.1
# ---------------------------------------------------------------------------
#  Captura salidas REALES de la terminal para el video (docs\video).
#
#  Lanza el AI de verdad (bin\ai.ps1, el REPL de siempre) con lo que
#  "teclea" el usuario ya escrito en un fichero, y guarda lo que sale.
#  Para que la captura no toque nada del usuario:
#    - corre sobre una copia de bin\ y lib\ en una carpeta temporal;
#    - LOCALAPPDATA apunta a una carpeta vacia: documentos, comandos y
#      preferencias empiezan de cero y no se mezclan con los del usuario;
#    - USERNAME es "usuario" (en ingles, "user"), asi el prompt no lleva el
#      nombre de nadie.
#  Dos cambios en la copia, los dos de la entrada; lo que contesta el
#  programa no se toca:
#    - con la entrada entubada, ai.ps1 la toma entera como UNA pregunta
#      ("type fichero | AI"); en la copia ese desvio se salta y el REPL lee
#      linea a linea, como si se tecleara;
#    - Read-AILine repite la linea que lee: con la entrada redirigida no hay
#      eco, y sin el no se veria que tecleo el usuario.
#
#  Uso:
#    powershell -NoProfile -ExecutionPolicy Bypass -File docs\video\capturar.ps1 `
#        -Entrada docs\video\capturas\documentos.txt -Salida <fichero>
#  En la entrada, cada linea es lo que se teclea; una linea vacia es Enter
#  y las que empiezan por "#" son comentarios. Hace falta el llama-server
#  en http://127.0.0.1:8080 (y internet para las escenas que buscan).
# ---------------------------------------------------------------------------
param(
    [Parameter(Mandatory)][string]$Entrada,
    [Parameter(Mandatory)][string]$Salida,
    [string]$Raiz,
    [string]$Datos,  # carpeta de datos (LOCALAPPDATA); se reusa entre capturas
    # El idioma del programa (AI_LANG). Se fija siempre: con la carpeta de
    # datos vacia, sin el, el programa tomaria el idioma de Windows.
    [ValidateSet('es', 'en')][string]$Idioma = 'es'
)
$ErrorActionPreference = 'Stop'
if (-not $Raiz) { $Raiz = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) }
$utf8 = New-Object Text.UTF8Encoding $false

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('ai-captura-' + [Guid]::NewGuid().ToString('N').Substring(0, 6))
$app = Join-Path $tmp 'app'
New-Item -ItemType Directory -Path $app | Out-Null
foreach ($d in 'bin', 'lib') { Copy-Item -LiteralPath (Join-Path $Raiz $d) -Destination $app -Recurse }
if (-not $Datos) { $Datos = Join-Path $tmp 'datos' }
New-Item -ItemType Directory -Path $Datos -Force | Out-Null

# El eco de lo tecleado, en el plan B de Read-AILine (stdin redirigido).
$ui = Join-Path $app 'lib\ui.ps1'
$t = [IO.File]::ReadAllText($ui, [Text.Encoding]::UTF8)
$viejo = '    return [Console]::In.ReadLine()'
if (-not $t.Contains($viejo)) { throw 'Read-AILine cambio: revisa el eco de capturar.ps1' }
$t = $t.Replace($viejo, '    $l = [Console]::In.ReadLine(); if ($null -ne $l) { [Console]::Out.WriteLine($l) }; return $l')
[IO.File]::WriteAllText($ui, $t, (New-Object Text.UTF8Encoding $true))
# El REPL, aunque la entrada venga entubada.
$aiCopia = Join-Path $app 'bin\ai.ps1'
$t = [IO.File]::ReadAllText($aiCopia, [Text.Encoding]::UTF8)
$re = 'if \(\[Console\]::IsInputRedirected\) \{(\s+\$todo = )'
if (-not [regex]::IsMatch($t, $re)) { throw 'la entrada entubada de ai.ps1 cambio: revisa capturar.ps1' }
$t = [regex]::Replace($t, $re, 'if ($false) {$1')
[IO.File]::WriteAllText($aiCopia, $t, (New-Object Text.UTF8Encoding $true))

# Lo tecleado, sin comentarios, en UTF-8 sin BOM.
$lineas = @([IO.File]::ReadAllLines((Resolve-Path -LiteralPath $Entrada).ProviderPath, [Text.Encoding]::UTF8) | Where-Object { -not $_.StartsWith('#') })
$in = Join-Path $tmp 'entrada.txt'
[IO.File]::WriteAllText($in, (($lineas -join "`r`n") + "`r`n"), $utf8)

$ai = Join-Path $app 'bin\ai.ps1'
$cmd = "[Console]::InputEncoding = New-Object Text.UTF8Encoding `$false; [Console]::OutputEncoding = New-Object Text.UTF8Encoding `$false; . '$ai'"
$antes = @{ LOCALAPPDATA = $env:LOCALAPPDATA; USERNAME = $env:USERNAME; AI_LANG = $env:AI_LANG }
$env:LOCALAPPDATA = $Datos; $env:AI_LANG = $Idioma
$env:USERNAME = if ($Idioma -eq 'en') { 'user' } else { 'usuario' }
$err = Join-Path $tmp 'error.txt'
try {
    $p = Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $cmd) `
        -NoNewWindow -Wait -PassThru -RedirectStandardInput $in -RedirectStandardOutput $Salida -RedirectStandardError $err
} finally { $env:LOCALAPPDATA = $antes.LOCALAPPDATA; $env:USERNAME = $antes.USERNAME; $env:AI_LANG = $antes.AI_LANG }
$e = [IO.File]::ReadAllText($err)
if ($e.Trim()) { Write-Output "--- stderr ---`n$e" }
Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
Write-Output "salida: $Salida (codigo $($p.ExitCode))"
