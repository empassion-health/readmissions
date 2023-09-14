
-- Here calculate days to readmission for encounters
-- that had a readmission and create readmission flags


{{ config(enabled=var('readmissions_enabled',var('tuva_packages_enabled',True))) }}

with encounter_sequence as (
select
    *
from {{ ref('readmissions__encounter_augmented') }}
where disqualified_encounter_flag = 0
)
--creating tables for members that have multiple transfers
, encounter_sequence_setup_multiple_transfers as 
(select *
, row_number () over  (partition by patient_id, overlaps_with_another_encounter_flag order BY admit_date) as first_row
, row_number () over  (partition by patient_id, overlaps_with_another_encounter_flag, admit_date order BY admit_date desc) as last_row
, 

lag (discharge_date , 1 ) 
    OVER ( partition by patient_id, overlaps_with_another_encounter_flag  order by admit_date) as previous_discharge_date
    , lead (admit_date , 1 ) 
    OVER ( partition by patient_id, overlaps_with_another_encounter_flag  order by admit_date) as next_admit_date
       , lead (discharge_date , 1 ) 
    OVER ( partition by patient_id, overlaps_with_another_encounter_flag  order by admit_date) as test_discharge_date
 from {{ ref('readmissions__encounter_augmented') }}
order by admit_date)

, dates_multiple_tranfers as (select *
, case when discharge_date=next_admit_date or previous_discharge_date=admit_date then true else false end as transfer
, case when discharge_date=next_admit_date then true else false end as transfer_1
, case when previous_discharge_date=admit_date then true else false end as transfer_2
from encounter_sequence_setup_multiple_transfers
)

, transfers as (select encounter_id
, patient_id
, admit_date
, discharge_date
, next_admit_date
, test_discharge_date 
, first_row
, last_row
, row_number () over  (partition by patient_id, transfer_1 order BY admit_date) as transfer_partition
, transfer
from dates_multiple_tranfers
where transfer
order by patient_id, admit_date)

, transfer_setup as (select *
, case when discharge_date=next_admit_date then lead(transfer_partition,1 ) OVER ( partition by patient_id  order by admit_date) end as lead_discharge_flag
from transfers )

, multiple_transfers_one_row_final as (select encounter_id
, patient_id
, admit_date
, case when lead_discharge_flag=transfer_partition then test_discharge_date else null end as discharge_date
from transfer_setup
where lead_discharge_flag=transfer_partition)

--creating tables for members that have transfers with two rows, transferred multiple times
, encounter_sequence_setup as 
(select *
, row_number () over  (partition by patient_id, overlaps_with_another_encounter_flag order BY admit_date) as first_row
, row_number () over  (partition by patient_id, overlaps_with_another_encounter_flag order BY admit_date desc) as last_row
 from {{ ref('readmissions__encounter_augmented') }}
order by admit_date)

, dates as (select *
, if(first_row=overlaps_with_another_encounter_flag, true, false) as first_row_flag
, if(last_row=overlaps_with_another_encounter_flag, true, false) as last_row_flag 
, case when (overlaps_with_another_encounter_flag=1 and first_row=overlaps_with_another_encounter_flag or 
last_row=overlaps_with_another_encounter_flag) 
then '1' end as row_number_keep
from encounter_sequence_setup
)

, add_row_number as (select *
, row_number () over  (partition by patient_id order BY admit_date desc)  as row_count

from dates
where row_number_keep is not null
order by admit_date)

, join_setup as( select *
, lag(encounter_id) over (partition by patient_id order by row_count desc) as admit_encounter_id
from add_row_number)

, admits as (select *
, row_number () over  (partition by patient_id order BY admit_date desc) as admit_rank

from dates
where first_row_flag )

, discharge as 
(select distinct patient_id
, discharge_date
, admit_encounter_id
, row_number () over  (partition by patient_id, disqualified_encounter_flag order BY discharge_date desc)  as admit_rank
from join_setup
where last_row_flag 
)

, join_admits_discharge as 
(select 
 admits.encounter_id
, admits.patient_id
, admits.admit_date
, discharge.discharge_date
, discharge_disposition_code
, facility_npi
, ms_drg_code
, paid_amount
, date_diff( discharge.discharge_date, admits.admit_date, day) as length_of_stay
, index_admission_flag 
, planned_flag
, specialty_cohort
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
and admits.encounter_id=discharge.admit_encounter_id
) 

, transfers_combined as (
select d.*
from join_admits_discharge d
full outer join multiple_transfers_one_row_final f
on d.encounter_id=f.encounter_id
where f.encounter_id is null
)

, transfers_combined_final as (select encounter_id
, patient_id
, admit_date
, discharge_date
from transfers_combined

union all 

select encounter_id
, patient_id
, admit_date
, discharge_date
from multiple_transfers_one_row_final t

)

select *
from transfers_combined_final

/*

, join_together_encounter_sequence as (
select *
from encounter_sequence
union all
select *
from join_admits_discharge)

, add_encounter_seq as (
select * 
, row_number() over(
        partition by patient_id order by admit_date, discharge_date
    ) as encounter_seq 
from join_together_encounter_sequence
)

, readmission_calc as (
select
    aa.encounter_id,
    aa.patient_id,
    aa.admit_date,
    aa.discharge_date,
    aa.discharge_disposition_code,
    aa.facility_npi,
    aa.ms_drg_code,
    --aa.paid_amount,
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
    add_encounter_seq aa
    left join add_encounter_seq bb
    on aa.patient_id = bb.patient_id
    and aa.encounter_seq + 1 = bb.encounter_seq
)

select *
from readmission_calc


*/