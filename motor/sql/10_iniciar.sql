SET NOCOUNT ON;SET XACT_ABORT ON;
IF DB_NAME()<>'SIS_RAW' OR NOT EXISTS(SELECT 1 FROM etl.Proyecto WHERE nombre='SIS-3BD-v1') THROW 52003,'Base no autorizada.',1;
DECLARE @Lock int;EXEC @Lock=sys.sp_getapplock @Resource='SIS_3BD',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;
IF @Lock<0 THROW 52004,'Otra carga 3BD esta activa.',1;
EXEC sys.sp_set_session_context @key=N'Lote',@value=@Lote;
UPDATE raw.EventosSQL SET estado='PENDIENTE',id_lote=NULL WHERE estado='PROCESANDO';
UPDATE etl.Lotes SET estado='ERROR',fecha_fin=sysdatetime(),mensaje=N'Proceso anterior interrumpido; repetir entrada.' WHERE id_lote<>@Lote AND estado NOT IN('EXITOSO','ERROR');
IF EXISTS(SELECT 1 FROM etl.Lotes WHERE id_lote=@Lote)
 UPDATE etl.Lotes SET estado='CARGANDO_RAW',fecha_fin=NULL,mensaje=NULL WHERE id_lote=@Lote;
ELSE
 INSERT etl.Lotes(id_lote,modo,estado,archivo) VALUES(@Lote,@Modo,'CARGANDO_RAW',@Archivo);
TRUNCATE TABLE stg.Entrada;

TRUNCATE TABLE stg.ErroresLectura;
