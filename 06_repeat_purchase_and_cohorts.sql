-- =====================================================
-- 06_repeat_purchase_and_cohorts.sql
-- Research question 2:
--   Are customers whose FIRST order arrived late less likely to buy again?
-- Plus a monthly cohort retention table.
-- Note: customer_unique_id identifies a person; customer_id is per order.
-- =====================================================

-- 1. Overall repeat-purchase rate
WITH per_customer AS (
    SELECT c.customer_unique_id, COUNT(*) AS n_orders
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
)
SELECT COUNT(*)                                  AS n_customers,
       SUM((n_orders > 1)::int)                  AS n_repeat_customers,
       ROUND(100.0 * AVG((n_orders > 1)::int), 2) AS repeat_rate_pct
FROM per_customer;

-- 2. Repeat rate by whether the customer's first order was late
WITH ranked AS (
    SELECT c.customer_unique_id,
           o.order_status,
           o.order_delivered_customer_date,
           o.order_estimated_delivery_date,
           ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id
                              ORDER BY o.order_purchase_timestamp) AS order_rank,
           COUNT(*)     OVER (PARTITION BY c.customer_unique_id)   AS n_orders
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
),
first_orders AS (
    SELECT customer_unique_id,
           order_delivered_customer_date::date > order_estimated_delivery_date::date AS first_order_late,
           (n_orders > 1)::int AS repurchased
    FROM ranked
    WHERE order_rank = 1
      AND order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
),
grp AS (
    SELECT first_order_late,
           COUNT(*)          AS n_customers,
           SUM(repurchased)  AS n_repurchased,
           AVG(repurchased)  AS p
    FROM first_orders
    GROUP BY first_order_late
)
SELECT first_order_late, n_customers, n_repurchased,
       ROUND(100 * p, 2) AS repeat_rate_pct
FROM grp
ORDER BY first_order_late;

-- 3. Two-proportion z-test for the difference above
WITH ranked AS (
    SELECT c.customer_unique_id, o.order_status,
           o.order_delivered_customer_date, o.order_estimated_delivery_date,
           ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id ORDER BY o.order_purchase_timestamp) AS order_rank,
           COUNT(*)     OVER (PARTITION BY c.customer_unique_id) AS n_orders
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
),
f AS (
    SELECT order_delivered_customer_date::date > order_estimated_delivery_date::date AS late,
           (n_orders > 1)::int AS rep
    FROM ranked
    WHERE order_rank = 1 AND order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL
),
s AS (
    SELECT SUM(rep) FILTER (WHERE NOT late)::numeric AS x1, COUNT(*) FILTER (WHERE NOT late)::numeric AS n1,
           SUM(rep) FILTER (WHERE late)::numeric     AS x2, COUNT(*) FILTER (WHERE late)::numeric     AS n2
    FROM f
)
SELECT ROUND(100 * x1 / n1, 2) AS ontime_repeat_pct,
       ROUND(100 * x2 / n2, 2) AS late_repeat_pct,
       ROUND(100 * (1 - (x2 / n2) / (x1 / n1)), 1) AS relative_drop_pct,
       ROUND((x1 / n1 - x2 / n2)
             / SQRT(((x1 + x2) / (n1 + n2)) * (1 - (x1 + x2) / (n1 + n2)) * (1 / n1 + 1 / n2)), 2) AS z_statistic
FROM s;
-- |z| > 1.96 means the difference is significant at the 5% level.

-- 4. Monthly cohort retention: % of each first-purchase cohort that buys again
--    1, 2, 3 ... months later
WITH orders_clean AS (
    SELECT c.customer_unique_id,
           DATE_TRUNC('month', o.order_purchase_timestamp)::date AS order_month
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
),
cohort AS (
    SELECT customer_unique_id, MIN(order_month) AS cohort_month
    FROM orders_clean
    GROUP BY customer_unique_id
),
activity AS (
    SELECT DISTINCT oc.customer_unique_id, ch.cohort_month,
           (EXTRACT(YEAR FROM AGE(oc.order_month, ch.cohort_month)) * 12
            + EXTRACT(MONTH FROM AGE(oc.order_month, ch.cohort_month)))::int AS month_number
    FROM orders_clean oc
    JOIN cohort ch USING (customer_unique_id)
),
cohort_size AS (
    SELECT cohort_month, COUNT(*) AS n_customers
    FROM cohort
    GROUP BY cohort_month
)
SELECT a.cohort_month,
       cs.n_customers,
       ROUND(100.0 * COUNT(*) FILTER (WHERE month_number = 1) / cs.n_customers, 2) AS m1_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE month_number = 2) / cs.n_customers, 2) AS m2_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE month_number = 3) / cs.n_customers, 2) AS m3_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE month_number = 6) / cs.n_customers, 2) AS m6_pct
FROM activity a
JOIN cohort_size cs USING (cohort_month)
WHERE a.cohort_month BETWEEN '2017-01-01' AND '2018-02-01'
GROUP BY a.cohort_month, cs.n_customers
ORDER BY a.cohort_month;
