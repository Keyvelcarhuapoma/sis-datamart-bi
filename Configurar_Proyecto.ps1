$ErrorActionPreference='Stop'
$target=Join-Path $PSScriptRoot 'motor\SIS_ELT_3BD.dtsx'
$entrada=Join-Path $PSScriptRoot 'motor\fuentes\entrada.csv'
if(-not(Test-Path -LiteralPath $entrada)){throw 'Falta la entrada sintética de SSIS.'}
$xml=[xml](Get-Content -LiteralPath $target -Raw -Encoding UTF8)
$nodes=$xml.SelectNodes('//@* | //text()')
foreach($node in $nodes){
 if($node.Value -and $node.Value.Contains('.\motor\fuentes\entrada.csv')){
  $node.Value=$node.Value.Replace('.\motor\fuentes\entrada.csv',$entrada)
 }
}
$xml.Save($target)
Write-Output 'Ruta local configurada. No se ejecutaron cargas ni cambios en SQL.'
