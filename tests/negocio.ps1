#requires -Version 5.1
<#
  negocio.ps1 - Una bateria con un negocio inventado entero: la Panaderia y
  Cafeteria La Espiga, con dos sucursales. Trae quienes son, servicios y
  precios, empleados, horarios por sucursal, vacaciones y permisos,
  reglamento, procedimientos, pedidos, quejas, proveedores, seguridad
  alimentaria, inventario, y necesidades y metas, en todos los formatos que
  se leen. Lleva trampas a proposito: datos que no estan (sueldos, tarjeta,
  domicilio), dos horarios distintos, un PDF, una imagen y un temporal de
  Word.

    .\tests\negocio.ps1                  procesamiento: que se lee de cada
                                         fichero y que cada pregunta encuentre
                                         su documento (sin modelo, segundos)
    .\tests\negocio.ps1 -Modelo          y ademas conocimiento: las preguntas
                                         al modelo de verdad, con su nota
    .\tests\negocio.ps1 -Crear <carpeta> solo crea los documentos, para
                                         probarlos a mano

  Todo es inventado: nombres, direcciones y telefonos no son de nadie.
#>
param([string]$Raiz = (Split-Path -Parent $PSScriptRoot), [string]$Crear, [switch]$Modelo, [string]$Proveedor = 'gemma')
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$root = $Raiz
foreach ($l in 'providers', 'web', 'equipo', 'documentos') { . (Join-Path $root "lib\$l.ps1") }
Add-Type -AssemblyName System.IO.Compression

