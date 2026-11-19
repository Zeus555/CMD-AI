#requires -Version 5.1
# ---------------------------------------------------------------------------
#  Monta el video de presentacion (docs\video) a partir de las capturas.
#
#  Escribe index.html y compositions\*.html, el proyecto HyperFrames que se
#  renderiza con:
#    cd docs\video
#    npx --yes hyperframes@0.8.221 render -o <fichero.mp4>
#
#  El texto de la terminal NO se escribe aqui: cada escena dice de que
#  captura sale y que lineas toma (capturas\*.out, salidas reales de
#  capturar.ps1). Las lineas van tal cual; donde se salta un trozo sale una
#  linea "...". Solo cambia el ritmo: las esperas del modelo se acortan, y
#  el pie de cada escena lo dice.
#  Comentarios y expresiones regulares en ASCII (ver tools\build.ps1).
# ---------------------------------------------------------------------------
param([string]$Dir, [ValidateSet('es', 'en')][string]$Idioma = 'es')
$ErrorActionPreference = 'Stop'
# El video en espanol es el proyecto de docs\video; el de ingles, el de
# docs\video\en (su index.html, sus composiciones, su narracion y su voz).
# Las capturas estan en capturas\ y capturas\en\.
$Base = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Dir) { $Dir = if ($Idioma -eq 'en') { Join-Path $Base 'en' } else { $Base } }
$Capturas = if ($Idioma -eq 'en') { Join-Path $Base 'capturas\en' } else { Join-Path $Base 'capturas' }
# Lo que el programa pone delante de cada linea, en cada idioma.
$PU  = if ($Idioma -eq 'en') { 'User > ' } else { 'Usuario > ' }
$PIA = if ($Idioma -eq 'en') { 'ai > ' } else { 'ia > ' }
$utf8 = New-Object Text.UTF8Encoding $false

