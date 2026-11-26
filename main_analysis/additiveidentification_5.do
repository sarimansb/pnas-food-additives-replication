********************************************************************************
* Paper:   Food additives in the U.S. food supply: Regulatory divergence,
*          market concentration, and exposure patterns
*
* Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
*          Vincenzina Caputo
*
* Code:    Sevval Buse Sariman
*
* Purpose: This do-file identifies the targeted food additives from product 
*		   ingredient lists in the USDA FoodData Central Branded Food Products 
*          Database (GBFPD). Ingredient text is first standardized to lowercase,
*          and statements indicating the absence of an additive (e.g., "no", 
*          "without", or "free from") are removed before detection. 
*          Additives are then identified using predefined names, alternative 
*          spellings, common abbreviations, E-numbers, known misspellings, and 
*          flexible punctuation/spacing patterns. 
* 		   Boundary and exclusion rules are applied where needed to reduce 
*          false-positive matches. 
*          For each additive, the code creates an indicator for its presence and
*          records the term responsible for the match.
*
* In this code we generate:
*         (1) Additive-specific indicator variables (*_flag): equal to 1 when the 
*         targeted additive is identified in the ingredient list and 0 otherwise.
*
*         (2) Additive-specific match variables (*_match): record the name, 
*         spelling, abbreviation, E-number, or other search term that triggered 
*         the match.
********************************************************************************

*Import the dta file created in the previous do file.
use ".../brandedfood_3.dta", clear

gen strL ingredients_lower = ustrlower(ingredients)
gen strL ing_scan = ingredients_lower

****************************************************
* REMOVE NEGATED ADDITIVE CLAIMS BEFORE ADDITIVE IDENTIFICATION
*
* Ingredient text may mention an additive to state that it is NOT present
* (e.g., "no MSG," "without aspartame," "BHA free," or
* "no nitrates or nitrites added"). Because subsequent detection is based
* on additive names appearing in the ingredient text, these statements
* are removed from ing_scan before any additive flags are constructed.
*
* NEGNAME identifies additive names and common additive-related terms that
* may occur in such absence claims. More specific expressions are listed
* before shorter alternatives to avoid partial matching.
****************************************************

* Additive names that can appear inside a negation claim (manually identified).
local NEGNAME "(aspartame|sucralose|saccharine?|acesulfame([ ]*(potassium|k))?|ace[ ]*-?[ ]*k|monosodium[ ]+glutamate|msg|high[ ,._-]*fructose[ ,._-]*corn[ ,._-]*syrup|hfcs|corn[ ]+syrup|carrageenan|bha|bht|tbhq|sodium[ ]+benzoate|potassium[ ]+benzoate|benzoates?|sodium[ ]+nitrite|sodium[ ]+nitrate|potassium[ ]+nitrite|potassium[ ]+nitrate|nitrates?|nitrites?|sulfites?|sulphites?|partially[ ]+hydrogenated([ ]+(vegetable|soybean|palm|cottonseed|corn|canola))?([ ]+oils?)?|hydrogenated[ ]+oils?|brominated[ ]+vegetable[ ]+oil|bvo|olestra|glycerine|glycerin|glycerol|propylene[ ]+glycol|titanium[ ]+dioxide|potassium[ ]+bromate|azodicarbonamide|propylparabens?|parabens?|caramel[ ]+colou?r(ing)?s?|artificial[ ]+(colou?rs?|flavou?rs?|sweeteners?|preservatives?)|preservatives?|(fd&c[ ]*)?(red|yellow|blue|green)[ ]*(no[.]?|n[.]?|#|number)?[ ]*[0-9]+|dyes?|colou?rs?|added)"

* NEGTRG defines expressions that explicitly indicate absence, including
* "no," "contains no," "does not contain," "without," and "free from."
local NEGTRG "(contains[ ]+no|does[ ]*n[o']*t[ ]+contain|w/[ ]*no|no[ ]+added|without|free[ ]+(of|from)|no)"

* Explicit connectors such as "and," "or," "&," and "/" strongly indicate
* that multiple additive names belong to the same absence claim. The
* negation is therefore allowed to continue to any recognized additive
* name following these connectors.
local NEGSTRONG "([ ]*(/|&|and|or|no)[ ]+)"

* Commas and semicolons are ambiguous because they may either continue an
* absence claim or separate the next genuine ingredient. Therefore, after
* a comma or semicolon, the negation is continued only when the following
* term belongs to a narrower set of expressions commonly observed in
* multi-additive absence claims. For example, "NO BHA, BHT" is removed in
* full, whereas "NO MSG, SODIUM BENZOATE (PRESERVATIVE)" stops after MSG
* so that a genuinely listed sodium benzoate is not removed.
local NEGWEAK "([ ]*[,;][ ]*(no[ ]+)?)"
local NEGCLAIM "(aspartame|sucralose|saccharine?|acesulfame([ ]*(potassium|k))?|ace[ ]*-?[ ]*k|monosodium[ ]+glutamate|msg|high[ ,._-]*fructose[ ,._-]*corn[ ,._-]*syrup|hfcs|corn[ ]+syrup|carrageenan|bha|bht|tbhq|nitrates?|nitrites?|sulfites?|sulphites?|partially[ ]+hydrogenated([ ]+(vegetable|soybean|palm|cottonseed|corn|canola))?([ ]+oils?)?|hydrogenated[ ]+oils?|brominated[ ]+vegetable[ ]+oil|bvo|olestra|propylparabens?|parabens?|artificial[ ]+(colou?rs?|flavou?rs?|sweeteners?|preservatives?)|preservatives?|(fd&c[ ]*)?(red|yellow|blue|green)[ ]*(no[.]?|n[.]?|#|number)?[ ]*[0-9]+|dyes?|colou?rs?|flavou?rs?|added)"

* Pattern 1: Remove claims in which an absence trigger precedes one or
* more additive names, including space-, colon-, and hyphen-separated
* forms such as "NO MSG," "NO-MSG," "WITHOUT ASPARTAME," and
* "NO ASPARTAME, SUCRALOSE OR SACCHARIN ADDED."
replace ing_scan = ustrregexra(ing_scan, "(^|[^a-z])`NEGTRG'[ :-]+`NEGNAME'((`NEGSTRONG'`NEGNAME')|(`NEGWEAK'`NEGCLAIM'))*([ ]+added)?", " ")

* Pattern 2: Remove postfix "-free" or " free" claims, such as
* "ASPARTAME-FREE" and "CARRAGEENAN FREE."
replace ing_scan = ustrregexra(ing_scan, "(^|[^a-z])`NEGNAME'[ -]*free", " ")

* Pattern 3: Remove statements in which an additive name is followed
* shortly by "not added," such as "NATURAL SULFITES NOT ADDED."
* The intervening text is limited to 40 characters and cannot cross
* common ingredient-list delimiters.
replace ing_scan = ustrregexra(ing_scan, "(^|[^a-z])`NEGNAME'[^.;,()]{0,40}not[ ]+added", " ")

****************************************************
* HELPER PROGRAM 1: ADDITIVE NAME MATCHING
*
* This program searches the cleaned ingredient text for a specified
* additive name. It allows differences in spacing and punctuation while
* applying boundaries that help prevent matches inside unrelated words
* or numbers.
*
* When a match is found:
*   - flagvar is set to 1; and
*   - matchvar records the additive term that produced the match.
*
* The sep option specifies what may appear between characters of the
* additive search term:
*
*   space   = allows spaces only. For example, a collapsed search term
*             such as "titaniumdioxide" can match "titanium dioxide."
*
*   any     = allows spaces or punctuation. This accommodates formatting
*             variants such as "titanium-dioxide" or "titanium.dioxide."
*
*   nocomma = allows spaces or punctuation except commas and semicolons.
*             Because commas and semicolons generally separate ingredients,
*             this prevents a match from extending across two different
*             ingredient-list entries.
****************************************************

capture program drop addflag
program define addflag
    args flagvar matchvar term sep src bound
	* Define the allowed spacing/punctuation within the additive name.
    if "`sep'" == "" | "`sep'" == "space" local SEP "[ ]*"
    else if "`sep'" == "any"              local SEP "[^a-z0-9]*"
    else if "`sep'" == "nocomma"          local SEP "[^a-z0-9,;]*"
	* Search ing_scan 
    if "`src'" == "" local src "ing_scan"

	* Build a flexible search pattern from the supplied additive term.
    * Each character is retained, while the selected SEP pattern is
    * allowed between characters.
    local t = subinstr(`"`term'"', "\", "", .)
    local n = ustrlen(`"`t'"')
    local rx ""
    forvalues i = 1/`n' {
        local c = usubstr(`"`t'"', `i', 1)
        if `"`c'"' == "." local c "[^a-z0-9 ]?"
        else if inlist(`"`c'"', "(", ")", "[", "]", "*", "+", "?", "|", "^") local c = "\" + `"`c'"'
        else if inlist(`"`c'"', "{", "}") local c = "\" + `"`c'"'
        local rx `"`rx'`c'"'
        if `i' < `n' local rx `"`rx'`SEP'"'
    }

    * British spelling: a term containing "color" is ALSO matched as "colour"
    * * (and "colors" as "colours"), so the term lists do not need separate
	* British spellings.
    local t2 = subinstr(`"`t'"', "color", "colour", .)
    if `"`t2'"' != `"`t'"' {
        local n2 = ustrlen(`"`t2'"')
        local rx2 ""
        forvalues i = 1/`n2' {
            local c = usubstr(`"`t2'"', `i', 1)
            if `"`c'"' == "." local c "[^a-z0-9 ]?"
            else if inlist(`"`c'"', "(", ")", "[", "]", "*", "+", "?", "|", "^") local c = "\" + `"`c'"'
            else if inlist(`"`c'"', "{", "}") local c = "\" + `"`c'"'
            local rx2 `"`rx2'`c'"'
            if `i' < `n2' local rx2 `"`rx2'`SEP'"'
        }
        local rx `"(`rx')|(`rx2')"'
    }
	
	* Prevent the additive name from starting inside another word.
    local first = usubstr(`"`t'"', 1, 1)
    if ustrregexm(`"`first'"', "[0-9]") local head "(?<![0-9a-z])"
    else local head "(?<![a-z])"
    * bound == "nohead": plain substring on the left. Only for long,
    * chemically unambiguous names (titanium dioxide, propylparaben,
    * sodium benzoate, caramel color) where OCR sometimes glues the name
    * to the previous word (TOTITANIUM DIOXIDE, ANDPROPYL PARABENS,
    * BENSODIUM BENZOATE, AGARAGARCARAMEL COLOR).
    if "`bound'" == "nohead" local head ""
    local last = usubstr(`"`t'"', `n', 1)
    if ustrregexm(`"`last'"', "[0-9]") local tail "(?![0-9])"
    else local tail ""

    tempvar h
    quietly gen byte `h' = ustrregexm(`src', `"`head'`rx'`tail'"')
    quietly replace `flagvar' = 1 if `h'
    quietly replace `matchvar' = `"`term'"' if `h' & `matchvar' == ""
end

****************************************************
* HELPER PROGRAM 2: E-NUMBER MATCHING
*
* Searches ingredient text for additive E-numbers written either with
* an explicit "E" (e.g., E127, E 127, E-127) or as standalone numeric
* codes (e.g., 127). Numeric matches are excluded when they appear to
* represent measurements, decimals, counts, product/specification
* numbers, or other known non-additive uses. Additive-specific
* exclusions can also be supplied when needed.
*
* If a valid match is found, flagvar is set to 1 and matchvar records
* the matched code.
****************************************************

capture program drop ecodeflag
program define ecodeflag
    args flagvar matchvar num extra
    local U "(mg|mgs|g|gr|grams?|mcg|ug|µg|kg|ml|l|liters?|litres?|oz|lb|lbs|ppm|ppb|iu|cfu|mesh|kcal|cal|calories?|ct|count|servings?|pieces?|mm|cm|bloom|%)"

    tempvar ok
    quietly gen byte `ok' = 1
    if `"`extra'"' != "" {
        quietly replace `ok' = 0 if ustrregexm(ing_scan, `"`extra'"')
    }

    * Explicit E-code
    tempvar h1
    quietly gen byte `h1' = ustrregexm(ing_scan, "(^|[^0-9a-z])e[ ]*-?[ ]*`num'([^0-9a-z]|$)") ///
        & !ustrregexm(ing_scan, "(^|[^0-9a-z])e[ ]*-?[ ]*`num'[ ]*[+/-]?[ ]*`U'([^a-z]|$)") ///
        & !ustrregexm(ing_scan, "(^|[^0-9a-z])e[ ]*-?[ ]*`num'[.][0-9]") ///
        & !ustrregexm(ing_scan, "vitamin[ ]+e[ ]*-?[ ]*`num'") ///
        & `ok'
    quietly replace `flagvar' = 1 if `h1'
    quietly replace `matchvar' = "e`num'" if `h1' & `matchvar' == ""

    * Plain standalone code
    tempvar h2
    quietly gen byte `h2' = ustrregexm(ing_scan, "(?<![0-9a-z.-])`num'(?![0-9a-z-])(?![.][0-9])") ///
        & !ustrregexm(ing_scan, "(?<![0-9a-z.-])`num'[ ]*[+/-]?[ ]*`U'([^a-z]|$)") ///
        & !ustrregexm(ing_scan, "`num'[ ]*(million|billion|thousand)") ///
        & !ustrregexm(ing_scan, "`num'[ ]*(th|st|nd|rd)([^a-z]|$)") ///
        & !ustrregexm(ing_scan, "tds[ ]*:[ ]*`num'") ///
        & !ustrregexm(ing_scan, "(saladizer|bloom|emulpals)[ ]+`num'") ///
        & !ustrregexm(ing_scan, "(lot|lotr|batch|code|item|ref|sku|no|number)[ ]*[.:#]?[ ]*`num'") ///
        & !ustrregexm(ing_scan, "`num'[ ]*(of|/)[ ]*[0-9]") ///
        & !ustrregexm(ing_scan, "less[ ]+than[ ]+`num'[ ]*of") ///
        & !ustrregexm(ing_scan, "corn[ ]+meal[ ]*#?[ ]*`num'") ///
        & `ok'
    quietly replace `flagvar' = 1 if `h2'
    quietly replace `matchvar' = "`num'" if `h2' & `matchvar' == ""
end

* Build the search terms for each additive from the fuzzy-matching results.
* Each list contains the spelling variants observed in the GBFPD ingredient
* text, including combined listings with other dyes (e.g., "RED 40 & 3").

* ------------------------------------- Red 3 --------------------------------------------
gen red_3_flag = 0
gen red_3_match = ""

foreach term in red3 red#3 redno.3 redno3 fd&credno.3 fd&credno3 erythrosine fd&credno40&3 red3&40 redno3&40 red40&3 redno40&3 redno40and3 red#3&40 red#3&#40 red#40&3 red#40&#3 reds40&3 reds40and3 reds40#3 reds40&#3 reds#40&3 reds#40and3 reds#40#3 reds#40&#3 redsno40&3 reds#40and#3 redsno40and3 redsno40#3 redsno40&#3 redsno.40&3 redsno.40and3 redsno.40#3 redsno.40&#3 redsn40&3 redsn40and3 redsn40#3 redsn40&#3 red40and3 red#40and3 redno40and3 redno.40and3 fd&creds40&3 fd&creds40and3 fd&creds#40&3 fd&creds#40and3 fd&credsno40&3 fd&credsno40and3 fd&credsno.40&3 fd&credsno.40and3 reds40and3 redlake3 redlake#3 redlake.3 redlakeno3 redlakeno.3 redlakeno#3 redlakeno.#3 redlaken3 redlaken.3 redlaken#3 redslake3 redslake#3 redslake.3 redslakeno3 redslakeno.3 redslakeno#3 redslakeno.#3 fd&credlake3 fd&credlake#3 fd&credlake.3 fd&credlakeno3 fd&credlakeno.3 fd&credlakeno#3 fd&credlakeno.#3 red40lake&3 red40lakeand3 red40lake#3 red40lake3 red#40lake&3 red#40lakeand3 red#40lake#3 red#40lake3 redno40lake&3 redno40lakeand3 redno40lake#3 redno40lake3 redno.40lake&3 redno.40lakeand3 redno.40lake#3 redno.40lake3 reds40lake&3 reds40lakeand3 reds40lake#3 reds40lake3 redslake40&3 redslake40and3 redslake40#3 redslake40andred3 fd&cred40lake&3 fd&cred40lakeand3 fd&cred40lake#3 fd&cred40lake3 fd&credno40lake&3 fd&credno40lakeand3 fd&credno40lake#3 fd&credno40lake3 fd&credno.40lake&3 fd&credno.40lakeand3 fd&credno.40lake#3 fd&credno.40lake3 redcolor#3 redcolors#3 redcolor#3lake redcolors#3lake redcolorno.3 redcolorsno.3 redcolour#3 redcolours#3 colorred#3 colorsred#3 colorredno.3 colourred#3 coloursred#3 red#3(color) red#3(colors) redno.3(color) fd&credcolor#3 fd&credcolors#3 fd&credcolorno.3 f.d.&c.redcolor#3 redlakecolor#3 redlakecolors#3 red#3lake redcolor#3and#40 redcolors#3and#40 redcolor#3and40 redcolors#3and40 redcolor#3&40 redcolors#3&40 redcolor#3&#40 redcolors#3&#40 redcolor#3and#40lake redcolors#3and#40lake redcolor#3lakeand#40lake redcolors#3lakeand#40lake redcolorno.3and40 redcolorsno.3and40 redcolorno.3andno.40 redcolorsno.3andno.40 redcolornos.3and40 redcolorsnos.3and40 redcolorno.3&40 redcolorsno.3&40 redcolour#3and#40 redcolours#3and#40 redcolour#3and40 redcolours#3and40 redcolour#3&40 redcolours#3&40 colorred#3and#40 colorsred#3and#40 red#3and#40(color) red#3and#40(colors) redno.3andno.40(color) rednos.3&40 fd&credcolor#3and#40 fd&credcolors#3and#40 fd&credcolorno.3andno.40 fd&credcolorsno.3andno.40 fd&credcolors#3&#40 fd&cred#3and#40color fd&cred#3and#40colors f.d.&c.redcolor#3and#40 f.d.&c.redcolors#3and#40 redcolors#3&#40lake redlakecolor#3and#40 redlakecolors#3and#40 red#3lakeandred#40lake {
    addflag red_3_flag red_3_match `term'
}

