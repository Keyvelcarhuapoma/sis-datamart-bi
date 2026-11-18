"""Aplicación local para recibir archivos SIS y ejecutar el proceso completo."""
import os
from pathlib import Path
import queue
import threading
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
from orquestador import Orquestador, ROOT


class Aplicacion:
 def __init__(self,ventana):
  self.v=ventana;self.eventos=queue.Queue();self.ocupado=False;self.ciclo=0
  ventana.title('SIS | ELT de tres bases');ventana.geometry('1120x790');ventana.minsize(950,690)
  ventana.configure(bg='#edf2f7')
  st=ttk.Style();st.theme_use('clam')
  st.configure('TFrame',background='#edf2f7');st.configure('TLabel',background='#edf2f7',foreground='#18324f',font=('Segoe UI',10))
  st.configure('Titulo.TLabel',font=('Segoe UI',25,'bold'))
  st.configure('Sub.TLabel',font=('Segoe UI',11))
  st.configure('TButton',font=('Segoe UI',11),padding=(16,11))
  st.configure('Subir.TButton',background='#087e8b',foreground='white',font=('Segoe UI',12,'bold'))
  st.map('Subir.TButton',background=[('active','#066672')])
  st.configure('Treeview',font=('Segoe UI',10),rowheight=28);st.configure('Treeview.Heading',font=('Segoe UI',10,'bold'))
  marco=ttk.Frame(ventana,padding=28);marco.pack(fill='both',expand=True)
  ttk.Label(marco,text='SIS / INTEGRACIÓN DE DATOS',font=('Segoe UI',10,'bold')).pack(anchor='w')
  ttk.Label(marco,text='Del archivo al informe',style='Titulo.TLabel').pack(anchor='w',pady=(6,4))
  ttk.Label(marco,text='Sube un snapshot mensual y sigue la validación, carga y publicación.',style='Sub.TLabel').pack(anchor='w')
  ttk.Label(marco,text='ARCHIVO    →    SIS_RAW    →    SIS_NORMALIZADA    →    SIS_DIMENSIONAL    →    POWER BI',font=('Segoe UI',11,'bold')).pack(anchor='w',pady=(24,16))
  contrato=ttk.Label(marco,text='Ámbito: demostración SIS. Cada archivo debe contener todas las filas de los meses incluidos dentro de este ámbito.\nLos meses no recibidos se conservan. Los códigos deben estar guardados como texto. Un archivo por lote. Años autorizados configurables en SQL.',wraplength=1040,justify='left')
  contrato.pack(anchor='w',pady=(0,15))
  fila=ttk.Frame(marco);fila.pack(fill='x')
  self.subir=ttk.Button(fila,text='Subir snapshot mensual',style='Subir.TButton',command=self.seleccionar);self.subir.pack(side='left')
  self.incremental=ttk.Button(fila,text='Publicar cambios SQL',command=self.ejecutar_incremental);self.incremental.pack(side='left',padx=(10,0))
  ttk.Button(fila,text='Abrir Power BI',command=self.abrir_powerbi).pack(side='left',padx=10)
  ttk.Button(fila,text='Ver ejemplos',command=lambda:os.startfile(ROOT/'ejemplos')).pack(side='left')
  ttk.Button(fila,text='Ver evidencias',command=lambda:os.startfile(ROOT/'operacion')).pack(side='left',padx=10)
  self.codificacion=tk.StringVar(value='UTF-8 / automatico BOM')
  codfila=ttk.Frame(marco);codfila.pack(fill='x',pady=(12,0))
  ttk.Label(codfila,text='Codificacion CSV:').pack(side='left',padx=(0,8))
  ttk.Combobox(codfila,textvariable=self.codificacion,values=['UTF-8 / automatico BOM','Windows-1252 confirmado'],state='readonly',width=29).pack(side='left')
  ttk.Button(fila,text='Diagrama',command=lambda:os.startfile(ROOT/'documentacion/DIAGRAMA_COMPLETO.html')).pack(side='left',padx=6)
  self.estado=tk.StringVar(value='Listo para recibir archivos .xlsx o .csv')
  ttk.Label(marco,textvariable=self.estado,font=('Segoe UI',12,'bold'),wraplength=1040).pack(anchor='w',pady=(24,8))
  self.barra=ttk.Progressbar(marco,mode='indeterminate');self.barra.pack(fill='x')
  ttk.Label(marco,text='Power BI consulta SQL automáticamente con el informe abierto. No hace falta pulsar Actualizar.',wraplength=1040).pack(anchor='w',pady=(10,18))
  ttk.Label(marco,text='Actividad del proceso',font=('Segoe UI',11,'bold')).pack(anchor='w')
  self.log=tk.Text(marco,height=7,font=('Consolas',10),bg='#142c43',fg='#e6f3fc',relief='flat',padx=12,pady=10,state='disabled')
  self.log.pack(fill='both',expand=True,pady=(7,16))
  ttk.Label(marco,text='Historial de recepciones',font=('Segoe UI',11,'bold')).pack(anchor='w')
  self.tabla=ttk.Treeview(marco,columns=('fecha','estado','detalle'),show='headings',height=5)
  for col,nombre,ancho in [('fecha','Fecha UTC',175),('estado','Estado',165),('detalle','Resultado',650)]:
   self.tabla.heading(col,text=nombre);self.tabla.column(col,width=ancho,minwidth=80)
  self.tabla.pack(fill='x',pady=(8,0))
  self.motor=Orquestador(informar=lambda s:self.eventos.put(('log',s)))
  self.refrescar();ventana.after(250,self.revisar)
  ventana.protocol('WM_DELETE_WINDOW',self.cerrar)

 def seleccionar(self):
  if self.ocupado:return
  archivos=filedialog.askopenfilenames(title='Seleccionar snapshots mensuales completos del ámbito SIS de demostración',filetypes=[('Archivos SIS','*.xlsx *.csv'),('Excel','*.xlsx'),('CSV','*.csv')],initialdir=ROOT/'ejemplos')
  if not archivos:return
  self.ocupado=True;self.subir.configure(state='disabled');self.barra.start(15)
  self.estado.set('Recibiendo y validando archivos...')
  threading.Thread(target=self.cargar,args=(archivos,),daemon=False).start()

 def cargar(self,archivos):
  try:self.eventos.put(('fin',self.motor.procesar(archivos,encoding='cp1252' if self.codificacion.get().startswith('Windows') else None)))
  except Exception as error:self.eventos.put(('error',str(error)))

 def ejecutar_incremental(self):
  if self.ocupado:return
  self.ocupado=True;self.subir.configure(state='disabled');self.incremental.configure(state='disabled');self.barra.start(15)
  self.estado.set('Procesando eventos SQL pendientes mediante SSIS...')
  threading.Thread(target=self.cargar_incremental,daemon=False).start()

 def cargar_incremental(self):
  try:self.eventos.put(('fin_incremental',self.motor.procesar_incremental()))
  except Exception as error:self.eventos.put(('error',str(error)))

 def revisar(self):
  try:
   while True:
    tipo,valor=self.eventos.get_nowait()
    if tipo=='log':
     self.log.configure(state='normal');self.log.insert('end',valor+'\n');self.log.see('end');self.log.configure(state='disabled');self.estado.set(valor)
    else:
     self.ocupado=False;self.subir.configure(state='normal');self.incremental.configure(state='normal');self.barra.stop()
     if tipo=='fin':
      self.estado.set(f"Carga correcta: {valor['filas_dm']:,} hechos y {valor['atenciones_dm']:,} atenciones. Power BI consulta la base publicada.")
     elif tipo=='fin_incremental':
      if valor['estado']=='SIN_PENDIENTES':self.estado.set('No hay cambios SQL pendientes por publicar.')
      else:self.estado.set(f"Carga incremental publicada. {valor['mensaje']}. Power BI consulta la base publicada.")
     else:
      self.estado.set('Carga detenida: requiere revisión del archivo o del proceso.')
      messagebox.showerror('Proceso requiere revisión',valor+'\nConsulta la auditoría antes de reintentar.')
     self.refrescar()
  except queue.Empty:pass
  self.ciclo+=1
  if self.ciclo%20==0 and not self.ocupado:self.refrescar()
  self.v.after(250,self.revisar)

 def refrescar(self):
  for i in self.tabla.get_children():self.tabla.delete(i)
  for id,fecha,estado,detalle in self.motor.historial():self.tabla.insert('', 'end',iid=id,values=(fecha[:19].replace('T',' '),estado,detalle))

 def abrir_powerbi(self):
  p=ROOT/'PowerBI/SIS_Final_3BD.pbip'
  try:os.startfile(p)
  except OSError:messagebox.showinfo('Abrir informe',f'Abre Power BI Desktop y selecciona este proyecto:\n{p}')

 def cerrar(self):
  if self.ocupado:
   messagebox.showinfo('Carga en curso','Espera a que termine la carga antes de cerrar la aplicación.');return
  self.v.destroy()


if __name__=='__main__':
 if os.name=='nt':
  import ctypes
  ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID('SIS.CentroCargas.Automatizado')
 v=tk.Tk();Aplicacion(v);v.mainloop()
