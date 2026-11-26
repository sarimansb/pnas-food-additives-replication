********************************************************************************
* Paper:   Food additives in the U.S. food supply: Regulatory divergence,
*          market concentration, and exposure patterns
*
* Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
*          Vincenzina Caputo
*
* Code:    Sevval Buse Sariman
*
* Purpose: Renames the regulatory case variables, counts the targeted
*          additives in each regulatory group, and labels the variables.
********************************************************************************


*Import the dta file created in the previous do file.
use ".../brandedfood_5.dta", clear

rename case1 EU_unauthorized
rename case2 EU_restricted
rename case3 flagged_permitted

* NUMBER OF TARGETED ADDITIVES BY REGULATORY GROUP
* Each count is the sum of the 0/1 additive indicators in that group.

* EU-unauthorized 
local eu_unauthorized red_3_flag azodicarbonamide_flag potassium_bromate_flag ///
    green_3_flag titanium_dioxide_flag propylparaben_flag brominated_oil_flag ///
    olestra_flag citrus_red_2_flag orange_b_flag

* EU-restricted 
local eu_restricted aspartame_flag saccharin_flag sucralose_flag ///
    acesulfame_k_flag carrageenan_flag red_40_flag yellow_5_flag yellow_6_flag ///
    nitrite_nitrate_flag allsulfites_flag partially_oil_flag potassium_iodate_flag

* Flagged-permitted 
local flag_permitted caramel_color_flag bha_flag bht_flag propyl_gallate_flag ///
    tbhq_flag benzoate_flag msg_flag pg_flag hfcs_flag ///
    blue_1_flag blue_2_flag glycerin_flag

