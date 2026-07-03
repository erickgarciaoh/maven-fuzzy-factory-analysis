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
| 1 | Ingesta: BDD del proyecto + tabla raw (todo NVARCHAR) + SP importador del/los archivo(s) de data/raw/ (loop ejecutar→corregir) | `COUNT(*)` en raw == filas del archivo (sin truncamiento) | Hecho |
| 2 | Exploración + calidad de datos: perfilar, VERIFICAR premisas contra la fuente real, fijar reglas de limpieza/ventana temporal, y PROPONER las preguntas de análisis que el dataset soporta | Doc de hallazgos; premisas confirmadas o corregidas; lista de preguntas de análisis (Fase 4) propuesta y aprobada por Erick | Hecho |
| 3 | Transformación: SPs que limpian/castean y materializan el modelo procesado (estrella ligera: fact + dims) | Tablas core pobladas; conteos cuadran con raw | Hecho |
| 4 | Análisis: una vista por pregunta de negocio en esquema `analysis`; export a JSON estático | Cada vista responde su pregunta; JSON generados | Pendiente |
| 5 | Diseño de delivery con el skill `/impeccable`: mapeo historia→visual, layout (anti-bloatware) | Brief de visualización aprobado | Pendiente |
| 6 | HTML data-story en docs/ (front-end primario, hosteable en GitHub Pages), construido con `/impeccable` y aplicando el design system de marca; tras el build, correr un audit con `/impeccable` y refinar la página al máximo | Página carga, charts renderizan, usa tokens de marca; auditada y refinada con `/impeccable` | Pendiente |
| 7 | Power BI: modelo + DAX + reporte PBIR + tema derivado de los tokens de marca + captura (capa aditiva) | Reporte abre y renderiza con el theme de marca; captura en powerbi/captures | Pendiente |
| 8 | Landing/repo: README de portfolio + deploy a GitHub Pages | Data-story en vivo accesible por URL | Pendiente |

Regla de corte anti-abandono: las fases 1→6 forman una pieza de portfolio completa y publicable por sí sola. La 7 es aditiva; si baja la energía, parar en 6 con entregable terminado, no a medias.

### Preguntas de análisis (Fase 4)
Fijadas y aprobadas por Erick en Fase 2 (2026-07-03). Detalle y límites de método en [`docs/02_data_quality.md`](docs/02_data_quality.md) §4. **Core** (Fases 3–6, una vista `analysis` + JSON cada una):
1. **P4 — Funnel de conversión multi-paso** por período y device (window functions sobre pageviews). Columna vertebral del data-story.
2. **P3 — Reconstrucción y evaluación de tests A/B** (landers, billing vs billing-2): ventanas disjuntas, asignación inferida por fecha, test z de proporciones + lift anualizado. Diferenciador de portfolio.
3. **P1 — Descomposición del crecimiento de CVR** 2012→2015 (intra-canal vs mix-shift; descomposición aditiva).
4. **P2 — Economía por canal con margen**: sesiones→órdenes→revenue→cogs→refunds por canal/producto; margen bruto y tasa de refund por producto/trimestre.