# ===========================================================================
#  Los documentos
# ===========================================================================
$utf8 = New-Object Text.UTF8Encoding $false
$esc = { param($s) [Security.SecurityElement]::Escape([string]$s) }
function Zip($ruta, $entradas) {
    $dir = Split-Path -Parent $ruta
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $fs = [IO.File]::Create($ruta)
    $z = New-Object IO.Compression.ZipArchive($fs, [IO.Compression.ZipArchiveMode]::Create)
    foreach ($k in $entradas.Keys) { $w = New-Object IO.StreamWriter($z.CreateEntry($k).Open(), $utf8); $w.Write($entradas[$k]); $w.Dispose() }
    $z.Dispose(); $fs.Dispose()
}
function Texto($ruta, $t, $enc = $utf8) {
    $dir = Split-Path -Parent $ruta
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [IO.File]::WriteAllText($ruta, $t, $enc)
}
function Docx($ruta, $bloques) {
    # bloques: @('h1', texto) @('h2', texto) @('p', texto) @('li', texto) @('tabla', filas)
    $sb = New-Object Text.StringBuilder
    foreach ($b in $bloques) {
        switch ($b[0]) {
            'h1' { [void]$sb.Append("<w:p><w:pPr><w:pStyle w:val=""Ttulo1""/></w:pPr><w:r><w:t>$(& $esc $b[1])</w:t></w:r></w:p>") }
            'h2' { [void]$sb.Append("<w:p><w:pPr><w:pStyle w:val=""Heading2""/></w:pPr><w:r><w:t>$(& $esc $b[1])</w:t></w:r></w:p>") }
            'li' { [void]$sb.Append("<w:p><w:pPr><w:numPr><w:ilvl w:val=""0""/><w:numId w:val=""1""/></w:numPr></w:pPr><w:r><w:t xml:space=""preserve"">$(& $esc $b[1])</w:t></w:r></w:p>") }
            'p'  { [void]$sb.Append("<w:p><w:r><w:t xml:space=""preserve"">$(& $esc $b[1])</w:t></w:r></w:p>") }
            'tabla' {
                [void]$sb.Append('<w:tbl><w:tblPr/>')
                foreach ($fila in $b[1]) {
                    [void]$sb.Append('<w:tr>')
                    foreach ($c in $fila) { [void]$sb.Append("<w:tc><w:p><w:r><w:t>$(& $esc $c)</w:t></w:r></w:p></w:tc>") }
                    [void]$sb.Append('</w:tr>')
                }
                [void]$sb.Append('</w:tbl>')
            }
        }
    }
    Zip $ruta ([ordered]@{ 'word/document.xml' = "<?xml version=""1.0"" encoding=""UTF-8""?><w:document xmlns:w=""http://schemas.openxmlformats.org/wordprocessingml/2006/main""><w:body>$($sb.ToString())<w:sectPr/></w:body></w:document>" })
}
function Xlsx($ruta, $hojas) {
    # hojas: [ordered] nombre -> filas; una celda es texto, numero,
    # @{ fecha = [datetime] }, @{ hora = 'hh:mm' } o @{ pct = 0.5 }
    $ss = New-Object 'System.Collections.Generic.List[string]'
    $id = { param($s) $i = $ss.IndexOf($s); if ($i -lt 0) { $ss.Add($s); $i = $ss.Count - 1 }; $i }
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $ent = [ordered]@{}
    $libro = ''; $rels = ''; $n = 0
    foreach ($nombre in $hojas.Keys) {
        $n++
        $sb = New-Object Text.StringBuilder
        $r = 0
        foreach ($fila in $hojas[$nombre]) {
            $r++
            [void]$sb.Append("<row r=""$r"">")
            $c = 0
            foreach ($v in $fila) {
                $ref = [string][char](65 + $c) + $r; $c++
                if ($null -eq $v -or $v -eq '') { continue }
                if ($v -is [hashtable]) {
                    if ($v.ContainsKey('fecha')) { [void]$sb.Append("<c r=""$ref"" s=""1""><v>$((($v.fecha - [datetime]'1899-12-30').TotalDays).ToString($inv))</v></c>") }
                    elseif ($v.ContainsKey('hora')) { $h, $m = $v.hora -split ':'; [void]$sb.Append("<c r=""$ref"" s=""2""><v>$((([int]$h * 60 + [int]$m) / 1440.0).ToString('R', $inv))</v></c>") }
                    else { [void]$sb.Append("<c r=""$ref"" s=""3""><v>$(([double]$v.pct).ToString($inv))</v></c>") }
                }
                elseif ($v -is [string]) { [void]$sb.Append("<c r=""$ref"" t=""s""><v>$(& $id $v)</v></c>") }
                else { [void]$sb.Append("<c r=""$ref""><v>$(([double]$v).ToString($inv))</v></c>") }
            }
            [void]$sb.Append('</row>')
        }
        $ent["xl/worksheets/sheet$n.xml"] = "<worksheet><sheetData>$($sb.ToString())</sheetData></worksheet>"
        $libro += "<sheet name=""$(& $esc $nombre)"" sheetId=""$n"" r:id=""rId$n""/>"
        $rels += "<Relationship Id=""rId$n"" Type=""worksheet"" Target=""worksheets/sheet$n.xml""/>"
    }
    $ent['xl/workbook.xml'] = "<workbook xmlns:r=""http://schemas.openxmlformats.org/officeDocument/2006/relationships""><sheets>$libro</sheets></workbook>"
    $ent['xl/_rels/workbook.xml.rels'] = "<Relationships>$rels</Relationships>"
    $ent['xl/sharedStrings.xml'] = '<sst>' + (($ss | ForEach-Object { "<si><t xml:space=""preserve"">$(& $esc $_)</t></si>" }) -join '') + '</sst>'
    $ent['xl/styles.xml'] = '<styleSheet><numFmts count="1"><numFmt numFmtId="164" formatCode="dd/mm/yyyy"/></numFmts><cellXfs count="4"><xf numFmtId="0"/><xf numFmtId="164" applyNumberFormat="1"/><xf numFmtId="20" applyNumberFormat="1"/><xf numFmtId="9" applyNumberFormat="1"/></cellXfs></styleSheet>'
    Zip $ruta $ent
}
function Pptx($ruta, $diapos) {
    $ent = [ordered]@{}; $k = 0
    foreach ($d in $diapos) {
        $k++
        $ps = (@($d) | ForEach-Object { "<a:p><a:r><a:t>$(& $esc $_)</a:t></a:r></a:p>" }) -join ''
        $ent["ppt/slides/slide$k.xml"] = "<p:sld xmlns:p=""p"" xmlns:a=""a""><p:cSld><p:spTree><p:sp><p:txBody>$ps</p:txBody></p:sp></p:spTree></p:cSld></p:sld>"
    }
    Zip $ruta $ent
}
function Odt($ruta, $bloques) {
    $sb = New-Object Text.StringBuilder
    foreach ($b in $bloques) {
        switch ($b[0]) {
            'h1' { [void]$sb.Append("<text:h text:outline-level=""1"">$(& $esc $b[1])</text:h>") }
            'h2' { [void]$sb.Append("<text:h text:outline-level=""2"">$(& $esc $b[1])</text:h>") }
            'p'  { [void]$sb.Append("<text:p>$(& $esc $b[1])</text:p>") }
            'li' { [void]$sb.Append("<text:list><text:list-item><text:p>$(& $esc $b[1])</text:p></text:list-item></text:list>") }
        }
    }
    Zip $ruta ([ordered]@{ 'content.xml' = "<office:document-content><office:body><office:text>$($sb.ToString())</office:text></office:body></office:document-content>" })
}
function Ods($ruta, $nombre, $filas) {
    $sb = New-Object Text.StringBuilder
    foreach ($f in $filas) {
        [void]$sb.Append('<table:table-row>')
        foreach ($c in $f) { [void]$sb.Append("<table:table-cell><text:p>$(& $esc $c)</text:p></table:table-cell>") }
        [void]$sb.Append('<table:table-cell table:number-columns-repeated="1020"/></table:table-row>')
    }
    Zip $ruta ([ordered]@{ 'content.xml' = "<office:document-content><office:body><office:spreadsheet><table:table table:name=""$nombre"">$($sb.ToString())</table:table></office:spreadsheet></office:body></office:document-content>" })
}

