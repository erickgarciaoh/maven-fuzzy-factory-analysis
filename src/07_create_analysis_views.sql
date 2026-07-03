-- Fase 4: capa de consumo. Esquema analysis, una vista por pregunta de negocio
-- (P4 funnel, P3 A/B tests, P1 descomposicion CVR, P2 economia por canal).
-- Metodo y limites documentados en cada vista; ver docs/02_data_quality.md #4.
USE maven_fuzzy_factory;
GO

IF SCHEMA_ID(N'analysis') IS NULL
    EXEC('CREATE SCHEMA analysis');
GO

IF OBJECT_ID(N'analysis.vw_funnel_conversion', 'V') IS NOT NULL DROP VIEW analysis.vw_funnel_conversion;
IF OBJECT_ID(N'analysis.vw_ab_test_results', 'V') IS NOT NULL DROP VIEW analysis.vw_ab_test_results;
IF OBJECT_ID(N'analysis.vw_cvr_decomposition', 'V') IS NOT NULL DROP VIEW analysis.vw_cvr_decomposition;
IF OBJECT_ID(N'analysis.vw_channel_economics', 'V') IS NOT NULL DROP VIEW analysis.vw_channel_economics;
GO

-- =====================================================================
-- P4 -- Multi-step conversion funnel by quarter and device.
-- Steps derived from the 16 distinct pageview_url values (landing pages
-- collapse home + 5 landers; product detail collapses the 4 catalog URLs).
-- =====================================================================
CREATE VIEW analysis.vw_funnel_conversion AS
WITH session_flags AS (
    SELECT
        ds.website_session_id,
        ds.device_type,
        DATEADD(quarter, DATEDIFF(quarter, 0, ds.created_at), 0) AS quarter_start,
        MAX(CASE WHEN pv.pageview_url IN ('/home','/lander-1','/lander-2','/lander-3','/lander-4','/lander-5') THEN 1 ELSE 0 END) AS reached_landing,
        MAX(CASE WHEN pv.pageview_url = '/products' THEN 1 ELSE 0 END) AS reached_products,
        MAX(CASE WHEN pv.pageview_url IN ('/the-original-mr-fuzzy','/the-forever-love-bear','/the-birthday-sugar-panda','/the-hudson-river-mini-bear') THEN 1 ELSE 0 END) AS reached_product_detail,
        MAX(CASE WHEN pv.pageview_url = '/cart' THEN 1 ELSE 0 END) AS reached_cart,
        MAX(CASE WHEN pv.pageview_url = '/shipping' THEN 1 ELSE 0 END) AS reached_shipping,
        MAX(CASE WHEN pv.pageview_url IN ('/billing','/billing-2') THEN 1 ELSE 0 END) AS reached_billing,
        MAX(CASE WHEN pv.pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END) AS reached_thankyou
    FROM core.dim_website_session ds
    JOIN core.fact_website_pageview pv ON pv.website_session_id = ds.website_session_id
    GROUP BY ds.website_session_id, ds.device_type, DATEADD(quarter, DATEDIFF(quarter, 0, ds.created_at), 0)
),
funnel_steps AS (
    SELECT quarter_start, device_type, 1 AS step_order, N'01_landing'        AS step_name, SUM(reached_landing)        AS sessions_reached, COUNT(*) AS sessions_in_quarter FROM session_flags GROUP BY quarter_start, device_type
    UNION ALL
    SELECT quarter_start, device_type, 2, N'02_products_page',  SUM(reached_products),       COUNT(*) FROM session_flags GROUP BY quarter_start, device_type
    UNION ALL
    SELECT quarter_start, device_type, 3, N'03_product_detail', SUM(reached_product_detail), COUNT(*) FROM session_flags GROUP BY quarter_start, device_type
    UNION ALL
    SELECT quarter_start, device_type, 4, N'04_cart',           SUM(reached_cart),           COUNT(*) FROM session_flags GROUP BY quarter_start, device_type
    UNION ALL
    SELECT quarter_start, device_type, 5, N'05_shipping',       SUM(reached_shipping),       COUNT(*) FROM session_flags GROUP BY quarter_start, device_type
    UNION ALL
    SELECT quarter_start, device_type, 6, N'06_billing',        SUM(reached_billing),        COUNT(*) FROM session_flags GROUP BY quarter_start, device_type
    UNION ALL
    SELECT quarter_start, device_type, 7, N'07_thank_you',      SUM(reached_thankyou),       COUNT(*) FROM session_flags GROUP BY quarter_start, device_type
)
SELECT
    quarter_start,
    device_type,
    step_order,
    step_name,
    sessions_reached,
    sessions_in_quarter,
    CAST(sessions_reached AS DECIMAL(18,6)) / NULLIF(FIRST_VALUE(sessions_reached) OVER (PARTITION BY quarter_start, device_type ORDER BY step_order), 0) AS pct_of_step1,
    CAST(sessions_reached AS DECIMAL(18,6)) / NULLIF(LAG(sessions_reached) OVER (PARTITION BY quarter_start, device_type ORDER BY step_order), 0) AS pct_of_prev_step
