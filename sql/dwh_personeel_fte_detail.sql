/* ==================================================================== <HEADER>
Source      : dwh_personeel_fte.sql
Description :
============================================================== <PROGRAM HISTORY>
Date       Vers Name         Changes (Incident/Change Number)
---------- ---- ------------ --------------------------------------------------
  1       Created
Mutaties: http://dwh.mchaaglanden.local/gitphp/?sort=age
======================================================================== <NOTES>

select format ( getdate(), 'yyyy-MM-dd' ) AS FormattedDate;
SELECT FORMAT(getdate(), N'yyyy-MM-dd hh:mm') AS FormattedDateTime;

exec tempdb..sp_columns '#';

[NT-DK-CCPRO-P].[CCPro].[dbo].
[nt-vm-dwh-p3].dwh_ezis.dbo.
[HIXR.mchbrv.nl].[HIX_PRODUCTIE].[dbo].

==================================================================== <SOURCE> */

set nocount on -- Stop de melding over aantal regels
set ansi_warnings on -- ISO foutmeldingen(NULL in aggregraat bv)
set ansi_nulls on -- ISO NULLL gedrag(field = null returns null, ook als field null is)

declare @CUR_JAAR char(4);
declare @PRV_JAAR char(4);

select @CUR_JAAR=year(rapport_einddatum)  from dwh_rap_periode where package_naam = 'dwh_dashboard';
select @PRV_JAAR=year(dateadd(yy, -1, rapport_einddatum)) from dwh_rap_periode where package_naam = 'dwh_dashboard';

declare @placeholder decimal(18,8);
set @placeholder = 0.0;

/*
|| Basis voor het vervangen van de bestaande tabel
*/

if object_id('tempdb..#budget') is not null drop table #budget
select * into #budget from
(
select
    t30.kostenplaats_code,
    t30.afdeling_code,
    t20.medewerker_functie_code functiecode_excl,
    t20.medewerker_functie_code functiecode,
    t20.medewerker_functie_naam oms_functie,
    sum(isnull(t00.FTE_BEGROOT_DAGEN, 0.00) / isnull(t10.aantal_dagen_maand, 0.00)) formatie,
    @placeholder as gem_realisatie_cum,
    t10.jaar,
    t10.maandnummer,
    t00.maand_id periode
from afas.FACT_FTE_BEGROTING t00
 join afas.vw_REF_DATUM t10
  on t00.MAAND_ID = t10.maand_id
 join afas.vw_DIM_MEDEWERKER_FUNCTIES t20
  on t00.MEDEWERKER_FUNCTIE_ID = t20.MEDEWERKER_FUNCTIE_ID
 join afas.vw_DIM_ORGANISATIE_EENHEID_INDELING t30
  on t00.ORGANISATIE_EENHEID_ID = t30.organisatie_eenheid_id
where t10.jaar  IN (@PRV_JAAR, @CUR_JAAR)
   and t30.cluster_code not in ('BC0003') -- => 'BUITEN EXPLOITATIE'
   and t20.medewerker_functie_code not in ( '3180000', 'dummy01', 'dummy02')
   and t00.groepering_id = '3'
group by
    t30.kostenplaats_code,
    t30.afdeling_code,
    t20.medewerker_functie_code,
    t20.medewerker_functie_code,
    t20.medewerker_functie_naam,
    t10.jaar,
    t10.maandnummer,
    t00.maand_id
) t1


