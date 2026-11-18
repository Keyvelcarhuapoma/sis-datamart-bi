/* PRUEBA CONTROLADA DE CARGA INCREMENTAL
   1) Ejecutar este bloque en SSMS conectado a SIS_RAW.
   2) En la aplicacion, pulsar "Publicar cambios SQL".
   3) Ejecutar el bloque de verificacion.
   No se escribe directamente en SIS_NORMALIZADA ni SIS_DIMENSIONAL. */

USE SIS_RAW;
GO

DECLARE @Clave nvarchar(100)=N'DEMO-INCREMENTAL-E2E-001';
DECLARE @Version int=(SELECT COALESCE(MAX(version),0)+1 FROM raw.EventosSQL WHERE clave_origen=@Clave);

EXEC raw.InsertarRegistroOrigen
 @ClaveOrigen=@Clave,
 @Version=@Version,
 @Operacion='U',
 @Datos=N'{
 "ANIO":"2026","MES":"10","REGION":"LIMA","PROVINCIA":"LIMA",
 "UBIGEO_DISTRITO":"150101","DISTRITO":"LIMA",
 "COD_UNIDAD_EJECUTORA":"9999","DESC_UNIDAD_EJECUTORA":"UNIDAD DEMO INCREMENTAL",
 "COD_IPRESS":"DEMO990001","IPRESS":"IPRESS DEMO INCREMENTAL","NIVEL_EESS":"I-1",
 "PLAN_SEGURO":"SIS GRATUITO","COD_SERVICIO":"DEMO001","DESC_SERVICIO":"SERVICIO DEMO INCREMENTAL",
 "SEXO":"MASCULINO","GRUPO_EDAD":"18 - 29 AÑOS","ATENCIONES":"13"
 }';

SELECT id_raw,id_lote,clave_origen,version_origen,operacion,estado_proceso
FROM raw.Registros WHERE clave_origen=@Clave ORDER BY id_raw DESC;
GO

/* VERIFICACION: ejecutar despues de pulsar Publicar cambios SQL */
DECLARE @ClaveVerificar nvarchar(100)=N'DEMO-INCREMENTAL-E2E-001';

SELECT 'RAW' AS capa,r.id_raw,r.clave_origen,r.version_origen,r.operacion,r.ANIO,r.MES,r.ATENCIONES,e.estado
FROM SIS_RAW.raw.Registros r
JOIN SIS_RAW.raw.EventosSQL e ON e.id_evento=r.id_evento
WHERE r.clave_origen=@ClaveVerificar;

SELECT 'NORMALIZADA' AS capa,a.clave_origen,a.version_origen,a.anio,a.mes,a.cantidad_atenciones,a.fuente_tipo
FROM SIS_NORMALIZADA.oltp.Registro_Atencion a
WHERE a.clave_origen=@ClaveVerificar;

SELECT 'DIMENSIONAL' AS capa,t.anio,t.numero_mes,i.cod_ipress,s.cod_servicio,d.sexo,d.grupo_edad,f.cantidad_atenciones,f.filas_origen
FROM SIS_DIMENSIONAL.dm.Fact_Atenciones f
JOIN SIS_DIMENSIONAL.dm.Dim_Tiempo t ON t.id_tiempo_sk=f.id_tiempo_sk
JOIN SIS_DIMENSIONAL.dm.Dim_IPRESS i ON i.id_ipress_sk=f.id_ipress_sk
JOIN SIS_DIMENSIONAL.dm.Dim_Servicio s ON s.id_servicio_sk=f.id_servicio_sk
JOIN SIS_DIMENSIONAL.dm.Dim_Demografia d ON d.id_demografia_sk=f.id_demografia_sk
WHERE i.cod_ipress=N'DEMO990001' AND s.cod_servicio=N'DEMO001';

SELECT TOP(5) id_lote,modo,estado,fecha_inicio,fecha_fin,mensaje
FROM SIS_RAW.etl.Lotes
WHERE modo='SQL'
ORDER BY fecha_inicio DESC;
