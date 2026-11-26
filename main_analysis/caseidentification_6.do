********************************************************************************
* Paper:   Food additives in the U.S. food supply: Regulatory divergence,
*          market concentration, and exposure patterns
*
* Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
*          Vincenzina Caputo
*
* Code:    Sevval Buse Sariman
*
* Purpose: Creates the regulatory case variables in the USDA Global Branded
*          Food Products Database (GBFPD). A product can belong to more than
*          one case if it contains additives from more than one group.
********************************************************************************

*Import the dta file created in the previous do file.
use ".../brandedfood_4.dta",clear

*Case 1: EU-unauthorized (not allowed in the EU)
gen case1=0
replace case1=1 if red_3_flag==1
replace case1=1 if azodicarbonamide_flag==1
replace case1=1 if potassium_bromate_flag==1
replace case1=1 if green_3_flag==1
replace case1=1 if titanium_dioxide_flag==1
replace case1=1 if propylparaben_flag==1
replace case1=1 if brominated_oil_flag==1
replace case1=1 if olestra_flag==1
replace case1=1 if citrus_red_2_flag==1
replace case1=1 if orange_b_flag==1

*Case 2: EU-restricted (restricted or requires a warning label in the EU)
gen case2=0
replace case2=1 if aspartame_flag==1
replace case2=1 if saccharin_flag==1
replace case2=1 if sucralose_flag==1
replace case2=1 if acesulfame_k_flag==1
replace case2=1 if carrageenan_flag==1
replace case2=1 if red_40_flag==1
replace case2=1 if yellow_5_flag==1
replace case2=1 if yellow_6_flag==1
replace case2=1 if nitrite_nitrate_flag==1
replace case2=1 if allsulfites_flag==1
replace case2=1 if partially_oil_flag==1
replace case2=1 if potassium_iodate_flag==1

*Case 3: Flagged-permitted (allowed in the EU)
gen case3=0
replace case3=1 if caramel_color_flag==1
replace case3=1 if bha_flag==1
replace case3=1 if bht_flag==1
replace case3=1 if propyl_gallate_flag==1
replace case3=1 if tbhq_flag==1
replace case3=1 if benzoate_flag==1
replace case3=1 if msg_flag==1
replace case3=1 if pg_flag==1
replace case3=1 if hfcs_flag==1
replace case3=1 if blue_1_flag==1
replace case3=1 if blue_2_flag==1
replace case3=1 if glycerin_flag==1

*Case All
gen caseall = 0
replace caseall = 1 if case1 == 1
replace caseall = 1 if case2 == 1
replace caseall = 1 if case3 == 1

save ".../brandedfood_5.dta", replace

