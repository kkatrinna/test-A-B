USE marketing_analysis;  -- Используем существующую БД или создаем новую
GO

-- Таблица эксперимента (разбивка пользователей на группы)
CREATE TABLE ab_test_experiment (
    experiment_id INT IDENTITY(1,1) PRIMARY KEY,
    experiment_name VARCHAR(100) NOT NULL,
    start_date DATETIME NOT NULL,
    end_date DATETIME NOT NULL,
    target_audience VARCHAR(200),
    hypothesis VARCHAR(500)
);
GO

-- Таблица участников теста
CREATE TABLE ab_test_users (
    test_id INT IDENTITY(1,1) PRIMARY KEY,
    experiment_id INT FOREIGN KEY REFERENCES ab_test_experiment(experiment_id),
    user_id INT NOT NULL,
    group_name VARCHAR(20) NOT NULL,  -- 'control' или 'variant'
    assignment_date DATETIME NOT NULL,
    device_type VARCHAR(20),
    browser VARCHAR(50),
    traffic_source VARCHAR(50)
);
GO

-- Таблица событий пользователей во время теста
CREATE TABLE ab_test_events (
    event_id INT IDENTITY(1,1) PRIMARY KEY,
    test_id INT FOREIGN KEY REFERENCES ab_test_users(test_id),
    event_type VARCHAR(50) NOT NULL,  -- 'page_view', 'add_to_cart', 'purchase', 'scroll'
    event_date DATETIME NOT NULL,
    page_url VARCHAR(200),
    session_duration INT,  -- в секундах
    scroll_depth INT  -- процент прокрутки страницы
);
GO

-- Таблица результатов заказов для теста
CREATE TABLE ab_test_orders (
    order_id INT PRIMARY KEY,  -- связь с основной таблицей orders
    test_id INT FOREIGN KEY REFERENCES ab_test_users(test_id),
    order_amount DECIMAL(10,2),
    items_count INT,
    conversion_time INT  -- время от входа до покупки в секундах
);
GO

-- Индексы для оптимизации
CREATE INDEX idx_ab_test_users_group ON ab_test_users(group_name, experiment_id);
CREATE INDEX idx_ab_test_users_user ON ab_test_users(user_id);
CREATE INDEX idx_ab_test_events_test ON ab_test_events(test_id, event_type);
CREATE INDEX idx_ab_test_events_date ON ab_test_events(event_date);
GO