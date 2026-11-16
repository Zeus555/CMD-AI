# Pedir un comando conversando («agregame un comando para ver mi IP publica»).
# Primero, sin modelo: reconocer la peticion (datos\peticiones.txt) y leer las
# propuestas. Despues, CON el modelo de verdad, las escenas de datos\escenas.txt
# pasan por el dialogo real de bin\ai.ps1 con las respuestas ya escritas.
# Con -SoloReconocer se queda en la primera parte (no hace falta el modelo).
param([string]$Raiz = (Split-Path -Parent $PSScriptRoot),
      [string]$Peticiones = (Join-Path $PSScriptRoot 'datos\peticiones.txt'),
      [string]$Escenas = (Join-Path $PSScriptRoot 'datos\escenas.txt'),
      [string]$Proveedor = 'gemma', [switch]$SoloReconocer)
# El dialogo REAL de bin\ai.ps1 (funciones sacadas por su arbol de sintaxis),
# con el modelo de verdad y las respuestas del usuario ya escritas.
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$root = $Raiz
. (Join-Path $root 'lib\providers.ps1'); . (Join-Path $root 'lib\core.ps1'); . (Join-Path $root 'lib\ui.ps1')
. (Join-Path $root 'lib\web.ps1'); . (Join-Path $root 'lib\equipo.ps1'); . (Join-Path $root 'lib\comandos.ps1')
foreach ($k in @($AI_COLOR.Keys)) { $AI_COLOR[$k] = '' }
$mal = 0; $n = 0
function Ver([string]$que, [bool]$ok, $extra = '') { $script:n++; if ($ok) { Write-Output "  ok   $que" } else { $script:mal++; Write-Output "  MAL  $que  $extra" } }

# ---- reconocer la peticion -------------------------------------------------
$rec = 0; $recMal = 0
foreach ($l in [IO.File]::ReadAllLines($Peticiones, [Text.Encoding]::UTF8)) {
    if (-not $l.Trim()) { continue }
    $i = $l.IndexOf('='); $esp = $l.Substring(0, $i); $frase = $l.Substring($i + 1)
    $p = Get-AIComandoPeticion $frase
    $got = if ($p) { "$($p.Comando)|$($p.Nombre)|$($p.Dato)" } else { '-' }
    $rec++
    if ($got -ne $esp) { $recMal++; $mal++; Write-Output "  MAL  peticion: $frase`n       esperado <$esp>`n       sale     <$got>" }
}
Write-Output "reconocer la peticion: $rec frases, $recMal mal"
Ver 'parece comando: Verbo-Nombre'  (Test-AIPareceComando 'Get-Process | Sort-Object CPU')
Ver 'parece comando: un programa'   (Test-AIPareceComando 'ipconfig /all')
Ver 'parece comando: una ruta'      (Test-AIPareceComando 'C:\x\y.exe')
Ver 'parece comando: un alias'      (Test-AIPareceComando 'irm https://x.com')
Ver 'no parece comando: una frase'  (-not (Test-AIPareceComando 'los tres procesos que mas memoria usan'))
Ver 'no parece comando: que sean cinco' (-not (Test-AIPareceComando 'que sean cinco'))
Ver 'nombre: de frase a nombre'     ((ConvertTo-AIComandoNombre ('IP p' + [char]0xFA + 'blica!')) -eq 'ip-publica')
Ver 'nombre: recorta a 30'          ((ConvertTo-AIComandoNombre ('a b ' * 20)).Length -le 30)
$p = ConvertFrom-AIComandoPropuesta "COMANDO: Get-Date`nNOMBRE: Fecha de Hoy"
Ver 'propuesta: dos lineas' ($p.Comando -eq 'Get-Date' -and $p.Nombre -eq 'fecha-hoy' -and -not $p.Imposible)
$p = ConvertFrom-AIComandoPropuesta ('```powershell' + "`n**COMANDO:** ``Get-Date```nNOMBRE: fecha`n" + '```')
Ver 'propuesta: con adornos' ($p.Comando -eq 'Get-Date' -and $p.Nombre -eq 'fecha') "<$($p.Comando)> <$($p.Nombre)>"
$p = ConvertFrom-AIComandoPropuesta 'IMPOSIBLE: habria que borrar archivos'
Ver 'propuesta: imposible' ($p.Imposible -eq 'habria que borrar archivos' -and -not $p.Comando)
$p = ConvertFrom-AIComandoPropuesta 'Get-Process | Sort-Object CPU'
Ver 'propuesta: solo el comando' ($p.Comando -eq 'Get-Process | Sort-Object CPU')
$p = ConvertFrom-AIComandoPropuesta 'Claro, aqui tienes una explicacion larga sin comando.'
Ver 'propuesta: nada util' (-not $p.Comando -and -not $p.Imposible)
Ver 'la guia nombra los comandos de la lista' ((Get-AIComandoGuia) -match 'Get-CimInstance' -and (Get-AIComandoGuia) -match 'Select-Object' -and (Get-AIComandoGuia) -notmatch 'Remove-Item')
if ($SoloReconocer) { Write-Output "MAL = $mal de $n"; exit $mal }

