#requires -Version 5.1
# Documentos sin modelo: los lectores de cada formato, los fragmentos, el
# indice (lo que se relee y lo que no), la busqueda (que encuentre y que no
# salte cuando la pregunta no va de los documentos) y la peticion
# conversada. Los documentos son de un negocio inventado y se crean en una
# carpeta temporal (con espacios y acentos en la ruta): en el repositorio no
# hay ficheros binarios.
#   -Crear <carpeta>: solo crea el negocio inventado en <carpeta> (para
#   probarlo a mano o con el modelo) y sale.
param([string]$Raiz = (Split-Path -Parent $PSScriptRoot), [string]$Crear)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$root = $Raiz
. (Join-Path $root 'lib\providers.ps1')
. (Join-Path $root 'lib\web.ps1')
. (Join-Path $root 'lib\equipo.ps1')
. (Join-Path $root 'lib\documentos.ps1')
Add-Type -AssemblyName System.IO.Compression

$mal = 0
function Ver([string]$que, [bool]$ok, $extra = '') { if ($ok) { Write-Output "  ok   $que" } else { $script:mal++; Write-Output "  MAL  $que  $extra" } }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('docs prueba ' + [char]0xF1 + ' ' + [Guid]::NewGuid().ToString('N').Substring(0, 6))
$neg = Join-Path $tmp ('Ferreter' + [char]0xED + 'a El Tornillo')
if ($Crear) { $tmp = $Crear; $neg = Join-Path $Crear ('Ferreter' + [char]0xED + 'a El Tornillo') }
$cache = Join-Path $tmp 'cache'
New-Item -ItemType Directory -Path (Join-Path $neg 'politicas'), (Join-Path $neg '.oculta'), $cache -Force | Out-Null
$utf8 = New-Object Text.UTF8Encoding $false
function Escribe($nombre, $texto) { [IO.File]::WriteAllText((Join-Path $neg $nombre), $texto, $utf8) }
function Zip($nombre, $entradas) {
    $fs = [IO.File]::Create((Join-Path $neg $nombre))
    $z = New-Object IO.Compression.ZipArchive($fs, [IO.Compression.ZipArchiveMode]::Create)
    foreach ($k in $entradas.Keys) {
        $w = New-Object IO.StreamWriter($z.CreateEntry($k).Open(), $utf8)
        $w.Write($entradas[$k]); $w.Dispose()
    }
    $z.Dispose(); $fs.Dispose()
}

# ---- El negocio inventado ---------------------------------------------------
Escribe 'leeme.md' @'
# Ferretería El Tornillo
Ferretería de barrio fundada en 2015. Vendemos herramientas, pintura, material eléctrico y de fontanería.

## Horario de atención
- Lunes a viernes: 7:30 a 17:30
- Sábados: 8:00 a 12:00
- Domingos y feriados: cerrado

