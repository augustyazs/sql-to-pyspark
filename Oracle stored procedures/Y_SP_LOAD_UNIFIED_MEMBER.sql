--------------------------------------------------------
--  File created - Wednesday-September-30-2026   
--------------------------------------------------------
--------------------------------------------------------
--  DDL for Procedure Y_SP_LOAD_UNIFIED_MEMBER
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "POPHEALTH_ANALYTICS_DEV"."Y_SP_LOAD_UNIFIED_MEMBER" 
as


--Added appointments from MV DM PATIENT ACCESS and F_SCHED_APPT

v_record_count NUMBER(20):=0; 
v_start_time DATE;
v_end_time DATE;
v_table_name VARCHAR2(400);
v_category VARCHAR2(20):='UNIFIED MEMBERSHIP';
v_payer VARCHAR2(100);
v_subpayer VARCHAR2(100);
v_err VARCHAR2(100);
v_msg VARCHAR2(200);
v_rolling_from_dt DATE;
v_rolling_to_dt DATE;

cursor cur_uv_cs is
with  
MEM_MTHS as 
(
    select /*+ parallel(4) */ * from 
    (
        select m.*,
        row_number() over(partition by PAYER, LOB, MEMBER_ID, EFFPER_DT order by member_months desc nulls last) rn
        from x_member_months m 
    ) where rn=1
),

prov as 
(
    select distinct NPI, LVL2_EMP_STATUS, LVL3_SUBGROUP, LVL4_PRACTICE, FULL_NAME, DEFAULT_TIN, PCP_SPC, CMS_PCP_SPC
    from x_provider
),

epic as
(
    select distinct LVL4_PRACTICE,EPIC_STATUS from YREF_EMP_MED_DIRECTOR_LIST
),

awvs AS
(
    select /*+ parallel(4) */ payer,lob,member_id,claim_id from x_fact_service where include_flag='Y' and 
    SERVICE_CODE IN  ('G0402','G0439', 'G0438')
    group by payer,lob,member_id,claim_id
)

select /*+ parallel(4) */ ch.payer, ch.lob, ch.member_Id, ch.PRI_MRN as MRN, ch.CLAIM_ID as ENCOUNTER_ID, ch.effper, ch.DATE_OF_SERVICE as DATE_OF_SERVICE, 'CLAIMSTAR' as source, 'ARRIVED' as visit_status_type,

mm.attributed_pcp_npi historical_pcp_npi, mm.attributed_pcp_tax_id as historical_pcp_tin, hp.LVL2_EMP_STATUS as historical_pcp_emp_status, hp.LVL3_SUBGROUP as historical_pcp_pod, hp.LVL4_PRACTICE as historical_pcp_practice,
hp.FULL_NAME as historical_pcp_provider,hp.PCP_SPC historical_prov_pcp_spc, hp.CMS_PCP_SPC historical_prov_cms_pcp_spc, 
case when mm.attributed_pcp_npi is not null and hpe.EPIC_STATUS is null then 'NON-EPIC' else hpe.EPIC_STATUS end as historical_prac_epic_status,

decode(ext.currently_active,'Y',ext.ATTRIBUTED_PCP_NPI,null) current_pcp_npi, mme.attributed_pcp_tax_id as current_pcp_tin, cp.LVL2_EMP_STATUS as current_pcp_emp_status, ext.PCP_LVL3_POD as current_pcp_pod, ext.PCP_LVL4_PRACTICE as current_pcp_practice,
cp.FULL_NAME as current_pcp_provider,cp.PCP_SPC current_prov_pcp_spc, cp.CMS_PCP_SPC current_prov_cms_pcp_spc, 
case when ext.attributed_pcp_npi is not null and cpe.EPIC_STATUS is null then 'NON-EPIC' else cpe.EPIC_STATUS end as current_prac_epic_status,

(CASE WHEN ((ch.SERVICING_NPI IN ('1013360528','1851328199', '1124347182','1588691828', '1730317769', '1215978960') OR ch.CLAIM_PLACE_OF_SERVICE = 'Hospital')
and ch.claim_type  = 'Facility')-- APT-3789 Add facility constraint in Y_SP_LOAD_UNIFIED_MEMBER
THEN ch.ATTENDING_NPI ELSE ch.SERVICING_NPI END) as servicing_pcp_npi, 
(CASE WHEN ((ch.SERVICING_NPI IN ('1013360528','1851328199', '1124347182','1588691828', '1730317769', '1215978960') OR ch.CLAIM_PLACE_OF_SERVICE = 'Hospital')
and ch.claim_type  = 'Facility')-- APT-3789 Add facility constraint in Y_SP_LOAD_UNIFIED_MEMBER
THEN ch.ATTENDING_TIN ELSE ch.SERVICING_TIN END) as servicing_pcp_tin, 
sp.LVL2_EMP_STATUS as servicing_pcp_emp_status,
sp.LVL3_SUBGROUP as servicing_pcp_pod, sp.LVL4_PRACTICE as servicing_pcp_practice,
sp.FULL_NAME as servicing_pcp_provider,sp.PCP_SPC servicing_prov_pcp_spc, sp.CMS_PCP_SPC servicing_prov_cms_pcp_spc, 
case when (CASE WHEN ((ch.SERVICING_NPI IN ('1013360528','1851328199', '1124347182','1588691828', '1730317769', '1215978960') OR ch.CLAIM_PLACE_OF_SERVICE = 'Hospital')
and ch.claim_type  = 'Facility') THEN ch.ATTENDING_NPI ELSE ch.SERVICING_NPI END)-- APT-3789 Add facility constraint in Y_SP_LOAD_UNIFIED_MEMBER
 is not null and spe.EPIC_STATUS is null then 'NON-EPIC' else spe.EPIC_STATUS end as servicing_prac_epic_status,

case when nvl(mm.member_months,0) > 0 then 'Y' else 'N' end as ATTRIBUTED_AT_VISIT,
nvl(ext.currently_active,'N') currently_attributed,

case when nvl(mm.attributed_pcp_npi,'x')=(CASE WHEN ((ch.SERVICING_NPI IN ('1013360528','1851328199', '1124347182','1588691828', '1730317769', '1215978960') OR ch.CLAIM_PLACE_OF_SERVICE = 'Hospital') 
and  ch.claim_type  = 'Facility')-- APT-3789 Add facility constraint in Y_SP_LOAD_UNIFIED_MEMBER
    THEN ch.ATTENDING_NPI ELSE ch.SERVICING_NPI END) then 'Y' else 'N' end as hist_serv_prov_check,
case when hp.LVL4_PRACTICE=sp.LVL4_PRACTICE then 'Y' else 'N' end as hist_serv_prac_check,

case when decode(ext.currently_active,'Y',ext.ATTRIBUTED_PCP_NPI,null)=(CASE WHEN ((ch.SERVICING_NPI IN ('1013360528','1851328199', '1124347182','1588691828', '1730317769', '1215978960') OR ch.CLAIM_PLACE_OF_SERVICE = 'Hospital')
and ch.claim_type  = 'Facility')    THEN ch.ATTENDING_NPI ELSE ch.SERVICING_NPI END) then 'Y' else 'N' end as current_serv_prov_check,-- APT-3789 Add facility constraint in Y_SP_LOAD_UNIFIED_MEMBER
case when cp.LVL4_PRACTICE=sp.LVL4_PRACTICE then 'Y' else 'N' end as current_serv_prac_check,

case when nvl(sp.PCP_SPC,'X')='PCP' then 'Y' else 'N' end as visit_with_any_spc_pcp,
case when nvl(sp.CMS_PCP_SPC,'X')='PCP' then 'Y' else 'N' end as visit_with_any_cms_spc_pcp,

decode(awv.claim_id,null,'N','Y') awv_indicator,

trunc(sysdate) as load_dt

from 
(
    select /*+ parallel(4) */ * from xc_um_claim_header 
    where INCLUDE_FLAG = 'Y'
    AND CLAIM_TYPE IN ('Professional', 'Facility')
    AND CLAIM_CATEGORY IN ('Professional', 'Outpatient')
    AND CLAIM_PLACE_OF_SERVICE IN ('Office Visit - PCP Visit', 'Hospital', 'Office Visit - Specialty Consult', 'Clinic')
    AND (IP_EPISODE_KEY IS NULL AND ED_EPISODE_KEY IS NULL) -- CS-2265 - Z_UNIFIED_MEMBER_VISITS logic Change 2/29
    AND DATE_OF_SERVICE >= to_date('01/01/2018','mm/dd/yyyy')
) CH

left outer join MEM_MTHS MM
on ch.payer=mm.payer and ch.lob=mm.lob and ch.member_id=mm.member_Id and ch.effper=mm.effper

left outer join prov hp
on mm.attributed_pcp_npi = hp.npi
left outer join epic hpe
on hp.LVL4_PRACTICE=hpe.LVL4_PRACTICE

left outer join
(
    select nvl(b.member_Id_token,a.member_Id) mem_id_ref,a.*
    from mv_x_extended_active_members a 
    left outer join w_confidential_emp_map b
    on a.member_Id=b.member_id
) ext
on ch.payer=ext.payer and ch.lob=ext.lob and ch.member_id=ext.mem_id_ref
left outer join prov cp
on ext.attributed_pcp_npi = cp.npi
left outer join epic cpe
on ext.PCP_LVL4_PRACTICE=cpe.LVL4_PRACTICE
left outer join MEM_MTHS MME
on ext.payer=mme.payer and ext.lob=mme.lob and ext.mem_id_ref=mme.member_id and ext.LATEST_ACTIVE_MONTH=mme.effper

left outer join prov sp
on (CASE WHEN ((ch.SERVICING_NPI IN ('1013360528','1851328199', '1124347182','1588691828', '1730317769', '1215978960') OR ch.CLAIM_PLACE_OF_SERVICE = 'Hospital') 
and ch.claim_type  = 'Facility') THEN ch.ATTENDING_NPI ELSE ch.SERVICING_NPI END) = sp.npi -- APT-3789 Add facility constraint in Y_SP_LOAD_UNIFIED_MEMBER
left outer join epic spe
on sp.LVL4_PRACTICE=spe.LVL4_PRACTICE

left outer join awvs awv
on ch.payer=awv.payer and ch.lob=awv.lob and ch.member_Id=awv.member_id and ch.claim_Id=awv.claim_Id
;

TYPE ty_uv_cs IS TABLE OF cur_uv_cs%ROWTYPE;
var_uv_cs ty_uv_cs;

cursor cur_uv_msx is
with  
MEM_MTHS as 
(
    select /*+ parallel(4) */ * from 
    (
        select m.*,
        row_number() over(partition by PAYER, LOB, MEMBER_ID, EFFPER_DT order by member_months desc nulls last) rn
        from x_member_months m 
    ) where rn=1
),

prov as 
(
    select distinct NPI, LVL2_EMP_STATUS, LVL3_SUBGROUP, LVL4_PRACTICE, FULL_NAME, DEFAULT_TIN, PCP_SPC, CMS_PCP_SPC
    from x_provider
),

epic as
(
    select distinct LVL4_PRACTICE,EPIC_STATUS from YREF_EMP_MED_DIRECTOR_LIST
)

select /*+ parallel(4) */ distinct b.payer, b.lob, b.member_Id, a.PATIENT_MRN, a.VISIT_ID, to_char(trunc(a.APPT_DATETIME),'YYYY-MM') effper, trunc(a.APPT_DATETIME) as APPT_DATETIME, a.source, appt_status_msx,

hm.attributed_pcp_npi historical_pcp_npi, hm.attributed_pcp_tax_id as historical_pcp_tin, hp.LVL2_EMP_STATUS as historical_pcp_emp_status, hp.LVL3_SUBGROUP as historical_pcp_pod, hp.LVL4_PRACTICE as historical_pcp_practice,
hp.FULL_NAME as historical_pcp_provider,hp.PCP_SPC historical_prov_pcp_spc, hp.CMS_PCP_SPC historical_prov_cms_pcp_spc, 
case when hm.attributed_pcp_npi is not null and hpe.EPIC_STATUS is null then 'NON-EPIC' else hpe.EPIC_STATUS end as historical_prac_epic_status,

ext.ATTRIBUTED_PCP_NPI current_pcp_npi, mme.attributed_pcp_tax_id as current_pcp_tin, cp.LVL2_EMP_STATUS as current_pcp_emp_status, ext.PCP_LVL3_POD as current_pcp_pod, ext.PCP_LVL4_PRACTICE as current_pcp_practice,
cp.FULL_NAME as current_pcp_provider,cp.PCP_SPC current_prov_pcp_spc, cp.CMS_PCP_SPC current_prov_cms_pcp_spc, 
case when ext.attributed_pcp_npi is not null and cpe.EPIC_STATUS is null then 'NON-EPIC' else cpe.EPIC_STATUS end as current_prac_epic_status,

a.APPT_PHYSICIAN_NPI as servicing_pcp_npi, null as servicing_pcp_tin, sp.LVL2_EMP_STATUS as servicing_pcp_emp_status, sp.LVL3_SUBGROUP as servicing_pcp_pod, sp.LVL4_PRACTICE as servicing_pcp_practice,
sp.FULL_NAME as servicing_pcp_provider,sp.PCP_SPC servicing_prov_pcp_spc, sp.CMS_PCP_SPC servicing_prov_cms_pcp_spc, 
case when a.APPT_PHYSICIAN_NPI is not null and spe.EPIC_STATUS is null then 'NON-EPIC' else spe.EPIC_STATUS end as servicing_prac_epic_status,

case when nvl(hm.member_months,0) > 0 then 'Y' else 'N' end as ATTRIBUTED_AT_VISIT,
nvl(ext.currently_active,'N') currently_attributed,

case when nvl(hm.attributed_pcp_npi,'x')=a.APPT_PHYSICIAN_NPI then 'Y' else 'N' end as hist_serv_prov_check,
case when hp.LVL4_PRACTICE=sp.LVL4_PRACTICE then 'Y' else 'N' end as hist_serv_prac_check,

case when ext.ATTRIBUTED_PCP_NPI=a.APPT_PHYSICIAN_NPI then 'Y' else 'N' end as current_serv_prov_check,
case when cp.LVL4_PRACTICE=sp.LVL4_PRACTICE then 'Y' else 'N' end as current_serv_prac_check,

case when nvl(sp.PCP_SPC,'X')='PCP' then 'Y' else 'N' end as visit_with_any_spc_pcp,
case when nvl(sp.CMS_PCP_SPC,'X')='PCP' then 'Y' else 'N' end as visit_with_any_cms_spc_pcp,

decode(APPT_REASON,'ANNUAL/WELL VISIT','Y','N') as awv_indicator,
trunc(sysdate) as load_dt

from
(
--Commented to exclude reference to MSX_SCHED per Analytics confirmation in 4/9
--  select PATIENT_MRN, APPT_DATETIME, VISIT_ID, appt_status_msx, APPT_PHYSICIAN_NPI, APPT_REASON, 'MSX_SCHED' as source from 
--  (
--      select ms.*, rank() over(partition by PATIENT_MRN,trunc(APPT_DATETIME), nvl(VISIT_ID,0) order by  decode (appt_status_msx,'ARRIVED',1,0) desc nulls last) rnf
--      from
--      (
--            select /*+ parallel(4) */ to_char(PATIENT_MRN) PATIENT_MRN, trunc(APPT_DATETIME) APPT_DATETIME, VISIT_ID, appt_status_msx, APPT_PHYSICIAN_NPI, APPT_REASON--, 1 as SRC 
--            from msx_sched where trunc(APPT_DATETIME) >= to_date('01/01/2018','mm/dd/yyyy')
--        ) ms
--  ) where rnf=1
--    union all
    select /*+ parallel(4) */ to_char(MRN) PATIENT_MRN, APPT_DTTM APPT_DATETIME, to_char(PAT_ENC_CSN_ID) VISIT_ID, upper(APPT_STATUS_NAME) appt_status_msx, NPI APPT_PHYSICIAN_NPI, REASON APPT_REASON, 'MV_DM_PATIENT_ACCESS' as source
    from z_md_pat_acc_temp
    union all
    select /*+ parallel(4) */ to_char(Y_MRN) MRN, APPT_DTTM, to_char(PAT_ENC_CSN_ID) PAT_ENC_CSN_ID, upper(NAME), NPI, REASON , 'F_SCHED_APPT' as source
    from z_schd_appt_temp
)a
left outer join 
(

    select /*+ parallel(4) */ distinct payer, lob, member_Id, fact from x_fact_member where fact_shortdescr='PRI-MRN' and payer <> 'ANY' and fact<>'0'
    union
    select /*+ parallel(4) */ distinct payer, lob, member_Id, pri_mrn from xc_um_claim_header where DATE_OF_SERVICE >= to_date('01/01/2018','mm/dd/yyyy') and pri_mrn is not null

) b
on a.PATIENT_MRN=b.fact

left outer join MEM_MTHS hm
on b.payer=hm.payer and b.lob=hm.lob and b.member_Id=hm.member_id and to_char(a.APPT_DATETIME,'yyyy-mm')=hm.effper
left outer join prov hp
on hm.attributed_pcp_npi = hp.npi
left outer join epic hpe
on hp.LVL4_PRACTICE=hpe.LVL4_PRACTICE

left outer join
(
    select nvl(b.member_Id_token,a.member_Id) mem_id_ref,a.*
    from mv_x_extended_active_members a 
    left outer join w_confidential_emp_map b
    on a.member_Id=b.member_id
    where currently_active='Y'
) ext
on b.payer=ext.payer and b.lob=ext.lob and b.member_id=ext.mem_id_ref
left outer join prov cp
on ext.attributed_pcp_npi = cp.npi
left outer join epic cpe
on ext.PCP_LVL4_PRACTICE=cpe.LVL4_PRACTICE
left outer join MEM_MTHS MME
on ext.payer=mme.payer and ext.lob=mme.lob and ext.mem_id_ref=mme.member_id and ext.LATEST_ACTIVE_MONTH=mme.effper

left outer join prov sp
on  a.APPT_PHYSICIAN_NPI = sp.npi
left outer join epic spe
on sp.LVL4_PRACTICE=spe.LVL4_PRACTICE;

TYPE ty_uv_msx IS TABLE OF cur_uv_msx%ROWTYPE;
var_uv_msx ty_uv_msx;

cursor cur_uv_ryan is
with  
MEM_MTHS as 
(
    select /*+ parallel(4) */ * from 
    (
        select m.*,
        row_number() over(partition by PAYER, LOB, MEMBER_ID, EFFPER_DT order by member_months desc nulls last) rn
        from x_member_months m 
    ) where rn=1
),

prov as 
(
    select distinct NPI, LVL2_EMP_STATUS, LVL3_SUBGROUP, LVL4_PRACTICE, FULL_NAME, DEFAULT_TIN, PCP_SPC, CMS_PCP_SPC
    from x_provider
),

epic as
(
    select distinct LVL4_PRACTICE,EPIC_STATUS from YREF_EMP_MED_DIRECTOR_LIST
)

select /*+ parallel(4) */ distinct fm.payer, fm.lob, nvl(fm.member_Id, ry.raw_member_Id) member_Id, xm.pri_mrn,
ry.IDENTIFIER1||'~'||ry.IDENTIFIER2||'~'||ry.APPTDATE encounter_id, to_char(ry.APPTDATE,'yyyy-mm') effper, ry.APPTDATE, 'RYAN SCHEDULING' as source,
ry.APPTSTATUS,

hm.attributed_pcp_npi historical_pcp_npi, hm.attributed_pcp_tax_id as historical_pcp_tin, hp.LVL2_EMP_STATUS as historical_pcp_emp_status, hp.LVL3_SUBGROUP as historical_pcp_pod, hp.LVL4_PRACTICE as historical_pcp_practice,
hp.FULL_NAME as historical_pcp_provider,hp.PCP_SPC historical_prov_pcp_spc, hp.CMS_PCP_SPC historical_prov_cms_pcp_spc, 
case when hm.attributed_pcp_npi is not null and hpe.EPIC_STATUS is null then 'NON-EPIC' else hpe.EPIC_STATUS end as historical_prac_epic_status,

ext.ATTRIBUTED_PCP_NPI current_pcp_npi, mme.attributed_pcp_tax_id as current_pcp_tin, cp.LVL2_EMP_STATUS as current_pcp_emp_status, ext.PCP_LVL3_POD as current_pcp_pod, ext.PCP_LVL4_PRACTICE as current_pcp_practice,
cp.FULL_NAME as current_pcp_provider,cp.PCP_SPC current_prov_pcp_spc, cp.CMS_PCP_SPC current_prov_cms_pcp_spc, 
case when ext.attributed_pcp_npi is not null and cpe.EPIC_STATUS is null then 'NON-EPIC' else cpe.EPIC_STATUS end as current_prac_epic_status,


ry.APPTPROVIDERNPI as servicing_pcp_npi, null as servicing_pcp_tin, sp.LVL2_EMP_STATUS as servicing_pcp_emp_status, sp.LVL3_SUBGROUP as servicing_pcp_pod, sp.LVL4_PRACTICE as servicing_pcp_practice,
sp.FULL_NAME as servicing_pcp_provider,sp.PCP_SPC servicing_prov_pcp_spc, sp.CMS_PCP_SPC servicing_prov_cms_pcp_spc, 
case when ry.APPTPROVIDERNPI is not null and spe.EPIC_STATUS is null then 'NON-EPIC' else spe.EPIC_STATUS end as servicing_prac_epic_status,

case when nvl(hm.member_months,0) > 0 then 'Y' else 'N' end as ATTRIBUTED_AT_VISIT,
nvl(ext.currently_active,'N') currently_attributed,

case when nvl(hm.attributed_pcp_npi,'x')=ry.APPTPROVIDERNPI then 'Y' else 'N' end as hist_serv_prov_check,
case when hp.LVL4_PRACTICE=sp.LVL4_PRACTICE then 'Y' else 'N' end as hist_serv_prac_check,

