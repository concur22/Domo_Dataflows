/* ===========================
   Bookings - Actuals (Salesforce)
   =========================== */

WITH
bookings_base AS (
    SELECT op.`Record Type Name`
         , op.`Order Type`
         , op.`Stage`
         , op.`Close Date`
         , op.`Opportunity ID`
         , op.`Subscription Term`
--         , NULLIF(op.`Subscription Term`, 0) / NULLIF(COUNT(op.`Opportunity Full ID`) OVER (PARTITION BY op.`Opportunity Full ID`), 0) AS "Subscription Term"
         , NULLIF(op.`Total Services Net`, 0) / NULLIF(COUNT(op.`Opportunity Full ID`) OVER (PARTITION BY op.`Opportunity Full ID`), 0) AS "Total Services Net"
         , NULLIF(op.`Total Revenues`, 0) / NULLIF(COUNT(op.`Opportunity Full ID`) OVER (PARTITION BY op.`Opportunity Full ID`), 0) AS "Total Revenues"
         , NULLIF(op.`Total Software Net`, 0) / NULLIF(COUNT(op.`Opportunity Full ID`) OVER (PARTITION BY op.`Opportunity Full ID`), 0) AS "Total Software Net"
         , NULLIF(op.`Total Amount`, 0) / NULLIF(COUNT(op.`Opportunity Full ID`) OVER (PARTITION BY op.`Opportunity Full ID`), 0) AS "Total Amount"
         , NULLIF(op.`Current ARR`, 0) / NULLIF(COUNT(op.`Opportunity Full ID`) OVER (PARTITION BY op.`Opportunity Full ID`), 0) AS "Current ARR"
         , oli.`Total Price Net`
         , oli.`Product Family` 
         , oli.`Product Name`
         , oli.`Solution Family`
         , oli.`Product ID.Solution`
    FROM `Opportunities` op
    LEFT JOIN `Opportunity Line Item` oli
        ON op.`Opportunity ID` = oli.`Opportunity ID`
    WHERE op.`Stage` = 'Closed Won'
      AND `Close Date` >= '2025-07-01'
),

-- StarRez Software Bookings
bookings_sr AS (
    SELECT 'Bookings' AS `Metric Group`
         , 'Salesforce' AS `Data Source`
         , DATE_TRUNC(MONTH, `Close Date`)::DATE AS `Month`
         , SUM(`Total Software Net`) AS `StarRez Software Bookings`
    FROM bookings_base
    WHERE `Stage` = 'Closed Won'
      AND `Order Type` NOT IN ('College Pads', 'Downsell - Beds/Modules', 'Renewal')
      AND `Record Type Name` IN ('Community Relations', 'New Business')
    GROUP BY 1, 2, 3
), 

-- College Pads PMC Bookings
bookings_cp AS (
    SELECT DATE_TRUNC(MONTH, `Close Date`)::DATE AS `Month`
         , SUM(IFNULL(`Total Revenues`, 0) - IFNULL(`Total Services NET`, 0)) AS `College Pads PMC Bookings`
    FROM bookings_base
    WHERE `Stage` = 'Closed Won'
      AND `Order Type` NOT IN ('Downsell - Beds/Modules', 'Renewal')
      AND `Record Type Name` IN ('PMC Listing')
    GROUP BY 1
), 

-- Renewal Bookings
bookings_ren AS (
    SELECT DATE_TRUNC(MONTH, `Close Date`)::DATE AS `Month`
         , SUM(`Total Amount` - `Current ARR`) AS `Renewal Bookings`
    FROM bookings_base 
    WHERE `Stage` = 'Closed Won'
      AND `Record Type Name` IN ('Renewal')
      AND (IFNULL(`Total Amount`, 0) - IFNULL(`Current ARR`, 0)) > 0
    GROUP BY 1
), 

-- Conference & Events Bookings
bookings_ce AS (
    SELECT DATE_TRUNC(MONTH, `Close Date`)::DATE AS `Month`
         , SUM(`Total Price Net`) AS `Conference & Events Bookings`
    FROM bookings_base
    WHERE `Stage` = 'Closed Won'
      AND `Order Type` NOT IN ('Cross-Sell - StarRez Conversion', 'Debooking', 'Downsell - Beds/Modules')
      AND `Record Type Name` IN ('Community Relations')
      AND `Solution Family` = 'Conference and Events'
    GROUP BY 1
), 

