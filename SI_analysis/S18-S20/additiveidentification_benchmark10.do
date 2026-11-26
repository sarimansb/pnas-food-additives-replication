********************************************************************************
* Paper:   Food additives in the U.S. food supply: Regulatory divergence,
*          market concentration, and exposure patterns
*
* Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
*          Vincenzina Caputo
*
* Code:    Sevval Buse Sariman
*
* Purpose: Identifies the 10 benchmark ingredients and additives in the
*          ingredient lists of the USDA Global Branded Food Products
*          Database (GBFPD).
*
*   Ingredient text is lowercased, and statements indicating the absence of
*   an ingredient (e.g., "no", "without", "free from") are removed before
*   identification. Ingredients are identified using predefined names,
*   alternative spellings, abbreviations, known misspellings, E-numbers where
*   applicable, and flexible punctuation/spacing patterns. Boundary and
*   exclusion rules reduce false-positive matches.
*
* Output:  brandedfood_6_wave2.dta, with for each ingredient:
*            <ingredient>_flag   1 if identified in the ingredient list, 0 if not
*            <ingredient>_match  the search term that triggered the match
********************************************************************************

clear all

local infile  ".../brandedfood_6.dta"
local outfile ".../brandedfood_6_wave2.dta"

********************************************************************************
* REVIEWED SEARCH TERMS
********************************************************************************

local citric_acid_terms ///
    acidocitrico citricacid cetricacid chiricacid cigricacid ///
    ciricacid cirticacid cirtricacid citicacid citircacid ///
    citiricacid citraicacid citrcacid citrciacid citricacd ///
    citricacdi citricaced citricaci citricaciid citricacio ///
    citricaciol citricacit citricacod citricadid citricaicd ///
    citricaoid citriccid citricscid citrictacid citriicacid ///
    citrioacid citrisacid citritacid citrticacid citrycacid ///
    cittricacid cotricacid criticacid crtricacid ctiricacid ///
    ctricacid cutricacid gitricacid

local riboflavin_terms ///
    lactoflavin riboflavin vitaminb2 biboflavin fiboflavin ///
    niboflavin rboflavin ribflavin ribiflavin riblofavin ///
    ribloflavin riboaflavin riboblavin ribofalvin riboffavin ///
    ribofiavin riboflabin riboflacvin riboflamin riboflaven ///
    riboflaviin riboflavim riboflavn riboflavoin riboflavon ///
    riboflayin riboflayini ribofllavin ribofloavin riboflovin ///
    riboflvain ribolfavin ribolflavin ribopflavin ribovlavin ///
    ribpflavin riobflavin rivboflavin rivoflavin roboflavin ///
    ryboflavin

local folic_acid_terms ///
    folate folicacid vitaminb9 vitaminm

local niacin_terms ///
    niacinamide nicotinamide nicotinicacid vitaminb3 ///
    niacinimide niacinamde niacinamie niacimamide niaciniamide ///
    niacinamid nicotinicacd nicotinicaci nicotinicicacid ///
    niacin

local corn_syrup_terms ///
    cornsyrup cornsyrupsolids driedcornsyrup consyrupsolids cornisyrupsolids ///
    cornsyrpsolids cornsyrusolids cornsyurpsolids corsyrupsolids corysyrupsolids ///
    driedcornsyrop

local lecithin_terms ///
    lecithin soyalacithin soyalecitin soyalecthin soyaleithin ///
    soybeanlecethin soyecithin soyiecithin soylacithin soylecethin ///
    soylechithi soylechithin soylechitin soylechthin soylecihin ///
    soylecihthin soylecithain soylecithan soylecithen soylecithiin ///
    soylecithim soylecithn soylecitian soylecitihin soylecitihn ///
    soylecitin soylecitthin soylecothin soylecthin soylectihin ///
    soylectthin soylegithin soyleicthin soyleithin soyleoithin ///
    soyletcithin soylicithin sunflowerecithin sunflowerlecethin sunflowerlechithin ///
    sunflowerlechitin sunflowerlechthin sunflowerlecithen sunflowerlecitin sunflowerlecthin ///
    sunflowerlectithin

local sodium_carbonate_terms ///
    sodaash sodiumcarbonate sodiumccarbonate