* E127 / 127 (dosage, decimals, product/spec codes excluded by ecodeflag)
ecodeflag red_3_flag red_3_match 127

* accounting for spelling mistakes
foreach term in red40&#3 redno.40&3 reds40&3 redcolor#3 fd&credif3 fd&credn3 fd&credcolor#40&#3 red#3 red#40&#3 red#40&3 reddye#3 reds3&40 reds3&40. fd&cred3 fd&cred#3 fd&cred.3 redfd&c#3 redfd&c3 redfd&cno.3 {
    addflag red_3_flag red_3_match `term'
}

* ------------------------------ Azodicarbonamide ------------------------------
gen azodicarbonamide_flag = 0
gen azodicarbonamide_match = ""

foreach term in azodicarbonamide improvere927 diazenedicarboxamide azodicarboxamide {
    addflag azodicarbonamide_flag azodicarbonamide_match `term'
}

* Chemical names that contain internal punctuation (1,1'-azobisformamide etc.):
* punctuation-flexible matching (this replaces the old ingredients_key,
* which was used here before it was ever created)
foreach term in formamide11azobis 11azobisformamide 11biureadelta {
    addflag azodicarbonamide_flag azodicarbonamide_match `term' any
}

* E927 / 927
ecodeflag azodicarbonamide_flag azodicarbonamide_match 927

* accounting for spelling mistakes
foreach term in anozodicarbonamide axodicarbonamide azobicarbonamide azodiacarbonamide azodibarbonamide azodicabonamide azodicarbon azodicarbonamid azodicarbonaminde azodicarbonimide azodicarbonmide azodicarbonomide azodicaronamide azodizcarbonamide azodycarbonamide azoidcarbonamide azooicarbonamide azordicarbonamide doughconditionerazodiar {
    addflag azodicarbonamide_flag azodicarbonamide_match `term'
}

* ------------------------------- Potassium Bromate -------------------------------
gen potassium_bromate_flag = 0
gen potassium_bromate_match = ""

addflag potassium_bromate_flag potassium_bromate_match potassiumbromate

* E924 / 924
ecodeflag potassium_bromate_flag potassium_bromate_match 924

* accounting for spelling mistakes
foreach term in potasiumbromate potassiiumbromate potassiumbromade potassiumbromatte potassiumpromate pottassiumbromate {
    addflag potassium_bromate_flag potassium_bromate_match `term'
}

* ---------------------------------------- Green 3 ---------------------------------------
gen green_3_flag = 0
gen green_3_match = ""

foreach term in green3 green#3 green.3 greenno3 greenno.3 greenno#3 greenno.#3 greenn3 greenn.3 greenn#3 greenn°3 greennÂ°3 greennâ°3 greennumber3 greennum3 foodgreen3 fastgreenfcf fastgreenf.c.f fastgreenf.c.f. fd&cgreen3 fd&cgreen#3 fd&cgreen.3 fd&cgreenno3 fd&cgreenno.3 fd&cgreenno#3 fd&cgreenno.#3 fd&cgreenn3 fd&cgreenn.3 fd&cgreenn#3 fd&cgreenn°3 fd&cgreennÂ°3 fd&cgreennâ°3 fd&cgreennumber3 fd&cgreennum3 fdandcgreen3 fdandcgreen#3 fdandcgreenno3 fdandcgreenno.3 green3lake green#3lake green.3lake greenno3lake greenno.3lake greenno#3lake greenno.#3lake greenlake3 greenlake#3 greenlake.3 greenlakeno3 greenlakeno.3 greenlakeno#3 greenlakeno.#3 greens3lake greens#3lake greenslake3 greenslake#3 fd&cgreen3lake fd&cgreen#3lake fd&cgreen.3lake fd&cgreenno3lake fd&cgreenno.3lake fd&cgreenno#3lake fd&cgreenno.#3lake fd&cgreenlake3 fd&cgreenlake#3 fd&cgreenlake.3 fd&cgreenlakeno3 fd&cgreenlakeno.3 fd&cgreenlakeno#3 fd&cgreenlakeno.#3 {
    addflag green_3_flag green_3_match `term'
}

* E143 / 143
ecodeflag green_3_flag green_3_match 143

* ------------------------------------- Titanium Dioxide ----------------------------
gen titanium_dioxide_flag = 0
gen titanium_dioxide_match = ""

* nocomma separator: punctuation may sit inside the name.
addflag titanium_dioxide_flag titanium_dioxide_match titaniumdioxide nocomma ing_scan nohead

* E171 / 171
ecodeflag titanium_dioxide_flag titanium_dioxide_match 171

* accounting for spelling mistakes
foreach term in titamiumdioxide titatiumdioxide titaninumdioxide titaniumdiozide titaniumdioxid titianiumdioxide ittaniumdioxide titaniumdiocide titaniumdioxcide titaniumdioxde titaniumdioxi titaniumdioxids titaniumdioxie titaniumdioxiode titaniumdioxode titaniumdioxyde titaniumdixide titaniumdixoide titaniumdixoide titaniumdoixide titaniumoxide titaniundioxide titanlumdioxide titantiumdioxide titanuimdioxide titanumdioxide titiniumdioxide {
    addflag titanium_dioxide_flag titanium_dioxide_match `term' nocomma ing_scan nohead
}

* ------------------------------------------ Propylparaben ----------------------------------
gen propylparaben_flag = 0
gen propylparaben_match = ""

foreach term in propylparaben propylparahydroxybenzoate propyl4hydroxybenzoate propyl4-hydroxybenzoate 4-hydroxybenzoicacidn-propylester 4hydroxybenzoicacidnpropylester {
    addflag propylparaben_flag propylparaben_match `term' space ing_scan nohead
}

* E216 / 216
ecodeflag propylparaben_flag propylparaben_match 216

* accounting for spelling mistakes
foreach term in propylparabeans proplparaben propyl.hydroxybenzoate propylhydroxybenzoate propylparaban propylparaoen {
    addflag propylparaben_flag propylparaben_match `term' space ing_scan nohead
}

* ---------------------------------- Brominated Vegetable Oil ------------------------------
gen brominated_oil_flag = 0
gen brominated_oil_match = ""

foreach term in brominatedvegetableoil brominatedsoybeanoil brominatedpalmoil brominatedcottonseedoil brominatedcanolaoil brominatedoil brominatedsoy brominatedpalm brominatedcottonseed brominatedcanola brominatedcorn brominatedsunflower brominatedrapeseed {
    addflag brominated_oil_flag brominated_oil_match `term'
}

* BVO abbreviation as standalone term
replace brominated_oil_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])b[.]?[ ]*v[.]?[ ]*o[.]?([^a-z]|$)")
replace brominated_oil_match = "bvo" if ustrregexm(ing_scan, "(^|[^a-z])b[.]?[ ]*v[.]?[ ]*o[.]?([^a-z]|$)") & brominated_oil_match == ""

* accounting for spelling mistakes
foreach term in birominatedvegetableoil bromatedvegetableoil brominatedoil brominatedsoy brominatedvegetabeloil brominatedvegetableol brominatedvegetableoil brominatedvegtableoil brominatevegetableoil bromnatedvegetableoil bromonatedsoybeanoil {
    addflag brominated_oil_flag brominated_oil_match `term'
}

* ------------------------------------- Olestra -------------------------------------
gen olestra_flag = 0
gen olestra_match = ""

* Olestra itself: word boundaries
replace olestra_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])olestra([^a-z]|$)")
replace olestra_match = "olestra" if ustrregexm(ing_scan, "(^|[^a-z])olestra([^a-z]|$)") & olestra_match == ""

* Olean as a separate word only
* (avoids wholeanise, wholestrawberries, hydrolean, wholeancient)
replace olestra_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])olean([^a-z]|$)")
replace olestra_match = "olean" if ustrregexm(ing_scan, "(^|[^a-z])olean([^a-z]|$)") & olestra_match == ""

* Olestra/Olean brand collapsed form
addflag olestra_flag olestra_match olestraoleanbrand

* Contains olestra
replace olestra_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])contains[ ]+olestra([^a-z]|$)")
replace olestra_match = "contains olestra" if ustrregexm(ing_scan, "(^|[^a-z])contains[ ]+olestra([^a-z]|$)") & olestra_match == ""

foreach term in sucrosepolyester {
    addflag olestra_flag olestra_match `term'
}

* ---------------------------------------- Citrus Red 2 ----------------------------------
gen citrus_red_2_flag = 0
gen citrus_red_2_match = ""

foreach term in citrusred2 citrusred#2 citrusred.2 citrusredno2 citrusredno.2 citrusredno#2 citrusredno.#2 citrusredn2 citrusredn.2 citrusredn#2 citrusrednumber2 citrusrednum2 citrusreddye2 citrusreddye#2 citrusredcolor2 citrusredcolor#2 solventred80 solventred#80 solventred.80 solventredno80 solventrednumber80 solventrednum80 cisolventred80 {
    addflag citrus_red_2_flag citrus_red_2_match `term'
}

* E121 / 121
ecodeflag citrus_red_2_flag citrus_red_2_match 121

* ------------------------------------------ Orange B -----------------------------------------
gen orange_b_flag = 0
gen orange_b_match = ""

* Acid Orange 137 variants
foreach term in acidorange137 acidorange#137 acidorange.137 acidorangeb acidorangeb acidorangenumber137 acidorangenum137 {
    addflag orange_b_flag orange_b_match `term'
}

* Orange B as a separate term
* (avoids orange beverage, orange blossom, orange butter, etc.)
replace orange_b_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])orange[ ]+b([^a-z]|$)")
replace orange_b_match = "orange b" if ustrregexm(ing_scan, "(^|[^a-z])orange[ ]+b([^a-z]|$)") & orange_b_match == ""

* Orange-B with hyphen
replace orange_b_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])orange[ ]*-[ ]*b([^a-z]|$)")
replace orange_b_match = "orange-b" if ustrregexm(ing_scan, "(^|[^a-z])orange[ ]*-[ ]*b([^a-z]|$)") & orange_b_match == ""

* FD&C / food color style variants
foreach term in fd&corangeb fd&c-orangeb fdcorangeb foodorangeb foodorange#b colororangeb colourorangeb dyeorangeb {
    addflag orange_b_flag orange_b_match `term'
}

* ------------------------------------------- Aspartame ---------------------------------------
gen aspartame_flag = 0
gen aspartame_match = ""

foreach term in aspartame phenylalaninesource artificialsweetener\(aspartame\) containsphenylalanine {
    addflag aspartame_flag aspartame_match `term'
}

* E951 / 951
ecodeflag aspartame_flag aspartame_match 951

* accounting for spelling mistakes
foreach term in aspertame asparteme aspartame aspartaime aspartme asparthame aspartane aspertane aspartem apsartame asaprtame {
    addflag aspartame_flag aspartame_match `term'
}

* ------------------------------------------ Saccharin ------------------------------------------
gen saccharin_flag = 0
gen saccharin_match = ""

* Known false-positive Saccharina seaweed names
gen byte saccharin_fp_species = ustrregexm(ing_scan, "saccharina[ ,._-]*(latissima|longissima)")

* Main saccharin terms with word boundaries
* (avoids Saccharina latissima / Saccharina longissima)
replace saccharin_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])saccharin([^a-z]|$)")
replace saccharin_match = "saccharin" if ustrregexm(ing_scan, "(^|[^a-z])saccharin([^a-z]|$)") & saccharin_match == ""

replace saccharin_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])sodium[ -]*saccharin([^a-z]|$)")
replace saccharin_match = "sodium saccharin" if ustrregexm(ing_scan, "(^|[^a-z])sodium[ -]*saccharin([^a-z]|$)") & saccharin_match == ""

replace saccharin_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])calcium[ -]*saccharin([^a-z]|$)")
replace saccharin_match = "calcium saccharin" if ustrregexm(ing_scan, "(^|[^a-z])calcium[ -]*saccharin([^a-z]|$)") & saccharin_match == ""

replace saccharin_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])saccharin[ -]*sodium([^a-z]|$)")
replace saccharin_match = "saccharin sodium" if ustrregexm(ing_scan, "(^|[^a-z])saccharin[ -]*sodium([^a-z]|$)") & saccharin_match == ""

* Collapsed / messy forms
foreach term in sodiumsaccharin calciumsaccharin saccharinsodium sweetenersaccharin sweetenersodiumsaccharin sweetenercalciumsaccharin saccharinassweetener sodiumsaccharine {
    addflag saccharin_flag saccharin_match `term'
}

* Remove Saccharina false positives only if no true saccharin form is present
gen byte sacch_true = ustrregexm(ing_scan, "(^|[^a-z])saccharin([^a-z]|$)") ///
    | ustrregexm(ing_scan, "(^|[^a-z])(sodium|calcium)[ -]*saccharine?([^a-z]|$)") ///
    | ustrregexm(ing_scan, "(^|[^a-z])saccharine?[ -]*(sodium|calcium)([^a-z]|$)") ///
    | ustrregexm(ing_scan, "(^|[^a-z])sweetener[ :\(-]*((sodium|calcium)[ ]*)?saccharine?([^a-z]|$)")

replace saccharin_flag = 0 if saccharin_fp_species == 1 & sacch_true == 0
replace saccharin_match = "" if saccharin_fp_species == 1 & sacch_true == 0
drop sacch_true

* E954 / 954
ecodeflag saccharin_flag saccharin_match 954

* ---------------------------------------------- Sucralose ------------------------------------
gen sucralose_flag = 0
gen sucralose_match = ""

addflag sucralose_flag sucralose_match sucralose

* Tolerant spelling pattern (e.g., SUCROLOSE): allows up to two variable
* letters between "sucr" and the final "-lose". The "l" before "-ose" is
* required, so the pattern cannot match SUCROSE, GLUCOSE, LACTOSE,
* FRUCTOSE or CELLULOSE.
replace sucralose_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])su[ck]r[a-z]{0,2}l[ao]se([^a-z]|$)")
replace sucralose_match = "sucralose (tolerant)" if ustrregexm(ing_scan, "(^|[^a-z])su[ck]r[a-z]{0,2}l[ao]se([^a-z]|$)") & sucralose_match == ""

* accounting for spelling mistakes
foreach term in sucrolose sukralose sucrallose succralose sucralos sucralouse sucraloce sucralese sucrulose sucralosa surcalose scuralose sucalose {
    addflag sucralose_flag sucralose_match `term'
}

* E955 / 955
ecodeflag sucralose_flag sucralose_match 955

* ---------------------------------------------- Acesulfame Potassium ---------------------------
gen acesulfame_k_flag = 0
gen acesulfame_k_match = ""

foreach term in acesulfamepotassium acesulfamek ace-k acesulfame-k acek {
    addflag acesulfame_k_flag acesulfame_k_match `term'
}

* E950 / 950
ecodeflag acesulfame_k_flag acesulfame_k_match 950

* accounting for spelling mistakes
foreach term in ace-k acek acesfulamepotassium acesulfame acessulfamepotassium acesuflamepotassium acesulamepotassium. acesulfame-k acesulfamek acesulfamepostassium acesulfamepotasium acesulfamepotassilim acesulfamepotassium acesulfamepotassum acesulfamepotrassium acesulfamesalt acesulfametopotassium acesulfamk acesulfampotassium acesulfanepotassium acesultamepotassium aceulfamepotassium acsulfamepotassium aesulfamepotassium agesulfamepotassium agesulfamepotassium ascesulfamek ascesulfamepotassium asesulfame ascesulfamepotassium aspartameacesulfame aceslfamepotassium potassiumacesulfame acesfulamek acesfulame-k acesuflamek acesuflame-k acesulamek acesulame-k aceslfamek aceslfame-k acessulfamek acessulfame-k acesulfamak acesulfanek acesultamek aceulfamek acsulfamek {
    addflag acesulfame_k_flag acesulfame_k_match `term'
}

* -------------------------------------------- Carrageenan ----------------------------------------
gen carrageenan_flag = 0
gen carrageenan_match = ""

foreach term in carrageenan carrageenin chondrusextract irishmossextract carragheengum irishmossgelose {
    addflag carrageenan_flag carrageenan_match `term'
}

