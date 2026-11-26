# ==============================================================================
# Paper:   Food additives in the U.S. food supply: Regulatory divergence,
#          market concentration, and exposure patterns
#
# Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
#          Vincenzina Caputo
#
# Code:    Sevval Buse Sariman
#
# Purpose: Identifies products containing each additive by matching
#          additive keywords against product ingredient text, using exact
#          matching first and fuzzy matching as a fallback.
# ==============================================================================

# ==============================================================================
# ADDITIVE MATCHING PROCEDURE (KEYWORD AND FUZZY MATCHING)
#
#   1. Convert the ingredient text to lowercase.
#   2. Search for the additive's keywords in order, using literal substring
#      matching.
#   3. If a keyword is found, record the matched substring and the keyword
#      that produced it.
#   4. If no keyword is found, use RapidFuzz process.extractOne with
#      fuzz.partial_ratio to identify the best-matching keyword.
#   5. If the best fuzzy score is at least 90, search the ingredient text for
#      a word with a fuzzy score of at least 90 against that keyword. If one
#      is found, record the matched substring and the keyword that produced it.
#   6. Save only the matched products for each additive.
# ==============================================================================
import re
from pathlib import Path

import pandas as pd
from rapidfuzz import fuzz, process


# PATHS AND PARAMETERS

STATA_PATH = Path(
    ".../brandedfood_3.dta"
)

OUTPUT_DIR = Path(
    ".../fuzzy_match"
)

COL_NAME = "clean_ingredients"     # cleaned ingredient list (ingredientcount_3.do)
MATCH_COL = "_s_cleaned_ingredients"
THRESHOLD = 90
CHUNKSIZE = 50000

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# =============================================================================
# ADDITIVE-SPECIFIC KEYWORD LISTS
# =============================================================================

