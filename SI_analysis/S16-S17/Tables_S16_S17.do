********************************************************************************
* Paper:   Food additives in the U.S. food supply: Regulatory divergence,
*          market concentration, and exposure patterns
*
* Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
*          Vincenzina Caputo
*
* Code:    Sevval Buse Sariman
*
* Purpose: Generates SI Tables S16-S17, which compare the dominant-count
*          classification with the original classification of products.
*
*   Dominant-count classification: each product is assigned to the group
*   with the largest number of detected targeted additives. Ties go to the
*   more stringent group (EU-unauthorized > EU-restricted > Flag-permitted).
*   Original classification: variable case (most stringent group present).
*
* Output:  Table_S16.xlsx, Table_S17.xlsx (in the SI Appendix)
********************************************************************************

version 17
clear all
set more off

* Paths
local indir ".../scanner/analysis"
local results   ".../tables"
capture mkdir "`results'"

* Category order = SI order (alphabetical)
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

* Helper: coefficient with stars, e.g. "-0.114***"
capture program drop starcell
program define starcell, rclass
    args b p
    local s = cond(`p'<0.01,"***",cond(`p'<0.05,"**",cond(`p'<0.10,"*","")))
    return local c = string(`b',"%9.3f") + "`s'"
end

* Helper: column widths, centered numbers, bold rows where bold==1
* (data in memory must be in the same row order as the Excel sheet)
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

local glabs `" "No targeted additive" "Flag-permitted" "EU-restricted" "EU-unauthorized" "'
local s17lab `" "Flag-permitted" "EU-restricted" "EU-unauthorized" "Constant" "'

* Results built row by row
tempfile s16 s17
tempname p16 p17
postfile `p16' byte bold str40 c1 str25 c2 str25 c3 str25 c4 str25 c5 ///
    using "`s16'", replace
postfile `p17' byte row str40 rowlabel byte col str40 cell using "`s17'", replace

* S16 header rows
post `p16' (1) ("Regulatory group") ("Dominant-count classification") ("") ///
    ("Original classification") ("")
post `p16' (1) ("") ("Unique UPCs") ("Mean price/oz (SD)") ///
    ("Unique UPCs") ("Mean price/oz (SD)")

local i = 0
foreach cat of local categories {
    local ++i
    local catlabel "`lbl_`cat''"
    use "`indir'/`cat'_analysis.dta", clear
    capture drop __*

    * ---------------- DOMINANT-COUNT CLASSIFICATION
    foreach v in flagged_permitted_count EU_restricted_count EU_unauthorized_count {
        capture confirm numeric variable `v'
        if _rc destring `v', replace
    }
    assert !missing(flagged_permitted_count, EU_restricted_count, EU_unauthorized_count)
    gen int maxcount = max(flagged_permitted_count, EU_restricted_count, ///
        EU_unauthorized_count)
    gen byte case_number = 0
    replace case_number = 1 if maxcount>0 & flagged_permitted_count==maxcount
    replace case_number = 2 if maxcount>0 & EU_restricted_count==maxcount
    replace case_number = 3 if maxcount>0 & EU_unauthorized_count==maxcount

    assert targeted == (maxcount>0)
    assert (case_number==0) == (case==0)
    bysort upc_x: assert case_number == case_number[1]
    bysort upc_x: assert case == case[1]

    * ---------------- UPC-level price data
    drop if missing(price_oz) | price_oz<=0
    collapse (mean) price_oz (firstnm) case case_number, by(upc_x)
    gen double ln_price_oz = ln(price_oz)

    * ---------------- S16: unique UPCs and mean price (SD) by group
    post `p16' (1) ("`catlabel'") ("") ("") ("") ("")
    forvalues g = 0/3 {
        local glab : word `=`g'+1' of `glabs'
        * k = 1 dominant count, k = 2 original
        foreach k in 1 2 {
            local v = cond(`k'==1,"case_number","case")
            quietly summarize price_oz if `v'==`g'
            local n`k' = r(N)
            local m`k' = r(mean)
            local s`k' = r(sd)
        }
        post `p16' (0) ("`glab'") ///
            (string(`n1',"%12.0fc")) ///
            (cond(`n1'>0, char(36) + string(`m1',"%9.3f") + " (" + string(`s1',"%9.3f") + ")", "")) ///
            (string(`n2',"%12.0fc")) ///
            (cond(`n2'>0, char(36) + string(`m2',"%9.3f") + " (" + string(`s2',"%9.3f") + ")", ""))
    }

    * ---------------- S17: OLS of log price per ounce
    foreach k in 1 2 {
        local v    = cond(`k'==1,"case_number","case")
        local spec = cond(`k'==1,"Dominant-count classification","Original classification")
        local col  = 2*`i' - 2 + `k'
        post `p17' (1) ("Regulatory group") (`col') (cond(`k'==1,"`catlabel'",""))
        post `p17' (2) ("") (`col') ("`spec'")
        quietly regress ln_price_oz ib0.`v', vce(robust)
        local N  = e(N)
        local r2 = e(r2)
        forvalues g = 1/4 {
            local lab : word `g' of `s17lab'
            local ex = cond(`g'==4,"_cons","`g'.`v'")
            local c ""
            local sec ""
            capture quietly lincom `ex'
            if _rc==0 & r(se)>0 & !missing(r(se)) {
                local sec = "(" + string(r(se),"%9.3f") + ")"
                starcell `=r(estimate)' `=r(p)'
                local c "`r(c)'"
            }
            post `p17' (2*`g'+1) ("`lab'") (`col') ("`c'")
            post `p17' (2*`g'+2) ("")      (`col') ("`sec'")
        }
        post `p17' (11) ("Observations") (`col') (string(`N',"%12.0fc"))
        post `p17' (12) ("R-squared")    (`col') (string(`r2',"%9.3f"))
    }
}
postclose `p16'
postclose `p17'

* ---------------- EXPORT S16
use "`s16'", clear
local f "`results'/Table_S16.xlsx"
export excel c1-c5 using "`f'", sheet("SI table") replace
xltidy "`f'" 5 30 20
putexcel B1:C1, merge hcenter
putexcel D1:E1, merge hcenter

* ---------------- EXPORT S17
use "`s17'", clear
reshape wide cell, i(row) j(col)
sort row
gen byte bold = row<=2
local f "`results'/Table_S17.xlsx"
export excel rowlabel cell* using "`f'", sheet("SI table") replace
xltidy "`f'" 19 22 16
* Merge each category name over its two columns
forvalues k = 1/9 {
    local L1 = char(65 + 2*`k' - 1)
    local L2 = char(65 + 2*`k')
    putexcel `L1'1:`L2'1, merge hcenter
}

