********************************************************************************
* Paper:   Food additives in the U.S. food supply: Regulatory divergence,
*          market concentration, and exposure patterns
*
* Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
*          Vincenzina Caputo
*
* Code:    Sevval Buse Sariman
*
* Purpose: Builds two tables by food and beverage category:
*          (1) the share of products in each regulatory case,
*          (2) the share of products containing each targeted additive.
*          Categories or cases with zero products are not written.
*
* Output:  results_case.csv and results_additive.csv
********************************************************************************

local additives red_3_flag azodicarbonamide_flag potassium_bromate_flag     ///
    green_3_flag titanium_dioxide_flag propylparaben_flag brominated_oil_flag ///
    olestra_flag citrus_red_2_flag orange_b_flag aspartame_flag              ///
    saccharin_flag sucralose_flag acesulfame_k_flag carrageenan_flag         ///
    red_40_flag yellow_5_flag yellow_6_flag nitrite_nitrate_flag             ///
    allsulfites_flag partially_oil_flag potassium_iodate_flag                ///
    caramel_color_flag bha_flag bht_flag propyl_gallate_flag tbhq_flag       ///
    benzoate_flag msg_flag pg_flag hfcs_flag blue_1_flag blue_2_flag         ///
    glycerin_flag

* Data created in the previous do-file
use ".../brandedfood_5.dta", clear
levelsof categories, local(cats)

* (1) Share of products in each regulatory case, by category
tempname t1
tempfile results_case
postfile `t1' str30 categories str40 additive long count float percentage ///
    using `results_case', replace

foreach cat of local cats {
    quietly count if categories == "`cat'"
    local total = r(N)

    * caseall = 1 if the product contains an additive from any case
    quietly count if caseall == 1 & categories == "`cat'"
    post `t1' ("`cat'") ("All Cases") (r(N)) (100 * r(N) / `total')

    foreach var in case1 case2 case3 {
        quietly count if `var' == 1 & categories == "`cat'"
        if r(N) > 0 post `t1' ("`cat'") ("`var'") (r(N)) (100 * r(N) / `total')
    }
}
postclose `t1'

* (2) Share of products containing each targeted additive, by category
tempname t2
tempfile results_additive
postfile `t2' str30 categories str40 additive long count float percentage ///
    using `results_additive', replace

foreach cat of local cats {
    quietly count if categories == "`cat'"
    local total = r(N)

    * Any targeted additive is the same as being in any case
    quietly count if caseall == 1 & categories == "`cat'"
    post `t2' ("`cat'") ("All Additives") (r(N)) (100 * r(N) / `total')

    foreach var of local additives {
        quietly count if `var' == 1 & categories == "`cat'"
        if r(N) > 0 post `t2' ("`cat'") ("`var'") (r(N)) (100 * r(N) / `total')
    }
}
postclose `t2'

* Export
use `results_case', clear
export delimited using ".../results_case.csv", replace

use `results_additive', clear
export delimited using ".../results_additive.csv", replace
