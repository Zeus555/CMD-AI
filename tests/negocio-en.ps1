#requires -Version 5.1
<#
  negocio-en.ps1 - El negocio de tests\negocio.ps1, en ingles: Linden Street
  Coffee House, una cafeteria de barrio de Estados Unidos que tambien hornea
  pan y pasteles, con dos locales (Downtown y Riverside). Los mismos tipos de
  fichero, las mismas carpetas y las mismas trampas que la Panaderia La
  Espiga (un PDF escaneado en Invoices\, un sueldo que no esta, una imagen y
  un temporal de Word), con precios en dolares, horas de 12 horas (7:00 AM)
  y fechas MM/DD/YYYY. Los datos casan entre ficheros: la tarta de zanahoria
  cuesta $5.50 la porcion en el catalogo PDF y en la hoja de Excel.

  No se lanza solo: lo carga negocio.ps1 con -Idioma en, ya con sus
  ayudantes (Docx, Xlsx, Texto...), las bibliotecas y el idioma puesto:
    .\tests\negocio.ps1 -Idioma en                  procesamiento
    .\tests\negocio.ps1 -Idioma en -Modelo          y el modelo de verdad
    .\tests\negocio.ps1 -Idioma en -Crear <carpeta> solo los documentos

  Algunas comprobaciones dependen del programa en ingles (la busqueda con
  palabras vacias y sinonimos ingleses, "learn from the documents in X",
  "forget about X" y los mensajes "There are N I can read (...)",
  "Forgotten.", "checking your documents: X", "It's not in the documents.").
  Todo es inventado: nombres, direcciones y telefonos (555-01xx) no son de
  nadie. Comentarios y expresiones regulares en ASCII.
#>

# Estilos del libro de Excel a la americana: fechas mm/dd/yyyy, horas
# h:mm AM/PM y dolares (el quinto formato, el de @{ usd = 4.5 }).
$script:XlsxEstilosEn = '<styleSheet><numFmts count="3"><numFmt numFmtId="164" formatCode="mm/dd/yyyy"/><numFmt numFmtId="165" formatCode="h:mm AM/PM"/><numFmt numFmtId="166" formatCode="&quot;$&quot;#,##0.00"/></numFmts><cellXfs count="5"><xf numFmtId="0"/><xf numFmtId="164" applyNumberFormat="1"/><xf numFmtId="165" applyNumberFormat="1"/><xf numFmtId="9" applyNumberFormat="1"/><xf numFmtId="166" applyNumberFormat="1"/></cellXfs></styleSheet>'

