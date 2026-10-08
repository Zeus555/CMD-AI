#requires -Version 5.1
# ============================================================================
#  core.ps1 - Nucleo unico agnostico del proveedor.
#  Cero curl, cero gawk, cero regex sobre JSON, cero desplazamientos de bytes.
#
#  NOTA sobre Set-StrictMode: NO se activa a proposito. En SSE los eventos
#  llegan con formas irregulares (choices vacio, delta sin content) y sin
#  StrictMode esos accesos devuelven $null en silencio, que es justo lo que
#  queremos. Con StrictMode 2.0 lanzarian PropertyNotFoundException.
# ============================================================================

function Get-AIKey {
    <#  Lee la clave. Nunca viaja por una linea de comandos.  #>
    param([hashtable]$Provider)

    $n = $Provider.KeyVar

    # Leer el ambito 'User' va directo a HKCU\Environment, asi que la clave se
    # ve en el mismo instante en que se guarda: sin abrir consola nueva, sin
    # cerrar sesion, sin reiniciar.
    $k = [Environment]::GetEnvironmentVariable($n, 'User')
    if ([string]::IsNullOrWhiteSpace($k)) {
        $k = [Environment]::GetEnvironmentVariable($n, 'Process')
    }
    if ([string]::IsNullOrWhiteSpace($k)) {
        if (-not $Provider.NeedsKey) { return 'ollama' }   # el shim lo ignora
        return $null
    }
    return $k.Trim()
}

# ---------------------------------------------------------------------------
#  Filtro de <think>
#  Los modelos de razonamiento locales devuelven <think>...</think> dentro de
#  content. Mirar cada fragmento SSE por separado NO funciona: llegan de 1 a 4
#  caracteres y la etiqueta viene partida ('<thi' + 'nk>razonando'). Hay que
#  acumular. Ademas se retiene una cola del tamano de la etiqueta mas larga
#  para no soltar medio '</think>' al usuario.
# ---------------------------------------------------------------------------
function New-AIThinkFilter {
    return [pscustomobject]@{ Buf = ''; Dentro = $false }
}

function Invoke-AIThinkFilter {
    <#  Recibe un fragmento y devuelve SOLO el texto que debe verse.  #>
    param([pscustomobject]$F, [string]$Token)

    $F.Buf += $Token
    $salida = ''

    while ($true) {
        if (-not $F.Dentro) {
            $i = $F.Buf.IndexOf('<think>')
            if ($i -ge 0) {
                $salida += $F.Buf.Substring(0, $i)
                $F.Buf = $F.Buf.Substring($i + 7)
                $F.Dentro = $true
                continue
            }
            # Retener una cola por si '<think>' viene partido entre fragmentos.
            $keep = [Math]::Min(7, $F.Buf.Length)
            if ($F.Buf.Length -gt $keep) {
                $salida += $F.Buf.Substring(0, $F.Buf.Length - $keep)
                $F.Buf = $F.Buf.Substring($F.Buf.Length - $keep)
            }
            break
        }
        else {
            $i = $F.Buf.IndexOf('</think>')
            if ($i -ge 0) {
                $F.Buf = $F.Buf.Substring($i + 8)
                $F.Dentro = $false
                continue
            }
            # Dentro del bloque no sale nada; se retiene solo la cola.
            $keep = [Math]::Min(8, $F.Buf.Length)
            if ($F.Buf.Length -gt $keep) { $F.Buf = $F.Buf.Substring($F.Buf.Length - $keep) }
            break
        }
    }
    return $salida
}

function Close-AIThinkFilter {
    <#  Suelta lo que quede pendiente al terminar el flujo.  #>
    param([pscustomobject]$F)
    if ($F.Dentro) { $F.Buf = ''; return '' }
    $r = $F.Buf; $F.Buf = ''
    return $r
}

