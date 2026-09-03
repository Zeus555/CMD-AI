#requires -Version 5.1
<#
  build.ps1 - Paso obligatorio despues de editar cualquier fichero.

  Por que existe: Windows PowerShell 5.1 decide la codificacion de un .ps1 por
  su BOM. SIN BOM lo lee como cp1252, y entonces:
    - en el mejor caso 'Eres un asistente util' se convierte en mojibake y se
      manda asi a la API, sin ningun error;
    - en el peor, el destrozo cae sobre un caracter de sintaxis y el script
      ni siquiera parsea ("The string is missing the terminator").
  Los .bat necesitan lo contrario: CRLF y sin BOM.
#>
param([string]$Root = (Split-Path -Parent $PSScriptRoot))

$utf8Bom   = New-Object System.Text.UTF8Encoding $true
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

# SOLO los ficheros de AI 2.0. Nada de -Recurse sobre la raiz: ahi vive
# tambien Script\, con codigo ajeno (search_product.bat, Text.bat) y el
# archivo _viejo\. Reescribir un fichero que no sea UTF-8 leyendolo como
# UTF-8 convierte cada acento en U+FFFD de forma irreversible.
$objetivos = @(
    (Join-Path $Root 'AI.bat')
    (Join-Path $Root 'bin')
    (Join-Path $Root 'lib')
    (Join-Path $Root 'tools')
)

$ficheros = foreach ($o in $objetivos) {
    if (Test-Path -LiteralPath $o -PathType Container) {
        Get-ChildItem $o -Recurse -Include *.ps1, *.bat -File
    } elseif (Test-Path -LiteralPath $o -PathType Leaf) {
        Get-Item -LiteralPath $o
    }
}

foreach ($f in $ficheros) {
    $t = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
    # Si la lectura como UTF-8 produjo U+FFFD, el fichero NO era UTF-8 (por
    # ejemplo, guardado en ANSI/cp1252 con acentos). Reescribirlo ahora
    # consolidaria el destrozo de forma irreversible: se salta y se avisa
    # para que se corrija la codificacion a mano en el editor.
    if ($t.IndexOf([char]0xFFFD) -ge 0) {
        Write-Warning "SALTADO $($f.Name): no es UTF-8 valido; corrige su codificacion a mano."
        continue
    }
    if ($f.Extension -eq '.ps1') {
        [IO.File]::WriteAllText($f.FullName, $t, $utf8Bom)      # BOM obligatorio
        Write-Host "  ps1  BOM   $($f.Name)"
    } else {
        $t = ($t -replace "`r`n", "`n") -replace "`n", "`r`n"
        [IO.File]::WriteAllText($f.FullName, $t, $utf8NoBom)    # CRLF, sin BOM
        Write-Host "  bat  CRLF  $($f.Name)"
    }
}
Write-Host "`nListo."
