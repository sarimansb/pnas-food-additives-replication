********************************************************************************
* Paper:   Food additives in the U.S. food supply: Regulatory divergence,
*          market concentration, and exposure patterns
*
* Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
*          Vincenzina Caputo
*
* Code:    Sevval Buse Sariman
*
* Purpose: Generates SI Tables S12-S14 for the rank-sensitive analysis,
*          which counts an additive only when it appears among the first
*          ingredients of the list. Uses the ranked analysis files
*          (<category>_analysis_ranked.dta) from rank_additives.do
*
*   Table S12  Panel A: position of each regulatory group's additives in the
*              ingredient list. Panel B: product share, unit share and
*              exposure wedge, binary presence vs. top 10 / 5 / 3
*   Table S13  UPC-level OLS of log price per ounce, top-10 vs. binary
*              classification (robust SE)
*   Table S14  Household-month expenditure (Poisson QMLE, sampling weights,
*              SE clustered by household), top-10 vs. binary
*
* Output:  Table_S12.xlsx, Table_S13.xlsx, Table_S14.xlsx (in the SI Appendix)
********************************************************************************
clear all
set more off

* Paths
local indir  ".../scanner/analysis"
local outdir ".../tables"
capture mkdir "`outdir'"

* Category order = SI order
local categories Beverages BreakfastProducts PreparedFoods DairyEggsandMilkAlt ///
    SnacksandConfectionery SpecialNutrition Ingredients MeatSeafoodAlternatives Produce
local lbl_Beverages               "Beverages"
local lbl_BreakfastProducts       "Breakfast Products"
local lbl_PreparedFoods           "Prepared Foods"
local lbl_DairyEggsandMilkAlt     "Dairy, Eggs & Alternatives"
local lbl_SnacksandConfectionery  "Snacks & Confectionery"
local lbl_SpecialNutrition        "Special Nutrition"
local lbl_Ingredients             "Ingredients & Cooking Aids"
local lbl_MeatSeafoodAlternatives "Meat, Seafood & Alternatives"
local lbl_Produce                 "Produce"