# ---- Las escenas -------------------------------------------------------------
#  Lineas: rangos de la captura, 1 = primera linea del fichero.
#  Resalta: textos; la linea que contenga alguno se marca.
$escenas = @(
    @{ Id = 'local'; Kicker = '1 · En tu equipo'; Titulo = 'Chat local con Gemma 4 E4B'
       Pie = 'El modelo corre en la propia laptop: sin clave, sin nube y sin mandar la conversación a ningún sitio.'
       Captura = '1-chat-web-equipo.out'; Lineas = '2-6'; Resalta = @('Gemma 4 E4B (local)') }
    @{ Id = 'web'; Kicker = '2 · Internet, solo si hace falta'; Titulo = 'Busca en internet cuando la pregunta lo pide'
       Pie = 'El modelo decide si necesita datos actuales; busca, lee las páginas y cita las fuentes.'
       Captura = '1-chat-web-equipo.out'; Lineas = '7-10'; Resalta = @('ia > buscando:', 'fuentes:') }
    @{ Id = 'equipo'; Kicker = '3 · Lo que el equipo ya sabe'; Titulo = 'Sabe datos de este equipo'
       Pie = 'La hora, la batería, la memoria, los discos... se leen del propio Windows, sin internet.'
       Captura = '1-chat-web-equipo.out'; Lineas = '11-13'; Resalta = @('leyendo de este equipo') }
    @{ Id = 'comandos'; Kicker = '4 · Comandos guardados'; Titulo = 'Guarda comandos conversando'
       Pie = 'Solo de lectura: unas reglas fijas lo comprueban, lo prueba y lo guarda. Desde entonces se usa al preguntar.'
       Captura = '2-comandos-consultas.out'; Lineas = '5,8,10-12,39-43'; Resalta = @('reglas:   pasa', 'ejecutando el comando guardado') }
    @{ Id = 'consultas'; Kicker = '5 · Consultas web'; Titulo = 'Datos de una página, en JSON'
       Pie = 'Elige la página, saca los datos por sus rótulos y te los enseña antes de guardarla.'
       Captura = '2-comandos-consultas.out'; Lineas = '44,47,49-50,64,66,69-75'; Resalta = @('"sorteo"', '"ganador"', '"premio"', '"fecha"', '"sucursal"') }
    @{ Id = 'preferencias'; Kicker = '6 · Preferencias'; Titulo = 'Recuerda cómo quieres que te conteste'
       Pie = 'Para esta conversación y las próximas.'
       Captura = '3-preferencias-documentos.out'; Lineas = '5-8'; Resalta = @('guardada.') }
    @{ Id = 'aprende'; Kicker = '7 · Los documentos de tu negocio'; Titulo = 'Aprende de una carpeta de documentos'
       Pie = 'Word, Excel, PowerPoint, PDF, texto... Lo que no puede leer, como un escaneo, lo dice. No entrena el modelo: busca en ellos.'
       Captura = '3-preferencias-documentos.out'; Lineas = '9-16'; Resalta = @('Hay 14 que sé leer', 'ia > Listo:') }
    @{ Id = 'pregunta'; Kicker = '7 · Los documentos de tu negocio'; Titulo = 'Contesta con lo que dicen, y dice de dónde'
       Pie = 'También de un PDF, con su apartado. Y si un dato no está en los documentos, lo dice: no lo inventa.'
       Captura = '3-preferencias-documentos.out'; Lineas = '17-28'; Resalta = @('Cuesta C$ 650', 'No viene en los documentos.') }
    @{ Id = 'buscar'; Kicker = '7 · Los documentos de tu negocio'; Titulo = 'Comprueba de dónde sale cada dato'
       Pie = '/documentos buscar enseña los trozos que vería el modelo, sin preguntarle: aquí, la tabla del PDF.'
       Captura = '3-preferencias-documentos.out'; Lineas = '29-35,41'; Resalta = @('Tres leches | C$ 60 | C$ 650') }
    @{ Id = 'olvida'; Kicker = '8 · Olvidar'; Titulo = 'Y olvida lo que le pidas'
       Pie = 'Enseña qué va a olvidar y pide un sí. Tus ficheros no se tocan: olvida lo leído.'
       Captura = '3-preferencias-documentos.out'; Lineas = '42-59'; Resalta = @('Voy a olvidar', 'Olvidado.') }
    @{ Id = 'recuerda'; Kicker = '8 · Olvidar'; Titulo = 'Y se puede deshacer'
       Pie = 'Lo olvidado queda en una lista: /documentos recordar lo vuelve a usar.'
       Captura = '3-preferencias-documentos.out'; Lineas = '61-65'; Resalta = @('vuelvo a usar') }
)
$NOTA = 'Salida real de PRC AI 2.0 con Gemma 4 E4B en la propia laptop · las esperas del modelo se han acortado'

