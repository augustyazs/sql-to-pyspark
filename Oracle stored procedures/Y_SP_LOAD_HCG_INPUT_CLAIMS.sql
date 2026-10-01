--------------------------------------------------------
--  File created - Wednesday-September-30-2026   
--------------------------------------------------------
--------------------------------------------------------
--  DDL for Procedure Y_SP_LOAD_HCG_INPUT_CLAIMS
--------------------------------------------------------
set define off;

  CREATE OR REPLACE EDITIONABLE PROCEDURE "POPHEALTH_ANALYTICS_DEV"."Y_SP_LOAD_HCG_INPUT_CLAIMS" 
as
/*************************************************************
--CS-1202 HCG Grouper Version 2019 
--CS-1480 05/06/2021 HCG Grouper 2021 version upgradation 
***************************************************************/

v_payer varchar2(30);
v_partition varchar2(30);
v_record_count NUMBER(20):=0;
v_start_time DATE;
v_end_time DATE;
v_table_name VARCHAR2(100):='Z_HCG_INPUT_CLAIMS';
v_category VARCHAR2(20):='HCG INPUT CLAIMS';
v_err VARCHAR2(100);
v_msg VARCHAR2(4000);
v_lob VARCHAR2(30);
v_subpartition VARCHAR2(30);


cursor cur_payer is
SELECT DISTINCT PAYER,LOB,PARTITION_NAME,SUBPARTITION_NAME
FROM Y_HCG_MILLIMAN_EXTRACT_CONTROL
WHERE IS_CURR_FLG=1
order by payer;

begin

EXECUTE IMMEDIATE 'Alter session disable parallel ddl';
EXECUTE IMMEDIATE 'Alter session disable parallel dml';
EXECUTE IMMEDIATE 'Alter session disable parallel query';

