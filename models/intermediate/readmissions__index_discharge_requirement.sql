
-- Here we list encounter_ids that meet
-- the discharge_disposition_code requirements to be an
-- index admission:
--    *** Must NOT be discharged to another acute care hospital
--    *** Must NOT have left against medical advice
--    *** Patient must be alive at discharge


{{ config(materialized='view'
    ,enabled=var('readmissions_enabled',var('tuva_packages_enabled',True))) }}




-- Encounters where the patient is discharged to
-- another acute care hospital
-- (discharge_disposition_code = '02', which is:
-- 'Discharged/transferred to other short term
--  general hospital for inpatient care.' )
with acute_care_discharge as (
select encounter_id
from {{ ref('readmissions__stg_encounter') }}
where discharge_disposition_code = '02'
),


-- Encounters where the patient left against medical advice
against_medical_advice as (
select encounter_id
from {{ ref('readmissions__stg_encounter') }}
where discharge_disposition_code = '07'   
),


-- Encounters where patient died
died as (
select encounter_id
from {{ ref('readmissions__stg_encounter') }}
where discharge_disposition_code = '20'   
),


-- Union of all invalid discharges
all_invalid_discharges as (
select encounter_id from acute_care_discharge
union distinct
select encounter_id from against_medical_advice
union distinct
select encounter_id from died
)


-- All discharges that meet the discharge_disposition_code
-- requirements to be an index admission
select encounter_id
from {{ ref('readmissions__stg_encounter') }}
where encounter_id not in (select * from all_invalid_discharges)