# ---- Las escenas en ingles ----------------------------------------------------------
#  Las mismas, con las capturas de capturas\en (el programa en ingles y la
#  cafeteria de tests\negocio.ps1 -Idioma en).
if ($Idioma -eq 'en') {
    $NOTA = 'Real output of PRC AI 2.0 with Gemma 4 E4B on the laptop itself · the model''s waits have been shortened'
    $escenas = @(
        @{ Id = 'local'; Kicker = '1 · On your computer'; Titulo = 'Local chat with Gemma 4 E4B'
           Pie = 'The model runs on the laptop itself: no key, no cloud, and the conversation goes nowhere.'
           Captura = '1-chat-web-computer.out'; Lineas = '2-6'; Resalta = @('Gemma 4 E4B (local)') }
        @{ Id = 'web'; Kicker = '2 · Internet, only when needed'; Titulo = 'It searches the internet when the question needs it'
           Pie = 'The model decides whether it needs current data; it searches, reads the pages and cites the sources.'
           Captura = '1-chat-web-computer.out'; Lineas = '7-10'; Resalta = @('ai > searching:', 'sources:') }
        @{ Id = 'equipo'; Kicker = '3 · What the computer already knows'; Titulo = 'It knows facts about this computer'
           Pie = 'Time, battery, memory, disks... read from Windows itself, without the internet.'
           Captura = '1-chat-web-computer.out'; Lineas = '11-13'; Resalta = @('reading from this computer') }
        @{ Id = 'comandos'; Kicker = '4 · Saved commands'; Titulo = 'It saves commands as you chat'
           Pie = 'Read-only: fixed rules check it, it tests it and saves it. From then on it uses it when you ask.'
           Captura = '2-commands-queries.out'; Lineas = '5,8,10-12,41-45'; Resalta = @('rules:    passes', 'running the saved command') }
        @{ Id = 'consultas'; Kicker = '5 · Web queries'; Titulo = 'Data from a page, as JSON'
           Pie = 'It picks the page (or you paste it), takes the data by its labels and shows it to you before saving.'
           Captura = '2-commands-queries.out'; Lineas = '46,49,51-52,63,66,68-69,71-74'; Resalta = @('"population"', '"area"') }
        @{ Id = 'preferencias'; Kicker = '6 · Preferences'; Titulo = 'It remembers how you want answers'
           Pie = 'For this conversation and the next ones.'
           Captura = '3-preferences-documents.out'; Lineas = '5-8'; Resalta = @('saved.') }
        @{ Id = 'aprende'; Kicker = '7 · Your business documents'; Titulo = 'It learns from a folder of documents'
           Pie = 'Word, Excel, PowerPoint, PDF, text... What it can''t read, like a scan, it says. It doesn''t train the model: it searches them.'
           Captura = '3-preferences-documents.out'; Lineas = '9-16'; Resalta = @('There are 14 I can read', 'it has no text') }
        @{ Id = 'pregunta'; Kicker = '7 · Your business documents'; Titulo = 'It answers with what they say, and from which one'
           Pie = 'From a PDF too. And if something isn''t in the documents, it says so: it doesn''t make it up.'
           Captura = '3-preferences-documents.out'; Lineas = '17-28'; Resalta = @('A whole carrot cake is $48.00', 'not stated in the documents') }
        @{ Id = 'buscar'; Kicker = '7 · Your business documents'; Titulo = 'Check where every answer comes from'
           Pie = '/documents search shows the excerpts the model would see, without asking it: here, the PDF''s table.'
           Captura = '3-preferences-documents.out'; Lineas = '29-35,49'; Resalta = @('Carrot cake | $5.50 | $48.00') }
        @{ Id = 'olvida'; Kicker = '8 · Forgetting'; Titulo = 'And it forgets what you ask it to'
           Pie = 'It shows what it will forget and asks for a yes. Your files aren''t touched: it forgets what it read.'
           Captura = '3-preferences-documents.out'; Lineas = '50-67'; Resalta = @('going to forget', 'Forgotten.') }
        @{ Id = 'recuerda'; Kicker = '8 · Forgetting'; Titulo = 'And it can be undone'
           Pie = 'What was forgotten stays on a list: /documents restore uses it again.'
           Captura = '3-preferences-documents.out'; Lineas = '69-73'; Resalta = @('using again') }
    )
}
$DUR_INTRO = 4.5
$DUR_FINAL = 6.0

# ---- La voz -----------------------------------------------------------------------
#  assets\voz\<id>.mp3 sale de narracion.txt con voz.ps1. Cada toma empieza
#  VOZ_INICIO segundos despues de su escena, y si no cabe, la escena se alarga
#  (se queda en su ultimo fotograma) hasta VOZ_COLA despues de que acabe.
#  Sin voz.json el video sale mudo, como antes.
$VOZ_INICIO = 0.5
$VOZ_COLA   = 0.7
$voces = @{}
$fichVoz = Join-Path $Dir 'assets\voz\voz.json'
if (Test-Path -LiteralPath $fichVoz) {
    $j = [IO.File]::ReadAllText($fichVoz, [Text.Encoding]::UTF8) | ConvertFrom-Json
    foreach ($p in $j.PSObject.Properties) {
        if (Test-Path -LiteralPath (Join-Path $Dir "assets\voz\$($p.Name).mp3")) { $voces[$p.Name] = [double]$p.Value.duracion }
    }
}
function Get-DurConVoz([string]$id, [double]$dur) {
    if (-not $voces.ContainsKey($id)) { return $dur }
    return [Math]::Round([Math]::Max($dur, $VOZ_INICIO + $voces[$id] + $VOZ_COLA), 1)
}