open cur_payer;
loop

  begin
  fetch cur_payer into v_payer,v_lob,v_partition,v_subpartition;
  exit when cur_payer%notfound;


  v_start_time:=sysdate;

  Insert into Y_TABLE_REFRESH(TABLE_NAME,PAYER,CATEGORY,DATE_THROUGH_TYPE,DATE_THROUGH,START_TIME,END_TIME,RECORD_COUNT,LOAD_DT)
  Values(v_table_name,v_payer||'-'||v_lob,v_category,'N/A',null,v_start_time,null,null,null);
  commit;


    if v_payer in ('MSSP','MSSP TRACK ONE PLUS','MSSP NYMP','BRIGHT','HUMANA','CIGNA','1199','UHH','UMR','OSCAR','REACH')
    then
          EXECUTE IMMEDIATE 'ALTER TABLE Z_HCG_INPUT_CLAIMS TRUNCATE PARTITION '|| V_PARTITION;

    Insert into Z_Hcg_Input_Claims
    select 
     ROW_NUMBER() OVER ( partition by S.PAYER,S.LOB order by S.Member_id ,S.CLAIM_ID) SequenceNumber,
     S.PAYER PAYER,
     S.CLAIM_ID ClaimID,
     '' LineNum,
     S.Member_id ContractID,
     S.Member_id MemberID,
     M.DOB,
     CASE WHEN UPPER(M.GENDER) in ('M','MALE') THEN 'M'
          WHEN  UPPER(M.GENDER) in ('F','FEMALE') THEN 'F'
          ELSE NULL END GENDER,
     sd.MIDS FromDate,
     sd.MADS ToDate,
     C.ADMIT_DATE AdmitDate,
     C.DISCHARGE_DATE DischDate ,
     C.PAID_DATE PaidDate ,
      /*CASE WHEN length (C.DRG) <=3 THEN LPAD(DRG,3,'0')
      when LENGTH (C.DRG) >=4 and SUBSTR(DRG,1,1)='0' THEN LPAD(SUBSTR(C.DRG,1,3),3,'0')
      ELSE NULL END DRG ,*/
     CASE WHEN C.DRG is not null then LPAD(C.DRG,4,'0') ELSE C.DRG END DRG,
     case when c.DRG_DESC='DRG - AP' THEN 'AP'
      WHEN c.DRG_DESC='DRG - APR' THEN 'APR'
       WHEN c.DRG_DESC='DRG - MS' THEN 'MS'
       ELSE NULL END DRGVersion,
     case when length(S.REVENUE_CODE) <=4 THEN LPAD(S.REVENUE_CODE,4,0) ELSE NULL END  Revcode,
     s.SERVICE_CODE  HCPCS , --removed substr 09/13
     --case when length(s.CPT_MODIFIER1) <=2 then CPT_MODIFIER1 ELSE NULL END  Modifier, --commented 09/13
     --case when length(s.CPT_MODIFIER2) <=2 then CPT_MODIFIER2 ELSE NULL END Modifier2,  --commented 09/13
     s.CPT_MODIFIER1  Modifier,   --added 09/13
     s.CPT_MODIFIER2  Modifier2,  --added 09/13
     s.PLACE_OF_SERVICE SRCPOS,
     CASE WHEN s.PLACE_OF_SERVICE in ('01','1') THEN '01'
          WHEN s.PLACE_OF_SERVICE in ('02','2') THEN '02'
          WHEN s.PLACE_OF_SERVICE in ('03','3') THEN '03'
          WHEN s.PLACE_OF_SERVICE in ('04','4') THEN '04'
          WHEN s.PLACE_OF_SERVICE in ('05','5') THEN '05'
          WHEN s.PLACE_OF_SERVICE in ('06','6') THEN '06' 
          WHEN s.PLACE_OF_SERVICE in ('07','7') THEN '07' 
          WHEN s.PLACE_OF_SERVICE in ('08','8') THEN '08' 
          WHEN s.PLACE_OF_SERVICE in ('09','9') THEN '09' 
          WHEN s.PLACE_OF_SERVICE in ('11') THEN '11'
          WHEN s.PLACE_OF_SERVICE in ('12') THEN '12'
          WHEN s.PLACE_OF_SERVICE in ('13') THEN '13'
          WHEN s.PLACE_OF_SERVICE in ('14') THEN '14'
          WHEN s.PLACE_OF_SERVICE in ('15') THEN '15'
          WHEN s.PLACE_OF_SERVICE in ('16') THEN '16'
          WHEN s.PLACE_OF_SERVICE in ('17') THEN '17'
          WHEN s.PLACE_OF_SERVICE in ('18') THEN '18'
          WHEN s.PLACE_OF_SERVICE in ('19') THEN '19'
          WHEN s.PLACE_OF_SERVICE in ('20') THEN '20'
          WHEN s.PLACE_OF_SERVICE in ('21') THEN '21'
          WHEN s.PLACE_OF_SERVICE in ('22') THEN '22'
          WHEN s.PLACE_OF_SERVICE in ('23') THEN '23'
          WHEN s.PLACE_OF_SERVICE in ('24') THEN '24'
          WHEN s.PLACE_OF_SERVICE in ('25') THEN '25'
          WHEN s.PLACE_OF_SERVICE in ('26') THEN '26'
          WHEN s.PLACE_OF_SERVICE in ('31') THEN '31'
          WHEN s.PLACE_OF_SERVICE in ('32') THEN '32'
          WHEN s.PLACE_OF_SERVICE in ('33') THEN '33'
          WHEN s.PLACE_OF_SERVICE in ('34') THEN '34'
          WHEN s.PLACE_OF_SERVICE in ('35') THEN '35'
          WHEN s.PLACE_OF_SERVICE in ('41') THEN '41'
          WHEN s.PLACE_OF_SERVICE in ('42') THEN '42'
          WHEN s.PLACE_OF_SERVICE in ('49') THEN '49'
          WHEN s.PLACE_OF_SERVICE in ('50') THEN '50'
          WHEN s.PLACE_OF_SERVICE in ('51') THEN '51'
          WHEN s.PLACE_OF_SERVICE in ('52') THEN '52'
          WHEN s.PLACE_OF_SERVICE in ('53') THEN '53'
          WHEN s.PLACE_OF_SERVICE in ('54') THEN '54'
          WHEN s.PLACE_OF_SERVICE in ('55') THEN '55'
          WHEN s.PLACE_OF_SERVICE in ('56') THEN '56'
          WHEN s.PLACE_OF_SERVICE in ('57') THEN '57'
          WHEN s.PLACE_OF_SERVICE in ('60') THEN '60'
          WHEN s.PLACE_OF_SERVICE in ('61') THEN '61'
          WHEN s.PLACE_OF_SERVICE in ('62') THEN '62'
          WHEN s.PLACE_OF_SERVICE in ('65') THEN '65'
          WHEN s.PLACE_OF_SERVICE in ('71') THEN '71'
          WHEN s.PLACE_OF_SERVICE in ('72') THEN '72'
          WHEN s.PLACE_OF_SERVICE in ('81') THEN '81'
          WHEN s.PLACE_OF_SERVICE in ('99') THEN '99'
     ELSE NULL END POS,
     substr(xp.SPECIALIZATION ,1,28) srcSpecialty,
     xms.Milliman_Specialty  Specialty,
     case when length (s.CAP_CLAIM_IND) <=1 then s.CAP_CLAIM_IND ELSE NULL END  EncounterFlag,
     c.SERVICING_NPI ProviderID,
     substr(xp. ZIP_CODE,1,5) ProviderZIP,
     '' ProviderCounty,
	 c.SERVICING_NPI  RenderingProviderID,
     substr(xp. ZIP_CODE,1,5) RenderingProviderZIP,
     '' RenderingProviderCounty,
     '' MedicareID,
     c.BILL_CODE_UB BillType,
     '' AdmitSource,
     CASE WHEN C.Ip_Admit_Type in ('NEW BORN','NEWBORN')  THEN '4'
          WHEN C.Ip_Admit_Type in ('ELECTIVE')  THEN '3'
          WHEN C.Ip_Admit_Type in ('EMERGENT','EMERGENCY')  THEN '1'
          WHEN C.Ip_Admit_Type in ('INFORMATION NOT AVAILABLE')  THEN '9'
          WHEN C.Ip_Admit_Type in ('URGENT')  THEN '2'
          WHEN C.Ip_Admit_Type in ('TRAUMA CENTER')  THEN '5'
          WHEN C.Ip_Admit_Type in ('RESERVED FOR NATIONAL ASSIGNMENT')  THEN '6'
          ELSE NULL END admittype,
     '0.1' Billed,
     s.ALLOWED_AMOUNT Allowed,
     --s.PAID_AMOUNT Paid, --commented 12-OCT-20 
     case when (s.PAYER like 'MSSP%' or s.payer like 'REACH') and C.CLAIM_TYPE='Facility' and S.rn=1 then C.tcc_paid
      when (s.PAYER like 'MSSP%' or s.payer like 'REACH') and C.CLAIM_TYPE='Facility' and S.rn<>1 then 0
     else s.PAID_AMOUNT END Paid, --added 12-OCT-20
     '' COB,
     '' Copay,
     '' Coinsurance,
     '' Deductible,
     '' PatientPay,
     (c.DISCHARGE_DATE - C.ADMIT_DATE) DAYS,
     s.UNIT_COUNT Units,
     c.DISCHARGE_DISPOSITION DischargeStatus,
     DXPX.CODE_DESC ICDVersion,
     '' AdmitDiag,
     DXPX.D1_D ICDDiag1,
     DXPX.D2_D ICDDiag2,
     DXPX.D3_D  ICDDiag3,
     DXPX.D4_D  ICDDiag4,
     DXPX.D5_D  ICDDiag5,
     DXPX.D6_D  ICDDiag6,
     DXPX.D7_D  ICDDiag7,
     DXPX.D8_D  ICDDiag8,
     DXPX.D9_D  ICDDiag9,
     DXPX.D10_D  ICDDiag10,
     DXPX.D11_D ICDDiag11,
     DXPX.D12_D  ICDDiag12,
     DXPX.D13_D ICDDiag13,
     DXPX.D14_D  ICDDiag14,
     DXPX.D15_D  ICDDiag15,
     DXPX.D16_D  ICDDiag16,
     DXPX.D17_D ICDDiag17,
     DXPX.D18_D  ICDDiag18,
     DXPX.D19_D  ICDDiag19,
     DXPX.D20_D  ICDDiag20,
     DXPX.D21_D  ICDDiag21,
     DXPX.D22_D  ICDDiag22,
     DXPX.D23_D  ICDDiag23,
     DXPX.D24_D  ICDDiag24,
     DXPX.D25_D  ICDDiag25,
     DXPX.D26_D  ICDDiag26,
     DXPX.D27_D  ICDDiag27,
     DXPX.D28_D  ICDDiag28,
     DXPX.D29_D  ICDDiag29,
     DXPX.D30_D ICDDiag30,
     DXPX.D1_P POA1,
     DXPX.D2_P POA2,
     DXPX.D3_P POA3,
     DXPX.D4_P POA4,
     DXPX.D5_P POA5,
     DXPX.D6_P POA6,
     DXPX.D7_P POA7,
     DXPX.D8_P POA8,
     DXPX.D9_P POA9,
     DXPX.D10_P POA10,
     DXPX.D11_P POA11,
     DXPX.D12_P POA12,
     DXPX.D13_P POA13,
     DXPX.D14_P POA14,
     DXPX.D15_P POA15,
     DXPX.D16_P POA16,
     DXPX.D17_P POA17,
     DXPX.D18_P POA18,
     DXPX.D19_P POA19,
     DXPX.D20_P POA20,
     DXPX.D21_P POA21,
     DXPX.D22_P POA22,
     DXPX.D23_P POA23,
     DXPX.D24_P POA24,
     DXPX.D25_P POA25,
     DXPX.D26_P POA26,
     DXPX.D27_P POA27,
     DXPX.D28_P POA28,
     DXPX.D29_P POA29,
     DXPX.D30_P POA30,
     PR.D1_PR ICDProc1,
     PR.D2_PR ICDProc2,
     PR.D3_PR ICDProc3,
     PR.D4_PR ICDProc4,
     PR.D5_PR ICDProc5,
     PR.D6_PR ICDProc6,
     PR.D7_PR ICDProc7,
     PR.D8_PR ICDProc8,
     PR.D9_PR ICDProc9,
     PR.D10_PR ICDProc10,
     PR.D11_PR ICDProc11,
     PR.D12_PR ICDProc12,
     PR.D13_PR ICDProc13,
     PR.D14_PR ICDProc14,
     PR.D15_PR ICDProc15,
     PR.D16_PR ICDProc16,
     PR.D17_PR ICDProc17,
     PR.D18_PR ICDProc18,
     PR.D19_PR ICDProc19,
     PR.D20_PR ICDProc20,
     PR.D21_PR ICDProc21,
     PR.D22_PR ICDProc22,
     PR.D23_PR ICDProc23,
     PR.D24_PR ICDProc24,
     PR.D25_PR ICDProc25,
     PR.D26_PR ICDProc26,
     PR.D27_PR ICDProc27,
     PR.D28_PR ICDProc28,
     PR.D29_PR ICDProc29,
     PR.D30_PR ICDProc30,
     '' RiskPool,
     '' OON,
     CASE WHEN C.PAID_STATUS='1' THEN 'P'
     WHEN C.PAID_STATUS='0' THEN 'D'
     WHEN C.PAID_STATUS='-1' THEN 'R' 
     ELSE 'P' END ClaimLineStatus,
     C.PAID_STATUS CurrentAllowed,
     '' LOINC,
     S.LOB SRCLOB,
      CASE WHEN S.LOB='Commercial' THEN 'COM'
          WHEN S.LOB='MA' THEN 'ADV'
           WHEN S.LOB='Medicare' THEN 'MCR'
           WHEN S.LOB='Medicaid' THEN 'MCD'
      ELSE 'UNK' END LOB,
      P.FACT srcProduct,
      P.FACT product,
      G.FACT GroupID,
      SUBSTR(M.ZIP,1,5) ZIP,
      '' COUNTY,
      '' MemberStatus,
     S.PAYER UserDefPop1,
     '' UserDefPop2,
     '' UserDefPop3,
     '' UserDefNum1,
     '' UserDefNum2,
     '' UserDefNum3,
     trunc(sysdate) load_Date
    from 
        ( select /* + parallel(fs,8) */
         fs.* ,
         row_number() over (
                   partition by payer,lob,member_id,claim_id 
                   order by --lpad(revenue_code,4,0) desc nulls last
        		   lpad(revenue_code,4,0) desc nulls last,
                   SERVICE_CODE desc nulls last, 
                    CPT_MODIFIER1 desc nulls last,
                    CPT_MODIFIER2 desc nulls last,
                    ALLOWED_AMOUNT desc nulls last, PAID_AMOUNT desc nulls last, UNIT_COUNT desc nulls last, 
                    PLACE_OF_SERVICE desc nulls last, CAP_CLAIM_IND desc nulls last
                   ) rn
         from X_FACT_SERVICE fs
         where PAYER=v_payer and LOB=v_lob and member_id <>'00000000000000000000'
        ) S
    left join
       (
        select  /* + parallel(XC_UM_CLAIM_HEADER,8) */ *
        from XC_UM_CLAIM_HEADER where PAYER=v_payer and LOB=v_lob and member_id <>'00000000000000000000'
        --where (DRG_DESC ='DRG - MS' or DRG_DESC is null ) 
       ) C
      on C.payer=s.payer
      and C.lob=s.lob
      and C.member_id=s.member_id
      and c.claim_id=s.claim_id
    left join 
       (select /* + parallel(X_MEMBER,8) */ * from X_MEMBER where payer=v_payer and lob=v_lob) M
      on s.payer=M.payer
      and s.lob=M.lob
      and s.member_id=M.member_id
    left join 
       (
        select /* + parallel(X_FACT_SERVICE,8) */
        PAYER,LOB,MEMBER_ID,Claim_id,MIN(SERVICE_DT) MIDS ,MAX(SERVICE_DT) MADS 
        from X_FACT_SERVICE where PAYER=v_payer AND LOB=v_lob group by PAYER,LOB,MEMBER_ID,Claim_id
       ) SD
      on s.payer=sd.payer
      and s.lob=sd.lob
      and s.member_id=sd.member_id
      and s.claim_id=sd.claim_id
    left join 
    --X_PROVIDER XP
       (
       select NPI,ZIP_CODE,taxonomy_code,primary_specialty,specialization,pcp_spc
         from
         (
         select distinct tax_npi.npi,tax_npi.PROV_BUS_MAIL_ADDR_POSTAL_CD as ZIP_CODE ,tax_npi.HC_PROV_TAXON_CD taxonomy_code,tax_xwalk.classification as primary_specialty,specialization,pcp_spc,
         row_number() over(partition by tax_npi.npi order by case when HC_PROV_PRIM_TAXON_SWITCH='Y' then 1 else 0 end desc,ind asc) rn
         from
         (select NPI,PROV_BUS_MAIL_ADDR_POSTAL_CD,HC_PROV_TAXON_CD,HC_PROV_PRIM_TAXON_SWITCH,ind from 
         (select /*+ parallel(8) */ npi, PROV_BUS_MAIL_ADDR_POSTAL_CD,
         HC_PROV_TAXON_CD_1,
         HC_PROV_TAXON_CD_2,
         HC_PROV_TAXON_CD_3,
         HC_PROV_TAXON_CD_4,
         HC_PROV_TAXON_CD_5,
         HC_PROV_TAXON_CD_6,
         HC_PROV_TAXON_CD_7,
         HC_PROV_TAXON_CD_8,
         HC_PROV_TAXON_CD_9,
         HC_PROV_TAXON_CD_10,
         HC_PROV_TAXON_CD_11,
         HC_PROV_TAXON_CD_12,
         HC_PROV_TAXON_CD_13,
         HC_PROV_TAXON_CD_14,
         HC_PROV_TAXON_CD_15,
         HC_PROV_PRIM_TAXON_SWITCH_1,
         HC_PROV_PRIM_TAXON_SWITCH_2,
         HC_PROV_PRIM_TAXON_SWITCH_3,
         HC_PROV_PRIM_TAXON_SWITCH_4,
         HC_PROV_PRIM_TAXON_SWITCH_5,
         HC_PROV_PRIM_TAXON_SWITCH_6,
         HC_PROV_PRIM_TAXON_SWITCH_7,
         HC_PROV_PRIM_TAXON_SWITCH_8,
         HC_PROV_PRIM_TAXON_SWITCH_9,
         HC_PROV_PRIM_TAXON_SWITCH_10,
         HC_PROV_PRIM_TAXON_SWITCH_11,
         HC_PROV_PRIM_TAXON_SWITCH_12,
         HC_PROV_PRIM_TAXON_SWITCH_13,
         HC_PROV_PRIM_TAXON_SWITCH_14,
         HC_PROV_PRIM_TAXON_SWITCH_15
          from XREF_PROVIDER_NPPES_RAW)
         unpivot
         (
          (HC_PROV_TAXON_CD,HC_PROV_PRIM_TAXON_SWITCH) for ind in
          (
           (HC_PROV_TAXON_CD_1,HC_PROV_PRIM_TAXON_SWITCH_1) as '1',
           (HC_PROV_TAXON_CD_2,HC_PROV_PRIM_TAXON_SWITCH_2) as '2',
           (HC_PROV_TAXON_CD_3,HC_PROV_PRIM_TAXON_SWITCH_3) as '3',
           (HC_PROV_TAXON_CD_4,HC_PROV_PRIM_TAXON_SWITCH_4) as '4',
           (HC_PROV_TAXON_CD_5,HC_PROV_PRIM_TAXON_SWITCH_5) as '5',
           (HC_PROV_TAXON_CD_6,HC_PROV_PRIM_TAXON_SWITCH_6) as '6',
           (HC_PROV_TAXON_CD_7,HC_PROV_PRIM_TAXON_SWITCH_7) as '7',
           (HC_PROV_TAXON_CD_8,HC_PROV_PRIM_TAXON_SWITCH_8) as '8',
           (HC_PROV_TAXON_CD_9,HC_PROV_PRIM_TAXON_SWITCH_9) as '9',
           (HC_PROV_TAXON_CD_10,HC_PROV_PRIM_TAXON_SWITCH_10) as '10',
           (HC_PROV_TAXON_CD_11,HC_PROV_PRIM_TAXON_SWITCH_11) as '11',
           (HC_PROV_TAXON_CD_12,HC_PROV_PRIM_TAXON_SWITCH_12) as '12',
           (HC_PROV_TAXON_CD_13,HC_PROV_PRIM_TAXON_SWITCH_13) as '13',
           (HC_PROV_TAXON_CD_14,HC_PROV_PRIM_TAXON_SWITCH_14) as '14',
           (HC_PROV_TAXON_CD_15,HC_PROV_PRIM_TAXON_SWITCH_15) as '15'
          )
         )
         where HC_PROV_TAXON_CD is not null) tax_npi
         left outer join
         XREF_TAXONOMY_XWALK tax_xwalk
         on tax_npi.HC_PROV_TAXON_CD=tax_xwalk.CODE
         )
         where rn=1
       ) XP   --added on 31-AUG-2020
      on c.SERVICING_NPI=xp.npi
    left join
      --XREF_MILLIMAN_SPECIALIZATION XMS
	  YREF_MILLIMAN_TAX_SPEC_XWALK XMS   --2021 code sets
       on Xp.Taxonomy_Code=xms.Taxonomy_Code
    left join 
       (
        select * from 
           (
              select /* + parallel(X_Fact_Dxpx,8) */ distinct PAYER,LOB,MEMBER_ID,CLAIM_ID,
                MAX(CASE WHEN CODE_DESC ='DXICD9' THEN '09'
                WHEN CODE_DESC ='DXICD10' THEN '10' ELSE NULL END ) CODE_DESC,
                CODE ,
                POA ,
                --ROW_NUMBER() over ( PARTITION by PAYER,LOB,MEMBER_ID,CLAIM_ID order by PRMRY_IND ) RN
                To_NUMBER(MIN(PRMRY_IND)) PRMRY_IND
              from X_Fact_Dxpx
                where PAYER=v_payer and LOB=v_lob --and CLAIM_ID='0107291691088' --'0107291691088'--'0104171814137' --'0205091611636'
                and CODE_DESC like 'DX%'
                group by PAYER,LOB,MEMBER_ID,CLAIM_ID,CODE,POA
                order by PAYER,LOB,MEMBER_ID,CLAIM_ID,PRMRY_IND
           ) 
           PIVOT  (MAX(CODE) D,MAX(POA) P for PRMRY_IND in ( '1' D1 ,'2' D2,'3' D3,'4' D4,'5' D5,'6' D6,7 D7,8 D8,9 D9,10 D10,
                                      '11' D11 ,'12' D12,'13' D13,'14' D14,'15' D15,'16' D16,17 D17,18 D18,19 D19,20 D20,
                                      '21' D21 ,'22' D22,'23' D23,'24' D24,'25' D25,'26' D26,27 D27,28 D28,29 D29,30 D30))
        ) DXPX
      on S.PAYER=DXPX.PAYER
      and S.LOB=DXPX.LOB
      AND S.MEMBER_ID=DXPX.MEMBER_ID
      and S.claim_id=DXPX.CLAIM_ID
    LEFT JOIN
       (
        select * from 
           (
            select /* + parallel(X_Fact_Dxpx,8) */ distinct PAYER,LOB,MEMBER_ID,CLAIM_ID,
              --MAX(CASE WHEN CODE_DESC ='DXICD9' THEN '09'
              --WHEN CODE_DESC ='DXICD10' THEN '10' ELSE NULL END ) CODE_DESC,
              CODE ,
              PRMRY_IND
            from X_Fact_Dxpx
              where PAYER=v_payer and LOB=v_lob --and CLAIM_ID='0104171814137' 
              and CODE_DESC like 'PX%'
              --group by PAYER,LOB,MEMBER_ID,CLAIM_ID,CODE
              order by PAYER,LOB,MEMBER_ID,CLAIM_ID,PRMRY_IND
           ) 
           PIVOT  (MAX(CODE) PR for PRMRY_IND in ( '1' D1 ,'2' D2,'3' D3,'4' D4,'5' D5,'6' D6,7 D7,8 D8,9 D9,10 D10,
                                      '11' D11 ,'12' D12,'13' D13,'14' D14,'15' D15,'16' D16,17 D17,18 D18,19 D19,20 D20,
                                      '21' D21 ,'22' D22,'23' D23,'24' D24,'25' D25,'26' D26,27 D27,28 D28,29 D29,30 D30))
        ) PR
      ON S.PAYER=PR.PAYER
       and S.LOB=PR.LOB
       AND S.MEMBER_ID=PR.MEMBER_ID
       and S.claim_id=PR.CLAIM_ID
    left join 
       (
	    select /* + PARALLEL(X_FACT_MEMBER,4) */ distinct payer,lob,member_id,FACT 
         from X_FACT_MEMBER
         where FACT_CATEGORY='Member Coverage' 
           and FACT_SHORTDESCR='Product'
           and PAYER=v_payer
           and LOB=v_lob
		) P
     on S.payer=P.payer
      and S.lob=P.lob
      and S.member_id=P.member_id
    left join 
       (
        select /* + PARALLEL(X_FACT_MEMBER,4) */ distinct payer,lob,member_id,FACT 
        from X_FACT_MEMBER
        where FACT_CATEGORY='Group Identifiers' 
         and FACT_SHORTDESCR='Group Number'
         and PAYER=v_payer
         and LOB=v_lob
       ) G
    on S.payer=G.payer
      and S.lob=G.lob
      and S.member_id=G.member_id
    where S.PAYER=v_payer and S.LOB=v_lob
    --and S.member_id='UY86308P'
    --and s.CLAIM_ID='0109161449259'
    ;
     v_record_count:=sql%ROWCOUNT;


 elsif v_payer in ('HNACO')
    then
          EXECUTE IMMEDIATE 'ALTER TABLE Z_HCG_INPUT_CLAIMS TRUNCATE PARTITION '|| V_PARTITION;

    Insert into Z_Hcg_Input_Claims
    select
     ROW_NUMBER() OVER ( partition by S.PAYER,S.LOB order by S.Member_id ,S.CLAIM_ID) SequenceNumber,
     S.PAYER PAYER,
     S.CLAIM_ID ClaimID,
     '' LineNum,
     S.Member_id ContractID,
     S.Member_id MemberID,
     M.DOB,
     CASE WHEN UPPER(M.GENDER) in ('M','MALE') THEN 'M'
          WHEN  UPPER(M.GENDER) in ('F','FEMALE') THEN 'F'
          ELSE NULL END GENDER,
     sd.MIDS FromDate,
     sd.MADS ToDate,
     C.ADMIT_DATE AdmitDate,
     C.DISCHARGE_DATE DischDate ,
     C.PAID_DATE PaidDate ,
      /*CASE WHEN length (C.DRG) <=3 THEN LPAD(DRG,3,'0')
      when LENGTH (C.DRG) >=4 and SUBSTR(DRG,1,1)='0' THEN LPAD(SUBSTR(C.DRG,1,3),3,'0')
      ELSE NULL END DRG ,*/
     CASE WHEN C.DRG is not null then LPAD(C.DRG,4,'0') ELSE C.DRG END DRG,
     case when c.DRG_DESC='DRG - AP' THEN 'AP'
      WHEN c.DRG_DESC='DRG - APR' THEN 'APR'
       WHEN c.DRG_DESC='DRG - MS' THEN 'MS'
       ELSE NULL END DRGVersion,
     case when length(S.REVENUE_CODE) <=4 THEN LPAD(S.REVENUE_CODE,4,0) ELSE NULL END  Revcode,
     s.SERVICE_CODE  HCPCS , --removed substr 09/13
     --case when length(s.CPT_MODIFIER1) <=2 then CPT_MODIFIER1 ELSE NULL END  Modifier, --commented 09/13
     --case when length(s.CPT_MODIFIER2) <=2 then CPT_MODIFIER2 ELSE NULL END Modifier2,  --commented 09/13
     s.CPT_MODIFIER1  Modifier,   --added 09/13
     s.CPT_MODIFIER2  Modifier2,  --added 09/13
     s.PLACE_OF_SERVICE SRCPOS,
     CASE WHEN s.PLACE_OF_SERVICE in ('01','1') THEN '01'
          WHEN s.PLACE_OF_SERVICE in ('02','2') THEN '02'
          WHEN s.PLACE_OF_SERVICE in ('03','3') THEN '03'
          WHEN s.PLACE_OF_SERVICE in ('04','4') THEN '04'
          WHEN s.PLACE_OF_SERVICE in ('05','5') THEN '05'
          WHEN s.PLACE_OF_SERVICE in ('06','6') THEN '06' 
          WHEN s.PLACE_OF_SERVICE in ('07','7') THEN '07' 
          WHEN s.PLACE_OF_SERVICE in ('08','8') THEN '08' 
          WHEN s.PLACE_OF_SERVICE in ('09','9') THEN '09' 
          WHEN s.PLACE_OF_SERVICE in ('11') THEN '11'
          WHEN s.PLACE_OF_SERVICE in ('12') THEN '12'
          WHEN s.PLACE_OF_SERVICE in ('13') THEN '13'
          WHEN s.PLACE_OF_SERVICE in ('14') THEN '14'
          WHEN s.PLACE_OF_SERVICE in ('15') THEN '15'
          WHEN s.PLACE_OF_SERVICE in ('16') THEN '16'
          WHEN s.PLACE_OF_SERVICE in ('17') THEN '17'
          WHEN s.PLACE_OF_SERVICE in ('18') THEN '18'
          WHEN s.PLACE_OF_SERVICE in ('19') THEN '19'
          WHEN s.PLACE_OF_SERVICE in ('20') THEN '20'
          WHEN s.PLACE_OF_SERVICE in ('21') THEN '21'
          WHEN s.PLACE_OF_SERVICE in ('22') THEN '22'
          WHEN s.PLACE_OF_SERVICE in ('23') THEN '23'
          WHEN s.PLACE_OF_SERVICE in ('24') THEN '24'
          WHEN s.PLACE_OF_SERVICE in ('25') THEN '25'
          WHEN s.PLACE_OF_SERVICE in ('26') THEN '26'
          WHEN s.PLACE_OF_SERVICE in ('31') THEN '31'
          WHEN s.PLACE_OF_SERVICE in ('32') THEN '32'
          WHEN s.PLACE_OF_SERVICE in ('33') THEN '33'
          WHEN s.PLACE_OF_SERVICE in ('34') THEN '34'
          WHEN s.PLACE_OF_SERVICE in ('35') THEN '35'
          WHEN s.PLACE_OF_SERVICE in ('41') THEN '41'
          WHEN s.PLACE_OF_SERVICE in ('42') THEN '42'
          WHEN s.PLACE_OF_SERVICE in ('49') THEN '49'
          WHEN s.PLACE_OF_SERVICE in ('50') THEN '50'
          WHEN s.PLACE_OF_SERVICE in ('51') THEN '51'
          WHEN s.PLACE_OF_SERVICE in ('52') THEN '52'
          WHEN s.PLACE_OF_SERVICE in ('53') THEN '53'
          WHEN s.PLACE_OF_SERVICE in ('54') THEN '54'
          WHEN s.PLACE_OF_SERVICE in ('55') THEN '55'
          WHEN s.PLACE_OF_SERVICE in ('56') THEN '56'
          WHEN s.PLACE_OF_SERVICE in ('57') THEN '57'
          WHEN s.PLACE_OF_SERVICE in ('60') THEN '60'
          WHEN s.PLACE_OF_SERVICE in ('61') THEN '61'
          WHEN s.PLACE_OF_SERVICE in ('62') THEN '62'
          WHEN s.PLACE_OF_SERVICE in ('65') THEN '65'
          WHEN s.PLACE_OF_SERVICE in ('71') THEN '71'
          WHEN s.PLACE_OF_SERVICE in ('72') THEN '72'
          WHEN s.PLACE_OF_SERVICE in ('81') THEN '81'
          WHEN s.PLACE_OF_SERVICE in ('99') THEN '99'
     ELSE NULL END POS,
     substr(xp.SPECIALIZATION ,1,28) srcSpecialty,
     xms.Milliman_Specialty  Specialty,
     case when length (s.CAP_CLAIM_IND) <=1 then s.CAP_CLAIM_IND ELSE NULL END  EncounterFlag,
     c.SERVICING_NPI ProviderID,
     substr(xp. ZIP_CODE,1,5) ProviderZIP,
     '' ProviderCounty,
	 c.SERVICING_NPI  RenderingProviderID,
     substr(xp. ZIP_CODE,1,5) RenderingProviderZIP,
     '' RenderingProviderCounty,
     '' MedicareID,
     c.BILL_CODE_UB BillType,
     '' AdmitSource,
     CASE WHEN C.Ip_Admit_Type in ('NEW BORN','NEWBORN')  THEN '4'
          WHEN C.Ip_Admit_Type in ('ELECTIVE')  THEN '3'
          WHEN C.Ip_Admit_Type in ('EMERGENT','EMERGENCY')  THEN '1'
          WHEN C.Ip_Admit_Type in ('INFORMATION NOT AVAILABLE')  THEN '9'
          WHEN C.Ip_Admit_Type in ('URGENT')  THEN '2'
          WHEN C.Ip_Admit_Type in ('TRAUMA CENTER')  THEN '5'
          WHEN C.Ip_Admit_Type in ('RESERVED FOR NATIONAL ASSIGNMENT')  THEN '6'
          ELSE NULL END admittype,
     '0.1' Billed,
     s.ALLOWED_AMOUNT Allowed,
     --s.PAID_AMOUNT Paid, --commented 12-OCT-20 
     case when ( s.payer like 'HNACO') and C.CLAIM_TYPE='Facility' and S.rn=1 then C.tcc_paid
      when ( s.payer like 'HNACO') and C.CLAIM_TYPE='Facility' and S.rn<>1 then 0
     else s.PAID_AMOUNT END Paid, --added 12-OCT-20
     '' COB,
     '' Copay,
     '' Coinsurance,
     '' Deductible,
     '' PatientPay,
     (c.DISCHARGE_DATE - C.ADMIT_DATE) DAYS,
     s.UNIT_COUNT Units,
     c.DISCHARGE_DISPOSITION DischargeStatus,
     DXPX.CODE_DESC ICDVersion,
     '' AdmitDiag,
     DXPX.D1_D ICDDiag1,
     DXPX.D2_D ICDDiag2,
     DXPX.D3_D  ICDDiag3,
     DXPX.D4_D  ICDDiag4,
     DXPX.D5_D  ICDDiag5,
     DXPX.D6_D  ICDDiag6,
     DXPX.D7_D  ICDDiag7,
     DXPX.D8_D  ICDDiag8,
     DXPX.D9_D  ICDDiag9,
     DXPX.D10_D  ICDDiag10,
     DXPX.D11_D ICDDiag11,
     DXPX.D12_D  ICDDiag12,
     DXPX.D13_D ICDDiag13,
     DXPX.D14_D  ICDDiag14,
     DXPX.D15_D  ICDDiag15,
     DXPX.D16_D  ICDDiag16,
     DXPX.D17_D ICDDiag17,
     DXPX.D18_D  ICDDiag18,
     DXPX.D19_D  ICDDiag19,
     DXPX.D20_D  ICDDiag20,
     DXPX.D21_D  ICDDiag21,
     DXPX.D22_D  ICDDiag22,
     DXPX.D23_D  ICDDiag23,
     DXPX.D24_D  ICDDiag24,
     DXPX.D25_D  ICDDiag25,
     DXPX.D26_D  ICDDiag26,
     DXPX.D27_D  ICDDiag27,
     DXPX.D28_D  ICDDiag28,
     DXPX.D29_D  ICDDiag29,
     DXPX.D30_D ICDDiag30,
     DXPX.D1_P POA1,
     DXPX.D2_P POA2,
     DXPX.D3_P POA3,
     DXPX.D4_P POA4,
     DXPX.D5_P POA5,
     DXPX.D6_P POA6,
     DXPX.D7_P POA7,
     DXPX.D8_P POA8,
     DXPX.D9_P POA9,
     DXPX.D10_P POA10,
     DXPX.D11_P POA11,
     DXPX.D12_P POA12,
     DXPX.D13_P POA13,
     DXPX.D14_P POA14,
     DXPX.D15_P POA15,
     DXPX.D16_P POA16,
     DXPX.D17_P POA17,
     DXPX.D18_P POA18,
     DXPX.D19_P POA19,
     DXPX.D20_P POA20,
     DXPX.D21_P POA21,
     DXPX.D22_P POA22,
     DXPX.D23_P POA23,
     DXPX.D24_P POA24,
     DXPX.D25_P POA25,
     DXPX.D26_P POA26,
     DXPX.D27_P POA27,
     DXPX.D28_P POA28,
     DXPX.D29_P POA29,
     DXPX.D30_P POA30,
     PR.D1_PR ICDProc1,
     PR.D2_PR ICDProc2,
     PR.D3_PR ICDProc3,
     PR.D4_PR ICDProc4,
     PR.D5_PR ICDProc5,
     PR.D6_PR ICDProc6,
     PR.D7_PR ICDProc7,
     PR.D8_PR ICDProc8,
     PR.D9_PR ICDProc9,
     PR.D10_PR ICDProc10,
     PR.D11_PR ICDProc11,
     PR.D12_PR ICDProc12,
     PR.D13_PR ICDProc13,
     PR.D14_PR ICDProc14,
     PR.D15_PR ICDProc15,
     PR.D16_PR ICDProc16,
     PR.D17_PR ICDProc17,
     PR.D18_PR ICDProc18,
     PR.D19_PR ICDProc19,
     PR.D20_PR ICDProc20,
     PR.D21_PR ICDProc21,
     PR.D22_PR ICDProc22,
     PR.D23_PR ICDProc23,
     PR.D24_PR ICDProc24,
     PR.D25_PR ICDProc25,
     PR.D26_PR ICDProc26,
     PR.D27_PR ICDProc27,
     PR.D28_PR ICDProc28,
     PR.D29_PR ICDProc29,
     PR.D30_PR ICDProc30,
     '' RiskPool,
     '' OON,
     CASE WHEN C.PAID_STATUS='1' THEN 'P'
     WHEN C.PAID_STATUS='0' THEN 'D'
     WHEN C.PAID_STATUS='-1' THEN 'R' 
     ELSE 'P' END ClaimLineStatus,
     C.PAID_STATUS CurrentAllowed,
     '' LOINC,
     S.LOB SRCLOB,
      CASE WHEN S.LOB='Commercial' THEN 'COM'
          WHEN S.LOB='MA' THEN 'ADV'
           WHEN S.LOB='Medicare' THEN 'MCR'
           WHEN S.LOB='Medicaid' THEN 'MCD'
      ELSE 'UNK' END LOB,
      P.FACT srcProduct,
      P.FACT product,
      G.FACT GroupID,
      SUBSTR(M.ZIP,1,5) ZIP,
      '' COUNTY,
      '' MemberStatus,
     S.PAYER UserDefPop1,
     '' UserDefPop2,
     '' UserDefPop3,
     '' UserDefNum1,
     '' UserDefNum2,
     '' UserDefNum3,
     trunc(sysdate) load_Date
    from 
        ( select /* + parallel(fs,8) */
         fs.* ,
         row_number() over (
                   partition by payer,lob,member_id,claim_id 
                   order by --lpad(revenue_code,4,0) desc nulls last
        		   lpad(revenue_code,4,0) desc nulls last,
                   SERVICE_CODE desc nulls last, 
                    CPT_MODIFIER1 desc nulls last,
                    CPT_MODIFIER2 desc nulls last,
                    ALLOWED_AMOUNT desc nulls last, PAID_AMOUNT desc nulls last, UNIT_COUNT desc nulls last, 
                    PLACE_OF_SERVICE desc nulls last, CAP_CLAIM_IND desc nulls last
                   ) rn
         from Y_FACT_SERVICE fs
         where PAYER=v_payer and LOB=v_lob and member_id <>'00000000000000000000'
        ) S
    left join
       (
        select  /* + parallel(YC_UM_CLAIM_HEADER,8) */ *
        from YC_UM_CLAIM_HEADER where PAYER=v_payer and LOB=v_lob and member_id <>'00000000000000000000'
        --where (DRG_DESC ='DRG - MS' or DRG_DESC is null ) 
       ) C
      on C.payer=s.payer
      and C.lob=s.lob
      and C.member_id=s.member_id
      and c.claim_id=s.claim_id
    left join 
       (select /* + parallel(Y_MEMBER,8) */ * from Y_MEMBER where payer=v_payer and lob=v_lob) M
      on s.payer=M.payer
      and s.lob=M.lob
      and s.member_id=M.member_id
    left join 
       (
        select /* + parallel(Y_FACT_SERVICE,8) */
        PAYER,LOB,MEMBER_ID,Claim_id,MIN(SERVICE_DT) MIDS ,MAX(SERVICE_DT) MADS 
        from y_FACT_SERVICE where PAYER=v_payer AND LOB=v_lob group by PAYER,LOB,MEMBER_ID,Claim_id
       ) SD
      on s.payer=sd.payer
      and s.lob=sd.lob
      and s.member_id=sd.member_id
      and s.claim_id=sd.claim_id
    left join 
    --X_PROVIDER XP
       (
       select NPI,ZIP_CODE,taxonomy_code,primary_specialty,specialization,pcp_spc
         from
         (
         select distinct tax_npi.npi,tax_npi.PROV_BUS_MAIL_ADDR_POSTAL_CD as ZIP_CODE ,tax_npi.HC_PROV_TAXON_CD taxonomy_code,tax_xwalk.classification as primary_specialty,specialization,pcp_spc,
         row_number() over(partition by tax_npi.npi order by case when HC_PROV_PRIM_TAXON_SWITCH='Y' then 1 else 0 end desc,ind asc) rn
         from
         (select NPI,PROV_BUS_MAIL_ADDR_POSTAL_CD,HC_PROV_TAXON_CD,HC_PROV_PRIM_TAXON_SWITCH,ind from 
         (select /*+ parallel(8) */ npi, PROV_BUS_MAIL_ADDR_POSTAL_CD,
         HC_PROV_TAXON_CD_1,
         HC_PROV_TAXON_CD_2,
         HC_PROV_TAXON_CD_3,
         HC_PROV_TAXON_CD_4,
         HC_PROV_TAXON_CD_5,
         HC_PROV_TAXON_CD_6,
         HC_PROV_TAXON_CD_7,
         HC_PROV_TAXON_CD_8,
         HC_PROV_TAXON_CD_9,
         HC_PROV_TAXON_CD_10,
         HC_PROV_TAXON_CD_11,
         HC_PROV_TAXON_CD_12,
         HC_PROV_TAXON_CD_13,
         HC_PROV_TAXON_CD_14,
         HC_PROV_TAXON_CD_15,
         HC_PROV_PRIM_TAXON_SWITCH_1,
         HC_PROV_PRIM_TAXON_SWITCH_2,
         HC_PROV_PRIM_TAXON_SWITCH_3,
         HC_PROV_PRIM_TAXON_SWITCH_4,
         HC_PROV_PRIM_TAXON_SWITCH_5,
         HC_PROV_PRIM_TAXON_SWITCH_6,
         HC_PROV_PRIM_TAXON_SWITCH_7,
         HC_PROV_PRIM_TAXON_SWITCH_8,
         HC_PROV_PRIM_TAXON_SWITCH_9,
         HC_PROV_PRIM_TAXON_SWITCH_10,
         HC_PROV_PRIM_TAXON_SWITCH_11,
         HC_PROV_PRIM_TAXON_SWITCH_12,
         HC_PROV_PRIM_TAXON_SWITCH_13,
         HC_PROV_PRIM_TAXON_SWITCH_14,
         HC_PROV_PRIM_TAXON_SWITCH_15
          from XREF_PROVIDER_NPPES_RAW)
         unpivot
         (
          (HC_PROV_TAXON_CD,HC_PROV_PRIM_TAXON_SWITCH) for ind in
          (
           (HC_PROV_TAXON_CD_1,HC_PROV_PRIM_TAXON_SWITCH_1) as '1',
           (HC_PROV_TAXON_CD_2,HC_PROV_PRIM_TAXON_SWITCH_2) as '2',
           (HC_PROV_TAXON_CD_3,HC_PROV_PRIM_TAXON_SWITCH_3) as '3',
           (HC_PROV_TAXON_CD_4,HC_PROV_PRIM_TAXON_SWITCH_4) as '4',
           (HC_PROV_TAXON_CD_5,HC_PROV_PRIM_TAXON_SWITCH_5) as '5',
           (HC_PROV_TAXON_CD_6,HC_PROV_PRIM_TAXON_SWITCH_6) as '6',
           (HC_PROV_TAXON_CD_7,HC_PROV_PRIM_TAXON_SWITCH_7) as '7',
           (HC_PROV_TAXON_CD_8,HC_PROV_PRIM_TAXON_SWITCH_8) as '8',
           (HC_PROV_TAXON_CD_9,HC_PROV_PRIM_TAXON_SWITCH_9) as '9',
           (HC_PROV_TAXON_CD_10,HC_PROV_PRIM_TAXON_SWITCH_10) as '10',
           (HC_PROV_TAXON_CD_11,HC_PROV_PRIM_TAXON_SWITCH_11) as '11',
           (HC_PROV_TAXON_CD_12,HC_PROV_PRIM_TAXON_SWITCH_12) as '12',
           (HC_PROV_TAXON_CD_13,HC_PROV_PRIM_TAXON_SWITCH_13) as '13',
           (HC_PROV_TAXON_CD_14,HC_PROV_PRIM_TAXON_SWITCH_14) as '14',
           (HC_PROV_TAXON_CD_15,HC_PROV_PRIM_TAXON_SWITCH_15) as '15'
          )
         )
         where HC_PROV_TAXON_CD is not null) tax_npi
         left outer join
         XREF_TAXONOMY_XWALK tax_xwalk
         on tax_npi.HC_PROV_TAXON_CD=tax_xwalk.CODE
         )
         where rn=1
       ) XP   --added on 31-AUG-2020
      on c.SERVICING_NPI=xp.npi
    left join
      --XREF_MILLIMAN_SPECIALIZATION XMS
	  YREF_MILLIMAN_TAX_SPEC_XWALK XMS   --2021 code sets
       on Xp.Taxonomy_Code=xms.Taxonomy_Code
    left join 
       (
        select * from 
           (
              select /* + parallel(Y_Fact_Dxpx,8) */ distinct PAYER,LOB,MEMBER_ID,CLAIM_ID,
                MAX(CASE WHEN CODE_DESC ='DXICD9' THEN '09'
                WHEN CODE_DESC ='DXICD10' THEN '10' ELSE NULL END ) CODE_DESC,
                CODE ,
                POA ,
                --ROW_NUMBER() over ( PARTITION by PAYER,LOB,MEMBER_ID,CLAIM_ID order by PRMRY_IND ) RN
                To_NUMBER(MIN(PRMRY_IND)) PRMRY_IND
              from y_Fact_Dxpx
                where PAYER=v_payer and LOB=v_lob --and CLAIM_ID='0107291691088' --'0107291691088'--'0104171814137' --'0205091611636'
                and CODE_DESC like 'DX%'
                group by PAYER,LOB,MEMBER_ID,CLAIM_ID,CODE,POA
                order by PAYER,LOB,MEMBER_ID,CLAIM_ID,PRMRY_IND
           ) 
           PIVOT  (MAX(CODE) D,MAX(POA) P for PRMRY_IND in ( '1' D1 ,'2' D2,'3' D3,'4' D4,'5' D5,'6' D6,7 D7,8 D8,9 D9,10 D10,
                                      '11' D11 ,'12' D12,'13' D13,'14' D14,'15' D15,'16' D16,17 D17,18 D18,19 D19,20 D20,
                                      '21' D21 ,'22' D22,'23' D23,'24' D24,'25' D25,'26' D26,27 D27,28 D28,29 D29,30 D30))
        ) DXPX
      on S.PAYER=DXPX.PAYER
      and S.LOB=DXPX.LOB
      AND S.MEMBER_ID=DXPX.MEMBER_ID
      and S.claim_id=DXPX.CLAIM_ID
    LEFT JOIN
       (
        select * from 
           (
            select /* + parallel(Y_Fact_Dxpx,8) */ distinct PAYER,LOB,MEMBER_ID,CLAIM_ID,
              --MAX(CASE WHEN CODE_DESC ='DXICD9' THEN '09'
              --WHEN CODE_DESC ='DXICD10' THEN '10' ELSE NULL END ) CODE_DESC,
              CODE ,
              PRMRY_IND
            from y_Fact_Dxpx
              where PAYER=v_payer and LOB=v_lob --and CLAIM_ID='0104171814137' 
              and CODE_DESC like 'PX%'
              --group by PAYER,LOB,MEMBER_ID,CLAIM_ID,CODE
              order by PAYER,LOB,MEMBER_ID,CLAIM_ID,PRMRY_IND
           ) 
           PIVOT  (MAX(CODE) PR for PRMRY_IND in ( '1' D1 ,'2' D2,'3' D3,'4' D4,'5' D5,'6' D6,7 D7,8 D8,9 D9,10 D10,
                                      '11' D11 ,'12' D12,'13' D13,'14' D14,'15' D15,'16' D16,17 D17,18 D18,19 D19,20 D20,
                                      '21' D21 ,'22' D22,'23' D23,'24' D24,'25' D25,'26' D26,27 D27,28 D28,29 D29,30 D30))
        ) PR
      ON S.PAYER=PR.PAYER
       and S.LOB=PR.LOB
       AND S.MEMBER_ID=PR.MEMBER_ID
       and S.claim_id=PR.CLAIM_ID
    left join 
       (
	    select /* + PARALLEL(y_FACT_MEMBER,4) */ distinct payer,lob,member_id,FACT 
         from y_FACT_MEMBER
         where FACT_CATEGORY='Member Coverage' 
           and FACT_SHORTDESCR='Product'
           and PAYER=v_payer
           and LOB=v_lob
		) P
     on S.payer=P.payer
      and S.lob=P.lob
      and S.member_id=P.member_id
    left join 
       (
        select /* + PARALLEL(y_FACT_MEMBER,4) */ distinct payer,lob,member_id,FACT 
        from Y_FACT_MEMBER
        where FACT_CATEGORY='Group Identifiers' 
         and FACT_SHORTDESCR='Group Number'
         and PAYER=v_payer
         and LOB=v_lob
       ) G
    on S.payer=G.payer
      and S.lob=G.lob
      and S.member_id=G.member_id
    where S.PAYER=v_payer and S.LOB=v_lob
    --and S.member_id='UY86308P'
    --and s.CLAIM_ID='0109161449259'
    ;
     v_record_count:=sql%ROWCOUNT;


