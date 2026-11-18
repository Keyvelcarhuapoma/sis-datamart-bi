IF SCHEMA_ID('dm') IS NULL EXEC('CREATE SCHEMA dm');
IF OBJECT_ID('dm.Dim_Tiempo') IS NULL CREATE TABLE dm.Dim_Tiempo(id_tiempo_sk int IDENTITY PRIMARY KEY,anio int NOT NULL,numero_mes int NOT NULL,mes nvarchar(20) NOT NULL,trimestre int NOT NULL,semestre int NOT NULL,periodo_codigo int NOT NULL UNIQUE,UNIQUE(anio,numero_mes));
IF OBJECT_ID('dm.Dim_IPRESS') IS NULL CREATE TABLE dm.Dim_IPRESS(id_ipress_sk int IDENTITY PRIMARY KEY,id_ipress_oltp int NOT NULL UNIQUE,cod_ipress nvarchar(50) NOT NULL,nombre_ipress nvarchar(400) NOT NULL,nivel_eess nvarchar(50) NOT NULL,ubigeo_distrito nvarchar(20) NOT NULL,distrito nvarchar(150) NOT NULL,provincia nvarchar(150) NOT NULL,region nvarchar(150) NOT NULL,cod_unidad_ejecutora nvarchar(50) NOT NULL,desc_unidad_ejecutora nvarchar(400) NOT NULL,ubigeo_valido bit NOT NULL);
IF OBJECT_ID('dm.Dim_Servicio') IS NULL CREATE TABLE dm.Dim_Servicio(id_servicio_sk int IDENTITY PRIMARY KEY,id_servicio_oltp int NOT NULL UNIQUE,cod_servicio nvarchar(50) NOT NULL,desc_servicio nvarchar(400) NOT NULL);
IF OBJECT_ID('dm.Dim_Seguro') IS NULL CREATE TABLE dm.Dim_Seguro(id_seguro_sk int IDENTITY PRIMARY KEY,id_plan_oltp int NOT NULL UNIQUE,plan_seguro nvarchar(100) NOT NULL);
IF OBJECT_ID('dm.Dim_Demografia') IS NULL CREATE TABLE dm.Dim_Demografia(id_demografia_sk int IDENTITY PRIMARY KEY,sexo nvarchar(50) NOT NULL,grupo_edad nvarchar(100) NOT NULL,UNIQUE(sexo,grupo_edad));
IF OBJECT_ID('dm.Fact_Atenciones') IS NULL CREATE TABLE dm.Fact_Atenciones(
 id_hecho_atencion bigint IDENTITY PRIMARY KEY,
 id_tiempo_sk int NOT NULL REFERENCES dm.Dim_Tiempo(id_tiempo_sk),
 id_ipress_sk int NOT NULL REFERENCES dm.Dim_IPRESS(id_ipress_sk),
 id_servicio_sk int NOT NULL REFERENCES dm.Dim_Servicio(id_servicio_sk),
 id_seguro_sk int NOT NULL REFERENCES dm.Dim_Seguro(id_seguro_sk),
 id_demografia_sk int NOT NULL REFERENCES dm.Dim_Demografia(id_demografia_sk),
 cantidad_atenciones bigint NOT NULL CHECK(cantidad_atenciones>=0),
 filas_origen bigint NOT NULL CHECK(filas_origen>0),id_lote uniqueidentifier NOT NULL,
 UNIQUE(id_tiempo_sk,id_ipress_sk,id_servicio_sk,id_seguro_sk,id_demografia_sk));
IF OBJECT_ID('dm.Publicacion') IS NULL CREATE TABLE dm.Publicacion(id int PRIMARY KEY CHECK(id=1),version bigint NOT NULL,id_lote uniqueidentifier,fecha datetime2 NOT NULL);
IF NOT EXISTS(SELECT 1 FROM dm.Publicacion) INSERT dm.Publicacion VALUES(1,0,NULL,sysdatetime());
