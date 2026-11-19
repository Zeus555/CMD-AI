#requires -Version 5.1
# ============================================================================
#  consultas.ps1 - Consultas web guardadas: leer una pagina fija y sacar de
#  ella unos datos concretos, en JSON.
#
#  Son comandos guardados de otro tipo ("tipo": "web" en comandos.json): se
#  listan, se ejecutan con /comando N, el modelo los pide por su nombre y
#  disparan el atajo igual que los de PowerShell. En vez de un comando llevan:
#    url        la pagina (https y servidor publico, como los comandos)
#    campos     [{ campo, rotulo }]: el rotulo es el texto que en la pagina
#               va justo antes del dato ("Ganador:" -> "12010")
#    registros  cuantos bloques sacar si la pagina los repite (1 = el primero)
#
#  Por que rotulos y no expresiones regulares: un rotulo se lee y se escribe
#  sin saber programar, el modelo lo copia de la pagina y el programa
#  comprueba que esta en ella. Y ninguna expresion de fuera puede colgar la
#  consola: aqui solo se buscan textos.
#
#  Lo que no inventa: cada valor es el texto de la pagina tal cual, sin
#  convertir (el "09065" de un billete conserva su cero). Lo que la pagina no
#  trae sale null. El modelo solo propone los rotulos al guardarla; al
#  ejecutarla no interviene.
#
#  Como se lee la pagina: con Get-AIWebPage (web.ps1), lo mismo que la
#  busqueda. Sin curl ni nada que instalar, con plazo, tope de tamano y cada
#  redireccion revisada antes de seguirla.
#
#  Comentarios y expresiones regulares en ASCII (ver tools\build.ps1).
#
#  IDIOMA: los mensajes, (L 'espanol' 'English') (idioma.ps1). Lo que teclea
#  el usuario (registros= o records=) y lo que responde el modelo (CAMPO o
#  FIELD...) se reconoce en los dos idiomas.
# ============================================================================
. (Join-Path $PSScriptRoot 'idioma.ps1')

$AI_CONSULTA_MAX_CAMPOS    = 8
$AI_CONSULTA_MAX_REGISTROS = 10
$AI_CONSULTA_MAX_ROTULO    = 60
$AI_CONSULTA_MAX_VALOR     = 200
$AI_CONSULTA_FILAS_BLOQUE  = 40      # el ultimo bloque no pasa de estas filas
$AI_CONSULTA_MUESTRA       = 3500    # caracteres de la pagina que ve el modelo

# Comparar sin mirar mayusculas ni acentos ("LOTERIA" casa con "Loteria" acentuada).
$script:AICompara = [Globalization.CultureInfo]::InvariantCulture.CompareInfo
$AI_CONSULTA_OPC  = [Globalization.CompareOptions]::IgnoreCase -bor [Globalization.CompareOptions]::IgnoreNonSpace

function Find-AIRotulo {
    <#  Donde empieza $Rotulo dentro de $Fila, desde $Desde, sin partir
        palabras ("Premio" no casa en "Premios"). -1 si no esta.  #>
    param([string]$Fila, [string]$Rotulo, [int]$Desde = 0)
    $len = $Rotulo.Length
    if (-not $len) { return -1 }
    while ($Desde -le $Fila.Length - $len) {
        $i = $script:AICompara.IndexOf($Fila, $Rotulo, $Desde, $AI_CONSULTA_OPC)
        if ($i -lt 0) { return -1 }
        $fin = $i + $len
        $antes   = ($i -eq 0) -or -not [char]::IsLetterOrDigit($Fila[$i - 1]) -or -not [char]::IsLetterOrDigit($Rotulo[0])
        $despues = ($fin -ge $Fila.Length) -or -not [char]::IsLetterOrDigit($Fila[$fin]) -or -not [char]::IsLetterOrDigit($Rotulo[$len - 1])
        if ($antes -and $despues) { return $i }
        $Desde = $i + 1
    }
    return -1
}

