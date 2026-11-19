#requires -Version 5.1
# ---------------------------------------------------------------------------
#  PDF: el texto de un PDF, sin bibliotecas. Lo usa lib\documentos.ps1.
#
#  Un PDF no guarda el texto como texto: guarda que letras se dibujan, en que
#  sitio y con que tipo de letra. Aqui se recorren las paginas en orden, se
#  descifra cada letra con su tipo de letra (su tabla ToUnicode si la trae;
#  si no, su codificacion) y por la posicion se decide si va un espacio, un
#  salto de linea, un parrafo nuevo o una columna de tabla (" | "). Una linea
#  en letra claramente mas grande que el cuerpo (o corta y toda en negrita)
#  se toma por titulo y sale como "# titulo", igual que con Word: asi los
#  fragmentos llevan su apartado y se puede olvidar un apartado de un PDF.
#
#  - El peligro es leer mal: un tipo de letra sin tabla da letras cambiadas y
#    un texto cambiado acabaria en datos falsos. Por eso se cuentan las letras
#    que no se pudieron descifrar y se mira si lo leido parece texto. Si no,
#    el PDF no se lee y se dice por que.
#  - No hay texto en un PDF escaneado (es una foto), salvo que lleve la capa
#    de texto de un OCR: esa si se lee. Los PDF protegidos con contrasena (o
#    solo contra copia) no se leen: se dice como sacar una copia sin
#    proteccion.
#  - El fichero se lee como Latin-1: cada byte es un caracter, y las
#    expresiones regulares de .NET hacen el trabajo pesado (en PowerShell,
#    byte a byte, seria muy lento).
#  Comentarios y expresiones regulares en ASCII (ver tools\build.ps1).
# ---------------------------------------------------------------------------

. (Join-Path $PSScriptRoot 'idioma.ps1')

# Los motivos para no leer un PDF, en los dos idiomas. Van en una tabla y no
# sueltos con L porque documentos.ps1 los guarda en su indice.tsv y, si se
# cambia de idioma, los vuelve a escribir en el nuevo (ConvertTo-AIDocMotivo):
# tiene que conocer las dos versiones. {0} es un dato.
$script:AIPdfMensajes = [ordered]@{
    pdfNoEs      = @('el fichero está dañado o no es un PDF', 'the file is damaged or is not a PDF')
    pdfProtegido = @('el PDF está protegido (con contraseña o contra copia); ábrelo y, si te deja, imprímelo en «Microsoft Print to PDF» para tener una copia sin protección',
                     'the PDF is protected (with a password or against copying); open it and, if it lets you, print it to "Microsoft Print to PDF" to get an unprotected copy')
    pdfPaginas   = @('el PDF está dañado: no se encuentran sus páginas', "the PDF is damaged: its pages can't be found")
    pdfLetras    = @('el PDF usa tipos de letra que no sé descifrar sin riesgo de leer mal; si tienes el original (Word, Excel), ponlo en la carpeta en su lugar',
                     "the PDF uses fonts I can't decode without the risk of misreading; if you have the original (Word, Excel), put it in the folder instead")
    pdfStream    = @('un stream comprimido esta danado', 'a compressed stream is damaged')
    pdfAviso     = @(('{0} letras no se pudieron descifrar y salen como ' + [char]0xFFFD), ('{0} letters could not be decoded and show as ' + [char]0xFFFD))
}
function Get-AIPdfMensaje([string]$Clave, [object[]]$Datos = @()) {
    $p = $script:AIPdfMensajes[$Clave]
    return [string]::Format((L $p[0] $p[1]), $Datos)
}

$AI_PDF_MAX_PAGINAS  = 2000
$AI_PDF_MAX_TEXTO    = 1600000   # se deja de leer pasado esto (documentos.ps1 recorta a 1,5 M)
$AI_PDF_MAX_DESCONOC = 0.05      # letras sin descifrar: por encima, no se lee

$script:AIPdfL1 = [Text.Encoding]::GetEncoding(28591)
$script:AIPdfCI = [Globalization.CultureInfo]::InvariantCulture
$script:AIPdfFinDic = New-Object object
$script:AIPdfFinArr = New-Object object
$script:AIPdfFinTxt = New-Object object
$script:AIPdfBlancos = [char[]]@(' ', [char]9, [char]10, [char]13, [char]12, [char]0)

# Los objetos (diccionarios, listas, nombres, numeros, referencias).
$script:AIPdfReTok = New-Object regex ('\G(?:[\s\x00]|%[^\r\n]*)*(?:(?<a><<|>>|\[|\])|(?<n>/[^\s\x00/\[\]()<>{}%]*)|(?<h><[0-9A-Fa-f\s]*>)' +
    '|(?<r>(?<rn>\d+)\s+\d+\s+R(?![A-Za-z0-9]))|(?<x>[-+]?(?:\d+\.?\d*|\.\d+))|(?<p>\()|(?<k>[A-Za-z_]+)|(?<o>\S))'), 'Compiled'
$script:AIPdfReObj = New-Object regex '(?<![0-9])(\d{1,8})\s+(\d{1,5})\s+obj\b', 'Compiled'
$script:AIPdfReEsc = New-Object regex '\\(?:([0-7]{1,3})|(\r\n|\r|\n)|([\s\S]))', 'Compiled'

# El contenido de una pagina: solo los operadores que tocan el texto. Una
# cadena suelta tambien se consume entera, para que nada de dentro de ella
# se tome por un operador.
& {
$cad = '\((?:[^\\()]|\\[\s\S]|\((?:[^\\()]|\\[\s\S]|\((?:[^\\()]|\\[\s\S])*\))*\))*\)'
$hex = '<[0-9A-Fa-f\s]*>'
$num = '[-+]?(?:\d+\.?\d*|\.\d+)'
$nom = '/[^\s/\[\]()<>{}%]+'
$fin = '(?![A-Za-z0-9*''"])'
$script:AIPdfReCont = New-Object regex ((@(
    "(?<tj>$cad|$hex)\s*Tj$fin"
    "\[(?<tja>(?:\s|$cad|$hex|$num)*)\]\s*TJ$fin"
    "(?<ap>$cad|$hex)\s*'"
    "(?<aw>$num)\s+(?<ac>$num)\s+(?<qq>$cad|$hex)\s*" + '"'
    "(?<tf>$nom)\s+(?<tfs>$num)\s+Tf$fin"
    "(?<m6>$num\s+$num\s+$num\s+$num\s+$num\s+$num)\s+(?<o6>Tm|cm)$fin"
    "(?<tdx>$num)\s+(?<tdy>$num)\s+(?<td>T[dD])$fin"
    "(?<v1>$num)\s+(?<o1>TL|Tc|Tw|Tz)$fin"
    "(?<xo>$nom)\s+Do$fin"
    "(?<![A-Za-z0-9*'`"/])(?<op>T\*|BT|ET|q|Q)$fin"
    "(?<![A-Za-z0-9])BI\s[\s\S]*?\sID\s[\s\S]*?\sEI$fin"
    $cad
    '%[^\r\n]*'
)) -join '|'), 'Compiled'
$script:AIPdfReTJ = New-Object regex "(?<s>$cad|$hex)|(?<x>$num)", 'Compiled'
}

