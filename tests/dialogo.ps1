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

# ---- el idioma (sin modelo) ------------------------------------------------------
# Las ordenes en ingles se pasan a su nombre en espanol antes del despacho
# (ConvertTo-AIOrdenEs, sacada de bin\ai.ps1 con sus dos tablas), y caen en la
# misma rama que la espanola.
$astI = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'bin\ai.ps1'), [ref]$null, [ref]$null)
foreach ($v in 'AI_ORDENES', 'AI_SUBORDENES') {
    $a = $astI.Find({ param($x) $x -is [System.Management.Automation.Language.AssignmentStatementAst] -and $x.Left.Extent.Text -eq "`$$v" }, $true)
    . ([scriptblock]::Create($a.Extent.Text))
}
foreach ($f in 'ConvertTo-AIOrdenEs', 'Save-AIIdiomaAjuste', 'Get-AIRotulo') {
    $d = $astI.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $f }, $true)
    . ([scriptblock]::Create($d.Extent.Text))
}
# Las ramas del despacho: los "$line -match '^/...'" del bucle, en su orden.
$todas = @($astI.FindAll({ param($x) $x -is [System.Management.Automation.Language.BinaryExpressionAst] -and $x.Operator -eq 'Imatch' -and $x.Left.Extent.Text -eq '$line' -and $x.Right -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $x.Right.Value -like '^/*' }, $true) | ForEach-Object { $_.Right.Value })
function Rama([string]$linea) { $i = 0; foreach ($p in $todas) { $i++; if ($linea -match $p) { return $i } }; return 0 }
$parejas = [ordered]@{
    '/documents add D:\My Business' = '/documentos agregar D:\My Business'
    '/documents remove negocio'     = '/documentos quitar negocio'
    '/documents search opening hours' = '/documentos buscar opening hours'
    '/documents forget salaries.csv' = '/documentos olvidar salaries.csv'
    '/documents forgotten'          = '/documentos olvidos'
    '/documents restore 2'          = '/documentos recordar 2'
    '/documents cloud on'           = '/documentos nube on'
    '/documents update'             = '/documentos actualizar'
    '/documents list'               = '/documentos lista'
    '/documents off'                = '/documentos off'
    '/docs add D:\x'                = '/docs agregar D:\x'
    '/command add public-ip Get-Date' = '/comando agregar public-ip Get-Date'
    '/command remove public-ip'     = '/comando quitar public-ip'
    '/commands'                     = '/comandos'
    '/command web lottery https://x.com a=B' = '/comando web lottery https://x.com a=B'
    '/command public-ip'            = '/comando public-ip'
    '/preferences'                  = '/preferencias'
    '/preference add Dates in ISO'  = '/preferencia agregar Dates in ISO'
    '/preference remove 1'          = '/preferencia quitar 1'
    '/computer battery'             = '/equipo bateria'
    '/computer off'                 = '/equipo off'
    '/search dollar rate'           = '/buscar dollar rate'
    '/language en'                  = '/idioma en'
    '/ayuda'                        = '/help'
}
foreach ($k in $parejas.Keys) {
    $t = ConvertTo-AIOrdenEs $k
    Ver "orden en ingles: $k" ($t -ceq $parejas[$k]) "-> <$t>"
    Ver "  misma rama que en espanol" ((Rama $t) -gt 0 -and (Rama $t) -eq (Rama $parejas[$k])) "$(Rama $t)"
}
foreach ($k in '/documentos agregar D:\X', '/comando quitar ip', '/new', '/model qwen', '/web off', '/save C:\a b.json', '/documental') {
    Ver "orden en espanol intacta: $k" ((ConvertTo-AIOrdenEs $k) -ceq $k)
}
$ri = @($todas | Where-Object { $_ -like '^/idioma*' })[0]
Ver '/idioma sola: muestra el actual' ('/idioma' -match $ri -and -not $Matches[1])
Ver '/language es -> /idioma es' ((ConvertTo-AIOrdenEs '/language es') -match $ri -and $Matches[1] -eq 'es')

# settings.json: crear, mezclar sin perder claves, y no pisar uno roto.
$tmpI = Join-Path ([IO.Path]::GetTempPath()) ('idioma-prueba-' + [Guid]::NewGuid().ToString('N'))
$cf = Join-Path $tmpI 'sub\settings.json'
Ver 'settings.json: se crea' ((Save-AIIdiomaAjuste $cf 'en') -eq '' -and ([IO.File]::ReadAllText($cf) | ConvertFrom-Json).language -eq 'en')
[IO.File]::WriteAllText($cf, '{"provider":"xai","web":false,"system":"Eres breve.","idioma":"es"}', (New-Object Text.UTF8Encoding $false))
$null = Save-AIIdiomaAjuste $cf 'en'
$j = [IO.File]::ReadAllText($cf, [Text.Encoding]::UTF8) | ConvertFrom-Json
Ver 'settings.json: mezcla sin perder claves' ($j.language -eq 'en' -and $j.idioma -eq 'en' -and $j.provider -eq 'xai' -and $j.web -eq $false -and $j.system -eq 'Eres breve.')
Ver 'settings.json: sin BOM' ([IO.File]::ReadAllBytes($cf)[0] -eq [byte][char]'{')
[IO.File]::WriteAllText($cf, '{roto')
$m = Save-AIIdiomaAjuste $cf 'en'
Ver 'settings.json roto: lo dice y no lo pisa' ($m -and [IO.File]::ReadAllText($cf) -eq '{roto')

