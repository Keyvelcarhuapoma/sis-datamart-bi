IF SCHEMA_ID('etl') IS NULL EXEC('CREATE SCHEMA etl');
IF SCHEMA_ID('raw') IS NULL EXEC('CREATE SCHEMA raw');
IF SCHEMA_ID('stg') IS NULL EXEC('CREATE SCHEMA stg');
IF OBJECT_ID('etl.Proyecto') IS NULL CREATE TABLE etl.Proyecto(id int PRIMARY KEY,nombre varchar(80));
IF NOT EXISTS(SELECT 1 FROM etl.Proyecto) INSERT etl.Proyecto VALUES(1,'SIS-3BD-v1');
IF OBJECT_ID('etl.Lotes') IS NULL CREATE TABLE etl.Lotes(id_lote uniqueidentifier PRIMARY KEY,modo varchar(20) NOT NULL,estado varchar(40) NOT NULL,archivo nvarchar(1000),fecha_inicio datetime2 NOT NULL DEFAULT sysdatetime(),fecha_fin datetime2,filas_origen bigint,filas_aceptadas bigint,filas_rechazadas bigint,filas_dm bigint,atenciones_dm bigint,mensaje nvarchar(2000));
IF OBJECT_ID('etl.Rechazos') IS NULL CREATE TABLE etl.Rechazos(id_lote uniqueidentifier NOT NULL REFERENCES etl.Lotes(id_lote),archivo nvarchar(260),fila_archivo bigint,motivo nvarchar(1000),anio_original nvarchar(1000),mes_original nvarchar(1000),atenciones_original nvarchar(1000));
IF OBJECT_ID('etl.Validaciones') IS NULL CREATE TABLE etl.Validaciones(id_lote uniqueidentifier NOT NULL REFERENCES etl.Lotes(id_lote),control varchar(100),esperado bigint,obtenido bigint,cumple bit,fecha datetime2 NOT NULL DEFAULT sysdatetime());
IF OBJECT_ID('etl.Errores') IS NULL CREATE TABLE etl.Errores(id_error bigint IDENTITY PRIMARY KEY,id_lote uniqueidentifier NOT NULL REFERENCES etl.Lotes(id_lote),mensaje nvarchar(2000),fecha datetime2 NOT NULL DEFAULT sysdatetime());
IF OBJECT_ID('etl.AniosPermitidos') IS NULL CREATE TABLE etl.AniosPermitidos(anio int PRIMARY KEY CHECK(anio BETWEEN 1900 AND 2100));
IF NOT EXISTS(SELECT 1 FROM etl.AniosPermitidos) INSERT etl.AniosPermitidos SELECT value FROM GENERATE_SERIES(2018,2026);

IF OBJECT_ID('stg.Entrada') IS NULL CREATE TABLE stg.Entrada(fila_archivo bigint IDENTITY PRIMARY KEY,[ANIO] nvarchar(1000) NULL,[MES] nvarchar(1000) NULL,[REGION] nvarchar(1000) NULL,[PROVINCIA] nvarchar(1000) NULL,[UBIGEO_DISTRITO] nvarchar(1000) NULL,[DISTRITO] nvarchar(1000) NULL,[COD_UNIDAD_EJECUTORA] nvarchar(1000) NULL,[DESC_UNIDAD_EJECUTORA] nvarchar(1000) NULL,[COD_IPRESS] nvarchar(1000) NULL,[IPRESS] nvarchar(1000) NULL,[NIVEL_EESS] nvarchar(1000) NULL,[PLAN_SEGURO] nvarchar(1000) NULL,[COD_SERVICIO] nvarchar(1000) NULL,[DESC_SERVICIO] nvarchar(1000) NULL,[SEXO] nvarchar(1000) NULL,[GRUPO_EDAD] nvarchar(1000) NULL,[ATENCIONES] nvarchar(1000) NULL);
IF OBJECT_ID('raw.Registros') IS NULL CREATE TABLE raw.Registros(id_raw bigint IDENTITY PRIMARY KEY,id_lote uniqueidentifier NOT NULL REFERENCES etl.Lotes(id_lote),fila_origen bigint NOT NULL,fuente_tipo varchar(10) NOT NULL,clave_origen nvarchar(100),version_origen int,operacion char(1) NOT NULL DEFAULT 'U',id_evento bigint,[ANIO] nvarchar(1000) NULL,[MES] nvarchar(1000) NULL,[REGION] nvarchar(1000) NULL,[PROVINCIA] nvarchar(1000) NULL,[UBIGEO_DISTRITO] nvarchar(1000) NULL,[DISTRITO] nvarchar(1000) NULL,[COD_UNIDAD_EJECUTORA] nvarchar(1000) NULL,[DESC_UNIDAD_EJECUTORA] nvarchar(1000) NULL,[COD_IPRESS] nvarchar(1000) NULL,[IPRESS] nvarchar(1000) NULL,[NIVEL_EESS] nvarchar(1000) NULL,[PLAN_SEGURO] nvarchar(1000) NULL,[COD_SERVICIO] nvarchar(1000) NULL,[DESC_SERVICIO] nvarchar(1000) NULL,[SEXO] nvarchar(1000) NULL,[GRUPO_EDAD] nvarchar(1000) NULL,[ATENCIONES] nvarchar(1000) NULL);
IF COL_LENGTH('raw.Registros','estado_proceso') IS NULL ALTER TABLE raw.Registros ADD estado_proceso varchar(20) NULL;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('raw.Registros') AND name='IX_Raw_Lote') CREATE INDEX IX_Raw_Lote ON raw.Registros(id_lote,id_raw);
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('raw.Registros') AND name='IX_Raw_IncrementalPendiente') CREATE INDEX IX_Raw_IncrementalPendiente ON raw.Registros(estado_proceso,id_lote,id_raw) INCLUDE(clave_origen,version_origen,operacion);
IF OBJECT_ID('raw.EventosSQL') IS NULL CREATE TABLE raw.EventosSQL(id_evento bigint IDENTITY PRIMARY KEY,clave_origen nvarchar(100) NOT NULL,version int NOT NULL CHECK(version>0),operacion char(1) NOT NULL CHECK(operacion IN('U','D')),datos nvarchar(max) NOT NULL CHECK(ISJSON(datos)=1),estado varchar(20) NOT NULL DEFAULT 'PENDIENTE',id_lote uniqueidentifier NULL REFERENCES etl.Lotes(id_lote),recibido datetime2 NOT NULL DEFAULT sysdatetime(),UNIQUE(clave_origen,version));
IF OBJECT_ID('stg.Limpia') IS NULL CREATE TABLE stg.Limpia(archivo nvarchar(260) NOT NULL,fila_archivo bigint NOT NULL,id_raw bigint NOT NULL,clave_origen nvarchar(100),version_origen int,ANIO int NOT NULL,MES int NOT NULL,[REGION] nvarchar(400) NOT NULL,[PROVINCIA] nvarchar(400) NOT NULL,[UBIGEO_DISTRITO] nvarchar(400) NOT NULL,[DISTRITO] nvarchar(400) NOT NULL,[COD_UNIDAD_EJECUTORA] nvarchar(400) NOT NULL,[DESC_UNIDAD_EJECUTORA] nvarchar(400) NOT NULL,[COD_IPRESS] nvarchar(400) NOT NULL,[IPRESS] nvarchar(400) NOT NULL,[NIVEL_EESS] nvarchar(400) NOT NULL,[PLAN_SEGURO] nvarchar(400) NOT NULL,[COD_SERVICIO] nvarchar(400) NOT NULL,[DESC_SERVICIO] nvarchar(400) NOT NULL,[SEXO] nvarchar(400) NOT NULL,[GRUPO_EDAD] nvarchar(400) NOT NULL,ATENCIONES bigint NOT NULL,ubigeo_valido bit NOT NULL,clave_ipress binary(32) NOT NULL,clave_servicio binary(32) NOT NULL,clave_unidad binary(32) NOT NULL);
SET NOCOUNT ON;
IF COL_LENGTH('stg.Limpia','huella_fila') IS NULL ALTER TABLE stg.Limpia ADD huella_fila binary(32) NULL;
IF OBJECT_ID('etl.Particiones') IS NULL
 CREATE TABLE etl.Particiones(periodo int PRIMARY KEY,huella binary(32) NOT NULL,filas bigint NOT NULL,atenciones bigint NOT NULL,version int NOT NULL,id_lote uniqueidentifier NOT NULL,actualizado datetime2 NOT NULL DEFAULT sysdatetime());
