-- =====================================================
-- 02_load_data.sql
-- Load raw CSVs into the tables created in 01.
-- CSV files are expected in /Users/Shared/olist_data/
-- (a folder the PostgreSQL server process is allowed to read on macOS).
-- =====================================================

COPY customers            FROM '/Users/Shared/olist_data/olist_customers_dataset.csv'           WITH (FORMAT csv, HEADER true);
COPY sellers              FROM '/Users/Shared/olist_data/olist_sellers_dataset.csv'             WITH (FORMAT csv, HEADER true);
COPY products             FROM '/Users/Shared/olist_data/olist_products_dataset.csv'            WITH (FORMAT csv, HEADER true);
COPY category_translation FROM '/Users/Shared/olist_data/product_category_name_translation.csv' WITH (FORMAT csv, HEADER true);
COPY orders               FROM '/Users/Shared/olist_data/olist_orders_dataset.csv'              WITH (FORMAT csv, HEADER true);
COPY order_items          FROM '/Users/Shared/olist_data/olist_order_items_dataset.csv'         WITH (FORMAT csv, HEADER true);
COPY order_payments       FROM '/Users/Shared/olist_data/olist_order_payments_dataset.csv'      WITH (FORMAT csv, HEADER true);
COPY order_reviews        FROM '/Users/Shared/olist_data/olist_order_reviews_dataset.csv'       WITH (FORMAT csv, HEADER true);
COPY geolocation          FROM '/Users/Shared/olist_data/olist_geolocation_dataset.csv'         WITH (FORMAT csv, HEADER true);

-- Sanity check: row count of every table
SELECT 'customers' AS table_name, COUNT(*) AS n_rows FROM customers
UNION ALL SELECT 'sellers',              COUNT(*) FROM sellers
UNION ALL SELECT 'products',             COUNT(*) FROM products
UNION ALL SELECT 'category_translation', COUNT(*) FROM category_translation
UNION ALL SELECT 'orders',               COUNT(*) FROM orders
UNION ALL SELECT 'order_items',          COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments',       COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews',        COUNT(*) FROM order_reviews
UNION ALL SELECT 'geolocation',          COUNT(*) FROM geolocation;