# El rotulo y unos mensajes, en ingles.
Set-AIIdioma en
Ver 'en: rotulo ai >' ((Get-AIRotulo) -eq 'ai > ')
$e1 = ''; try { $null = Resolve-AIProvider 'nadie' } catch { $e1 = $_.Exception.Message }
Ver 'en: proveedor desconocido' ($e1 -like "Unknown provider 'nadie'. Valid:*") $e1
Ver 'en: como arrancar el servidor' ((Get-AIProviderHint (Resolve-AIProvider 'gemma')) -eq 'Start the service:  pm2 start rpa-ai-portable')
$r1 = Invoke-AIChat -Provider @{ KeyVar = 'AI_PRUEBA_SIN_CLAVE_' + [Guid]::NewGuid().ToString('N'); NeedsKey = $true } -Messages @(@{ role = 'user'; content = 'x' })
Ver 'en: falta la clave' ($r1.Error -like 'the environment variable * is missing. Run:  AI -SetKey *') $r1.Error
Ver 'en: la herramienta de buscar' ((Get-AIWebTool).function.description -like 'Searches the internet*' -and (Get-AIWebTool).function.name -eq 'buscar_web')
Set-AIIdioma es
Ver 'es: rotulo ia >' ((Get-AIRotulo) -eq 'ia > ')
Ver 'es: como arrancar el servidor, igual que antes' ((Get-AIProviderHint (Resolve-AIProvider 'gemma')) -eq 'Arranca el servicio:  pm2 start rpa-ai-portable')
Ver 'es: la herramienta de buscar, igual que antes' ((Get-AIWebTool).function.description -like 'Busca en internet*')

# -Help de verdad (otro powershell), con el idioma de AI_LANG, de -Lang y de
# settings.json (en una carpeta de datos de prueba).
$ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$ai = Join-Path $root 'bin\ai.ps1'
$espanol = '[\u00C0-\u00FF\u00BF\u00A1\u00AB\u00BB]|\b(?:de|que|para|los|las|el|una|con|sin|del|por|esto|modo|comando|comandos|documentos|equipo|preferencias?|buscar|agregar|quitar|olvidar|olvidos|recordar|lista|nube|idioma|ayuda|pregunta|carpeta)\b'
$viejo = $env:AI_LANG; $viejoLA = $env:LOCALAPPDATA
try {
    $env:AI_LANG = 'en'
    $h = (& $ps -NoProfile -ExecutionPolicy Bypass -File $ai -Help) -join "`n"
    $sobra = @([regex]::Matches($h, $espanol) | ForEach-Object { $_.Value } | Select-Object -Unique)
    Ver 'en: -Help sin nada en espanol' ($h -like '*IN INTERACTIVE MODE*' -and $sobra.Count -eq 0) ($sobra -join ' ')
    Ver 'en: -Help con los nombres en ingles' ($h -like '*/documents add*' -and $h -like '*/language en|es*' -and $h -like '*/command add*' -and $h -like '*/preference add*' -and $h -like '*/computer*')
    $env:AI_LANG = 'es'
    $h = (& $ps -NoProfile -ExecutionPolicy Bypass -File $ai -Help) -join "`n"
    Ver 'es: -Help en espanol' ($h -like '*EN EL MODO INTERACTIVO*' -and $h -like '*/documentos agregar*' -and $h -like '*/idioma es|en*')
    $h = (& $ps -NoProfile -ExecutionPolicy Bypass -File $ai -Help -Lang en) -join "`n"
    Ver '-Lang en gana a AI_LANG' ($h -like '*IN INTERACTIVE MODE*')
    $env:AI_LANG = $null
    $env:LOCALAPPDATA = $tmpI
    New-Item -ItemType Directory -Path (Join-Path $tmpI 'PRC-CMD-AI') -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $tmpI 'PRC-CMD-AI\settings.json'), '{"language":"en"}')
    $h = (& $ps -NoProfile -ExecutionPolicy Bypass -File $ai -Help) -join "`n"
    Ver 'settings.json "language": "en"' ($h -like '*IN INTERACTIVE MODE*')
    [IO.File]::WriteAllText((Join-Path $tmpI 'PRC-CMD-AI\settings.json'), '{"idioma":"en"}')
    $h = (& $ps -NoProfile -ExecutionPolicy Bypass -File $ai -Help) -join "`n"
    Ver 'settings.json "idioma": "en" tambien vale' ($h -like '*IN INTERACTIVE MODE*')
    [IO.File]::WriteAllText((Join-Path $tmpI 'PRC-CMD-AI\settings.json'), '{"provider":"gemma"}')
    $h = (& $ps -NoProfile -ExecutionPolicy Bypass -File $ai -Help) -join "`n"
    Ver 'sin idioma y con datos de antes: espanol' ($h -like '*EN EL MODO INTERACTIVO*')
} finally { $env:AI_LANG = $viejo; $env:LOCALAPPDATA = $viejoLA }
Remove-Item -LiteralPath $tmpI -Recurse -Force -ErrorAction SilentlyContinue

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
