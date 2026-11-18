-- Ejecutar sin cargas activas. No se desconectan clientes con ROLLBACK IMMEDIATE.
IF NOT EXISTS(SELECT 1 FROM sys.databases WHERE name='SIS_DIMENSIONAL' AND is_read_committed_snapshot_on=1)
 ALTER DATABASE SIS_DIMENSIONAL SET READ_COMMITTED_SNAPSHOT ON;
GO
USE SIS_DIMENSIONAL;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dm.Fact_Atenciones') AND name='IX_Informe_Tiempo')
 CREATE INDEX IX_Informe_Tiempo ON dm.Fact_Atenciones(id_tiempo_sk) INCLUDE(cantidad_atenciones,filas_origen);
