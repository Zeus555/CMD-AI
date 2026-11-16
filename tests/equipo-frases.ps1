# Que frases piden datos del equipo, y cuales (lib\equipo.ps1,
# Find-AIEquipoGroups). Cada linea de datos\equipo-frases.txt es
# «grupos esperados|frase»; «-» quiere decir que la frase no pide nada.
param([string]$Raiz = (Split-Path -Parent $PSScriptRoot),
      [string]$Lista = (Join-Path $PSScriptRoot 'datos\equipo-frases.txt'))
. (Join-Path $Raiz 'lib\equipo.ps1')
$mal = 0; $n = 0
foreach ($l in [IO.File]::ReadAllLines($Lista, [Text.Encoding]::UTF8)) {
    if (-not $l.Trim()) { continue }
    $i = $l.IndexOf('|'); $esp = $l.Substring(0, $i); $frase = $l.Substring($i + 1)
    $got = (Find-AIEquipoGroups $frase) -join ','
    if (-not $got) { $got = '-' }
    $n++
    if ($got -ne $esp) { $mal++; Write-Output "MAL  esperado=$esp  sale=$got  : $frase" }
}
$largo = 'resume esto' + "`n`n--- contexto ---`n" + 'mi ip es 10.0.0.1 y la bateria esta al 3 %'
$n++; if ((Find-AIEquipoGroups $largo).Count -ne 0) { $mal++; Write-Output 'MAL  el contexto entubado no cuenta' }
$n++; if ((Find-AIEquipoGroups ('cual es mi ip ' * 30)).Count -ne 0) { $mal++; Write-Output 'MAL  un mensaje largo no se toma' }
Write-Output "detector: $n frases, $mal mal"
exit $mal