function Test-AIConsultaCampos {
    <#  '' si los campos valen, o el motivo.  #>
    param([array]$Campos, [int]$Registros = 1)
    if (-not $Campos -or $Campos.Count -eq 0) { return (L 'faltan los campos (nombre=rótulo)' 'the fields are missing (name=label)') }
    if ($Campos.Count -gt $AI_CONSULTA_MAX_CAMPOS) { return (L "como mucho $AI_CONSULTA_MAX_CAMPOS campos" "at most $AI_CONSULTA_MAX_CAMPOS fields") }
    $nombres = @{}; $rotulos = @{}
    foreach ($c in $Campos) {
        $n = [string]$c.Campo; $r = [string]$c.Rotulo
        if ($n -cnotmatch '^[a-z][a-z0-9_]{0,29}$') { return (L "el campo «$n» no vale: en minúsculas, sin acentos ni espacios (ganador, fecha_sorteo)" "the field ""$n"" is not valid: lowercase, without accents or spaces (winner, draw_date)") }
        if ($nombres.ContainsKey($n)) { return (L "el campo «$n» está repetido" "the field ""$n"" is repeated") }
        if (-not $r.Trim() -or $r.Length -gt $AI_CONSULTA_MAX_ROTULO -or $r -match '[\x00-\x1F\x7F]') {
            return (L "el rótulo de «$n» tiene que ser un texto corto de la página, de una sola fila" "the label of ""$n"" must be a short text from the page, on a single line")
        }
        # Un rotulo con cifras suele llevar dentro el dato, que cambia.
        if ($r -match '\d{3}') { return (L "el rótulo de «$n» («$r») lleva cifras: tiene que ser el texto fijo que va antes del dato, no el dato" "the label of ""$n"" (""$r"") has digits: it must be the fixed text that comes before the value, not the value") }
        $k = $r.Trim().ToLowerInvariant()
        if ($rotulos.ContainsKey($k)) { return (L "«$n» y «$($rotulos[$k])» tienen el mismo rótulo" """$n"" and ""$($rotulos[$k])"" have the same label") }
        $nombres[$n] = 1; $rotulos[$k] = $n
    }
    if ($Registros -lt 1 -or $Registros -gt $AI_CONSULTA_MAX_REGISTROS) { return (L "los registros van de 1 a $AI_CONSULTA_MAX_REGISTROS" "records go from 1 to $AI_CONSULTA_MAX_REGISTROS") }
    return ''
}

function Get-AIConsultaValor {
    <#  El dato: lo que sigue al rotulo en su fila, cortado donde empiece otro
        rotulo. Si la fila no trae nada mas, la fila siguiente.  #>
    param([string]$Resto, [string]$Siguiente, [string[]]$Rotulos)
    # Una pagina que es JSON ("drawDate": "2026-09-26",): el rotulo es la
    # clave y el valor, lo que va entre comillas o la cifra. Un objeto o una
    # lista no son un dato: null.
    $m = [regex]::Match([string]$Resto, '^\s*"\s*:\s*(?:"((?:[^"\\]|\\.)*)"|(-?\d[\d.eE+-]*|true|false)|(null|\{|\[))')
    if ($m.Success) {
        if ($m.Groups[1].Success) { $v = ($m.Groups[1].Value -replace '\\"', '"' -replace '\\/', '/').Trim() }
        elseif ($m.Groups[2].Success) { $v = $m.Groups[2].Value }
        else { return $null }
        if (-not $v) { return $null }
        if ($v.Length -gt $AI_CONSULTA_MAX_VALOR) { $v = $v.Substring(0, $AI_CONSULTA_MAX_VALOR).TrimEnd() + '...' }
        return $v
    }
    foreach ($t in @($Resto, $Siguiente)) {
        $v = [string]$t
        $corte = $v.Length
        foreach ($o in $Rotulos) { $k = Find-AIRotulo $v $o; if ($k -ge 0 -and $k -lt $corte) { $corte = $k } }
        $v = $v.Substring(0, $corte)
        # Fuera el separador del rotulo ("Ganador: 12010", "Premio - C$8"),
        # pero no el signo de un numero negativo ("-5").
        $v = ($v -replace '^\s*(?:[:=|>]+|[-–—]+(?=\s))\s*', '').Trim()
        if ($v) {
            if ($v.Length -gt $AI_CONSULTA_MAX_VALOR) { $v = $v.Substring(0, $AI_CONSULTA_MAX_VALOR).TrimEnd() + '...' }
            return $v
        }
    }
    return $null
}

function Get-AIConsultaDatos {
    <#  Saca los campos del texto de la pagina (el de ConvertTo-AIPlainText).
        Devuelve @{ Registros = lista de [ordered] campo -> valor o $null;
        Hallados = valores no nulos; Vacios = campos sin valor en el primero }.

        Los bloques: el campo cuyo rotulo sale antes en la pagina marca donde
        empieza cada bloque, y los demas se buscan solo dentro de su bloque.
        Asi un dato que falta en el primer sorteo sale null, y no se toma el
        del sorteo siguiente.  #>
    param([string]$Texto, [array]$Campos, [int]$Registros = 1)
    $filas = @(($Texto -split "\r?\n") | ForEach-Object { ($_ -replace '\s+', ' ').Trim() } | Where-Object { $_ })
    $nada = @{ Registros = @(); Hallados = 0; Vacios = @($Campos | ForEach-Object { $_.Campo }) }
    if (-not $filas.Count -or -not $Campos.Count) { return $nada }

    # El campo que sale primero.
    $guia = $null; $mejor = [long]::MaxValue
    foreach ($c in $Campos) {
        for ($j = 0; $j -lt $filas.Count; $j++) {
            if ([long]$j * 100000 -gt $mejor) { break }
            $k = Find-AIRotulo $filas[$j] $c.Rotulo
            if ($k -ge 0) {
                $pos = [long]$j * 100000 + $k
                if ($pos -lt $mejor) { $mejor = $pos; $guia = $c }
                break
            }
        }
    }
    if (-not $guia) { return $nada }

    # Donde empieza cada bloque: cada aparicion del rotulo guia.
    $inicios = New-Object System.Collections.ArrayList
    for ($j = 0; $j -lt $filas.Count; $j++) {
        $d = 0
        while (($k = Find-AIRotulo $filas[$j] $guia.Rotulo $d) -ge 0) {
            [void]$inicios.Add(@($j, $k))
            $d = $k + $guia.Rotulo.Length
        }
    }

    $rotulos = @($Campos | ForEach-Object { [string]$_.Rotulo })
    $salida = New-Object System.Collections.ArrayList
    $hallados = 0
    $vacios = @()
    $tope = [Math]::Min($Registros, $inicios.Count)
    for ($r = 0; $r -lt $tope; $r++) {
        $sj = $inicios[$r][0]; $sc = $inicios[$r][1]
        if ($r + 1 -lt $inicios.Count) { $ej = $inicios[$r + 1][0]; $ec = $inicios[$r + 1][1] }
        else { $ej = [Math]::Min($filas.Count - 1, $sj + $AI_CONSULTA_FILAS_BLOQUE); $ec = $filas[$ej].Length }
        # El bloque, en trozos de fila: de donde empieza este hasta donde empieza el siguiente.
        $trozos = @(for ($j = $sj; $j -le $ej; $j++) {
            $a = if ($j -eq $sj) { $sc } else { 0 }
            $b = if ($j -eq $ej) { $ec } else { $filas[$j].Length }
            if ($b -gt $a) { $filas[$j].Substring($a, $b - $a) }
        })
        $fila = [ordered]@{}
        foreach ($c in $Campos) {
            $v = $null
            for ($t = 0; $t -lt $trozos.Count; $t++) {
                $k = Find-AIRotulo $trozos[$t] $c.Rotulo
                if ($k -lt 0) { continue }
                $sig = if ($t + 1 -lt $trozos.Count) { $trozos[$t + 1] } else { '' }
                $v = Get-AIConsultaValor $trozos[$t].Substring($k + $c.Rotulo.Length) $sig $rotulos
                break
            }
            $fila[[string]$c.Campo] = $v
            if ($null -ne $v) { $hallados++ } elseif ($r -eq 0) { $vacios += [string]$c.Campo }
        }
        [void]$salida.Add($fila)
    }
    return @{ Registros = $salida.ToArray(); Hallados = $hallados; Vacios = $vacios }
}

function ConvertTo-AIConsultaJson {
    <#  JSON con sangria de dos espacios (el de ConvertTo-Json de PowerShell
        5.1 sale con sangrias de cuatro y huecos raros). Solo hacen falta
        textos y null. Con -Lista, una lista aunque haya un solo registro.  #>
    param([array]$Registros, [switch]$Lista)
    $txt = {
        param($s)
        if ($null -eq $s) { return 'null' }
        $e = ([string]$s) -replace '\\', '\\' -replace '"', '\"' -replace '[\x00-\x1F]', ' '
        return '"' + $e + '"'
    }
    $obj = {
        param($o, [string]$sangria)
        $filas = @(foreach ($k in $o.Keys) { "$sangria  " + (& $txt $k) + ': ' + (& $txt $o[$k]) })
        return "{`n" + ($filas -join ",`n") + "`n$sangria}"
    }
    if (-not $Lista) { return (& $obj $Registros[0] '') }
    $partes = @(foreach ($o in $Registros) { '  ' + (& $obj $o '  ') })
    return "[`n" + ($partes -join ",`n") + "`n]"
}

function Invoke-AIConsultaWeb {
    <#  Lee la pagina y saca los campos. Devuelve @{ Ok; Salida (el JSON);
        Motivo; Url; Datos }.  #>
    param($Consulta)
    $url = [string]$Consulta.Url
    $reg = [Math]::Max(1, [int]$Consulta.Registros)
    $no = { param($m) return @{ Ok = $false; Salida = ''; Motivo = $m; Url = $url; Datos = $null } }
    $m = Test-AIConsultaCampos @($Consulta.Campos) $reg
    if ($m) { return (& $no $m) }
    $m = Test-AIComandoUrl $url -ComprobarRed
    if ($m) { return (& $no $m) }
    try { $html = Get-AIWebPage $url 12 }
    catch {
        $cod = $script:AIWebStatus
        if ($cod -ge 400) { return (& $no (L "la página respondió con el código $cod" "the page answered with code $cod")) }
        return (& $no (L "no pude leer la página ($($_.Exception.GetBaseException().Message))" "I couldn't read the page ($($_.Exception.GetBaseException().Message))"))
    }
    $d = Get-AIConsultaDatos (ConvertTo-AIPlainText $html) @($Consulta.Campos) $reg
    if ($d.Hallados -eq 0) {
        return (& $no (L 'la página ya no trae esos rótulos: quizá cambió, o pinta los datos con JavaScript' 'the page no longer has those labels: maybe it changed, or it draws the data with JavaScript'))
    }
    return @{ Ok = $true; Salida = (ConvertTo-AIConsultaJson $d.Registros -Lista:($reg -gt 1)); Motivo = ''; Url = $url; Datos = $d }
}

function Format-AIConsultaCampos {
    <#  Los campos como se escriben a mano: sorteo="Sorteo" ganador="Ganador:"  #>
    param([array]$Campos, [int]$Registros = 1)
    $t = (@($Campos | ForEach-Object { "$($_.Campo)=""$($_.Rotulo)""" }) -join ' ')
    if ($Registros -gt 1) { $t += (L " registros=$Registros" " records=$Registros") }
    return $t
}

