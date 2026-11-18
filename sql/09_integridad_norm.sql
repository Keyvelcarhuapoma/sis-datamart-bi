IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE name='CK_Registro_Fuente')
 ALTER TABLE oltp.Registro_Atencion WITH CHECK ADD CONSTRAINT CK_Registro_Fuente CHECK(fuente_tipo IN('SNAPSHOT','SQL'));
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE name='CK_Registro_IdentidadOrigen')
 ALTER TABLE oltp.Registro_Atencion WITH CHECK ADD CONSTRAINT CK_Registro_IdentidadOrigen CHECK(
 (fuente_tipo='SQL' AND clave_origen IS NOT NULL AND version_origen IS NOT NULL AND version_origen>0)
 OR(fuente_tipo='SNAPSHOT' AND clave_origen IS NULL AND version_origen IS NULL));
