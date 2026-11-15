#requires -Version 5.1
# ============================================================================
#  equipo.ps1 - Lo que el equipo ya sabe, sin salir a internet.
#
#  La hora no esta en internet ni en la memoria del modelo: esta en el reloj
#  de la laptop. Lo mismo la bateria, la red a la que esta conectada, su IP
#  local o el espacio en disco. Preguntar eso no necesita conexion.
#
#  Tres piezas:
#    - EL RELOJ va en la instruccion de sistema de cada peticion
#      (Get-AIClockNote): la hora y la fecha se contestan a la primera, sin
#      herramienta y con cualquier proveedor.
#    - EL ATAJO (Find-AIEquipoGroups): si la pregunta pide a las claras un
#      dato de este equipo ("cual es mi IP", "cuanta bateria me queda"), el
#      programa lo lee ANTES de preguntar al modelo y se lo pasa junto a la
#      pregunta. No depende de que el modelo sepa pedir herramientas: medido
#      el 2026-11-15, Gemma 3 4B no la pedia y contestaba una IP y un
#      porcentaje de bateria inventados.
#    - LA HERRAMIENTA datos_equipo, igual que buscar_web, para lo que el
#      atajo no reconoce: el modelo decide si la pregunta lo necesita y pide
#      uno o varios grupos. A diferencia de buscar_web se ofrece SIEMPRE,
#      haya o no internet, porque no sale a ningun sitio.
#
#  SOLO LECTURA Y LISTA CERRADA. Del modelo llega el NOMBRE de un grupo y
#  aqui se elige que leer; ningun texto del usuario ni del modelo llega a una
#  linea de comandos. Nada de esto hace peticiones a internet. Un dato que
#  Windows no da se dice que no se pudo leer; no se inventa.
#
#  ACENTOS: los comentarios y las expresiones van en ASCII, como en el resto
#  del programa, pero las frases que acaba leyendo el usuario (las lineas de
#  datos, que el modelo copia casi tal cual, y lo que ensena /equipo) llevan
#  sus acentos. Por eso este fichero necesita su BOM (tools\build.ps1). Solo
#  minusculas acentuadas: sin BOM se verian mal, pero ninguna rompe el
#  analisis del script como lo haria una mayuscula acentuada.
#
#  OJO con los proveedores en la nube (OpenAI, xAI): lo que el modelo pide
#  leer viaja a ese proveedor junto a la conversacion, como cualquier otro
#  mensaje. Se apaga con -NoEquipo, con "equipo": false en settings.json o
#  con /equipo off. El comando /equipo lo ensena en pantalla sin modelo.
#
#  Es la misma lista de lecturas que la ruta /equipo del puente de Gemma
#  Portable (tts\piper-server.ps1); aqui se lee en el propio proceso.
# ============================================================================

$AI_EQUIPO_GRUPOS = @('bateria', 'red', 'equipo', 'sistema', 'procesador', 'memoria', 'disco', 'grafica')

# Como se llama cada grupo cuando hay que decir que no se pudo leer.
$AI_EQUIPO_NOMBRE = @{
    bateria = 'Batería'; red = 'Red'; equipo = 'Equipo'; sistema = 'Sistema'
    procesador = 'Procesador'; memoria = 'Memoria RAM'; disco = 'Discos'; grafica = 'Tarjeta gráfica'
}

# Otras formas de pedir un grupo. El esquema de la herramienta ya limita los
# valores, pero no todos los servidores lo hacen cumplir.
$AI_EQUIPO_ALIAS = @{
    pila = 'bateria'; carga = 'bateria'; energia = 'bateria'
    wifi = 'red'; internet = 'red'; ip = 'red'; conexion = 'red'; dns = 'red'; router = 'red'; ethernet = 'red'
    nombre = 'equipo'; usuario = 'equipo'; modelo = 'equipo'; marca = 'equipo'; pc = 'equipo'; laptop = 'equipo'
    windows = 'sistema'; so = 'sistema'; encendido = 'sistema'
    cpu = 'procesador'; ram = 'memoria'
    discos = 'disco'; almacenamiento = 'disco'; espacio = 'disco'
    gpu = 'grafica'; video = 'grafica'
}