function ConvertFrom-AIConsultaCampos {
    <#  De lo que teclea el usuario en /comando web a @{ Campos; Registros }:
          sorteo=Sorteo ganador="Ganador:" "premio mayor"=Premio registros=5
        El nombre del campo se normaliza (premio_mayor). "records=5" vale
        igual que "registros=5".  #>
    param([string]$Texto)
    $campos = @(); $reg = 1
    $rx = [regex]'(?:"([^"]+)"|([^\s="]+))\s*=\s*(?:"([^"]*)"|(\S+))'
    foreach ($m in $rx.Matches([string]$Texto)) {
        $n = if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value }
        $v = if ($m.Groups[3].Success) { $m.Groups[3].Value } else { $m.Groups[4].Value }
        $n = ConvertTo-AIConsultaCampo $n
        if (($n -eq 'registros' -or $n -eq 'records') -and $v -match '^\d+$') { $reg = [int]$v; continue }
        $campos += [pscustomobject]@{ Campo = $n; Rotulo = $v.Trim() }
    }
    return @{ Campos = $campos; Registros = $reg }
}

function ConvertTo-AIConsultaCampo {
    <#  De "Premio Mayor" a premio_mayor.  #>
    param([string]$Texto)
    $n = ((ConvertTo-AIPlano ([string]$Texto)) -replace '[^a-z0-9]+', '_').Trim('_')
    if ($n -match '^\d') { $n = 'c_' + $n }
    if ($n.Length -gt 30) { $n = $n.Substring(0, 30).Trim('_') }
    return $n
}