FROM funnel_steps;
GO

-- =====================================================================
-- P3 -- Reconstructed A/B tests. Assignment is INFERRED from concurrent
-- traffic windows per pageview_url, not from a labeled experiment flag
-- (declare this limit downstream). Four genuine overlap windows found by
-- profiling entry-page mix over time (see chat/session log for the
-- month-by-month checks); all other lander transitions were instant
-- cutovers (no concurrent control) and are excluded as non-tests:
--   1. home vs lander-1      : gsearch/nonbrand, both devices, 2012-06-19..2012-07-29
--   2. lander-2 vs lander-4  : gsearch/nonbrand, desktop only,  2014-02-02..2014-04-19
--   3. lander-2 vs lander-5  : gsearch/nonbrand, desktop only,  2014-08-02..2014-10-31 (excludes the Nov-2014 rollout ramp)
--   4. billing vs billing-2 : all channels,      2012-09-10..2013-01-05
-- Significance uses a two-proportion z-test with pooled variance;
-- flagged at |z|>=1.96 (95%) and |z|>=2.576 (99%), no exact p-value.
-- Annualized lift extrapolates the TEST WINDOW's own daily session rate
-- to 365 days -- ignores seasonality, a stated method limit.
-- =====================================================================
CREATE VIEW analysis.vw_ab_test_results AS
WITH test_config AS (
    SELECT
        test_name, scope_channel, scope_campaign, scope_device, control_url, variant_url,
        CAST(window_start AS DATE) AS window_start, CAST(window_end AS DATE) AS window_end
    FROM (VALUES
        ('home_vs_lander1',           'gsearch', 'nonbrand', NULL,      '/home',     '/lander-1', '2012-06-19', '2012-07-29'),
        ('lander2_vs_lander4_desktop','gsearch', 'nonbrand', 'desktop', '/lander-2', '/lander-4', '2014-02-02', '2014-04-19'),
        ('lander2_vs_lander5_desktop','gsearch', 'nonbrand', 'desktop', '/lander-2', '/lander-5', '2014-08-02', '2014-10-31'),
        ('billing_vs_billing2',       NULL,      NULL,       NULL,      '/billing',  '/billing-2','2012-09-10', '2013-01-05')
    ) AS t(test_name, scope_channel, scope_campaign, scope_device, control_url, variant_url, window_start, window_end)
),
session_arm AS (
    SELECT
        tc.test_name, tc.window_start, tc.window_end, ds.website_session_id,
        CASE
            WHEN SUM(CASE WHEN pv.pageview_url = tc.control_url THEN 1 ELSE 0 END) > 0
             AND SUM(CASE WHEN pv.pageview_url = tc.variant_url THEN 1 ELSE 0 END) > 0 THEN NULL
            WHEN SUM(CASE WHEN pv.pageview_url = tc.control_url THEN 1 ELSE 0 END) > 0 THEN 'control'
            WHEN SUM(CASE WHEN pv.pageview_url = tc.variant_url THEN 1 ELSE 0 END) > 0 THEN 'variant'
        END AS arm
    FROM test_config tc
    JOIN core.dim_website_session ds
        ON ds.created_at >= CAST(tc.window_start AS DATETIME2)
       AND ds.created_at <  DATEADD(day, 1, CAST(tc.window_end AS DATETIME2))
       AND (tc.scope_channel  IS NULL OR ds.channel_group = tc.scope_channel)
       AND (tc.scope_campaign IS NULL OR ds.utm_campaign  = tc.scope_campaign)
       AND (tc.scope_device   IS NULL OR ds.device_type   = tc.scope_device)
    JOIN core.fact_website_pageview pv
        ON pv.website_session_id = ds.website_session_id
       AND pv.pageview_url IN (tc.control_url, tc.variant_url)
    GROUP BY tc.test_name, tc.window_start, tc.window_end, ds.website_session_id
),
arm_metrics AS (
    SELECT
        sa.test_name, sa.arm, sa.window_start, sa.window_end,
        COUNT(*) AS sessions,
        COUNT(fo.order_id) AS orders,
        SUM(ISNULL(fo.price_usd, 0)) AS revenue_usd
    FROM session_arm sa
    LEFT JOIN core.fact_order fo ON fo.website_session_id = sa.website_session_id
    WHERE sa.arm IS NOT NULL
    GROUP BY sa.test_name, sa.arm, sa.window_start, sa.window_end
),
arm_calc AS (
    SELECT
        test_name, arm, window_start, window_end, sessions, orders, revenue_usd,
        CAST(orders AS DECIMAL(18,6)) / NULLIF(sessions, 0) AS cvr,
        CAST(revenue_usd AS DECIMAL(18,4)) / NULLIF(orders, 0) AS aov_usd
    FROM arm_metrics
)
SELECT
    test_name, N'arm' AS row_type, arm, window_start, window_end,
    sessions, orders, cvr, aov_usd,
    CAST(NULL AS DECIMAL(18,6)) AS control_cvr, CAST(NULL AS DECIMAL(18,6)) AS variant_cvr,
    CAST(NULL AS DECIMAL(18,6)) AS lift_pp, CAST(NULL AS DECIMAL(18,6)) AS lift_relative_pct,
    CAST(NULL AS DECIMAL(18,6)) AS pooled_se, CAST(NULL AS DECIMAL(18,6)) AS z_score,
    CAST(NULL AS INT) AS significant_95, CAST(NULL AS INT) AS significant_99,
    CAST(NULL AS DECIMAL(18,2)) AS annualized_revenue_lift_usd
