* PROJECT:

* EXTENSION OF: Jan Eeckhout, Roberto Pinheiro, Kurt Schmidheiny
* "Spatial Sorting"
* Forthcoming 2014 in the Journal of Political Economy
* by Alexander Gordan
*
* FILE: 
* data.do
*
* DESCRIPTION:
* this file generates the data files and variables used for the empirical analysis 
* from IPUMS USA data
*
*
* VERSION: 
* 2018-04-04

clear all
set matsize 2500

local year = 1990

* ------------------------------
* METAREA Population 
* ------------------------------

* DATA SOURCE:
* U.S. Census Bureau
*
* WEBLINK:
* https://usa.ipums.org/usa
*
* LOCAL FILE LOCATION:
* ../IPUMS_data/usa.dta

* use USA data, keep only relevant year
use ../IPUMS_data/usa.dta, clear
keep if year == `year'

* drop data on unidentified and rural areas
drop if metarea==0

* estimate population for each METAREA
bysort metarea: egen pop_est = sum(perwt)

* collapse to METAREA level
collapse (first) pop_est, by(metarea)
label variable pop_est "METAREA population (perwt estimate)"

* in logs
generate lpop_est = log(pop_est)
label variable lpop_est "log METAREA population (perwt estimate)"

* save
save temp/population.dta, replace


* ------------------------------
* Hedonic Housing Prices 
* ------------------------------

* DATA SOURCE:
* U.S. Census Bureau, Decennial Census and ACS
* provided by Minnesota Population Center, IPUMS-USA
*
* WEBLINK:
* https://usa.ipums.org/usa/
*
* VARIABLES IN RAW DATA:
* year datanum serial hhwt statefip metro metarea metaread puma 
* gq farm ownershp ownershpd rent rooms builtyr2 unitsstr 
* pernum perwt age bpl bpld labforce wkswork2 uhrswork incwage 
*
* LOCAL FILE LOCATION:
* ../IPUMS_data/usa.dta

* open ACS raw data
use ../IPUMS_data/usa.dta, clear

* only 2009 data
keep if year==`year'

* drop group quarters (institutions), drop 2000 definition of families (e.g. may contain 54 members)
drop if gq==3 | gq==4 | gq==5

* drop farmhouses
drop if farm~=1 

* drop mobile homes, trailers, boats, tents, ...
drop if unitsstr==01 | unitsstr==02