local thiamine_terms ///
    thiaminemononitrate thiaminmononitrate ///
    thiaminehydrochloride thiaminhydrochloride ///
    vitaminb1 ///
    shiaminemononitrate tahiminemononitrate thaiaminemononitrate ///
    thaiaminmononitrate thaiminemononitrate thaiminmononitrate ///
    thaminemononitrate thaminiemononitrate thaminmononitrate ///
    thiaiminemononitrate thiamhydrochloride thiamidemononitrate ///
    thiamnemononitrate thiamnmononitrate thiamonmononitrate ///
    thianinemononitrate thianinmononitrate thiavinmononitrate ///
    thimainmononitrate thiminemononitrate thiminmononitrate ///
    thitaminmononitrate thlaminemononitrate thlaminmononitrate ///
    tiaminemononitrate trhiaminemononitrate triaminemononitrate ///
    thiamine thiamin

local pyridoxine_hcl_terms ///
    pyridoxine pyridoxinehcl pyridoxinehydrochloride vitaminb6 piridoxine ///
    pryidoxinehydrocholride pyndoxinehydrochloride pyrdoxinehydrochloride pyrdoxinehydrocholride pyriddoxinehydrochloride ///
    pyridoxidehydrochloride pyridoxiehydrochloride pyridoxinhydrochloride pyridoxinshydrocholoride pyridoxnehydrochloride ///
    pyriodoxinehydrochloride pyriodxinehydrochloride pyrodoxinehydrochloride pyroidoxinehydrochloride pyroxidinehydrochloride

local canola_oil_terms ///
    canolaoil colzaoil rapeseedoil lowerucicacidrapesseedoil rapessedoil ///
    rapseedoil raspeseedoil


********************************************************************************
* HELPER 1: REVIEWED NAME MATCHING
********************************************************************************
* Builds a punctuation/spacing-flexible regex from a reviewed compact term.
* Commas and semicolons are NOT allowed inside the match so a term cannot be
* assembled across separate ingredient entries.
*
* The left boundary prevents a reviewed spelling from starting inside an
* unrelated word.
********************************************************************************

