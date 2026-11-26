********************************************************************************
* Paper:   Food additives in the U.S. food supply: Regulatory divergence,
*          market concentration, and exposure patterns
*
* Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
*          Vincenzina Caputo
*
* Code:    Sevval Buse Sariman
*
* Purpose: For each scanner category, this do-file:
*   	   1. Constructs the regulatory additive classification.
*  		   2. Reads the package size from the NielsenIQ PRODUCT_SIZE text 
*   	   (added to each product by match_scanner_usda_9.py).
*   	   3. Fills missing package-size information using PRODUCT_SIZE or 
*      	   another complete transaction record for the same UPC.
*   	   4. Converts package size to ounces and calculates price per ounce.
*          5. Constructs the liquid/solid measures used in subsequent analyses.
*          6. Constructs household demographic variables, sampling weights, 
*		   and month.
*          7. Saves one analysis dataset per product category.
********************************************************************************

clear all
set more off
set maxvar 20000

* Category datasets created by match_scanner_usda_9.py and import_categories_10.do
local paneldir ".../scanner"

* Analysis datasets are saved in a new folder
local outdir "`paneldir'/analysis"
capture mkdir "`outdir'"

* Category file-name suffixes, as in purchase_2023_panel_<suffix>.dta
local categories ///
     Beverages BreakfastProducts PreparedFoods DairyEggsandMilkAlt ///
    SnacksandConfectionery SpecialNutrition Ingredients ///
    MeatSeafoodAlternatives Produce

