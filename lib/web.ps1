#requires -Version 5.1
# ============================================================================
#  web.ps1 - Buscar en internet desde la consola, sin abrir el navegador.
#
#  Como funciona: a los modelos se les ofrece una herramienta, buscar_web
#  (el "tools" de /chat/completions, el mismo dialecto en OpenAI, xAI, Ollama
#  y llama-server). El MODELO decide si la necesita: "cuanto es 748 por 6" o
#  "que es un BOM" los contesta solo; "a como esta el dolar hoy" o "noticias
#  de hoy" piden la herramienta. Entonces se busca en DuckDuckGo (gratis, sin
#  clave), se leen las primeras paginas y el modelo contesta con eso.
#
#  Solo si hay salida: antes de cada turno se mira, con un plazo corto, si se
#  llega a DuckDuckGo. Sin conexion la herramienta no se ofrece y el modelo
#  sabe que no puede buscar, asi que no se queda esperando ni inventa que
#  busco.
#
#  Se apaga con -NoWeb, con "web": false en settings.json o con /web off.
# ============================================================================

. (Join-Path $PSScriptRoot 'idioma.ps1')
$AI_WEB_SEARCH_URL = 'https://html.duckduckgo.com/html/?q='
$AI_WEB_HOST       = 'html.duckduckgo.com'

# La herramienta tal como viaja en la peticion. La descripcion es lo que el
# modelo lee para decidir: datos que cambian o que no sabe, nunca cuentas ni
# definiciones. Es una funcion para que salga en el idioma activo aunque se
# cambie a mitad de la sesion (/language); el nombre y el parametro no cambian.
function Get-AIWebTool {
    return @{
        type     = 'function'
        function = @{
            name        = 'buscar_web'
            description = (L 'Busca en internet y devuelve los resultados con el texto de las primeras paginas. Usala para datos que cambian con el tiempo o que no conoces con seguridad: precios, tipo de cambio, clima, noticias, resultados deportivos, horarios, versiones recientes, personas o sitios concretos. No la uses para cuentas, definiciones, traducciones ni charla.' 'Searches the internet and returns the results with the text of the first pages. Use it for data that changes over time or that you do not know for sure: prices, exchange rates, weather, news, sports results, opening hours, recent versions, specific people or places. Do not use it for arithmetic, definitions, translations or small talk.')
            parameters  = @{
                type       = 'object'
                properties = @{
                    consulta = @{ type = 'string'; description = (L 'lo que se busca, en pocas palabras, como se escribiria en un buscador' 'what to search for, in a few words, as you would type it into a search engine') }
                }
                required   = @('consulta')
            }
        }
    }
}
$AI_WEB_TOOL = Get-AIWebTool

# ---------------------------------------------------------------------------
#  Hay salida?
#  Una conexion TCP a DuckDuckGo con plazo de 2 s. No se usa ping: muchas
#  redes (y Windows por defecto en algunas) bloquean ICMP y daria "sin
#  internet" con internet. El resultado se recuerda un rato para no pagar
#  la comprobacion en cada turno, pero poco: la laptop entra y sale de redes.
# ---------------------------------------------------------------------------
$script:AINet = @{ Ok = $false; When = [DateTime]::MinValue }

function Test-AIInternet {
    param([switch]$Force)
    $edad = ([DateTime]::UtcNow - $script:AINet.When).TotalSeconds
    $vale = if ($script:AINet.Ok) { 60 } else { 15 }
    if (-not $Force -and $edad -lt $vale) { return $script:AINet.Ok }

    $ok = $false
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $ar = $tcp.BeginConnect($AI_WEB_HOST, 443, $null, $null)
        if ($ar.AsyncWaitHandle.WaitOne(2000)) {
            try { $tcp.EndConnect($ar); $ok = $tcp.Connected } catch { $ok = $false }
        }
    } catch { $ok = $false }      # sin DNS (sin red) lanza aqui
    finally { $tcp.Close() }

    $script:AINet = @{ Ok = $ok; When = [DateTime]::UtcNow }
    return $ok
}