if object_id('tempdb..#realisatie1') is not null drop table #realisatie1
select * into #realisatie1
from (
select
    isnull(cast(t00.medewerker_id as varchar(max)), 'Onbekend') medewerker_id,
    isnull(cast(t00.dienstverband_id as varchar(max)), 'Onbekend') dienstverband_id,
    isnull(t30.kostenplaats_code, 'Onbekend') kostenplaats_code,
    isnull(t30.afdeling_code, 'Onbekend') afdeling_code,
    isnull(t20.medewerker_functie_code, 'Onbekend') functiecode_excl,
    isnull(t20.medewerker_functie_code, 'Onbekend') functiecode,
    isnull(t20.medewerker_functie_naam, 'Onbekend') oms_functie,
    @placeholder as plan_formatie,
    sum(isnull(t00.dienstverband_dagen, 0) / isnull(t10.aantal_dagen_maand, 0)) realisatie,
    sum(isnull(DIENSTVERBAND_DAGEN, 0)) DIENSTVERBAND_DAGEN,
    @placeholder gem_realisatie,
    isnull(cast(t10.jaar as varchar(4)), 'Onbekend') jaar,
    isnull(cast(t10.maandnummer as varchar(2)), 'Onbekend') maandnummer,
    t00.maand_id periode
from afas.fact_fte_realisatie t00
 join afas.vw_ref_datum t10
  on t00.maand_id = t10.maand_id
  left join afas.vw_DIM_MEDEWERKER_FUNCTIES t20
  on t00.MEDEWERKER_FUNCTIE_ID = t20.MEDEWERKER_FUNCTIE_ID
   and t20.medewerker_functie_code not in ( '3180000', 'dummy01', 'dummy02')
  left join afas.vw_DIM_ORGANISATIE_EENHEID_INDELING t30
  on t00.ORGANISATIE_EENHEID_ID = t30.organisatie_eenheid_id
   and t30.cluster_code not in ('BC0003') -- => 'BUITEN EXPLOITATIE'
 join afas.vw_dim_dienstverbanden t40
  on t00.DIENSTVERBAND_ID = t40.dienstverband_id
   and t40.werkgever_code not in  ('99', '04', '13')
   and t40.dienstbetrekking not in ('15', '08', '14')
   and isnull(t40.[type werknemer], '') not in ( 'Stagiair - zonder salaris')
where isnull(left(t00.maand_id, 4), '') IN (@PRV_JAAR, @CUR_JAAR, '')
   --   and t30.afdeling_code <> 'BA2303' -- reorganisatie afdeling
   and t00.groepering_id = '3'
group by
    isnull(cast(t00.medewerker_id as varchar(max)), 'Onbekend'),
    isnull(cast(t00.dienstverband_id as varchar(max)), 'Onbekend'),
    isnull(t30.kostenplaats_code, 'Onbekend'),
    isnull(t30.afdeling_code, 'Onbekend'),
    isnull(t20.medewerker_functie_code, 'Onbekend'),
    isnull(t20.medewerker_functie_code, 'Onbekend'),
    isnull(t20.medewerker_functie_naam, 'Onbekend'),
    isnull(cast(t10.jaar as varchar(4)), 'Onbekend'),
    isnull(cast(t10.maandnummer as varchar(2)), 'Onbekend'),
    t00.maand_id
) t1

if object_id('tempdb..#dwh_personeel_fte') is not null drop table #dwh_personeel_fte
select * into #dwh_personeel_fte
from (
select
     t00.periode
    ,t00.medewerker_id
    ,t00.kostenplaats_code
    ,t00.functiecode functie_code
    ,@placeholder formatie
    ,sum(t00.realisatie) realisatie 
    ,@placeholder DAGEN_ZIEK_EX_ZWANGER
    ,sum(t00.DIENSTVERBAND_DAGEN) DIENSTVERBAND_DAGEN
from #realisatie1 t00
group by
     t00.periode
    ,t00.medewerker_id
    ,t00.kostenplaats_code
    ,t00.functiecode
) t1

