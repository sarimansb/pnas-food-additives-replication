********************************************************************************
* Paper:   Food additives in the U.S. food supply: Regulatory divergence,
*          market concentration, and exposure patterns
*
* Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
*          Vincenzina Caputo
*
* Code:    Sevval Buse Sariman
*
* Purpose: Generates SI Tables S18-S20, which compare the 34 targeted
*          additives with a benchmark set of 10 commonly used ingredients and
*          additives (citric acid, riboflavin, folic acid, niacin, corn syrup,
*          lecithin, sodium carbonate, thiamine, pyridoxine hydrochloride,
*          canola oil):
*
*   Table S18  Product share, purchase-unit share and exposure wedge for
*              each set
*   Table S19  UPC-level OLS of log price per ounce by comparison group
*              (neither, benchmark only, targeted only, both)
*   Table S20  Household-month expenditure on each set (Poisson QMLE,
*              sampling weights, SE clustered by household), benchmark vs.
*              targeted
*
*
* Output:  Table_S18.xlsx, Table_S19.xlsx, Table_S20.xlsx (in the SI Appendix)
********************************************************************************

version 17.0
clear all
set more off

* 0. PATHS
local indir ".../scanner/analysis"
local productdata ".../brandedfood_6_wave2.dta"
local results ".../tables"
cap mkdir "`results'"


