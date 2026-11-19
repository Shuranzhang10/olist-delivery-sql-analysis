-- =====================================================
-- 05_delay_vs_reviews.sql
-- Research question 1:
--   How does late delivery relate to customer review scores?
-- delay_days = actual delivery date - promised (estimated) delivery date
-- =====================================================

-- 1. Review score by delay bucket
SELECT CASE
           WHEN delay_days <= 0  THEN '0. on time / early'
           WHEN delay_days <= 3  THEN '1. 1-3 days late'
           WHEN delay_days <= 7  THEN '2. 4-7 days late'
           WHEN delay_days <= 14 THEN '3. 8-14 days late'
           ELSE                       '4. 15+ days late'
       END                                                  AS delay_bucket,
       COUNT(*)                                             AS n_orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)   AS share_pct,
       ROUND(AVG(review_score), 2)                          AS avg_review,
       ROUND(100.0 * AVG((review_score <= 2)::int), 1)      AS pct_1_2_stars,
       ROUND(100.0 * AVG((review_score = 5)::int), 1)       AS pct_5_stars
FROM v_delivered_orders
WHERE review_score IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- 2. Statistical test: Welch's two-sample t-test (late vs on time), computed in SQL
WITH g AS (
    SELECT (delay_days > 0)         AS is_late,
           COUNT(*)                 AS n,
           AVG(review_score)        AS mean,
           VAR_SAMP(review_score)   AS var
    FROM v_delivered_orders
    WHERE review_score IS NOT NULL
    GROUP BY 1
),
w AS (
    SELECT l.n AS n_late,   l.mean AS mean_late,   l.var AS var_late,
           o.n AS n_ontime, o.mean AS mean_ontime, o.var AS var_ontime
    FROM g l, g o
    WHERE l.is_late AND NOT o.is_late
)
SELECT n_ontime, n_late,
       ROUND(mean_ontime, 3)                                   AS mean_ontime,
       ROUND(mean_late, 3)                                     AS mean_late,
       ROUND(mean_ontime - mean_late, 3)                       AS diff,
       ROUND(SQRT(var_ontime / n_ontime + var_late / n_late), 4) AS std_error,
       ROUND((mean_ontime - mean_late)
             / SQRT(var_ontime / n_ontime + var_late / n_late), 1) AS t_statistic,
       ROUND(mean_ontime - mean_late - 1.96 * SQRT(var_ontime / n_ontime + var_late / n_late), 3) AS ci95_low,
       ROUND(mean_ontime - mean_late + 1.96 * SQRT(var_ontime / n_ontime + var_late / n_late), 3) AS ci95_high
FROM w;
-- With thousands of observations per group the t distribution is ~normal,
-- so 1.96 gives an approximate 95% confidence interval.

-- 3. Robustness check: is the gap driven by region? Compare within each state.
--    (Stratified analysis - controls for state as a possible confounder.)
WITH s AS (
    SELECT customer_state,
           AVG(review_score) FILTER (WHERE delay_days <= 0) AS avg_ontime,
           AVG(review_score) FILTER (WHERE delay_days > 0)  AS avg_late,
           COUNT(*) FILTER (WHERE delay_days > 0)           AS n_late,
           COUNT(*)                                         AS n_total
    FROM v_delivered_orders
    WHERE review_score IS NOT NULL
    GROUP BY customer_state
)
SELECT customer_state, n_total, n_late,
       ROUND(avg_ontime, 2)            AS avg_ontime,
       ROUND(avg_late, 2)              AS avg_late,
       ROUND(avg_ontime - avg_late, 2) AS gap
FROM s
WHERE n_late >= 100
ORDER BY n_total DESC;

-- 4. Correlation between delay (days) and review score, among late orders
SELECT ROUND(CORR(delay_days, review_score)::numeric, 3) AS pearson_r_late_orders
FROM v_delivered_orders
WHERE delay_days > 0 AND review_score IS NOT NULL;
