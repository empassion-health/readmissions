
-- Here calculate days to readmission for encounters
-- that had a readmission and create readmission flags


{{ config(enabled=var('readmissions_enabled',var('tuva_packages_enabled',True))) }}



-- We create the encounter_sequence integer count
-- which keeps track of what number of encounter each
-- encounter is for a given patient
with encounter_sequence as (
select
    *,
    row_number() over(
        partition by patient_id order by admit_date, discharge_date
    ) as encounter_seq
from {{ ref('readmissions__encounter_augmented') }}
where disqualified_encounter_flag = 0
),

, encounter_sequence_setup (select 
*
, LAG(discharge_date, 1) OVER(PARTITION BY patient_id
       ORDER BY admit_date) as previous_discharge_date
, row_number () over  (partition by patient_id, overlaps_with_another_encounter_flag order BY admit_date) as first_row
, row_number () over  (partition by patient_id, overlaps_with_another_encounter_flag order BY admit_date desc) as last_row
 from production-dna.analytics_int.encounter_augmented
order by admit_date)

, dates as (select *
, if(first_row=overlaps_with_another_encounter_flag, true, false) as first_row_flag
, if(last_row=overlaps_with_another_encounter_flag, true, false) as last_row_flag
from encounter_sequence_setup
)

,  admits as (select 
*

, row_number () over  (partition by patient_id order BY admit_date desc) as admit_rank

from dates
where first_row_flag )

,  discharge as (select patient_id, 
discharge_date
, row_number () over  (partition by patient_id order BY discharge_date desc) as admit_rank

from dates
where last_row_flag )

join_admits_discharge as (select 
, encounter_id
, patient_id
, admits.admit_date
, discharge.discharge_date
, discharge_disposition_code
, facility_npi
, ms_drg_code
, paid_amount
, datediff(admits.admit_date, discharge.discharge_date, days) length_of_stay
, index_admission_flag
, planned_flag
, died_flag
, diagnosis_ccs
, disqualified_encounter_flag
, missing_admit_date_flag
, missing_discharge_date_flag
, admit_after_discharge_flag
, missing_discharge_disposition_code_flag
, invalid_discharge_disposition_code_flag
, missing_primary_diagnosis_flag
, multiple_primary_diagnoses_flag
, invalid_primary_diagnosis_code_flag
, no_diagnosis_ccs_flag
, 0 as overlaps_with_another_encounter_flag
, missing_ms_drg_flag
, invalid_ms_drg_flag

from admits
left join discharge 
on admits.admit_rank=discharge.admit_rank
)

, encounter_sequence_update as (
select
  
from join_admits_discharge

)

, join_together_encounter_sequence as (

select *
from encounter_sequence
union all
select *
from encounter_sequence_update


)


,

readmission_calc as (
select
    aa.encounter_id,
    aa.patient_id,
    aa.admit_date,
    aa.discharge_date,
    aa.discharge_disposition_code,
    aa.facility_npi,
    aa.ms_drg_code,
    aa.paid_amount,
    aa.length_of_stay,
    aa.index_admission_flag,
    aa.planned_flag,
    aa.specialty_cohort,
    aa.died_flag,
    aa.diagnosis_ccs,
    case
        when bb.encounter_id is not null then 1
	    else 0
    end as had_readmission_flag,
    {{ dbt.datediff("aa.discharge_date", "bb.admit_date","day") }} as days_to_readmit,
    case
        when ({{ dbt.datediff("aa.discharge_date", "bb.admit_date","day") }}) <= 30  then 1
	    else 0
    end as readmit_30_flag,
    case
        when
	    (({{ dbt.datediff("aa.discharge_date", "bb.admit_date", "day") }}) <= 30) and (bb.planned_flag = 0) then 1
	    else 0
    end as unplanned_readmit_30_flag,
    bb.encounter_id as readmission_encounter_id,
    bb.admit_date as readmission_admit_date,
    bb.discharge_date as readmission_discharge_date,
    bb.discharge_disposition_code as readmission_discharge_disposition_code,
    bb.facility_npi as readmission_facility,
    bb.ms_drg_code as readmission_ms_drg,
    bb.length_of_stay as readmission_length_of_stay,
    bb.index_admission_flag as readmission_index_admission_flag,
    bb.planned_flag as readmission_planned_flag,
    bb.specialty_cohort as readmission_specialty_cohort,
    bb.died_flag as readmission_died_flag,
    bb.diagnosis_ccs as readmission_diagnosis_ccs
from
    encounter_sequence aa
    left join encounter_sequence bb
    on aa.patient_id = bb.patient_id
    and aa.encounter_seq + 1 = bb.encounter_seq
)

select *
from readmission_calc