function New-AINegocio {
    <#  Crea la Panaderia y Cafeteria La Espiga en $Destino. Devuelve la ruta.  #>
    param([string]$Destino)
    $n = Join-Path $Destino ('Panader' + [char]0xED + 'a La Espiga')
    New-Item -ItemType Directory -Path $n -Force | Out-Null

    Docx (Join-Path $n 'Quiénes somos.docx') @(
        ,@('h1', 'Panadería y Cafetería La Espiga')
        ,@('p', 'La Espiga es una panadería y cafetería familiar fundada en 2012 por Rosa Delgado, que sigue siendo la dueña y gerente general.')
        ,@('h2', 'Misión')
        ,@('p', 'Hornear cada día pan fresco con harina de la región y atender a cada cliente como a un vecino.')
        ,@('h2', 'Sucursales')
        ,@('li', 'Sucursal Central: Calle de los Almendros 45, frente al parque.')
        ,@('li', 'Sucursal Norte: Plaza El Roble, local 3.')
        ,@('h2', 'Qué ofrecemos')
        ,@('p', 'Pan del día, repostería, pasteles por encargo, bocadillos para eventos y una cafetería con café de finca.')
    )
    Xlsx (Join-Path $n 'Servicios y precios.xlsx') ([ordered]@{
        'Panadería' = @(
            ,@('Producto', 'Precio', 'Unidad', 'Vigente desde')
            ,@('Pan francés', 5, 'unidad', @{ fecha = [datetime]'2026-10-01' })
            ,@('Baguette', 35, 'unidad', @{ fecha = [datetime]'2026-10-01' })
            ,@('Croissant', 28, 'unidad', @{ fecha = [datetime]'2026-10-01' })
            ,@('Pastel de tres leches', 60, 'porción', @{ fecha = [datetime]'2026-10-01' })
        )
        'Cafetería' = @(
            ,@('Bebida', 'Pequeño', 'Grande')
            ,@('Café americano', 30, 40)
            ,@('Capuchino', 45, 55)
            ,@('Chocolate caliente', 35, 45)
        )
        'Pedidos especiales' = @(
            ,@('Servicio', 'Días de anticipación', 'Anticipo')
            ,@('Pastel para eventos', 3, @{ pct = 0.5 })
            ,@('Bocadillos para 50 personas', 5, @{ pct = 0.5 })
            ,@('Pan al por mayor para negocios', 1, @{ pct = 0 })
        )
        'Horarios' = @(
            ,@('Día', 'Central abre', 'Central cierra', 'Norte abre', 'Norte cierra')
            ,@('Lunes a viernes', @{ hora = '6:00' }, @{ hora = '19:00' }, @{ hora = '7:00' }, @{ hora = '20:00' })
            ,@('Sábado', @{ hora = '6:00' }, @{ hora = '14:00' }, @{ hora = '7:00' }, @{ hora = '20:00' })
            ,@('Domingo', 'cerrado', 'cerrado', @{ hora = '8:00' }, @{ hora = '13:00' })
        )
    })
    Texto (Join-Path $n 'Empleados.csv') ("Nombre;Cargo;Sucursal;Turno;Ingreso;Extensión`n" +
        "Rosa Delgado;Gerente general;Central;Mañana;2012-03-15;101`n" +
        "Carlos Ruiz;Jefe de panadería;Central;Madrugada;2014-07-01;102`n" +
        "Lucía Martínez;Cajera;Central;Mañana;2019-02-11;103`n" +
        "Ana Torres;Encargada de sucursal;Norte;Mañana;2017-05-20;200`n" +
        "Jorge Peña;Barista;Norte;Tarde;2021-09-06;201`n" +
        "Marcos Díaz;Ayudante de panadería;Central;Madrugada;2023-01-09;104`n")
    Docx (Join-Path $n 'Recursos humanos\Vacaciones y permisos.docx') @(
        ,@('h1', 'Política de vacaciones y permisos')
        ,@('h2', 'Vacaciones')
        ,@('p', 'Cada empleado tiene 15 días hábiles de vacaciones por año trabajado, a partir de su primer año.')
        ,@('p', 'Las vacaciones se piden por escrito a la gerente general con 30 días de anticipación.')
        ,@('p', 'No puede haber más de dos personas de vacaciones a la vez en una misma sucursal.')
        ,@('p', 'En diciembre no se dan vacaciones: es la temporada alta.')
        ,@('h2', 'Permisos')
        ,@('li', 'Enfermedad: se avisa antes del turno y se entrega la constancia médica en 48 horas.')
        ,@('li', 'Permiso personal: hasta 2 días al año con goce de salario, pedidos con una semana de anticipación.')
    )
    Odt (Join-Path $n 'Recursos humanos\Reglamento interno.odt') @(
        ,@('h1', 'Reglamento interno')
        ,@('h2', 'Uniforme')
        ,@('p', 'Gabacha café con el logo, gorro o redecilla en el área de producción y zapatos cerrados.')
        ,@('h2', 'Puntualidad')
        ,@('p', 'Hay 10 minutos de tolerancia. Tres llegadas tarde en un mismo mes se sancionan con una llamada de atención por escrito.')
        ,@('h2', 'Conducta')
        ,@('li', 'Se prohíbe usar el celular en el área de producción.')
        ,@('li', 'Se prohíbe fumar en todo el local.')
        ,@('li', 'El descanso de almuerzo es de 30 minutos.')
    )
    Docx (Join-Path $n 'Procedimientos\Apertura y cierre.docx') @(
        ,@('h1', 'Apertura y cierre de sucursal')
        ,@('h2', 'Apertura')
        ,@('li', 'A las 4:00 el jefe de panadería enciende los hornos.')
        ,@('li', 'A las 5:30 se limpian las vitrinas y el mostrador.')
        ,@('li', 'A las 5:45 la cajera cuenta el fondo de caja, que es de C$ 1,500.')
        ,@('li', 'Se abre al público a la hora del horario de cada sucursal.')
        ,@('h2', 'Cierre')
        ,@('li', 'Se cuadra la caja y el efectivo se guarda en la caja fuerte.')
        ,@('li', 'Se apagan los hornos y se anota la temperatura final de las cámaras.')
        ,@('li', 'Se activa la alarma; el código solo lo tienen la encargada y la gerente.')
        ,@('h2', 'Responsables')
        ,@('tabla', @(@('Sucursal', 'Responsable de apertura', 'Responsable de cierre'), @('Central', 'Carlos Ruiz', 'Lucía Martínez'), @('Norte', 'Ana Torres', 'Jorge Peña')))
    )
    Texto (Join-Path $n 'Procedimientos\Atención de quejas.md') @'
# Atención de quejas

1. Se escucha al cliente con amabilidad y sin discutir.
2. Se anota la queja en el libro de quejas de la sucursal.
3. Si el producto salió en mal estado, se cambia o se devuelve el dinero presentando el ticket.
4. Si el cliente no queda conforme, se pasa a la encargada de sucursal o a la gerente.

## Plazos
- Toda queja se resuelve en 48 horas como máximo.
- Si el cliente la pide por escrito, la respuesta escrita se entrega en 5 días hábiles.
'@
    # En Windows-1252, como el Bloc de notas antiguo.
    Texto (Join-Path $n 'Procedimientos\Pedidos para eventos.txt') @'
PEDIDOS PARA EVENTOS
Los pasteles para eventos se piden con un mínimo de 3 días de anticipación.
Para confirmar el pedido se paga un anticipo del 50%.
Si el cliente cancela con más de 48 horas de anticipación se le devuelve el 100% del anticipo.
Si cancela con menos de 48 horas se le devuelve el 50% del anticipo.
Los pedidos se hacen en caja o por WhatsApp al 8888-0000.
'@ ([Text.Encoding]::GetEncoding(1252))
    Pptx (Join-Path $n 'Necesidades y metas 2027.pptx') @(
        ,@('Necesidades actuales', 'Un segundo horno industrial, con un presupuesto de C$ 450,000.', 'Dos personas más para los fines de semana en la sucursal Norte.', 'Un sistema de inventario digital.', 'Reparar la cámara de refrigeración de la sucursal Central.')
        ,@('Metas 2027', 'Abrir una tercera sucursal en el segundo semestre de 2027.', 'Aumentar un 20% las ventas de la cafetería.', 'Capacitar a todo el personal en manipulación de alimentos antes de marzo de 2027.')
    )
    Texto (Join-Path $n 'Proveedores.html') @'
<html><head><title>Proveedores</title><script>var proveedor = "Proveedor falso";</script></head><body>
<h1>Proveedores</h1>
<table>
<tr><th>Insumo</th><th>Proveedor</th><th>Entrega</th></tr>
<tr><td>Harina</td><td>Molinos del Norte</td><td>lunes y jueves</td></tr>
<tr><td>Café</td><td>Finca Las Nubes</td><td>cada 15 días</td></tr>
<tr><td>Lácteos</td><td>Lácteos San José</td><td>todos los días a las 5:00</td></tr>
<tr><td>Huevos</td><td>Granja Santa Fe</td><td>martes y viernes</td></tr>
</table></body></html>
'@
    Texto (Join-Path $n 'Seguridad alimentaria.rtf') ('{\rtf1\ansi\deff0{\fonttbl{\f0 Arial;}}{\*\generator Prueba;}\f0 SEGURIDAD ALIMENTARIA\par ' +
        'Los refrigeradores se mantienen entre 0 y 4 \''b0C y los congeladores a -18 \''b0C o menos.\par ' +
        'La temperatura se anota cada 4 horas en la bit\''e1cora.\par ' +
        'Todo producto lleva etiqueta con su fecha de elaboraci\''f3n.\par ' +
        'El pan que no se vende en el d\''eda se dona al cierre al Comedor Infantil del barrio; nunca se vende al d\''eda siguiente.\par}') ([Text.Encoding]::ASCII)
    Ods (Join-Path $n 'Inventario mínimo.ods') 'Inventario' @(
        @('Insumo', 'Mínimo', 'Unidad'), @('Harina', '20', 'quintales'), @('Azúcar', '5', 'quintales'),
        @('Huevos', '30', 'cajillas'), @('Café en grano', '15', 'libras'), @('Leche', '40', 'litros'))
    Texto (Join-Path $n 'Catálogo de pasteles.pdf') '%PDF-1.4 no es un pdf de verdad'
    Texto (Join-Path $n 'logo.png') 'no es una imagen'
    Texto (Join-Path $n 'Procedimientos\~$Apertura y cierre.docx') 'temporal de Word'
    return $n
}

