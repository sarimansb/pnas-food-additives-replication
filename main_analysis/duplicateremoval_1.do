********************************************************************************
* Paper:   Food additives in the U.S. food supply: Regulatory divergence,
*          market concentration, and exposure patterns
*
* Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
*          Vincenzina Caputo
*
* Code:    Sevval Buse Sariman
*
* Purpose: Removes duplicate UPCs from the USDA Global Branded Food Products
*          Database (GBFPD).
********************************************************************************

* Import the CSV file
import delimited ///
".../FoodData_Central_branded_food_csv_2025-04-24/branded_food.csv", clear

* Preserve the original CSV row order so exact ties are resolved the same way in every run.
gen long source_row = _n

* CLEAN THE ORIGINAL GTIN/UPC
* Remove spaces, hyphens, and all other nonnumeric characters
gen strL gtin_upc_clean = ///
subinstr(subinstr(gtin_upc, " ", "", .), "-", "", .)
replace gtin_upc_clean = ///
ustrregexra(gtin_upc_clean, "[^0-9]", "")

* ---------------- FIRST DUPLICATE CHECK:
bysort gtin_upc_clean: gen count = _N
list gtin_upc_clean branded_food_category modified_date ///
if count > 1
drop count

* Identify records with a populated branded food category
gen byte category_nonmissing = ///
!missing(strtrim(branded_food_category))

* Identify records with a populated ingredient list so nonmissing ingredients can also be preferred.
gen byte ingredients_nonmissing = ///
!missing(strtrim(ingredients))

* Determine whether each duplicate group has a populated category
bysort gtin_upc_clean: egen byte any_category = ///
max(category_nonmissing)

* If a populated category exists, drop duplicate records with no category
drop if any_category == 1 & category_nonmissing == 0
drop any_category

* Determine whether the remaining duplicate group has a populated ingredient list.
bysort gtin_upc_clean: egen byte any_ingredients = ///
max(ingredients_nonmissing)

* If a populated ingredient list exists, drop duplicate records with missing ingredients.
drop if any_ingredients == 1 & ingredients_nonmissing == 0
drop any_ingredients

* Among remaining duplicates, keep the latest record
* Source_row resolves ties when multiple records have the same modified_date.
bysort gtin_upc_clean (modified_date source_row): keep if _n == _N

* CREATE UPC WITHOUT LEADING ZEROS
gen strL upc_str = gtin_upc_clean
replace upc_str = regexr(upc_str, "^[0]+", "")
drop if missing(upc_str)

* ---------------- SECOND DUPLICATE CHECK:
* SAME UPC AFTER REMOVING LEADING ZEROS
* Determine whether each duplicate group has a populated category
bysort upc_str: egen byte any_category = ///
max(category_nonmissing)

* If a populated category exists, drop duplicate records with no category
drop if any_category == 1 & category_nonmissing == 0
drop any_category

* Determine whether the remaining duplicate group has a populated ingredient list.
bysort upc_str: egen byte any_ingredients = ///
max(ingredients_nonmissing)

* If a populated ingredient list exists, drop duplicate records with missing ingredients.
drop if any_ingredients == 1 & ingredients_nonmissing == 0
drop any_ingredients

* Among remaining duplicates, keep the latest record
* source_row resolves ties when multiple records have the same modified_date.
bysort upc_str (modified_date source_row): keep if _n == _N

* Drop the additional temporary variables after duplicate selection is complete.
drop category_nonmissing ingredients_nonmissing source_row

* Confirm that UPC is now unique
isid upc_str

*drop if market_country is not US
drop if market_country!="United States" 

* SAVE FINAL DATA
save ".../brandedfood_1.dta", replace