# ---- Medidas de la terminal -------------------------------------------------
$FUENTE   = 24                       # px, JetBrains Mono
$ALTO_LN  = [Math]::Round($FUENTE * 1.45, 2)
$ANCHO_CH = $FUENTE * 0.6            # una monoespaciada mide 0,6 em de ancho
$COLS     = [Math]::Floor((1680 - 64) / $ANCHO_CH * 0.95)   # 0,95: se parte por palabras
$MAX_FILAS    = [Math]::Floor((730 - 44 - 44) / $ALTO_LN)
$CPS      = 70                       # letras por segundo al teclear

$enc = { param($s) [System.Net.WebUtility]::HtmlEncode([string]$s) }

function Read-Captura([string]$fichero) {
    $t = [IO.File]::ReadAllText((Join-Path $Capturas $fichero), [Text.Encoding]::UTF8)
    $ls = @($t -replace "`r`n", "`n" -split "`n")
    # Una linea que se reescribio con `r (el avance "leyendo 3 de 13: ...")
    # se queda como acabo en pantalla: lo ultimo que se escribio en ella.
    for ($i = 0; $i -lt $ls.Count; $i++) {
        if ($ls[$i].Contains("`r")) { $ls[$i] = (@($ls[$i] -split "`r" | Where-Object { $_.Trim() }))[-1] }
        $k = $ls[$i].IndexOf($PIA)
        if ($ls[$i] -match '^\s+(leyendo \d+ de|reading \d+ of) \d+: ' -and $k -gt 0) { $ls[$i] = $ls[$i].Substring($k) }
    }
    return $ls
}

function Get-Lineas($ls, [string]$rangos) {
    $out = New-Object System.Collections.Generic.List[object]
    $ant = $null
    foreach ($r in ($rangos -split ',')) {
        $a, $b = $r -split '-'
        if (-not $b) { $b = $a }
        if ($null -ne $ant -and [int]$a -ne $ant + 1) { $out.Add(@{ Tipo = 'gap'; Texto = '...' }) }
        for ($n = [int]$a; $n -le [int]$b; $n++) {
            $l = $ls[$n - 1].TrimEnd()
            $tipo = if ($l.StartsWith($PU)) { 'u' } elseif ($l.StartsWith($PIA)) { 'ia' } elseif ($l -match '^\s|^\(' -or -not $l) { 'dim' } else { 'ia' }
            $out.Add(@{ Tipo = $tipo; Texto = $l; N = $n })
        }
        $ant = [int]$b
    }
    return ,$out
}

function Get-Filas([string]$texto) { return [Math]::Max(1, [Math]::Ceiling($texto.Length / $COLS)) }