# Nombres de letra (los de la lista de Adobe) para las posiciones 32-255 de
# Windows-1252; con ellos se descifran las tablas /Differences.
$script:AIPdfGlifos = New-Object 'System.Collections.Generic.Dictionary[string,string]'
& {
    $nombres = @((@'
space exclam quotedbl numbersign dollar percent ampersand quotesingle parenleft parenright asterisk plus comma hyphen period slash
zero one two three four five six seven eight nine colon semicolon less equal greater question
at A B C D E F G H I J K L M N O P Q R S T U V W X Y Z bracketleft backslash bracketright asciicircum underscore
grave a b c d e f g h i j k l m n o p q r s t u v w x y z braceleft bar braceright asciitilde -
Euro - quotesinglbase florin quotedblbase ellipsis dagger daggerdbl circumflex perthousand Scaron guilsinglleft OE - Zcaron -
- quoteleft quoteright quotedblleft quotedblright bullet endash emdash tilde trademark scaron guilsinglright oe - zcaron Ydieresis
nbspace exclamdown cent sterling currency yen brokenbar section dieresis copyright ordfeminine guillemotleft logicalnot sfthyphen registered macron
degree plusminus twosuperior threesuperior acute mu paragraph periodcentered cedilla onesuperior ordmasculine guillemotright onequarter onehalf threequarters questiondown
Agrave Aacute Acircumflex Atilde Adieresis Aring AE Ccedilla Egrave Eacute Ecircumflex Edieresis Igrave Iacute Icircumflex Idieresis
Eth Ntilde Ograve Oacute Ocircumflex Otilde Odieresis multiply Oslash Ugrave Uacute Ucircumflex Udieresis Yacute Thorn germandbls
agrave aacute acircumflex atilde adieresis aring ae ccedilla egrave eacute ecircumflex edieresis igrave iacute icircumflex idieresis
eth ntilde ograve oacute ocircumflex otilde odieresis divide oslash ugrave uacute ucircumflex udieresis yacute thorn ydieresis
'@) -split '\s+' | Where-Object { $_ })
    $cp = [Text.Encoding]::GetEncoding(1252)
    for ($i = 0; $i -lt $nombres.Count; $i++) {
        if ($nombres[$i] -ne '-') { $script:AIPdfGlifos[$nombres[$i]] = $cp.GetString([byte[]]@(32 + $i)) }
    }
    foreach ($p in 'fi=fi', 'fl=fl', 'ff=ff', 'ffi=ffi', 'ffl=ffl', 'space= ', 'hyphen=-', 'apple=') {
        $k = $p.IndexOf('='); $script:AIPdfGlifos[$p.Substring(0, $k)] = $p.Substring($k + 1)
    }
    foreach ($p in @(@('dotlessi', 0x131), @('minus', 0x2212), @('fraction', 0x2044), @('mu', 0xB5), @('Omega', 0x3A9),
                     @('Delta', 0x394), @('pi', 0x3C0), @('nonbreakingspace', 0xA0), @('uni00A0', 0xA0))) {
        $script:AIPdfGlifos[$p[0]] = [string][char]$p[1]
    }
}
# Windows-1252 por posicion (lo que se usa sin otra tabla). Por debajo de
# 32 no hay letras: un codigo ahi es de un tipo de letra sin tabla.
$script:AIPdfWin = & {
    $cp = [Text.Encoding]::GetEncoding(1252)
    $t = New-Object 'string[]' 256
    for ($i = 32; $i -lt 256; $i++) { if ($i -ne 127) { $t[$i] = $cp.GetString([byte[]]@($i)) } }
    , $t
}
$script:AIPdfMac = & {
    $cp = [Text.Encoding]::GetEncoding(10000)
    $t = New-Object 'string[]' 256
    for ($i = 32; $i -lt 256; $i++) { if ($i -ne 127) { $t[$i] = $cp.GetString([byte[]]@($i)) } }
    , $t
}

# ---------------------------------------------------------------------------
#  Objetos
# ---------------------------------------------------------------------------
function ConvertFrom-AIPdfHex([string]$Hex) {
    <#  "<48 6f6c61>" (o sin <>) -> los bytes, un caracter por byte.  #>
    $h = $Hex.Trim('<', '>') -replace '\s+', ''
    if ($h.Length % 2) { $h += '0' }
    $sb = New-Object System.Text.StringBuilder ($h.Length / 2)
    for ($i = 0; $i -lt $h.Length; $i += 2) { [void]$sb.Append([char][Convert]::ToInt32($h.Substring($i, 2), 16)) }
    return $sb.ToString()
}

function ConvertFrom-AIPdfLiteral([string]$Cad) {
    <#  "(texto con \( escapes \050)" -> los bytes, un caracter por byte.  #>
    $t = $Cad.Substring(1, $Cad.Length - 2)
    if ($t.IndexOf('\') -lt 0) { return $t }
    return $script:AIPdfReEsc.Replace($t, [Text.RegularExpressions.MatchEvaluator]{
        param($m)
        if ($m.Groups[1].Success) { return [string][char]([Convert]::ToInt32($m.Groups[1].Value, 8) -band 255) }
        if ($m.Groups[2].Success) { return '' }
        switch -CaseSensitive ($m.Groups[3].Value) { 'n' { "`n" } 'r' { "`r" } 't' { "`t" } 'b' { "`b" } 'f' { "`f" } default { $_ } }
    })
}

function Read-AIPdfValor($St) {
    <#  El siguiente valor de $St.S desde $St.P. Diccionario -> hashtable;
        lista -> ArrayList; nombre -> '/Nombre'; numero -> double;
        referencia "12 0 R" -> long; cadena -> @{ Cad = bytes }. Al final, un
        cierre (>> ]) o el fin del texto devuelven sus marcas.  #>
    $m = $script:AIPdfReTok.Match($St.S, $St.P)
    if (-not $m.Success) { return $script:AIPdfFinTxt }
    $St.P = $m.Index + $m.Length
    $g = $m.Groups
    if ($g['n'].Success) { return $g['n'].Value }
    if ($g['x'].Success) { $d = 0.0; [void][double]::TryParse($g['x'].Value, [Globalization.NumberStyles]::Float, $script:AIPdfCI, [ref]$d); return $d }
    if ($g['r'].Success) { return [long]$g['rn'].Value }
    if ($g['a'].Success) {
        switch ($g['a'].Value) {
            '<<' {
                $d = @{}
                while ($true) {
                    $k = Read-AIPdfValor $St
                    if ($k -isnot [string] -or -not $k.StartsWith('/')) { break }
                    $v = Read-AIPdfValor $St
                    if ([object]::ReferenceEquals($v, $script:AIPdfFinDic) -or [object]::ReferenceEquals($v, $script:AIPdfFinTxt)) { break }
                    $d[$k.Substring(1)] = $v
                }
                return $d
            }
            '>>' { return $script:AIPdfFinDic }
            '[' {
                $l = New-Object System.Collections.ArrayList
                while ($true) {
                    $v = Read-AIPdfValor $St
                    if ([object]::ReferenceEquals($v, $script:AIPdfFinArr) -or [object]::ReferenceEquals($v, $script:AIPdfFinTxt) -or [object]::ReferenceEquals($v, $script:AIPdfFinDic)) { break }
                    [void]$l.Add($v)
                }
                return , $l
            }
            ']' { return $script:AIPdfFinArr }
        }
    }
    if ($g['h'].Success) { return @{ Cad = (ConvertFrom-AIPdfHex $g['h'].Value) } }
    if ($g['p'].Success) {
        $s = $St.S; $i = $St.P; $prof = 1
        while ($i -lt $s.Length -and $prof -gt 0) {
            $ch = $s[$i]
            if ($ch -eq '\') { $i += 2; continue }
            if ($ch -eq '(') { $prof++ } elseif ($ch -eq ')') { $prof-- }
            $i++
        }
        $txt = $s.Substring($m.Index + $m.Length - 1, $i - ($m.Index + $m.Length - 1))
        $St.P = $i
        return @{ Cad = (ConvertFrom-AIPdfLiteral $txt) }
    }
    if ($g['k'].Success) {
        switch -CaseSensitive ($g['k'].Value) {
            'true' { return $true } 'false' { return $false } 'null' { return $null }
            default { return $script:AIPdfFinTxt }      # obj, endobj, stream...
        }
    }
    return (Read-AIPdfValor $St)                         # un caracter suelto
}

function Get-AIPdfObjetos([string]$S) {
    <#  Donde empieza y acaba cada objeto "12 0 obj ... endobj", y sus datos
        si es un stream. No se lee la tabla xref: se recorre el fichero, que
        tambien vale si la tabla esta mal. Si un objeto sale dos veces (un
        PDF modificado despues), vale el ultimo.  #>
    $obj = New-Object 'System.Collections.Generic.Dictionary[long,object]'
    $o = [StringComparison]::Ordinal
    $pos = 0
    $m = $script:AIPdfReObj.Match($S, 0)
    while ($m.Success) {
        $ini = $m.Index + $m.Length
        $eo = $S.IndexOf('endobj', $ini, $o)
        if ($eo -lt 0) { $eo = $S.Length }
        $st = $S.IndexOf('stream', $ini, $eo - $ini, $o)
        $x = @{ Ini = $ini; Fin = $eo; DIni = -1; DFin = -1; Pos = $m.Index; Texto = $null }
        $sig = $eo
        if ($st -ge 0) {
            $x.Fin = $st
            $d = $st + 6
            if ($d -lt $S.Length -and $S[$d] -eq "`r") { $d++ }
            if ($d -lt $S.Length -and $S[$d] -eq "`n") { $d++ }
            $e = -1
            $lm = [regex]::Match($S.Substring($ini, $st - $ini), '/Length\s+(\d+)(?!\s+\d+\s+R)')
            if ($lm.Success) {
                $L = [long]$lm.Groups[1].Value
                if ($d + $L -le $S.Length -and [regex]::IsMatch($S.Substring($d + $L, [Math]::Min(24, $S.Length - $d - $L)), '^\s*endstream')) { $e = $d + $L }
            }
            if ($e -lt 0) {
                $e = $S.IndexOf('endstream', $d, $o)
                if ($e -lt 0) { $e = $S.Length }
            }
            $x.DIni = $d; $x.DFin = $e
            $sig = $S.IndexOf('endobj', $e, $o)
            if ($sig -lt 0) { $sig = $e }
        }
        $obj[[long]$m.Groups[1].Value] = $x
        $m = $script:AIPdfReObj.Match($S, [Math]::Min($sig, $S.Length))
    }
    return , $obj
}

function New-AIPdfDoc([string]$S) {
    $doc = @{ S = $S; Obj = (Get-AIPdfObjetos $S); Cache = @{}; Datos = @{}; Fuentes = @{} }
    # Los objetos guardados dentro de streams (/Type /ObjStm, PDF 1.5 y
    # posteriores: lo hacen Word, Chrome y casi todo lo moderno).
    foreach ($n in @($doc.Obj.Keys)) {
        $x = $doc.Obj[$n]
        if ($x.DIni -lt 0 -or $S.IndexOf('/ObjStm', $x.Ini, $x.Fin - $x.Ini, [StringComparison]::Ordinal) -lt 0) { continue }
        $dic = Get-AIPdfObj $doc $n
        $dat = Get-AIPdfDatos $doc $n
        if ($null -eq $dat -or $dic -isnot [hashtable]) { continue }
        $primero = [int]$dic['First']
        if ($primero -le 0 -or $primero -gt $dat.Length) { continue }
        $nums = @([regex]::Matches($dat.Substring(0, $primero), '\d+') | ForEach-Object { [long]$_.Value })
        for ($i = 0; $i + 1 -lt $nums.Count; $i += 2) {
            $ini = $primero + $nums[$i + 1]
            $finO = if ($i + 3 -lt $nums.Count) { $primero + $nums[$i + 3] } else { $dat.Length }
            if ($ini -ge $dat.Length -or $finO -lt $ini) { continue }
            $num = $nums[$i]
            if ($doc.Obj.ContainsKey($num) -and $doc.Obj[$num].Pos -gt $x.Pos) { continue }
            $doc.Obj[$num] = @{ Ini = 0; Fin = 0; DIni = -1; DFin = -1; Pos = $x.Pos; Texto = $dat.Substring($ini, $finO - $ini) }
            $doc.Cache.Remove($num)
        }
    }
    return $doc
}

function Get-AIPdfObj($Doc, [long]$N) {
    <#  El valor del objeto N (su diccionario, si es un stream), o $null.  #>
    if ($Doc.Cache.ContainsKey($N)) { return $Doc.Cache[$N] }
    $v = $null
    if ($Doc.Obj.ContainsKey($N)) {
        $x = $Doc.Obj[$N]
        $txt = if ($null -ne $x.Texto) { $x.Texto } else { $Doc.S.Substring($x.Ini, $x.Fin - $x.Ini) }
        $v = Read-AIPdfValor @{ S = $txt; P = 0 }
        if ($v -is [object] -and ([object]::ReferenceEquals($v, $script:AIPdfFinTxt) -or [object]::ReferenceEquals($v, $script:AIPdfFinDic) -or [object]::ReferenceEquals($v, $script:AIPdfFinArr))) { $v = $null }
    }
    $Doc.Cache[$N] = $v
    return , $v
}

function Get-AIPdfValor($Doc, $V) {
    <#  Sigue las referencias hasta el valor.  #>
    $k = 0
    while ($V -is [long] -and $k -lt 16) { $V = Get-AIPdfObj $Doc $V; $k++ }
    return , $V
}

function Expand-AIPdfFlate([string]$Datos) {
    $b = $script:AIPdfL1.GetBytes($Datos)
    $off = 0
    if ($b.Length -ge 2 -and ($b[0] -band 15) -eq 8 -and ((([int]$b[0] * 256) + $b[1]) % 31) -eq 0) { $off = 2 }
    $ms = New-Object IO.MemoryStream -ArgumentList $b, $off, ($b.Length - $off)
    $ds = New-Object IO.Compression.DeflateStream($ms, [IO.Compression.CompressionMode]::Decompress)
    $out = New-Object IO.MemoryStream
    try { $ds.CopyTo($out) }
    catch { if ($out.Length -eq 0) { throw (Get-AIPdfMensaje 'pdfStream') } }   # lo leido hasta el dano vale
    finally { $ds.Dispose() }
    return $script:AIPdfL1.GetString($out.ToArray())
}

function Expand-AIPdfA85([string]$Datos) {
    $t = ($Datos -replace '\s+', '')
    if ($t.StartsWith('<~')) { $t = $t.Substring(2) }
    $k = $t.IndexOf('~>'); if ($k -ge 0) { $t = $t.Substring(0, $k) }
    $sb = New-Object System.Text.StringBuilder
    $grupo = New-Object 'System.Collections.Generic.List[int]'
    foreach ($ch in $t.ToCharArray()) {
        if ($ch -eq 'z' -and $grupo.Count -eq 0) { [void]$sb.Append([string][char]0 * 4); continue }
        $grupo.Add([int]$ch - 33)
        if ($grupo.Count -eq 5) {
            [long]$v = 0; foreach ($d in $grupo) { $v = $v * 85 + $d }
            foreach ($s in 24, 16, 8, 0) { [void]$sb.Append([char](($v -shr $s) -band 255)) }
            $grupo.Clear()
        }
    }
    if ($grupo.Count -gt 1) {
        $n = $grupo.Count
        while ($grupo.Count -lt 5) { $grupo.Add(84) }
        [long]$v = 0; foreach ($d in $grupo) { $v = $v * 85 + $d }
        $sh = @(24, 16, 8, 0)
        for ($i = 0; $i -lt $n - 1; $i++) { [void]$sb.Append([char](($v -shr $sh[$i]) -band 255)) }
    }
    return $sb.ToString()
}

function Get-AIPdfDatos($Doc, [long]$N) {
    <#  Los datos del stream N, ya descomprimidos (un caracter por byte), o
        $null si no es un stream o usa un filtro que no se sabe deshacer.  #>
    if ($Doc.Datos.ContainsKey($N)) { return $Doc.Datos[$N] }
    $r = $null
    if ($Doc.Obj.ContainsKey($N) -and $Doc.Obj[$N].DIni -ge 0) {
        $x = $Doc.Obj[$N]
        $r = $Doc.S.Substring($x.DIni, $x.DFin - $x.DIni)
        $dic = Get-AIPdfObj $Doc $N
        $f = if ($dic -is [hashtable]) { Get-AIPdfValor $Doc $dic['Filter'] } else { $null }
        $filtros = @(if ($f -is [System.Collections.IList]) { $f } elseif ($f) { $f })
        foreach ($fi in $filtros) {
            switch ([string]$fi) {
                { $_ -in '/FlateDecode', '/Fl' } { $r = Expand-AIPdfFlate $r; break }
                { $_ -in '/ASCIIHexDecode', '/AHx' } { $r = ConvertFrom-AIPdfHex (($r -split '>')[0]); break }
                { $_ -in '/ASCII85Decode', '/A85' } { $r = Expand-AIPdfA85 $r; break }
                default { $r = $null }
            }
            if ($null -eq $r) { break }
        }
    }
    $Doc.Datos[$N] = $r
    return $r
}

# ---------------------------------------------------------------------------
#  Tipos de letra
# ---------------------------------------------------------------------------
function Get-AIPdfGlifo([string]$Nombre) {
    <#  "/aacute" -> la letra; $null si el nombre no dice que letra es (los
        de un tipo de letra recortado, como /g13 o /cid42).  #>
    $n = $Nombre.TrimStart('/')
    $u = $null
    if ($script:AIPdfGlifos.TryGetValue($n, [ref]$u)) { return $u }
    if ($n -cmatch '^uni((?:[0-9A-F]{4})+)$') {
        $h = $Matches[1]; $sb = New-Object System.Text.StringBuilder
        for ($i = 0; $i -lt $h.Length; $i += 4) { [void]$sb.Append([char][Convert]::ToInt32($h.Substring($i, 4), 16)) }
        return $sb.ToString()
    }
    if ($n -cmatch '^u([0-9A-F]{4,6})$') { return [char]::ConvertFromUtf32([Convert]::ToInt32($Matches[1], 16)) }
    $p = $n.IndexOf('.')
    if ($p -gt 0) { return (Get-AIPdfGlifo $n.Substring(0, $p)) }
    if ($n.Contains('_')) {
        $partes = @(foreach ($x in $n.Split('_')) { Get-AIPdfGlifo $x })
        if (@($partes | Where-Object { $null -eq $_ }).Count -eq 0) { return ($partes -join '') }
    }
    return $null
}

function ConvertFrom-AIPdfUtf16([string]$Hex) {
    if ($Hex.Length -le 2) { return [string][char][Convert]::ToInt32('0' + $Hex, 16) }
    $sb = New-Object System.Text.StringBuilder
    for ($i = 0; $i + 3 -lt $Hex.Length; $i += 4) { [void]$sb.Append([char][Convert]::ToInt32($Hex.Substring($i, 4), 16)) }
    return $sb.ToString()
}

function Read-AIPdfCMap([string]$T) {
    <#  Una tabla ToUnicode: codigo -> texto. Los rangos cortos se abren en
        la tabla; los largos (0000-FFFF) se guardan como rango.  #>
    $mapa = New-Object 'System.Collections.Generic.Dictionary[int,string]'
    $rangos = New-Object 'System.Collections.Generic.List[object]'
    $bytes = 0
    $cs = [regex]::Match($T, 'begincodespacerange\s*<([0-9A-Fa-f]+)>')
    if ($cs.Success) { $bytes = [int]($cs.Groups[1].Value.Length / 2) }
    foreach ($b in [regex]::Matches($T, '(?s)beginbfchar(.*?)endbfchar')) {
        foreach ($p in [regex]::Matches($b.Groups[1].Value, '<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]*)>')) {
            if (-not $bytes) { $bytes = [int]($p.Groups[1].Value.Length / 2) }
            $mapa[[Convert]::ToInt32($p.Groups[1].Value, 16)] = ConvertFrom-AIPdfUtf16 $p.Groups[2].Value
        }
    }
    foreach ($b in [regex]::Matches($T, '(?s)beginbfrange(.*?)endbfrange')) {
        foreach ($p in [regex]::Matches($b.Groups[1].Value, '<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*(?:<([0-9A-Fa-f]*)>|\[([^\]]*)\])')) {
            if (-not $bytes) { $bytes = [int]($p.Groups[1].Value.Length / 2) }
            $lo = [Convert]::ToInt32($p.Groups[1].Value, 16); $hi = [Convert]::ToInt32($p.Groups[2].Value, 16)
            if ($hi -lt $lo) { continue }
            if ($p.Groups[3].Success) {
                $base = ConvertFrom-AIPdfUtf16 $p.Groups[3].Value
                if (-not $base) { continue }
                if ($hi - $lo -le 1024) {
                    $pre = $base.Substring(0, $base.Length - 1); $ult = [int]$base[$base.Length - 1]
                    for ($c = $lo; $c -le $hi; $c++) { $mapa[$c] = $pre + [char](($ult + $c - $lo) -band 0xFFFF) }
                } else { $rangos.Add(@($lo, $hi, $base)) }
            } else {
                $c = $lo
                foreach ($h in [regex]::Matches($p.Groups[4].Value, '<([0-9A-Fa-f]*)>')) {
                    if ($c -gt $hi) { break }
                    $mapa[$c] = ConvertFrom-AIPdfUtf16 $h.Groups[1].Value; $c++
                }
            }
        }
    }
    return @{ Mapa = $mapa; Rangos = $rangos; Bytes = $bytes }
}

function New-AIPdfFuenteVacia {
    <#  Sin tipo de letra (o uno que no se encuentra): Windows-1252.  #>
    $an = [Linq.Enumerable]::ToArray([Linq.Enumerable]::Repeat([double]500, 256)); $an[32] = 278.0
    return @{ Dos = $false; Mapa = $null; Rangos = $null; Base = $script:AIPdfWin; Ancho = $null; AnchoDef = 500.0; Escala = 0.001
              Negrita = $false; Espacio = 278.0; Tabla = $script:AIPdfWin; Anchos = $an }
}

function Get-AIPdfFuente($Doc, $Ref) {
    <#  Lo que hace falta para leer con un tipo de letra: como se descifra
        cada codigo y cuanto avanza (para saber donde van los espacios).  #>
    $clave = if ($Ref -is [long]) { "r$Ref" } else { "d$([Runtime.CompilerServices.RuntimeHelpers]::GetHashCode($Ref))" }
    if ($Doc.Fuentes.ContainsKey($clave)) { return $Doc.Fuentes[$clave] }
    $fd = Get-AIPdfValor $Doc $Ref
    $f = @{ Dos = $false; Mapa = $null; Rangos = $null; Base = $script:AIPdfWin; Ancho = $null; AnchoDef = 500.0; Escala = 0.001; Negrita = $false; Espacio = 278.0 }
    if ($fd -isnot [hashtable]) { $f = New-AIPdfFuenteVacia; $Doc.Fuentes[$clave] = $f; return $f }
    $sub = [string]$fd['Subtype']
    $nombre = [string](Get-AIPdfValor $Doc $fd['BaseFont'])
    $f.Negrita = $nombre -match '(?i)bold|black|heavy|semibold|demi'
    # La tabla ToUnicode manda: es la que dice que letra es cada codigo.
    $tu = $fd['ToUnicode']
    $cmap = $null
    if ($tu -is [long]) {
        $t = Get-AIPdfDatos $Doc $tu
        if ($t) { $cmap = Read-AIPdfCMap $t; $f.Mapa = $cmap.Mapa; if ($cmap.Rangos.Count) { $f.Rangos = $cmap.Rangos } }
    }
    if ($sub -eq '/Type0') {
        $f.Dos = $true
        $f.Base = $null                       # sin ToUnicode, un CID no dice que letra es
        $enc = $fd['Encoding']
        if ($enc -is [long]) {
            $t = Get-AIPdfDatos $Doc $enc
            if ($t) { $m = [regex]::Match($t, 'begincodespacerange\s*<([0-9A-Fa-f]+)>'); if ($m.Success -and $m.Groups[1].Value.Length -eq 2) { $f.Dos = $false } }
        }
        $desc = Get-AIPdfValor $Doc $fd['DescendantFonts']
        $cid = if ($desc -is [System.Collections.IList] -and $desc.Count) { Get-AIPdfValor $Doc $desc[0] } else { $null }
        if ($cid -is [hashtable]) {
            if ($null -ne $cid['DW']) { $f.AnchoDef = [double](Get-AIPdfValor $Doc $cid['DW']) } else { $f.AnchoDef = 1000.0 }
            $w = Get-AIPdfValor $Doc $cid['W']
            if ($w -is [System.Collections.IList]) {
                $f.Ancho = New-Object 'System.Collections.Generic.Dictionary[int,double]'
                $i = 0
                while ($i -lt $w.Count) {
                    $c0 = [int]$w[$i]
                    $sig = $w[$i + 1]; if ($sig -is [long]) { $sig = Get-AIPdfValor $Doc $sig }
                    if ($sig -is [System.Collections.IList]) {
                        for ($k = 0; $k -lt $sig.Count; $k++) { $f.Ancho[$c0 + $k] = [double]$sig[$k] }
                        $i += 2
                    } else {
                        if ($i + 2 -ge $w.Count) { break }
                        $c1 = [int]$sig; $an = [double]$w[$i + 2]
                        if ($c1 - $c0 -le 65535) { for ($c = $c0; $c -le $c1; $c++) { $f.Ancho[$c] = $an } }
                        $i += 3
                    }
                }
            }
            if (-not $nombre) { $nombre = [string]$cid['BaseFont'] }
        } else { $f.AnchoDef = 1000.0 }
        $f.Espacio = $f.AnchoDef
    } else {
        # Un tipo de letra simple: un byte por letra y su codificacion.
        $enc = Get-AIPdfValor $Doc $fd['Encoding']
        $baseNom = if ($enc -is [hashtable]) { [string]$enc['BaseEncoding'] } else { [string]$enc }
        $base = if ($baseNom -eq '/MacRomanEncoding') { $script:AIPdfMac } else { $script:AIPdfWin }
        if ($nombre -match '(?i)symbol|dingbat|wingding|webding') {
            # Vinetas y simbolos: no son texto; la vineta de una lista de Word
            # sale de aqui (0xB7).
            $base = New-Object 'string[]' 256
            for ($i = 0; $i -lt 256; $i++) { $base[$i] = '' }
            $base[0xB7] = '-'; $base[0x6C] = '-'; $base[0xA7] = '-'
        } else { $base = [string[]]$base.Clone() }
        if ($enc -is [hashtable]) {
            $dif = Get-AIPdfValor $Doc $enc['Differences']
            if ($dif -is [System.Collections.IList]) {
                $c = 0
                foreach ($d in $dif) {
                    if ($d -is [double]) { $c = [int]$d; continue }
                    if ($d -is [string] -and $c -ge 0 -and $c -lt 256) { $base[$c] = Get-AIPdfGlifo $d; $c++ }
                }
            }
        }
        $f.Base = $base
        if ($sub -eq '/Type3') {
            $fm = Get-AIPdfValor $Doc $fd['FontMatrix']
            if ($fm -is [System.Collections.IList] -and $fm.Count -ge 1) { $f.Escala = [Math]::Abs([double]$fm[0]) }
        }
        $ws = Get-AIPdfValor $Doc $fd['Widths']
        if ($ws -is [System.Collections.IList]) {
            $f.Ancho = New-Object 'System.Collections.Generic.Dictionary[int,double]'
            $c0 = [int](Get-AIPdfValor $Doc $fd['FirstChar'])
            for ($k = 0; $k -lt $ws.Count; $k++) { $x = $ws[$k]; if ($x -is [long]) { $x = Get-AIPdfValor $Doc $x }; $f.Ancho[$c0 + $k] = [double]$x }
            $fdes = Get-AIPdfValor $Doc $fd['FontDescriptor']
            $f.AnchoDef = if ($fdes -is [hashtable] -and $null -ne $fdes['MissingWidth']) { [double]$fdes['MissingWidth'] } else { 0.0 }
            if ($f.Ancho.ContainsKey(32)) { $f.Espacio = $f.Ancho[32] }
        }
    }
    # Todo en dos tablas por codigo (letra y ancho): una consulta por letra.
    $tam = if ($f.Dos) { 65536 } else { 256 }
    $tabla = New-Object 'string[]' $tam
    if ($null -ne $f.Base) { [Array]::Copy($f.Base, $tabla, [Math]::Min(256, $f.Base.Length)) }
    if ($null -ne $f.Rangos) {
        foreach ($r in $f.Rangos) {
            $b = $r[2]; $pre = $b.Substring(0, $b.Length - 1); $ult = [int]$b[$b.Length - 1]
            for ($c = $r[0]; $c -le [Math]::Min($r[1], $tam - 1); $c++) { $tabla[$c] = $pre + [char](($ult + $c - $r[0]) -band 0xFFFF) }
        }
    }
    if ($null -ne $f.Mapa) { foreach ($kv in $f.Mapa.GetEnumerator()) { if ($kv.Key -ge 0 -and $kv.Key -lt $tam) { $tabla[$kv.Key] = $kv.Value } } }
    $anchos = [Linq.Enumerable]::ToArray([Linq.Enumerable]::Repeat([double]$f.AnchoDef, $tam))
    if ($null -ne $f.Ancho) { foreach ($kv in $f.Ancho.GetEnumerator()) { if ($kv.Key -ge 0 -and $kv.Key -lt $tam) { $anchos[$kv.Key] = $kv.Value } } }
    elseif (-not $f.Dos) { $anchos[32] = $f.Espacio }
    $f.Tabla = $tabla; $f.Anchos = $anchos
    $Doc.Fuentes[$clave] = $f
    return $f
}

# ---------------------------------------------------------------------------
#  Contenido de las paginas
# ---------------------------------------------------------------------------
function New-AIPdfLinea($E, [bool]$Hueco) {
    $l = @{ SB = [Text.StringBuilder]::new(); SumaTam = 0.0; N = 0; Neg = $true; Hueco = $Hueco }
    $E.Lineas.Add($l)
    $E.Linea = $l
    return $l
}

function Merge-AIPdfMatriz([double[]]$A, [double[]]$B) {
    <#  A x B (matrices de PDF de 6 numeros).  #>
    return [double[]]@(
        ($A[0] * $B[0] + $A[1] * $B[2]), ($A[0] * $B[1] + $A[1] * $B[3]),
        ($A[2] * $B[0] + $A[3] * $B[2]), ($A[2] * $B[1] + $A[3] * $B[3]),
        ($A[4] * $B[0] + $A[5] * $B[2] + $B[4]), ($A[4] * $B[1] + $A[5] * $B[3] + $B[5]))
}

function Read-AIPdfContenido($E, [string]$Cont, $Rec, [int]$Prof = 0) {
    <#  Recorre el contenido de una pagina (o de un formulario dentro de ella)
        con sus recursos (tipos de letra y formularios), y va poniendo cada
        trozo de texto donde le toca: en la misma linea (con un espacio, o con
        " | " si el hueco es de columna) o en una nueva (y si el salto es
        grande, en un parrafo nuevo).
        Todo va en variables locales y sin llamar a funciones por cada letra:
        Chrome y Edge colocan las letras de una en una, y asi una pagina
        llena tarda decimas de segundo y no segundos.  #>
    $doc = $E.Doc
    $fuentes = if ($Rec -is [hashtable]) { Get-AIPdfValor $doc $Rec['Font'] } else { $null }
    $reTJ = $script:AIPdfReTJ
    $repl = [string][char]0xFFFD
    # El estado del texto.
    $ctm = $E.Ctm; $tm = $E.Tm; $tlm = $E.Tlm
    $fnt = $E.Fuente; $tfs = $E.Tfs; $tc = $E.Tc; $tw = $E.Tw; $th = $E.Th; $tl = $E.TL
    $pila = $E.Pila
    $f = if ($fnt) { $fnt } else { $E.SinFuente }
    $fTabla = $f.Tabla; $fAnchos = $f.Anchos; $fDos = $f.Dos
    $fEsc = $f.Escala; $fNeg = $f.Negrita
    # La salida.
    $lineas = $E.Lineas; $lin = $E.Linea; $lsb = $lin.SB
    $lSuma = $lin.SumaTam; $lN = $lin.N; $lNeg = $lin.Neg
    $hay = $E.Hay; $ux = $E.UX; $uy = $E.UY; $ut = $E.UT
    $largo = $E.Largo; $glifos = $E.Glifos; $desc = $E.Desconocidos
    $finEsp = ($lsb.Length -eq 0) -or ($lsb.ToString($lsb.Length - 1, 1) -eq ' ')
    $sbt = $E.SBT
    $u = $null; $ww = 0.0; $d = 0.0; $tx = 0.0; $ty = 0.0
    $ns = [Globalization.NumberStyles]::Float; $ci = $script:AIPdfCI

    foreach ($m in $script:AIPdfReCont.Matches($Cont)) {
        if ($largo -gt $AI_PDF_MAX_TEXTO) { break }
        $g = $m.Groups
        $items = $null
        if ($g['tj'].Success) { $items = , $g['tj'].Value }
        elseif ($g['tja'].Success) { $items = $reTJ.Matches($g['tja'].Value) }
        elseif ($g['td'].Success) {
            $null = [double]::TryParse($g['tdx'].Value, $ns, $ci, [ref]$tx); $null = [double]::TryParse($g['tdy'].Value, $ns, $ci, [ref]$ty)
            if ($g['td'].Value -ceq 'TD') { $tl = - $ty }
            $tlm[4] += $tx * $tlm[0] + $ty * $tlm[2]; $tlm[5] += $tx * $tlm[1] + $ty * $tlm[3]
            $tm = [double[]]$tlm.Clone()
            continue
        }
        elseif ($g['m6'].Success) {
            $pz = $g['m6'].Value.Trim() -split '\s+'
            $v = New-Object 'double[]' 6
            for ($k = 0; $k -lt 6; $k++) { $null = [double]::TryParse($pz[$k], $ns, $ci, [ref]$d); $v[$k] = $d }
            if ($g['o6'].Value -ceq 'Tm') { $tlm = $v; $tm = [double[]]$v.Clone() } else { $ctm = [double[]]@(($v[0] * $ctm[0] + $v[1] * $ctm[2]), ($v[0] * $ctm[1] + $v[1] * $ctm[3]), ($v[2] * $ctm[0] + $v[3] * $ctm[2]), ($v[2] * $ctm[1] + $v[3] * $ctm[3]), ($v[4] * $ctm[0] + $v[5] * $ctm[2] + $ctm[4]), ($v[4] * $ctm[1] + $v[5] * $ctm[3] + $ctm[5])) }
            continue
        }
        elseif ($g['tf'].Success) {
            $null = [double]::TryParse($g['tfs'].Value, $ns, $ci, [ref]$tfs)
            $nombre = $g['tf'].Value.Substring(1)
            $fnt = if ($fuentes -is [hashtable] -and $null -ne $fuentes[$nombre]) { Get-AIPdfFuente $doc $fuentes[$nombre] } else { $null }
            $f = if ($fnt) { $fnt } else { $E.SinFuente }
            $fTabla = $f.Tabla; $fAnchos = $f.Anchos; $fDos = $f.Dos
            $fEsc = $f.Escala; $fNeg = $f.Negrita
            continue
        }
        elseif ($g['op'].Success) {
            switch -CaseSensitive ($g['op'].Value) {
                'BT' { $tm = [double[]]@(1, 0, 0, 1, 0, 0); $tlm = [double[]]@(1, 0, 0, 1, 0, 0) }
                'T*' { $tlm[4] += - $tl * $tlm[2]; $tlm[5] += - $tl * $tlm[3]; $tm = [double[]]$tlm.Clone() }
                'q'  { $pila.Push(@($ctm, $fnt, $tfs, $tc, $tw, $th, $tl)) }
                'Q'  {
                    if ($pila.Count) {
                        $p = $pila.Pop()
                        $ctm = $p[0]; $fnt = $p[1]; $tfs = $p[2]; $tc = $p[3]; $tw = $p[4]; $th = $p[5]; $tl = $p[6]
                        $f = if ($fnt) { $fnt } else { $E.SinFuente }
                        $fTabla = $f.Tabla; $fAnchos = $f.Anchos; $fDos = $f.Dos
                        $fEsc = $f.Escala; $fNeg = $f.Negrita
                    }
                }
            }
            continue
        }
        elseif ($g['v1'].Success) {
            $v = 0.0; $null = [double]::TryParse($g['v1'].Value, $ns, $ci, [ref]$v)
            switch -CaseSensitive ($g['o1'].Value) { 'TL' { $tl = $v } 'Tc' { $tc = $v } 'Tw' { $tw = $v } 'Tz' { $th = $v / 100.0 } }
            continue
        }
        elseif ($g['ap'].Success -or $g['qq'].Success) {
            if ($g['qq'].Success) { $null = [double]::TryParse($g['aw'].Value, $ns, $ci, [ref]$tw); $null = [double]::TryParse($g['ac'].Value, $ns, $ci, [ref]$tc); $items = , $g['qq'].Value }
            else { $items = , $g['ap'].Value }
            $tlm[4] += - $tl * $tlm[2]; $tlm[5] += - $tl * $tlm[3]; $tm = [double[]]$tlm.Clone()
        }
        elseif ($g['xo'].Success) {
            # Un formulario (XObject /Form): contenido aparte, a veces con texto.
            if ($Prof -ge 8 -or $Rec -isnot [hashtable]) { continue }
            $xos = Get-AIPdfValor $doc $Rec['XObject']
            if ($xos -isnot [hashtable]) { continue }
            $ref = $xos[$g['xo'].Value.Substring(1)]
            if ($ref -isnot [long]) { continue }
            $xd = Get-AIPdfObj $doc $ref
            if ($xd -isnot [hashtable] -or [string]$xd['Subtype'] -ne '/Form') { continue }
            $datos = Get-AIPdfDatos $doc $ref
            if (-not $datos) { continue }
            $rec2 = Get-AIPdfValor $doc $xd['Resources']
            if ($rec2 -isnot [hashtable]) { $rec2 = $Rec }
            $ctm2 = $ctm
            $mx = Get-AIPdfValor $doc $xd['Matrix']
            if ($mx -is [System.Collections.IList] -and $mx.Count -eq 6) { $ctm2 = Merge-AIPdfMatriz ([double[]]@($mx | ForEach-Object { [double]$_ })) $ctm }
            $lin.SumaTam = $lSuma; $lin.N = $lN; $lin.Neg = $lNeg
            $E.Linea = $lin; $E.Hay = $hay; $E.UX = $ux; $E.UY = $uy; $E.UT = $ut; $E.Largo = $largo; $E.Glifos = $glifos; $E.Desconocidos = $desc
            $E.Ctm = $ctm2; $E.Tm = [double[]]@(1, 0, 0, 1, 0, 0); $E.Tlm = [double[]]@(1, 0, 0, 1, 0, 0)
            $E.Fuente = $fnt; $E.Tfs = $tfs; $E.Tc = $tc; $E.Tw = $tw; $E.Th = $th; $E.TL = $tl
            Read-AIPdfContenido $E $datos $rec2 ($Prof + 1)
            $lin = $E.Linea; $lsb = $lin.SB; $lSuma = $lin.SumaTam; $lN = $lin.N; $lNeg = $lin.Neg
            $hay = $E.Hay; $ux = $E.UX; $uy = $E.UY; $ut = $E.UT; $largo = $E.Largo; $glifos = $E.Glifos; $desc = $E.Desconocidos
            $finEsp = ($lsb.Length -eq 0) -or ($lsb.ToString($lsb.Length - 1, 1) -eq ' ')
            continue
        }
        else { continue }

        # Mostrar: cada cadena, con su tipo de letra, en su sitio.
        foreach ($it in $items) {
            if ($it -is [string]) { $raw = $it }
            elseif ($it.Groups['x'].Success) {
                $null = [double]::TryParse($it.Groups['x'].Value, $ns, $ci, [ref]$d); $d = - $d / 1000.0 * $tfs * $th
                $tm[4] += $d * $tm[0]; $tm[5] += $d * $tm[1]
                continue
            } else { $raw = $it.Groups['s'].Value }
            # Los codigos de la cadena: de 1 o 2 bytes; en hexadecimal se
            # leen directamente (Chrome y Edge escriben todo asi).
            $null = $sbt.Clear()
            $adv = 0.0; $nc = 0; $nesp = 0
            if ($raw[0] -eq '(') {
                $bytes = if ($raw.IndexOf('\') -ge 0) { ConvertFrom-AIPdfLiteral $raw } else { $raw.Substring(1, $raw.Length - 2) }
                $n = $bytes.Length; $k = 0
                while ($k -lt $n) {
                    if ($fDos) { if ($k + 1 -ge $n) { break }; $c = ([int]$bytes[$k] -shl 8) -bor [int]$bytes[$k + 1]; $k += 2 }
                    else { $c = [int]$bytes[$k]; $k++; if ($c -eq 32) { $nesp++ } }
                    $u = $fTabla[$c]
                    if ($null -eq $u) { $desc++; $u = $repl }
                    $null = $sbt.Append($u); $adv += $fAnchos[$c]; $nc++
                }
            } else {
                $h = $raw.Substring(1, $raw.Length - 2)
                if ($h.IndexOfAny($script:AIPdfBlancos) -ge 0) { $h = $h -replace '\s+', '' }
                $paso = if ($fDos) { 4 } else { 2 }
                while ($h.Length % $paso) { $h += '0' }
                for ($k = 0; $k -lt $h.Length; $k += $paso) {
                    $c = [Convert]::ToInt32($h.Substring($k, $paso), 16)
                    if ($c -eq 32 -and -not $fDos) { $nesp++ }
                    $u = $fTabla[$c]
                    if ($null -eq $u) { $desc++; $u = $repl }
                    $null = $sbt.Append($u); $adv += $fAnchos[$c]; $nc++
                }
            }
            $glifos += $nc
            $adv = ($adv * $fEsc * $tfs + $tc * $nc + $tw * $nesp) * $th
            $x = $tm[4] * $ctm[0] + $tm[5] * $ctm[2] + $ctm[4]
            $y = $tm[4] * $ctm[1] + $tm[5] * $ctm[3] + $ctm[5]
            $vx = $tfs * $tm[2]; $vy = $tfs * $tm[3]
            $ax = $vx * $ctm[0] + $vy * $ctm[2]; $ay = $vx * $ctm[1] + $vy * $ctm[3]
            $tam = [Math]::Sqrt($ax * $ax + $ay * $ay)
            if ($tam -le 0.1) { $tam = 10.0 }
            $tm[4] += $adv * $tm[0]; $tm[5] += $adv * $tm[1]
            $finX = $tm[4] * $ctm[0] + $tm[5] * $ctm[2] + $ctm[4]
            if (-not $sbt.Length) { continue }
            $txt = $sbt.ToString()
            $empEsp = $txt[0] -eq ' '

            # Donde va: misma linea (y si con espacio o columna) o una nueva.
            $nueva = $false; $hueco = $false
            if ($hay) {
                $ref = if ($tam -gt $ut) { $tam } else { $ut }
                $dy = $y - $uy
                if ($dy -gt $ref * 0.5 -or $dy -lt - $ref * 0.5) { $nueva = $true; $hueco = ($dy -lt - $ref * 1.65) -or ($dy -gt $ref * 2) }
                else {
                    $dx = $x - $ux
                    if (-not $finEsp -and -not $empEsp -and $dx -gt $ref * 0.8) { $null = $lsb.Append(' | '); $finEsp = $true }
                    elseif (-not $finEsp -and -not $empEsp -and $dx -gt $ref * 0.15) { $null = $lsb.Append(' '); $finEsp = $true }
                    elseif ($dx -lt - $ref * 1.5) { $nueva = $true }
                }
            }
            if ($nueva) {
                $lin.SumaTam = $lSuma; $lin.N = $lN; $lin.Neg = $lNeg
                $lin = @{ SB = [Text.StringBuilder]::new(); SumaTam = 0.0; N = 0; Neg = $true; Hueco = $hueco }
                $lineas.Add($lin)
                $lsb = $lin.SB; $lSuma = 0.0; $lN = 0; $lNeg = $true; $finEsp = $true
            }
            $null = $lsb.Append($txt)
            $finEsp = $txt[$txt.Length - 1] -eq ' '
            $nt = $txt.Trim().Length
            if ($nt) { $lSuma += $tam * $nt; $lN += $nt; if (-not $fNeg) { $lNeg = $false } }
            $ux = $finX; $uy = $y; $ut = $tam; $hay = $true
            $largo += $txt.Length
        }
    }
    $lin.SumaTam = $lSuma; $lin.N = $lN; $lin.Neg = $lNeg
    $E.Linea = $lin; $E.Hay = $hay; $E.UX = $ux; $E.UY = $uy; $E.UT = $ut
    $E.Largo = $largo; $E.Glifos = $glifos; $E.Desconocidos = $desc
}

function Get-AIPdfPaginas($Doc) {
    <#  Las paginas en orden, cada una con sus recursos (que se heredan del
        arbol de paginas).  #>
    $out = New-Object 'System.Collections.Generic.List[object]'
    $raiz = $null
    $ms = [regex]::Matches($Doc.S, '/Root\s+(\d+)\s+\d+\s+R')
    if ($ms.Count) { $raiz = Get-AIPdfObj $Doc ([long]$ms[$ms.Count - 1].Groups[1].Value) }
    $vistos = New-Object 'System.Collections.Generic.HashSet[long]'
    $recorre = {
        param($ref, $rec, $prof)
        if ($out.Count -ge $AI_PDF_MAX_PAGINAS -or $prof -gt 40) { return }
        if ($ref -is [long] -and -not $vistos.Add($ref)) { return }
        $n = Get-AIPdfValor $Doc $ref
        if ($n -isnot [hashtable]) { return }
        $r = Get-AIPdfValor $Doc $n['Resources']
        if ($r -isnot [hashtable]) { $r = $rec }
        $kids = Get-AIPdfValor $Doc $n['Kids']
        if ($kids -is [System.Collections.IList]) { foreach ($k in $kids) { & $recorre $k $r ($prof + 1) } }
        elseif ([string]$n['Type'] -ne '/Pages') { $out.Add(@{ Dic = $n; Rec = $r }) }
    }
    if ($raiz -is [hashtable] -and $null -ne $raiz['Pages']) { & $recorre $raiz['Pages'] $null 0 }
    if (-not $out.Count) {
        # Sin arbol de paginas que valga: las paginas en el orden del fichero.
        $lista = @($Doc.Obj.Keys | Sort-Object { $Doc.Obj[$_].Pos })
        foreach ($k in $lista) {
            $x = $Doc.Obj[$k]
            $txt = if ($null -ne $x.Texto) { $x.Texto } else { $Doc.S.Substring($x.Ini, $x.Fin - $x.Ini) }
            if ($txt -match '/Type\s*/Page(?![A-Za-z])') { $d = Get-AIPdfObj $Doc $k; if ($d -is [hashtable]) { $out.Add(@{ Dic = $d; Rec = (Get-AIPdfValor $Doc $d['Resources']) }) } }
            if ($out.Count -ge $AI_PDF_MAX_PAGINAS) { break }
        }
    }
    return , $out
}

function Format-AIPdfLineas($Lineas) {
    <#  Las lineas en texto: parrafos separados por una linea en blanco y los
        titulos (letra mas grande que el cuerpo, o una linea corta toda en
        negrita) como "# titulo".  #>
    $peso = @{}
    foreach ($l in $Lineas) { if ($l.N) { $k = [Math]::Round($l.SumaTam / $l.N * 2) / 2; $peso[$k] = [int]$peso[$k] + $l.N } }
    $cuerpo = 0.0
    if ($peso.Count) { $cuerpo = [double](($peso.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key) }
    $textos = foreach ($l in $Lineas) { ($l.SB.ToString() -replace '\s+', ' ').Trim() }
    $textos = @($textos)
    $nivel = New-Object 'int[]' $Lineas.Count
    $tams = @{}
    $conTexto = 0
    for ($i = 0; $i -lt $Lineas.Count; $i++) {
        $l = $Lineas[$i]; $t = $textos[$i]
        if (-not $l.N) { continue }
        $conTexto++
        if ($t.Length -gt 90 -or $t -notmatch '\p{L}{2}' -or $t.Contains(' | ')) { continue }
        $tam = [Math]::Round($l.SumaTam / $l.N * 2) / 2
        if ($cuerpo -gt 0 -and $tam -ge $cuerpo * 1.18) { $nivel[$i] = -1; $tams[$tam] = 1 }
        elseif ($l.Neg -and $t.Length -le 70 -and $t -notmatch '[.,;]$' -and $cuerpo -gt 0 -and $tam -ge $cuerpo * 0.95) { $nivel[$i] = -2 }
    }
    $orden = @($tams.Keys | Sort-Object -Descending)
    $titulos = @($nivel | Where-Object { $_ -ne 0 }).Count
    $usar = $conTexto -ge 4 -and $titulos -le [Math]::Max(2, $conTexto * 0.35)
    $sb = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $Lineas.Count; $i++) {
        $l = $Lineas[$i]; $t = $textos[$i]
        if (-not $t) { if ($l.Hueco) { [void]$sb.Append("`n") }; continue }
        if ($l.Hueco -and $sb.Length) { [void]$sb.Append("`n") }
        $nv = 0
        if ($usar -and $nivel[$i] -eq -1) { $nv = [Math]::Min(3, [array]::IndexOf($orden, [Math]::Round($l.SumaTam / $l.N * 2) / 2) + 1) }
        elseif ($usar -and $nivel[$i] -eq -2) { $nv = [Math]::Min(3, $orden.Count + 1) }
        if ($nv) { [void]$sb.Append("`n").Append('#' * $nv).Append(' ').Append($t).Append("`n`n") }
        else { [void]$sb.Append($t).Append("`n") }
    }
    $r = $sb.ToString()
    # Palabras partidas con guion al final de la linea; ligaduras; vinetas.
    $r = [regex]::Replace($r, '(\p{L})-\n(\p{Ll})', '$1$2')
    $r = $r.Replace([string][char]0xFB00, 'ff').Replace([string][char]0xFB01, 'fi').Replace([string][char]0xFB02, 'fl').Replace([string][char]0xFB03, 'ffi').Replace([string][char]0xFB04, 'ffl')
    $r = [regex]::Replace($r, '(?m)^[\uE000-\uF8FF\u2022\u25AA\u25CF\u25E6\u2023\u2043]\s*', '- ')
    $r = [regex]::Replace($r, '[\uE000-\uF8FF]', '')
    return $r
}

function Test-AIPdfLegible([string]$Texto) {
    <#  Si lo leido parece texto: un tipo de letra mal descifrado da palabras
        sin vocales y signos sueltos, no palabras corrientes.  #>
    $pal = @([regex]::Matches($Texto, '\p{L}{2,}') | ForEach-Object { $_.Value })
    if ($pal.Count -lt 30) { return $true }
    $sinVocal = @($pal | Where-Object { $_ -notmatch '(?i)[aeiouy\u00E0-\u00E6\u00E8-\u00EF\u00F2-\u00F6\u00F9-\u00FC]' }).Count
    $raros = [regex]::Matches($Texto, '[^\p{L}\p{N}\s\p{P}\p{Sc}|+=<>~^]').Count
    $letras = [regex]::Matches($Texto, '[\p{L}\p{N}]').Count
    $llenos = [Math]::Max(1, [regex]::Matches($Texto, '\S').Count)
    $ok = ($sinVocal / $pal.Count) -lt 0.35 -and ($raros / $llenos) -lt 0.1 -and ($letras / $llenos) -gt 0.6
    return $ok
}

function Read-AIPdf {
    <#  El texto de un PDF: @{ Texto; Aviso }. Lanza un error (en el idioma activo,
        para el usuario) si no se puede leer sin riesgo de leer mal.  #>
    param([string]$Ruta)
    $s = $script:AIPdfL1.GetString([IO.File]::ReadAllBytes($Ruta))
    $p = $s.IndexOf('%PDF-')
    if ($p -lt 0 -or $p -gt 1024) { throw (Get-AIPdfMensaje 'pdfNoEs') }
    if ([regex]::IsMatch($s, '/Encrypt\s*(?:\d+\s+\d+\s+R|<<)')) {
        throw (Get-AIPdfMensaje 'pdfProtegido')
    }
    $doc = New-AIPdfDoc $s
    $pags = Get-AIPdfPaginas $doc
    if (-not $pags.Count) { throw (Get-AIPdfMensaje 'pdfPaginas') }
    $E = @{
        Doc = $doc; Lineas = (New-Object 'System.Collections.Generic.List[object]'); Linea = $null; Hay = $false
        UX = 0.0; UY = 0.0; UT = 0.0; Largo = 0; Glifos = 0; Desconocidos = 0
        Ctm = [double[]]@(1, 0, 0, 1, 0, 0); Tm = [double[]]@(1, 0, 0, 1, 0, 0); Tlm = [double[]]@(1, 0, 0, 1, 0, 0)
        Fuente = $null; Tfs = 10.0; Tc = 0.0; Tw = 0.0; Th = 1.0; TL = 0.0
        Pila = (New-Object System.Collections.Stack); SBT = (New-Object System.Text.StringBuilder)
        SinFuente = (New-AIPdfFuenteVacia)
    }
    [void](New-AIPdfLinea $E $false)
    foreach ($pg in $pags) {
        if ($E.Largo -gt $AI_PDF_MAX_TEXTO) { break }
        $c = Get-AIPdfValor $doc $pg.Dic['Contents']
        $refs = @()
        $cref = $pg.Dic['Contents']
        if ($cref -is [long] -and $doc.Obj.ContainsKey($cref) -and $doc.Obj[$cref].DIni -ge 0) { $refs = @($cref) }
        elseif ($c -is [System.Collections.IList]) { $refs = @($c) }
        $partes = foreach ($r in $refs) { if ($r -is [long]) { Get-AIPdfDatos $doc $r } }
        $cont = (@($partes) | Where-Object { $_ }) -join "`n"
        $E.Ctm = [double[]]@(1, 0, 0, 1, 0, 0); $E.Pila.Clear(); $E.Fuente = $null; $E.Tc = 0.0; $E.Tw = 0.0; $E.Th = 1.0; $E.TL = 0.0
        $E.Hay = $false
        [void](New-AIPdfLinea $E $true)
        if ($cont) { Read-AIPdfContenido $E $cont $pg.Rec }
    }
    if (-not $E.Glifos) { return @{ Texto = ''; Aviso = '' } }
    $desc = $E.Desconocidos / $E.Glifos
    $texto = Format-AIPdfLineas $E.Lineas
    if ($desc -gt $AI_PDF_MAX_DESCONOC -or -not (Test-AIPdfLegible $texto)) {
        throw (Get-AIPdfMensaje 'pdfLetras')
    }
    $aviso = if ($E.Desconocidos) { Get-AIPdfMensaje 'pdfAviso' @($E.Desconocidos) } else { '' }
    return @{ Texto = $texto; Aviso = $aviso }
}
