USE SIS_RAW;
-- Alta/correccion: identificador estable de la fuente, version creciente.
DECLARE @Version int=(SELECT COALESCE(MAX(version),0)+1 FROM raw.EventosSQL WHERE clave_origen=N'EXPOSICION-SQL-001');
EXEC raw.RecibirCambio @ClaveOrigen=N'EXPOSICION-SQL-001',@Version=@Version,@Operacion='U',@Datos=N'{"MES": "10", "REGION": "APURÍMAC", "PROVINCIA": "ANDAHUAYLAS", "UBIGEO_DISTRITO": "030203", "DISTRITO": "CHIARA", "COD_UNIDAD_EJECUTORA": "0756", "DESC_UNIDAD_EJECUTORA": "REGION APURIMAC - SALUD CHANKA", "COD_IPRESS": "0000004157", "IPRESS": "CENTRO DE PRUEBA ÑANDÚ", "NIVEL_EESS": "I", "PLAN_SEGURO": "SIS GRATUITO", "COD_SERVICIO": "001", "DESC_SERVICIO": "CONTROL SINTÉTICO, NIÑEZ", "SEXO": "MASCULINO", "GRUPO_EDAD": "00 - 04 AÑOS", "ATENCIONES": "13", "ANIO": "2026"}';
-- La tarea Windows procesa automaticamente la cola. No hay que lanzar SSIS a mano.
SELECT * FROM raw.EventosSQL WHERE clave_origen=N'EXPOSICION-SQL-001';