# ---- Una escena de terminal ---------------------------------------------------
function New-Escena($e) {
    $id = $e.Id
    $ls = Read-Captura $e.Captura
    $lineas = Get-Lineas $ls $e.Lineas
    $html = New-Object System.Text.StringBuilder
    $js = New-Object System.Text.StringBuilder
    [void]$js.AppendLine("      tl.fromTo('#$id-kicker', { opacity: 0, y: 14 }, { opacity: 1, y: 0, duration: 0.45, ease: 'power3.out' }, 0);")
    [void]$js.AppendLine("      tl.fromTo('#$id-titulo', { opacity: 0, y: 18 }, { opacity: 1, y: 0, duration: 0.55, ease: 'power3.out' }, 0.08);")
    [void]$js.AppendLine("      tl.fromTo('#$id-pie', { opacity: 0, y: 12 }, { opacity: 1, y: 0, duration: 0.5, ease: 'power3.out' }, 0.35);")
    [void]$js.AppendLine("      tl.fromTo('#$id-term', { opacity: 0, y: 24 }, { opacity: 1, y: 0, duration: 0.5, ease: 'power3.out' }, 0.2);")
    $t = 1.0; $filas = 0; $palabras = 0; $i = 0
    for ($k = 0; $k -lt $lineas.Count; $k++) {
        $l = $lineas[$k]; $i++
        $lid = "$id-l$i"
        $resalta = $l.Tipo -ne 'u' -and $l.Tipo -ne 'gap' -and @($e.Resalta | Where-Object { $l.Texto.Contains($_) }).Count -gt 0
        $hl = if ($resalta) { '<span class="hl-bg"></span>' } else { '' }
        $filas += Get-Filas $l.Texto
        if ($l.Tipo -eq 'u') {
            # Si antes hubo respuesta, una pausa para leerla.
            if ($palabras) { $t += [Math]::Min(3.0, 0.8 + $palabras * 0.07); $palabras = 0 }
            $resto = $l.Texto.Substring($PU.Length)
            $chars = -join ($resto.ToCharArray() | ForEach-Object { '<span class="ch">' + (& $enc $_) + '</span>' })
            [void]$html.AppendLine("          <div class=""ln u"" id=""$lid""><span class=""pr"">$(& $enc $PU)</span>$chars<span class=""cur"" id=""$lid-cur""></span></div>")
            [void]$js.AppendLine("      tl.set('#$lid', { opacity: 1 }, $([Math]::Round($t, 2)));")
            [void]$js.AppendLine("      tl.set('#$lid-cur', { opacity: 1 }, $([Math]::Round($t, 2)));")
            $t0 = $t + 0.2
            if ($resto.Length) { [void]$js.AppendLine("      tl.fromTo('#$lid .ch', { display: 'none' }, { display: 'inline', duration: 0.001, stagger: $([Math]::Round(1 / $CPS, 4)) }, $([Math]::Round($t0, 2)));") }
            $fin = $t0 + $resto.Length / $CPS
            [void]$js.AppendLine("      tl.set('#$lid-cur', { opacity: 0 }, $([Math]::Round($fin + 0.25, 2)));")
            $t = $fin + 0.35
        } else {
            $clase = if ($l.Tipo -eq 'gap') { 'gap' } else { $l.Tipo }
            $txt = $l.Texto
            if ($txt.StartsWith($PIA)) { $cuerpo = '<span class="pr">' + (& $enc $PIA) + '</span>' + (& $enc $txt.Substring($PIA.Length)) }
            else { $cuerpo = (& $enc $txt) }
            # La negrita del modelo (**x**): la terminal la pinta en negrita;
            # en la captura, con la salida redirigida, sale tal cual.
            $cuerpo = [regex]::Replace($cuerpo, '\*\*(.+?)\*\*', '<b>$1</b>')
            if (-not $txt) { $cuerpo = '&#8203;' }
            [void]$html.AppendLine("          <div class=""ln $clase"" id=""$lid"">$hl<span class=""tx"">$cuerpo</span></div>")
            [void]$js.AppendLine("      tl.fromTo('#$lid', { opacity: 0 }, { opacity: 1, duration: 0.18 }, $([Math]::Round($t, 2)));")
            if ($resalta) { [void]$js.AppendLine("      tl.fromTo('#$lid .hl-bg', { scaleX: 0 }, { scaleX: 1, duration: 0.4, ease: 'power2.out' }, $([Math]::Round($t + 0.25, 2)));") }
            $palabras += @($txt -split '\s+' | Where-Object { $_ }).Count
            $t += if ($l.Tipo -eq 'gap') { 0.3 } else { 0.16 }
        }
        # Lo que no cabe sube, como en una terminal.
        if ($filas -gt $MAX_FILAS) {
            [void]$js.AppendLine("      tl.to('#$id-cuerpo', { y: -$([Math]::Round(($filas - $MAX_FILAS) * $ALTO_LN, 1)), duration: 0.25, ease: 'power2.out' }, $([Math]::Round($t - 0.15, 2)));")
        }
    }
    $t += [Math]::Min(4.0, 1.4 + $palabras * 0.08)
    $dur = [Math]::Round($t, 1)
    $doc = @"
<template>
  <style>
    #root { position: absolute; inset: 0; background: #F3EFE6; font-family: 'Inter', sans-serif; }
    #$id-head { position: absolute; left: 120px; top: 62px; width: 1680px; }
    #$id-kicker { font-weight: 700; font-size: 22px; letter-spacing: 0.14em; text-transform: uppercase; color: #A85C14; }
    #$id-titulo { font-weight: 700; font-size: 56px; line-height: 1.1; letter-spacing: -0.02em; color: #1D1B18; margin-top: 12px; }
    #$id-pie { font-weight: 400; font-size: 27px; line-height: 1.35; color: #5B554C; margin-top: 12px; }
    #$id-term { position: absolute; left: 120px; top: 282px; width: 1680px; height: 730px; background: #15171B; border-radius: 14px; overflow: hidden; box-shadow: 0 28px 60px rgba(60, 40, 10, 0.22); }
    #$id-term .bar { height: 44px; background: #23262C; display: flex; align-items: center; padding: 0 18px; gap: 10px; }
    #$id-term .dot { width: 14px; height: 14px; border-radius: 50%; }
    #$id-term .bar-t { margin-left: 14px; font: 500 17px 'JetBrains Mono', monospace; color: #8B9099; }
    #$id-cuerpo { padding: 22px 32px; font: 400 ${FUENTE}px/1.45 'JetBrains Mono', monospace; color: #E4DFD4; }
    #$id-term .ln { opacity: 0; position: relative; white-space: pre-wrap; word-break: break-word; }
    #$id-term .tx { position: relative; }
    #$id-term .u { color: #F6F2EA; }
    #$id-term .u .pr { color: #7CC7B2; }
    #$id-term .ia .pr { color: #8B9099; }
    #$id-term .dim { color: #A3A8B0; }
    #$id-term .gap { color: #7C8087; }
    #$id-term .ch { display: none; }
    #$id-term .cur { display: inline-block; width: 12px; height: 1.1em; background: #7CC7B2; vertical-align: -0.2em; opacity: 0; }
    #$id-term .hl-bg { position: absolute; left: -14px; right: -14px; top: -1px; bottom: -1px; background: rgba(232, 160, 72, 0.17); border-left: 4px solid #E8A048; transform-origin: left center; }
    #$id-nota { position: absolute; left: 120px; top: 1028px; font-weight: 400; font-size: 22px; color: #6A645A; }
  </style>
  <div id="root" data-composition-id="$id" data-width="1920" data-height="1080">
    <div id="$id-head">
      <div id="$id-kicker">$(& $enc $e.Kicker)</div>
      <div id="$id-titulo">$(& $enc $e.Titulo)</div>
      <div id="$id-pie">$(& $enc $e.Pie)</div>
    </div>
    <div id="$id-term" data-layout-allow-overflow>
      <div class="bar"><span class="dot" style="background:#E5675B"></span><span class="dot" style="background:#E8B04A"></span><span class="dot" style="background:#5DBB72"></span><span class="bar-t" data-layout-ignore>AI  ·  PowerShell</span></div>
      <div id="$id-cuerpo">
$($html.ToString().TrimEnd())
      </div>
    </div>
    <div id="$id-nota">$NOTA</div>
  </div>
  <script>
    (function () {
      const tl = gsap.timeline({ paused: true });
$($js.ToString().TrimEnd())
      window.__timelines["$id"] = tl;
    })();
  </script>
</template>
"@
    [IO.File]::WriteAllText((Join-Path $Dir "compositions\$id.html"), $doc, $utf8)
    if ($filas -gt $MAX_FILAS) { Write-Host ("  {0,-13} {1,5} s  {2} filas (sube {3})" -f $id, $dur, $filas, ($filas - $MAX_FILAS)) }
    else { Write-Host ("  {0,-13} {1,5} s  {2} filas" -f $id, $dur, $filas) }
    return $dur
}