* E407 / 407 and E407a / 407a
ecodeflag carrageenan_flag carrageenan_match 407a
ecodeflag carrageenan_flag carrageenan_match 407

* accounting for spelling mistakes
foreach term in caarageenan corrageenan carageenan cararageenan carargeenan carnageenan carraageenan carrabeenan carrageean carrageeenan carrageeian carrageeman carrageen carrageena carrageenaaan carrageenaan carrageenam carrageenan carrageenar carrageenen carrageenon carrageeran carragenaan carragenan carragenina carragenine carragennan carragfenan carraggenan carragheenan carragneenan carragreenan carrangeenan carregeenan carrgeenan carrrageenan crrageenan darrageenan garrageenan carragenin arrageenan carrageine {
    addflag carrageenan_flag carrageenan_match `term'
}

* ---------------------------------------- Red 40 ----------------------------------------
gen red_40_flag = 0
gen red_40_match = ""

foreach term in red40 red#40 red.#40 redno.40 redno40 redno#40 redno.#40 redn40 redn.40 redn#40 rednâ°40 rednÂ°40 redn°40 rednumber40 rednum40 red40lake red#40lake red.#40lake redno40lake redno.40lake redno#40lake redno.#40lake redn40lake redn.40lake redn#40lake rednâ°40lake rednÂ°40lake redn°40lake redlake40 redlake#40 redlake.40 redlakeno40 redlakeno.40 redlakeno#40 redlakeno.#40 redlaken40 redlaken.40 redlaken#40 reds40 reds#40 reds.40 redsno40 redsno.40 redsno#40 redsno.#40 redsn40 redsn.40 redsn#40 reds40lake reds#40lake reds.40lake redsno40lake redsno.40lake redsno#40lake redsno.#40lake redslake40 redslake#40 redslake.40 fd&cred40 fd&cred#40 fd&cred.#40 fd&credno40 fd&credno.40 fd&credno#40 fd&credno.#40 fd&credn40 fd&credn.40 fd&credn#40 fd&crednâ°40 fd&crednÂ°40 fd&credn°40 fd&cred40lake fd&cred#40lake fd&cred.#40lake fd&credno40lake fd&credno.40lake fd&credno#40lake fd&credno.#40lake fd&credn40lake fd&credn.40lake fd&credn#40lake fd&crednâ°40lake fd&crednÂ°40lake fd&credn°40lake fd&credlake40 fd&credlake#40 fd&credlake.40 fd&credlakeno40 fd&credlakeno.40 fd&credlakeno#40 fd&credlakeno.#40 fd&cre#40 fd&cre.40 fd&cred#4o fd&cred4o fd&c-red#40 fd&c-red40 alluraredac allurared alluraredlake alluraredaclake alluraredac40 alluraredac#40 fd&credno40&3 fd&credno.40&3 fd&credno40and3 fd&credno.40and3 fd&cred40&3 fd&cred40and3 fd&cred#40&3 fd&cred#40and3 fd&creds40&3 fd&creds40and3 fd&creds#40&3 fd&creds#40and3 red3&40 red3and40 red#3&40 red#3and40 red#3&#40 red#40&3 red#40and3 red#40&#3 red40&3 red40and3 redno3&40 redno3and40 redno.3&40 redno.3and40 redno40&3 redno40and3 redno.40&3 redno.40and3 reds40&3 reds40and3 reds#40&3 reds#40and3 redsno40&3 redsno40and3 redsno.40&3 redsno.40and3 red40lake&3 red40lakeand3 red#40lake&3 red#40lakeand3 redno40lake&3 redno40lakeand3 redno.40lake&3 redno.40lakeand3 reds40lake&3 reds40lakeand3 redslake40&3 redslake40and3 fd&cred40lake&3 fd&cred40lakeand3 fd&cred#40lake&3 fd&cred#40lakeand3 fd&credno40lake&3 fd&credno40lakeand3 fd&credno.40lake&3 fd&credno.40lakeand3 {
    addflag red_40_flag red_40_match `term'
}

* E129 / 129 (SALT (129) excluded via extra rule)
ecodeflag red_40_flag red_40_match 129 "salt\s*\(\s*129\s*\)"

* accounting for spelling mistakes
foreach term in allauraredac allurared redn.40 bedno.40 red.no.40 fd&credn40 redn40 redno.#40 rednos.40 reno.40 fd&cre#40 red#3&#40 red#3&40 red#40 red3&40 red40 redno.40 redno3&40 monored40 redcolor#40 redcolors#40 redcolor40 redcolorno.40 redcolorno40 redcolorsno.40 redcolour#40 redcolours#40 colorred#40 colorsred#40 colorredno.40 colourred#40 red#40(color) red#40(colors) redno.40(color) fd&credcolor#40 fd&credcolors#40 fd&credcolorno.40 f.d.&c.redcolor#40 redlakecolor#40 redlakecolors#40 redfd&c#40 redfd&c40 redfd&cno.40 {
    addflag red_40_flag red_40_match `term'
}

* ---------------------------------------- Yellow 5 ----------------------------------------
gen yellow_5_flag = 0
gen yellow_5_match = ""

foreach term in yellow5 yellow#5 yellow.#5 yellowno.5 yellowno5 yellowno#5 yellowno.#5 yellown5 yellown.5 yellown#5 yellownâ°5 yellownÂ°5 yellown°5 yellownumber5 yellownum5 fd&cyellow5 fd&cyellow#5 fd&cyellow.#5 fd&cyellowno.5 fd&cyellowno5 fd&cyellowno#5 fd&cyellowno.#5 fd&cyellown5 fd&cyellown.5 fd&cyellown#5 fd&cyellownâ°5 fd&cyellownÂ°5 fd&cyellown°5 yellows5 yellows#5 yellows.5 yellowsno5 yellowsno.5 yellowsno#5 yellowsno.#5 tartrazine tartazine tartarzine tatrazine yellow5&6 yellow6&5 yellow5and6 yellow6and5 yellow#5&6 yellow#6&5 yellow#5&#6 yellow#6&#5 yellow#5and6 yellow#6and5 yellow#5and#6 yellow#6and#5 yellowcolors#5and#6 yellowcolor#5and#6 yellow#5#6 yellow#6#5 yellowno5&6 yellowno6&5 yellowno5and6 yellowno6and5 yellowno.5&6 yellowno.6&5 yellowno.5and6 yellowno.6and5 yellowno.5andno.6 yellowno.6andno.5 yellows5&6 yellows6&5 yellows5and6 yellows6and5 yellows#5&#6 yellows#6&#5 yellows#5and#6 yellows#6and#5 fd&cyellow5&6 fd&cyellow6&5 fd&cyellow5and6 fd&cyellow6and5 fd&cyellow#5&#6 fd&cyellow#6&#5 fd&cyellow#5and#6 fd&cyellow#6and#5 yellow5lake yellow#5lake yellow.#5lake yellowno5lake yellowno.5lake yellowno#5lake yellowno.#5lake yellown5lake yellown.5lake yellown#5lake yellownâ°5lake yellownÂ°5lake yellown°5lake yellowlake5 yellowlake#5 yellowlake.5 yellowlakeno5 yellowlakeno.5 yellowlakeno#5 yellowlakeno.#5 yellowlaken5 yellowlaken.5 yellowlaken#5 yellowlakenâ°5 yellowlakenÂ°5 yellowlaken°5 yellowslake5 yellowslake#5 yellowslake.5 yellowslakeno5 yellowslakeno.5 yellowslakeno#5 yellowslakeno.#5 fd&cyellow5lake fd&cyellow#5lake fd&cyellow.#5lake fd&cyellowno5lake fd&cyellowno.5lake fd&cyellowno#5lake fd&cyellowno.#5lake fd&cyellowlake5 fd&cyellowlake#5 fd&cyellowlake.5 fd&cyellowlakeno5 fd&cyellowlakeno.5 fd&cyellowlakeno#5 fd&cyellowlakeno.#5 yellowlake5and6 yellowlake6and5 yellowlake5&6 yellowlake6&5 yellowlake#5and#6 yellowlake#6and#5 yellowlake#5&#6 yellowlake#6&#5 yellowlakes5and6 yellowlakes6and5 yellowlakes5&6 yellowlakes6&5 yellowslake5and6 yellowslake6and5 yellowslake5&6 yellowslake6&5 yellow5lakeand6 yellow6lakeand5 yellow5lake&6 yellow6lake&5 yellow#5lakeand#6 yellow#6lakeand#5 yellow#5lake&#6 yellow#6lake&#5 fd&cyellowlake5and6 fd&cyellowlake6and5 fd&cyellowlake5&6 fd&cyellowlake6&5 fd&cyellowlake#5and#6 fd&cyellowlake#6and#5 fd&cyellowlake#5&#6 fd&cyellowlake#6&#5 yellowcolor#5 yellowcolors#5 yellowcolor#5lake yellowcolors#5lake yellowcolorno.5 yellowcolorsno.5 yellowcolour#5 yellowcolours#5 coloryellow#5 colorsyellow#5 coloryellowno.5 colouryellow#5 coloursyellow#5 yellow#5(color) yellow#5(colors) yellowno.5(color) fd&cyellowcolor#5 fd&cyellowcolors#5 fd&cyellowcolorno.5 f.d.&c.yellowcolor#5 yellowlakecolor#5 yellowlakecolors#5 yellow#5lake yellowcolor#5and6 yellowcolors#5and6 yellowcolor#5&6 yellowcolors#5&6 yellowcolor#5&#6 yellowcolors#5&#6 yellowcolor#5and#6lake yellowcolors#5and#6lake yellowcolor#5lakeand#6lake yellowcolors#5lakeand#6lake yellowcolorno.5and6 yellowcolorsno.5and6 yellowcolorno.5andno.6 yellowcolorsno.5andno.6 yellowcolornos.5and6 yellowcolorsnos.5and6 yellowcolorno.5&6 yellowcolorsno.5&6 yellowcolour#5and#6 yellowcolours#5and#6 yellowcolour#5and6 yellowcolours#5and6 yellowcolour#5&6 yellowcolours#5&6 coloryellow#5and#6 colorsyellow#5and#6 yellow#5and#6(color) yellow#5and#6(colors) yellowno.5andno.6(color) yellownos.5&6 fd&cyellowcolor#5and#6 fd&cyellowcolors#5and#6 fd&cyellowcolorno.5andno.6 fd&cyellowcolorsno.5andno.6 fd&cyellowcolors#5&#6 fd&cyellow#5and#6color fd&cyellow#5and#6colors f.d.&c.yellowcolor#5and#6 f.d.&c.yellowcolors#5and#6 yellowcolors#5&#6lake yellowlakecolor#5and#6 yellowlakecolors#5and#6 yellow#5lakeandyellow#6lake {
    addflag yellow_5_flag yellow_5_match `term' space ing_scan nohead
}

* E102 / 102
ecodeflag yellow_5_flag yellow_5_match 102

* accounting for spelling mistakes
foreach term in yellow#6&#5 yellows5&6 tartazine yellosno.5&6 cyellown5 yelow#5 tartarzine yellown5 fd&ctellow#5 fd&cyellow#.5 fd&cyellow#6&#5 fd&cyellow#6&5 fd&cyellow.no.5 fd&cyellowcolor#5&#6 fd&cyellown5 fd&cyellowndegree5 fd&cyellows5 fd&cyelow#5 fd&cyelown5 tatrazine tartrazine yellowsno.5 yellown.5 yellowno.6&5 yellownos5and6 yellownos6and5 yellowlakes5 yellowlakes5&6 yellowlakes6&5 includingyellow5 andyellow5 lyellow5 oryellow5 oryellow#5 yellowv5 yellowv#5 yellow#05 yellow05 fd&cyellow#05 yellowfd&c#5 yellowfd&c5 yellowfd&cno.5 {
    addflag yellow_5_flag yellow_5_match `term' space ing_scan nohead
}

* -------------------------------------- Sodium Nitrite --------------------------------------
gen sodium_nitrite_flag = 0
gen sodium_nitrite_match = ""

addflag sodium_nitrite_flag sodium_nitrite_match sodiumnitrite

* accounting for other names
foreach term in nitrousacidsodiumsalt {
    addflag sodium_nitrite_flag sodium_nitrite_match `term'
}

* E250 / 250 (corn meal #250, 250 CFU, TDS:250, SALADIZER 250, BLOOM 250
* all excluded generically by ecodeflag)
ecodeflag sodium_nitrite_flag sodium_nitrite_match 250 "bloom\s+25[o0]"

* accounting for spelling mistakes
foreach term in dodiaumnitrite sodiummnitrite sodiumhitrite sodiuminitrte sodiumntirite sodlumnitrite sodiumnirtite sodiumnitirite sodiumnitirte sodiumnitite sodiumnitrit sodiumnitritie sodiumnitritre sodiumnitrte sodiumnitrtite sodiumnotrite sodiumnitrine sodiumnitrice {
    addflag sodium_nitrite_flag sodium_nitrite_match `term'
}

* accounting for spacing / punctuation 
replace sodium_nitrite_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])sodium[ ,;:/._-]*nitrite([^a-z]|$)")
replace sodium_nitrite_match = "sodium[ ,;:/._-]*nitrite" if ustrregexm(ing_scan, "(^|[^a-z])sodium[ ,;:/._-]*nitrite([^a-z]|$)") & sodium_nitrite_match == ""

* -------------------------------------- Sodium Nitrate ------------------------------------------
gen sodium_nitrate_flag = 0
gen sodium_nitrate_match = ""

addflag sodium_nitrate_flag sodium_nitrate_match sodiumnitrate

* accounting for other names
foreach term in nitricacidsodiumsalt {
    addflag sodium_nitrate_flag sodium_nitrate_match `term'
}

* E251 / 251
ecodeflag sodium_nitrate_flag sodium_nitrate_match 251

* accounting for spelling mistakes
foreach term in bodiumnitrate sodiumnitaite sodiumnitraite {
    addflag sodium_nitrate_flag sodium_nitrate_match `term'
}

* accounting for spacing / punctuation
replace sodium_nitrate_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])sodium[ ,;:/._-]*nitrate([^a-z]|$)")
replace sodium_nitrate_match = "sodium[ ,;:/._-]*nitrate" if ustrregexm(ing_scan, "(^|[^a-z])sodium[ ,;:/._-]*nitrate([^a-z]|$)") & sodium_nitrate_match == ""

* ---------------------------------------- Potassium Nitrite ----------------------------
gen potassium_nitrite_flag = 0
gen potassium_nitrite_match = ""

addflag potassium_nitrite_flag potassium_nitrite_match potassiumnitrite

* accounting for other names
foreach term in nitrousacidpotassiumsalt {
    addflag potassium_nitrite_flag potassium_nitrite_match `term'
}

* E249 / 249
ecodeflag potassium_nitrite_flag potassium_nitrite_match 249

* accounting for spacing / punctuation
replace potassium_nitrite_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])potassium[ ,;:/._-]*nitrite([^a-z]|$)")
replace potassium_nitrite_match = "potassium[ ,;:/._-]*nitrite" if ustrregexm(ing_scan, "(^|[^a-z])potassium[ ,;:/._-]*nitrite([^a-z]|$)") & potassium_nitrite_match == ""

* ---------------------------------- Potassium Nitrate ------------------------------------------
gen potassium_nitrate_flag = 0
gen potassium_nitrate_match = ""

addflag potassium_nitrate_flag potassium_nitrate_match potassiumnitrate

* accounting for other names
foreach term in niter nitre saltpeter saltpetre nitricacidpotassiumsalt {
    addflag potassium_nitrate_flag potassium_nitrate_match `term'
}

* E252 / 252
ecodeflag potassium_nitrate_flag potassium_nitrate_match 252

* accounting for spacing / punctuation 
replace potassium_nitrate_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])potassium[ ,;:/._-]*nitrate([^a-z]|$)")
replace potassium_nitrate_match = "potassium[ ,;:/._-]*nitrate" if ustrregexm(ing_scan, "(^|[^a-z])potassium[ ,;:/._-]*nitrate([^a-z]|$)") & potassium_nitrate_match == ""

* ------------------------------ Combined Nitrates/Nitrites --------------------------
gen nitrite_nitrate_flag = 0
gen nitrite_nitrate_match = ""

foreach term in sodiumnitrite sodiumnitrate potassiumnitrite potassiumnitrate {
    addflag nitrite_nitrate_flag nitrite_nitrate_match `term'
}

* accounting for other names
foreach term in nitrousacidpotassiumsalt nitrousacidsodiumsalt niter nitre saltpeter saltpetre nitricacidpotassiumsalt nitricacidsodiumsalt {
    addflag nitrite_nitrate_flag nitrite_nitrate_match `term'
}

* E249 potassium nitrite, E250 sodium nitrite, E251 sodium nitrate, E252 potassium nitrate
foreach num in 249 250 251 252 {
    ecodeflag nitrite_nitrate_flag nitrite_nitrate_match `num'
}

