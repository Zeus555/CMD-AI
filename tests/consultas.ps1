# Consultas web guardadas (lib\consultas.ps1): sacar datos de una pagina por
# sus rotulos, el JSON, lo que se guarda en comandos.json y lo que propone el
# modelo. Sin red, con una pagina de ejemplo (datos\consulta.html). Con -Red,
# ademas la pagina de verdad de la Loteria Nacional de Nicaragua.
param([string]$Raiz = (Split-Path -Parent $PSScriptRoot), [switch]$Red)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$root = $Raiz
. (Join-Path $root 'lib\web.ps1'); . (Join-Path $root 'lib\equipo.ps1'); . (Join-Path $root 'lib\comandos.ps1'); . (Join-Path $root 'lib\consultas.ps1')
$mal = 0; $n = 0
function Ver([string]$que, [bool]$ok, $extra = '') { $script:n++; if ($ok) { Write-Output "  ok   $que" } else { $script:mal++; Write-Output "  MAL  $que  $extra" } }
function C([string]$campo, [string]$rotulo) { [pscustomobject]@{ Campo = $campo; Rotulo = $rotulo } }

# ---- buscar un rotulo -------------------------------------------------------
$e = [char]0xE9
Ver 'rotulo: sin mirar mayusculas'      ((Find-AIRotulo 'GANADOR: 1' 'Ganador:') -eq 0)
Ver 'rotulo: sin mirar acentos'         ((Find-AIRotulo "Pr${e}stamo 5" 'prestamo') -eq 0)
Ver 'rotulo: no parte palabras'         ((Find-AIRotulo 'Premios especiales' 'Premio') -eq -1)
Ver 'rotulo: dentro de la fila'         ((Find-AIRotulo 'Fecha 1 Ganador 2' 'Ganador') -eq 8)
Ver 'rotulo: desde una posicion'        ((Find-AIRotulo 'a: 1 a: 2' 'a:' 1) -eq 5)
Ver 'rotulo: que no esta'               ((Find-AIRotulo 'nada' 'Ganador') -eq -1)

# ---- reglas de los campos ----------------------------------------------------
Ver 'campos: valen'                     (-not (Test-AIConsultaCampos @((C 'sorteo' 'Sorteo'), (C 'ganador' 'Ganador:'))))
Ver 'campos: ninguno'                   ([bool](Test-AIConsultaCampos @()))
Ver 'campos: nombre con mayusculas'     ([bool](Test-AIConsultaCampos @((C 'Sorteo' 'Sorteo'))))
Ver 'campos: nombre con espacio'        ([bool](Test-AIConsultaCampos @((C 'premio mayor' 'Premio'))))
Ver 'campos: nombre repetido'           ([bool](Test-AIConsultaCampos @((C 'a' 'X'), (C 'a' 'Y'))))
Ver 'campos: rotulo repetido'           ([bool](Test-AIConsultaCampos @((C 'a' 'X:'), (C 'b' 'x:'))))
Ver 'campos: rotulo con el dato'        ([bool](Test-AIConsultaCampos @((C 'sorteo' 'Sorteo 2304'))))
Ver 'campos: rotulo vacio'              ([bool](Test-AIConsultaCampos @((C 'a' ' '))))
Ver 'campos: rotulo de dos filas'       ([bool](Test-AIConsultaCampos @((C 'a' "X`nY"))))
Ver 'campos: mas de ocho'               ([bool](Test-AIConsultaCampos @(1..9 | ForEach-Object { C "c$_" "R$_" })))
Ver 'campos: registros 0'               ([bool](Test-AIConsultaCampos @((C 'a' 'X')) 0))
Ver 'campos: registros 11'              ([bool](Test-AIConsultaCampos @((C 'a' 'X')) 11))

