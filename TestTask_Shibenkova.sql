-- Продажи с НДС по сети в руб.
-- Продажи по сети в шт.
-- Цена закупки руб. без НДС
-- Маржа руб. без НДС
-- Наценка % без НДС, 
-- по группам товаров 'Биологически активные добавки' и 'Косметические средства', в июне 2017.
--
-- Вывод доли продаж с НДС товара, в каждом дне/магазине/группе товаров, сортировка выборки по убыванию показателя

DROP PROCEDURE IF EXISTS [dbo].[sp_report_1];
GO

CREATE PROCEDURE [dbo].[sp_report_1]
    @date_from DATE,
    @date_to DATE,
    @good_group_name NVARCHAR(MAX)
AS
BEGIN
    -- Создание табличной переменной для хранения списка групп товаров
    DECLARE @good_groups TABLE (group_name NVARCHAR(110));

    -- Разбиение строки с группами товаров на отдельные элементы
    DECLARE @separator CHAR(1) = ',';
    DECLARE @group_name NVARCHAR(110);
    DECLARE @pos INT;
    DECLARE @len INT;

    SET @len = LEN(@good_group_name);
    SET @pos = CHARINDEX(@separator, @good_group_name);

    WHILE @pos > 0
    BEGIN
        SET @group_name = SUBSTRING(@good_group_name, 1, @pos - 1);
        INSERT INTO @good_groups (group_name) VALUES (@group_name);
        SET @good_group_name = SUBSTRING(@good_group_name, @pos + 1, @len - @pos);
        SET @len = LEN(@good_group_name);
        SET @pos = CHARINDEX(@separator, @good_group_name);
    END

    INSERT INTO @good_groups (group_name) VALUES (@good_group_name);


	-- сумма продаж с НДС по дню/магазину/группе товаров
    WITH daily_sales AS (
        SELECT
            fct_cheque.date_id AS sales_date,
            fct_cheque.store_id AS store_id,
            dim_goods.group_name AS group_name,
            SUM(CAST(fct_cheque.sale_grs AS DECIMAL(10,2))) AS total_date_store_group_sale_grs
        FROM fct_cheque
            JOIN dim_date ON fct_cheque.date_id = dim_date.did
            JOIN dim_goods ON fct_cheque.good_id = dim_goods.good_id
        WHERE dim_date.d BETWEEN @date_from AND @date_to
        GROUP BY
            fct_cheque.date_id,
            fct_cheque.store_id,
            dim_goods.group_name
    ),

    filter_goods AS (
	    -- Вывод результатов о доли продаж
        SELECT
            dd.d AS [Дата],
            st.store_name AS [Название магазина],
            ds.group_name AS [Название группы товаров],
            dg.good_name AS [Название товара],
            ROW_NUMBER() OVER (PARTITION BY dg.good_name ORDER BY (SELECT NULL)) AS rn,
            fc.sale_grs AS [Продажи руб., с НДС],
            fc.quantity AS [Продажи шт.],
            fc.cost_net AS [Средняя цена закупки руб., без НДС],
            CAST(fc.sale_net AS DECIMAL(10,2)) - CAST(fc.cost_net AS DECIMAL(10,2)) AS [Маржа руб. без НДС],
            CASE WHEN CAST(fc.cost_net AS DECIMAL(10,2)) <> 0 THEN (CAST(fc.sale_net AS DECIMAL(10,2)) - CAST(fc.cost_net AS DECIMAL(10,2))) / CAST(fc.cost_net AS DECIMAL(10,2)) * 100 ELSE NULL END AS [Наценка % без НДС],
            CASE WHEN ds.total_date_store_group_sale_grs <> 0 THEN (CAST(fc.sale_grs AS DECIMAL(10,2)) / ds.total_date_store_group_sale_grs) * 100 ELSE NULL END AS [Доля продаж с НДС, %]
        FROM daily_sales ds
            JOIN fct_cheque fc ON fc.date_id = ds.sales_date AND ds.store_id = fc.store_id
            JOIN dim_date dd ON fc.date_id = dd.did
            JOIN dim_stores st ON ds.store_id = st.store_id
            JOIN dim_goods dg ON fc.good_id = dg.good_id AND ds.group_name = dg.group_name
            JOIN @good_groups gg ON ds.group_name = gg.group_name
    )

    SELECT
        fg.[Дата] AS [Дата],
        fg.[Название магазина] AS [Название магазина],
        fg.[Название группы товаров] AS [Название группы товаров],
        fg.[Название товара] AS [Название товара],
        fg.[Продажи руб., с НДС] AS [Продажи руб., с НДС],
        fg.[Продажи шт.] AS [Продажи шт.],
        fg.[Средняя цена закупки руб., без НДС] AS [Цена закупки руб., без НДС],
        fg.[Маржа руб. без НДС] AS [Маржа руб. без НДС],
        fg.[Наценка % без НДС] AS [Наценка % без НДС],
        fg.[Доля продаж с НДС, %] AS [Доля продаж с НДС, %]
    FROM filter_goods fg
    WHERE fg.rn = 1
    ORDER BY [Дата], [Название магазина], [Название группы товаров], [Доля продаж с НДС, %] DESC

END
GO

exec sp_report_1 @date_from='2017-06-01', @date_to='2017-06-30', @good_group_name=N'Биологически активные добавки,Косметические средства';