# ---------------------------------------------------------------------------
#  Pedirla con una frase: "agregame un comando para obtener los datos del
#  ultimo sorteo de la loteria de Nicaragua de internet". El dialogo esta en
#  bin\ai.ps1; aqui, lo que no depende del modelo ni de la consola.
# ---------------------------------------------------------------------------

function Test-AIConsultaPedida {
    <#  La peticion de un comando habla de internet o de una pagina? En los
        dos idiomas ("from the lottery website", "that reads the page").  #>
    param([string]$Texto)
    $p = ConvertTo-AIPlano ([string]$Texto)
    return ($p -match '\b(?:internet|web|pagina|paginas|sitio|duckduckgo|html|curl|en linea|online|page|pages|webpage|webpages|site|sites|website|websites)\b|https?://')
}

function Get-AIConsultaMuestra {
    <#  El principio del texto de la pagina, para que el modelo elija los
        rotulos. Acotado: el servidor local tiene 4096 tokens.  #>
    param([string]$Texto)
    $t = [string]$Texto
    if ($t.Length -gt $AI_CONSULTA_MUESTRA) { $t = $t.Substring(0, $AI_CONSULTA_MUESTRA) + "`n[...]" }
    return $t
}

function Get-AIConsultaGuia {
    <#  Lo que se le dice al modelo cuando tiene que proponer los campos. La
        barrera es Test-AIConsultaPropuesta: cada rotulo tiene que estar en
        la pagina y dar un dato. Las etiquetas de la respuesta, en el idioma
        de los mensajes; ConvertFrom-AIConsultaPropuesta lee las dos.  #>
    $en = @"
I give you the text of a web page and what the user wants to get from it. You choose the data and, for each one, its label: the fixed text that comes RIGHT BEFORE the value on the page. A program will look for each label on the page and keep what follows it.
Rules:
- From 1 to $AI_CONSULTA_MAX_CAMPOS fields, only the ones the user asks for. If they ask for "the data" of something, all the ones in that block.
- The label is copied exactly from the page, with its colon if it has one. If the page says "Winner: 12010", the field is winner and the label "Winner:". If it says "Draw 2304", the label is "Draw".
- Never put the value in the label: the label is what stays fixed; the value, what changes.
- If the page repeats the data in blocks (one per draw, per product, per day), the program takes the first one. If the user asks for several (the last 5), put RECORDS with that number.
Answer ONLY with these lines, without explanations:
NAME: one or two words for the query, lowercase and joined with a hyphen (lottery-results, dollar-price)
DESCRIPTION: one sentence saying what data it gives and from which page
FIELD field_name: label
FIELD field_name: label
RECORDS: 1
If the text does not have that data, answer only:
NODATA: the reason, in a few words
"@
    $es = @"
Te paso el texto de una pagina web y lo que el usuario quiere sacar de ella. Eliges los datos y, para cada uno, su rotulo: el texto fijo que en la pagina va JUSTO ANTES del dato. Un programa buscara cada rotulo en la pagina y se quedara con lo que le sigue.
Reglas:
- De 1 a $AI_CONSULTA_MAX_CAMPOS campos, solo los que pide el usuario. Si pide "los datos" de algo, todos los de ese bloque.
- El rotulo se copia tal cual de la pagina, con sus dos puntos si los lleva. Si la pagina dice "Ganador: 12010", el campo es ganador y el rotulo "Ganador:". Si dice "Sorteo 2304", el rotulo es "Sorteo".
- Nunca metas el dato en el rotulo: el rotulo es lo fijo; el dato, lo que cambia.
- Si la pagina repite los datos en bloques (uno por sorteo, por producto, por dia), el programa saca el primero. Si el usuario pide varios (los ultimos 5), pon REGISTROS con ese numero.
Responde SOLO con estas lineas, sin explicaciones:
NOMBRE: una o dos palabras para la consulta, en minusculas y unidas con guion (loteria-nicaragua, precio-dolar)
DESCRIPCION: una frase que diga que datos da y de que pagina
CAMPO nombre_del_campo: rotulo
CAMPO nombre_del_campo: rotulo
REGISTROS: 1
Si el texto no tiene esos datos, responde solo:
NOHAY: el motivo, en pocas palabras
"@
    return (L $es $en)
}

