-- Fase 3: SP que limpia/castea raw.* y materializa core.* (fact + dims).
-- Reglas de limpieza fijadas en docs/02_data_quality.md §3:
--   - strip CHAR(13) colgando en la última columna de cada tabla (menos pageviews)
--   - strip comillas dobles en website_pageviews.created_at
--   - utm_* literal 'NULL' -> NULL real
--   - channel_group: utm_source si existe: si no, derivado de http_referer
USE maven_fuzzy_factory;
GO

CREATE OR ALTER PROCEDURE core.usp_transform_core_model
AS
BEGIN
    SET NOCOUNT ON;

    -- Orden de borrado: hijos antes que padres (FKs)
    DELETE FROM core.fact_order_item_refund;
    DELETE FROM core.fact_order_item;
    DELETE FROM core.fact_website_pageview;
    DELETE FROM core.fact_order;
    DELETE FROM core.dim_website_session;
    DELETE FROM core.dim_product;

    INSERT INTO core.dim_product (product_id, created_at, product_name)
    SELECT
        TRY_CONVERT(INT, product_id),
        TRY_CONVERT(DATETIME2, created_at),
        TRIM(REPLACE(product_name, CHAR(13), ''))
    FROM raw.products;

    INSERT INTO core.dim_website_session (
        website_session_id, created_at, user_id, is_repeat_session, device_type,
        utm_source, utm_campaign, utm_content, http_referer, channel_group
    )
    SELECT
        TRY_CONVERT(INT, s.website_session_id),
        TRY_CONVERT(DATETIME2, s.created_at),
        TRY_CONVERT(INT, s.user_id),
        TRY_CONVERT(BIT, TRY_CONVERT(INT, s.is_repeat_session)),
        s.device_type,
        NULLIF(s.utm_source, 'NULL'),
        NULLIF(s.utm_campaign, 'NULL'),
        NULLIF(s.utm_content, 'NULL'),
        NULLIF(TRIM(REPLACE(s.http_referer, CHAR(13), '')), 'NULL'),
        CASE
            WHEN s.utm_source IS NOT NULL AND s.utm_source <> 'NULL' THEN s.utm_source
            WHEN TRIM(REPLACE(s.http_referer, CHAR(13), '')) = 'https://www.gsearch.com' THEN 'organic_search_gsearch'
            WHEN TRIM(REPLACE(s.http_referer, CHAR(13), '')) = 'https://www.bsearch.com' THEN 'organic_search_bsearch'
            ELSE 'direct'
        END
    FROM raw.website_sessions s;

    INSERT INTO core.fact_website_pageview (website_pageview_id, created_at, website_session_id, pageview_url)
    SELECT
        TRY_CONVERT(INT, website_pageview_id),
        TRY_CONVERT(DATETIME2, REPLACE(created_at, '"', '')),
        TRY_CONVERT(INT, website_session_id),
        pageview_url
    FROM raw.website_pageviews;

    INSERT INTO core.fact_order (
        order_id, created_at, website_session_id, user_id, primary_product_id,
        items_purchased, price_usd, cogs_usd
    )
    SELECT
        TRY_CONVERT(INT, order_id),
        TRY_CONVERT(DATETIME2, created_at),
        TRY_CONVERT(INT, website_session_id),
        TRY_CONVERT(INT, user_id),
        TRY_CONVERT(INT, primary_product_id),
        TRY_CONVERT(INT, items_purchased),
        TRY_CONVERT(DECIMAL(18,4), price_usd),
        TRY_CONVERT(DECIMAL(18,4), TRIM(REPLACE(cogs_usd, CHAR(13), '')))
    FROM raw.orders;

    INSERT INTO core.fact_order_item (
        order_item_id, created_at, order_id, product_id, is_primary_item, price_usd, cogs_usd
    )
    SELECT
        TRY_CONVERT(INT, order_item_id),
        TRY_CONVERT(DATETIME2, created_at),
        TRY_CONVERT(INT, order_id),
        TRY_CONVERT(INT, product_id),
        TRY_CONVERT(BIT, TRY_CONVERT(INT, is_primary_item)),
        TRY_CONVERT(DECIMAL(18,4), price_usd),
        TRY_CONVERT(DECIMAL(18,4), TRIM(REPLACE(cogs_usd, CHAR(13), '')))
    FROM raw.order_items;

    INSERT INTO core.fact_order_item_refund (
        order_item_refund_id, created_at, order_item_id, order_id, refund_amount_usd
    )
    SELECT
        TRY_CONVERT(INT, order_item_refund_id),
        TRY_CONVERT(DATETIME2, created_at),
        TRY_CONVERT(INT, order_item_id),
        TRY_CONVERT(INT, order_id),
        TRY_CONVERT(DECIMAL(18,4), TRIM(REPLACE(refund_amount_usd, CHAR(13), '')))
    FROM raw.order_item_refunds;
END
GO