FROM arm_calc

UNION ALL

SELECT
    c.test_name, N'result' AS row_type, CAST(NULL AS NVARCHAR(20)) AS arm, c.window_start, c.window_end,
    c.sessions + v.sessions AS sessions,
    c.orders + v.orders AS orders,
    CAST(c.orders + v.orders AS DECIMAL(18,6)) / NULLIF(c.sessions + v.sessions, 0) AS cvr,
    CAST(NULL AS DECIMAL(18,4)) AS aov_usd,
    c.cvr AS control_cvr,
    v.cvr AS variant_cvr,
    v.cvr - c.cvr AS lift_pp,
    (v.cvr - c.cvr) / NULLIF(c.cvr, 0) AS lift_relative_pct,
    ss.se AS pooled_se,
    (v.cvr - c.cvr) / NULLIF(ss.se, 0) AS z_score,
    CASE WHEN ABS((v.cvr - c.cvr) / NULLIF(ss.se, 0)) >= 1.96   THEN 1 ELSE 0 END AS significant_95,
    CASE WHEN ABS((v.cvr - c.cvr) / NULLIF(ss.se, 0)) >= 2.576  THEN 1 ELSE 0 END AS significant_99,
    (v.cvr - c.cvr) * ann.annual_sessions_estimate * c.aov_usd AS annualized_revenue_lift_usd
FROM arm_calc c
JOIN arm_calc v ON v.test_name = c.test_name AND c.arm = 'control' AND v.arm = 'variant'
CROSS APPLY (SELECT CAST(c.orders + v.orders AS DECIMAL(18,6)) / NULLIF(c.sessions + v.sessions, 0) AS p_pool) pp
CROSS APPLY (SELECT SQRT(pp.p_pool * (1 - pp.p_pool) * (1.0 / c.sessions + 1.0 / v.sessions)) AS se) ss
CROSS APPLY (SELECT CAST(c.sessions + v.sessions AS DECIMAL(18,6)) / NULLIF(DATEDIFF(day, c.window_start, c.window_end) + 1, 0) * 365.0 AS annual_sessions_estimate) ann;
GO

