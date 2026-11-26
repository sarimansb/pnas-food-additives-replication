********************************************************************************
* Paper:   Food additives in the U.S. food supply: Regulatory divergence,
*          market concentration, and exposure patterns
*
* Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
*          Vincenzina Caputo
*
* Code:    Sevval Buse Sariman
*
* Purpose: This do-file generates the main tables and SI Tables S9-S10 for 
*		   the nine food and beverage categories, using the category-specific 
* 		   analysis datasets created in the data-cleaning step. 
*
*   Each table is exported to Excel in the same layout as in the paper:
*   Table_1.xlsx    Purchase-weighted additive exposure by food category (2023)
*   Table_2.xlsx    Mean price per ounce by UPC, by regulatory case (USD)
*   Table_3.xlsx    OLS estimates of log price per ounce
*   Table_4.xlsx    Exponential mean models of household monthly expenditure
*                   on products containing targeted additives
*   Table_S9.xlsx   Unique products (UPCs) purchased by regulatory case
*   Table_S10.xlsx  Products purchased (sum of units) by regulatory case
********************************************************************************

version 17
clear all
set more off

* Analysis datasets and output folder
local data   ".../scanner"
local indir  "`data'/analysis"
local outdir ".../tables"
capture mkdir "`outdir'"

* Categories 
local categories Beverages BreakfastProducts PreparedFoods DairyEggsandMilkAlt ///
    SnacksandConfectionery SpecialNutrition Ingredients ///
    MeatSeafoodAlternatives Produce

