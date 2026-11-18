"""Recepcion liviana. CSV directo a SSIS; SQL valida y transforma en tres BD."""
from pathlib import Path
from datetime import datetime,timezone
import argparse,csv,hashlib,json,os,sqlite3,subprocess,uuid,unicodedata
ROOT=Path(__file__).resolve().parents[1]
COLUMNAS=['ANIO','MES','REGION','PROVINCIA','UBIGEO_DISTRITO','DISTRITO','COD_UNIDAD_EJECUTORA','DESC_UNIDAD_EJECUTORA','COD_IPRESS','IPRESS','NIVEL_EESS','PLAN_SEGURO','COD_SERVICIO','DESC_SERVICIO','SEXO','GRUPO_EDAD','ATENCIONES']
PS=Path(os.environ['SystemRoot'])/'System32/WindowsPowerShell/v1.0/powershell.exe'
def cabecera(s):
 s=''.join(c for c in unicodedata.normalize('NFD',str(s).strip().upper()) if unicodedata.category(c)!='Mn')
 return 'ANIO' if s in ('ANO','ANIO') else s
def json_guardar(p,o):Path(p).write_text(json.dumps(o,ensure_ascii=False,indent=2),encoding='utf-8')
def powershell(script,args,log):
 env=os.environ.copy();env.pop('PSModulePath',None)
 with Path(log).open('w',encoding='utf-8') as f:
  p=subprocess.run([str(PS),'-NoProfile','-File',str(script)]+list(map(str,args)),stdout=f,stderr=subprocess.STDOUT,env=env,creationflags=subprocess.CREATE_NO_WINDOW)
 if p.returncode:raise RuntimeError('Carga no confirmada. Revisar '+str(log))
def inspeccionar(path,encoding=None):
 """Lee solo cabecera y una muestra. No transforma ni cuenta todo el CSV."""
 with Path(path).open('rb') as f:b=f.read(65536)
 if b.startswith(b'\xff\xfe'):enc,cp,uni='utf-16',1200,True
 elif b.startswith(b'\xfe\xff'):raise ValueError('UTF-16 BE requiere conversion explicita; conserva el original.')
 elif encoding=='cp1252':enc,cp,uni='cp1252',1252,False
 else:
  enc,cp,uni='utf-8-sig',65001,False
  try:b.decode(enc,errors='strict')
  except UnicodeDecodeError as e:
   # Una muestra puede terminar dentro de un caracter UTF-8.
   import codecs
   try:codecs.getincrementaldecoder(enc)('strict').decode(b,final=False)
   except UnicodeDecodeError:raise ValueError('No es UTF-8. Confirma Windows-1252 con --encoding cp1252; no se adivina la codificacion.') from e
 with Path(path).open(encoding=enc,newline='') as f:
  sample=f.read(16384);f.seek(0)
  first=f.readline();end='\r\n' if first.endswith('\r\n') else '\n';f.seek(0)
  try:delimiter=csv.Sniffer().sniff(sample,delimiters=',;\t').delimiter
  except csv.Error:delimiter=','
  names=next(csv.reader(f,delimiter=delimiter),[])
  if [cabecera(x) for x in names]!=COLUMNAS:raise ValueError('Cabecera incompatible: se requieren las 17 columnas SIS en el orden documentado.')
 return {'encoding':enc,'codepage':cp,'unicode':uni,'delimiter':delimiter,'fin_linea':end,'alcance':'cabecera y muestra; validacion completa en SSIS/SQL'}
def preparar_excel(src,dest):
 """Excepcion para Excel: lectura secuencial, sin aplicar reglas de negocio."""
 from openpyxl import load_workbook
 w=load_workbook(src,read_only=True,data_only=False)
 try:
  if len(w.worksheets)!=1:raise ValueError('Excel debe tener una sola hoja.')
  with Path(dest).open('w',encoding='utf-8-sig',newline='') as f:
   writer=csv.writer(f)
   for n,row in enumerate(w.worksheets[0].iter_rows(),1):
    values=[]
    for i,c in enumerate(row):
     if c.data_type=='f':raise ValueError(f'Formula en fila {n}: entregar valores.')
     if n>1 and i in (4,6,8,12) and isinstance(c.value,(int,float)):raise ValueError(f'Codigo numerico en fila {n}: guardar como texto.')
     values.append(c.value)
    if n==1 and [cabecera(v) for v in values]!=COLUMNAS:raise ValueError('Cabecera Excel incompatible.')
    if any(v is not None for v in values):writer.writerow(values)
 finally:w.close()
