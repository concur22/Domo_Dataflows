TESTING('window_functions')

-- Initial union
WITH actuals AS (
    SELECT * FROM `Bookings - Actuals`
    UNION ALL
    SELECT * FROM `ARR & Monday - Actuals` 
),

-- Add variance columns
var AS (
    SELECT a.* 
         , t.`Target Value`
         , a.`Actual Value` - t.`Target Value` AS `Variance Amount`
         , (a.`Actual Value` - t.`Target Value`) / NULLIF(t.`Target Value`, 0) AS `Variance Percentage`
         , p.`Actual Value` AS `Prior Month Actual Value`
    FROM actuals a
    LEFT JOIN `Targets` t 
        ON a.`Month` = DATE_SUB(t.`Month`, INTERVAL DAYOFMONTH(t.`Month`) - 1 DAY)
       AND a.`Metric` = t.`Metric`
    LEFT JOIN `Actuals` p 
        ON DATE_SUB(a.`Month`, INTERVAL 1 MONTH)  = p.`Month` 
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
            AND tr.`Month` BETWEEN DATE_SUB(cr.`Month`, INTERVAL 3 MONTH) AND DATE_SUB(cr.`Month`, INTERVAL 1 MONTH)
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