if ($Crear) { New-AINegocio $Crear; exit 0 }

$mal = 0; $total = 0
function Ver([string]$que, [bool]$ok, $extra = '') { $script:total++; if ($ok) { Write-Output "  ok   $que" } else { $script:mal++; Write-Output "  MAL  $que  $extra" } }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('negocio-' + [Guid]::NewGuid().ToString('N').Substring(0, 6))
$neg = New-AINegocio $tmp
$cache = Join-Path $tmp 'cache'
$carpetas = @([pscustomobject]@{ Nombre = 'la-espiga'; Ruta = $neg; Tema = 'la Panadería y Cafetería La Espiga: servicios, precios, empleados, horarios, políticas, procedimientos, necesidades y metas'; Creado = '' })

# ===========================================================================
#  1. Procesamiento: que se lee de cada fichero
# ===========================================================================
Write-Output '=== procesamiento: lectura'
$sw = [Diagnostics.Stopwatch]::StartNew()
$e = Update-AIDocIndice $carpetas $cache $null $null
$ok = @($e.Ficheros | Where-Object { $_.Estado -eq 'ok' })
$no = @($e.Ficheros | Where-Object { $_.Estado -ne 'ok' })
Write-Output "    $($ok.Count) leídos, $($e.Indice.N) fragmentos, $([Math]::Round($sw.Elapsed.TotalSeconds, 1)) s"
Ver 'los doce documentos que se saben leer' ($ok.Count -eq 12) (@($ok | ForEach-Object { $_.Fichero }) -join ', ')
Ver 'el PDF no, con su motivo' ($no.Count -eq 1 -and $no[0].Fichero -like '*.pdf' -and $no[0].Motivo -match 'PDF')
Ver 'la imagen y el temporal de Word, ni eso' ($e.Otros -eq 1 -and @($e.Ficheros | Where-Object { $_.Fichero -match '~\$' }).Count -eq 0)
$txt = @{}
foreach ($f in $ok) { $txt[$f.Fichero] = [IO.File]::ReadAllText((Join-Path $cache "textos\$($f.Clave).txt"), [Text.Encoding]::UTF8) }
function Lee($fich, $que, $patrones) { $t = [string]$txt[$fich]; $falta = @($patrones | Where-Object { $t -notmatch $_ }); Ver ("{0,-34} {1}" -f $fich, $que) ($falta.Count -eq 0) ("falta: $($falta -join ' / ')") }
Lee 'Quiénes somos.docx' 'titulos y listas de Word' @('(?m)^# Panadería y Cafetería La Espiga$', '(?m)^## Sucursales$', '(?m)^- Sucursal Norte: Plaza El Roble, local 3\.$')
Lee 'Servicios y precios.xlsx' 'hojas, precios y fechas de Excel' @('## Hoja: Panadería', 'Producto: Capuchino|Bebida: Capuchino \| Pequeño: 45 \| Grande: 55', 'Producto: Croissant \| Precio: 28 \| Unidad: unidad \| Vigente desde: 01/10/2026')
Lee 'Servicios y precios.xlsx' 'porcentajes de Excel' @('Servicio: Pastel para eventos \| Días de anticipación: 3 \| Anticipo: 50%', 'Anticipo: 0%')
Lee 'Servicios y precios.xlsx' 'horas de Excel y celdas de texto' @('Día: Domingo \| Central abre: cerrado \| Central cierra: cerrado \| Norte abre: 08:00 \| Norte cierra: 13:00', 'Día: Lunes a viernes \| Central abre: 06:00 \| Central cierra: 19:00')
Lee 'Empleados.csv' 'CSV con punto y coma y acentos' @('Nombre: Jorge Peña \| Cargo: Barista \| Sucursal: Norte \| Turno: Tarde \| Ingreso: 2021-09-06 \| Extensión: 201')
Lee 'Recursos humanos\Vacaciones y permisos.docx' 'apartados de Word' @('(?m)^## Vacaciones$', '15 días hábiles', '(?m)^- Permiso personal: hasta 2 días')
Lee 'Recursos humanos\Reglamento interno.odt' 'OpenDocument con listas' @('(?m)^## Puntualidad$', 'llamada de atención por escrito', '- Se prohíbe usar el celular')
Lee 'Procedimientos\Apertura y cierre.docx' 'tabla de Word sin cifras' @('Columnas \(primera fila\): Sucursal \| Responsable de apertura \| Responsable de cierre', '(?m)^Norte \| Ana Torres \| Jorge Peña$', 'C\$ 1,500')
Lee 'Procedimientos\Atención de quejas.md' 'Markdown' @('(?m)^## Plazos$', '48 horas', '5 días hábiles')
Lee 'Procedimientos\Pedidos para eventos.txt' 'texto en Windows-1252' @('mínimo de 3 días', 'menos de 48 horas se le devuelve el 50%')
Lee 'Necesidades y metas 2027.pptx' 'diapositivas en orden' @('(?s)Necesidades actuales.*Metas 2027', 'C\$ 450,000')
Lee 'Proveedores.html' 'tabla HTML sin el codigo' @('Harina\s+Molinos del Norte\s+lunes y jueves')
Lee 'Seguridad alimentaria.rtf' 'RTF con grados y acentos' @('entre 0 y 4 °C', '-18 °C', 'bitácora', 'día siguiente')
Lee 'Inventario mínimo.ods' 'hoja de OpenDocument' @('## Hoja: Inventario', 'Insumo: Harina \| Mínimo: 20 \| Unidad: quintales')
Ver 'el codigo de la pagina no se cuela' ([string]$txt['Proveedores.html'] -notmatch 'Proveedor falso')

