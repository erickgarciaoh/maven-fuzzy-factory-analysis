/* =============================================================================
   04_data_profiling.sql  —  Phase 2: exploration + data quality
   Profiling queries run against the raw NVARCHAR layer to VERIFY the scoping
   premises (data/raw/EXPLORATION.md) against the actual load. Read-only.
   Findings are documented in docs/02_data_quality.md.
   Engine: SQL Server (XTREMUS\DB001). Run in order; each block is independent.
   ============================================================================= */

/* ---- 1. Temporal window + timestamp parseability -------------------------- */
-- pageviews.created_at carries literal double quotes from BULK INSERT -> strip.
SELECT 'website_sessions' AS tbl, MIN(TRY_CONVERT(datetime2, created_at)) AS min_ts, MAX(TRY_CONVERT(datetime2, created_at)) AS max_ts, COUNT(*) AS n, SUM(CASE WHEN TRY_CONVERT(datetime2, created_at) IS NULL THEN 1 ELSE 0 END) AS unparsable_ts FROM raw.website_sessions
UNION ALL SELECT 'website_pageviews', MIN(TRY_CONVERT(datetime2, REPLACE(created_at,'"',''))), MAX(TRY_CONVERT(datetime2, REPLACE(created_at,'"',''))), COUNT(*), SUM(CASE WHEN TRY_CONVERT(datetime2, REPLACE(created_at,'"','')) IS NULL THEN 1 ELSE 0 END) FROM raw.website_pageviews
UNION ALL SELECT 'orders', MIN(TRY_CONVERT(datetime2, created_at)), MAX(TRY_CONVERT(datetime2, created_at)), COUNT(*), SUM(CASE WHEN TRY_CONVERT(datetime2, created_at) IS NULL THEN 1 ELSE 0 END) FROM raw.orders
UNION ALL SELECT 'order_items', MIN(TRY_CONVERT(datetime2, created_at)), MAX(TRY_CONVERT(datetime2, created_at)), COUNT(*), SUM(CASE WHEN TRY_CONVERT(datetime2, created_at) IS NULL THEN 1 ELSE 0 END) FROM raw.order_items
UNION ALL SELECT 'order_item_refunds', MIN(TRY_CONVERT(datetime2, created_at)), MAX(TRY_CONVERT(datetime2, created_at)), COUNT(*), SUM(CASE WHEN TRY_CONVERT(datetime2, created_at) IS NULL THEN 1 ELSE 0 END) FROM raw.order_item_refunds
UNION ALL SELECT 'products', MIN(TRY_CONVERT(datetime2, created_at)), MAX(TRY_CONVERT(datetime2, created_at)), COUNT(*), SUM(CASE WHEN TRY_CONVERT(datetime2, created_at) IS NULL THEN 1 ELSE 0 END) FROM raw.products;

/* ---- 2. Primary-key uniqueness + user cardinality ------------------------- */
SELECT 'sessions.website_session_id' AS pk, COUNT(*) AS n, COUNT(DISTINCT website_session_id) AS distinct_pk FROM raw.website_sessions
UNION ALL SELECT 'pageviews.website_pageview_id', COUNT(*), COUNT(DISTINCT website_pageview_id) FROM raw.website_pageviews
UNION ALL SELECT 'orders.order_id', COUNT(*), COUNT(DISTINCT order_id) FROM raw.orders
UNION ALL SELECT 'order_items.order_item_id', COUNT(*), COUNT(DISTINCT order_item_id) FROM raw.order_items
UNION ALL SELECT 'refunds.order_item_refund_id', COUNT(*), COUNT(DISTINCT order_item_refund_id) FROM raw.order_item_refunds
UNION ALL SELECT 'products.product_id', COUNT(*), COUNT(DISTINCT product_id) FROM raw.products
UNION ALL SELECT 'sessions.user_id (distinct)', COUNT(*), COUNT(DISTINCT user_id) FROM raw.website_sessions;

