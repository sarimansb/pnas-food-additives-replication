
********************************************************************************
* Paper:   Food additives in the U.S. food supply: Regulatory divergence,
*          market concentration, and exposure patterns
*
* Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
*          Vincenzina Caputo
*
* Code:    Sevval Buse Sariman
*
* Purpose: Finds where each targeted additive appears in the ingredient list
*          (its rank) for the rank-sensitive exposure analysis.
*
*     1. Keep one row per product (UPC x ingredient list).
*     2. Clean the ingredient list so it can be searched (no spaces, no
*        punctuation inside additive names).
*     3. Count the ingredients (number of , ; & delimiters + 1).
*     4. For each of the 34 targeted additives, find its rank in the list
*        (rank 1 = first ingredient) and its normalized position (rank / n).
*     5. Regulatory-group measures (any, flagged, restricted, unauth): earliest
*        rank, earliest position, number of group additives found.
*     6. Top-k indicators (k = 3, 5, 10) and case_top<k>: the regulatory case
*        counting only additives among the first k ingredients.
*     7. Merge the ranks onto all purchases and save.
*
* Output:  <category>_analysis_ranked.dta (one per category), used by the
*          do-file for SI Tables S12-S14
********************************************************************************
clear all
set more off

* Paths
local indir "...scanner/analysis"

* CATEGORIES
local categories Beverages BreakfastProducts PreparedFoods DairyEggsandMilkAlt ///
    SnacksandConfectionery SpecialNutrition Ingredients ///
    MeatSeafoodAlternatives Produce

* TARGETED ADDITIVES AND REGULATORY GROUPS
local m_unauth ///
    red_3 azodicarbonamide potassium_bromate green_3 titanium_dioxide ///
    propylparaben brominated_oil olestra citrus_red_2 orange_b
local m_restricted ///
    aspartame saccharin sucralose acesulfame_k carrageenan red_40 yellow_5 yellow_6 ///
    nitrite_nitrate allsulfites partially_oil potassium_iodate 
local m_flagged ///
    caramel_color bha bht propyl_gallate tbhq benzoate msg pg hfcs ///
    blue_1 blue_2 glycerin