capture drop EU_unauthorized_count EU_restricted_count flagged_permitted_count total_caseall_count
gen int EU_unauthorized_count   = 0
gen int EU_restricted_count     = 0
gen int flagged_permitted_count = 0
foreach v of local eu_unauthorized {
    replace EU_unauthorized_count = EU_unauthorized_count + `v'
}
foreach v of local eu_restricted {
    replace EU_restricted_count = EU_restricted_count + `v'
}
foreach v of local flag_permitted {
    replace flagged_permitted_count = flagged_permitted_count + `v'
}
gen int total_caseall_count = EU_unauthorized_count + EU_restricted_count + flagged_permitted_count

* VARIABLE LABELS
* USDA product information
label variable fdc_id                         "USDA FoodData Central product ID"
label variable brand_owner                    "Brand owner"
label variable brand_name                     "Brand name"
label variable subbrand_name                  "Sub-brand name"
label variable gtin_upc                       "Original USDA GTIN/UPC"
label variable ingredients                    "Original ingredient list"
label variable not_a_significant_source_of    "Nutrients not present in significant amounts"
label variable serving_size                   "Serving size"
label variable serving_size_unit              "Serving size unit"
label variable household_serving_fulltext     "Household serving description"
label variable branded_food_category          "USDA branded food category"
label variable data_source                    "USDA data source"
label variable package_weight                 "Package weight"
label variable modified_date                  "USDA product modification date"
label variable available_date                 "USDA product availability date"
label variable market_country                 "Market country"
label variable discontinued_date              "Product discontinued date"
label variable preparation_state_code         "Preparation state code"
label variable trade_channel                  "Trade channel"
label variable short_description              "Product short description"
label variable material_code                  "Material code"

* Product identifiers and categories
label variable gtin_upc_clean                 "Cleaned USDA GTIN/UPC"
label variable categories                     "Detailed food and beverage category"
label variable category_name                  "Product category name"
label variable ingredient_count               "Number of ingredients"
label variable upc_str                        "Standardized UPC used for matching"
label variable clean_ingredients              "Cleaned ingredient list"

* Additive indicators and matched terms
label variable red_3_flag                     "Red 3 identified"
label variable red_3_match                    "Red 3 matched term"

label variable azodicarbonamide_flag           "Azodicarbonamide identified"
label variable azodicarbonamide_match          "Azodicarbonamide matched term"

label variable potassium_bromate_flag         "Potassium bromate identified"
label variable potassium_bromate_match        "Potassium bromate matched term"

label variable green_3_flag                   "Green 3 identified"
label variable green_3_match                  "Green 3 matched term"

label variable titanium_dioxide_flag          "Titanium dioxide identified"
label variable titanium_dioxide_match         "Titanium dioxide matched term"

label variable propylparaben_flag             "Propylparaben identified"
label variable propylparaben_match            "Propylparaben matched term"

label variable brominated_oil_flag            "Brominated vegetable oil identified"
label variable brominated_oil_match           "Brominated vegetable oil matched term"

label variable olestra_flag                   "Olestra identified"
label variable olestra_match                  "Olestra matched term"

label variable citrus_red_2_flag              "Citrus Red 2 identified"
label variable citrus_red_2_match             "Citrus Red 2 matched term"

label variable orange_b_flag                  "Orange B identified"
label variable orange_b_match                 "Orange B matched term"

label variable aspartame_flag                 "Aspartame identified"
label variable aspartame_match                "Aspartame matched term"

label variable saccharin_flag                 "Saccharin identified"
label variable saccharin_match                "Saccharin matched term"

label variable sucralose_flag                 "Sucralose identified"
label variable sucralose_match                "Sucralose matched term"

label variable acesulfame_k_flag              "Acesulfame potassium identified"
label variable acesulfame_k_match             "Acesulfame potassium matched term"

label variable carrageenan_flag               "Carrageenan identified"
label variable carrageenan_match              "Carrageenan matched term"

label variable red_40_flag                    "Red 40 identified"
label variable red_40_match                   "Red 40 matched term"

label variable yellow_5_flag                  "Yellow 5 identified"
label variable yellow_5_match                 "Yellow 5 matched term"

label variable sodium_nitrite_flag            "Sodium nitrite identified"
label variable sodium_nitrite_match           "Sodium nitrite matched term"

label variable sodium_nitrate_flag            "Sodium nitrate identified"
label variable sodium_nitrate_match           "Sodium nitrate matched term"

label variable potassium_nitrite_flag         "Potassium nitrite identified"
label variable potassium_nitrite_match        "Potassium nitrite matched term"

label variable potassium_nitrate_flag         "Potassium nitrate identified"
label variable potassium_nitrate_match        "Potassium nitrate matched term"

label variable nitrite_nitrate_flag           "Nitrite or nitrate identified"
label variable nitrite_nitrate_match          "Nitrite or nitrate matched term"

label variable sodium_sulfites_flag           "Sodium sulfite identified"
label variable sodium_sulfites_match          "Sodium sulfite matched term"

label variable potassium_sulfites_flag        "Potassium sulfite identified"
label variable potassium_sulfites_match       "Potassium sulfite matched term"

label variable sulfites_flag                  "Sulfite identified"
label variable sulfites_match                 "Sulfite matched term"

label variable allsulfites_flag               "Any targeted sulfite identified"
label variable allsulfites_match              "Any targeted sulfite matched term"

label variable partially_oil_flag             "Partially hydrogenated oil identified"
label variable partially_oil_match            "Partially hydrogenated oil matched term"

label variable potassium_iodate_flag          "Potassium iodate identified"
label variable potassium_iodate_match         "Potassium iodate matched term"

label variable caramel_color_flag             "Caramel color identified"
label variable caramel_color_match            "Caramel color matched term"

label variable bha_flag                       "BHA identified"
label variable bha_match                      "BHA matched term"

label variable bht_flag                       "BHT identified"
label variable bht_match                      "BHT matched term"

label variable propyl_gallate_flag            "Propyl gallate identified"
label variable propyl_gallate_match           "Propyl gallate matched term"

label variable tbhq_flag                      "TBHQ identified"
label variable tbhq_match                     "TBHQ matched term"

label variable sodium_benzoate_flag           "Sodium benzoate identified"
label variable sodium_benzoate_match          "Sodium benzoate matched term"

label variable potassium_benzoate_flag        "Potassium benzoate identified"
label variable potassium_benzoate_match       "Potassium benzoate matched term"

label variable benzoate_flag                  "Benzoate identified"
label variable benzoate_match                 "Benzoate matched term"

label variable msg_flag                       "Monosodium glutamate identified"
label variable msg_match                      "Monosodium glutamate matched term"

label variable pg_flag                        "Propylene glycol identified"
label variable pg_match                       "Propylene glycol matched term"

label variable hfcs_flag                      "High-fructose corn syrup identified"
label variable hfcs_match                     "High-fructose corn syrup matched term"

label variable yellow_6_flag                  "Yellow 6 identified"
label variable yellow_6_match                 "Yellow 6 matched term"

label variable blue_1_flag                    "Blue 1 identified"
label variable blue_1_match                   "Blue 1 matched term"

label variable blue_2_flag                    "Blue 2 identified"
label variable blue_2_match                   "Blue 2 matched term"

label variable glycerin_flag                  "Glycerin identified"
label variable glycerin_match                 "Glycerin matched term"

* Regulatory classifications
label variable EU_unauthorized                "Contains EU-unauthorized targeted additive"
label variable EU_restricted                  "Contains EU-restricted targeted additive"
label variable flagged_permitted              "Contains Flagged-permitted targeted additive"
label variable caseall                        "Contains any targeted additive"

* Number of targeted additives by regulatory group
label variable EU_unauthorized_count          "Number of EU-unauthorized targeted additives"
label variable EU_restricted_count            "Number of EU-restricted targeted additives"
label variable flagged_permitted_count        "Number of Flagged-permitted targeted additives"
label variable total_caseall_count            "Total number of targeted additives"

save ".../brandedfood_6.dta", replace