class Orquestador:
 def __init__(self,root=ROOT,informar=lambda s:None,**kwargs):
  self.root=Path(root);self.informar=informar;self.datos=self.root/'operacion';self.datos.mkdir(exist_ok=True);self.db=self.datos/'recepciones.sqlite'
  with sqlite3.connect(self.db) as c:c.execute('CREATE TABLE IF NOT EXISTS recepciones(id TEXT PRIMARY KEY,fecha TEXT,estado TEXT,detalle TEXT)')
 def historial(self):
  with sqlite3.connect(self.db) as c:return c.execute('SELECT id,fecha,estado,detalle FROM recepciones ORDER BY fecha DESC LIMIT 30').fetchall()
 def estado(self,id,estado,detalle):
  with sqlite3.connect(self.db) as c:c.execute('UPDATE recepciones SET estado=?,detalle=? WHERE id=?',(estado,detalle,id))
  self.informar(estado+' | '+detalle)
 def procesar(self,archivos,encoding=None):
  if len(archivos)!=1:raise ValueError('Selecciona un archivo por lote; puede contener varios meses completos.')
  id=uuid.uuid4().hex;folder=self.datos/'recibidos'/id;folder.mkdir(parents=True)
  with sqlite3.connect(self.db) as c:c.execute('INSERT INTO recepciones VALUES(?,?,?,?)',(id,datetime.now(timezone.utc).isoformat(),'RECIBIENDO','Archivando original'))
  try:
   src=Path(archivos[0]);dest=folder/src.name;sha=hashlib.sha256()
   with src.open('rb') as fi,dest.open('wb') as fo:
    while block:=fi.read(4*1024*1024):fo.write(block);sha.update(block)
   info={'original':src.name,'bytes':dest.stat().st_size,'sha256':sha.hexdigest(),'contrato':'SNAPSHOT_MENSUAL_COMPLETO','base_raw':'SIS_RAW'}
   entrada=dest
   if dest.suffix.lower()=='.xlsx':
    self.estado(id,'PREPARANDO_EXCEL','Conversion secuencial de Excel; CSV no utiliza esta etapa')
    entrada=folder/'excel_preparado.csv';preparar_excel(dest,entrada)
   elif dest.suffix.lower()!='.csv':raise ValueError('Solo CSV o XLSX.')
   formato=inspeccionar(entrada,encoding);info.update(formato);json_guardar(folder/'recepcion.json',info)
   self.estado(id,'CARGANDO_SSIS','CSV -> RAW -> NORMALIZADA -> DIMENSIONAL')
   args=['-Archivo',entrada,'-CodePage',formato['codepage'],'-Delimitador',formato['delimiter'],'-FinLinea',formato['fin_linea'],'-CarpetaEvidencia',folder/'ssis']
   if entrada==dest:args+=['-Sha256',sha.hexdigest()]
   if formato['unicode']:args+=['-Unicode']
   powershell(self.root/'motor/Ejecutar_3BD.ps1',args,folder/'ejecucion.log')
   result=json.loads((folder/'ssis/resultado.json').read_text(encoding='utf-8-sig'))
   if result['estado']!='EXITOSO':raise RuntimeError('SQL no confirma exito.')
   self.estado(id,'PUBLICADO_SQL',f"{result['filas_dm']:,} hechos | {result['atenciones_dm']:,} atenciones")
   return result
  except Exception as e:
   self.estado(id,'REQUIERE_REVISION',str(e));json_guardar(folder/'error.json',{'mensaje':str(e)});raise

 def procesar_incremental(self):
  """Publica eventos SQL pendientes a traves del mismo paquete SSIS de tres capas."""
  id=uuid.uuid4().hex;folder=self.datos/'incrementales'/id;folder.mkdir(parents=True)
  with sqlite3.connect(self.db) as c:
   c.execute('INSERT INTO recepciones VALUES(?,?,?,?)',(id,datetime.now(timezone.utc).isoformat(),'INCREMENTAL_PENDIENTE','Revisando eventos SQL pendientes'))
  try:
   self.estado(id,'EJECUTANDO_SSIS_INCREMENTAL','SIS_RAW -> SIS_NORMALIZADA -> SIS_DIMENSIONAL')
   powershell(self.root/'motor/Ejecutar_Incremental.ps1',['-CarpetaEvidencia',folder/'ssis'],folder/'ejecucion.log')
   result=json.loads((folder/'ssis/resultado.json').read_text(encoding='utf-8-sig'))
   if result['estado']=='SIN_PENDIENTES':
    self.estado(id,'SIN_PENDIENTES','No existian eventos SQL por publicar.')
    return result
   if result['estado']!='EXITOSO':raise RuntimeError('SQL no confirmo la publicacion incremental.')
   self.estado(id,'PUBLICADO_INCREMENTAL',f"Lote {result['id_lote']} | {result['mensaje']}")
   return result
  except Exception as e:
   self.estado(id,'REQUIERE_REVISION',str(e));json_guardar(folder/'error.json',{'mensaje':str(e)});raise
def main():
 p=argparse.ArgumentParser();p.add_argument('archivo',type=Path);p.add_argument('--encoding',choices=['cp1252']);a=p.parse_args()
 print(json.dumps(Orquestador(informar=print).procesar([a.archivo],a.encoding),ensure_ascii=True))
if __name__=='__main__':main()