function New-AINegocioEn {
    <#  Crea Linden Street Coffee House en $Destino. Devuelve la ruta.  #>
    param([string]$Destino)
    $n = Join-Path $Destino 'Linden Street Coffee House'
    New-Item -ItemType Directory -Path $n -Force | Out-Null
    $cafe = 'caf' + [char]0xE9

    Docx (Join-Path $n 'About us.docx') @(
        ,@('h1', 'Linden Street Coffee House')
        ,@('p', 'Linden Street Coffee House is a family-owned coffee house and bakery founded in 2012 by Ellen Porter, who is still the owner and general manager.')
        ,@('h2', 'Our mission')
        ,@('p', 'Bake fresh bread and pastries every morning, brew good coffee, and treat every customer like a neighbor.')
        ,@('h2', 'Our locations')
        ,@('p', 'We have two locations, Downtown and Riverside:')
        ,@('li', 'Downtown: 214 Linden Street, across from Founders Park.')
        ,@('li', 'Riverside: Riverside Plaza, Unit 3, 88 Mill Road.')
        ,@('h2', 'Products and services')
        ,@('p', 'Fresh bread and pastries, custom cakes, catering platters for events, and a coffee bar with locally roasted coffee.')
    )
    Xlsx (Join-Path $n 'Menu and prices.xlsx') ([ordered]@{
        'Bakery' = @(
            ,@('Item', 'Price', 'Unit', 'Effective since')
            ,@('Sourdough loaf', @{ usd = 8 }, 'loaf', @{ fecha = [datetime]'2026-10-15' })
            ,@('Baguette', @{ usd = 4.25 }, 'each', @{ fecha = [datetime]'2026-10-15' })
            ,@('Croissant', @{ usd = 3.75 }, 'each', @{ fecha = [datetime]'2026-10-15' })
            ,@('Blueberry muffin', @{ usd = 3.25 }, 'each', @{ fecha = [datetime]'2026-10-15' })
            ,@('Carrot cake', @{ usd = 5.5 }, 'slice', @{ fecha = [datetime]'2026-10-15' })
        )
        'Coffee bar' = @(
            ,@('Drink', 'Small', 'Large')
            ,@('Drip coffee', @{ usd = 2.75 }, @{ usd = 3.25 })
            ,@('Cappuccino', @{ usd = 4.25 }, @{ usd = 4.95 })
            ,@('Latte', @{ usd = 4.5 }, @{ usd = 5.25 })
            ,@('Hot chocolate', @{ usd = 3.5 }, @{ usd = 4.25 })
        )
        'Special orders' = @(
            ,@('Service', 'Days notice', 'Deposit')
            ,@('Event cakes', 3, @{ pct = 0.5 })
            ,@('Catering platter for 50 people', 5, @{ pct = 0.5 })
            ,@('Wholesale bread for businesses', 1, @{ pct = 0 })
        )
        'Hours' = @(
            ,@('Day', 'Downtown opens', 'Downtown closes', 'Riverside opens', 'Riverside closes')
            ,@('Monday to Friday', @{ hora = '6:00' }, @{ hora = '19:00' }, @{ hora = '7:00' }, @{ hora = '20:00' })
            ,@('Saturday', @{ hora = '6:00' }, @{ hora = '14:00' }, @{ hora = '7:00' }, @{ hora = '20:00' })
            ,@('Sunday', 'closed', 'closed', @{ hora = '8:00' }, @{ hora = '13:00' })
        )
    }) $script:XlsxEstilosEn
    # Con comas, como lo guarda Excel en ingles. Megan Reyes no tiene la paga
    # puesta: es la pregunta que no esta en los documentos.
    Texto (Join-Path $n 'Employees.csv') ("Name,Role,Location,Shift,Start date,Extension,Hourly pay`n" +
        "Ellen Porter,General manager,Downtown,Morning,03/15/2012,101,`$32.00`n" +
        "Daniel Brooks,Head baker,Downtown,Early morning,07/01/2014,102,`$24.50`n" +
        "Megan Reyes,Cashier,Downtown,Morning,02/11/2019,103,`n" +
        "Anna Walsh,Store manager,Riverside,Morning,05/20/2017,200,`$26.00`n" +
        "Jordan Hayes,Barista,Riverside,Afternoon,09/06/2021,201,`$17.50`n" +
        "Marcus Diaz,Baker's assistant,Downtown,Early morning,01/09/2023,104,`$16.75`n")
    Docx (Join-Path $n 'Human resources\Vacation and leave.docx') @(
        ,@('h1', 'Vacation and leave policy')
        ,@('h2', 'Vacation')
        ,@('p', 'Every employee gets 10 paid vacation days for each year worked, starting after the first year.')
        ,@('p', 'Vacation requests go in writing to the general manager 30 days in advance.')
        ,@('p', 'No more than two people from the same location can be on vacation at the same time.')
        ,@('p', 'No vacation is given in December: it is our busiest season.')
        ,@('h2', 'Leave')
        ,@('li', "Sick leave: call before your shift and bring a doctor's note within 48 hours.")
        ,@('li', 'Personal leave: up to 2 paid days a year, requested one week in advance.')
    )
    Odt (Join-Path $n 'Human resources\Employee handbook.odt') @(
        ,@('h1', 'Employee handbook')
        ,@('h2', 'Uniform')
        ,@('p', 'Brown apron with the logo, a cap or hairnet in the kitchen, and closed-toe shoes.')
        ,@('h2', 'Punctuality')
        ,@('p', 'There is a 10-minute grace period. Three late arrivals in the same month mean a written warning.')
        ,@('h2', 'Conduct')
        ,@('li', 'Phones are not allowed in the kitchen.')
        ,@('li', 'Smoking is not allowed anywhere on the premises.')
        ,@('li', 'The lunch break is 30 minutes.')
    )
    Docx (Join-Path $n 'Procedures\Opening and closing.docx') @(
        ,@('h1', 'Opening and closing a location')
        ,@('h2', 'Opening')
        ,@('li', 'At 4:00 AM the head baker turns on the ovens.')
        ,@('li', 'At 5:30 AM the display cases and the counter are cleaned.')
        ,@('li', 'At 5:45 AM the cashier counts the starting cash in the register: $200.')
        ,@('li', 'Each location opens to the public at the time on its schedule.')
        ,@('h2', 'Closing')
        ,@('li', 'The register is balanced and the cash goes into the safe.')
        ,@('li', 'The ovens are turned off and the final temperature of the coolers is written down.')
        ,@('li', 'The alarm is set; only the store manager and the general manager have the code.')
        ,@('h2', 'Who opens and who closes')
        ,@('tabla', @(@('Location', 'Who opens', 'Who closes'), @('Downtown', 'Daniel Brooks', 'Megan Reyes'), @('Riverside', 'Anna Walsh', 'Jordan Hayes')))
    )
    Texto (Join-Path $n 'Procedures\Handling complaints.md') @'
# Handling complaints

1. Listen to the customer kindly and without arguing.
2. Log the complaint in the location's complaint book.
3. If a product was not in good condition, replace it or refund the money with the receipt.
4. If the customer is still not satisfied, call the store manager or the general manager.

## Deadlines
- We resolve every complaint within 48 hours at most.
- If the customer asks for a written answer, it is delivered within 5 business days.
'@
    # En Windows-1252, como el Bloc de notas antiguo: la e de cafe lo dice.
    Texto (Join-Path $n 'Procedures\Event orders.txt') ("EVENT ORDERS`r`n" +
        "Event cakes must be ordered at least 3 days in advance.`r`n" +
        "A 50% deposit confirms the order.`r`n" +
        "If the customer cancels more than 48 hours ahead, the full deposit (100%) is refunded.`r`n" +
        "If the customer cancels less than 48 hours ahead, 50% of the deposit is refunded.`r`n" +
        "Orders can be placed at the $cafe register or by text message at (555) 014-2200.`r`n") ([Text.Encoding]::GetEncoding(1252))
    Pptx (Join-Path $n 'Needs and goals 2027.pptx') @(
        ,@('Current needs of the business', 'A second commercial oven, with a budget of $18,000.', 'Two more weekend staff for the Riverside location.', 'A digital inventory system.', 'Repair the walk-in cooler at the Downtown location.')
        ,@('Goals for 2027', 'Open a third location in the second half of 2027.', 'Grow coffee bar sales by 20%.', 'Food handler training for all staff before March 2027.')
    )
    Texto (Join-Path $n 'Suppliers.html') @'
<html><head><title>Suppliers</title><script>var supplier = "Fake supplier";</script></head><body>
<h1>Suppliers</h1>
<table>
<tr><th>Item</th><th>Supplier</th><th>Delivery days</th></tr>
<tr><td>Flour</td><td>Northfield Mills</td><td>Monday and Thursday</td></tr>
<tr><td>Coffee beans</td><td>Hillcrest Roasting Co.</td><td>every two weeks</td></tr>
<tr><td>Dairy</td><td>Clover Valley Dairy</td><td>daily at 5:00 AM</td></tr>
<tr><td>Eggs</td><td>Sunny Acres Farm</td><td>Tuesday and Friday</td></tr>
</table></body></html>
'@
    Texto (Join-Path $n 'Food safety.rtf') ('{\rtf1\ansi\deff0{\fonttbl{\f0 Arial;}}{\*\generator Test;}\f0 FOOD SAFETY\par ' +
        'Refrigerators are kept between 33 and 40 \''b0F and freezers at 0 \''b0F or below.\par ' +
        'Temperatures are written in the log book every 4 hours.\par ' +
        'Every product in the caf\''e9 display has a label with the date it was made.\par ' +
        'Any bread we don''t sell by closing is donated to the Eastside Community Pantry; it is never sold the next day.\par}') ([Text.Encoding]::ASCII)
    Ods (Join-Path $n 'Minimum inventory.ods') 'Inventory' @(
        @('Item', 'Minimum', 'Unit'), @('Flour', '20', '50-lb bags'), @('Sugar', '5', '50-lb bags'),
        @('Eggs', '30', 'dozen'), @('Coffee beans', '15', 'pounds'), @('Milk', '40', 'gallons'))
    # Un PDF de verdad (comprimido, con titulos y dos tablas) y otro que es
    # solo una imagen, como una factura escaneada.
    $x3 = @(72, 280, 380)
    New-AIPdfPrueba (Join-Path $n 'Cakes and pastries catalog.pdf') @(,@(
        @{ T = 'Cakes and pastries catalog'; Tam = 20; F = 'B' }
        @{ T = 'All our cakes are baked at the Downtown location with fresh ingredients.'; Hueco = 8 }
        @{ T = 'Whole cakes must be ordered 3 days in advance.' }
        @{ T = 'Prices'; Tam = 14; F = 'B'; Hueco = 12 }
        @{ Celdas = @('Cake', 'Slice', 'Whole (12 slices)'); X = $x3; F = 'B' }
        @{ Celdas = @('Carrot cake', '$5.50', '$48.00'); X = $x3 }
        @{ Celdas = @('Chocolate hazelnut', '$6.25', '$58.00'); X = $x3 }
        @{ Celdas = @('Lemon blueberry', '$5.75', '$52.00'); X = $x3 }
        @{ Celdas = @('Black Forest', '$6.50', '$62.00'); X = $x3 }
        @{ T = 'Pastries'; Tam = 14; F = 'B'; Hueco = 12 }
        @{ Celdas = @('Pastry', 'Each', 'Dozen'); X = $x3; F = 'B' }
        @{ Celdas = @('Croissant', '$3.75', '$40.00'); X = $x3 }
        @{ Celdas = @('Blueberry muffin', '$3.25', '$34.00'); X = $x3 }
        @{ Celdas = @('Cinnamon roll', '$4.00', '$42.00'); X = $x3 }
        @{ T = 'Decorations'; Tam = 14; F = 'B'; Hueco = 12 }
        @{ T = 'A name or message on the cake is free.'; Kern = $true }
        @{ T = 'An edible photo costs $12.00 extra.' }
        @{ T = 'Fondant figures are quoted separately, depending on the design.' }
    )) -Comprimir
    New-AIPdfPrueba (Join-Path $n 'Invoices\Flour invoice November.pdf') @(,@(@{ T = 'x' })) -Imagen
    Texto (Join-Path $n 'logo.png') 'not an image'
    Texto (Join-Path $n 'Procedures\~$Opening and closing.docx') 'Word temp file'
    return $n
}

