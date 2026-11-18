USE SIS_RAW;
DECLARE @Version int=(SELECT COALESCE(MAX(version),0)+1 FROM raw.EventosSQL WHERE clave_origen=N'EXPOSICION-SQL-001');
EXEC raw.RecibirCambio @ClaveOrigen=N'EXPOSICION-SQL-001',@Version=@Version,@Operacion='D',@Datos=N'{}';
