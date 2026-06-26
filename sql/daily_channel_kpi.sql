-- Daily channel KPI monitoring.


WITH order_base AS (
    SELECT
        dt,
        industry,
        category,
        channel,
        merchant_id,
        user_id,
        SUM(pay_gmv) AS pay_gmv,
        SUM(order_cnt) AS order_cnt,
        SUM(subsidy_amount) AS subsidy_amount
    FROM analytics.fact_order_daily
    WHERE dt BETWEEN :start_date AND :end_date
      AND industry = :industry
    GROUP BY
        dt, industry, category, channel, merchant_id, user_id
),
traffic_base AS (
    SELECT
        dt,
        industry,
        category,
        channel,
        SUM(exposure_cnt) AS exposure_cnt,
        SUM(click_cnt) AS click_cnt,
        SUM(view_cnt) AS view_cnt
    FROM analytics.fact_traffic_daily
    WHERE dt BETWEEN :start_date AND :end_date
      AND industry = :industry
    GROUP BY
        dt, industry, category, channel
),
order_agg AS (
    SELECT
        dt,
        industry,
        category,
        channel,
        SUM(pay_gmv) AS pay_gmv,
        SUM(order_cnt) AS order_cnt,
        COUNT(DISTINCT user_id) AS buyer_cnt,
        COUNT(DISTINCT merchant_id) AS active_merchant_cnt,
        SUM(subsidy_amount) AS subsidy_amount
    FROM order_base
    GROUP BY
        dt, industry, category, channel
)
SELECT
    o.dt,
    o.industry,
    o.category,
    o.channel,
    o.pay_gmv,
    o.order_cnt,
    o.buyer_cnt,
    o.active_merchant_cnt,
    t.exposure_cnt,
    t.click_cnt,
    t.view_cnt,
    o.subsidy_amount,
    o.pay_gmv / NULLIF(t.exposure_cnt, 0) * 1000 AS gpm,
    o.order_cnt / NULLIF(t.exposure_cnt, 0) * 1000 AS opm,
    t.click_cnt / NULLIF(t.exposure_cnt, 0) AS ctr,
    o.order_cnt / NULLIF(t.click_cnt, 0) AS click_to_order_cvr,
    o.pay_gmv / NULLIF(o.order_cnt, 0) AS avg_order_value,
    o.subsidy_amount / NULLIF(o.pay_gmv + o.subsidy_amount, 0) AS subsidy_rate
FROM order_agg o
LEFT JOIN traffic_base t
    ON o.dt = t.dt
   AND o.industry = t.industry
   AND o.category = t.category
   AND o.channel = t.channel;
