# Datos del equipo (lib\equipo.ps1): reloj, grupos pedidos, formato con un
# equipo de mentira, la herramienta, el propio fichero y, al final, la lectura
# de verdad de este equipo (se ensena en pantalla y no se guarda en ningun sitio).
param([string]$Raiz = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
. (Join-Path $Raiz 'lib\equipo.ps1')
$mal = 0
function Plano([string]$x) { return ($x.Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', '') }
function Ver([string]$que, [bool]$ok, $extra = '') { if ($ok) { Write-Host "  ok   $que" } else { $script:mal++; Write-Host "  MAL  $que  $extra" } }

# reloj
$t = Get-AIClockText ([DateTime]'2026-11-14T10:07:00')
Ver 'reloj por la manana' ((Plano $t) -match '^sabado 14 de noviembre de 2026, 10:07 a\. m\. \(zona UTC[+-]\d\d:\d\d\)$') $t
$t = Get-AIClockText ([DateTime]'2026-03-04T00:05:00')
Ver 'medianoche es 12 a. m.' ((Plano $t) -like 'miercoles 4 de marzo de 2026, 12:05 a. m. (zona*') $t
$t = Get-AIClockText ([DateTime]'2026-03-04T13:05:00')
Ver 'la una de la tarde' ((Plano $t) -like '*, 1:05 p. m. (zona*') $t
$t = Get-AIClockText ([DateTime]'2026-03-04T12:00:00')
Ver 'mediodia es 12 p. m.' ((Plano $t) -like '*, 12:00 p. m. (zona*') $t
$n = Get-AIClockNote ([DateTime]'2026-11-14T10:07:00')
Ver 'la nota conserva la fecha ISO' ($n.StartsWith('Hoy es 2026-11-14.')) $n
Ver 'la nota da hora y fecha' ((Plano $n) -like '*la hora es 10:07 a. m. y la fecha es sabado 14 de noviembre de 2026.*') $n

# grupos pedidos
function G($s) { (ConvertTo-AIEquipoGroups $s) -join ',' }
Ver 'json con lista'            ((G '{"datos":["red"]}') -eq 'red')
Ver 'json con dos, en orden'    ((G '{"datos":["disco","bateria"]}') -eq 'bateria,disco')
Ver 'json con cadena y comas'   ((G '{"datos":"memoria, procesador"}') -eq 'procesador,memoria')
Ver 'acentos y alias'           ((G ('{"datos":["Bater' + [char]0xED + 'a","IP","RAM","gr' + [char]0xE1 + 'fica"]}')) -eq 'bateria,red,memoria,grafica')
# el comando /equipo del modo interactivo
function Cmd($linea) {
    if ($linea -match '^/equipo\s+(on|off|si|no)$') { return 'interruptor:' + $Matches[1] }
    if ($linea -match '^/equipo(\s+(.+))?$') { return (ConvertTo-AIEquipoGroups ([string]$Matches[2])) -join ',' }
    return 'al modelo'
}
Ver '/equipo: todos'        ((Cmd '/equipo') -eq ($AI_EQUIPO_GRUPOS -join ','))
Ver '/equipo red'           ((Cmd '/equipo red') -eq 'red')
Ver '/equipo wifi y disco'  ((Cmd '/equipo wifi y disco') -eq 'red,disco')
Ver '/equipo off'           ((Cmd '/equipo off') -eq 'interruptor:off')
Ver '/equipos no es comando' ((Cmd '/equipos') -eq 'al modelo')
Ver 'lo que no esta se ignora'  ((G '{"datos":["red","borrar-todo","calc.exe"]}') -eq 'red')
Ver 'nada valido: todos'        ((G '{"datos":["formatear"]}') -eq ($AI_EQUIPO_GRUPOS -join ','))
Ver 'vacio: todos'              ((G '') -eq ($AI_EQUIPO_GRUPOS -join ','))
Ver 'json roto: todos'          ((G '{"datos":[') -eq ($AI_EQUIPO_GRUPOS -join ','))
Ver 'otra clave'                ((G '{"grupo":"wifi"}') -eq 'red')
Ver 'texto del usuario'         ((G 'red disco') -eq 'red,disco')

# duraciones y numeros
Ver '45 min'      ((Plano (Format-AIDuration 45)) -eq '45 min')
Ver '2 h 10 min'  ((Plano (Format-AIDuration 130)) -eq '2 h 10 min')
Ver '3 h'         ((Plano (Format-AIDuration 180)) -eq '3 h')
Ver '2 dias 2 h'  ((Plano (Format-AIDuration 3000)) -eq '2 dias 2 h')
Ver '1 dia'       ((Plano (Format-AIDuration 1440)) -eq '1 dia')
Ver 'coma decimal' ((Format-AINumber 15.82) -eq '15,8')
Ver 'entero sin coma' ((Format-AINumber 16) -eq '16')

# formato con un equipo de mentira
$lin = Format-AIEquipo 'bateria' @{ hay = $true; porcentaje = 73; enchufado = $false; cargando = $false; minutos = 130 }
Ver 'bateria sin enchufar' ((Plano $lin[0]) -eq '- Bateria: 73 %, sin enchufar a la corriente. Windows calcula que quedan unas 2 h 10 min.') $lin[0]
$lin = Format-AIEquipo 'bateria' @{ hay = $true; porcentaje = 100; enchufado = $true; cargando = $false; minutos = $null }
Ver 'bateria enchufada' ((Plano $lin[0]) -eq '- Bateria: 100 %, enchufado a la corriente.') $lin[0]
$lin = Format-AIEquipo 'bateria' @{ hay = $false }
Ver 'sin bateria' ((Plano $lin[0]) -like '*no tiene bateria*') $lin[0]
$lin = Format-AIEquipo 'red' @{ internet = $false; wifi = @{ ssid = 'Red de pruebas'; senal = 82 }
    conexiones = @(@{ nombre = 'Wi-Fi'; tipo = 'wifi'; ip = '192.168.50.23'; puerta = '192.168.50.1'; dns = @('192.168.50.1', '9.9.9.9'); mbps = 300 }) }
Ver 'red: cuatro lineas' ($lin.Count -eq 4) $lin.Count
Ver 'red: sin internet' ((Plano $lin[0]) -like '- Internet: no,*') $lin[0]
Ver 'red: wifi' ((Plano $lin[1]) -eq '- Red wifi a la que esta conectado: "Red de pruebas", con senal del 82 %.') $lin[1]
Ver 'red: ip' ((Plano $lin[2]) -eq '- Direccion IP de este equipo en la red local: 192.168.50.23 (por wifi, adaptador "Wi-Fi"); puerta de enlace (router): 192.168.50.1; servidores DNS: 192.168.50.1 y 9.9.9.9; velocidad del enlace: 300 Mbps.') $lin[2]
Ver 'red: la publica no se inventa' ((Plano $lin[3]) -like '*IP publica*no esta en el equipo*') $lin[3]
$lin = Format-AIEquipo 'red' @{ internet = $null; wifi = $null; conexiones = @() }
Ver 'red: sin conexiones' ((Plano $lin[0]) -like '*ninguna activa*') $lin[0]
$lin = Format-AIEquipo 'disco' @{ unidades = @(@{ unidad = 'C:'; etiqueta = 'Windows'; totalGB = 476.3; libreGB = 120.4; tipo = 'fijo' }) }
Ver 'disco' ((Plano $lin[0]) -eq '- Disco C: (fijo, "Windows"): 476,3 GB en total; 120,4 GB libres y 355,9 GB ocupados.') $lin[0]
$lin = Format-AIEquipo 'memoria' @{ totalMB = 16200; libreMB = 6350 }
Ver 'memoria' ((Plano $lin[0]) -eq '- Memoria RAM: 15,8 GB en total; ahora hay 6,2 GB libres y 9,6 GB en uso.') $lin[0]
$lin = Format-AIEquipo 'grafica' @{ nombres = @('A', 'B') }
Ver 'dos graficas' ((Plano $lin[0]) -eq '- Tarjetas graficas (2): A; B.') $lin[0]

# en ingles: textos, cifras con punto, fechas y unidades en ingles
Set-AIIdioma en
$t = Get-AIClockText ([DateTime]'2026-11-14T10:07:00')
Ver 'en: reloj' ($t -match '^Saturday, November 14, 2026, 10:07 AM \(time zone UTC[+-]\d\d:\d\d\)$') $t
Ver 'en: 12 AM y 1 PM' ((Get-AIClockText ([DateTime]'2026-03-04T00:05:00')) -like 'Wednesday, March 4, 2026, 12:05 AM*' -and (Get-AIClockText ([DateTime]'2026-03-04T13:05:00')) -like '*, 1:05 PM (time zone*')
$n = Get-AIClockNote ([DateTime]'2026-11-14T10:07:00')
Ver 'en: la nota' ($n.StartsWith('Today is 2026-11-14.') -and $n -like '*the time right now is 10:07 AM and the date is Saturday, November 14, 2026.*') $n
Ver 'en: punto decimal' ((Format-AINumber 15.82) -eq '15.8')
Ver 'en: 2 days 2 h' ((Format-AIDuration 3000) -eq '2 days 2 h' -and (Format-AIDuration 1440) -eq '1 day' -and (Format-AIDuration 130) -eq '2 h 10 min')
$lin = Format-AIEquipo 'bateria' @{ hay = $true; porcentaje = 73; enchufado = $false; cargando = $false; minutos = 130 }
Ver 'en: bateria' ($lin[0] -eq '- Battery: 73%, not plugged in. Windows estimates about 2 h 10 min left.') $lin[0]
$lin = Format-AIEquipo 'memoria' @{ totalMB = 32563; libreMB = 6350 }
Ver 'en: memoria' ($lin[0] -eq '- RAM: 31.8 GB in total; right now 6.2 GB free and 25.6 GB in use.') $lin[0]
$lin = Format-AIEquipo 'disco' @{ unidades = @(@{ unidad = 'C:'; etiqueta = 'Windows'; totalGB = 476.3; libreGB = 120.4; tipo = 'fijo' }) }
Ver 'en: disco' ($lin[0] -eq '- Disk C: (fixed, "Windows"): 476.3 GB in total; 120.4 GB free and 355.9 GB used.') $lin[0]
$lin = Format-AIEquipo 'red' @{ internet = $true; wifi = @{ ssid = 'Test'; senal = 82 }
    conexiones = @(@{ nombre = 'Wi-Fi'; tipo = 'wifi'; ip = '192.168.50.23'; puerta = '192.168.50.1'; dns = @('192.168.50.1', '9.9.9.9'); mbps = 300 }) }
Ver 'en: red' ($lin[1] -eq '- Wi-Fi network it is connected to: "Test", with 82% signal.' -and $lin[2] -eq '- IP address of this computer on the local network: 192.168.50.23 (over Wi-Fi, adapter "Wi-Fi"); gateway (router): 192.168.50.1; DNS servers: 192.168.50.1 and 9.9.9.9; link speed: 300 Mbps.') ($lin -join ' / ')
$o = (Get-AIEquipoTool).function
Ver 'en: la herramienta en ingles, mismos grupos' ($o.description -like 'Reads data from THIS computer*' -and $o.name -eq 'datos_equipo' -and @($o.parameters.properties.datos.items.enum).Count -eq 8)
Ver 'en: sin espanol en las lineas' (-not ((@(Format-AIEquipo 'bateria' @{ hay = $false }) + @(Format-AIEquipo 'grafica' @{ nombres = @() })) -join ' ' -match 'equipo|tarjeta|bater'))
Set-AIIdioma es
Ver 'y de vuelta en espanol' ((Format-AINumber 15.82) -eq '15,8' -and (Get-AIEquipoTool).function.description -like 'Lee datos de ESTE equipo*')

# la herramienta viaja bien como JSON
$j = @{ tools = @($AI_EQUIPO_TOOL) } | ConvertTo-Json -Depth 10 -Compress
$o = $j | ConvertFrom-Json
Ver 'herramienta: nombre' ($o.tools[0].function.name -eq 'datos_equipo')
Ver 'herramienta: enum de ocho' (@($o.tools[0].function.parameters.properties.datos.items.enum).Count -eq 8)
Ver 'herramienta: required es lista' ($j -match '"required":\["datos"\]') $j

# solo ASCII en el fichero (aparte del BOM)
$bytes = [IO.File]::ReadAllBytes((Join-Path $Raiz 'lib\equipo.ps1'))
$txt = [Text.Encoding]::GetEncoding(28591).GetString($bytes)
Ver 'equipo.ps1 lleva BOM' ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
Ver 'sin mayusculas acentuadas (romperian el analisis sin BOM)' (-not [regex]::IsMatch($txt, [string][char]0xC3 + '[' + [char]0x80 + '-' + [char]0x9F + ']'))
# ninguna orden externa salvo netsh con argumentos fijos, y ninguna peticion a internet
$src = [IO.File]::ReadAllText((Join-Path $Raiz 'lib\equipo.ps1'))
Ver 'sin Invoke-Expression ni Start-Process ni cmd' ($src -notmatch 'Invoke-Expression|\biex\b|Start-Process|cmd\.exe|powershell\.exe')
Ver 'sin peticiones web' ($src -notmatch 'WebRequest|WebClient|Invoke-RestMethod|TcpClient|https?://')
Ver 'netsh con argumentos fijos' (([regex]::Matches($src, '&\s*\$netsh[^\r\n]*')).Count -eq 1 -and $src -match '& \$netsh wlan show interfaces 2>\$null')

# la lectura de verdad
$sw = [Diagnostics.Stopwatch]::StartNew()
$e = Get-AIEquipoText $AI_EQUIPO_GRUPOS -Reloj
$ms1 = $sw.ElapsedMilliseconds
$sw.Restart(); $null = Get-AIEquipoText @('red') -ParaModelo; $ms2 = $sw.ElapsedMilliseconds
Ver 'las ocho lecturas dan dato' ($e.Fallidos.Count -eq 0) ($e.Fallidos -join ',')
Write-Host ''
Write-Host $e.Text
Write-Host ''
Write-Host "todo: $ms1 ms; solo red, segunda vez: $ms2 ms"
Write-Host "MAL = $mal"
exit $mal
