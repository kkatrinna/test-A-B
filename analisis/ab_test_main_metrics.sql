USE marketing_analysis;
GO

-- 1. Основные метрики конверсии
PRINT '=== 1. ОСНОВНЫЕ МЕТРИКИ КОНВЕРСИИ ===';
WITH funnel_metrics AS (
    SELECT 
        au.group_name,
        COUNT(DISTINCT au.test_id) as total_users,
        COUNT(DISTINCT CASE WHEN ae.event_type = 'page_view' THEN au.test_id END) as viewed_product,
        COUNT(DISTINCT CASE WHEN ae.event_type = 'add_to_cart' THEN au.test_id END) as added_to_cart,
        COUNT(DISTINCT CASE WHEN ae.event_type = 'purchase' THEN au.test_id END) as made_purchase,
        COUNT(DISTINCT ao.order_id) as total_orders,
        SUM(ao.order_amount) as total_revenue,
        AVG(ao.order_amount) as avg_order_value
    FROM ab_test_users au
    LEFT JOIN ab_test_events ae ON au.test_id = ae.test_id
    LEFT JOIN ab_test_orders ao ON au.test_id = ao.test_id
    GROUP BY au.group_name
)
SELECT 
    group_name,
    total_users,
    viewed_product,
    added_to_cart,
    made_purchase,
    total_orders,
    total_revenue,
    avg_order_value,
    -- Конверсии
    ROUND(CAST(viewed_product AS FLOAT) / total_users * 100, 2) as view_rate_percent,
    ROUND(CAST(added_to_cart AS FLOAT) / viewed_product * 100, 2) as cart_add_rate_percent,
    ROUND(CAST(made_purchase AS FLOAT) / added_to_cart * 100, 2) as purchase_rate_percent,
    ROUND(CAST(made_purchase AS FLOAT) / total_users * 100, 2) as overall_conversion_percent,
    -- Средние значения
    ROUND(total_revenue / total_users, 2) as revenue_per_user,
    ROUND(total_revenue / made_purchase, 2) as revenue_per_paying_user
FROM funnel_metrics
ORDER BY group_name;
GO

-- 2. Статистическая значимость разницы в конверсии
PRINT '=== 2. СТАТИСТИЧЕСКАЯ ЗНАЧИМОСТЬ РАЗНИЦЫ ===';
WITH conversion_rates AS (
    SELECT 
        group_name,
        COUNT(DISTINCT test_id) as sample_size,
        COUNT(DISTINCT CASE WHEN EXISTS (
            SELECT 1 FROM ab_test_events ae 
            WHERE ae.test_id = au.test_id AND ae.event_type = 'purchase'
        ) THEN test_id END) as conversions
    FROM ab_test_users au
    GROUP BY group_name
),
stats AS (
    SELECT 
        *,
        CAST(conversions AS FLOAT) / sample_size as conversion_rate
    FROM conversion_rates
),
pooled AS (
    SELECT 
        SUM(conversions) as total_conversions,
        SUM(sample_size) as total_sample,
        CAST(SUM(conversions) AS FLOAT) / SUM(sample_size) as pooled_probability
    FROM stats
)
SELECT 
    s.group_name,
    s.sample_size,
    s.conversions,
    ROUND(s.conversion_rate * 100, 2) as conversion_rate_percent,
    ROUND(p.pooled_probability * 100, 2) as pooled_rate_percent,
    -- Z-score calculation
    ROUND(
        (s.conversion_rate - 
         (SELECT conversion_rate FROM stats WHERE group_name = 'control')) /
        SQRT(
            p.pooled_probability * (1 - p.pooled_probability) * 
            (1.0/s.sample_size + 1.0/(SELECT sample_size FROM stats WHERE group_name = 'control'))
        ), 4
    ) as z_score
FROM stats s
CROSS JOIN pooled p
ORDER BY s.group_name;
GO

-- 3. Анализ по сегментам пользователей
PRINT '=== 3. АНАЛИЗ ПО СЕГМЕНТАМ ===';
SELECT 
    au.group_name,
    au.device_type,
    au.browser,
    au.traffic_source,
    COUNT(DISTINCT au.test_id) as segment_users,
    COUNT(DISTINCT CASE WHEN ae.event_type = 'purchase' THEN au.test_id END) as segment_conversions,
    ROUND(CAST(COUNT(DISTINCT CASE WHEN ae.event_type = 'purchase' THEN au.test_id END) AS FLOAT) / 
          COUNT(DISTINCT au.test_id) * 100, 2) as segment_conversion_rate,
    SUM(ao.order_amount) as segment_revenue,
    ROUND(AVG(ao.order_amount), 2) as avg_segment_order_value
FROM ab_test_users au
LEFT JOIN ab_test_events ae ON au.test_id = ae.test_id AND ae.event_type = 'purchase'
LEFT JOIN ab_test_orders ao ON au.test_id = ao.test_id
GROUP BY au.group_name, au.device_type, au.browser, au.traffic_source
HAVING COUNT(DISTINCT au.test_id) > 50  -- только значимые сегменты
ORDER BY au.group_name, segment_conversion_rate DESC;
GO

-- 4. Временные метрики
PRINT '=== 4. АНАЛИЗ ВРЕМЕННЫХ МЕТРИК ===';
SELECT 
    au.group_name,
    AVG(ae.session_duration) as avg_session_duration_seconds,
    AVG(ae.scroll_depth) as avg_scroll_depth_percent,
    AVG(ao.conversion_time) as avg_conversion_time_seconds,
    AVG(DATEDIFF(SECOND, 
        (SELECT MIN(event_date) FROM ab_test_events ae2 WHERE ae2.test_id = au.test_id AND ae2.event_type = 'page_view'),
        (SELECT MIN(event_date) FROM ab_test_events ae3 WHERE ae3.test_id = au.test_id AND ae3.event_type = 'purchase')
    )) as avg_time_to_purchase_seconds
FROM ab_test_users au
LEFT JOIN ab_test_events ae ON au.test_id = ae.test_id
LEFT JOIN ab_test_orders ao ON au.test_id = ao.test_id
WHERE EXISTS (SELECT 1 FROM ab_test_events ae4 WHERE ae4.test_id = au.test_id AND ae4.event_type = 'purchase')
GROUP BY au.group_name;
GO