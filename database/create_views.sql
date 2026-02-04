USE marketing_analysis;
GO

-- 1. Представление для анализа эффективности каналов
CREATE VIEW vw_channel_performance AS
WITH customer_first_touch AS (
    SELECT 
        user_id,
        channel,
        touch_date,
        ad_cost,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY touch_date) as rn
    FROM marketing_touch
),
customer_acquisition AS (
    SELECT 
        user_id,
        channel,
        touch_date as acquisition_date,
        ad_cost as cac
    FROM customer_first_touch
    WHERE rn = 1
),
customer_revenue AS (
    SELECT 
        ca.user_id,
        ca.channel,
        COUNT(DISTINCT o.order_id) as orders_count,
        SUM(o.total_amount) as total_revenue_90d,
        AVG(o.total_amount) as avg_order_value
    FROM customer_acquisition ca
    LEFT JOIN orders o ON ca.user_id = o.user_id 
        AND o.status = 'completed'
        AND o.order_date BETWEEN ca.acquisition_date AND DATEADD(DAY, 90, ca.acquisition_date)
    GROUP BY ca.user_id, ca.channel
)
SELECT 
    cr.channel,
    COUNT(DISTINCT ca.user_id) as acquired_customers,
    ROUND(AVG(ca.cac), 2) as avg_cac,
    ROUND(AVG(cr.orders_count), 2) as avg_orders_per_customer,
    ROUND(SUM(cr.total_revenue_90d) / NULLIF(COUNT(DISTINCT ca.user_id), 0), 2) as avg_ltv_90d,
    ROUND(SUM(cr.total_revenue_90d), 2) as total_revenue_90d,
    ROUND(SUM(mc.total_cost), 2) as total_marketing_cost,
    CASE 
        WHEN SUM(mc.total_cost) > 0 
        THEN ROUND((SUM(cr.total_revenue_90d) - SUM(mc.total_cost)) / SUM(mc.total_cost) * 100, 2)
        ELSE NULL 
    END as roi_percent,
    CASE 
        WHEN AVG(ca.cac) > 0 
        THEN ROUND((SUM(cr.total_revenue_90d) / NULLIF(COUNT(DISTINCT ca.user_id), 0)) / AVG(ca.cac), 2)
        ELSE NULL 
    END as ltv_cac_ratio
FROM customer_acquisition ca
LEFT JOIN customer_revenue cr ON ca.user_id = cr.user_id AND ca.channel = cr.channel
LEFT JOIN marketing_costs mc ON ca.channel = mc.channel
    AND mc.cost_date BETWEEN '2023-01-01' AND '2023-12-31'
GROUP BY cr.channel;
GO

-- 2. Представление для ежедневных продаж
CREATE VIEW vw_daily_sales AS
SELECT 
    CAST(o.order_date AS DATE) as sale_date,
    DATEPART(MONTH, o.order_date) as month_num,
    DATENAME(MONTH, o.order_date) as month_name,
    DATEPART(QUARTER, o.order_date) as quarter,
    DATEPART(YEAR, o.order_date) as year,
    mt.channel,
    COUNT(DISTINCT o.order_id) as orders_count,
    COUNT(DISTINCT o.user_id) as unique_customers,
    SUM(o.total_amount) as daily_revenue,
    AVG(o.total_amount) as avg_order_value,
    SUM(mc.total_cost) as daily_marketing_cost,
    SUM(o.total_amount) - SUM(mc.total_cost) as daily_profit
FROM orders o
JOIN (
    SELECT DISTINCT user_id, channel
    FROM marketing_touch mt
    WHERE touch_date = (
        SELECT MIN(touch_date) 
        FROM marketing_touch mt2 
        WHERE mt2.user_id = mt.user_id
    )
) mt ON o.user_id = mt.user_id
LEFT JOIN marketing_costs mc ON mt.channel = mc.channel 
    AND mc.cost_date = CAST(o.order_date AS DATE)
WHERE o.status = 'completed'
GROUP BY 
    CAST(o.order_date AS DATE),
    DATEPART(MONTH, o.order_date),
    DATENAME(MONTH, o.order_date),
    DATEPART(QUARTER, o.order_date),
    DATEPART(YEAR, o.order_date),
    mt.channel;
GO

