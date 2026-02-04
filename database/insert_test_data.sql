SET IDENTITY_INSERT users ON;

-- Вставляем пользователей
    SELECT TOP 500 
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) as n
    FROM sys.all_columns a
    CROSS JOIN sys.all_columns b
)
INSERT INTO users (user_id, email, registration_date, country, city, age, gender)
SELECT 
    n,
    'user_' + CAST(n AS VARCHAR) + '@email.com',
    DATEADD(DAY, CAST(RAND(CHECKSUM(NEWID())) * 365 AS INT), '2023-01-01'),
    CASE 
        WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 60 THEN 'Russia'
        WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 80 THEN 'USA'
        ELSE 'Kazakhstan'
    END,
    CASE 
        WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 30 THEN 'Moscow'
        WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 50 THEN 'Saint-Petersburg'
        ELSE 'Almaty'
    END,
    18 + CAST(RAND(CHECKSUM(NEWID())) * 50 AS INT),
    CASE 
        WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 45 THEN 'male'
        WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 90 THEN 'female'
        ELSE 'other'
    END
FROM Numbers;

SET IDENTITY_INSERT users OFF;
GO

-- Маркетинговые касания
DECLARE @i INT = 1;
WHILE @i <= 1000
BEGIN
    INSERT INTO marketing_touch (user_id, touch_date, channel, campaign_name, device_type, ad_cost)
    VALUES (
        CAST(RAND(CHECKSUM(NEWID())) * 499 + 1 AS INT),
        DATEADD(DAY, -CAST(RAND(CHECKSUM(NEWID())) * 180 AS INT), GETDATE()),
        CASE 
            WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 25 THEN 'context_ads'
            WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 45 THEN 'social_media_a'
            WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 65 THEN 'social_media_b'
            WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 85 THEN 'email'
            ELSE 'referral'
        END,
        'campaign_' + CAST(CAST(RAND(CHECKSUM(NEWID())) * 5 + 1 AS INT) AS VARCHAR),
        CASE 
            WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 60 THEN 'mobile'
            WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 90 THEN 'desktop'
            ELSE 'tablet'
        END,
        CAST(RAND(CHECKSUM(NEWID())) * 50 AS DECIMAL(10,2))
    );
    SET @i = @i + 1;
END;
GO

-- Товары
SET IDENTITY_INSERT products ON;

INSERT INTO products (product_id, product_name, category, price, cost)
VALUES
    (1, 'iPhone 14 Pro', 'electronics', 999.99, 650.00),
    (2, 'Samsung Galaxy S23', 'electronics', 849.99, 550.00),
    (3, 'MacBook Air M2', 'electronics', 1199.99, 850.00),
    (4, 'Sony WH-1000XM5', 'electronics', 349.99, 200.00),
    (5, 'Nike Air Max 270', 'clothing', 149.99, 60.00),
    (6, 'Adidas Ultraboost', 'clothing', 179.99, 70.00),
    (7, 'Levi''s 501 Jeans', 'clothing', 89.99, 35.00),
    (8, 'Zara T-shirt', 'clothing', 29.99, 12.00),
    (9, 'Harry Potter Complete Set', 'books', 99.99, 40.00),
    (10, 'Atomic Habits by James Clear', 'books', 19.99, 8.00),
    (11, 'Dune by Frank Herbert', 'books', 24.99, 10.00),
    (12, 'IKEA Markus Chair', 'home', 199.99, 120.00),
    (13, 'Philips Hue Starter Kit', 'home', 199.99, 110.00),
    (14, 'KitchenAid Mixer', 'home', 429.99, 280.00),
    (15, 'Nespresso Vertuo', 'home', 179.99, 100.00),
    (16, 'Apple Watch Series 8', 'electronics', 399.99, 250.00),
    (17, 'Canon EOS R6', 'electronics', 2499.99, 1800.00),
    (18, 'The North Face Jacket', 'clothing', 229.99, 110.00),
    (19, 'Python Crash Course', 'books', 34.99, 15.00),
    (20, 'Instant Pot Duo', 'home', 99.99, 55.00);

SET IDENTITY_INSERT products OFF;
GO

-- Сессии
SET NOCOUNT ON;
DECLARE @j INT = 1;
WHILE @j <= 1500
BEGIN
    INSERT INTO sessions (user_id, session_date, session_duration, pages_viewed, traffic_source)
    VALUES (
        CAST(RAND(CHECKSUM(NEWID())) * 499 + 1 AS INT),
        DATEADD(DAY, -CAST(RAND(CHECKSUM(NEWID())) * 90 AS INT), GETDATE()),
        CAST(RAND(CHECKSUM(NEWID())) * 1800 + 30 AS INT),
        CAST(RAND(CHECKSUM(NEWID())) * 20 + 1 AS INT),
        CASE 
            WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 30 THEN 'direct'
            WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 50 THEN 'organic'
            WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 70 THEN 'social'
            WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 90 THEN 'email'
            ELSE 'referral'
        END
    );
    SET @j = @j + 1;
