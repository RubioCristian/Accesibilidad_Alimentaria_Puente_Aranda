<#
.SYNOPSIS
  Monta todo el proyecto: base PostGIS/pgRouting restaurada desde Backup/ y visor web.
.DESCRIPTION
  Detecta Docker o Podman. Si no hay ninguno, instala Docker Desktop con winget.
  Por defecto restaura el respaldo final (toda la localidad ya cargada y analizada).
  -Regenerar     vuelve a descargar las fuentes, reconstruye el modelo, corre el analisis y exporta el visor (horas).
  -Limpiar       borra el volumen de la base antes de montar (fuerza restaurar de nuevo el respaldo).
  -SinNavegador  no abre el visor al terminar.
  -Motor         fuerza 'docker' o 'podman' (por defecto usa el que encuentre, Docker primero).
.EXAMPLE
  .\montar.ps1
  .\montar.ps1 -Limpiar
  .\montar.ps1 -Regenerar
#>
[CmdletBinding()]
param(
    [switch]$Regenerar,
    [switch]$Limpiar,
    [switch]$SinNavegador,
    [ValidateSet('', 'docker', 'podman')][string]$Motor = ''
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$puertoDb = if ($env:DB_PORT) { $env:DB_PORT } else { '5433' }
$puertoWeb = if ($env:WEB_PORT) { $env:WEB_PORT } else { '8080' }
$baseDatos = 'alimentos_puente_aranda'

function Paso($texto) { Write-Host "`n==> $texto" -ForegroundColor Cyan }

function Ejecutar {
    # Ejecuta un comando nativo (primer elemento) y falla si devuelve error.
    $exe, $resto = $args
    & $exe @resto
    if ($LASTEXITCODE -ne 0) { throw "Fallo: $($args -join ' ') (codigo $LASTEXITCODE)" }
}

function Agregar-RutaDocker {
    # Tras instalar, la sesion actual aun no ve docker en el PATH.
    $bin = Join-Path $env:ProgramFiles 'Docker\Docker\resources\bin'
    if ((Test-Path $bin) -and ($env:Path -notlike "*$bin*")) { $env:Path = "$bin;$env:Path" }
}

function Motor-Responde($nombre) {
    & $nombre info *> $null
    return ($LASTEXITCODE -eq 0)
}

function Instalar-Docker {
    Paso 'No se encontro Docker ni Podman: instalando Docker Desktop con winget'
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'winget no esta disponible. Instale "App Installer" desde Microsoft Store (o Docker Desktop desde docker.com) y vuelva a ejecutar.'
    }
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $admin) { Write-Warning 'Docker Desktop pide permisos de administrador; acepte la ventana de Windows (UAC) cuando aparezca.' }
    & winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw "winget no pudo instalar Docker Desktop (codigo $LASTEXITCODE)." }
    Agregar-RutaDocker
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host "`nDocker Desktop quedo instalado, pero Windows necesita reiniciar para terminar de activar WSL2." -ForegroundColor Yellow
        Write-Host 'Reinicie el equipo, abra Docker Desktop una vez (acepte los terminos) y vuelva a ejecutar .\montar.ps1'
        exit 0
    }
}

function Iniciar-DockerDesktop {
    if (Motor-Responde 'docker') { return }
    $exe = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
    if (-not (Test-Path $exe)) { throw 'No se encontro Docker Desktop.exe; abra Docker Desktop manualmente y vuelva a ejecutar.' }
    Write-Host 'Iniciando Docker Desktop (la primera vez puede pedir aceptar los terminos de servicio)...'
    Start-Process $exe
    for ($i = 0; $i -lt 60; $i++) {
        if (Motor-Responde 'docker') { return }
        Start-Sleep -Seconds 5
    }
    throw 'Docker Desktop no quedo listo en 5 minutos. Abralo, acepte los terminos si los pide, espere "Engine running" y vuelva a ejecutar.'
}

# ---- Motor de contenedores ----
Paso 'Buscando Docker o Podman'
Agregar-RutaDocker
$motor = $Motor
if (-not $motor) {
    if (Get-Command docker -ErrorAction SilentlyContinue) { $motor = 'docker' }
    elseif (Get-Command podman -ErrorAction SilentlyContinue) { $motor = 'podman' }
    else { Instalar-Docker; $motor = 'docker' }
}
elseif (-not (Get-Command $motor -ErrorAction SilentlyContinue)) {
    if ($motor -eq 'docker') { Instalar-Docker } else { throw 'Podman no esta instalado.' }
}

if ($motor -eq 'docker') {
    Iniciar-DockerDesktop
}
elseif (-not (Motor-Responde 'podman')) {
    Write-Host 'La maquina de Podman no responde; intentando iniciarla...'
    & podman machine start
    if (-not (Motor-Responde 'podman')) { throw 'Podman no esta disponible. Ejecute "podman machine init" y "podman machine start".' }
}
Write-Host "Usando $motor"
& $motor compose version *> $null
if ($LASTEXITCODE -ne 0) { throw "'$motor compose' no esta disponible. Con Podman instale podman-compose (pip install podman-compose)." }

$respaldo = Join-Path $PSScriptRoot 'Backup/alimentos_puente_aranda_final.backup'
if (-not (Test-Path $respaldo)) {
    Write-Warning 'No existe el respaldo final; se restaurara el original (solo 76 manzanas) y habra que usar -Regenerar.'
}

if ($Limpiar) {
    Paso 'Borrando contenedores y volumen de la base'
    & $motor compose down -v
}

Paso 'Levantando la base y el visor (la primera vez descarga imagenes, construye y restaura el respaldo)'
Ejecutar $motor compose up -d --build db web

Paso 'Esperando a que la base termine de restaurar'
$listo = $false
for ($i = 0; $i -lt 120; $i++) {
    $r = & $motor compose exec -T db psql -U postgres -d $baseDatos -Atc 'select count(*) from analisis.indicador_predio' 2>$null
    if ($LASTEXITCODE -eq 0 -and "$r".Trim() -match '^\d+$') { $listo = $true; break }
    Start-Sleep -Seconds 5
}
if (-not $listo) { throw "La base no quedo lista en 10 minutos. Revise: $motor compose logs db" }

if ($Regenerar) {
    Paso 'Regenerando: cargas, modelo, analisis y exportacion (tarda horas)'
    $env:CODE_VERSION = (& git rev-parse --short HEAD 2>$null)
    Ejecutar $motor compose -f compose.yaml --profile etl run --rm -T etl
}

Paso 'Verificando'
$consulta = 'select (select count(*) from territorio.predio), (select count(*) from alimentos.establecimiento), (select count(*) from analisis.indicador_predio)'
$conteos = & $motor compose exec -T db psql -U postgres -d $baseDatos -Atc $consulta
Write-Host "predios | establecimientos | indicadores: $conteos"
try {
    $web = Invoke-WebRequest -Uri "http://localhost:$puertoWeb/" -UseBasicParsing -TimeoutSec 15
    Write-Host "Visor responde (HTTP $($web.StatusCode))"
} catch {
    Write-Warning "El visor no respondio en el puerto ${puertoWeb}: $($_.Exception.Message)"
}

Write-Host "`nListo." -ForegroundColor Green
Write-Host "  Visor:  http://localhost:$puertoWeb"
Write-Host "  Base:   psql -h localhost -p $puertoDb -U postgres $baseDatos   (clave: postgres)"
if (-not $SinNavegador) { Start-Process "http://localhost:$puertoWeb" }