$mal = 0; $total = 0
function Ver([string]$que, [bool]$ok, $extra = '') { $script:total++; if ($ok) { Write-Output "  ok   $que" } else { $script:mal++; Write-Output "  MAL  $que  $extra" } }

if ($Crear) { New-AINegocioEn $Crear; return }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('business-' + [Guid]::NewGuid().ToString('N').Substring(0, 6))
$neg = New-AINegocioEn $tmp
$cache = Join-Path $tmp 'cache'
$carpetas = @([pscustomobject]@{ Nombre = 'linden-street'; Ruta = $neg; Tema = 'Linden Street Coffee House: menu, prices, employees, hours, policies, procedures, needs and goals'; Creado = '' })

# ===========================================================================
#  1. Procesamiento: que se lee de cada fichero
# ===========================================================================
Write-Output '=== processing: reading'
$sw = [Diagnostics.Stopwatch]::StartNew()
$e = Update-AIDocIndice $carpetas $cache $null $null
$ok = @($e.Ficheros | Where-Object { $_.Estado -eq 'ok' })
$no = @($e.Ficheros | Where-Object { $_.Estado -ne 'ok' })
Write-Output "    $($ok.Count) read, $($e.Indice.N) chunks, $([Math]::Round($sw.Elapsed.TotalSeconds, 1)) s"
Ver 'the thirteen documents it can read' ($ok.Count -eq 13) (@($ok | ForEach-Object { $_.Fichero }) -join ', ')
Ver 'not the scanned PDF, with its reason (in English)' ($no.Count -eq 1 -and $no[0].Fichero -like 'Invoices\*.pdf' -and $no[0].Motivo -match '(?i)scann') (@($no | ForEach-Object { "$($_.Fichero): $($_.Motivo)" }) -join ' / ')
Ver 'not even the image or the Word temp file' ($e.Otros -eq 1 -and @($e.Ficheros | Where-Object { $_.Fichero -match '~\$' }).Count -eq 0)
$censo = Get-AIDocCenso $neg
Ver 'the census: 14 it can read, the scanned PDF included' ($censo.Leibles -eq 14) "Leibles=$($censo.Leibles)"
$txt = @{}
foreach ($f in $ok) { $txt[$f.Fichero] = [IO.File]::ReadAllText((Join-Path $cache "textos\$($f.Clave).txt"), [Text.Encoding]::UTF8) }
function Lee($fich, $que, $patrones) { $t = [string]$txt[$fich]; $falta = @($patrones | Where-Object { $t -notmatch $_ }); Ver ("{0,-40} {1}" -f $fich, $que) ($falta.Count -eq 0) ("missing: $($falta -join ' / ')") }
# Excel: las horas y fechas de la hoja tienen formato americano (h:mm AM/PM,
# mm/dd/yyyy); se aceptan tambien como las da hoy el programa (08:00,
# 15/10/2026). Los dolares de la hoja salen como cifra (4.95) o con $.
$h8 = '(?:08:00|8:00 AM)'; $f15 = '(?:10/15/2026|15/10/2026)'
Lee 'About us.docx' 'Word titles and lists' @('(?m)^# Linden Street Coffee House$', '(?m)^## Our locations$', '(?m)^- Riverside: Riverside Plaza, Unit 3, 88 Mill Road\.$')
Lee 'Menu and prices.xlsx' 'Excel sheets, prices and dates' @('## (?:Hoja|Sheet): Bakery', 'Drink: Cappuccino \| Small: \$?4\.25 \| Large: \$?4\.95', "Item: Croissant \| Price: \`$?3\.75 \| Unit: each \| Effective since: $f15")
Lee 'Menu and prices.xlsx' 'Excel percentages' @('Service: Event cakes \| Days notice: 3 \| Deposit: 50%', 'Deposit: 0%')
Lee 'Menu and prices.xlsx' 'Excel times and text cells' @("Day: Sunday \| Downtown opens: closed \| Downtown closes: closed \| Riverside opens: $h8 \| Riverside closes: (?:13:00|1:00 PM)", 'Day: Monday to Friday \| Downtown opens: (?:06:00|6:00 AM) \| Downtown closes: (?:19:00|7:00 PM)')
Lee 'Employees.csv' 'CSV with commas and $' @('Name: Jordan Hayes \| Role: Barista \| Location: Riverside \| Shift: Afternoon \| Start date: 09/06/2021 \| Extension: 201 \| Hourly pay: \$17\.50', '(?m)^Name: Megan Reyes \| Role: Cashier \| Location: Downtown \| Shift: Morning \| Start date: 02/11/2019 \| Extension: 103\s*$')
Lee 'Human resources\Vacation and leave.docx' 'Word sections' @('(?m)^## Vacation$', '10 paid vacation days', '(?m)^- Personal leave: up to 2 paid days')
Lee 'Human resources\Employee handbook.odt' 'OpenDocument with lists' @('(?m)^## Punctuality$', 'written warning', '- Phones are not allowed in the kitchen')
Lee 'Procedures\Opening and closing.docx' 'Word table without figures' @('Columnas \(primera fila\): Location \| Who opens \| Who closes|Columns \(first row\): Location \| Who opens \| Who closes', '(?m)^Riverside \| Anna Walsh \| Jordan Hayes$', 'register: \$200\.')
Lee 'Procedures\Handling complaints.md' 'Markdown' @('(?m)^## Deadlines$', '48 hours', '5 business days')
Lee 'Procedures\Event orders.txt' 'Windows-1252 text' @('at least 3 days', 'less than 48 hours ahead, 50% of the deposit', 'caf\u00E9 register')
Lee 'Needs and goals 2027.pptx' 'slides in order' @('(?s)Current needs.*Goals for 2027', '\$18,000')
Lee 'Suppliers.html' 'HTML table without the code' @('Flour\s+Northfield Mills\s+Monday and Thursday')
Lee 'Food safety.rtf' 'RTF with degrees and accents' @('between 33 and 40 \u00B0F', '0 \u00B0F or below', 'caf\u00E9 display', 'next day')
Lee 'Minimum inventory.ods' 'OpenDocument sheet' @('## (?:Hoja|Sheet): Inventory', 'Item: Flour \| Minimum: 20 \| Unit: 50-lb bags')
Lee 'Cakes and pastries catalog.pdf' 'PDF: titles, tables and spaces' @('(?m)^# Cakes and pastries catalog$', '(?m)^## Prices$', '(?m)^Cake \| Slice \| Whole \(12 slices\)$', '(?m)^Carrot cake \| \$5\.50 \| \$48\.00$', '(?m)^Croissant \| \$3\.75 \| \$40\.00$', 'A name or message on the cake is free\.')
Ver 'the page code does not leak in' ([string]$txt['Suppliers.html'] -notmatch 'Fake supplier')