ADDITIVES = {'red3': {'label': 'RED 3',
          'keywords': ['red3',
                       'red#3',
                       'redno.3',
                       'redno3',
                       'fd&credno.3',
                       'fd&cred3',
                       'fd&credno3',
                       'fd&credno#3',
                       'fd&cred#3',
                       'erythrosine',
                       'fd&credno40&3',
                       'red3&40',
                       'redno3&40',
                       'red40&3',
                       'redno40&3',
                       'redno40and3',
                       'red#3&40',
                       'red#3&#40',
                       'red#40&3',
                       'red#40&#3',
                       'foodred14',
                       'ci45430'],
          'output': 'brandedfood_additives_red3_only.csv'},
 'ada': {'label': 'AZODICARBAMIDE',
         'keywords': ['azodicarbonamide', 'azodicarboxamide', 'diazenedicarboxamide', 'improvere927'],
         'output': 'brandedfood_additives_ada3_only.csv'},
 'potassium_bromate': {'label': 'POTASSIUM BROMATE',
                       'keywords': ['potassiumbromate', 'potassium bromate', 'bromicacid', 'bromic acid'],
                       'output': 'brandedfood_additives_potassiumbromate_bromicacid.csv'},
 'green3': {'label': 'GREEN 3',
            'keywords': ['green3',
                         'green#3',
                         'greenno#3',
                         'greenno3',
                         'greenno.3',
                         'fastgreenfcf',
                         'fd&cgreenno.3',
                         'fd&cgreenno3',
                         'fd&cgreenno#3',
                         'fd&cgreen#3',
                         'fd&cgreen3',
                         'foodgreen3',
                         'd&cgreenno.3',
                         'd&cgreenno3',
                         'd&cgreenno#3',
                         'd&cgreen3',
                         'd&cgreen#3',
                         'ci42053',
                         'benzenemethanaminium'],
            'output': 'brandedfood_additives_green3_only.csv'},
 'titanium_dioxide': {'label': 'TITANIUM DIOXIDE',
                      'keywords': ['titaniumdioxide',
                                   'titaniumperoxide',
                                   'titaniumoxide',
                                   'titaniumivoxide',
                                   'cipigmentwhite6',
                                   'pigmentwhite6',
                                   'ci77891'],
                      'output': 'brandedfood_additives_titaniumdioxide_only.csv'},
 'propylparaben': {'label': 'PROPYLPARABEN',
                   'keywords': ['propylparaben',
                                'propylparahydroxybenzoate',
                                'propyl4hydroxybenzoate',
                                'propyl4-hydroxybenzoate',
                                '4-hydroxybenzoicacidn-propylester',
                                '4hydroxybenzoicacidnpropylester',
                                'propylp-hydroxybenzoate'],
                   'output': 'brandedfood_additives_propylparaben_only.csv'},
 'bvo': {'label': 'BVO',
         'keywords': ['brominatedvegetableoil',
                      'bvo',
                      'brominatedsoybeanoil',
                      'brominatedpalmoil',
                      'brominatedcottonseedoil',
                      'brominatedcanolaoil',
                      'brominatedoil',
                      'brominatedsoy',
                      'brominatedpalm',
                      'brominatedcottonseed',
                      'brominatedcanola',
                      'brominatedcorn',
                      'brominatedsunflower',
                      'brominatedrapeseed'],
         'output': 'brandedfood_additives_bvo_only.csv'},
 'olestra': {'label': 'OLEAN',
             'keywords': ['olestra', 'olean'],
             'output': 'brandedfood_additives_olestra_only.csv'},
 'aspartame': {'label': 'ASPARTAME',
               'keywords': ['aspartame',
                            'phenylalaninesource',
                            'artificialsweetener(aspartame)',
                            'containsphenylalanine',
                            'methylaspartylphenylalanate',
                            'methyl-l-alpha-aspartyl-l-phenylalanate',
                            'methyl-l-aspartyl-l-phenylalanine',
                            'aspartame,l,l-alpha-',
                            '1-methyl-n-l-alpha-aspartyl-l-phenylalanine',
                            'l-phenylalanine,n-l-alpha-aspartyl-,1-methylester',
                            '1-methyl-n-l-alpha-aspartyl-lphenylalanate',
                            'asp-phe-ome'],
               'output': 'brandedfood_additives_aspartame_only.csv'},
 'saccharin': {'label': 'SACCHARIN',
               'keywords': ['saccharin',
                            'sodiumsaccharin',
                            'benzoicacidsulfimide',
                            'benzosulfimide',
                            'benzoicsulfimide',
                            'saccharimide',
                            'anhydro-o-sulfamoylbenzoicacid',
                            'sulfobenzimide'],
               'output': 'brandedfood_additives_saccharin_only.csv'},
 'sucralose': {'label': 'SUCRALOSE',
               'keywords': ['trichlorogalactosucrose', 'sucralose'],
               'output': 'brandedfood_additives_sucralose_only.csv'},
 'acesulfame_potassium': {'label': 'ACESULFAME POTASSIUM',
                          'keywords': ['acesulfamepotassium',
                                       'acesulfamek',
                                       'ace-k',
                                       'acesulfame-k',
                                       'acek',
                                       'potassiumacesulfame',
                                       'acesulfam-k'],
                          'output': 'brandedfood_additives_acesulfamepotassium_only.csv'},
 'carrageenan': {'label': 'CARRAGEENAN',
                 'keywords': ['carrageenan',
                              'carrageenin',
                              'chondrusextract',
                              'irishmossextract',
                              'carragheengum',
                              'irishmossgelose'],
                 'output': 'brandedfood_additives_carrageenan_only.csv'},
 'red40': {'label': 'RED 40',
           'keywords': ['red40',
                        'red#40',
                        'redno.40',
                        'redno40',
                        'fd&credno.40',
                        'fd&credno40',
                        'fd&credno#40',
                        'alluraredac',
                        'allurared',
                        'fd&credno40&3',
                        'red3&40',
                        'redno3&40',
                        'red40&3',
                        'redno40&3',
                        'redno40and3',
                        'red#3&40',
                        'red#3&#40',
                        'ci16035',
                        'cidoofred17',
                        'foodred17',
                        'd&credno.40',
                        'd&credno#40',
                        'd&credno40',
                        'd&cred#40',
                        'd&cred40'],
           'output': 'brandedfood_additives_red40_only.csv'},
 'yellow5': {'label': 'YELLOW 5',
             'keywords': ['yellow5',
                          'yellow#5',
                          'yellowno.5',
                          'yellowno5',
                          'fd&cyellowno.5',
                          'fd&cyellowno5',
                          'yellow5&6',
                          'yellowno5&6',
                          'yellowno6&5',
                          'yellowno6and5',
                          'tartrazine',
                          'tartrazinelake',
                          'ciacidyellow23',
                          'acidyellow23',
                          'yellowlake69',
                          'd&cyellowno5',
                          'd&cyellowno.5',
                          'd&cyellowno#5',
                          'd&cyellow5',
                          'd&cyellow#5',
                          'yellow#5&6',
                          'yellow#5#6',
                          'ci19140',
                          'cifoodyellow4',
                          'foodyellowno.4',
                          'foodyellow4',
                          'foodyellowno4',
                          'foodyellowno#4'],
             'output': 'brandedfood_additives_yellow5_only.csv'},
 'nitrite_nitrate': {'label': 'NITRATES AND NITRITES',
                     'keywords': ['sodiumnitrite',
                                  'sodiumnitrate',
                                  'potassiumnitrite',
                                  'potassiumnitrate',
                                  'nitrousacid'],
                     'output': 'brandedfood_additives_nitrite_nitrate_only.csv'},
 'sulfites': {'label': 'SULFITES',
              'keywords': ['sulfites', 'sulphites', 'sulphurdioxide', 'sulfurdioxide'],
              'output': 'brandedfood_additives_sulfites_only.csv'},
 'phvo': {'label': 'PHVO',
          'keywords': ['partiallyhydrogenatedoil',
                       'partiallyhydrogenatedvegetableoil',
                       'partiallyhydrogenatedsoybeanoil',
                       'partiallyhydrogenatedpalmoil',
                       'partiallyhydrogenatedcottonseedoil',
                       'partiallyhydrogenatedcornoil',
                       'partiallyhydrogenatedcanolaoil',
                       'partiallyhydrogenatedvegetable',
                       'partiallyhydrogenatedsoybean',
                       'partiallyhydrogenatedpalm',
                       'partiallyhydrogenatedcottonseed',
                       'partiallyhydrogenatedcorn',
                       'partiallyhydrogenatedcanola',
                       'partiallyhydrogenatedcoconutoil',
                       'partiallyhydrogenatedrapeseedoil',
                       'partiallyhydrogenatedsunfloweroil',
                       'partiallyhydrogenatedlard',
                       'partiallyhydrogenatedtallow',
                       'partiallyhydrogenatedflaxseedoil'],
          'output': 'brandedfood_additives_partiallyhydrogenated_only.csv'},
 'potassium_iodate': {'label': 'POTASSIUM IODATE',
                      'keywords': ['potassiumiodate', 'kio3'],
                      'output': 'brandedfood_additives_potassiumiodate_only.csv'},
 'caramel_color': {'label': 'CARAMEL COLOR',
                   'keywords': ['caramelcolor',
                                'caramelcoloring',
                                'cinaturalbrown10',
                                'naturalbrown10',
                                'caramel(color)'],
                   'output': 'brandedfood_additives_caramelcolor_only.csv'},
 'bha': {'label': 'BHA',
         'keywords': ['butylatedhydroxyanisole',
                      'antioxidant(bha)',
                      'preservative(bha)',
                      'butylmethoxyphenol',
                      'butyl-4-methoxyphenol,tert-',
                      'butylhydroxyanisole,tert-',
                      'butyl-4-hydroxyanisole,tert-',
                      'phenol,(1,1-dimethylethyl)-4-methoxy-',
                      'phenol,tert-butyl-4-methoxy-',
                      '(1,1-dimethylethyl)-4-methoxyphenol',
                      'tert-butyl-4-hydroxyanisole',
                      'tert-butyl-4-methoxyphenol',
                      'tert-butylhydroxyanisole'],
         'output': 'brandedfood_additives_bha_only.csv'},
 'bht': {'label': 'BHT',
         'keywords': ['butylatedhydroxytoluene',
                      'antioxidant(bht)',
                      'preservative(bht)',
                      '3,5-di-tert-butyl-4-hydroxytoluene',
                      'ditertiarybutylparacresol',
                      '2,6-di-tert-butyl-4-methylphenol',
                      '2,6-di-tert-butyl-p-cresol',
                      'p-cresol,2,6-di-tert-butyl-',
                      'phenol,2,6-bis(1,1-dimethylethyl)-4-methyl-',
                      '2,6-bis(1,1-dimethylethyl)-4-methylphenol'],
         'output': 'brandedfood_additives_bht_only.csv'},
 'propyl_gallate': {'label': 'PROPYL GALLATE',
                    'keywords': ['propylgallate',
                                 'propyl3,4,5-trihydroxybenzoate',
                                 'propyl-gallate',
                                 'antioxidant(propylgallate)',
                                 'gallicacid,propylester'],
                    'output': 'brandedfood_additives_propylgallate_only.csv'},
 'tbhq': {'label': 'TBHQ',
          'keywords': ['tbhq',
                       'tert-butylhydroquinone',
                       'tertbutylhydroquinone',
                       'butylhydroquinone,tert-hydroquinone,tert-butyl-',
                       'mono-tert-butylhydroquinone',
                       '2-(1,1-dimethylethyl)-1,4-benzenedio',
                       '1,4-benzenediol,2-(1,1-dimethylethyl)-',
                       '2-tert-butyl-1,4-benzenediol',
                       '2-tert-butylhydroquinone'],
          'output': 'brandedfood_additives_tbhq_only.csv'},
 'benzoates': {'label': 'BENZOATES',
               'keywords': ['sodiumbenzoate',
                            'potassiumbenzoate',
                            'preservative(sodiumbenzoate)',
                            'preservative(potassiumbenzoate)'],
               'output': 'brandedfood_additives_benzoates_only.csv'},
 'msg': {'label': 'MSG',
         'keywords': ['monosodiumglutamate',
                      'monosodiuml-glutamate',
                      'glumatedesodium',
                      'msg',
                      'l-glutamicacidmonosodiumsalt',
                      'glutamicacidmonosodiumsaltl',
                      'glutamicacidl-sodiumsalt',
                      'sodiuml-glutamate',
                      'monosodiumglutamatel'],
         'output': 'brandedfood_additives_msg_only.csv'},
 'propylene_glycol': {'label': 'PROPYLENE GLYCOL',
                      'keywords': ['propyleneglycol',
                                   '1,2-propanediol',
                                   '1,2-propyleneglycol',
                                   '1,2-dihydroxypropane',
                                   '2-hydroxypropanol',
                                   'propane-1,2-diol',
                                   'isopropyleneglycol',
                                   'alpha-propyleneglycol',
                                   'methylethyleneglycol'],
                      'output': 'brandedfood_additives_propyleneglycol_only.csv'},
 'hfcs': {'label': 'HFCS',
          'keywords': ['highfructosecornsyrup',
                       'hfcs',
                       'cornsyrup(withhighfructose)',
                       'glucose-fructosesyrup',
                       'isoglucose',
                       'glucosefructosesyrup'],
          'output': 'brandedfood_additives_hfcs_only.csv'},
 'yellow6': {'label': 'YELLOW 6',
             'keywords': ['yellow6',
                          'yellowno.6',
                          'yellowno6',
                          'yellow#6',
                          'yellow5and6',
                          'yellow5&6',
                          'yellow#5&6',
                          'yellow#5#6',
                          'sunsetyellow',
                          'orangeyellows',
                          'fd&cyellowno.6',
                          'fd&cyellowno6',
                          'fd&cyellowno#6',
                          'fd&cyellow6',
                          'fd&cyellow#6',
                          'yellowno5&6',
                          'yellowno6&5',
                          'yellowno6and5',
                          'solarradiationcolor',
                          'cifoodyellow3',
                          'd&cyellowno6',
                          'd&cyellowno#6',
                          'd&cyellowno.6',
                          'd&cyellow6',
                          'd&cyellow#6',
                          'ci15985',
                          'foodyellowno.5'],
             'output': 'brandedfood_additives_yellow6_only.csv'},
 'blue1': {'label': 'BLUE 1',
           'keywords': ['blue1',
                        'blue#1',
                        'blueno1',
                        'blue1&2',
                        'blueno.1',
                        'blueno1&2',
                        'fd&cblueno.1',
                        'fd&cblueno1',
                        'acidblue9',
                        'blue#1&#2',
                        'blue#2&#1',
                        'blue#1&2',
                        'blue#2&1',
                        'ciacidblue9',
                        'brilliantbluefcf',
                        'ci42090',
                        'd&cblueno.1',
                        'd&cblueno1',
                        'd&cblueno#1',
                        'd&cblue1',
                        'd&cblue#1',
                        'cifoodblue2',
                        'cifoodblue#2',
                        'cifoodblueno2',
                        'foodbluno.1',
                        'brilliantblue'],
           'output': 'brandedfood_additives_blue1_only.csv'},
 'blue2': {'label': 'BLUE 2',
           'keywords': ['blue2',
                        'blue#2',
                        'blueno2',
                        'blue1&2',
                        'blueno1&2',
                        'blueno.2',
                        'fd&cblueno.2',
                        'fd&cblueno2',
                        'indigotine',
                        'blue#1&#2',
                        'blue#2&#1',
                        'blue#1&2',
                        'blue#2&1',
                        'sodiumindigotindisulfonate',
                        'indigocarmine',
                        'ciacidblue74',
                        'acidblue74',
                        'ci73015',
                        'cifoodblue1',
                        'cifoodblue#1',
                        'cifoodblueno1',
                        'foodblueno2',
                        'indigotindisulfonatesodium'],
           'output': 'brandedfood_additives_blue2_only.csv'},
 'glycerin': {'label': 'GLYCERIN',
              'keywords': ['glycerin', 'glycerine', 'glycerol', 'propanetriol'],
              'output': 'brandedfood_additives_glycerin_only.csv'}}