* coefficient with stars
capture program drop starcell
program define starcell, rclass
    args b p
    local s = cond(`p'<0.01,"***",cond(`p'<0.05,"**",cond(`p'<0.10,"*","")))
    return local c = string(`b',"%9.3f") + "`s'"
end

* first column wide, other columns medium, bold header with a bottom line
capture program drop xlformat
program define xlformat
    args file ncol width1 width
    mata: b = xl()
    mata: b.load_book("`file'")
    mata: b.set_sheet("SI table")
    mata: b.set_column_width(1, 1, `width1')
    mata: b.set_column_width(2, `ncol', `width')
    mata: b.close_book()
    local lastcol = char(64 + `ncol')
    putexcel set "`file'", sheet("SI table") modify
    putexcel A1:`lastcol'1, bold border(bottom) txtwrap
end

* 1. CATEGORIES
local categories Beverages BreakfastProducts PreparedFoods DairyEggsandMilkAlt ///
    SnacksandConfectionery SpecialNutrition Ingredients ///
    MeatSeafoodAlternatives Produce
local lbl_Beverages               "Beverages"
local lbl_BreakfastProducts       "Breakfast Products"
local lbl_PreparedFoods           "Prepared Foods"
local lbl_DairyEggsandMilkAlt     "Dairy, Eggs & Alternatives"
local lbl_SnacksandConfectionery  "Snacks & Confectionery"
local lbl_SpecialNutrition        "Special Nutrition"
local lbl_Ingredients             "Ingredients & Cooking Aids"
local lbl_MeatSeafoodAlternatives "Meat, Seafood & Alternatives"
local lbl_Produce                 "Produce"

* 2. PRODUCT FILE: one row per USDA UPC, any targeted / any benchmark additive
use "`productdata'", clear
cap drop wave2_any_flag
egen byte wave2_any_flag = rowmax( ///
    citric_acid_flag riboflavin_flag folic_acid_flag niacin_flag ///
    corn_syrup_flag lecithin_flag sodium_carbonate_flag ///
    thiamine_flag pyridoxine_hcl_flag canola_oil_flag)
keep upc_str caseall wave2_any_flag
isid upc_str
tempfile upc_map exposure
save "`upc_map'"

local i = 0

* 3. CATEGORY LOOP
foreach cat of local categories {
    local ++i
    local catlabel "`lbl_`cat''"
    use "`indir'/`cat'_analysis.dta", clear
    capture drop __*
    cap drop caseall wave2_any_flag comparison_group _merge
    merge m:1 upc_str using "`upc_map'", keep(match) nogen

    * 0 neither; 1 benchmark only; 2 targeted only; 3 both
    gen byte comparison_group = wave2_any_flag + 2*caseall
    label define comp 0 "Neither" 1 "Benchmark only" ///
        2 "Targeted only" 3 "Both", replace
    label values comparison_group comp

    * 3A. PREVALENCE OF EACH SET (products with both sets count in each)
    preserve
        bysort upc_str: gen byte tag_upc = (_n == 1)
        gen long total_upcs = tag_upc
        gen long benchmark_upcs = tag_upc*(wave2_any_flag==1)
        gen long targeted_upcs  = tag_upc*(caseall==1)
        gen double total_units = quantity
        gen double benchmark_units = quantity*(wave2_any_flag==1)
        gen double targeted_units  = quantity*(caseall==1)
        collapse (sum) total_upcs benchmark_upcs targeted_upcs ///
            total_units benchmark_units targeted_units
        expand 2
        gen byte set_order = _n-1
        gen str20 additive_set = cond(set_order==0,"Benchmark 10","Targeted 34")
        gen long exposed_upcs = cond(set_order==0,benchmark_upcs,targeted_upcs)
        gen double exposed_units = cond(set_order==0,benchmark_units,targeted_units)
        gen double upc_share_percent = 100*exposed_upcs/total_upcs if total_upcs>0
        gen double unit_share_percent = 100*exposed_units/total_units if total_units>0
        gen double exposure_wedge_pp = unit_share_percent-upc_share_percent
        gen str40 category = "`catlabel'"
        gen byte category_order = `i'
        keep category category_order set_order additive_set total_upcs ///
            exposed_upcs upc_share_percent total_units exposed_units ///
            unit_share_percent exposure_wedge_pp
        capture confirm file "`exposure'"
        if !_rc append using "`exposure'"
        save "`exposure'", replace
    restore

    * 3B. UPC-LEVEL PRICE REGRESSION
    preserve
        drop if missing(price_oz) | price_oz<=0
        collapse (mean) price_oz (firstnm) comparison_group, by(upc_str)
        gen double ln_price_oz = ln(price_oz)
        regress ln_price_oz ib0.comparison_group, vce(robust)
        estimates store p`i'
    restore

    * 3C. HOUSEHOLD-MONTH EXPENDITURE GLM
    preserve
        drop if missing(total_price_paid,household_code,ym,hh_weight)
        gen double spend0 = cond(wave2_any_flag==1,total_price_paid,0)
        gen double spend1 = cond(caseall==1,total_price_paid,0)
        collapse (sum) spend0 spend1 ///
            (firstnm) income married child_under12 employed max_education ///
            white hispanic household_size hh_weight, by(household_code ym)
        reshape long spend, i(household_code ym) j(set_id)
        label define set_lbl 0 "Benchmark 10" 1 "Targeted 34", replace
        label values set_id set_lbl
        egen byte taghh = tag(household_code)
        quietly count if taghh
        local nh`i' = r(N)
        quietly count if set_id==0
        local nhm`i' = r(N)
        glm spend i.set_id##( ///
            ib1.income c.married c.child_under12 c.employed ///
            c.max_education c.white c.hispanic c.household_size i.ym) ///
            [pweight=hh_weight], family(poisson) link(log) ///
            vce(cluster household_code) nolog
        estimates store h`i'
    restore
}

* EXPORT TABLES:
* 4. SI TABLE S18: Panel A (benchmark) and Panel B (targeted) in one sheet
use "`exposure'", clear
gen str15 c1 = string(total_upcs,"%12.0fc")
gen str15 c2 = string(exposed_upcs,"%12.0fc")
gen str15 c3 = string(upc_share_percent,"%9.1f")
gen str15 c4 = string(total_units,"%15.0fc")
gen str15 c5 = string(exposed_units,"%15.0fc")
gen str15 c6 = string(unit_share_percent,"%9.1f")
gen str15 c7 = cond(exposure_wedge_pp>=0,"+","") + ///
    string(exposure_wedge_pp,"%9.1f")
* Panel header rows
expand 2 if category_order==1, gen(hdr)
foreach v of varlist c1-c7 {
    replace `v' = "" if hdr
}
replace category = cond(set_order==0, ///
    "Panel A. Benchmark additives (10)", ///
    "Panel B. Targeted additives (34)") if hdr
replace category_order = 0 if hdr
sort set_order category_order
label var category "Category"
label var c1 "Distinct products"
label var c2 "Products containing set"
label var c3 "Product share (%)"
label var c4 "Purchased units"
label var c5 "Units containing set"
label var c6 "Purchase-unit share (%)"
label var c7 "Exposure wedge (pp)"
export excel category c1-c7 using "`results'/Table_S18.xlsx", ///
    sheet("SI table") firstrow(varlabels) replace
xlformat "`results'/Table_S18.xlsx" 8 30 14
putexcel A2:H2, bold     // Panel A row
putexcel A12:H12, bold   // Panel B row


* 5. SI TABLE S19
local clabels `" "Benchmark only vs neither" "Targeted only vs neither" "Both sets vs neither" "Targeted only minus benchmark only" "Both sets minus benchmark only" "Both sets minus targeted only" "Constant (neither set)" "'
local exprs `" "1.comparison_group" "2.comparison_group" "3.comparison_group" "2.comparison_group - 1.comparison_group" "3.comparison_group - 1.comparison_group" "3.comparison_group - 2.comparison_group" "_cons" "'

tempfile table_s19
tempname Q
postfile `Q' str40 category byte row str45 rowlabel str20 cell ///
    using "`table_s19'", replace
local i = 0
foreach cat of local categories {
    local ++i
    quietly estimates restore p`i'
    local catlabel "`lbl_`cat''"
    forvalues j = 1/7 {
        local lab : word `j' of `clabels'
        local ex  : word `j' of `exprs'
        quietly lincom `ex'
        local se = string(r(se),"%9.3f")
        starcell `=r(estimate)' `=r(p)'
        post `Q' ("`catlabel'") (2*`j'-1) ("`lab'") ("`r(c)'")
        post `Q' ("`catlabel'") (2*`j')   ("")      ("(`se')")
    }
    post `Q' ("`catlabel'") (15) ("N")         (string(e(N),"%12.0fc"))
    post `Q' ("`catlabel'") (16) ("R-squared") (string(e(r2),"%9.3f"))
}
postclose `Q'

use "`table_s19'", clear
gen byte col = .
local i = 0
foreach cat of local categories {
    local ++i
    replace col = `i' if category == "`lbl_`cat''"
}
assert !missing(col)
forvalues k = 1/9 {
    quietly levelsof category if col==`k', local(nm) clean
    local collab`k' `"`nm'"'
}
drop category
reshape wide cell, i(row) j(col)
sort row
label var rowlabel "Price comparison"
forvalues k = 1/9 {
    label var cell`k' "`collab`k''"
}
export excel rowlabel cell* using "`results'/Table_S19.xlsx", ///
    sheet("SI table") firstrow(varlabels) replace
xlformat "`results'/Table_S19.xlsx" 10 34 16

* 6. SI TABLE S20
local rlabels `" "Income \$25–50k" "Income \$50–100k" "Income \$100k+" "Married" "Child under 12" "Employed" "Maximum education" "White" "Hispanic" "Household size" "Constant" "'
local terms "2.income 3.income 4.income married child_under12 employed max_education white hispanic household_size _cons"
local interactions "1.set_id#2.income 1.set_id#3.income 1.set_id#4.income 1.set_id#c.married 1.set_id#c.child_under12 1.set_id#c.employed 1.set_id#c.max_education 1.set_id#c.white 1.set_id#c.hispanic 1.set_id#c.household_size 1.set_id"

tempfile table_s20
tempname P
postfile `P' str40 category byte row str40 rowlabel ///
    str25 benchmark str25 targeted str25 difference ///
    using "`table_s20'", replace
local i = 0
foreach cat of local categories {
    local ++i
    quietly estimates restore h`i'
    local catlabel "`lbl_`cat''"
    post `P' ("`catlabel'") (0) ("`catlabel'") ("") ("") ("")
    forvalues j = 1/11 {
        local lab : word `j' of `rlabels'
        local x   : word `j' of `terms'
        local z   : word `j' of `interactions'
        * b = beta, t = beta + delta, d = delta
        foreach part in b t d {
            if "`part'"=="b" local ex "`x'"
            if "`part'"=="t" local ex "`x' + `z'"
            if "`part'"=="d" local ex "`z'"
            quietly lincom `ex'
            local se = string(r(se),"%9.3f")
            starcell `=r(estimate)' `=r(p)'
            local `part' "`r(c)' (`se')"
        }
        post `P' ("`catlabel'") (`j') ("`lab'") ("`b'") ("`t'") ("`d'")
    }
    post `P' ("`catlabel'") (12) ("Month fixed effects") ("") ("Yes") ("")
    post `P' ("`catlabel'") (13) ("Sampling weights")    ("") ("Yes") ("")
    post `P' ("`catlabel'") (14) ("N of households")     ("") ///
        (string(`nh`i'',"%12.0fc")) ("")
    post `P' ("`catlabel'") (15) ("N of household-months") ("") ///
        (string(`nhm`i'',"%12.0fc")) ("")
}
postclose `P'

use "`table_s20'", clear

gen byte category_order = .
local i = 0
foreach cat of local categories {
    local ++i
    replace category_order = `i' if category == "`lbl_`cat''"
}
assert !missing(category_order)
sort category_order row
label var rowlabel   "Household characteristic"
label var benchmark  "Benchmark 10 (β)"
label var targeted   "Targeted 34 (β + δ)"
label var difference "Targeted - Benchmark (δ)"
export excel rowlabel benchmark targeted difference ///
    using "`results'/Table_S20.xlsx", ///
    sheet("SI table") firstrow(varlabels) replace
xlformat "`results'/Table_S20.xlsx" 4 30 22

forvalues k = 0/8 {
    local r = 2 + 16*`k'
    putexcel A`r', bold
}
