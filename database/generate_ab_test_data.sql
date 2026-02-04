-- эксперимент
INSERT INTO ab_test_experiment (experiment_name, start_date, end_date, target_audience, hypothesis)
VALUES (
    'New Product Card Design - Q4 2023',
    '2023-10-01',
    '2023-10-31',
    'All users visiting product pages',
    'Новый дизайн карточки товара увеличит конверсию в покупку на 15% за счет улучшенного CTA и отзывов'
);
GO

DECLARE @experiment_id INT = SCOPE_IDENTITY();
DECLARE @total_users INT = 10000;  -- всего пользователей в тесте
DECLARE @i INT = 1;
DECLARE @control_size INT = @total_users * 0.5;  -- 50/50 split

-- Генерируем пользователей для теста
WHILE @i <= @total_users
BEGIN
    INSERT INTO ab_test_users (experiment_id, user_id, group_name, assignment_date, device_type, browser, traffic_source)
    VALUES (
        @experiment_id,
        @i + 10000,
        CASE WHEN @i <= @control_size THEN 'control' ELSE 'variant' END,
        DATEADD(DAY, -CAST(RAND(CHECKSUM(NEWID())) * 30 AS INT), '2023-10-31'),
        CASE 
            WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 60 THEN 'mobile'
            WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 90 THEN 'desktop'
            ELSE 'tablet'
        END,
        CASE 
            WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 45 THEN 'Chrome'
            WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 70 THEN 'Safari'
            WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 85 THEN 'Firefox'
            ELSE 'Edge'
        END,
        CASE 
            WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 30 THEN 'direct'
            WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 50 THEN 'organic'
            WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 70 THEN 'social'
            WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 90 THEN 'email'
            ELSE 'referral'
        END
    );
    
    SET @i = @i + 1;
END;
GO

-- Генерируем события для пользователей
DECLARE @j INT = 1;
DECLARE @test_user_count INT = (SELECT COUNT(*) FROM ab_test_users);
DECLARE @test_id INT;
DECLARE @group_name VARCHAR(20);
DECLARE @events_per_user INT;
DECLARE @k INT;

WHILE @j <= @test_user_count
BEGIN
    SELECT @test_id = test_id, @group_name = group_name 
    FROM ab_test_users 
    WHERE test_id = @j;
    
    IF @group_name = 'control'
        SET @events_per_user = CAST(RAND(CHECKSUM(NEWID())) * 5 + 2 AS INT);
    ELSE
        SET @events_per_user = CAST(RAND(CHECKSUM(NEWID())) * 7 + 3 AS INT);  -- variant имеет больше событий
    
    SET @k = 1;
    
    WHILE @k <= @events_per_user
    BEGIN
        INSERT INTO ab_test_events (test_id, event_type, event_date, page_url, session_duration, scroll_depth)
        VALUES (
            @test_id,
            CASE 
                WHEN @k = 1 THEN 'page_view'
                WHEN @k = 2 AND CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 70 THEN 'add_to_cart'
                WHEN @k = 3 AND CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 40 THEN 'purchase'
                ELSE CASE 
                    WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 60 THEN 'scroll'
                    ELSE 'page_view'
                END
            END,
            DATEADD(MINUTE, -CAST(RAND(CHECKSUM(NEWID())) * 120 AS INT), 
                   DATEADD(DAY, -CAST(RAND(CHECKSUM(NEWID())) * 30 AS INT), '2023-10-31')),
            '/product/' + CAST(CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) AS VARCHAR) + '/',
            CAST(RAND(CHECKSUM(NEWID())) * 300 + 30 AS INT),
            CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT)
        );
        
        -- Если событие покупки, добавляем заказ
        IF (SELECT event_type FROM ab_test_events WHERE event_id = SCOPE_IDENTITY()) = 'purchase'
        BEGIN
            INSERT INTO ab_test_orders (order_id, test_id, order_amount, items_count, conversion_time)
            VALUES (
                @test_id * 1000 + @k,
                @test_id,
                CAST(RAND(CHECKSUM(NEWID())) * 500 + 20 AS DECIMAL(10,2)),
                CAST(RAND(CHECKSUM(NEWID())) * 3 + 1 AS INT),
                CAST(RAND(CHECKSUM(NEWID())) * 1800 + 300 AS INT)  -- 5-35 минут
            );
        END;
        
        SET @k = @k + 1;
    END;
    
    SET @j = @j + 1;
END;
GO

-- Корректируем конверсию для лучших результатов variant группы
UPDATE ab_test_events
SET event_type = 'purchase'
WHERE event_id IN (
    SELECT TOP 300 e.event_id
    FROM ab_test_events e
    JOIN ab_test_users u ON e.test_id = u.test_id
    WHERE u.group_name = 'variant' 
        AND e.event_type = 'add_to_cart'
        AND CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 40
);
GO