# GENERAL MATCHING FUNCTION
def detect_additive(df_chunk, keywords):
    """
    Keep the products whose ingredient text contains one of the keywords:
    exact substring matching first, fuzzy matching as a fallback.
    """

    # Lowercase the ingredient text
    df_chunk[COL_NAME] = df_chunk[COL_NAME].astype(str).str.lower()

    # Lowercase ingredient text with whitespace removed, used for matching.
    df_chunk[MATCH_COL] = (
        df_chunk[COL_NAME]
        .str.replace(r"\s+", "", regex=True)
    )

    match_texts = []
    match_keywords = []

    for text in df_chunk[MATCH_COL]:
        found_exact = None
        found_keyword = None

        # EXACT MATCH
        for kw in keywords:
            if kw in text:
                found_exact = re.search(re.escape(kw), text).group(0)
                found_keyword = kw
                break

        # FUZZY MATCH
        if not found_exact:
            best_match, score, _ = process.extractOne(
                text,
                keywords,
                scorer=fuzz.partial_ratio
            )

            if score >= THRESHOLD:
                for word in re.findall(r"[a-z0-9&#.]+", text):
                    if fuzz.partial_ratio(word, best_match) >= THRESHOLD:
                        found_exact = word
                        found_keyword = best_match
                        break

        match_texts.append(found_exact)
        match_keywords.append(found_keyword)

    df_chunk["additive_match_text"] = match_texts
    df_chunk["additive_match_keyword"] = match_keywords

    return df_chunk[df_chunk["additive_match_text"].notna()]


