********************************************************************************
* Paper:   Food additives in the U.S. food supply: Regulatory divergence,
*          market concentration, and exposure patterns
*
* Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
*          Vincenzina Caputo
*
* Code:    Sevval Buse Sariman
*
* Purpose: Generates SI Tables S21-S23, which compare the full sample with a
*          restricted sample of products last modified in or before 2023.
*          The restricted sample drops all transactions for products whose
*          modified_date is after 2023 or missing. The main exposure, price
*          and household-expenditure analyses are then rerun on it.
*
* Output:  Table_S21.xlsx, Table_S22.xlsx, Table_S23.xlsx (in the SI Appendix)
********************************************************************************
version 17
clear all
set more off


local indir ".../analysis"
local results ".../tables"
capture mkdir "`results'"

* Category order 
local categories Beverages BreakfastProducts DairyEggsandMilkAlt Ingredients ///
    MeatSeafoodAlternatives PreparedFoods Produce SnacksandConfectionery ///
    SpecialNutrition
local lbl_Beverages               "Beverages"
local lbl_BreakfastProducts       "Breakfast Products"
local lbl_DairyEggsandMilkAlt     "Dairy, Eggs & Alternatives"
local lbl_Ingredients             "Ingredients & Cooking Aids"
local lbl_MeatSeafoodAlternatives "Meat, Seafood & Alternatives"
local lbl_PreparedFoods           "Prepared Foods"
local lbl_Produce                 "Produce"
local lbl_SnacksandConfectionery  "Snacks & Confectionery"
local lbl_SpecialNutrition        "Special Nutrition"

* Helper: coefficient with stars and SE, e.g. "-0.114*** (0.031)"
capture program drop starcell
program define starcell, rclass
    args b se p
    local s = cond(`p'<0.01,"***",cond(`p'<0.05,"**",cond(`p'<0.10,"*","")))
    return local c = string(`b',"%9.3f") + "`s'" + " (" + string(`se',"%9.3f") + ")"
end

* Helper: column widths, centered numbers, bold rows where bold==1
capture program drop xltidy
program define xltidy
    args file ncol width1 width
    mata: b = xl(); b.load_book("`file'"); b.set_sheet("SI table"); b.set_column_width(1, 1, `width1'); b.set_column_width(2, `ncol', `width'); b.close_book()
    local L = char(64 + `ncol')
    putexcel set "`file'", sheet("SI table") modify
    putexcel B1:`L'`=_N', hcenter
    forvalues n = 1/`=_N' {
        if bold[`n'] putexcel A`n':`L'`n', bold
    }
end

local s22lab `" "Flag-permitted" "EU-restricted" "EU-unauthorized" "Constant" "'
local s22terms "1.case 2.case 3.case _cons"
local s23lab `" "Income \$25-50k" "Income \$50-100k" "Income \$100k+" "Married" "Child under 12" "Employed" "Maximum education" "White" "Hispanic" "Household size" "Constant" "'
local s23terms "2.income 3.income 4.income married child_under12 employed max_education white hispanic household_size _cons"

* Results built row by row
tempfile s21 s22 s23
tempname p21 p22 p23
postfile `p21' byte bold str40 c1 ///
    str60 c2 str60 c3 str60 c4 str60 c5 ///
    str60 c6 str60 c7 str60 c8 ///
    using "`s21'", replace
postfile `p22' byte bold str40 c1 str25 c2 str25 c3 using "`s22'", replace
postfile `p23' byte row str40 rowlabel byte col str40 cell using "`s23'", replace

