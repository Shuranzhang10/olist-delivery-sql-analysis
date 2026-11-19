-- =====================================================
-- 01_create_tables.sql
-- Olist E-commerce Analysis: schema definition
-- Run this while connected to the "olist" database.
-- Foreign keys are added later (03) after data quality checks.
-- =====================================================

DROP TABLE IF EXISTS order_reviews, order_payments, order_items, orders,
    customers, sellers, products, category_translation, geolocation CASCADE;

-- One row per customer per order (customer_id is order-specific).
-- customer_unique_id identifies the real person across orders.
CREATE TABLE customers (
    customer_id              VARCHAR(32) PRIMARY KEY,
    customer_unique_id       VARCHAR(32) NOT NULL,
    customer_zip_code_prefix VARCHAR(5),
    customer_city            TEXT,
    customer_state           CHAR(2)
);

CREATE TABLE sellers (
    seller_id              VARCHAR(32) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(5),
    seller_city            TEXT,
    seller_state           CHAR(2)
);

-- Note: "lenght" is misspelled in the original dataset; kept as-is.
CREATE TABLE products (
    product_id                 VARCHAR(32) PRIMARY KEY,
    product_category_name      TEXT,
    product_name_lenght        INT,
    product_description_lenght INT,
    product_photos_qty         INT,
    product_weight_g           INT,
    product_length_cm          INT,
    product_height_cm          INT,
    product_width_cm           INT
);

CREATE TABLE category_translation (
    product_category_name         TEXT PRIMARY KEY,
    product_category_name_english TEXT
);

CREATE TABLE orders (
    order_id                      VARCHAR(32) PRIMARY KEY,
    customer_id                   VARCHAR(32) NOT NULL,
    order_status                  TEXT,
    order_purchase_timestamp      TIMESTAMP,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

-- One row per item in an order.
CREATE TABLE order_items (
    order_id            VARCHAR(32),
    order_item_id       INT,
    product_id          VARCHAR(32),
    seller_id           VARCHAR(32),
    shipping_limit_date TIMESTAMP,
    price               NUMERIC(10,2),
    freight_value       NUMERIC(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

-- An order can be paid in several parts (e.g. voucher + credit card).
CREATE TABLE order_payments (
    order_id             VARCHAR(32),
    payment_sequential   INT,
    payment_type         TEXT,
    payment_installments INT,
    payment_value        NUMERIC(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);

-- No primary key yet: review_id is NOT unique in the raw data.
-- We will investigate this in the data-cleaning step.
CREATE TABLE order_reviews (
    review_id               VARCHAR(32),
    order_id                VARCHAR(32),
    review_score            SMALLINT,
    review_comment_title    TEXT,
    review_comment_message  TEXT,
    review_creation_date    TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

-- Many rows per zip code; no natural key.
CREATE TABLE geolocation (
    geolocation_zip_code_prefix VARCHAR(5),
    geolocation_lat             DOUBLE PRECISION,
    geolocation_lng             DOUBLE PRECISION,
    geolocation_city            TEXT,
    geolocation_state           CHAR(2)
);