# RUN ALL ADDITIVES
for spec in ADDITIVES.values():
    (OUTPUT_DIR / spec["output"]).unlink(missing_ok=True)

reader = pd.read_stata(STATA_PATH, columns=[COL_NAME], iterator=True, chunksize=CHUNKSIZE)

for chunk in reader:
    for additive, spec in ADDITIVES.items():
        matched = detect_additive(chunk, spec["keywords"])

        if not matched.empty:
            out_path = OUTPUT_DIR / spec["output"]
            matched.to_csv(out_path, mode="a", index=False, header=not out_path.exists())


# SAVE UNIQUE MATCHED NAMINGS
unique_tables = []

for additive, spec in ADDITIVES.items():
    file_path = OUTPUT_DIR / spec["output"]

    # Additives with zero matches have no CSV file.
    if not file_path.exists():
        continue

    temp = (
        pd.read_csv(file_path)
        .groupby(["additive_match_text", "additive_match_keyword"], dropna=False)
        .size()
        .reset_index(name="n_products")
        .rename(columns={"additive_match_text": "matched_text",
                         "additive_match_keyword": "matched_keyword"})
    )
    temp.insert(0, "additive", additive)
    temp.insert(1, "additive_label", spec["label"])
    unique_tables.append(temp)

if unique_tables:
    unique_namings = (
        pd.concat(unique_tables, ignore_index=True)
        .sort_values(["additive", "n_products", "matched_text"],
                     ascending=[True, False, True])
    )

    unique_path = OUTPUT_DIR / "unique_matched_namings.xlsx"

    with pd.ExcelWriter(unique_path) as writer:
        unique_namings.to_excel(writer, sheet_name="All_additives", index=False)

        for additive in ADDITIVES:
            table = unique_namings[unique_namings["additive"] == additive]
            if not table.empty:
                table.to_excel(writer, sheet_name=additive[:31], index=False)
