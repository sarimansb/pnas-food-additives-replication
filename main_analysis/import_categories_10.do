********************************************************************************
* Paper:   Food additives in the U.S. food supply: Regulatory divergence,
*          market concentration, and exposure patterns
*
* Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
*          Vincenzina Caputo
*
* Code:    Sevval Buse Sariman
*
* Purpose: This do-file opens the 9 food and beverage category files created by
* 		   match_scanner_usda_9.py (USDA GBFPD products merged with NielsenIQ 
*          consumer panel purchases), stores the numeric variables as numbers, 
*		   and saves each category as a Stata file.
********************************************************************************

* PART 1  SETUP 
clear all
set more off
set maxvar 20000

global dtadir ".../scanner"

* importcat <category>: open the category's CSV, make the numeric variables
* numbers, and save the .dta
capture program drop importcat
program define importcat
    args g

    * Read every variable as text, keeping the variable names as written.
    * maxquotedrows(unlimited): some text fields (e.g. ingredient lists) contain
    * line breaks; this lets one quoted field run over more than 20 lines.
    import delimited using "$dtadir/csv/purchase_2023_panel_`g'.csv", ///
        varnames(1) case(preserve) stringcols(_all) bindquote(strict) ///
        maxquotedrows(unlimited) encoding("utf-8") clear

    * Variables stored as numbers (all other variables stay as text)
    local numeric trip_code_uc quantity total_price_paid coupon_value             ///
        deal_flag_uc size1_amount_hms panel_year _exact_match _common_digits        ///
        multi year serving_size cat_id ingredient_count                             ///
        EU_unauthorized EU_restricted flagged_permitted caseall                     ///
        EU_unauthorized_count EU_restricted_count flagged_permitted_count           ///
        total_caseall_count california_restricted california_banned                 ///
        california_rest_total california_ban_total                                  ///
        red_3_flag azodicarbonamide_flag potassium_bromate_flag green_3_flag        ///
        titanium_dioxide_flag propylparaben_flag brominated_oil_flag olestra_flag   ///
        citrus_red_2_flag orange_b_flag aspartame_flag saccharin_flag               ///
        sucralose_flag acesulfame_k_flag carrageenan_flag red_40_flag yellow_5_flag ///
        sodium_nitrite_flag sodium_nitrate_flag potassium_nitrite_flag              ///
        potassium_nitrate_flag nitrite_nitrate_flag sodium_sulfites_flag            ///
        potassium_sulfites_flag sulfites_flag allsulfites_flag partially_oil_flag   ///
        potassium_iodate_flag caramel_color_flag bha_flag bht_flag                  ///
        propyl_gallate_flag tbhq_flag sodium_benzoate_flag potassium_benzoate_flag  ///
        benzoate_flag msg_flag pg_flag hfcs_flag yellow_6_flag blue_1_flag          ///
        blue_2_flag glycerin_flag

    * Text -> number
    foreach v of local numeric {
        capture confirm string variable `v'
        if !_rc destring `v', replace force
        capture confirm numeric variable `v'
        if !_rc recast double `v'
    }

    display as result "`g' rows = " %15.0fc _N
    save "$dtadir/purchase_2023_panel_`g'.dta", replace
end

* PART 2  ONE CATEGORY AT A TIME
importcat Beverages
importcat BreakfastProducts
importcat PreparedFoods
importcat DairyEggsandMilkAlt
importcat SnacksandConfectionery
importcat SpecialNutrition
importcat Ingredients
importcat MeatSeafoodAlternatives
importcat Produce