* accounting for spelling mistakes
foreach term in bodiumnitrate dodiaumnitrite potassiumnitrate potassiumnitrite sodiumnitirte sodiumnitrtite sodiumhitrite sodiuminitrte sodiummnitrite sodiumnirtite sodiumnitaite sodiumnitirite sodiumnitirte sodiumnitite sodiumnitraite sodiumnitrate sodiumnitrice sodiumnitrine sodiumnitrit sodiumnitrite sodiumnitritie sodiumnitritre sodiumnitrte sodiumnotrite sodiumntirite sodlumnitrite {
    addflag nitrite_nitrate_flag nitrite_nitrate_match `term'
}

* accounting for punctuation / spacing between salt name and nitrite/nitrate
foreach pattern in "sodium[ ,;:/._-]*nitrite" "sodium[ ,;:/._-]*nitrate" "potassium[ ,;:/._-]*nitrite" "potassium[ ,;:/._-]*nitrate" {
    replace nitrite_nitrate_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])`pattern'([^a-z]|$)")
    replace nitrite_nitrate_match = "`pattern'" if ustrregexm(ing_scan, "(^|[^a-z])`pattern'([^a-z]|$)") & nitrite_nitrate_match == ""
}

* --------------------------------------- Sodium Sulfites ----------------------------
gen sodium_sulfites_flag = 0
gen sodium_sulfites_match = ""

foreach term in sodiumsulfite sodiumsulphite sodiumbisulfite sodiumbisulphite sodiummetabisulfite sodiummetabisulphite sodiumhydrogensulfite sodiumhydrogensulphite sodiumacidsulfite sodiumacidsulphite monosodiumsulfite monosodiumsulphite disodiumsulfite disodiumsulphite sulfitesodium sulphitesodium sulfurousacidmonosodiumsalt sulphurousacidmonosodiumsalt sulfurousaciddisodiumsalt sulphurousaciddisodiumsalt disodiumpyrosulfite disodiumpyrosulphite disodiumdisulfite disodiumdisulphite sodiumpyrosulfite sodiumpyrosulphite sodiumdisulfite sodiumdisulphite pyrosulfurousaciddisodiumsalt pyrosulphurousaciddisodiumsalt disulfurousaciddisodiumsalt disulphurousaciddisodiumsalt {
    addflag sodium_sulfites_flag sodium_sulfites_match `term'
}

* E221 sodium sulfite, E222 sodium bisulfite, E223 sodium metabisulfite
foreach num in 221 222 223 {
    ecodeflag sodium_sulfites_flag sodium_sulfites_match `num'
}

* ---------------------------------------- Potassium Sulfites ------------------------------
gen potassium_sulfites_flag = 0
gen potassium_sulfites_match = ""

foreach term in potassiumsulfite potassiumsulphite dipotassiumsulfite dipotassiumsulphite potassiumbisulfite potassiumbisulphite potassiummetabisulfite potassiummetabisulphite potassiumhydrogensulfite potassiumhydrogensulphite potassiumacidsulfite potassiumacidsulphite monopotassiumsulfite monopotassiumsulphite sulfurousacidmonopotassiumsalt sulfurousaciddipotassiumsalt dipotassiumdisulfite dipotassiumdisulphite dipotassiumpyrosulfite dipotassiumpyrosulphite disulfurousaciddipotassiumsalt disulphurousaciddipotassiumsalt potassiumpyrosulfite potassiumpyrosulphite pyrosulfurousaciddipotassiumsalt pyrosulphurousaciddipotassiumsalt potassiumdisulfite potassiumdisulphite {
    addflag potassium_sulfites_flag potassium_sulfites_match `term'
}

* E224 potassium metabisulfite, E225 potassium sulfite, E228 potassium bisulfite
foreach num in 224 225 228 {
    ecodeflag potassium_sulfites_flag potassium_sulfites_match `num'
}

* -------------------- General Sulfites (Excludes sodium & potassium) -------------------------
gen sulfites_flag = 0
gen sulfites_match = ""

foreach term in sulfite sulfites sulphite sulphites calciumsulfite calciumsulphite calciumbisulfite calciumbisulphite calciummetabisulfite calciummetabisulphite calciumhydrogensulfite calciumhydrogensulphite ammoniumsulfite ammoniumbisulfite magnesiumsulfite sulfurdioxide sulphurdioxide sulferdioxide sulpherdioxide sulfrdioxide sulfurousacid sulphurousacid sulfurousoxide sulphurousoxide sulfursuperoxide sulphursuperoxide sulfurousanhydride sulphurousanhydride {
    addflag sulfites_flag sulfites_match `term'
}

* Catch-all SUBSTRING for sulfite/sulphite (no left word boundary):
* META-BISULFITE, BISULFITES, and typos like METABBISULFITE,
* MATABISULFITE, METABILSULPHITE, plus collapsed text like
* CONTAINSSULFITES, all contain "sulfite" inside a longer word.
replace sulfites_flag = 1 if ustrregexm(ing_scan, "sul(f|ph)it(e|i)|sul(f|ph)ating[ ]+agents?")
replace sulfites_match = "sulfite (substring)" if ustrregexm(ing_scan, "sul(f|ph)it(e|i)|sul(f|ph)ating[ ]+agents?") & sulfites_match == ""

* (E226/E227 are included so that the general and all-sulfite flags
* capture calcium sulfites; the sodium and potassium sections use only
* their own codes.)
foreach num in 220 226 227 {
    ecodeflag sulfites_flag sulfites_match `num'
}

* Exclude cases already covered by the sodium/potassium sections
replace sulfites_flag = 0 if sodium_sulfites_flag == 1 | potassium_sulfites_flag == 1
replace sulfites_match = "" if sodium_sulfites_flag == 1 | potassium_sulfites_flag == 1

* ------------------------------------- All Sulfites ----------------------------------------------
gen allsulfites_flag = 0
gen allsulfites_match = ""

* Punctuation-flexible matching 
foreach term in sodiumsulfite sodiumsulphite sodiumbisulfite sodiumbisulphite sodiummetabisulfite sodiummetabisulphite sodiumhydrogensulfite sodiumhydrogensulphite sodiumacidsulfite sodiumacidsulphite monosodiumsulfite monosodiumsulphite disodiumsulfite disodiumsulphite sulfitesodium sulphitesodium sulfurousacidmonosodiumsalt sulphurousacidmonosodiumsalt sulfurousaciddisodiumsalt sulphurousaciddisodiumsalt disodiumpyrosulfite disodiumpyrosulphite disodiumdisulfite disodiumdisulphite sodiumpyrosulfite sodiumpyrosulphite sodiumdisulfite sodiumdisulphite pyrosulfurousaciddisodiumsalt pyrosulphurousaciddisodiumsalt disulfurousaciddisodiumsalt disulphurousaciddisodiumsalt potassiumsulfite potassiumsulphite dipotassiumsulfite dipotassiumsulphite potassiumbisulfite potassiumbisulphite potassiummetabisulfite potassiummetabisulphite potassiumhydrogensulfite potassiumhydrogensulphite potassiumacidsulfite potassiumacidsulphite monopotassiumsulfite monopotassiumsulphite sulfurousacidmonopotassiumsalt sulfurousaciddipotassiumsalt dipotassiumdisulfite dipotassiumdisulphite dipotassiumpyrosulfite dipotassiumpyrosulphite disulfurousaciddipotassiumsalt disulphurousaciddipotassiumsalt potassiumpyrosulfite potassiumpyrosulphite pyrosulfurousaciddipotassiumsalt pyrosulphurousaciddipotassiumsalt potassiumdisulfite potassiumdisulphite calciumsulfite calciumsulphite calciumbisulfite calciumbisulphite calciummetabisulfite calciummetabisulphite calciumhydrogensulfite calciumhydrogensulphite ammoniumsulfite ammoniumbisulfite magnesiumsulfite sulfite sulfites sulphite sulphites sulfurdioxide sulphurdioxide sulferdioxide sulpherdioxide sulfrdioxide sulfurousacid sulphurousacid sulfurousanhydride sulphurousanhydride sulfurousoxide sulphurousoxide sulfursuperoxide sulphursuperoxide {
    addflag allsulfites_flag allsulfites_match `term' any
}

* Catch-all SUBSTRING for sulfite/sulphite (see note in the General
* Sulfites section): restores matches inside longer words such as
* META-BISULFITE, BISULFITES, METABBISULFITE, CONTAINSSULFITES.
replace allsulfites_flag = 1 if ustrregexm(ing_scan, "sul(f|ph)it(e|i)|sul(f|ph)ating[ ]+agents?")
replace allsulfites_match = "sulfite (substring)" if ustrregexm(ing_scan, "sul(f|ph)it(e|i)|sul(f|ph)ating[ ]+agents?") & allsulfites_match == ""

* E220-E228 sulfite codes (incl. E226 calcium sulfite, E227 calcium bisulfite)
foreach num in 220 221 222 223 224 225 226 227 228 {
    ecodeflag allsulfites_flag allsulfites_match `num'
}

* ------------------------------ Partially Hydrogenated Vegetable Oils ----------------------
gen partially_oil_flag = 0
gen partially_oil_match = ""

foreach term in partiallyhydrogenatedoil partiallyhydrogenatedvegetableoil partiallyhydrogenatedsoybeanoil partiallyhydrogenatedpalmoil partiallyhydrogenatedcottonseedoil partiallyhydrogenatedcornoil partiallyhydrogenatedcanolaoil partiallyhydrogenatedvegetable partiallyhydrogenatedsoybean partiallyhydrogenatedpalm partiallyhydrogenatedcottonseed partiallyhydrogenatedcorn partiallyhydrogenatedcanola partiallyhydrogenatedcoconutoil partiallyhydrogenatedrapeseedoil partiallyhydrogenatedsunfloweroil partiallyhydrogenatedlard partiallyhydrogenatedtallow partiallyhydrogenatedflaxseedoil {
    addflag partially_oil_flag partially_oil_match `term'
}

* accounting for spelling mistakes
* stray punctuation between the two words: "PARTIALLY, HYDROGENATED
* SOYBEAN OIL" (PARTIALLY alone is not an ingredient).
replace partially_oil_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])part(ially|ly|ial)[ ,._-]{1,3}hydrogenated")
replace partially_oil_match = "partially, hydrogenated" if ustrregexm(ing_scan, "(^|[^a-z])part(ially|ly|ial)[ ,._-]{1,3}hydrogenated") & partially_oil_match == ""

foreach term in partiallyhydrogenatedsoy pratiallyhydrogenatedvegetable vegetableoilpartiallyhydrogenatedsoy partiallyhidrogenatedsoybean partiallyhydrogenatedblendof partiallyhydrogenatedsoybeal partiallyhydrogenatedsoyoil partiallyhydrogenatesoybean partiallyhydronatedsoybean partialyhydrogenatedvegetable partiallyhydrogenatedcoconutorpalmkernel paritallyhydrogenatedpalmoil partallyhydrogenatedpalmkerneloil partialhydrogenatedsoybeanoil partialhydrogenatedvegetableoilpalm partialllyhydrogenatedcoconutoil partiallydehydrogenatedsoybeanoil partiallyhdyrogenatedsoybeansoil partiallyhidrogenatedsoybeanoil partiallyhidrogenatedvegetableoil partiallyhydorgenatedsoybean partiallyhydorogenatedsoybeanoil partiallyhydrcgenatedpalmkerneloil partiallyhydrgenatedvegetableoil partiallyhydrgogenatedpalmoil partiallyhydrogeatedsoybean partiallyhydrogenatdpalmkerneloil partiallyhydrogenatedcoconutorcottons partiallyhydrogenatedcoconutorpalm partiallyhydrogenatedcottenseed partiallyhydrogenatedkerneloil partiallyhydrogenatedpal partiallyhydrogenatedpalkerneloil partiallyhydrogenatedplamkerneloil partiallyhydrogenatedprotein partiallyhydrogenatedshorteningpalmoil partiallyhydrogenatedshorteningsoybean partiallyhydrogenatedsoyabeanoil partiallyhydrogenatedsoyoilcheeseched partiallyhydrogenatedsoyorcottonseedoil partiallyhydrogenatedsunflower partiallyhydrogenatedvegatablefat partiallyhydrogenatedvegtablesortenin partiallyhydrogenatepalmkerneloil partiallyhydrogenatesoybeanoil partiallyhydrogenatessoybeanoil partiallyhydrogentaedcottonseed partiallyhydrogentatedsoybeanoil partiallyhydrogentedsoybeanoil partiallyhydrogrnatedpalmoil partiallyhyrdrogenatedsoy partiallyhyrdrogenatedsoybean partialyhydrogenatedsoybeanoil partialyhydrogenatedvegetableoil particallyhydrogenatedsoybean particallyhydrogenatedvegetableoilsoy particiallyhydrogenatedpalmoils partillyhydrogenatedpalmkerneloil partlyhydrogenatedsoybeanoil partlyhydrogenatedvegetablefat partlyhydrogenatedvegetablefatpalm partlyhydrogenatedvegetablefatspalm partlyhydrogenatedvegetablepalmfat patriallyhydrogenatedpalmkerneloil rapeseedoilpartiallyhydrogenated partiallyhydrogenatecpalmkerneloil partlyhydrogenatedsoybean partiallyhidrogenatedvegetableoilsoybean {
    addflag partially_oil_flag partially_oil_match `term'
}

* Negations (NO PARTIALLY HYDROGENATED OILS, CONTAINS NO PARTIALLY
* HYDROGENATED OIL - extremely common post-2018 claims) are removed from
* ing_scan before matching.

* ---------------------------------- Potassium Iodate ------------------------------------------
gen potassium_iodate_flag = 0
gen potassium_iodate_match = ""

foreach term in potassiumiodate kio3 doughconditioner\(potassiumiodate\) {
    addflag potassium_iodate_flag potassium_iodate_match `term'
}

* E917 / 917
ecodeflag potassium_iodate_flag potassium_iodate_match 917

* accounting for spelling mistakes
foreach term in pctassiumiodate potasiumiodate potassiumiodite potassiumlodate potassiumtodate pottasiumiodate {
    addflag potassium_iodate_flag potassium_iodate_match `term'
}

* ---------------------------------------- Caramel Color ----------------------------------------
gen caramel_color_flag = 0
gen caramel_color_match = ""

****************************************************
* CARAMEL SETUP

* COLORANT = a named colorant appearing near the caramel
* CARFOOD  = food word AFTER caramel (CARAMEL DIP / SWIRLS / COATING / CUPS / WAFER ...)
* CARPRE   = food adjective BEFORE caramel (SEA SALTED CARAMEL, CHOCOLATE CARAMEL ...)
* CARSUB   = caramel with its OWN sub-ingredient list, e.g.
*            CARAMEL (SUGAR, PALM KERNEL OIL, MILK SOLIDS ...) - a compound
*            food component, never a colorant
****************************************************
local COLORANT "(titanium[ ]*dioxide|annatto|turmeric|beta[ ]*-?[ ]*carotene|carotene|spirulina|lycopene|carmine|cochineal|paprika[ ]+(extract|oleoresin)|vegetable[ ]+juice|fruit[ ]+juice|artificial[ ]+colou?r|colou?red[ ]+with|(fd&c[ ]*)?(red|yellow|blue|green)[ ]*(no[.]?|n[.]?|#|number)?[ ]*[0-9])"
local CARFOOD "(?![ ]*(dip|swirls?|sauce|syrup|bits?|pieces?|chips?|chunks?|balls?|bites?|candy|candies|flavou?r(ed|ing)?s?|popcorn|apples?|topping|base|filling|coating|cream|creme|nuts?|corn|:|brown|cups?|spread|drizzle|truffles?|ribbons?|filled|wafers?|variegate|nougat|fudge|chocolate|sugar|bars?|clusters?|chews?|centers?|center|crunch|cookies?|custard|pudding|mousse|sundae|caramels|milk|lava|ripple|core|drumstick))"
local CARSUB "(?![ ]*[\(\[][ ]*(sugar|corn[ ]+syrup|syrup|palm|milk|cream|butter|water|sweetened|glucose|molasses|brown))"
local CARPRE "(?<!salted )(?<!salt )(?<!chocolate )(?<!butter )(?<!toffee )(?<!creamy )(?<!chewy )(?<!soft )(?<!mini )(?<!vanilla )(?<!dulce )(?<!milk )"

* Working copy: caramel inside a FLAVOR declaration is a flavor, not a
* colorant ("ARTIFICIAL FLAVORS (VANILLIN, CARAMEL, CHOCOLATE)"). The span
* is blanked so that a second caramel elsewhere on the label (e.g.
* "ARTIFICIAL COLORS (TITANIUM DIOXIDE, CARAMEL)") is still detected.
capture drop car_scan
gen strL car_scan = ing_scan
* Only blank the flavor parenthetical when it contains NO color
* word. "VANILLA FLAVOR (PROPYLENE GLYCOL, SUGAR, CARAMEL COLOR)" and
* "NATURAL FLAVOR (..., NATURAL COLOR CARAMEL)" are genuine caramel color
* declared inside a flavor; only "ARTIFICIAL FLAVORS (VANILLIN, CARAMEL,
* CHOCOLATE)" - caramel as a flavor with no color word - is blanked.
replace car_scan = ustrregexra(car_scan, "flavou?r(ing)?s?[ ]*[\(\[](?![^\)\]]*colou?r)[^\)\]]{0,100}caramel[^\)\]]{0,100}[\)\]]", " ")

