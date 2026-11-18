-- Configuracion aplicada en la instancia local durante las pruebas (no ejecutar por lote):
-- min server memory: de configuracion 0 (runtime informaba 16 MB) a 768 MB.
-- max server memory: de 2147483647 a 1536 MB.
-- Se encontraron esperas SLEEP_BPOOL_STEAL durante las primeras pruebas.
-- Son ajustes globales de instancia; MAXDOP=1 se aplica solo a las tres bases nuevas.
-- Reversion manual a los valores anteriores, si se decide retirar el ajuste:
-- EXEC sp_configure 'show advanced options',1; RECONFIGURE;
-- EXEC sp_configure 'min server memory (MB)',0;
-- EXEC sp_configure 'max server memory (MB)',2147483647; RECONFIGURE;
SELECT name,value,value_in_use FROM sys.configurations WHERE name IN('min server memory (MB)','max server memory (MB)');
