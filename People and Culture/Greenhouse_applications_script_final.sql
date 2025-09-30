-- This query builds an Applications reporting dataset by progressively enriching
-- application records with job stages, job openings (incl. entity), job details,
-- latest offer info, and hiring manager data. The final result excludes a known
-- placeholder department.

WITH applications_join_1 AS (
    -- Start from Applications and attach the CURRENT job stage (if any).
    -- Note: LEFT JOIN so applications without a matching stage are retained.
    SELECT
          a.id AS "Application ID"
        , a.source_id AS "Source ID"
        , a.candidate_id AS "Candidate ID"
        , a.prospect AS "Is Prospect Ind"                              -- boolean/string indicator
        , a.applied_at AS "Applied At Date"
        , a.rejected_at AS "Rejected At Date"
        , a.last_activity_at AS "Last Activity Date"
        , a.location AS "Applicant Location"
        , a.source_public_name AS "Application Source Name"
        , a.credited_to_name AS "Application Credited To Name"
        , a.status AS "Application Status"
        , a.custom_fields_desired_salary AS "Desired Salary"
        , a.rejection_reason_name AS "Rejection Reason Name"
        , a.rejection_reason_type_name AS "Rejection Reason Type"
        , a.current_stage_name AS "Application Current Stage"
        , a.jobs_name AS "Job Name"
        , a."jobs_id"                                                  -- Application's job foreign key
        , js.name AS "Job Stage Name"
        , js.active
        , js.interviews_name
        , js.interviews_schedulable
        , js.interviews_default_interviewer_users
        , js.created_at
        , js._BATCH_LAST_RUN_ AS "Job Stages_BATCH_LAST_RUN_"
    FROM `Applications` a
    LEFT JOIN `Job Stages` js
        ON a.current_stage_id = js.id
),

job_openings_join_1 AS (
    -- Join Job Openings with the "w/ Entity" view to expose the hiring entity.
    -- Keeping both job and openings timestamps for clarity.
    SELECT
          jo.id AS "Job ID"                                           -- NB: "Job ID" here is the Job primary key
        , jo.openings_id AS "Job Openings ID"                         -- Greenhouse "opening" identifier
        , jo.is_template AS "Is Job Openings Template"                -- Filter out templates later
        , jo.custom_fields_employment_type AS "Employment Type"
        , jo.custom_fields_elt_leader_name AS "ELT Leader"
        , jo.keyed_custom_fields_reason_for_hire_value AS "Reason for Hire"
        , jo.openings_status AS "Job Openings Status"
        , jo.created_at AS "Job Openings Created At Date"
        , jo.opened_at AS "Job Opened At Date"
        , jo.closed_at AS "Job Closed At Date"
        , jo.updated_at AS "Job Openings Updated At Date"
        , jo.openings_opened_at AS "Job Openings Opened At Date"
        , jo.openings_closed_at AS "Job Openings Closed At Date"
        , jo_we.id AS job_id                                          -- Duplicate of jo.id (job PK) for clarity
        , jo_we.custom_fields_entity_custom_fields_entity AS "Entity"
    FROM `Job Openings` jo
    LEFT JOIN `Job Openings w/ Entity` jo_we
        ON jo.id = jo_we.id
),

applications_join_2 AS (
    -- Attach openings/entity data to applications via the job id.
    -- DISTINCT handles potential duplication from upstream joins.
    -- Filter out job opening templates (keep only real postings).
    SELECT DISTINCT
          a."Application ID"
        , a."jobs_id"
        , a."Source ID"
        , a."Candidate ID"
        , a."Is Prospect Ind"
        , a."Applied At Date"
        , a."Rejected At Date"
        , a."Last Activity Date"
        , a."Applicant Location"
        , a."Application Source Name"
        , a."Application Credited To Name"
        , a."Application Status"
        , a."Desired Salary"
        , a."Rejection Reason Name"
        , a."Rejection Reason Type"
        , a."Application Current Stage"
        , a."Job Name"
        , a."Job Stage Name"
        , jo."Entity"
        , jo."Job ID"
        , jo."Job Openings ID"
        , jo."Is Job Openings Template"
        , jo."Job Openings Created At Date"
        , jo."Job Openings Opened At Date"
        , jo."Job Openings Updated At Date"
        , jo."Job Openings Closed At Date"
        , jo."Employment Type"
        , jo."Reason for Hire"
        , jo."Job Openings Status"
        , jo."ELT Leader"
    FROM applications_join_1 a
    LEFT JOIN job_openings_join_1 jo
        ON a."jobs_id" = jo."Job ID"
    WHERE jo."Is Job Openings Template" NOT ILIKE '%true%'            -- exclude templates (case-insensitive)
),