* --------------------- explicit caramel color terms ---------------------
* Direct terms run on ing_scan: "CARAMEL COLOR" is unambiguous even inside
* a flavor parenthetical.
foreach term in caramelcolor caramelcoloring caramelcolour caramelcolouring caramel.color caramelcolouring caramelcoloradded caramelcolouradded carameladdedcolor carameladdedcolour {
    addflag caramel_color_flag caramel_color_match `term' space ing_scan nohead
}

* Caramel explicitly used as/for color
foreach term in caramelascolor caramelascolour caramelforcolor caramelforcolour {
    addflag caramel_color_flag caramel_color_match `term' space ing_scan nohead
}

* Punctuation/parentheses: CARAMEL AS COLOR, CARAMEL (FOR COLOR), caramel-for-color
replace caramel_color_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])caramel[ ]*[\(]?[ ]*(as|for)[ ]*colou?r[ ]*[\)]?([^a-z]|$)")
replace caramel_color_match = "caramel as/for color" if ustrregexm(ing_scan, "(^|[^a-z])caramel[ ]*[\(]?[ ]*(as|for)[ ]*colou?r[ ]*[\)]?([^a-z]|$)") & caramel_color_match == ""

* --------------------- caramel next to a color declaration ---------------------
* COLOR; CARAMEL / COLOR: CARAMEL / CARAMEL, COLOUR / ORGANIC CARAMEL,
* [COLOR] / NATURAL FOOD COLORINGS (..., CARAMEL) / CARAMEL AND ANNATTO
* EXTRACT (COLOR).
*
* The punctuation window excludes ) and ]: in "ANNATTO (COLOR), CARAMEL
* SWIRLS" the closing bracket means COLOR belonged to the previous
* ingredient and CARAMEL starts a new one. CARFOOD / CARSUB / CARPRE keep
* food caramel out. "caramel" must end at a word boundary, so CARAMELIZED
* never matches.

* (a) color -> caramel across short punctuation
replace caramel_color_flag = 1 if ustrregexm(car_scan, "(^|[^a-z])colou?r(ing)?s?[^a-z0-9)\]]{1,12}`CARPRE'caramel(?![a-z])`CARFOOD'`CARSUB'")
replace caramel_color_match = "color, caramel" if ustrregexm(car_scan, "(^|[^a-z])colou?r(ing)?s?[^a-z0-9)\]]{1,12}`CARPRE'caramel(?![a-z])`CARFOOD'`CARSUB'") & caramel_color_match == ""

* (b) caramel -> color across short punctuation
replace caramel_color_flag = 1 if ustrregexm(car_scan, "(^|[^a-z])`CARPRE'caramel(?![a-z])`CARSUB'[^a-z0-9)\]]{1,12}colou?r(ing)?s?([^a-z]|$)")
replace caramel_color_match = "caramel, color" if ustrregexm(car_scan, "(^|[^a-z])`CARPRE'caramel(?![a-z])`CARSUB'[^a-z0-9)\]]{1,12}colou?r(ing)?s?([^a-z]|$)") & caramel_color_match == ""

* (c) caramel anywhere inside a color parenthetical: COLORS (ANNATTO, ..., CARAMEL)
replace caramel_color_flag = 1 if ustrregexm(car_scan, "(^|[^a-z])colou?r(ing)?s?[ ]*[:\(\[][^\)\]]{0,250}`CARPRE'caramel(?![a-z])`CARFOOD'`CARSUB'")
replace caramel_color_match = "colors (..., caramel)" if ustrregexm(car_scan, "(^|[^a-z])colou?r(ing)?s?[ ]*[:\(\[][^\)\]]{0,250}`CARPRE'caramel(?![a-z])`CARFOOD'`CARSUB'") & caramel_color_match == ""

* (d) caramel and <other colorant> (color): CARAMEL AND ANNATTO EXTRACT (COLOR)
replace caramel_color_flag = 1 if ustrregexm(car_scan, "(^|[^a-z])`CARPRE'caramel(?![a-z])[ ]+and[ ]+[a-z ]{0,30}[\(\[]?colou?r(ing)?s?([^a-z]|$)")
replace caramel_color_match = "caramel and ... (color)" if ustrregexm(car_scan, "(^|[^a-z])`CARPRE'caramel(?![a-z])[ ]+and[ ]+[a-z ]{0,30}[\(\[]?colou?r(ing)?s?([^a-z]|$)") & caramel_color_match == ""

* (e) COLOR[CARAMEL] / COLOR (CARAMEL) / COLOR: CARAMEL - tight adjacency.
* The separator must not include a closing bracket: "ANNATTO FOR COLOR).
* CARAMEL SAUCE" is annatto's color declaration followed by a caramel FOOD
* component.
replace caramel_color_flag = 1 if ustrregexm(car_scan, "(^|[^a-z])colou?rs?[^a-z0-9,;)\]]{0,6}`CARPRE'caramel(?![a-z])`CARFOOD'`CARSUB'")
replace caramel_color_match = "color[caramel]" if ustrregexm(car_scan, "(^|[^a-z])colou?rs?[^a-z0-9,;)\]]{0,6}`CARPRE'caramel(?![a-z])`CARFOOD'`CARSUB'") & caramel_color_match == ""

replace caramel_color_flag = 1 if ustrregexm(car_scan, "(^|[^a-z])`CARPRE'caramel(?![a-z])`CARSUB'[^a-z0-9,;)\]]{0,6}colou?rs?([^a-z]|$)")
replace caramel_color_match = "caramel[color]" if ustrregexm(car_scan, "(^|[^a-z])`CARPRE'caramel(?![a-z])`CARSUB'[^a-z0-9,;)\]]{0,6}colou?rs?([^a-z]|$)") & caramel_color_match == ""

* --------------------- caramel in the company of named colorants ---------------------
* Three label structures no color-adjacency rule above can reach:
*   1. "..., CARAMEL, YELLOW NO. 5 AND BLUE NO. 1)" - caramel listed
*      alongside named dyes with no "color" word at all
*   2. "COLORED WITH (VEGETABLE JUICE, TURMERIC, ... AND CARAMEL)" - the
*      opener is "COLORED WITH (", not "COLOR("
*   3. "ARTIFICIAL COLOR (...), TITANIUM DIOXIDE, ... PARABENS, CARAMEL]"
*      - caramel sits just OUTSIDE the color parenthetical
*
* Rule: caramel counts when a NAMED COLORANT appears within 80 characters
* on either side. The window was set based on the manually validated
* samples.

* colorant BEFORE caramel (within 80 chars)
replace caramel_color_flag = 1 if ustrregexm(car_scan, "`COLORANT'.{0,80}`CARPRE'caramel(?![a-z])`CARFOOD'`CARSUB'")
replace caramel_color_match = "caramel w/ named colorants" if ustrregexm(car_scan, "`COLORANT'.{0,80}`CARPRE'caramel(?![a-z])`CARFOOD'`CARSUB'") & caramel_color_match == ""

* colorant AFTER caramel (within 80 chars)
replace caramel_color_flag = 1 if ustrregexm(car_scan, "`CARPRE'caramel(?![a-z])`CARFOOD'`CARSUB'.{0,80}`COLORANT'")
replace caramel_color_match = "caramel w/ named colorants" if ustrregexm(car_scan, "`CARPRE'caramel(?![a-z])`CARFOOD'`CARSUB'.{0,80}`COLORANT'") & caramel_color_match == ""

* E150 subclasses first, then E150 / 150
foreach code in 150a 150b 150c 150d {
    ecodeflag caramel_color_flag caramel_color_match `code'
}
ecodeflag caramel_color_flag caramel_color_match 150

* accounting for spelling mistakes
foreach term in carmelcolor garamelcolor capamelcolor caramalcolor caramealcolor caramecolor caramekcolor caramel.color caramelacoloring caramelcolo caramelcolour caramelcoloure caramelcolouring caramelfolor caramelgolor caramelicolor caramlcolor caramlecolor caranelcolor caravelcolor caremelcolor carmelcolour ceramelcolor cramelcolor saramelcolor {
    addflag caramel_color_flag caramel_color_match `term' space ing_scan nohead
}

capture drop car_scan

* ------------------------------------------------------- BHA ----------------------------------
gen bha_flag = 0
gen bha_match = ""

* Name-based matches
foreach term in butylatedhydroxyanisole antioxidant\(bha\) preservative\(bha\) antioxidantbha preservativebha {
    addflag bha_flag bha_match `term'
}

* Standalone BHA
replace bha_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])bha([^a-z]|$)")
replace bha_match = "bha" if ustrregexm(ing_scan, "(^|[^a-z])bha([^a-z]|$)") & bha_match == ""

* E320 / 320 (cashew grade sizes excluded via extra rule)
ecodeflag bha_flag bha_match 320 "cashews?\W{0,3}(w\s*)?320|320\W{0,3}cashews?|raw\s+320\s+cashews?"

* accounting for spelling mistakes
foreach term in butylatedhydroxianisole butylatedhydroxyanisole butylatedhydroxylanisole butylhydroxyanisole butylatedhydroxyanisol {
    addflag bha_flag bha_match `term'
}

* --------------------------------------------- BHT ---------------------------------------------
gen bht_flag = 0
gen bht_match = ""

* Name-based matches
foreach term in butylatedhydroxytoluene antioxidant\(bht\) preservative\(bht\) antioxidantbht preservativebht {
    addflag bht_flag bht_match `term'
}

* Standalone BHT
replace bht_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])bht([^a-z]|$)")
replace bht_match = "bht" if ustrregexm(ing_scan, "(^|[^a-z])bht([^a-z]|$)") & bht_match == ""

* E321 / 321
ecodeflag bht_flag bht_match 321

* accounting for spelling mistakes / alternate spellings
foreach term in butylatedhydroxtoluene butylatedhydroxytolune butylatedhydroxytoluen butylatedhydroxytoluol butylhydroxytoluene dibutylhydroxytoluene {
    addflag bht_flag bht_match `term'
}

* ---------------------------------- Propyl Gallate ----------------------------------
gen propyl_gallate_flag = 0
gen propyl_gallate_match = ""

* Name-based matches
foreach term in propylgallate propyl-gallate antioxidant\(propylgallate\) antioxidantpropylgallate {
    addflag propyl_gallate_flag propyl_gallate_match `term'
}

* Propyl gallate with spacing / punctuation
replace propyl_gallate_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])propyl[ -]*gallate([^a-z]|$)")
replace propyl_gallate_match = "propyl gallate" if ustrregexm(ing_scan, "(^|[^a-z])propyl[ -]*gallate([^a-z]|$)") & propyl_gallate_match == ""

* stray comma inside the name (PROPYL, GALLATE): PROPYL alone is not an
* ingredient, so the comma must be a label typo
replace propyl_gallate_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])propyl[ ,._-]{1,3}gallate([^a-z]|$)")
replace propyl_gallate_match = "propyl, gallate" if ustrregexm(ing_scan, "(^|[^a-z])propyl[ ,._-]{1,3}gallate([^a-z]|$)") & propyl_gallate_match == ""

* E310 / 310
ecodeflag propyl_gallate_flag propyl_gallate_match 310

* accounting for spelling mistakes
foreach term in propylgellate proplgallate proplygallate proppylgallate propygallate propylgalate propylgaliate propylgallare propyllgallate {
    addflag propyl_gallate_flag propyl_gallate_match `term'
}

* --------------------------------------- TBHQ --------------------------------------------------
gen tbhq_flag = 0
gen tbhq_match = ""

* Name-based matches
foreach term in tertbutylhydroquinone tert-butylhydroquinone tertiarybutylhydroquinone tertiary-butylhydroquinone antioxidant\(tbhq\) preservative\(tbhq\) antioxidanttbhq preservativetbhq {
    addflag tbhq_flag tbhq_match `term'
}

* Standalone TBHQ
replace tbhq_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])tbhq([^a-z]|$)")
replace tbhq_match = "tbhq" if ustrregexm(ing_scan, "(^|[^a-z])tbhq([^a-z]|$)") & tbhq_match == ""

* E319 / 319
ecodeflag tbhq_flag tbhq_match 319

* -------------------------------------- Sodium Benzoate -------------------------------
gen sodium_benzoate_flag = 0
gen sodium_benzoate_match = ""

* Name-based matches
foreach term in sodiumbenzoate preservative\(sodiumbenzoate\) preservativesodiumbenzoate sodiumbenzoatepreservative sodiumbenzoatepreservesfreshness benzoicacidsodiumsalt {
    addflag sodium_benzoate_flag sodium_benzoate_match `term' space ing_scan nohead
}

* Sodium benzoate with spacing / punctuation
replace sodium_benzoate_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])sodium[ -]*benzoate([^a-z]|$)")
replace sodium_benzoate_match = "sodium benzoate" if ustrregexm(ing_scan, "(^|[^a-z])sodium[ -]*benzoate([^a-z]|$)") & sodium_benzoate_match == ""

* stray comma inside the name: "SODIUM, BENZOATE ( A PRESERVATIVE)"
* (SODIUM alone is not an ingredient here)
replace sodium_benzoate_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])sodium[ ,._-]{1,3}benzoate([^a-z]|$)")
replace sodium_benzoate_match = "sodium, benzoate" if ustrregexm(ing_scan, "(^|[^a-z])sodium[ ,._-]{1,3}benzoate([^a-z]|$)") & sodium_benzoate_match == ""

* BENZOATE OF SODA (traditional English name) and BENZOATE DE SODIUM /
* BENZOATO DE SODIO (French / Spanish-Portuguese names on imported labels).
replace sodium_benzoate_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])benzoat[eo]s?[ ]+(of[ ]+soda|de[ ]+(sodium|sodio)|di[ ]+sodio)([^a-z]|$)")
replace sodium_benzoate_match = "benzoate of soda / de sodium" if ustrregexm(ing_scan, "(^|[^a-z])benzoat[eo]s?[ ]+(of[ ]+soda|de[ ]+(sodium|sodio)|di[ ]+sodio)([^a-z]|$)") & sodium_benzoate_match == ""

* E211 / 211
ecodeflag sodium_benzoate_flag sodium_benzoate_match 211

* -------------------------------------- Potassium Benzoate -------------------------------
gen potassium_benzoate_flag = 0
gen potassium_benzoate_match = ""

* Name-based matches
foreach term in potassiumbenzoate preservative\(potassiumbenzoate\) preservativepotassiumbenzoate potassiumbenzoatepreservative potassiumbenzoatepreservesfreshness benzoicacidpotassiumsalt {
    addflag potassium_benzoate_flag potassium_benzoate_match `term' space ing_scan nohead
}

* Potassium benzoate with spacing / punctuation
replace potassium_benzoate_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])potassium[ -]*benzoate([^a-z]|$)")
replace potassium_benzoate_match = "potassium benzoate" if ustrregexm(ing_scan, "(^|[^a-z])potassium[ -]*benzoate([^a-z]|$)") & potassium_benzoate_match == ""

* stray comma inside the name: "POTASSIUM, BENZOATE ( A PRESERVATIVE)"
* (POTASSIUM alone is not an ingredient here)
replace potassium_benzoate_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])potassium[ ,._-]{1,3}benzoate([^a-z]|$)")
replace potassium_benzoate_match = "potassium, benzoate" if ustrregexm(ing_scan, "(^|[^a-z])potassium[ ,._-]{1,3}benzoate([^a-z]|$)") & potassium_benzoate_match == ""

* BENZOATE OF POTASH / DE POTASSIUM / DE POTASIO
replace potassium_benzoate_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])benzoat[eo]s?[ ]+(of[ ]+potash|de[ ]+(potassium|potasio|potassio))([^a-z]|$)")
replace potassium_benzoate_match = "benzoate of potash / de potassium" if ustrregexm(ing_scan, "(^|[^a-z])benzoat[eo]s?[ ]+(of[ ]+potash|de[ ]+(potassium|potasio|potassio))([^a-z]|$)") & potassium_benzoate_match == ""

* E212 / 212
ecodeflag potassium_benzoate_flag potassium_benzoate_match 212

* --------------------------------------------- General Benzoates -------------------------------
gen benzoate_flag = 0
gen benzoate_match = ""

* Name-based matches
foreach term in sodiumbenzoate potassiumbenzoate preservative\(sodiumbenzoate\) preservative\(potassiumbenzoate\) preservativesodiumbenzoate preservativepotassiumbenzoate sodiumbenzoatepreservative potassiumbenzoatepreservative sodiumbenzoatepreservesfreshness potassiumbenzoatepreservesfreshness benzoicacidsodiumsalt benzoicacidpotassiumsalt {
    addflag benzoate_flag benzoate_match `term' space ing_scan nohead
}

* Spacing / punctuation variants
replace benzoate_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])sodium[ -]*benzoate([^a-z]|$)")
replace benzoate_match = "sodium benzoate" if ustrregexm(ing_scan, "(^|[^a-z])sodium[ -]*benzoate([^a-z]|$)") & benzoate_match == ""