if object_id('tempdb..#verzuim') is not null drop table #verzuim
select * into #verzuim from
(
select
    cast(t10.jaar as varchar(4)) +''+RIGHT('00'+cast(t10.maandnummer as varchar(2)),2) periode,
    t30.kostenplaats_code,
    t20.medewerker_functie_code functiecode,
    sum(isnull(t00.DAGEN_ZIEK_EX_ZWANGER, 0.00))  DAGEN_ZIEK_EX_ZWANGER,
    t60.medewerker_id
from dwh_ezis.afas.FACT_FTE_ZIEKTEVERZUIM t00
  join dwh_ezis.afas.vw_REF_DATUM t10
  on t00.MAAND_ID = t10.maand_id
  join dwh_ezis.afas.vw_DIM_MEDEWERKER_FUNCTIES t20
  on t00.MEDEWERKER_FUNCTIE_ID = t20.MEDEWERKER_FUNCTIE_ID
   and t20.medewerker_functie_code not in ( '3180000', 'dummy01', 'dummy02')
  join dwh_ezis.afas.vw_DIM_ORGANISATIE_EENHEID_INDELING t30
  on t00.ORGANISATIE_EENHEID_ID = t30.organisatie_eenheid_id
   and t30.cluster_code not in ('BC0003') -- => 'BUITEN EXPLOITATIE'
 join dwh_ezis.afas.DIM_MEDEWERKERS t60
  on t00.MEDEWERKER_ID = t60.MEDEWERKER_ID
   join afas.vw_dim_dienstverbanden t40
  on t00.DIENSTVERBAND_ID = t40.dienstverband_id
   and t40.werkgever_code not in  ('99', '04', '13')
   and t40.dienstbetrekking not in ('15', '08', '14')
   and isnull(t40.[type werknemer], 'XXX') not in ( 'Stagiair - zonder salaris')
where isnull(left(t00.maand_id, 4), '') IN (@PRV_JAAR, @CUR_JAAR)
 and t00.ZIEKTEPERCENTAGE <> 0
group by
    cast(t10.jaar as varchar(4)) +''+RIGHT('00'+cast(t10.maandnummer as varchar(2)),2),
    t30.kostenplaats_code,
    t20.medewerker_functie_code,
    t60.medewerker_id
) t1

/*
insert into #dwh_personeel_fte
select
    periode,
    kostenplaats_code,
    functiecode,
    formatie,
    @placeholder,
    @placeholder,
    @placeholder
from #budget
*/

-- declare @placeholder decimal(18,8);
-- set @placeholder = 0.0;

insert into #dwh_personeel_fte
select
    periode,
    medewerker_id,
    kostenplaats_code,
    functiecode,
    @placeholder,
    @placeholder,
    DAGEN_ZIEK_EX_ZWANGER,
    @placeholder
from #verzuim


drop table afas.dwh_personeel_fte
select * into afas.dwh_personeel_fte
from (
select
    left(periode, 4) jaar,
    right(periode, 2) maand,
    medewerker_id,
	kostenplaats_code,
	functie_code,
	sum(formatie) [FTE Begroot],
	sum(realisatie) [FTE Realisatie],
    sum(realisatie)  [FTE Realisatie cum],
	sum(cast(DAGEN_ZIEK_EX_ZWANGER  as decimal(18,6))) [DAGEN_ZIEK_EX_ZWANGER],
	sum(cast(DIENSTVERBAND_DAGEN  as decimal(18,6))) [DIENSTVERBAND_DAGEN],
    @placeholder [DAGEN_ZIEK_EX_ZWANGER cum],
    @placeholder [DIENSTVERBAND_DAGEN cum],
    getdate() loaddatime
from  #dwh_personeel_fte
group by
	periode,
    medewerker_id,
	kostenplaats_code,
	functie_code
) t1

update t00
set t00.[FTE Realisatie cum] = t10.[FTE Realisatie cum]
,   t00.[DAGEN_ZIEK_EX_ZWANGER cum] = t10.[DAGEN_ZIEK_EX_ZWANGER cum]
,   t00.[DIENSTVERBAND_DAGEN cum] = t10.[DIENSTVERBAND_DAGEN cum]
from afas.dwh_personeel_fte t00
 join (select
    t00.medewerker_id,
    t00.kostenplaats_code,
    t00.functie_code,
    t00.jaar,
    t00.maand,
    sum(t10.[FTE Realisatie])  [FTE Realisatie cum],
    sum(t10.[DAGEN_ZIEK_EX_ZWANGER]) [DAGEN_ZIEK_EX_ZWANGER cum],
    sum(t10.[DIENSTVERBAND_DAGEN]) [DIENSTVERBAND_DAGEN cum]
from afas.dwh_personeel_fte t00
 join afas.dwh_personeel_fte t10
  on t00.kostenplaats_code = t10.kostenplaats_code
   and t00.medewerker_id = t10.medewerker_id
   and t00.functie_code = t10.functie_code
   and t00.jaar = t10.jaar
   and t00.maand >= t10.maand
group by t00.medewerker_id, t00.kostenplaats_code, t00.functie_code, t00.jaar, t00.maand
 ) t10
  on t00.kostenplaats_code = t10.kostenplaats_code
   and t00.functie_code = t10.functie_code
   and t00.medewerker_id = t10.medewerker_id
   and t00.jaar = t10.jaar
   and t00.maand = t10.maand


