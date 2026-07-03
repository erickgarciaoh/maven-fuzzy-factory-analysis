# Fase 2 — Exploración y calidad de datos

Verificación de las premisas del scoping (`data/raw/EXPLORATION.md`) contra la carga raw real (`raw.*` en `maven_fuzzy_factory`, instancia `XTREMUS\DB001`). Queries reproducibles en [`src/04_data_profiling.sql`](../src/04_data_profiling.sql). Todo ejecutado en modo lectura sobre la capa NVARCHAR; ningún casteo persistido (eso es Fase 3).

## 1. Premisas confirmadas

Todas las cifras del scoping se confirmaron contra la carga, muchas al dígito:

| Premisa (scoping) | Verificado | Estado |
|---|---|---|
| Ventana temporal 2012-03-19 → 2015-03-19 | sessions/pageviews/orders/items exactamente en ese rango; refunds hasta 2015-04-01 (lag de reembolso) | ✅ |
| Timestamps completos, sin basura | 0 valores no parseables a `datetime2` en las 6 tablas | ✅ |
| PKs únicas | count == distinct en las 6 PKs | ✅ |
| Integridad referencial perfecta | **0 huérfanos en 7 FKs** (incluido `orders→primary_product`, no listado en scoping) | ✅ |
| Usuarios únicos 394.318 | `COUNT(DISTINCT user_id)` = 394.318 (== nº de sesiones nuevas) | ✅ |
| CVR 4,14% → 8,44% | 2012 **4,14** → 2013 6,60 → 2014 7,22 → 2015 **8,44** | ✅ |
| Revenue ≈ $1,94M | $1.938.509,75; AOV ≈ $60 | ✅ |
| Mix de canal 67/18/13/2 | gsearch 66,83 · (no utm) 17,62 · bsearch 13,29 · socialbook 2,26 | ✅ |
| Devices 69/31 | desktop 69,16 · mobile 30,84 | ✅ |
| Repeat sessions 16,6% | 16,61% (78.553 de 472.871) | ✅ |
| Órdenes de 1 o 2 ítems | 1 ítem 76,13% (24.601) · 2 ítems 23,87% (7.712) | ✅ |
| Lanzamientos escalonados | Mr. Fuzzy 2012-03-19 · Love Bear 2013-01-06 · Sugar Panda 2013-12-13 · Mini Bear 2014-02-05 | ✅ |
| UTM nulos estructurales | 83.328 con literal `'NULL'` en source/campaign/content; 0 true-null, 0 vacío | ✅ |

Nombres reales del catálogo (antes desconocidos): **The Original Mr. Fuzzy**, **The Forever Love Bear**, **The Birthday Sugar Panda**, **The Hudson River Mini bear**.

## 2. Correcciones y hallazgos nuevos

### 2.1 CRÍTICO — `\r` colgando en la última columna (contaminación de BULK INSERT)
El importador de Fase 1 usó `ROWTERMINATOR='\n'` sobre archivos con saltos CRLF (`\r\n`). Resultado: **la última columna de cada fila arrastra un `CHAR(13)`** literal. Alcance verificado:

| Tabla | Última columna | Filas con `\r` |
|---|---|---|
| `orders` | `cogs_usd` | 32.313 / 32.313 (100%) |
| `order_items` | `cogs_usd` | 40.025 / 40.025 (100%) |
| `order_item_refunds` | `refund_amount_usd` | 1.731 / 1.731 (100%) |
| `website_sessions` | `http_referer` | 472.871 / 472.871 (100%) |
| `products` | `product_name` | 4 / 4 (100%) |
| `website_pageviews` | `pageview_url` | 0 (carga con terminador distinto) |

Impacto directo: `TRY_CONVERT(decimal, cogs_usd)` devuelve NULL en el 100% de las filas (el `\r` invalida el casteo numérico). El scoping declaró "integridad impecable" pero **no perfiló este defecto** — el análisis de margen (`cogs`) habría fallado en silencio.

**Regla Fase 3:** `REPLACE(col, CHAR(13), '')` + `TRIM` defensivo sobre toda columna de texto antes de castear. `pageviews` no tiene `\r` pero sí comillas dobles en `created_at` (ya conocido) → `REPLACE(created_at,'"','')`.

### 2.2 Refund: separar tasa de volumen (corrige el énfasis del scoping)
El scoping señalaba el "refund spike conocido de Mr. Fuzzy". En volumen es cierto (1.237 refunds, $61.838), pero **la tasa más alta es de Sugar Panda (6,04%)**, no de Mr. Fuzzy (5,11%):

