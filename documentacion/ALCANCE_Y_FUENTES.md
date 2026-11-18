# Alcance, fuentes y límites

## Fuente pública

Datos agregados de atenciones SIS: https://www.datosabiertos.gob.pe/dataset/datos-de-atenciones-realizadas-los-asegurados-sis

Las fuentes masivas se obtienen de su publicador. No se redistribuyen en este repositorio. El contrato de 17 campos y el diccionario se encuentran en `DICCIONARIO_DATOS.json`.

## Cobertura observada en la instalación de origen

Consulta de agregados realizada el 17/11/2026 a las 05:14 UTC. Es una referencia histórica, no el estado de una base recién creada ni una conexión automática.

| Año | Meses con registros | Hechos | Atenciones | Tipo |
|---|---|---:|---:|---|
| 2018 | Enero–abril | 1.000.000 | 9.956.107 | Extracto real |
| 2019 | Enero–febrero | 20.000 | 199.223 | Extracto real |
| 2025 | Julio–diciembre | 20.000 | 192.821 | Extracto real |
| 2026 | 1, 2, 6, 8, 9, 10 y 11 | 9 | 113 | Ensayos sintéticos |

Los períodos y muestras no son equivalentes. No se afirma cobertura nacional completa ni crecimiento anual comparable. En el corte, las tres capas sumaban 25 claves foráneas habilitadas y confiables; el control dimensional no detectó hechos huérfanos. Ese control no prueba exactitud de todo el dato contra padrones oficiales.

## Incidencias y validación

La auditoría del 16/11/2026 documentó un fallo de carga completa 2019 por log transaccional lleno e incidencias de versión incremental. La preparación del repositorio no reejecuta cargas ni certifica esas incidencias como resueltas. Las pruebas deben repetirse en una instalación aislada antes de uso institucional.

El proyecto no mide costos, presupuesto, rentabilidad, cobertura poblacional ni resultados clínicos. Los Excel distinguen juicios estratégicos, metas propuestas y datos observados. Las referencias heredadas de Power BI requieren aprobación funcional y conciliación con las fichas antes de calificarlas como metas oficiales.

## Ejemplos incluidos

Todos los archivos de `ejemplos` son casos controlados de demostración, incluidos los que deben ser rechazados. No se incluyen copias masivas de fuentes reales, cachés del modelo, archivos MDF/LDF, respaldos BAK ni historiales locales de recepciones.