replace benzoate_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])potassium[ -]*benzoate([^a-z]|$)")
replace benzoate_match = "potassium benzoate" if ustrregexm(ing_scan, "(^|[^a-z])potassium[ -]*benzoate([^a-z]|$)") & benzoate_match == ""

* stray comma inside the name
replace benzoate_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])(sodium|potassium)[ ,._-]{1,3}benzoate([^a-z]|$)")
replace benzoate_match = "sodium/potassium, benzoate" if ustrregexm(ing_scan, "(^|[^a-z])(sodium|potassium)[ ,._-]{1,3}benzoate([^a-z]|$)") & benzoate_match == ""

* BENZOATE OF SODA/POTASH and BENZOATE DE SODIUM / BENZOATO DE SODIO
* (traditional English + French/Spanish names)
replace benzoate_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])benzoat[eo]s?[ ]+(of[ ]+(soda|potash)|de[ ]+(sodium|sodio|potassium|potasio|potassio)|di[ ]+sodio)([^a-z]|$)")
replace benzoate_match = "benzoate of soda / de sodium" if ustrregexm(ing_scan, "(^|[^a-z])benzoat[eo]s?[ ]+(of[ ]+(soda|potash)|de[ ]+(sodium|sodio|potassium|potasio|potassio)|di[ ]+sodio)([^a-z]|$)") & benzoate_match == ""

* E211 sodium benzoate, E212 potassium benzoate
foreach num in 211 212 {
    ecodeflag benzoate_flag benzoate_match `num'
}

* accounting for spelling mistakes
foreach term in sodiumbenzonate sodiumbenzate odiumbenzoate porassiumbenzoate postassiumbenzoate potassiumbenozate potassiumbenozoate potassiumbenzoata potassiumbenzonate potassiumbonzoate potassiumcbenzoate sodiumbenoate saodiumbenzoate sdoiumbenzoate soddiumbenzoate sodidumbenzoate sodiembenzoate sodiumbanzoate sodiumbeazoate sodiumbenazoate sodiumbenozate sodiumbenozoate sodiumbensoate sodiumbenszoate sodiumbenxoate sodiumbenzcate sodiumbenzdate sodiumbenzoale sodiumbenzoalte sodiumbenzoat sodiumbenzoato sodiumbenzolate sodiumbenzonte sodiumbenzoote sodiumbenzote sodiumbenztate sodiumbeozoate sodiumbezoate sodiumbnzoate sodiumbonzoate sodiumdenzoate sodiumhenzoate sodiummbenzoate sodiunbenzoate sodlumbenzoate soduimbenzoate sodumbenzoate soidumbenzoate soudiumbenzoate {
    addflag benzoate_flag benzoate_match `term' space ing_scan nohead
}

* --------------------------------------------- MSG ----------------------------------
gen msg_flag = 0
gen msg_match = ""

* Name-based matches: strictly MSG / monosodium glutamate
foreach term in monosodiumglutamate monosodiumlglutamate flavorenhancer\(msg\) flavourenhancer\(msg\) flavorenhancermsg flavourenhancermsg {
    addflag msg_flag msg_match `term'
}

* Monosodium glutamate / monosodium L-glutamate with spacing or punctuation
replace msg_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])mono[ -]*sodium[ -]*glutamate([^a-z]|$)")
replace msg_match = "monosodium glutamate" if ustrregexm(ing_scan, "(^|[^a-z])mono[ -]*sodium[ -]*glutamate([^a-z]|$)") & msg_match == ""

replace msg_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])mono[ -]*sodium[ -]*l[ -]*glutamate([^a-z]|$)")
replace msg_match = "monosodium l-glutamate" if ustrregexm(ing_scan, "(^|[^a-z])mono[ -]*sodium[ -]*l[ -]*glutamate([^a-z]|$)") & msg_match == ""

* Standalone MSG only
replace msg_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])msg([^a-z]|$)")
replace msg_match = "msg" if ustrregexm(ing_scan, "(^|[^a-z])msg([^a-z]|$)") & msg_match == ""

* E621 / 621
ecodeflag msg_flag msg_match 621

* accounting for spelling mistakes
foreach term in maonosodiumglutamate momosodiumglutamate monododiumglutamate monosdiumglutamate monosodicglutamate monosodiiumglutamate monosodiumgglutamate monosodiumgluamate monosodiumgluatamate monosodiumglumate monosodiumgluta monosodiumglutamamte monosodiumglutamata monosodiumglutamatae monosodiumglutamante monosodiumglutamiate monosodiumglutamiatee monosodiumglutammate monosodiumglutamte monosodiumglutamute monosodiumglutanate monosodiumglutaomate monosodiumglutatmate monosodiumglutemate monosodiumglutenmate monosodiumglutiamate monosodiumglutimate monosodiumglutmamate monosodiumglutmate monosodiumglutumate monosodiumglytamate monosodiumgultamate monosodiumgutamate monosodiumlglutamate monosodiumlutamate monosodumglutamate monosoidiumglutamate monosoodiumglutamate monososodiumglutamate monsodiumglutamate nonosodiumglutamate {
    addflag msg_flag msg_match `term'
}

* Negations (NO MSG, NO MSG ADDED, MSG FREE, CONTAINS NO MSG, DOES NOT
* CONTAIN MSG) are removed from ing_scan before matching.

* -------------------------------------- Propylene Glycol --------------------------
gen byte pg_flag = 0
gen str50 pg_match = ""

* Scan text: punctuation converted to spaces
gen strL pg_scan = ustrregexra(ing_scan, "[^a-z0-9]+", " ")
replace pg_scan = ustrtrim(ustrregexra(pg_scan, "[ ]+", " "))

* Broad PG base pattern, so that misspelled propylene glycol followed by
* a derivative word is also excluded. The base covers typo spellings of
* glycol (GYLCOL, CLYCOL, LYCOL, GLYCIL, GLYCL, GLYCON, ...) and the
* propanediol family (PROPANE-1,2-DIOL, 1,2-PROPANEDIOL), so derivatives
* written on any of these bases are excluded too.
local PGB "((mono|iso|alpha|i)?p[a-z]{3,10}(ene|en|ane|ence|enc)[ ]?[gcl][a-z]{1,6}|(1 2 )?propane ?1? ?2? ?diol|1 2 dihydroxypropane|2 hydroxypropanol|methyl ?ethylene ?glycol)"

* Derivative followers
* (alginat/alginate/alginates, gum, mono*, mono-and-di*, diester(s)/
*  diestr(s), dstr, ester(s), fattyacid(s), fatacds)
* mono branch allows "fatty acid(s)" and a scrambled "of" before the
* ester stem (MONO FATTY ACID ESTERS / MONO FATTY ACID OF ESTERS) and the
* OCR stem DESTERS (MONO-AND DESTERS)
local PGD "(alginates?|alginat|gum|dstr|dstrs|fatacds|fat ?acds|fatty ?acids?( ?esters?)?|mono( ?fatty ?acids?)?( ?and)?( ?di)?( ?of)? ?(esters?|estrs?|dstrs?|dsters?|desters?|stearates?|sterates?|strearates?|strates?|oleates?|gleates?|leates?)|di ?esters?|diesters?|di ?estrs?|diestrs?|esters?|estrs?)"

* Remove derivative phrases: PG + derivative [+ of fatty acids] [+ esters]
* an oil-source word may sit between the base and the derivative:
* PROPANE-1,2-DIOL PALM ESTERS OF FATTY ACIDS
local PGSRC "((palm|soy|soybean|vegetable|sunflower|rapeseed|canola|coconut|corn|cottonseed)( ?oil)? )?"
replace pg_scan = ustrregexra(pg_scan, "(^| )`PGB' ?`PGSRC'`PGD'( ?of ?fat[a-z]*( ?and ?fatty)?( ?acids?| ?acds)?)?( ?esters?)?(?=[ ]|$)", " ")

* Reversed orderings: ALGINATE OF PROPYLENE GLYCOL, ESTERS OF PROPYLENE GLYCOL,
* FATTY ACID ESTERS OF PROPYLENE GLYCOL
replace pg_scan = ustrregexra(pg_scan, "(^| )(alginates?|esters?|fatty ?acids? ?esters?) ?of ?`PGB'(?=[ ]|$)", " ")

replace pg_scan = ustrtrim(ustrregexra(pg_scan, "[ ]+", " "))

* Official propylene glycol names + spelling variants
* (punctuation was converted to spaces, so 1,2-propanediol -> 1 2 propanediol
*  is caught by 12propanediol; propylene.glycol is likewise covered by
*  propyleneglycol)
* MPG / MONOPROPYLENE GLYCOL is an industry name for propylene glycol itself
foreach term in propyleneglycol monopropyleneglycol 12propanediol 12propyleneglycol 12dihydroxypropane 2hydroxypropanol propane12diol isopropyleneglycol alphapropyleneglycol methylethyleneglycol propileneglycol {
    addflag pg_flag pg_match `term' space pg_scan
}

* E1520 / 1520 
ecodeflag pg_flag pg_match 1520

* accounting for spelling mistakes 
foreach term in proplyeneglycol pryopyleneglycol phopyleneglycol popyleneglycol prophleneglycol prophyleneglycol propileneglycol propleneglycol proplyleneglycol propyeneglycol propylaneglycol propylenceglycol propyleneclycol propyleneglicol propylenegluycol propyleneglycil propyleneglycl propyleneglyco propyleneglycon propylenegycol propylenegylcol propylenelycol propylenglycol propyoleneglycol proyleneglycol pyropyleneglycol propylyeneglycol ipropyleneglycol {
    addflag pg_flag pg_match `term' space pg_scan
}

drop pg_scan

* -------------------------------------- HIGH-FRUCTOSE CORN SYRUP --------------------------
gen byte hfcs_flag = 0
gen str50 hfcs_match = ""

* nocomma: punctuation and spaces may appear inside a match, but NOT a
* comma or semicolon. This keeps HIGH-FRUCTOSE CORN SYRUP / HIGH FRUCTOSE
* CORN SYRUP matching while preventing "CRYSTALLINE FRUCTOSE, CORN SYRUP"
* (two separate ingredients) from matching the term fructosecornsyrup.

* Official names and recognized alternatives
foreach term in highfructosecornsyrup cornsyrupwithhighfructose glucosefructosesyrup fructoseglucosesyrup isoglucose {
    addflag hfcs_flag hfcs_match `term' nocomma
}

* HFCS as a standalone abbreviation only. It must NOT go through the
* flexible-separator matching: with spaces allowed between characters,
* "HFC SYRUP" matched (H-F-C, space, then the S of SYRUP)
replace hfcs_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])h[ ]*\.?[ ]*f[ ]*\.?[ ]*c[ ]*\.?[ ]*s([^a-z]|$)")
replace hfcs_match = "hfcs" if ustrregexm(ing_scan, "(^|[^a-z])h[ ]*\.?[ ]*f[ ]*\.?[ ]*c[ ]*\.?[ ]*s([^a-z]|$)") & hfcs_match == ""

* HFC SYRUP / HFC CORN SYRUP = high fructose corn syrup.
* Written as an explicit pattern rather than through the flexible "hfcs"
* abbreviation, to avoid the cross-word match described above.
replace hfcs_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])h[ ]*\.?[ ]*f[ ]*\.?[ ]*c[ ]*\.?[ ]*[ ,._-]*(corn[ ,._-]*)?syrup([^a-z]|$)")
replace hfcs_match = "hfc syrup" if ustrregexm(ing_scan, "(^|[^a-z])h[ ]*\.?[ ]*f[ ]*\.?[ ]*c[ ]*\.?[ ]*[ ,._-]*(corn[ ,._-]*)?syrup([^a-z]|$)") & hfcs_match == ""

* HFCS definition:
*   - GLUCOSE-FRUCTOSE SYRUP and ISOGLUCOSE count as HFCS (EU/Canadian
*     naming for high-fructose syrups) - matched by the term list above.
*   - Bare GLUCOSE-FRUCTOSE (no "syrup") counts ONLY with corn syrup
*     context: GLUCOSE-FRUCTOSE CORN SYRUP / GLUCOSE-FRUCTOSE, CORN
*     SYRUP (stray comma) below.
*   - "GLUCOSE, FRUCTOSE" and "GLUCOSE, FRUCTOSE SYRUP" with a comma =
*     separate sweeteners, NOT HFCS.
replace hfcs_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])(glucose[ ,._-]*fructose|fructose[ ,._-]*glucose)[ ,._-]*corn[ ,._-]*syrup")
replace hfcs_match = "glucose-fructose corn syrup" if ustrregexm(ing_scan, "(^|[^a-z])(glucose[ ,._-]*fructose|fructose[ ,._-]*glucose)[ ,._-]*corn[ ,._-]*syrup") & hfcs_match == ""

* "HIGH FRUCTOSE, CORN SYRUP" with a stray comma is still HFCS: "HIGH
* FRUCTOSE" is not an ingredient on its own, so the comma must be a
* label typo. Allow the comma only when HIGH is present (the bare
* fructosecornsyrup term stays comma-blocked, because "FRUCTOSE, CORN
* SYRUP" without HIGH really is two separate ingredients).
replace hfcs_flag = 1 if ustrregexm(ing_scan, "(^|[^a-z])high[ ,._-]*fructose[ ,._-]*corn[ ,._-]*syrup")
replace hfcs_match = "high fructose, corn syrup" if ustrregexm(ing_scan, "(^|[^a-z])high[ ,._-]*fructose[ ,._-]*corn[ ,._-]*syrup") & hfcs_match == ""

* Observed spelling and OCR errors
foreach term in highfructosecomsyrup fructosecornsyrup hifructosecornsyrup highfluctosecornsyrup highfrucrtosecorbsyrup highfructisecornsyrup highfructoecornsyrup highfructosecansyrup highfructosecoansirup highfructoseconsyrup highfructosecorn highfructosecorncyrup highfructosecornsirup highfructosecornsrup highfructosecornsyup highfructosecornysyrup highfructosecorysyrup highfructoseornsyrup highfructosescornsyrup highfructosezcornsyrup highfructusecornsyrup highfrugtosecornsyrup highfruotosecornsyrup highfrustosecornsyrup highfrutcosecornsyrup highfrutosecornsyrup highfrutrosecornsyrup highfuctosecornsyrup highofructosecornsyrup highrructosecornsyrup highructosecornsyrup hightfructosecornsyrup hughfructosecornsyrup cornsyrupwithhighfructose nighfructosecornsyrup hoghfructosecornsyrup highfructosecornstrup highfrutosecorn highfrutosecornstrup highfructosecorysyrup highfructosecom glucosefruktosesyrup glucosefruktozesyrup glukosefruktosesyrup glukozefruktozesyrup fruktoseglucosesyrup fruktozeglucosesyrup {
    addflag hfcs_flag hfcs_match `term' nocomma
}

* ---------------------------------------------- Yellow 6 ----------------------------------
gen yellow_6_flag = 0
gen yellow_6_match = ""