case when ext.ATTRIBUTED_PCP_NPI=ry.APPTPROVIDERNPI then 'Y' else 'N' end as current_serv_prov_check,
case when cp.LVL4_PRACTICE=sp.LVL4_PRACTICE then 'Y' else 'N' end as current_serv_prac_check,

case when nvl(sp.PCP_SPC,'X')='PCP' then 'Y' else 'N' end as visit_with_any_spc_pcp,
case when nvl(sp.CMS_PCP_SPC,'X')='PCP' then 'Y' else 'N' end as visit_with_any_cms_spc_pcp,

null as awv_indicator,
trunc(sysdate) as load_dt

from
(
    select FIRST_NAME, LAST_NAME, MIDDLE_NAME, DOB, GENDER, IDENTIFIER1, IDENTIFIER2, APPTDATE, APPTSTATUS, APPTPROVIDERNPI,
    substr(IDENTIFIER2,instr(IDENTIFIER2,'_',1,1)+1) raw_member_Id
    from 
    (
        select a.*,
        row_number() over(partition by IDENTIFIER1, IDENTIFIER2, trunc(APPTDATE) order by trunc(LOAD_DATE) desc nulls last) rn
        from Y_RYAN_SCHEDULING a
        --where identifier2='13001_8P15E43RR63'
    ) where rn=1 and trunc(APPTDATE) >= to_date('01/01/2018','mm/dd/yyyy')
) ry
left outer join 
(
    select /*+ parallel(4) */ distinct payer, lob, member_Id, fact from x_fact_member where fact_category='Member Identifiers' and payer <> 'ANY' and fact<>'0'
    union
    select /*+ parallel(4) */ distinct payer, lob, member_Id, pri_mrn from xc_um_claim_header where DATE_OF_SERVICE >= to_date('01/01/2018','mm/dd/yyyy') and pri_mrn is not null
) fm
on ry.raw_member_Id=fm.fact
left outer join x_member xm
on fm.payer=xm.payer and fm.lob=xm.lob and fm.member_Id=xm.member_id

left outer join MEM_MTHS hm
on fm.payer=hm.payer and fm.lob=hm.lob and fm.member_Id=hm.member_id and to_char(ry.APPTDATE,'yyyy-mm')=hm.effper
left outer join prov hp
on hm.attributed_pcp_npi = hp.npi
left outer join epic hpe
on hp.LVL4_PRACTICE=hpe.LVL4_PRACTICE

left outer join
(
    select nvl(b.member_Id_token,a.member_Id) mem_id_ref,a.*
    from mv_x_extended_active_members a 
    left outer join w_confidential_emp_map b
    on a.member_Id=b.member_id
    where currently_active='Y'
) ext
on fm.payer=ext.payer and fm.lob=ext.lob and fm.member_id=ext.mem_id_ref
left outer join prov cp
on ext.attributed_pcp_npi = cp.npi
left outer join epic cpe
on ext.PCP_LVL4_PRACTICE=cpe.LVL4_PRACTICE
left outer join MEM_MTHS MME
on ext.payer=mme.payer and ext.lob=mme.lob and ext.mem_id_ref=mme.member_id and ext.LATEST_ACTIVE_MONTH=mme.effper

left outer join prov sp
on  ry.APPTPROVIDERNPI = sp.npi
left outer join epic spe
on sp.LVL4_PRACTICE=spe.LVL4_PRACTICE;

TYPE ty_uv_ryan IS TABLE OF cur_uv_ryan%ROWTYPE;
var_uv_ryan ty_uv_ryan;

---------------------------------------------------------------------------

cursor cur_uvm_r12 is
with  
MEM_MTHS as 
(
    select m1.*, f1.mrn
    from
    (
        select /*+ parallel(4) */ * from 
        (
            select m.*,
            row_number() over(partition by PAYER, LOB, MEMBER_ID, EFFPER_DT order by member_months desc nulls last) rn
            from x_member_months m 
        ) where rn=1 and nvl(member_months,0) > 0
    ) m1
    left outer join
    (
        select  /*+ parallel(4) */ distinct payer, lob, member_Id, fact as mrn from x_fact_member where fact_shortdescr='PRI-MRN'
    ) f1
    on m1.PAYER=f1.PAYER and m1.lob=f1.lob and m1.MEMBER_ID=f1.MEMBER_ID
),

prov as 
(
    select distinct NPI, LVL2_EMP_STATUS, LVL3_SUBGROUP, LVL4_PRACTICE, FULL_NAME, DEFAULT_TIN, PCP_SPC, CMS_PCP_SPC
    from x_provider
),

epic as
(
    select distinct LVL4_PRACTICE,EPIC_STATUS from YREF_EMP_MED_DIRECTOR_LIST
),

ext as 
(
    select nvl(b.member_Id_token,a.member_Id) mem_id_ref,a.*
    from mv_x_extended_active_members a 
    left outer join w_confidential_emp_map b
    on a.member_Id=b.member_id
)

