<#
Instala o actualiza la API en IIS a partir del zip de la release. Idempotente.
Ejecutar como administrador:
  .\instalar-iis.ps1 -Zip C:\ruta\proveedores-api-X.Y.Z-win-x64.zip
Primera vez: pide la cadena de conexion y la guarda como variable de entorno del app pool
(nunca en disco ni en el repo). Al actualizar no la vuelve a pedir.
Solo ASCII: PowerShell 5.1 lee mal los scripts UTF-8 sin BOM.
#>
#Requires -RunAsAdministrator
param(
    [Parameter(Mandatory)][string]$Zip,
    [string]$Sitio = 'ProveedoresApi',
    [string]$Ruta = 'C:\inetpub\ProveedoresApi',
    [int]$Puerto = 5178,
    [switch]$CambiarConexion
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Zip)) { throw "No existe $Zip" }

# Rol IIS (en Windows Server; Web-Scripting-Tools trae el modulo WebAdministration).
Install-WindowsFeature Web-Server, Web-Scripting-Tools | Out-Null

# El Hosting Bundle no se baja solo: hay que instalarlo antes (descarga de Microsoft, .NET 10).
if (-not (Test-Path "$env:ProgramFiles\IIS\Asp.Net Core Module\V2\aspnetcorev2.dll")) {
    throw 'Falta el .NET 10 Hosting Bundle. Instalalo y volve a correr el script.'
}
Import-Module WebAdministration

# App pool sin codigo administrado.
if (-not (Test-Path "IIS:\AppPools\$Sitio")) { New-WebAppPool -Name $Sitio | Out-Null }
Set-ItemProperty "IIS:\AppPools\$Sitio" -Name managedRuntimeVersion -Value ''

# Cadena de conexion: variable de entorno del app pool (doble guion bajo).
$filtro = "system.applicationHost/applicationPools/add[@name='$Sitio']/environmentVariables"
$nombre = 'ConnectionStrings__Proveedores'
$existe = Get-WebConfiguration -PSPath 'MACHINE/WEBROOT/APPHOST' -Filter "$filtro/add[@name='$nombre']"
if ($CambiarConexion -or -not $existe) {
    $seg = Read-Host 'Cadena de conexion (usuario con solo SELECT)' -AsSecureString
    $cs = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($seg))
    if ([string]::IsNullOrWhiteSpace($cs)) { throw 'La cadena de conexion no puede estar vacia' }
    if ($existe) {
        Remove-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Filter $filtro -Name '.' -AtElement @{ name = $nombre }
    }
    Add-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Filter $filtro -Name '.' -Value @{ name = $nombre; value = $cs }
}

# Archivos: con app_offline.htm mientras se descomprime (IIS detiene la app).
New-Item -ItemType Directory -Force $Ruta | Out-Null
$offline = Join-Path $Ruta 'app_offline.htm'
Set-Content $offline 'Actualizando...'
try {
    Expand-Archive -Path $Zip -DestinationPath $Ruta -Force
} finally {
    Remove-Item $offline -ErrorAction SilentlyContinue
}
& icacls $Ruta /grant "IIS AppPool\${Sitio}:(OI)(CI)RX" | Out-Null

# Sitio enlazado solo a 127.0.0.1.
if (-not (Get-Website -Name $Sitio)) {
    New-Website -Name $Sitio -PhysicalPath $Ruta -ApplicationPool $Sitio -IPAddress '127.0.0.1' -Port $Puerto | Out-Null
}
if ((Get-WebsiteState -Name $Sitio).Value -ne 'Started') { Start-Website -Name $Sitio }
Restart-WebAppPool -Name $Sitio

Start-Sleep -Seconds 3
$r = Invoke-RestMethod "http://127.0.0.1:$Puerto/version"
Write-Host "OK: version $($r.version) en http://127.0.0.1:$Puerto"
try { Invoke-WebRequest "http://127.0.0.1:$Puerto/health/ready" -UseBasicParsing | Out-Null; Write-Host 'Base: OK' }
catch { Write-Warning 'La API responde pero /health/ready falla: revisar la cadena de conexion y el acceso a la base.' }