# ===========================================================================
#  2. Procesamiento: que cada pregunta encuentre su documento
# ===========================================================================
# Como en negocio.ps1: T dato, falta (no esta: hay que decirlo), fuera (no va
# de los documentos) o sigue (va con la pregunta anterior); F el documento,
# Viaja lo que tiene que llegar al modelo y Dice lo que tiene que contestar.
$preguntas = @(
    @{ T = 'dato'; P = 'Who founded the coffee house and in what year?'; F = 'About us.docx'; Viaja = 'Ellen Porter'; Dice = @('Ellen Porter', '2012') }
    @{ T = 'dato'; P = 'How many locations do you have and where are they?'; F = 'About us.docx'; Viaja = 'Riverside Plaza'; Dice = @('Downtown', 'Riverside', 'Linden|Mill') }
    @{ T = 'dato'; P = 'What time does the Riverside location open on Sundays?'; F = 'Menu and prices.xlsx'; Viaja = "Riverside opens: $h8"; Dice = @('(?i)\b8(?::00)?\s?(?:a\.?\s?m\b|o.clock)|\b08:00\b|\b8:00\b') }
    @{ T = 'dato'; P = 'Is the Downtown location open on Sundays?'; F = 'Menu and prices.xlsx'; Viaja = 'Downtown opens: closed'; Dice = @('(?i)closed|not open|\bno\b') }
    @{ T = 'dato'; P = 'How much is a large cappuccino?'; F = 'Menu and prices.xlsx'; Viaja = 'Large: \$?4\.95'; Dice = @('4\.95') }
    @{ T = 'dato'; P = 'Since when have the bakery prices been in effect?'; F = 'Menu and prices.xlsx'; Viaja = "Effective since: $f15"; Dice = @('(?i)10/15/2026|October 15') }
    @{ T = 'dato'; P = 'How many days ahead do I need to order a catering platter for 50 people?'; F = 'Menu and prices.xlsx'; Viaja = 'Catering platter for 50 people'; Dice = @('(?i)\b5\b|five') }
    @{ T = 'dato'; P = 'Who is the head baker and what shift does he work?'; F = 'Employees.csv'; Viaja = 'Daniel Brooks'; Dice = @('Daniel Brooks', '(?i)early morning') }
    @{ T = 'dato'; P = "What is Anna Walsh's extension?"; F = 'Employees.csv'; Viaja = 'Anna Walsh'; Dice = @('\b200\b') }
    @{ T = 'dato'; P = 'How much does Jordan Hayes make per hour?'; F = 'Employees.csv'; Viaja = 'Hourly pay: \$17\.50'; Dice = @('17\.50') }
    @{ T = 'dato'; P = 'How many vacation days do I get, and how far in advance do I ask for them?'; F = 'Human resources\Vacation and leave.docx'; Viaja = '10 paid vacation days'; Dice = @('\b10\b|\bten\b', '\b30\b|thirty') }
    @{ T = 'dato'; P = 'Can I take vacation in December?'; F = 'Human resources\Vacation and leave.docx'; Viaja = 'December'; Dice = @('(?i)\bno\b|\bnot\b|n.t\b') }
    @{ T = 'dato'; P = "What happens if I'm late three times in a month?"; F = 'Human resources\Employee handbook.odt'; Viaja = 'written warning'; Dice = @('(?i)written warning') }
    @{ T = 'dato'; P = 'Can I use my phone in the kitchen?'; F = 'Human resources\Employee handbook.odt'; Viaja = 'Phones are not allowed'; Dice = @('(?i)\bno\b|not allowed|n.t\b') }
    @{ T = 'dato'; P = 'How much starting cash goes in the register at opening?'; F = 'Procedures\Opening and closing.docx'; Viaja = '\$200'; Dice = @('\b200\b') }
    @{ T = 'dato'; P = 'Who closes the Riverside location?'; F = 'Procedures\Opening and closing.docx'; Viaja = 'Jordan Hayes'; Dice = @('Jordan Hayes') }
    @{ T = 'dato'; P = 'How quickly do we have to resolve a complaint?'; F = 'Procedures\Handling complaints.md'; Viaja = '48 hours'; Dice = @('48') }
    @{ T = 'dato'; P = 'If a customer cancels a cake one day ahead, how much do they get back?'; F = 'Procedures\Event orders.txt'; Viaja = 'less than 48 hours'; Dice = @('50') }
    @{ T = 'dato'; P = 'What does the business need right now?'; F = 'Needs and goals 2027.pptx'; Viaja = 'second commercial oven'; Dice = @('(?i)oven', '(?i)inventory|staff|people|cooler') }
    @{ T = 'dato'; P = 'How much does the oven we need cost?'; F = 'Needs and goals 2027.pptx'; Viaja = '18,000'; Dice = @('(?i)18,000|18000|18 thousand|18k') }
    @{ T = 'dato'; P = 'What are the goals for 2027?'; F = 'Needs and goals 2027.pptx'; Viaja = 'third location'; Dice = @('(?i)third location') }
    @{ T = 'dato'; P = 'What days does the flour arrive?'; F = 'Suppliers.html'; Viaja = 'Northfield Mills'; Dice = @('(?i)monday', '(?i)thursday') }
    @{ T = 'dato'; P = 'What temperature should the refrigerators be at?'; F = 'Food safety.rtf'; Viaja = 'between 33 and 40'; Dice = @('\b33\b', '\b40\b') }
    @{ T = 'dato'; P = "What do we do with the bread we don't sell?"; F = 'Food safety.rtf'; Viaja = 'Community Pantry'; Dice = @('(?i)donat') }
    @{ T = 'dato'; P = 'How much is a whole carrot cake?'; F = 'Cakes and pastries catalog.pdf'; Viaja = 'Carrot cake \| \$5\.50 \| \$48\.00'; Dice = @('\b48\b') }
    @{ T = 'dato'; P = 'How much do you charge to put a photo on the cake?'; F = 'Cakes and pastries catalog.pdf'; Viaja = 'edible photo'; Dice = @('\b12\b') }
    @{ T = 'dato'; P = "What's the minimum amount of flour we should have in inventory?"; F = 'Minimum inventory.ods'; Viaja = 'Minimum: 20'; Dice = @('\b20\b', '(?i)bag') }
    @{ T = 'falta'; P = 'How much does Megan Reyes make?' }
    @{ T = 'falta'; P = 'Do you take credit cards?' }
    @{ T = 'falta'; P = 'Do you offer delivery?' }
    @{ T = 'falta'; P = "What is the general manager's email address?" }
    @{ T = 'dato'; P = 'What time does the Downtown location open on weekdays?'; F = 'Menu and prices.xlsx'; Viaja = 'Downtown opens: (?:06:00|6:00 AM)'; Dice = @('(?i)\b6(?::00)?\s?(?:a\.?\s?m\b|o.clock)|\b06:00\b|\b6:00\b') }
    @{ T = 'sigue'; P = 'And on Saturdays?'; F = 'Menu and prices.xlsx'; Viaja = 'Saturday'; Dice = @('(?i)\b6(?::00)?\s?(?:a\.?\s?m\b|o.clock)|\b06:00\b|\b6:00\b') }
    @{ T = 'fuera'; P = 'What is the capital of France?'; Dice = @('(?i)paris') }
    @{ T = 'fuera'; P = 'Write a short poem about the sea' }
)

