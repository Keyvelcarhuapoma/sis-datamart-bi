# Manual básico de usuario

## Preparar el equipo

Sigue primero la instalación del README. Se requieren las tres bases y SSIS 170. La aplicación no instala SQL Server ni SSIS.

## Cargar un archivo

1. Abre `INICIAR.cmd`.
2. Pulsa **Subir snapshot mensual** y selecciona un CSV o Excel de `ejemplos`.
3. Espera la confirmación **PUBLICADO_SQL**. Una recepción no es una publicación confirmada.
4. Si aparece **REQUIERE_REVISION**, abre la evidencia de esa recepción en `operacion` y revisa el lote. No modifiques estados para ocultar errores.

Cada archivo debe contener un snapshot completo de los meses incluidos dentro del ámbito de demostración. Los meses no recibidos se conservan. Un archivo parcial no equivale a un movimiento incremental.

## Probar el incremental

1. En SSMS abre `sql/91_Prueba_Incremental_EndToEnd.sql` conectado a SIS_RAW.
2. Ejecuta el bloque de entrada de la prueba. Utiliza una clave y una versión superior a la recibida para esa clave.
3. En la aplicación pulsa **Publicar cambios SQL**.
4. Espera **PUBLICADO_INCREMENTAL**. **SIN_PENDIENTES** solo indica que no se encontró trabajo en la cola.
5. Ejecuta el bloque de verificación del script para contrastar RAW, normalizada y dimensional. Revisa además el estado del lote.

## Consultar Power BI

Abre `PowerBI/SIS_Final_3BD.pbip`. Usa autenticación Windows contra localhost. El modelo usa DirectQuery, por lo que necesita SQL Server disponible. Un repositorio Git no sustituye a SQL Server ni aloja un dashboard en ejecución.

- Atenciones suma `cantidad_atenciones`; no cuenta personas únicas.
- Períodos publicados cuenta períodos con hechos. Tener registros no acredita completitud.
- Hora de consulta usa NOW(); no indica la última carga completada.
- Los porcentajes de planes y nivel describen el ámbito filtrado. Una tarjeta expresada en millones puede redondear 113 a 0,00 mill.
- Las referencias 80%, 70% y 85% heredadas no tienen acreditación de meta oficial en esta entrega.

## Consultar los Excel

En `excel` están diagnóstico, estrategias y BSC. Las entradas de valoración estratégica son propuestas técnicas justificadas. No se interpretan como mediciones institucionales. El BSC permite seleccionar 2018, 2019 o 2025; conserva los datos de origen como una instantánea.

## Cerrar y revisar

Espera a que termine una carga antes de cerrar la aplicación. Los archivos de operación permanecen locales y están excluidos de Git. El repositorio no incluye una tarea programada instalada automáticamente.