# ---- Entrada y cierre -------------------------------------------------------
$intro = @'
<template>
  <style>
    #root { position: absolute; inset: 0; background: #15171B; font-family: 'Inter', sans-serif; }
    #intro-marca { position: absolute; left: 160px; top: 300px; font: 700 132px/1 'JetBrains Mono', monospace; color: #F6F2EA; letter-spacing: -0.03em; }
    #intro-cur { display: inline-block; width: 64px; height: 118px; background: #E8A048; vertical-align: -12px; margin-left: 18px; }
    #intro-l1 { position: absolute; left: 164px; top: 500px; font-weight: 700; font-size: 54px; color: #F6F2EA; letter-spacing: -0.02em; }
    #intro-l2 { position: absolute; left: 164px; top: 580px; font-weight: 400; font-size: 54px; color: #E8A048; letter-spacing: -0.02em; }
    #intro-l3 { position: absolute; left: 164px; top: 700px; font: 400 28px 'JetBrains Mono', monospace; color: #8B9099; }
  </style>
  <div id="root" data-composition-id="intro" data-width="1920" data-height="1080">
    <div id="intro-marca">PRC AI 2.0<span id="intro-cur"></span></div>
    <div id="intro-l1">Una IA en la terminal de Windows.</div>
    <div id="intro-l2">En tu equipo, sin nube.</div>
    <div id="intro-l3">PowerShell puro · cero dependencias · en español</div>
  </div>
  <script>
    (function () {
      const tl = gsap.timeline({ paused: true });
      [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5].forEach(function (s, i) { tl.set('#intro-cur', { opacity: i % 2 ? 1 : 0 }, s); });
      tl.fromTo('#intro-l1', { opacity: 0, y: 20 }, { opacity: 1, y: 0, duration: 0.5, ease: 'power3.out' }, 1.1);
      tl.fromTo('#intro-l2', { opacity: 0, y: 20 }, { opacity: 1, y: 0, duration: 0.5, ease: 'power3.out' }, 1.8);
      tl.fromTo('#intro-l3', { opacity: 0 }, { opacity: 1, duration: 0.6 }, 2.8);
      window.__timelines["intro"] = tl;
    })();
  </script>