/* ---- 3. Referential integrity (anti-joins; expect 0 orphans) -------------- */
SELECT 'pageviews->sessions' AS fk, COUNT(*) AS orphans FROM raw.website_pageviews p WHERE NOT EXISTS (SELECT 1 FROM raw.website_sessions s WHERE s.website_session_id = p.website_session_id)
UNION ALL SELECT 'orders->sessions', COUNT(*) FROM raw.orders o WHERE NOT EXISTS (SELECT 1 FROM raw.website_sessions s WHERE s.website_session_id = o.website_session_id)
UNION ALL SELECT 'order_items->orders', COUNT(*) FROM raw.order_items i WHERE NOT EXISTS (SELECT 1 FROM raw.orders o WHERE o.order_id = i.order_id)
UNION ALL SELECT 'order_items->products', COUNT(*) FROM raw.order_items i WHERE NOT EXISTS (SELECT 1 FROM raw.products pr WHERE pr.product_id = i.product_id)
UNION ALL SELECT 'refunds->order_items', COUNT(*) FROM raw.order_item_refunds r WHERE NOT EXISTS (SELECT 1 FROM raw.order_items i WHERE i.order_item_id = r.order_item_id)
UNION ALL SELECT 'refunds->orders', COUNT(*) FROM raw.order_item_refunds r WHERE NOT EXISTS (SELECT 1 FROM raw.orders o WHERE o.order_id = r.order_id)
UNION ALL SELECT 'orders->primary_product', COUNT(*) FROM raw.orders o WHERE NOT EXISTS (SELECT 1 FROM raw.products pr WHERE pr.product_id = o.primary_product_id);

/* ---- 4. Trailing carriage-return contamination (last column of each table)  */
-- BULK INSERT used ROWTERMINATOR '\n' on CRLF files -> CHAR(13) sticks to the
-- LAST field of every row. Must be stripped before casting in Phase 3.
SELECT 'sessions.http_referer' AS last_col, SUM(CASE WHEN RIGHT(http_referer,1)=CHAR(13) THEN 1 ELSE 0 END) AS with_cr, COUNT(*) AS n FROM raw.website_sessions
UNION ALL SELECT 'pageviews.pageview_url', SUM(CASE WHEN RIGHT(pageview_url,1)=CHAR(13) THEN 1 ELSE 0 END), COUNT(*) FROM raw.website_pageviews
UNION ALL SELECT 'orders.cogs_usd', SUM(CASE WHEN RIGHT(cogs_usd,1)=CHAR(13) THEN 1 ELSE 0 END), COUNT(*) FROM raw.orders
UNION ALL SELECT 'order_items.cogs_usd', SUM(CASE WHEN RIGHT(cogs_usd,1)=CHAR(13) THEN 1 ELSE 0 END), COUNT(*) FROM raw.order_items
UNION ALL SELECT 'refunds.refund_amount_usd', SUM(CASE WHEN RIGHT(refund_amount_usd,1)=CHAR(13) THEN 1 ELSE 0 END), COUNT(*) FROM raw.order_item_refunds
UNION ALL SELECT 'products.product_name', SUM(CASE WHEN RIGHT(product_name,1)=CHAR(13) THEN 1 ELSE 0 END), COUNT(*) FROM raw.products;

/* ---- 5. UTM nulls: literal 'NULL' vs true NULL vs empty (structural) ------ */
SELECT
  SUM(CASE WHEN utm_source = 'NULL' THEN 1 ELSE 0 END) AS src_literal_null,
  SUM(CASE WHEN utm_source IS NULL THEN 1 ELSE 0 END)  AS src_true_null,
  SUM(CASE WHEN utm_source = '' THEN 1 ELSE 0 END)     AS src_empty,
  SUM(CASE WHEN utm_campaign = 'NULL' THEN 1 ELSE 0 END) AS camp_literal_null,
  SUM(CASE WHEN utm_content  = 'NULL' THEN 1 ELSE 0 END) AS cont_literal_null,
  COUNT(*) AS n
FROM raw.website_sessions;

/* ---- 6. Channel mix (utm_source) ------------------------------------------ */
SELECT CASE WHEN utm_source = 'NULL' THEN '(no utm)' ELSE utm_source END AS utm_source,
       COUNT(*) AS sessions,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER() AS decimal(5,2)) AS pct