# ---------------------------------------------------------------------------
#  Guarda de destinos internos
#  Las direcciones vienen de una pagina de resultados, es decir, de fuera. Un
#  resultado (o una redireccion) que apunte a 127.0.0.1, a la red de casa o a
#  la del router no se pide nunca: el llama-server, el router y el NAS estan
#  ahi. Ante la duda (no se analiza o no resuelve) cuenta como interna.
# ---------------------------------------------------------------------------
function Test-AIInternalIp([Net.IPAddress]$ip) {
    if ($ip.IsIPv4MappedToIPv6) { $ip = $ip.MapToIPv4() }
    $b = $ip.GetAddressBytes()
    if ($ip.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork) {
        return ($b[0] -eq 0) -or ($b[0] -eq 10) -or ($b[0] -eq 127) -or
               ($b[0] -eq 100 -and ($b[1] -band 0xC0) -eq 64) -or
               ($b[0] -eq 169 -and $b[1] -eq 254) -or
               ($b[0] -eq 172 -and ($b[1] -band 0xF0) -eq 16) -or
               ($b[0] -eq 192 -and $b[1] -eq 168) -or
               ($b[0] -ge 224)
    }
    return [Net.IPAddress]::IsLoopback($ip) -or $ip.Equals([Net.IPAddress]::IPv6Any) -or
           $ip.IsIPv6LinkLocal -or $ip.IsIPv6SiteLocal -or $ip.IsIPv6Multicast -or
           (($b[0] -band 0xFE) -eq 0xFC)
}

function Test-AIInternalUrl([string]$u) {
    $uri = $null
    if (-not [Uri]::TryCreate($u, [UriKind]::Absolute, [ref]$uri)) { return $true }
    if ($uri.Scheme -ne 'http' -and $uri.Scheme -ne 'https') { return $true }
    if ($uri.UserInfo -or -not $uri.DnsSafeHost) { return $true }
    try {
        $dns = [Net.Dns]::GetHostAddressesAsync($uri.DnsSafeHost)
        if (-not $dns.Wait(5000)) { return $true }
        $ips = @($dns.Result)
    } catch { return $true }
    if ($ips.Count -eq 0) { return $true }
    foreach ($ip in $ips) { if (Test-AIInternalIp $ip) { return $true } }
    return $false
}

# ---------------------------------------------------------------------------
#  Descarga acotada en tiempo y en tamano. Las redirecciones se siguen a mano
#  para validar cada salto ANTES de pedirlo.
# ---------------------------------------------------------------------------
function Get-AIWebPage {
    param([string]$Url, [int]$Secs = 10, [int]$MaxBytes = 2097152)

    $script:AIWebStatus = 0
    $limite = [DateTime]::UtcNow.AddSeconds($Secs)
    for ($salto = 0; ; $salto++) {
        if ($salto -gt 5) { throw (L 'demasiadas redirecciones' 'too many redirects') }
        if (Test-AIInternalUrl $Url) { throw (L 'destino interno' 'internal destination') }
        $resta = [int]($limite - [DateTime]::UtcNow).TotalMilliseconds
        if ($resta -le 0) { throw (L 'tiempo agotado' 'timed out') }
        $r = [Net.HttpWebRequest]::Create($Url)
        $r.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
        $r.Accept = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
        $r.Headers.Add('Accept-Language', (L 'es,en;q=0.7' 'en,es;q=0.7'))
        $r.AutomaticDecompression = [Net.DecompressionMethods]::GZip -bor [Net.DecompressionMethods]::Deflate
        $r.Timeout = $resta
        $r.ReadWriteTimeout = 8000
        $r.AllowAutoRedirect = $false
        try { $resp = $r.GetResponse() }
        catch {
            $we = $_.Exception.GetBaseException()
            if ($we -is [Net.WebException] -and $we.Response) { $script:AIWebStatus = [int]$we.Response.StatusCode }
            throw
        }
        $cod = [int]$resp.StatusCode
        $script:AIWebStatus = $cod
        $destino = $resp.Headers['Location']
        if ($cod -lt 300 -or $cod -ge 400 -or -not $destino) { break }
        $resp.Close()
        $Url = ([Uri]::new([Uri]$Url, $destino)).AbsoluteUri
    }
    try {
        $ct = [string]$resp.ContentType
        if ($ct -and $ct -notmatch 'text/|html|xml|json') { throw (L "tipo no textual: $ct" "not a text type: $ct") }
        $st  = $resp.GetResponseStream()
        $ms  = New-Object IO.MemoryStream
        $buf = New-Object byte[] 65536
        $fin = [DateTime]::UtcNow.AddSeconds($Secs)
        while ($ms.Length -lt $MaxBytes -and [DateTime]::UtcNow -lt $fin) {
            $n = $st.Read($buf, 0, $buf.Length)
            if ($n -le 0) { break }
            $ms.Write($buf, 0, $n)
        }
        $enc = [Text.Encoding]::UTF8
        if ($resp.CharacterSet) { try { $enc = [Text.Encoding]::GetEncoding($resp.CharacterSet) } catch { } }
        return $enc.GetString($ms.ToArray())
    } finally { $resp.Close() }
}