update t00
set t00.[FTE Realisatie cum] = t00.[FTE Realisatie cum]/cast(t00.maand as int)
,   t00.[DAGEN_ZIEK_EX_ZWANGER cum] = t00.[DAGEN_ZIEK_EX_ZWANGER cum]/cast(t00.maand as int)
,   t00.[DIENSTVERBAND_DAGEN cum] = t00.[DIENSTVERBAND_DAGEN cum]/cast(t00.maand as int)
from afas.dwh_personeel_fte t00


return

/*
|| Controle
*/



select
    'Hmc Totaal' divisie,
    t00.jaar,
--    t00.maand,
    format(sum(DAGEN_ZIEK_EX_ZWANGER), '#,##0;-#,##0') DAGEN_ZIEK_EX_ZWANGER,
    format(sum(DIENSTVERBAND_DAGEN), '#,##0;-#,##0') DIENSTVERBAND_DAGEN,
    format((sum(DAGEN_ZIEK_EX_ZWANGER)/sum(DIENSTVERBAND_DAGEN))*100.00, '0.00') [verzuim ex zwanger]
from afas.dwh_personeel_fte_cum t00
group by
    t00.jaar
--    t00.maand
order by 2,1

select
    t10.zorgbedrijf,
--    t10.afdeling,
--    t00.functie_code,
    t00.jaar,
    t00.maand,
    format(sum(DAGEN_ZIEK_EX_ZWANGER), '#,##0;-#,##0') DAGEN_ZIEK_EX_ZWANGER,
    format(sum(DIENSTVERBAND_DAGEN), '#,##0;-#,##0') DIENSTVERBAND_DAGEN,
    format((sum(DAGEN_ZIEK_EX_ZWANGER)/sum(DIENSTVERBAND_DAGEN))*100.00, '0.00') [verzuim ex zwanger],
    sum([FTE Realisatie])
from afas.dwh_personeel_fte_cum t00
 join dwh_budgetplaatsen t10
  on t00.kostenplaats_code = t10.kostenplaats_code
where t00.jaar in( '2016', '2017')
--  and t10.zorgbedrijf = 'SERVICE EN HUISVESTING'
  and t10.zorgbedrijf = 'CLUSTER 2 SNIJDEND'
group by
    t10.zorgbedrijf,
--    t10.afdeling,
--    t00.functie_code,
    t00.jaar,
    t00.maand
order by 2,3


set nocount on; -- Stop de melding over aantal regels
set ansi_warnings on; -- ISO foutmeldingen(NULL in aggregraat bv)
set ansi_nulls on; -- ISO NULLL gedrag(field = null returns null, ook als field null is)

declare @begin int;
declare @eind int;
select @begin = year(dateadd(yy, -1, rapport_einddatum)) from dwh_rap_periode where package_naam = 'dwh_dashboard';
select @eind = year(rapport_einddatum)  from dwh_rap_periode where package_naam = 'dwh_dashboard';

