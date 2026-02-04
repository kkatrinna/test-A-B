-- =============================================
-- ПРОВЕРКА КОРРЕКТНОСТИ A/B ТЕСТА
-- =============================================

USE marketing_analysis;
GO

-- 1. Проверка равномерности разбиения
PRINT '=== 1. РАВНОМЕРНОСТЬ РАЗБИЕНИЯ ПО ГРУППАМ ===';
SELECT 
    group_name,
    COUNT(DISTINCT test_id) as users_count,
    CAST(COUNT(DISTINCT test_id) AS FLOAT) / SUM(COUNT(DISTINCT test_id)) OVER () * 100 as percent_of_total,
    AVG(DATEDIFF(DAY, assignment_date, GETDATE())) as avg_days_in_test
FROM ab_test_users
GROUP BY group_name;
GO

-- 2. Проверка распределения по устройствам и браузерам
PRINT '=== 2. РАСПРЕДЕЛЕНИЕ ПО УСТРОЙСТВАМ И БРАУЗЕРАМ ===';
SELECT 
    group_name,
    device_type,
    browser,
    COUNT(DISTINCT test_id) as users_count,
    ROUND(CAST(COUNT(DISTINCT test_id) AS FLOAT) / SUM(COUNT(DISTINCT test_id)) OVER (PARTITION BY group_name) * 100, 2) as percent_in_group
FROM ab_test_users
GROUP BY group_name, device_type, browser
ORDER BY group_name, users_count DESC;
GO

-- 3. Проверка временного распределения
PRINT '=== 3. РАСПРЕДЕЛЕНИЕ ПО ДНЯМ НЕДЕЛИ И ВРЕМЕНИ СУТОК ===';
SELECT 
    group_name,
    DATENAME(WEEKDAY, assignment_date) as weekday,
    DATEPART(HOUR, assignment_date) as hour_of_day,
    COUNT(DISTINCT test_id) as users_assigned
FROM ab_test_users
GROUP BY group_name, DATENAME(WEEKDAY, assignment_date), DATEPART(HOUR, assignment_date)
ORDER BY group_name, weekday, hour_of_day;
GO

-- 4. Проверка на пересечение пользователей (не должно быть)
PRINT '=== 4. ПРОВЕРКА НА ПОВТОРНОЕ НАЗНАЧЕНИЕ ===';
WITH user_assignments AS (
    SELECT 
        user_id,
        COUNT(DISTINCT group_name) as groups_assigned
    FROM ab_test_users
    GROUP BY user_id
    HAVING COUNT(DISTINCT group_name) > 1
)
SELECT 
    COUNT(*) as users_with_multiple_assignments
FROM user_assignments;
GO

-- 5. Проверка достаточности данных
PRINT '=== 5. ДОСТАТОЧНОСТЬ ДАННЫХ ДЛЯ АНАЛИЗА ===';
SELECT 
    group_name,
    COUNT(DISTINCT au.test_id) as total_users,
    COUNT(DISTINCT CASE WHEN ae.event_type = 'page_view' THEN au.test_id END) as users_with_pageviews,
    COUNT(DISTINCT CASE WHEN ae.event_type = 'add_to_cart' THEN au.test_id END) as users_with_cart_adds,
    COUNT(DISTINCT CASE WHEN ae.event_type = 'purchase' THEN au.test_id END) as users_with_purchases,
    COUNT(DISTINCT ao.order_id) as total_orders,
    SUM(ao.order_amount) as total_revenue
FROM ab_test_users au
LEFT JOIN ab_test_events ae ON au.test_id = ae.test_id
LEFT JOIN ab_test_orders ao ON au.test_id = ao.test_id
GROUP BY group_name;
GO