post `p21' (1) ("Category") ("UPCs excluded by restriction") ///
    ("% UPCs with targeted additives, restricted sample") ///
    ("% UPCs with targeted additives, full sample") ///
    ("% Units purchased, restricted sample") ("% Units purchased, full sample") ///
    ("Exposure wedge, restricted sample") ("Exposure wedge, full sample")
post `p22' (1) ("Regulatory group") ("Full sample") ("Restricted sample")
post `p22' (1) ("") ("Coefficient (SE)") ("Coefficient (SE)")

local i = 0
foreach cat of local categories {
    local ++i
    local catlabel "`lbl_`cat''"
    capture confirm file "`indir'/`cat'_analysis.dta"
    if _rc {
        di as error "Skipping `cat': file missing"
        continue
    }
    di as result "Processing `catlabel'"
    use "`indir'/`cat'_analysis.dta", clear
    capture drop __*

    * ---------------- modified_date -> modified_year
    capture drop modified_year
    capture confirm numeric variable modified_date
    if !_rc {
        local fmt = lower("`: format modified_date'")
        if strpos("`fmt'","%td")      gen int modified_year = year(modified_date)
        else if strpos("`fmt'","%tc") gen int modified_year = year(dofc(modified_date))
        else {
            gen int modified_year = modified_date if inrange(modified_date,1900,2100)
            replace modified_year = year(modified_date) if missing(modified_year) & !missing(modified_date)
        }
    }
    else {
        gen double md = daily(substr(strtrim(modified_date),1,10),"YMD")
        replace md = daily(substr(strtrim(modified_date),1,10),"MDY") if missing(md)
        replace md = daily(substr(strtrim(modified_date),1,10),"DMY") if missing(md)
        gen int modified_year = year(md)
        drop md
    }
    gen byte by2023 = !missing(modified_year) & modified_year<=2023

    * ---------------- s = 0 full sample, s = 1 restricted sample
    forvalues s = 0/1 {
        if `s'==1 keep if by2023

        * S21: product share, unit share, wedge
        preserve
            bysort upc_x: keep if _n==1
            quietly count
            local nupc`s' = r(N)
            quietly count if targeted==1
            local upcsh`s' = 100*r(N)/`nupc`s''
        restore
        quietly summarize quantity, meanonly
        local tot = r(sum)
        quietly summarize quantity if targeted==1, meanonly
        local unitsh`s' = 100*r(sum)/`tot'
        local wedge`s'  = `unitsh`s'' - `upcsh`s''

        * S22: UPC-level OLS of log price per ounce
        preserve
            drop if missing(price_oz) | price_oz<=0
            collapse (mean) price_oz, by(upc_x case)
            isid upc_x
            gen double ln_price_oz = ln(price_oz)
            regress ln_price_oz ib0.case, vce(robust)
            forvalues g = 1/4 {
                local x : word `g' of `s22terms'
                quietly lincom `x'
                starcell `=r(estimate)' `=r(se)' `=r(p)'
                local b`g'_`s' "`r(c)'"
            }
            local N`s'  = string(e(N),"%12.0fc")
            local r2`s' = string(e(r2),"%9.3f")
        restore

        * S23: household-month expenditure on targeted products
        preserve
            drop if missing(total_price_paid,household_code,ym,hh_weight)
            gen double spend = cond(targeted==1,total_price_paid,0)
            collapse (sum) spend ///
                (firstnm) income married child_under12 employed max_education ///
                white hispanic household_size hh_weight, by(household_code ym)
            glm spend ib1.income married child_under12 employed max_education ///
                white hispanic household_size i.ym [pweight=hh_weight], ///
                family(poisson) link(log) vce(cluster household_code) nolog
            local col = 2*`i' - 1 + `s'
            post `p23' (1) ("Household characteristic") (`col') (cond(`s'==0,"`catlabel'",""))
            post `p23' (2) ("") (`col') (cond(`s'==0,"Full sample","Restricted sample"))
            forvalues j = 1/11 {
                local x   : word `j' of `s23terms'
                local lab : word `j' of `s23lab'
                quietly lincom `x'
                starcell `=r(estimate)' `=r(se)' `=r(p)'
                post `p23' (`j'+2) ("`lab'") (`col') ("`r(c)'")
            }
            post `p23' (14) ("Month fixed effects")   (`col') ("Yes")
            post `p23' (15) ("Sampling weights")      (`col') ("Yes")
            post `p23' (16) ("N of households")       (`col') (string(e(N_clust),"%12.0fc"))
            post `p23' (17) ("N of household-months") (`col') (string(e(N),"%12.0fc"))
        restore
    }

    * ---------------- S21 row
    local excl = 100*(`nupc0' - `nupc1')/`nupc0'
    post `p21' (0) ("`catlabel'") (string(`excl',"%9.1f") + "%") ///
        (string(`upcsh1',"%9.1f") + "%")  (string(`upcsh0',"%9.1f") + "%") ///
        (string(`unitsh1',"%9.1f") + "%") (string(`unitsh0',"%9.1f") + "%") ///
        (string(`wedge1',"%9.1f") + " pp") (string(`wedge0',"%9.1f") + " pp")

    * ---------------- S22 block
    post `p22' (1) ("`catlabel'") ("") ("")
    forvalues g = 1/4 {
        local lab : word `g' of `s22lab'
        post `p22' (0) ("`lab'") ("`b`g'_0'") ("`b`g'_1'")
    }
    post `p22' (0) ("N")         ("`N0'")  ("`N1'")
    post `p22' (0) ("R-squared") ("`r20'") ("`r21'")
}
postclose `p21'
postclose `p22'
postclose `p23'

* ---------------- EXPORT S21
use "`s21'", clear
local f "`results'/Table_S21.xlsx"
export excel c1-c8 using "`f'", sheet("SI table") replace
xltidy "`f'" 8 30 16
putexcel A1:H1, txtwrap

* ---------------- EXPORT S22
use "`s22'", clear
local f "`results'/Table_S22.xlsx"
export excel c1-c3 using "`f'", sheet("SI table") replace
xltidy "`f'" 3 30 22

* ---------------- EXPORT S23 (two header rows, categories in pairs)
use "`s23'", clear
reshape wide cell, i(row) j(col)
sort row
gen byte bold = row<=2
local f "`results'/Table_S23.xlsx"
export excel rowlabel cell* using "`f'", sheet("SI table") replace
xltidy "`f'" 19 26 18
forvalues k = 1/9 {
    local L1 = char(65 + 2*`k' - 1)
    local L2 = char(65 + 2*`k')
    putexcel `L1'1:`L2'1, merge hcenter
}