* CATEGORY LOOP
* Process each food category separately so one analysis dataset is created per category.
foreach cat of local categories {

    local datafile "`paneldir'/purchase_2023_panel_`cat'.dta"

    * Load the category-specific scanner data
    use "`datafile'", clear

    foreach pair in "size1_amount size1_amount_hms" "size1_units size1_unit_hms" ///
                    "multi multi_hms" "brand_descr brand_descr_hms" {
        local from : word 1 of `pair'
        local to   : word 2 of `pair'
        capture confirm variable `to', exact
        if _rc {
            capture confirm variable `from', exact
            if !_rc rename `from' `to'
        }
    }

    * REGULATORY CLASSIFICATION
	* Construct a mutually exclusive regulatory classification so products can be compared by additive status.
	foreach v in EU_unauthorized EU_restricted flagged_permitted {
		capture confirm numeric variable `v'
		if _rc {
			destring `v', replace force
		}
	}

	gen EU_unauth_o=0
	gen EU_rest_o=0
	gen flag_per_o=0
	gen EU_none=0
	replace EU_unauth_o=1 if EU_unauthorized ==1
	replace EU_rest_o=1 if EU_restricted==1 & EU_unauth_o==0
	replace flag_per_o=1 if flagged_permitted==1 & EU_unauth_o==0 & EU_rest_o==0
	replace EU_none=1 if EU_unauth_o==0 & EU_rest_o==0 & flag_per_o==0

	egen byte regulatory_missing = rowmiss( ///
	EU_unauthorized EU_restricted flagged_permitted ///
	)

	gen byte case = 0

	replace case = 1 if flag_per_o == 1
	replace case = 2 if EU_rest_o == 1
	replace case = 3 if EU_unauth_o == 1

	replace case = . if regulatory_missing == 3

	label define case_label ///
		0 "No targeted additive" ///
		1 "Flagged-permitted" ///
		2 "EU-restricted" ///
		3 "EU-unauthorized", replace

	label values case case_label

	gen byte targeted = inlist(case, 1, 2, 3)
	replace targeted = . if missing(case)
	
    * PACKAGE SIZE AND PRICE PER OUNCE
    * Standardize HMS package-size variables so package sizes can be converted to ounces.
    * size1_amount_hms carries three implied decimals (12000 -> 12).
    * multi = containers per package; total = multi * size1_amount.
    capture confirm string variable size1_unit_hms
    if !_rc {
        replace size1_unit_hms = upper(strtrim(size1_unit_hms))
    }

    foreach v in size1_amount_hms multi_hms quantity total_price_paid {
    capture confirm numeric variable `v'
    if _rc {
        destring `v', replace ignore(",") force
    }
}

    * PACKAGE SIZE FROM PRODUCT_SIZE (e.g. "16 FLUID OUNCE")
    * Read each distinct PRODUCT_SIZE text once and create
    *   der_unit   = unit code in NielsenIQ's format ("OZ", "LITER", ...)
    *   der_amount = amount x 1000 (NielsenIQ's 3 implied decimals)
    *   is_liquid  = 1 for fluid units, 0 for other units
    * Unusable text ("PRODUCT SIZE NOT AVAILABLE", no number) stays missing.
    preserve
        keep PRODUCT_SIZE
        duplicates drop
        gen ps = ustrupper(PRODUCT_SIZE)

        * Unit text: the text with numbers, "." "/" and a lone "X" removed
        gen unit = ustrregexra(ps, "[0-9./]", " ")
        replace unit = ustrregexra(unit, "\bX\b", " ")
        replace unit = ustrtrim(ustrregexra(unit, "\s+", " "))

        * Amount: the last number in the text (the per-container amount);
        * numbers are taken one at a time from left to right
        gen rest = ps
        gen numtxt = ""
        gen m = ""
        count if ustrregexm(rest, "[0-9]*\.?[0-9]+")
        while r(N) > 0 {
            replace m = ""
            replace m = ustrregexs(0) if ustrregexm(rest, "[0-9]*\.?[0-9]+")
            replace numtxt = m if m != ""
            replace rest = usubstr(rest, ustrpos(rest, m) + ustrlen(m), .) if m != ""
            replace rest = "" if m == ""
            count if ustrregexm(rest, "[0-9]*\.?[0-9]+")
        }
        gen double v = real(numtxt) * 1000
        gen double der_amount = round(v)
        replace der_amount = der_amount - 1 if v - floor(v) == 0.5 & mod(der_amount, 2) == 1

        * Unit code: NielsenIQ names for the common units; otherwise the unit
        * text with spaces and symbols removed
        gen der_unit = ustrregexra(unit, "[^A-Z0-9]", "")
        replace der_unit = "OZ"       if inlist(unit, "OUNCE", "FLUID OUNCE")
        replace der_unit = "KG"       if unit == "KILOGRAM"
        replace der_unit = "MG"       if unit == "MILLIGRAM"
        replace der_unit = "ML"       if unit == "MILLILITER"
        replace der_unit = "CL"       if unit == "CENTILITER"
        replace der_unit = "CC"       if unit == "CUBIC CENTIMETER"
        replace der_unit = "LITER"    if unit == "LITRE"
        replace der_unit = "FLDRAM"   if unit == "FLUID DRAM"
        replace der_unit = "CT"       if unit == "COUNT"
        replace der_unit = "CM"       if unit == "CENTIMETER"
        replace der_unit = "SQFT"     if unit == "SQUARE FOOT"
        replace der_unit = "SQM"      if unit == "SQUARE METER"
        replace der_unit = "CUFT"     if unit == "CUBIC FOOT"
        replace der_unit = "CUIN"     if unit == "CUBIC INCH"
        * (POUND, GRAM, LITER, GALLON, QUART, PINT, DOZEN, YARD, FOOT, INCH,
        *  METER, EXPOSURE, DRY QUART, DRY PINT, DRY CUP keep their name
        *  without spaces)

        gen byte is_liquid = inlist(unit, "FLUID OUNCE", "FLUID DRAM", "MILLILITER", ///
            "CENTILITER", "LITER", "LITRE", "GALLON", "QUART", "PINT") ///
            | unit == "CUBIC CENTIMETER"

        * Unusable text -> missing
        gen byte nosize = inlist(unit, "PRODUCT SIZE NOT AVAILABLE", "NOT STATED", ///
            "NO PRODUCT SIZE", "NOT A WEIGHTED ITEM", "") | numtxt == ""
        replace der_unit   = "" if nosize
        replace der_amount = .  if nosize
        replace is_liquid  = .  if nosize

        keep PRODUCT_SIZE der_unit der_amount is_liquid
        tempfile psize
        save "`psize'"
    restore
    merge m:1 PRODUCT_SIZE using "`psize'", keep(master match) nogen

	* Fill missing NielsenIQ package sizes with the size from PRODUCT_SIZE, but
	* only for UPCs that have no complete NielsenIQ size on any row. A UPC
	* with a complete size on some rows gets that size on its other rows in
	* the next part (donor rows).
    tempvar inc0 upc_complete order
    gen byte `inc0' = missing(size1_amount_hms) | inlist(size1_unit_hms, "", ".", "NA", "NAN", "NONE")
    gen long `order' = _n                         // to restore the row order
    bysort upc_x: egen byte `upc_complete' = ///
        max(!missing(size1_amount_hms) & !inlist(size1_unit_hms, "", ".", "NA", "NAN", "NONE"))
    sort `order'
    replace der_unit   = "" if `upc_complete' == 1
    replace der_amount = .  if `upc_complete' == 1
    replace size1_amount_hms = der_amount if `inc0' & der_unit != "" & !missing(der_amount)
    replace size1_unit_hms   = der_unit   if `inc0' & der_unit != "" & !missing(der_amount)

    gen byte size1_from_product_size = ///
        (`inc0' & der_unit != "" & !missing(der_amount))

    * Check: a size filled from PRODUCT_SIZE should never be 0
    quietly count if size1_from_product_size == 1
    local nfill = r(N)
    quietly count if size1_from_product_size == 1 & size1_amount_hms == 0
    display as result "`cat': rows filled from PRODUCT_SIZE = `nfill'; filled with 0 = `r(N)' (expect 0)"
    drop der_unit der_amount

	 * Fill incomplete package-size observations from another complete row for the same UPC.
    tempvar hasboth rid donor_amt donor_unit incomplete
    gen byte `hasboth' = !missing(size1_amount_hms) & !inlist(size1_unit_hms, "", ".", "NA", "NAN", "NONE")
    gen long `rid' = _n
    sort upc_x `hasboth' `rid'
    by upc_x: gen double `donor_amt' = size1_amount_hms[_N] if `hasboth'[_N]
    by upc_x: gen        `donor_unit' = size1_unit_hms[_N]  if `hasboth'[_N]
    gen byte `incomplete' = missing(size1_amount_hms) | inlist(size1_unit_hms, "", ".", "NA", "NAN", "NONE")
    replace size1_amount_hms = `donor_amt' if `incomplete' & !missing(`donor_amt')
    replace size1_unit_hms   = `donor_unit' if `incomplete' & `donor_unit' != ""
    gen byte size1_from_donor = (`incomplete' & !missing(`donor_amt'))

	* Convert package sizes to ounces so price per ounce can be calculated consistently across products.
    gen double pack_size = size1_amount_hms / 1000
    gen double multi_use = multi_hms
    replace multi_use = 1 if missing(multi_use) | multi_use <= 0

    gen double pack_size_oz = .
    replace pack_size_oz = pack_size              if size1_unit_hms == "OZ"
    replace pack_size_oz = pack_size * 33.8140    if size1_unit_hms == "LITER"
    replace pack_size_oz = pack_size * 0.0338140  if size1_unit_hms == "ML"
    replace pack_size_oz = pack_size * 128        if size1_unit_hms == "GALLON"
    replace pack_size_oz = pack_size * 32         if size1_unit_hms == "QUART"
    replace pack_size_oz = pack_size * 16         if size1_unit_hms == "PINT"
    replace pack_size_oz = pack_size * 16         if size1_unit_hms == "POUND"
    replace pack_size_oz = pack_size * 0.035274   if size1_unit_hms == "GRAM"
    replace pack_size_oz = pack_size * 35.274     if size1_unit_hms == "KG"

    * Fluid volume -> FLUID ounces:
    replace pack_size_oz = pack_size * 0.0338140  if size1_unit_hms == "CC"      // cubic cm = mL
    replace pack_size_oz = pack_size * 0.338140   if size1_unit_hms == "CL"      // 1 cL = 10 mL
    replace pack_size_oz = pack_size * 0.125      if size1_unit_hms == "FLDRAM"  // 1 fl dram = 1/8 fl oz
    * Weight:
    replace pack_size_oz = pack_size * 0.000035274 if size1_unit_hms == "MG"     // mg -> weight oz
	* Dry-volume units are converted to approximate weight ounces assuming
	* a density of 1 g/mL.
    replace pack_size_oz = pack_size * 38.8444    if size1_unit_hms == "DRYQUART"
    replace pack_size_oz = pack_size * 19.4222    if size1_unit_hms == "DRYPINT"
    replace pack_size_oz = pack_size * 9.7111     if size1_unit_hms == "DRYCUP"
    * DOZEN and CT: only meaningful as a weight for eggs. Assume
    * 1 egg = 50 g (approximate USDA's reference weight for a "medium" egg: https://www.fsis.usda.gov/food-safety/safe-food-handling-and-preparation/eggs/shell-eggs-farm-table).
    *   DOZEN -> 12 eggs -> pack_size(dozens) * 12 * 50 g
    *   CT    -> pack_size already IS the egg count -> pack_size * 50 g
    * Eggs are identified with `categories'.
    capture confirm variable categories
    if !_rc {
        replace pack_size_oz = pack_size * 12 * 50 * 0.035274 ///
            if size1_unit_hms == "DOZEN" & categories == "Egg"

        replace pack_size_oz = pack_size * 50 * 0.035274 ///
            if size1_unit_hms == "CT" & categories == "Egg"
    }
    else {
        display as error ///
    "`cat': row-level categories variable not found - DOZEN/CT egg conversion skipped for this file."
    }
    * DOZEN outside Egg (e.g. a dozen dinner rolls), and CT outside
    * Egg (any other count-sold product), have no fixed weight
    * assumption we are willing to make -> stays missing.
    * blank size1_unit_hms -> stays missing.
    replace pack_size_oz = pack_size_oz * multi_use
    display ""
    display "`cat': units with NO package size (expect CT/DOZEN only"
	display "outside categories==Egg, plus blank):"
    tab size1_unit_hms if missing(pack_size_oz), missing

    gen double price_one = total_price_paid / quantity ///
        if quantity > 0 & !missing(total_price_paid)

    gen double price_oz = price_one / pack_size_oz ///
        if !missing(price_one) & price_one > 0 & ///
           !missing(pack_size_oz) & pack_size_oz > 0
   
    * LIQUID / SOLID CLASSIFICATION
	* Classify products as liquid or solid so ounce-based sizes can be converted to the appropriate volume or weight basis.
	gen str12 ssu = lower(strtrim(serving_size_unit))
	gen byte is_liquid_serv = .
	replace is_liquid_serv = 0 ///
		if inlist(ssu, "g", "grm", "gm", "mg", "mc")
	replace is_liquid_serv = 1 ///
		if inlist(ssu, "ml", "mlt")
	replace is_liquid = is_liquid_serv ///
		if missing(is_liquid)
	drop ssu
	
    * Converts one ounce into the appropriate gram/milliliter equivalent: 29.5735 mL for liquids and 28.3495 g for solids.
    gen double g_per_oz = .
    replace g_per_oz = 29.5735 if is_liquid == 1
    replace g_per_oz = 28.3495 if is_liquid == 0

	* For observations whose liquid/solid status remains unresolved,
	* beverages are treated as volume-based and all other categories as
	* weight-based.
    if "`cat'" == "Beverages" {
        replace g_per_oz = 29.5735 if missing(g_per_oz)
    }
    else {
        replace g_per_oz = 28.3495 if missing(g_per_oz)
    }

    gen double package_g = pack_size_oz * g_per_oz

    * DEMOGRAPHICS
	* Construct household demographic variables so they can be used in the sociodemographic analyses.
    foreach v in marital_status age_and_presence_of_children race ///
        male_head_employment female_head_employment ///
        male_head_education female_head_education ///
        household_income hispanic_origin household_size ///
        projection_factor household_code {

        capture confirm numeric variable `v'
        if _rc {
            destring `v', replace ignore(",")
        }
    }
	* Married household
	* NielsenIQ marital status:
	*   1 = Married
	*   2 = Widowed
	*   3 = Divorced/Separated
	*   4 = Single
	* married = 1 for married households and 0 for all other reported statuses.
    gen byte married = (marital_status == 1) if !missing(marital_status)
	
	* White household
	* NielsenIQ race:
	*   1 = White/Caucasian
	*   2 = Black/African American
	*   3 = Asian
	*   4 = Other
	* white = 1 for White/Caucasian households and 0 for all other reported races.
    gen byte white = (race == 1) if !missing(race)

	* Hispanic household
	* NielsenIQ Hispanic origin:
	*   1 = Yes
	*   2 = No
	* hispanic = 1 for Hispanic households and 0 for non-Hispanic households.
	* Missing Hispanic-origin information remains missing.
    gen byte hispanic = (hispanic_origin == 1) if !missing(hispanic_origin)

	* Child under age 12
	* NielsenIQ's age_and_presence_of_children variable identifies the age ranges
	* of children in the household:
	*   1 = Under 6 only
	*   2 = 6–12 only
	*   3 = 13–17 only
	*   4 = Under 6 & 6–12
	*   5 = Under 6 & 13–17
	*   6 = 6–12 & 13–17
	*   7 = Under 6 & 6–12 & 13–17
	*   9 = No children under 18
	*
	* child_under12 = 1 if the household contains at least one child age 12
	* or younger, and 0 otherwise.
    gen byte child_under12 = ///
        inlist(age_and_presence_of_children, 1, 2, 4, 5, 6, 7) ///
        if !missing(age_and_presence_of_children)

	* Household-head employment
	* NielsenIQ codes male/female head employment as:
	*   1 = Employed under 30 hours per week
	*   2 = Employed 30–34 hours per week
	*   3 = Employed 35+ hours per week
	*   9 = Not employed for pay
	*   0 = No male/female head
	*
	* employed = 1 if either the male or female household head is employed
	* for pay (codes 1–3).
	* employed = 0 when neither observed household head is coded as employed.
	* If both employment variables are missing, employed remains missing.
	gen byte employed = .

	replace employed = 1 if ///
		inlist(male_head_employment, 1, 2, 3) | ///
		inlist(female_head_employment, 1, 2, 3)

	replace employed = 0 if missing(employed) & ///
		(!missing(male_head_employment) | ///
		 !missing(female_head_employment))

	* max_education records the highest education level reported for either
	* household head. A resulting value of 0 indicates that education is
	* unavailable for both heads and is therefore recoded as missing.
    egen double max_education = rowmax(male_head_education female_head_education)
    replace max_education = . if max_education == 0

	* Household income
	* Collapse NielsenIQ's detailed household-income categories into four
	* broader income groups:
	*   1 = Less than $25,000
	*   2 = $25,000–$49,999
	*   3 = $50,000–$99,999
	*   4 = $100,000 or more
    gen byte income = .
    replace income = 1 if household_income <= 13
    replace income = 2 if inrange(household_income, 14, 19)
    replace income = 3 if inrange(household_income, 20, 26)
    replace income = 4 if household_income >= 27 & !missing(household_income)

    * WEIGHT AND MONTH
    * Construct the household sampling weight and purchase month for the weighted monthly analyses.
    gen double hh_weight = projection_factor

    capture confirm string variable purchase_date
    if !_rc {
        gen double pdate = daily(purchase_date, "YMD")
    }
    else {
        gen double pdate = purchase_date
    }
    format pdate %td
	
    gen int ym = mofd(pdate)
    format ym %tm

    * SAVE
	save "`outdir'/`cat'_analysis.dta", replace
}