## Backlog (explícitamente diferido)
- **P5 — Impacto de lanzamientos de producto** (before/after CVR/AOV/mix por launch; matriz de co-compra cross-sell). Diferida de Fase 4 el 2026-07-03; candidata a capa aditiva (Fase 7 Power BI) o a una v2 del data-story.
- **P6 — Retención y valor del usuario** (cohortes de primera sesión, repeat rate, revenue acumulado 30/60/90 días por canal). Diferida de Fase 4 el 2026-07-03; conecta con la metodología LTV del proyecto `patient_revenue_ltv`.

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
- Fuente(s) canónica(s) (versionadas): `data/raw/<archivo>` — 6 CSV (website_sessions, website_pageviews, orders, order_items, order_item_refunds, products) + `maven_fuzzy_factory_data_dictionary.csv`. Delimitador `,`, sin comillas salvo `website_pageviews.csv` (created_at entre `"`). `website_sessions.csv` usa el literal de texto `NULL` en utm_source/campaign/content (83.328 filas, tráfico directo/orgánico) — no vacío.
- Importar TODO como NVARCHAR(4000) a `raw.*` primero; castear en el SP de transformación (Fase 3), no en la carga.
- BULK INSERT en modo nativo (`FIELDTERMINATOR`/`ROWTERMINATOR`), sin `FORMAT='CSV'`+`FIELDQUOTE`: esa combinación rompe el proveedor OLE DB "BULK" (error IID_IColumnsInfo) en esta instancia al leer `website_pageviews.csv`. Consecuencia: `raw.website_pageviews.created_at` llega con comillas dobles literales — limpiar con TRIM/REPLACE al castear en Fase 3.
- Conteos raw verificados == líneas de archivo (sin header): sessions 472.871, pageviews 1.188.124, orders 32.313, order_items 40.025, refunds 1.731, products 4.
- Calidad (Fase 2): verificada contra la carga raw ([`docs/02_data_quality.md`](docs/02_data_quality.md), queries en `src/04_data_profiling.sql`). PKs únicas; 0 huérfanos en 7 FKs; timestamps 100% parseables; ventana 2012-03-19→2015-03-19 (refunds cuelgan hasta 2015-04-01). **Defecto crítico:** `\r` (CHAR(13)) colgando en la ÚLTIMA columna de cada tabla salvo pageviews (rompe casteo numérico de cogs/refund) → strip `REPLACE(col,CHAR(13),'')` + TRIM en Fase 3. `utm_*` literal `'NULL'` en 83.328 sesiones = directo/orgánico (split por http_referer: 39.917 directo / 35.202 org-gsearch / 8.209 org-bsearch). Refund: tasa ≠ volumen (Sugar Panda 6,04% > Mr. Fuzzy 5,11%, pero Mr. Fuzzy lidera volumen). Catálogo: The Original Mr. Fuzzy, The Forever Love Bear, The Birthday Sugar Panda, The Hudson River Mini bear.
- Modelo objetivo (Fase 3): estrella ligera en esquema `core`, poblada por `core.usp_transform_core_model` (`src/05_create_core_tables.sql`, `src/06_sp_transform_core.sql`). Dims: `dim_product`, `dim_website_session` (incluye `channel_group` derivado: `utm_source` si existe, si no directo/orgánico por `http_referer`). Facts: `fact_website_pageview`, `fact_order`, `fact_order_item`, `fact_order_item_refund`. IDs = los del origen (sin IDENTITY). Conteos verificados == raw (472.871 sesiones, 1.188.124 pageviews, 32.313 orders, 40.025 items, 1.731 refunds, 4 productos); 0 nulos en `cogs_usd`/`price_usd` tras strip de `\r`; split de canal exacto a Fase 2 (gsearch 316.035 · bsearch 62.823 · direct 39.917 · org-gsearch 35.202 · socialbook 10.685 · org-bsearch 8.209).
- Capa de consumo (Fase 4): esquema `analysis`, una vista por historia, exportada a docs/data/*.json.

## Convenciones
- SQL en src/ numerado por orden de ejecución (01_, 02_, ...). Comentarios e identificadores en inglés.
- Una vista analítica = una pregunta de negocio. Calcular desde el fact, no hardcodear.
- Declarar supuestos del analista como hipótesis en los entregables, no como hechos. En proyecciones/forecasts, declarar límites del método (ej. "techo de planificación, no pronóstico").
- **Idioma de los entregables públicos (data-story HTML, reporte Power BI): inglés** — la audiencia de portfolio es internacional (reclutadores). Formato numérico en-US (`62,516` / `3.9%`). Los docs internos (`docs/*.md`) y las conversaciones siguen en español.