END;
SET NOCOUNT OFF;
GO

-- Заказы
CREATE TABLE #temp_users_with_orders (
    user_id INT,
    order_date DATETIME,
    status VARCHAR(20)
);

INSERT INTO #temp_users_with_orders
SELECT TOP 350 
    user_id,
    DATEADD(DAY, -CAST(RAND(CHECKSUM(NEWID())) * 180 AS INT), GETDATE()) as order_date,
    CASE 
        WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 95 THEN 'completed'
        WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 98 THEN 'cancelled'
        ELSE 'returned'
    END as status
FROM users
WHERE CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 70;

-- Создаем заказы
DECLARE @user_id INT;
DECLARE @status VARCHAR(20);
DECLARE @order_date DATETIME;
DECLARE @num_orders INT;
DECLARE @k INT;

DECLARE user_cursor CURSOR FOR 
SELECT user_id, order_date, status FROM #temp_users_with_orders;

OPEN user_cursor;
FETCH NEXT FROM user_cursor INTO @user_id, @order_date, @status;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @num_orders = CAST(RAND(CHECKSUM(NEWID())) * 3 + 1 AS INT);
    SET @k = 1;
    
    WHILE @k <= @num_orders
    BEGIN
        INSERT INTO orders (user_id, order_date, status, total_amount, discount)
        VALUES (
            @user_id,
            DATEADD(DAY, -@k * 7, @order_date), -- заказы разнесены по времени
            @status,
            CAST(RAND(CHECKSUM(NEWID())) * 500 + 20 AS DECIMAL(10,2)),
            CASE 
                WHEN CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 30 
                THEN CAST(RAND(CHECKSUM(NEWID())) * 50 AS DECIMAL(10,2))
                ELSE 0 
            END
        );
        SET @k = @k + 1;
    END;
    
    FETCH NEXT FROM user_cursor INTO @user_id, @order_date, @status;
END;

CLOSE user_cursor;
DEALLOCATE user_cursor;
DROP TABLE #temp_users_with_orders;
GO

-- Позиции заказов
INSERT INTO order_items (order_id, product_id, quantity, price, cost)
SELECT 
    o.order_id,
    p.product_id,
    CAST(RAND(CHECKSUM(NEWID())) * 3 + 1 AS INT) as quantity,
    p.price,
    p.cost
FROM orders o
CROSS APPLY (
    SELECT TOP (CAST(RAND(CHECKSUM(NEWID())) * 3 + 1 AS INT)) 
        product_id, price, cost 
    FROM products 
    ORDER BY NEWID()
) p
WHERE CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 90;
GO

-- Обновляем total_amount в orders на основе реальных сумм
UPDATE o
SET total_amount = COALESCE((
    SELECT SUM(oi.price * oi.quantity)
    FROM order_items oi
    WHERE oi.order_id = o.order_id
), 0) - o.discount
FROM orders o
WHERE EXISTS (
    SELECT 1 
    FROM order_items oi 
    WHERE oi.order_id = o.order_id
);
GO

-- Маркетинговые затраты
DECLARE @start_date DATE = '2023-01-01';
DECLARE @end_date DATE = '2023-12-31';
DECLARE @current_date DATE = @start_date;
DECLARE @channels TABLE (channel VARCHAR(50));
INSERT INTO @channels VALUES 
    ('context_ads'), 
    ('social_media_a'), 
    ('social_media_b'), 
    ('email'), 
    ('referral');

WHILE @current_date <= @end_date
BEGIN
    INSERT INTO marketing_costs (channel, cost_date, impressions, clicks, total_cost)
    SELECT 
        c.channel,
        @current_date,
        CAST(10000 + RAND(CHECKSUM(NEWID())) * 50000 AS INT),
        CAST(500 + RAND(CHECKSUM(NEWID())) * 5000 AS INT),
        CAST(100 + RAND(CHECKSUM(NEWID())) * 2000 AS DECIMAL(10,2))
    FROM @channels c
    WHERE CAST(RAND(CHECKSUM(NEWID())) * 100 AS INT) < 80;
    
    SET @current_date = DATEADD(DAY, 1, @current_date);
END;
GO