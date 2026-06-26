-- New customer cohort repurchase.
-- Purpose: evaluate whether acquisition brings long-term value.

WITH first_order AS (
    SELECT
        user_id,
        MIN(dt) AS first_pay_dt
    FROM analytics.fact_order_daily
    WHERE industry = :industry
      AND pay_gmv > 0
    GROUP BY user_id
),
cohort_users AS (
    SELECT
        user_id,
        first_pay_dt,
        DATE_TRUNC('week', first_pay_dt) AS cohort_week
    FROM first_order
    WHERE first_pay_dt BETWEEN :cohort_start_date AND :cohort_end_date
),
repurchase AS (
    SELECT
        c.cohort_week,
        c.user_id,
        MAX(CASE
            WHEN o.dt > c.first_pay_dt
             AND o.dt <= DATE_ADD(c.first_pay_dt, INTERVAL '14' DAY)
            THEN 1 ELSE 0
        END) AS repurchase_14d,
        MAX(CASE
            WHEN o.dt > c.first_pay_dt
             AND o.dt <= DATE_ADD(c.first_pay_dt, INTERVAL '30' DAY)
            THEN 1 ELSE 0
        END) AS repurchase_30d,
        SUM(CASE
            WHEN o.dt > c.first_pay_dt
             AND o.dt <= DATE_ADD(c.first_pay_dt, INTERVAL '30' DAY)
            THEN o.pay_gmv ELSE 0
        END) AS repurchase_30d_gmv
    FROM cohort_users c
    LEFT JOIN analytics.fact_order_daily o
        ON c.user_id = o.user_id
       AND o.industry = :industry
    GROUP BY c.cohort_week, c.user_id
)
SELECT
    cohort_week,
    COUNT(DISTINCT user_id) AS new_user_cnt,
    SUM(repurchase_14d) AS repurchase_14d_user_cnt,
    SUM(repurchase_30d) AS repurchase_30d_user_cnt,
    SUM(repurchase_14d) * 1.0 / NULLIF(COUNT(DISTINCT user_id), 0) AS repurchase_14d_rate,
    SUM(repurchase_30d) * 1.0 / NULLIF(COUNT(DISTINCT user_id), 0) AS repurchase_30d_rate,
    SUM(repurchase_30d_gmv) AS repurchase_30d_gmv
FROM repurchase
GROUP BY cohort_week
ORDER BY cohort_week;
