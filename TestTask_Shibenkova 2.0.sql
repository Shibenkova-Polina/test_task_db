-- Продажи с НДС по сети в руб.
-- Продажи по сети в шт.
-- Средняя цена закупки руб. без НДС
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
    -- Объявление переменных
    DECLARE @total_sale_grs DECIMAL(10,2);
    DECLARE @total_quantity DECIMAL(10,2);
    DECLARE @total_sale_net NUMERIC(10,2);
    DECLARE @total_cost_net NUMERIC(10,2);

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

    -- Выборка данных по продажам
    SELECT 
        @total_sale_grs = SUM(CAST(fct_cheque.sale_grs AS DECIMAL(10,2))),
        @total_quantity = SUM(CAST(fct_cheque.quantity AS DECIMAL(10,2))),
        @total_sale_net = SUM(CAST(fct_cheque.sale_net AS NUMERIC(10,2))),
        @total_cost_net = SUM(CAST(fct_cheque.cost_net AS NUMERIC(10,2)))
    FROM fct_cheque
        JOIN dim_goods ON fct_cheque.good_id = dim_goods.good_id
        JOIN dim_date ON fct_cheque.date_id = dim_date.did
        JOIN @good_groups gg ON dim_goods.group_name = gg.group_name
    WHERE dim_date.d BETWEEN @date_from AND @date_to;


    -- Вывод общих результатов о продажах
    SELECT 
        @total_sale_grs AS [Продажи руб., с НДС],
        @total_quantity AS [Продажи шт.],
        CASE WHEN @total_quantity <> 0 THEN @total_cost_net / @total_quantity ELSE NULL END AS [Средняя цена закупки руб., без НДС],
        @total_sale_net - @total_cost_net AS [Маржа руб. без НДС],
        CASE WHEN @total_cost_net <> 0 THEN (@total_sale_net - @total_cost_net) / @total_cost_net * 100 ELSE NULL END AS [Наценка % без НДС];


	-- сумма продаж с НДС по дню/магазину/группе товаров
    WITH daily_sales AS (
        SELECT
            dim_date.d AS sales_date,
            dim_stores.store_name AS store_name,
            dim_goods.group_name AS group_name,
            SUM(CAST(fct_cheque.sale_grs AS DECIMAL(10,2))) AS total_date_store_group_sale_grs
        FROM fct_cheque
            JOIN dim_date ON fct_cheque.date_id = dim_date.did
            JOIN dim_stores ON fct_cheque.store_id = dim_stores.store_id
            JOIN dim_goods ON fct_cheque.good_id = dim_goods.good_id
        WHERE dim_date.d BETWEEN @date_from AND @date_to
        GROUP BY
            dim_date.d,
            dim_stores.store_name,
            dim_goods.group_name
    ),
	-- сумма продаж с НДС по дню/магазину
    total_daily_sales AS (
        SELECT
            sales_date,
            store_name,
            SUM(total_date_store_group_sale_grs) AS total_date_store_sale_grs
        FROM
            daily_sales
        GROUP BY
            sales_date,
            store_name
    )
	-- Вывод результатов о доли продаж
    SELECT
        ds.sales_date AS [Дата],
        ds.store_name AS [Название магазина],
        ds.group_name AS [Название группы товаров],
        ds.total_date_store_group_sale_grs AS [Продажи руб., с НДС],
        CASE WHEN tds.total_date_store_sale_grs <> 0 THEN (ds.total_date_store_group_sale_grs / tds.total_date_store_sale_grs) * 100 ELSE NULL END AS [Доля продаж с НДС, %]
    FROM daily_sales ds
        LEFT JOIN total_daily_sales tds ON ds.sales_date = tds.sales_date AND ds.store_name = tds.store_name
        JOIN @good_groups gg ON ds.group_name = gg.group_name
    ORDER BY [Доля продаж с НДС, %] DESC;
END
GO

exec sp_report_1 @date_from='2017-06-01', @date_to='2017-06-30', @good_group_name=N'Биологически активные добавки,Косметические средства';