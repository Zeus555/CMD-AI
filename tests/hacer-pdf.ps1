#requires -Version 5.1
# ---------------------------------------------------------------------------
#  hacer-pdf.ps1 - Escribe PDFs de prueba de verdad, sin bibliotecas, para
#  documentos.ps1 y negocio.ps1 (no es una prueba: se carga con ". ").
#
#  Cada pagina es una lista de lineas. Una linea es una tabla con:
#    T      el texto                    Celdas  o varias, en columnas (X)
#    Tam    tamano de letra (11)         X       margen o columnas (72)
#    F      'R' normal, 'B' negrita, 'C' CID con ToUnicode, 'D' con tabla
#           /Differences (las letras por su nombre)
#    Kern   las palabras separadas con desplazamientos (TJ), sin espacios
#    Hueco  puntos de mas antes de la linea (un parrafo nuevo)
#  Las opciones del PDF entero: -Comprimir (Flate), -ObjStm (objetos dentro
#  de un stream y tabla xref en stream, como Word y Chrome), -SinToUnicode
#  (el tipo de letra CID sin su tabla: no se puede descifrar), -Cifrado
#  (marcado como protegido) e -Imagen (solo una imagen: un escaneo).
#  Los tipos R, B y D se ven bien en cualquier visor (Helvetica y Times, que
#  trae todo visor); C no lleva el tipo de letra dentro: es solo para leerlo.
#  Comentarios y expresiones regulares en ASCII.
# ---------------------------------------------------------------------------

$script:PdfL1 = [Text.Encoding]::GetEncoding(28591)
$script:PdfCp = [Text.Encoding]::GetEncoding(1252)

function ConvertTo-PdfZlib([string]$Datos) {
    $b = $script:PdfL1.GetBytes($Datos)
    $ms = New-Object IO.MemoryStream
    $ms.WriteByte(0x78); $ms.WriteByte(0x9C)
    $ds = New-Object IO.Compression.DeflateStream -ArgumentList $ms, ([IO.Compression.CompressionMode]::Compress), $true
    $ds.Write($b, 0, $b.Length); $ds.Dispose()
    [long]$s1 = 1; [long]$s2 = 0
    foreach ($x in $b) { $s1 = ($s1 + $x) % 65521; $s2 = ($s2 + $s1) % 65521 }
    $ad = ($s2 -shl 16) -bor $s1
    foreach ($sh in 24, 16, 8, 0) { $ms.WriteByte([byte](($ad -shr $sh) -band 255)) }
    return $script:PdfL1.GetString($ms.ToArray())
}

function ConvertTo-PdfCadena([string]$T) {
    <#  Texto -> cadena literal de PDF en Windows-1252, con sus escapes.  #>
    $b = $script:PdfL1.GetString($script:PdfCp.GetBytes($T))
    return '(' + $b.Replace('\', '\\').Replace('(', '\(').Replace(')', '\)') + ')'
}

