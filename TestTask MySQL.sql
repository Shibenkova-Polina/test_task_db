USE dbo;
DROP PROCEDURE IF EXISTS sp_report_1;
DELIMITER //

CREATE PROCEDURE sp_report_1 (
    IN date_from DATE,
    IN date_to DATE,
    IN good_group_name NVARCHAR(110)
)
BEGIN
    -- Объявление переменных
    DECLARE v_total_sale_grs DECIMAL(10,2);
    DECLARE v_total_quantity DECIMAL(10,2);
    DECLARE expected_sale_grs DECIMAL(10,2) DEFAULT 1782949.1;
    DECLARE expected_quantity DECIMAL(10,2) DEFAULT 6761.1;


    -- Выборка данных по продажам
    SELECT 
        SUM(CAST(sale_grs AS DECIMAL(10,2))), 
        SUM(CAST(quantity AS DECIMAL(10,2)))
    INTO v_total_sale_grs, v_total_quantity
    FROM fct_cheque
    JOIN dim_goods ON fct_cheque.good_id = dim_goods.good_id
    JOIN dim_date ON fct_cheque.date_id = dim_date.did
    WHERE dim_date.d BETWEEN date_from AND date_to
    AND dim_goods.group_name = good_group_name;

    -- Вывод результатов и сообщение о расхождениях
    SELECT 
        v_total_sale_grs AS 'Продажи руб., с НДС',
        v_total_quantity AS 'Продажи шт.';

    IF v_total_sale_grs != expected_sale_grs OR @v_total_sale_grs IS NULL THEN
        SELECT 'Расхождение в данных о продажах' AS message;
        IF v_total_quantity != expected_quantity OR v_total_quantity IS NULL THEN
			SELECT 'Расхождение в данных о количестве' AS message;
		END IF;
    END IF;

END //

DELIMITER ;

call sp_report_1 (@date_from='2017-06-01', @date_to='2017-06-30', @good_group_name=N'Биологически активные добавки');