Write-Output ''
Write-Output '=== processing: each question finds its document'
$ix = $e.Indice
$previa = ''
foreach ($q in $preguntas) {
    $h = Find-AIDocTrozos $ix $q.P $(if ($q.T -eq 'sigue') { $previa } else { '' })
    $llega = ($h.Trozos | ForEach-Object { $_.Texto }) -join "`n"
    switch ($q.T) {
        'fuera' { Ver ("{0,-74} -> nothing" -f $q.P) (-not $h.Relevante) "cov=$($h.Cobertura) $(@($h.Trozos)[0].Fichero)" }
        'falta' { Write-Output ("  --   {0,-74} (not in the documents: {1})" -f $q.P, $(if ($h.Relevante) { 'sends ' + ((@($h.Trozos | ForEach-Object { $_.Fichero } | Select-Object -Unique)) -join ', ') } else { 'sends nothing' })) }
        default {
            $bien = $h.Relevante -and @($h.Trozos | Where-Object { $_.Fichero -eq $q.F }).Count -and $llega -match $q.Viaja
            Ver ("{0,-74} -> {1}" -f $q.P, $q.F) $bien "relevant=$($h.Relevante) cov=$($h.Cobertura) sent: $((@($h.Trozos | ForEach-Object { $_.Fichero })) -join ', ')"
        }
    }
    $previa = $q.P
}

