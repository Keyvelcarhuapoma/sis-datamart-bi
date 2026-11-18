CREATE OR ALTER PROCEDURE raw.RecibirCambio
 @ClaveOrigen nvarchar(100),@Version int,@Datos nvarchar(max)=N'{}',@Operacion char(1)='U'
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF NULLIF(LTRIM(RTRIM(@ClaveOrigen)),N'') IS NULL OR @Version<=0 OR @Operacion NOT IN('U','D') OR ISJSON(@Datos)<>1 THROW 52001,'Evento invalido.',1;
 IF @Operacion='U' AND ((SELECT COUNT(*) FROM OPENJSON(@Datos))<>17 OR EXISTS(SELECT 1 FROM OPENJSON(@Datos) WHERE [key] NOT IN('ANIO','MES','REGION','PROVINCIA','UBIGEO_DISTRITO','DISTRITO','COD_UNIDAD_EJECUTORA','DESC_UNIDAD_EJECUTORA','COD_IPRESS','IPRESS','NIVEL_EESS','PLAN_SEGURO','COD_SERVICIO','DESC_SERVICIO','SEXO','GRUPO_EDAD','ATENCIONES') OR [type] NOT IN(0,1,2) OR DATALENGTH(value)>2000) OR EXISTS(SELECT [key] FROM OPENJSON(@Datos) GROUP BY [key] HAVING COUNT(*)>1)) THROW 52010,'JSON debe contener los 17 campos SIS, escalares de hasta 1000 caracteres.',1;
 IF @Operacion='U' AND EXISTS(SELECT 1 FROM OPENJSON(@Datos) WHERE [key] IN('UBIGEO_DISTRITO','COD_UNIDAD_EJECUTORA','COD_IPRESS','COD_SERVICIO') AND [type]=2) THROW 52011,'Los codigos deben ser cadenas para preservar ceros.',1;
 BEGIN TRAN;
 DECLARE @Id bigint,@Anterior nvarchar(max),@Op char(1);
 SELECT @Id=id_evento,@Anterior=datos,@Op=operacion FROM raw.EventosSQL WITH(UPDLOCK,HOLDLOCK) WHERE clave_origen=@ClaveOrigen AND version=@Version;
 IF @Id IS NOT NULL AND (@Anterior COLLATE Latin1_General_100_BIN2<>@Datos COLLATE Latin1_General_100_BIN2 OR @Op<>@Operacion) BEGIN ROLLBACK;THROW 52002,'La misma clave/version no puede cambiar de contenido.',1;END;
 IF @Id IS NULL BEGIN INSERT raw.EventosSQL(clave_origen,version,datos,operacion) VALUES(@ClaveOrigen,@Version,@Datos,@Operacion);SET @Id=SCOPE_IDENTITY();END;
 COMMIT;SELECT @Id id_evento;
END;

GO
/* Ruta canonica: el sistema origen escribe una sola vez en raw.Registros.
   SSIS toma el lote pendiente y materializa las capas normalizada y dimensional. */
