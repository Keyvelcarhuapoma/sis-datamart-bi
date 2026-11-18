/* GUIA DE CARGA INCREMENTAL SIS
   La unica puerta de escritura para eventos SQL es SIS_RAW.raw.RecibirCambio.
   No insertar directamente en SIS_NORMALIZADA ni SIS_DIMENSIONAL.
*/

USE SIS_RAW;
GO

/* 1. Alta o correccion: U
      La clave identifica el registro de la fuente; la version debe aumentar. */
DECLARE @ClaveOrigen nvarchar(100)=N'EXPOSICION-SQL-001';
DECLARE @Version int=(SELECT COALESCE(MAX(version),0)+1
                      FROM raw.EventosSQL WHERE clave_origen=@ClaveOrigen);

EXEC raw.RecibirCambio
 @ClaveOrigen=@ClaveOrigen,
 @Version=@Version,
 @Operacion='U',
 @Datos=N'{
  "ANIO":"2026", "MES":"10", "REGION":"APURIMAC", "PROVINCIA":"ANDAHUAYLAS",
  "UBIGEO_DISTRITO":"030203", "DISTRITO":"CHIARA",
  "COD_UNIDAD_EJECUTORA":"0756", "DESC_UNIDAD_EJECUTORA":"SALUD CHANKA",
  "COD_IPRESS":"0000004157", "IPRESS":"CENTRO PRUEBA", "NIVEL_EESS":"I",
  "PLAN_SEGURO":"SIS GRATUITO", "COD_SERVICIO":"001", "DESC_SERVICIO":"CONTROL",
  "SEXO":"MASCULINO", "GRUPO_EDAD":"00 - 04 ANOS", "ATENCIONES":"13"
 }';
GO

/* 2. Seguimiento: debe quedar PENDIENTE y luego PUBLICADO al ejecutar la tarea programada. */
SELECT id_evento,clave_origen,version,operacion,estado,id_lote,recibido
FROM raw.EventosSQL
WHERE clave_origen=N'EXPOSICION-SQL-001'
ORDER BY version DESC;
GO

/* 3. Baja logica: D. No enviar las 17 columnas para una baja. */
DECLARE @ClaveOrigenBaja nvarchar(100)=N'EXPOSICION-SQL-001';
DECLARE @VersionBaja int=(SELECT COALESCE(MAX(version),0)+1
                          FROM raw.EventosSQL WHERE clave_origen=@ClaveOrigenBaja);
EXEC raw.RecibirCambio @ClaveOrigen=@ClaveOrigenBaja,
                        @Version=@VersionBaja,
                        @Operacion='D',@Datos=N'{}';
GO

/* 4. Auditoria de lotes y resultado publicado. */
SELECT TOP (20) id_lote,estado,modo,filas_origen,filas_aceptadas,filas_rechazadas,
       filas_dm,atenciones_dm,fecha_inicio,fecha_fin,mensaje
FROM etl.Lotes
ORDER BY fecha_inicio DESC;
GO

/* 5. Conciliacion del Data Mart. */
SELECT COUNT_BIG(*) AS hechos,SUM(cantidad_atenciones) AS atenciones
FROM SIS_DIMENSIONAL.dm.Fact_Atenciones;
GO
