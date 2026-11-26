********************************************************************************
* Paper:   Food additives in the U.S. food supply: Regulatory divergence,
*          market concentration, and exposure patterns
*
* Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
*          Vincenzina Caputo
*
* Code:    Sevval Buse Sariman
*
* Purpose: Computes price per calorie and generates SI Table S15, which
*          compares log price per calorie with log price per ounce.
*
*   The NielsenIQ label columns (CALORIES_PER_SERVING_SIZE,
*   SERVING_SIZE_METRIC, SERVING_SIZE_HOUSEHOLD) are already in the analysis
*   files, added by match_scanner_usda_9.py 
*
*   For each category:
*
*   A. Package calories. Price per calorie needs the calories in the whole
*      package, but the label data give only calories per serving. We
*      therefore compute:
*
*        package calories     = calories per serving x servings per package
*        servings per package = package size / serving size
*
*      The serving size is not reported in the same way for every product,
*      and is sometimes missing. For each product we use the most reliable
*      serving size available, in this order:
*
*        1. Scanner metric serving size, e.g. "30 GRAM"
*        2. Scanner household serving size, e.g. "1 CUP", when the serving
*          and the package are both measured by weight (g, oz) or both by
*          volume (mL, fl oz)
*        3. Scanner serving given as a count, e.g. "1 BOTTLE":
*          items in the package / items per serving
*        4. USDA serving size, when the serving and the package are both
*          measured by weight or both by volume
*        5. Scanner household serving size, when one is measured by weight
*          and the other by volume (e.g. a 16 oz jar with a "2 TABLESPOONS"
*          serving); 1 mL is assumed to weigh 1 g
*        6. USDA serving size, when one is measured by weight and the other
*          by volume; 1 mL is assumed to weigh 1 g
*
*
*   B. Price per calorie = price paid / calories in the package bought.
*
*   C. S15 regressions on the U.S. sample, one observation per UPC, robust
*      standard errors:
*        (1) log price per calorie (products with non-zero calories)
*        (2) log price per ounce
*
* Output:  Table_S15.xlsx (in the SI Appendix)
*          package_kcal/<category>_package_kcal.dta (calories by UPC and
*          package size, for checking)
********************************************************************************
clear all
set more off


* ---------------------------------------------------------------- paths
local indir ".../scanner/analysis"
local out   ".../tables"
capture mkdir "`out'"
capture mkdir "`out'/package_kcal"

* Category order = SI order 
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

* Helper: "-0.114*** (0.031)"
capture program drop starcell
program define starcell, rclass
    args b se p
    local s = cond(`p'<0.01,"***",cond(`p'<0.05,"**",cond(`p'<0.10,"*","")))
    return local c = string(`b',"%9.3f") + "`s'" + " (" + string(`se',"%9.3f") + ")"
end