# ===========================================================================
#  2. Procesamiento: que cada pregunta encuentre su documento
# ===========================================================================
# Cada pregunta: el texto, el documento del que sale la respuesta, un patron
# que tiene que estar en lo que viaja al modelo, y lo que tiene que contestar
# el modelo (con -Modelo). Tipo: dato (esta en los documentos), falta (no
# esta: hay que decirlo), fuera (no va de los documentos) o sigue (va con la
# pregunta anterior).
$preguntas = @(
    @{ T = 'dato'; P = '¿Quién fundó la panadería y en qué año?'; F = 'Quiénes somos.docx'; Viaja = 'Rosa Delgado'; Dice = @('Rosa Delgado', '2012') }
    @{ T = 'dato'; P = '¿Cuántas sucursales tienen y dónde están?'; F = 'Quiénes somos.docx'; Viaja = 'Plaza El Roble'; Dice = @('Central', 'Norte', 'Almendros|Roble') }
    @{ T = 'dato'; P = '¿A qué hora abre la sucursal Norte los domingos?'; F = 'Servicios y precios.xlsx'; Viaja = 'Norte abre: 08:00'; Dice = @('8:00|8 de la ma|08:00|8 a\. ?m') }
    @{ T = 'dato'; P = '¿La sucursal Central abre los domingos?'; F = 'Servicios y precios.xlsx'; Viaja = 'Central abre: cerrado'; Dice = @('(?i)cerrad|no abre') }
    @{ T = 'dato'; P = '¿Cuánto cuesta un capuchino grande?'; F = 'Servicios y precios.xlsx'; Viaja = 'Grande: 55'; Dice = @('55') }
    @{ T = 'dato'; P = '¿Desde cuándo están vigentes los precios del pan?'; F = 'Servicios y precios.xlsx'; Viaja = 'Vigente desde: 01/10/2026'; Dice = @('01/10/2026|1/10/2026|1 de octubre') }
    @{ T = 'dato'; P = '¿Con cuántos días de anticipación se piden bocadillos para 50 personas?'; F = 'Servicios y precios.xlsx'; Viaja = 'Bocadillos para 50 personas'; Dice = @('\b5\b|cinco') }
    @{ T = 'dato'; P = '¿Quién es el jefe de panadería y en qué turno trabaja?'; F = 'Empleados.csv'; Viaja = 'Carlos Ruiz'; Dice = @('Carlos Ruiz', '(?i)madrugada') }
    @{ T = 'dato'; P = '¿Cuál es la extensión de Ana Torres?'; F = 'Empleados.csv'; Viaja = 'Ana Torres'; Dice = @('\b200\b') }
    @{ T = 'dato'; P = '¿Cuántos días de vacaciones me tocan y con cuánta anticipación las pido?'; F = 'Recursos humanos\Vacaciones y permisos.docx'; Viaja = '15 días hábiles'; Dice = @('15', '30') }
    @{ T = 'dato'; P = '¿Puedo tomar vacaciones en diciembre?'; F = 'Recursos humanos\Vacaciones y permisos.docx'; Viaja = 'diciembre'; Dice = @('(?i)\bno\b') }
    @{ T = 'dato'; P = '¿Qué pasa si llego tarde tres veces en un mes?'; F = 'Recursos humanos\Reglamento interno.odt'; Viaja = 'llamada de atención'; Dice = @('(?i)llamada de atenci') }
    @{ T = 'dato'; P = '¿Puedo usar el celular en el área de producción?'; F = 'Recursos humanos\Reglamento interno.odt'; Viaja = 'celular'; Dice = @('(?i)\bno\b|proh[ií]b') }
    @{ T = 'dato'; P = '¿Cuánto es el fondo de caja al abrir?'; F = 'Procedimientos\Apertura y cierre.docx'; Viaja = 'C\$ 1,500'; Dice = @('1,500|1\.500|1500') }
    @{ T = 'dato'; P = '¿Quién cierra la sucursal Norte?'; F = 'Procedimientos\Apertura y cierre.docx'; Viaja = 'Jorge Peña'; Dice = @('Jorge Peña') }
    @{ T = 'dato'; P = '¿En cuánto tiempo hay que resolver una queja?'; F = 'Procedimientos\Atención de quejas.md'; Viaja = '48 horas'; Dice = @('48') }
    @{ T = 'dato'; P = 'Si un cliente cancela un pastel con un día de anticipación, ¿cuánto se le devuelve?'; F = 'Procedimientos\Pedidos para eventos.txt'; Viaja = 'menos de 48 horas'; Dice = @('50') }
    @{ T = 'dato'; P = '¿Qué necesidades tiene el negocio ahora mismo?'; F = 'Necesidades y metas 2027.pptx'; Viaja = 'segundo horno'; Dice = @('(?i)horno', '(?i)inventario|personal|personas|refrigeraci') }
    @{ T = 'dato'; P = '¿Cuánto cuesta el horno que necesitamos?'; F = 'Necesidades y metas 2027.pptx'; Viaja = '450,000'; Dice = @('450,000|450\.000|450000|450 mil') }
    @{ T = 'dato'; P = '¿Cuáles son las metas para 2027?'; F = 'Necesidades y metas 2027.pptx'; Viaja = 'tercera sucursal'; Dice = @('(?i)tercera sucursal') }
    @{ T = 'dato'; P = '¿Qué días llega la harina?'; F = 'Proveedores.html'; Viaja = 'Molinos del Norte'; Dice = @('(?i)lunes', '(?i)jueves') }
    @{ T = 'dato'; P = '¿A qué temperatura deben estar los refrigeradores?'; F = 'Seguridad alimentaria.rtf'; Viaja = 'entre 0 y 4'; Dice = @('\b0\b', '\b4\b') }
    @{ T = 'dato'; P = '¿Qué se hace con el pan que no se vende?'; F = 'Seguridad alimentaria.rtf'; Viaja = 'Comedor Infantil'; Dice = @('(?i)don') }
    @{ T = 'dato'; P = '¿Cuál es el mínimo de harina que debe haber en inventario?'; F = 'Inventario mínimo.ods'; Viaja = 'Mínimo: 20'; Dice = @('\b20\b', '(?i)quintal') }
    @{ T = 'falta'; P = '¿Cuánto gana Lucía Martínez?' }
    @{ T = 'falta'; P = '¿Aceptan pago con tarjeta?' }
    @{ T = 'falta'; P = '¿Tienen servicio a domicilio?' }
    @{ T = 'falta'; P = '¿Cuál es el correo electrónico de la gerente?' }
    @{ T = 'dato'; P = '¿A qué hora abre la sucursal Central entre semana?'; F = 'Servicios y precios.xlsx'; Viaja = 'Central abre: 06:00'; Dice = @('6:00|06:00|6 de la ma|6 a\. ?m') }
    @{ T = 'sigue'; P = '¿y los sábados?'; F = 'Servicios y precios.xlsx'; Viaja = 'Sábado'; Dice = @('6:00|06:00|6 de la ma|6 a\. ?m') }
    @{ T = 'fuera'; P = '¿Cuál es la capital de Francia?'; Dice = @('(?i)par[ií]s') }
    @{ T = 'fuera'; P = 'Escribe un poema corto sobre el mar' }
)

