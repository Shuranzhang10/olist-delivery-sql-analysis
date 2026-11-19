-- =====================================================
-- 04_business_overview.sql
-- Descriptive metrics: sales trend, categories, regional delivery performance.
-- =====================================================

-- 1. Monthly orders, revenue (GMV) and average order value, with month-over-month growth
WITH monthly AS (
    SELECT DATE_TRUNC('month', o.order_purchase_timestamp)::date AS month,
           COUNT(DISTINCT o.order_id)                            AS n_orders,
           SUM(i.price + i.freight_value)                        AS gmv
    FROM orders o
    JOIN order_items i ON i.order_id = o.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY 1
)
SELECT month,
       n_orders,
       ROUND(gmv, 0)                     AS gmv_brl,
       ROUND(gmv / n_orders, 2)          AS avg_order_value,
       ROUND(100.0 * (gmv - LAG(gmv) OVER (ORDER BY month))
             / LAG(gmv) OVER (ORDER BY month), 1) AS gmv_mom_growth_pct
FROM monthly
ORDER BY month;

-- 2. Top 10 product categories by revenue, with their share of total revenue
WITH cat AS (
    SELECT COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
           SUM(i.price)               AS revenue,
           COUNT(DISTINCT i.order_id) AS n_orders
    FROM order_items i
    JOIN orders o   ON o.order_id = i.order_id
    JOIN products p ON p.product_id = i.product_id
    LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY 1
)
SELECT RANK() OVER (ORDER BY revenue DESC)              AS rank,
       category,
       n_orders,
       ROUND(revenue, 0)                                AS revenue_brl,
       ROUND(100.0 * revenue / SUM(revenue) OVER (), 1) AS revenue_share_pct
FROM cat
ORDER BY revenue DESC
LIMIT 10;

-- 3. Delivery performance by customer state (states with >= 500 delivered orders)
SELECT customer_state,
       COUNT(*)                                          AS n_orders,
       ROUND(AVG(delivery_days), 1)                      AS avg_delivery_days,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_days) AS median_delivery_days,
       ROUND(100.0 * AVG((delay_days > 0)::int), 1)      AS late_rate_pct,
       ROUND(AVG(review_score), 2)                       AS avg_review
FROM v_delivered_orders
GROUP BY customer_state
HAVING COUNT(*) >= 500
ORDER BY late_rate_pct DESC;
