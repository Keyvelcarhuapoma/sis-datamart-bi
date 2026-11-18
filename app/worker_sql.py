"""Procesa la cola SQL con SSIS. Una ejecucion programada, sin bucle residente."""
from orquestador import ROOT,PS,powershell,json_guardar,Orquestador
import json,os,subprocess,uuid,sqlite3
from datetime import datetime,timezone

def ejecutar():
 env=os.environ.copy();env.pop('PSModulePath',None)
 r=subprocess.run([str(PS),'-NoProfile','-File',str(ROOT/'app/Pendientes.ps1')],capture_output=True,text=True,env=env,creationflags=subprocess.CREATE_NO_WINDOW)
 if r.returncode:raise RuntimeError(r.stderr)
 if int(r.stdout.strip() or 0)==0:return
 m=Orquestador();id=uuid.uuid4().hex;folder=ROOT/'operacion'/('sql_'+id);folder.mkdir(parents=True)
 with sqlite3.connect(m.db) as c:c.execute('INSERT INTO recepciones VALUES(?,?,?,?)',(id,datetime.now(timezone.utc).isoformat(),'SQL_PENDIENTE','Procesando eventos SQL'))
 try:
  powershell(ROOT/'motor/Ejecutar_3BD.ps1',['-Modo','SQL','-CarpetaEvidencia',folder],folder/'worker.log')
  out=json.loads((folder/'resultado.json').read_text(encoding='utf-8-sig'))
  m.estado(id,'PUBLICADO_SQL',f"SQL: {out['filas_dm']} hechos / {out['atenciones_dm']} atenciones")
 except Exception as e:m.estado(id,'REQUIERE_REVISION',str(e));raise
if __name__=='__main__':ejecutar()