function Get-AIErrorText {
    <#  Traduce un fallo HTTP a una linea legible.
        Las APIs NO comparten forma de error:
          OpenAI / Ollama -> {"error":{"message":"..."}}   (objeto)
          xAI             -> {"code":"...","error":"..."}  (cadena plana)
          xAI con JSON malformado -> texto plano, ni siquiera JSON
        Ademas xAI responde 400 (no 401) a una clave invalida, asi que NO se
        ramifica por codigo de estado: se muestran codigo y mensaje siempre. #>
    param($ErrorRecord)

    $resp = $null
    try { $resp = $ErrorRecord.Exception.Response } catch { }
    if (-not $resp) {
        return "sin respuesta del servidor -> $($ErrorRecord.Exception.Message)"
    }

    $code = 0
    try { $code = [int]$resp.StatusCode } catch { }

    $raw = ''
    try {
        # Con HttpWebRequest crudo el stream de error NO viene consumido
        # (a diferencia de Invoke-RestMethod), asi que aqui si se puede leer.
        $s = $resp.GetResponseStream()
        if ($s) {
            $rd = New-Object System.IO.StreamReader($s, [Text.Encoding]::UTF8)
            $raw = $rd.ReadToEnd()
            $rd.Close()
        }
    } catch { }

    $msg = $null
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        try {
            $o = $raw | ConvertFrom-Json
            if     ($o.error -is [string]) { $msg = $o.error }          # xAI
            elseif ($o.error)              { $msg = $o.error.message }  # OpenAI/Ollama
            elseif ($o.message)            { $msg = $o.message }
        } catch {
            $msg = $raw.Trim()                                          # texto plano
        }
    }
    if ([string]::IsNullOrWhiteSpace($msg)) { $msg = '(sin cuerpo)' }

    return ("HTTP {0} -> {1}" -f $code, ($msg -replace '\s+', ' ').Trim())
}

