# maven-fuzzy-factory-analysis

## Objetivo
<!-- Una o dos líneas: qué análisis y para quién (portfolio + reclutadores). -->

## Método
Pipeline SQL-céntrico construido con loops agénticos: ejecutar SQL real contra la BDD → leer el resultado/error → corregir. Cada fase = un commit. No codear sin plan acordado (regla anti-abandono); no reiniciar ni cambiar de rumbo sin decisión explícita de Erick. Idea nueva a mitad de camino → clasificar (ahora / backlog / descarte) antes de tocar nada.

Primer paso de cualquier sesión de trabajo: verificar que el MCP de SQL responde con un `list_databases` (mostrará master/tempdb/model/msdb aunque no haya BDD de usuario). Sin esa herramienta el loop no cierra el ciclo.

## Plan por fases
<!-- Esqueleto estándar de la metodología. Ajustar descripciones al dataset; no quitar fases sin decisión explícita. -->

| Fase | Descripción | Criterio de éxito | Estado |
|---|---|---|---|
| 0 | Setup: estructura, git, CLAUDE.md con plan | Repo versionado | Hecho |
| 1 | Ingesta: BDD del proyecto + tabla raw (todo NVARCHAR) + SP importador del/los archivo(s) de data/raw/ (loop ejecutar→corregir) | `COUNT(*)` en raw == filas del archivo (sin truncamiento) | Pendiente |
| 2 | Exploración + calidad de datos: perfilar, VERIFICAR premisas contra la fuente real, fijar reglas de limpieza/ventana temporal, y PROPONER las preguntas de análisis que el dataset soporta | Doc de hallazgos; premisas confirmadas o corregidas; lista de preguntas de análisis (Fase 4) propuesta y aprobada por Erick | Pendiente |
| 3 | Transformación: SPs que limpian/castean y materializan el modelo procesado (estrella ligera: fact + dims) | Tablas core pobladas; conteos cuadran con raw | Pendiente |
| 4 | Análisis: una vista por pregunta de negocio en esquema `analysis`; export a JSON estático | Cada vista responde su pregunta; JSON generados | Pendiente |
| 5 | Diseño de delivery con el skill `/impeccable`: mapeo historia→visual, layout (anti-bloatware) | Brief de visualización aprobado | Pendiente |
| 6 | HTML data-story en docs/ (front-end primario, hosteable en GitHub Pages), construido con `/impeccable` y aplicando el design system de marca; tras el build, correr un audit con `/impeccable` y refinar la página al máximo | Página carga, charts renderizan, usa tokens de marca; auditada y refinada con `/impeccable` | Pendiente |
| 7 | Power BI: modelo + DAX + reporte PBIR + tema derivado de los tokens de marca + captura (capa aditiva) | Reporte abre y renderiza con el theme de marca; captura en powerbi/captures | Pendiente |
| 8 | Landing/repo: README de portfolio + deploy a GitHub Pages | Data-story en vivo accesible por URL | Pendiente |

Regla de corte anti-abandono: las fases 1→6 forman una pieza de portfolio completa y publicable por sí sola. La 7 es aditiva; si baja la energía, parar en 6 con entregable terminado, no a medias.

### Preguntas de análisis (Fase 4)
<!-- Se fijan en Fase 2 y se aprueban ANTES de construir (regla anti-abandono). Origen: (a) preguntas que trae Erick, (b) candidatas derivadas de la exploración cuando el dataset es desconocido (ej. bajado de internet), o (c) mezcla. Listar aquí las acordadas; marcar core vs adicionales. -->

## Backlog (explícitamente diferido)
<!-- Ideas diferidas. Nada se descarta sin registrarse aquí. -->

## Stack
- Motor de datos único: SQL Server, instancia `XTREMUS\DB001` (Windows Auth), vía MCP `sql-mcp-server`.
- Consumo primario: HTML/JS data-story (ECharts vía CDN, sin build; hosteable en GitHub Pages desde /docs).
- Consumo aditivo: Power BI + DAX (PBIR en repo + capturas + publish-to-web manual).
- Versionado: git local desde Fase 0.

## Diseño (marca) — input fijo
El diseño del data-story HTML y del reporte de Power BI DEBE basarse en el design system de marca personal en `D:\Dev\Projects\personal-brand-design`. No inventar paleta, tipografía ni espaciado: derivarlos de los tokens. Fuentes canónicas:
- Spec (referencia humana): `D:\Dev\Projects\personal-brand-design\src\PERSONAL_BRAND_DESIGN.md`.
- Tokens (fuente de verdad): construir con `pnpm build:tokens` en ese repo → `outputs\css\tokens.css` (+ `tokens.dark.css`) para el HTML, y `outputs\json\tokens.flat.json` para derivar el theme JSON de Power BI.
- Assets de marca (monograma): `D:\Dev\Projects\personal-brand-design\src\brand\`.
- Aplicación: copiar/importar los tokens CSS a docs/assets/ del proyecto (no enlazar fuera del repo, para que GitHub Pages sea autocontenido); el theme de Power BI en powerbi/theme/ se deriva de los mismos tokens.

## Datos
<!-- Rellenar tras Fase 1/2. -->
- Fuente(s) canónica(s) (versionadas): `data/raw/<archivo>`. <!-- delimitador, encoding, columnas, formatos (decimal, fecha) --> 
- Importar TODO como NVARCHAR a raw primero; castear en el SP de transformación (Fase 3), no en la carga.
- Calidad (Fase 2): <!-- nulos, duplicados, rangos, PK natural, ventana temporal --> 
- Modelo objetivo (Fase 3): estrella ligera — `fact_<grano>` + `dim_*`.
- Capa de consumo (Fase 4): esquema `analysis`, una vista por historia, exportada a docs/data/*.json.

## Convenciones
- SQL en src/ numerado por orden de ejecución (01_, 02_, ...). Comentarios e identificadores en inglés.
- Una vista analítica = una pregunta de negocio. Calcular desde el fact, no hardcodear.
- Declarar supuestos del analista como hipótesis en los entregables, no como hechos. En proyecciones/forecasts, declarar límites del método (ej. "techo de planificación, no pronóstico").
- **Idioma de los entregables públicos (data-story HTML, reporte Power BI): inglés** — la audiencia de portfolio es internacional (reclutadores). Formato numérico en-US (`62,516` / `3.9%`). Los docs internos (`docs/*.md`) y las conversaciones siguen en español.
