param([string]$Archivo,[ValidateSet('SNAPSHOT','SQL')][string]$Modo='SNAPSHOT',[int]$CodePage=65001,[string]$Delimitador=',',[string]$FinLinea="`r`n",[switch]$Unicode,[switch]$SimularFallo,[string]$CarpetaEvidencia,[string]$Sha256)
$ErrorActionPreference='Stop'
if(-not $Archivo){$Archivo=Join-Path $PSScriptRoot 'fuentes\entrada.csv'}
if(-not(Test-Path -LiteralPath $Archivo)){throw 'Archivo no encontrado'}

Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Utility\Microsoft.PowerShell.Utility.psd1') -Force
if($Modo -eq 'SNAPSHOT'){
 Add-Type -AssemblyName Microsoft.VisualBasic
 $enc=if($Unicode){[Text.Encoding]::Unicode}else{[Text.Encoding]::GetEncoding($CodePage)}
 $reader=[Microsoft.VisualBasic.FileIO.TextFieldParser]::new([IO.Path]::GetFullPath($Archivo),$enc,$true)
 try{
  $reader.SetDelimiters(@($Delimitador));$reader.HasFieldsEnclosedInQuotes=$true
  $header=@($reader.ReadFields() | ForEach-Object {($_.Trim().ToUpperInvariant().Replace('AÑO','ANIO'))})
  $expected='ANIO,MES,REGION,PROVINCIA,UBIGEO_DISTRITO,DISTRITO,COD_UNIDAD_EJECUTORA,DESC_UNIDAD_EJECUTORA,COD_IPRESS,IPRESS,NIVEL_EESS,PLAN_SEGURO,COD_SERVICIO,DESC_SERVICIO,SEXO,GRUPO_EDAD,ATENCIONES'
  if(($header -join ',') -ne $expected){throw 'Cabecera incompatible con el contrato SIS.'}
 }finally{$reader.Close()}
 if(-not $Sha256){$Sha256=(Get-FileHash -LiteralPath $Archivo -Algorithm SHA256).Hash}
 if($Sha256 -notmatch '^[A-Fa-f0-9]{64}$'){throw 'SHA256 invalido'}
}
if(-not $CarpetaEvidencia){$CarpetaEvidencia=Join-Path (Split-Path $PSScriptRoot) ('operacion\run_'+[guid]::NewGuid().ToString('N'))}
New-Item -ItemType Directory -Path $CarpetaEvidencia -Force|Out-Null
$gac='C:\Windows\Microsoft.NET\assembly'
foreach($ref in @("$gac\GAC_MSIL\Microsoft.SqlServer.ManagedDTS\v4.0_17.0.0.0__89845dcd8080cc91\Microsoft.SqlServer.ManagedDTS.dll","$gac\GAC_64\Microsoft.SqlServer.DTSRuntimeWrap\v4.0_17.0.0.0__89845dcd8080cc91\Microsoft.SqlServer.DTSRuntimeWrap.dll")){[void][Reflection.Assembly]::LoadFrom($ref)}
$app=New-Object Microsoft.SqlServer.Dts.Runtime.Application
$p=$app.LoadPackage((Join-Path $PSScriptRoot 'SIS_ELT_3BD.dtsx'),$null)
$p.Variables['User::Archivo_Entrada'].Value=[IO.Path]::GetFullPath($Archivo)
$p.Variables['User::Modo'].Value=$Modo
$lotId=if($env:SIS_LOTE_INCREMENTAL){([guid]$env:SIS_LOTE_INCREMENTAL).ToString()}else{[guid]::NewGuid().ToString()}
$p.Variables['User::IdLote'].EvaluateAsExpression=$false
$p.Variables['User::IdLote'].Value=$lotId
$p.Variables['User::SimularFallo'].Value=if($SimularFallo){'1'}else{'0'}
$refs=@("$gac\GAC_MSIL\Microsoft.SqlServer.ManagedDTS\v4.0_17.0.0.0__89845dcd8080cc91\Microsoft.SqlServer.ManagedDTS.dll","$gac\GAC_64\Microsoft.SqlServer.DTSRuntimeWrap\v4.0_17.0.0.0__89845dcd8080cc91\Microsoft.SqlServer.DTSRuntimeWrap.dll")
$refs+="$gac\GAC_MSIL\Microsoft.SqlServer.DTSPipelineWrap\v4.0_17.0.0.0__89845dcd8080cc91\Microsoft.SQLServer.DTSPipelineWrap.dll"
foreach($ref in $refs){[void][Reflection.Assembly]::LoadFrom($ref)}
Add-Type -ReferencedAssemblies $refs -TypeDefinition @'
using Microsoft.SqlServer.Dts.Runtime;
using W=Microsoft.SqlServer.Dts.Runtime.Wrapper;
using Microsoft.SqlServer.Dts.Pipeline.Wrapper;
public static class ConfigCSV {
 public static void Set(Package p,bool unicode,int cp,string end,string delimiter){
  var f=(W.IDTSConnectionManagerFlatFile100)p.Connections["CSV_Entrada"].InnerObject;
  f.Unicode=unicode;f.CodePage=cp;f.HeaderRowDelimiter=end;f.RowDelimiter=end;
  for(int i=0;i<f.Columns.Count;i++)f.Columns[i].ColumnDelimiter=i==f.Columns.Count-1?end:delimiter;
  var pipe=(MainPipe)((TaskHost)p.Executables["02_CSV_a_SIS_RAW_FastLoad"]).InnerObject;
  var source=pipe.ComponentMetaDataCollection["Leer_CSV_Entrada"];
  source.OutputCollection[1].OutputColumnCollection[0].SetDataTypeProperties(unicode?W.DataType.DT_NTEXT:W.DataType.DT_TEXT,0,0,0,unicode?0:cp);
 }
}
'@
[ConfigCSV]::Set($p,[bool]$Unicode,$CodePage,$FinLinea,$Delimitador)
$runtime=Join-Path $CarpetaEvidencia 'ejecucion.dtsx';$app.SaveToXml($runtime,$p,$null)
$started=Get-Date
$process=[Diagnostics.Process]::new()
$process.StartInfo.FileName='C:\Program Files\Microsoft SQL Server\170\DTS\Binn\DTExec.exe'
$process.StartInfo.Arguments='/FILE "'+[IO.Path]::GetFullPath($runtime)+'" /REPORTING EIWP'
$process.StartInfo.UseShellExecute=$false;$process.StartInfo.CreateNoWindow=$true
$process.StartInfo.RedirectStandardOutput=$true;$process.StartInfo.RedirectStandardError=$true
$process.StartInfo.StandardOutputEncoding=[Text.Encoding]::GetEncoding(850)
$process.StartInfo.StandardErrorEncoding=[Text.Encoding]::GetEncoding(850)
[void]$process.Start();$null=$process.Handle
$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
$peak=0L;$samples=[Collections.Generic.List[object]]::new()
while(-not $process.HasExited){
 $process.Refresh();$peak=[Math]::Max($peak,$process.WorkingSet64)
 $samples.Add([ordered]@{segundos=[Math]::Round(((Get-Date)-$started).TotalSeconds,1);ssis_ram_mb=[Math]::Round($process.WorkingSet64/1MB,1)})
 if(((Get-Date)-$started).TotalHours -gt 6){$process.Kill();throw 'Tiempo limite de seis horas: revisar y recuperar lote.'}
 Start-Sleep -Milliseconds 500
}
$process.WaitForExit();$code=$process.ExitCode
[IO.File]::WriteAllText((Join-Path $CarpetaEvidencia 'ssis.log'),$stdout.Result,[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $CarpetaEvidencia 'ssis_error.log'),$stderr.Result,[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $CarpetaEvidencia 'recursos.json'),(ConvertTo-Json -InputObject @($samples) -Depth 4),[Text.UTF8Encoding]::new($false))
$c=[System.Data.SqlClient.SqlConnection]::new('Data Source=localhost;Initial Catalog=SIS_RAW;Integrated Security=True;Encrypt=True;TrustServerCertificate=True');$c.Open()
try{

 if($Modo -eq 'SNAPSHOT'){
  $meta=$c.CreateCommand();$meta.CommandText='IF EXISTS(SELECT 1 FROM etl.Lotes WHERE id_lote=@id) AND NOT EXISTS(SELECT 1 FROM etl.Archivos WHERE id_lote=@id) INSERT etl.Archivos(id_lote,ruta,sha256,bytes,codepage) VALUES(@id,@ruta,@sha,@bytes,@cp)'
  [void]$meta.Parameters.AddWithValue('@id',[guid]$lotId);[void]$meta.Parameters.AddWithValue('@ruta',[IO.Path]::GetFullPath($Archivo));[void]$meta.Parameters.AddWithValue('@sha',$Sha256);[void]$meta.Parameters.AddWithValue('@bytes',(Get-Item -LiteralPath $Archivo).Length);[void]$meta.Parameters.AddWithValue('@cp',$CodePage);[void]$meta.ExecuteNonQuery()
 }
 $cmd=$c.CreateCommand();$cmd.CommandText="SELECT * FROM etl.Lotes WHERE id_lote='$lotId' FOR JSON PATH";$s=$cmd.ExecuteScalar();$lot=($s|ConvertFrom-Json)[0]
 [IO.File]::WriteAllText((Join-Path $CarpetaEvidencia 'lote.json'),$s,[Text.UTF8Encoding]::new($false))
 foreach($t in @('Rechazos','Validaciones','Errores','PlanParticion','Publicaciones')){$cmd=$c.CreateCommand();$cmd.CommandText="SELECT * FROM etl.$t WHERE id_lote='$($lot.id_lote)' FOR JSON PATH";$r=$cmd.ExecuteReader();$sb=[Text.StringBuilder]::new();while($r.Read()){[void]$sb.Append($r.GetString(0))};$r.Close();[IO.File]::WriteAllText((Join-Path $CarpetaEvidencia ($t+'.json')),$sb.ToString(),[Text.UTF8Encoding]::new($false))}
 $result=[ordered]@{codigo_salida=$code;segundos=((Get-Date)-$started).TotalSeconds;ssis_ram_pico_mb=[Math]::Round($peak/1MB,1);id_lote=$lot.id_lote;estado=$lot.estado;filas_dm=$lot.filas_dm;atenciones_dm=$lot.atenciones_dm;mensaje=$lot.mensaje}
 $result|ConvertTo-Json | Set-Content (Join-Path $CarpetaEvidencia 'resultado.json') -Encoding UTF8
 $result|ConvertTo-Json -Compress
}finally{$c.Close()}
if($code -ne 0 -or $lot.estado -ne 'EXITOSO'){throw "SSIS no confirmo exito. Revisar $CarpetaEvidencia\ssis.log"}