applications_join_3 AS (
    -- Enrich with core Job attributes (department, office, lifecycle dates).
    -- LEFT JOIN to preserve applications even if job metadata is missing.
    SELECT
          a.*
        , j.id as "Jobs ID"                                           -- Redundant to "Job ID" but kept for clarity
        , j.departments_name as "Department"
        , j.offices_name as "Office"
        , j.status AS "Job Status"
        , j.created_at AS "Job Created At Date"
        , j.opened_at AS "Job Opened At Date"
        , j.closed_at AS "Job Closed At Date"
    FROM applications_join_2 a
    LEFT JOIN `Jobs` j
        ON a."Job ID" = j.id
),

offers_select1 AS (
    -- From all offers, keep ONLY the latest version per application.
    -- VersionRowNum=1 picks the highest version (ORDER BY version DESC).
    SELECT *
    FROM (
        SELECT
              o.id AS "Offer ID"
            , o.version as "Version"
            , o.application_id
            , o.created_at AS "Offer Created At Date"
            , o.updated_at AS "Offer Updated At Date"
            , o.sent_at AS "Offer Sent At Date"
            , o.resolved_at AS "Offer Resolved At Date"
            , o.starts_at AS "Offer Starts At Date"
            , o.status AS "Offer Status"
            , ROW_NUMBER() OVER (
                PARTITION BY o.application_id
                ORDER BY o.version DESC
              ) AS VersionRowNum
        FROM offers o
    ) ranked
    WHERE VersionRowNum = 1
),

applications_join_4 AS (
    -- Attach the latest offer (if any) to each application.
    SELECT *
    FROM applications_join_3 a
    LEFT JOIN offers_select1 o
        ON a."Application ID" = o.application_id
),

applications_join_5 AS (
    -- Add Hiring Manager info from Job Recruiters, filtering to "responsible" recruiters.
    -- NOTE: Verify the join key: joining ON a."Job ID" = jr.id assumes jr.id == job id,
    -- which is unusual. Typically you'd join ON jr.job_id = a."Job ID".
    -- If jr.id is the recruiter record ID (not the job), this join will be incorrect.
    SELECT
          a.*
        , jr.id AS "recruiter_job_id"
        , jr.hiring_team_recruiters_name AS "Hiring Manager Name"
    FROM applications_join_4 a
    LEFT JOIN `Job Recruiters` jr
        ON a."Job ID" = jr.id                                         -- ⚠️ Potential issue: confirm this matches your schema
       AND jr.hiring_team_recruiters_responsible = 'true'
),

applications_final_select AS (
    -- Curate the final column set and compute a row number within each opening.
    SELECT
          "Jobs ID"
        , "Job Openings ID"
        , "Application ID"
        , "Job Name"
        , "Job Stage Name"
        , "Job Status"
        , "Job Openings Status"
        , "Employment Type"
        , "Reason For Hire"
        , "ELT Leader"
        , COALESCE("Entity", 'StarRez') AS "Entity"                    -- default entity when missing
        , "Department"
        , "Office"
        , "Is Prospect Ind"
        , "Applicant Location"
        , "Application Source Name"
        , "Application Credited To Name"
        , "Application Status"
        , "Desired Salary"
        , "Rejection Reason Name"
        , "Rejection Reason Type"
        , "Application Current Stage"
        , "Offer Status"
        , "Hiring Manager Name"
        , "Job Opened At Date"
        , "Job Closed At Date"
        , "Job Openings Created At Date"
        , "Job Openings Opened At Date"
        , "Job Openings Updated At Date"
        , "Job Openings Closed At Date"
        , "Applied At Date"
        , "Rejected At Date"
        , "Last Activity Date"
        , "Offer Created At Date"
        , "Offer Updated At Date"
        , "Offer Sent At Date"
        , "Offer Resolved At Date"
        , "Offer Starts At Date"
        , ROW_NUMBER() OVER (
            PARTITION BY "Job Openings ID"
            ORDER BY "Application ID"
          ) AS "Job Openings Row Number"                               -- useful for de-duping or top-n per opening
    FROM applications_join_5
)

-- FINAL RESULT: exclude the known placeholder/invalid department.
-- Using ILIKE for case-insensitive match across warehouses that support it.
SELECT *
FROM applications_final_select
WHERE "Department" NOT ILIKE '%Container Department - do not use%';
