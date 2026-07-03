-- Fase 3: modelo core (estrella ligera). Tipado real, casteado desde raw.*.
-- dim_product, dim_website_session + fact_website_pageview, fact_order,
-- fact_order_item, fact_order_item_refund. IDs son los del origen (sin IDENTITY).
USE maven_fuzzy_factory;
GO

IF SCHEMA_ID(N'core') IS NULL
    EXEC('CREATE SCHEMA core');
GO

IF OBJECT_ID(N'core.fact_order_item_refund', 'U') IS NOT NULL DROP TABLE core.fact_order_item_refund;
IF OBJECT_ID(N'core.fact_order_item', 'U') IS NOT NULL DROP TABLE core.fact_order_item;
IF OBJECT_ID(N'core.fact_website_pageview', 'U') IS NOT NULL DROP TABLE core.fact_website_pageview;
IF OBJECT_ID(N'core.fact_order', 'U') IS NOT NULL DROP TABLE core.fact_order;
IF OBJECT_ID(N'core.dim_website_session', 'U') IS NOT NULL DROP TABLE core.dim_website_session;
IF OBJECT_ID(N'core.dim_product', 'U') IS NOT NULL DROP TABLE core.dim_product;
GO

CREATE TABLE core.dim_product (
    product_id   INT           NOT NULL CONSTRAINT PK_dim_product PRIMARY KEY,
    product_name NVARCHAR(200) NOT NULL,
    created_at   DATETIME2     NOT NULL
);
GO

-- channel_group: utm_source cuando existe (canal pagado); si no, derivado de
-- http_referer (directo / orgánico gsearch / orgánico bsearch). Ver docs/02_data_quality.md §3.
CREATE TABLE core.dim_website_session (
    website_session_id INT          NOT NULL CONSTRAINT PK_dim_website_session PRIMARY KEY,
    created_at          DATETIME2    NOT NULL,
    user_id             INT          NOT NULL,
    is_repeat_session    BIT          NOT NULL,
    device_type          NVARCHAR(20) NOT NULL,
    utm_source           NVARCHAR(50) NULL,
    utm_campaign         NVARCHAR(50) NULL,
    utm_content          NVARCHAR(50) NULL,
    http_referer         NVARCHAR(200) NULL,
    channel_group        NVARCHAR(30) NOT NULL
);
GO

CREATE TABLE core.fact_website_pageview (
    website_pageview_id INT          NOT NULL CONSTRAINT PK_fact_website_pageview PRIMARY KEY,
    created_at           DATETIME2    NOT NULL,
    website_session_id   INT          NOT NULL
        CONSTRAINT FK_pageview_session REFERENCES core.dim_website_session(website_session_id),
    pageview_url          NVARCHAR(200) NOT NULL
);
GO

CREATE TABLE core.fact_order (
    order_id            INT            NOT NULL CONSTRAINT PK_fact_order PRIMARY KEY,
    created_at          DATETIME2      NOT NULL,
    website_session_id  INT            NOT NULL
        CONSTRAINT FK_order_session REFERENCES core.dim_website_session(website_session_id),
    user_id             INT            NOT NULL,
    primary_product_id  INT            NOT NULL
        CONSTRAINT FK_order_product REFERENCES core.dim_product(product_id),
    items_purchased     INT            NOT NULL,
    price_usd           DECIMAL(18,4)  NOT NULL,
    cogs_usd            DECIMAL(18,4)  NOT NULL
);
GO

CREATE TABLE core.fact_order_item (
    order_item_id  INT            NOT NULL CONSTRAINT PK_fact_order_item PRIMARY KEY,
    created_at     DATETIME2      NOT NULL,
    order_id       INT            NOT NULL
        CONSTRAINT FK_orderitem_order REFERENCES core.fact_order(order_id),
    product_id     INT            NOT NULL
        CONSTRAINT FK_orderitem_product REFERENCES core.dim_product(product_id),
    is_primary_item BIT           NOT NULL,
    price_usd      DECIMAL(18,4)  NOT NULL,
    cogs_usd       DECIMAL(18,4)  NOT NULL
);
GO

CREATE TABLE core.fact_order_item_refund (
    order_item_refund_id INT            NOT NULL CONSTRAINT PK_fact_order_item_refund PRIMARY KEY,
    created_at            DATETIME2      NOT NULL,
    order_item_id         INT            NOT NULL
        CONSTRAINT FK_refund_orderitem REFERENCES core.fact_order_item(order_item_id),
    order_id              INT            NOT NULL
        CONSTRAINT FK_refund_order REFERENCES core.fact_order(order_id),
    refund_amount_usd     DECIMAL(18,4)  NOT NULL
);
GO