function ConvertTo-AIPlainText {
    <#  Al modelo le llega solo el texto visible: fuera codigo, estilos,
        comentarios, svg, menus y pies.  #>
    param([string]$Html)
    $t = $Html -replace '(?s)<!--.*?-->', ' '
    $t = $t -replace '(?is)<(script|style|noscript|template|svg|iframe|object|canvas|nav|footer|header|form)[^>]*>.*?</\1>', ' '
    $t = $t -replace '(?i)<(br|/p|/div|/li|/tr|/h[1-6])[^>]*>', "`n"
    $t = $t -replace '<[^>]+>', ' '
    $t = [Net.WebUtility]::HtmlDecode($t)
    $t = $t -replace '[ \t ]+', ' ' -replace '(\s*\n\s*)+', "`n"
    return $t.Trim()
}

# ---------------------------------------------------------------------------
#  Buscar: la version HTML de DuckDuckGo, la misma que usa Gemma Portable.
#  Devuelve @{ Estado = ok|vacio|bloqueado|fallo; Motivo; Items }.
# ---------------------------------------------------------------------------
function Search-AIWeb {
    param([string]$Query)

    try { $html = Get-AIWebPage ($AI_WEB_SEARCH_URL + [Uri]::EscapeDataString($Query)) 12 }
    catch {
        $cod = $script:AIWebStatus
        if ($cod -eq 403 -or $cod -eq 429 -or $cod -eq 418) {
            return @{ Estado = 'bloqueado'; Motivo = (L "DuckDuckGo respondio $cod" "DuckDuckGo answered $cod"); Items = @() }
        }
        return @{ Estado = 'fallo'; Motivo = (L "DuckDuckGo no respondio ($($_.Exception.Message))" "DuckDuckGo did not answer ($($_.Exception.Message))"); Items = @() }
    }

    $rx = [regex]'(?s)<a[^>]*class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>.*?class="result__snippet"[^>]*>(.*?)</a>'
    $items = @()
    foreach ($m in $rx.Matches($html)) {
        $u = $m.Groups[1].Value
        if ($u -match 'uddg=([^&]+)') { $u = [Uri]::UnescapeDataString($Matches[1]) }
        if ($u.StartsWith('//')) { $u = 'https:' + $u }
        # los anuncios de DuckDuckGo pasan por y.js: no son resultados
        if ($u -match '^https?://duckduckgo\.com/y\.js') { continue }
        $items += [pscustomobject]@{
            Title   = [Net.WebUtility]::HtmlDecode(($m.Groups[2].Value -replace '<[^>]+>', '')).Trim()
            Url     = $u
            Snippet = [Net.WebUtility]::HtmlDecode(($m.Groups[3].Value -replace '<[^>]+>', '')).Trim()
        }
        if ($items.Count -ge 6) { break }
    }
    if ($items.Count -gt 0) { return @{ Estado = 'ok'; Motivo = ''; Items = $items } }

    # Sin resultados de verdad, o la pagina con que DuckDuckGo despacha a quien
    # toma por un robot (llega con 202 y un formulario de comprobacion). La
    # pagina repite la consulta, asi que una senal que ya venia en ella no
    # cuenta.
    $robot = ($script:AIWebStatus -eq 202)
    foreach ($s in 'anomaly', 'challenge-form', 'bots use DuckDuckGo') {
        if ($html.IndexOf($s, [StringComparison]::OrdinalIgnoreCase) -ge 0 -and
            $Query.IndexOf($s, [StringComparison]::OrdinalIgnoreCase) -lt 0) { $robot = $true }
    }
    if ($robot) { return @{ Estado = 'bloqueado'; Motivo = (L 'DuckDuckGo pide comprobar que no es un robot' 'DuckDuckGo asks to check that this is not a robot'); Items = @() } }
    return @{ Estado = 'vacio'; Motivo = (L 'DuckDuckGo no tiene resultados' 'DuckDuckGo has no results'); Items = @() }
}