function Invoke-AIChat {
    <#  Una sola funcion para todos los proveedores.
        Devuelve [pscustomobject] @{ Text; Model; Ok; Error }
        Si se pasa -OnToken, se invoca por cada fragmento ya filtrado.  #>
    param(
        [Parameter(Mandatory)][hashtable]$Provider,
        [Parameter(Mandatory)][array]$Messages,
        [string]$Model,
        [double]$Temperature = 0.7,
        [scriptblock]$OnToken,
        [switch]$NoStream,
        [int]$TimeoutSec = 30
    )

    $key = Get-AIKey $Provider
    if (-not $key) {
        return [pscustomobject]@{
            Text = ''; Model = $null; Ok = $false
            Error = "falta la variable de entorno $($Provider.KeyVar). Ejecuta:  AI -SetKey $($Provider.KeyVar)"
        }
    }

    if (-not $Model) { $Model = $Provider.Model }
    # Plazo propio del proveedor (campo Timeout de providers.ps1). Un
    # -TimeoutSec explicito siempre gana.
    if ($Provider.Timeout -and -not $PSBoundParameters.ContainsKey('TimeoutSec')) {
        $TimeoutSec = [int]$Provider.Timeout
    }
    $stream = (-not $NoStream) -and $Provider.Stream

    # ---- Cuerpo de la peticion -------------------------------------------
    $body = @{
        model       = $Model
        messages    = @($Messages)
        temperature = $Temperature
        stream      = $stream
    }
    foreach ($k in $Provider.Extra.Keys) { $body[$k] = $Provider.Extra[$k] }

    # -Depth 10 es OBLIGATORIO: con la profundidad por defecto (2)
    # ConvertTo-Json escribe la cadena literal "System.Collections.Hashtable"
    # sin dar ningun error ni aviso.
    $json  = $body | ConvertTo-Json -Depth 10 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)

    # ---- Peticion ---------------------------------------------------------
    $url = $Provider.BaseUrl.TrimEnd('/') + '/chat/completions'
    $req = [System.Net.HttpWebRequest]::Create($url)
    $req.Method           = 'POST'
    $req.ContentType      = 'application/json; charset=utf-8'
    $req.ContentLength    = $bytes.Length
    $req.Timeout          = $TimeoutSec * 1000   # conectar + enviar + esperar el inicio de la respuesta
    $req.ReadWriteTimeout = 600000               # leer: el modelo puede tardar
    $req.UserAgent        = 'PRC-AI/2.0'
    $req.ServicePoint.Expect100Continue = $false
    # La clave vive en una cabecera en memoria. Nunca en el PEB de un proceso,
    # asi que no aparece en Win32_Process.CommandLine como pasaba con curl.
    $req.Headers.Add('Authorization', "Bearer $key")
    # El proxy del sistema rompe localhost: para los servidores locales
    # (Ollama, llama-server) se desactiva.
    if ($url -match '^http://(localhost|127\.0\.0\.1)') { $req.Proxy = $null }

    $resp = $null
    try {
        $rs = $req.GetRequestStream()
        $rs.Write($bytes, 0, $bytes.Length)
        $rs.Close()
        $resp = $req.GetResponse()
    }
    catch [System.Net.WebException] {
        # ESTO es lo que `for /F ... in ('curl ...')` jamas pudo detectar.
        $err = Get-AIErrorText $_
        # ConnectFailure = nadie escucha en esa direccion. En un servidor local
        # el arreglo es arrancarlo y el proveedor sabe como (campo Hint de
        # providers.ps1). Un plazo vencido NO entra aqui: es otro Status.
        if ($Provider.Hint -and $_.Exception.Status -eq [System.Net.WebExceptionStatus]::ConnectFailure) {
            $err = "nadie escucha en $($Provider.BaseUrl). $($Provider.Hint)"
        }
        return [pscustomobject]@{
            Text = ''; Model = $null; Ok = $false; Error = $err
        }
    }
    catch {
        return [pscustomobject]@{
            Text = ''; Model = $null; Ok = $false; Error = $_.Exception.Message
        }
    }

    # ---- Lectura ----------------------------------------------------------
    $sb        = New-Object System.Text.StringBuilder
    $realModel = $null
    # Un flujo SSE bien terminado trae finish_reason y/o 'data: [DONE]'. Si el
    # servidor cierra la conexion antes (un llama-server en modo router que
    # descarga el modelo porque otro cliente pidio el otro), el flujo acaba
    # limpio y a medias: sin esta marca se daba por buena una respuesta cortada.
    $completo  = $false
    $filtro    = if ($Provider.HideThink) { New-AIThinkFilter } else { $null }

    # StreamReader con UTF8 mantiene el estado del decodificador entre
    # lecturas, asi que un caracter multibyte partido entre dos paquetes TCP
    # se recompone bien. Por eso NO se leen bytes a mano.
    $sr = New-Object System.IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
    try {
        if ($stream) {
            while (-not $sr.EndOfStream) {
                $line = $sr.ReadLine()
                if ([string]::IsNullOrWhiteSpace($line))  { continue }
                if (-not $line.StartsWith('data:'))       { continue }
                $d = $line.Substring(5).Trim()
                if ($d -eq '[DONE]') { $completo = $true; break }

                $ev = $null
                try { $ev = $d | ConvertFrom-Json } catch { continue }

                # El modelo REAL se lee de la respuesta, nunca se da por hecho
                # el que se pidio: xAI sustituye nombres retirados en silencio.
                if (-not $realModel -and $ev.model) { $realModel = $ev.model }
                # Un evento de error en mitad del flujo no trae choices:
                # indexar $null lanzaria 'Cannot index into a null array'.
                $ch = @($ev.choices)[0]
                if ($ch.finish_reason) { $completo = $true }

                $tok = $ch.delta.content
                if ($tok) {
                    if ($filtro) { $tok = Invoke-AIThinkFilter $filtro $tok }
                    if ($tok) {
                        [void]$sb.Append($tok)
                        if ($OnToken) { & $OnToken $tok }
                    }
                }
            }
            if ($filtro) {
                $tok = Close-AIThinkFilter $filtro
                if ($tok) {
                    [void]$sb.Append($tok)
                    if ($OnToken) { & $OnToken $tok }
                }
            }
        }
        else {
            $all = $sr.ReadToEnd()
            $o   = $all | ConvertFrom-Json      # inmune a saltos de linea y sangrado
            $realModel = $o.model
            $tok = $o.choices[0].message.content
            if ($tok) {
                if ($filtro) {
                    $tok = (Invoke-AIThinkFilter $filtro $tok) + (Close-AIThinkFilter $filtro)
                }
                if ($tok) {
                    [void]$sb.Append($tok)
                    if ($OnToken) { & $OnToken $tok }
                }
            }
        }
    }
    finally {
        $sr.Close()
        if ($resp) { $resp.Close() }
    }

    if ($stream -and -not $completo) {
        $corte = 'la respuesta se corto: el servidor cerro el flujo sin terminarla.'
        if ($Provider.Hint) {
            $corte += ' Pasa si otro cliente pide el otro modelo (solo cabe uno en memoria): repite la pregunta.'
        }
        return [pscustomobject]@{
            Text = $sb.ToString(); Model = $realModel; Ok = $false; Error = $corte
        }
    }

    return [pscustomobject]@{
        Text  = $sb.ToString()
        Model = $realModel
        Ok    = $true
        Error = $null
    }
}