Write-Output ''
Write-Output '=== procesamiento: cada pregunta encuentra su documento'
$ix = $e.Indice
$previa = ''
foreach ($q in $preguntas) {
    $h = Find-AIDocTrozos $ix $q.P $(if ($q.T -eq 'sigue') { $previa } else { '' })
    $llega = ($h.Trozos | ForEach-Object { $_.Texto }) -join "`n"
    switch ($q.T) {
        'fuera' { Ver ("{0,-70} -> nada" -f $q.P) (-not $h.Relevante) "cob=$($h.Cobertura) $(@($h.Trozos)[0].Fichero)" }
        'falta' { Write-Output ("  --   {0,-70} (no está en los documentos: {1})" -f $q.P, $(if ($h.Relevante) { 'viajan ' + ((@($h.Trozos | ForEach-Object { $_.Fichero } | Select-Object -Unique)) -join ', ') } else { 'no viaja nada' })) }
        default {
            $bien = $h.Relevante -and @($h.Trozos | Where-Object { $_.Fichero -eq $q.F }).Count -and $llega -match $q.Viaja
            Ver ("{0,-70} -> {1}" -f $q.P, $q.F) $bien "relevante=$($h.Relevante) llegan: $((@($h.Trozos | ForEach-Object { $_.Fichero })) -join ', ')"
        }
    }
    $previa = $q.P
}