-- Resident Life Bookings
bookings_res AS (
    SELECT DATE_TRUNC(MONTH, `Close Date`)::DATE AS `Month`
         , SUM(`Total Price Net`) AS `Resident Life Bookings`
    FROM bookings_base
    WHERE `Stage` = 'Closed Won'
      AND `Order Type` NOT IN ('Cross-Sell - StarRez Conversion', 'Debooking', 'Downsell - Beds/Modules')
--    AND LOWER(`Product Name`) NOT LIKE '%data subscriptions%'
      AND `Record Type Name` IN ('Community Relations')
      AND `Solution Family` = 'ResLife'
      AND `Product ID.Solution` IN ('Community Management Solution', 'Conduct Solution', 'Employment Solution')
    GROUP BY 1
), 

-- College Pads New Logos
bookings_cpn AS (
    SELECT DATE_TRUNC(MONTH, `Close Date`)::DATE AS `Month`
         , COUNT_DISTINCT(`Opportunity ID`) AS `College Pads New Logos`
    FROM bookings_base
    WHERE `Stage` = 'Closed Won'
      AND `Order Type` IN ('College Pads')
      AND `Record Type Name` IN ('Community Relations', 'New Business')
      AND `Total Price Net` >= -1
    GROUP BY 1
), 

-- College Pads Contract Duration
bookings_cpd AS (
    SELECT DATE_TRUNC(MONTH, `Close Date`)::DATE AS `Month`
         , SUM(AVG(`Subscription Term`)) OVER (
               PARTITION BY DATE_TRUNC(MONTH, `Close Date`)::DATE, `Opportunity ID`
           ) AS `College Pads Contract Duration`
    FROM bookings_base
    WHERE `Stage` = 'Closed Won'
      AND `Order Type` NOT IN ('Downsell - Beds/Modules', 'Renewal')
      AND `Record Type Name` IN ('PMC Listing')
    GROUP BY 1
), 

-- current wide result
bookings_wide AS (
    SELECT bookings_sr.`Metric Group`
         , bookings_sr.`Data Source`
         , bookings_sr.`Month` 
         , bookings_sr.`StarRez Software Bookings`
         , bookings_cp.`College Pads PMC Bookings`
         , bookings_ren.`Renewal Bookings`
         , bookings_ce.`Conference & Events Bookings`
         , bookings_res.`Resident Life Bookings` 
         , bookings_cpn.`College Pads New Logos`
         , bookings_cpd.`College Pads Contract Duration`
    FROM bookings_sr 
    LEFT JOIN bookings_cp 
        ON bookings_sr.`Month` = bookings_cp.`Month`
    LEFT JOIN bookings_ren 
        ON bookings_sr.`Month` = bookings_ren.`Month`
    LEFT JOIN bookings_ce 
        ON bookings_sr.`Month` = bookings_ce.`Month`
    LEFT JOIN bookings_res 
        ON bookings_sr.`Month` = bookings_res.`Month`
    LEFT JOIN bookings_cpn 
        ON bookings_sr.`Month` = bookings_cpn.`Month`
    LEFT JOIN bookings_cpd 
        ON bookings_sr.`Month` = bookings_cpd.`Month`
),

bookings_actuals AS (
    -- unpivot to Month / Metric / Value
    SELECT `Metric Group`
         , `Data Source`
         , `Month`
         , 'StarRez Software Bookings' AS `Metric`
         , `StarRez Software Bookings` AS `Actual Value`
    FROM bookings_wide

    UNION ALL

    SELECT `Metric Group`
         , `Data Source`
         , `Month`
         , 'College Pads PMC Bookings' AS `Metric`
         , `College Pads PMC Bookings` AS `Actual Value`
    FROM bookings_wide

    UNION ALL

    SELECT `Metric Group`
         , `Data Source`
         , `Month`
         , 'Renewal Bookings' AS `Metric`
         , `Renewal Bookings` AS `Actual Value`
    FROM bookings_wide

    UNION ALL

    SELECT `Metric Group`
         , `Data Source`
         , `Month`
         , 'Conference & Events Bookings' AS `Metric`
         , `Conference & Events Bookings` AS `Actual Value`
    FROM bookings_wide

    UNION ALL

    SELECT `Metric Group`
         , `Data Source`
         , `Month`
         , 'Resident Life Bookings' AS `Metric`
         , `Resident Life Bookings` AS `Actual Value`
    FROM bookings_wide

    UNION ALL

    SELECT `Metric Group`
         , `Data Source`
         , `Month`
         , 'College Pads New Logos' AS `Metric`
         , `College Pads New Logos` AS `Actual Value`
    FROM bookings_wide

    UNION ALL

    SELECT `Metric Group`
         , `Data Source`
         , `Month`
         , 'College Pads Contract Duration' AS `Metric`
         , `College Pads Contract Duration` AS `Actual Value`
    FROM bookings_wide
)