-- =====================================================================
-- P1 -- CVR growth decomposition, calendar year 2012 vs 2015 (matches the
-- validated year-over-year CVR figures from docs/02_data_quality.md:
-- 2012 4.14% -> 2015 8.44%). Symmetric (average-weight) additive
-- decomposition by channel_group: intra-channel improvement vs mix-shift.
-- Contributions sum exactly to the total CVR delta (see TOTAL row).
-- Limit: single dimension (channel); device/repeat mix not decomposed.
-- =====================================================================
CREATE VIEW analysis.vw_cvr_decomposition AS
WITH channel_year AS (
    SELECT
        ds.channel_group,
        DATEPART(year, ds.created_at) AS yr,
        COUNT(*) AS sessions,
        SUM(CASE WHEN fo.order_id IS NOT NULL THEN 1 ELSE 0 END) AS orders
    FROM core.dim_website_session ds
    LEFT JOIN core.fact_order fo ON fo.website_session_id = ds.website_session_id
    WHERE DATEPART(year, ds.created_at) IN (2012, 2015)
    GROUP BY ds.channel_group, DATEPART(year, ds.created_at)
),
totals AS (
    SELECT
        SUM(CASE WHEN yr = 2012 THEN sessions END) AS total_sessions_2012,
        SUM(CASE WHEN yr = 2012 THEN orders   END) AS total_orders_2012,
        SUM(CASE WHEN yr = 2015 THEN sessions END) AS total_sessions_2015,
        SUM(CASE WHEN yr = 2015 THEN orders   END) AS total_orders_2015
    FROM channel_year
),
pivoted AS (
    SELECT
        cy12.channel_group,
        cy12.sessions AS sessions_2012, cy12.orders AS orders_2012,
        CAST(cy12.orders AS DECIMAL(18,6)) / NULLIF(cy12.sessions, 0) AS cvr_2012,
        cy15.sessions AS sessions_2015, cy15.orders AS orders_2015,
        CAST(cy15.orders AS DECIMAL(18,6)) / NULLIF(cy15.sessions, 0) AS cvr_2015
    FROM channel_year cy12
    JOIN channel_year cy15 ON cy15.channel_group = cy12.channel_group AND cy15.yr = 2015
    WHERE cy12.yr = 2012
),
contrib AS (
    SELECT
        p.channel_group, p.sessions_2012, p.orders_2012, p.cvr_2012,
        CAST(p.sessions_2012 AS DECIMAL(18,6)) / t.total_sessions_2012 AS share_2012,
        p.sessions_2015, p.orders_2015, p.cvr_2015,
        CAST(p.sessions_2015 AS DECIMAL(18,6)) / t.total_sessions_2015 AS share_2015,
        ((CAST(p.sessions_2012 AS DECIMAL(18,6)) / t.total_sessions_2012
          + CAST(p.sessions_2015 AS DECIMAL(18,6)) / t.total_sessions_2015) / 2.0)
          * (p.cvr_2015 - p.cvr_2012) AS contribution_intra_channel_pp,
        ((CAST(p.sessions_2015 AS DECIMAL(18,6)) / t.total_sessions_2015
          - CAST(p.sessions_2012 AS DECIMAL(18,6)) / t.total_sessions_2012))
          * ((p.cvr_2012 + p.cvr_2015) / 2.0) AS contribution_mix_shift_pp
    FROM pivoted p
    CROSS JOIN totals t
)
SELECT channel_group, sessions_2012, orders_2012, cvr_2012, share_2012,
       sessions_2015, orders_2015, cvr_2015, share_2015,
       contribution_intra_channel_pp, contribution_mix_shift_pp
FROM contrib
UNION ALL
SELECT
    N'TOTAL', t.total_sessions_2012, t.total_orders_2012,
    CAST(t.total_orders_2012 AS DECIMAL(18,6)) / t.total_sessions_2012, 1.0,
    t.total_sessions_2015, t.total_orders_2015,
    CAST(t.total_orders_2015 AS DECIMAL(18,6)) / t.total_sessions_2015, 1.0,
    (SELECT SUM(contribution_intra_channel_pp) FROM contrib),
    (SELECT SUM(contribution_mix_shift_pp) FROM contrib)
FROM totals t;
GO