# ---------------------------------------------------------------------------
#  Lo que recibe el modelo: los resultados con su resumen y el texto de las
#  primeras paginas que se dejen leer. Acotado: el servidor local trabaja con
#  4096 tokens de contexto y la conversacion tambien cuenta.
# ---------------------------------------------------------------------------
function Invoke-AIWebSearch {
    param([string]$Query, [int]$Pages = 2, [int]$CharsPerPage = 1800)

    $hoy = Get-Date -Format 'yyyy-MM-dd'
    $r = Search-AIWeb $Query
    if ($r.Estado -ne 'ok') {
        $txt = if ($r.Estado -eq 'vacio') { (L "La busqueda '$Query' no dio resultados." "The search '$Query' gave no results.") }
               else { (L "No se pudo buscar '$Query': $($r.Motivo). Dile al usuario que la busqueda fallo; no inventes el dato." "Could not search '$Query': $($r.Motivo). Tell the user the search failed; do not make up the data.") }
        return [pscustomobject]@{ Ok = $false; Text = $txt; Sources = @(); Motivo = $r.Motivo }
    }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine((L "Resultados de la busqueda '$Query' (hecha hoy, $hoy):" "Results of the search '$Query' (done today, $hoy):"))
    $i = 0
    foreach ($it in $r.Items) {
        $i++
        [void]$sb.AppendLine("$i. $($it.Title) - $($it.Url)")
        if ($it.Snippet) { [void]$sb.AppendLine("   $($it.Snippet)") }
    }

    # Se prueba con los primeros resultados hasta leer $Pages paginas, con un
    # plazo total: mejor contestar con los resumenes que hacer esperar.
    $leidas  = @()
    $limite  = [DateTime]::UtcNow.AddSeconds(18)
    foreach ($it in ($r.Items | Select-Object -First ($Pages + 2))) {
        if ($leidas.Count -ge $Pages -or [DateTime]::UtcNow -gt $limite) { break }
        try {
            $t = ConvertTo-AIPlainText (Get-AIWebPage $it.Url 8)
            if ($t.Length -lt 200) { continue }
            if ($t.Length -gt $CharsPerPage) { $t = $t.Substring(0, $CharsPerPage) + ' [...]' }
            $leidas += [pscustomobject]@{ Url = $it.Url; Text = $t }
        } catch { continue }
    }
    foreach ($p in $leidas) {
        [void]$sb.AppendLine()
        [void]$sb.AppendLine((L "--- texto de $($p.Url) ---" "--- text of $($p.Url) ---"))
        [void]$sb.AppendLine($p.Text)
    }

    $fuentes = if ($leidas.Count) { @($leidas | ForEach-Object { $_.Url }) }
               else { @($r.Items | Select-Object -First 2 | ForEach-Object { $_.Url }) }
    return [pscustomobject]@{ Ok = $true; Text = $sb.ToString().Trim(); Sources = $fuentes; Motivo = '' }
}
