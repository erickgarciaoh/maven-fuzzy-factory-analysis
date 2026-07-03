-- Fase 1: raw landing layer. Todo NVARCHAR, sin casteo, columnas en el mismo
-- orden que los CSV de origen. El casteo/tipado ocurre en la Fase 3 (transform).
USE maven_fuzzy_factory;
GO

IF SCHEMA_ID(N'raw') IS NULL
    EXEC('CREATE SCHEMA raw');
GO

IF OBJECT_ID(N'raw.website_sessions', 'U') IS NOT NULL DROP TABLE raw.website_sessions;
CREATE TABLE raw.website_sessions (
    website_session_id NVARCHAR(4000) NULL,
    created_at          NVARCHAR(4000) NULL,
    user_id             NVARCHAR(4000) NULL,
    is_repeat_session   NVARCHAR(4000) NULL,
    utm_source          NVARCHAR(4000) NULL,
    utm_campaign        NVARCHAR(4000) NULL,
    utm_content         NVARCHAR(4000) NULL,
    device_type         NVARCHAR(4000) NULL,
    http_referer        NVARCHAR(4000) NULL
);
GO

IF OBJECT_ID(N'raw.website_pageviews', 'U') IS NOT NULL DROP TABLE raw.website_pageviews;
CREATE TABLE raw.website_pageviews (
    website_pageview_id NVARCHAR(4000) NULL,
    created_at           NVARCHAR(4000) NULL,
    website_session_id   NVARCHAR(4000) NULL,
    pageview_url          NVARCHAR(4000) NULL
);
GO

IF OBJECT_ID(N'raw.orders', 'U') IS NOT NULL DROP TABLE raw.orders;
CREATE TABLE raw.orders (
    order_id            NVARCHAR(4000) NULL,
    created_at          NVARCHAR(4000) NULL,
    website_session_id  NVARCHAR(4000) NULL,
    user_id             NVARCHAR(4000) NULL,
    primary_product_id  NVARCHAR(4000) NULL,
    items_purchased     NVARCHAR(4000) NULL,
    price_usd           NVARCHAR(4000) NULL,
    cogs_usd            NVARCHAR(4000) NULL
);
GO

IF OBJECT_ID(N'raw.order_items', 'U') IS NOT NULL DROP TABLE raw.order_items;
CREATE TABLE raw.order_items (
    order_item_id  NVARCHAR(4000) NULL,
    created_at     NVARCHAR(4000) NULL,
    order_id       NVARCHAR(4000) NULL,
    product_id     NVARCHAR(4000) NULL,
    is_primary_item NVARCHAR(4000) NULL,
    price_usd      NVARCHAR(4000) NULL,
    cogs_usd       NVARCHAR(4000) NULL
);
GO

IF OBJECT_ID(N'raw.order_item_refunds', 'U') IS NOT NULL DROP TABLE raw.order_item_refunds;
CREATE TABLE raw.order_item_refunds (
    order_item_refund_id NVARCHAR(4000) NULL,
    created_at            NVARCHAR(4000) NULL,
    order_item_id         NVARCHAR(4000) NULL,
    order_id              NVARCHAR(4000) NULL,
    refund_amount_usd     NVARCHAR(4000) NULL
);
GO

IF OBJECT_ID(N'raw.products', 'U') IS NOT NULL DROP TABLE raw.products;
CREATE TABLE raw.products (
    product_id    NVARCHAR(4000) NULL,
    created_at    NVARCHAR(4000) NULL,
    product_name  NVARCHAR(4000) NULL
);
GO