function ConvertFrom-AIConsultaPropuesta {
    <#  De la respuesta del modelo a @{ Campos; Registros; Nombre;
        Descripcion; NoHay }.  #>
    param([string]$Texto)
    $t = ([string]$Texto) -replace '(?m)^\s*```\w*\s*$', '' -replace '`', ''
    $r = @{ Campos = @(); Registros = 1; Nombre = ''; Descripcion = ''; NoHay = '' }
    $m = [regex]::Match($t, '(?im)^\W*(?:NOHAY|NODATA)\W*:\s*(.+?)\s*$')
    if ($m.Success) { $r.NoHay = $m.Groups[1].Value.Trim() }
    foreach ($m in [regex]::Matches($t, '(?im)^\W*(?:CAMPO|FIELD)\W+([^:=\r\n]{1,40}?)\s*[:=]\s*(.+?)\s*$')) {
        $n = ConvertTo-AIConsultaCampo ($m.Groups[1].Value.Trim('*', '_', ' ', '"'))
        $v = $m.Groups[2].Value.Trim().Trim('*', ' ').Trim().Trim('"', "'", [char]0xAB, [char]0xBB, [char]0x201C, [char]0x201D)
        if ($n -and $v) { $r.Campos += [pscustomobject]@{ Campo = $n; Rotulo = $v } }
    }
    if ($r.Campos.Count) { $r.NoHay = '' }
    $m = [regex]::Match($t, '(?im)^\W*(?:REGISTROS|RECORDS)\W*:\s*(\d{1,3})')
    if ($m.Success) { $r.Registros = [Math]::Max(1, [int]$m.Groups[1].Value) }
    $m = [regex]::Match($t, '(?im)^\W*(?:NOMBRE|NAME)\W*:\s*(.+?)\s*$')
    if ($m.Success) { $r.Nombre = ConvertTo-AIComandoNombreCorto $m.Groups[1].Value }
    $m = [regex]::Match($t, '(?im)^\W*(?:DESCRIPCI.N|DESCRIPTION)\W*:\s*(.+?)\s*$')
    if ($m.Success) { $r.Descripcion = ConvertTo-AIComandoTexto ($m.Groups[1].Value.Trim('*', ' ', '"')) }
    return $r
}