# ---- sacar los datos de la pagina de ejemplo ---------------------------------
$html  = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'datos\consulta.html'), [Text.Encoding]::UTF8)
$texto = ConvertTo-AIPlainText $html
$lot = @((C 'sorteo' 'Sorteo'), (C 'ganador' 'Ganador:'), (C 'premio' 'Premio:'), (C 'fecha' 'Fecha:'), (C 'sucursal' 'Sucursal:'))
$d = Get-AIConsultaDatos $texto $lot 1
$r1 = $d.Registros[0]
Ver 'datos: el primer bloque'           ($r1.sorteo -eq '1002' -and $r1.fecha -eq '10/11/2026') "<$($r1.sorteo)> <$($r1.fecha)>"
Ver 'datos: conserva el cero'           ($r1.ganador -eq '01234') "<$($r1.ganador)>"
Ver 'datos: con acento'                 ($r1.sucursal -eq ('Le' + [char]0xF3 + 'n')) "<$($r1.sucursal)>"
Ver 'datos: lo que falta sale null, no el del bloque siguiente' ($null -eq $r1.premio) "<$($r1.premio)>"
Ver 'datos: dice que campo falto'       (@($d.Vacios) -join ',' -eq 'premio') "<$($d.Vacios -join ',')>"
Ver 'datos: no lee el script'           ($texto -notmatch 'no soy un dato')
$d2 = Get-AIConsultaDatos $texto $lot 5
Ver 'datos: varios bloques'             ($d2.Registros.Count -eq 2 -and $d2.Registros[1].sorteo -eq '1001' -and $d2.Registros[1].premio -eq 'C$9,000,000') "<$($d2.Registros.Count)> <$($d2.Registros[1].premio)>"
Ver 'datos: el pie no es un bloque'     (-not ($d2.Registros | Where-Object { $_.sorteo -eq '9999' -or $_.sorteo -like '*pie*' }))
$d = Get-AIConsultaDatos $texto @((C 'temperatura' 'Temperatura:'), (C 'humedad' 'Humedad:')) 1
Ver 'datos: dos en una fila, y el negativo' ($d.Registros[0].temperatura -eq '-5' -and $d.Registros[0].humedad -eq '80 %') "<$($d.Registros[0].temperatura)> <$($d.Registros[0].humedad)>"
$d = Get-AIConsultaDatos $texto @((C 'proximo' ('Pr' + [char]0xF3 + 'ximo premio'))) 1
Ver 'datos: el dato en la fila siguiente' ($d.Registros[0].proximo -eq 'C$ 12,000,000') "<$($d.Registros[0].proximo)>"
$d = Get-AIConsultaDatos $texto @((C 'nada' 'No existe:')) 1
Ver 'datos: rotulo que no esta'         ($d.Hallados -eq 0 -and $d.Registros.Count -eq 0)

# ---- una pagina que es JSON ---------------------------------------------------
$j = '{"drawDate": "2026-09-26", "premio": {"x": 1}, "total": 5, "nombre": "con \"comillas\""}'
$d = Get-AIConsultaDatos $j @((C 'fecha' 'drawDate'), (C 'premio' 'premio'), (C 'total' 'total'), (C 'nombre' 'nombre')) 1
$r = $d.Registros[0]
Ver 'json: el texto entre comillas'     ($r.fecha -eq '2026-09-26') "<$($r.fecha)>"
Ver 'json: un objeto no es un dato'     ($null -eq $r.premio) "<$($r.premio)>"
Ver 'json: una cifra'                   ($r.total -eq '5') "<$($r.total)>"
Ver 'json: comillas dentro'             ($r.nombre -eq 'con "comillas"') "<$($r.nombre)>"