* Full names (S9, S10), names in Tables 1-2, abbreviations in Tables 3-4
local lbl_Beverages               "Beverages"
local lbl_BreakfastProducts       "Breakfast Products"
local lbl_PreparedFoods           "Prepared Foods"
local lbl_DairyEggsandMilkAlt     "Dairy, Eggs & Alternatives"
local lbl_SnacksandConfectionery  "Snacks & Confectionery"
local lbl_SpecialNutrition        "Special Nutrition"
local lbl_Ingredients             "Ingredients & Cooking Aids"
local lbl_MeatSeafoodAlternatives "Meat, Seafood & Meat Alternatives"
local lbl_Produce                 "Produce"
foreach c of local categories {
    local sh_`c' "`lbl_`c''"
}
local sh_DairyEggsandMilkAlt     "Dairy, Eggs & Alt."
local sh_MeatSeafoodAlternatives "Meat, Seafood & Alt."
local ab_Beverages "Bev."
local ab_BreakfastProducts "Break."
local ab_PreparedFoods "Prep."
local ab_DairyEggsandMilkAlt "Dairy"
local ab_SnacksandConfectionery "Snacks"
local ab_SpecialNutrition "Special"
local ab_Ingredients "Ingred."
local ab_MeatSeafoodAlternatives "Meat"
local ab_Produce "Prod."

* Helper: a number with 2 decimals
capture program drop fmt2
program define fmt2, rclass
    args x
    local x3 = round(`x', 0.001)
    local s = string(sign(`x3') * round(abs(`x3') + 1e-9, 0.01), "%9.2f")
    if real("`s'") == 0 local s = subinstr("`s'", "-", "", 1)
    return local s "`s'"
end

* Helper: "-0.11*** (0.03)" 
capture program drop cellfmt
program define cellfmt, rclass
    args b se p dec
    local s = cond(`p'<0.01,"***",cond(`p'<0.05,"**",cond(`p'<0.10,"*","")))
    fmt2 `b'
    local bs "`r(s)'"
    fmt2 `se'
    return local c = "`bs'`s' (`r(s)')"
end

* Helper: column widths, centered numbers, bold rows where bold==1
capture program drop xltidy
program define xltidy
    args file ncol width1 width
    mata: b = xl(); b.load_book("`file'"); b.set_sheet("Table"); b.set_column_width(1, 1, `width1'); b.set_column_width(2, `ncol', `width'); b.close_book()
    local L = char(64 + `ncol')
    putexcel set "`file'", sheet("Table") modify
    putexcel B1:`L'`=_N', hcenter
    forvalues n = 1/`=_N' {
        if bold[`n'] putexcel A`n':`L'`n', bold
    }
end

* Results built row by row
tempfile t1 t2 t3 t4 s9 s10
tempname P1 P2 P3 P4 P9 P10

postfile `P1'  byte bold str40 c1 str25 c2 str25 c3 str40 c4 using "`t1'", replace
postfile `P2'  byte bold str40 c1 str25 c2 str25 c3 str25 c4 str25 c5 using "`t2'", replace
postfile `P9'  byte bold str40 c1 str25 c2 str25 c3 str25 c4 str25 c5 using "`s9'", replace
postfile `P10' byte bold str40 c1 str25 c2 str25 c3 str25 c4 str25 c5 using "`s10'", replace
postfile `P3'  byte row str40 rowlabel byte col str30 cell using "`t3'", replace
postfile `P4'  byte row str40 rowlabel byte col str30 cell using "`t4'", replace

local cases `" "Other Additives/None" "Flagged-permitted" "EU-restricted" "EU-unauthorized" "'
post `P1' (1) ("Category") ("% UPCs with targeted additives") ("% Units purchased") ///
    ("Exposure Wedge (Units " + uchar(8722) + " UPC share)")
foreach P in `P2' `P9' `P10' {
    post `P' (1) ("Categories") ("Other Additives/None") ("Flagged-permitted") ///
        ("EU-restricted") ("EU-unauthorized")
}

* Row labels for Tables 3 and 4
local t3lab `" "Flagged-permitted" "EU-restricted" "EU-unauth." "Constant" "'
local t3terms "1.case 2.case 3.case _cons"
local t4lab `" "Household Income" "\$25,000-\$49,999" "\$50,000-\$99,999" "\$100,000 & higher" "Other Demographics" "Married" "Children" "Employed" "Education" "White" "Hispanic" "HH size" "Constant" "'
local t4terms "- 2.income 3.income 4.income - married child_under12 employed max_education white hispanic household_size _cons"

* ---------------- LOOP OVER CATEGORIES
local i = 0
foreach cat of local categories {
    local ++i
    di as result _n "==== `lbl_`cat''"
    use "`indir'/`cat'_analysis.dta", clear
    capture drop __*

* ---------------- TABLE S9: unique UPCs by regulatory case, n (%)
    * ---------------- TABLE 1, UPC share: share of UPCs with a targeted additive
    preserve
        bysort upc_x: keep if _n == 1
        quietly count
        local N = r(N)
        forvalues c = 0/3 {
            quietly count if case == `c'
            local s9_`c' = string(r(N),"%12.0fc") + " (" + string(100*r(N)/`N',"%9.2f") + "%)"
        }
        quietly count if targeted == 1
        local upc_share = 100*r(N)/`N'
    restore
    post `P9' (0) ("`lbl_`cat''") ("`s9_0'") ("`s9_1'") ("`s9_2'") ("`s9_3'")

* ---------------- TABLE S10: units purchased by regulatory case, n (%)
    * ---------------- TABLE 1, unit share and exposure wedge
    ****************************************************************************
    quietly summarize quantity, meanonly
    local U = r(sum)
    forvalues c = 0/3 {
        quietly summarize quantity if case == `c', meanonly
        local s10_`c' = string(r(sum),"%15.0fc") + " (" + string(100*r(sum)/`U',"%9.2f") + "%)"
    }
    post `P10' (0) ("`lbl_`cat''") ("`s10_0'") ("`s10_1'") ("`s10_2'") ("`s10_3'")

    quietly summarize quantity if targeted == 1, meanonly
    local unit_share = 100*r(sum)/`U'
    local wedge = `unit_share' - `upc_share'
    post `P1' (0) ("`sh_`cat''") (string(`upc_share',"%9.2f") + "%") ///
        (string(`unit_share',"%9.2f") + "%") ///
        (cond(`wedge'>=0,"+","") + string(`wedge',"%9.2f") + " pp")

    * ---------------- TABLE 2: mean price per ounce by UPC and regulatory case, $mean (SD)
    preserve
        drop if missing(price_oz)
        collapse (mean) price_oz, by(upc_x case)
        forvalues c = 0/3 {
            quietly summarize price_oz if case == `c'
            local t2_`c' ""
            if r(N) > 0 {
                local sd = r(sd)
                fmt2 `r(mean)'
                local m "`r(s)'"
                fmt2 `sd'
                local t2_`c' = char(36) + "`m' (`r(s)')"
            }
        }
    restore
    post `P2' (0) ("`sh_`cat''") ("`t2_0'") ("`t2_1'") ("`t2_2'") ("`t2_3'")

    * ---------------- TABLE 3: OLS of log price per ounce, one observation per UPC (robust SE)
    preserve
        drop if missing(price_oz) | price_oz <= 0
        collapse (mean) price_oz, by(upc_x case)
        isid upc_x
        gen double ln_price_oz = ln(price_oz)
        regress ln_price_oz ib0.case, vce(robust)
        
		* Write this food group's results to Table 3
		post `P3' (0) ("") (`i') ("`ab_`cat''")
        forvalues j = 1/4 {
            local x   : word `j' of `t3terms'
            local lab : word `j' of `t3lab'
            quietly lincom `x'
            cellfmt `=r(estimate)' `=r(se)' `=r(p)' 2
            post `P3' (`j') ("`lab'") (`i') ("`r(c)'")
        }
        post `P3' (5) ("N")         (`i') (string(e(N),"%12.0fc"))
        post `P3' (6) ("R-squared") (`i') (string(e(r2),"%9.2f"))
    restore

    * ---------------- TABLE 4: household-month expenditure on targeted products (Poisson QMLE, sampling weights, SE clustered by household)
    preserve
        drop if missing(total_price_paid, household_code, ym, hh_weight)
        gen double spend_additive = cond(targeted == 1, total_price_paid, 0)
        collapse (sum) spend_additive ///
            (firstnm) income married child_under12 employed max_education ///
            white hispanic household_size hh_weight, by(household_code ym)
        glm spend_additive ib1.income married child_under12 employed ///
            max_education white hispanic household_size i.ym [pweight = hh_weight], ///
            family(poisson) link(log) vce(cluster household_code) nolog
        
		* Write this food group's results to Table 4
		post `P4' (0) ("") (`i') ("`ab_`cat''")
        forvalues j = 1/13 {
            local x   : word `j' of `t4terms'
            local lab : word `j' of `t4lab'
            local c ""
            if "`x'" != "-" {
                quietly lincom `x'
                cellfmt `=r(estimate)' `=r(se)' `=r(p)' 2
                local c "`r(c)'"
            }
            post `P4' (`j') ("`lab'") (`i') ("`c'")
        }
        post `P4' (14) ("Month fixed effects") (`i') ("Yes")
        post `P4' (15) ("Samp. Weights")       (`i') ("Yes")
        post `P4' (16) ("N of HH-months")      (`i') (string(e(N),"%12.0fc"))
        post `P4' (17) ("N of HHs")            (`i') (string(e(N_clust),"%12.0fc"))
    restore
}
foreach P in `P1' `P2' `P3' `P4' `P9' `P10' {
    postclose `P'
}

* ---------------- EXPORT
* Tables 1, 2, S9, S10: one row per category
foreach t in 1 2 S9 S10 {
    local tf = cond("`t'"=="1","`t1'",cond("`t'"=="2","`t2'",cond("`t'"=="S9","`s9'","`s10'")))
    use "`tf'", clear
    local ncol = cond("`t'"=="1",4,5)
    local f "`outdir'/Table_`t'.xlsx"
    export excel c1-c`ncol' using "`f'", sheet("Table") replace
    xltidy "`f'" `ncol' 30 22
    putexcel A1:`=char(64+`ncol')'1, txtwrap
}

* Tables 3 and 4: rows = terms, columns = categories
foreach t in 3 4 {
    use "`t`t''", clear
    reshape wide cell, i(row) j(col)
    sort row
    gen byte bold = row==0 | inlist(rowlabel, "Household Income", "Other Demographics")
    local f "`outdir'/Table_`t'.xlsx"
    export excel rowlabel cell* using "`f'", sheet("Table") replace
    xltidy "`f'" 10 22 16
}

di as result "Done. Tables saved to `outdir'"