capture program drop w2_addflag
program define w2_addflag
    args flagvar matchvar term src

    if "`src'" == "" local src "ing_scan"

    local SEP "[^a-z0-9,;]*"

    local t = subinstr(`"`term'"', "\", "", .)
    local n = ustrlen(`"`t'"')
    local rx ""

    forvalues i = 1/`n' {
        local c = usubstr(`"`t'"', `i', 1)

        if `"`c'"' == "." local c "[^a-z0-9 ]?"
        else if inlist(`"`c'"', "(", ")", "[", "]", "*", "+", "?", "|", "^") ///
            local c = "\" + `"`c'"'
        else if inlist(`"`c'"', "{", "}") ///
            local c = "\" + `"`c'"'

        local rx `"`rx'`c'"'

        if `i' < `n' local rx `"`rx'`SEP'"'
    }

    local first = usubstr(`"`t'"', 1, 1)

    if ustrregexm(`"`first'"', "[0-9]") ///
        local head "(?<![0-9a-z])"
    else ///
        local head "(?<![a-z])"

    local last = usubstr(`"`t'"', `n', 1)

    if ustrregexm(`"`last'"', "[0-9]") ///
        local tail "(?![0-9])"
    else ///
        local tail ""

    tempvar h
    quietly gen byte `h' = ustrregexm(`src', `"`head'`rx'`tail'"')

    quietly replace `flagvar' = 1 if `h'
    quietly replace `matchvar' = `"`term'"' if `h' & `matchvar' == ""
end


********************************************************************************
* HELPER 2: REVIEWED SAFE NUMERIC E-CODE MATCHING
********************************************************************************
* The code excludes common measurement/dose/count/product-number contexts.
*********************************************************************************

capture program drop w2_ecodeflag
program define w2_ecodeflag
    args flagvar matchvar num

    local U "(mg|mgs|g|gr|grams?|mcg|ug|µg|kg|ml|l|liters?|litres?|oz|lb|lbs|ppm|ppb|iu|cfu|mesh|kcal|cal|calories?|ct|count|servings?|pieces?|mm|cm|bloom|%)"

    * Explicit E-code: E330, E 330, E-330, etc.
    tempvar h1
    quietly gen byte `h1' = ///
        ustrregexm(ing_scan, "(^|[^0-9a-z])e[ ]*-?[ ]*`num'([^0-9a-z]|$)") & ///
        !ustrregexm(ing_scan, "(^|[^0-9a-z])e[ ]*-?[ ]*`num'[ ]*[+/-]?[ ]*`U'([^a-z]|$)") & ///
        !ustrregexm(ing_scan, "(^|[^0-9a-z])e[ ]*-?[ ]*`num'[.][0-9]") & ///
        !ustrregexm(ing_scan, "vitamin[ ]+e[ ]*-?[ ]*`num'")

    quietly replace `flagvar' = 1 if `h1'
    quietly replace `matchvar' = "e`num'" if `h1' & `matchvar' == ""

    * Plain standalone code: 330 / 322.
    * The left side cannot be a digit, letter, period, or hyphen.
    * The right side cannot immediately continue as another digit/letter.
    tempvar h2
    quietly gen byte `h2' = ///
        ustrregexm(ing_scan, "(?<![0-9a-z.-])`num'(?![0-9a-z])(?![.][0-9])") & ///
        !ustrregexm(ing_scan, "(?<![0-9a-z.-])`num'[ ]*[+/-]?[ ]*`U'([^a-z]|$)") & ///
        !ustrregexm(ing_scan, "`num'[ ]*(million|billion|thousand)") & ///
        !ustrregexm(ing_scan, "`num'[ ]*(th|st|nd|rd)([^a-z]|$)") & ///
        !ustrregexm(ing_scan, "tds[ ]*:[ ]*`num'") & ///
        !ustrregexm(ing_scan, "(saladizer|bloom|emulpals)[ ]+`num'") & ///
        !ustrregexm(ing_scan, "(lot|lotr|batch|code|item|ref|sku|no|number)[ ]*[.:#]?[ ]*`num'") & ///
        !ustrregexm(ing_scan, "`num'[ ]*(of|/)[ ]*[0-9]") & ///
        !ustrregexm(ing_scan, "less[ ]+than[ ]+`num'[ ]*of") & ///
        !ustrregexm(ing_scan, "corn[ ]+meal[ ]*#?[ ]*`num'")

    quietly replace `flagvar' = 1 if `h2'
    quietly replace `matchvar' = "`num'" if `h2' & `matchvar' == ""
end

********************************************************************************
* LOAD USDA BRANDED FOOD FILE
********************************************************************************

capture confirm file "`infile'"
if _rc {
    display as error "FILE NOT FOUND: `infile'"
    exit 601
}

use "`infile'", clear

* Drop any existing flag variables so the file can be rerun.
	capture drop ///
    citric_acid_flag citric_acid_match ///
    riboflavin_flag riboflavin_match ///
    folic_acid_flag folic_acid_match ///
    niacin_flag niacin_match ///
    corn_syrup_flag corn_syrup_match ///
    lecithin_flag lecithin_match ///
    sodium_carbonate_flag sodium_carbonate_match ///
    thiamine_flag thiamine_match ///
    pyridoxine_hcl_flag pyridoxine_hcl_match ///
    canola_oil_flag canola_oil_match

gen strL ingredients_lower = ustrlower(ingredients)
replace ingredients_lower = subinstr(ingredients_lower, uchar(160), " ", .)