foreach term in yellow6 yellow#6 yellow.#6 yellowno.6 yellowno6 yellowno#6 yellowno.#6 yellown6 yellown.6 yellown#6 yellownâ°6 yellownÂ°6 yellown°6 yellownumber6 yellownum6 fd&cyellow6 fd&cyellow#6 fd&cyellow.#6 fd&cyellowno.6 fd&cyellowno6 fd&cyellowno#6 fd&cyellowno.#6 fd&cyellown6 fd&cyellown.6 fd&cyellown#6 fd&cyellownâ°6 fd&cyellownÂ°6 fd&cyellown°6 yellows6 yellows#6 yellows.6 yellowsno6 yellowsno.6 yellowsno#6 yellowsno.#6 sunsetyellow sunsetyellowfcf sunsetyellowf.c.f sunsetyellowf.c.f. orangeyellows orangeyellowsfcf orangeyellow yellow5&6 yellow6&5 yellow5and6 yellow6and5 yellow#5&6 yellow#6&5 yellow#5&#6 yellow#6&#5 yellow#5and6 yellow#6and5 yellow#5and#6 yellow#6and#5 yellow#5#6 yellow#6#5 yellowno5&6 yellowno6&5 yellowno5and6 yellowno6and5 yellowno.5&6 yellowno.6&5 yellowno.5and6 yellowno.6and5 yellowno.5andno.6 yellowno.6andno.5 yellows5&6 yellows6&5 yellows5and6 yellows6and5 yellows#5&#6 yellows#6&#5 yellows#5and#6 yellows#6and#5 fd&cyellow5&6 fd&cyellow6&5 fd&cyellow5and6 fd&cyellow6and5 fd&cyellow#5&6 fd&cyellow#6&5 fd&cyellow#5&#6 fd&cyellow#6&#5 fd&cyellow#5and6 fd&cyellow#6and5 fd&cyellow#5and#6 fd&cyellow#6and#5 yellow6lake yellow#6lake yellow.#6lake yellowno6lake yellowno.6lake yellowno#6lake yellowno.#6lake yellown6lake yellown.6lake yellown#6lake yellownâ°6lake yellownÂ°6lake yellown°6lake yellowlake6 yellowlake#6 yellowlake.6 yellowlakeno6 yellowlakeno.6 yellowlakeno#6 yellowlakeno.#6 yellowlaken6 yellowlaken.6 yellowlaken#6 yellowlakenâ°6 yellowlakenÂ°6 yellowlaken°6 yellowslake6 yellowslake#6 yellowslake.6 yellowslakeno6 yellowslakeno.6 yellowslakeno#6 yellowslakeno.#6 fd&cyellow6lake fd&cyellow#6lake fd&cyellow.#6lake fd&cyellowno6lake fd&cyellowno.6lake fd&cyellowno#6lake fd&cyellowno.#6lake fd&cyellowlake6 fd&cyellowlake#6 fd&cyellowlake.6 fd&cyellowlakeno6 fd&cyellowlakeno.6 fd&cyellowlakeno#6 fd&cyellowlakeno.#6 yellowlake5and6 yellowlake6and5 yellowlake5&6 yellowlake6&5 yellowlake#5and#6 yellowlake#6and#5 yellowlake#5&#6 yellowlake#6&#5 yellowlakes5and6 yellowlakes6and5 yellowlakes5&6 yellowlakes6&5 yellowslake5and6 yellowslake6and5 yellowslake5&6 yellowslake6&5 yellow5lakeand6 yellow6lakeand5 yellow5lake&6 yellow6lake&5 yellow#5lakeand#6 yellow#6lakeand#5 yellow#5lake&#6 yellow#6lake&#5 fd&cyellowlake5and6 fd&cyellowlake6and5 fd&cyellowlake5&6 fd&cyellowlake6&5 fd&cyellowlake#5and#6 fd&cyellowlake#6and#5 fd&cyellowlake#5&#6 fd&cyellowlake#6&#5 yellowcolor#5and#6 yellowcolors#5and#6 yellowcolor#5and6 yellowcolors#5and6 yellowcolor#5&6 yellowcolors#5&6 yellowcolor#5&#6 yellowcolors#5&#6 yellowcolor#5and#6lake yellowcolors#5and#6lake yellowcolor#5lakeand#6lake yellowcolors#5lakeand#6lake yellowcolorno.5and6 yellowcolorsno.5and6 yellowcolorno.5andno.6 yellowcolorsno.5andno.6 yellowcolornos.5and6 yellowcolorsnos.5and6 yellowcolorno.5&6 yellowcolorsno.5&6 yellowcolour#5and#6 yellowcolours#5and#6 yellowcolour#5and6 yellowcolours#5and6 yellowcolour#5&6 yellowcolours#5&6 coloryellow#5and#6 colorsyellow#5and#6 yellow#5and#6(color) yellow#5and#6(colors) yellowno.5andno.6(color) yellownos.5&6 fd&cyellowcolor#5and#6 fd&cyellowcolors#5and#6 fd&cyellowcolorno.5andno.6 fd&cyellowcolorsno.5andno.6 fd&cyellowcolors#5&#6 fd&cyellow#5and#6color fd&cyellow#5and#6colors f.d.&c.yellowcolor#5and#6 f.d.&c.yellowcolors#5and#6 yellowcolors#5&#6lake yellowlakecolor#5and#6 yellowlakecolors#5and#6 yellow#5lakeandyellow#6lake yellowcolor#6 yellowcolors#6 yellowcolor#6lake yellowcolors#6lake yellowcolorno.6 yellowcolorsno.6 yellowcolour#6 yellowcolours#6 coloryellow#6 colorsyellow#6 coloryellowno.6 colouryellow#6 coloursyellow#6 yellow#6(color) yellow#6(colors) yellowno.6(color) fd&cyellowcolor#6 fd&cyellowcolors#6 fd&cyellowcolorno.6 f.d.&c.yellowcolor#6 yellowlakecolor#6 yellowlakecolors#6 yellow#6lake {
    addflag yellow_6_flag yellow_6_match `term' space ing_scan nohead
}

* E110 / 110 (110TH, EMULPALS 110, 110MG etc. excluded generically)
ecodeflag yellow_6_flag yellow_6_match 110

* accounting for spelling mistakes
foreach term in fd&cyellow#5&#6 fd&cyellow#6&#5 fd&cyellow#5&6 fd&cyellow#6&5 fd&cyellow#5and#6 fd&cyellow#6and#5 fd&cyellowno.5&6 fd&cyellowno.6&5 fd&cyellowno.5&no.6 fd&cyellowno.6&no.5 fd&cyellowno5&no6 fd&cyellowno6&no5 fd&cyellowno5no6 fd&cyellowno6no5 fd&cyellows5&6 fd&cyellows6&5 fdcyellow#5&#6 fdcyellow#6&#5 yellows5&6 yellows6&5 yellowno.5&no.6 yellowno.6&no.5 yellowno.5&6 yellowno.6&5 yellowno.5y6 yellowno.6y5 yellow#5&#6 yellow#6&#5 yellow#5&6 yellow#6&5 yellowcolor#5&#6 yellowcolor#6&#5 artyellowno.5&6 artyellowno.6&5 fd&cvellow#6 fd&cyellon#6 fd&cyellown6 fd&cyellowno6 fd&cyellowndegree6 fd&cyelow#6 fd&cyelown6 yellosno.6 yelow#6 yellownos5and6 yellownos6and5 yellowlakes6 yellowlakes5&6 yellowlakes6&5 includingyellow6 andyellow6 lyellow6 oryellow6 oryellow#6 yellowv6 yellowv#6 yellow#06 yellow06 fd&cyellow#06 yellow61 yellow65 yellowfd&c#6 yellowfd&c6 yellowfd&cno.6 {
    addflag yellow_6_flag yellow_6_match `term' space ing_scan nohead
}

* ---------------------------------------- Blue 1 ----------------------------------------
gen blue_1_flag = 0
gen blue_1_match = ""

foreach term in blue1 blue#1 blue.#1 blueno1 blueno.1 blueno#1 blueno.#1 bluen1 bluen.1 bluen#1 bluenâ°1 bluenÂ°1 bluen°1 bluenumber1 bluenum1 blues1 blues#1 blues.1 bluesno1 bluesno.1 bluesno#1 bluesno.#1 fd&cblue1 fd&cblue#1 fd&cblue.#1 fd&cblueno1 fd&cblueno.1 fd&cblueno#1 fd&cblueno.#1 fd&cbluen1 fd&cbluen.1 fd&cbluen#1 fd&cbluenâ°1 fd&cbluenÂ°1 fd&cbluen°1 brilliantbluefcf brilliantbluef.c.f brilliantbluef.c.f. brilliantblue acidblue9 acidblue#9 acidblue.9 acidblueno9 acidblueno.9 blue1&2 blue2&1 blue1and2 blue2and1 blue#1&2 blue#2&1 blue#1&#2 blue#2&#1 blue#1and2 blue#2and1 blue#1and#2 blue#2and#1 blue#1#2 blue#2#1 blueno1&2 blueno2&1 blueno1and2 blueno2and1 blueno.1&2 blueno.2&1 blueno.1and2 blueno.2and1 blueno.1andno.2 blueno.2andno.1 blues1&2 blues2&1 blues1and2 blues2and1 blues#1&#2 blues#2&#1 blues#1and#2 blues#2and#1 bluecolor#1 bluecolors#1 bluecolor#1lake bluecolors#1lake bluecolorno.1 bluecolorsno.1 bluecolour#1 bluecolours#1 colorblue#1 colorsblue#1 colorblueno.1 colourblue#1 coloursblue#1 blue#1(color) blue#1(colors) blueno.1(color) fd&cbluecolor#1 fd&cbluecolors#1 fd&cbluecolorno.1 f.d.&c.bluecolor#1 bluelakecolor#1 bluelakecolors#1 blue#1lake fd&cblue1&2 fd&cblue2&1 fd&cblue1and2 fd&cblue2and1 fd&cblue#1&2 fd&cblue#2&1 fd&cblue#1&#2 fd&cblue#2&#1 fd&cblue#1and#2 fd&cblue#2and#1 blue1lake blue#1lake blue.#1lake blueno1lake blueno.1lake blueno#1lake blueno.#1lake bluen1lake bluen.1lake bluen#1lake bluenâ°1lake bluenÂ°1lake bluen°1lake bluelake1 bluelake#1 bluelake.1 bluelakeno1 bluelakeno.1 bluelakeno#1 bluelakeno.#1 bluelaken1 bluelaken.1 bluelaken#1 bluelakenâ°1 bluelakenÂ°1 bluelaken°1 blueslake1 blueslake#1 blueslake.1 blueslakeno1 blueslakeno.1 blueslakeno#1 blueslakeno.#1 fd&cblue1lake fd&cblue#1lake fd&cblue.#1lake fd&cblueno1lake fd&cblueno.1lake fd&cblueno#1lake fd&cblueno.#1lake fd&cbluelake1 fd&cbluelake#1 fd&cbluelake.1 fd&cbluelakeno1 fd&cbluelakeno.1 fd&cbluelakeno#1 fd&cbluelakeno.#1 bluelake1and2 bluelake2and1 bluelake1&2 bluelake2&1 bluelake#1and#2 bluelake#2and#1 bluelake#1&#2 bluelake#2&#1 blueslake1and2 blueslake2and1 blueslake1&2 blueslake2&1 blue1lakeand2 blue2lakeand1 blue1lake&2 blue2lake&1 blue#1lakeand#2 blue#2lakeand#1 blue#1lake&#2 blue#2lake&#1 fd&cbluelake1and2 fd&cbluelake2and1 fd&cbluelake1&2 fd&cbluelake2&1 fd&cbluelake#1and#2 fd&cbluelake#2and#1 fd&cbluelake#1&#2 fd&cbluelake#2&#1 bluecolor#1and#2 bluecolors#1and#2 bluecolor#1and2 bluecolors#1and2 bluecolor#1&2 bluecolors#1&2 bluecolor#1&#2 bluecolors#1&#2 bluecolor#1and#2lake bluecolors#1and#2lake bluecolor#1lakeand#2lake bluecolors#1lakeand#2lake bluecolorno.1and2 bluecolorsno.1and2 bluecolorno.1andno.2 bluecolorsno.1andno.2 bluecolornos.1and2 bluecolorsnos.1and2 bluecolorno.1&2 bluecolorsno.1&2 bluecolour#1and#2 bluecolours#1and#2 bluecolour#1and2 bluecolours#1and2 bluecolour#1&2 bluecolours#1&2 colorblue#1and#2 colorsblue#1and#2 blue#1and#2(color) blue#1and#2(colors) blueno.1andno.2(color) bluenos.1&2 fd&cbluecolor#1and#2 fd&cbluecolors#1and#2 fd&cbluecolorno.1andno.2 fd&cbluecolorsno.1andno.2 fd&cbluecolors#1&#2 fd&cblue#1and#2color fd&cblue#1and#2colors f.d.&c.bluecolor#1and#2 f.d.&c.bluecolors#1and#2 bluecolors#1&#2lake bluelakecolor#1and#2 bluelakecolors#1and#2 blue#1lakeandblue#2lake {
    addflag blue_1_flag blue_1_match `term' space ing_scan nohead
}

* E133 / 133
ecodeflag blue_1_flag blue_1_match 133

* accounting for spelling mistakes
foreach term in brilliantblefcf brilliantbluefc brilliantbluefdf fd&cbluen1 fd&cbluen1fcf fd&cbluenos.1 fd&cblueno1fcf fd&cblue.no.1 fd&cbluenumber1 fd&cbluendegree1 fd&cblue#1&#2 fd&cblue#2&#1 fd&cblue#1&2 fd&cblue#2&1 fd&cbluecolor#1&#2 fd&cbluecolor#2&#1 fd&cbleu#1 fd&cbluw#1 fd&cblie#1 fd&cbule#1 blu#1 bue#1 blie#1 bluw#1 bleu#1 bluelakes1 bluelakes1&2 bluelakes1and2 bluelakes2&1 bluelakes2and1 bluenos1 bluenos.1 bluefd&c#1 bluefd&c1 bluefd&cno.1 {
    addflag blue_1_flag blue_1_match `term' space ing_scan nohead
}

* ---------------------------------------- Blue 2 ----------------------------------------------
gen blue_2_flag = 0
gen blue_2_match = ""

foreach term in blue2 blue#2 blue.#2 blueno2 blueno.2 blueno#2 blueno.#2 bluen2 bluen.2 bluen#2 bluenâ°2 bluenÂ°2 bluen°2 bluenumber2 bluenum2 blues2 blues#2 blues.2 bluesno2 bluesno.2 bluesno#2 bluesno.#2 fd&cblue2 fd&cblue#2 fd&cblue.#2 fd&cblueno2 fd&cblueno.2 fd&cblueno#2 fd&cblueno.#2 fd&cbluen2 fd&cbluen.2 fd&cbluen#2 fd&cbluenâ°2 fd&cbluenÂ°2 fd&cbluen°2 indigotine indigotin indigocarmine indigocarmin indigo5.5disulfonicacid disodiumindigodisulfonate blue1&2 blue2&1 blue1and2 blue2and1 blue#1&2 blue#2&1 blue#1&#2 blue#2&#1 blue#1and2 blue#2and1 blue#1and#2 blue#2and#1 blue#1#2 blue#2#1 blueno1&2 blueno2&1 blueno1and2 blueno2and1 blueno.1&2 blueno.2&1 blueno.1and2 blueno.2and1 blueno.1andno.2 blueno.2andno.1 blues1&2 blues2&1 blues1and2 blues2and1 blues#1&#2 blues#2&#1 blues#1and#2 blues#2and#1 fd&cblue1&2 fd&cblue2&1 fd&cblue1and2 fd&cblue2and1 fd&cblue#1&2 fd&cblue#2&1 fd&cblue#1&#2 fd&cblue#2&#1 fd&cblue#1and#2 fd&cblue#2and#1 blue2lake blue#2lake blue.#2lake blueno2lake blueno.2lake blueno#2lake blueno.#2lake bluen2lake bluen.2lake bluen#2lake bluenâ°2lake bluenÂ°2lake bluen°2lake bluelake2 bluelake#2 bluelake.2 bluelakeno2 bluelakeno.2 bluelakeno#2 bluelakeno.#2 bluelaken2 bluelaken.2 bluelaken#2 bluelakenâ°2 bluelakenÂ°2 bluelaken°2 blueslake2 blueslake#2 blueslake.2 blueslakeno2 blueslakeno.2 blueslakeno#2 blueslakeno.#2 bluecolor#2 bluecolors#2 bluecolor#2lake bluecolors#2lake bluecolorno.2 bluecolorsno.2 bluecolour#2 bluecolours#2 colorblue#2 colorsblue#2 colorblueno.2 colourblue#2 coloursblue#2 blue#2(color) blue#2(colors) blueno.2(color) fd&cbluecolor#2 fd&cbluecolors#2 fd&cbluecolorno.2 f.d.&c.bluecolor#2 bluelakecolor#2 bluelakecolors#2 blue#2lake fd&cblue2lake fd&cblue#2lake fd&cblue.#2lake fd&cblueno2lake fd&cblueno.2lake fd&cblueno#2lake fd&cblueno.#2lake fd&cbluelake2 fd&cbluelake#2 fd&cbluelake.2 fd&cbluelakeno2 fd&cbluelakeno.2 fd&cbluelakeno#2 fd&cbluelakeno.#2 bluelake1and2 bluelake2and1 bluelake1&2 bluelake2&1 bluelake#1and#2 bluelake#2and#1 bluelake#1&#2 bluelake#2&#1 blueslake1and2 blueslake2and1 blueslake1&2 blueslake2&1 blue1lakeand2 blue2lakeand1 blue1lake&2 blue2lake&1 blue#1lakeand#2 blue#2lakeand#1 blue#1lake&#2 blue#2lake&#1 fd&cbluelake1and2 fd&cbluelake2and1 fd&cbluelake1&2 fd&cbluelake2&1 fd&cbluelake#1and#2 fd&cbluelake#2and#1 fd&cbluelake#1&#2 fd&cbluelake#2&#1 bluecolor#1and#2 bluecolors#1and#2 bluecolor#1and2 bluecolors#1and2 bluecolor#1&2 bluecolors#1&2 bluecolor#1&#2 bluecolors#1&#2 bluecolor#1and#2lake bluecolors#1and#2lake bluecolor#1lakeand#2lake bluecolors#1lakeand#2lake bluecolorno.1and2 bluecolorsno.1and2 bluecolorno.1andno.2 bluecolorsno.1andno.2 bluecolornos.1and2 bluecolorsnos.1and2 bluecolorno.1&2 bluecolorsno.1&2 bluecolour#1and#2 bluecolours#1and#2 bluecolour#1and2 bluecolours#1and2 bluecolour#1&2 bluecolours#1&2 colorblue#1and#2 colorsblue#1and#2 blue#1and#2(color) blue#1and#2(colors) blueno.1andno.2(color) bluenos.1&2 fd&cbluecolor#1and#2 fd&cbluecolors#1and#2 fd&cbluecolorno.1andno.2 fd&cbluecolorsno.1andno.2 fd&cbluecolors#1&#2 fd&cblue#1and#2color fd&cblue#1and#2colors f.d.&c.bluecolor#1and#2 f.d.&c.bluecolors#1and#2 bluecolors#1&#2lake bluelakecolor#1and#2 bluelakecolors#1and#2 blue#1lakeandblue#2lake {
    addflag blue_2_flag blue_2_match `term' space ing_scan nohead
}

* E132 / 132
ecodeflag blue_2_flag blue_2_match 132

* accounting for spelling mistakes
foreach term in f.d&cbluen.2 fd&cbluen2 fd&cbluen.2 fd&cbluen#2 fd&cbluenos.2 fd&cblueno2fcf fd&cblue.no.2 fd&cbluenumber2 fd&cbluendegree2 fd&cblue#1&#2 fd&cblue#2&#1 fd&cblue#1&2 fd&cblue#2&1 fd&cbluecolor#1&#2 fd&cbluecolor#2&#1 fd&cbleu#2 fd&cbluw#2 fd&cblie#2 fd&cbule#2 blu#2 bue#2 blie#2 bluw#2 bleu#2 indigotin indigotene indigocarmine indigocarmin bluelakes2 bluelakes1&2 bluelakes1and2 bluelakes2&1 bluelakes2and1 bluenos2 bluenos.2 bluefd&c#2 bluefd&c2 bluefd&cno.2 {
    addflag blue_2_flag blue_2_match `term' space ing_scan nohead
}

