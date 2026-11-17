#requires -Version 5.1
<#
  probar.ps1 - Pasa las pruebas de AI 2.0 y dice si alguna falla.

    .\tests\probar.ps1             las que no necesitan modelo (unos segundos)
    .\tests\probar.ps1 -Red        y ademas unas pocas peticiones a internet
    .\tests\probar.ps1 -Modelo     y ademas el dialogo y /comando agregar con el
                                   modelo de verdad (necesita el llama-server
                                   en marcha; tarda varios minutos)

  Cada prueba corre en su propio powershell.exe: algunas cambian variables
  de lib\ (el plazo de los comandos, los colores) y no deben pisarse entre si.
  Sale con el numero de pruebas que fallaron (0 = todo bien).
#>
param([switch]$Red, [switch]$Modelo, [string]$Proveedor = 'gemma')

$ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$aqui = $PSScriptRoot

$pruebas = @(
    @{ Nombre = 'comandos guardados'; Fichero = 'comandos.ps1'; Args = @(if ($Red) { '-Red' }) }
    @{ Nombre = 'frases del equipo'; Fichero = 'equipo-frases.ps1'; Args = @() }
    @{ Nombre = 'datos del equipo'; Fichero = 'equipo.ps1'; Args = @() }
    @{ Nombre = 'preferencias'; Fichero = 'preferencias.ps1'; Args = @() }
    @{ Nombre = 'consultas web'; Fichero = 'consultas.ps1'; Args = @(if ($Red) { '-Red' }) }
    @{ Nombre = 'documentos'; Fichero = 'documentos.ps1'; Args = @() }
)
if ($Modelo) {
    $pruebas += @{ Nombre = 'dialogo, con el modelo'; Fichero = 'dialogo.ps1'; Args = @('-Proveedor', $Proveedor) }
    $pruebas += @{ Nombre = '/comando agregar, con el modelo'; Fichero = 'agregar.ps1'; Args = @('-Proveedor', $Proveedor) }
} else {
    $pruebas += @{ Nombre = 'reconocer peticiones'; Fichero = 'dialogo.ps1'; Args = @('-SoloReconocer') }
}

$fallan = @()
foreach ($p in $pruebas) {
    Write-Host ''
    Write-Host "=== $($p.Nombre)"
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $a = @($p.Args)
    & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $aqui $p.Fichero) @a
    $codigo = $LASTEXITCODE
    $s = [Math]::Round($sw.Elapsed.TotalSeconds, 1)
    if ($codigo -eq 0) { Write-Host "--- bien ($s s)" }
    else { Write-Host "--- FALLA: $codigo mal ($s s)"; $fallan += $p.Nombre }
}

Write-Host ''
if ($fallan.Count) { Write-Host "FALLAN $($fallan.Count) de $($pruebas.Count): $($fallan -join ', ')" }
else { Write-Host "Todo bien: $($pruebas.Count) pruebas." }
exit $fallan.Count