</template>
'@
$final = @'
<template>
  <style>
    #root { position: absolute; inset: 0; background: #15171B; font-family: 'Inter', sans-serif; }
    #final-l1 { position: absolute; left: 160px; top: 250px; font-weight: 700; font-size: 64px; color: #F6F2EA; letter-spacing: -0.02em; }
    #final-l2 { position: absolute; left: 160px; top: 340px; font-weight: 700; font-size: 64px; color: #E8A048; letter-spacing: -0.02em; }
    #final-l3 { position: absolute; left: 160px; top: 450px; font-weight: 400; font-size: 34px; color: #C9C3B8; }
    #final-marca { position: absolute; left: 160px; top: 640px; font: 700 64px 'JetBrains Mono', monospace; color: #F6F2EA; }
    #final-repo { position: absolute; left: 160px; top: 740px; font: 400 30px 'JetBrains Mono', monospace; color: #7CC7B2; }
    #final-guia { position: absolute; left: 160px; top: 800px; font: 400 28px 'JetBrains Mono', monospace; color: #8B9099; }
  </style>
  <div id="root" data-composition-id="final" data-width="1920" data-height="1080">
    <div id="final-l1">Aprende de los documentos de tu negocio.</div>
    <div id="final-l2">Y olvida lo que le pidas.</div>
    <div id="final-l3">Si un dato no está en tus documentos, te lo dice.</div>
    <div id="final-marca">PRC AI 2.0</div>
    <div id="final-repo">github.com/Zeus555/CMD-AI</div>
    <div id="final-guia">guía de uso: docs/guia-documentos.md</div>
  </div>
  <script>
    (function () {
      const tl = gsap.timeline({ paused: true });
      tl.fromTo('#final-l1', { opacity: 0, y: 20 }, { opacity: 1, y: 0, duration: 0.5, ease: 'power3.out' }, 0.2);
      tl.fromTo('#final-l2', { opacity: 0, y: 20 }, { opacity: 1, y: 0, duration: 0.5, ease: 'power3.out' }, 0.9);
      tl.fromTo('#final-l3', { opacity: 0 }, { opacity: 1, duration: 0.6 }, 1.8);
      tl.fromTo('#final-marca', { opacity: 0, x: -24 }, { opacity: 1, x: 0, duration: 0.5, ease: 'power3.out' }, 3.0);
      tl.fromTo('#final-repo', { opacity: 0 }, { opacity: 1, duration: 0.5 }, 3.5);
      tl.fromTo('#final-guia', { opacity: 0 }, { opacity: 1, duration: 0.5 }, 3.9);
      window.__timelines["final"] = tl;
    })();
  </script>
</template>
'@

