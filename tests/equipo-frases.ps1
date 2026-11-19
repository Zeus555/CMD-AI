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
# Las mismas ideas en ingles: lo que escribe el usuario se reconoce en los
# dos idiomas, sea cual sea el activo.
$ingles = @'
red|what's my IP?
red|what is my ip and which wifi am I connected to
bateria|how much battery do I have left?
bateria|will my battery last for a two-hour movie?
bateria|battery level
disco|how much free space do I have on drive D?
disco|how much free space is left on my disks?
memoria,disco|how much space is left on C and how much memory do I have free
memoria|how much RAM does this computer have and how much is free?
memoria|how much RAM does this laptop have?
procesador|what processor do I have?
red|do I have internet?
red|is there internet?
red|which wifi network am I connected to?
grafica|what graphics card do I have?
sistema|how long has the laptop been on?
equipo|what is my computer called?
sistema|what version of Windows do I have?
red|what's the gateway of my network?
equipo,sistema,procesador,memoria,disco,grafica|give me a summary of this laptop
equipo,sistema,procesador,memoria,disco,grafica|what does this computer have?
red|my internet is slow
bateria|IS THE LAPTOP   PLUGGED IN? how much battery is there
-|what time is it?
-|hello
-|what is 748 times 6?
-|what is an IP address?
-|what is a public IP?
-|how much battery does the iPhone 15 have?
-|how do I change my IP?
-|how can I find out how much RAM I have?
-|write a PowerShell script that shows the IP
-|which processor is better, i5 or Ryzen 5?
-|how much RAM does Windows 11 need?
-|search the internet for the price of coffee
-|do you remember what we talked about?
-|make me a sales chart
-|explain how DNS works
-|how much space is there between the Earth and the Moon?
-|what's the battery of my phone?
-|what processor does the Lenovo Legion 5 have?
-|how long does the battery of a Dell XPS 13 last?
-|how much battery does my brother's laptop have?
-|how much RAM does a gaming laptop usually have?
-|is there any laptop with 64 GB of RAM?
-|how much battery is left?
-|my friend asks how much RAM his computer has
-|how much VRAM does the RTX 4060 have?
bateria|how much battery does the laptop have?
red|what is the IP of this pc?
memoria|am I low on RAM?
disco|what disks do I have?
equipo|what laptop do I have?
-|how long has the PlayStation been on?
'@
foreach ($l in ($ingles -split "\r?\n")) {
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
