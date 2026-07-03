# Maven Fuzzy Factory — Exploración

## 1. Contexto y origen
Base relacional de un e-commerce ficticio (peluches) con la instrumentación completa de marketing digital: sesiones web con UTMs, pageviews, órdenes, ítems y reembolsos. Ventana **2012-03-19 → 2015-03-19** (3 años exactos; refunds cuelgan hasta abr-2015). Es el dataset más cercano a una base de producción real del lote: 6 tablas, ~100 MB, 1,66M de eventos.

## 2. Estructura
Modelo relacional verificado (integridad referencial **perfecta: 0 huérfanos** en los 4 FKs):

| Tabla | Filas | Grano | Relación |
|---|---|---|---|
| `website_sessions` | 472.871 | sesión | user_id (394.318 únicos), UTMs, device, referer |
| `website_pageviews` | 1.188.124 | pageview | → sessions (~2,5 pv/sesión) |
| `orders` | 32.313 | orden | → sessions (1:0..1), price/cogs |
| `order_items` | 40.025 | ítem | → orders; flag primary |
| `order_item_refunds` | 1.731 | reembolso | → order_items |
| `products` | 4 | producto | lanzamientos escalonados 2012–2014 |

Hechos clave verificados: revenue $1,94M; CVR sesión→orden sube **4,14% (2012) → 8,44% (2015)**; canales: gsearch 67%, sin-UTM 18% (directo/orgánico), bsearch 13%, socialbook 2%; devices 69/31 desktop/mobile; órdenes de 1 (24.601) o 2 ítems (7.712); repeat sessions 16,6%.

**Los experimentos están en los datos aunque nadie los etiquetó**: `/lander-1..5` y `/billing`→`/billing-2` tienen ventanas de vida disjuntas (p.ej. lander-4 solo feb–abr 2014) — son tests A/B reconstruibles por fechas. Los 4 productos se lanzan escalonados (Mr. Fuzzy 2012 → Love Bear ene-2013 → Sugar Panda dic-2013 → Mini Bear feb-2014).

## 3. Calidad de datos
- Integridad referencial impecable (verificada con anti-joins); PKs únicas.
- `utm_source/campaign/content` nulos en 83.328 sesiones — **estructural**: tráfico no pagado (directo u orgánico); separar por `http_referer` en el pipeline, no imputar.
- `products` sin registro para pedidos previos al lanzamiento (consistente).
- Timestamps completos a segundo; sin duplicados evidentes.
- Único matiz: refunds con fechas posteriores al fin de sesiones (lag natural del proceso de reembolso) — cuidado al cerrar ventanas de análisis.

## 4. Preguntas de negocio (storytelling)
1. **¿De dónde vino la duplicación de la conversión?** CVR 4,1%→8,4% en 3 años. ¿Mejoró el sitio (landers/billing), el mix de canal, el catálogo (4 productos vs 1), o la base de repetidores? Atribuir el delta es LA pregunta.
2. **¿Qué canal compra crecimiento rentable?** gsearch nonbrand domina el volumen, pero ¿convierte y retiene igual que brand? ¿socialbook (piloto) justificó existir? Con cogs disponible: margen por canal, no solo revenue.
3. **¿Los tests A/B pagaron?** Reconstruir el test `/billing` vs `/billing-2` y los landers: ¿el uplift fue real (test de proporciones) y cuánto revenue anual generó cada ganador?
4. **¿Dónde gotea el funnel?** home/lander → products → producto → cart → shipping → billing → thank-you: ¿qué paso pierde más, difiere por device (mobile convierte peor: hipótesis), y mejoró con el tiempo?
5. **¿Cada producto nuevo sumó o canibalizó?** Tras cada lanzamiento: ¿el CVR total sube, el AOV cambia, el producto viejo cae? Cross-sell: ¿qué pares se compran juntos (órdenes de 2 ítems)?
6. **¿El cliente vuelve?** 16,6% de sesiones repetidas: ¿los repetidores convierten más barato (sin CPC de nueva adquisición)? ¿Cuánto vale un usuario a 90 días por canal de origen?

## 5. Análisis de mayor valor (ranqueados)
1. **Funnel de conversión multi-paso por período y device** — secuencia de pageviews por sesión (window functions), tasas de paso, evolución trimestral. Extiende el patrón funnel del proyecto de referencia a un funnel de 6 pasos. Responde P4.
2. **Reconstrucción y evaluación de tests A/B** — detectar ventanas de solapamiento (billing vs billing-2, landers), asignación de sesiones, test z de proporciones + lift de revenue anualizado. Es el diferenciador del portfolio: análisis experimental sin etiquetas, con la honestidad de declarar que la asignación se infiere. Responde P3.
3. **Descomposición del crecimiento de CVR** — mix-shift analysis: cuánto del delta 2012→2015 viene de mejora intra-canal vs cambio de mix de canales/devices/repeat (descomposición aditiva tipo Oaxaca simplificada). Responde P1; técnica de analista senior.
4. **Economía por canal con margen** — sesiones→órdenes→revenue→cogs→refunds por utm_source/campaign; margen bruto por canal y por producto (Mr. Fuzzy tiene refund spike conocido a investigar: tasa de refund por producto/trimestre). Responde P2.
5. **Impacto de lanzamientos de producto** — before/after de cada launch sobre CVR, AOV y mix; matriz de co-compra para cross-sell. Responde P5.
6. **Retención y valor del usuario** — cohortes mensuales de primer sesión, repeat rate y revenue acumulado por usuario a 30/60/90 días por canal. Responde P6; conecta con la metodología LTV del proyecto anterior.

## 6. Recomendación de proyecto
- **Motor**: SQL Server, sin dudarlo — es una base relacional de manual para pipeline raw→estrella (fact_session, fact_pageview, fact_order_item + dims) y todo el análisis vive en T-SQL con window functions. El dataset está diseñado para SQL avanzado (es el curso de SQL de Maven).
- **Consumo**: doble capa como el proyecto de referencia — HTML data-story para el funnel y los A/B; Power BI para el executive dashboard de canales.
- **Perfil que demuestra**: digital/marketing analytics end-to-end — funnels, experimentación, atribución, unit economics. Probablemente la pieza de mayor peso laboral del lote.

## 7. Limitaciones
- Atribución session-scoped: user_id existe pero el journey cross-device no es rastreable (mismo user en mobile y desktop cuenta como usuarios distintos si el id difiere — verificar en pipeline).
- Sin coste de adquisición (no hay spend de campañas): ROI de canal queda en margen bruto, no en CAC/ROAS — declarar el límite.
- Tests A/B inferidos por fechas, no etiquetados: la asignación aleatoria es supuesto no verificable.
- Datos ficticios con patrones idealizados (integridad perfecta, crecimiento suave): excelente para demostrar técnica, no para hallazgos de negocio reales.
