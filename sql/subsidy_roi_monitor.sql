-- Subsidy ROI monitoring sample.
-- Purpose: compare subsidized performance with a baseline and identify inefficient spend.

WITH campaign_order AS (
    SELECT
        dt,
        campaign_id,
        industry,
        category,
        channel,
        merchant_id,
        SUM(pay_gmv) AS pay_gmv,
        SUM(order_cnt) AS order_cnt,
        SUM(subsidy_amount) AS subsidy_amount,
        COUNT(DISTINCT user_id) AS buyer_cnt
    FROM analytics.fact_campaign_order_daily
    WHERE dt BETWEEN :start_date AND :end_date
      AND industry = :industry
    GROUP BY
        dt, campaign_id, industry, category, channel, merchant_id
),
baseline AS (
    SELECT
        merchant_id,
        channel,
        AVG(pay_gmv) AS baseline_daily_gmv,
        AVG(order_cnt) AS baseline_daily_order_cnt
    FROM analytics.fact_order_daily
    WHERE dt BETWEEN :baseline_start_date AND :baseline_end_date
      AND industry = :industry
    GROUP BY merchant_id, channel
),
joined AS (
    SELECT
        c.dt,
        c.campaign_id,
        c.industry,
        c.category,
        c.channel,
        c.merchant_id,
        c.pay_gmv,
        c.order_cnt,
        c.subsidy_amount,
        c.buyer_cnt,
        COALESCE(b.baseline_daily_gmv, 0) AS baseline_daily_gmv,
        COALESCE(b.baseline_daily_order_cnt, 0) AS baseline_daily_order_cnt
    FROM campaign_order c
    LEFT JOIN baseline b
        ON c.merchant_id = b.merchant_id
       AND c.channel = b.channel
)
SELECT
    dt,
    campaign_id,
    industry,
    category,
    channel,
    SUM(pay_gmv) AS pay_gmv,
    SUM(order_cnt) AS order_cnt,
    SUM(subsidy_amount) AS subsidy_amount,
    SUM(pay_gmv - baseline_daily_gmv) AS incremental_gmv,
    SUM(order_cnt - baseline_daily_order_cnt) AS incremental_order_cnt,
    SUM(pay_gmv - baseline_daily_gmv) / NULLIF(SUM(subsidy_amount), 0) AS incremental_roi,
    SUM(subsidy_amount) / NULLIF(SUM(pay_gmv + subsidy_amount), 0) AS subsidy_rate,
    COUNT(DISTINCT merchant_id) AS merchant_cnt,
    SUM(buyer_cnt) AS buyer_cnt
FROM joined
GROUP BY dt, campaign_id, industry, category, channel
HAVING SUM(subsidy_amount) > 0
ORDER BY dt, campaign_id, channel;