Write-Output ''
Write-Output '=== processing: forgetting'
$o = Find-AIDocOlvido $e 'Needs and goals 2027'
Ver 'forget "Needs and goals 2027" -> that document' ($o.Tipo -eq 'fichero') $o.Que
$o2 = Find-AIDocOlvido $e 'Leave'
Ver 'forget "Leave" -> that section' ($o2.Tipo -eq 'apartado' -and $o2.Reglas[0].Apartado -eq 'Vacation and leave policy > Leave') $o2.Que
$o3 = Find-AIDocOlvido $e 'extension'
Ver 'forget "extension" -> only that field of each employee' ($o3.Tipo -eq 'tema' -and $o3.Trozos -eq 6) $o3.Que
$eo = Update-AIDocIndice $carpetas $cache $null $e (@($o.Reglas) + @($o2.Reglas) + @($o3.Reglas))
$todo = $eo.Indice.Texto -join "`n"
Ver 'what was forgotten is gone' ($todo -notmatch 'commercial oven|Personal leave|Extension: \d')
Ver 'and the rest is still there' ($todo -match 'Name: Anna Walsh \| Role: Store manager' -and $todo -match '10 paid vacation days' -and $todo -match 'Cappuccino')
$h = Find-AIDocTrozos $eo.Indice 'What does the business need right now?'
Ver 'the needs question no longer brings the forgotten document' (@($h.Trozos | Where-Object { $_.Fichero -like 'Needs*' }).Count -eq 0)
$h = Find-AIDocTrozos $eo.Indice "What is Anna Walsh's extension?"
Ver 'asked again, the extension no longer travels' ((($h.Trozos | ForEach-Object { $_.Texto }) -join "`n") -notmatch 'Extension: \d')
$eo = $null
$e = Update-AIDocIndice $carpetas $cache $null $null

