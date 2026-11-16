#requires -Version 5.1
# ---------------------------------------------------------------------------
#  Preferencias: lo que el usuario pide que se recuerde en esta y en las
#  proximas conversaciones ("las cifras de dinero en dolares", "la loteria de
#  Nicaragua en cordobas").
#
#  - Viven en preferencias.json, junto a comandos.json.
#  - Solo las escribe el usuario: con /preferencia agregar o empezando el
#    mensaje con "recuerda que...". El modelo no tiene herramienta para
#    guardarlas, asi que una pagina leida en una busqueda no puede colarle
#    una "preferencia" que se repita en todas las conversaciones.
#  - Viajan en la nota de sistema de cada peticion, recortadas: el servidor
#    local tiene 4096 tokens de contexto.
#  Comentarios y expresiones regulares en ASCII (ver tools\build.ps1).
# ---------------------------------------------------------------------------

$AI_PREF_MAX   = 12      # cuantas como mucho
$AI_PREF_LARGO = 200     # caracteres de cada una

# "recuerda que...", "de ahora en adelante...": el mensaje entero es la
# preferencia. Grupo 1: el arranque que se quita; grupo 2: la preferencia.
# Va sobre el texto original (con acentos); por eso las clases [ee].
$AI_PREF_PIDE = '(?is)^\W*(?:(?:por favor|oye|ia),?\s+)?' +
    '((?:recu[e' + [char]0xE9 + ']rda(?:lo|me)?|acu[e' + [char]0xE9 + ']rdate)(?:\s+(?:siempre\s+)?(?:de\s+)?que|\s*:|\s+esto\s*:)' +
    '|ten\s+(?:en\s+cuenta|presente)(?:\s+que|\s*:)' +
    '|toma\s+nota(?:\s+de\s+que|\s*:)' +
    '|(?:gu[a' + [char]0xE1 + ']rda|an[o' + [char]0xF3 + ']ta|ap[u' + [char]0xFA + ']nta)(?:lo|me)?\s+(?:esto\s+)?(?:en|como)\s+(?:mis\s+|tus\s+|una\s+)?preferencias?(?:\s+que|\s*:)?' +
    '|(?:de\s+ahora\s+en\s+adelante|a\s+partir\s+de\s+ahora|desde\s+ahora(?:\s+en\s+adelante)?)\s*,?)' +
    '\s*(.+)$'

function ConvertTo-AIPreferencia {
    <#  Una preferencia limpia: en una fila, sin caracteres de control, sin
        espacios de sobra y recortada. Vacia si no queda nada.  #>
    param([string]$Texto)
    $t = ([string]$Texto) -replace '[\x00-\x1f\x7f]+', ' ' -replace '\s+', ' '
    $t = $t.Trim().Trim('"').Trim()
    if ($t.Length -gt $AI_PREF_LARGO) { $t = $t.Substring(0, $AI_PREF_LARGO).TrimEnd() + '...' }
    if ($t) { $t = $t.Substring(0, 1).ToUpper() + $t.Substring(1) }
    return $t
}

function Read-AIPreferencias {
    <#  Devuelve @{ Lista; Error }. Con el fichero roto, Error lo dice y la
        lista va vacia: asi nadie lo sobrescribe sin querer al agregar otra.  #>
    param([string]$Fichero)
    $r = @{ Lista = @(); Error = '' }
    if (-not (Test-Path -LiteralPath $Fichero)) { return $r }
    try {
        $j = [IO.File]::ReadAllText($Fichero, [Text.Encoding]::UTF8) | ConvertFrom-Json
    } catch {
        $r.Error = "preferencias.json no se puede leer ($Fichero). Arreglalo o borralo."
        return $r
    }
    $r.Lista = @(@($j) | ForEach-Object {
        $t = ConvertTo-AIPreferencia ([string]$_.texto)
        if ($t) { [pscustomobject]@{ Texto = $t; Creado = [string]$_.creado } }
    } | Select-Object -First $AI_PREF_MAX)
    return $r
}

function Save-AIPreferencias {
    param([string]$Fichero, [array]$Lista)
    $dir = Split-Path -Parent $Fichero
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $filas = @($Lista | ForEach-Object { [ordered]@{ texto = $_.Texto; creado = $_.Creado } })
    # ConvertTo-Json de una lista de un elemento por la tuberia da un objeto, no una lista.
    $json = if ($filas.Count -eq 0) { '[]' } else { ConvertTo-Json -InputObject $filas -Depth 3 }
    [IO.File]::WriteAllText($Fichero, $json, (New-Object System.Text.UTF8Encoding $false))
}

function Get-AIPreferenciaPeticion {
    <#  Si el mensaje pide recordar algo ("recuerda que...", "de ahora en
        adelante..."), la preferencia limpia; si no, $null. Una pregunta
        ("recuerdas que...?") no cuenta.  #>
    param([string]$Texto)
    $t = ([string]$Texto).Trim()
    if ($t.Length -gt 400) { return $null }
    if ($t -notmatch $AI_PREF_PIDE) { return $null }
    $p = ConvertTo-AIPreferencia $Matches[2]
    if (-not $p -or $p.Length -lt 3) { return $null }
    return $p
}

function Get-AIPreferenciasNota {
    <#  Lo que se anade a la instruccion de sistema. Sin preferencias, solo el
        aviso de que el modelo no puede guardar nada por su cuenta (sin el,
        contestaba "lo recordare" y era falso).  #>
    param([array]$Lista)
    $nota = 'Tu no puedes guardar nada para otras conversaciones. Si el usuario te pide que recuerdes algo para la proxima vez, no digas que lo recordaras: dile que empiece el mensaje con "recuerda que" o que use /preferencia agregar.'
    if ($Lista -and $Lista.Count) {
        $nota += ' Estas son las preferencias que el usuario guardo; las escribio el mismo. Siguelas siempre que vengan al caso, salvo que en este mensaje pida otra cosa:'
        foreach ($p in $Lista) { $nota += "`n- $($p.Texto)" }
        # Sin esto, con "cifras en dolares" y una pagina en cordobas, Gemma 4
        # E4B daba solo los cordobas: no inventaba, pero no seguia la
        # preferencia.
        $nota += "`nSi una preferencia pide una moneda y la fuente da otra, no conviertas con un cambio de memoria: busca el tipo de cambio, da la cifra de la fuente y su equivalente diciendo el cambio usado. Si no puedes buscarlo, da la cifra de la fuente y di que no tienes el cambio."
    }
    return $nota
}
