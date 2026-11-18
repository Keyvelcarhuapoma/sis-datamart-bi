$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path -Parent $PSScriptRoot
$gac='C:\Windows\Microsoft.NET\assembly'
$refs=@("$gac\GAC_MSIL\Microsoft.SqlServer.ManagedDTS\v4.0_17.0.0.0__89845dcd8080cc91\Microsoft.SqlServer.ManagedDTS.dll","$gac\GAC_MSIL\Microsoft.SqlServer.DTSPipelineWrap\v4.0_17.0.0.0__89845dcd8080cc91\Microsoft.SQLServer.DTSPipelineWrap.dll","$gac\GAC_64\Microsoft.SqlServer.DTSRuntimeWrap\v4.0_17.0.0.0__89845dcd8080cc91\Microsoft.SqlServer.DTSRuntimeWrap.dll")
foreach($r in $refs){[void][Reflection.Assembly]::LoadFrom($r)}
Add-Type -Path (Join-Path $PSScriptRoot 'CrearIncremental.cs') -ReferencedAssemblies $refs
[CrearIncremental]::Build($root)
$app=New-Object Microsoft.SqlServer.Dts.Runtime.Application
$package=$app.LoadPackage((Join-Path $root 'SIS_ELT_3BD.dtsx'),$null)
$project=[Microsoft.SqlServer.Dts.Runtime.Project]::CreateProject()
$project.Name='SIS_ELT_3BD';$project.ProtectionLevel=[Microsoft.SqlServer.Dts.Runtime.DTSProtectionLevel]::DontSaveSensitive
$project.TargetServerVersion=[Microsoft.SqlServer.Dts.Runtime.DTSTargetServerVersion]::SQLServer2025
$project.PackageItems.Add($package,'SIS_ELT_3BD.dtsx')|Out-Null
$project.SaveTo((Join-Path $root 'SIS_ELT_3BD.ispac'));$project.Dispose()

$zip=[IO.Compression.ZipFile]::OpenRead((Join-Path $root 'SIS_ELT_3BD.ispac'))
try {
 $reader=New-Object IO.StreamReader($zip.GetEntry('@Project.manifest').Open());$manifest=[xml]$reader.ReadToEnd();$reader.Dispose()
 $reader=New-Object IO.StreamReader($zip.GetEntry('Project.params').Open());$params=$reader.ReadToEnd();$reader.Dispose()
 [IO.File]::WriteAllText((Join-Path $root 'Project.params'),$params,[Text.UTF8Encoding]::new($false))
 $path=Join-Path $root 'SIS_ELT_3BD.dtproj';$xml=[xml](Get-Content $path -Raw)
 $node=$xml.Project.DeploymentModelSpecificContent.Manifest;$node.RemoveAll();$node.AppendChild($xml.ImportNode($manifest.DocumentElement,$true))|Out-Null;$xml.Save($path)
} finally {$zip.Dispose()}
Write-Output 'Paquete, ISPAC y manifiesto del proyecto actualizados.'