if ($Idioma -eq 'en') {
    $cambios = [ordered]@{
        'Una IA en la terminal de Windows.'                         = 'An AI in the Windows terminal.'
        'En tu equipo, sin nube.'                                   = 'On your computer, no cloud.'
        'PowerShell puro · cero dependencias · en español'          = 'Pure PowerShell · zero dependencies · English and Spanish'
        'Aprende de los documentos de tu negocio.'                  = 'It learns from your business documents.'
        'Y olvida lo que le pidas.'                                 = 'And forgets what you ask it to.'
        'Si un dato no está en tus documentos, te lo dice.'         = 'If something isn''t in your documents, it tells you.'
        'guía de uso: docs/guia-documentos.md'                      = 'guide: docs/documents-guide.md'
    }
    foreach ($k in $cambios.Keys) {
        if (-not ($intro.Contains($k) -or $final.Contains($k))) { throw "montar.ps1: no encuentro «$k» en la entrada ni en el cierre" }
        $intro = $intro.Replace($k, $cambios[$k]); $final = $final.Replace($k, $cambios[$k])
    }
}

# ---- Montaje ----------------------------------------------------------------
New-Item -ItemType Directory -Path (Join-Path $Dir 'compositions') -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $Dir 'compositions\intro.html'), $intro, $utf8)
[IO.File]::WriteAllText((Join-Path $Dir 'compositions\final.html'), $final, $utf8)
$hosts = New-Object System.Text.StringBuilder
$t = 0.0
$pista = 1
$audios = New-Object System.Text.StringBuilder
$add = {
    param($id, $dur)
    [void]$hosts.AppendLine(@"
      <div id="$id" class="escena" data-composition-id="$id" data-composition-src="compositions/$id.html"
           data-start="$t" data-duration="$dur" data-track-index="1" data-track-kind="graphics" data-width="1920" data-height="1080"></div>
"@)
    if ($voces.ContainsKey($id)) {
        $ini = [Math]::Round($t + $VOZ_INICIO, 2)
        [void]$audios.AppendLine("      <audio id=""voz-$id"" src=""assets/voz/$id.mp3"" data-start=""$ini"" data-duration=""$($voces[$id])"" data-track-index=""10"" data-volume=""1""></audio>")
    }
}
$d = Get-DurConVoz 'intro' $DUR_INTRO
& $add 'intro' $d; $t = [Math]::Round($t + $d, 1)
Write-Output ("  {0,-13} {1,5} s" -f 'intro', $d)
foreach ($e in $escenas) {
    $d0 = New-Escena $e
    $d = Get-DurConVoz $e.Id $d0
    if ($d -gt $d0) { Write-Output ("  {0,-13} {1,5} s  con la voz" -f '', $d) }
    & $add $e.Id $d
    $t = [Math]::Round($t + $d, 1)
}
$d = Get-DurConVoz 'final' $DUR_FINAL
& $add 'final' $d; $t = [Math]::Round($t + $d, 1)
Write-Output ("  {0,-13} {1,5} s" -f 'final', $d)
$faltan = @(@('intro') + @($escenas | ForEach-Object { $_.Id }) + @('final') | Where-Object { -not $voces.ContainsKey($_) })
if ($voces.Count -and $faltan.Count) { Write-Warning "Escenas sin voz: $($faltan -join ', ') (pasa voz.ps1)." }

$index = @"
<!doctype html>
<html lang="$Idioma" data-resolution="landscape">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=1920, height=1080" />
    <!-- Generado por montar.ps1: los cambios van alli, no aqui. -->
    <script src="https://cdn.jsdelivr.net/npm/gsap@3.14.2/dist/gsap.min.js"></script>
    <style>
      * { margin: 0; padding: 0; box-sizing: border-box; }
      html, body { width: 1920px; height: 1080px; overflow: hidden; background: #15171B; }
      #root { position: relative; width: 1920px; height: 1080px; overflow: hidden; }
      .escena { position: absolute; inset: 0; }
    </style>
  </head>
  <body>
    <div id="root" data-composition-id="main" data-start="0" data-duration="$t" data-width="1920" data-height="1080">
$($hosts.ToString().TrimEnd())
$($audios.ToString().TrimEnd())
    </div>
    <script>
      window.__timelines = window.__timelines || {};
      window.__timelines["main"] = gsap.timeline({ paused: true });
    </script>
  </body>
</html>
"@
[IO.File]::WriteAllText((Join-Path $Dir 'index.html'), $index, $utf8)
Write-Output "  total         $t s"