local m_any `m_unauth' `m_restricted' `m_flagged'
local targeted `m_any'
local groupnames any unauth restricted flagged
local kvals 3 5 10

********************************************************************************
* BACKUP NAMES OF EACH ADDITIVE 
*
* Used to locate a flagged additive when its matched text cannot be found in
* the cleaned ingredient list. This happens when the match is a label rather
* than text from the list (e.g. "red list ..., 3", written by the detection
* step for dye lists such as "RED 40 & 3"), or when the matched term is
* written differently from the list. The name found earliest in the list
* gives the additive's position.
*
* Written in cleaned form (lowercase, no spaces, no - . # / * or apostrophes,
* fd&c -> fdc); commas separate ingredients.
********************************************************************************
*EU-unauthorized
local fb_red_3             red3 redno3 fdcredno3 fdc3 erythrosine red40,3 reds3,40 red3,40 ci45430 e127
local fb_azodicarbonamide  azodicarbonamide azodicarboxamide e927
local fb_potassium_bromate potassiumbromate bromicacid
local fb_green_3           green3 greenno3 fdcgreenno3 fastgreenfcf ci42053 e143
local fb_titanium_dioxide  titaniumdioxide titaniumoxide ci77891 e171
local fb_propylparaben     propylparaben e216
local fb_brominated_oil    brominatedvegetableoil brominated bvo
local fb_olestra           olestra olean
local fb_citrus_red_2      citrusred2 citrusredno2
local fb_orange_b          orangeb
* EU-restricted
local fb_aspartame         aspartame aspartam e951
local fb_saccharin         saccharin e954
local fb_sucralose         sucralose sucrlose sucrolose sucrlase sucralos trichlorogalactosucrose e955
local fb_acesulfame_k      acesulfamepotassium acesulfamek acek e950
local fb_carrageenan       carrageenan carrageenin chondrusextract irishmoss e407
local fb_red_40            red40 redno40 fdcredno40 allurared alluraredac red3,40 reds3,40 red40,3 redfdc40 fdcre40 ci16035 e129
local fb_yellow_5          yellow5 yellowno5 fdcyellowno5 tartrazine yellow5,6 yellow6,5 yellowno5,6 yellowno6,5 yellows5,6 yellowfdcno5 ci19140 e102
local fb_yellow_6          yellow6 yellowno6 fdcyellowno6 sunsetyellow yellow5,6 yellow6,5 yellowno5,6 yellowno6,5 yellows5,6 yellowno5&no6 yellowfdc6 fdcvellow6 ci15985 e110
local fb_nitrite_nitrate   sodiumnitrite sodium,nitrite potassiumnitrite potassium,nitrite sodiumnitrate sodium,nitrate potassiumnitrate potassium,nitrate e249 e250 e251 e252
local fb_allsulfites       sulfit sulphit metabisulfite metabisulphite bisulfite bisulphite sulfurdioxide sulphurdioxide sulfatingagent sulfitingagent e220 e221 e222 e223 e224 e226 e227 e228
local fb_partially_oil     partiallyhydrogenated partlyhydrogenated partialhydrogenated
local fb_potassium_iodate  potassiumiodate kio3
* Flagged-permitted
local fb_caramel_color     caramel e150
local fb_bha               butylatedhydroxyanisole bha e320
local fb_bht               butylatedhydroxytoluene bht e321
local fb_propyl_gallate    propylgallate e310
local fb_tbhq              tbhq tertbutylhydroquinone butylhydroquinone e319
local fb_benzoate          sodiumbenzoate potassiumbenzoate sodium,benzoate potassium,benzoate benzoateofsoda benzoatedesodium benzoatodesodio e211 e212
local fb_msg               monosodiumglutamate monosodium,glutamate monosodiumlglutamate glutamatedesodium msg e621
local fb_pg                propyleneglycol propylene,glycol propane12diol 1,2propanediol e1520
local fb_hfcs              highfructosecornsyrup highfructosecorn,syrup highfructose,cornsyrup highfructosecomsyrup glucosefructosesyrup fructoseglucosesyrup glucose,fructosesyrup fructose,glucosesyrup isoglucose hfcs
local fb_blue_1            blue1 blueno1 fdcblueno1 brilliantblue blue1,2 blue2,1 blues1,2 bluefdc1 ci42090 e133
local fb_blue_2            blue2 blueno2 fdcblueno2 indigotine indigocarmine blue1,2 blue2,1 blues1,2 ci73015 e132
local fb_glycerin          glycerin glycerine glycerol e422

* Color numbers (step 4d): in a two-color name such as "yellow5,6", the
* second color (yellow 6) is one ingredient after the first 
local color_red_3    3
local color_red_40   40
local color_yellow_5 5
local color_yellow_6 6
local color_blue_1   1
local color_blue_2   2
local color_green_3  3

* HELPER PROGRAMS
* countdelim newvar textvar: number of ingredient delimiters (, ; &) in textvar
capture program drop countdelim
program define countdelim
    args newvar text
    gen long `newvar' = 3*length(`text') ///
        - length(subinstr(`text', ",", "", .)) ///
        - length(subinstr(`text', ";", "", .)) ///
        - length(subinstr(`text', "&", "", .))
end

* cleantext var [, hit]: make text searchable.
*   - remove spaces, tabs and line breaks
*   - "fd&c"/"d&c" -> "fdc"/"dc" as whole words, before spaces are removed
*   - "glucose&fructosesyrup" is one ingredient
*   - "redno,40" -> "redno40" (comma inside one color name)
*   - "yellow#5/#6" -> "yellow5,6" (two colors, two ingredients)
*   - remove - . # / * and apostrophes (never delimiters)
* Option hit (for the matched text of one additive): also remove brackets and
* colons, and turn "and" into a comma.
capture program drop cleantext
program define cleantext
    syntax varname [, hit]
    local v `varlist'
    quietly {
        replace `v' = ustrregexra(`v', "\bfd ?& ?c\b", "fdc")
        replace `v' = ustrregexra(`v', "\bd ?& ?c\b", "dc")
        replace `v' = subinstr(`v', " ", "", .)
        replace `v' = subinstr(`v', char(9), "", .)
        replace `v' = subinstr(`v', char(10), "", .)
        replace `v' = subinstr(`v', char(13), "", .)
        if "`hit'" != "" {
            replace `v' = subinstr(`v', "\", "", .)
            replace `v' = subinstr(`v', ")", "", .)
            replace `v' = subinstr(`v', "(", "", .)
            replace `v' = subinstr(`v', "{", "", .)
            replace `v' = subinstr(`v', "}", "", .)
            replace `v' = subinstr(`v', "[", "", .)
            replace `v' = subinstr(`v', "]", "", .)
            replace `v' = subinstr(`v', ":", "", .)
        }
        replace `v' = subinstr(`v', "glucose&fructosesyrup", "glucosefructosesyrup", .)
        replace `v' = subinstr(`v', "fructose&glucosesyrup", "fructoseglucosesyrup", .)
        foreach c in redno,3 redno,40 greenno,3 yellowno,5 yellowno,6 blueno,1 blueno,2 ///
                     red,3 red,40 green,3 yellow,5 yellow,6 blue,1 blue,2 {
            local nocomma = subinstr("`c'", ",", "", 1)
            replace `v' = subinstr(`v', "`c'", "`nocomma'", .)
        }
        foreach sep in "/" "&" ";" "and" {
            foreach trio in "yellow 5 6" "yellow 6 5" "yellows 5 6" "yellows 6 5" ///
                            "blue 1 2" "blue 2 1" "blues 1 2" "blues 2 1" ///
                            "red 3 40" "red 40 3" "reds 3 40" "reds 40 3" {
                tokenize `trio'
                replace `v' = subinstr(`v', "`1'#`2'`sep'#`3'", "`1'`2',`3'", .)
                replace `v' = subinstr(`v', "`1'`2'`sep'`3'", "`1'`2',`3'", .)
            }
        }
        if "`hit'" != "" {
            replace `v' = subinstr(`v', "and/or", "and", .)
            replace `v' = subinstr(`v', "and", ",", .)
            forvalues z = 1/3 {
                replace `v' = subinstr(`v', ",,", ",", .)
            }
        }
        foreach c in "-" "." "#" "/" "*" {
            replace `v' = subinstr(`v', "`c'", "", .)
        }
        replace `v' = subinstr(`v', char(39), "", .)
    }
end
*Ingredient text was standardized using rule-based cleaning procedures developed through manual inspection of observed labeling inconsistencies. The procedures removed non-informative formatting characters, corrected punctuation embedded within additive names, and standardized separators between multiple color additives to improve consistency in subsequent additive identification.

* CATEGORY LOOP
foreach cat of local categories {
    use "`indir'/`cat'_analysis.dta", clear
    capture drop __*
    capture drop _merge

    * Product key: UPC + ingredient list. Stata cannot sort on long text, so
    * the list is represented by its first 244 characters and its length.
    gen str244 zz_head = substr(ingredients, 1, 244)
    gen long   zz_len  = length(ingredients)
    tempfile fulldata ranks
    save "`fulldata'"

    * 1. ONE ROW PER PRODUCT
    local keepvars upc_x zz_head zz_len ingredients clean_ingredients ingredient_count
    foreach a of local targeted {
        local keepvars `keepvars' `a'_flag `a'_match
    }
    keep `keepvars'
    bysort upc_x zz_head zz_len: keep if _n == 1

    foreach a of local targeted {
        capture confirm string variable `a'_match
        if _rc {
            drop `a'_match
            gen str1 `a'_match = ""
        }
    }

    * 2. CLEAN THE INGREDIENT LIST FOR SEARCHING
    gen strL placement_compact = clean_ingredients
    cleantext placement_compact
    compress

    * 3. NUMBER OF INGREDIENTS = DELIMITERS + 1
    clonevar ingredient_count_original = ingredient_count
    countdelim w_n placement_compact
    replace ingredient_count = 1 + w_n if strtrim(placement_compact) != ""
    replace ingredient_count = .       if strtrim(placement_compact) == ""
    drop w_n

    * 4. RANK AND NORMALIZED POSITION OF EACH ADDITIVE
    foreach a of local targeted {
        quietly {
            * (a) Look for the matched text from the detection step
            gen strL w_hit = lower(`a'_match) if `a'_flag == 1
            cleantext w_hit, hit
            * Some match values are descriptions, not text: e.g. "(substring)"
            replace w_hit = "" if `a'_flag == 1 & ( ///
                strpos(lower(`a'_match), "(") | strpos(lower(`a'_match), "[") | ///
                strpos(lower(`a'_match), "...") | strpos(lower(`a'_match), "list"))
            gen long w_pos = strpos(placement_compact, w_hit) if `a'_flag == 1 & w_hit != ""
            replace w_pos = . if w_pos == 0

            * (b) Not found: use the earliest of the additive's other names
            gen long w_fbpos = .
            gen strL w_fbtext = ""
            foreach f of local fb_`a' {
                gen long w_this = strpos(placement_compact, "`f'") if `a'_flag == 1
                replace w_fbtext = "`f'"  if w_this > 0 & w_this < . & (missing(w_fbpos) | w_this < w_fbpos)
                replace w_fbpos  = w_this if w_this > 0 & w_this < . & (missing(w_fbpos) | w_this < w_fbpos)
                drop w_this
            }
            replace w_hit = w_fbtext if `a'_flag == 1 & missing(w_pos) & w_fbpos < .
            replace w_pos = w_fbpos  if `a'_flag == 1 & missing(w_pos) & w_fbpos < .

            * (c) Rank = 1 + delimiters before the additive
            gen strL w_before = substr(placement_compact, 1, w_pos - 1) if w_pos > 0 & w_pos < .
            countdelim w_nbefore w_before
            gen int rank_`a' = 1 + w_nbefore if w_pos > 0 & w_pos < .

            * (d) Colors: in "yellow5,6", yellow 6 gets one more rank
            if "`color_`a''" != "" {
                gen int w_cpos = strpos(w_hit, "`color_`a''") if rank_`a' < .
                gen strL w_cbefore = substr(w_hit, 1, w_cpos - 1) if w_cpos > 0 & w_cpos < .
                countdelim w_ncbefore w_cbefore
                replace rank_`a' = rank_`a' + w_ncbefore if rank_`a' < . & w_cpos > 0 & w_cpos < .
            }

            * (e) Drop impossible ranks (below 1 or above the number of ingredients), 
			* compute the normalized position, and mark additives that are flagged but could not be located.
            gen byte invalid_`a' = `a'_flag == 1 & rank_`a' < . ///
                & (rank_`a' < 1 | rank_`a' > ingredient_count)
            replace rank_`a' = . if invalid_`a' == 1
            gen double pos_`a' = rank_`a' / ingredient_count if rank_`a' < . & ingredient_count > 0
            gen byte notfound_`a' = `a'_flag == 1 & missing(rank_`a')
            label variable rank_`a' "Ingredient-list rank: `a'"
            label variable pos_`a'  "Normalized position (rank/n): `a'"

            drop w_*
        }
    }

    * 5. REGULATORY-GROUP MEASURES
    foreach g of local groupnames {
        local rv ""
        local pv ""
        local fv ""
        local nv ""
        foreach a of local m_`g' {
            local rv `rv' rank_`a'
            local pv `pv' pos_`a'
            local fv `fv' `a'_flag
            local nv `nv' notfound_`a'
        }
        * highest_rank = earliest position in the list (smallest rank number)
        egen highest_rank_`g' = rowmin(`rv')
        egen double minpos_`g' = rowmin(`pv')
        gen str32 highest_additive_`g' = ""
        foreach a of local m_`g' {
            replace highest_additive_`g' = "`a'" if highest_additive_`g' == "" ///
                & highest_rank_`g' < . & rank_`a' == highest_rank_`g'
        }
        egen flagcount_`g'      = rowtotal(`fv')
        egen rankcount_`g'      = rownonmiss(`rv')
        egen notfound_count_`g' = rowtotal(`nv')
        gen byte placement_complete_`g' = flagcount_`g' == rankcount_`g'
        label variable minpos_`g' "Earliest normalized position: `g'"
    }

    * 6. TOP-K INDICATORS AND REGULATORY CASE IN THE TOP K
    *    1 = among the first k ingredients, 0 = absent or below rank k,
    *    . = present but not located
    foreach k of local kvals {
        quietly {
            foreach a of local targeted {
                gen byte top`k'_`a' = 0 if `a'_flag == 0
                replace top`k'_`a' = rank_`a' <= `k' if rank_`a' < .
                label variable top`k'_`a' "`a' among first `k' ingredients"
            }
            foreach g of local groupnames {
                gen byte top`k'_`g' = 0 if flagcount_`g' == 0
                replace top`k'_`g' = 1 if highest_rank_`g' < . & highest_rank_`g' <= `k'
                replace top`k'_`g' = 0 if flagcount_`g' > 0 & placement_complete_`g' == 1 ///
                    & highest_rank_`g' < . & highest_rank_`g' > `k'
                label variable top`k'_`g' "Any `g' additive among first `k' ingredients"
            }
            gen byte case_top`k' = .
            replace case_top`k' = 0 if placement_complete_any == 1 & top`k'_any == 0
            replace case_top`k' = 1 if top`k'_flagged == 1
            replace case_top`k' = 2 if top`k'_restricted == 1
            replace case_top`k' = 3 if top`k'_unauth == 1
        }
        label define case_top`k'_lbl ///
            0 "Other/no targeted additive in top `k'" ///
            1 "Flagged-permitted additive in top `k'" ///
            2 "EU-restricted additive in top `k'" ///
            3 "EU-unauthorized additive in top `k'", replace
        label values case_top`k' case_top`k'_lbl
    }

    * 7. MERGE RANKS ONTO ALL PURCHASES AND SAVE THE RANKED FILE
    * Keep the key and the new rank variables only
    drop ingredients clean_ingredients placement_compact *_flag *_match
    compress
    save "`ranks'"

    use "`fulldata'", clear
    drop ingredient_count
    merge m:1 upc_x zz_head zz_len using "`ranks'", keep(master match) nogenerate
    save "`indir'/`cat'_analysis_ranked.dta", replace
}
