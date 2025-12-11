  WITH base AS (
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
sr AS (
    SELECT 'Bookings' AS `Metric Group`
         , 'Salesforce' AS `Data Source`
         , DATE_TRUNC(MONTH, `Close Date`)::DATE AS `Month`
         , SUM(`Total Software Net`) AS `StarRez Software Bookings`
    FROM base
    WHERE `Stage` = 'Closed Won'
      AND `Order Type` NOT IN ('College Pads', 'Downsell - Beds/Modules', 'Renewal')
      AND `Record Type Name` IN ('Community Relations', 'New Business')
    GROUP BY 1, 2, 3
    ORDER BY 3
), 

-- College Pads PMC Bookings
cp AS (
    SELECT DATE_TRUNC(MONTH, `Close Date`)::DATE AS `Month`
         , SUM(IFNULL(`Total Revenues`, 0) - IFNULL(`Total Services NET`, 0)) AS `College Pads PMC Bookings`
    FROM base
    WHERE `Stage` = 'Closed Won'
      AND `Order Type` NOT IN ('Downsell - Beds/Modules', 'Renewal')
      AND `Record Type Name` IN ('PMC Listing')
    GROUP BY 1
    ORDER BY 1
), 

-- Renewal Bookings
ren AS (
    SELECT DATE_TRUNC(MONTH, `Close Date`)::DATE AS `Month`
         , SUM(`Total Amount` - `Current ARR`) AS `Renewal Bookings`
    FROM base 
    WHERE `Stage` = 'Closed Won'
      AND `Record Type Name` IN ('Renewal')
      AND (IFNULL(`Total Amount`, 0) - IFNULL(`Current ARR`, 0)) > 0
    GROUP BY 1
    ORDER BY 1
), 

-- Conference & Events Bookings
ce AS (
    SELECT DATE_TRUNC(MONTH, `Close Date`)::DATE AS `Month`
         , SUM(`Total Price Net`) AS `Conference & Events Bookings`
    FROM base
    WHERE `Stage` = 'Closed Won'
      AND `Order Type` NOT IN ('Cross-Sell - StarRez Conversion', 'Debooking', 'Downsell - Beds/Modules')
      AND `Record Type Name` IN ('Community Relations')
      AND `Solution Family` = 'Conference and Events'
    GROUP BY 1
    ORDER BY 1
), 

-- Resident Life Bookings
res AS (
    SELECT DATE_TRUNC(MONTH, `Close Date`)::DATE AS `Month`
         , SUM(`Total Price Net`) AS `Resident Life Bookings`
    FROM base
    WHERE `Stage` = 'Closed Won'
      AND `Order Type` NOT IN ('Cross-Sell - StarRez Conversion', 'Debooking', 'Downsell - Beds/Modules')
--    AND LOWER(`Product Name`) NOT LIKE '%data subscriptions%'
      AND `Record Type Name` IN ('Community Relations')
      AND `Solution Family` = 'ResLife'
      AND `Product ID.Solution` IN ('Community Management Solution', 'Conduct Solution', 'Employment Solution')
    GROUP BY 1
    ORDER BY 1
),

-- College Pads New Logos
cpn AS (
    SELECT DATE_TRUNC(MONTH, `Close Date`)::DATE AS `Month`
         , COUNT_DISTINCT(`Opportunity ID`) AS `College Pads New Logos`
    FROM base
    WHERE `Stage` = 'Closed Won'
      AND `Order Type` IN ('College Pads')
      AND `Record Type Name` IN ('Community Relations', 'New Business')
      AND `Total Price Net` >= -1
    GROUP BY 1
    ORDER BY 1
),

-- College Pads Contract Duration
cpd AS (
    SELECT DATE_TRUNC(MONTH, `Close Date`)::DATE AS `Month`
         , SUM(AVG(`Subscription Term`)) OVER (PARTITION BY DATE_TRUNC(MONTH, `Close Date`)::DATE, `Opportunity ID`) AS `College Pads Contract Duration`
    FROM base
    WHERE `Stage` = 'Closed Won'
      AND `Order Type` NOT IN ('Downsell - Beds/Modules', 'Renewal')
      AND `Record Type Name` IN ('PMC Listing')
    GROUP BY 1
    ORDER BY 1
),

-- current wide result
wide AS (
    SELECT sr.`Metric Group`
         , sr.`Data Source`
         , sr.`Month` 
         , sr.`StarRez Software Bookings`
         , cp.`College Pads PMC Bookings`
         , ren.`Renewal Bookings`
         , ce.`Conference & Events Bookings`
         , res.`Resident Life Bookings` 
         , cpn.`College Pads New Logos`
         , cpd.`College Pads Contract Duration`
    FROM sr 
    LEFT JOIN cp 
        ON sr.`Month` = cp.`Month`
    LEFT JOIN ren 
        ON sr.`Month` = ren.`Month`
    LEFT JOIN ce 
        ON sr.`Month` = ce.`Month`
    LEFT JOIN res 
        ON sr.`Month` = res.`Month`
    LEFT JOIN cpn 
        ON sr.`Month` = cpn.`Month`
    LEFT JOIN cpd 
        ON sr.`Month` = cpd.`Month`
)

-- unpivot to Month / Metric / Value
SELECT `Metric Group`
     , `Data Source`
     , `Month`
     , 'StarRez Software Bookings' AS `Metric`
     , `StarRez Software Bookings` AS `Actual Value`
FROM wide

UNION ALL

SELECT `Metric Group`
     , `Data Source`
     , `Month`
     , 'College Pads PMC Bookings' AS `Metric`
     , `College Pads PMC Bookings` AS `Actual Value`
FROM wide

UNION ALL

SELECT `Metric Group`
     , `Data Source`
     , `Month`
     , 'Renewal Bookings' AS `Metric`
     , `Renewal Bookings` AS `Actual Value`
FROM wide

UNION ALL

SELECT `Metric Group`
     , `Data Source`
     , `Month`
     , 'Conference & Events Bookings' AS `Metric`
     , `Conference & Events Bookings` AS `Actual Value`
FROM wide

UNION ALL

SELECT `Metric Group`
     , `Data Source`
     , `Month`
     , 'Resident Life Bookings' AS `Metric`
     , `Resident Life Bookings` AS `Actual Value`
FROM wide

UNION ALL

SELECT `Metric Group`
     , `Data Source`
     , `Month`
     , 'College Pads New Logos' AS `Metric`
     , `College Pads New Logos` AS `Actual Value`
FROM wide

UNION ALL

SELECT `Metric Group`
     , `Data Source`
     , `Month`
     , 'College Pads Contract Duration' AS `Metric`
     , `College Pads Contract Duration` AS `Actual Value`
FROM wide

ORDER BY `Month` DESC