# ---- el JSON que sale -----------------------------------------------------------
$d = Get-AIConsultaDatos $texto @((C 'nota' 'Nota:')) 1
$js = ConvertTo-AIConsultaJson $d.Registros
Ver 'salida: escapa comillas y barras'  ($js -eq "{`n  ""nota"": ""el \""texto\"" con comillas y una barra \\ invertida""`n}") $js
Ver 'salida: se lee con ConvertFrom-Json' ((($js | ConvertFrom-Json).nota) -eq 'el "texto" con comillas y una barra \ invertida')
$js = ConvertTo-AIConsultaJson @([ordered]@{ a = '1'; b = $null }, [ordered]@{ a = '2'; b = 'x' }) -Lista
# En PowerShell 5.1, @($x | ConvertFrom-Json) mete toda la lista en un solo elemento.
$o = $js | ConvertFrom-Json
Ver 'salida: lista y null'              ($o.Count -eq 2 -and $null -eq $o[0].b -and $o[1].b -eq 'x') $js

# ---- lo que teclea el usuario en /comando web --------------------------------------
$cf = ConvertFrom-AIConsultaCampos 'sorteo=Sorteo ganador="Ganador:" "Premio Mayor"=Premio registros=5'
Ver 'teclear: campos'                   ((@($cf.Campos | ForEach-Object { "$($_.Campo)=$($_.Rotulo)" }) -join ' ') -eq 'sorteo=Sorteo ganador=Ganador: premio_mayor=Premio') ((@($cf.Campos | ForEach-Object { "$($_.Campo)=$($_.Rotulo)" }) -join ' '))
Ver 'teclear: registros'                ($cf.Registros -eq 5)
Ver 'teclear: ida y vuelta'             ((Format-AIConsultaCampos $cf.Campos $cf.Registros) -eq 'sorteo="Sorteo" ganador="Ganador:" premio_mayor="Premio" registros=5') (Format-AIConsultaCampos $cf.Campos $cf.Registros)

# ---- lo que propone el modelo ------------------------------------------------------
$p = ConvertFrom-AIConsultaPropuesta ("NOMBRE: Loteria Nicaragua`nDESCRIPCI" + [char]0xD3 + "N: El ultimo sorteo`n**CAMPO sorteo:** ""Sorteo""`nCAMPO Fecha del sorteo: Fecha:`nREGISTROS: 3")
Ver 'propuesta: campos'                 ((@($p.Campos | ForEach-Object { "$($_.Campo)=$($_.Rotulo)" }) -join ' ') -eq 'sorteo=Sorteo fecha_del_sorteo=Fecha:') ((@($p.Campos | ForEach-Object { "$($_.Campo)=$($_.Rotulo)" }) -join ' '))
Ver 'propuesta: nombre, descripcion y registros' ($p.Nombre -eq 'loteria-nicaragua' -and $p.Descripcion -eq 'El ultimo sorteo' -and $p.Registros -eq 3) "<$($p.Nombre)> <$($p.Descripcion)> <$($p.Registros)>"
$p = ConvertFrom-AIConsultaPropuesta 'NOHAY: la pagina no trae resultados'
Ver 'propuesta: no hay'                 ($p.NoHay -eq 'la pagina no trae resultados' -and -not $p.Campos.Count)
$v = Test-AIConsultaPropuesta @{ Campos = @((C 'sorteo' 'Sorteo'), (C 'ganador' 'Ganador:')); Registros = 1 } $texto
Ver 'propuesta: vale'                   ($v.Ok -and $v.Datos.Registros[0].ganador -eq '01234') $v.Motivo
$v = Test-AIConsultaPropuesta @{ Campos = @((C 'sorteo' 'Sorteo'), (C 'bote' 'Bote acumulado:')); Registros = 1 } $texto
Ver 'propuesta: rotulo que no esta en la pagina' (-not $v.Ok -and $v.Motivo -match 'Bote acumulado') $v.Motivo
$v = Test-AIConsultaPropuesta @{ Campos = @((C 'sorteo' 'Sorteo'), (C 'premio' 'Premio:')); Registros = 1 } $texto
Ver 'propuesta: quita el campo que no da nada' ($v.Ok -and (@($v.Quitados) -join ',') -eq 'premio' -and $v.Campos.Count -eq 1) "<$($v.Quitados -join ',')>"
$v = Test-AIConsultaPropuesta @{ Campos = @(); Registros = 1 } $texto
Ver 'propuesta: sin campos'             (-not $v.Ok)

# ---- reconocer que la peticion es de internet ---------------------------------------
foreach ($t in 'agregame un comando para el ultimo sorteo de la loteria de internet', 'agregame un comando que lea la pagina de la loteria',
               'agregame un comando con https://example.com/x', 'agregame un comando usando curl y duckduckgo') {
    Ver "pedida web: $t" (Test-AIConsultaPedida $t)
}
foreach ($t in 'agregame un comando para ver mi IP publica', 'agregame un comando para los procesos que mas memoria usan') {
    Ver "pedida no web: $t" (-not (Test-AIConsultaPedida $t))
}

# ---- guardar y leer en comandos.json -------------------------------------------------
$f = Join-Path ([IO.Path]::GetTempPath()) ('consultas-' + [Guid]::NewGuid().ToString('N') + '.json')
try {
    $web = [pscustomobject]@{ Nombre = 'loteria'; Tipo = 'web'; Comando = 'https://example.com/r'; Url = 'https://example.com/r'
                              Campos = @((C 'sorteo' 'Sorteo')); Registros = 2; Descripcion = 'el sorteo'; Creado = '2026-11-16' }
    $ps  = [pscustomobject]@{ Nombre = 'fecha'; Tipo = 'powershell'; Comando = 'Get-Date'; Descripcion = 'la fecha'; Creado = '2026-11-16' }
    Save-AIComandos $f @($web, $ps)
    $l = (Read-AIComandos $f -SinReglas).Lista
    $w = @($l | Where-Object { $_.Nombre -eq 'loteria' })[0]
    Ver 'fichero: la consulta vuelve igual' ($w.Tipo -eq 'web' -and $w.Url -eq 'https://example.com/r' -and $w.Registros -eq 2 -and $w.Campos[0].Rotulo -eq 'Sorteo' -and $w.Servidores[0] -eq 'example.com')
    Ver 'fichero: el comando de PowerShell sigue igual' (@($l | Where-Object { $_.Nombre -eq 'fecha' -and $_.Tipo -eq 'powershell' -and $_.Comando -eq 'Get-Date' }).Count -eq 1)
    Ver 'fichero: el modelo la ve como un comando mas' ((Get-AIComandoTool $l).function.parameters.properties.nombre.enum -contains 'loteria')
    $malos = '[{"nombre":"a","tipo":"web","url":"http://example.com","campos":[{"campo":"x","rotulo":"X"}]},' +
             '{"nombre":"b","tipo":"web","url":"https://192.168.0.1/","campos":[{"campo":"x","rotulo":"X"}]},' +
             '{"nombre":"c","tipo":"web","url":"https://example.com","campos":[]},' +
             '{"nombre":"d","tipo":"web","url":"https://example.com","campos":[{"campo":"x","rotulo":"X"}],"registros":50}]'
    [IO.File]::WriteAllText($f, $malos)
    $rd = Read-AIComandos $f -SinReglas
    Ver 'fichero: rechaza http, red local, sin campos y registros de mas' ($rd.Lista.Count -eq 0 -and $rd.Rechazados.Count -eq 4) ($rd.Rechazados -join ' / ')
} finally { Remove-Item $f -ErrorAction SilentlyContinue }
Ver 'web es un nombre reservado'        ([bool](Test-AIComandoNombre 'web'))

# ---- ejecutarla: sin pasar las reglas no sale a internet -----------------------------
$x = Invoke-AIComandoGuardado ([pscustomobject]@{ Nombre = 'mala'; Tipo = 'web'; Url = 'http://example.com'; Campos = @((C 'a' 'A')); Registros = 1 })
Ver 'ejecutar: una direccion http no se pide' (-not $x.Ok -and $x.ParaModelo -match 'no inventes') $x.Motivo

# ---- en ingles -----------------------------------------------------------------------
# Lo que escribe el programa cambia; lo que teclea el usuario o contesta el
# modelo se reconoce en los dos idiomas.
Set-AIIdioma en
Ver 'en: campos que faltan'             ((Test-AIConsultaCampos @()) -eq 'the fields are missing (name=label)')
Ver 'en: rotulo con el dato'            ((Test-AIConsultaCampos @((C 'draw' 'Draw 2304'))) -eq 'the label of "draw" ("Draw 2304") has digits: it must be the fixed text that comes before the value, not the value')
Ver 'en: registros'                     ((Test-AIConsultaCampos @((C 'a' 'X')) 11) -eq 'records go from 1 to 10')
foreach ($t in 'add a command to get the latest lottery results from the internet', 'add a command that reads the lottery page',
               'add a web query for the dollar price', 'save a command for the weather from a website', 'add a command to get the price from https://example.com/x') {
    Ver "en: pedida web: $t" (Test-AIConsultaPedida $t)
}
foreach ($t in 'add a command to see my public IP', 'add a command for the processes that use the most memory') {
    Ver "en: pedida no web: $t" (-not (Test-AIConsultaPedida $t))
}
$p = ConvertFrom-AIConsultaPropuesta "NAME: Lottery Results`nDESCRIPTION: The last draw`n**FIELD draw:** ""Sorteo""`nFIELD Draw date: Fecha:`nRECORDS: 3"
Ver 'en: propuesta'                     ((@($p.Campos | ForEach-Object { "$($_.Campo)=$($_.Rotulo)" }) -join ' ') -eq 'draw=Sorteo draw_date=Fecha:' -and $p.Nombre -eq 'lottery-results' -and $p.Descripcion -eq 'The last draw' -and $p.Registros -eq 3) "<$((@($p.Campos | ForEach-Object { "$($_.Campo)=$($_.Rotulo)" }) -join ' '))> <$($p.Nombre)> <$($p.Descripcion)> <$($p.Registros)>"
$p = ConvertFrom-AIConsultaPropuesta 'NODATA: the page has no results'
Ver 'en: propuesta: no hay'             ($p.NoHay -eq 'the page has no results' -and -not $p.Campos.Count)
$v = Test-AIConsultaPropuesta @{ Campos = @((C 'sorteo' 'Sorteo'), (C 'bote' 'Bote acumulado:')); Registros = 1 } $texto
Ver 'en: rotulo que no esta en la pagina' ($v.Motivo -eq 'the label "Bote acumulado:" of bote is not on the page: copy it exactly from the text') $v.Motivo
Ver 'en: sin campos'                    ((Test-AIConsultaPropuesta @{ Campos = @(); Registros = 1 } $texto).Motivo -eq 'you gave no FIELD line')
$cf = ConvertFrom-AIConsultaCampos 'draw=Sorteo winner="Ganador:" records=4'
Ver 'en: teclear records='              ($cf.Registros -eq 4 -and $cf.Campos.Count -eq 2 -and (Format-AIConsultaCampos $cf.Campos $cf.Registros) -eq 'draw="Sorteo" winner="Ganador:" records=4') (Format-AIConsultaCampos $cf.Campos $cf.Registros)
Ver 'en: teclear registros= sigue valiendo' ((ConvertFrom-AIConsultaCampos 'a=X registros=2').Registros -eq 2)
$g = Get-AIConsultaGuia
Ver 'en: la guia'                       ($g -match '(?m)^FIELD field_name: label' -and $g -match '(?m)^NODATA: ' -and $g -notmatch 'CAMPO')
$x = Invoke-AIComandoGuardado ([pscustomobject]@{ Nombre = 'bad'; Tipo = 'web'; Url = 'http://example.com'; Campos = @((C 'a' 'A')); Registros = 1 })
Ver 'en: ejecutar: una direccion http'  (-not $x.Ok -and $x.ParaModelo -eq 'The saved web query "bad" could not be done: the address must start with https://. Say so and do not make up the data.') $x.ParaModelo
Set-AIIdioma es
Ver 'de vuelta al espanol'              ((Test-AIConsultaCampos @()) -eq ('faltan los campos (nombre=r' + [char]0xF3 + 'tulo)'))

# ---- con red: la pagina de verdad ------------------------------------------------------
if ($Red) {
    $q = [pscustomobject]@{ Nombre = 'loteria-nicaragua'; Tipo = 'web'; Url = 'https://loterianacional.com.ni/resultados/'; Registros = 2; Descripcion = 'prueba'
                            Campos = @((C 'sorteo' 'Sorteo'), (C 'ganador' 'Ganador:'), (C 'premio' 'Premio:'), (C 'fecha' 'Fecha:'), (C 'sucursal' 'Sucursal:')) }
    $x = Invoke-AIComandoGuardado $q
    Ver 'red: lee la Loteria Nacional' $x.Ok $x.Motivo
    if ($x.Ok) {
        $o = $x.Salida | ConvertFrom-Json
        Ver 'red: dos sorteos seguidos'   ($o.Count -eq 2 -and [int]$o[0].sorteo -eq [int]$o[1].sorteo + 1) $x.Salida
        Ver 'red: billete de cinco cifras' ($o[0].ganador -match '^\d{5}$') $o[0].ganador
        Ver 'red: premio en cordobas'     ($o[0].premio -match '^C\$') $o[0].premio
        Ver 'red: fecha'                  ($o[0].fecha -match '^\d{1,2}/\d{1,2}/\d{4}$') $o[0].fecha
        Ver 'red: al modelo, con la pagina' ($x.ParaModelo -match 'loterianacional\.com\.ni' -and $x.ParaModelo -match 'no instrucciones')
    }
}

Write-Output "MAL = $mal de $n"
exit $mal
