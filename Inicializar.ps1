param([string]$Servidor='localhost')
$ErrorActionPreference='Stop'
$b=[System.Data.SqlClient.SqlConnectionStringBuilder]::new()
$b['Data Source']=$Servidor;$b['Integrated Security']=$true;$b['Encrypt']=$true;$b['TrustServerCertificate']=$true;$b['Initial Catalog']='master'
$c=[System.Data.SqlClient.SqlConnection]::new($b.ConnectionString);$c.Open()
try{
 foreach($db in @('SIS_RAW','SIS_NORMALIZADA','SIS_DIMENSIONAL')){
  $c.ChangeDatabase('master');$cmd=$c.CreateCommand();$cmd.CommandText='SELECT DB_ID(@db)';[void]$cmd.Parameters.AddWithValue('@db',$db);$exists=$cmd.ExecuteScalar()
  if($exists -eq [DBNull]::Value){$cmd=$c.CreateCommand();$cmd.CommandText="CREATE DATABASE [$db]";[void]$cmd.ExecuteNonQuery()}
  $c.ChangeDatabase($db);$cmd=$c.CreateCommand();$cmd.CommandText="IF OBJECT_ID('dbo.SIS_Marca') IS NOT NULL SELECT nombre FROM dbo.SIS_Marca ELSE SELECT N''";$marca=$cmd.ExecuteScalar()
  if($exists -ne [DBNull]::Value -and $marca -ne 'SIS-3BD-v1'){throw "La base $db no pertenece a este proyecto; no se modifica."}
  $cmd=$c.CreateCommand();$cmd.CommandText="IF OBJECT_ID('dbo.SIS_Marca') IS NULL BEGIN CREATE TABLE dbo.SIS_Marca(nombre varchar(80) PRIMARY KEY);INSERT dbo.SIS_Marca VALUES('SIS-3BD-v1');END";[void]$cmd.ExecuteNonQuery()
  $cmd=$c.CreateCommand();$cmd.CommandText="ALTER DATABASE SCOPED CONFIGURATION SET MAXDOP=1";[void]$cmd.ExecuteNonQuery()
 }
 foreach($pair in @(@('SIS_RAW','01_raw.sql'),@('SIS_NORMALIZADA','02_normalizada.sql'),@('SIS_NORMALIZADA','09_integridad_norm.sql'),@('SIS_DIMENSIONAL','03_dimensional.sql'),@('SIS_RAW','04_eventos.sql'),@('SIS_RAW','05_vista.sql'),@('SIS_RAW','08_integridad_raw.sql'),@('SIS_DIMENSIONAL','06_vistas_powerbi.sql'))){
  $c.ChangeDatabase($pair[0]);$sql=Get-Content -LiteralPath (Join-Path $PSScriptRoot ('sql\'+$pair[1])) -Raw -Encoding UTF8
  foreach($batch in ($sql -split '(?m)^GO\s*$')){if($batch.Trim()){$cmd=$c.CreateCommand();$cmd.CommandTimeout=180;$cmd.CommandText=$batch;[void]$cmd.ExecuteNonQuery()}}
 }
 Write-Output 'Tres bases listas: SIS_RAW -> SIS_NORMALIZADA -> SIS_DIMENSIONAL'
}finally{$c.Dispose()}