* collapse to household level
foreach v of var * {
	local l`v' : variable label `v'
	if `"`l`v''"' == "" {
		local l`v' "`v'" 
	}
}
collapse (first) hhwt-incearn (count) hhmembers=hhwt, by(year datanum serial) 
foreach v of var * {
	label var `v' "`l`v''"
}
label var hhmembers "Number of household members in dataset"

* drop if not in known metro area
drop if metarea==0

* generate price vars
replace rent = . if rent==0
generate lrent = log(rent)

* top code number of rooms at 9 (max is 28 in later ACS, 9 in earlier PUMS samples)
replace rooms = 9 if rooms > 9
tabulate rooms, nolabel

* Census 1990 labels "builtyr"
label define builtyr 00	"NA", add
label define builtyr 01	"0-1 year old", add
label define builtyr 02	"2-5 years", add
label define builtyr 03	"6-10 years", add
label define builtyr 04	"11-20 years", add
label define builtyr 05	"21-30 years", add
label define builtyr 06	"31-40 years (31+ in 1960 and 1970)", add
label define builtyr 07	"41-50 years (41+ in 1980)", add
label define builtyr 08	"51-60 years (51+ in 1990)", add
label define builtyr 09	"61+ years", add
label values builtyr builtyr
tabulate builtyr

* Census 1990 labels "unitstr"
label define unitsstr 00	"N/A", add
label define unitsstr 01	"Mobile home or trailer", add	
label define unitsstr 02	"Boat, tent, van, other", add	
label define unitsstr 03	"1-family house, detached", add
label define unitsstr 04	"1-family house, attached", add
label define unitsstr 05	"2-family building", add	
label define unitsstr 06	"3-4 family building", add		
label define unitsstr 07	"5-9 family building", add		
label define unitsstr 08	"10-19 family building", add	
label define unitsstr 09	"20-49 family building", add	
label define unitsstr 10	"50+ family building", add		
label values unitsstr unitsstr
tabulate unitsstr

* IPUMS labels "metarea"
label values metarea metarea_lbl

* define sample, rules out missing values in rent
generate samplemetarea = (ownershpd==22 & rent>0 & ~missing(rent))

* hedonic regression with metarea fixed effects
* reference groups are 4="4 rooms", 8="1990-1994", 3="1-family detached"
* note: xtreg cannot deal with weights within areas
reg lrent b4.rooms b3.builtyr b3.unitsstr i.metarea [aw=hhwt] if samplemetarea
estimates store lrent_metarea

* sample size for Table 4 footer
sum rent if e(sample)
codebook metarea if e(sample)

* store metarea fixed effects in data
levelsof metarea if samplemetarea
generate lrentindexmetarea = .
foreach lev in `r(levels)' {
	replace lrentindexmetarea = _b[_cons]+_b[`lev'.metarea] if metarea==`lev'
}
generate rentindexmetarea = exp(lrentindexmetarea)

* number of observations per area
bysort metarea:      egen rentobsmetarea = total(samplemetarea)

* weight of all observations per area
bysort metarea:      egen renthhwtmetarea = total(hhwt*samplemetarea)

* save estimation results: Table 4
estout * using "results/table4.txt", stats(r2 N N_g, fmt(%12.4f)) cells(b(star fmt(%9.4f)) se(fmt(%9.4f))) starlevels(* 0.10 ** 0.05 *** 0.01) margin legend replace

* labels
label variable lrentindexmetarea  "Log housing rent, monthly, metarea hedonic price index, `year'"
label variable rentindexmetarea   "Housing rent, monthly, metarea hedonic price index, `year'"
label variable rentobsmetarea 	   "Number of observed rental prices in metarea, `year'"
label variable renthhwtmetarea    "Total household weights of observed prices in metarea, `year'"

* only keep one obs per METAREA
bysort metarea: egen seqmetarea = seq() if ~missing(rentindexmetarea)
keep if seqmetarea==1

* standardize index to mean=1 across METAREAs
sum rentindexmetarea [aw=renthhwtmetarea]
replace rentindexmetarea = rentindexmetarea/r(mean)
replace lrentindexmetarea = log(rentindexmetarea)		

* save rent index for METAREA
keep metarea lrentindexmetarea rentindexmetarea rentobsmetarea renthhwtmetarea
order metarea lrentindexmetarea rentindexmetarea rentobsmetarea renthhwtmetarea
save temp/housepricemetarea.dta, replace

* ------------------------------
*  Wage and skill from Census
* ------------------------------

* U.S. Census Bureau
* provided by Minnesota Population Center, IPUMS-USA
*
* WEBLINK:
* https://usa.ipums.org/usa/
*
* VARIABLES IN RAW DATA:
* year datanum serial hhwt statefip metro metarea metaread puma 
* gq farm ownershp ownershpd rent rooms builtyr2 unitsstr 
* pernum perwt age bpl bpld labforce wkswork2 uhrswork incwage 
*
* LOCAL FILE LOCATION:
* ../IPUMS_data/usa.dta

* open USA raw data, keep only relevant year
use ../IPUMS_data/usa.dta, clear
keep if year == `year'

* id names as in cps
rename serial hhid
rename pernum pid
order year hhid pid

* yearly wage for full time workers, full year workers
replace incwage = . if incwage==999999 | incwage==999998
gen wage = .
replace wage = incwage/48.5 if labforce==2 & wkswork2==5 & uhrswork>=36 & uhrswork<=60 // 48-49 weeks
replace wage = incwage/51 if labforce==2 & wkswork2==6 & uhrswork>=36 & uhrswork<=60 // 50-52 weeks	
replace wage = . if wage <= 0
label var wage "Weekly wage full-time, full-year workers, `year' (Source: ACS)"

* drop lowest 0.1% of observations to deal with obvious outliers
egen wagemin = pctile(wage), p(0.1) 
replace wage = . if wage <= wagemin
replace wage = wagemin if wage < wagemin
** the above line seems like an artefact of some kind, doesn't do anything.
sum wage, detail
	
* log wage	
gen lwage = log(wage)
label var lwage "= log(wage)"
	
* weight, same variable name as CPS
generate earnwt = perwt/100
label var earnwt "Person weight, =perwt/100"
	
* birthplace
generate birthplace = 1 if bpl<=99
replace birthplace = 2 if bpl>=100 & bpl<150
replace birthplace = 3 if bpl>=150
label var birthplace "Birthplace" 
label define birthplace 1 "Born in US" 2 "Born in Puerto Rico or US Outlying Area" 3 "Born abroad" 

* drop if not in identified metro area
drop if metarea == 0

* merge METAREA population from Census
merge m:1 metarea using temp/population.dta, keep(master match)
drop _merge

* merge METAREA housing price
merge m:1 metarea using temp/housepricemetarea.dta, keep(master match)
drop _merge

* drop observations with missing wage
keep if ~missing(wage)

* baseline wage-based skill measure
* Cobb-Douglas utility
local a = 0.24
local K = 1/(`a'^`a'*(1-`a')^(1-`a'))
generate utility1 = wage/(rentindexmetarea^(`a')*`K')
label var utility1 "Skill: metarea rentindex"
generate lutility1 = log(utility1)
label var lutility1 "Skill: Cobb-Douglas, metarea rentindex"

* alternative skill measure
* Stone-Geary utility
local a = 0.224 
local h = 27.7 
local K = 1/(`a'^`a'*(1-`a')^(1-`a'))
generate utility4 = 1/`K'*(wage/rentindexmetarea-`h')* rentindexmetarea ^(1-`a')
label var utility4 "Skill: metarea rentindex"
generate lutility4 = log(utility4)
label var lutility4 "Skill: Stone-Geary, metarea rentindex"

* alternative skill measure
* Stone-Geary utility (h=250)
local a = 0.224 
local h = 250 
local K = 1/(`a'^`a'*(1-`a')^(1-`a'))
generate utility5 = 1/`K'*(wage/rentindexmetarea-`h')* rentindexmetarea ^(1-`a')
label var utility5 "Skill: cbsa rentindex"
generate lutility5 = log(utility5)
label var lutility5 "Skill: Stone-Geary (h=250), metarea rentindex"

* save
order year
save finaldata/skill.dta, replace


























