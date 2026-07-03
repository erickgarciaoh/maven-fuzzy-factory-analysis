# Fase 5 — Brief de visualización

Mapeo historia→visual y plan de layout (anti-bloatware) para el data-story HTML de una sola página. Construido con `/impeccable` (register **brand**), derivado de los tokens de marca (ver [`DESIGN.md`](../DESIGN.md)) y de la estrategia en [`PRODUCT.md`](../PRODUCT.md). Entregable a **aprobar por Erick** antes de la Fase 6 (build).

Decisiones de delivery acordadas (2026-07-03): narrativa **scrollytelling guiado** · tema **light + toggle dark** · interactividad **selectiva (anti-bloatware)** · escribir **brief + PRODUCT.md + DESIGN.md**.

> Idioma: este doc interno va en español; los **bloques de copy** son el texto real de la página, en inglés (audiencia internacional). Formato numérico en-US.

---

## 1. Resumen de la pieza

Una página, scroll vertical, que convierte las 4 vistas `analysis` (P4 funnel, P3 A/B, P1 descomposición, P2 economía) en un solo relato: **cómo la tasa de conversión de una juguetería ficticia más que se duplicó en 3 años, y por qué.** El scroll es el motor narrativo; cada acto responde una pregunta y entrega la siguiente. Para reclutadores: el titular y el rigor se captan en <60 s sin tocar un control. Para analistas: el método (window functions, z-test de proporciones, descomposición Oaxaca, margen/refunds) y sus límites quedan explícitos.

## 2. Acción / comprensión primaria

**Que el lector entienda que el crecimiento de CVR 4.14%→8.44% fue mejora real y testeada (no suerte ni cambio de mix de tráfico), y que el analista detrás lo demostró con método honesto.** Todo lo demás es soporte de esa tesis.

## 3. Dirección visual

- **Lane bloqueado por identidad de marca.** Cormorant Garamond (display) + Barlow Thin (métricas) + Barlow (UI) sobre canvas cálido/ink, con un único acento ámbar. `brand.md` marca el serif editorial como reflex-reject para greenfield, pero la marca **ya comprometió** ese lane como identidad → *identity-preservation* gana. No se cuestiona; se aplica con disciplina.
- **Estrategia de color: Restrained** (neutros tintados + un acento ≤10%). Es el default de producto, pero aquí es deliberado: el rigor es la estética; el ámbar es escaso por regla y por eso significa "mira aquí". La saturación la aportan los datos, no el fondo.
- **Tema:** light (canvas) por defecto, toggle a dark (ink) persistido. Ambos derivados de tokens.
- **Referencias ancla** (no categoría, objeto físico): (1) *The Pudding* — data-story scrollytelling donde el gráfico se transforma con el scroll, pero aquí sobrio, sin ilustración; (2) *Stripe* press/annual — restraint tipográfico y métrica thin de autoridad; (3) una **ficha de museo / caption editorial** — serif con voz, etiquetas pequeñas y precisas, mucho aire.
- **Paso de probes visuales: omitido** — el harness no tiene generación de imágenes nativa y el lane ya está fijado por la marca (no hay ambigüedad direccional que explorar).

## 4. Alcance

- **Fidelidad:** production-ready (es portfolio en vivo, no boceto).
- **Amplitud:** una superficie completa (single page, ~6 folds: hero + 4 actos + coda).
- **Interactividad:** shipped-quality, **selectiva**. Scroll = narrativa; controles mínimos dentro de cada acto (toggle device + control de trimestre en el funnel; hover/tooltip en el resto). Sin filtros globales tipo dashboard.
- **Intención de tiempo:** pulir hasta publicable en GitHub Pages.
- **Stack:** HTML/CSS/JS estático, ECharts vía CDN, sin build. Datos desde `docs/data/*.json` (ya generados en Fase 4). Tokens copiados a `docs/assets/`.

## 5. Estrategia de layout y arco narrativo

