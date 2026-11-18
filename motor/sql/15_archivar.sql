SET NOCOUNT ON;
IF @Modo='SNAPSHOT'
 INSERT raw.Registros(id_lote,fila_origen,fuente_tipo,[ANIO],[MES],[REGION],[PROVINCIA],[UBIGEO_DISTRITO],[DISTRITO],[COD_UNIDAD_EJECUTORA],[DESC_UNIDAD_EJECUTORA],[COD_IPRESS],[IPRESS],[NIVEL_EESS],[PLAN_SEGURO],[COD_SERVICIO],[DESC_SERVICIO],[SEXO],[GRUPO_EDAD],[ATENCIONES]) SELECT @Lote,fila_archivo,'SNAPSHOT',[ANIO],[MES],[REGION],[PROVINCIA],[UBIGEO_DISTRITO],[DISTRITO],[COD_UNIDAD_EJECUTORA],[DESC_UNIDAD_EJECUTORA],[COD_IPRESS],[IPRESS],[NIVEL_EESS],[PLAN_SEGURO],[COD_SERVICIO],[DESC_SERVICIO],[SEXO],[GRUPO_EDAD],[ATENCIONES] FROM stg.Entrada;
ELSE IF EXISTS(SELECT 1 FROM raw.Registros WHERE id_lote=@Lote AND fuente_tipo='SQL' AND estado_proceso='PENDIENTE') BEGIN
 UPDATE raw.Registros SET estado_proceso='PROCESANDO' WHERE id_lote=@Lote AND fuente_tipo='SQL' AND estado_proceso='PENDIENTE';
END ELSE BEGIN
 ;WITH e AS(SELECT TOP(1000) * FROM raw.EventosSQL WITH(UPDLOCK,READPAST) WHERE estado='PENDIENTE' ORDER BY id_evento)
 UPDATE e SET estado='PROCESANDO',id_lote=@Lote;
 INSERT raw.Registros(id_lote,fila_origen,fuente_tipo,clave_origen,version_origen,operacion,id_evento,[ANIO],[MES],[REGION],[PROVINCIA],[UBIGEO_DISTRITO],[DISTRITO],[COD_UNIDAD_EJECUTORA],[DESC_UNIDAD_EJECUTORA],[COD_IPRESS],[IPRESS],[NIVEL_EESS],[PLAN_SEGURO],[COD_SERVICIO],[DESC_SERVICIO],[SEXO],[GRUPO_EDAD],[ATENCIONES])
 SELECT @Lote,e.id_evento,'SQL',e.clave_origen,e.version,e.operacion,e.id_evento,j.[ANIO],j.[MES],j.[REGION],j.[PROVINCIA],j.[UBIGEO_DISTRITO],j.[DISTRITO],j.[COD_UNIDAD_EJECUTORA],j.[DESC_UNIDAD_EJECUTORA],j.[COD_IPRESS],j.[IPRESS],j.[NIVEL_EESS],j.[PLAN_SEGURO],j.[COD_SERVICIO],j.[DESC_SERVICIO],j.[SEXO],j.[GRUPO_EDAD],j.[ATENCIONES] FROM raw.EventosSQL e OUTER APPLY OPENJSON(e.datos) WITH([ANIO] nvarchar(1000) '$.ANIO',[MES] nvarchar(1000) '$.MES',[REGION] nvarchar(1000) '$.REGION',[PROVINCIA] nvarchar(1000) '$.PROVINCIA',[UBIGEO_DISTRITO] nvarchar(1000) '$.UBIGEO_DISTRITO',[DISTRITO] nvarchar(1000) '$.DISTRITO',[COD_UNIDAD_EJECUTORA] nvarchar(1000) '$.COD_UNIDAD_EJECUTORA',[DESC_UNIDAD_EJECUTORA] nvarchar(1000) '$.DESC_UNIDAD_EJECUTORA',[COD_IPRESS] nvarchar(1000) '$.COD_IPRESS',[IPRESS] nvarchar(1000) '$.IPRESS',[NIVEL_EESS] nvarchar(1000) '$.NIVEL_EESS',[PLAN_SEGURO] nvarchar(1000) '$.PLAN_SEGURO',[COD_SERVICIO] nvarchar(1000) '$.COD_SERVICIO',[DESC_SERVICIO] nvarchar(1000) '$.DESC_SERVICIO',[SEXO] nvarchar(1000) '$.SEXO',[GRUPO_EDAD] nvarchar(1000) '$.GRUPO_EDAD',[ATENCIONES] nvarchar(1000) '$.ATENCIONES') j WHERE e.id_lote=@Lote AND e.estado='PROCESANDO';
END;
DECLARE @N bigint=(SELECT COUNT_BIG(*) FROM raw.Registros WHERE id_lote=@Lote);

UPDATE etl.Lotes SET filas_origen=@N,estado='RAW_ARCHIVADO' WHERE id_lote=@Lote;

IF EXISTS(SELECT 1 FROM stg.ErroresLectura) BEGIN
 INSERT etl.Rechazos(id_lote,archivo,motivo) SELECT @Lote,@Archivo,CONCAT('PARSER_SSIS: ErrorCode=',ErrorCode,'; columna=',ErrorColumn,'; original completo archivado en la recepcion') FROM stg.ErroresLectura;
 UPDATE etl.Lotes SET filas_rechazadas=(SELECT COUNT_BIG(*) FROM stg.ErroresLectura),filas_origen=filas_origen+(SELECT COUNT_BIG(*) FROM stg.ErroresLectura) WHERE id_lote=@Lote;
 THROW 52012,'Errores de lectura: lote conservado, no se publica parcialmente.',1;
END;
IF @Modo='SNAPSHOT' AND (SELECT COUNT_BIG(*) FROM raw.Registros WHERE id_lote=@Lote)<>(SELECT COUNT_BIG(*) FROM stg.Entrada) THROW 52013,'Conteo RAW no coincide con la entrada SSIS.',1;

IF @Modo='SNAPSHOT' AND @N=0 THROW 52005,'Snapshot vacio: no autoriza borrar periodos.',1;
