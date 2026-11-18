param(
 [string]$CarpetaEvidencia
)

# Ejecuta la misma cadena SSIS sobre lotes incrementales ya recibidos en
# SIS_RAW.raw.Registros. El CSV de ejemplo solo satisface la conexion plana:
# el Data Flow se deshabilita automaticamente cuando Modo=SQL.
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
if(-not $CarpetaEvidencia){$CarpetaEvidencia=Join-Path (Split-Path $root) ('operacion\incremental_'+[guid]::NewGuid().ToString('N'))}
New-Item -ItemType Directory -Path $CarpetaEvidencia -Force|Out-Null

$cn=[System.Data.SqlClient.SqlConnection]::new('Data Source=localhost;Initial Catalog=SIS_RAW;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;Connect Timeout=10')
$cn.Open()
try {
 $cmd=$cn.CreateCommand();$cmd.CommandText="SELECT TOP(1) CONVERT(nvarchar(36),id_lote) FROM raw.Registros WHERE fuente_tipo='SQL' AND estado_proceso='PENDIENTE' ORDER BY id_raw";$loteRaw=$cmd.ExecuteScalar()
 $cmd=$cn.CreateCommand();$cmd.CommandText="SELECT COUNT_BIG(*) FROM raw.EventosSQL WHERE estado='PENDIENTE'";$pendientesEventos=[int64]$cmd.ExecuteScalar()
} finally {$cn.Dispose()}

if(-not $loteRaw -and $pendientesEventos -eq 0){
 [ordered]@{codigo_salida=0;estado='SIN_PENDIENTES';id_lote=$null;filas_dm=$null;atenciones_dm=$null;mensaje='No existen eventos SQL pendientes.';eventos_pendientes=0}|ConvertTo-Json|Set-Content (Join-Path $CarpetaEvidencia 'resultado.json') -Encoding utf8
 Write-Output '{"estado":"SIN_PENDIENTES","eventos_pendientes":0}'
 return
}

$archivoTecnico=Join-Path $root 'fuentes\entrada.csv'
if($loteRaw){$env:SIS_LOTE_INCREMENTAL=$loteRaw}
& (Join-Path $root 'Ejecutar_3BD.ps1') -Archivo $archivoTecnico -Modo SQL -CarpetaEvidencia $CarpetaEvidencia
$env:SIS_LOTE_INCREMENTAL=$null
if($LASTEXITCODE -ne 0){throw 'La ejecucion incremental de SSIS finalizo con error.'}