function Test-AIConsultaPropuesta {
    <#  Lo que propone el modelo vale si cada rotulo esta en la pagina y da un
        dato. Los campos que no dan nada se quitan (y se dice cuales); si no
        queda ninguno, no vale. Devuelve @{ Ok; Motivo; Campos; Registros;
        Quitados; Datos }.  #>
    param([hashtable]$Propuesta, [string]$Texto)
    $campos = @($Propuesta.Campos | Select-Object -First $AI_CONSULTA_MAX_CAMPOS)
    $reg = [Math]::Min([Math]::Max(1, [int]$Propuesta.Registros), $AI_CONSULTA_MAX_REGISTROS)
    $no = { param($m) return @{ Ok = $false; Motivo = $m; Campos = @(); Registros = $reg; Quitados = @(); Datos = $null } }
    if (-not $campos.Count) { return (& $no (L 'no diste ninguna linea CAMPO' 'you gave no FIELD line')) }
    $m = Test-AIConsultaCampos $campos $reg
    if ($m) { return (& $no $m) }
    $filas = @(([string]$Texto) -split "\r?\n" | ForEach-Object { ($_ -replace '\s+', ' ').Trim() } | Where-Object { $_ })
    foreach ($c in $campos) {
        $esta = $false
        foreach ($f in $filas) { if ((Find-AIRotulo $f $c.Rotulo) -ge 0) { $esta = $true; break } }
        if (-not $esta) { return (& $no (L "el rótulo «$($c.Rotulo)» de $($c.Campo) no está en la página: cópialo tal cual del texto" "the label ""$($c.Rotulo)"" of $($c.Campo) is not on the page: copy it exactly from the text")) }
    }
    $d = Get-AIConsultaDatos $Texto $campos $reg
    $quitados = @($d.Vacios)
    $quedan = @($campos | Where-Object { $quitados -notcontains $_.Campo })
    if (-not $quedan.Count) { return (& $no (L 'con esos rótulos no sale ningún dato: el rótulo es el texto que va justo antes del dato' 'those labels give no value: the label is the text that comes right before the value')) }
    if ($quitados.Count) { $d = Get-AIConsultaDatos $Texto $quedan $reg }
    return @{ Ok = $true; Motivo = ''; Campos = $quedan; Registros = $reg; Quitados = $quitados; Datos = $d }
}
