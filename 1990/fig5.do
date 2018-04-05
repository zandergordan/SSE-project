* PROJECT:
* EXTENSION OF: Jan Eeckhout, Roberto Pinheiro, Kurt Schmidheiny
* "Spatial Sorting"
* Forthcoming 2014 in the Journal of Political Economy
* by Alexander Gordan
*
* FILE: 
* fig5.do
*
* DESCRIPTION:
* produce figure 5, the two way graph of large and small city wage and 
* skill distributions
*
* VERSION: 
* 2018-04-04

* ------------------------------
* Figure 5
* ------------------------------

clear all

local year = 1990

* open skill data from IPUMS
use finaldata/skill.dta

* generate variable that identifies observations within metros, so we can do
* things using 1 observation per metro
bysort metarea: gen count_1 = _n

* store percentiles of city size distribution in macros
_pctile pop_est if count_1==1, p(80)
local small_city_cutoff = r(r1)
local scstr = string(`small_city_cutoff', "%9.1f")
_pctile pop_est if count_1==1, p(93)
local large_city_cutoff = r(r1)
local lgstr = string(`large_city_cutoff', "%9.1f")

* define city groups
generate group = .
replace group = 1 if pop_est<=`small_city_cutoff'
replace group = 2 if pop_est>`large_city_cutoff'
generate group1 = (group==1) if ~missing(group)
generate group2 = (group==2) if ~missing(group)

* number of workers and METAREA in sample
sum wage
codebook metarea

* ------------------------------
* Figure 5 left
* ------------------------------

* already same observations for wage and skill
sum wage if missing(utility1) 

* calculate and test selective quantiles of log wage, weighted
foreach quant in 0.1 0.9 {
	local quantpct = 100*`quant'
	quietly qreg lwage if group==1 [pw=earnwt], q(`quant') 
	local pctile`quantpct'_group1 = string(_b[_cons],"%9.2f")
	disp "centile(`quantpct'), group==1: " _b[_cons]
	quietly qreg lwage if group==2 [pw=earnwt], q(`quant') 
	local pctile`quantpct'_group2 = string(_b[_cons],"%9.2f")
	disp "centile(`quantpct'), group==2: " _b[_cons]
	qreg lwage group2 [pw=earnwt], q(`quant')
	local pctile`quantpct'_diff = string(_b[group2],"%9.3f") 
	local pctile`quantpct'_se = string(_se[group2],"%9.3f")
	local pctile`quantpct'_t = string(_b[group2]/_se[group2],"%9.1f")
	local pctile`quantpct'_p = string(ttail(e(df_r), abs(_b[group2]/_se[group2])),"%9.1f")
	if ttail(e(df_r), abs(_b[group2]/_se[group2])) <= 0.01 {
		local pctile`quantpct'_star = "***"
	}
	else if ttail(e(df_r), abs(_b[group2]/_se[group2])) <= 0.05 {
		local pctile`quantpct'_star = "**"
	}
	else if ttail(e(df_r), abs(_b[group2]/_se[group2])) <= 0.1 {
		local pctile`quantpct'_star = "*"
	}
	else {
		local pctile`quantpct'_star = ""
	}
}

* support of kernel density
sum lwage if group==1 | group==2
local depvarmaxsmpl = r(max)
local depvarminsmpl = r(min)
local gap = (`depvarminsmpl'-`depvarmaxsmpl')/99
egen x = fill(`depvarminsmpl'[`gap']`depvarmaxsmpl')
replace x =. if _n>100

* kernel density
#delimit ;
kdensity lwage if group==1 [aw=earnwt], 
    bwidth(0.1) generate(x1 y1) at(x) nograph;
kdensity lwage if group==2 [aw=earnwt], 
    bwidth(0.1) generate(x2 y2) at(x) nograph;
twoway 
    line y1 x1, lpattern(dash) lcolor(black) legend(label(1 "population < `scstr'")) 
    ||
    line y2 x2, lpattern(solid) lcolor(black) legend(label(2 "> `lgstr'"))
	, xtitle("log wage `year'") ytitle("pdf") 
	scheme(s1color) legend(region(lstyle(none)))
	xsize(5.50) ysize(4.28) scale(1)
	note(
	"10th percentile: pop < `scstr' = `pctile10_group1', pop > `lgstr' = `pctile10_group2', diff = `pctile10_diff'`pctile10_star' (`pctile10_se')" 
	"90th percentile: pop < `scstr' = `pctile90_group1', pop > `lgstr' = `pctile90_group2', diff = `pctile90_diff'`pctile90_star' (`pctile90_se')"
);
#delimit cr
drop x1 x2 y1 y2 x

* save graph
graph export "results/figure_5_left_`year'.pdf", replace
graph export "results/figure_5_left_`year'.eps", replace

* ------------------------------
* Figure 5 right
* ------------------------------

* calculate and test selective quantiles of log wage, weighted
foreach quant in 0.1 0.9 {
	local quantpct = 100*`quant'
	quietly qreg lutility1 if group==1 [pw=earnwt], q(`quant') 
	local pctile`quantpct'_group1 = string(_b[_cons],"%9.2f")
	disp "centile(`quantpct'), group==1: " _b[_cons]
	quietly qreg lutility1 if group==2 [pw=earnwt], q(`quant') 
	local pctile`quantpct'_group2 = string(_b[_cons],"%9.2f")
	disp "centile(`quantpct'), group==2: " _b[_cons]
	qreg lutility1 group2 [pw=earnwt], q(`quant')
	local pctile`quantpct'_diff = string(_b[group2],"%9.3f") 
	local pctile`quantpct'_se = string(_se[group2],"%9.3f")
	local pctile`quantpct'_t = string(_b[group2]/_se[group2],"%9.1f")
	local pctile`quantpct'_p = string(ttail(e(df_r), abs(_b[group2]/_se[group2])),"%9.1f")
	if ttail(e(df_r), abs(_b[group2]/_se[group2])) <= 0.01 {
		local pctile`quantpct'_star = "***"
	}
	else if ttail(e(df_r), abs(_b[group2]/_se[group2])) <= 0.05 {
		local pctile`quantpct'_star = "**"
	}
	else if ttail(e(df_r), abs(_b[group2]/_se[group2])) <= 0.1 {
		local pctile`quantpct'_star = "*"
	}
	else {
		local pctile`quantpct'_star = ""
	}
}

* support of kernel density
sum lutility1 if group==1 | group==2
local depvarmaxsmpl = r(max)
local depvarminsmpl = r(min)
local gap = (`depvarminsmpl'-`depvarmaxsmpl')/99
egen x = fill(`depvarminsmpl'[`gap']`depvarmaxsmpl')
replace x =. if _n>100

* kernel density
#delimit ;
kdensity lutility1 if group==1 [aw=earnwt], 
    bwidth(0.1) generate(x1 y1) at(x) nograph;
kdensity lutility1 if group==2 [aw=earnwt], 
    bwidth(0.1) generate(x2 y2) at(x) nograph;
twoway 
    line y1 x1, lpattern(dash) lcolor(black) legend(label(1 "population < `scstr'")) 
    ||
    line y2 x2, lpattern(solid) lcolor(black) legend(label(2 "> `lgstr'"))
	, xtitle("skill (log utility) `year'") ytitle("pdf") 
	scheme(s1color) legend(region(lstyle(none)))
	xsize(5.50) ysize(4.28) scale(1)
	note(
	"10th percentile: pop < `scstr' = `pctile10_group1', pop > `lgstr' = `pctile10_group2', diff = `pctile10_diff'`pctile10_star' (`pctile10_se')" 
	"90th percentile: pop < `scstr' = `pctile90_group1', pop > `lgstr' = `pctile90_group2', diff = `pctile90_diff'`pctile90_star' (`pctile90_se')"
);
#delimit cr
drop x1 x2 y1 y2 x

* save graph
graph export "results/figure_5_right_`year'.pdf", replace
graph export "results/figure_5_right_`year'.eps", replace

