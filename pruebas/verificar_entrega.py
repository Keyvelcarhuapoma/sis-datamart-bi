from pathlib import Path
import ast,csv,json,sys,xml.etree.ElementTree as ET,zipfile
r=Path(__file__).resolve().parents[1]
required=['README.md','Inicializar.ps1','Configurar_Proyecto.ps1','INICIAR.cmd','Iniciar.ps1','requirements.txt','motor/SIS_ELT_3BD.dtsx','motor/fuentes/entrada.csv','PowerBI/SIS_Final_3BD.pbip']
for name in required:
    if not (r/name).is_file():raise AssertionError('Falta '+name)
for p in r.rglob('*.py'):
    if '.venv' not in p.parts:ast.parse(p.read_text(encoding='utf-8-sig'),filename=str(p))
for p in (r/'PowerBI').rglob('*.json'):json.loads(p.read_text(encoding='utf-8-sig'))
pbip=json.loads((r/'PowerBI/SIS_Final_3BD.pbip').read_text(encoding='utf-8-sig'))
for artifact in pbip['artifacts']:
    if not (r/'PowerBI'/artifact['report']['path']).is_dir():raise AssertionError('Reporte PBIP ausente')
ET.parse(r/'motor/SIS_ELT_3BD.dtsx')
for p in (r/'excel').glob('*.xlsx'):
    with zipfile.ZipFile(p) as z:
        if z.testzip() is not None:raise AssertionError('Excel dañado '+p.name)
if len(list((r/'excel').glob('*.xlsx')))!=3:raise AssertionError('Se requieren tres Excel')
for p in (r/'ejemplos').glob('*.csv'):
    raw=p.read_bytes()
    encoding='utf-16' if raw[:2] in (b'\xff\xfe',b'\xfe\xff') else 'cp1252' if 'windows1252' in p.name else 'utf-8-sig'
    with p.open(encoding=encoding,newline='') as f:
        if len(next(csv.reader(f)))!=17:raise AssertionError('Cabecera de ejemplo incorrecta '+p.name)
print('Entrega válida: fuentes Python/XML/JSON, proyecto PBIP, 3 Excel y cabeceras sintéticas. No se conectó a SQL.')
