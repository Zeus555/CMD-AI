#requires -Version 5.1
<#
  Set-AIKey.ps1 - Guarda una clave de API en una variable de entorno de usuario.

  Por que asi y no con setx:
    - setx TRUNCA en 1024 caracteres (silenciosamente) y no puede tocar la
      sesion actual.
    - Teclear "setx XAI_API_KEY xai-..." dejaria la clave escrita en claro
      dentro del historial de PSReadLine, para siempre.
  Read-Host -AsSecureString no muestra nada y no pasa por el historial.
#>
param(
    [Parameter(Mandatory)][string]$Name,
    [switch]$Remove
)

if ($Remove) {
    [Environment]::SetEnvironmentVariable($Name, $null, 'User')
    [Environment]::SetEnvironmentVariable($Name, $null, 'Process')
    Write-Host "$Name eliminada."; exit 0
}

$sec  = Read-Host "Pega la clave para $Name" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
try     { $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }

if ([string]::IsNullOrWhiteSpace($plain)) { Write-Host "Vacio: cancelado."; exit 1 }
$plain = $plain.Trim()

# 'User'    -> persiste en HKCU\Environment (sin el limite de 1024 de setx).
# 'Process' -> ademas queda usable en esta misma sesion, sin abrir consola nueva.
[Environment]::SetEnvironmentVariable($Name, $plain, 'User')
[Environment]::SetEnvironmentVariable($Name, $plain, 'Process')

$mask = $plain.Substring(0, [Math]::Min(6, $plain.Length)) + '...' + `
        $plain.Substring([Math]::Max(0, $plain.Length - 4))
Write-Host "OK: $Name guardada ($($plain.Length) caracteres, $mask)."
$plain = $null
[GC]::Collect()
exit 0
