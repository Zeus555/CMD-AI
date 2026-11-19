#requires -Version 5.1
# ---------------------------------------------------------------------------
#  idioma.ps1 - El idioma de los mensajes: espanol ('es') o ingles ('en').
#
#  Cada mensaje lleva sus dos versiones en el sitio donde se usa:
#      Write-Host (L 'memoria vaciada' 'memory cleared')
#  L devuelve la del idioma activo. Asi el texto se lee junto al codigo que
#  lo usa y no hay ficheros de traducciones que mantener aparte.
#
#  Lo que escribe el usuario se reconoce SIEMPRE en los dos idiomas ("si" y
#  "yes", "cancelar" y "cancel"): el idioma solo decide lo que se escribe.
#
#  Por defecto 'es', para que una prueba o un script que carga lib\ sin mas
#  siga como antes; ai.ps1 decide el de verdad con Resolve-AIIdioma.
#  Comentarios y expresiones regulares en ASCII (ver tools\build.ps1).
# ---------------------------------------------------------------------------
if (-not (Get-Variable -Name AI_IDIOMA -Scope Script -ErrorAction SilentlyContinue)) { $script:AI_IDIOMA = 'es' }

function L([string]$es, [string]$en) {
    if ($script:AI_IDIOMA -eq 'en') { return $en }
    return $es
}

# 'es', 'en' o $null si el texto no es un idioma que se sepa hablar.
function ConvertTo-AIIdioma([string]$v) {
    $t = "$v".Trim().ToLowerInvariant()
    if ($t -match '^(es|esp|spa|castellano)') { return 'es' }
    if ($t -match '^(en|eng|ingl)') { return 'en' }
    return $null
}

# El orden: lo pedido al lanzarlo (-Lang), la variable AI_LANG, el ajuste
# "language" de settings.json y, si no hay nada de eso:
#   - si la carpeta de datos ya existe, 'es': quien ya lo usaba lo usaba en
#     espanol (antes no habia otro idioma), aunque su Windows este en ingles;
#   - si es la primera vez, el idioma de Windows (es-* -> 'es'; si no, 'en').
function Resolve-AIIdioma([string]$Pedido, [string]$Ajuste, [string]$DataDir) {
    foreach ($v in @($Pedido, $env:AI_LANG, $Ajuste)) {
        $n = ConvertTo-AIIdioma $v
        if ($n) { return $n }
    }
    if ($DataDir -and (Test-Path -LiteralPath $DataDir)) { return 'es' }
    if ((Get-UICulture).TwoLetterISOLanguageName -eq 'es') { return 'es' }
    return 'en'
}

function Set-AIIdioma([string]$Idioma) {
    $n = ConvertTo-AIIdioma $Idioma
    if (-not $n) { throw "idioma desconocido: $Idioma" }
    $script:AI_IDIOMA = $n
}
