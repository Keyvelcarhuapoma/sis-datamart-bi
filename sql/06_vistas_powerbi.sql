IF SCHEMA_ID('pbi') IS NULL EXEC('CREATE SCHEMA pbi');
GO
CREATE OR ALTER VIEW pbi.[Dim_Demografia] AS SELECT [id_demografia_sk],[sexo],[grupo_edad] FROM dm.[Dim_Demografia];
GO
CREATE OR ALTER VIEW pbi.[Dim_IPRESS] AS SELECT [id_ipress_sk],[cod_ipress],[nombre_ipress],[nivel_eess],[ubigeo_distrito],[distrito],[provincia],[region],[cod_unidad_ejecutora],[desc_unidad_ejecutora],COALESCE(CASE LEFT(ubigeo_distrito,2) WHEN '01' THEN N'AMAZONAS' WHEN '02' THEN N'ANCASH' WHEN '03' THEN N'APURIMAC' WHEN '04' THEN N'AREQUIPA' WHEN '05' THEN N'AYACUCHO' WHEN '06' THEN N'CAJAMARCA' WHEN '07' THEN N'CALLAO' WHEN '08' THEN N'CUSCO' WHEN '09' THEN N'HUANCAVELICA' WHEN '10' THEN N'HUANUCO' WHEN '11' THEN N'ICA' WHEN '12' THEN N'JUNIN' WHEN '13' THEN N'LA LIBERTAD' WHEN '14' THEN N'LAMBAYEQUE' WHEN '15' THEN N'LIMA' WHEN '16' THEN N'LORETO' WHEN '17' THEN N'MADRE DE DIOS' WHEN '18' THEN N'MOQUEGUA' WHEN '19' THEN N'PASCO' WHEN '20' THEN N'PIURA' WHEN '21' THEN N'PUNO' WHEN '22' THEN N'SAN MARTIN' WHEN '23' THEN N'TACNA' WHEN '24' THEN N'TUMBES' WHEN '25' THEN N'UCAYALI' END, CASE WHEN region IN(N'LORETO',N'PUNO',N'LA LIBERTAD',N'CALLAO') THEN region END) AS departamento_mapa FROM dm.[Dim_IPRESS];
GO
CREATE OR ALTER VIEW pbi.[Dim_Seguro] AS SELECT [id_seguro_sk],[plan_seguro] FROM dm.[Dim_Seguro];
GO
CREATE OR ALTER VIEW pbi.[Dim_Servicio] AS SELECT [id_servicio_sk],[cod_servicio],[desc_servicio] FROM dm.[Dim_Servicio];
GO
CREATE OR ALTER VIEW pbi.[Dim_Tiempo] AS SELECT [id_tiempo_sk],[anio],[mes],[numero_mes],[trimestre],[semestre],CONVERT(nvarchar(6),periodo_codigo) AS periodo_codigo,CHOOSE(numero_mes,N'Ene',N'Feb',N'Mar',N'Abr',N'May',N'Jun',N'Jul',N'Ago',N'Sep',N'Oct',N'Nov',N'Dic') AS mes_nombre FROM dm.[Dim_Tiempo];
GO
CREATE OR ALTER VIEW pbi.[Fact_Atenciones] AS SELECT [id_hecho_atencion],[id_tiempo_sk],[id_ipress_sk],[id_servicio_sk],[id_seguro_sk],[id_demografia_sk],[cantidad_atenciones] FROM dm.[Fact_Atenciones];