select distinct 
extract(year from EFFPER_DT) reporting_year
--, dense_rank() over(partition by nvl(stg.PAYER,'P'), nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'), nvl(stg.mrn,'M2') order by stg.EFFPER_DT) reporting_month
, dense_rank() over(partition by to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy') order by stg.EFFPER_DT) reporting_month
--, stg.EFFPER_DT
, stg.EFFPER_DT reporting_date
, to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy') reporting_period  
, stg.payer
, stg.lob
, stg.member_Id
, stg.mrn
, stg.attributed_pcp_npi as pcp_npi
, p1.FULL_NAME as PCP_PROVIDER
, p1.LVL2_EMP_STATUS as PCP_EMP_STATUS
, p1.PCP_SPC
, p1.CMS_PCP_SPC
, p1.LVL3_SUBGROUP PCP_POD
, p1.LVL4_PRACTICE PCP_PRACTICE
, e1.EPIC_STATUS EPIC_STATUS
, case when nvl(stg.attributed_pcp_npi,'x') = nvl(e1.ATTRIBUTED_PCP_NPI,'e') then 'Currently Attributed' else 'Historically Attributed' end as PROVIDER_ATTRIBUTION_TYPE
, stg.member_months
, b.MEASUREMENT_PERIOD_DESC as reporting_window
, nvl(e1.currently_active,'N') as CURRENTLY_ATTRIBUTED
, max(nvl(case when nvl(uv.SERVICING_PCP_NPI,'S') = nvl(uv.HISTORICAL_PCP_NPI,'H') then 1 else 0 end,0)) 
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2') ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING) pcp_npi_visit
, max(nvl(case when nvl(uv.SERVICING_PCP_PRACTICE,'S') = nvl(uv.HISTORICAL_PCP_PRACTICE,'H') then 1 else 0 end,0)) 
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2') ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING) pcp_practice_visit
, max(nvl(case when nvl(uv.SERVICING_PCP_POD,'S') = nvl(uv.HISTORICAL_PCP_POD,'H') then 1 else 0 end,0)) 
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2') ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING) pcp_pod_visit
, nvl(max(nvl(case when uv2.HISTORICAL_PCP_PRACTICE is not null then 1 else 0 end,0)) 
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2') ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING),0) mt_sinai_visit
, nvl(sum(nvl(case when nvl(uv.SERVICING_PCP_NPI,'S') = nvl(uv.HISTORICAL_PCP_NPI,'H') then 1 else 0 end,0))
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2') ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING),0) count_pcp_npi_visits
, nvl(sum(nvl(case when nvl(uv.SERVICING_PCP_PRACTICE,'S') = nvl(uv.HISTORICAL_PCP_PRACTICE,'H') then 1 else 0 end,0))
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2') ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING),0) count_pcp_practice_visits
, nvl(sum(nvl(case when nvl(uv.SERVICING_PROV_PCP_SPC,'P') = 'PCP' then 1 else 0 end,0))
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2') ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING),0) count_any_pcp_npi_visits
, nvl(sum(nvl(case when nvl(uv.SERVICING_PROV_CMS_PCP_SPC,'P') = 'PCP' then 1 else 0 end,0))
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2') ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING),0) count_any_cms_pcp_npi_visits
, max(nvl(case when coalesce(uv3.MEMBER_ID,uv3.mrn) is not null then 1 else 0 end,0)) 
    over(partition by stg.EFFPER_DT, to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy'), stg.payer, stg.lob, stg.member_Id, stg.mrn, p1.LVL3_SUBGROUP, p1.LVL4_PRACTICE, e1.EPIC_STATUS, case when nvl(stg.attributed_pcp_npi,'x') = nvl(e1.ATTRIBUTED_PCP_NPI,'e') then 'Currently Attributed' else 'Historically Attributed' end, stg.member_months, b.MEASUREMENT_PERIOD_DESC, nvl(e1.currently_active,' N')) Upcoming_Appointments_Rolling
, 0 as Upcoming_Appointments_YTD
, 0 as Upcoming_Appointments_MSSP
, trunc(sysdate) LOAD_DT
from 
MEM_MTHS stg
inner join
(
    select * from yref_meas_period
    union all
    --select 'Rolling 12', to_char(extract(year from sysdate)), trunc(sysdate,'month')-365, last_day(add_months(trunc(sysdate,'month')-365,11)) from dual
    select 'Rolling 12', to_char(extract(year from v_rolling_to_dt)),  v_rolling_from_dt , v_rolling_to_dt from dual
) b
on (stg.EFFPER_DT between b.START_DT and b.END_DT) and b.MEASUREMENT_PERIOD_DESC='Rolling 12'

left outer join prov p1
on stg.attributed_pcp_npi = p1.npi
left outer join epic e1
on p1.LVL4_PRACTICE=e1.LVL4_PRACTICE

left outer join ext e1
on nvl(stg.PAYER,'P') = e1.payer and nvl(stg.LOB,'L') = e1.lob and nvl(stg.MEMBER_ID,'M')=e1.member_id

left outer join Z_UNIFIED_MEMBER_VISITS uv
on nvl(stg.PAYER,'P') = nvl(uv.PAYER,'P') and nvl(stg.LOB,'L') = nvl(uv.LOB,'L') and nvl(stg.MEMBER_ID,'M')=nvl(uv.MEMBER_ID,'M') and nvl(stg.MRN,'M2')=nvl(uv.MRN,'M2') and stg.EFFPER_DT = trunc(uv.DATE_OF_SERVICE,'month')

left outer join 
(
    select distinct payer, lob, member_id, mrn, HISTORICAL_PCP_PRACTICE
    from Z_UNIFIED_MEMBER_VISITS uva
    inner join
    (
        select * from yref_meas_period
        union all
        select 'Rolling 12', to_char(extract(year from v_rolling_to_dt)),  v_rolling_from_dt , v_rolling_to_dt from dual
    ) b
    on (trunc(uva.DATE_OF_SERVICE,'month') between b.START_DT and b.END_DT) and b.MEASUREMENT_PERIOD_DESC='Rolling 12'
) uv2
on nvl(uv.PAYER,'P') = nvl(uv2.PAYER,'P') and nvl(uv.LOB,'L') = nvl(uv2.LOB,'L') and nvl(uv.MEMBER_ID,'M')=nvl(uv2.MEMBER_ID,'M') and nvl(uv.MRN,'M2')=nvl(uv2.MRN,'M2') 
and nvl(uv.SERVICING_PCP_PRACTICE,'S') = nvl(uv2.HISTORICAL_PCP_PRACTICE,'H') 

left outer join
(
    select distinct payer, lob, member_id, mrn
    from Z_UNIFIED_MEMBER_VISITS
    where VISIT_STATUS_TYPE='SCHEDULED' and DATE_OF_SERVICE between trunc(sysdate) and trunc(sysdate)+180
) uv3
on nvl(stg.PAYER,'P') = nvl(uv3.PAYER,'P') and nvl(stg.LOB,'L') = nvl(uv3.LOB,'L') and nvl(stg.MEMBER_ID,'M')=nvl(uv3.MEMBER_ID,'M') and nvl(uv.mrn,'M2')=nvl(uv3.MRN,'M2')

--where nvl(stg.member_months,0) > 0 --and stg.member_Id='00000025151124170925' and stg.payer='AETNA' 
order by stg.EFFPER_DT
 ;

TYPE ty_uvm_r12 IS TABLE OF cur_uvm_r12%ROWTYPE;
var_uvm_r12 ty_uvm_r12;

cursor cur_uvm_calyr is 
with  
MEM_MTHS as 
(
    select m1.*, f1.mrn
    from
    (
        select /*+ parallel(4) */ * from 
        (
            select m.*,
            row_number() over(partition by PAYER, LOB, MEMBER_ID, EFFPER_DT order by member_months desc nulls last) rn
            from x_member_months m 
        ) where rn=1 and nvl(member_months,0) > 0
    ) m1
    left outer join
    (
        select  /*+ parallel(4) */ distinct payer, lob, member_Id, fact as mrn from x_fact_member where fact_shortdescr='PRI-MRN'
    ) f1
    on m1.PAYER=f1.PAYER and m1.lob=f1.lob and m1.MEMBER_ID=f1.MEMBER_ID
),

prov as 
(
    select distinct NPI, LVL2_EMP_STATUS, LVL3_SUBGROUP, LVL4_PRACTICE, FULL_NAME, DEFAULT_TIN, PCP_SPC, CMS_PCP_SPC
    from x_provider
),

epic as
(
    select distinct LVL4_PRACTICE,EPIC_STATUS from YREF_EMP_MED_DIRECTOR_LIST
),

ext as 
(
    select nvl(b.member_Id_token,a.member_Id) mem_id_ref,a.*
    from mv_x_extended_active_members a 
    left outer join w_confidential_emp_map b
    on a.member_Id=b.member_id
)

select distinct 
extract(year from EFFPER_DT) reporting_year
--, dense_rank() over(partition by nvl(stg.PAYER,'P'), nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'), nvl(stg.mrn,'M2') order by stg.EFFPER_DT) reporting_month
, dense_rank() over(partition by to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy') order by stg.EFFPER_DT) reporting_month
--, stg.EFFPER_DT
, stg.EFFPER_DT reporting_date
, to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy') reporting_period  
, stg.payer
, stg.lob
, stg.member_Id
, stg.mrn 
, stg.attributed_pcp_npi PCP_NPI
, p1.FULL_NAME PCP_PROVIDER
, p1.LVL2_EMP_STATUS PCP_EMP_STATUS
, p1.PCP_SPC
, p1.CMS_PCP_SPC
, p1.LVL3_SUBGROUP PCP_POD
, p1.LVL4_PRACTICE PCP_PRACTICE
, e1.EPIC_STATUS EPIC_STATUS
, case when nvl(stg.attributed_pcp_npi,'x') = nvl(e1.ATTRIBUTED_PCP_NPI,'e') then 'Currently Attributed' else 'Historically Attributed' end as PROVIDER_ATTRIBUTION_TYPE
, stg.member_months
, b.MEASUREMENT_PERIOD_DESC as reporting_window
, nvl(e1.currently_active,'N') as CURRENTLY_ATTRIBUTED
, max(nvl(case when nvl(uv.SERVICING_PCP_NPI,'S') = nvl(uv.HISTORICAL_PCP_NPI,'H') then 1 else 0 end,0)) 
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2'), b.MEASUREMENT_PERIOD_DESC, to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy')  ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING) pcp_npi_visit
, max(nvl(case when nvl(uv.SERVICING_PCP_PRACTICE,'S') = nvl(uv.HISTORICAL_PCP_PRACTICE,'H') then 1 else 0 end,0)) 
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2'), b.MEASUREMENT_PERIOD_DESC, to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy')  ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING) pcp_practice_visit
, max(nvl(case when nvl(uv.SERVICING_PCP_POD,'S') = nvl(uv.HISTORICAL_PCP_POD,'H') then 1 else 0 end,0)) 
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2'), b.MEASUREMENT_PERIOD_DESC, to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy')  ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING) pcp_pod_visit
, nvl(max(nvl(case when uv2.HISTORICAL_PCP_PRACTICE is not null then 1 else 0 end,0)) 
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2'), b.MEASUREMENT_PERIOD_DESC, to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy')  ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING),0) mt_sinai_visit
, nvl(sum(nvl(case when nvl(uv.SERVICING_PCP_NPI,'S') = nvl(uv.HISTORICAL_PCP_NPI,'H') then 1 else 0 end,0))
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2'), b.MEASUREMENT_PERIOD_DESC, to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy')  ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING),0) count_pcp_npi_visits
, nvl(sum(nvl(case when nvl(uv.SERVICING_PCP_PRACTICE,'S') = nvl(uv.HISTORICAL_PCP_PRACTICE,'H') then 1 else 0 end,0))
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2'), b.MEASUREMENT_PERIOD_DESC, to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy')  ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING),0) count_pcp_practice_visits
, nvl(sum(nvl(case when nvl(uv.SERVICING_PROV_PCP_SPC,'P') = 'PCP' then 1 else 0 end,0))
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2'), b.MEASUREMENT_PERIOD_DESC, to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy')  ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING),0) count_any_pcp_npi_visits
, nvl(sum(nvl(case when nvl(uv.SERVICING_PROV_CMS_PCP_SPC,'P') = 'PCP' then 1 else 0 end,0))
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2'), b.MEASUREMENT_PERIOD_DESC, to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy')  ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING),0) count_any_cms_pcp_npi_visits
, max(nvl(case when coalesce(uv3.MEMBER_ID,uv3.mrn) is not null then 1 else 0 end,0)) 
    over(partition by stg.EFFPER_DT, to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy'), stg.payer, stg.lob, stg.member_Id, stg.mrn, p1.LVL3_SUBGROUP, p1.LVL4_PRACTICE, e1.EPIC_STATUS, case when nvl(stg.attributed_pcp_npi,'x') = nvl(e1.ATTRIBUTED_PCP_NPI,'e') then 'Currently Attributed' else 'Historically Attributed' end, stg.member_months, b.MEASUREMENT_PERIOD_DESC, nvl(e1.currently_active,' N')) Upcoming_Appointments_Rolling
, 0 as Upcoming_Appointments_YTD
, 0 as Upcoming_Appointments_MSSP
, trunc(sysdate) LOAD_DT
from 
MEM_MTHS stg
inner join
(
    select * from yref_meas_period
    union all
    select 'Rolling 12', to_char(extract(year from v_rolling_to_dt)),  v_rolling_from_dt , v_rolling_to_dt from dual
) b
on (stg.EFFPER_DT between b.START_DT and b.END_DT) and b.MEASUREMENT_PERIOD_DESC='Calendar Year' and b.EFFYEAR >= '2019'

left outer join prov p1
on stg.attributed_pcp_npi = p1.npi
left outer join epic e1
on p1.LVL4_PRACTICE=e1.LVL4_PRACTICE

left outer join ext e1
on nvl(stg.PAYER,'P') = e1.payer and nvl(stg.LOB,'L') = e1.lob and nvl(stg.MEMBER_ID,'M')=e1.member_id

left outer join Z_UNIFIED_MEMBER_VISITS uv
on nvl(stg.PAYER,'P') = nvl(uv.PAYER,'P') and nvl(stg.LOB,'L') = nvl(uv.LOB,'L') and nvl(stg.MEMBER_ID,'M')=nvl(uv.MEMBER_ID,'M') and nvl(stg.MRN,'M2')=nvl(uv.MRN,'M2') and stg.EFFPER_DT = trunc(uv.DATE_OF_SERVICE,'month')

left outer join 
(
    select distinct payer, lob, member_id, mrn, HISTORICAL_PCP_PRACTICE
    from Z_UNIFIED_MEMBER_VISITS uva
    inner join
    (
        select * from yref_meas_period
        union all
        select 'Rolling 12', to_char(extract(year from v_rolling_to_dt)),  v_rolling_from_dt , v_rolling_to_dt from dual
    ) b
    on (trunc(uva.DATE_OF_SERVICE,'month') between b.START_DT and b.END_DT) and b.MEASUREMENT_PERIOD_DESC='Calendar Year'
) uv2
on nvl(uv.PAYER,'P') = nvl(uv2.PAYER,'P') and nvl(uv.LOB,'L') = nvl(uv2.LOB,'L') and nvl(uv.MEMBER_ID,'M')=nvl(uv2.MEMBER_ID,'M') and nvl(uv.MRN,'M2')=nvl(uv2.MRN,'M2') 
and nvl(uv.SERVICING_PCP_PRACTICE,'S') = nvl(uv2.HISTORICAL_PCP_PRACTICE,'H') 

left outer join
(
    select distinct payer, lob, member_id, mrn
    from Z_UNIFIED_MEMBER_VISITS
    where VISIT_STATUS_TYPE='SCHEDULED' and DATE_OF_SERVICE between trunc(sysdate) and trunc(sysdate)+180
) uv3
on nvl(stg.PAYER,'P') = nvl(uv3.PAYER,'P') and nvl(stg.LOB,'L') = nvl(uv3.LOB,'L') and nvl(stg.MEMBER_ID,'M')=nvl(uv3.MEMBER_ID,'M') and nvl(uv.mrn,'M2')=nvl(uv3.MRN,'M2')

--where nvl(stg.member_months,0) > 0 --and stg.member_Id='00000025151124170925' and stg.payer='AETNA' 
order by stg.EFFPER_DT
 ;

TYPE ty_uvm_calyr IS TABLE OF cur_uvm_calyr%ROWTYPE;
var_uvm_calyr ty_uvm_calyr;

cursor cur_uvm_mssp is 
with  
MEM_MTHS as 
(
    select m1.*, f1.mrn
    from
    (
        select /*+ parallel(4) */ * from 
        (
            select m.*,
            row_number() over(partition by PAYER, LOB, MEMBER_ID, EFFPER_DT order by member_months desc nulls last) rn
            from x_member_months m 
        ) where rn=1 and nvl(member_months,0) > 0
    ) m1
    left outer join
    (
        select  /*+ parallel(4) */ distinct payer, lob, member_Id, fact as mrn from x_fact_member where fact_shortdescr='PRI-MRN'
    ) f1
    on m1.PAYER=f1.PAYER and m1.lob=f1.lob and m1.MEMBER_ID=f1.MEMBER_ID
),

prov as 
(
    select distinct NPI, LVL2_EMP_STATUS, LVL3_SUBGROUP, LVL4_PRACTICE, FULL_NAME, DEFAULT_TIN, PCP_SPC, CMS_PCP_SPC
    from x_provider
),

epic as
(
    select distinct LVL4_PRACTICE,EPIC_STATUS from YREF_EMP_MED_DIRECTOR_LIST
),

ext as 
(
    select nvl(b.member_Id_token,a.member_Id) mem_id_ref,a.*
    from mv_x_extended_active_members a 
    left outer join w_confidential_emp_map b
    on a.member_Id=b.member_id
)

select distinct 
extract(year from EFFPER_DT) reporting_year
--, dense_rank() over(partition by nvl(stg.PAYER,'P'), nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'), nvl(stg.mrn,'M2') order by stg.EFFPER_DT) reporting_month
, dense_rank() over(partition by to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy') order by stg.EFFPER_DT) reporting_month
--, stg.EFFPER_DT
, stg.EFFPER_DT reporting_date
, to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy') reporting_period  
, stg.payer
, stg.lob
, stg.member_Id
, stg.mrn
, stg.attributed_pcp_npi pcp_npi
, p1.FULL_NAME PCP_PROVIDER
, p1.LVL2_EMP_STATUS pcp_EMP_STATUS
, p1.PCP_SPC
, p1.CMS_PCP_SPC
, p1.LVL3_SUBGROUP PCP_POD
, p1.LVL4_PRACTICE PCP_PRACTICE
, e1.EPIC_STATUS EPIC_STATUS
, case when nvl(stg.attributed_pcp_npi,'x') = nvl(e1.ATTRIBUTED_PCP_NPI,'e') then 'Currently Attributed' else 'Historically Attributed' end as PROVIDER_ATTRIBUTION_TYPE
, stg.member_months
, b.MEASUREMENT_PERIOD_DESC as reporting_window
, nvl(e1.currently_active,'N') as CURRENTLY_ATTRIBUTED
, max(nvl(case when nvl(uv.SERVICING_PCP_NPI,'S') = nvl(uv.HISTORICAL_PCP_NPI,'H') then 1 else 0 end,0)) 
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2'), b.MEASUREMENT_PERIOD_DESC, to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy')  ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING) pcp_npi_visit
, max(nvl(case when nvl(uv.SERVICING_PCP_PRACTICE,'S') = nvl(uv.HISTORICAL_PCP_PRACTICE,'H') then 1 else 0 end,0)) 
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2'), b.MEASUREMENT_PERIOD_DESC, to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy')  ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING) pcp_practice_visit
, max(nvl(case when nvl(uv.SERVICING_PCP_POD,'S') = nvl(uv.HISTORICAL_PCP_POD,'H') then 1 else 0 end,0)) 
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2'), b.MEASUREMENT_PERIOD_DESC, to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy')  ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING) pcp_pod_visit
, nvl(max(nvl(case when uv2.HISTORICAL_PCP_PRACTICE is not null then 1 else 0 end,0)) 
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2'), b.MEASUREMENT_PERIOD_DESC, to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy')  ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING),0) mt_sinai_visit
, nvl(sum(nvl(case when nvl(uv.SERVICING_PCP_NPI,'S') = nvl(uv.HISTORICAL_PCP_NPI,'H') then 1 else 0 end,0))
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2'), b.MEASUREMENT_PERIOD_DESC, to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy')  ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING),0) count_pcp_npi_visits
, nvl(sum(nvl(case when nvl(uv.SERVICING_PCP_PRACTICE,'S') = nvl(uv.HISTORICAL_PCP_PRACTICE,'H') then 1 else 0 end,0))
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2'), b.MEASUREMENT_PERIOD_DESC, to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy')  ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING),0) count_pcp_practice_visits
, nvl(sum(nvl(case when nvl(uv.SERVICING_PROV_PCP_SPC,'P') = 'PCP' then 1 else 0 end,0))
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2'), b.MEASUREMENT_PERIOD_DESC, to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy')  ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING),0) count_any_pcp_npi_visits
, nvl(sum(nvl(case when nvl(uv.SERVICING_PROV_CMS_PCP_SPC,'P') = 'PCP' then 1 else 0 end,0))
    OVER(PARTITION BY nvl(stg.PAYER,'P'),nvl(stg.LOB,'L'), nvl(stg.MEMBER_ID,'M'),nvl(stg.mrn,'M2'), b.MEASUREMENT_PERIOD_DESC, to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy')  ORDER by stg.EFFPER_DT ROWS UNBOUNDED PRECEDING),0) count_any_cms_pcp_npi_visits
, max(nvl(case when coalesce(uv3.MEMBER_ID,uv3.mrn) is not null then 1 else 0 end,0)) 
    over(partition by stg.EFFPER_DT, to_char(START_DT,'mm/dd/yyyy') ||' - ' || to_char(END_DT,'mm/dd/yyyy'), stg.payer, stg.lob, stg.member_Id, stg.mrn, p1.LVL3_SUBGROUP, p1.LVL4_PRACTICE, e1.EPIC_STATUS, case when nvl(stg.attributed_pcp_npi,'x') = nvl(e1.ATTRIBUTED_PCP_NPI,'e') then 'Currently Attributed' else 'Historically Attributed' end, stg.member_months, b.MEASUREMENT_PERIOD_DESC, nvl(e1.currently_active,' N')) Upcoming_Appointments_Rolling
, 0 as Upcoming_Appointments_YTD
, 0 as Upcoming_Appointments_MSSP
, trunc(sysdate) as LOAD_DT
from 
MEM_MTHS stg
inner join
(
    select * from yref_meas_period
    union all
    select 'Rolling 12', to_char(extract(year from v_rolling_to_dt)),  v_rolling_from_dt , v_rolling_to_dt from dual
) b
on (stg.EFFPER_DT between b.START_DT and b.END_DT) and b.MEASUREMENT_PERIOD_DESC='MSSP' and b.EFFYEAR >= '2019'

left outer join prov p1
on stg.attributed_pcp_npi = p1.npi
left outer join epic e1
on p1.LVL4_PRACTICE=e1.LVL4_PRACTICE

left outer join ext e1
on nvl(stg.PAYER,'P') = e1.payer and nvl(stg.LOB,'L') = e1.lob and nvl(stg.MEMBER_ID,'M')=e1.member_id

left outer join Z_UNIFIED_MEMBER_VISITS uv
on nvl(stg.PAYER,'P') = nvl(uv.PAYER,'P') and nvl(stg.LOB,'L') = nvl(uv.LOB,'L') and nvl(stg.MEMBER_ID,'M')=nvl(uv.MEMBER_ID,'M') and nvl(stg.MRN,'M2')=nvl(uv.MRN,'M2') and stg.EFFPER_DT = trunc(uv.DATE_OF_SERVICE,'month')

left outer join 
(
    select distinct payer, lob, member_id, mrn, HISTORICAL_PCP_PRACTICE
    from Z_UNIFIED_MEMBER_VISITS uva
    inner join
    (
        select * from yref_meas_period
        union all
        select 'Rolling 12', to_char(extract(year from v_rolling_to_dt)),  v_rolling_from_dt , v_rolling_to_dt from dual
    ) b
    on (trunc(uva.DATE_OF_SERVICE,'month') between b.START_DT and b.END_DT) and b.MEASUREMENT_PERIOD_DESC='Calendar Year'
) uv2
on nvl(uv.PAYER,'P') = nvl(uv2.PAYER,'P') and nvl(uv.LOB,'L') = nvl(uv2.LOB,'L') and nvl(uv.MEMBER_ID,'M')=nvl(uv2.MEMBER_ID,'M') and nvl(uv.MRN,'M2')=nvl(uv2.MRN,'M2') 
and nvl(uv.SERVICING_PCP_PRACTICE,'S') = nvl(uv2.HISTORICAL_PCP_PRACTICE,'H') 

left outer join
(
    select distinct payer, lob, member_id, mrn
    from Z_UNIFIED_MEMBER_VISITS
    where VISIT_STATUS_TYPE='SCHEDULED' and DATE_OF_SERVICE between trunc(sysdate) and trunc(sysdate)+180
) uv3
on nvl(stg.PAYER,'P') = nvl(uv3.PAYER,'P') and nvl(stg.LOB,'L') = nvl(uv3.LOB,'L') and nvl(stg.MEMBER_ID,'M')=nvl(uv3.MEMBER_ID,'M') and nvl(uv.mrn,'M2')=nvl(uv3.MRN,'M2')

--where nvl(stg.member_months,0) > 0 --and stg.member_Id='00000025151124170925' and stg.payer='AETNA' 
order by stg.EFFPER_DT
 ;

TYPE ty_uvm_mssp IS TABLE OF cur_uvm_mssp%ROWTYPE;
var_uvm_mssp ty_uvm_mssp;

BEGIN


BEGIN

v_payer:='ALL';
v_subpayer:='ALL';
v_record_count:=0;
v_start_time:=sysdate;
v_table_name := 'Y_UNIFIED_MEMBER_VISITS';

Insert into Y_TABLE_REFRESH(TABLE_NAME,PAYER,CATEGORY,DATE_THROUGH_TYPE,DATE_THROUGH,START_TIME,END_TIME,RECORD_COUNT,RECORD_DIFF,LOAD_DT,status)
            Values(v_table_name,v_subpayer,v_category,'N/A',NULL,v_start_time,NULL,NULL,NULL,NULL,NULL);
COMMIT;    

execute immediate 'truncate table z_enc_reason';

insert into z_enc_reason
select a.PAT_ENC_CSN_ID, case when upper(REASON_VISIT_NAME) in ('ANNUAL PHYSICAL','ANNUAL','ANNUAL / FOLLOW UP','MEDICARE ANNUAL WELLNESS VISIT') then 'ANNUAL/WELL VISIT' else REASON_VISIT_NAME end as APPT_REASON
from PAT_ENC_RSN_VISIT a
left outer join 
(select REASON_VISIT_ID, REASON_VISIT_NAME 
from CL_RSN_FOR_VISIT 
) b
on a.ENC_REASON_ID=b.REASON_VISIT_ID;
commit;

execute immediate 'truncate table z_md_pat_acc_temp';

insert into z_md_pat_acc_temp
select /*+ parallel(4) */ MRN, trunc(APPT_DTTM) APPT_DTTM, p.PAT_ENC_CSN_ID, APPT_STATUS_NAME, NPI, q.APPT_REASON as REASON  
from MV_DM_PATIENT_ACCESS p
left outer join
z_enc_reason q
on p.PAT_ENC_CSN_ID=q.PAT_ENC_CSN_ID
where trunc(APPT_DTTM)  >= to_date('01/01/2018','mm/dd/yyyy') 
;
commit;

execute immediate 'truncate table z_epic_pat';
insert into z_epic_pat
SELECT /*+ parallel(4) */ 
    Y_MRN, PAT_ID
    FROM PATIENT
    group by  Y_MRN, PAT_ID;
commit;

execute immediate 'truncate table Z_CLARITY_SER_2';
insert into Z_CLARITY_SER_2
select /*+ parallel(4) */  PROV_ID,npi from CLARITY_SER_2 group by PROV_ID,npi;
commit;

execute immediate 'truncate table z_schd_appt_temp';

insert into z_schd_appt_temp
select /*+ parallel(4) */ b.Y_MRN as Y_MRN,  APPT_DTTM, a.PAT_ENC_CSN_ID, d.NAME,  c.npi,  q.APPT_REASON  as reason
from F_SCHED_APPT  a 
left outer join z_epic_pat b
on a.PAT_ID=b.PAT_ID
left outer join 
(select distinct prov_id, npi from Z_CLARITY_SER_2) c
on a.PROV_ID=c.PROV_ID
left outer join ZC_APPT_STATUS d
on a.APPT_STATUS_C=d.APPT_STATUS_C
left outer join
z_enc_reason q
on a.PAT_ENC_CSN_ID=q.PAT_ENC_CSN_ID
where  APPT_DTTM >= to_date('01/01/2018','mm/dd/yyyy') 
;
commit;

execute immediate 'truncate table Y_UNIFIED_MEMBER_VISITS';
execute immediate 'truncate table Z_UNIFIED_MEMBER_VISITS';

    OPEN cur_uv_cs;
    LOOP
        FETCH cur_uv_cs BULK COLLECT INTO var_uv_cs LIMIT 100000;
        EXIT WHEN var_uv_cs.COUNT=0;

            FORALL i IN 1..var_uv_cs.COUNT
            INSERT INTO Y_UNIFIED_MEMBER_VISITS
            ( PAYER, LOB, MEMBER_ID, MRN, ENCOUNTER_ID, EFFPER, DATE_OF_SERVICE, SOURCE, VISIT_STATUS_TYPE, HISTORICAL_PCP_NPI, HISTORICAL_PCP_TIN, HISTORICAL_PCP_EMP_STATUS, HISTORICAL_PCP_POD, HISTORICAL_PCP_PRACTICE, HISTORICAL_PCP_PROVIDER, HISTORICAL_PROV_PCP_SPC, HISTORICAL_PROV_CMS_PCP_SPC, HISTORICAL_PRAC_EPIC_STATUS, CURRENT_PCP_NPI, CURRENT_PCP_TIN, CURRENT_PCP_EMP_STATUS, CURRENT_PCP_POD, CURRENT_PCP_PRACTICE, CURRENT_PCP_PROVIDER, CURRENT_PROV_PCP_SPC, CURRENT_PROV_CMS_PCP_SPC, CURRENT_PRAC_EPIC_STATUS, SERVICING_PCP_NPI, SERVICING_PCP_TIN, SERVICING_PCP_EMP_STATUS, SERVICING_PCP_POD, SERVICING_PCP_PRACTICE, SERVICING_PCP_PROVIDER, SERVICING_PROV_PCP_SPC, SERVICING_PROV_CMS_PCP_SPC, SERVICING_PRAC_EPIC_STATUS, ATTRIBUTED_AT_VISIT, CURRENTLY_ATTRIBUTED, HIST_SERV_PROV_CHECK, HIST_SERV_PRAC_CHECK, CURRENT_SERV_PROV_CHECK, CURRENT_SERV_PRAC_CHECK, VISIT_WITH_ANY_SPC_PCP, VISIT_WITH_ANY_CMS_SPC_PCP, AWV_INDICATOR, LOAD_DT ) 
             VALUES
            ( 
                var_uv_cs(i).PAYER
                , var_uv_cs(i).LOB
                , var_uv_cs(i).MEMBER_ID
                , var_uv_cs(i).MRN
                , var_uv_cs(i).ENCOUNTER_ID
                , var_uv_cs(i).EFFPER
                , var_uv_cs(i).DATE_OF_SERVICE
                , var_uv_cs(i).SOURCE
                , var_uv_cs(i).VISIT_STATUS_TYPE
                , var_uv_cs(i).HISTORICAL_PCP_NPI
                , var_uv_cs(i).HISTORICAL_PCP_TIN
                , var_uv_cs(i).HISTORICAL_PCP_EMP_STATUS
                , var_uv_cs(i).HISTORICAL_PCP_POD
                , var_uv_cs(i).HISTORICAL_PCP_PRACTICE
                , var_uv_cs(i).HISTORICAL_PCP_PROVIDER
                , var_uv_cs(i).HISTORICAL_PROV_PCP_SPC
                , var_uv_cs(i).HISTORICAL_PROV_CMS_PCP_SPC
                , var_uv_cs(i).HISTORICAL_PRAC_EPIC_STATUS
                , var_uv_cs(i).CURRENT_PCP_NPI
                , var_uv_cs(i).CURRENT_PCP_TIN
                , var_uv_cs(i).CURRENT_PCP_EMP_STATUS
                , var_uv_cs(i).CURRENT_PCP_POD
                , var_uv_cs(i).CURRENT_PCP_PRACTICE
                , var_uv_cs(i).CURRENT_PCP_PROVIDER
                , var_uv_cs(i).CURRENT_PROV_PCP_SPC
                , var_uv_cs(i).CURRENT_PROV_CMS_PCP_SPC
                , var_uv_cs(i).CURRENT_PRAC_EPIC_STATUS
                , var_uv_cs(i).SERVICING_PCP_NPI
                , var_uv_cs(i).SERVICING_PCP_TIN
                , var_uv_cs(i).SERVICING_PCP_EMP_STATUS
                , var_uv_cs(i).SERVICING_PCP_POD
                , var_uv_cs(i).SERVICING_PCP_PRACTICE
                , var_uv_cs(i).SERVICING_PCP_PROVIDER
                , var_uv_cs(i).SERVICING_PROV_PCP_SPC
                , var_uv_cs(i).SERVICING_PROV_CMS_PCP_SPC
                , var_uv_cs(i).SERVICING_PRAC_EPIC_STATUS
                , var_uv_cs(i).ATTRIBUTED_AT_VISIT
                , var_uv_cs(i).CURRENTLY_ATTRIBUTED
                , var_uv_cs(i).HIST_SERV_PROV_CHECK
                , var_uv_cs(i).HIST_SERV_PRAC_CHECK
                , var_uv_cs(i).CURRENT_SERV_PROV_CHECK
                , var_uv_cs(i).CURRENT_SERV_PRAC_CHECK
                , var_uv_cs(i).VISIT_WITH_ANY_SPC_PCP
                , var_uv_cs(i).VISIT_WITH_ANY_CMS_SPC_PCP
                , var_uv_cs(i).AWV_INDICATOR
                , var_uv_cs(i).LOAD_DT
             );
             COMMIT;

    END LOOP;
    CLOSE cur_uv_cs;

    OPEN cur_uv_msx;
    LOOP
        FETCH cur_uv_msx BULK COLLECT INTO var_uv_msx LIMIT 100000;
        EXIT WHEN var_uv_msx.COUNT=0;

            FORALL i IN 1..var_uv_msx.COUNT
            INSERT INTO Y_UNIFIED_MEMBER_VISITS
            ( PAYER, LOB, MEMBER_ID, MRN, ENCOUNTER_ID, EFFPER, DATE_OF_SERVICE, SOURCE, VISIT_STATUS_TYPE, HISTORICAL_PCP_NPI, HISTORICAL_PCP_TIN, HISTORICAL_PCP_EMP_STATUS, HISTORICAL_PCP_POD, HISTORICAL_PCP_PRACTICE, HISTORICAL_PCP_PROVIDER, HISTORICAL_PROV_PCP_SPC, HISTORICAL_PROV_CMS_PCP_SPC, HISTORICAL_PRAC_EPIC_STATUS, CURRENT_PCP_NPI, CURRENT_PCP_TIN, CURRENT_PCP_EMP_STATUS, CURRENT_PCP_POD, CURRENT_PCP_PRACTICE, CURRENT_PCP_PROVIDER, CURRENT_PROV_PCP_SPC, CURRENT_PROV_CMS_PCP_SPC, CURRENT_PRAC_EPIC_STATUS, SERVICING_PCP_NPI, SERVICING_PCP_TIN, SERVICING_PCP_EMP_STATUS, SERVICING_PCP_POD, SERVICING_PCP_PRACTICE, SERVICING_PCP_PROVIDER, SERVICING_PROV_PCP_SPC, SERVICING_PROV_CMS_PCP_SPC, SERVICING_PRAC_EPIC_STATUS, ATTRIBUTED_AT_VISIT, CURRENTLY_ATTRIBUTED, HIST_SERV_PROV_CHECK, HIST_SERV_PRAC_CHECK, CURRENT_SERV_PROV_CHECK, CURRENT_SERV_PRAC_CHECK, VISIT_WITH_ANY_SPC_PCP, VISIT_WITH_ANY_CMS_SPC_PCP, AWV_INDICATOR, LOAD_DT ) 
             VALUES
            ( 
                var_uv_msx(i).PAYER
                , var_uv_msx(i).LOB
                , var_uv_msx(i).MEMBER_ID
                , var_uv_msx(i).PATIENT_MRN
                , var_uv_msx(i).VISIT_ID
                , var_uv_msx(i).EFFPER
                , var_uv_msx(i).APPT_DATETIME
                , var_uv_msx(i).SOURCE
                , var_uv_msx(i).appt_status_msx
                , var_uv_msx(i).HISTORICAL_PCP_NPI
                , var_uv_msx(i).HISTORICAL_PCP_TIN
                , var_uv_msx(i).HISTORICAL_PCP_EMP_STATUS
                , var_uv_msx(i).HISTORICAL_PCP_POD
                , var_uv_msx(i).HISTORICAL_PCP_PRACTICE
                , var_uv_msx(i).HISTORICAL_PCP_PROVIDER
                , var_uv_msx(i).HISTORICAL_PROV_PCP_SPC
                , var_uv_msx(i).HISTORICAL_PROV_CMS_PCP_SPC
                , var_uv_msx(i).HISTORICAL_PRAC_EPIC_STATUS
                , var_uv_msx(i).CURRENT_PCP_NPI
                , var_uv_msx(i).CURRENT_PCP_TIN
                , var_uv_msx(i).CURRENT_PCP_EMP_STATUS
                , var_uv_msx(i).CURRENT_PCP_POD
                , var_uv_msx(i).CURRENT_PCP_PRACTICE
                , var_uv_msx(i).CURRENT_PCP_PROVIDER
                , var_uv_msx(i).CURRENT_PROV_PCP_SPC
                , var_uv_msx(i).CURRENT_PROV_CMS_PCP_SPC
                , var_uv_msx(i).CURRENT_PRAC_EPIC_STATUS
                , var_uv_msx(i).SERVICING_PCP_NPI
                , var_uv_msx(i).SERVICING_PCP_TIN
                , var_uv_msx(i).SERVICING_PCP_EMP_STATUS
                , var_uv_msx(i).SERVICING_PCP_POD
                , var_uv_msx(i).SERVICING_PCP_PRACTICE
                , var_uv_msx(i).SERVICING_PCP_PROVIDER
                , var_uv_msx(i).SERVICING_PROV_PCP_SPC
                , var_uv_msx(i).SERVICING_PROV_CMS_PCP_SPC
                , var_uv_msx(i).SERVICING_PRAC_EPIC_STATUS
                , var_uv_msx(i).ATTRIBUTED_AT_VISIT
                , var_uv_msx(i).CURRENTLY_ATTRIBUTED
                , var_uv_msx(i).HIST_SERV_PROV_CHECK
                , var_uv_msx(i).HIST_SERV_PRAC_CHECK
                , var_uv_msx(i).CURRENT_SERV_PROV_CHECK
                , var_uv_msx(i).CURRENT_SERV_PRAC_CHECK
                , var_uv_msx(i).VISIT_WITH_ANY_SPC_PCP
                , var_uv_msx(i).VISIT_WITH_ANY_CMS_SPC_PCP
                , var_uv_msx(i).AWV_INDICATOR
                , var_uv_msx(i).LOAD_DT
             );
             COMMIT;

    END LOOP;
    CLOSE cur_uv_msx;

    OPEN cur_uv_ryan;
    LOOP
        FETCH cur_uv_ryan BULK COLLECT INTO var_uv_ryan LIMIT 100000;
        EXIT WHEN var_uv_ryan.COUNT=0;

            FORALL i IN 1..var_uv_ryan.COUNT
            INSERT INTO Y_UNIFIED_MEMBER_VISITS
            ( PAYER, LOB, MEMBER_ID, MRN, ENCOUNTER_ID, EFFPER, DATE_OF_SERVICE, SOURCE, VISIT_STATUS_TYPE, HISTORICAL_PCP_NPI, HISTORICAL_PCP_TIN, HISTORICAL_PCP_EMP_STATUS, HISTORICAL_PCP_POD, HISTORICAL_PCP_PRACTICE, HISTORICAL_PCP_PROVIDER, HISTORICAL_PROV_PCP_SPC, HISTORICAL_PROV_CMS_PCP_SPC, HISTORICAL_PRAC_EPIC_STATUS, CURRENT_PCP_NPI, CURRENT_PCP_TIN, CURRENT_PCP_EMP_STATUS, CURRENT_PCP_POD, CURRENT_PCP_PRACTICE, CURRENT_PCP_PROVIDER, CURRENT_PROV_PCP_SPC, CURRENT_PROV_CMS_PCP_SPC, CURRENT_PRAC_EPIC_STATUS, SERVICING_PCP_NPI, SERVICING_PCP_TIN, SERVICING_PCP_EMP_STATUS, SERVICING_PCP_POD, SERVICING_PCP_PRACTICE, SERVICING_PCP_PROVIDER, SERVICING_PROV_PCP_SPC, SERVICING_PROV_CMS_PCP_SPC, SERVICING_PRAC_EPIC_STATUS, ATTRIBUTED_AT_VISIT, CURRENTLY_ATTRIBUTED, HIST_SERV_PROV_CHECK, HIST_SERV_PRAC_CHECK, CURRENT_SERV_PROV_CHECK, CURRENT_SERV_PRAC_CHECK, VISIT_WITH_ANY_SPC_PCP, VISIT_WITH_ANY_CMS_SPC_PCP, AWV_INDICATOR, LOAD_DT ) 
             VALUES
            ( 
                var_uv_ryan(i).PAYER
                , var_uv_ryan(i).LOB
                , var_uv_ryan(i).MEMBER_ID
                , var_uv_ryan(i).pri_mrn
                , var_uv_ryan(i).ENCOUNTER_ID
                , var_uv_ryan(i).EFFPER
                , var_uv_ryan(i).APPTDATE
                , var_uv_ryan(i).SOURCE
                , var_uv_ryan(i).APPTSTATUS
                , var_uv_ryan(i).HISTORICAL_PCP_NPI
                , var_uv_ryan(i).HISTORICAL_PCP_TIN
                , var_uv_ryan(i).HISTORICAL_PCP_EMP_STATUS
                , var_uv_ryan(i).HISTORICAL_PCP_POD
                , var_uv_ryan(i).HISTORICAL_PCP_PRACTICE
                , var_uv_ryan(i).HISTORICAL_PCP_PROVIDER
                , var_uv_ryan(i).HISTORICAL_PROV_PCP_SPC
                , var_uv_ryan(i).HISTORICAL_PROV_CMS_PCP_SPC
                , var_uv_ryan(i).HISTORICAL_PRAC_EPIC_STATUS
                , var_uv_ryan(i).CURRENT_PCP_NPI
                , var_uv_ryan(i).CURRENT_PCP_TIN
                , var_uv_ryan(i).CURRENT_PCP_EMP_STATUS
                , var_uv_ryan(i).CURRENT_PCP_POD
                , var_uv_ryan(i).CURRENT_PCP_PRACTICE
                , var_uv_ryan(i).CURRENT_PCP_PROVIDER
                , var_uv_ryan(i).CURRENT_PROV_PCP_SPC
                , var_uv_ryan(i).CURRENT_PROV_CMS_PCP_SPC
                , var_uv_ryan(i).CURRENT_PRAC_EPIC_STATUS
                , var_uv_ryan(i).SERVICING_PCP_NPI
                , var_uv_ryan(i).SERVICING_PCP_TIN
                , var_uv_ryan(i).SERVICING_PCP_EMP_STATUS
                , var_uv_ryan(i).SERVICING_PCP_POD
                , var_uv_ryan(i).SERVICING_PCP_PRACTICE
                , var_uv_ryan(i).SERVICING_PCP_PROVIDER
                , var_uv_ryan(i).SERVICING_PROV_PCP_SPC
                , var_uv_ryan(i).SERVICING_PROV_CMS_PCP_SPC
                , var_uv_ryan(i).SERVICING_PRAC_EPIC_STATUS
                , var_uv_ryan(i).ATTRIBUTED_AT_VISIT
                , var_uv_ryan(i).CURRENTLY_ATTRIBUTED
                , var_uv_ryan(i).HIST_SERV_PROV_CHECK
                , var_uv_ryan(i).HIST_SERV_PRAC_CHECK
                , var_uv_ryan(i).CURRENT_SERV_PROV_CHECK
                , var_uv_ryan(i).CURRENT_SERV_PRAC_CHECK
                , var_uv_ryan(i).VISIT_WITH_ANY_SPC_PCP
                , var_uv_ryan(i).VISIT_WITH_ANY_CMS_SPC_PCP
                , var_uv_ryan(i).AWV_INDICATOR
                , var_uv_ryan(i).LOAD_DT
             );
             COMMIT;

    END LOOP;
    CLOSE cur_uv_ryan;

--Insert limited entries to old visits for old PNS process
insert into Z_UNIFIED_MEMBER_VISITS
(PAYER, LOB, MEMBER_ID, MRN, ENCOUNTER_ID, EFFPER, DATE_OF_SERVICE, SOURCE, VISIT_STATUS_TYPE, HISTORICAL_PCP_NPI, HISTORICAL_PCP_TIN, HISTORICAL_PCP_EMP_STATUS, HISTORICAL_PCP_POD, HISTORICAL_PCP_PRACTICE, HISTORICAL_PCP_PROVIDER, HISTORICAL_PROV_PCP_SPC, HISTORICAL_PROV_CMS_PCP_SPC, HISTORICAL_PRAC_EPIC_STATUS, CURRENT_PCP_NPI, CURRENT_PCP_TIN, CURRENT_PCP_EMP_STATUS, CURRENT_PCP_POD, CURRENT_PCP_PRACTICE, CURRENT_PCP_PROVIDER, CURRENT_PROV_PCP_SPC, CURRENT_PROV_CMS_PCP_SPC, CURRENT_PRAC_EPIC_STATUS, SERVICING_PCP_NPI, SERVICING_PCP_TIN, SERVICING_PCP_EMP_STATUS, SERVICING_PCP_POD, SERVICING_PCP_PRACTICE, SERVICING_PCP_PROVIDER, SERVICING_PROV_PCP_SPC, SERVICING_PROV_CMS_PCP_SPC, SERVICING_PRAC_EPIC_STATUS, ATTRIBUTED_AT_VISIT, CURRENTLY_ATTRIBUTED, HIST_SERV_PROV_CHECK, HIST_SERV_PRAC_CHECK, CURRENT_SERV_PROV_CHECK, CURRENT_SERV_PRAC_CHECK, VISIT_WITH_ANY_SPC_PCP, VISIT_WITH_ANY_CMS_SPC_PCP, AWV_INDICATOR, LOAD_DT)
select /*+ parallel(4) */ 
PAYER, LOB, MEMBER_ID, MRN, ENCOUNTER_ID, EFFPER, DATE_OF_SERVICE, SOURCE, VISIT_STATUS_TYPE, HISTORICAL_PCP_NPI, HISTORICAL_PCP_TIN, HISTORICAL_PCP_EMP_STATUS, HISTORICAL_PCP_POD, HISTORICAL_PCP_PRACTICE, HISTORICAL_PCP_PROVIDER, HISTORICAL_PROV_PCP_SPC, HISTORICAL_PROV_CMS_PCP_SPC, HISTORICAL_PRAC_EPIC_STATUS, CURRENT_PCP_NPI, CURRENT_PCP_TIN, CURRENT_PCP_EMP_STATUS, CURRENT_PCP_POD, CURRENT_PCP_PRACTICE, CURRENT_PCP_PROVIDER, CURRENT_PROV_PCP_SPC, CURRENT_PROV_CMS_PCP_SPC, CURRENT_PRAC_EPIC_STATUS, SERVICING_PCP_NPI, SERVICING_PCP_TIN, SERVICING_PCP_EMP_STATUS, SERVICING_PCP_POD, SERVICING_PCP_PRACTICE, SERVICING_PCP_PROVIDER, SERVICING_PROV_PCP_SPC, SERVICING_PROV_CMS_PCP_SPC, SERVICING_PRAC_EPIC_STATUS, ATTRIBUTED_AT_VISIT, CURRENTLY_ATTRIBUTED, HIST_SERV_PROV_CHECK, HIST_SERV_PRAC_CHECK, CURRENT_SERV_PROV_CHECK, CURRENT_SERV_PRAC_CHECK, VISIT_WITH_ANY_SPC_PCP, VISIT_WITH_ANY_CMS_SPC_PCP, AWV_INDICATOR, LOAD_DT
from Y_UNIFIED_MEMBER_VISITS
where visit_status_type in ('ARRIVED', 'SCHEDULED', 'COMPLETED');
commit;

select /*+ parallel(4) */ count(1) into v_record_count from Z_UNIFIED_MEMBER_VISITS;

v_end_time:=sysdate;

UPDATE  Y_TABLE_REFRESH SET 
END_TIME=v_end_time,
RECORD_COUNT=v_record_count,
load_dt=trunc(sysdate),
status = 'Completed'
WHERE TABLE_NAME=v_table_name AND PAYER=v_subpayer  AND START_TIME = v_start_time;
COMMIT;

EXCEPTION
WHEN OTHERS THEN
    v_err:= SQLCODE;
    v_msg:= SUBSTR(SQLERRM, 1, 200);
    INSERT INTO y_table_err_log (TABLE_NAME,PAYER,category,START_TIME,ERROR_TIME,ERROR_CODE,ERROR_MSG,LOAD_DT,REPROCESSED,REPROCESSED_DT) VALUES (v_table_name,v_subpayer,v_category,v_start_time,SYSDATE,v_err,v_msg,TRUNC(SYSDATE),'N',NULL);
    COMMIT;
    UPDATE  y_TABLE_REFRESH SET END_TIME = SYSDATE,status = 'Failed',load_dt=TRUNC(SYSDATE) WHERE TABLE_NAME=v_table_name AND PAYER=v_subpayer  AND START_TIME = v_start_time;
    COMMIT;

END;

--S0 visit table with enhanced data
BEGIN

v_payer:='ALL';
v_subpayer:='ALL';
v_record_count:=0;
v_start_time:=sysdate;
v_table_name := 'Y_PATIENT_SEEN_VISITS_ALL';

Insert into Y_TABLE_REFRESH(TABLE_NAME,PAYER,CATEGORY,DATE_THROUGH_TYPE,DATE_THROUGH,START_TIME,END_TIME,RECORD_COUNT,RECORD_DIFF,LOAD_DT,status)
            Values(v_table_name,v_subpayer,v_category,'N/A',NULL,v_start_time,NULL,NULL,NULL,NULL,NULL);
COMMIT;

execute immediate 'truncate table Y_PATIENT_SEEN_VISITS_ALL';
--Updated logic based on CS-2961
insert into Y_PATIENT_SEEN_VISITS_ALL
(PAYER, LOB, MEMBER_ID, MRN, ENCOUNTER_ID, EFFPER, DATE_OF_SERVICE, SOURCE, VISIT_STATUS_TYPE, HISTORICAL_PCP_NPI, HISTORICAL_PCP_TIN, HISTORICAL_PCP_EMP_STATUS, HISTORICAL_PCP_POD, HISTORICAL_PCP_PRACTICE, HISTORICAL_PCP_PROVIDER, HISTORICAL_PROV_PCP_SPC, HISTORICAL_PROV_CMS_PCP_SPC, HISTORICAL_PRAC_EPIC_STATUS, CURRENT_PCP_NPI, CURRENT_PCP_TIN, CURRENT_PCP_EMP_STATUS, CURRENT_PCP_POD, CURRENT_PCP_PRACTICE, CURRENT_PCP_PROVIDER, CURRENT_PROV_PCP_SPC, CURRENT_PROV_CMS_PCP_SPC, CURRENT_PRAC_EPIC_STATUS, SERVICING_PCP_NPI, SERVICING_PCP_TIN, SERVICING_PCP_EMP_STATUS, SERVICING_PCP_POD, SERVICING_PCP_PRACTICE, SERVICING_PCP_PROVIDER, SERVICING_PROV_PCP_SPC, SERVICING_PROV_CMS_PCP_SPC, SERVICING_PRAC_EPIC_STATUS, ATTRIBUTED_AT_VISIT, CURRENTLY_ATTRIBUTED, HIST_SERV_PROV_CHECK, HIST_SERV_PRAC_CHECK, CURRENT_SERV_PROV_CHECK, CURRENT_SERV_PRAC_CHECK, VISIT_WITH_ANY_SPC_PCP, VISIT_WITH_ANY_CMS_SPC_PCP, AWV_INDICATOR, LOAD_DT, EFFYEAR, GROUPER_NAME, DEPARTMENT_NAME, ENC_TYPE_C, ENC_TYPE_POS, PROC_CODE, PROC_CODE_DESC, PROV_NAME, PROV_TITLE, PROV_TITLE_ID, APPT_STATUS, ENC_CLOSED_YN, PC_VISIT_CMPLT_CLOSE_YN, PC_VISIT_LOS_CODE_YN, PC_VISIT_PROV_TYPE_YN, PC_VISIT_GROUPER_YN, PC_VISIT_ALL_MATCH_YN, PAYER_NOT_CHGD, CREATE_DT)
            --QUERY FOR EPIC DATA; SEPARATING BY DATA SOURCE TO ADD ENHANCED DATA 
            SELECT 
            --TO STANDARDIZE MSSP PAYER NAME
            CASE WHEN Z.PAYER LIKE '%MSSP%' THEN 'MSSP NYMP' ELSE PAYER 
            END AS PAYER,
            Z.LOB,
            Z.MEMBER_ID,
            Z.MRN,
            Z.ENCOUNTER_ID,
            Z.EFFPER,
            Z.DATE_OF_SERVICE,
            Z.SOURCE,
            --12/17/2024 CONSOLIDATING 'CANCELED','CANCELLED' AND 'NO SHOW','NOSHOW' FOR CLEANER STATUS TYPE  L.Heinrich
            CASE WHEN Z.VISIT_STATUS_TYPE IN ('CANCELED','CANCELLED') THEN 'CANCELED'
                 WHEN Z.VISIT_STATUS_TYPE IN ('NO SHOW','NOSHOW') THEN 'NO SHOW'
                 ELSE Z.VISIT_STATUS_TYPE
                 END AS VISIT_STATUS_TYPE,
            Z.HISTORICAL_PCP_NPI,
            Z.HISTORICAL_PCP_TIN,
            Z.HISTORICAL_PCP_EMP_STATUS,
            Z.HISTORICAL_PCP_POD,
            Z.HISTORICAL_PCP_PRACTICE,
            Z.HISTORICAL_PCP_PROVIDER,
            Z.HISTORICAL_PROV_PCP_SPC,
            Z.HISTORICAL_PROV_CMS_PCP_SPC,
            Z.HISTORICAL_PRAC_EPIC_STATUS,
            Z.CURRENT_PCP_NPI,
            Z.CURRENT_PCP_TIN,
            Z.CURRENT_PCP_EMP_STATUS,
            Z.CURRENT_PCP_POD,
            Z.CURRENT_PCP_PRACTICE,
            Z.CURRENT_PCP_PROVIDER,
            Z.CURRENT_PROV_PCP_SPC,
            Z.CURRENT_PROV_CMS_PCP_SPC,
            Z.CURRENT_PRAC_EPIC_STATUS,
            Z.SERVICING_PCP_NPI,
            Z.SERVICING_PCP_TIN,
            Z.SERVICING_PCP_EMP_STATUS,
            Z.SERVICING_PCP_POD,
            Z.SERVICING_PCP_PRACTICE,
            Z.SERVICING_PCP_PROVIDER,
            Z.SERVICING_PROV_PCP_SPC,
            Z.SERVICING_PROV_CMS_PCP_SPC,
            Z.SERVICING_PRAC_EPIC_STATUS,
            Z.ATTRIBUTED_AT_VISIT,
            Z.CURRENTLY_ATTRIBUTED,
            Z.HIST_SERV_PROV_CHECK,
            Z.HIST_SERV_PRAC_CHECK,
            Z.CURRENT_SERV_PROV_CHECK,
            Z.CURRENT_SERV_PRAC_CHECK,
            Z.VISIT_WITH_ANY_SPC_PCP,
            Z.VISIT_WITH_ANY_CMS_SPC_PCP,
            Z.AWV_INDICATOR,
            Z.LOAD_DT,
            --ADD'L FIELDS FOR PRIMARY CARE GROUPER VISITS TO COUNT AS PROPOSED DEFINITION VISITS
            SUBSTR(Z.EFFPER,1,4) AS EFFYEAR,
            D.GROUPER_NAME,
            D.DEPARTMENT_NAME,
            D.ENC_TYPE_C,
            D.ENC_TYPE_POS,
            D.PROC_CODE,
            D.PROC_CODE_DESC,
            D.PROV_NAME,
            D.PROV_TITLE,
            D.PROV_TITLE_ID,
            --3/15/2025 VISIT LOGIC CHECKS 
            D.APPT_STATUS,
            D.ENC_CLOSED_YN,
            D.PC_VISIT_CMPLT_CLOSE_YN,
            D.PC_VISIT_LOS_CODE_YN,
            D.PC_VISIT_PROV_TYPE_YN,
            D.PC_VISIT_GROUPER_YN,
            CASE WHEN D.PC_VISIT_CMPLT_CLOSE_YN = 1
                 AND D.PC_VISIT_LOS_CODE_YN = 1
                 AND D.PC_VISIT_PROV_TYPE_YN = 1
                 AND D.PC_VISIT_GROUPER_YN = 1 
                 THEN TO_NUMBER('1') ELSE TO_NUMBER('0') END AS PC_VISIT_ALL_MATCH_YN,
            --THIS IS A QA CHECK; PAYER NAME ESPECIALLY FOR MSSP IS DUPLICATED ACROSS ALL NAMES FOR MSSP
            Z.PAYER AS PAYER_NOT_CHGD,
            SYSDATE AS CREATE_DT 
            --3/14/25 change to prod table (Y_UNIFIED_MEMBER_VISITS) from QA table (Z_UNIFIED_MEMBER_VISITS_QA) 
            FROM (SELECT * FROM Y_UNIFIED_MEMBER_VISITS) Z 
            LEFT OUTER JOIN 
                (SELECT
                MDPA.PAT_ID,
                MDPA.PAT_ENC_CSN_ID,
                TO_NUMBER(MDPA.PAT_ENC_CSN_ID) AS ENC_ID_NUMB,
                TRUNC(TO_NUMBER(MDPA.PAT_ENC_CSN_ID)) AS ENC_ID_TRUNC_NUMB,
                MDPA.CONTACT_DATE,
                MDPA.DEPARTMENT_ID,
                DEP.DEPARTMENT_NAME,
                PC.GROUPER_NAME,
                MDPA.ENC_TYPE_C,
                ZC.NAME AS ENC_TYPE_POS,
                EAP.PROC_CODE,
                --PRC.CPT_DESC AS PROC_CODE_DESC,
                EAP.PROC_NAME AS PROC_CODE_DESC,
                Z.TITLE AS PROV_TITLE,
                Z.SERVICE_TYPE_C AS PROV_TITLE_ID,
                --3/15/2025 additional columns for logic change check
                ZAS.NAME AS APPT_STATUS,
                MDPA.VISIT_PROV_ID,
                SER.PROV_NAME,
                Z.TITLE,
                PROV.PROVIDER_TYPE_C,
                PROV.PROVIDER_tYPE,
                MDPA.ENC_CLOSED_YN,
                CASE WHEN ZAS.TITLE = 'COMPLETED' OR MDPA.ENC_CLOSED_YN = 'Y' THEN TO_NUMBER('1') ELSE TO_NUMBER('0') END AS PC_VISIT_CMPLT_CLOSE_YN,
                CASE WHEN MDPA.LOS_PRIME_PROC_ID IS NOT NULL AND MDPA.LOS_PRIME_PROC_ID = LOS.PROC_ID AND NOT(MDPA.ENC_TYPE_C = '50')  --NOT AN EPIC SCHEDULED VISIT
                THEN TO_NUMBER('1') ELSE TO_NUMBER('0') END AS PC_VISIT_LOS_CODE_YN,
                CASE WHEN PROV.PROVIDER_TYPE_C = Z.SERVICE_TYPE_C THEN TO_NUMBER('1') ELSE TO_NUMBER('0') END AS PC_VISIT_PROV_TYPE_YN,
                CASE WHEN PC.GROUPER_NAME IS NOT NULL THEN TO_NUMBER('1') ELSE TO_NUMBER('0') END AS PC_VISIT_GROUPER_YN

                FROM 
                --Using Epic Clarity table PAT_ENC instead of MV_DM_PATIENT_ACCESS (too slow for performance) or F_SCHED_APPT (didn't have ENC_TYPE_C) to make sure only office visits and telehealth visits are included
                PAT_ENC MDPA
                LEFT OUTER JOIN CLARITY_DEP DEP ON MDPA.DEPARTMENT_ID = DEP.DEPARTMENT_ID
                LEFT OUTER JOIN CLARITY_EAP EAP ON MDPA.LOS_PRIME_PROC_ID = EAP.PROC_ID  --IS THIS NEEDED
                --3/15/25 no longer a filter for visits
                LEFT OUTER JOIN ZC_DISP_ENC_TYPE ZC ON MDPA.ENC_TYPE_C = ZC.DISP_ENC_TYPE_C   
                LEFT OUTER JOIN CLARITY_SER SER ON MDPA.VISIT_PROV_ID = SER.PROV_ID
                LEFT OUTER JOIN (SELECT * FROM ZC_NOTE_SER) Z ON SER.PROVIDER_TYPE_C = Z.SERVICE_tYPE_C
                --3/15/25 revised logic requested from Nikita Barai 2/2025 to match ambulatory quality dashboard defininions provided by Ying Qiu from DTP
                --RULE 1 Patient appointment status = Completed [2] from (I EPT 7020; PAT_ENC.APPT_STATUS_C) for Ambulatory Quality Dashboard visit rule MS Filter Completed Office/Video Visit In Primary Care Department With MD PA NP [207450]
                LEFT OUTER JOIN (SELECT * FROM ZC_APPT_STATUS) ZAS ON MDPA.APPT_STATUS_C = ZAS.APPT_STATUS_C
                --RULE 3 & 4: Patient level of service for Ambulatory Quality Dashboard visit rule MS Filter Completed Office/Video Visit In Primary Care Department With MD PA NP [207450]
                LEFT OUTER JOIN (SELECT * FROM Z_PATIENT_SEEN_LOS_REF) LOS ON MDPA.LOS_PRIME_PROC_ID = LOS.PROC_ID
                --RULE 5: Visit provider type for Ambulatory Quality Dashboard visit rule MS Filter Completed Office/Video Visit In Primary Care Department With MD PA NP [207450]
                LEFT OUTER JOIN (SELECT * FROM Z_PATIENT_SEEN_SER_PROVIDER_TYPE_REF) PROV ON Z.SERVICE_tYPE_C =  PROV.PROVIDER_TYPE_C       
                --RULES 6-9: Visit in PRIMARY CARE department using PC GROUPER - TABLE CREATED BY DTP; SERVICE NOW RITM0364732 for Ambulatory Quality Dashboard visit rule MS Filter Completed Office/Video Visit In Primary Care Department With MD PA NP [207450]
                LEFT OUTER JOIN V_HP_PCP_DEPT_GROUPER PC ON PC.GROUPER_RECORDS_NUMERIC_ID = MDPA.DEPARTMENT_ID
                --logic changed 3/15/2023; orginally approved 12/2024 provider credential at time of visit less populated; Nikita Barai asked to change to Ambulatory Quality dashboard logic per Ying Qiu
                --LEFT OUTER JOIN ZC_ALT_ORD_PRV_TIT PRV ON MDPA.VISIT_PROV_TITLE = PRV.ALT_ORD_PRV_TIT_C
                --These E&M codes are from the AMA LIST OF E&M CODES PULLED 11/2024  https://www.ama-assn.org/topics/evaluation-and-management-em-coding#:~:text=medical%20practice%20today.-,E%26M%20coding%20involves%20use%20of%20CPT%20codes%20ranging%20from%2099202,or%20managing%20a%20patient's%20health.
                --LEFT OUTER JOIN (SELECT * FROM Z_AMA_EM_CODE_LIST_REF) PRC ON TRIM(TO_CHAR(EAP.PROC_CODE)) = TRIM(TO_CHAR(PRC.CPT_CD))  --not a filter for visits 

                WHERE 
------DATE #1 OF 7
                MDPA.CONTACT_DATE >= '01-JAN-19'
                --test data 
--                MDPA.CONTACT_DATE >= '01-JAN-24' AND MDPA.CONTACT_DATE < '01-JAN-25'
                ) D ON TRUNC(TO_NUMBER(D.PAT_ENC_CSN_ID)) = TRUNC(TO_NUMBER(Z.ENCOUNTER_ID))

        WHERE 
        --5/4/2025 Logic to match Ambulatory Quality Dashboard change captures ALL VISIT STATUSES
        --PER DTP ON 4/13/2025: Any scheduled appointment where the patient has not yet checked in will always be an encounter type of appointment/ ENC TYPE C = 50
        --EXCLUDE SOURCE = 'F_SCHED_APPT' PER DTP F_SCHED_APPT IS INCLUDED IN MV_DM_PATIENT_ACCESS; Epic scheduled data to come from SOURCE = 'MV_DM_PATIENT_ACCESS' where ENC_TYPE_C = '50'
        Z.SOURCE = 'MV_DM_PATIENT_ACCESS' 
----DATE #2 OF 7
        AND Z.DATE_OF_SERVICE >= '01-JAN-19' 
        --STATEMENTS TO REMOVE DATA THAT COULDN'T LINK TO VBC MEMBERS 
        AND (Z.DATE_OF_SERVICE IS NOT NULL AND Z.MEMBER_ID IS NOT NULL AND Z.SERVICING_PCP_NPI IS NOT NULL)
        AND NOT(Z.MEMBER_ID LIKE '%?%')
        AND NOT(UPPER(Z.MEMBER_ID) LIKE '%SUBSCRIBER%')
        AND Z.MEMBER_ID IS NOT NULL
        AND Z.PAYER IS NOT NULL
        AND Z.LOB IS NOT NULL
        AND NOT (Z.MEMBER_ID LIKE '00000000%00000000')
        AND Z.SERVICING_PCP_NPI IS NOT NULL

    UNION ALL

--QUERY FOR SCHEDULING SOURCES IN Z_UNIFIED_MEMBER_VISITS
     SELECT  
            --TO STANDARDIZE MSSP PAYER NAME
            CASE WHEN Z.PAYER LIKE '%MSSP%' THEN 'MSSP NYMP' ELSE PAYER 
            END AS PAYER,
            Z.LOB,
            Z.MEMBER_ID,
            Z.MRN,
            Z.ENCOUNTER_ID,
            Z.EFFPER,
            Z.DATE_OF_SERVICE,
            Z.SOURCE,
            --12/17/2024 CONSOLIDATING 'CANCELED','CANCELLED' AND 'NO SHOW','NOSHOW' FOR CLEANER STATUS TYPE  L.Heinrich
            CASE WHEN Z.VISIT_STATUS_TYPE IN ('CANCELED','CANCELLED') THEN 'CANCELED'
                 WHEN Z.VISIT_STATUS_TYPE IN ('NO SHOW','NOSHOW') THEN 'NO SHOW'
                 ELSE Z.VISIT_STATUS_TYPE
                 END AS VISIT_STATUS_TYPE,
            Z.HISTORICAL_PCP_NPI,
            Z.HISTORICAL_PCP_TIN,
            Z.HISTORICAL_PCP_EMP_STATUS,
            Z.HISTORICAL_PCP_POD,
            Z.HISTORICAL_PCP_PRACTICE,
            Z.HISTORICAL_PCP_PROVIDER,
            Z.HISTORICAL_PROV_PCP_SPC,
            Z.HISTORICAL_PROV_CMS_PCP_SPC,
            Z.HISTORICAL_PRAC_EPIC_STATUS,
            Z.CURRENT_PCP_NPI,
            Z.CURRENT_PCP_TIN,
            Z.CURRENT_PCP_EMP_STATUS,
            Z.CURRENT_PCP_POD,
            Z.CURRENT_PCP_PRACTICE,
            Z.CURRENT_PCP_PROVIDER,
            Z.CURRENT_PROV_PCP_SPC,
            Z.CURRENT_PROV_CMS_PCP_SPC,
            Z.CURRENT_PRAC_EPIC_STATUS,
            Z.SERVICING_PCP_NPI,
            Z.SERVICING_PCP_TIN,
            Z.SERVICING_PCP_EMP_STATUS,
            Z.SERVICING_PCP_POD,
            Z.SERVICING_PCP_PRACTICE,
            Z.SERVICING_PCP_PROVIDER,
            Z.SERVICING_PROV_PCP_SPC,
            Z.SERVICING_PROV_CMS_PCP_SPC,
            Z.SERVICING_PRAC_EPIC_STATUS,
            Z.ATTRIBUTED_AT_VISIT,
            Z.CURRENTLY_ATTRIBUTED,
            Z.HIST_SERV_PROV_CHECK,
            Z.HIST_SERV_PRAC_CHECK,
            Z.CURRENT_SERV_PROV_CHECK,
            Z.CURRENT_SERV_PRAC_CHECK,
            Z.VISIT_WITH_ANY_SPC_PCP,
            Z.VISIT_WITH_ANY_CMS_SPC_PCP,
            Z.AWV_INDICATOR,
            Z.LOAD_DT,
            --ADD'L FIELDS WITH GROUPER NAMES AS NULL 
            SUBSTR(Z.EFFPER,1,4) AS EFFYEAR,
            '' AS GROUPER_NAME,
            '' AS DEPARTMENT_NAME,
            '' AS ENC_TYPE_C,
            '' AS ENC_TYPE_POS,
            '' AS PROC_CODE,
            '' AS PROC_CODE_DESC,
            '' AS PROV_NAME,
            '' AS PROV_TITLE,
            '' AS PROV_TITLE_ID,
            '' AS APPT_STATUS,
            '' AS ENC_CLOSED_YN,
            TO_NUMBER('') AS PC_VISIT_CMPLT_CLOSE_YN,
            TO_NUMBER('') AS PC_VISIT_LOS_CODE_YN,
            TO_NUMBER('') AS PC_VISIT_PROV_TYPE_YN,
            TO_NUMBER('') AS PC_VISIT_GROUPER_YN,
            TO_NUMBER('') AS PC_VISIT_ALL_MATCH_YN,

            Z.PAYER AS PAYER_NOT_CHGD,
            SYSDATE AS CREATE_DT
            --3/14/25 change to prod table (Y_UNIFIED_MEMBER_VISITS) from QA table (Z_UNIFIED_MEMBER_VISITS_QA) 
            FROM (SELECT * FROM Y_UNIFIED_MEMBER_VISITS) Z 
            WHERE 
            --QUERY FOR NEW STORED PROCEDURE AND VISIT TABLE DOES NOT FILTER ON VISIT_STATUS_TYPE; NEW STORED PROCEDURE TO CAPTURE ALL VISIT STATUSES
            --LESS EMPHASIS ON MSX SCHED AS IT'S BEING SUNSET;
            --CAN DO DEEPER DIVE ON RYAN SCHEDULING. FOR NOW GIVE MOST GENEROUS CREDIT 
            Z.SOURCE IN ('RYAN SCHEDULING') --'MSX_SCHED',
------DATE #3 OF 7
            AND Z.DATE_OF_SERVICE >= '01-JAN-19' 
            --ADDED 4/13/2025
            AND VISIT_STATUS_TYPE IN ('SCHEDULED','ARRIVED')
            --STATEMENTS TO REMOVE DATA THAT COULDN'T LINK TO VBC MEMBERS 
            AND (Z.DATE_OF_SERVICE IS NOT NULL AND Z.MEMBER_ID IS NOT NULL AND Z.SERVICING_PCP_NPI IS NOT NULL)
            AND NOT(Z.MEMBER_ID LIKE '%?%')
            AND NOT(UPPER(Z.MEMBER_ID) LIKE '%SUBSCRIBER%')
            AND Z.MEMBER_ID IS NOT NULL
            AND Z.PAYER IS NOT NULL
            AND Z.LOB IS NOT NULL
            AND NOT (Z.MEMBER_ID LIKE '00000000%00000000')
            AND Z.SERVICING_PCP_NPI IS NOT NULL
        UNION ALL


 --QUERY FOR CLAIMS DATA SOURCES IN Z_UNIFIED_MEMBER_VISITS
 --UPDATED 3/23/2025 
        SELECT  
            --TO STANDARDIZE MSSP PAYER NAME
            CASE WHEN Z.PAYER LIKE '%MSSP%' THEN 'MSSP NYMP' ELSE Z.PAYER 
            END AS PAYER,
            Z.LOB,
            Z.MEMBER_ID,
            Z.MRN,
            Z.ENCOUNTER_ID,
            Z.EFFPER,
            Z.DATE_OF_SERVICE,
            Z.SOURCE,
            --12/17/2024 CONSOLIDATING 'CANCELED','CANCELLED' AND 'NO SHOW','NOSHOW' FOR CLEANER STATUS TYPE  L.Heinrich
            CASE WHEN Z.VISIT_STATUS_TYPE IN ('CANCELED','CANCELLED') THEN 'CANCELED'
                 WHEN Z.VISIT_STATUS_TYPE IN ('NO SHOW','NOSHOW') THEN 'NO SHOW'
                 ELSE Z.VISIT_STATUS_TYPE
                 END AS VISIT_STATUS_TYPE,
            Z.HISTORICAL_PCP_NPI,
            Z.HISTORICAL_PCP_TIN,
            Z.HISTORICAL_PCP_EMP_STATUS,
            Z.HISTORICAL_PCP_POD,
            Z.HISTORICAL_PCP_PRACTICE,
            Z.HISTORICAL_PCP_PROVIDER,
            Z.HISTORICAL_PROV_PCP_SPC,
            Z.HISTORICAL_PROV_CMS_PCP_SPC,
            Z.HISTORICAL_PRAC_EPIC_STATUS,
            Z.CURRENT_PCP_NPI,
            Z.CURRENT_PCP_TIN,
            Z.CURRENT_PCP_EMP_STATUS,
            Z.CURRENT_PCP_POD,
            Z.CURRENT_PCP_PRACTICE,
            Z.CURRENT_PCP_PROVIDER,
            Z.CURRENT_PROV_PCP_SPC,
            Z.CURRENT_PROV_CMS_PCP_SPC,
            Z.CURRENT_PRAC_EPIC_STATUS,
            Z.SERVICING_PCP_NPI,
            Z.SERVICING_PCP_TIN,
            Z.SERVICING_PCP_EMP_STATUS,
            Z.SERVICING_PCP_POD,
            Z.SERVICING_PCP_PRACTICE,
            Z.SERVICING_PCP_PROVIDER,
            Z.SERVICING_PROV_PCP_SPC,
            Z.SERVICING_PROV_CMS_PCP_SPC,
            Z.SERVICING_PRAC_EPIC_STATUS,
            Z.ATTRIBUTED_AT_VISIT,
            Z.CURRENTLY_ATTRIBUTED,
            Z.HIST_SERV_PROV_CHECK,
            Z.HIST_SERV_PRAC_CHECK,
            Z.CURRENT_SERV_PROV_CHECK,
            Z.CURRENT_SERV_PRAC_CHECK,
            Z.VISIT_WITH_ANY_SPC_PCP,
            Z.VISIT_WITH_ANY_CMS_SPC_PCP,
            Z.AWV_INDICATOR,
            Z.LOAD_DT,
            --ADD'L FIELDS WITH GROUPER NAMES AS NULL 
            SUBSTR(Z.EFFPER,1,4) AS EFFYEAR,
            '' AS GROUPER_NAME,
            '' AS DEPARTMENT_NAME,
            '' AS ENC_TYPE_C,
            CH.CLAIM_PLACE_OF_SERVICE AS ENC_TYPE_POS,
            XFS.SERVICE_CODE AS PROC_CODE,
            XFS.PROC_CODE_DESC,
            '' AS PROV_NAME,
            '' AS PROV_TITLE,
            '' AS PROV_TITLE_ID,
            'Completed' AS APPT_STATUS,
            'Y' AS ENC_CLOSED_YN,
            TO_NUMBER('1') AS PC_VISIT_CMPLT_CLOSE_YN,
            CASE WHEN XFS.EXCL_CODE IS NULL THEN TO_NUMBER('1') ELSE TO_NUMBER('0') END AS PC_VISIT_LOS_CODE_YN,
            TO_NUMBER('') AS PC_VISIT_PROV_TYPE_YN,
            TO_NUMBER('') AS PC_VISIT_GROUPER_YN,
            CASE WHEN XFS.EXCL_CODE IS NULL THEN TO_NUMBER('1') ELSE TO_NUMBER('0') END  AS PC_VISIT_ALL_MATCH_YN,
            Z.PAYER AS PAYER_NOT_CHGD,
            SYSDATE AS CREATE_DT

            --3/14/25 change to prod table (Y_UNIFIED_MEMBER_VISITS) from QA table (Z_UNIFIED_MEMBER_VISITS_QA) 
            FROM (SELECT * FROM Y_UNIFIED_MEMBER_VISITS ) Z 
            --CLAIM HEADER CLAIMS for Office Visit-PCP Visit, Clinic, Office Visit-Specialty Consult, Hospital
            LEFT OUTER JOIN 
                (SELECT C.* FROM XC_UM_CLAIM_HEADER C
                --These Claims Star values are put into a reference table to avoid hard coding
                INNER JOIN (SELECT * FROM Z_PATIENT_SEEN_CLAIM_POS) POS ON C.CLAIM_PLACE_OF_SERVICE = POS.CLAIM_PLACE_OF_SERVICE
                WHERE INCLUDE_FLAG = 'Y'
                AND CLAIM_TYPE IN ('Professional', 'Facility')
                AND CLAIM_CATEGORY IN ('Professional', 'Outpatient')
                ) CH ON CH.CLAIM_ID = Z.ENCOUNTER_ID AND CH.MEMBER_ID = Z.MEMBER_ID AND CH.PAYER = Z.PAYER AND CH.LOB = Z.LOB
            LEFT OUTER JOIN 
            --logic to associate a single service code for the claim that might identify it as a PCP visit to enhance visit data
             (SELECT * FROM 
                     (SELECT EXCL.PROC_CODE AS EXCL_CODE, LOS.PROC_CODE AS INCL_CODE, EXCL.PROC_CODE_DESCRIPTION, LOS.PROC_NAME, COALESCE(EXCL.PROC_CODE_DESCRIPTION, LOS.PROC_NAME) AS PROC_CODE_DESC,
                     COALESCE(EXCL.PROC_CODE,LOS.PROC_CODE) AS PROC_CODE,
                     --ranking to report EXCLUDED PROC CODE first and AMB QUAL DASHBOARD INCLUDED CODE next and any non-null PROC CODE next to display 1 PROC-LEVEL CODE PER CLAIM
                     ROW_NUMBER() OVER (PARTITION BY X.MEMBER_ID, X.PAYER, X.LOB, X.CLAIM_ID, X.SERVICE_DT ORDER BY EXCL.PROC_CODE ASC NULLS LAST, LOS.PROC_CODE DESC NULLS LAST, X.SERVICE_CODE NULLS LAST) AS RN,
                     X.*
-------DATE #5 OF 7
                     FROM (SELECT * FROM X_FACT_SERVICE WHERE SERVICE_DT >= '01-JAN-19') X
                     --LOGIC TO EXCLUDE PROC CODES DETERMINED BY BUSINESS AS OF 12/2024
                     LEFT OUTER JOIN (SELECT * FROM Z_PATIENT_SEEN_PROC_CODE_REF) EXCL ON X.SERVICE_CODE = EXCL.PROC_CODE 
                     --LOGI TO IDENTIFY PROC CODES DETERMINED BY BUSINESS TO INCLUDE LIKE AMBULATORY QUALITY DHASBOARD LOS CODES AS OF 3/15/2025
                     LEFT OUTER JOIN (SELECT * FROM Z_PATIENT_SEEN_LOS_REF) LOS ON X.SERVICE_CODE = LOS.PROC_CODE 
                ) WHERE RN = 1
                 ) XFS ON CH.CLAIM_ID = XFS.CLAIM_ID AND CH.PAYER = XFS.PAYER AND CH.LOB = XFS.LOB AND CH.MEMBER_ID = XFS.MEMBER_ID
            WHERE 
            --QUERY FOR NEW STORED PROCEDURE AND VISIT TABLE DOES NOT FILTER ON VISIT_STATUS_TYPE; NEW STORED PROCEDURE TO CAPTURE ALL VISIT STATUSES)
            Z.SOURCE = 'CLAIMSTAR'
-------DATE #6 OF 7
            AND Z.DATE_OF_SERVICE >= '01-JAN-19' 
            --STATEMENTS TO REMOVE DATA THAT COULDN'T LINK TO VBC MEMBERS 
            AND (Z.DATE_OF_SERVICE IS NOT NULL AND Z.MEMBER_ID IS NOT NULL AND Z.SERVICING_PCP_NPI IS NOT NULL)
            AND NOT(Z.MEMBER_ID LIKE '%?%')
            AND NOT(UPPER(Z.MEMBER_ID) LIKE '%SUBSCRIBER%')
            AND Z.MEMBER_ID IS NOT NULL
            AND Z.PAYER IS NOT NULL
            AND Z.LOB IS NOT NULL
            AND NOT (Z.MEMBER_ID LIKE '00000000%00000000')
            AND Z.SERVICING_PCP_NPI IS NOT NULL
            ;

commit;

select /*+ parallel(4) */ count(1) into v_record_count from Y_PATIENT_SEEN_VISITS_ALL;

v_end_time:=sysdate;

UPDATE  Y_TABLE_REFRESH SET 
END_TIME=v_end_time,
RECORD_COUNT=v_record_count,
load_dt=trunc(sysdate),
status = 'Completed'
WHERE TABLE_NAME=v_table_name AND PAYER=v_subpayer  AND START_TIME = v_start_time;
COMMIT;

EXCEPTION
WHEN OTHERS THEN
    v_err:= SQLCODE;
    v_msg:= SUBSTR(SQLERRM, 1, 200);
    INSERT INTO y_table_err_log (TABLE_NAME,PAYER,category,START_TIME,ERROR_TIME,ERROR_CODE,ERROR_MSG,LOAD_DT,REPROCESSED,REPROCESSED_DT) VALUES (v_table_name,v_subpayer,v_category,v_start_time,SYSDATE,v_err,v_msg,TRUNC(SYSDATE),'N',NULL);
    COMMIT;
    UPDATE  y_TABLE_REFRESH SET END_TIME = SYSDATE,status = 'Failed',load_dt=TRUNC(SYSDATE) WHERE TABLE_NAME=v_table_name AND PAYER=v_subpayer  AND START_TIME = v_start_time;
    COMMIT;

END;

--visit data mart de-duped
BEGIN

v_payer:='ALL';
v_subpayer:='ALL';
v_record_count:=0;
v_start_time:=sysdate;
v_table_name := 'Y_PATIENT_SEEN_VISITS_DATA_MART';

Insert into Y_TABLE_REFRESH(TABLE_NAME,PAYER,CATEGORY,DATE_THROUGH_TYPE,DATE_THROUGH,START_TIME,END_TIME,RECORD_COUNT,RECORD_DIFF,LOAD_DT,status)
            Values(v_table_name,v_subpayer,v_category,'N/A',NULL,v_start_time,NULL,NULL,NULL,NULL,NULL);
COMMIT;

execute immediate 'truncate table Y_PATIENT_SEEN_VISITS_DATA_MART';
--Updated logic based on CS-2961
insert into Y_PATIENT_SEEN_VISITS_DATA_MART
(PAYER, LOB, MEMBER_ID, PRI_MRN, ENCOUNTER_ID, EFFPER, DATE_OF_SERVICE, SOURCE, VISIT_STATUS_TYPE, SERVICING_PCP_NPI, SERVICING_PCP_TIN, SERVICING_PCP_EMP_STATUS, SERVICING_PCP_POD, SERVICING_PCP_PRACTICE, SERVICING_PCP_PROVIDER, EFFMONTH, EFFYEAR, PRAC_EMP_STATUS, PCP_EMP_STATUS, CRNT_PYR, VBC_FLAG, DEATH_DT, PAYER_EFFPER_NPI, PAYER_EFFPER_LVL4_PRACTICE, PAYER_EFFPER_FULL_NAME, PAYER_EFFPER_POD, PAYER_EFFPER_PRAC_EMP_STATUS, PAYER_CURRENT_NPI, PAYER_CURRENT_LVL4_PRACTICE, PAYER_CURRENT_FULL_NAME, PAYER_CURRENT_POD, PAYER_CURRENT_PRAC_EMP_STATUS, EPIC_NPI, EPIC_LVL4_PRACTICE, EPIC_FULL_NAME, EPIC_POD, EPIC_PRAC_EMP_STATUS, ENC_CLOSED_YN, PC_GROUPER_NAME, EPIC_DEPT, ENC_TYPE_C, ENC_TYPE_POS, PROC_CODE, PROC_CODE_DESC, PROV_TITLE, PROV_TITLE_ID, EXCLUDED_EPIC_PROV_TYPE, SCHEDULED_VISIT_YN, SCHED_VISIT_FUTURE_YN, SCHEDULED_WI_180DAYS_YN, PC_VISIT_CMPLT_CLOSE_YN, PC_VISIT_LOS_CODE_YN, PC_VISIT_PROV_TYPE_YN, PC_VISIT_GROUPER_YN, PC_VISIT_ALL_MATCH_YN, PAYER_CURRENT_MATCH, PAYER_EFFPER_MATCH, EPIC_MATCH, PC_GROUPER_MATCH, RYAN_MATCH, ONE_MED_MATCH, ANY_MATCH, HISTORIC_DEF_MATCH, SERVICING_PROV_PCP_SPC, SERVICING_PROV_CMS_PCP_SPC, SERVICING_PRAC_EPIC_STATUS, HISTORICAL_PCP_NPI, HISTORICAL_PCP_TIN, HISTORICAL_PCP_EMP_STATUS, HISTORICAL_PCP_POD, HISTORICAL_PCP_PRACTICE, HISTORICAL_PCP_PROVIDER, HISTORICAL_PROV_PCP_SPC, HISTORICAL_PROV_CMS_PCP_SPC, HISTORICAL_PRAC_EPIC_STATUS, CURRENT_PCP_NPI, CURRENT_PCP_TIN, CURRENT_PCP_EMP_STATUS, CURRENT_PCP_POD, CURRENT_PCP_PRACTICE, CURRENT_PCP_PROVIDER, CURRENT_PROV_PCP_SPC, CURRENT_PROV_CMS_PCP_SPC, CURRENT_PRAC_EPIC_STATUS, ATTRIBUTED_AT_VISIT, CURRENTLY_ATTRIBUTED, HIST_SERV_PROV_CHECK, HIST_SERV_PRAC_CHECK, CURRENT_SERV_PROV_CHECK, CURRENT_SERV_PRAC_CHECK, VISIT_WITH_ANY_SPC_PCP, VISIT_WITH_ANY_CMS_SPC_PCP, AWV_INDICATOR, DATA_UPDATE_DT, DOS_NPI_RN, ENC_RN)
WITH V AS
--add in table name of table created from GitHub: Patients-Seen/01 Patients Seen - S0 visit table with enhanced data
            (SELECT * FROM (SELECT * FROM Y_PATIENT_SEEN_VISITS_ALL)  
            --Y_PATIENT_SEEN_VISITS_ALL  dev table
             WHERE PAYER IS NOT NULL
             AND LOB IS NOT NULL
             AND NOT (MEMBER_ID LIKE '00000000%00000000')
--THESE SHOULD'VE BEEN FIXED IN S0 TABLE. THIS IS A DOUBLE CHECK.
             AND  ((SOURCE IN ('RYAN SCHEDULING') AND VISIT_STATUS_TYPE IN ('SCHEDULED','ARRIVED'))
             OR (SOURCE IN ('MV_DM_PATIENT_ACCESS','CLAIMSTAR')))
-------DATE #1
             AND EFFYEAR >= 2019
            )

,MM AS
--this is the denominator - active VBC members by effper
    (SELECT
    MR.MEMBER_ID, MR.LOB, MR.PAYER, MR.PRI_MRN, 
    MR.NPI, MR.EFFPER, MR.EFFYEAR, MR.PRAC_EMP_STATUS, MR.PCP_EMP_STATUS,
    MR.CRNT_PYR, MR.VBC_FLAG, PCP_FULL_NAME, LVL4_PRACTICE
    FROM (SELECT * FROM XC_UM_MANAGEMENT_REPORTING) MR
    WHERE 
    MR.EFFYEAR >= 2019
    )

--CURRENT EPIC PCP BY NPI AND MRN FROM CURR_PCP IN EPIC; 
--Enhancement to work with DTP to get historic Epic-attributed PCP by effper 
--12/12/2024 update to data sourace from S1_PATIENT_ATTRIBUTION_V (undocumented, unknown owner) to Y_MBR_EPIC_PCP_DTL (created by MSHP Data Engineering CS-2787
,EPIC AS 
    (SELECT MRN, NPI AS EPIC_ATTR_PCP_NPI, RELATIONSHIP_TYPE
    FROM Y_MBR_EPIC_PCP_DTL 
    ) 

--PAYER-ATTRIBUTED PROVIDER INFO FROM X_MEMBER ON MANAGEMENT_REPORTING PCP NPI -> PROVIDER -> CURRENT ATTRIBUTED PRACTICE (HISTORIC ATTRIBUTED PRACTICE IS NOT RETAINED IN CLAIMS STAR)
,PPROV AS
    (SELECT NPI, FULL_NAME, LVL4_PRACTICE, PCP_SPC, CMS_PCP_SPC, LVL5_PRAC_EMP_STATUS, LVL3_SUBGROUP
    FROM X_PROVIDER 
     ) 

--EPIC-ATTRIBUTED PROVIDER INFO S1_PATIENT_ATTRIBUTION_V AS EPIC'S CURRENT PCP NPI -> PROVIDER -> CURRENT ATTRIBUTED PRACTICE (HISTORIC ATTRIBUTED PRACTICE IS NOT RETAINED IN CLAIMS STAR)
,EPROV AS
     (SELECT NPI, FULL_NAME, LVL4_PRACTICE, PCP_SPC, CMS_PCP_SPC, LVL5_PRAC_EMP_STATUS, LVL3_SUBGROUP
     FROM X_PROVIDER
     ) 

--01/22/2025 CURRENT PAYER-ATTRIBUTED PROVIDER INFO BASED ON MOST RECENT MEMBER ATTRIBUTION
--THIS IS A REQUEST FROM POR WORK TO COUNT VISITS FROM PAYER-ATTRIBUTED PROVIDER/PRACTICE WHEN MEMBER ISN'T ATTRIBUTED TO VBC CONTRACT; DATA WILL REFRESH EACH TIME TABLE REFRESHES
--test member   MEMBER_ID = '00000021630189697325' AND PAYER = 'AETNA' AND LOB = 'Commercial'
,CURR_PAYER_PROV AS
   (SELECT * FROM 
        (SELECT 
        LOB, PAYER, MEMBER_ID, EFFPER, NPI, PRAC_EMP_STATUS, PCP_FULL_NAME, LVL4_PRACTICE,
        ROW_NUMBER() OVER (PARTITION BY LOB, PAYER, MEMBER_ID ORDER BY EFFPER DESC) AS RN
        FROM XC_UM_MANAGEMENT_REPORTING MR
        ) MR_CURR_PAYER_PROV
    WHERE RN = 1
    )

--01/22/2025 ADDED TO SUPPORT CURRENT PAYER-ATTRIBUTED PROVIDER INFO BASED ON MOST RECENT MEMBER ATTRIBUTION
,CPROV AS
    (SELECT NPI, FULL_NAME, LVL4_PRACTICE, PCP_SPC, CMS_PCP_SPC, LVL5_PRAC_EMP_STATUS, LVL3_SUBGROUP
     FROM X_PROVIDER
     ) 

--CLAIM STAR DEATH DT, different info than Epic; Per Gayathri, we get more info back from the payer so there'll be more death info
,CS_DEATH AS
    (SELECT MEMBER_ID, PRI_MRN, LOB, PAYER, DEATH_DT, FULL_NAME FROM X_MEMBER)   



SELECT * FROM (
SELECT 
--COLAPSE CLAIM AND EPIC INTO SINGLE ROW
B.*,
ROW_NUMBER() OVER (PARTITION BY MEMBER_ID, LOB, PAYER, TO_DATE(DATE_OF_SERVICE), SERVICING_PCP_NPI, PC_VISIT_CMPLT_CLOSE_YN ORDER BY PC_VISIT_ALL_MATCH_YN DESC NULLS LAST, SOURCE DESC) AS ENC_RN
FROM 
(SELECT A.* FROM 
(SELECT 
--PRIOR RANKING FROM 12/2024 
Z.*,

--3/15/24 change in logic to get edge case individual encounters - member having >1 visit on same DOS, same NPI servicing provider 
ROW_NUMBER() OVER (PARTITION BY Z.LOB, Z.PAYER, Z.MEMBER_ID, TO_DATE(Z.DATE_OF_SERVICE), Z.SERVICING_PCP_NPI, Z.ENCOUNTER_ID ORDER BY Z.ANY_MATCH DESC, Z.PC_VISIT_ALL_MATCH_YN DESC, Z.AWV_INDICATOR DESC, Z.SOURCE DESC) AS DOS_NPI_RN

FROM 
(SELECT * FROM    
    (SELECT   
    X.PAYER,
    X.LOB,
    X.MEMBER_ID,
    X.PRI_MRN,
    X.ENCOUNTER_ID,
    X.EFFPER,
    X.DATE_OF_SERVICE,
    X.SOURCE,
    X.VISIT_STATUS_TYPE,
    X.SERVICING_PCP_NPI,
    X.SERVICING_PCP_TIN,
    X.SERVICING_PCP_EMP_STATUS,
    X.SERVICING_PCP_POD,
    X.SERVICING_PCP_PRACTICE,
    X.SERVICING_PCP_PROVIDER,
    SUBSTR(X.EFFPER,6,7) AS EFFMONTH,
    X.EFFYEAR,

    --THIS WAS A FIELD TO COMPARE MSSP PAYER STAMPED ON S0 TABLE VS. CASE STATEMENT TO REPORT ALL HISTORIC MSSP NAMES AS 'MSSP NYMP'
    --X.PAYER_NOT_CHGD,
    X.PRAC_EMP_STATUS,
    X.PCP_EMP_STATUS,
    X.CRNT_PYR,
    --SEEMS TO BE SAME COLUMN AS LEGACY TABLE 'ATTRIBUTED_AT_VISIT'
    X.VBC_FLAG,
    X.DEATH_DT,
    X.PAYER_EFFPER_NPI,
    X.PAYER_EFFPER_LVL4_PRACTICE,
    X.PAYER_EFFPER_FULL_NAME,
    X.PAYER_EFFPER_POD,
    X.PAYER_EFFPER_PRAC_EMP_STATUS,
    X.PAYER_CURRENT_NPI,
    X.PAYER_CURRENT_LVL4_PRACTICE,
    X.PAYER_CURRENT_FULL_NAME,
    X.PAYER_CURRENT_POD,
    X.PAYER_CURRENT_PRAC_EMP_STATUS,
    X.EPIC_NPI,
    X.EPIC_LVL4_PRACTICE,
    X.EPIC_FULL_NAME,
    X.EPIC_POD,
    X.EPIC_PRAC_EMP_STATUS,
    --NOTE: APPT_STATUS IS BEING REMOVED FROM TABLE SINCE RESULTS CAN CAUSE FALSE POSITIVE CONFUSION FOR TELEHEALTH VISITS 
--    X.APPT_STATUS,
    X.ENC_CLOSED_YN,
    X.GROUPER_NAME AS PC_GROUPER_NAME,
    X.DEPARTMENT_NAME AS EPIC_DEPT,
    X.ENC_TYPE_C,
    X.ENC_TYPE_POS,
    X.PROC_CODE,
    X.PROC_CODE_DESC,
    X.PROV_TITLE,
    X.PROV_TITLE_ID,
    --EXCLUDED AFTER 4/14/25 DUE TO VISIT DEFINITION BASED ON AMBULATORY QUALITY DASHBOARD W FLAGS CREATED IN S0 TABLE 
    X.EXCLUDED_EPIC_PROV_TYPE,
    X.SCHEDULED_VISIT_YN,
    X.SCHED_VISIT_FUTURE_YN,
    X.SCHEDULED_WI_180DAYS_YN,
    X.PC_VISIT_CMPLT_CLOSE_YN,
    X.PC_VISIT_LOS_CODE_YN,
    X.PC_VISIT_PROV_TYPE_YN,
    PC_VISIT_GROUPER_YN,
    PC_VISIT_ALL_MATCH_YN,
    X.PAYER_CURRENT_MATCH,
    X.PAYER_EFFPER_MATCH,
    X.EPIC_MATCH,
    X.PC_GROUPER_MATCH,
    X.RYAN_MATCH,
    X.ONE_MED_MATCH,
    CASE WHEN PAYER_EFFPER_MATCH = TO_NUMBER('1') OR EPIC_MATCH = TO_NUMBER('1') OR PC_GROUPER_MATCH = TO_NUMBER('1') OR RYAN_MATCH = TO_NUMBER('1') 
    OR ONE_MED_MATCH = TO_NUMBER('1') OR PAYER_CURRENT_MATCH = TO_NUMBER('1')  THEN TO_NUMBER('1') ELSE TO_NUMBER('0') END AS ANY_MATCH,
    X.HISTORIC_DEF_MATCH,
    --LEGACY COLUMNS FROM Z_UNIFIED_MEMBER_VISITS RETAINED FOR LEGACY ANALYSIS
    X.SERVICING_PROV_PCP_SPC,
    X.SERVICING_PROV_CMS_PCP_SPC,
    X.SERVICING_PRAC_EPIC_STATUS,
    X.HISTORICAL_PCP_NPI,
    X.HISTORICAL_PCP_TIN,
    X.HISTORICAL_PCP_EMP_STATUS,
    X.HISTORICAL_PCP_POD,
    X.HISTORICAL_PCP_PRACTICE,
    X.HISTORICAL_PCP_PROVIDER,
    X.HISTORICAL_PROV_PCP_SPC,
    X.HISTORICAL_PROV_CMS_PCP_SPC,
    X.HISTORICAL_PRAC_EPIC_STATUS,
    X.CURRENT_PCP_NPI,
    X.CURRENT_PCP_TIN,
    X.CURRENT_PCP_EMP_STATUS,
    X.CURRENT_PCP_POD,
    X.CURRENT_PCP_PRACTICE,
    X.CURRENT_PCP_PROVIDER,
    X.CURRENT_PROV_PCP_SPC,
    X.CURRENT_PROV_CMS_PCP_SPC,
    X.CURRENT_PRAC_EPIC_STATUS,
    X.ATTRIBUTED_AT_VISIT,
    X.CURRENTLY_ATTRIBUTED,
    X.HIST_SERV_PROV_CHECK,
    X.HIST_SERV_PRAC_CHECK,
    X.CURRENT_SERV_PROV_CHECK,
    X.CURRENT_SERV_PRAC_CHECK,
    X.VISIT_WITH_ANY_SPC_PCP,
    X.VISIT_WITH_ANY_CMS_SPC_PCP,
    X.AWV_INDICATOR,
--PRIOR RANKING LOGIC AND PLACEMENT IN CODE FROM 12/2024 
--MOVING IT OUT TO USE 'ANY NEW DEF MATCH'
--1/25/2025 THIS NEEDS MORE THOUGHT TO BEST CONSIDER VISIT_STATUS_TYPE - IF THERE ARE MULTIPLE VISITS PER MEMBER, PAYER, LOB, DATE OF SERVICE, NPI, HOW TO APPROPRIATE CONSIDER VISIT STATUS TYPE TO FAVOR? TRIED USING COMPLETED VISITS/SCHEDULED VISIT FLAGS
--    ROW_NUMBER() OVER (PARTITION BY X.LOB, X.PAYER, X.MEMBER_ID, TO_DATE(X.DATE_OF_SERVICE), X.SERVICING_PCP_NPI ORDER BY X.GROUPER_NAME DESC NULLS LAST, X.DEPARTMENT_NAME DESC NULLS LAST, X.SOURCE DESC) AS RN,
    X.DATA_UPDATE_DT

    FROM

        (SELECT VIS.*, 
    --VISIT MATCHING LOGIC FLAGS  2/3/2015 adding exclusions and visit status types 
--CURRRENT PAYER ATTRIB MATCH modeled after EPIC ATTRIB MATCH  ADDED 1/22/25, REVISED 3/23/2025 TO SPLIT LOGIC FOR CLAIMS AND CLINICAL
        CASE 
        WHEN (((UPPER(VIS.PAYER_CURRENT_LVL4_PRACTICE) = UPPER(VIS.SERVICING_PCP_PRACTICE) AND NOT(VIS.PAYER_CURRENT_POD LIKE '%Requires Investigation%') )
        AND VIS.PAYER_CURRENT_LVL4_PRACTICE IS NOT NULL 
        --3/15/25 REVISED LOGIC
        AND (VIS.PC_VISIT_LOS_CODE_YN = 1 AND VIS.PC_VISIT_CMPLT_CLOSE_YN = 1 AND VIS.PC_VISIT_PROV_TYPE_YN = 1
        --3/23/2025 SEPARATE CLINICAL LOGIC
        AND VIS.SOURCE IN ('MV_DM_PATIENT_ACCESS')))
        ) THEN TO_NUMBER('1') 

        --Claims added 3/23/25
        WHEN (((UPPER(VIS.PAYER_CURRENT_LVL4_PRACTICE) = UPPER(VIS.SERVICING_PCP_PRACTICE) AND NOT(VIS.PAYER_CURRENT_POD LIKE '%Requires Investigation%') )
        AND VIS.PAYER_CURRENT_LVL4_PRACTICE IS NOT NULL 
        --3/15/25 REVISED LOGIC
        AND (VIS.PC_VISIT_LOS_CODE_YN = 1 AND VIS.PC_VISIT_CMPLT_CLOSE_YN = 1 
        --3/23/2025 SEPARATE CLINICAL LOGIC
        AND VIS.SOURCE IN ('CLAIMSTAR')))
        ) THEN TO_NUMBER('1') 

        --Non-affiliated providers can match if NPI of attributed provider = NPI of visit servicing provider alone
        WHEN (VIS.PAYER_CURRENT_NPI = VIS.SERVICING_PCP_NPI
            --3/15/25 REVISED LOGIC
             AND (VIS.PC_VISIT_LOS_CODE_YN = 1 AND VIS.PC_VISIT_CMPLT_CLOSE_YN = 1 AND VIS.PC_VISIT_PROV_TYPE_YN = 1 AND VIS.SOURCE IN ('MV_DM_PATIENT_ACCESS'))
             ) THEN TO_NUMBER('1')     

        --Non-affiliated providers can match if NPI of attributed provider = NPI of visit servicing provider alone
        WHEN (VIS.PAYER_CURRENT_NPI = VIS.SERVICING_PCP_NPI
            --3/15/25 REVISED LOGIC
             AND (VIS.PC_VISIT_LOS_CODE_YN = 1 AND VIS.PC_VISIT_CMPLT_CLOSE_YN = 1 AND VIS.SOURCE IN ('CLAIMSTAR'))
             ) THEN TO_NUMBER('1')
             ELSE TO_NUMBER('0') END AS PAYER_CURRENT_MATCH,


    --PAYER EFFPER ATTRIB MATCH
        CASE WHEN (((UPPER(VIS.PAYER_EFFPER_LVL4_PRACTICE) = UPPER(VIS.SERVICING_PCP_PRACTICE) AND NOT(VIS.PAYER_EFFPER_POD LIKE '%Requires Investigation%'))
        AND VIS.PAYER_EFFPER_LVL4_PRACTICE IS NOT NULL
        --3/15/25 REVISED LOGIC
        AND (VIS.PC_VISIT_LOS_CODE_YN = 1 AND VIS.PC_VISIT_CMPLT_CLOSE_YN = 1 AND VIS.PC_VISIT_PROV_TYPE_YN = 1 AND VIS.SOURCE IN ('MV_DM_PATIENT_ACCESS')))
        ) THEN TO_NUMBER('1') 

        --Claims added 3/23/25
        WHEN (((UPPER(VIS.PAYER_EFFPER_LVL4_PRACTICE) = UPPER(VIS.SERVICING_PCP_PRACTICE) AND NOT(VIS.PAYER_EFFPER_POD LIKE '%Requires Investigation%') )
        AND VIS.PAYER_EFFPER_LVL4_PRACTICE IS NOT NULL 
        --3/15/25 REVISED LOGIC
        AND (VIS.PC_VISIT_LOS_CODE_YN = 1 AND VIS.PC_VISIT_CMPLT_CLOSE_YN = 1  AND VIS.SOURCE IN ('CLAIMSTAR')))
        ) THEN TO_NUMBER('1') 

        --Non-affiliated providers can match if NPI of attributed provider = NPI of visit servicing provider (Healthfirst case), but but be NPI match and not practice name match (too generous on non-affiliated by practice name)
            WHEN (VIS.PAYER_EFFPER_NPI = VIS.SERVICING_PCP_NPI
            --3/15/25 REVISED LOGIC
            AND (VIS.PC_VISIT_LOS_CODE_YN = 1 AND VIS.PC_VISIT_CMPLT_CLOSE_YN = 1 AND VIS.PC_VISIT_PROV_TYPE_YN = 1 AND VIS.SOURCE IN ('MV_DM_PATIENT_ACCESS'))
            ) THEN TO_NUMBER('1')  

            --Non-affiliated providers can match if NPI of attributed provider = NPI of visit servicing provider alone
            WHEN (VIS.PAYER_EFFPER_NPI = VIS.SERVICING_PCP_NPI
            --3/15/25 REVISED LOGIC
             AND (VIS.PC_VISIT_LOS_CODE_YN = 1 AND VIS.PC_VISIT_CMPLT_CLOSE_YN = 1 AND VIS.SOURCE IN ('CLAIMSTAR'))
             ) THEN TO_NUMBER('1')
            ELSE TO_NUMBER('0') END AS PAYER_EFFPER_MATCH,

    --EPIC ATTRIB MATCH
        --removes cases of incorrectly matching on practice names like '80 - Requires Investigation - Employed' or '80 - Requires Investigation - Not Affiliated'
        CASE WHEN (UPPER(VIS.EPIC_LVL4_PRACTICE) = UPPER(VIS.SERVICING_PCP_PRACTICE) AND NOT(VIS.EPIC_POD LIKE '%Requires Investigation%') 
        AND VIS.EPIC_LVL4_PRACTICE IS NOT NULL 
        --3/15/25 REVISED LOGIC
        AND (VIS.PC_VISIT_LOS_CODE_YN = 1 AND VIS.PC_VISIT_CMPLT_CLOSE_YN = 1 AND VIS.PC_VISIT_PROV_TYPE_YN = 1 AND VIS.SOURCE IN ('MV_DM_PATIENT_ACCESS'))
        ) THEN TO_NUMBER('1')   

         --Claims added 3/23/25
        WHEN ((UPPER(VIS.EPIC_LVL4_PRACTICE) = UPPER(VIS.SERVICING_PCP_PRACTICE) AND NOT(VIS.EPIC_POD LIKE '%Requires Investigation%') )
        AND VIS.EPIC_LVL4_PRACTICE IS NOT NULL
        --3/15/25 REVISED LOGIC
        AND (VIS.PC_VISIT_LOS_CODE_YN = 1 AND VIS.PC_VISIT_CMPLT_CLOSE_YN = 1  AND VIS.SOURCE IN ('CLAIMSTAR'))
        ) THEN TO_NUMBER('1') 

        --Non-affiliated providers can match if NPI of attributed provider = NPI of visit servicing provider (Healthfirst case), but but be NPI match and not practice name match (too generous on non-affiliated by practice name)
            WHEN (VIS.EPIC_NPI = VIS.SERVICING_PCP_NPI 
            --3/15/25 REVISED LOGIC
            AND (VIS.PC_VISIT_LOS_CODE_YN = 1 AND VIS.PC_VISIT_CMPLT_CLOSE_YN = 1 AND VIS.PC_VISIT_PROV_TYPE_YN = 1 AND VIS.SOURCE IN ('MV_DM_PATIENT_ACCESS'))
             ) THEN TO_NUMBER('1')  

             WHEN (VIS.EPIC_NPI = VIS.SERVICING_PCP_NPI 
            --3/15/25 REVISED LOGIC
            AND (VIS.PC_VISIT_LOS_CODE_YN = 1 AND VIS.PC_VISIT_CMPLT_CLOSE_YN = 1 AND VIS.SOURCE IN ('CLAIMSTAR'))
             ) THEN TO_NUMBER('1') 
             ELSE TO_NUMBER('0') END AS EPIC_MATCH,

    --PC GROUPER MATCH         
        --4/9/25 REVISED LOGIC 
        CASE WHEN VIS.SOURCE IN ('MV_DM_PATIENT_ACCESS')
        AND (VIS.PC_VISIT_LOS_CODE_YN = 1 AND VIS.PC_VISIT_CMPLT_CLOSE_YN = 1 AND VIS.PC_VISIT_PROV_TYPE_YN = 1 AND VIS.PC_VISIT_GROUPER_YN = 1)
        THEN TO_NUMBER('1') ELSE TO_NUMBER('0') END AS PC_GROUPER_MATCH,  

    --RYAN MATCH
        CASE WHEN (VIS.SERVICING_PCP_POD IN ('23 - Ryan Health') AND (VIS.SERVICING_PCP_POD = VIS.EPIC_POD OR VIS.SERVICING_PCP_POD = VIS.PAYER_EFFPER_POD OR VIS.SERVICING_PCP_POD = VIS.PAYER_CURRENT_POD)
        --3/15/25 REVISED LOGIC
        AND (VIS.PC_VISIT_LOS_CODE_YN = 1 AND VIS.PC_VISIT_CMPLT_CLOSE_YN = 1 AND VIS.SOURCE IN ('CLAIMSTAR'))
        ) THEN TO_NUMBER('1') ELSE TO_NUMBER('0') END AS RYAN_MATCH,

    --ONE MEDICAL MATCH
        CASE WHEN (VIS.SERVICING_PCP_POD IN ('07 - One Medical') AND (VIS.SERVICING_PCP_POD = VIS.EPIC_POD OR VIS.SERVICING_PCP_POD = VIS.PAYER_EFFPER_POD OR VIS.SERVICING_PCP_POD = VIS.PAYER_CURRENT_POD)
        --3/15/25 REVISED LOGIC
        AND (VIS.PC_VISIT_LOS_CODE_YN = 1 AND VIS.PC_VISIT_CMPLT_CLOSE_YN = 1 AND VIS.PC_VISIT_PROV_TYPE_YN = 1 AND VIS.SOURCE IN ('MV_DM_PATIENT_ACCESS'))
        ) THEN TO_NUMBER('1') 

        WHEN (VIS.SERVICING_PCP_POD IN ('07 - One Medical') AND (VIS.SERVICING_PCP_POD = VIS.EPIC_POD OR VIS.SERVICING_PCP_POD = VIS.PAYER_EFFPER_POD OR VIS.SERVICING_PCP_POD = VIS.PAYER_CURRENT_POD)
        --3/15/25 REVISED LOGIC
        AND (VIS.PC_VISIT_LOS_CODE_YN = 1 AND VIS.PC_VISIT_CMPLT_CLOSE_YN = 1 AND VIS.SOURCE IN ('CLAIMSTAR'))
        ) THEN TO_NUMBER('1')
        ELSE TO_NUMBER('0') END AS ONE_MED_MATCH,    

    --HISTORIC MATCH  --confirmed with 12/11/2024 deep dive that Patients Seen current dashboard only counts PCP visits if member is in contract during effper of visit effper; visit and membership tables are joined on effper, LOB, Payer, Member ID
    --it's important in HISTORIC MATCH for VBC_FLAG = 'Y' because historic definition need to have a visit in the effper the member was attributed
        CASE WHEN (VIS.SERVICING_PROV_PCP_SPC = 'PCP' AND VBC_FLAG = 'Y') THEN TO_NUMBER('1') ELSE TO_NUMBER('0') END AS HISTORIC_DEF_MATCH
        FROM
        (
            SELECT PCP.* FROM   
                (

                SELECT 
                V.PAYER,
                V.LOB,
                V.MEMBER_ID,
                V.MRN AS PRI_MRN,
                V.ENCOUNTER_ID,
                V.EFFPER,
                TO_DATE(V.DATE_OF_SERVICE,'DD-MON-YY') AS DATE_OF_SERVICE,
                V.SOURCE,
                --these fields are pickups from existing Z_UNIFIED_MEMBER_VISITS so any legacy report can use these
                V.VISIT_STATUS_TYPE,
                V.HISTORICAL_PCP_NPI,
                V.HISTORICAL_PCP_TIN,
                V.HISTORICAL_PCP_EMP_STATUS,
                V.HISTORICAL_PCP_POD,
                V.HISTORICAL_PCP_PRACTICE,
                V.HISTORICAL_PCP_PROVIDER,
                V.HISTORICAL_PROV_PCP_SPC,
                V.HISTORICAL_PROV_CMS_PCP_SPC,
                V.HISTORICAL_PRAC_EPIC_STATUS,
                V.CURRENT_PCP_NPI,
                V.CURRENT_PCP_TIN,
                V.CURRENT_PCP_EMP_STATUS,
                V.CURRENT_PCP_POD,
                V.CURRENT_PCP_PRACTICE,
                V.CURRENT_PCP_PROVIDER,
                V.CURRENT_PROV_PCP_SPC,
                V.CURRENT_PROV_CMS_PCP_SPC,
                V.CURRENT_PRAC_EPIC_STATUS,
                V.SERVICING_PCP_NPI,
                V.SERVICING_PCP_TIN,
                V.SERVICING_PCP_EMP_STATUS,
                V.SERVICING_PCP_POD,
                V.SERVICING_PCP_PRACTICE,
                V.SERVICING_PCP_PROVIDER,
                V.SERVICING_PROV_PCP_SPC,
                V.SERVICING_PROV_CMS_PCP_SPC,
                V.SERVICING_PRAC_EPIC_STATUS,
                V.ATTRIBUTED_AT_VISIT,
                V.CURRENTLY_ATTRIBUTED,
                V.HIST_SERV_PROV_CHECK,
                V.HIST_SERV_PRAC_CHECK,
                V.CURRENT_SERV_PROV_CHECK,
                V.CURRENT_SERV_PRAC_CHECK,
                V.VISIT_WITH_ANY_SPC_PCP,
                V.VISIT_WITH_ANY_CMS_SPC_PCP,
                V.AWV_INDICATOR,
    --            V.LOAD_DT,
                V.EFFYEAR,
                V.GROUPER_NAME,
                V.DEPARTMENT_NAME,
                V.ENC_TYPE_C,

                V.ENC_TYPE_POS,
                V.PROC_CODE,

                V.PROC_CODE_DESC,
                V.PROV_TITLE,
                V.PROV_TITLE_ID,
                --NOTE: APPT_STATUS IS BEING REMOVED FROM TABLE SINCE RESULTS CAN CAUSE FALSE POSITIVE CONFUSION FOR TELEHEALTH VISITS
--                V.APPT_STATUS,
                V.ENC_CLOSED_YN,
                V.PAYER_NOT_CHGD, 
                MM.PRAC_EMP_STATUS,
                MM.PCP_EMP_STATUS,
                MM.CRNT_PYR,
                MM.VBC_FLAG,
                CS_DEATH.DEATH_DT,
                MM.NPI AS PAYER_EFFPER_NPI, 
                PPROV.LVL4_PRACTICE AS PAYER_EFFPER_LVL4_PRACTICE,
                PPROV.FULL_NAME AS PAYER_EFFPER_FULL_NAME,
                PPROV.PCP_SPC AS PAYER_EFFPER_PCP_SPC, 
                PPROV.LVL3_SUBGROUP AS PAYER_EFFPER_POD,
                PPROV.LVL5_PRAC_EMP_STATUS AS PAYER_EFFPER_PRAC_EMP_STATUS,

                EPIC.EPIC_ATTR_PCP_NPI AS EPIC_NPI,
                EPROV.LVL4_PRACTICE AS EPIC_LVL4_PRACTICE,
                EPROV.FULL_NAME AS EPIC_FULL_NAME,
                EPROV.PCP_SPC AS EPIC_PCP_SPC,
                EPROV.LVL3_SUBGROUP AS EPIC_POD,
                EPROV.LVL5_PRAC_EMP_STATUS AS EPIC_PRAC_EMP_STATUS,

                --ADDED 1/22/25
                CURR_PAYER_PROV.NPI AS PAYER_CURRENT_NPI,
                CPROV.LVL4_PRACTICE AS PAYER_CURRENT_LVL4_PRACTICE,
                CPROV.FULL_NAME AS PAYER_CURRENT_FULL_NAME,
                CPROV.PCP_SPC AS PAYER_CURRENT_PCP_SPC,
                CPROV.LVL3_SUBGROUP AS PAYER_CURRENT_POD,
                CPROV.LVL5_PRAC_EMP_STATUS AS PAYER_CURRENT_PRAC_EMP_STATUS,

                CASE WHEN V.SOURCE IN ('MV_DM_PATIENT_ACCESS') AND V.PC_VISIT_PROV_TYPE_YN IS NULL OR V.PC_VISIT_PROV_TYPE_YN = 0 THEN TO_NUMBER('1') END AS EXCLUDED_EPIC_PROV_TYPE,
                CAST(null AS NUMBER)  AS EXCLUDED_EPIC_ENC_TYPE,
                CASE WHEN V.PC_VISIT_LOS_CODE_YN IS NULL OR V.PC_VISIT_LOS_CODE_YN = 0 THEN TO_NUMBER('1') END AS EXCLUDED_PROC_CODE,
                CASE WHEN V.PC_VISIT_GROUPER_YN IS NULL OR V.PC_VISIT_GROUPER_YN = 0 THEN TO_NUMBER('1') END AS EXCLUDED_PC_GROUPER,
                CASE WHEN V.PC_VISIT_CMPLT_CLOSE_YN IS NULL OR V.PC_VISIT_CMPLT_CLOSE_YN = 1 THEN TO_NUMBER('1') END AS EXCLUDED_VIS_COMPL_CLSD,
                CASE WHEN V.PC_VISIT_ALL_MATCH_YN IS NULL OR V.PC_VISIT_ALL_MATCH_YN = 0 THEN TO_NUMBER('1') END AS EXCLUDED_ANY_REASON,
                --3/15/25 for Epic data 
                V.PC_VISIT_CMPLT_CLOSE_YN,
                V.PC_VISIT_LOS_CODE_YN,
                V.PC_VISIT_PROV_TYPE_YN,
                V.PC_VISIT_GROUPER_YN,
                V.PC_VISIT_ALL_MATCH_YN,

--2/4/2025 THIS SECTION OF FLAGS WAS CREATED TO FAVOR COMPLETED VISITS     
    --REVISE LOGIC ON 12/17/2024 TO INCLUDE DOS < SYSDATE
    --3/15/25 REVISE COMPLETED VISIT DATA TO PICK UP VISIT_CHECK FLAGS FOR EPIC VISITS USING LOGIC IN AMBULATORY QUALITY DASHBOARD
                CASE WHEN (V.SOURCE IN ('MV_DM_PATIENT_ACCESS') AND PC_VISIT_CMPLT_CLOSE_YN = 1 AND V.PC_VISIT_LOS_CODE_YN = 1 AND V.PC_VISIT_PROV_TYPE_YN = 1) THEN TO_NUMBER('1') 
                WHEN (V.SOURCE IN ('CLAIMSTAR') AND V.PC_VISIT_LOS_CODE_YN = 1 AND V.PC_VISIT_CMPLT_CLOSE_YN = 1 ) THEN TO_NUMBER('1')
                ELSE TO_NUMBER('0') END AS COMPLETED_VISIT_YN,
    --REVISE LOGIC ON 5/4/2025 TO ONLY COUNT RYAN SCHDULING DATA AS FUTURE ARRIVED/SCHEDULED VISITS 
                CASE WHEN (V.SOURCE IN ('RYAN SCHEDULING') AND V.VISIT_STATUS_TYPE IN ('ARRIVED','SCHEDULED') AND DATE_OF_SERVICE > SYSDATE) THEN TO_NUMBER('1') 
    --REVISED LOGIC ON 5/4/2025 TO REMOVE F_SCHED_APPT (PER DTP: ALREADY CAPTURED IN MV_DM_PATIENT_ACCESS) AND ADD IN MV_DM_PATIENT_ACCESS WHERE ENC_TYPE_C = 50 (SCHEDULED APPOINTMENTS WITH VISIT TYPE OF SCHEDULED PER DTP)
    --REVISED LOGIC ON 6/26/2025 TO ADD 'AND V.GROUPER_NAMEIS NOT NULL' TO EPIC SCHEDULED VISIT LOGIC PER STAKEHOLDER REQUEST
                WHEN (V.SOURCE IN ('MV_DM_PATIENT_ACCESS') AND V.ENC_TYPE_C = '50' AND V.VISIT_STATUS_TYPE = 'SCHEDULED' AND V.GROUPER_NAME IS NOT NULL) THEN TO_NUMBER('1') ELSE TO_NUMBER('0')
                END AS SCHEDULED_VISIT_YN,
                CASE WHEN (V.SOURCE IN ('RYAN SCHEDULING') AND V.VISIT_STATUS_TYPE IN ('ARRIVED','SCHEDULED') AND (TO_DATE(V.DATE_OF_SERVICE) > SYSDATE)) THEN TO_NUMBER('1')  
                WHEN (V.SOURCE IN ('MV_DM_PATIENT_ACCESS') AND V.ENC_TYPE_C = '50' AND V.VISIT_STATUS_TYPE = 'SCHEDULED' AND V.GROUPER_NAME IS NOT NULL AND (TO_DATE(V.DATE_OF_SERVICE) > SYSDATE)) THEN TO_NUMBER('1') ELSE TO_NUMBER('0') 
                END AS SCHED_VISIT_FUTURE_YN,
    --REVISE LOGIC ON 5/4/2025 TO REMOVE F_SCHED_APPT AND ADD IN MV_DM_PATIENT_ACCESS WHERE ENC_TYPE_C = 50
    --REVISED LOGIC ON 6/26/2025 TO ADD 'AND V.GROUPER_NAME IS NOT NULL' TO EPIC SCHEDULED VISIT LOGIC PER STAKEHOLDER REQUEST
                CASE WHEN V.SOURCE IN ('RYAN SCHEDULING') AND V.VISIT_STATUS_TYPE IN ('ARRIVED','SCHEDULED') AND (TO_DATE(V.DATE_OF_SERVICE) > SYSDATE AND TO_DATE(V.DATE_OF_SERVICE) <= SYSDATE + 180) THEN TO_NUMBER('1') 
                WHEN (V.SOURCE IN ('MV_DM_PATIENT_ACCESS') AND V.ENC_TYPE_C = '50' AND V.VISIT_STATUS_TYPE = 'SCHEDULED' AND V.GROUPER_NAME IS NOT NULL AND(TO_DATE(V.DATE_OF_SERVICE) > SYSDATE AND TO_DATE(V.DATE_OF_SERVICE) <= SYSDATE + 180)) THEN TO_NUMBER('1') ELSE TO_NUMBER('0')
                END AS SCHEDULED_WI_180DAYS_YN,
    --REMOVED ORIG LOGIC TO DE-DUPE VISITS TO 1 PER MEMBER_ID, PAYER, LOB, DATE_OF_SERVICE, SERVICING_NPI  --DIDN'T ACCOUNT FOR MEMBER HAVING > 1 VISIT PER DATE OF SERVICE, SERVICING PROVIDER BECAUSE OF APPTOINTMENTS AND VISITS IN F_SCHED AND MV_DM_PATIENT_ACCESS
    --ROW_NUMBER() OVER (PARTITION BY V.LOB, V.PAYER, V.MEMBER_ID, TO_DATE(V.DATE_OF_SERVICE), V.SERVICING_PCP_NPI ORDER BY V.GROUPER_NAME DESC NULLS LAST, V.DEPARTMENT_NAME DESC NULLS LAST, V.SOURCE DESC) AS RN_ORIG

                TO_DATE(SYSDATE,'DD-MON-YY') AS DATA_UPDATE_DT
--  
                FROM V 
                LEFT OUTER JOIN MM ON V.MEMBER_ID = MM.MEMBER_ID AND V.LOB = MM.LOB AND V.PAYER = MM.PAYER AND V.EFFPER = MM.EFFPER  --AND V.EFFYEAR = MM.EFFYEAR  
                --MRN JOIN FROM EPIC DATA TO VISIT MRN SO ALL EFFPERS POPULATE 
                LEFT OUTER JOIN EPIC ON EPIC.MRN = V.MRN  
                LEFT OUTER JOIN PPROV ON PPROV.NPI = MM.NPI   
                LEFT OUTER JOIN EPROV ON EPROV.NPI = EPIC.EPIC_ATTR_PCP_NPI  
                --ADDING LOGIC FOR CURRENT PAYER-ATTRIBUTED PROVIDER 1/22/25
                LEFT OUTER JOIN CURR_PAYER_PROV ON CURR_PAYER_PROV.MEMBER_ID = V.MEMBER_ID AND CURR_PAYER_PROV.LOB = V.LOB AND CURR_PAYER_PROV.PAYER = V.PAYER
                --ADDING LOGIC FOR CURRENT PAYER-ATTRIBUTED PROVIDER 1/22/25
                LEFT OUTER JOIN CPROV ON CPROV.NPI = CURR_PAYER_PROV.NPI
                LEFT OUTER JOIN CS_DEATH ON V.MEMBER_ID = CS_DEATH.MEMBER_ID AND V.LOB = CS_DEATH.LOB AND V.PAYER = CS_DEATH.PAYER

                --logic from 12/13/24 updated 3/15/25
                LEFT OUTER JOIN Z_PATIENT_SEEN_PROC_CODE_REF ON Z_PATIENT_SEEN_PROC_CODE_REF.PROC_CODE = V.PROC_CODE    --select * from Z_PATIENT_SEEN_PROC_CODE_REF
                --business reference table defining Epic encounters that count as patient seen visits
                --LEFT OUTER JOIN Z_PATIENT_SEEN_ENC_REF ON TO_NUMBER(V.ENC_TYPE_C) = TO_NUMBER(Z_PATIENT_SEEN_ENC_REF.ENC_TYPE_C)  --select * from Z_PATIENT_SEEN_ENC_REF
                --business reference table defining Epic provider credentials that count as patient seen visits
                --6/26/2025 CHANGE FROM Z_PATIENT_SEEN_PROV_TYPE_REF AS OLDER LOGIC TO Z_PATIENT_SEEN_SER_PROVIDER_TYPE_REF PER NIKITA / YING FOR AMB QUALITY DASHBOARD 
                LEFT OUTER JOIN Z_PATIENT_SEEN_SER_PROVIDER_TYPE_REF ON V.PROV_TITLE_ID = Z_PATIENT_SEEN_SER_PROVIDER_TYPE_REF.PROVIDER_TYPE_C  --select * from Z_PATIENT_SEEN_PROV_TYPE_REF  --SELECT * FROM Z_PATIENT_SEEN_SER_PROVIDER_TYPE_REF

                WHERE 
                --Filter for visit data that doesn't align to VBC LOBs
                V.LOB IN ('Medicare','MA','Commercial','Medicaid') 
                --TEST MEMBERS WITH MULTIPLE ENCS ON SAME DOS, NPI AND V.MEMBER_ID IN ('13998249801','181775806')      --AND V.PAYER = 'CIGNA' AND V.LOB = 'Commercial' 
                ---

            ) 
            PCP 
            --WHERE RN = 1
        ) VIS
    ) X 
    )
) Z 
) A WHERE DOS_NPI_RN = 1  --LOOK AT THIS LOGIC
) B 
) WHERE ENC_RN = 1
and PAYER <> 'EMBLEM' -- APT-6897 07/13/2026 
--and member_id = '771766038' and payer = 'EMPIRE' AND LOB = 'Commercial'
ORDER BY MEMBER_ID, DATE_OF_SERVICE, ENCOUNTER_ID, SOURCE
;
commit;

select /*+ parallel(4) */ count(1) into v_record_count from Y_PATIENT_SEEN_VISITS_DATA_MART;

v_end_time:=sysdate;

UPDATE  Y_TABLE_REFRESH SET 
END_TIME=v_end_time,
RECORD_COUNT=v_record_count,
load_dt=trunc(sysdate),
status = 'Completed'
WHERE TABLE_NAME=v_table_name AND PAYER=v_subpayer  AND START_TIME = v_start_time;
COMMIT;

EXCEPTION
WHEN OTHERS THEN
    v_err:= SQLCODE;
    v_msg:= SUBSTR(SQLERRM, 1, 200);
    INSERT INTO y_table_err_log (TABLE_NAME,PAYER,category,START_TIME,ERROR_TIME,ERROR_CODE,ERROR_MSG,LOAD_DT,REPROCESSED,REPROCESSED_DT) VALUES (v_table_name,v_subpayer,v_category,v_start_time,SYSDATE,v_err,v_msg,TRUNC(SYSDATE),'N',NULL);
    COMMIT;
    UPDATE  y_TABLE_REFRESH SET END_TIME = SYSDATE,status = 'Failed',load_dt=TRUNC(SYSDATE) WHERE TABLE_NAME=v_table_name AND PAYER=v_subpayer  AND START_TIME = v_start_time;
    COMMIT;

END;


BEGIN

v_payer:='ALL';
v_subpayer:='ALL';
v_record_count:=0;
v_start_time:=sysdate;
v_table_name := 'ZC_UM_UNIFIED_MEMBER';

Insert into Y_TABLE_REFRESH(TABLE_NAME,PAYER,CATEGORY,DATE_THROUGH_TYPE,DATE_THROUGH,START_TIME,END_TIME,RECORD_COUNT,RECORD_DIFF,LOAD_DT,status)
            Values(v_table_name,v_subpayer,v_category,'N/A',NULL,v_start_time,NULL,NULL,NULL,NULL,NULL);
COMMIT;    

select 
nvl(case when trunc(sysdate)>=trunc(sysdate,'month') and load_dt < trunc(sysdate,'month') 
    then add_months(min_reporting_dt,1) else min_reporting_dt end, trunc(sysdate,'month')-365) as min_reporting_dt,
nvl(last_day(case when trunc(sysdate)>=trunc(sysdate,'month') and load_dt < trunc(sysdate,'month') 
    then add_months(max_reporting_dt,1) else max_reporting_dt end), last_day(add_months(trunc(sysdate,'month')-365,11))) as max_reporting_dt
into v_rolling_from_dt, v_rolling_to_dt
from 
(
    select /*+ parallel(4) */ distinct min(REPORTING_DATE) min_reporting_dt,  max(REPORTING_DATE) max_reporting_dt,  max(trunc(load_dt)) load_dt
    from ZC_UM_UNIFIED_MEMBER where upper(REPORTING_WINDOW)='ROLLING 12'
);

execute immediate 'truncate table ZC_UM_UNIFIED_MEMBER';

    OPEN cur_uvm_r12;
    LOOP
        FETCH cur_uvm_r12 BULK COLLECT INTO var_uvm_r12 LIMIT 100000;
        EXIT WHEN var_uvm_r12.COUNT=0;

            FORALL i IN 1..var_uvm_r12.COUNT
            INSERT INTO ZC_UM_UNIFIED_MEMBER
            ( REPORTING_YEAR, REPORTING_MONTH, REPORTING_DATE, REPORTING_PERIOD, PAYER, LOB, MEMBER_ID, MRN, PCP_NPI, PCP_PROVIDER, PCP_EMP_STATUS, PCP_SPC, CMS_PCP_SPC, PCP_POD, PCP_PRACTICE, EPIC_STATUS, PROVIDER_ATTRIBUTION_TYPE, MEMBER_MONTHS, REPORTING_WINDOW, CURRENTLY_ATTRIBUTED, PCP_NPI_VISIT, PCP_PRACTICE_VISIT, PCP_POD_VISIT, MT_SINAI_VISIT, COUNT_PCP_NPI_VISITS, COUNT_PCP_PRACTICE_VISITS, COUNT_ANY_PCP_NPI_VISITS, COUNT_ANY_CMS_PCP_NPI_VISITS, UPCOMING_APPOINTMENTS_ROLLING, UPCOMING_APPOINTMENTS_YTD, UPCOMING_APPOINTMENTS_MSSP, LOAD_DT ) 
             VALUES
            ( 
                var_uvm_r12(i).REPORTING_YEAR
                , var_uvm_r12(i).REPORTING_MONTH
                , var_uvm_r12(i).REPORTING_DATE
                , var_uvm_r12(i).REPORTING_PERIOD
                , var_uvm_r12(i).PAYER
                , var_uvm_r12(i).LOB
                , var_uvm_r12(i).MEMBER_ID
                , var_uvm_r12(i).MRN
                , var_uvm_r12(i).PCP_NPI
                , var_uvm_r12(i).PCP_PROVIDER
                , var_uvm_r12(i).PCP_EMP_STATUS
                , var_uvm_r12(i).PCP_SPC
                , var_uvm_r12(i).CMS_PCP_SPC
                , var_uvm_r12(i).PCP_POD
                , var_uvm_r12(i).PCP_PRACTICE
                , var_uvm_r12(i).EPIC_STATUS
                , var_uvm_r12(i).PROVIDER_ATTRIBUTION_TYPE
                , var_uvm_r12(i).MEMBER_MONTHS
                , var_uvm_r12(i).REPORTING_WINDOW
                , var_uvm_r12(i).CURRENTLY_ATTRIBUTED
                , var_uvm_r12(i).PCP_NPI_VISIT
                , var_uvm_r12(i).PCP_PRACTICE_VISIT
                , var_uvm_r12(i).PCP_POD_VISIT
                , var_uvm_r12(i).MT_SINAI_VISIT
                , var_uvm_r12(i).COUNT_PCP_NPI_VISITS
                , var_uvm_r12(i).COUNT_PCP_PRACTICE_VISITS
                , var_uvm_r12(i).COUNT_ANY_PCP_NPI_VISITS
                , var_uvm_r12(i).COUNT_ANY_CMS_PCP_NPI_VISITS
                , var_uvm_r12(i).UPCOMING_APPOINTMENTS_ROLLING
                , var_uvm_r12(i).UPCOMING_APPOINTMENTS_YTD
                , var_uvm_r12(i).UPCOMING_APPOINTMENTS_MSSP
                , var_uvm_r12(i).LOAD_DT
             );
             COMMIT;

    END LOOP;
    CLOSE cur_uvm_r12;

    OPEN cur_uvm_calyr;
    LOOP
        FETCH cur_uvm_calyr BULK COLLECT INTO var_uvm_calyr LIMIT 100000;
        EXIT WHEN var_uvm_calyr.COUNT=0;

            FORALL i IN 1..var_uvm_calyr.COUNT
            INSERT INTO ZC_UM_UNIFIED_MEMBER
            ( REPORTING_YEAR, REPORTING_MONTH, REPORTING_DATE, REPORTING_PERIOD, PAYER, LOB, MEMBER_ID, MRN, PCP_NPI, PCP_PROVIDER, PCP_EMP_STATUS, PCP_SPC, CMS_PCP_SPC, PCP_POD, PCP_PRACTICE, EPIC_STATUS, PROVIDER_ATTRIBUTION_TYPE, MEMBER_MONTHS, REPORTING_WINDOW, CURRENTLY_ATTRIBUTED, PCP_NPI_VISIT, PCP_PRACTICE_VISIT, PCP_POD_VISIT, MT_SINAI_VISIT, COUNT_PCP_NPI_VISITS, COUNT_PCP_PRACTICE_VISITS, COUNT_ANY_PCP_NPI_VISITS, COUNT_ANY_CMS_PCP_NPI_VISITS, UPCOMING_APPOINTMENTS_ROLLING, UPCOMING_APPOINTMENTS_YTD, UPCOMING_APPOINTMENTS_MSSP, LOAD_DT ) 
             VALUES
            ( 
                var_uvm_calyr(i).REPORTING_YEAR
                , var_uvm_calyr(i).REPORTING_MONTH
                , var_uvm_calyr(i).REPORTING_DATE
                , var_uvm_calyr(i).REPORTING_PERIOD
                , var_uvm_calyr(i).PAYER
                , var_uvm_calyr(i).LOB
                , var_uvm_calyr(i).MEMBER_ID
                , var_uvm_calyr(i).MRN
                , var_uvm_calyr(i).PCP_NPI
                , var_uvm_calyr(i).PCP_PROVIDER
                , var_uvm_calyr(i).PCP_EMP_STATUS
                , var_uvm_calyr(i).PCP_SPC
                , var_uvm_calyr(i).CMS_PCP_SPC
                , var_uvm_calyr(i).PCP_POD
                , var_uvm_calyr(i).PCP_PRACTICE
                , var_uvm_calyr(i).EPIC_STATUS
                , var_uvm_calyr(i).PROVIDER_ATTRIBUTION_TYPE
                , var_uvm_calyr(i).MEMBER_MONTHS
                , var_uvm_calyr(i).REPORTING_WINDOW
                , var_uvm_calyr(i).CURRENTLY_ATTRIBUTED
                , var_uvm_calyr(i).PCP_NPI_VISIT
                , var_uvm_calyr(i).PCP_PRACTICE_VISIT
                , var_uvm_calyr(i).PCP_POD_VISIT
                , var_uvm_calyr(i).MT_SINAI_VISIT
                , var_uvm_calyr(i).COUNT_PCP_NPI_VISITS
                , var_uvm_calyr(i).COUNT_PCP_PRACTICE_VISITS
                , var_uvm_calyr(i).COUNT_ANY_PCP_NPI_VISITS
                , var_uvm_calyr(i).COUNT_ANY_CMS_PCP_NPI_VISITS
                , var_uvm_calyr(i).UPCOMING_APPOINTMENTS_ROLLING
                , var_uvm_calyr(i).UPCOMING_APPOINTMENTS_YTD
                , var_uvm_calyr(i).UPCOMING_APPOINTMENTS_MSSP
                , var_uvm_calyr(i).LOAD_DT
             );
             COMMIT;

    END LOOP;
    CLOSE cur_uvm_calyr;
----


    OPEN cur_uvm_mssp;
    LOOP
        FETCH cur_uvm_mssp BULK COLLECT INTO var_uvm_mssp LIMIT 100000;
        EXIT WHEN var_uvm_mssp.COUNT=0;

            FORALL i IN 1..var_uvm_mssp.COUNT
            INSERT INTO ZC_UM_UNIFIED_MEMBER
            ( REPORTING_YEAR, REPORTING_MONTH, REPORTING_DATE, REPORTING_PERIOD, PAYER, LOB, MEMBER_ID, MRN, PCP_NPI, PCP_PROVIDER, PCP_EMP_STATUS, PCP_SPC, CMS_PCP_SPC, PCP_POD, PCP_PRACTICE, EPIC_STATUS, PROVIDER_ATTRIBUTION_TYPE, MEMBER_MONTHS, REPORTING_WINDOW, CURRENTLY_ATTRIBUTED, PCP_NPI_VISIT, PCP_PRACTICE_VISIT, PCP_POD_VISIT, MT_SINAI_VISIT, COUNT_PCP_NPI_VISITS, COUNT_PCP_PRACTICE_VISITS, COUNT_ANY_PCP_NPI_VISITS, COUNT_ANY_CMS_PCP_NPI_VISITS, UPCOMING_APPOINTMENTS_ROLLING, UPCOMING_APPOINTMENTS_YTD, UPCOMING_APPOINTMENTS_MSSP, LOAD_DT ) 
             VALUES
            ( 
                var_uvm_mssp(i).REPORTING_YEAR
                , var_uvm_mssp(i).REPORTING_MONTH
                , var_uvm_mssp(i).REPORTING_DATE
                , var_uvm_mssp(i).REPORTING_PERIOD
                , var_uvm_mssp(i).PAYER
                , var_uvm_mssp(i).LOB
                , var_uvm_mssp(i).MEMBER_ID
                , var_uvm_mssp(i).MRN
                , var_uvm_mssp(i).PCP_NPI
                , var_uvm_mssp(i).PCP_PROVIDER
                , var_uvm_mssp(i).PCP_EMP_STATUS
                , var_uvm_mssp(i).PCP_SPC
                , var_uvm_mssp(i).CMS_PCP_SPC
                , var_uvm_mssp(i).PCP_POD
                , var_uvm_mssp(i).PCP_PRACTICE
                , var_uvm_mssp(i).EPIC_STATUS
                , var_uvm_mssp(i).PROVIDER_ATTRIBUTION_TYPE
                , var_uvm_mssp(i).MEMBER_MONTHS
                , var_uvm_mssp(i).REPORTING_WINDOW
                , var_uvm_mssp(i).CURRENTLY_ATTRIBUTED
                , var_uvm_mssp(i).PCP_NPI_VISIT
                , var_uvm_mssp(i).PCP_PRACTICE_VISIT
                , var_uvm_mssp(i).PCP_POD_VISIT
                , var_uvm_mssp(i).MT_SINAI_VISIT
                , var_uvm_mssp(i).COUNT_PCP_NPI_VISITS
                , var_uvm_mssp(i).COUNT_PCP_PRACTICE_VISITS
                , var_uvm_mssp(i).COUNT_ANY_PCP_NPI_VISITS
                , var_uvm_mssp(i).COUNT_ANY_CMS_PCP_NPI_VISITS
                , var_uvm_mssp(i).UPCOMING_APPOINTMENTS_ROLLING
                , var_uvm_mssp(i).UPCOMING_APPOINTMENTS_YTD
                , var_uvm_mssp(i).UPCOMING_APPOINTMENTS_MSSP
                , var_uvm_mssp(i).LOAD_DT
             );
             COMMIT;

    END LOOP;
    CLOSE cur_uvm_mssp;


delete /*+ parallel(4) */ from ZC_UM_UNIFIED_MEMBER where rowid in 
(
    select rowid row_id from (
    select  /*+ parallel(4) */ a.*,
    row_number() over(partition by REPORTING_MONTH, REPORTING_DATE, REPORTING_PERIOD, REPORTING_WINDOW, PAYER, LOB, MEMBER_ID, nvl(MRN,'M')
    order by PCP_NPI_VISIT desc, PCP_PRACTICE_VISIT desc, PCP_POD_VISIT desc, MT_SINAI_VISIT desc, COUNT_PCP_NPI_VISITS desc, COUNT_PCP_PRACTICE_VISITS desc, COUNT_ANY_PCP_NPI_VISITS desc, COUNT_ANY_CMS_PCP_NPI_VISITS desc, UPCOMING_APPOINTMENTS_ROLLING desc, UPCOMING_APPOINTMENTS_YTD desc, UPCOMING_APPOINTMENTS_MSSP desc) rn
    from ZC_UM_UNIFIED_MEMBER a 
    ) where rn>1 
);

commit;


delete /*+ parallel(4) */ from ZC_UM_UNIFIED_MEMBER where rowid in 
(
    select rowid row_id from (
    select  /*+ parallel(4) */ a.*,
    row_number() over(partition by REPORTING_MONTH, REPORTING_DATE, REPORTING_PERIOD, REPORTING_WINDOW, PAYER, LOB, MEMBER_ID
    order by PCP_NPI_VISIT desc, PCP_PRACTICE_VISIT desc, PCP_POD_VISIT desc, MT_SINAI_VISIT desc, COUNT_PCP_NPI_VISITS desc, COUNT_PCP_PRACTICE_VISITS desc, COUNT_ANY_PCP_NPI_VISITS desc, COUNT_ANY_CMS_PCP_NPI_VISITS desc, UPCOMING_APPOINTMENTS_ROLLING desc, UPCOMING_APPOINTMENTS_YTD desc, UPCOMING_APPOINTMENTS_MSSP desc, MRN desc nulls last) rn
    from ZC_UM_UNIFIED_MEMBER a 
    ) where rn>1 
);

commit;

--COUNT_PCP_NPI_VISITS, COUNT_PCP_PRACTICE_VISITS, COUNT_ANY_PCP_NPI_VISITS, COUNT_ANY_CMS_PCP_NPI_VISITS

select /*+ parallel(4) */ count(1) into v_record_count from ZC_UM_UNIFIED_MEMBER;

v_end_time:=sysdate;

UPDATE  Y_TABLE_REFRESH SET 
END_TIME=v_end_time,
RECORD_COUNT=v_record_count,
load_dt=trunc(sysdate),
status = 'Completed'
WHERE TABLE_NAME=v_table_name AND PAYER=v_subpayer  AND START_TIME = v_start_time;
COMMIT;

EXCEPTION
WHEN OTHERS THEN
    v_err:= SQLCODE;
    v_msg:= SUBSTR(SQLERRM, 1, 200);
    INSERT INTO y_table_err_log (TABLE_NAME,PAYER,category,START_TIME,ERROR_TIME,ERROR_CODE,ERROR_MSG,LOAD_DT,REPROCESSED,REPROCESSED_DT) VALUES (v_table_name,v_subpayer,v_category,v_start_time,SYSDATE,v_err,v_msg,TRUNC(SYSDATE),'N',NULL);
    COMMIT;
    UPDATE  y_TABLE_REFRESH SET END_TIME = SYSDATE,status = 'Failed',load_dt=TRUNC(SYSDATE) WHERE TABLE_NAME=v_table_name AND PAYER=v_subpayer  AND START_TIME = v_start_time;
    COMMIT;

END;

END;

-------

/