# ===========================================================================
#  3. Lo que dice el programa al aprender y al olvidar, sin modelo: las
#     funciones de bin\ai.ps1 con las respuestas del usuario ya escritas.
# ===========================================================================
Write-Output ''
Write-Output '=== processing: learning and forgetting, in the program''s words'
foreach ($l in 'core', 'ui') { . (Join-Path $root "lib\$l.ps1") }
foreach ($k in @($AI_COLOR.Keys)) { $AI_COLOR[$k] = '' }
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'bin\ai.ps1'), [ref]$null, [ref]$null)
foreach ($f in 'Get-AIDocsEstado', 'Add-AIDocCarpeta', 'Start-AIDocOlvido') {
    $d = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $f }, $true)
    . ([scriptblock]::Create($d.Extent.Text))
}
$script:Respuestas = New-Object 'System.Collections.Generic.Queue[string]'
function Read-AILine { param([string]$Prompt, $UsePRL) if ($script:Respuestas.Count) { return $script:Respuestas.Dequeue() }; return $null }
function Invoke-AIDialogo([scriptblock]$Que, [string[]]$Contesta) {
    # Lo que escribe el programa (Write-Host y errores) como texto.
    $script:Respuestas.Clear(); foreach ($x in $Contesta) { $script:Respuestas.Enqueue($x) }
    $viejo = [Console]::Out; $viejoE = [Console]::Error
    $err = New-Object IO.StringWriter
    [Console]::SetOut([IO.TextWriter]::Null); [Console]::SetError($err)
    try { $s = (& $Que 6>&1 2>&1 | Out-String -Width 4096) } finally { [Console]::SetOut($viejo); [Console]::SetError($viejoE) }
    return $s + $err.ToString()
}
$rotulo = 'ai > '; $user = 'Tester'
$DocDir = Join-Path $tmp 'cache-dialog'
$DocFile = Join-Path $tmp 'documentos.json'; $OlvFile = Join-Path $tmp 'documentos-olvidos.json'
$script:DocCarpetas = @(); $script:DocOlvidos = @(); $script:DocMal = ''; $script:DocEstado = $null; $script:DocsNube = $false
$prov = [pscustomobject]@{ BaseUrl = 'http://127.0.0.1:8080/v1'; Label = 'Gemma'; Model = '' }
$messages = New-Object System.Collections.ArrayList
$pide = "learn from the documents in $neg"
$dp = Get-AIDocPeticion $pide
Ver '"learn from the documents in <folder>" -> that folder' ($dp -and $dp.Ruta -eq $neg) $(if ($dp) { "-> '$($dp.Ruta)'" } else { '-> not recognized' })
$dicho = Invoke-AIDialogo { Add-AIDocCarpeta $neg $pide $false } @($carpetas[0].Tema)
$linea = @($dicho -split "`r?`n" | Where-Object { $_ -match '\(\d+ Word' }) | Select-Object -First 1
Write-Output "    $linea"
Ver 'the learning summary: "There are 14 I can read (...)"' ($dicho -match 'There are 14 I can read \(') "-> $linea"
Ver 'and the folder is learned, with its 13 documents' ($script:DocCarpetas.Count -eq 1 -and $script:DocEstado -and @($script:DocEstado.Ficheros | Where-Object { $_.Estado -eq 'ok' }).Count -eq 13)
$op = Get-AIDocOlvidoPeticion 'forget about the extension'
Ver '"forget about the extension" -> forget the extension' ($op -and -not $op.Todo -and $op.Que -match '^(?:the\s+)?extensions?$') $(if ($op) { "-> Todo=$($op.Todo) Que='$($op.Que)'" } else { '-> not recognized' })
$dicho = Invoke-AIDialogo { Start-AIDocOlvido $(if ($op -and $op.Que) { $op.Que } else { 'extension' }) $false $false } @('yes')
$linea = @($dicho -split "`r?`n" | Where-Object { $_ -match '(?i)forgotten|olvidado' }) | Select-Object -First 1
Write-Output "    $linea"
Ver 'it says "Forgotten."' ($dicho -match '(?m)\bForgotten\.') "-> $linea"
$h = if ($script:DocEstado) { Find-AIDocTrozos $script:DocEstado.Indice "What is Anna Walsh's extension?" } else { @{ Trozos = @() } }
Ver 'and asked again, the extension no longer travels' ($script:DocOlvidos.Count -eq 1 -and (($h.Trozos | ForEach-Object { $_.Texto }) -join "`n") -notmatch 'Extension: \d')
$script:DocCarpetas = @(); $script:DocOlvidos = @(); $script:DocEstado = $null