with cte_mo ( divisie, jaar, maand, zv, zvc) as (
select
    'Hmc Totaal' divisie,
    t00.jaar,
    t00.maand,
    (sum(DAGEN_ZIEK_EX_ZWANGER)/sum(DIENSTVERBAND_DAGEN))*100.00,
    (sum([DAGEN_ZIEK_EX_ZWANGER cum])/sum([DIENSTVERBAND_DAGEN cum]))*100.00
from afas.dwh_personeel_fte_cum t00
group by
    t00.jaar,
    t00.maand
union all
select
    t10.zorgbedrijf,
    t00.jaar,
    t00.maand,
    (sum(DAGEN_ZIEK_EX_ZWANGER)/sum(DIENSTVERBAND_DAGEN))*100.00,
    (sum([DAGEN_ZIEK_EX_ZWANGER cum])/sum([DIENSTVERBAND_DAGEN cum]))*100.00
from afas.dwh_personeel_fte_cum t00
 join dwh_budgetplaatsen t10
  on t00.kostenplaats_code = t10.kostenplaats_code
group by
    t10.zorgbedrijf,
    t00.jaar,
    t00.maand

)
select
    divisie zorgbedrijf,
    jaar,
    'zv' bron,
    max(case when cast(maand as int) = 1 then  cast(zv as decimal(18,2)) end) 'Verzuim Januari',
    max(case when cast(maand as int) = 2 then  cast(zv as decimal(18,2)) end) 'Verzuim Februari',
    max(case when cast(maand as int) = 3 then  cast(zv as decimal(18,2)) end) 'Verzuim Maart',
    max(case when cast(maand as int) = 4 then  cast(zv as decimal(18,2)) end) 'Verzuim April',
    max(case when cast(maand as int) = 5 then  cast(zv as decimal(18,2)) end) 'Verzuim Mei',
    max(case when cast(maand as int) = 6 then  cast(zv as decimal(18,2)) end) 'Verzuim Juni',
    max(case when cast(maand as int) = 7 then  cast(zv as decimal(18,2)) end) 'Verzuim Juli',
    max(case when cast(maand as int) = 8 then  cast(zv as decimal(18,2)) end) 'Verzuim Augustus',
    max(case when cast(maand as int) = 9 then  cast(zv as decimal(18,2)) end) 'Verzuim September',
    max(case when cast(maand as int) = 10 then cast(zv as decimal(18,2)) end) 'Verzuim Oktober',
    max(case when cast(maand as int) = 11 then cast(zv as decimal(18,2)) end) 'Verzuim November',
    max(case when cast(maand as int) = 12 then cast(zv as decimal(18,2)) end) 'Verzuim December'
from cte_mo
where jaar in (@begin, @eind)
group by divisie, jaar
union all
select
    divisie zorgbedrijf,
    jaar,
    'zv' bron,
    max(case when cast(maand as int) = 1 then  cast(zvc as decimal(18,2)) end) 'Verzuim Januari',
    max(case when cast(maand as int) = 2 then  cast(zvc as decimal(18,2)) end) 'Verzuim Februari',
    max(case when cast(maand as int) = 3 then  cast(zvc as decimal(18,2)) end) 'Verzuim Maart',
    max(case when cast(maand as int) = 4 then  cast(zvc as decimal(18,2)) end) 'Verzuim April',
    max(case when cast(maand as int) = 5 then  cast(zvc as decimal(18,2)) end) 'Verzuim Mei',
    max(case when cast(maand as int) = 6 then  cast(zvc as decimal(18,2)) end) 'Verzuim Juni',
    max(case when cast(maand as int) = 7 then  cast(zvc as decimal(18,2)) end) 'Verzuim Juli',
    max(case when cast(maand as int) = 8 then  cast(zvc as decimal(18,2)) end) 'Verzuim Augustus',
    max(case when cast(maand as int) = 9 then  cast(zvc as decimal(18,2)) end) 'Verzuim September',
    max(case when cast(maand as int) = 10 then cast(zvc as decimal(18,2)) end) 'Verzuim Oktober',
    max(case when cast(maand as int) = 11 then cast(zvc as decimal(18,2)) end) 'Verzuim November',
    max(case when cast(maand as int) = 12 then cast(zvc as decimal(18,2)) end) 'Verzuim December'
from cte_mo
where jaar in (@begin, @eind)
group by divisie, jaar
order by 1, 2