function Test-AIProvider {
    <#  Diagnostico barato: dice si hay clave, si el extremo contesta y, en los
        proveedores locales, si ofrece el modelo de la entrada.  #>
    param([hashtable]$Provider)

    $key = Get-AIKey $Provider
    # Get-AIKey devuelve un relleno para los proveedores que no piden clave.
    # Mostrarlo como "definida (6 chars)" haria creer que hay una guardada.
    $real = [Environment]::GetEnvironmentVariable($Provider.KeyVar, 'User')
    $r = [ordered]@{
        Proveedor = $Provider.Label
        Variable  = $Provider.KeyVar
        Clave     = if ($real)                   { 'definida (' + $real.Length + ' chars)' }
                    elseif (-not $Provider.NeedsKey) { 'no hace falta' }
                    else                         { 'FALTA' }
        Modelo    = $Provider.Model
        Estado    = 'no probado'
    }
    if (-not $key) { $r.Estado = 'sin clave'; return [pscustomobject]$r }

    # /v1/models responde en todos y no gasta tokens.
    $url = $Provider.BaseUrl.TrimEnd('/') + '/models'
    try {
        $req = [System.Net.HttpWebRequest]::Create($url)
        $req.Timeout = 10000
        $req.Headers.Add('Authorization', "Bearer $key")
        if ($url -match '^http://(localhost|127\.0\.0\.1)') { $req.Proxy = $null }
        $resp = $req.GetResponse()
        $r.Estado = 'OK'
        # Solo en los locales: que el servidor conteste no dice que ofrezca el
        # modelo de ESTA entrada (dos entradas pueden compartir servidor, y en
        # ese puerto puede haber un llama-server de un solo modelo, que ignora
        # el campo model y contesta con el suyo sin avisar). /models lista lo
        # que hay y, en llama-server, no despierta al modelo dormido.
        if (-not $Provider.NeedsKey) {
            $lista = $null
            $sr = New-Object System.IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
            try { $lista = ($sr.ReadToEnd() | ConvertFrom-Json).data } catch { } finally { $sr.Close() }
            if ($lista) {
                $m = @($lista | Where-Object { $_.id -ceq $Provider.Model -or @($_.aliases) -ccontains $Provider.Model })
                if ($m.Count -eq 0)             { $r.Estado = "contesta, pero no ofrece '$($Provider.Model)'" }
                elseif ($m[0].status.value)     { $r.Estado = "OK ($($m[0].status.value))" }
            }
        }
        $resp.Close()
    }
    catch [System.Net.WebException] {
        $r.Estado = (Get-AIErrorText $_)
        # Igual que en Invoke-AIChat: si nadie escucha, decir como arrancarlo.
        if ($Provider.Hint -and $_.Exception.Status -eq [System.Net.WebExceptionStatus]::ConnectFailure) {
            $r.Estado = "parado. $($Provider.Hint)"
        }
    }
    catch                           { $r.Estado = $_.Exception.Message }

    return [pscustomobject]$r
}
