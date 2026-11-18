using System;
using System.IO;
using Microsoft.SqlServer.Dts.Runtime;
using Microsoft.SqlServer.Dts.Pipeline.Wrapper;
using W=Microsoft.SqlServer.Dts.Runtime.Wrapper;

public static class CrearIncremental {
 static string root;
 public static Package p;
 static ConnectionManager db; static ConnectionManager bulk;
 static Executable previous;
 static void Link(Executable t) { if(previous!=null) p.PrecedenceConstraints.Add(previous,t).Value=DTSExecResult.Success; previous=t; }
 static void Sql(string name,string sql,bool lot) {
  TaskHost t=(TaskHost)p.Executables.Add("Microsoft.SqlServer.Dts.Tasks.ExecuteSQLTask.ExecuteSQLTask, Microsoft.SqlServer.SQLTask, Version=17.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91");
  t.Name=name;t.DelayValidation=true;
  t.Properties["Connection"].SetValue(t,db.ID);
  // 0 significa sin límite de tiempo en SSIS. El archivo se mantiene como una
  // sola entrega; Fast Load lo confirma internamente por bloques y las fases
  // SQL pueden terminar sin que un snapshot masivo sea cancelado a los 30 min.
  t.Properties["TimeOut"].SetValue(t,(uint)0);
  if(lot){
   string v="SQL_"+name;p.Variables.Add(v,false,"User",sql);
   t.SetExpression("SqlStatementSource","\"DECLARE @Lote uniqueidentifier = '\" + @[User::IdLote] + \"'; DECLARE @Esperadas bigint = \" + @[User::FilasEsperadas] + \"; DECLARE @SimularFallo int = \" + @[User::SimularFallo] + \"; \" + \" DECLARE @Modo varchar(20)='\" + @[User::Modo] + \"'; DECLARE @Archivo nvarchar(1000)=N'\" + REPLACE(@[User::Archivo_Entrada],\"'\",\"''\") + \"'; \" + @[User::"+v+"]");
  }else t.Properties["SqlStatementSource"].SetValue(t,sql);
  Link(t);
 }
 static void Flow(int year) {
  string suffix="Entrada";
  ConnectionManager file=p.Connections.Add("FLATFILE");file.Name="CSV_"+suffix;
  file.ConnectionString=Path.Combine(root,"fuentes","entrada.csv");
  p.Variables.Add("Archivo_"+suffix,false,"User",file.ConnectionString);
  file.SetExpression("ConnectionString","@[User::Archivo_"+suffix+"]");
  W.IDTSConnectionManagerFlatFile100 flat=(W.IDTSConnectionManagerFlatFile100)file.InnerObject;
  flat.Format="Delimited";flat.Unicode=false;flat.CodePage=65001;flat.ColumnNamesInFirstDataRow=true;flat.TextQualifier="\"";flat.HeaderRowDelimiter="\r\n";flat.RowDelimiter="\r\n";
  string[] names={"ANIO","MES","REGION","PROVINCIA","UBIGEO_DISTRITO","DISTRITO","COD_UNIDAD_EJECUTORA","DESC_UNIDAD_EJECUTORA","COD_IPRESS","IPRESS","NIVEL_EESS","PLAN_SEGURO","COD_SERVICIO","DESC_SERVICIO","SEXO","GRUPO_EDAD","ATENCIONES"};
  for(int i=0;i<names.Length;i++){
   W.IDTSConnectionManagerFlatFileColumn100 c=flat.Columns.Add();
   ((W.IDTSName100)c).Name=names[i];c.ColumnType="Delimited";c.ColumnDelimiter=i==names.Length-1?"\r\n":",";
   c.DataType=W.DataType.DT_WSTR;c.MaximumWidth=1000;c.TextQualified=true;
  }
  TaskHost t=(TaskHost)p.Executables.Add("STOCK:PipelineTask");t.Name="02_CSV_a_SIS_RAW_FastLoad";t.DelayValidation=true;t.SetExpression("Disable","@[User::Modo] == \"SQL\"");
  MainPipe pipe=(MainPipe)t.InnerObject;pipe.DefaultBufferMaxRows=1000;pipe.DefaultBufferSize=10485760;pipe.EngineThreads=2;
  IDTSComponentMetaData100 source=pipe.ComponentMetaDataCollection.New();source.ComponentClassID="DTSAdapter.FlatFileSource.9";
  CManagedComponentWrapper sw=source.Instantiate();sw.ProvideComponentProperties();source.Name="Leer_CSV_"+suffix;
  source.RuntimeConnectionCollection[0].ConnectionManager=DtsConvert.GetExtendedInterface(file);source.RuntimeConnectionCollection[0].ConnectionManagerID=file.ID;
  sw.AcquireConnections(null);sw.ReinitializeMetaData();sw.ReleaseConnections();
  IDTSComponentMetaData100 dest=pipe.ComponentMetaDataCollection.New();dest.ComponentClassID="DTSAdapter.OLEDBDestination.9";
  CManagedComponentWrapper dw=dest.Instantiate();dw.ProvideComponentProperties();dest.Name="Cargar_stg_Raw_"+suffix;
  dest.RuntimeConnectionCollection[0].ConnectionManager=DtsConvert.GetExtendedInterface(bulk);dest.RuntimeConnectionCollection[0].ConnectionManagerID=bulk.ID;
  Console.WriteLine("Config destino");dw.SetComponentProperty("AccessMode",3);dw.SetComponentProperty("OpenRowset","[stg].[Entrada]");dw.SetComponentProperty("FastLoadMaxInsertCommitSize",1000);dw.SetComponentProperty("FastLoadOptions","TABLOCK,ROWS_PER_BATCH=1000");dw.SetComponentProperty("FastLoadKeepNulls",true);
  Console.WriteLine("Metadatos destino");dw.AcquireConnections(null);dw.ReinitializeMetaData();dw.ReleaseConnections();
  IDTSPath100 path=pipe.PathCollection.New();path.AttachPathAndPropagateNotifications(source.OutputCollection[0],dest.InputCollection[0]);
  IDTSInput100 input=dest.InputCollection[0];IDTSVirtualInput100 vi=input.GetVirtualInput();
  foreach(IDTSVirtualInputColumn100 vc in vi.VirtualInputColumnCollection){
   IDTSInputColumn100 ic=dw.SetUsageType(input.ID,vi,vc.LineageID,DTSUsageType.UT_READONLY);
   foreach(IDTSExternalMetadataColumn100 ec in input.ExternalMetadataColumnCollection) if(ec.Name==vc.Name) {dw.MapInputColumn(input.ID,ic.ID,ec.ID);break;}
  }
  source.OutputCollection[0].ErrorRowDisposition=DTSRowDisposition.RD_NotUsed;
  source.OutputCollection[0].TruncationRowDisposition=DTSRowDisposition.RD_NotUsed;
  foreach(IDTSOutputColumn100 oc in source.OutputCollection[0].OutputColumnCollection){oc.ErrorRowDisposition=DTSRowDisposition.RD_RedirectRow;oc.TruncationRowDisposition=DTSRowDisposition.RD_RedirectRow;}
  IDTSComponentMetaData100 err=pipe.ComponentMetaDataCollection.New();err.ComponentClassID="DTSAdapter.OLEDBDestination.9";
  CManagedComponentWrapper ew=err.Instantiate();ew.ProvideComponentProperties();err.Name="Cuarentena_Errores_de_Lectura";
  err.RuntimeConnectionCollection[0].ConnectionManager=DtsConvert.GetExtendedInterface(bulk);err.RuntimeConnectionCollection[0].ConnectionManagerID=bulk.ID;
  ew.SetComponentProperty("AccessMode",3);ew.SetComponentProperty("OpenRowset","[stg].[ErroresLectura]");ew.SetComponentProperty("FastLoadMaxInsertCommitSize",1000);
  ew.AcquireConnections(null);ew.ReinitializeMetaData();ew.ReleaseConnections();
  pipe.PathCollection.New().AttachPathAndPropagateNotifications(source.OutputCollection[1],err.InputCollection[0]);
  var ei=err.InputCollection[0];var ev=ei.GetVirtualInput();
  foreach(IDTSVirtualInputColumn100 vc in ev.VirtualInputColumnCollection){
   foreach(IDTSExternalMetadataColumn100 ec in ei.ExternalMetadataColumnCollection)if(ec.Name==vc.Name){
    var ic=ew.SetUsageType(ei.ID,ev,vc.LineageID,DTSUsageType.UT_READONLY);ew.MapInputColumn(ei.ID,ic.ID,ec.ID);break;
   }
  }
  Console.WriteLine("Flujo creado: "+t.Name);Link(t);
 }