/*
=====================================================================<KLADBLOK>

select *
from dwh_dashboard
where rap_periode = '201608'
 and rap_item = 'FTE_VERZ_AFAS'
 and rap_code = 'AFD'
order by rap_item

select *
from dwh_dashboard
where rap_code = 'DIV'
 and rap_periode > 201605
 and rap_item5 = 'MGT_RAP'
order by rap_item




select * from afas.FACT_FTE_BEGROTING
where  left(maand_id, 4) in ('2015','2016')

select distinct
 tabel,
 kolomnaam,
 length
from
(
select distinct
  t2.name as tabel,
  t3.rows,
  t1.name as kolomnaam,
  t1.length
from dbo.syscolumns t1
  join dbo.sysobjects t2
   on t2.id = t1.id
  left join dbo.sysindexes t3
   on t3.id = t1.id and t3.name = t2.name
where upper(t2.name) like '%%'        -- tabel
and upper(t1.name) like '%%'        -- kolom
) t0 group by tabel, kolomnaam, length
order by 1


select
    t20.zorgbedrijf,
    t00.jaar,
 	cast(sum(case when maand = 01 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Jan',
 	cast(sum(case when maand = 02 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Feb',
 	cast(sum(case when maand = 03 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Mar',
 	cast(sum(case when maand = 04 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Apr',
 	cast(sum(case when maand = 05 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Mei',
 	cast(sum(case when maand = 06 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Jun',
 	cast(sum(case when maand = 07 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Jul',
 	cast(sum(case when maand = 08 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Aug',
 	cast(sum(case when maand = 09 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Sep',
 	cast(sum(case when maand = 10 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Okt',
 	cast(sum(case when maand = 11 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Nov',
 	cast(sum(case when maand = 12 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Dec'
from afas.dwh_personeel_fte_cum t00
 join dwh_budgetplaatsen t20
  on t00.kostenplaats_code = t20.kostenplaats_code
where zorgbedrijf is not null
 and t00.jaar = '2016'
group by t20.zorgbedrijf, t00.jaar
union all
select
 ' Mch Totaal' divisie,
 jaar,
 	cast(sum(case when maand = 01 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Jan',
 	cast(sum(case when maand = 02 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Feb',
 	cast(sum(case when maand = 03 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Mar',
 	cast(sum(case when maand = 04 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Apr',
 	cast(sum(case when maand = 05 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Mei',
 	cast(sum(case when maand = 06 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Jun',
 	cast(sum(case when maand = 07 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Jul',
 	cast(sum(case when maand = 08 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Aug',
 	cast(sum(case when maand = 09 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Sep',
 	cast(sum(case when maand = 10 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Okt',
 	cast(sum(case when maand = 11 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Nov',
 	cast(sum(case when maand = 12 then [FTE Realisatie] else 0 end) as decimal(18,2)) as 'Dec'
from afas.dwh_personeel_fte_cum t00
 join dwh_budgetplaatsen t20
  on t00.kostenplaats_code = t20.kostenplaats_code
where zorgbedrijf is not null
 and t00.jaar = '2016'
group by
 jaar
 order by 1 


select
    t20.zorgbedrijf,
    t00.jaar,
 	cast(sum(case when maand = 01 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 then cast(([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN] )*100.00 as decimal(18,2)) else 0 end) as decimal(18,2)) as 'Jan',
 	cast(sum(case when maand = 02 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 then cast(([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN])*100.00 as decimal(18,2)) else 0 end) as decimal(18,2)) as 'Feb',
 	cast(sum(case when maand = 03 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 then cast(([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN])*100.00 as decimal(18,2)) else 0 end) as decimal(18,2)) as 'Mar',
 	cast(sum(case when maand = 04 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 then cast(([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN])*100.00 as decimal(18,2)) else 0 end) as decimal(18,2)) as 'Apr',
 	cast(sum(case when maand = 05 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 then cast(([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN])*100.00 as decimal(18,2)) else 0 end) as decimal(18,2)) as 'Mei',
 	cast(sum(case when maand = 06 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 then cast(([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN])*100.00 as decimal(18,2)) else 0 end) as decimal(18,2)) as 'Jun',
 	cast(sum(case when maand = 07 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 then cast(([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN])*100.00 as decimal(18,2)) else 0 end) as decimal(18,2)) as 'Jul',
 	cast(sum(case when maand = 08 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 then cast(([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN])*100.00 as decimal(18,2)) else 0 end) as decimal(18,2)) as 'Aug',
 	cast(sum(case when maand = 09 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 then cast(([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN])*100.00 as decimal(18,2)) else 0 end) as decimal(18,2)) as 'Sep',
 	cast(sum(case when maand = 10 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 then cast(([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN])*100.00 as decimal(18,2)) else 0 end) as decimal(18,2)) as 'Okt',
 	cast(sum(case when maand = 11 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 then cast(([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN])*100.00 as decimal(18,2)) else 0 end) as decimal(18,2)) as 'Nov',
 	cast(sum(case when maand = 12 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 then cast(([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN])*100.00 as decimal(18,2)) else 0 end) as decimal(18,2)) as 'Dec'
from afas.dwh_personeel_fte_cum t00
 join dwh_budgetplaatsen t20
  on t00.kostenplaats_code = t20.kostenplaats_code
where zorgbedrijf is not null
 and t00.jaar = '2016'
group by t20.zorgbedrijf, t00.jaar
union all
select
    'Mch Totaal' divisie,
    t00.jaar,
 	(case when maand = 01 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 
                  then cast((sum(DAGEN_ZIEK_EX_ZWANGER)/sum(DIENSTVERBAND_DAGEN))*100.00 as decimal(18,2)) 
                  else 0 end) as 'Jan'
/* 	cast(sum(case when maand = 02 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 then cast(([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN])*100.00 as decimal(18,2)) else 0 end) as decimal(18,2)) as 'Feb',
 	cast(sum(case when maand = 03 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 then cast(([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN])*100.00 as decimal(18,2)) else 0 end) as decimal(18,2)) as 'Mar',
 	cast(sum(case when maand = 04 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 then cast(([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN])*100.00 as decimal(18,2)) else 0 end) as decimal(18,2)) as 'Apr',
 	cast(sum(case when maand = 05 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 then cast(([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN])*100.00 as decimal(18,2)) else 0 end) as decimal(18,2)) as 'Mei',
 	cast(sum(case when maand = 06 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 then cast(([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN])*100.00 as decimal(18,2)) else 0 end) as decimal(18,2)) as 'Jun',
 	cast(sum(case when maand = 07 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 then cast(([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN])*100.00 as decimal(18,2)) else 0 end) as decimal(18,2)) as 'Jul',
 	cast(sum(case when maand = 08 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 then cast(([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN])*100.00 as decimal(18,2)) else 0 end) as decimal(18,2)) as 'Aug',
 	cast(sum(case when maand = 09 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 then cast(([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN])*100.00 as decimal(18,2)) else 0 end) as decimal(18,2)) as 'Sep',
 	cast(sum(case when maand = 10 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 then cast(([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN])*100.00 as decimal(18,2)) else 0 end) as decimal(18,2)) as 'Okt',
 	cast(sum(case when maand = 11 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 then cast(([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN])*100.00 as decimal(18,2)) else 0 end) as decimal(18,2)) as 'Nov',
 	cast(sum(case when maand = 12 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 then cast(([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN])*100.00 as decimal(18,2)) else 0 end) as decimal(18,2)) as 'Dec' */
from afas.dwh_personeel_fte_cum t00
where t00.jaar = '2016'
group by t00.jaar
order by 1,2,3

select
    'Mch Totaal' divisie,
    t00.jaar,
 	sum(cast(case when maand = 01 
                  then ([DAGEN_ZIEK_EX_ZWANGER] / [DIENSTVERBAND_DAGEN] )*100.00 
                  else 0 end as decimal(18,2))) as 'Jan'
from afas.dwh_personeel_fte_cum t00
where t00.jaar = '2016'
 and isnull([DIENSTVERBAND_DAGEN], 0) > 0 
group by t00.jaar
order by 1,2,3

select
    'Mch Totaal' divisie,
    t00.jaar,
 	(sum(DAGEN_ZIEK_EX_ZWANGER)/sum(DIENSTVERBAND_DAGEN))*100.00
from afas.dwh_personeel_fte_cum t00
where t00.jaar = '2016'
and  [FTE verzuim] > 0
group by t00.jaar
order by 1,2,3

select * from afas.dwh_personeel_fte_cum


===============================================================================
*/