ELSE --AETNA,EMPIRE,HEALTHFIRST,UNITED

          EXECUTE IMMEDIATE 'ALTER TABLE Z_HCG_INPUT_CLAIMS TRUNCATE SUBPARTITION '|| V_SUBPARTITION;

    Insert into Z_Hcg_Input_Claims
    select
     ROW_NUMBER() OVER ( partition by S.PAYER,S.LOB order by S.Member_id ,S.CLAIM_ID) SequenceNumber,
     S.PAYER PAYER,
     S.CLAIM_ID ClaimID,
     '' LineNum,
     S.Member_id ContractID,
     S.Member_id MemberID,
     M.DOB,
     CASE WHEN UPPER(M.GENDER) in ('M','MALE') THEN 'M'
          WHEN  UPPER(M.GENDER) in ('F','FEMALE') THEN 'F'
          ELSE NULL END GENDER,
     sd.MIDS FromDate,
     sd.MADS ToDate,
     C.ADMIT_DATE AdmitDate,
     C.DISCHARGE_DATE DischDate ,
     C.PAID_DATE PaidDate ,
      /*CASE WHEN length (C.DRG) <=3 THEN LPAD(DRG,3,'0')
      when LENGTH (C.DRG) >=4 and SUBSTR(DRG,1,1)='0' THEN LPAD(SUBSTR(C.DRG,1,3),3,'0')
      ELSE NULL END DRG ,*/
     CASE WHEN C.DRG is not null then LPAD(C.DRG,4,'0') ELSE C.DRG END DRG,
     case when c.DRG_DESC='DRG - AP' THEN 'AP'
      WHEN c.DRG_DESC='DRG - APR' THEN 'APR'
       WHEN c.DRG_DESC='DRG - MS' THEN 'MS'
       ELSE NULL END DRGVersion,
     case when length(S.REVENUE_CODE) <=4 THEN LPAD(S.REVENUE_CODE,4,0) ELSE NULL END  Revcode,
     s.SERVICE_CODE  HCPCS , --removed substr 09/13
     --case when length(s.CPT_MODIFIER1) <=2 then CPT_MODIFIER1 ELSE NULL END  Modifier, --commented 09/13
     --case when length(s.CPT_MODIFIER2) <=2 then CPT_MODIFIER2 ELSE NULL END Modifier2,  --commented 09/13
     s.CPT_MODIFIER1  Modifier,   --added 09/13
     s.CPT_MODIFIER2  Modifier2,  --added 09/13
     s.PLACE_OF_SERVICE SRCPOS,
     CASE WHEN s.PLACE_OF_SERVICE in ('01','1') THEN '01'
          WHEN s.PLACE_OF_SERVICE in ('02','2') THEN '02'
          WHEN s.PLACE_OF_SERVICE in ('03','3') THEN '03'
          WHEN s.PLACE_OF_SERVICE in ('04','4') THEN '04'
          WHEN s.PLACE_OF_SERVICE in ('05','5') THEN '05'
          WHEN s.PLACE_OF_SERVICE in ('06','6') THEN '06' 
          WHEN s.PLACE_OF_SERVICE in ('07','7') THEN '07' 
          WHEN s.PLACE_OF_SERVICE in ('08','8') THEN '08' 
          WHEN s.PLACE_OF_SERVICE in ('09','9') THEN '09' 
          WHEN s.PLACE_OF_SERVICE in ('11') THEN '11'
          WHEN s.PLACE_OF_SERVICE in ('12') THEN '12'
          WHEN s.PLACE_OF_SERVICE in ('13') THEN '13'
          WHEN s.PLACE_OF_SERVICE in ('14') THEN '14'
          WHEN s.PLACE_OF_SERVICE in ('15') THEN '15'
          WHEN s.PLACE_OF_SERVICE in ('16') THEN '16'
          WHEN s.PLACE_OF_SERVICE in ('17') THEN '17'
          WHEN s.PLACE_OF_SERVICE in ('18') THEN '18'
          WHEN s.PLACE_OF_SERVICE in ('19') THEN '19'
          WHEN s.PLACE_OF_SERVICE in ('20') THEN '20'
          WHEN s.PLACE_OF_SERVICE in ('21') THEN '21'
          WHEN s.PLACE_OF_SERVICE in ('22') THEN '22'
          WHEN s.PLACE_OF_SERVICE in ('23') THEN '23'
          WHEN s.PLACE_OF_SERVICE in ('24') THEN '24'
          WHEN s.PLACE_OF_SERVICE in ('25') THEN '25'
          WHEN s.PLACE_OF_SERVICE in ('26') THEN '26'
          WHEN s.PLACE_OF_SERVICE in ('31') THEN '31'
          WHEN s.PLACE_OF_SERVICE in ('32') THEN '32'
          WHEN s.PLACE_OF_SERVICE in ('33') THEN '33'
          WHEN s.PLACE_OF_SERVICE in ('34') THEN '34'
          WHEN s.PLACE_OF_SERVICE in ('35') THEN '35'
          WHEN s.PLACE_OF_SERVICE in ('41') THEN '41'
          WHEN s.PLACE_OF_SERVICE in ('42') THEN '42'
          WHEN s.PLACE_OF_SERVICE in ('49') THEN '49'
          WHEN s.PLACE_OF_SERVICE in ('50') THEN '50'
          WHEN s.PLACE_OF_SERVICE in ('51') THEN '51'
          WHEN s.PLACE_OF_SERVICE in ('52') THEN '52'
          WHEN s.PLACE_OF_SERVICE in ('53') THEN '53'
          WHEN s.PLACE_OF_SERVICE in ('54') THEN '54'
          WHEN s.PLACE_OF_SERVICE in ('55') THEN '55'
          WHEN s.PLACE_OF_SERVICE in ('56') THEN '56'
          WHEN s.PLACE_OF_SERVICE in ('57') THEN '57'
          WHEN s.PLACE_OF_SERVICE in ('60') THEN '60'
          WHEN s.PLACE_OF_SERVICE in ('61') THEN '61'
          WHEN s.PLACE_OF_SERVICE in ('62') THEN '62'
          WHEN s.PLACE_OF_SERVICE in ('65') THEN '65'
          WHEN s.PLACE_OF_SERVICE in ('71') THEN '71'
          WHEN s.PLACE_OF_SERVICE in ('72') THEN '72'
          WHEN s.PLACE_OF_SERVICE in ('81') THEN '81'
          WHEN s.PLACE_OF_SERVICE in ('99') THEN '99'
     ELSE NULL END POS,
     substr(xp.SPECIALIZATION ,1,28) srcSpecialty,
     xms.Milliman_Specialty  Specialty,
     case when length (s.CAP_CLAIM_IND) <=1 then s.CAP_CLAIM_IND ELSE NULL END  EncounterFlag,
     c.SERVICING_NPI ProviderID,
     substr(xp. ZIP_CODE,1,5) ProviderZIP,
     '' ProviderCounty,
     c.SERVICING_NPI  RenderingProviderID,
     substr(xp. ZIP_CODE,1,5) RenderingProviderZIP,
     '' RenderingProviderCounty,
     '' MedicareID,
     c.BILL_CODE_UB BillType,
     '' AdmitSource,
     CASE WHEN C.Ip_Admit_Type in ('NEW BORN','NEWBORN')  THEN '4'
          WHEN C.Ip_Admit_Type in ('ELECTIVE')  THEN '3'
          WHEN C.Ip_Admit_Type in ('EMERGENT','EMERGENCY')  THEN '1'
          WHEN C.Ip_Admit_Type in ('INFORMATION NOT AVAILABLE')  THEN '9'
          WHEN C.Ip_Admit_Type in ('URGENT')  THEN '2'
          WHEN C.Ip_Admit_Type in ('TRAUMA CENTER')  THEN '5'
          WHEN C.Ip_Admit_Type in ('RESERVED FOR NATIONAL ASSIGNMENT')  THEN '6'
          ELSE NULL END admittype,
     '0.1' Billed,
     s.ALLOWED_AMOUNT Allowed,
     --s.PAID_AMOUNT Paid, --commented 12-OCT-20 
     case when s.PAYER like 'MSSP%' and C.CLAIM_TYPE='Facility' and S.rn=1 then C.tcc_paid
      when s.PAYER like 'MSSP%' and C.CLAIM_TYPE='Facility' and S.rn<>1 then 0
     else s.PAID_AMOUNT END Paid, --added 12-OCT-20
     '' COB,
     '' Copay,
     '' Coinsurance,
     '' Deductible,
     '' PatientPay,
     (c.DISCHARGE_DATE - C.ADMIT_DATE) DAYS,
     s.UNIT_COUNT Units,
     c.DISCHARGE_DISPOSITION DischargeStatus,
     DXPX.CODE_DESC ICDVersion,
     '' AdmitDiag,
     DXPX.D1_D ICDDiag1,
     DXPX.D2_D ICDDiag2,
     DXPX.D3_D  ICDDiag3,
     DXPX.D4_D  ICDDiag4,
     DXPX.D5_D  ICDDiag5,
     DXPX.D6_D  ICDDiag6,
     DXPX.D7_D  ICDDiag7,
     DXPX.D8_D  ICDDiag8,
     DXPX.D9_D  ICDDiag9,
     DXPX.D10_D  ICDDiag10,
     DXPX.D11_D ICDDiag11,
     DXPX.D12_D  ICDDiag12,
     DXPX.D13_D ICDDiag13,
     DXPX.D14_D  ICDDiag14,
     DXPX.D15_D  ICDDiag15,
     DXPX.D16_D  ICDDiag16,
     DXPX.D17_D ICDDiag17,
     DXPX.D18_D  ICDDiag18,
     DXPX.D19_D  ICDDiag19,
     DXPX.D20_D  ICDDiag20,
     DXPX.D21_D  ICDDiag21,
     DXPX.D22_D  ICDDiag22,
     DXPX.D23_D  ICDDiag23,
     DXPX.D24_D  ICDDiag24,
     DXPX.D25_D  ICDDiag25,
     DXPX.D26_D  ICDDiag26,
     DXPX.D27_D  ICDDiag27,
     DXPX.D28_D  ICDDiag28,
     DXPX.D29_D  ICDDiag29,
     DXPX.D30_D ICDDiag30,
     DXPX.D1_P POA1,
     DXPX.D2_P POA2,
     DXPX.D3_P POA3,
     DXPX.D4_P POA4,
     DXPX.D5_P POA5,
     DXPX.D6_P POA6,
     DXPX.D7_P POA7,
     DXPX.D8_P POA8,
     DXPX.D9_P POA9,
     DXPX.D10_P POA10,
     DXPX.D11_P POA11,
     DXPX.D12_P POA12,
     DXPX.D13_P POA13,
     DXPX.D14_P POA14,
     DXPX.D15_P POA15,
     DXPX.D16_P POA16,
     DXPX.D17_P POA17,
     DXPX.D18_P POA18,
     DXPX.D19_P POA19,
     DXPX.D20_P POA20,
     DXPX.D21_P POA21,
     DXPX.D22_P POA22,
     DXPX.D23_P POA23,
     DXPX.D24_P POA24,
     DXPX.D25_P POA25,
     DXPX.D26_P POA26,
     DXPX.D27_P POA27,
     DXPX.D28_P POA28,
     DXPX.D29_P POA29,
     DXPX.D30_P POA30,
     PR.D1_PR ICDProc1,
     PR.D2_PR ICDProc2,
     PR.D3_PR ICDProc3,
     PR.D4_PR ICDProc4,
     PR.D5_PR ICDProc5,
     PR.D6_PR ICDProc6,
     PR.D7_PR ICDProc7,
     PR.D8_PR ICDProc8,
     PR.D9_PR ICDProc9,
     PR.D10_PR ICDProc10,
     PR.D11_PR ICDProc11,
     PR.D12_PR ICDProc12,
     PR.D13_PR ICDProc13,
     PR.D14_PR ICDProc14,
     PR.D15_PR ICDProc15,
     PR.D16_PR ICDProc16,
     PR.D17_PR ICDProc17,
     PR.D18_PR ICDProc18,
     PR.D19_PR ICDProc19,
     PR.D20_PR ICDProc20,
     PR.D21_PR ICDProc21,
     PR.D22_PR ICDProc22,
     PR.D23_PR ICDProc23,
     PR.D24_PR ICDProc24,
     PR.D25_PR ICDProc25,
     PR.D26_PR ICDProc26,
     PR.D27_PR ICDProc27,
     PR.D28_PR ICDProc28,
     PR.D29_PR ICDProc29,
     PR.D30_PR ICDProc30,
     '' RiskPool,
     '' OON,
     CASE WHEN C.PAID_STATUS='1' THEN 'P'
     WHEN C.PAID_STATUS='0' THEN 'D'
     WHEN C.PAID_STATUS='-1' THEN 'R' 
     ELSE 'P' END ClaimLineStatus,
     C.PAID_STATUS CurrentAllowed,
     '' LOINC,
     S.LOB SRCLOB,
      CASE WHEN S.LOB='Commercial' THEN 'COM'
          WHEN S.LOB='MA' THEN 'ADV'
           WHEN S.LOB='Medicare' THEN 'MCR'
           WHEN S.LOB='Medicaid' THEN 'MCD'
      ELSE 'UNK' END LOB,
      P.FACT srcProduct,
      P.FACT product,
      G.FACT GroupID,
      SUBSTR(M.ZIP,1,5) ZIP,
      '' COUNTY,
      '' MemberStatus,
     S.PAYER UserDefPop1,
     '' UserDefPop2,
     '' UserDefPop3,
     '' UserDefNum1,
     '' UserDefNum2,
     '' UserDefNum3,
     trunc(sysdate) load_Date
    from 
        ( select /* + parallel(fs,8) */
         fs.* ,
         row_number() over (
                   partition by payer,lob,member_id,claim_id 
                   order by --lpad(revenue_code,4,0) desc nulls last
        		   lpad(revenue_code,4,0) desc nulls last,
                   SERVICE_CODE desc nulls last, 
                    CPT_MODIFIER1 desc nulls last,
                    CPT_MODIFIER2 desc nulls last,
                    ALLOWED_AMOUNT desc nulls last, PAID_AMOUNT desc nulls last, UNIT_COUNT desc nulls last, 
                    PLACE_OF_SERVICE desc nulls last, CAP_CLAIM_IND desc nulls last
                   ) rn
         from X_FACT_SERVICE fs
         where PAYER=v_payer and LOB=v_lob and member_id <>'00000000000000000000'
        ) S
    left join
       (
        select  /* + parallel(XC_UM_CLAIM_HEADER,8) */ *
        from XC_UM_CLAIM_HEADER where PAYER=v_payer and LOB=v_lob and member_id <>'00000000000000000000'
        --where (DRG_DESC ='DRG - MS' or DRG_DESC is null ) 
       ) C
      on C.payer=s.payer
      and C.lob=s.lob
      and C.member_id=s.member_id
      and c.claim_id=s.claim_id
    left join 
       (select /* + parallel(X_MEMBER,8) */ * from X_MEMBER where payer=v_payer and lob=v_lob) M
      on s.payer=M.payer
      and s.lob=M.lob
      and s.member_id=M.member_id
    left join 
       (
        select /* + parallel(X_FACT_SERVICE,8) */
        PAYER,LOB,MEMBER_ID,Claim_id,MIN(SERVICE_DT) MIDS ,MAX(SERVICE_DT) MADS 
        from X_FACT_SERVICE where PAYER=v_payer AND LOB=v_lob group by PAYER,LOB,MEMBER_ID,Claim_id
       ) SD
      on s.payer=sd.payer
      and s.lob=sd.lob
      and s.member_id=sd.member_id
      and s.claim_id=sd.claim_id
    left join 
    --X_PROVIDER XP
       (
       select NPI,ZIP_CODE,taxonomy_code,primary_specialty,specialization,pcp_spc
         from
         (
         select distinct tax_npi.npi,tax_npi.PROV_BUS_MAIL_ADDR_POSTAL_CD as ZIP_CODE ,tax_npi.HC_PROV_TAXON_CD taxonomy_code,tax_xwalk.classification as primary_specialty,specialization,pcp_spc,
         row_number() over(partition by tax_npi.npi order by case when HC_PROV_PRIM_TAXON_SWITCH='Y' then 1 else 0 end desc,ind asc) rn
         from
         (select NPI,PROV_BUS_MAIL_ADDR_POSTAL_CD,HC_PROV_TAXON_CD,HC_PROV_PRIM_TAXON_SWITCH,ind from 
         (select /*+ parallel(8) */ npi, PROV_BUS_MAIL_ADDR_POSTAL_CD,
         HC_PROV_TAXON_CD_1,
         HC_PROV_TAXON_CD_2,
         HC_PROV_TAXON_CD_3,
         HC_PROV_TAXON_CD_4,
         HC_PROV_TAXON_CD_5,
         HC_PROV_TAXON_CD_6,
         HC_PROV_TAXON_CD_7,
         HC_PROV_TAXON_CD_8,
         HC_PROV_TAXON_CD_9,
         HC_PROV_TAXON_CD_10,
         HC_PROV_TAXON_CD_11,
         HC_PROV_TAXON_CD_12,
         HC_PROV_TAXON_CD_13,
         HC_PROV_TAXON_CD_14,
         HC_PROV_TAXON_CD_15,
         HC_PROV_PRIM_TAXON_SWITCH_1,
         HC_PROV_PRIM_TAXON_SWITCH_2,
         HC_PROV_PRIM_TAXON_SWITCH_3,
         HC_PROV_PRIM_TAXON_SWITCH_4,
         HC_PROV_PRIM_TAXON_SWITCH_5,
         HC_PROV_PRIM_TAXON_SWITCH_6,
         HC_PROV_PRIM_TAXON_SWITCH_7,
         HC_PROV_PRIM_TAXON_SWITCH_8,
         HC_PROV_PRIM_TAXON_SWITCH_9,
         HC_PROV_PRIM_TAXON_SWITCH_10,
         HC_PROV_PRIM_TAXON_SWITCH_11,
         HC_PROV_PRIM_TAXON_SWITCH_12,
         HC_PROV_PRIM_TAXON_SWITCH_13,
         HC_PROV_PRIM_TAXON_SWITCH_14,
         HC_PROV_PRIM_TAXON_SWITCH_15
          from XREF_PROVIDER_NPPES_RAW)
         unpivot
         (
          (HC_PROV_TAXON_CD,HC_PROV_PRIM_TAXON_SWITCH) for ind in
          (
           (HC_PROV_TAXON_CD_1,HC_PROV_PRIM_TAXON_SWITCH_1) as '1',
           (HC_PROV_TAXON_CD_2,HC_PROV_PRIM_TAXON_SWITCH_2) as '2',
           (HC_PROV_TAXON_CD_3,HC_PROV_PRIM_TAXON_SWITCH_3) as '3',
           (HC_PROV_TAXON_CD_4,HC_PROV_PRIM_TAXON_SWITCH_4) as '4',
           (HC_PROV_TAXON_CD_5,HC_PROV_PRIM_TAXON_SWITCH_5) as '5',
           (HC_PROV_TAXON_CD_6,HC_PROV_PRIM_TAXON_SWITCH_6) as '6',
           (HC_PROV_TAXON_CD_7,HC_PROV_PRIM_TAXON_SWITCH_7) as '7',
           (HC_PROV_TAXON_CD_8,HC_PROV_PRIM_TAXON_SWITCH_8) as '8',
           (HC_PROV_TAXON_CD_9,HC_PROV_PRIM_TAXON_SWITCH_9) as '9',
           (HC_PROV_TAXON_CD_10,HC_PROV_PRIM_TAXON_SWITCH_10) as '10',
           (HC_PROV_TAXON_CD_11,HC_PROV_PRIM_TAXON_SWITCH_11) as '11',
           (HC_PROV_TAXON_CD_12,HC_PROV_PRIM_TAXON_SWITCH_12) as '12',
           (HC_PROV_TAXON_CD_13,HC_PROV_PRIM_TAXON_SWITCH_13) as '13',
           (HC_PROV_TAXON_CD_14,HC_PROV_PRIM_TAXON_SWITCH_14) as '14',
           (HC_PROV_TAXON_CD_15,HC_PROV_PRIM_TAXON_SWITCH_15) as '15'
          )
         )
         where HC_PROV_TAXON_CD is not null) tax_npi
         left outer join
         XREF_TAXONOMY_XWALK tax_xwalk
         on tax_npi.HC_PROV_TAXON_CD=tax_xwalk.CODE
         )
         where rn=1
       ) XP   --added on 31-AUG-2020
      on c.SERVICING_NPI=xp.npi
    left join
      --XREF_MILLIMAN_SPECIALIZATION XMS   
	  YREF_MILLIMAN_TAX_SPEC_XWALK XMS   --2021 code sets
       on Xp.Taxonomy_Code=xms.Taxonomy_Code
    left join 
       (
        select * from 
           (
              select /* + parallel(X_Fact_Dxpx,8) */ distinct PAYER,LOB,MEMBER_ID,CLAIM_ID,
                MAX(CASE WHEN CODE_DESC ='DXICD9' THEN '09'
                WHEN CODE_DESC ='DXICD10' THEN '10' ELSE NULL END ) CODE_DESC,
                CODE ,
                POA ,
                --ROW_NUMBER() over ( PARTITION by PAYER,LOB,MEMBER_ID,CLAIM_ID order by PRMRY_IND ) RN
                To_NUMBER(MIN(PRMRY_IND)) PRMRY_IND
              from X_Fact_Dxpx
                where PAYER=v_payer and LOB=v_lob --and CLAIM_ID='0107291691088' --'0107291691088'--'0104171814137' --'0205091611636'
                and CODE_DESC like 'DX%'
                group by PAYER,LOB,MEMBER_ID,CLAIM_ID,CODE,POA
                order by PAYER,LOB,MEMBER_ID,CLAIM_ID,PRMRY_IND
           ) 
           PIVOT  (MAX(CODE) D,MAX(POA) P for PRMRY_IND in ( '1' D1 ,'2' D2,'3' D3,'4' D4,'5' D5,'6' D6,7 D7,8 D8,9 D9,10 D10,
                                      '11' D11 ,'12' D12,'13' D13,'14' D14,'15' D15,'16' D16,17 D17,18 D18,19 D19,20 D20,
                                      '21' D21 ,'22' D22,'23' D23,'24' D24,'25' D25,'26' D26,27 D27,28 D28,29 D29,30 D30))
        ) DXPX
      on S.PAYER=DXPX.PAYER
      and S.LOB=DXPX.LOB
      AND S.MEMBER_ID=DXPX.MEMBER_ID
      and S.claim_id=DXPX.CLAIM_ID
    LEFT JOIN
       (
        select * from 
           (
            select /* + parallel(X_Fact_Dxpx,8) */ distinct PAYER,LOB,MEMBER_ID,CLAIM_ID,
              --MAX(CASE WHEN CODE_DESC ='DXICD9' THEN '09'
              --WHEN CODE_DESC ='DXICD10' THEN '10' ELSE NULL END ) CODE_DESC,
              CODE ,
              PRMRY_IND
            from X_Fact_Dxpx
              where PAYER=v_payer and LOB=v_lob --and CLAIM_ID='0104171814137' 
              and CODE_DESC like 'PX%'
              --group by PAYER,LOB,MEMBER_ID,CLAIM_ID,CODE
              order by PAYER,LOB,MEMBER_ID,CLAIM_ID,PRMRY_IND
           ) 
           PIVOT  (MAX(CODE) PR for PRMRY_IND in ( '1' D1 ,'2' D2,'3' D3,'4' D4,'5' D5,'6' D6,7 D7,8 D8,9 D9,10 D10,
                                      '11' D11 ,'12' D12,'13' D13,'14' D14,'15' D15,'16' D16,17 D17,18 D18,19 D19,20 D20,
                                      '21' D21 ,'22' D22,'23' D23,'24' D24,'25' D25,'26' D26,27 D27,28 D28,29 D29,30 D30))
        ) PR
      ON S.PAYER=PR.PAYER
       and S.LOB=PR.LOB
       AND S.MEMBER_ID=PR.MEMBER_ID
       and S.claim_id=PR.CLAIM_ID
    left join 
       (
	    select /* + PARALLEL(X_FACT_MEMBER,4) */ distinct payer,lob,member_id,FACT 
         from X_FACT_MEMBER
         where FACT_CATEGORY='Member Coverage' 
           and FACT_SHORTDESCR='Product'
           and PAYER=v_payer
           and LOB=v_lob
		) P
     on S.payer=P.payer
      and S.lob=P.lob
      and S.member_id=P.member_id
    left join 
       (
        select /* + PARALLEL(X_FACT_MEMBER,4) */ distinct payer,lob,member_id,FACT 
        from X_FACT_MEMBER
        where FACT_CATEGORY='Group Identifiers' 
         and FACT_SHORTDESCR='Group Number'
         and PAYER=v_payer
         and LOB=v_lob
       ) G
    on S.payer=G.payer
      and S.lob=G.lob
      and S.member_id=G.member_id
    where S.PAYER=v_payer and S.LOB=v_lob
    --and S.member_id='UY86308P'
    --and s.CLAIM_ID='0109161449259'
    ;
     v_record_count:=sql%ROWCOUNT;
    end if;

    COMMIT;

  v_end_time:=sysdate;

  select count(*) into v_record_count from Z_HCG_INPUT_CLAIMS where payer = v_payer and srclob=v_lob;

  UPDATE  Y_TABLE_REFRESH 
      SET END_TIME=v_end_time,
          RECORD_COUNT=v_record_count,
          load_dt=trunc(sysdate),
          status='Completed'
          WHERE TABLE_NAME=v_table_name AND PAYER=v_payer||'-'||v_lob AND category = v_category AND START_TIME = v_start_time;
   COMMIT;

    EXCEPTION
      WHEN OTHERS THEN
          v_err:= SQLCODE;
          v_msg:= SUBSTR(SQLERRM, 1, 200)||':'||SUBSTR(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,1,3799);
          INSERT INTO y_table_err_log(TABLE_NAME,PAYER,category,START_TIME,ERROR_TIME,ERROR_CODE,ERROR_MSG,LOAD_DT,REPROCESSED,REPROCESSED_DT) VALUES (v_table_name,v_payer||'-'||v_lob,v_category,v_start_time,SYSDATE,v_err,v_msg,TRUNC(SYSDATE),'N',NULL);
          COMMIT;
          UPDATE Y_TABLE_REFRESH SET end_time = SYSDATE ,status = 'Failed',load_dt=TRUNC(SYSDATE) WHERE TABLE_NAME=v_table_name AND PAYER=v_payer||'-'||v_lob  AND START_TIME = v_start_time;
          COMMIT;
      END;

end loop;
close cur_payer;

end;

/