/* ===========================
   ARR & Monday - Actuals
   =========================== */

, arr_base AS (
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
arr_ending_arr AS (
    SELECT
        month_start,
        SUM(Value) AS ending_arr
    FROM arr_base
    WHERE `Type` = 'Ending ARR'
    GROUP BY month_start
),

-- Ending Software, Housing ARR by month
arr_software_ending_arr AS (
    SELECT
        month_start,
        SUM(Value) AS software_ending_arr
    FROM arr_base
    WHERE `Type` = 'Ending ARR'
      AND `Product Group` = 'Housing'
      AND `Product Type` = 'Software'
    GROUP BY month_start
),

-- Upsell & churn by month (for NRR)
arr_upsell_churn_monthly AS (
    SELECT
        month_start,
        SUM(Value) AS upsell_churn
    FROM arr_base
    WHERE `Type` NOT IN ('Beginning ARR', 'Ending ARR', 'New Logo')
      AND `Product Group` = 'Housing'
      AND `Product Type` = 'Software'
    GROUP BY month_start
),

-- 12-month rolling upsell & churn (for NRR)
arr_rolling_upsell AS (
    SELECT
        month_start,
        SUM(upsell_churn) OVER (
            ORDER BY month_start
            ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
        ) AS upsell_churn_12m
    FROM arr_upsell_churn_monthly
),

-- Churn only by month (for GRR)
arr_churn_monthly AS (
    SELECT
        month_start,
        SUM(Value) AS churn
    FROM arr_base
    WHERE `Type` IN ('Downsell', 'Lost')
      AND `Product Group` = 'Housing'
      AND `Product Type` = 'Software'
    GROUP BY month_start
),

-- 12-month rolling churn (for GRR)
arr_rolling_churn AS (
    SELECT
        month_start,
        SUM(churn) OVER (
            ORDER BY month_start
            ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
        ) AS churn_12m
    FROM arr_churn_monthly
),

-- NRR components and NRR per month
arr_nrr_calc AS (
    SELECT
        cur.month_start,
        py.software_ending_arr AS software_prior_year_arr,
        ru.upsell_churn_12m,
        (py.software_ending_arr + ru.upsell_churn_12m) / NULLIF(py.software_ending_arr, 0) AS nrr
    FROM arr_software_ending_arr cur
    JOIN arr_software_ending_arr py
        ON py.month_start = DATE_SUB(cur.month_start, INTERVAL 12 MONTH)
    LEFT JOIN arr_rolling_upsell ru
        ON ru.month_start = cur.month_start
),

-- GRR components and GRR per month
arr_grr_calc AS (
    SELECT
        cur.month_start,
        py.software_ending_arr AS prior_year_arr,
        rc.churn_12m,
        (py.software_ending_arr + rc.churn_12m) / NULLIF(py.software_ending_arr, 0) AS grr
    FROM arr_software_ending_arr cur
    JOIN arr_software_ending_arr py
        ON py.month_start = DATE_SUB(cur.month_start, INTERVAL 12 MONTH)
    LEFT JOIN arr_rolling_churn rc
        ON rc.month_start = cur.month_start
),

arr_monday_actuals AS (
    -- FINAL OUTPUT for ARR & Monday Actuals
    SELECT 
        'Annual Recurring Revenue' AS `Metric Group`,
        'Adaptive' AS `Data Source`,
        e.month_start AS `Month`,
        'ARR' AS `Metric`,
        e.ending_arr AS `Actual Value`
    FROM arr_ending_arr e

    UNION ALL

    SELECT 
        'Annual Recurring Revenue' AS `Metric Group`,
        'Adaptive' AS `Data Source`,
        month_start AS `Month`,
        'On-Campus ARR' AS `Metric`,
        SUM(Value) AS `Actual Value`
    FROM arr_base
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
    FROM arr_base
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
    FROM arr_nrr_calc

    UNION ALL

    SELECT
        'Annual Recurring Revenue' AS `Metric Group`,
        'Adaptive' AS `Data Source`,
        month_start AS `Month`,
        'GRR' AS `Metric`,
        grr AS `Actual Value`
    FROM arr_grr_calc

    UNION ALL

    SELECT
        'Annual Recurring Revenue' AS `Metric Group`,
        'Adaptive' AS `Data Source`,
        month_start AS `Month`,
        'Software ARR' AS `Metric`,
        software_ending_arr AS `Actual Value`
    FROM arr_software_ending_arr

    UNION ALL

    SELECT
        'Annual Recurring Revenue' AS `Metric Group`,
        'Adaptive' AS `Data Source`,
        month_start AS `Month`,
        'T12 Upsell/Churn' AS `Metric`,
        upsell_churn_12m AS `Actual Value`
    FROM arr_rolling_upsell

    UNION ALL

    SELECT
        'Annual Recurring Revenue' AS `Metric Group`,
        'Adaptive' AS `Data Source`,
        month_start AS `Month`,
        'T12 Churn' AS `Metric`,
        churn_12m AS `Actual Value`
    FROM arr_rolling_churn

    UNION ALL

    SELECT
        'Annual Recurring Revenue' AS `Metric Group`,
        'Adaptive' AS `Data Source`,
        month_start AS `Month`,
        'Prior Year Software ARR' AS `Metric`,
        prior_year_arr AS `Actual Value`
    FROM arr_grr_calc

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
)


/* ===========================
   Targets
   =========================== */

, targets_base AS (    
    SELECT
        -- normalize to first of month
        DATE_SUB(`Month`, INTERVAL DAYOFMONTH(`Month`) - 1 DAY)::DATE AS month_start,
        `Type`,
        `Product Group`,
        `Product Type`,
        `Value`
    FROM `ARR & Bookings - Targets`
),

-- Ending ARR by month
targets_ending_arr AS (
    SELECT
        month_start,
        SUM(Value) AS ending_arr
    FROM targets_base
    WHERE `Type` = 'Ending ARR'
    GROUP BY month_start
),

-- Ending Software, Housing ARR by month
targets_software_ending_arr AS (
    SELECT
        month_start,
        SUM(Value) AS software_ending_arr
    FROM targets_base
    WHERE `Type` = 'Ending ARR'
      AND `Product Group` = 'Housing'
      AND `Product Type` = 'Software'
    GROUP BY month_start
),

-- Upsell & churn by month (for NRR)
targets_upsell_churn_monthly AS (
    SELECT
        month_start,
        SUM(Value) AS upsell_churn
    FROM targets_base
    WHERE `Type` NOT IN ('Beginning ARR', 'Ending ARR', 'New Logo')
      AND `Product Group` = 'Housing'
      AND `Product Type` = 'Software'
    GROUP BY month_start
),

-- 12-month rolling upsell & churn (for NRR)
targets_rolling_upsell AS (
    SELECT
        month_start,
        SUM(upsell_churn) OVER (
            ORDER BY month_start
            ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
        ) AS upsell_churn_12m
    FROM targets_upsell_churn_monthly
),

-- Churn only by month (for GRR)
targets_churn_monthly AS (
    SELECT
        month_start,
        SUM(Value) AS churn
    FROM targets_base
    WHERE `Type` IN ('Downsell', 'Lost')
      AND `Product Group` = 'Housing'
      AND `Product Type` = 'Software'
    GROUP BY month_start
),

-- 12-month rolling churn (for GRR)
targets_rolling_churn AS (
    SELECT
        month_start,
        SUM(churn) OVER (
            ORDER BY month_start
            ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
        ) AS churn_12m
    FROM targets_churn_monthly
),

-- NRR components and NRR per month
targets_nrr_calc AS (
    SELECT
        cur.month_start,
        py.software_ending_arr AS software_prior_year_arr,
        ru.upsell_churn_12m,
        (py.software_ending_arr + ru.upsell_churn_12m) / NULLIF(py.software_ending_arr, 0) AS nrr
    FROM targets_software_ending_arr cur
    JOIN targets_software_ending_arr py
        ON py.month_start = DATE_SUB(cur.month_start, INTERVAL 12 MONTH)
    LEFT JOIN targets_rolling_upsell ru
        ON ru.month_start = cur.month_start
),

-- GRR components and GRR per month
targets_grr_calc AS (
    SELECT
        cur.month_start,
        py.software_ending_arr AS prior_year_arr,
        rc.churn_12m,
        (py.software_ending_arr + rc.churn_12m) / NULLIF(py.software_ending_arr, 0) AS grr
    FROM targets_software_ending_arr cur
    JOIN targets_software_ending_arr py
        ON py.month_start = DATE_SUB(cur.month_start, INTERVAL 12 MONTH)
    LEFT JOIN targets_rolling_churn rc
        ON rc.month_start = cur.month_start
),

targets AS (
    -- FINAL OUTPUT -- Targets
    SELECT 
        'Annual Recurring Revenue' AS `Metric Group`,
        'Adaptive' AS `Data Source`,
        e.month_start AS `Month`,
        'ARR' AS `Metric`,
        e.ending_arr AS `Target Value`
    FROM targets_ending_arr e

    UNION ALL

    SELECT 
        'Annual Recurring Revenue' AS `Metric Group`,
        'Adaptive' AS `Data Source`,
        month_start AS `Month`,
        'On-Campus ARR' AS `Metric`,
        SUM(Value) AS `Target Value`
    FROM targets_base
    WHERE `Type` = 'Ending ARR'
      AND `Product Group` <> 'College Pads'
    GROUP BY month_start

    UNION ALL

    SELECT 
        'Annual Recurring Revenue' AS `Metric Group`,
        'Adaptive' AS `Data Source`,
        month_start AS `Month`,
        'Off-Campus ARR' AS `Metric`,
        SUM(Value) AS `Target Value`
    FROM targets_base
    WHERE `Type` = 'Ending ARR'
      AND `Product Group` = 'College Pads'
    GROUP BY month_start

    UNION ALL

    SELECT
        'Annual Recurring Revenue' AS `Metric Group`,
        'Adaptive' AS `Data Source`,
        month_start AS `Month`,
        'NRR' AS `Metric`,
        nrr AS `Target Value`
    FROM targets_nrr_calc

    UNION ALL

    SELECT
        'Annual Recurring Revenue' AS `Metric Group`,
        'Adaptive' AS `Data Source`,
        month_start AS `Month`,
        'GRR' AS `Metric`,
        grr AS `Target Value`
    FROM targets_grr_calc

    UNION ALL

    SELECT
        'Annual Recurring Revenue' AS `Metric Group`,
        'Adaptive' AS `Data Source`,
        month_start AS `Month`,
        'Software ARR' AS `Metric`,
        software_ending_arr AS `Target Value`
    FROM targets_software_ending_arr

    UNION ALL

    SELECT
        'Annual Recurring Revenue' AS `Metric Group`,
        'Adaptive' AS `Data Source`,
        month_start AS `Month`,
        'T12 Upsell/Churn' AS `Metric`,
        upsell_churn_12m AS `Target Value`
    FROM targets_rolling_upsell

    UNION ALL

    SELECT
        'Annual Recurring Revenue' AS `Metric Group`,
        'Adaptive' AS `Data Source`,
        month_start AS `Month`,
        'T12 Churn' AS `Metric`,
        churn_12m AS `Target Value`
    FROM targets_rolling_churn

    UNION ALL

    SELECT
        'Annual Recurring Revenue' AS `Metric Group`,
        'Adaptive' AS `Data Source`,
        month_start AS `Month`,
        'Prior Year Software ARR' AS `Metric`,
        prior_year_arr AS `Target Value`
    FROM targets_grr_calc

    --------- Monday data ------------
    UNION ALL

    SELECT 
        'TBD' AS `Metric Group`,
        'Monday.com' AS `Data Source`,
        DATE_SUB(`Month`, INTERVAL DAYOFMONTH(`Month`) - 1 DAY) AS `Month`, 
        `Metric`, 
        `Target` AS `Target Value` 
    FROM `Monthly Targets`

    UNION ALL

    SELECT 
        'TBD' AS `Metric Group`,
        'Monday.com' AS `Data Source`,
        DATE_SUB(`Quarter Ending`, INTERVAL DAYOFMONTH(`Quarter Ending`) - 1 DAY)::DATE AS `Month`, 
        `Metric`, 
        `Target` AS `Target Value` 
    FROM `Quarterly Targets Amortized`
)


/* ===========================
   Final Select (Variance, Color, Streaks)
   =========================== */

, actuals AS (
    SELECT * FROM bookings_actuals
    UNION ALL
    SELECT * FROM arr_monday_actuals
),

var AS (
    SELECT a.* 
         , t.`Target Value`
         , a.`Actual Value` - t.`Target Value` AS `Variance Amount`
         , (a.`Actual Value` - t.`Target Value`) / NULLIF(t.`Target Value`, 0) AS `Variance Percentage`
         , p.`Actual Value` AS `Prior Month Actual Value`
    FROM actuals a
    LEFT JOIN targets t 
        ON a.`Month` = DATE_SUB(t.`Month`, INTERVAL DAYOFMONTH(t.`Month`) - 1 DAY)
       AND a.`Metric` = t.`Metric`
    LEFT JOIN actuals p 
        ON DATE_SUB(a.`Month`, INTERVAL 1 MONTH) = p.`Month` 
       AND a.`Metric` = p.`Metric`
),

-- Add Color Status
cs AS (
    SELECT v.*
         , CASE 
               WHEN `Variance Percentage` IS NULL THEN NULL
               WHEN `Variance Percentage` <= -0.05 THEN 'Red'
               WHEN `Variance Percentage` > -0.05
                    AND `Variance Percentage` < 0 THEN 'Yellow'
               ELSE 'Green'
           END AS `Color Status`
    FROM var v
),

-- Attach previous month's color using a self-join (no windows)
cs_with_prev AS (
    SELECT c.*
         , p.`Color Status` AS `Prev Color Status`
    FROM cs c
    LEFT JOIN cs p
           ON p.`Metric` = c.`Metric`
          AND p.`Month` = DATE_SUB(c.`Month`, INTERVAL 1 MONTH)
),

-- Rows where a "color run" starts (first row for a metric or color changed)
color_changes AS (
    SELECT c.`Metric`,
           c.`Month`
    FROM cs_with_prev c
    WHERE c.`Prev Color Status` IS NULL
       OR c.`Prev Color Status` <> c.`Color Status`
),

-- For each row, find the start month of its current color run
color_run_start AS (
    SELECT c.`Metric`,
           c.`Month`,
           MAX(ch.`Month`) AS `Run Start Month`
    FROM cs_with_prev c
    JOIN color_changes ch
      ON ch.`Metric` = c.`Metric`
     AND ch.`Month` <= c.`Month`
    GROUP BY c.`Metric`, c.`Month`
),

-- For each row, count how many rows from the run start to this month
color_run_length AS (
    SELECT c.`Metric`,
           c.`Month`,
           COUNT(*) AS `Color Status Streak Months`
    FROM cs_with_prev c
    JOIN color_run_start rs
      ON rs.`Metric` = c.`Metric`
     AND rs.`Month` = c.`Month`
    JOIN cs_with_prev c2
      ON c2.`Metric` = c.`Metric`
     AND c2.`Month` BETWEEN rs.`Run Start Month` AND c.`Month`
     AND c2.`Color Status` = c.`Color Status`
    GROUP BY c.`Metric`, c.`Month`
),

-- Trailing 3 Month Averages
trailing_3_month_averages AS (
    SELECT cr.*
         , AVG(tr.`Actual Value`) AS `Actual Value - Trailing 3 Month Avg`
    FROM color_run_length cr
    LEFT JOIN actuals tr  
        ON cr.`Metric` = tr.`Metric`
       AND tr.`Month` BETWEEN DATE_SUB(cr.`Month`, INTERVAL 3 MONTH)
                          AND DATE_SUB(cr.`Month`, INTERVAL 1 MONTH)
    GROUP BY  
          cr.`Month`
        , cr.`Metric`
)

SELECT 
      c.`Month`
    , c.`Metric Group`  
    , c.`Metric`
    , c.`Actual Value`
    , c.`Target Value`
    , c.`Variance Amount`
    , c.`Variance Percentage`
    , c.`Color Status`
    , c.`Prev Color Status`
    , rl.`Color Status Streak Months`
    , tr.`Actual Value - Trailing 3 Month Avg`
    , c.`Prior Month Actual Value`
FROM cs_with_prev c
LEFT JOIN color_run_length rl
       ON rl.`Metric` = c.`Metric`
      AND rl.`Month` = c.`Month`
LEFT JOIN trailing_3_month_averages tr
       ON tr.`Metric` = c.`Metric`
      AND tr.`Month` = c.`Month`
ORDER BY c.`Month` DESC, c.`Metric`;