# La herramienta tal como viaja en la peticion. La descripcion es lo que el
# modelo lee para decidir.
$AI_EQUIPO_TOOL = @{
    type     = 'function'
    function = @{
        name        = 'datos_equipo'
        description = 'Lee datos de ESTE equipo (la computadora del usuario, donde corre este programa) y de su red local. No necesita internet. Usala cuando el usuario pregunte por los datos de su propio equipo: su bateria; su conexion (si tiene internet, a que red wifi esta conectado, la senal, su direccion IP, la puerta de enlace o router, los DNS); el nombre del equipo o del usuario, la marca y el modelo; la version de Windows y cuanto lleva encendido; el procesador; la memoria RAM; los discos y su espacio libre; la tarjeta grafica. Solo sabe de este equipo: los datos de cualquier otro aparato (un telefono, otro modelo de computadora) son una pregunta normal, que se contesta con lo que sepas o buscando en internet.'
        parameters  = @{
            type       = 'object'
            properties = @{
                datos = @{
                    type        = 'array'
                    items       = @{ type = 'string'; enum = $AI_EQUIPO_GRUPOS }
                    description = 'que grupos leer: bateria; red (internet, wifi, IP, puerta de enlace, DNS); equipo (nombre, usuario, marca y modelo); sistema (Windows, tiempo encendido); procesador; memoria (RAM); disco; grafica'
                }
            }
            required   = @('datos')
        }
    }
}

# ---------------------------------------------------------------------------
#  El reloj. Los nombres de dia y mes van escritos aqui: los de la cultura de
#  Windows saldrian en ingles en un Windows en ingles.
# ---------------------------------------------------------------------------
$AI_DIAS  = @('domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado')
$AI_MESES = @('enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto',
              'septiembre', 'octubre', 'noviembre', 'diciembre')

function Get-AIClock {
    <#  Las tres piezas del reloj: hora "10:07 a. m.", fecha "domingo 15 de
        noviembre de 2026" y zona "UTC-08:00".  #>
    param([DateTime]$Now = (Get-Date))
    $h12 = $Now.Hour % 12
    if ($h12 -eq 0) { $h12 = 12 }
    $ampm = if ($Now.Hour -lt 12) { 'a. m.' } else { 'p. m.' }
    $off = [TimeZoneInfo]::Local.GetUtcOffset($Now)
    $signo = if ($off -lt [TimeSpan]::Zero) { '-' } else { '+' }
    return @{
        Hora  = '{0}:{1:00} {2}' -f $h12, $Now.Minute, $ampm
        Fecha = '{0} {1} de {2} de {3}' -f $AI_DIAS[[int]$Now.DayOfWeek], $Now.Day, $AI_MESES[$Now.Month - 1], $Now.Year
        Zona  = 'UTC{0}{1:00}:{2:00}' -f $signo, [Math]::Abs($off.Hours), [Math]::Abs($off.Minutes)
    }
}

function Get-AIClockText {
    <#  "domingo 15 de noviembre de 2026, 10:07 a. m. (zona UTC-08:00)"  #>
    param([DateTime]$Now = (Get-Date))
    $r = Get-AIClock $Now
    return "$($r.Fecha), $($r.Hora) (zona $($r.Zona))"
}

function Get-AIClockNote {
    <#  Lo que se anade a la instruccion de sistema en cada peticion. Se
        conserva la fecha en formato ISO: es la que el modelo usa para fechar
        las busquedas. La zona va en frase aparte: metida entre parentesis
        junto a la hora, el modelo la repetia al contestar "que hora es".  #>
    param([DateTime]$Now = (Get-Date))
    $r = Get-AIClock $Now
    return ("Hoy es $($Now.ToString('yyyy-MM-dd')). Según el reloj de este equipo, ahora mismo la hora es $($r.Hora) y la fecha es $($r.Fecha). " +
            "La zona horaria del equipo es $($r.Zona). Si el usuario pregunta qué hora es o qué día es, dile la hora o la fecha del reloj de este equipo.")
}

# ---------------------------------------------------------------------------
#  Las lecturas. Una por grupo; devuelven una tabla o $null si Windows no da
#  el dato. Lo que no cambia mientras dura el programa se lee una sola vez.
# ---------------------------------------------------------------------------
$script:AIEquipoFijo = @{}