# ===========================================================================
#  4. Conocimiento: las preguntas al modelo de verdad (-Modelo)
# ===========================================================================
if ($Modelo) {
    Write-Output ''
    Write-Output "=== knowledge, with $Proveedor"
    foreach ($l in 'core', 'ui', 'comandos', 'consultas', 'preferencias') { . (Join-Path $root "lib\$l.ps1") }
    foreach ($k in @($AI_COLOR.Keys)) { $AI_COLOR[$k] = '' }
    foreach ($f in 'Get-AITurnMessages', 'Invoke-AITurn', 'Get-AIDocsEstado') {
        $d = $ast.Find({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $f }, $true)
        . ([scriptblock]::Create($d.Extent.Text))
    }
    # Los avisos se apuntan: "checking your documents" dice si viajaron.
    $script:Notas = New-Object System.Collections.Generic.List[string]
    function Write-AINote { param([string]$Text, [int]$PrefixWidth = 0, [switch]$Reprefix) $script:Notas.Add($Text) }
    $prov = Resolve-AIProvider $Proveedor; $Model = $prov.Model
    $Temp = 0.7; $Plain = $true; $NoStream = $true
    $script:Web = $false; $script:Equipo = $false; $script:ComandosOn = $false
    $script:SinHerramientas = @{}; $rotulo = 'ai > '
    $script:Comandos = @(); $script:Preferencias = @()
    $DocDir = $cache
    $script:DocCarpetas = $carpetas; $script:DocOlvidos = @()
    $script:DocsOn = $true; $script:DocsNube = $false; $script:DocEstado = $null; $script:DocNubeDicho = $false
    # Que no viene en los documentos, dicho de las formas de siempre; la del
    # programa es "It's not in the documents."
    $niega = '(?i)not in the documents|\bnot\s+(?:in|listed|mentioned|included|specified|stated|given|available|found|covered|provided)\b|\b(?:doesn.t|does not|don.t|do not|isn.t|is not|aren.t|are not)\s+(?:say|mention|list|include|specify|state|appear|have|contain|show|cover|provide)|\bno\s+(?:information|mention|record|data|details?)\b|\b(?:can.t|cannot|couldn.t|could not)\s+find'
    $messages = New-Object System.Collections.ArrayList
    $nuevo = { $messages.Clear(); [void]$messages.Add(@{ role = 'system'; content = 'You are a helpful assistant. Answer in English, briefly and to the point.' }) }
    $tiempos = @(); $citas = 0; $datos = 0
    function Pregunta($q) {
        $script:Notas.Clear()
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $viejo = [Console]::Out; [Console]::SetOut([IO.TextWriter]::Null)
        try { $null = Invoke-AITurn $q.P 0 *>&1 } finally { [Console]::SetOut($viejo) }
        $s = [Math]::Round($sw.Elapsed.TotalSeconds, 1)
        $script:tiempos += $s
        $r = [string]$messages[$messages.Count - 1].content
        if ($messages[$messages.Count - 1].role -ne 'assistant') { $r = '' }
        $consulto = @($script:Notas | Where-Object { $_ -like 'checking your documents*' }).Count -gt 0
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
                $bien = $a.R -match $niega -and $a.R -notmatch '\$\s?\d|\d+\s?dollars|@'
                Ver ("[missing] {0}" -f $q.P) $bien "-> $($a.Una)"
            }
            'fuera' {
                $bien = -not $a.Consulto -and @($q.Dice | Where-Object { $a.R -notmatch $_ }).Count -eq 0
                Ver ("[outside] {0}" -f $q.P) $bien "-> checked=$($a.Consulto) $($a.Una)"
            }
            default {
                $falta = @($q.Dice | Where-Object { $a.R -notmatch $_ })
                Ver ("[$($q.T)] {0}" -f $q.P) ($a.Consulto -and $falta.Count -eq 0) "-> missing $($falta -join ' / '): $($a.Una)"
                # Si dice de donde sale: "This comes from the document X, section "Y"."
                $datos++; if ($a.R -match '(?i)comes from the document|\bfrom\s+(?:the\s+)?(?:document\s+)?"?' + [regex]::Escape([IO.Path]::GetFileNameWithoutExtension($q.F))) { $citas++ }
            }
        }
        Write-Output "         $($a.S) s: $($a.Una)"
    }
    Write-Output "    answers that say which document they come from: $citas of $datos"
    # La lista de documentos, con el motivo del PDF.
    & $nuevo
    $a = Pregunta @{ P = 'What documents do you have?' }
    Ver '[list] What documents do you have?' ($a.R -match 'Employees' -and $a.R -match '(?i)opening' -and $a.R -notmatch '(?i)pdf[^.\n]{0,60}(?:damaged|corrupt)') "-> $($a.Una)"
    Write-Output "         $($a.S) s"
    # Lo olvidado, ya no se sabe.
    $script:DocOlvidos = @((Find-AIDocOlvido $e 'Needs and goals 2027').Reglas)
    $script:DocEstado = $null
    & $nuevo
    $a = Pregunta @{ P = 'What does the business need right now?' }
    Ver '[forget] after forgetting Needs and goals 2027, it no longer knows the needs' ($a.R -notmatch '(?i)oven|18,000') "-> $($a.Una)"
    Write-Output "         $($a.S) s: $($a.Una)"
    $script:DocOlvidos = @((Find-AIDocOlvido $e 'extension').Reglas)
    $script:DocEstado = $null
    & $nuevo
    $a = Pregunta @{ P = "What is Anna Walsh's extension?" }
    Ver '[forget] after forgetting the extension, asked again, it says it is not there' ($a.R -notmatch '\b200\b' -and $a.R -match $niega) "-> $($a.Una)"
    Write-Output "         $($a.S) s: $($a.Una)"
    $media = [Math]::Round((($tiempos | Measure-Object -Average).Average), 1)
    Write-Output "    time per question: average $media s, max $(($tiempos | Measure-Object -Maximum).Maximum) s"
}

Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
Write-Output ''
Write-Output "MAL = $mal de $total"