Write-Output ''
Write-Output '=== procesamiento: olvidar'
$o = Find-AIDocOlvido $e 'Necesidades y metas 2027'
Ver 'olvidar "Necesidades y metas 2027" -> ese documento' ($o.Tipo -eq 'fichero') $o.Que
$o2 = Find-AIDocOlvido $e 'Permisos'
Ver 'olvidar "Permisos" -> ese apartado' ($o2.Tipo -eq 'apartado' -and $o2.Reglas[0].Apartado -eq 'Política de vacaciones y permisos > Permisos') $o2.Que
$o3 = Find-AIDocOlvido $e 'extensión'
Ver 'olvidar "extensión" -> solo ese dato de cada empleado' ($o3.Tipo -eq 'tema' -and $o3.Trozos -eq 6) $o3.Que
$eo = Update-AIDocIndice $carpetas $cache $null $e (@($o.Reglas) + @($o2.Reglas) + @($o3.Reglas))
$todo = $eo.Indice.Texto -join "`n"
Ver 'lo olvidado ya no esta' ($todo -notmatch 'horno industrial|Permiso personal|Extensión: \d')
Ver 'y lo demas si' ($todo -match 'Nombre: Ana Torres \| Cargo: Encargada' -and $todo -match '15 días hábiles' -and $todo -match 'Capuchino')
$h = Find-AIDocTrozos $eo.Indice '¿Qué necesidades tiene el negocio ahora mismo?'
Ver 'la pregunta de las necesidades ya no trae el documento olvidado' (@($h.Trozos | Where-Object { $_.Fichero -like 'Necesidades*' }).Count -eq 0)
$eo = $null
$e = Update-AIDocIndice $carpetas $cache $null $null