Scrollytelling guiado como **realce progresivo sobre charts ya renderizados** — el contenido nunca se oculta detrás de una transición (regla dura del skill y de accesibilidad). El scroll resalta, dibuja y pivota; con `reduced-motion` degrada a long-scroll plano con todos los charts en estado final.

Ancho máx. 1280px, columna de lectura ≤720px, densidad `comfortable`, ritmo vertical `space-24` entre actos. Cards **no** son el default: flujo + reglas + whitespace llevan el relato; panel con borde solo para contenido modular (tabla de resultados A/B, fila de KPIs).

| # | Acto (pregunta) | Rol narrativo | Titular |
|---|---|---|---|
| Hero | — | Enganche + tesis | CVR **4.14% → 8.44%** (+104% en 3 años) |
| 01 | **P4 Funnel** | *¿Dónde se cae la gente?* Columna vertebral. | El embudo de 7 pasos y la brecha mobile |
| 02 | **P3 A/B** | *¿Fue suerte? No — se testeó.* Diferenciador. | 4 experimentos reconstruidos, con su z-test |
| 03 | **P1 Descomposición** | *¿Mejora real o mix de tráfico?* | +4.27pp intra-canal vs +0.03pp mix |
| 04 | **P2 Economía** | *¿El crecimiento paga?* | Margen ~61–63% y dónde duelen los refunds |
| Coda | — | Honestidad de método + provenance | Límites, datos sintéticos, link al SQL/repo |

## 6. Mapeo historia→visual por acto

Regla transversal: **un gráfico primario por acto** + a lo sumo una fila de stats de apoyo. Nada redundante. El ámbar marca el *único* dato/serie focal de cada vista.

### Hero
- **Copy:** titular display + subhead de una línea.
  > **How a plush-toy store doubled its conversion rate.**
  > *A three-year teardown of Maven Fuzzy Factory — funnel, experiments, and the economics behind 8.44%.*
- **Visual:** métrica hero `metric-xl` thin: `4.14% → 8.44%` con delta `+104%` (success), y un sparkline/línea CVR trimestral 2012→2015 de fondo, serie única en ámbar. Sin chart-junk.
- **Stats de apoyo (una fila, discreta):** `472,871` sessions · `32,313` orders · `$1.94M` revenue · `~$60` AOV. (De Fase 2, cifras verificadas.)
- **Provenance chip:** "Fictional dataset · SQL Server → star schema → analysis views". Honestidad desde el frame.

### Acto 01 — Funnel de conversión (P4)
- **Fuente:** `funnel_conversion.json` (168 filas: 7 pasos × 2 devices × 12 trimestres).
- **Chart primario:** funnel horizontal de 7 pasos (landing → products → product detail → cart → shipping → billing → thank-you). Barras por paso mostrando % del paso 1 y drop % entre pasos.
- **Controles selectivos:** toggle **Desktop / Mobile** + control de **trimestre** (slider o segmented, default Q4-2014, el pico de la historia).
- **Emphasis:** el relato es "mobile convierte peor". Serie/lectura focal en ámbar; la de contraste en neutro (`data-1` slate o muted). El gap end-to-end **desktop 9.6% vs mobile 3.4%** (Q4-2014) es el datum ámbar.
- **Micro-copy de hallazgo:** "Every quarter, mobile loses buyers fastest at the products step — the funnel's widest leak."
- **Scroll:** los 7 pasos se dibujan en cascada (stagger 40ms) al entrar; el gap desktop/mobile se resalta al llegar. Reduced-motion → estado final directo.
- **Anti-bloatware:** sin tabla de 168 filas; el control temporal reemplaza el volcado. Fallback accesible: tabla del trimestre visible.

