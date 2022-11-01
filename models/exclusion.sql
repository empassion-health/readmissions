
-- Here we list encounter_ids that are excluded
-- from being index admissions because they
-- belong to one of these categories:
--       [1] Medical Treatment of Cancer
--       [2] Rehabilitation
--       [3] Psychiatric


{{ config(materialized='view') }}


-- encounter_ids for encounters that should be
-- excluded because they belong to one of the
-- exclusion categories
with exclusions as (
select distinct encounter_id
from {{ ref('diagnosis_ccs') }}
where ccs_diagnosis_category in
    (select distinct ccs_diagnosis_category
     from {{ source('tuva_terminology','exclusion_ccs_diagnosis_category') }} )
)


select *
from exclusions