# Nombres de letra para el tipo D. Diccionarios ordinales: en una tabla de
# PowerShell (@{}) la "a" y la "A" serian la misma clave.
$script:PdfNombres = New-Object 'System.Collections.Generic.Dictionary[string,string]'
foreach ($p in @(@(0xE1, 'aacute'), @(0xE9, 'eacute'), @(0xED, 'iacute'), @(0xF3, 'oacute'), @(0xFA, 'uacute'), @(0xF1, 'ntilde'),
                 @(0xC1, 'Aacute'), @(0xC9, 'Eacute'), @(0xD3, 'Oacute'), @(0xD1, 'Ntilde'), @(0xFC, 'udieresis'), @(0xBF, 'questiondown'),
                 @(32, 'space'), @(46, 'period'), @(44, 'comma'), @(58, 'colon'), @(59, 'semicolon'), @(36, 'dollar'), @(45, 'hyphen'),
                 @(40, 'parenleft'), @(41, 'parenright'), @(63, 'question'), @(37, 'percent'), @(48, 'zero'), @(49, 'one'), @(50, 'two'),
                 @(51, 'three'), @(52, 'four'), @(53, 'five'), @(54, 'six'), @(55, 'seven'), @(56, 'eight'), @(57, 'nine'))) {
    $script:PdfNombres[[string][char]$p[0]] = $p[1]
}
function New-AIPdfPrueba {
    param([string]$Ruta, $Paginas, [switch]$Comprimir, [switch]$ObjStm, [switch]$SinToUnicode, [switch]$Cifrado, [switch]$Imagen)
    $cid = New-Object 'System.Collections.Generic.Dictionary[string,int]'   # letra -> codigo, tipo C
    $dif = New-Object 'System.Collections.Generic.Dictionary[string,int]'   # y tipo D
    $sbC = { param($ch) if (-not $cid.ContainsKey($ch)) { $cid[$ch] = 3 + $cid.Count }; $cid[$ch] }
    $sbD = { param($ch) if (-not $dif.ContainsKey($ch)) { $dif[$ch] = 1 + $dif.Count }; $dif[$ch] }
    $cifra = {
        param($t, $f, $kern)
        $palabras = @(if ($kern) { $t -split ' ' } else { $t })
        $partes = foreach ($w in $palabras) {
            switch ($f) {
                'C' { '<' + ((@($w.ToCharArray() | ForEach-Object { '{0:X4}' -f (& $sbC ([string]$_)) })) -join '') + '>' }
                'D' { '<' + ((@($w.ToCharArray() | ForEach-Object { '{0:X2}' -f (& $sbD ([string]$_)) })) -join '') + '>' }
                default { ConvertTo-PdfCadena $w }
            }
        }
        if ($kern) { '[' + ($partes -join ' -300 ') + '] TJ' } else { "$partes Tj" }
    }
    # El contenido de cada pagina.
    $contenidos = foreach ($pag in $Paginas) {
        $sb = New-Object System.Text.StringBuilder
        if ($Imagen) { [void]$sb.Append("q 400 0 0 500 100 200 cm /Im1 Do Q`n") }
        else {
            [void]$sb.Append("BT`n")
            $y = 780.0
            foreach ($l in $pag) {
                $tam = if ($l.Tam) { [double]$l.Tam } else { 11.0 }
                $y -= $tam * 1.3 + [double]$l.Hueco
                $f = if ($l.F) { $l.F } else { 'R' }
                $fn = @{ R = 'F1'; B = 'F2'; C = 'F3'; D = 'F4' }[$f]
                $celdas = @(if ($l.Celdas) { $l.Celdas } else { $l.T })
                $xs = @(if ($l.X) { $l.X } else { 72 })
                for ($i = 0; $i -lt $celdas.Count; $i++) {
                    $x = if ($i -lt $xs.Count) { $xs[$i] } else { 72 + 150 * $i }
                    [void]$sb.Append("/$fn $tam Tf 1 0 0 1 $x $($y.ToString([Globalization.CultureInfo]::InvariantCulture)) Tm ")
                    [void]$sb.Append((& $cifra $celdas[$i] $f ([bool]$l.Kern))).Append("`n")
                }
            }
            [void]$sb.Append("ET`n")
        }
        $sb.ToString()
    }
    $contenidos = @($contenidos)
    # Los objetos: @{ N; Dic; Datos }. Los numeros van fijos.
    $objs = New-Object 'System.Collections.Generic.List[object]'
    $nPag = @($Paginas).Count
    $primera = 20
    $kids = (0..($nPag - 1) | ForEach-Object { "$($primera + 2 * $_) 0 R" }) -join ' '
    $objs.Add(@{ N = 1; Dic = '<< /Type /Catalog /Pages 2 0 R >>' })
    $objs.Add(@{ N = 2; Dic = "<< /Type /Pages /Kids [$kids] /Count $nPag /Resources << /Font << /F1 3 0 R /F2 4 0 R /F3 5 0 R /F4 8 0 R >> /XObject << /Im1 9 0 R >> >> >>" })
    $objs.Add(@{ N = 3; Dic = '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>' })
    $objs.Add(@{ N = 4; Dic = '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>' })
    for ($i = 0; $i -lt $nPag; $i++) {
        $objs.Add(@{ N = $primera + 2 * $i; Dic = "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents $($primera + 2 * $i + 1) 0 R >>" })
        $objs.Add(@{ N = $primera + 2 * $i + 1; Dic = '<< >>'; Datos = $contenidos[$i] })
    }
    # Tipo C: Type0 con su tabla ToUnicode (codigos inventados, como un
    # tipo de letra recortado). Tipo D: Times con /Differences.
    $tu = New-Object System.Text.StringBuilder
    [void]$tu.Append("/CIDInit /ProcSet findresource begin 12 dict begin begincmap /CMapName /Prueba def 1 begincodespacerange <0000> <FFFF> endcodespacerange`n")
    [void]$tu.Append("$($cid.Count) beginbfchar`n")
    foreach ($k in $cid.Keys) { [void]$tu.Append(('<{0:X4}> <{1:X4}>' -f $cid[$k], [int][char]$k)).Append("`n") }
    [void]$tu.Append("endbfchar endcmap CMapName currentdict /CMap defineresource pop end end")
    $toU = if ($SinToUnicode) { '' } else { ' /ToUnicode 7 0 R' }
    $objs.Add(@{ N = 5; Dic = "<< /Type /Font /Subtype /Type0 /BaseFont /ABCDEF+Arial /Encoding /Identity-H /DescendantFonts [6 0 R]$toU >>" })
    $objs.Add(@{ N = 6; Dic = '<< /Type /Font /Subtype /CIDFontType2 /BaseFont /ABCDEF+Arial /CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> /DW 500 /W [3 [600 550] 10 20 520] >>' })
    $objs.Add(@{ N = 7; Dic = '<< >>'; Datos = $tu.ToString() })
    $difs = (@($dif.Keys | Sort-Object { $dif[$_] } | ForEach-Object { if ($script:PdfNombres.ContainsKey($_)) { '/' + $script:PdfNombres[$_] } else { '/' + $_ } })) -join ' '
    $anchosD = (@(1..[Math]::Max(1, $dif.Count) | ForEach-Object { 500 })) -join ' '
    $objs.Add(@{ N = 8; Dic = "<< /Type /Font /Subtype /Type1 /BaseFont /Times-Roman /FirstChar 1 /LastChar $([Math]::Max(1, $dif.Count)) /Widths [$anchosD] /Encoding << /Type /Encoding /Differences [1 $difs] >> >>" })
    $objs.Add(@{ N = 9; Dic = '<< /Type /XObject /Subtype /Image /Width 2 /Height 2 /ColorSpace /DeviceGray /BitsPerComponent 8 >>'; Datos = ([string][char]0 + [char]255 + [char]255 + [char]0) })
    if ($Cifrado) { $objs.Add(@{ N = 10; Dic = '<< /Filter /Standard /V 1 /R 2 /O <00> /U <00> /P -4 >>' }) }

    # Escribir: cabecera, objetos (o un stream de objetos) y la tabla xref.
    $out = New-Object System.Text.StringBuilder
    [void]$out.Append("%PDF-1.5`n%" + [char]0xE2 + [char]0xE3 + [char]0xCF + [char]0xD3 + "`n")
    $pos = @{}; $enStm = @{}
    $escribe = {
        param($o)
        $pos[$o.N] = $out.Length
        if ($null -ne $o.Datos) {
            $d = $o.Datos; $filtro = ''
            if ($Comprimir) { $d = ConvertTo-PdfZlib $d; $filtro = ' /Filter /FlateDecode' }
            $dic = $o.Dic.Substring(0, $o.Dic.Length - 2).TrimEnd() + " /Length $($d.Length)$filtro >>"
            [void]$out.Append("$($o.N) 0 obj`n$dic`nstream`n").Append($d).Append("`nendstream`nendobj`n")
        } else { [void]$out.Append("$($o.N) 0 obj`n$($o.Dic)`nendobj`n") }
    }
    $sueltos = @($objs | Where-Object { $null -ne $_.Datos -or -not $ObjStm -or $_.N -eq 10 })
    $dentro = @($objs | Where-Object { $null -eq $_.Datos -and $ObjStm -and $_.N -ne 10 })
    foreach ($o in $sueltos) { & $escribe $o }
    $max = (@($objs | ForEach-Object { $_.N }) | Measure-Object -Maximum).Maximum
    if ($ObjStm) {
        $nStm = $max + 1; $nXref = $max + 2
        $cab = New-Object System.Text.StringBuilder; $cuerpo = New-Object System.Text.StringBuilder
        $k = 0
        foreach ($o in $dentro) { [void]$cab.Append("$($o.N) $($cuerpo.Length) "); [void]$cuerpo.Append($o.Dic).Append("`n"); $enStm[$o.N] = @($nStm, $k); $k++ }
        $h = $cab.ToString()
        & $escribe @{ N = $nStm; Dic = "<< /Type /ObjStm /N $($dentro.Count) /First $($h.Length) >>"; Datos = $h + $cuerpo.ToString() }
        # La tabla xref en un stream: tipo (1), desplazamiento (4), generacion o indice (2).
        $pos[$nXref] = $out.Length
        $filas = New-Object System.Text.StringBuilder
        for ($n = 0; $n -le $nXref; $n++) {
            if ($enStm.ContainsKey($n)) { $t = 2; $a = $enStm[$n][0]; $b = $enStm[$n][1] }
            elseif ($pos.ContainsKey($n)) { $t = 1; $a = $pos[$n]; $b = 0 }
            else { $t = 0; $a = 0; $b = $(if ($n -eq 0) { 65535 } else { 0 }) }
            [void]$filas.Append([char]$t)
            foreach ($sh in 24, 16, 8, 0) { [void]$filas.Append([char](($a -shr $sh) -band 255)) }
            [void]$filas.Append([char](($b -shr 8) -band 255)).Append([char]($b -band 255))
        }
        $f = $filas.ToString()
        $enc = if ($Cifrado) { ' /Encrypt 10 0 R' } else { '' }
        [void]$out.Append("$nXref 0 obj`n<< /Type /XRef /Size $($nXref + 1) /W [1 4 2] /Root 1 0 R$enc /Length $($f.Length) >>`nstream`n").Append($f).Append("`nendstream`nendobj`n")
        [void]$out.Append("startxref`n$($pos[$nXref])`n%%EOF`n")
    } else {
        $xref = $out.Length
        [void]$out.Append("xref`n0 $($max + 1)`n0000000000 65535 f `n")
        for ($n = 1; $n -le $max; $n++) {
            if ($pos.ContainsKey($n)) { [void]$out.Append(('{0:D10} 00000 n ' -f $pos[$n])).Append("`n") } else { [void]$out.Append("0000000000 00000 f `n") }
        }
        $enc = if ($Cifrado) { ' /Encrypt 10 0 R' } else { '' }
        [void]$out.Append("trailer`n<< /Size $($max + 1) /Root 1 0 R$enc >>`nstartxref`n$xref`n%%EOF`n")
    }
    $dir = Split-Path -Parent $Ruta
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [IO.File]::WriteAllBytes($Ruta, $script:PdfL1.GetBytes($out.ToString()))
}
