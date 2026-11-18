SET NOCOUNT ON;SET XACT_ABORT ON;
BEGIN TRAN;
SELECT l.* INTO #Carga FROM stg.Limpia l WHERE @Modo='SQL' OR EXISTS(SELECT 1 FROM etl.Afectados a WHERE a.id_lote=@Lote AND a.periodo=l.ANIO*100+l.MES) OPTION(MAXDOP 1,MAX_GRANT_PERCENT=1);
IF @Modo='SNAPSHOT'
 DELETE a FROM SIS_NORMALIZADA.oltp.Registro_Atencion a JOIN etl.Afectados p ON p.id_lote=@Lote AND a.anio=p.periodo/100 AND a.mes=p.periodo%100 WHERE a.fuente_tipo='SNAPSHOT' OPTION(MAXDOP 1,MAX_GRANT_PERCENT=1);
ELSE
 DELETE a FROM SIS_NORMALIZADA.oltp.Registro_Atencion a WHERE a.fuente_tipo='SQL' AND EXISTS(SELECT 1 FROM raw.Registros r WHERE r.id_lote=@Lote AND r.clave_origen=a.clave_origen) OPTION(MAXDOP 1,MAX_GRANT_PERCENT=1);
IF @SimularFallo=1 THROW 52008,'Fallo controlado: rollback entre las tres bases.',1;
INSERT SIS_NORMALIZADA.oltp.Region(nombre) SELECT DISTINCT REGION FROM #Carga l WHERE NOT EXISTS(SELECT 1 FROM SIS_NORMALIZADA.oltp.Region x WHERE x.nombre=l.REGION) OPTION(MAXDOP 1, MAX_GRANT_PERCENT=1);
INSERT SIS_NORMALIZADA.oltp.Provincia(id_region,nombre) SELECT DISTINCT r.id_region,l.PROVINCIA FROM #Carga l JOIN SIS_NORMALIZADA.oltp.Region r ON r.nombre=l.REGION WHERE NOT EXISTS(SELECT 1 FROM SIS_NORMALIZADA.oltp.Provincia x WHERE x.id_region=r.id_region AND x.nombre=l.PROVINCIA) OPTION(MAXDOP 1, MAX_GRANT_PERCENT=1);
INSERT SIS_NORMALIZADA.oltp.Distrito(id_provincia,ubigeo,nombre) SELECT DISTINCT p.id_provincia,l.UBIGEO_DISTRITO,l.DISTRITO FROM #Carga l JOIN SIS_NORMALIZADA.oltp.Region r ON r.nombre=l.REGION JOIN SIS_NORMALIZADA.oltp.Provincia p ON p.id_region=r.id_region AND p.nombre=l.PROVINCIA WHERE NOT EXISTS(SELECT 1 FROM SIS_NORMALIZADA.oltp.Distrito x WHERE x.id_provincia=p.id_provincia AND x.ubigeo=l.UBIGEO_DISTRITO AND x.nombre=l.DISTRITO) OPTION(MAXDOP 1, MAX_GRANT_PERCENT=1);
INSERT SIS_NORMALIZADA.oltp.Unidad_Ejecutora(clave_version,codigo,nombre) SELECT DISTINCT clave_unidad,COD_UNIDAD_EJECUTORA,DESC_UNIDAD_EJECUTORA FROM #Carga l WHERE NOT EXISTS(SELECT 1 FROM SIS_NORMALIZADA.oltp.Unidad_Ejecutora x WHERE x.clave_version=l.clave_unidad) OPTION(MAXDOP 1, MAX_GRANT_PERCENT=1);
INSERT SIS_NORMALIZADA.oltp.IPRESS(clave_version,cod_ipress,nombre,nivel,id_distrito,id_unidad,ubigeo_valido)
SELECT DISTINCT l.clave_ipress,l.COD_IPRESS,l.IPRESS,l.NIVEL_EESS,d.id_distrito,u.id_unidad,l.ubigeo_valido
FROM #Carga l JOIN SIS_NORMALIZADA.oltp.Region r ON r.nombre=l.REGION JOIN SIS_NORMALIZADA.oltp.Provincia p ON p.id_region=r.id_region AND p.nombre=l.PROVINCIA JOIN SIS_NORMALIZADA.oltp.Distrito d ON d.id_provincia=p.id_provincia AND d.ubigeo=l.UBIGEO_DISTRITO AND d.nombre=l.DISTRITO JOIN SIS_NORMALIZADA.oltp.Unidad_Ejecutora u ON u.clave_version=l.clave_unidad WHERE NOT EXISTS(SELECT 1 FROM SIS_NORMALIZADA.oltp.IPRESS x WHERE x.clave_version=l.clave_ipress) OPTION(MAXDOP 1, MAX_GRANT_PERCENT=1);
INSERT SIS_NORMALIZADA.oltp.Servicio(clave_version,codigo,descripcion) SELECT DISTINCT clave_servicio,COD_SERVICIO,DESC_SERVICIO FROM #Carga l WHERE NOT EXISTS(SELECT 1 FROM SIS_NORMALIZADA.oltp.Servicio x WHERE x.clave_version=l.clave_servicio) OPTION(MAXDOP 1, MAX_GRANT_PERCENT=1);
INSERT SIS_NORMALIZADA.oltp.Plan_Seguro(nombre) SELECT DISTINCT PLAN_SEGURO FROM #Carga l WHERE NOT EXISTS(SELECT 1 FROM SIS_NORMALIZADA.oltp.Plan_Seguro x WHERE x.nombre=l.PLAN_SEGURO) OPTION(MAXDOP 1, MAX_GRANT_PERCENT=1);
INSERT SIS_NORMALIZADA.oltp.Sexo(nombre) SELECT DISTINCT SEXO FROM #Carga l WHERE NOT EXISTS(SELECT 1 FROM SIS_NORMALIZADA.oltp.Sexo x WHERE x.nombre=l.SEXO) OPTION(MAXDOP 1, MAX_GRANT_PERCENT=1);
INSERT SIS_NORMALIZADA.oltp.Grupo_Edad(nombre) SELECT DISTINCT GRUPO_EDAD FROM #Carga l WHERE NOT EXISTS(SELECT 1 FROM SIS_NORMALIZADA.oltp.Grupo_Edad x WHERE x.nombre=l.GRUPO_EDAD) OPTION(MAXDOP 1, MAX_GRANT_PERCENT=1);

