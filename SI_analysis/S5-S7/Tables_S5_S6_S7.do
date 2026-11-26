********************************************************************************
* Paper:   Food additives in the U.S. food supply: Regulatory divergence,
*          market concentration, and exposure patterns
*
* Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
*          Vincenzina Caputo
*
* Code:    Sevval Buse Sariman
*
* Purpose: Generates SI Tables S5-S7 from the USDA Global Branded Food
*          Products Database (GBFPD), one row per product:
*
*   Table S5  Number of products containing each targeted additive
*   Table S6  Distribution (%) of products by number of targeted additives,
*             by food category
*   Table S7  Mean ingredient count and standard deviation, by food category
*
* Output:  Table_S5.xlsx, Table_S6.xlsx, Table_S7.xlsx (in the SI Appendix)
********************************************************************************

version 17
clear all
set more off

local infile "...//brandedfood_6.dta"
local outdir ".../tables"
capture mkdir "`outdir'"

* Helper: column widths, centered numbers, bold header row
capture program drop xltidy
program define xltidy
    args file ncol width1 width
    mata: b = xl(); b.load_book("`file'"); b.set_sheet("SI table"); b.set_column_width(1, 1, `width1'); b.set_column_width(2, `ncol', `width'); b.close_book()
    local L = char(64 + `ncol')
    putexcel set "`file'", sheet("SI table") modify
    putexcel B1:`L'`=_N', hcenter
    putexcel A1:`L'1, bold
end

* Targeted additives in table order (EU-unauthorized, EU-restricted,
* flagged-permitted) and their names in the table
local additives ///
    red_3 azodicarbonamide potassium_bromate green_3 titanium_dioxide        ///
    propylparaben brominated_oil olestra citrus_red_2 orange_b               ///
    aspartame saccharin sucralose acesulfame_k carrageenan red_40 yellow_5   ///
    yellow_6 nitrite_nitrate allsulfites partially_oil potassium_iodate      ///
    caramel_color bha bht propyl_gallate tbhq benzoate msg pg hfcs           ///
    blue_1 blue_2 glycerin

local nm_red_3             "Red 3"
local nm_azodicarbonamide  "Azodicarbonamide"
local nm_potassium_bromate "Potassium Bromate"
local nm_green_3           "Green 3"
local nm_titanium_dioxide  "Titanium Dioxide"
local nm_propylparaben     "Propylparaben"
local nm_brominated_oil    "Brominated Vegetable Oil"
local nm_olestra           "Olestra"
local nm_citrus_red_2      "Citrus Red 2"
local nm_orange_b          "Orange B"
local nm_aspartame         "Aspartame"
local nm_saccharin         "Saccharin"
local nm_sucralose         "Sucralose"
local nm_acesulfame_k      "Acesulfame Potassium"
local nm_carrageenan       "Carrageenan"
local nm_red_40            "Red 40"
local nm_yellow_5          "Yellow 5"
local nm_yellow_6          "Yellow 6"
local nm_nitrite_nitrate   "Nitrites and Nitrates"
local nm_allsulfites       "Sulfites"
local nm_partially_oil     "Partially Hydrogenated Oil"
local nm_potassium_iodate  "Potassium Iodate"
local nm_caramel_color     "Caramel Color"
local nm_bha               "BHA"
local nm_bht               "BHT"
local nm_propyl_gallate    "Propyl Gallate"
local nm_tbhq              "TBHQ"
local nm_benzoate          "Benzoates"
local nm_msg               "Monosodium Glutamate"
local nm_pg                "Propylene Glycol"
local nm_hfcs              "High Fructose Corn Syrup"
local nm_blue_1            "Blue 1"
local nm_blue_2            "Blue 2"
local nm_glycerin          "Glycerin"

* Food category names in Tables S6-S7
local cat_Alcohol        "Alcoholic beverages"
local cat_Baby           "Baby/infant foods"
local cat_Bakery         "Bakery products"
local cat_Baking         "Baking supplies"
local cat_Breakfast      "Breakfast foods"
local cat_Cereals        "Cereals"
local cat_Convenience    "Convenience/prepared foods"
local cat_Dairy          "Dairy products"
local cat_Deli           "Deli foods"
local cat_Dessert        "Desserts & ice creams"
local cat_Oil            "Edible oils & fats"
local cat_Egg            "Egg products & substitutes"
local cat_Energy         "Energy drinks"
local cat_Fruit          "Fruits & vegetables"
local cat_Honey          "Honey"
local cat_WaterEnhancer  "Liquid water enhancers"
local cat_Meat           "Meat products"
local cat_MilkAdditive   "Milk additives"
local cat_Nut            "Nuts, seeds & grains"
local cat_NonAlcohol     "Other non-alcoholic beverages"
local cat_Pasta          "Pasta, noodles & rice"
local cat_Pickled        "Pickled foods"
local cat_PlantBasedMeat "Plant-based meat products"
local cat_PlantBasedMilk "Plant-based milk products"
local cat_Sauce          "Sauces & condiments"
local cat_Seafood        "Seafood products"
local cat_Seasoning      "Seasonings"
local cat_Snack          "Snacks, sweet or savory"
local cat_Soft           "Soft beverages"
local cat_Stuffing       "Stuffings & gravy"
local cat_Supplement     "Supplements & vitamins"
local cat_Syrup          "Syrups & molasses"
local cat_TeaCoffee      "Tea & coffee beverages"
local cat_Water          "Water beverages"

* Data: one row per product, products with a food category
use "`infile'", clear
keep if !missing(categories) & categories != ""

* Display name of each category; rows of S6-S7 are sorted by this name
gen str40 catname = ""
levelsof categories, local(cats)
foreach c of local cats {
    quietly replace catname = "`cat_`c''" if categories == "`c'"
}
assert catname != ""
levelsof catname, local(catnames)

* ---------------- TABLE S5: number of products containing each targeted additive
tempfile s5 s6 s7
tempname P5 P6 P7
postfile `P5' str40 c1 str20 c2 using "`s5'", replace
post `P5' ("Additives") ("Count")
foreach a of local additives {
    quietly count if `a'_flag == 1
    post `P5' ("`nm_`a''") (string(r(N), "%12.0fc"))
}
postclose `P5'

* ---------------- TABLE S6: % of products by number of targeted additives, by category
postfile `P6' str40 c1 str12 c2 str12 c3 str12 c4 str12 c5 str12 c6 str12 c7 ///
    using "`s6'", replace
post `P6' ("Categories") ("0") ("1") ("2") ("3") ("4") ("5 or more")
foreach c of local catnames {
    quietly count if catname == "`c'"
    local N = r(N)
    forvalues k = 0/5 {
        if `k' < 5 quietly count if catname == "`c'" & total_caseall_count == `k'
        else       quietly count if catname == "`c'" & total_caseall_count >= 5
        local p`k' = string(100 * r(N) / `N', "%9.2f")
    }
    post `P6' ("`c'") ("`p0'") ("`p1'") ("`p2'") ("`p3'") ("`p4'") ("`p5'")
}
postclose `P6'

* ---------------- TABLE S7: mean ingredient count and standard deviation, by category
postfile `P7' str40 c1 str12 c2 str25 c3 str20 c4 using "`s7'", replace
post `P7' ("Categories") ("N") ("Mean ingredient count") ("Standard deviation")
foreach c of local catnames {
    quietly summarize ingredient_count if catname == "`c'"
    post `P7' ("`c'") (string(r(N), "%12.0fc")) ///
        (string(r(mean), "%9.2f")) (string(r(sd), "%9.2f"))
}
postclose `P7'

* ---------------- EXPORT
foreach t in 5 6 7 {
    use "`s`t''", clear
    local ncol = cond(`t' == 5, 2, cond(`t' == 6, 7, 4))
    local f "`outdir'/Table_S`t'.xlsx"
    export excel c1-c`ncol' using "`f'", sheet("SI table") replace
    xltidy "`f'" `ncol' 34 14
}
