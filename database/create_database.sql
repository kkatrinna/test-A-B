USE master;
GO

CREATE DATABASE marketing_analysis;
GO

USE marketing_analysis;
GO

-- 1. Таблица пользователей
CREATE TABLE users (
    user_id INT IDENTITY(1,1) PRIMARY KEY,
    email VARCHAR(100) UNIQUE NOT NULL,
    registration_date DATE NOT NULL,
    country VARCHAR(50),
    city VARCHAR(50),
    age INT,
    gender VARCHAR(10)
);
GO

-- 2. Таблица маркетинговых касаний
CREATE TABLE marketing_touch (
    touch_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT FOREIGN KEY REFERENCES users(user_id),
    touch_date DATETIME NOT NULL,
    channel VARCHAR(50) NOT NULL,
    campaign_name VARCHAR(100),
    device_type VARCHAR(20),
    ad_cost DECIMAL(10,2) DEFAULT 0
);
GO

-- 3. Таблица сессий на сайте
CREATE TABLE sessions (
    session_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT FOREIGN KEY REFERENCES users(user_id),
    session_date DATETIME NOT NULL,
    session_duration INT,
    pages_viewed INT,
    traffic_source VARCHAR(50)
);
GO

-- 4. Таблица товаров
CREATE TABLE products (
    product_id INT IDENTITY(1,1) PRIMARY KEY,
    product_name VARCHAR(200) NOT NULL,
    category VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    cost DECIMAL(10,2) NOT NULL
);
GO

-- 5. Таблица заказов
CREATE TABLE orders (
    order_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT FOREIGN KEY REFERENCES users(user_id),
    order_date DATETIME NOT NULL,
    status VARCHAR(20) DEFAULT 'completed',
    total_amount DECIMAL(10,2) NOT NULL,
    discount DECIMAL(10,2) DEFAULT 0
);
GO

-- 6. Таблица позиций заказа
CREATE TABLE order_items (
    order_item_id INT IDENTITY(1,1) PRIMARY KEY,
    order_id INT FOREIGN KEY REFERENCES orders(order_id),
    product_id INT FOREIGN KEY REFERENCES products(product_id),
    quantity INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    cost DECIMAL(10,2) NOT NULL
);
GO

-- 7. Таблица затрат на маркетинг
CREATE TABLE marketing_costs (
    cost_id INT IDENTITY(1,1) PRIMARY KEY,
    channel VARCHAR(50) NOT NULL,
    cost_date DATE NOT NULL,
    impressions INT,
    clicks INT,
    total_cost DECIMAL(10,2) NOT NULL,
    CONSTRAINT uq_channel_date UNIQUE (channel, cost_date)
);
GO

CREATE INDEX idx_marketing_touch_user_id ON marketing_touch(user_id);
CREATE INDEX idx_marketing_touch_channel ON marketing_touch(channel);
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_date ON orders(order_date);
CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_marketing_costs_channel ON marketing_costs(channel);
GO