# ---- el dialogo -------------------------------------------------------------
$tok = $null; $err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'bin\ai.ps1'), [ref]$tok, [ref]$err)
if ($err.Count) { throw "bin\ai.ps1 no se analiza: $($err[0].Message)" }
foreach ($f in 'Get-AIComandoOpinion', 'Show-AIComandoRevision', 'Save-AIComandoNuevo', 'Add-AIComando', 'Find-AIComandoPropuesta', 'Start-AIComandoDialogo') {
    $d = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $f }, $true)
    if (-not $d) { throw "falta la funcion $f" }
    . ([scriptblock]::Create($d.Extent.Text))
}
$prov = Resolve-AIProvider $Proveedor; $Model = $prov.Model
$script:Web = $true; $rotulo = 'ia > '; $user = 'Usuario'
$messages = New-Object System.Collections.ArrayList
$CmdFile = Join-Path ([IO.Path]::GetTempPath()) ("comandos-dialogo-" + [Guid]::NewGuid().ToString('N') + '.json')
$script:Comandos = @(); $script:ComandosMalos = @(); $script:Respuestas = @(); $script:Sobran = 0
function Read-AILine { param($Prompt, $UsaPRL)
    if ($script:Respuestas.Count -eq 0) { Write-Host "$Prompt<se acabaron las respuestas>"; $script:Sobran++; return $null }
    $r = $script:Respuestas[0]; $script:Respuestas = @($script:Respuestas | Select-Object -Skip 1)
    Write-Host "$Prompt$r"; return $r
}
$titulo = ''; $pide = ''; $resp = @()
function Escena {
    Write-Output ''; Write-Output "=== $titulo"; Write-Output "Usuario > $pide"
    $pet = Get-AIComandoPeticion $pide
    if (-not $pet) { Write-Output '  (no se reconoce como peticion)'; $script:mal++; return }
    $script:Respuestas = @($resp); $script:Sobran = 0
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Start-AIComandoDialogo $pet $pide $false *>&1 | ForEach-Object { Write-Output ([string]$_) }
    Write-Output "    [$([Math]::Round($sw.Elapsed.TotalSeconds, 1)) s; respuestas sin usar: $($script:Respuestas.Count); pidio de mas: $($script:Sobran)]"
}
foreach ($l in [IO.File]::ReadAllLines($Escenas, [Text.Encoding]::UTF8)) {
    if ($l.StartsWith('#')) { $titulo = $l.Substring(1).Trim(); $resp = @(); continue }
    if ($l.StartsWith('>')) { $pide = $l.Substring(1).Trim(); continue }
    if ($l.StartsWith('<')) { $resp += $l.Substring(1).Trim(); continue }
    if ($l.StartsWith('=')) {
        Escena
        $partes = @($l.Substring(1).Trim() -split '\s+')
        $cuantos = [int]$partes[0]
        Ver "quedan $cuantos guardados" ($script:Comandos.Count -eq $cuantos) "hay $($script:Comandos.Count): $(($script:Comandos | ForEach-Object { $_.Nombre }) -join ', ')"
        if ($partes.Count -gt 1) { Ver "hay uno cuyo nombre contiene «$($partes[1])»" (@($script:Comandos | Where-Object { $_.Nombre -like "*$($partes[1])*" }).Count -ge 1) (($script:Comandos | ForEach-Object { $_.Nombre }) -join ', ') }
        Ver 'el dialogo no se quedo sin respuestas ni le sobraron' ($script:Sobran -eq 0 -and $script:Respuestas.Count -eq 0)
    }
}
Write-Output ''; Write-Output '--- comandos.json al final'
if (Test-Path $CmdFile) { Write-Output ([IO.File]::ReadAllText($CmdFile)); Remove-Item $CmdFile }
Write-Output "--- en la memoria de la conversacion: $($messages.Count) mensajes"
Write-Output "MAL = $mal de $n"
exit $mal
