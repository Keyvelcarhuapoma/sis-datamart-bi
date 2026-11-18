SET NOCOUNT ON;
INSERT etl.Validaciones(id_lote,control,esperado,obtenido,cumple)
SELECT @Lote,CONCAT('ATENCIONES_',p.periodo),COALESCE(n.cantidad,0),COALESCE(d.cantidad,0),CASE WHEN COALESCE(n.cantidad,0)=COALESCE(d.cantidad,0) THEN 1 ELSE 0 END FROM etl.Afectados p
OUTER APPLY(SELECT SUM(cantidad_atenciones) cantidad FROM SIS_NORMALIZADA.oltp.Registro_Atencion WHERE anio=p.periodo/100 AND mes=p.periodo%100)n
OUTER APPLY(SELECT SUM(f.cantidad_atenciones) cantidad FROM SIS_DIMENSIONAL.dm.Fact_Atenciones f JOIN SIS_DIMENSIONAL.dm.Dim_Tiempo t ON t.id_tiempo_sk=f.id_tiempo_sk WHERE t.periodo_codigo=p.periodo)d WHERE p.id_lote=@Lote OPTION(MAXDOP 1,MAX_GRANT_PERCENT=1);
INSERT etl.Validaciones(id_lote,control,esperado,obtenido,cumple)
SELECT @Lote,CONCAT('LINAJE_FILAS_',p.periodo),COALESCE(n.filas,0),COALESCE(d.filas,0),CASE WHEN COALESCE(n.filas,0)=COALESCE(d.filas,0) THEN 1 ELSE 0 END FROM etl.Afectados p
OUTER APPLY(SELECT COUNT_BIG(*) filas FROM SIS_NORMALIZADA.oltp.Registro_Atencion WHERE anio=p.periodo/100 AND mes=p.periodo%100)n
OUTER APPLY(SELECT SUM(f.filas_origen) filas FROM SIS_DIMENSIONAL.dm.Fact_Atenciones f JOIN SIS_DIMENSIONAL.dm.Dim_Tiempo t ON t.id_tiempo_sk=f.id_tiempo_sk WHERE t.periodo_codigo=p.periodo)d WHERE p.id_lote=@Lote OPTION(MAXDOP 1,MAX_GRANT_PERCENT=1);
IF EXISTS(SELECT 1 FROM etl.Validaciones WHERE id_lote=@Lote AND cumple=0) THROW 52009,'Conciliacion fallida; rollback.',1;
INSERT etl.Publicaciones SELECT @Lote,periodo,version_anterior+1,huella,filas_anteriores,filas,atenciones,sysdatetime() FROM etl.PlanParticion WHERE id_lote=@Lote AND accion<>'SIN_CAMBIOS';
UPDATE p SET huella=n.huella,filas=n.filas,atenciones=n.atenciones,version=n.version_anterior+1,id_lote=@Lote,actualizado=sysdatetime() FROM etl.Particiones p JOIN etl.PlanParticion n ON n.periodo=p.periodo WHERE n.id_lote=@Lote AND n.accion='CAMBIADO';
INSERT etl.Particiones(periodo,huella,filas,atenciones,version,id_lote) SELECT periodo,huella,filas,atenciones,1,@Lote FROM etl.PlanParticion WHERE id_lote=@Lote AND accion='NUEVO';
IF EXISTS(SELECT 1 FROM etl.Afectados WHERE id_lote=@Lote) UPDATE SIS_DIMENSIONAL.dm.Publicacion SET version=version+1,id_lote=@Lote,fecha=sysdatetime() WHERE id=1;
UPDATE raw.EventosSQL SET estado='PUBLICADO' WHERE id_lote=@Lote AND estado='PROCESANDO';
UPDATE raw.Registros SET estado_proceso='PUBLICADO' WHERE id_lote=@Lote AND fuente_tipo='SQL' AND estado_proceso='PROCESANDO';
-- En SQL se confirman eventos (incluidas bajas/versiones superadas), no filas finales del hecho.
IF @Modo='SQL' UPDATE etl.Lotes SET filas_aceptadas=filas_origen WHERE id_lote=@Lote;
UPDATE etl.Lotes SET estado='EXITOSO',fecha_fin=sysdatetime(),filas_dm=(SELECT COUNT_BIG(*) FROM SIS_DIMENSIONAL.dm.Fact_Atenciones),atenciones_dm=(SELECT COALESCE(SUM(cantidad_atenciones),0) FROM SIS_DIMENSIONAL.dm.Fact_Atenciones),mensaje=CONCAT('Periodos afectados: ',(SELECT COUNT(*) FROM etl.Afectados WHERE id_lote=@Lote)) WHERE id_lote=@Lote;
COMMIT;
EXEC sys.sp_releaseapplock @Resource='SIS_3BD',@LockOwner='Session';