FROM raw.website_sessions
GROUP BY CASE WHEN utm_source = 'NULL' THEN '(no utm)' ELSE utm_source END
ORDER BY sessions DESC;

/* ---- 7. No-UTM traffic split: direct vs organic via http_referer ---------- */
-- Referer 'NULL' (literal) = direct; a search-engine referer = organic.
SELECT LEFT(REPLACE(http_referer,CHAR(13),''),40) AS referer, COUNT(*) AS n
FROM raw.website_sessions
WHERE utm_source = 'NULL'
GROUP BY LEFT(REPLACE(http_referer,CHAR(13),''),40)
ORDER BY n DESC;

/* ---- 8. Device mix + repeat-session rate ---------------------------------- */
SELECT device_type, COUNT(*) AS n, CAST(100.0*COUNT(*)/SUM(COUNT(*)) OVER() AS decimal(5,2)) AS pct FROM raw.website_sessions GROUP BY device_type ORDER BY n DESC;
SELECT is_repeat_session, COUNT(*) AS n, CAST(100.0*COUNT(*)/SUM(COUNT(*)) OVER() AS decimal(5,2)) AS pct FROM raw.website_sessions GROUP BY is_repeat_session ORDER BY is_repeat_session;

/* ---- 9. Conversion rate by year (session -> order) ------------------------ */
SELECT YEAR(TRY_CONVERT(datetime2, s.created_at)) AS yr, COUNT(*) AS sessions, COUNT(o.order_id) AS orders,
       CAST(100.0 * COUNT(o.order_id) / COUNT(*) AS decimal(5,2)) AS cvr_pct
FROM raw.website_sessions s
LEFT JOIN raw.orders o ON o.website_session_id = s.website_session_id
GROUP BY YEAR(TRY_CONVERT(datetime2, s.created_at))
ORDER BY yr;

/* ---- 10. Revenue / AOV / items + order-size distribution ------------------ */
SELECT SUM(TRY_CONVERT(decimal(18,4), price_usd)) AS revenue,
       SUM(TRY_CONVERT(decimal(18,4), REPLACE(cogs_usd,CHAR(13),''))) AS cogs,
       COUNT(*) AS orders,
       SUM(TRY_CONVERT(int, items_purchased)) AS items,
       CAST(AVG(TRY_CONVERT(decimal(18,4), price_usd)) AS decimal(10,2)) AS aov
FROM raw.orders;
SELECT items_purchased, COUNT(*) AS orders, CAST(100.0*COUNT(*)/SUM(COUNT(*)) OVER() AS decimal(5,2)) AS pct FROM raw.orders GROUP BY items_purchased ORDER BY items_purchased;

/* ---- 11. Product catalog: staggered launches + volume --------------------- */
SELECT p.product_id, REPLACE(p.product_name,CHAR(13),'') AS product_name, MIN(TRY_CONVERT(datetime2,p.created_at)) AS launch,
       COUNT(i.order_item_id) AS units
FROM raw.products p LEFT JOIN raw.order_items i ON i.product_id = p.product_id
GROUP BY p.product_id, REPLACE(p.product_name,CHAR(13),''), p.created_at ORDER BY launch;

/* ---- 12. Refund rate by product (volume vs rate) -------------------------- */
SELECT REPLACE(pr.product_name,CHAR(13),'') AS product,
       COUNT(DISTINCT i.order_item_id) AS items_sold,
       COUNT(DISTINCT r.order_item_refund_id) AS refunds,
       CAST(100.0*COUNT(DISTINCT r.order_item_refund_id)/COUNT(DISTINCT i.order_item_id) AS decimal(5,2)) AS refund_rate_pct,
       SUM(TRY_CONVERT(decimal(18,4), REPLACE(r.refund_amount_usd,CHAR(13),''))) AS refund_usd
FROM raw.order_items i
JOIN raw.products pr ON pr.product_id = i.product_id
LEFT JOIN raw.order_item_refunds r ON r.order_item_id = i.order_item_id
GROUP BY REPLACE(pr.product_name,CHAR(13),'')
ORDER BY items_sold DESC;