* coefficient with stars 
capture program drop starcell
program define starcell, rclass
    args b p
    local s = cond(`p'<0.01,"***",cond(`p'<0.05,"**",cond(`p'<0.10,"*","")))
    return local c = string(`b',"%9.3f") + "`s'"
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

* Row labels
local s13lab `" "Flagged-permitted" "EU-restricted" "EU-unauthorized" "Constant" "'
local s14lab `" "Income \$25–50k" "Income \$50–100k" "Income \$100k+" "Married" "Child under 12" "Employed" "Maximum education" "White" "Hispanic" "Household size" "Constant" "'
local s14terms "2.income 3.income 4.income married child_under12 employed max_education white hispanic household_size _cons"

* Results files built row by row
tempfile s12 s13 s14
tempname p12 p13 p14
postfile `p12' byte bold str90 c1 str25 c2 str25 c3 str25 c4 str25 c5 ///
    str25 c6 str25 c7 str25 c8 using "`s12'", replace
postfile `p13' byte row str40 rowlabel byte col str40 cell using "`s13'", replace
postfile `p14' byte row str40 rowlabel byte col str40 cell using "`s14'", replace

local i = 0
foreach cat of local categories {
    local ++i
    local catlabel "`lbl_`cat''"
    use "`indir'/`cat'_analysis_ranked.dta", clear
    capture drop __*
    local upc upc_x

    * ---------------- S12 PANEL A: one row per UPC (groups overlap)
    post `p12' (1) ("`catlabel'") ("") ("") ("") ("") ("") ("") ("")
    post `p12' (1) ("Panel A. Ingredient-list position among products containing each regulatory case additives") ///
        ("") ("") ("") ("") ("") ("") ("")
    post `p12' (1) ("Regulatory group") ("Products containing group") ///
        ("Median earliest rank") ("Median normalized position") ///
        ("Mean normalized position") ("Top 3 (%)") ("Top 5 (%)") ("Top 10 (%)")
    preserve
        bysort `upc': keep if _n==1
        foreach g in any flagged restricted unauth {
            if "`g'"=="any"        local glabel "Any targeted additive"
            if "`g'"=="flagged"    local glabel "Flag-permitted"
            if "`g'"=="restricted" local glabel "EU-restricted"
            if "`g'"=="unauth"     local glabel "EU-unauthorized"
            quietly count if flagcount_`g'>0
            local n = r(N)
            quietly summarize highest_rank_`g' if flagcount_`g'>0, detail
            local mr = r(p50)
            quietly summarize minpos_`g' if flagcount_`g'>0, detail
            local mp  = r(p50)
            local avg = r(mean)
            foreach k in 3 5 10 {
                quietly count if top`k'_`g'==1
                local p`k' = cond(`n'>0,100*r(N)/`n',.)
                local t`k' = cond(`p`k''==0,"0",string(`p`k'',"%9.2f"))
            }
            post `p12' (0) ("`glabel'") (string(`n',"%12.0fc")) ///
                (string(`mr',"%9.0g")) (string(`mp',"%9.2f")) ///
                (string(`avg',"%9.2f")) ("`t3'") ("`t5'") ("`t10'")
        }
    restore

    * ---------------- S12 PANEL B: units from transactions, products from UPCs
    post `p12' (1) ("Panel B. Rank-sensitive product prevalence and purchase-weighted exposure") ///
        ("") ("") ("") ("") ("") ("") ("")
    post `p12' (1) ("Specification") ("Product share (%)") ("Unit share (%)") ///
        ("Exposure wedge (pp)") ("") ("") ("") ("")
    foreach s in targeted top10_any top5_any top3_any {
        if "`s'"=="targeted"  local slabel "Binary presence"
        if "`s'"=="top10_any" local slabel "Top 10"
        if "`s'"=="top5_any"  local slabel "Top 5"
        if "`s'"=="top3_any"  local slabel "Top 3"
        quietly summarize quantity if !missing(`s'), meanonly
        local tot = r(sum)
        quietly summarize quantity if `s'==1, meanonly
        local ush = cond(`tot'>0,100*r(sum)/`tot',.)
        preserve
            bysort `upc': keep if _n==1
            quietly count if !missing(`s')
            local nt = r(N)
            quietly count if `s'==1
            local psh = cond(`nt'>0,100*r(N)/`nt',.)
        restore
        post `p12' (0) ("`slabel'") (string(`psh',"%9.2f")) ///
            (string(`ush',"%9.2f")) (string(`ush'-`psh',"%9.2f")) ///
            ("") ("") ("") ("")
    }

    * ---------------- S13: UPC-level price, Top-10 vs Binary
    preserve
        keep if !missing(price_oz) & price_oz>0
        collapse (mean) price_oz (firstnm) case case_top10, by(`upc')
        gen double ln_price_oz = ln(price_oz)
        foreach s in 1 2 {
            local v    = cond(`s'==1,"case_top10","case")
            local spec = cond(`s'==1,"Top-10 occurrence","Binary occurrence")
            local col  = 2*`i' - 2 + `s'
            post `p13' (1) ("Regulatory group") (`col') (cond(`s'==1,"`catlabel'",""))
            post `p13' (2) ("") (`col') ("`spec'")
            quietly regress ln_price_oz ib0.`v' if !missing(`v'), vce(robust)
            local N  = e(N)
            local r2 = e(r2)
            forvalues g = 1/4 {
                local lab : word `g' of `s13lab'
                local ex = cond(`g'==4,"_cons","`g'.`v'")
                local c ""
                local sec ""
                capture quietly lincom `ex'
                if _rc==0 & r(se)>0 & !missing(r(se)) {
                    local sec = "(" + string(r(se),"%9.3f") + ")"
                    starcell `=r(estimate)' `=r(p)'
                    local c "`r(c)'"
                }
                post `p13' (2*`g'+1) ("`lab'") (`col') ("`c'")
                post `p13' (2*`g'+2) ("")      (`col') ("`sec'")
            }
            post `p13' (11) ("N")         (`col') (string(`N',"%12.0fc"))
            post `p13' (12) ("R-squared") (`col') (string(`r2',"%9.3f"))
        }
    restore

    * ---------------- S14: household-month expenditure, Top-10 vs Binary
    preserve
        drop if missing(total_price_paid,household_code,ym,hh_weight)
        gen double spend1 = cond(top10_any==1,total_price_paid,0) if !missing(top10_any)
        gen double spend2 = cond(targeted==1,total_price_paid,0) if !missing(targeted)
        collapse (sum) spend1 spend2 ///
            (firstnm) income married child_under12 employed max_education ///
            white hispanic household_size hh_weight, by(household_code ym)
        foreach s in 1 2 {
            local spec = cond(`s'==1,"Top-10 occurrence","Binary occurrence")
            local col  = 2*`i' - 2 + `s'
            post `p14' (1) ("Household characteristic") (`col') (cond(`s'==1,"`catlabel'",""))
            post `p14' (2) ("") (`col') ("`spec'")
            quietly glm spend`s' ib1.income married child_under12 employed ///
                max_education white hispanic household_size i.ym [pweight=hh_weight], ///
                family(poisson) link(log) vce(cluster household_code) nolog
            forvalues j = 1/11 {
                local lab : word `j' of `s14lab'
                local x   : word `j' of `s14terms'
                quietly lincom `x'
                local sec = "(" + string(r(se),"%9.3f") + ")"
                starcell `=r(estimate)' `=r(p)'
                post `p14' (2*`j'+1) ("`lab'") (`col') ("`r(c)'")
                post `p14' (2*`j'+2) ("")      (`col') ("`sec'")
            }
            post `p14' (25) ("Month fixed effects") (`col') ("Yes")
            post `p14' (26) ("Sampling weights")    (`col') ("Yes")
            * N rows are shown once per category (merged across both columns)
            post `p14' (27) ("N of household-months") (`col') ///
                (cond(`s'==1,string(e(N),"%12.0fc"),""))
            post `p14' (28) ("N of households") (`col') ///
                (cond(`s'==1,string(e(N_clust),"%12.0fc"),""))
        }
    restore
}
postclose `p12'
postclose `p13'
postclose `p14'

* ---------------- EXPORT S12
use "`s12'", clear
local f "`outdir'/Table_S12.xlsx"
export excel c1-c8 using "`f'", sheet("SI table") replace
xltidy "`f'" 8 34 16

* ---------------- EXPORT S13 AND S14 
foreach t in 13 14 {
    use "`s`t''", clear
    reshape wide cell, i(row) j(col)
    sort row
    gen byte bold = row<=2
    local f "`outdir'/Table_S`t'.xlsx"
    export excel rowlabel cell* using "`f'", sheet("SI table") replace
    xltidy "`f'" 19 28 14
    * Merge each category name over its Top-10 / Binary pair
    local mrows = cond(`t'==13,"1","1 27 28")
    forvalues k = 1/9 {
        local L1 = char(65 + 2*`k' - 1)
        local L2 = char(65 + 2*`k')
        foreach r of local mrows {
            putexcel `L1'`r':`L2'`r', merge hcenter
        }
    }
}