 static void Errors(){
  DtsEventHandler handler=(DtsEventHandler)p.EventHandlers.Add("OnError");
  TaskHost t=(TaskHost)handler.Executables.Add("Microsoft.SqlServer.Dts.Tasks.ExecuteSQLTask.ExecuteSQLTask, Microsoft.SqlServer.SQLTask, Version=17.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91");
  t.Name="Registrar_Error";t.DelayValidation=true;t.DisableEventHandlers=true;
  t.Properties["Connection"].SetValue(t,db.ID);t.Properties["TimeOut"].SetValue(t,(uint)60);
  t.SetExpression("SqlStatementSource","\"DECLARE @Lote uniqueidentifier='\" + @[User::IdLote] + \"'; DECLARE @Mensaje nvarchar(2000)=N'\" + REPLACE(@[System::ErrorDescription],\"'\",\"''\") + \"'; IF XACT_STATE()<>0 ROLLBACK; IF NOT EXISTS(SELECT 1 FROM etl.Lotes WHERE id_lote=@Lote) INSERT etl.Lotes(id_lote,modo,estado) VALUES(@Lote,'Incremental_SSIS','ERROR'); UPDATE etl.Lotes SET estado='ERROR',fecha_fin=sysdatetime(),mensaje=@Mensaje WHERE id_lote=@Lote; INSERT etl.Errores(id_lote,mensaje) VALUES(@Lote,@Mensaje); UPDATE raw.EventosSQL SET estado='RECHAZADO' WHERE id_lote=@Lote AND estado='PROCESANDO';\"");
  DtsEventHandler post=(DtsEventHandler)p.EventHandlers.Add("OnPostExecute");
  TaskHost release=(TaskHost)post.Executables.Add("Microsoft.SqlServer.Dts.Tasks.ExecuteSQLTask.ExecuteSQLTask, Microsoft.SqlServer.SQLTask, Version=17.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91");
  release.Name="Liberar_Bloqueo_al_Final";release.DelayValidation=true;release.DisableEventHandlers=true;
  release.SetExpression("Disable","@[System::SourceID] != @[System::PackageID]");
  release.Properties["Connection"].SetValue(release,db.ID);release.Properties["TimeOut"].SetValue(release,(uint)60);
  release.Properties["SqlStatementSource"].SetValue(release,"IF APPLOCK_MODE('public','SIS_3BD','Session')='Exclusive' EXEC sys.sp_releaseapplock @Resource='SIS_3BD',@LockOwner='Session';");
 }
 public static void Build(string folder){
  root=Path.GetFullPath(folder);p=new Package();p.Name="SIS_ELT_3BD";
  p.Description="ELT de tres bases: CSV directo a SIS_RAW; validacion y normalizacion en SQL; modelo estrella incremental. SQL eventos con clave/version.";
  p.ProtectionLevel=DTSProtectionLevel.DontSaveSensitive;p.MaxConcurrentExecutables=1;
  p.Variables.Add("Modo",false,"User","SNAPSHOT");p.Variables.Add("Servidor",false,"User","localhost");p.Variables.Add("BaseDatos",false,"User","SIS_RAW");p.Variables.Add("FilasEsperadas",false,"User","40000");p.Variables.Add("SimularFallo",false,"User","0");
  Variable lot=p.Variables.Add("IdLote",false,"User",Guid.NewGuid().ToString());lot.EvaluateAsExpression=true;lot.Expression="@[System::ExecutionInstanceGUID]";
  db=p.Connections.Add("ADO.NET:System.Data.SqlClient.SqlConnection, System.Data, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089");db.Name="SQL_SIS_ELT_3BD";
  db.Properties["RetainSameConnection"].SetValue(db,true);
  db.ConnectionString="Data Source=localhost;Initial Catalog=SIS_RAW;Integrated Security=True;Encrypt=True;TrustServerCertificate=True;";
  db.SetExpression("ConnectionString","\"Data Source=\" + @[User::Servidor] + \";Initial Catalog=\" + @[User::BaseDatos] + \";Integrated Security=True;Encrypt=True;TrustServerCertificate=True;\"");
  bulk=p.Connections.Add("OLEDB");bulk.Name="SQL_Carga_Rapida";bulk.ConnectionString="Provider=MSOLEDBSQL19;Data Source=localhost;Initial Catalog=SIS_RAW;Integrated Security=SSPI;Use Encryption for Data=Mandatory;Trust Server Certificate=True;"; bulk.SetExpression("ConnectionString","\"Provider=MSOLEDBSQL19;Data Source=\" + @[User::Servidor] + \";Initial Catalog=\" + @[User::BaseDatos] + \";Integrated Security=SSPI;Use Encryption for Data=Mandatory;Trust Server Certificate=True;\"");
  Sql("01_Iniciar_Lote_y_Bloquear",File.ReadAllText(Path.Combine(root,"sql","10_iniciar.sql")),true);
  Flow(0);
  Sql("03_Archivar_RAW_Historico",File.ReadAllText(Path.Combine(root,"sql","15_archivar.sql")),true);
  Sql("04_Validar_Contrato_y_Nulos",File.ReadAllText(Path.Combine(root,"sql","20_validar.sql")),true);
  Sql("05_Detectar_Incremento",File.ReadAllText(Path.Combine(root,"sql","25_detectar.sql")),true);
  Sql("06_Normalizar_SIS_NORMALIZADA",File.ReadAllText(Path.Combine(root,"sql","30_normalizar.sql")),true);
  Sql("07_Publicar_SIS_DIMENSIONAL",File.ReadAllText(Path.Combine(root,"sql","40_dimensional.sql")),true);
  Sql("08_Conciliar_y_Confirmar",File.ReadAllText(Path.Combine(root,"sql","50_conciliar.sql")),true);
  Errors();
  new Application().SaveToXml(Path.Combine(root,"SIS_ELT_3BD.dtsx"),p,null);
  Console.WriteLine("Paquete nativo guardado");
 }
}





