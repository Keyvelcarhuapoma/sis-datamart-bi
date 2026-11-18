SET NOCOUNT ON;
IF @Modo='SNAPSHOT' BEGIN
 UPDATE l SET huella_fila=HASHBYTES('SHA2_256',(SELECT l.[ANIO],l.[MES],l.[REGION],l.[PROVINCIA],l.[UBIGEO_DISTRITO],l.[DISTRITO],l.[COD_UNIDAD_EJECUTORA],l.[DESC_UNIDAD_EJECUTORA],l.[COD_IPRESS],l.[IPRESS],l.[NIVEL_EESS],l.[PLAN_SEGURO],l.[COD_SERVICIO],l.[DESC_SERVICIO],l.[SEXO],l.[GRUPO_EDAD],l.[ATENCIONES] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)) FROM stg.Limpia l;
 -- Merkle por 256 cubetas: conserva multiplicidad sin concatenar todo el mes en un unico valor.
 SELECT ANIO*100+MES periodo,CONVERT(varchar(64),huella_fila,2) h,COUNT_BIG(*) n INTO #H FROM stg.Limpia GROUP BY ANIO,MES,huella_fila OPTION(MAXDOP 1,MAX_GRANT_PERCENT=1);
 SELECT periodo,LEFT(h,2) cubeta,HASHBYTES('SHA2_256',STRING_AGG(CONVERT(varchar(max),CONCAT(h,':',n,';')),'') WITHIN GROUP(ORDER BY h)) firma INTO #B FROM #H GROUP BY periodo,LEFT(h,2) OPTION(MAXDOP 1,MAX_GRANT_PERCENT=1);
 SELECT periodo,HASHBYTES('SHA2_256',STRING_AGG(CONVERT(varchar(max),CONCAT(cubeta,CONVERT(varchar(64),firma,2))),';') WITHIN GROUP(ORDER BY cubeta)) firma INTO #P FROM #B GROUP BY periodo OPTION(MAXDOP 1,MAX_GRANT_PERCENT=1);
 INSERT etl.PlanParticion(id_lote,periodo,huella,filas,atenciones,accion,filas_anteriores,version_anterior)
 SELECT @Lote,n.periodo,h.firma,n.filas,n.atenciones,CASE WHEN p.periodo IS NULL THEN 'NUEVO' WHEN p.huella=h.firma AND p.filas=n.filas THEN 'SIN_CAMBIOS' ELSE 'CAMBIADO' END,COALESCE(p.filas,0),COALESCE(p.version,0)
 FROM(SELECT ANIO*100+MES periodo,COUNT_BIG(*) filas,SUM(ATENCIONES) atenciones FROM stg.Limpia GROUP BY ANIO,MES)n JOIN #P h ON h.periodo=n.periodo LEFT JOIN etl.Particiones p ON p.periodo=n.periodo;
 IF EXISTS(SELECT 1 FROM etl.PlanParticion WHERE id_lote=@Lote AND filas<filas_anteriores*0.8) BEGIN
  INSERT etl.Rechazos(id_lote,archivo,motivo) SELECT @Lote,@Archivo,CONCAT('SNAPSHOT_PARCIAL: periodo ',periodo,', filas previas ',filas_anteriores,', recibidas ',filas) FROM etl.PlanParticion WHERE id_lote=@Lote AND filas<filas_anteriores*0.8;
  THROW 52007,'Posible snapshot parcial: disminucion superior al 20%; requiere revision.',1;
 END;
 INSERT etl.Afectados SELECT @Lote,periodo FROM etl.PlanParticion WHERE id_lote=@Lote AND accion<>'SIN_CAMBIOS';
END ELSE BEGIN
 INSERT etl.Afectados SELECT @Lote,periodo FROM(
 SELECT ANIO*100+MES periodo FROM stg.Limpia
 UNION SELECT a.anio*100+a.mes FROM SIS_NORMALIZADA.oltp.Registro_Atencion a JOIN raw.Registros r ON r.clave_origen=a.clave_origen WHERE r.id_lote=@Lote AND a.fuente_tipo='SQL')p;
END;
UPDATE etl.Lotes SET estado='CAMBIOS_DETECTADOS' WHERE id_lote=@Lote;