-- =====================================================================
-- P2 -- Channel economics with margin (grain='channel') + refund rate by
-- product (grain='product'), both by calendar quarter. Refunds anchored
-- to the ORDER date, not the refund date (docs/02_data_quality.md #3).
-- Channel grain uses order-level price/cogs; product grain uses
-- order_item-level price/cogs (matches the Fase 2 refund-by-product
-- method). No CAC/ROAS: raw data has no acquisition cost, margin is
-- gross margin only.
-- =====================================================================
CREATE VIEW analysis.vw_channel_economics AS
WITH sessions_cte AS (
    SELECT channel_group, DATEPART(year, created_at) AS yr, DATEPART(quarter, created_at) AS qtr, COUNT(*) AS sessions
    FROM core.dim_website_session
    GROUP BY channel_group, DATEPART(year, created_at), DATEPART(quarter, created_at)
),
orders_cte AS (
    SELECT ds.channel_group, DATEPART(year, fo.created_at) AS yr, DATEPART(quarter, fo.created_at) AS qtr,
        COUNT(*) AS orders, SUM(fo.price_usd) AS revenue_usd, SUM(fo.cogs_usd) AS cogs_usd
    FROM core.fact_order fo
    JOIN core.dim_website_session ds ON ds.website_session_id = fo.website_session_id
    GROUP BY ds.channel_group, DATEPART(year, fo.created_at), DATEPART(quarter, fo.created_at)
),
refunds_channel_cte AS (
    SELECT ds.channel_group, DATEPART(year, fo.created_at) AS yr, DATEPART(quarter, fo.created_at) AS qtr,
        COUNT(*) AS refund_count, SUM(r.refund_amount_usd) AS refund_usd
    FROM core.fact_order_item_refund r
    JOIN core.fact_order fo ON fo.order_id = r.order_id
    JOIN core.dim_website_session ds ON ds.website_session_id = fo.website_session_id
    GROUP BY ds.channel_group, DATEPART(year, fo.created_at), DATEPART(quarter, fo.created_at)
),
items_cte AS (
    SELECT dp.product_name, DATEPART(year, oi.created_at) AS yr, DATEPART(quarter, oi.created_at) AS qtr,
        COUNT(*) AS items_sold, SUM(oi.price_usd) AS revenue_usd, SUM(oi.cogs_usd) AS cogs_usd
    FROM core.fact_order_item oi
    JOIN core.dim_product dp ON dp.product_id = oi.product_id
    GROUP BY dp.product_name, DATEPART(year, oi.created_at), DATEPART(quarter, oi.created_at)
),
refunds_product_cte AS (
    SELECT dp.product_name, DATEPART(year, fo.created_at) AS yr, DATEPART(quarter, fo.created_at) AS qtr,
        COUNT(*) AS refund_count, SUM(r.refund_amount_usd) AS refund_usd
    FROM core.fact_order_item_refund r
    JOIN core.fact_order_item oi ON oi.order_item_id = r.order_item_id
    JOIN core.dim_product dp ON dp.product_id = oi.product_id
    JOIN core.fact_order fo ON fo.order_id = r.order_id
    GROUP BY dp.product_name, DATEPART(year, fo.created_at), DATEPART(quarter, fo.created_at)
)
SELECT
    N'channel' AS grain,
    s.channel_group AS dimension_value,
    CONCAT(s.yr, '-Q', s.qtr) AS period,
    s.sessions,
    ISNULL(o.orders, 0) AS orders,
    ISNULL(o.revenue_usd, 0) AS revenue_usd,
    ISNULL(o.cogs_usd, 0) AS cogs_usd,
    ISNULL(o.revenue_usd, 0) - ISNULL(o.cogs_usd, 0) AS gross_margin_usd,
    (ISNULL(o.revenue_usd, 0) - ISNULL(o.cogs_usd, 0)) / NULLIF(o.revenue_usd, 0) AS gross_margin_pct,
    ISNULL(rf.refund_count, 0) AS refund_count,
    ISNULL(rf.refund_usd, 0) AS refund_usd,
    ISNULL(rf.refund_usd, 0) / NULLIF(o.revenue_usd, 0) AS refund_rate_pct
FROM sessions_cte s
LEFT JOIN orders_cte o ON o.channel_group = s.channel_group AND o.yr = s.yr AND o.qtr = s.qtr
LEFT JOIN refunds_channel_cte rf ON rf.channel_group = s.channel_group AND rf.yr = s.yr AND rf.qtr = s.qtr

UNION ALL

-- orders column holds items_sold for grain='product' (order_item grain, not order grain)
SELECT
    N'product' AS grain,
    i.product_name AS dimension_value,
    CONCAT(i.yr, '-Q', i.qtr) AS period,
    NULL AS sessions,
    i.items_sold AS orders,
    i.revenue_usd,
    i.cogs_usd,
    i.revenue_usd - i.cogs_usd AS gross_margin_usd,
    (i.revenue_usd - i.cogs_usd) / NULLIF(i.revenue_usd, 0) AS gross_margin_pct,
    ISNULL(rp.refund_count, 0) AS refund_count,
    ISNULL(rp.refund_usd, 0) AS refund_usd,
    ISNULL(rp.refund_usd, 0) / NULLIF(i.revenue_usd, 0) AS refund_rate_pct
FROM items_cte i
LEFT JOIN refunds_product_cte rp ON rp.product_name = i.product_name AND rp.yr = i.yr AND rp.qtr = i.qtr;
GO
