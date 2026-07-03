-- Fase 1: SP importador de los 6 CSV de data/raw/ a la capa raw.
-- Modo nativo (FIELDTERMINATOR/ROWTERMINATOR), sin FORMAT='CSV' ni
-- FIELDQUOTE: esa combinación rompe el proveedor OLE DB "BULK" en esta
-- build (error IID_IColumnsInfo) al importar website_pageviews.csv.
-- Consecuencia: created_at en raw.website_pageviews llega con comillas
-- dobles literales (el CSV de origen lo trae así); se limpian con
-- TRIM/REPLACE en el casteo de la Fase 3, no aquí.
USE maven_fuzzy_factory;
GO

CREATE OR ALTER PROCEDURE raw.usp_import_all_raw_data
    @DataPath NVARCHAR(500) = N'D:\Dev\Projects\maven-fuzzy-factory-analysis\data\raw\'
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE raw.website_sessions;
    TRUNCATE TABLE raw.website_pageviews;
    TRUNCATE TABLE raw.orders;
    TRUNCATE TABLE raw.order_items;
    TRUNCATE TABLE raw.order_item_refunds;
    TRUNCATE TABLE raw.products;

    DECLARE @sql NVARCHAR(MAX);

    SET @sql = N'BULK INSERT raw.website_sessions FROM ''' + @DataPath + N'website_sessions.csv''
        WITH (FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', FIRSTROW = 2, TABLOCK);';
    EXEC sp_executesql @sql;

    SET @sql = N'BULK INSERT raw.website_pageviews FROM ''' + @DataPath + N'website_pageviews.csv''
        WITH (FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', FIRSTROW = 2, TABLOCK);';
    EXEC sp_executesql @sql;

    SET @sql = N'BULK INSERT raw.orders FROM ''' + @DataPath + N'orders.csv''
        WITH (FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', FIRSTROW = 2, TABLOCK);';
    EXEC sp_executesql @sql;

    SET @sql = N'BULK INSERT raw.order_items FROM ''' + @DataPath + N'order_items.csv''
        WITH (FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', FIRSTROW = 2, TABLOCK);';
    EXEC sp_executesql @sql;

    SET @sql = N'BULK INSERT raw.order_item_refunds FROM ''' + @DataPath + N'order_item_refunds.csv''
        WITH (FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', FIRSTROW = 2, TABLOCK);';
    EXEC sp_executesql @sql;

    SET @sql = N'BULK INSERT raw.products FROM ''' + @DataPath + N'products.csv''
        WITH (FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', FIRSTROW = 2, TABLOCK);';
    EXEC sp_executesql @sql;
END
GO
