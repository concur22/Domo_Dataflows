WITH applications_join_1 AS (
    SELECT		
          a.id AS "Application ID"
        , a.source_id AS "Source ID" 
        , a.candidate_id AS "Candidate ID"
        , a.prospect AS "Is Prospect Ind"
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
        , a."jobs_id"
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
    SELECT 
          jo.id AS "Job ID"
        , jo.openings_id AS "Job Openings ID"
        , jo.is_template AS "Is Job Openings Template"
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
        , jo_we.id AS job_id
        , jo_we.custom_fields_entity_custom_fields_entity AS "Entity"
    FROM `Job Openings` jo
    LEFT JOIN `Job Openings w/ Entity` jo_we
        ON jo.id = jo_we.id
),

applications_join_2 AS (
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
        , jo."Job Openings Closed At Date"
        , jo."Job Openings Updated At Date"
        , jo."Employment Type"
        , jo."Reason for Hire"
        , jo."Job Openings Status"
        , jo."ELT Leader"
    FROM applications_join_1 a 
    LEFT JOIN job_openings_join_1 jo 
        ON a."jobs_id" = jo."Job ID"
    WHERE jo."Is Job Openings Template" NOT ILIKE '%true%'
),

applications_join_3 AS (
    SELECT 
          a.* 
        , j.id as "Jobs ID"
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
    SELECT * 
    FROM applications_join_3 a 
    LEFT JOIN offers_select1 o
        ON a."Application ID" = o.application_id
),

applications_join_5 AS (
    SELECT
          a.*
        , jr.id AS "recruiter_job_id"
        , jr.hiring_team_recruiters_name AS "Hiring Manager Name"
    FROM applications_join_4 a
    LEFT JOIN `Job Recruiters` jr
        ON a."Job ID" = jr.id 
       AND jr.hiring_team_recruiters_responsible = 'true'
),

applications_final_select AS (
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
        , COALESCE("Entity", 'StarRez') AS "Entity"
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
          ) AS "Job Openings Row Number"
    FROM applications_join_5
)

-- final query: Greenhouse | Applications
SELECT * 
FROM applications_final_select
WHERE "Department" NOT ILIKE '%Container Department - do not use%';
