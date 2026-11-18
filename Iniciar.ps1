$ErrorActionPreference='Stop'
$python=Join-Path $PSScriptRoot '.venv\Scripts\pythonw.exe'
if(-not(Test-Path -LiteralPath $python)){
 throw 'Falta .venv. Sigue la instalación de Python indicada en README.md.'
}
Start-Process -FilePath $python -ArgumentList ('"'+(Join-Path $PSScriptRoot 'app\aplicacion.py')+'"') -WorkingDirectory $PSScriptRoot -WindowStyle Hidden
$pbi=Join-Path $env:ProgramFiles 'Microsoft Power BI Desktop\bin\PBIDesktop.exe'
if(Test-Path -LiteralPath $pbi){
 Start-Process -FilePath $pbi -ArgumentList ('"'+(Join-Path $PSScriptRoot 'PowerBI\SIS_Final_3BD.pbip')+'"') -WindowStyle Hidden
}else{Write-Output 'Abre PowerBI/SIS_Final_3BD.pbip desde Power BI Desktop.'}
