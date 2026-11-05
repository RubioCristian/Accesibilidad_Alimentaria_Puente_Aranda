<#
.SYNOPSIS
  Monta todo el proyecto: base PostGIS/pgRouting restaurada desde Backup/ y visor web.
.DESCRIPTION
  Por defecto restaura el respaldo final (toda la localidad ya cargada y analizada).
  -Regenerar  vuelve a descargar las fuentes, reconstruye el modelo, corre el analisis y exporta el visor (~2 h).
  -Limpiar    borra el volumen de la base antes de montar (fuerza restaurar de nuevo el respaldo).
  -SinNavegador  no abre el visor al terminar.
.EXAMPLE
  .\montar.ps1
  .\montar.ps1 -Limpiar
  .\montar.ps1 -Regenerar
#>
[CmdletBinding()]
param(
    [switch]$Regenerar,
    [switch]$Limpiar,
    [switch]$SinNavegador
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$puertoDb = if ($env:DB_PORT) { $env:DB_PORT } else { '5433' }
$puertoWeb = if ($env:WEB_PORT) { $env:WEB_PORT } else { '8080' }
$baseDatos = 'alimentos_puente_aranda'

function Paso($texto) { Write-Host "`n==> $texto" -ForegroundColor Cyan }
function Ejecutar {
    # Ejecuta un comando nativo y falla si devuelve error.
    & $args[0] $args[1..($args.Count - 1)]
    if ($LASTEXITCODE -ne 0) { throw "Fallo: $($args -join ' ') (codigo $LASTEXITCODE)" }
}

Paso 'Comprobando Podman'
if (-not (Get-Command podman -ErrorAction SilentlyContinue)) {
    throw 'No se encontro podman. Instale Podman (probado con 6.1.4) y vuelva a ejecutar.'
}
& podman info *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'La maquina de Podman no responde; intentando iniciarla...'
    & podman machine start
    & podman info *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Podman no esta disponible. Ejecute "podman machine init" y "podman machine start".' }
}

$respaldo = Join-Path $PSScriptRoot 'Backup/alimentos_puente_aranda_final.backup'
if (-not (Test-Path $respaldo)) {
    Write-Warning 'No existe el respaldo final; se restaurara el original (solo 76 manzanas) y habra que usar -Regenerar.'
}

if ($Limpiar) {
    Paso 'Borrando contenedores y volumen de la base'
    & podman compose down -v
}

Paso 'Levantando la base y el visor (la primera vez construye la imagen y restaura el respaldo)'
Ejecutar podman compose up -d --build db web

Paso 'Esperando a que la base termine de restaurar'
$listo = $false
for ($i = 0; $i -lt 120; $i++) {
    $r = & podman exec accesibilidad-alimentaria_db_1 psql -U postgres -d $baseDatos -Atc "select count(*) from analisis.indicador_predio" 2>$null
    if ($LASTEXITCODE -eq 0 -and $r -match '^\d+$') { $listo = $true; break }
    Start-Sleep -Seconds 5
}
if (-not $listo) { throw 'La base no quedo lista en 10 minutos. Revise: podman logs accesibilidad-alimentaria_db_1' }

if ($Regenerar) {
    Paso 'Regenerando: cargas, modelo, analisis y exportacion (tarda horas)'
    $env:CODE_VERSION = (& git rev-parse --short HEAD)
    Ejecutar podman compose -f compose.yaml --profile etl run --rm -T etl
}

Paso 'Verificando'
$consulta = "select (select count(*) from territorio.predio), (select count(*) from alimentos.establecimiento), (select count(*) from analisis.indicador_predio)"
$conteos = & podman exec accesibilidad-alimentaria_db_1 psql -U postgres -d $baseDatos -Atc $consulta
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