INSERT SIS_NORMALIZADA.oltp.Registro_Atencion(archivo,fila_archivo,anio,mes,id_ipress,id_servicio,id_plan,id_sexo,id_grupo_edad,cantidad_atenciones,fuente_tipo,clave_origen,version_origen,id_raw)
SELECT l.archivo,l.fila_archivo,l.ANIO,l.MES,i.id_ipress,s.id_servicio,p.id_plan,x.id_sexo,g.id_grupo_edad,l.ATENCIONES,@Modo,l.clave_origen,l.version_origen,l.id_raw
FROM #Carga l JOIN SIS_NORMALIZADA.oltp.IPRESS i ON i.clave_version=l.clave_ipress JOIN SIS_NORMALIZADA.oltp.Servicio s ON s.clave_version=l.clave_servicio JOIN SIS_NORMALIZADA.oltp.Plan_Seguro p ON p.nombre=l.PLAN_SEGURO JOIN SIS_NORMALIZADA.oltp.Sexo x ON x.nombre=l.SEXO JOIN SIS_NORMALIZADA.oltp.Grupo_Edad g ON g.nombre=l.GRUPO_EDAD OPTION(MAXDOP 1,MAX_GRANT_PERCENT=1);
IF @Modo='SQL' BEGIN
 SELECT clave_origen,MAX(version_origen) version INTO #V FROM raw.Registros WHERE id_lote=@Lote GROUP BY clave_origen;
 UPDATE v SET version=n.version,eliminado=CASE WHEN r.operacion='D' THEN 1 ELSE 0 END FROM SIS_NORMALIZADA.oltp.OrigenVersion v JOIN #V n ON n.clave_origen=v.clave_origen JOIN raw.Registros r ON r.id_lote=@Lote AND r.clave_origen=n.clave_origen AND r.version_origen=n.version;
 INSERT SIS_NORMALIZADA.oltp.OrigenVersion SELECT n.clave_origen,n.version,CASE WHEN r.operacion='D' THEN 1 ELSE 0 END FROM #V n JOIN raw.Registros r ON r.id_lote=@Lote AND r.clave_origen=n.clave_origen AND r.version_origen=n.version WHERE NOT EXISTS(SELECT 1 FROM SIS_NORMALIZADA.oltp.OrigenVersion v WHERE v.clave_origen=n.clave_origen);
END;
DROP TABLE #Carga;