## Contacto
Teléfono: 2222-0000
Correo: ventas@eltornillo.example
'@
# En Windows-1252, como el Bloc de notas de antes.
[IO.File]::WriteAllBytes((Join-Path $neg 'politicas\devoluciones.txt'), [Text.Encoding]::GetEncoding(1252).GetBytes(@'
POLÍTICA DE DEVOLUCIONES
El cliente puede devolver un producto en los 15 días siguientes a la compra, siempre con la factura.
No se aceptan devoluciones de pintura preparada ni de cable cortado a la medida.
El reembolso se hace por el mismo medio de pago.
'@))
Escribe 'empleados.csv' "Nombre;Cargo;Turno;Ingreso`nAna Pérez;Gerente;Mañana;2015-03-01`nLuis Mora;Cajero;Tarde;2021-06-15`nMarta Ruiz;Bodega;Mañana;2019-01-10`n"
Zip 'procedimientos.docx' ([ordered]@{ 'word/document.xml' = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>
<w:p><w:pPr><w:pStyle w:val="Ttulo1"/></w:pPr><w:r><w:t>Procedimientos internos</w:t></w:r></w:p>
<w:p><w:pPr><w:pStyle w:val="Ttulo2"/></w:pPr><w:r><w:t>Apertura de la tienda</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t xml:space="preserve">Desactivar la alarma </w:t></w:r><w:r><w:t>con el código del encargado.</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>Contar el fondo de caja: C$ 2,000.</w:t></w:r></w:p>
<w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr><w:r><w:t>Cierre de caja</w:t></w:r></w:p>
<w:p><w:r><w:t>El cajero cuenta el efectivo y lo entrega al gerente antes de las 17:45.</w:t></w:r><w:del w:id="1" w:author="x"><w:r><w:delText>SECRETO BORRADO</w:delText></w:r></w:del><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> PAGE </w:instrText></w:r></w:p>
<w:tbl><w:tblPr/><w:tr><w:tc><w:tcPr/><w:p><w:r><w:t>Día</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Responsable del cierre</w:t></w:r></w:p></w:tc></w:tr>
<w:tr><w:tc><w:p><w:r><w:t>Lunes</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Luis Mora</w:t></w:r></w:p></w:tc></w:tr>
<w:tr><w:tc><w:p><w:r><w:t>Sábado</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Ana Pérez &amp; Marta</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
<w:p/><w:sectPr/></w:body></w:document>
'@ })
Zip 'precios.xlsx' ([ordered]@{
    'xl/workbook.xml' = '<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Servicios" sheetId="1" r:id="rId1"/><sheet name="Horario bodega" sheetId="2" r:id="rId2"/></sheets></workbook>'
    'xl/_rels/workbook.xml.rels' = '<Relationships><Relationship Id="rId1" Type="w" Target="worksheets/sheet1.xml"/><Relationship Target="/xl/worksheets/sheet2.xml" Type="w" Id="rId2"/></Relationships>'
    'xl/sharedStrings.xml' = '<sst><si><t>Servicio</t></si><si><t>Precio</t></si><si><t>Desde</t></si><si><r><rPr><b/></rPr><t xml:space="preserve">Corte </t></r><r><t>de llaves</t></r></si><si><t>Mezcla de pintura</t></si><si><t>Día</t></si><si><t>Abre</t></si><si><t>Cierra</t></si><si><t>Lunes a viernes</t></si><si><t>Sábado</t></si><si><t>Entrega a domicilio</t></si></sst>'
    'xl/styles.xml' = '<styleSheet><numFmts count="1"><numFmt numFmtId="164" formatCode="dd/mm/yyyy"/></numFmts><cellXfs count="4"><xf numFmtId="0"/><xf numFmtId="164" applyNumberFormat="1"/><xf numFmtId="20"/><xf numFmtId="9"/></cellXfs></styleSheet>'
    'xl/worksheets/sheet1.xml' = '<worksheet><sheetData><row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="C1" t="s"><v>2</v></c><c r="D1" t="inlineStr"><is><t>Descuento</t></is></c></row><row r="2"><c r="A2" t="s"><v>3</v></c><c r="B2"><v>50</v></c><c r="C2" s="1"><v>45971</v></c><c r="D2" s="3"><v>0.1</v></c></row><row r="3"><c r="A3" t="s"><v>4</v></c><c r="B3"><v>120.5</v></c></row><row r="4"><c r="A4" t="s"><v>10</v></c><c r="B4"><v>80</v></c><c r="C4" s="1"><v>45972</v></c></row><row r="5"/></sheetData></worksheet>'
    'xl/worksheets/sheet2.xml' = '<worksheet><sheetData><row r="1"><c r="A1" t="s"><v>5</v></c><c r="B1" t="s"><v>6</v></c><c r="C1" t="s"><v>7</v></c></row><row r="2"><c r="A2" t="s"><v>8</v></c><c r="B2" s="2"><v>0.3125</v></c><c r="C2" s="2"><v>0.72916666666666663</v></c></row><row r="3"><c r="A3" t="s"><v>9</v></c><c r="B3" s="2"><v>0.33333333333333331</v></c><c r="C3" s="2"><v>0.5</v></c></row></sheetData></worksheet>'
})
$diapo = '<p:sld xmlns:p="p" xmlns:a="a"><p:cSld><p:spTree><p:sp><p:txBody>{0}</p:txBody></p:sp></p:spTree></p:cSld></p:sld>'
Zip 'capacitacion.pptx' ([ordered]@{
    'ppt/slides/slide10.xml' = ($diapo -f '<a:p><a:r><a:t>Seguridad</a:t></a:r></a:p><a:p><a:r><a:t>Usar guantes al cortar vidrio.</a:t></a:r></a:p>')
    'ppt/slides/slide2.xml'  = ($diapo -f '<a:p><a:r><a:t>Bienvenida al equipo</a:t></a:r></a:p><a:p><a:r><a:t>Uniforme: camisa roja con el logo de la tienda.</a:t></a:r></a:p>')
})
Zip 'reglamento.odt' ([ordered]@{ 'content.xml' = '<office:document-content><office:body><office:text><text:h text:outline-level="1">Reglamento interno</text:h><text:p>Se prohíbe fumar dentro de la tienda.</text:p><text:h text:outline-level="2">Vacaciones</text:h><text:p>Cada empleado tiene 15 días hábiles<text:s/>de vacaciones por año trabajado, pedidas con un mes de anticipación.</text:p><table:table table:name="T1"><table:table-row><table:table-cell><text:p>Falta</text:p></table:table-cell><table:table-cell><text:p>Sanción</text:p></table:table-cell></table:table-row><table:table-row><table:table-cell><text:p>Llegada tarde</text:p></table:table-cell><table:table-cell><text:p>Llamada de atención</text:p></table:table-cell></table:table-row></table:table></office:text></office:body></office:document-content>' })
Zip 'inventario.ods' ([ordered]@{ 'content.xml' = '<office:document-content><office:body><office:spreadsheet><table:table table:name="Inventario"><table:table-row><table:table-cell><text:p>Producto</text:p></table:table-cell><table:table-cell><text:p>Existencias</text:p></table:table-cell><table:table-cell table:number-columns-repeated="1000"/></table:table-row><table:table-row><table:table-cell><text:p>Martillo</text:p></table:table-cell><table:table-cell office:value-type="float" office:value="12"><text:p>12</text:p></table:table-cell></table:table-row><table:table-row table:number-rows-repeated="1048000"><table:table-cell table:number-columns-repeated="1024"/></table:table-row></table:table></office:spreadsheet></office:body></office:document-content>' })
[IO.File]::WriteAllText((Join-Path $neg 'anuncio.rtf'), '{\rtf1\ansi\deff0{\fonttbl{\f0 Arial;}}{\*\generator Prueba;}{\pict\pngblip 89504e470d0a}\f0\fs24 Promoci\''f3n de noviembre: 10% de descuento en pintura.\par V\''e1lida hasta el 30 de noviembre \{sin excepciones\}.\par}', [Text.Encoding]::ASCII)
Escribe 'proveedores.html' '<html><head><title>Proveedores</title><script>var proveedor = "dato falso";</script></head><body><h1>Proveedores</h1><p>El proveedor de pintura es Pinturas del Lago; los pedidos se hacen los martes.</p></body></html>'
Escribe 'catalogo.pdf' '%PDF-1.4 no es un pdf de verdad'
Escribe 'foto.jpg' 'no es una foto'
Escribe '~$procedimientos.docx' 'temporal de Word'
Escribe '.oculta\secreto.txt' 'no se lee'
Escribe 'dañado.docx' 'esto no es un zip'

if ($Crear) { Write-Output $neg; exit 0 }

# ---- Lectores -------------------------------------------------------------------
Write-Output '--- lectores'
$t = (Read-AIDocTexto (Join-Path $neg 'politicas\devoluciones.txt')).Texto
Ver 'texto en Windows-1252' ($t -match ('POL' + [char]0xCD + 'TICA') -and $t -match ('15 d' + [char]0xED + 'as'))
$t = (Read-AIDocTexto (Join-Path $neg 'empleados.csv')).Texto
Ver 'CSV con punto y coma, con cabecera' ($t -match 'Nombre: Luis Mora \| Cargo: Cajero \| Turno: Tarde \| Ingreso: 2021-06-15') $t
$t = (Read-AIDocTexto (Join-Path $neg 'procedimientos.docx')).Texto
Ver 'Word: titulos' ($t -match '(?m)^# Procedimientos internos$' -and $t -match '(?m)^## Apertura de la tienda$' -and $t -match '(?m)^## Cierre de caja$') $t
Ver 'Word: listas y trozos de una misma frase' ($t -match ('(?m)^- Desactivar la alarma con el c' + [char]0xF3 + 'digo del encargado\.$'))
Ver 'Word: sin texto borrado ni codigos de campo' ($t -notmatch 'SECRETO|PAGE')
Ver 'Word: tabla sin cifras -> columnas aparte' ($t -match 'Columnas \(primera fila\): D.a \| Responsable del cierre' -and $t -match ('(?m)^S' + [char]0xE1 + 'bado \| Ana P' + [char]0xE9 + 'rez & Marta$')) $t
$t = (Read-AIDocTexto (Join-Path $neg 'precios.xlsx')).Texto
Ver 'Excel: hojas por nombre' ($t -match '## Hoja: Servicios' -and $t -match '## Hoja: Horario bodega') $t
Ver 'Excel: texto con formato, fecha y porcentaje' ($t -match 'Servicio: Corte de llaves \| Precio: 50 \| Desde: 10/11/2025 \| Descuento: 10%') $t
Ver 'Excel: decimales y celdas vacias' ($t -match '(?m)^Servicio: Mezcla de pintura \| Precio: 120\.5$')
Ver 'Excel: horas (0.3125 son las 07:30)' ($t -match 'Abre: 07:30 \| Cierra: 17:30' -and $t -match 'Abre: 08:00 \| Cierra: 12:00') $t
$t = (Read-AIDocTexto (Join-Path $neg 'capacitacion.pptx')).Texto
Ver 'PowerPoint: diapositivas en orden (2 antes que 10)' ($t.IndexOf('Bienvenida') -ge 0 -and $t.IndexOf('Bienvenida') -lt $t.IndexOf('Seguridad')) $t
$t = (Read-AIDocTexto (Join-Path $neg 'reglamento.odt')).Texto
Ver 'OpenDocument texto: titulos, espacios y tabla' ($t -match '(?m)^## Vacaciones$' -and $t -match 'h.biles de vacaciones' -and $t -match 'Llegada tarde \| Llamada de atenci') $t
$t = (Read-AIDocTexto (Join-Path $neg 'inventario.ods')).Texto
Ver 'OpenDocument hoja: sin las mil columnas vacias' ($t -match '## Hoja: Inventario' -and $t -match 'Producto: Martillo \| Existencias: 12' -and $t.Length -lt 200) $t
$t = (Read-AIDocTexto (Join-Path $neg 'anuncio.rtf')).Texto
Ver 'RTF: acentos, llaves y sin imagen' ($t -match ('Promoci' + [char]0xF3 + 'n de noviembre') -and $t -match ('V' + [char]0xE1 + 'lida') -and $t -match '\{sin excepciones\}' -and $t -notmatch '89504e|Arial|Prueba') $t
$t = (Read-AIDocTexto (Join-Path $neg 'proveedores.html')).Texto
Ver 'HTML: sin el codigo de la pagina' ($t -match 'Pinturas del Lago' -and $t -notmatch 'dato falso') $t
$r = Read-AIDocTexto (Join-Path $neg 'catalogo.pdf')
Ver 'PDF: no se lee y se dice que hacer' (-not $r.Ok -and $r.Motivo -match 'PDF' -and $r.Motivo -match 'docx')
$r = Read-AIDocTexto (Join-Path $neg 'dañado.docx')
Ver 'Word danado: no se lee, con motivo' (-not $r.Ok -and $r.Motivo -match 'no se pudo leer') $r.Motivo

# ---- Fragmentos -----------------------------------------------------------------
Write-Output '--- fragmentos'
$ts = Split-AIDocTrozos ("# Manual`n## Caja`n" + ((1..40 | ForEach-Object { "Paso $_ del cierre de caja, contado con cuidado." }) -join "`n"))
Ver 'un texto largo se parte' ($ts.Count -ge 2 -and @($ts | Where-Object { $_.Texto.Length -gt $AI_DOC_TROZO }).Count -eq 0) $ts.Count
Ver 'cada fragmento con su apartado' (@($ts | Where-Object { $_.Seccion -ne 'Manual > Caja' }).Count -eq 0)
$filas = "Columnas (primera fila): Nombre | Correo`n" + ((1..40 | ForEach-Object { "Persona $_ | persona$_@x.example" }) -join "`n")
$ts = Split-AIDocTrozos $filas
Ver 'una tabla partida repite sus columnas' ($ts.Count -ge 2 -and @($ts | Where-Object { -not $_.Texto.StartsWith('Columnas (primera fila): Nombre | Correo') }).Count -eq 0)
$ts = Split-AIDocTrozos "TEXTO PLANO`nHORARIO`nAbrimos a las 8."
Ver 'titulos en mayusculas en texto plano' ($ts[0].Seccion -eq 'HORARIO' -and $ts[0].Texto -eq 'Abrimos a las 8.') ($ts | Out-String)
$a = (ConvertTo-AIDocTerminos 'horarios empleadas vacaciones') -join ' '
$b = (ConvertTo-AIDocTerminos 'horario empleado vacación') -join ' '
Ver 'plurales, genero y acentos dan la misma raiz' ($a -eq $b) "$a / $b"
$a = (ConvertTo-AIDocTerminos 'vendemos cierran almacenes talleres') -join ' '
$b = (ConvertTo-AIDocTerminos 'venden cierre almacén taller') -join ' '
Ver 'y las formas verbales' ($a -eq $b) "$a / $b"
$a = (ConvertTo-AIDocTerminos 'joven orden mes') -join ' '
Ver 'sin dejar raices de menos de cuatro letras' ($a -eq 'joven orden mes') $a

# ---- Indice --------------------------------------------------------------------
Write-Output '--- indice'
$carpetas = @([pscustomobject]@{ Nombre = 'ferreteria'; Ruta = $neg; Tema = 'la ferretería El Tornillo'; Creado = '2026-11-17' })
$avisos = New-Object System.Collections.Generic.List[string]
$e = Update-AIDocIndice $carpetas $cache { param($t) $avisos.Add($t) } $null
$ok = @($e.Ficheros | Where-Object { $_.Estado -eq 'ok' })
$no = @($e.Ficheros | Where-Object { $_.Estado -ne 'ok' })
Ver 'lee los diez documentos' ($ok.Count -eq 10) (@($ok | ForEach-Object { $_.Fichero }) -join ', ')
Ver 'el PDF y el danado, con su motivo' ($no.Count -eq 2 -and @($no | Where-Object { -not $_.Motivo }).Count -eq 0) (@($no | ForEach-Object { "$($_.Fichero): $($_.Motivo)" }) -join ' / ')
Ver 'la foto cuenta como otro; el temporal y lo oculto, ni eso' ($e.Otros -eq 1 -and @($e.Ficheros | Where-Object { $_.Fichero -match '^~|oculta' }).Count -eq 0) $e.Otros
Ver 'avisa de lo que va leyendo' ($avisos.Count -eq 12) $avisos.Count
Ver 'ruta relativa dentro de la carpeta' (@($ok | Where-Object { $_.Fichero -eq 'politicas\devoluciones.txt' }).Count -eq 1)
Write-Output "    $($e.Indice.N) fragmentos en $($e.Segundos) s"
$e2 = Update-AIDocIndice $carpetas $cache $null $e
Ver 'la segunda vez no relee nada y reusa el indice' ($e2.Nuevos -eq 0 -and $e2.Reusados -eq 12 -and [object]::ReferenceEquals($e2, $e))
$e3 = Update-AIDocIndice $carpetas $cache $null $null
Ver 'arrancando de cero, sale de lo ya leido y del indice guardado' ($e3.Nuevos -eq 0 -and $e3.Indice.N -eq $e.Indice.N -and $e3.Indice.Cargado -and -not $e.Indice.Cargado -and $e3.Indice.Corpus -eq $e.Indice.Corpus -and ($e3.Indice.Texto -join '|') -eq ($e.Indice.Texto -join '|'))
Start-Sleep -Milliseconds 50
Escribe 'leeme.md' (([IO.File]::ReadAllText((Join-Path $neg 'leeme.md'))) + "`n## Estacionamiento`nHay parqueo para cuatro carros frente a la tienda.`n")
Escribe 'nuevo.txt' 'Las capacitaciones son el primer lunes de cada mes.'
Remove-Item -LiteralPath (Join-Path $neg 'foto.jpg')
$e4 = Update-AIDocIndice $carpetas $cache $null $e
Ver 'un fichero cambiado y uno nuevo: solo se leen esos dos' ($e4.Nuevos -eq 2 -and $e4.Reusados -eq 11 -and -not [object]::ReferenceEquals($e4, $e)) "$($e4.Nuevos) / $($e4.Reusados)"
Ver 'y lo nuevo se encuentra' ((Find-AIDocTrozos $e4.Indice 'hay parqueo?').Trozos[0].Texto -match 'cuatro carros')
Remove-Item -LiteralPath (Join-Path $neg 'nuevo.txt')
$e5 = Update-AIDocIndice $carpetas $cache $null $e4
Ver 'un fichero borrado se olvida' (@($e5.Ficheros | Where-Object { $_.Fichero -eq 'nuevo.txt' }).Count -eq 0 -and @(Get-ChildItem (Join-Path $cache 'textos')).Count -eq 10)
$falta = @($carpetas) + @([pscustomobject]@{ Nombre = 'usb'; Ruta = 'Z:\no\existe'; Tema = ''; Creado = '' })
$e6 = Update-AIDocIndice $falta $cache $null $null
Ver 'una carpeta que no esta se dice' ($e6.NoEncontradas -contains 'Z:\no\existe' -and @($e6.Ficheros | Where-Object { $_.Estado -eq 'ok' }).Count -eq 10)
$ix = $e5.Indice

# ---- Busqueda -------------------------------------------------------------------
Write-Output '--- busqueda'
function Busca($pregunta, $fichero, $dice, $previa = '') {
    # Lo que cuenta es lo que le llega al modelo: el fragmento bueno tiene que
    # ir entre los que viajan, no hace falta que sea el primero.
    $h = Find-AIDocTrozos $ix $pregunta $previa
    $k = 0; $pos = 0
    foreach ($t in @($h.Trozos)) { $k++; if (-not $pos -and $t.Fichero -eq $fichero -and $t.Texto -match $dice) { $pos = $k } }
    $todos = (@($h.Trozos | ForEach-Object { $_.Fichero }) -join ', ')
    Ver ("{0,-48} -> {1} ({2}.)" -f $pregunta, $fichero, $pos) ($h.Relevante -and $pos -gt 0) "relevante=$($h.Relevante) cob=$($h.Cobertura) llegan: $todos"
}
Busca '¿A qué hora abren los sábados?' 'leeme.md' 'S.bados: 8:00 a 12:00'
Busca '¿Puedo devolver algo sin la factura?' 'politicas\devoluciones.txt' 'factura'
Busca '¿Quién es la gerente?' 'empleados.csv' 'Cargo: Gerente'
Busca '¿Cuánto cuesta el corte de llaves?' 'precios.xlsx' 'Corte de llaves \| Precio: 50'
Busca '¿Qué hay que hacer al cerrar la caja?' 'procedimientos.docx' 'cuenta el efectivo'
Busca '¿De qué color es el uniforme?' 'capacitacion.pptx' 'camisa roja'
Busca '¿Cuántos días de vacaciones tengo?' 'reglamento.odt' '15 d.as h.biles'
Busca '¿Hay alguna promoción en pintura?' 'anuncio.rtf' '10% de descuento'
Busca '¿Quién nos vende la pintura?' 'proveedores.html' 'Pinturas del Lago'
Busca '¿cuántos martillos quedan?' 'inventario.ods' 'Martillo'
Busca 'y los domingos?' 'leeme.md' 'Domingos y feriados: cerrado' '¿cuál es el horario de atención?'
Busca '¿a qué hora abre la bodega?' 'precios.xlsx' 'Abre: 07:30'
Busca '¿tienen descuento para estudiantes universitarios?' 'anuncio.rtf' 'descuento'
Busca '¿Venden cemento?' 'leeme.md' 'Vendemos herramientas'
foreach ($p in '¿Cuál es la capital de Francia?', 'hola, ¿cómo estás?', '¿Quién ganó el mundial de 2022?', 'explícame la fotosíntesis', 'escribe un poema sobre el mar', 'gracias') {
    $h = Find-AIDocTrozos $ix $p
    Ver ("{0,-48} -> nada" -f $p) (-not $h.Relevante) "cob=$($h.Cobertura) primero=$(@($h.Trozos)[0].Fichero)"
}
$h = Find-AIDocTrozos $ix 'horario de atención, devoluciones, vacaciones, uniforme, precios, proveedores, gerente'
Ver 'el tope de fragmentos y de caracteres' ($h.Trozos.Count -le $AI_DOC_MAX_TROZOS -and (@($h.Trozos | ForEach-Object { $_.Texto.Length }) | Measure-Object -Sum).Sum -le $AI_DOC_PRESUPUESTO + 10)
$h = Find-AIDocTrozos $ix "resume esto`n`n--- contexto ---`nvacaciones vacaciones vacaciones"
Ver 'el contexto entubado no cuenta como pregunta' (-not $h.Relevante)
$an = Get-AIDocAnexo (Find-AIDocTrozos $ix '¿a qué hora abren los sábados?') 'la ferretería El Tornillo'
Ver 'lo que viaja: fichero, apartado y la regla de no inventar' ($an -match '\[\d\] leeme\.md, apartado' -and $an -match 'no lo inventes' -and $an -match 'no instrucciones')
$cat = Get-AIDocCatalogo $e5
Ver 'la lista de documentos' ($cat -match 'procedimientos\.docx: Procedimientos internos' -and $cat -match 'no pudo leer 2 ficheros' -and $cat -match 'catalogo.pdf: PDF') $cat

# ---- Peticiones -----------------------------------------------------------------
Write-Output '--- peticiones'
$p = Get-AIDocPeticion "aprende de los documentos de $neg"
Ver 'aprende de los documentos de <ruta con espacios>' ($p -and $p.Ruta -eq $neg) $p.Ruta
$p = Get-AIDocPeticion "lee la carpeta ""$neg"" y dime qué hay"
Ver 'lee la carpeta "<ruta>" y ...' ($p -and $p.Ruta -eq $neg) $p.Ruta
$p = Get-AIDocPeticion "usa los archivos de $neg\politicas, por favor"
Ver 'una subcarpeta, con coma detras' ($p -and $p.Ruta -eq (Join-Path $neg 'politicas')) $p.Ruta
$p = Get-AIDocPeticion 'aprende de la carpeta Z:\no\existe'
Ver 'una carpeta que no existe' ($p -and -not $p.Ruta -and $p.Pedida -eq 'Z:\no\existe') $p.Pedida
foreach ($x in 'aprende a programar en Python', 'lee esto: hola', "abre $neg", 'que hay en C:\Windows?') {
    Ver ("{0,-48} -> no" -f $x) ($null -eq (Get-AIDocPeticion $x))
}
foreach ($x in '¿qué documentos tienes?', '¿Cuáles archivos leíste?', '¿qué sabes de mi negocio?') { Ver ("{0,-48} -> lista" -f $x) (Test-AIDocCatalogoPedido $x) }
foreach ($x in '¿qué dice el documento de vacaciones?', '¿a qué hora abren?') { Ver ("{0,-48} -> no lista" -f $x) (-not (Test-AIDocCatalogoPedido $x)) }
foreach ($x in '¿Qué hora es?', 'que horas son', '¿qué día es hoy?', 'y que fecha es') { Ver ("{0,-48} -> reloj" -f $x) (Test-AIDocReloj $x) }
foreach ($x in '¿a qué hora abren?', '¿qué día cierran?', '¿qué hora es la del cierre de caja?') { Ver ("{0,-48} -> no reloj" -f $x) (-not (Test-AIDocReloj $x)) }

# ---- Olvidar ------------------------------------------------------------------
Write-Output '--- olvidar'
$o = Find-AIDocOlvido $e5 'empleados'
Ver 'olvidar "empleados" -> el documento empleados.csv' ($o.Tipo -eq 'fichero' -and $o.Reglas[0].Fichero -eq 'empleados.csv' -and $o.Trozos -ge 1) $o.Que
$o = Find-AIDocOlvido $e5 'ferreteria'
Ver 'olvidar "ferreteria" -> la carpeta' ($o.Tipo -eq 'carpeta' -and $o.Carpeta -eq 'ferreteria') $o.Que
$o = Find-AIDocOlvido $e5 'Vacaciones'
Ver 'olvidar "Vacaciones" -> el apartado de reglamento.odt' ($o.Tipo -eq 'apartado' -and $o.Reglas[0].Fichero -eq 'reglamento.odt' -and $o.Reglas[0].Apartado -eq 'Reglamento interno > Vacaciones') $o.Que
$o = Find-AIDocOlvido $e5 'pintura preparada'
Ver 'olvidar "pintura preparada" -> un tema, con ejemplos' ($o.Tipo -eq 'tema' -and $o.Trozos -ge 1 -and $o.Ejemplos.Count -ge 1 -and $o.Ejemplos[0] -match 'devoluciones') $o.Que
Ver 'olvidar algo que no esta -> nada' ($null -eq (Find-AIDocOlvido $e5 'submarinos nucleares'))
$reglas = @((Find-AIDocOlvido $e5 'empleados').Reglas) + @((Find-AIDocOlvido $e5 'Vacaciones').Reglas) + @((Find-AIDocOlvido $e5 'pintura').Reglas)
$eo = Update-AIDocIndice $carpetas $cache $null $e5 $reglas
$em = @($eo.Ficheros | Where-Object { $_.Fichero -eq 'empleados.csv' })[0]
Ver 'el documento olvidado ni se lee: queda como olvidado y se borra lo leido' ($em.Estado -eq 'olvidado' -and @(Get-ChildItem (Join-Path $cache 'textos')).Count -eq 9 -and @($eo.Indice.Fichero | Where-Object { $_ -eq 'empleados.csv' }).Count -eq 0)
$h = Find-AIDocTrozos $eo.Indice '¿Quién es la gerente?'
Ver 'y ya no sale en las respuestas' (@($h.Trozos | Where-Object { $_.Fichero -eq 'empleados.csv' }).Count -eq 0)
$h = Find-AIDocTrozos $eo.Indice '¿Cuántos días de vacaciones tengo?'
Ver 'el apartado olvidado tampoco' (@($h.Trozos | Where-Object { $_.Seccion -like '*Vacaciones*' }).Count -eq 0)
Ver 'pero el resto del documento si' (@($eo.Indice.Seccion | Where-Object { $_ -eq 'Reglamento interno' }).Count -ge 1)
$todo = $eo.Indice.Texto -join "`n"
Ver 'el tema olvidado no sale en ningun documento' ($todo -notmatch '(?i)pintura') (@($eo.Indice.Texto | Where-Object { $_ -match '(?i)pintura' }) -join ' // ')
Ver 'pero lo de al lado si: solo se van las lineas del tema' ($todo -match 'Corte de llaves \| Precio: 50' -and $todo -match 'herramientas' -eq $false -and $todo -match 'Correo: ventas@')
Ver 'una fila cuyo primer dato es del tema se va entera (sin precio huerfano)' ($todo -notmatch '120\.5')
$r = Remove-AIDocTema 'Planilla' "Nombre: Ana | Sueldo: 25000 | Cargo: Gerente`nNombre: Luis | Sueldo: 18000 | Cargo: Cajero`nEl sueldo se paga el 30." ([string[]]@((ConvertTo-AIDocTerminos 'sueldos')))
Ver 'en una fila se quita solo el dato del tema' ($r.Quedan -eq "Nombre: Ana | Cargo: Gerente`nNombre: Luis | Cargo: Cajero" -and $r.Fuera.Count -eq 3) $r.Quedan
$r = Remove-AIDocTema 'Politicas > Sueldos' "Se paga el 30.`nCon transferencia." ([string[]]@((ConvertTo-AIDocTerminos 'sueldos')))
Ver 'si el apartado es del tema, se va todo' ($r.Quedan -eq '' -and $r.Fuera.Count -eq 2)
Ver 'la lista de documentos no nombra el olvidado' ((Get-AIDocCatalogo $eo) -notmatch 'empleados')
$ev = Update-AIDocIndice $carpetas $cache $null $eo @()
Ver 'recordar: sin reglas, todo vuelve' (@($ev.Indice.Fichero | Where-Object { $_ -eq 'empleados.csv' }).Count -ge 1 -and $ev.Indice.N -eq $e5.Indice.N)
$f = Join-Path $tmp 'olvidos.json'
Save-AIDocOlvidos $f $reglas
$l = Read-AIDocOlvidos $f
Ver 'documentos-olvidos.json ida y vuelta' ($l.Lista.Count -eq $reglas.Count -and $l.Lista[1].Apartado -eq 'Reglamento interno > Vacaciones' -and $l.Lista[2].Tema -eq 'pintura')
foreach ($x in @(
    @('olvida todo lo que aprendiste', 'TODO'), @('olvida todos los documentos', 'TODO'), @('Olvida lo que aprendiste.', 'TODO'),
    @('olvida el documento empleados.csv', 'empleados.csv'), @('borra lo de los sueldos', 'sueldos'),
    @('deja de usar la carpeta ferreteria', 'ferreteria'), @('olvida el apartado de vacaciones', 'vacaciones'),
    @('por favor olvida lo relacionado con la pintura', 'pintura'))) {
    $pe = Get-AIDocOlvidoPeticion $x[0]
    $ok = if ($x[1] -eq 'TODO') { $pe -and $pe.Todo } else { $pe -and -not $pe.Todo -and $pe.Que -eq $x[1] }
    Ver ("{0,-48} -> {1}" -f $x[0], $x[1]) $ok "$($pe.Todo) / $($pe.Que)"
}
foreach ($x in 'olvida lo que te dije', 'quita la tilde de esta palabra', 'borra esto de mi cabeza', '¿cómo olvido un documento?') {
    Ver ("{0,-48} -> no" -f $x) ($null -eq (Get-AIDocOlvidoPeticion $x))
}

# ---- Carpetas guardadas y proveedores --------------------------------------------
Write-Output '--- guardadas'
$f = Join-Path $tmp 'documentos.json'
Save-AIDocCarpetas $f $carpetas
$l = Read-AIDocCarpetas $f
Ver 'documentos.json ida y vuelta' ($l.Lista.Count -eq 1 -and $l.Lista[0].Ruta -eq $neg -and $l.Lista[0].Tema -eq $carpetas[0].Tema)
[IO.File]::WriteAllText($f, '{ roto')
Ver 'documentos.json roto: se dice y no se usa' ((Read-AIDocCarpetas $f).Error -and (Read-AIDocCarpetas $f).Lista.Count -eq 0)
Ver 'nombre corto sin acentos' ((ConvertTo-AIDocNombre $neg @()) -eq 'ferreteria-el-tornillo')
Ver 'nombre repetido -> -2' ((ConvertTo-AIDocNombre $neg @([pscustomobject]@{ Nombre = 'ferreteria-el-tornillo' })) -eq 'ferreteria-el-tornillo-2')
Ver 'gemma y ollama son locales; xai y openai no' ((Test-AIDocLocal (Resolve-AIProvider 'gemma')) -and (Test-AIDocLocal (Resolve-AIProvider 'ollama')) -and -not (Test-AIDocLocal (Resolve-AIProvider 'xai')) -and -not (Test-AIDocLocal (Resolve-AIProvider 'openai')))

# ---- Ordenes de /documentos, en el orden en que estan en bin\ai.ps1 --------------
Write-Output '--- ordenes'
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'bin\ai.ps1'), [ref]$null, [ref]$null)
$patrones = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $n.Value -like '^/(?:documentos?|docs?)*' }, $true) | ForEach-Object { $_.Value })
function Orden($linea) { $i = 0; foreach ($p in $patrones) { $i++; if ($linea -match $p) { return $i } }; return 0 }
Ver 'once ordenes de /documentos' ($patrones.Count -eq 11) $patrones.Count
Ver '/documentos nube on    -> nube' ((Orden '/documentos nube on') -eq 1 -and (Orden '/docs nube off') -eq 1)
Ver '/documentos on|off     -> interruptor' ((Orden '/documentos off') -eq 2 -and (Orden '/doc on') -eq 2)
Ver '/documentos agregar X  -> agregar' ((Orden '/documentos agregar D:\Mi Negocio') -eq 3 -and (Orden '/docs leer "D:\x y"') -eq 3)
Ver '/documentos quitar X   -> quitar' ((Orden '/documentos quitar negocio') -eq 4)
Ver '/documentos olvidar X  -> olvidar' ((Orden '/documentos olvidar empleados.csv') -eq 5 -and (Orden '/documentos olvidar todo') -eq 5)
Ver '/documentos olvidos    -> lista de olvidos' ((Orden '/documentos olvidos') -eq 6)
Ver '/documentos recordar N -> deshacer' ((Orden '/documentos recordar 2') -eq 7)
Ver '/documentos actualizar -> releer' ((Orden '/documentos actualizar') -eq 8)
Ver '/documentos buscar X   -> buscar' ((Orden '/documentos buscar horario sabado') -eq 9)
Ver '/documentos y /docs    -> lista' ((Orden '/documentos') -eq 10 -and (Orden '/docs') -eq 10 -and (Orden '/documentos lista') -eq 10)
Ver '/documentos otra cosa  -> modo de uso' ((Orden '/documentos agregar') -eq 11 -and (Orden '/documentos nube') -eq 11 -and (Orden '/documentos recordar x') -eq 11)
Ver '/documental            -> al modelo' ((Orden '/documental') -eq 0)

Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
Write-Output "MAL = $mal"
exit $mal