### Acto 02 — Tests A/B reconstruidos (P3)
- **Fuente:** `ab_test_results.json` (4 tests, filas `arm` + `result`).
- **Chart primario:** **dot-plot con intervalos de confianza** — por test, CVR de control vs variante con barra de error (95% CI), y anotación del `z` y del lift en pp. Small multiples (4 paneles) o un panel apilado ordenado por |z|.
- **Emphasis honesto:** significativos en color pleno; el **test perdedor lander-4 (−1.47pp, z=−3.23)** se marca con `error`, **no se esconde** — es el gancho de credibilidad para analistas. El no-significativo (home vs lander-1, z=1.49) se muestra atenuado con badge "n.s.".
- **Panel modular de apoyo:** tabla compacta (los 4 tests): ventana, sessions/arm, CVR control/variante, lift pp, z, significancia 95/99, lift anualizado. Aquí sí un panel con borde — es contenido tabular que el analista quiere leer.
- **Copy de encuadre + límite declarado en el frame:**
  > **The growth wasn't luck — it was tested.**
  > *Assignment is inferred from disjoint date windows, not a labeled flag. Reported as reconstruction, with a pooled-variance z-test on each overlap.*
- **Destacar el gran ganador:** billing vs billing-2 **+17.0pp (z=9.84)**, ~$87K de lift anualizado — el experimento que mueve la aguja.

### Acto 03 — Descomposición del crecimiento de CVR (P1)
- **Fuente:** `cvr_decomposition.json` (5 canales + TOTAL; contribuciones intra-canal vs mix-shift).
- **Chart primario:** **waterfall** — baseline CVR 2012 `4.14%` → `+4.27pp` intra-channel → `+0.03pp` mix-shift → CVR 2015 `8.44%`. La barra intra-canal (la respuesta) en ámbar; mix-shift casi nula, en neutro.
- **Chart de apoyo:** contribución intra-canal por canal (barra horizontal ordenada) — **gsearch aporta +3.26pp** de los +4.27pp; el resto reparte. Emphasis en gsearch.
- **Copy + tesis:**
  > **Real improvement, not a traffic-mix illusion.**
  > *A symmetric (Oaxaca) decomposition splits the +4.30pp gain: +4.27pp from within-channel conversion gains, +0.03pp from shifting the channel mix. The site got better at converting — the audience barely changed.*
- **Método declarado:** "Additive Oaxaca-style decomposition by channel_group, 2012 vs 2015."
- **Scroll:** el waterfall se construye barra a barra; al cerrar, mix-shift "desaparece" visualmente para subrayar que es ~0.

### Acto 04 — Economía por canal con margen (P2)
- **Fuente:** `channel_economics.json` (dos grains: `channel` y `product`, por trimestre).
- **Chart primario (grain channel):** revenue trimestral por canal con **margen bruto** — small multiples o área/línea; emphasis en **gsearch** (canal dominante). Margen bruto estable ~61–63%.
- **Chart secundario (grain product):** **tasa de refund por producto/trimestre** (líneas) — el datum ámbar es el **spike de Mr. Fuzzy en 2014-Q3: 10.55%**, contrastado con la regla de Fase 2 (tasa ≠ volumen: Sugar Panda 6.04% es la tasa más alta crónica; Mr. Fuzzy lidera volumen). Separar tasa y volumen visualmente.
- **Copy + límite:**
  > **Growth that pays — with one quarter that stings.**
  > *~62% gross margin, steady across channels. Refund rates stay low except a Q3-2014 spike on the flagship. Economics stop at gross margin — no acquisition cost (CAC/ROAS) exists in this data.*
- **Anti-bloatware:** no repetir el revenue total (ya en el hero); aquí el foco es **margen y refund**, no ventas brutas.

### Coda — Método y provenance
- Bloque final sobrio (sin chart): límites del método en una lista honesta + provenance.
  > **How this was built, and what it can't tell you.** Fictional data with idealized patterns (technique demo, not real-world findings) · A/B assignment inferred from dates · session-scoped attribution (no cross-device) · gross-margin economics only · annualized lifts are planning ceilings, not forecasts.
- Cadena de provenance: `6 CSV → raw NVARCHAR → star schema (core) → analysis views → JSON`. Link al repo / SQL. Monograma EG (top-left nav) y firma.

## 7. Estados clave