IF OBJECT_ID('etl.PlanParticion') IS NULL
 CREATE TABLE etl.PlanParticion(id_lote uniqueidentifier NOT NULL,periodo int NOT NULL,huella binary(32) NOT NULL,filas bigint NOT NULL,atenciones bigint NOT NULL,accion varchar(20) NOT NULL,filas_anteriores bigint NOT NULL,version_anterior int NOT NULL,PRIMARY KEY(id_lote,periodo));
IF OBJECT_ID('etl.Publicaciones') IS NULL
 CREATE TABLE etl.Publicaciones(id_lote uniqueidentifier NOT NULL,periodo int NOT NULL,version int NOT NULL,huella binary(32) NOT NULL,filas_retiradas bigint NOT NULL,filas_insertadas bigint NOT NULL,atenciones bigint NOT NULL,fecha datetime2 NOT NULL DEFAULT sysdatetime(),PRIMARY KEY(id_lote,periodo));
IF OBJECT_ID('etl.Errores') IS NULL
 CREATE TABLE etl.Errores(id_error bigint IDENTITY PRIMARY KEY,id_lote uniqueidentifier NOT NULL,mensaje nvarchar(2000) NOT NULL,fecha datetime2 NOT NULL DEFAULT sysdatetime());
IF OBJECT_ID('etl.ConfigIncremental') IS NULL
 BEGIN CREATE TABLE etl.ConfigIncremental(id int PRIMARY KEY CHECK(id=1),ambito varchar(60) NOT NULL); INSERT etl.ConfigIncremental VALUES(1,'SIS_DEMOSTRACION'); END;


IF OBJECT_ID('etl.Afectados') IS NULL CREATE TABLE etl.Afectados(id_lote uniqueidentifier NOT NULL REFERENCES etl.Lotes(id_lote),periodo int NOT NULL,PRIMARY KEY(id_lote,periodo));


IF OBJECT_ID('stg.ErroresLectura') IS NULL CREATE TABLE stg.ErroresLectura(id_error bigint IDENTITY PRIMARY KEY,ErrorCode int NOT NULL,ErrorColumn int NOT NULL);

IF OBJECT_ID('etl.Archivos') IS NULL CREATE TABLE etl.Archivos(id_lote uniqueidentifier PRIMARY KEY REFERENCES etl.Lotes(id_lote),ruta nvarchar(1000) NOT NULL,sha256 char(64) NOT NULL,bytes bigint NOT NULL,codepage int NOT NULL,recibido datetime2 NOT NULL DEFAULT sysdatetime());

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('raw.EventosSQL') AND name='IX_Eventos_Pendientes') CREATE INDEX IX_Eventos_Pendientes ON raw.EventosSQL(estado,id_evento) INCLUDE(clave_origen,version,operacion);


