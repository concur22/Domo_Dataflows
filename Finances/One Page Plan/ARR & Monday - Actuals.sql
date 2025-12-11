WITH base AS (
    SELECT
        -- normalize to first of month
        DATE_SUB(`Month`, INTERVAL DAYOFMONTH(`Month`) - 1 DAY) AS month_start,
        `Type`,
        `Product Group`,
        `Product Type`,
        `Value`
    FROM `ARR & Bookings - Actual Data`
),

-- Ending ARR by month
ending_arr AS (
    SELECT
        month_start,
        SUM(Value) AS ending_arr
    FROM base
    WHERE `Type` = 'Ending ARR'
    GROUP BY month_start
),

-- Ending Software, Housing ARR by month
software_ending_arr AS (
    SELECT
        month_start,
        SUM(Value) AS software_ending_arr
    FROM base
    WHERE `Type` = 'Ending ARR'
        AND `Product Group` = 'Housing'
        AND `Product Type` = 'Software'
    GROUP BY month_start
),

-- Upsell & churn by month (for NRR)
upsell_churn_monthly AS (
    SELECT
        month_start,
        SUM(Value) AS upsell_churn
    FROM base
    WHERE `Type` NOT IN ('Beginning ARR', 'Ending ARR', 'New Logo')
        AND `Product Group` = 'Housing'
        AND `Product Type` = 'Software'
    GROUP BY month_start
),

-- 12-month rolling upsell & churn (for NRR)
rolling_upsell AS (
    SELECT
        month_start,
        SUM(upsell_churn) OVER (
            ORDER BY month_start
            ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
        ) AS upsell_churn_12m
    FROM upsell_churn_monthly
),

-- Churn only by month (for GRR)
churn_monthly AS (
    SELECT
        month_start,
        SUM(Value) AS churn
    FROM base
    WHERE `Type` IN ('Downsell', 'Lost')
        AND `Product Group` = 'Housing'
        AND `Product Type` = 'Software'
    GROUP BY month_start
),

-- 12-month rolling churn (for GRR)
rolling_churn AS (
    SELECT
        month_start,
        SUM(churn) OVER (
            ORDER BY month_start
            ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
        ) AS churn_12m
    FROM churn_monthly
),

-- NRR components and NRR per month
nrr_calc AS (
    SELECT
        cur.month_start,
        py.software_ending_arr AS software_prior_year_arr,
        ru.upsell_churn_12m,
        (py.software_ending_arr + ru.upsell_churn_12m) / NULLIF(py.software_ending_arr, 0) AS nrr
    FROM software_ending_arr cur
    JOIN software_ending_arr py
        ON py.month_start = DATE_SUB(cur.month_start, INTERVAL 12 MONTH)
    LEFT JOIN rolling_upsell ru
        ON ru.month_start = cur.month_start
),

-- GRR components and GRR per month
grr_calc AS (
    SELECT
        cur.month_start,
        py.software_ending_arr AS prior_year_arr,
        rc.churn_12m,
        (py.software_ending_arr + rc.churn_12m) / NULLIF(py.software_ending_arr, 0) AS grr
    FROM software_ending_arr cur
    JOIN software_ending_arr py
        ON py.month_start = DATE_SUB(cur.month_start, INTERVAL 12 MONTH)
    LEFT JOIN rolling_churn rc
        ON rc.month_start = cur.month_start
)

-- FINAL OUTPUT --
SELECT 
    'Annual Recurring Revenue' AS `Metric Group`,
    'Adaptive' AS `Data Source`,
    e.month_start AS `Month`,
    'ARR' AS `Metric`,
    e.ending_arr AS `Actual Value`
FROM ending_arr e

UNION ALL

SELECT 
    'Annual Recurring Revenue' AS `Metric Group`,
    'Adaptive' AS `Data Source`,
    month_start AS `Month`,
    'On-Campus ARR' AS `Metric`,
    SUM(Value) AS `Actual Value`
FROM base
WHERE `Type` = 'Ending ARR'
  AND `Product Group` <> 'College Pads'
GROUP BY month_start

UNION ALL

SELECT 
    'Annual Recurring Revenue' AS `Metric Group`,
    'Adaptive' AS `Data Source`,
    month_start AS `Month`,
    'Off-Campus ARR' AS `Metric`,
    SUM(Value) AS `Actual Value`
FROM base
WHERE `Type` = 'Ending ARR'
  AND `Product Group` = 'College Pads'
GROUP BY month_start

UNION ALL

SELECT
    'Annual Recurring Revenue' AS `Metric Group`,
    'Adaptive' AS `Data Source`,
    month_start AS `Month`,
    'NRR' AS `Metric`,
    nrr AS `Actual Value`
FROM nrr_calc

UNION ALL

SELECT
    'Annual Recurring Revenue' AS `Metric Group`,
    'Adaptive' AS `Data Source`,
    month_start AS `Month`,
    'GRR' AS `Metric`,
    grr AS `Actual Value`
FROM grr_calc

UNION ALL

SELECT
    'Annual Recurring Revenue' AS `Metric Group`,
    'Adaptive' AS `Data Source`,
    month_start AS `Month`,
    'Software ARR' AS `Metric`,
    software_ending_arr AS `Actual Value`
FROM software_ending_arr

UNION ALL

SELECT
    'Annual Recurring Revenue' AS `Metric Group`,
    'Adaptive' AS `Data Source`,
    month_start AS `Month`,
    'T12 Upsell/Churn' AS `Metric`,
    upsell_churn_12m AS `Actual Value`
FROM rolling_upsell

UNION ALL

SELECT
    'Annual Recurring Revenue' AS `Metric Group`,
    'Adaptive' AS `Data Source`,
    month_start AS `Month`,
    'T12 Churn' AS `Metric`,
    churn_12m AS `Actual Value`
FROM rolling_churn

UNION ALL

SELECT
    'Annual Recurring Revenue' AS `Metric Group`,
    'Adaptive' AS `Data Source`,
    month_start AS `Month`,
    'Prior Year Software ARR' AS `Metric`,
    prior_year_arr AS `Actual Value`
FROM grr_calc

--------- Monday data ------------
UNION ALL

SELECT 
    CASE 
        WHEN `Metric` = 'Migrations' OR `Metric` LIKE '%Milestones%' THEN 'Bookings'
        WHEN LOWER(`Metric`) LIKE '%nps%' THEN 'Satisfaction & Engagement'
        WHEN `Metric` IN ('AI Enablement', 'AI Enabled Users', 'Z-AI-Factor Callouts', 'AI Adoption') THEN 'StarAI-Ify'
        ELSE 'TBD' 
    END AS `Metric Group`,
    'Monday.com' AS `Data Source`,
    DATE_SUB(`Month`, INTERVAL DAYOFMONTH(`Month`) - 1 DAY) AS `Month`, 
    `Metric`, 
    `Actual` AS `Actual Value` 
FROM `Monday Actuals`

ORDER BY 3 DESC
