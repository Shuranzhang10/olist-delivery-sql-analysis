-- =====================================================
-- 03_data_quality.sql
-- Data quality checks, cleaning decisions, constraints,
-- and a clean analysis view used by later scripts.
-- =====================================================

-- 1. Order status distribution: only 'delivered' orders have a full delivery timeline
SELECT order_status, COUNT(*) AS n_orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM orders
GROUP BY order_status
ORDER BY n_orders DESC;

-- 2. Missing / inconsistent timestamps
SELECT
    COUNT(*) FILTER (WHERE order_approved_at IS NULL)                         AS missing_approval,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL)             AS missing_delivery,
    COUNT(*) FILTER (WHERE order_status = 'delivered'
                       AND order_delivered_customer_date IS NULL)             AS delivered_but_no_date,
    COUNT(*) FILTER (WHERE order_delivered_customer_date < order_purchase_timestamp) AS delivered_before_purchase
FROM orders;

-- 3. Is review_id unique? (No - this is why order_reviews has no primary key yet)
SELECT COUNT(*)                              AS n_rows,
       COUNT(DISTINCT review_id)             AS distinct_review_id,
       COUNT(DISTINCT order_id)              AS distinct_order_id,
       COUNT(DISTINCT (review_id, order_id)) AS distinct_pair
FROM order_reviews;
-- Finding: the same review_id can cover several orders, and some orders have
-- more than one review. (review_id, order_id) is unique, so it becomes the key.

-- How many orders have more than one review?
SELECT COUNT(*) AS orders_with_multiple_reviews
FROM (SELECT order_id FROM order_reviews GROUP BY order_id HAVING COUNT(*) > 1) t;
-- Cleaning rule used in the analysis: keep the most recent review per order.

-- 4. Orphan checks before adding foreign keys (all should be 0)
SELECT 'orders -> customers' AS relation, COUNT(*) AS orphans
  FROM orders o WHERE NOT EXISTS (SELECT 1 FROM customers c WHERE c.customer_id = o.customer_id)
UNION ALL
SELECT 'order_items -> orders', COUNT(*)
  FROM order_items i WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.order_id = i.order_id)
UNION ALL
SELECT 'order_items -> products', COUNT(*)
  FROM order_items i WHERE NOT EXISTS (SELECT 1 FROM products p WHERE p.product_id = i.product_id)
UNION ALL
SELECT 'order_items -> sellers', COUNT(*)
  FROM order_items i WHERE NOT EXISTS (SELECT 1 FROM sellers s WHERE s.seller_id = i.seller_id)
UNION ALL
SELECT 'order_payments -> orders', COUNT(*)
  FROM order_payments p WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.order_id = p.order_id)
UNION ALL
SELECT 'order_reviews -> orders', COUNT(*)
  FROM order_reviews r WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.order_id = r.order_id);

-- 5. Products with no category, and categories missing an English translation
SELECT COUNT(*) AS products_without_category
FROM products WHERE product_category_name IS NULL;

SELECT DISTINCT p.product_category_name AS untranslated_category
FROM products p
LEFT JOIN category_translation t USING (product_category_name)
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL;

-- 6. Coverage over time: months at the edges have very few orders
SELECT DATE_TRUNC('month', order_purchase_timestamp)::date AS month, COUNT(*) AS n_orders
FROM orders
GROUP BY 1
ORDER BY 1;
-- Decision: time-series analysis uses Jan 2017 - Aug 2018 (complete months).

-- =====================================================
-- Constraints (safe to add now that orphan checks return 0)
-- =====================================================
ALTER TABLE order_reviews  DROP CONSTRAINT IF EXISTS order_reviews_pkey;
ALTER TABLE order_reviews  ADD PRIMARY KEY (review_id, order_id);

ALTER TABLE orders         DROP CONSTRAINT IF EXISTS fk_orders_customer;
ALTER TABLE orders         ADD CONSTRAINT fk_orders_customer  FOREIGN KEY (customer_id) REFERENCES customers (customer_id);
ALTER TABLE order_items    DROP CONSTRAINT IF EXISTS fk_items_order;
ALTER TABLE order_items    ADD CONSTRAINT fk_items_order      FOREIGN KEY (order_id)    REFERENCES orders (order_id);
ALTER TABLE order_items    DROP CONSTRAINT IF EXISTS fk_items_product;
ALTER TABLE order_items    ADD CONSTRAINT fk_items_product    FOREIGN KEY (product_id)  REFERENCES products (product_id);
ALTER TABLE order_items    DROP CONSTRAINT IF EXISTS fk_items_seller;
ALTER TABLE order_items    ADD CONSTRAINT fk_items_seller     FOREIGN KEY (seller_id)   REFERENCES sellers (seller_id);
ALTER TABLE order_payments DROP CONSTRAINT IF EXISTS fk_payments_order;
ALTER TABLE order_payments ADD CONSTRAINT fk_payments_order   FOREIGN KEY (order_id)    REFERENCES orders (order_id);
ALTER TABLE order_reviews  DROP CONSTRAINT IF EXISTS fk_reviews_order;
ALTER TABLE order_reviews  ADD CONSTRAINT fk_reviews_order    FOREIGN KEY (order_id)    REFERENCES orders (order_id);

-- Indexes on join columns used throughout the analysis
CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders (customer_id);
CREATE INDEX IF NOT EXISTS idx_customers_unique ON customers (customer_unique_id);
CREATE INDEX IF NOT EXISTS idx_reviews_order ON order_reviews (order_id);

-- =====================================================
-- Clean analysis view: one row per delivered order
-- =====================================================
CREATE OR REPLACE VIEW v_delivered_orders AS
WITH latest_review AS (
    SELECT DISTINCT ON (order_id)
           order_id, review_score
    FROM order_reviews
    ORDER BY order_id, review_answer_timestamp DESC
),
order_value AS (
    SELECT order_id,
           SUM(price)         AS items_value,
           SUM(freight_value) AS freight_value,
           COUNT(*)           AS n_items
    FROM order_items
    GROUP BY order_id
)
SELECT
    o.order_id,
    c.customer_unique_id,
    c.customer_state,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    o.order_delivered_customer_date::date - o.order_purchase_timestamp::date      AS delivery_days,
    o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date AS delay_days,
    v.items_value,
    v.freight_value,
    v.n_items,
    r.review_score
FROM orders o
JOIN customers c        ON c.customer_id = o.customer_id
LEFT JOIN order_value v ON v.order_id = o.order_id
LEFT JOIN latest_review r ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL;

SELECT COUNT(*) AS n_clean_delivered_orders FROM v_delivered_orders;