function Read-AIEquipo {
    param([string]$Grupo)
    switch ($Grupo) {
        'bateria' {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            $p = [System.Windows.Forms.SystemInformation]::PowerStatus
            $estado = [int]$p.BatteryChargeStatus
            if ($estado -eq 255) { return $null }                      # Windows no lo sabe
            if (($estado -band 128) -ne 0) { return @{ hay = $false } }
            $pct = [double]$p.BatteryLifePercent
            if ($pct -lt 0 -or $pct -gt 1) { return $null }
            $enchufado = ([string]$p.PowerLineStatus -eq 'Online')
            $min = $null
            if (-not $enchufado -and $p.BatteryLifeRemaining -gt 0) { $min = [int][Math]::Round($p.BatteryLifeRemaining / 60) }
            return @{ hay = $true; porcentaje = [int][Math]::Round($pct * 100); enchufado = $enchufado
                      cargando = (($estado -band 8) -ne 0); minutos = $min }
        }
        'red' {
            $con = New-Object System.Collections.ArrayList
            foreach ($n in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
                $tipoNic = [string]$n.NetworkInterfaceType
                if ([string]$n.OperationalStatus -ne 'Up' -or $tipoNic -eq 'Loopback' -or $tipoNic -eq 'Tunnel') { continue }
                $ipp = $n.GetIPProperties()
                $ip4 = @($ipp.UnicastAddresses | Where-Object { [string]$_.Address.AddressFamily -eq 'InterNetwork' } | ForEach-Object { $_.Address.ToString() })
                if (-not $ip4.Count) { continue }
                $gw = @($ipp.GatewayAddresses | Where-Object { [string]$_.Address.AddressFamily -eq 'InterNetwork' -and $_.Address.ToString() -ne '0.0.0.0' } | ForEach-Object { $_.Address.ToString() })
                $dns = @($ipp.DnsAddresses | Where-Object { [string]$_.AddressFamily -eq 'InterNetwork' } | ForEach-Object { $_.ToString() })
                $tipo = 'otra'
                if ($tipoNic -eq 'Wireless80211') { $tipo = 'wifi' } elseif ($tipoNic -match 'Ethernet') { $tipo = 'cable' }
                $puerta = $null; if ($gw.Count) { $puerta = $gw[0] }
                [void]$con.Add(@{ nombre = [string]$n.Name; tipo = $tipo; ip = $ip4[0]; puerta = $puerta; dns = $dns
                                  mbps = [int]([Math]::Min([double]$n.Speed, 1e11) / 1e6) })
            }
            # Solo las conexiones con puerta de enlace, que son por las que se
            # sale: los adaptadores virtuales (maquinas virtuales, WSL) tienen
            # IP pero no llevan a ningun sitio. Si ninguna la tiene, todas.
            $conSalida = @($con | Where-Object { $_.puerta })
            $lista = if ($conSalida.Count) { $conSalida } else { @($con) }
            # El nombre de la red wifi: netsh, con sus argumentos fijos.
            $wifi = $null
            try {
                $netsh = Join-Path $env:SystemRoot 'System32\netsh.exe'
                $ssid = ''; $senal = $null
                foreach ($l in (& $netsh wlan show interfaces 2>$null)) {
                    if (-not $ssid -and $l -match '^\s*SSID\s*:\s*(.+?)\s*$') { $ssid = $Matches[1] }
                    elseif ($null -eq $senal -and $l -match ':\s*(\d{1,3})\s*%\s*$') { $senal = [int]$Matches[1] }
                }
                if ($ssid) { $wifi = @{ ssid = $ssid; senal = $senal } }
            } catch { }
            # Si hay salida a internet lo dice Windows (su indicador de red):
            # aqui no se hace ninguna peticion fuera para averiguarlo.
            $internet = $null
            try {
                $nlm = [Activator]::CreateInstance([Type]::GetTypeFromCLSID([Guid]'DCB00C01-570F-4A9B-8D69-199FDBA5723B'))
                $internet = [bool]$nlm.IsConnectedToInternet
            } catch { }
            return @{ internet = $internet; conexiones = @($lista); wifi = $wifi }
        }
        'equipo' {
            if (-not $script:AIEquipoFijo.ContainsKey('equipo')) {
                $cs = Get-CimInstance Win32_ComputerSystem -Property Manufacturer, Model
                # los equipos montados por piezas traen textos de relleno
                $relleno = '^(To be filled by O\.E\.M\.|System manufacturer|System Product Name|Default string|Not Applicable|)$'
                $fab = ([string]$cs.Manufacturer).Trim(); if ($fab -match $relleno) { $fab = '' }
                $mod = ([string]$cs.Model).Trim(); if ($mod -match $relleno) { $mod = '' }
                $script:AIEquipoFijo['equipo'] = @($fab, $mod)
            }
            return @{ nombre = [string]$env:COMPUTERNAME; usuario = [string]$env:USERNAME
                      fabricante = $script:AIEquipoFijo['equipo'][0]; modelo = $script:AIEquipoFijo['equipo'][1] }
        }
        'sistema' {
            $os = Get-CimInstance Win32_OperatingSystem -Property Caption, Version, OSArchitecture, LastBootUpTime
            return @{ nombre = ([string]$os.Caption).Trim(); version = [string]$os.Version; arquitectura = ([string]$os.OSArchitecture).Trim()
                      minutosEncendido = [int]((Get-Date) - $os.LastBootUpTime).TotalMinutes }
        }
        'memoria' {
            $os = Get-CimInstance Win32_OperatingSystem -Property TotalVisibleMemorySize, FreePhysicalMemory
            return @{ totalMB = [int]($os.TotalVisibleMemorySize / 1024); libreMB = [int]($os.FreePhysicalMemory / 1024) }
        }
        'procesador' {
            if (-not $script:AIEquipoFijo.ContainsKey('procesador')) {
                $cpu = @(Get-CimInstance Win32_Processor -Property Name, NumberOfCores, NumberOfLogicalProcessors)[0]
                $script:AIEquipoFijo['procesador'] = @{ nombre = (([string]$cpu.Name) -replace '\s+', ' ').Trim()
                                                        nucleos = [int]$cpu.NumberOfCores; hilos = [int]$cpu.NumberOfLogicalProcessors }
            }
            return $script:AIEquipoFijo['procesador']
        }
        'grafica' {
            if (-not $script:AIEquipoFijo.ContainsKey('grafica')) {
                $script:AIEquipoFijo['grafica'] = @(Get-CimInstance Win32_VideoController -Property Name | ForEach-Object { ([string]$_.Name).Trim() } | Where-Object { $_ })
            }
            return @{ nombres = @($script:AIEquipoFijo['grafica']) }
        }
        'disco' {
            $u = New-Object System.Collections.ArrayList
            foreach ($d in [IO.DriveInfo]::GetDrives()) {
                $t = [string]$d.DriveType
                if (-not $d.IsReady -or ($t -ne 'Fixed' -and $t -ne 'Removable')) { continue }
                [void]$u.Add(@{ unidad = $d.Name.TrimEnd('\'); etiqueta = [string]$d.VolumeLabel
                                totalGB = [Math]::Round($d.TotalSize / 1GB, 1); libreGB = [Math]::Round($d.AvailableFreeSpace / 1GB, 1)
                                tipo = $(if ($t -eq 'Fixed') { 'fijo' } else { 'extraíble' }) })
            }
            return @{ unidades = @($u) }
        }
    }
    return $null
}

# ---------------------------------------------------------------------------
#  De la lectura al texto. Es lo que lee el modelo y lo que ensena /equipo.
# ---------------------------------------------------------------------------
function Format-AINumber {
    <#  Con coma decimal y sin depender de la cultura de Windows.  #>
    param([double]$N)
    return $N.ToString('0.#', [Globalization.CultureInfo]::InvariantCulture).Replace('.', ',')
}

function Format-AIDuration {
    <#  130 -> "2 h 10 min"; 3000 -> "2 dias 2 h"  #>
    param([int]$Min)
    if ($Min -lt 60) { return "$Min min" }
    $h = [Math]::Floor($Min / 60); $m = $Min % 60
    if ($h -lt 24) { if ($m) { return "$h h $m min" } else { return "$h h" } }
    $d = [Math]::Floor($h / 24); $h = $h % 24
    $dias = if ($d -eq 1) { '1 día' } else { "$d días" }
    if ($h) { return "$dias $h h" } else { return $dias }
}

function Format-AIEquipo {
    <#  Las lineas de un grupo ya leido.  #>
    param([string]$Grupo, $D)
    $l = @()
    switch ($Grupo) {
        'bateria' {
            if (-not $D.hay) { $l += '- Batería: este equipo no tiene batería (o Windows no la ve): funciona enchufado a la corriente.'; break }
            $s = "- Batería: $($D.porcentaje) %"
            if ($D.enchufado) { $s += if ($D.cargando) { ', enchufado a la corriente y cargando.' } else { ', enchufado a la corriente.' } }
            else {
                $s += ', sin enchufar a la corriente.'
                if ($D.minutos) { $s += " Windows calcula que quedan unas $(Format-AIDuration $D.minutos)." }
                else { $s += ' Windows todavía no calcula cuánto tiempo queda.' }
            }
            $l += $s
        }
        'red' {
            if ($D.internet -eq $true)      { $l += '- Internet: sí, este equipo tiene conexión a internet ahora (según el indicador de red de Windows).' }
            elseif ($D.internet -eq $false) { $l += '- Internet: no, este equipo no tiene conexión a internet ahora (según el indicador de red de Windows).' }
            if ($D.wifi) {
                $s = "- Red wifi a la que está conectado: `"$($D.wifi.ssid)`""
                if ($null -ne $D.wifi.senal) { $s += ", con señal del $($D.wifi.senal) %" }
                $l += $s + '.'
            }
            $cons = @($D.conexiones)
            if ($cons.Count -eq 0) { $l += '- Conexiones de red: ninguna activa (ni wifi ni cable).' }
            foreach ($c in $cons) {
                $via = switch ($c.tipo) { 'wifi' { 'por wifi' } 'cable' { 'por cable' } default { 'otro tipo de conexión' } }
                $s = "- Dirección IP de este equipo en la red local: $($c.ip) ($via, adaptador `"$($c.nombre)`")"
                if ($c.puerta) { $s += "; puerta de enlace (router): $($c.puerta)" }
                if (@($c.dns).Count) { $s += "; servidores DNS: $(@($c.dns) -join ' y ')" }
                if ($c.mbps -gt 0) { $s += "; velocidad del enlace: $($c.mbps) Mbps" }
                $l += $s + '.'
            }
            $l += '- La IP pública (la que ven los sitios de internet, que asigna el proveedor) no se puede leer desde el equipo; la de arriba es la IP local.'
        }
        'equipo' {
            $s = "- Nombre de este equipo: $($D.nombre). Usuario de Windows: $($D.usuario)."
            $mm = (@($D.fabricante, $D.modelo) | Where-Object { $_ }) -join ' '
            if ($mm) { $s += " Marca y modelo: $mm." } else { $s += ' Marca y modelo: el fabricante no los dejó anotados.' }
            $l += $s
        }
        'sistema' {
            $l += "- Sistema operativo: $($D.nombre), versión $($D.version), $($D.arquitectura). El equipo lleva encendido $(Format-AIDuration $D.minutosEncendido)."
        }
        'procesador' {
            $l += "- Procesador: $($D.nombre), con $($D.nucleos) núcleos y $($D.hilos) hilos."
        }
        'memoria' {
            $tot = $D.totalMB / 1024; $lib = $D.libreMB / 1024
            $l += "- Memoria RAM: $(Format-AINumber $tot) GB en total; ahora hay $(Format-AINumber $lib) GB libres y $(Format-AINumber ($tot - $lib)) GB en uso."
        }
        'disco' {
            $us = @($D.unidades)
            if ($us.Count -eq 0) { $l += '- Discos: Windows no muestra ninguna unidad lista.' }
            foreach ($u in $us) {
                $et = if ($u.etiqueta) { ", `"$($u.etiqueta)`"" } else { '' }
                $l += "- Disco $($u.unidad) ($($u.tipo)$et): $(Format-AINumber $u.totalGB) GB en total; $(Format-AINumber $u.libreGB) GB libres y $(Format-AINumber ($u.totalGB - $u.libreGB)) GB ocupados."
            }
        }
        'grafica' {
            $ns = @($D.nombres)
            if ($ns.Count -eq 0) { $l += '- Tarjeta gráfica: Windows no muestra ninguna.' }
            elseif ($ns.Count -eq 1) { $l += "- Tarjeta gráfica: $($ns[0])." }
            else { $l += "- Tarjetas gráficas ($($ns.Count)): $($ns -join '; ')." }
        }
    }
    return , @($l)
}

function ConvertTo-AIEquipoGroups {
    <#  De lo que pide el modelo (los argumentos de la herramienta, en JSON) o
        el usuario (/equipo red disco) a grupos de la lista cerrada. Lo que no
        esta en la lista se ignora; si no queda nada, se leen todos.  #>
    param([string]$Texto)
    $pedidos = @()
    try {
        $o = $Texto | ConvertFrom-Json
        if ($o -is [string] -or $o -is [array]) { $pedidos = @($o) }
        elseif ($o.PSObject.Properties['datos']) { $pedidos = @($o.datos) }
        else { $pedidos = @($o.PSObject.Properties | ForEach-Object { $_.Value }) }
    } catch { $pedidos = @($Texto) }

    $visto = @{}
    foreach ($p in $pedidos) {
        $plano = ([string]$p).ToLowerInvariant().Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', ''
        foreach ($w in ($plano -split '[^a-z]+')) {
            if (-not $w) { continue }
            if ($AI_EQUIPO_ALIAS.ContainsKey($w)) { $w = $AI_EQUIPO_ALIAS[$w] }
            if ($AI_EQUIPO_GRUPOS -contains $w) { $visto[$w] = $true }
        }
    }
    $gr = @($AI_EQUIPO_GRUPOS | Where-Object { $visto[$_] })
    if ($gr.Count -eq 0) { $gr = @($AI_EQUIPO_GRUPOS) }
    return , $gr
}

function Get-AIEquipoText {
    <#  Lee los grupos pedidos y devuelve @{ Text; Leidos; Fallidos }.
        Con -Reloj anade la fecha y la hora (para /equipo; al modelo ya le
        llegan en la instruccion de sistema).  #>
    param([string[]]$Grupos, [switch]$Reloj, [switch]$ParaModelo)

    $lineas   = New-Object System.Collections.ArrayList
    $leidos   = @()
    $fallidos = @()
    if ($Reloj) { [void]$lineas.Add("- Fecha y hora: $(Get-AIClockText)") }
    foreach ($g in $AI_EQUIPO_GRUPOS) {
        if ($Grupos -notcontains $g) { continue }
        $d = $null
        try { $d = Read-AIEquipo $g } catch { $d = $null }
        if ($null -eq $d) {
            $fallidos += $g
            [void]$lineas.Add("- $($AI_EQUIPO_NOMBRE[$g]): no se pudo leer; Windows no dio ese dato.")
            continue
        }
        $leidos += $g
        foreach ($x in (Format-AIEquipo $g $d)) { [void]$lineas.Add($x) }
    }
    $cab = if ($ParaModelo) {
        'Datos de este equipo, leídos ahora mismo por el programa (no vienen de internet). Son solo de este equipo: si la pregunta es sobre otro aparato, no los uses. Si es sobre este, responde con ellos sin cambiar las cifras ni los nombres; si un dato dice que no se pudo leer, dilo y no lo inventes:'
    } else { 'Datos de este equipo, leídos ahora:' }
    return [pscustomobject]@{
        Text     = ($cab + "`n" + ($lineas -join "`n"))
        Leidos   = $leidos
        Fallidos = $fallidos
    }
}

# ---------------------------------------------------------------------------
#  El atajo: que grupos pide A LAS CLARAS un mensaje.
#
#  Es prudente a proposito, porque leer de mas SI puede acabar en un dato
#  falso: medido el 2026-11-15, a "que procesador trae la Lenovo Legion 5?"
#  un atajo que solo miraba el tema le pegaba el procesador de esta laptop y
#  Gemma 4 E4B contestaba que ese era el de la Legion. Por eso hacen falta
#  DOS cosas: el tema (bateria, IP...) y una marca de que se habla de este
#  equipo ("mi", "tengo", "me queda", "esta laptop"). Y no se lee si el
#  mensaje nombra otro aparato, una marca, a otra persona o una computadora
#  cualquiera, ni si pide una explicacion, un como se hace, codigo o una
#  compra. Lo que el atajo deja pasar no se pierde: el modelo sigue teniendo
#  la herramienta y decide el.
#
#  Las expresiones trabajan sobre el texto en minusculas y sin acentos.
# ---------------------------------------------------------------------------
# "equipo" a secas tambien es el de futbol: solo cuenta "mi equipo" o "este equipo".
$AI_EQUIPO_APARATO = '(?:pc|computador|computadora|compu|laptop|portatil|ordenador|notebook|(?:mi|esta) maquina|(?:mi|este) equipo)'

$AI_EQUIPO_TEMA = [ordered]@{
    bateria    = '\bbateria\b|\bcuanta (?:carga|pila)\b|\b(?:esta|estoy|sigue) (?:enchufad[oa]|cargando)\b'
    red        = '\b(?:ip|wi-?fi|dns|router|ruteador)\b|\bpuerta de enlace\b|\bgateway\b|\b(?:mi|esta|que|cual) red\b|\bred (?:wifi|local|inalambrica)\b|\b(?:tengo|hay|tiene|sin|mi) (?:conexion a |acceso a |salida a )?internet\b|\bestoy (?:conectad[oa]|en linea|sin conexion|sin internet)\b|\b(?:tengo|hay|mi) conexion\b|\binternet (?:funciona|anda|sirve|esta)\b'
    equipo     = "\b(?:como se llama|nombre|marca|modelo|usuario)\b.{0,40}\b(?:$AI_EQUIPO_APARATO|windows)\b|\b(?:que|cual) $AI_EQUIPO_APARATO (?:tengo|es esta|es este|estoy usando|uso)\b"
    sistema    = "\b(?:que|cual|mi|version de) windows\b|\bwindows (?:tengo|tiene|uso|es)\b|\b(?:mi|que|cual) sistema operativo\b|\b(?:encendid[oa]|prendid[oa])\b.{0,30}\b$AI_EQUIPO_APARATO\b|\b$AI_EQUIPO_APARATO\b.{0,30}\b(?:encendid[oa]|prendid[oa])\b|\bcuanto (?:tiempo )?lleva (?:encendid|prendid)[oa]\b|\bsin (?:apagar|reiniciar)\b|\bultimo reinicio\b"
    procesador = '\b(?:procesador|cpu)\b|\bcuantos (?:nucleos|hilos)\b'
    memoria    = '\bram\b|\bcuanta memoria\b|\bmemoria (?:ram|libre|disponible|instalada|en uso|usada|ocupada|total|fisica)\b'
    disco      = '\bdiscos? (?:duros?|ssd|solido|locales?|[a-z])\b|\b(?:que|cuantos) discos (?:tengo|tiene|hay)\b|\bcuanto espacio (?:libre|disponible|me queda|queda|tengo|tiene)\b|\bespacio (?:libre|en disco|disponible|ocupado|usado|me queda|queda|tengo)\b|\b(?:mi|cuanto) almacenamiento\b|\bunidad [a-z]\b'
    grafica    = '\btarjetas? graficas?\b|\btarjeta de video\b|\b(?:gpu|vram)\b|\b(?:que|cual|mi) grafica\b'
}
# "dame un resumen de esta laptop": el equipo entero menos la red y la bateria.
$AI_EQUIPO_RESUMEN = "\b(?:resumen|especificaciones|caracteristicas|specs|datos|informacion|hardware|componentes)\b.{0,30}\b$AI_EQUIPO_APARATO\b|\bque (?:tiene|trae) (?:(?:mi|esta|este) )?$AI_EQUIPO_APARATO\b"

# Otro aparato. Con uno de estos en el mensaje no se lee nada NI se ofrece la
# herramienta en ese turno: medido el 2026-11-15, con la herramienta a la
# vista Gemma 4 E4B contestaba "no puedo saber la bateria de un iPhone 15"
# (3 de 3) en vez de buscarlo en internet, que es lo que hace sin ella (3 de 3).
$AI_EQUIPO_AJENO = '\b(?:iphone|ipad|android|samsung|galaxy|xiaomi|redmi|huawei|motorola|pixel|celular|telefono|movil|tablet|tableta|consola|playstation|ps[45]|xbox|switch|televisor|tele|tv|smart ?tv|reloj|smartwatch|audifonos|auriculares|carro|coche|auto|moto|servidor|impresora|camara|dron|kindle|macbook|mac|imac|chromebook)\b'

# La marca de que se habla de ESTE equipo: primera persona, o el equipo
# senalado ("esta laptop", "la laptop", "hay internet").
$AI_EQUIPO_PROPIO = '\b(?:mi|mis|tengo|tenemos|me queda|me quedan|me dura|me alcanza|estoy|estamos)\b|\best[ae] (?:laptop|pc|computadora|computador|compu|maquina|portatil|ordenador|notebook|equipo)\b|\b(?:la laptop|la pc|la compu|la computadora|el equipo|el ordenador)\b|\bhay (?:internet|conexion|wifi|red|senal)\b|\bcuanto (?:tiempo )?lleva (?:encendid|prendid)[oa]\b'

$AI_EQUIPO_VETO = @(
    # una marca o un modelo: se pregunta por un producto, no por este equipo
    '\b(?:dell|lenovo|hp|asus|acer|msi|apple|razer|toshiba|sony|lg|alienware|thinkpad|surface|legion|ideapad|pavilion|xps|zenbook|vivobook|rog|tuf|omen|inspiron|latitude|ryzen|intel|amd|nvidia|geforce|rtx|gtx|radeon|snapdragon|tesla)\b|\bcore i\d'
    # otra persona
    '\b(?:hermano|hermana|amigo|amiga|papa|mama|hijo|hija|esposo|esposa|novio|novia|jefe|jefa|vecino|vecina|companero|companera|primo|prima|tio|tia|abuelo|abuela|cliente|pareja|colega)\b'
    # una computadora cualquiera, no esta
    '\b(?:un|una|otro|otra|cualquier|algun|alguna|ningun|ninguna|unas|unos|las|los) (?:buen[ao]? )?(?:laptop|pc|computador|computadora|compu|maquina|portatil|ordenador|notebook)s?\b|\b(?:laptops|pcs|computadoras|portatiles|ordenadores|notebooks)\b'
    # una explicacion
    '\b(?:que es|que son|que significa|que quiere decir|para que sirven?|como funcionan?|explica\w*|definicion|diferencia entre|historia de)\b'
    # un como se hace ("como se llama" no lo es)
    '\bcomo (?:puedo|hago|hacer|veo|ver|saber|se (?!llama)|cambio|cambiar|configuro|configurar|instalo|instalar|actualizo|actualizar|arreglo|arreglar|mejoro|mejorar|libero|liberar|aumento|aumentar|reparo|reparar|activo|activar|desactivo|desactivar|conecto|conectar|comparto|compartir|reinicio|reiniciar|formateo|formatear|limpio|limpiar|optimizo|optimizar|acelero|acelerar)'
    # codigo
    '\b(?:script|codigo|programa|comando|funcion|python|powershell|bash|cmd|javascript|regex|sql|linux|ubuntu|macos)\b'
    # una compra o una comparacion
    '\b(?:mejor|recomiend\w*|comprar?|conviene|vs|versus|precio|cuesta|cuestan|barat\w*|vale la pena|requisitos|necesita|necesitan|compatible)\b'
)

function ConvertTo-AIPlano {
    <#  La pregunta en minusculas, sin acentos y con espacios sencillos. Con
        un fichero entubado solo cuenta la pregunta, no el contexto.  #>
    param([string]$Texto)
    $corte = $Texto.IndexOf('--- contexto ---')
    if ($corte -ge 0) { $Texto = $Texto.Substring(0, $corte) }
    $plano = $Texto.ToLowerInvariant().Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', ''
    return ($plano -replace '\s+', ' ').Trim()
}

function Test-AIEquipoAjeno {
    <#  El mensaje habla de otro aparato?  #>
    param([string]$Texto)
    return ((ConvertTo-AIPlano $Texto) -match $AI_EQUIPO_AJENO)
}

function Find-AIEquipoGroups {
    <#  Devuelve los grupos que el mensaje pide a las claras, o ninguno.  #>
    param([string]$Texto)

    $plano = ConvertTo-AIPlano $Texto
    if ($plano.Length -gt 300) { return , @() }
    if ($plano -match $AI_EQUIPO_AJENO) { return , @() }
    if ($plano -notmatch $AI_EQUIPO_PROPIO) { return , @() }
    foreach ($v in $AI_EQUIPO_VETO) { if ($plano -match $v) { return , @() } }

    $visto = @{}
    foreach ($g in $AI_EQUIPO_TEMA.Keys) { if ($plano -match $AI_EQUIPO_TEMA[$g]) { $visto[$g] = $true } }
    if ($plano -match $AI_EQUIPO_RESUMEN) {
        foreach ($g in 'equipo', 'sistema', 'procesador', 'memoria', 'disco', 'grafica') { $visto[$g] = $true }
    }
    return , @($AI_EQUIPO_GRUPOS | Where-Object { $visto[$_] })
}