CREATE OR ALTER PROCEDURE raw.InsertarRegistroOrigen
 @ClaveOrigen nvarchar(100),@Version int,@Datos nvarchar(max)=N'{}',@Operacion char(1)='U'
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF NULLIF(LTRIM(RTRIM(@ClaveOrigen)),N'') IS NULL OR @Version<=0 OR @Operacion NOT IN('U','D') OR ISJSON(@Datos)<>1 THROW 52001,'Registro incremental invalido.',1;
 IF @Operacion='U' AND ((SELECT COUNT(*) FROM OPENJSON(@Datos))<>17 OR EXISTS(SELECT 1 FROM OPENJSON(@Datos) WHERE [key] NOT IN('ANIO','MES','REGION','PROVINCIA','UBIGEO_DISTRITO','DISTRITO','COD_UNIDAD_EJECUTORA','DESC_UNIDAD_EJECUTORA','COD_IPRESS','IPRESS','NIVEL_EESS','PLAN_SEGURO','COD_SERVICIO','DESC_SERVICIO','SEXO','GRUPO_EDAD','ATENCIONES') OR [type] NOT IN(0,1,2) OR DATALENGTH(value)>2000) OR EXISTS(SELECT [key] FROM OPENJSON(@Datos) GROUP BY [key] HAVING COUNT(*)>1)) THROW 52010,'JSON debe contener exactamente los 17 campos SIS.',1;
 IF @Operacion='U' AND EXISTS(SELECT 1 FROM OPENJSON(@Datos) WHERE [key] IN('UBIGEO_DISTRITO','COD_UNIDAD_EJECUTORA','COD_IPRESS','COD_SERVICIO') AND [type]=2) THROW 52011,'Los codigos deben enviarse como texto para conservar ceros.',1;
 BEGIN TRAN;
 IF EXISTS(SELECT 1 FROM raw.Registros WITH(UPDLOCK,HOLDLOCK) WHERE clave_origen=@ClaveOrigen AND version_origen>=@Version)
 BEGIN ROLLBACK;THROW 52002,'La version debe ser mayor que la ultima version recibida para esa clave.',1;END;
 /* La capa normalizada es la referencia de lo ya publicado.  Asi se evita
    aceptar una version que no exista en RAW, pero ya haya sido procesada. */
 IF EXISTS(SELECT 1 FROM SIS_NORMALIZADA.oltp.OrigenVersion WITH(UPDLOCK,HOLDLOCK) WHERE clave_origen=@ClaveOrigen AND version>=@Version)
 BEGIN ROLLBACK;THROW 52003,'La version debe ser mayor que la ultima version ya publicada.',1;END;
 DECLARE @Lote uniqueidentifier=NEWID(),@IdRaw bigint;
 INSERT etl.Lotes(id_lote,modo,estado,archivo) VALUES(@Lote,'SQL_DIRECTO','RECIBIDO_SQL',N'raw.Registros');
 INSERT raw.Registros(id_lote,fila_origen,fuente_tipo,clave_origen,version_origen,operacion,estado_proceso,[ANIO],[MES],[REGION],[PROVINCIA],[UBIGEO_DISTRITO],[DISTRITO],[COD_UNIDAD_EJECUTORA],[DESC_UNIDAD_EJECUTORA],[COD_IPRESS],[IPRESS],[NIVEL_EESS],[PLAN_SEGURO],[COD_SERVICIO],[DESC_SERVICIO],[SEXO],[GRUPO_EDAD],[ATENCIONES])
 SELECT @Lote,1,'SQL',@ClaveOrigen,@Version,@Operacion,'PENDIENTE',j.[ANIO],j.[MES],j.[REGION],j.[PROVINCIA],j.[UBIGEO_DISTRITO],j.[DISTRITO],j.[COD_UNIDAD_EJECUTORA],j.[DESC_UNIDAD_EJECUTORA],j.[COD_IPRESS],j.[IPRESS],j.[NIVEL_EESS],j.[PLAN_SEGURO],j.[COD_SERVICIO],j.[DESC_SERVICIO],j.[SEXO],j.[GRUPO_EDAD],j.[ATENCIONES]
 FROM OPENJSON(@Datos) WITH([ANIO] nvarchar(1000) '$.ANIO',[MES] nvarchar(1000) '$.MES',[REGION] nvarchar(1000) '$.REGION',[PROVINCIA] nvarchar(1000) '$.PROVINCIA',[UBIGEO_DISTRITO] nvarchar(1000) '$.UBIGEO_DISTRITO',[DISTRITO] nvarchar(1000) '$.DISTRITO',[COD_UNIDAD_EJECUTORA] nvarchar(1000) '$.COD_UNIDAD_EJECUTORA',[DESC_UNIDAD_EJECUTORA] nvarchar(1000) '$.DESC_UNIDAD_EJECUTORA',[COD_IPRESS] nvarchar(1000) '$.COD_IPRESS',[IPRESS] nvarchar(1000) '$.IPRESS',[NIVEL_EESS] nvarchar(1000) '$.NIVEL_EESS',[PLAN_SEGURO] nvarchar(1000) '$.PLAN_SEGURO',[COD_SERVICIO] nvarchar(1000) '$.COD_SERVICIO',[DESC_SERVICIO] nvarchar(1000) '$.DESC_SERVICIO',[SEXO] nvarchar(1000) '$.SEXO',[GRUPO_EDAD] nvarchar(1000) '$.GRUPO_EDAD',[ATENCIONES] nvarchar(1000) '$.ATENCIONES') j;
 SET @IdRaw=SCOPE_IDENTITY();COMMIT;
 SELECT @IdRaw AS id_raw,@Lote AS id_lote,N'PENDIENTE' AS estado_proceso;
END;