-- 3. Представление для анализа клиентов 
CREATE VIEW vw_customer_rfm AS
WITH customer_stats AS (
    SELECT 
        u.user_id,
        u.registration_date,
        u.country,
        u.city,
        u.age,
        u.gender,
        mt.channel as acquisition_channel,
        COUNT(DISTINCT o.order_id) as total_orders,
        SUM(o.total_amount) as total_revenue,
        MAX(o.order_date) as last_order_date,
        DATEDIFF(DAY, MIN(o.order_date), MAX(o.order_date)) as customer_lifetime_days
    FROM users u
    LEFT JOIN marketing_touch mt ON u.user_id = mt.user_id
        AND mt.touch_date = (
            SELECT MIN(touch_date) 
            FROM marketing_touch 
            WHERE user_id = u.user_id
        )
    LEFT JOIN orders o ON u.user_id = o.user_id 
        AND o.status = 'completed'
    GROUP BY 
        u.user_id, u.registration_date, u.country, u.city, 
        u.age, u.gender, mt.channel
),
rfm_calc AS (
    SELECT 
        *,
        NTILE(5) OVER (ORDER BY last_order_date DESC) as recency_score,
        NTILE(5) OVER (ORDER BY total_orders) as frequency_score,
        NTILE(5) OVER (ORDER BY total_revenue) as monetary_score,
        (NTILE(5) OVER (ORDER BY last_order_date DESC) * 100) + 
        (NTILE(5) OVER (ORDER BY total_orders) * 10) + 
        NTILE(5) OVER (ORDER BY total_revenue) as rfm_cell
    FROM customer_stats
    WHERE last_order_date IS NOT NULL
)
SELECT 
    *,
    CASE 
        WHEN rfm_cell IN (555, 554, 545, 544, 455, 454, 445, 444) THEN 'Champions'
        WHEN rfm_cell IN (543, 542, 541, 533, 532, 531, 443, 433, 432, 431) THEN 'Loyal Customers'
        WHEN rfm_cell IN (525, 524, 523, 522, 521, 515, 514, 513, 425, 424, 413) THEN 'Potential Loyalists'
        WHEN rfm_cell IN (335, 334, 325, 324, 315, 314, 313, 235, 234, 225, 224) THEN 'New Customers'
        WHEN rfm_cell IN (155, 154, 144, 135, 134, 125, 124) THEN 'Promising'
        WHEN rfm_cell IN (331, 321, 312, 221, 213) THEN 'Need Attention'
        WHEN rfm_cell IN (255, 254, 245, 244, 253, 252, 243, 242, 235, 234, 225) THEN 'About To Sleep'
        ELSE 'At Risk'
    END as rfm_segment
FROM rfm_calc;
GO

-- 4. Представление для анализа продуктов
CREATE VIEW vw_product_performance AS
SELECT 
    p.product_id,
    p.product_name,
    p.category,
    p.price,
    p.cost,
    ROUND(p.price - p.cost, 2) as margin_per_unit,
    ROUND((p.price - p.cost) / p.price * 100, 2) as margin_percent,
    COUNT(DISTINCT oi.order_id) as times_ordered,
    SUM(oi.quantity) as total_quantity_sold,
    SUM(oi.quantity * oi.price) as total_revenue,
    SUM(oi.quantity * (oi.price - oi.cost)) as total_profit,
    ROUND(AVG(oi.quantity), 2) as avg_quantity_per_order,
    ROW_NUMBER() OVER (PARTITION BY p.category ORDER BY SUM(oi.quantity * oi.price) DESC) as rank_in_category
FROM products p
LEFT JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id AND o.status = 'completed'
GROUP BY 
    p.product_id, p.product_name, p.category, 
    p.price, p.cost;
GO

-- 5. Представление для воронки продаж
CREATE VIEW vw_sales_funnel AS
WITH funnel_base AS (
    SELECT 
        mt.channel,
        mt.user_id,
        MIN(mt.touch_date) as first_touch,
        MIN(s.session_date) as first_session,
        MIN(o.order_date) as first_order
    FROM marketing_touch mt
    LEFT JOIN sessions s ON mt.user_id = s.user_id 
        AND s.session_date >= mt.touch_date
        AND s.session_date <= DATEADD(DAY, 7, mt.touch_date)
    LEFT JOIN orders o ON mt.user_id = o.user_id 
        AND o.status = 'completed'
        AND o.order_date >= mt.touch_date
        AND o.order_date <= DATEADD(DAY, 30, mt.touch_date)
    GROUP BY mt.channel, mt.user_id
)
SELECT 
    channel,
    COUNT(DISTINCT user_id) as touched_users,
    COUNT(DISTINCT CASE WHEN first_session IS NOT NULL THEN user_id END) as visited_website,
    COUNT(DISTINCT CASE WHEN first_order IS NOT NULL THEN user_id END) as made_purchase,
    ROUND(CAST(COUNT(DISTINCT CASE WHEN first_session IS NOT NULL THEN user_id END) AS FLOAT) / 
          NULLIF(COUNT(DISTINCT user_id), 0) * 100, 2) as visit_rate_percent,
    ROUND(CAST(COUNT(DISTINCT CASE WHEN first_order IS NOT NULL THEN user_id END) AS FLOAT) / 
          NULLIF(COUNT(DISTINCT CASE WHEN first_session IS NOT NULL THEN user_id END), 0) * 100, 2) as conversion_rate_percent
FROM funnel_base
GROUP BY channel;
GO