| Producto | Ítems vendidos | Refunds | Tasa | $ reembolsado |
|---|---|---|---|---|
| The Original Mr. Fuzzy | 24.226 | 1.237 | 5,11% | $61.837,63 |
| The Birthday Sugar Panda | 4.985 | 301 | **6,04%** | $13.842,99 |
| The Forever Love Bear | 5.796 | 129 | 2,23% | $7.738,71 |
| The Hudson River Mini bear | 5.018 | 64 | 1,28% | $1.919,36 |

En Fase 4, el análisis de refunds debe reportar **tasa y volumen por separado**, y perfilar el spike de Mr. Fuzzy por trimestre (probablemente concentrado, no crónico).

### 2.3 Split directo vs orgánico — cuantificado
Las 83.328 sesiones sin UTM se separan por `http_referer` (tras quitar `\r`):

| Origen | `http_referer` | Sesiones |
|---|---|---|
| Directo | `NULL` (literal) | 39.917 |
| Orgánico gsearch | `https://www.gsearch.com` | 35.202 |
| Orgánico bsearch | `https://www.bsearch.com` | 8.209 |

Confirma la premisa del scoping ("separar por http_referer, no imputar") y le pone números. `http_referer` nunca es true-NULL: usa el literal `'NULL'` para el tráfico directo.

## 3. Reglas de limpieza y ventana (input para Fase 3)

- **Strip `\r`**: `REPLACE(<col>, CHAR(13), '')` en la última columna de cada tabla (todas menos pageviews). Por robustez, aplicar a toda columna NVARCHAR.
- **Strip comillas**: `REPLACE(created_at, '"', '')` en `website_pageviews` antes de `TRY_CONVERT(datetime2, …)`.
- **Casteos**: ids → `INT`; `created_at` → `DATETIME2`; `price_usd`/`cogs_usd`/`refund_amount_usd` → `DECIMAL(18,4)` (usar `DECIMAL(10,2)` sirve, pero 18,4 da margen); flags `is_repeat_session`/`is_primary_item`/`items_purchased` → `INT`.
- **`utm_*` literal `'NULL'`** → mapear a `NULL` real (o a etiqueta de canal derivada) en la dim de marketing; no imputar. Derivar canal: `utm_source` pagado, o directo/orgánico según `http_referer` cuando no hay UTM.
- **Ventana de análisis**: acotar a `2012-03-19` → `2015-03-19` para sessions/pageviews/orders. Los refunds de fechas posteriores (hasta 2015-04-01) son válidos pero cuelgan fuera de la ventana de sesiones: al calcular tasas de refund por período, anclar el refund a la fecha de la **orden**, no a la del reembolso.
- **Cross-device**: `user_id` es session-scoped; el mismo humano en dos devices puede tener ids distintos. Declarar el límite; no deduplicar usuarios cross-device.

## 4. Preguntas de análisis propuestas (Fase 4) — pendientes de aprobación

Heredadas del scoping (`EXPLORATION.md` §4–5), ahora respaldadas por datos verificados. Cada una = una vista en esquema `analysis` + un JSON en `docs/data/`. Ranqueadas por valor de portfolio:

1. **Funnel de conversión multi-paso por período y device** — secuencia de pageviews por sesión (window functions), tasa de paso home/lander→products→producto→cart→shipping→billing→thank-you; evolución trimestral; hipótesis mobile convierte peor. *(P4)*
2. **Reconstrucción y evaluación de tests A/B** — detectar ventanas disjuntas de `/lander-1..5` y `/billing`→`/billing-2`, inferir asignación por fecha, test z de proporciones + lift de revenue anualizado. Diferenciador del portfolio; declarar que la asignación es inferida. *(P3)*
3. **Descomposición del crecimiento de CVR 2012→2015** — cuánto del delta viene de mejora intra-canal vs cambio de mix (canal/device/repeat); descomposición aditiva tipo Oaxaca simplificada. *(P1)*
4. **Economía por canal con margen** — sesiones→órdenes→revenue→cogs→refunds por `utm_source`/campaña; margen bruto por canal y producto; tasa de refund por producto/trimestre. *(P2)*
5. **Impacto de lanzamientos de producto** — before/after de cada launch sobre CVR, AOV y mix; matriz de co-compra (órdenes de 2 ítems) para cross-sell. *(P5)*
6. **Retención y valor del usuario** — cohortes mensuales de primera sesión, repeat rate y revenue acumulado a 30/60/90 días por canal de origen. *(P6)*

**Límites del método a declarar en los entregables:** sin coste de adquisición (ROI queda en margen bruto, no CAC/ROAS); tests A/B inferidos por fecha, no etiquetados; atribución session-scoped; datos ficticios con patrones idealizados (técnica demostrable, no hallazgos de negocio reales).