* ------------------- digit-noise in dye numbers -------------------
* BLUE 11, BLUE 12 LAKE, BLUE 21, BLUE 23, RED 30, RED 401/402, RED LAKE 340/403,
* YELLOW 50/56/61/65/511/586. No real food dye carries these numbers, so they
* are attributed to the underlying dye(s); fused pairs of two valid
* numbers (12, 21, 56, 65, 340, 403, 586) are attributed to BOTH dyes.
local G "[ ]*(no[.]?[ ]*|#[ ]*|lake[ ]*)*"

* RED keeps its left boundary (FLAVORED/COLORED protection)
replace red_3_flag = 1 if ustrregexm(ing_scan, "(?<![a-z])red`G'3[0-9](?![0-9])")
replace red_3_match = "red 3x (ocr digit)" if ustrregexm(ing_scan, "(?<![a-z])red`G'3[0-9](?![0-9])") & red_3_match == ""

replace red_40_flag = 1 if ustrregexm(ing_scan, "(?<![a-z])red`G'40[0-9](?![0-9])")
replace red_40_match = "red 40x (ocr digit)" if ustrregexm(ing_scan, "(?<![a-z])red`G'40[0-9](?![0-9])") & red_40_match == ""

* RED 340 / RED 403 = Red 3 + Red 40 fused
replace red_3_flag = 1 if ustrregexm(ing_scan, "(?<![a-z])red`G'(340|403)(?![0-9])")
replace red_3_match = "red 340/403 (ocr)" if ustrregexm(ing_scan, "(?<![a-z])red`G'(340|403)(?![0-9])") & red_3_match == ""
replace red_40_flag = 1 if ustrregexm(ing_scan, "(?<![a-z])red`G'340(?![0-9])")
replace red_40_match = "red 340 (ocr)" if ustrregexm(ing_scan, "(?<![a-z])red`G'340(?![0-9])") & red_40_match == ""

* YELLOW / BLUE have no left boundary (no label word ends in these color names)
replace yellow_5_flag = 1 if ustrregexm(ing_scan, "yellow`G'5[0-9]{1,2}(?![0-9])")
replace yellow_5_match = "yellow 5x (ocr digit)" if ustrregexm(ing_scan, "yellow`G'5[0-9]{1,2}(?![0-9])") & yellow_5_match == ""

replace yellow_6_flag = 1 if ustrregexm(ing_scan, "yellow`G'6[0-9]{1,2}(?![0-9])")
replace yellow_6_match = "yellow 6x (ocr digit)" if ustrregexm(ing_scan, "yellow`G'6[0-9]{1,2}(?![0-9])") & yellow_6_match == ""

* YELLOW 56 / 65 / 586 = Yellow 5 + Yellow 6 fused
replace yellow_5_flag = 1 if ustrregexm(ing_scan, "yellow`G'(65|586)(?![0-9])")
replace yellow_5_match = "yellow 65/586 (ocr)" if ustrregexm(ing_scan, "yellow`G'(65|586)(?![0-9])") & yellow_5_match == ""
replace yellow_6_flag = 1 if ustrregexm(ing_scan, "yellow`G'(56|586)(?![0-9])")
replace yellow_6_match = "yellow 56/586 (ocr)" if ustrregexm(ing_scan, "yellow`G'(56|586)(?![0-9])") & yellow_6_match == ""

replace blue_1_flag = 1 if ustrregexm(ing_scan, "blue`G'1[0-9](?![0-9])")
replace blue_1_match = "blue 1x (ocr digit)" if ustrregexm(ing_scan, "blue`G'1[0-9](?![0-9])") & blue_1_match == ""

replace blue_2_flag = 1 if ustrregexm(ing_scan, "blue`G'2[0-9](?![0-9])")
replace blue_2_match = "blue 2x (ocr digit)" if ustrregexm(ing_scan, "blue`G'2[0-9](?![0-9])") & blue_2_match == ""

* Comma/&-distributed dye number lists:
* FD&C YELLOW #6, #5 / BLUE#1,2 / RED#3, 40 -> the continuation numbers
* after the connector belong to the same color word. The (?![ ]*%) guard
* keeps "BLUE 1, 2% OR LESS OF..." from flagging Blue 2.
local P "(nos?[.]?[ ]*|#[ ]*|lakes?[ ]*|fd&c[ ]*)*"
local C "[ ]*(,|&|/|and|or)[ ]*"

replace red_3_flag = 1 if ustrregexm(ing_scan, "(?<![a-z])red[sv]?[ ]*`P'([0-9]{1,3}[ ]*`P'`C'`P')+3(?![0-9])(?![ ]*%)")
replace red_3_match = "red list ..., 3" if ustrregexm(ing_scan, "(?<![a-z])red[sv]?[ ]*`P'([0-9]{1,3}[ ]*`P'`C'`P')+3(?![0-9])(?![ ]*%)") & red_3_match == ""

replace red_40_flag = 1 if ustrregexm(ing_scan, "(?<![a-z])red[sv]?[ ]*`P'([0-9]{1,3}[ ]*`P'`C'`P')+40(?![0-9])(?![ ]*%)")
replace red_40_match = "red list ..., 40" if ustrregexm(ing_scan, "(?<![a-z])red[sv]?[ ]*`P'([0-9]{1,3}[ ]*`P'`C'`P')+40(?![0-9])(?![ ]*%)") & red_40_match == ""

replace yellow_5_flag = 1 if ustrregexm(ing_scan, "yellow[sv]?[ ]*`P'([0-9]{1,3}[ ]*`P'`C'`P')+5(?![0-9])(?![ ]*%)")
replace yellow_5_match = "yellow list ..., 5" if ustrregexm(ing_scan, "yellow[sv]?[ ]*`P'([0-9]{1,3}[ ]*`P'`C'`P')+5(?![0-9])(?![ ]*%)") & yellow_5_match == ""

replace yellow_6_flag = 1 if ustrregexm(ing_scan, "yellow[sv]?[ ]*`P'([0-9]{1,3}[ ]*`P'`C'`P')+6(?![0-9])(?![ ]*%)")
replace yellow_6_match = "yellow list ..., 6" if ustrregexm(ing_scan, "yellow[sv]?[ ]*`P'([0-9]{1,3}[ ]*`P'`C'`P')+6(?![0-9])(?![ ]*%)") & yellow_6_match == ""

replace blue_1_flag = 1 if ustrregexm(ing_scan, "blue[sv]?[ ]*`P'([0-9]{1,3}[ ]*`P'`C'`P')+1(?![0-9])(?![ ]*%)")
replace blue_1_match = "blue list ..., 1" if ustrregexm(ing_scan, "blue[sv]?[ ]*`P'([0-9]{1,3}[ ]*`P'`C'`P')+1(?![0-9])(?![ ]*%)") & blue_1_match == ""

replace blue_2_flag = 1 if ustrregexm(ing_scan, "blue[sv]?[ ]*`P'([0-9]{1,3}[ ]*`P'`C'`P')+2(?![0-9])(?![ ]*%)")
replace blue_2_match = "blue list ..., 2" if ustrregexm(ing_scan, "blue[sv]?[ ]*`P'([0-9]{1,3}[ ]*`P'`C'`P')+2(?![0-9])(?![ ]*%)") & blue_2_match == ""

replace green_3_flag = 1 if ustrregexm(ing_scan, "(?<![a-z])green[sv]?[ ]*`P'([0-9]{1,3}[ ]*`P'`C'`P')+3(?![0-9])(?![ ]*%)")
replace green_3_match = "green list ..., 3" if ustrregexm(ing_scan, "(?<![a-z])green[sv]?[ ]*`P'([0-9]{1,3}[ ]*`P'`C'`P')+3(?![0-9])(?![ ]*%)") & green_3_match == ""

* BLUE 12 / BLUE 21 = Blue 1 + Blue 2 fused
replace blue_1_flag = 1 if ustrregexm(ing_scan, "blue`G'21(?![0-9])")
replace blue_1_match = "blue 21 (ocr)" if ustrregexm(ing_scan, "blue`G'21(?![0-9])") & blue_1_match == ""
replace blue_2_flag = 1 if ustrregexm(ing_scan, "blue`G'12(?![0-9])")
replace blue_2_match = "blue 12 (ocr)" if ustrregexm(ing_scan, "blue`G'12(?![0-9])") & blue_2_match == ""

* ---------------------------------------- GLYCERIN ----------------------------------------------
gen byte  glycerin_flag  = 0
gen str20 glycerin_match = ""

* Temporary normalized text used only for glycerin detection
gen strL glycerin_scan = ustrregexra(ing_scan, "[^a-z0-9]+", " ")
replace glycerin_scan = ustrregexra(glycerin_scan, "[ ]+", " ")
replace glycerin_scan = ustrtrim(glycerin_scan)

local glycerin_base "(glycerol|glycerin|glycerine)"

****************************************************
* REMOVE FALSE-POSITIVE DERIVATIVE PHRASES
* Only the derivative span is removed, so "GLYCEROL MONOSTEARATE, GLYCEROL"
* remains positive via the second standalone GLYCEROL.
****************************************************

* 1. Polyglycerol compounds: E475/E476
replace glycerin_scan = ustrregexra(glycerin_scan, ///
    "(^| )(polyglycerol|poly glycerol|polyglycerin|poly glycerin|polyglycerine|poly glycerine) esters? of fatty acids?(?=[ ]|$)", " ")

replace glycerin_scan = ustrregexra(glycerin_scan, ///
    "(^| )(polyglycerol|poly glycerol|polyglycerin|poly glycerin|polyglycerine|poly glycerine) polyricinoleate(?=[ ]|$)", " ")

replace glycerin_scan = ustrregexra(glycerin_scan, ///
    "(^| )(polyglycerol|poly glycerol|polyglycerin|poly glycerin|polyglycerine|poly glycerine)(?=[ ]|$)", " ")

* 2. Glycerol-lacto derivatives
replace glycerin_scan = ustrregexra(glycerin_scan, ///
    "(^| )`glycerin_base' lacto sorbitan monostearate(?=[ ]|$)", " ")
replace glycerin_scan = ustrregexra(glycerin_scan, ///
    "(^| )`glycerin_base' lacto esters? of fatty (acid|acids|ester|esters)(?=[ ]|$)", " ")

* 3. Glycerol monostearate, monooleate and related derivatives
replace glycerin_scan = ustrregexra(glycerin_scan, ///
    "(^| )`glycerin_base' (monostearate|monosterate|monostrearate|monstrate|mono stearate|monooleate|monoleate|monogleate|mono oleate|monolaurate|mono laurate|monopalmitate|mono palmitate|monocaprylate|monocaprate|monobehenate|monoacetate|diacetate|triacetate|distearate|distrearate|dioleate|dipalmitate|dilaurate|tristearate|tripalmitate|trioleate|mono and distearate|mono and distrearate|mono and di stearate)(?=[ ]|$)", " ")

* Other named glycerol derivatives 
replace glycerin_scan = ustrregexra(glycerin_scan, ///
    "(^| )`glycerin_base' (stearate|oleate|palmitate|laurate|ricinoleate|polyricinoleate|abietate|behenate|caprylate|caprate|myristate|linoleate|phosphate)(?=[ ]|$)", " ")

* 4. Glycerol ester(s) of rosin/resin/wood rosin/gum rosin: E445 (incl. OCR variants)
replace glycerin_scan = ustrregexra(glycerin_scan, ///
    "(^| )`glycerin_base' esters? (of|or) ((wood|gum) )?(rosin|resin|roisin|rusin|rosih|roain|niacin)(?=[ ]|$)", " ")

replace glycerin_scan = ustrregexra(glycerin_scan, ///
    "(^| )`glycerin_base' easter (of|or) ((wood|gum) )?(rosin|resin|roisin|rusin|rosih|roain|niacin)(?=[ ]|$)", " ")

replace glycerin_scan = ustrregexra(glycerin_scan, ///
    "(^| )`glycerin_base' esters? (rosin|resin|roisin|rusin) of wood(?=[ ]|$)", " ")

replace glycerin_scan = ustrregexra(glycerin_scan, ///
    "(^| )`glycerin_base' esters? gum(?=[ ]|$)", " ")

replace glycerin_scan = ustrregexra(glycerin_scan, ///
    "(^| )`glycerin_base' esters? of gum (rosin|resin)(?=[ ]|$)", " ")

replace glycerin_scan = ustrregexra(glycerin_scan, ///
    "(^| )`glycerin_base' of (rosin|resin|roisin|rusin|rosih|roain)(?=[ ]|$)", " ")

* 5. Glycerol ester(s) of fatty acid(s)
replace glycerin_scan = ustrregexra(glycerin_scan, ///
    "(^| )`glycerin_base' esters? of fatty acids?(?=[ ]|$)", " ")

replace glycerin_scan = ustrregexra(glycerin_scan, ///
    "(^| )fatty acids? esters? of `glycerin_base'(?=[ ]|$)", " ")

* 6. DATEM and other compounds ending with "esters of glycerol"
replace glycerin_scan = ustrregexra(glycerin_scan, ///
    "(^| )esters? of `glycerin_base'(?=[ ]|$)", " ")

* 7. Unqualified glycerol ester(s) - run after the more specific patterns
replace glycerin_scan = ustrregexra(glycerin_scan, ///
    "(^| )`glycerin_base' esters?(?=[ ]|$)", " ")

* 8. Alpha-GPC
replace glycerin_scan = ustrregexra(glycerin_scan, ///
    "(^| )alpha glycerol phosphoryl choline(?=[ ]|$)", " ")

* 9. Esterified propoxylated glycerol
replace glycerin_scan = ustrregexra(glycerin_scan, ///
    "(^| )esterified propoxylated glycerol(?=[ ]|$)", " ")

* 10. Explanatory glycerol mention within a derivative description
replace glycerin_scan = ustrregexra(glycerin_scan, ///
    "(^| )made from glycerol and fatty acids?(?=[ ]|$)", " ")

* 11. Likely OCR error for propylene glycol
replace glycerin_scan = ustrregexra(glycerin_scan, ///
    "(^| )propylene glycerol(?=[ ]|$)", " ")

* 12. Glyceryl derivatives 
replace glycerin_scan = ustrregexra(glycerin_scan, ///
    "(^| )glyceryl (monostearate|monosterate|monostrearate|mono stearate|monooleate|monoleate|mono oleate|monolaurate|monopalmitate|monocaprylate|monocaprate|monobehenate|monoacetate|diacetate|triacetate|distearate|dioleate|dipalmitate|dilaurate|tristearate|tripalmitate|trioleate|stearate|oleate|palmitate|laurate|ricinoleate|abietate|behenate|caprylate|caprate|myristate|linoleate|phosphate)(?=[ ]|$)", " ")

* Clean spacing after derivative removal
replace glycerin_scan = ustrregexra(glycerin_scan, "[ ]+", " ")
replace glycerin_scan = ustrtrim(glycerin_scan)

* IDENTIFY TRUE STANDALONE GLYCERIN / GLYCERINE / GLYCEROL
replace glycerin_flag = 1 if ustrregexm(glycerin_scan, "(^| )glycerin( |$)")
replace glycerin_match = "glycerin" if ustrregexm(glycerin_scan, "(^| )glycerin( |$)") & glycerin_match == ""

replace glycerin_flag = 1 if ustrregexm(glycerin_scan, "(^| )glycerine( |$)")
replace glycerin_match = "glycerine" if ustrregexm(glycerin_scan, "(^| )glycerine( |$)") & glycerin_match == ""

replace glycerin_flag = 1 if ustrregexm(glycerin_scan, "(^| )glycerol( |$)")
replace glycerin_match = "glycerol" if ustrregexm(glycerin_scan, "(^| )glycerol( |$)") & glycerin_match == ""

* E422 / 422
ecodeflag glycerin_flag glycerin_match 422

* Remove temporary scanning variable
drop glycerin_scan

* CLEANUP AND SAVE
drop ingredients_lower
drop ing_scan
drop saccharin_fp_species

save ".../brandedfood_4.dta", replace