gen strL ing_scan = ingredients_lower

        ************************************************************************
        * REMOVE NEGATED PRESENCE CLAIMS
        ************************************************************************
        * Remove explicit claims such as "no corn syrup", "without canola oil" 
		* etc., before positive matching.
        ************************************************************************

        local NEGNAME "(citric[ ,._-]*acid|riboflavin|folic[ ,._-]*acid|folate|niacin|niacinamide|nicotinamide|nicotinic[ ,._-]*acid|vitamin[ ,._-]*b3|corn[ ,._-]*syrup|lecithin|sodium[ ,._-]*carbonate|soda[ ,._-]*ash|thiamin(e)?|vitamin[ ,._-]*b1|pyridoxine([ ,._-]*hydrochloride|[ ,._-]*hcl)?|vitamin[ ,._-]*b6|canola[ ,._-]*oil|rapeseed[ ,._-]*oil|colza[ ,._-]*oil)"
        local NEGTRG "(contains[ ]+no|does[ ]*n[o']*t[ ]+contain|w/[ ]*no|no[ ]+added|without|free[ ]+(of|from)|no)"
        local NEGSTRONG "([ ]*(/|&|and|or|no)[ ]+)"
        local NEGWEAK "([ ]*[,;][ ]*(no[ ]+)?)"

        replace ing_scan = ustrregexra( ///
            ing_scan, ///
            "(^|[^a-z])`NEGTRG'[ :-]+`NEGNAME'((`NEGSTRONG'`NEGNAME')|(`NEGWEAK'`NEGNAME'))*([ ]+added)?", ///
            " " ///
        )

        replace ing_scan = ustrregexra( ///
            ing_scan, ///
            "(^|[^a-z])`NEGNAME'[ -]*free", ///
            " " ///
        )


        ************************************************************************
        * ADDITIVE-SPECIFIC WORKING COPIES FOR KNOWN FALSE POSITIVES
        ************************************************************************

        * Citric acid: remove citric acid esters (the left boundary in
		* w2_addflag already keeps "cetric acid" from matching inside
		* "acetric acid").
        gen strL citric_scan = ing_scan
        replace citric_scan = ustrregexra( ///
            citric_scan, ///
            "citric[^a-z0-9,;]*acid[^a-z0-9,;]*esters?", ///
            " " ///
        )

        * Niacin excluded compounds.
        gen strL niacin_scan = ing_scan

		replace niacin_scan = ustrregexra( ///
			niacin_scan, ///
			"niacinamide[ ,._-]*ascorbate", ///
			" " ///
		)

		replace niacin_scan = ustrregexra( ///
			niacin_scan, ///
			"nicotinamide[ ,._-]*riboside", ///
			" " ///
		)

		replace niacin_scan = ustrregexra( ///
			niacin_scan, ///
			"nicotinamide[ ,._-]*mononucleotide", ///
			" " ///
		)

		replace niacin_scan = ustrregexra( ///
			niacin_scan, ///
			"inositol[ ,._-]*hexanicotinate", ///
			" " ///
		)

        * Corn syrup: remove HFCS/fructose-corn-syrup spans first so the
        * shorter reviewed term "corn syrup" cannot fire inside them.
        * "high frugtose/fructrose ..." misspellings are also removed by
        * the high-fru[a-z]* rule.
        gen strL corn_scan = ing_scan

        replace corn_scan = ustrregexra( ///
            corn_scan, ///
            "high[ ,._-]*fru[a-z]*[ ,._-]*corn[ ,._-]*syrup", ///
            " " ///
        )

        replace corn_scan = ustrregexra( ///
            corn_scan, ///
            "fructose[ ,._-]*corn[ ,._-]*syrup", ///
            " " ///
        )

        replace corn_scan = ustrregexra(corn_scan, "(^|[^a-z])hfcs([^a-z]|$)", " ")

        * Thiaminase contains "thiamin" but is not thiamine.
        gen strL thiamine_scan = ing_scan
        replace thiamine_scan = ustrregexra( ///
            thiamine_scan, ///
            "(^|[^a-z])thiaminase([^a-z]|$)", ///
            " " ///
        )

        * Canola/rapeseed: remove hydrogenated forms before searching.
        * Bare canola/rapeseed are never used as unrestricted search terms.
        gen strL canola_scan = ing_scan

        replace canola_scan = ustrregexra( ///
            canola_scan, ///
            "(^|[^a-z])((partially|fully)[^a-z0-9,;]*)?hydrogenated[^a-z0-9,;]*(canola|rapeseed|rapseed|rapseseed|raspeseed)[^a-z0-9,;]*oil", ///
            " " ///
        )


        ************************************************************************
        * CITRIC ACID
        ************************************************************************

        gen byte citric_acid_flag = 0
        gen str80 citric_acid_match = ""

        foreach term of local citric_acid_terms {
            w2_addflag citric_acid_flag citric_acid_match `term' citric_scan
        }

        * 330 / E330
        w2_ecodeflag citric_acid_flag citric_acid_match 330

        * INS330 
        replace citric_acid_flag = 1 if ///
            ustrregexm(ing_scan, "(^|[^0-9a-z])ins[ ]*-?[ ]*330([^0-9a-z]|$)")

        replace citric_acid_match = "ins330" if ///
            ustrregexm(ing_scan, "(^|[^0-9a-z])ins[ ]*-?[ ]*330([^0-9a-z]|$)") & ///
            citric_acid_match == ""


        ************************************************************************
        * RIBOFLAVIN
        ************************************************************************

        gen byte riboflavin_flag = 0
        gen str80 riboflavin_match = ""

        foreach term of local riboflavin_terms {
            w2_addflag riboflavin_flag riboflavin_match `term' ing_scan
        }

        * E101 
        replace riboflavin_flag = 1 if ///
            ustrregexm(ing_scan, "(^|[^0-9a-z])e[ ]*-?[ ]*101([^0-9a-z]|$)")

        replace riboflavin_match = "e101" if ///
            ustrregexm(ing_scan, "(^|[^0-9a-z])e[ ]*-?[ ]*101([^0-9a-z]|$)") & ///
            riboflavin_match == ""

        * The sole reviewed true form is standalone 101 inside a color/colour declaration.
        replace riboflavin_flag = 1 if ///
            ustrregexm( ///
                ing_scan, ///
                "colou?r(ing|s)?[^.;]{0,80}(?<![0-9a-z.-])101(?![0-9a-z-])" ///
            )

        replace riboflavin_match = "101 (colour context)" if ///
            ustrregexm( ///
                ing_scan, ///
                "colou?r(ing|s)?[^.;]{0,80}(?<![0-9a-z.-])101(?![0-9a-z-])" ///
            ) & riboflavin_match == ""


        ************************************************************************
        * FOLIC ACID
        ************************************************************************

        gen byte folic_acid_flag = 0
        gen str80 folic_acid_match = ""

        foreach term of local folic_acid_terms {
            w2_addflag folic_acid_flag folic_acid_match `term' ing_scan
        }


        ************************************************************************
        * NIACIN
        ************************************************************************

        gen byte niacin_flag = 0
        gen str80 niacin_match = ""

        foreach term of local niacin_terms {
            w2_addflag niacin_flag niacin_match `term' niacin_scan
        }


        ************************************************************************
        * CORN SYRUP
        ************************************************************************

        gen byte corn_syrup_flag = 0
        gen str80 corn_syrup_match = ""

        foreach term of local corn_syrup_terms {
            w2_addflag corn_syrup_flag corn_syrup_match `term' corn_scan
        }


        ************************************************************************
        * LECITHIN
        ************************************************************************

        gen byte lecithin_flag = 0
        gen str80 lecithin_match = ""

        foreach term of local lecithin_terms {
            w2_addflag lecithin_flag lecithin_match `term' ing_scan
        }

        * Reviewed E-number result: 322/E322 were all correct.
        w2_ecodeflag lecithin_flag lecithin_match 322


        ************************************************************************
        * SODIUM CARBONATE
        ************************************************************************

        gen byte sodium_carbonate_flag = 0
        gen str80 sodium_carbonate_match = ""

        foreach term of local sodium_carbonate_terms {
            w2_addflag sodium_carbonate_flag sodium_carbonate_match `term' ing_scan
        }


        * Accept only explicit subtype 500(i):
        *   500(i)
        *   E500(i), E-500(i), E500i
        *   INS500(i), INS-500(i), INS500i
        tempvar h500i
        gen byte `h500i' = ustrregexm( ///
            ing_scan, ///
            "(^|[^0-9a-z])((e|ins)[ ]*-?[ ]*500[ ]*([(][ ]*i[ ]*[)]|i)|500[ ]*[(][ ]*i[ ]*[)])([^0-9a-z]|$)" ///
        )

        replace sodium_carbonate_flag = 1 if `h500i'
        replace sodium_carbonate_match = "500(i)" if ///
            `h500i' & sodium_carbonate_match == ""


        ************************************************************************
        * THIAMINE
        ************************************************************************

        gen byte thiamine_flag = 0
        gen str80 thiamine_match = ""

        foreach term of local thiamine_terms {
            w2_addflag thiamine_flag thiamine_match `term' thiamine_scan
        }


        ************************************************************************
        * PYRIDOXINE HYDROCHLORIDE / VITAMIN B6
        ************************************************************************

        gen byte pyridoxine_hcl_flag = 0
        gen str80 pyridoxine_hcl_match = ""

        foreach term of local pyridoxine_hcl_terms {
            w2_addflag pyridoxine_hcl_flag pyridoxine_hcl_match `term' ing_scan
        }


        ************************************************************************
        * CANOLA / RAPESEED OIL
        ************************************************************************

        gen byte canola_oil_flag = 0
        gen str80 canola_oil_match = ""

        * Oil names and spelling variants
        foreach term of local canola_oil_terms {
            w2_addflag canola_oil_flag canola_oil_match `term' canola_scan
        }

        * Bare "canola" and "rapeseed" are not searched by themselves.
        * They are accepted only in an explicit mixed-oil construction such as:
        *   canola or sunflower oil
        *   canola and/or soybean oil
        *   canola, sunflower and soybean oils
        *
        * Requiring the second term to be a known oil source prevents phrases
        * such as "canola mayonnaise" from being classified as canola oil.
        local OILSEED "(sunflower|soybean|soy|safflower|corn|vegetable|rapeseed|canola|cottonseed|palm|palm[ ]+kernel|olive|avocado|coconut|peanut|rice[ ]*bran|grapeseed|sesame)"
        local OILCONN "([ ]*(,([ ]*(and|or))?|/|&|and([ ]*/[ ]*or)?|or)[ ]*)"

        tempvar h_canola_blend h_rapeseed_blend

        gen byte `h_canola_blend' = ustrregexm( ///
            canola_scan, ///
            "(^|[^a-z])canola`OILCONN'`OILSEED'(`OILCONN'`OILSEED')*[ ]+oils?([^a-z]|$)" ///
        )

        gen byte `h_rapeseed_blend' = ustrregexm( ///
            canola_scan, ///
            "(^|[^a-z])rapeseed`OILCONN'`OILSEED'(`OILCONN'`OILSEED')*[ ]+oils?([^a-z]|$)" ///
        )

        replace canola_oil_flag = 1 if `h_canola_blend' | `h_rapeseed_blend'

        replace canola_oil_match = "canola/rapeseed oil context" if ///
            (`h_canola_blend' | `h_rapeseed_blend') & ///
            canola_oil_match == ""

		* Canola/rapeseed appearing INSIDE an oil declaration rather than
        * leading it: "vegetable oil (palm, sunflower, canola)", "canola,
        * soybean and/or sunflower oil". Still requires the word "oil", so
        * "canola mayonnaise" is not matched. 
        tempvar h_canola_inlist
        gen byte `h_canola_inlist' = ///
            ustrregexm(canola_scan, ///
                "oils?[^.;:()\[\]]{0,15}[\(\[][^\)\]]{0,60}(?<![a-z])(canola|rapeseed|rapseed|colza)(?![a-z])") | ///
            ustrregexm(canola_scan, ///
                "(?<![a-z])(canola|rapeseed|rapseed|colza)(?![a-z])[^.;:]{0,40}oils?([^a-z]|$)")
        replace canola_oil_flag = 1 if `h_canola_inlist'
        replace canola_oil_match = "canola/rapeseed oil context" if ///
            `h_canola_inlist' & canola_oil_match == ""


********************************************************************************
* LABELS, AND SAVE
********************************************************************************

label variable citric_acid_flag       "Contains citric acid"
label variable riboflavin_flag        "Contains riboflavin"
label variable folic_acid_flag        "Contains folic acid"
label variable niacin_flag   "Contains niacin/vitamin B3"
label variable thiamine_flag "Contains thiamine/vitamin B1"
label variable corn_syrup_flag        "Contains corn syrup"
label variable lecithin_flag          "Contains lecithin"
label variable sodium_carbonate_flag  "Contains sodium carbonate"
label variable pyridoxine_hcl_flag    "Contains pyridoxine/B6"
label variable canola_oil_flag        "Contains canola/rapeseed oil"

capture drop ///
    ingredients_lower ing_scan citric_scan niacin_scan corn_scan ///
    thiamine_scan canola_scan ///
    `h500i' `h_canola_blend' `h_rapeseed_blend' `h_canola_inlist'

compress
save "`outfile'", replace