| Estado | Qué ve / siente el lector |
|---|---|
| **Default (JS + datos OK)** | Página completa, charts renderizados, scroll realza. Todo legible sin interactuar. |
| **Sin JS / JS falla** | Los charts son el enriquecimiento; el copy, titulares, KPIs y una tabla-fallback por acto siguen presentes (contenido no gateado). La tesis se lee igual. |
| **Reduced-motion** | Long-scroll plano; todos los charts en estado final, sin cascada ni pin. |
| **Fetch de JSON falla** | Mensaje de error a nivel de acto (borde `error`, ícono, "Couldn't load this chart") — no una página rota; el resto del relato sigue. |
| **Mobile 360px** | KPIs 1-up, funnel scroll horizontal dentro de su card (nunca wrap de números), controles como bottom-sheet/segmented, densidad comfortable (touch ≥44px). |
| **Dark** | Superficies ink, borders en vez de shadows, ámbar → `accent-on-dark`, contraste AA reverificado. |

## 8. Modelo de interacción

- **Scroll:** único driver narrativo. Al entrar cada acto: reveal del chart (stagger) + highlight del dato focal. IntersectionObserver, no scroll-jacking pesado; el usuario mantiene control del scroll nativo.
- **Funnel:** toggle device (2 estados) + control de trimestre → recalcula solo ese chart. Transición `medium (250ms)`.
- **Hover en charts:** tooltip oscuro (siempre ink-900), valor `metric-xs` tabular, label uppercase. Touch: tap = tooltip.
- **Theme toggle:** top bar, persiste en `localStorage`, respeta `prefers-color-scheme` en primera carga.
- **Nav:** mínima. Progreso de scroll sutil o índice de actos anclado (opcional, no dashboard). Focus rings ámbar, todo operable por teclado.

## 9. Requisitos de contenido

- **Copy:** los bloques en inglés de §6 son el texto real (titulares, subheads, hallazgos, límites). Tono analyst-to-analyst, sin hype.
- **Números:** todos calculados desde los JSON de Fase 4 (no hardcodear). Verificados contra Fase 2/3. Formato en-US.
- **Assets:** monograma EG (`personal-brand-design/src/brand/`), favicon EG sobre ink. Sin fotografía (sistema anti-fotográfico); la "imagery" son los propios charts + un bloque de SQL real en la coda (`code-lg`, JetBrains Mono) como prueba de provenance.
- **Micro-copy de estados:** mensajes de error/fallback por acto (§7).
- **Rangos reales de datos:** funnel 168 filas; A/B 4 tests; descomposición 6 filas; economía ~90 filas (channel + product × trimestre).

## 10. Referencias de impeccable para la Fase 6 (build)

- `craft` — construir el feature end-to-end desde este brief aprobado.
- `layout.md` — ritmo vertical entre actos, columna de lectura, grid.
- `animate.md` — scrollytelling como realce (no gating), stagger, reduced-motion.
- `typeset.md` — jerarquía display/thin-metric, la voz Cormorant.
- `dataviz` (skill) + `DESIGN.md §Charts` — encoding, paleta emphasis, tooltips.
- `audit.md` + `polish.md` — pase final de a11y/perf/responsive y refinamiento (Fase 6 lo exige).

## 11. Preguntas abiertas (con default asertado)

1. **Índice de actos anclado (mini-nav lateral)** — *Default: incluirlo, sutil, colapsable en mobile.* Ayuda a reclutadores a saltar; no lo convierte en dashboard si se mantiene discreto.
2. **Bloque SQL real en la coda** — *Default: sí,* un fragmento representativo (p. ej. la window function del funnel) como prueba visible de provenance. Refuerza el principio "show the work".
3. **Toggle "tasa vs volumen" en el chart de refunds (Acto 04)** — *Default: no;* mostrar tasa como primario y volumen como stat/anotación. Añadir toggle solo si en el build se ve que un chart no basta.

---

**Criterio de éxito de Fase 5:** este brief aprobado por Erick. Al aprobar, la Fase 6 arranca con `/impeccable craft` sobre este documento.