local terms "1.case 2.case 3.case _cons"
local tlabs `" "Flag-permitted" "EU-restricted" "EU-unauthorized" "Constant" "'

tempfile tab
tempname P
postfile `P' byte bold str40 c1 str25 c2 str25 c3 using "`tab'", replace
post `P' (1) ("Regulatory group") ("Log price per calorie") ("Log price per ounce")

foreach cat of local categories {
    local catlabel "`lbl_`cat''"
    use "`indir'/`cat'_analysis.dta", clear
    capture drop __*

    ****************************************************************************
    * A. PACKAGE CALORIES (one row per UPC and package size)
    ****************************************************************************
    *Package unit: 1 = volume, 0 = weight, . = not identified
    capture drop pack_is_fluid
    gen byte pack_is_fluid = .
    replace pack_is_fluid = 1 if inlist(size1_unit_hms, "LITER","ML","GALLON","QUART","PINT","CC","CL","FLDRAM")
    replace pack_is_fluid = 0 if inlist(size1_unit_hms, "OZ","POUND","GRAM","KG","MG","DRYQUART","DRYPINT","DRYCUP")

    * One id per UPC and package size (calories, serving sizes and USDA
    * serving size are the same for all rows of a UPC)
    egen long calc_id = group(upc_x pack_size pack_size_oz multi_use size1_unit_hms), missing

    preserve
        keep calc_id upc_x pack_size pack_size_oz multi_use size1_unit_hms ///
            is_liquid pack_is_fluid serving_size serving_size_unit ///
            CALORIES_PER_SERVING_SIZE SERVING_SIZE_METRIC SERVING_SIZE_HOUSEHOLD
        bysort calc_id: keep if _n==1

        * Calories per serving (scanner label)
			* (text -> number, keeping only digits, "." and "-")
        gen double kcal = real(ustrregexra(CALORIES_PER_SERVING_SIZE, "[^0-9.\-]", ""))
        replace kcal = . if kcal<0

        * Serving size, from three places
			* Scanner metric serving size, used in source 1
			* m_amt = serving in g or mL; m_basis = 0 weight, 1 volume
		gen mtxt = subinstr(subinstr(upper(itrim(strtrim(SERVING_SIZE_METRIC))),",","",.),char(34),"",.)
        gen double m_num = real(regexs(1)) if regexm(mtxt,"^([0-9]*[.]?[0-9]+)")
        gen str40 m_unit = strtrim(regexs(2)) if regexm(mtxt,"^([0-9]*[.]?[0-9]+)[ ]+(.+)$")
        gen double m_amt = .
        gen byte m_basis = .
        replace m_amt = m_num           if inlist(m_unit,"GRAM","GRAMS","GM","GRM","G","GRAM DRY")
        replace m_amt = m_num/1000      if inlist(m_unit,"MILLIGRAM","MILLIGRAMS","MG")
        replace m_amt = m_num*28.3495   if inlist(m_unit,"OUNCE","OUNCES","OZ")
        replace m_basis = 0 if m_amt<.
        replace m_amt = m_num           if inlist(m_unit,"MILLILITER","MILLILITERS","ML","MLT")
        replace m_amt = m_num*1000      if inlist(m_unit,"LITER","LITERS","LTR")
        replace m_amt = m_num*29.5735   if inlist(m_unit,"FLUID OUNCE","FLUID OUNCES","FL OZ")
        replace m_basis = 1 if inlist(m_unit,"MILLILITER","MILLILITERS","ML","MLT","LITER","LITERS","LTR") ///
                             | inlist(m_unit,"FLUID OUNCE","FLUID OUNCES","FL OZ")
        replace m_amt = . if m_amt<=0
        replace m_basis = . if m_amt>=.

        * Household serving size (h_amt in grams or mL; counts for containers/pieces)
		* h_amt = serving in g or mL (sources 2 and 5); h_basis = 0 weight, 1 volume.
        * h_container / h_piece = serving given as a count, e.g.
        gen htxt = subinstr(subinstr(upper(itrim(strtrim(SERVING_SIZE_HOUSEHOLD))),",","",.),char(34),"",.)
        gen double h_num = real(regexs(1)) if regexm(htxt,"^([0-9]*[.]?[0-9]+)")
        gen str80 h_unit = strtrim(regexs(2)) if regexm(htxt,"^([0-9]*[.]?[0-9]+)[ ]+(.+)$")
        gen byte h_complex = regexm(htxt," TO ") | regexm(htxt," PLUS ")
        gen double h_amt = .
        gen byte h_basis = .
        replace h_amt = h_num*29.5735 if regexm(h_unit,"^FLUID OUNCE") & !h_complex
        replace h_amt = h_num*236.588 if regexm(h_unit,"^CUP($| )") & !h_complex
        replace h_amt = h_num*14.7868 if (regexm(h_unit,"^TABLESPOON($| )") | regexm(h_unit,"^ROUNDED TABLESPOON($| )")) & !h_complex
        replace h_amt = h_num*4.92892 if (regexm(h_unit,"^TEASPOON($| )") | regexm(h_unit,"^ROUNDED TEASPOON($| )")) & !h_complex
        replace h_basis = 1 if h_amt<.
        replace h_amt = h_num*28.3495 if regexm(h_unit,"^OUNCE(S)?$") & !h_complex
        replace h_amt = h_num         if regexm(h_unit,"^GRAM(S)?$") & !h_complex
        replace h_basis = 0 if (regexm(h_unit,"^OUNCE(S)?$") | regexm(h_unit,"^GRAM(S)?$")) & !h_complex
        replace h_amt = . if h_amt<=0
        replace h_basis = . if h_amt>=.
        gen byte h_container = (regexm(h_unit,"^(BOTTLE|CAN|CARTON|CONTAINER|PACKAGE|PACKET|POUCH|POUCHES|BOX|BAG|STICK)(S)?($| )") ///
            | regexm(h_unit,"^(SACHET|ENVELOPE|POD|K CUP|TEA BAG|DRINK BOX|SINGLE SERVE CUP|SHAKE|TUB|TRAY|PACK|PAK|INFUSER|COFFEE BOMB)(S)?($| )")) & !h_complex
        gen byte h_piece = regexm(h_unit,"^(PIECE|PIECES|SLICE|SLICES|TABLET|TABLETS|CUBE|CUBES|BALL|BALLS|SQUARE|SQUARES|SPEAR|SPEARS|BERRY|BERRIES|TEA DROP|TEA STICK|STRAW)(S)?$") & !h_complex

        * USDA serving size fallback
        * u_amt = serving in g or mL; u_basis = 0 weight, 1 volume
        capture confirm numeric variable serving_size
        if !_rc gen double u_size = real(strtrim(string(serving_size,"%30.15g")))
        else    gen double u_size = real(strtrim(serving_size))
        capture confirm numeric variable serving_size_unit
        if !_rc gen u_unit = lower(strtrim(string(serving_size_unit,"%30.15g")))
        else    gen u_unit = lower(itrim(strtrim(serving_size_unit)))
        gen double u_amt = .
        gen byte u_basis = .
        replace u_amt = u_size      if inlist(u_unit,"g","gm","grm")
        replace u_amt = u_size/1000 if u_unit=="mg"
        replace u_basis = 0 if u_amt<.
        replace u_amt = u_size      if inlist(u_unit,"ml","mlt")
        replace u_basis = 1         if inlist(u_unit,"ml","mlt")
        replace u_amt = . if u_amt<=0
        replace u_basis = . if u_amt>=.

        * Package size in grams or mL: package unit first, then liquid flag
        capture confirm numeric variable is_liquid
        if !_rc gen byte liquid = is_liquid
        else    gen byte liquid = real(strtrim(is_liquid))
        replace liquid = . if !inlist(liquid,0,1)
        gen byte p_basis = pack_is_fluid
        replace p_basis = liquid if p_basis>=.
        gen double p_amt = .
        replace p_amt = pack_size_oz*28.3495 if p_basis==0 & pack_size_oz>0 & pack_size_oz<.
        replace p_amt = pack_size_oz*29.5735 if p_basis==1 & pack_size_oz>0 & pack_size_oz<.

        * p_count = number of items in the package 
        capture confirm numeric variable size1_unit_hms
        if !_rc gen p_unit = upper(strtrim(string(size1_unit_hms,"%30.15g")))
        else    gen p_unit = upper(itrim(strtrim(size1_unit_hms)))
        gen double mult = multi_use
        replace mult = 1 if mult>=. | mult<=0
        gen double p_count = .
        replace p_count = pack_size*mult    if p_unit=="CT"    & pack_size>0 & pack_size<.
        replace p_count = pack_size*12*mult if p_unit=="DOZEN" & pack_size>0 & pack_size<.
        replace p_count = mult if p_count>=. & h_container==1

        * Servings per package: first available source
		* Source 1: scanner metric serving
		gen double servings = .
        gen byte source = .
        local ok "kcal<. & servings>=."
        replace source = 1 if `ok' & p_amt>0 & p_amt<. & m_amt>0 & m_amt<.
        replace servings = p_amt/m_amt if source==1
        * Source 2: scanner household serving, same basis as package
        replace source = 2 if `ok' & p_amt>0 & p_amt<. & h_amt>0 & h_amt<. & h_basis==p_basis
        replace servings = p_amt/h_amt if source==2
        * Source 3: serving given as a count (items / items per serving)
        replace source = 3 if `ok' & (h_container==1 | h_piece==1) & p_count>0 & p_count<. & h_num>0 & h_num<.
        replace servings = p_count/h_num if source==3
        * Source 4: USDA serving, same basis as package
        replace source = 4 if `ok' & p_amt>0 & p_amt<. & u_amt>0 & u_amt<. & u_basis==p_basis
        replace servings = p_amt/u_amt if source==4
        * Source 5: scanner household serving, different basis (1 g = 1 mL)
        replace source = 5 if `ok' & p_amt>0 & p_amt<. & h_amt>0 & h_amt<. & h_basis<. & p_basis<. & h_basis!=p_basis
        replace servings = p_amt/h_amt if source==5
        * Source 6: USDA serving, different basis (1 g = 1 mL)
        replace source = 6 if `ok' & p_amt>0 & p_amt<. & u_amt>0 & u_amt<. & u_basis<. & p_basis<. & u_basis!=p_basis
        replace servings = p_amt/u_amt if source==6
        * No valid source
        replace servings = . if servings<=0
        replace source = . if servings>=.

        * Package calories = calories per serving x servings per package
        gen double package_kcal = kcal*servings if kcal<. & servings<.
        gen byte zero_calorie = kcal==0 if kcal<.

        keep calc_id upc_x pack_size pack_size_oz multi_use size1_unit_hms ///
            kcal servings source package_kcal zero_calorie
        label var kcal "Calories per labeled serving (scanner)"
        label var servings "Labeled servings per package"
        label var source "Serving-size source (1-6)"
        label var package_kcal "Calories per package"
        label var zero_calorie "Label reports zero calories"
        save "`out'/package_kcal/`cat'_package_kcal.dta", replace
        tempfile pk
        save "`pk'"
    restore

    ****************************************************************************
    * B. PRICE PER CALORIE (transaction level, US sample)
    ****************************************************************************
    merge m:1 calc_id using "`pk'", keep(master match) nogen keepusing(kcal servings source package_kcal zero_calorie)
    gen double ppc = price_one/package_kcal if price_one>0 & price_one<. & package_kcal>0 & package_kcal<.

    ****************************************************************************
    * C. S15 REGRESSIONS (one observation per UPC, robust SE)
    ****************************************************************************
    * (1) Log price per calorie, products with scanner calories, non-zero
    preserve
        keep if kcal<.
        collapse (mean) ppc (firstnm) zero_calorie, by(upc_x case)
        isid upc_x
        keep if zero_calorie==0 & ppc>0 & ppc<. & case<.
        gen double ln_ppc = ln(ppc)
        regress ln_ppc ib0.case, vce(robust)
        forvalues j = 1/4 {
            local x : word `j' of `terms'
            local cal`j' ""
            capture quietly lincom `x'
            if _rc==0 & r(se)>0 & !missing(r(se)) {
                starcell `=r(estimate)' `=r(se)' `=r(p)'
                local cal`j' "`r(c)'"
            }
        }
        local Ncal  = string(e(N),"%12.0fc")
        local r2cal = string(e(r2),"%9.3f")
    restore

    * (2) Log price per ounce, all products with a valid price per ounce
    preserve
        drop if missing(price_oz) | price_oz<=0
        collapse (mean) price_oz, by(upc_x case)
        isid upc_x
        gen double ln_price_oz = ln(price_oz)
        regress ln_price_oz ib0.case, vce(robust)
        forvalues j = 1/4 {
            local x : word `j' of `terms'
            local oz`j' ""
            capture quietly lincom `x'
            if _rc==0 & r(se)>0 & !missing(r(se)) {
                starcell `=r(estimate)' `=r(se)' `=r(p)'
                local oz`j' "`r(c)'"
            }
        }
        local Noz  = string(e(N),"%12.0fc")
        local r2oz = string(e(r2),"%9.3f")
    restore

    * Table block
    post `P' (1) ("`catlabel'") ("") ("")
    forvalues j = 1/4 {
        local lab : word `j' of `tlabs'
        post `P' (0) ("`lab'") ("`cal`j''") ("`oz`j''")
    }
    post `P' (0) ("N")         ("`Ncal'")  ("`Noz'")
    post `P' (0) ("R-squared") ("`r2cal'") ("`r2oz'")
}
postclose `P'

* ---------------------------------------------------------------- export
use "`tab'", clear
local f "`out'/Table_S15.xlsx"
export excel c1-c3 using "`f'", sheet("SI table") replace
mata: b = xl(); b.load_book("`f'"); b.set_sheet("SI table"); b.set_column_width(1, 1, 30); b.set_column_width(2, 3, 24); b.close_book()
putexcel set "`f'", sheet("SI table") modify
putexcel B1:C`=_N', hcenter
forvalues n = 1/`=_N' {
    if bold[`n'] putexcel A`n':C`n', bold
}