# ===========================================================================
#  3. Conocimiento: las preguntas al modelo de verdad (-Modelo)
# ===========================================================================
if ($Modelo) {
    Write-Output ''
    Write-Output "=== conocimiento, con $Proveedor"
    foreach ($l in 'core', 'ui', 'comandos', 'consultas', 'preferencias') { . (Join-Path $root "lib\$l.ps1") }
    foreach ($k in @($AI_COLOR.Keys)) { $AI_COLOR[$k] = '' }
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'bin\ai.ps1'), [ref]$null, [ref]$null)
    foreach ($f in 'Get-AITurnMessages', 'Invoke-AITurn', 'Get-AIDocsEstado') {
        $d = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $f }, $true)
        . ([scriptblock]::Create($d.Extent.Text))
    }
    # Los avisos se apuntan: "consultando tus documentos" dice si viajaron.
    $script:Notas = New-Object System.Collections.Generic.List[string]
    function Write-AINote { param([string]$Text, [int]$PrefixWidth = 0, [switch]$Reprefix) $script:Notas.Add($Text) }
    $prov = Resolve-AIProvider $Proveedor; $Model = $prov.Model
    $Temp = 0.7; $Plain = $true; $NoStream = $true
    $script:Web = $false; $script:Equipo = $false; $script:ComandosOn = $false
    $script:SinHerramientas = @{}; $rotulo = 'ia > '
    $script:Comandos = @(); $script:Preferencias = @()
    $DocDir = $cache
    $script:DocCarpetas = $carpetas; $script:DocOlvidos = @()
    $script:DocsOn = $true; $script:DocsNube = $false; $script:DocEstado = $null; $script:DocNubeDicho = $false
    $niega = '(?i)\bno\s+(?:viene|aparece|aparecen|se\s+menciona|menciona|mencionan|indica|indican|especifica|especifican|dice|dicen|tengo|hay|encuentro|figura|incluye|incluyen|contiene|contienen|se\s+especifica|se\s+indica|se\s+detalla|detalla|detallan|consta|est[aá])|sin\s+informaci|ning[uú]n\s+dato|ninguna\s+informaci|no\s+(?:se\s+)?(?:encontr|dispon)'
    $messages = New-Object System.Collections.ArrayList
    $nuevo = { $messages.Clear(); [void]$messages.Add(@{ role = 'system'; content = 'Eres un asistente util. Responde en espanol, breve y al grano.' }) }
    $tiempos = @()
    function Pregunta($q) {
        $script:Notas.Clear()
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $viejo = [Console]::Out; [Console]::SetOut([IO.TextWriter]::Null)
        try { $null = Invoke-AITurn $q.P 0 *>&1 } finally { [Console]::SetOut($viejo) }
        $s = [Math]::Round($sw.Elapsed.TotalSeconds, 1)
        $script:tiempos += $s
        $r = [string]$messages[$messages.Count - 1].content
        if ($messages[$messages.Count - 1].role -ne 'assistant') { $r = '' }
        $consulto = @($script:Notas | Where-Object { $_ -like 'consultando tus documentos*' }).Count -gt 0
        $una = ($r -replace '\s+', ' ').Trim()
        if ($una.Length -gt 220) { $una = $una.Substring(0, 220) + '...' }
        return @{ R = $r; Una = $una; Consulto = $consulto; S = $s }
    }
    foreach ($q in $preguntas) {
        if ($q.T -ne 'sigue') { & $nuevo }
        $a = Pregunta $q
        switch ($q.T) {
            'falta' {
                # No esta: tiene que decirlo y no dar cifras ni correos inventados.
                $bien = $a.R -match $niega -and $a.R -notmatch 'C\$\s?\d|\d+\s?(?:c[oó]rdobas|d[oó]lares)|@'
                Ver ("[falta] {0}" -f $q.P) $bien "-> $($a.Una)"
            }
            'fuera' {
                $bien = -not $a.Consulto -and @($q.Dice | Where-Object { $a.R -notmatch $_ }).Count -eq 0
                Ver ("[fuera] {0}" -f $q.P) $bien "-> consulto=$($a.Consulto) $($a.Una)"
            }
            default {
                $falta = @($q.Dice | Where-Object { $a.R -notmatch $_ })
                Ver ("[$($q.T)] {0}" -f $q.P) ($a.Consulto -and $falta.Count -eq 0) "-> falta $($falta -join ' / '): $($a.Una)"
            }
        }
        Write-Output "         $($a.S) s: $($a.Una)"
    }
    # La lista de documentos, con el motivo del PDF.
    & $nuevo
    $a = Pregunta @{ P = '¿Qué documentos tienes?' }
    Ver '[lista] ¿Qué documentos tienes?' ($a.R -match 'Empleados' -and $a.R -match '(?i)apertura' -and $a.R -notmatch '(?i)pdf[^.\n]{0,60}da[ñn]ad') "-> $($a.Una)"
    Write-Output "         $($a.S) s"
    # Lo olvidado, ya no se sabe.
    $script:DocOlvidos = @((Find-AIDocOlvido $e 'Necesidades y metas 2027').Reglas)
    $script:DocEstado = $null
    & $nuevo
    $a = Pregunta @{ P = '¿Qué necesidades tiene el negocio ahora mismo?' }
    Ver '[olvido] tras olvidar Necesidades y metas 2027, ya no sabe las necesidades' ($a.R -notmatch '(?i)horno|450') "-> $($a.Una)"
    Write-Output "         $($a.S) s: $($a.Una)"
    $media = [Math]::Round((($tiempos | Measure-Object -Average).Average), 1)
    Write-Output "    tiempo por pregunta: media $media s, máximo $(($tiempos | Measure-Object -Maximum).Maximum) s"
}

Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
Write-Output ''
Write-Output "MAL = $mal de $total"
exit $mal
