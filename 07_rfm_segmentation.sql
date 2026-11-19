-- =====================================================
-- 07_rfm_segmentation.sql
-- RFM customer segmentation (Recency, Frequency, Monetary).
-- Reference date = day after the last order in the analysis window.
-- Because ~97% of customers buy only once, Frequency is scored as
-- 1 (one order) vs 2+ (repeat) instead of quintiles.
-- =====================================================

WITH customer_stats AS (
    SELECT c.customer_unique_id,
           MAX(o.order_purchase_timestamp)::date AS last_order_date,
           COUNT(DISTINCT o.order_id)            AS frequency,
           SUM(p.payment_value)                  AS monetary
    FROM orders o
    JOIN customers c      ON c.customer_id = o.customer_id
    JOIN order_payments p ON p.order_id = o.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp < '2018-09-01'
    GROUP BY c.customer_unique_id
),
scored AS (
    SELECT *,
           DATE '2018-09-01' - last_order_date               AS recency_days,
           NTILE(5) OVER (ORDER BY last_order_date)           AS r_score,  -- 5 = most recent
           CASE WHEN frequency > 1 THEN 2 ELSE 1 END          AS f_score,
           NTILE(5) OVER (ORDER BY monetary)                  AS m_score   -- 5 = highest spend
    FROM customer_stats
),
segmented AS (
    SELECT *,
           CASE
               WHEN f_score = 2 AND r_score >= 4                 THEN 'Loyal - active'
               WHEN f_score = 2                                  THEN 'Loyal - lapsing'
               WHEN r_score >= 4 AND m_score >= 4                THEN 'New high-value'
               WHEN r_score >= 4                                 THEN 'New low-value'
               WHEN r_score = 3                                  THEN 'At risk'
               WHEN m_score >= 4                                 THEN 'Lost high-value'
               ELSE                                                   'Lost low-value'
           END AS segment
    FROM scored
)
SELECT segment,
       COUNT(*)                                            AS n_customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)  AS customer_share_pct,
       ROUND(AVG(recency_days), 0)                         AS avg_recency_days,
       ROUND(AVG(frequency), 2)                            AS avg_orders,
       ROUND(AVG(monetary), 2)                             AS avg_spend_brl,
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS revenue_share_pct
FROM segmented
GROUP BY segment
ORDER BY revenue_share_pct DESC;
