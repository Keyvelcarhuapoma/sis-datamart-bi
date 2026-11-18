# Preparación de la entrega

- Se conserva el código de la aplicación, scripts SQL y fuentes SSIS de la entrega local.
- Se copian los tres Excel finales sin modificar sus cálculos.
- Se versionan las definiciones PBIP, reporte y modelo. Se excluyen `.pbi`, cachés, PBIX grandes y ajustes personales.
- Se sustituyen rutas del equipo original por rutas relativas en las fuentes copiadas. `Configurar_Proyecto.ps1` adapta la entrada SSIS al directorio del clon.
- `Iniciar.ps1` usa un entorno `.venv` del proyecto en vez de una instalación privada de herramientas de autoría.
- No se instala automatización de Windows, no se ejecutan scripts de configuración de recursos SQL y no se cargan ni borran datos al preparar esta entrega.
- La validación de publicación comprueba sintaxis, integridad de archivos y referencias locales. La validación funcional de SSIS requiere el entorno Windows descrito en el README.

No se declara una licencia nueva sobre datos, marcas o materiales de terceros. Deben respetarse las condiciones de sus publicadores.
