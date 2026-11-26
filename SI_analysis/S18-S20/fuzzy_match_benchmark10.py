# ==============================================================================
# Paper:   Food additives in the U.S. food supply: Regulatory divergence,
#          market concentration, and exposure patterns
#
# Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
#          Vincenzina Caputo
#
# Code:    Sevval Buse Sariman
#
# Purpose: Identifies 10 benchmark additives in the USDA GBFPD ingredient
#          lists using keyword and fuzzy matching.
#
#   For each additive and each product's ingredient list:
#     1. Lowercase the ingredient text and remove all whitespace.
#     2. Exact match: the first keyword (in list order) found in the text,
#        unless that occurrence is a look-alike ingredient (see the rules
#        not_after and never_tokens below).
#     3. Code match: an E/INS number (e.g. "e330") as a separate token.
#     4. Fuzzy match: the best keyword by fuzz.partial_ratio. If its score is
#        at least 90, the first word in the text that scores at least 90
#        against it (look-alike words are skipped).
#
#   Rules for look-alike ingredients:
#     not_after     keyword does not count right after this text
#                   (e.g. "cornsyrup" in "highfructosecornsyrup")
#     never_tokens  words that never count as the additive
#
# Output:  <additive>_matches.csv       matched products, one file per additive
#          _summary.csv                 matches by additive and method
#          unique_matched_namings.xlsx  each matched text and how often it occurs
# ==============================================================================

import re
from pathlib import Path

import pandas as pd
from rapidfuzz import fuzz, process


# SETTINGS
STATA_PATH = Path(
    '.../brandedfood_6.dta'
)
OUTPUT_DIR = Path(".../benchmark10_fuzzy_matches")
ID_COL = "gtin_upc"          # product UPC
TEXT_COL = "ingredients"     # ingredient list
THRESHOLD = 90               # minimum fuzzy score

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# ADDITIVES
# keywords      names searched in the text (in this order)
# codes         E/INS numbers, matched only as separate tokens
# not_after, never_tokens: look-alike rules (see top)
ADDITIVES = {
    "citric_acid": dict(
        label="CITRIC ACID",
        keywords=["citricacid", "citricacidanhydrous", "anhydrouscitricacid",
                  "acidecitrique", "acidocitrico", "propanetricarboxylicacid",
                  "hydroxypropanetricarboxylicacid", "hydroxytricarballylicacid",
                  "tricarballylicacid"],
        codes=["e330", "ins330", "e-330", "330"],
        not_after=[],
        never_tokens=["sodiumcitrate", "trisodiumcitrate", "monosodiumcitrate",
                      "potassiumcitrate", "calciumcitrate", "magnesiumcitrate",
                      "isocitricacid", "ascorbicacid", "citricacidesters"],
    ),
    "riboflavin": dict(
        label="RIBOFLAVIN",
        keywords=["riboflavin", "riboflavine", "lactoflavin", "vitaminb2",
                  "riboflavin5phosphate", "riboflavin-5-phosphate",
                  "riboflavinphosphatesodium", "sodiumriboflavinphosphate",
                  "riboflavintetrabutyrate"],
        codes=["e101", "ins101", "e-101", "101", "101i", "101ii", "101(i)", "101(ii)"],
        not_after=[], never_tokens=[],
    ),
    "folic_acid": dict(
        label="FOLIC ACID",
        keywords=["folicacid", "folate", "folacin", "pteroylglutamicacid",
                  "pteroylmonoglutamicacid", "pteroyl-l-glutamicacid",
                  "vitaminb9", "vitaminm"],
        codes=[], not_after=[], never_tokens=[],
    ),
    "niacin": dict(
        label="NIACIN / VITAMIN B3",
        keywords=["niacinamide", "nicotinamide", "niacin", "nicotinicacid",
                  "pyridinecarboxylicacid", "3-pyridinecarboxylicacid",
                  "vitaminb3", "vitaminpp"],
        codes=["e375", "ins375", "e-375", "375"],
        not_after=[],
        never_tokens=["niacinamideascorbate", "nicotinamideriboside",
                      "nicotinamidemononucleotide", "inositolhexanicotinate"],
    ),
    "corn_syrup": dict(
        label="CORN SYRUP",
        keywords=["cornsyrup", "cornsirup", "cornsyrupsolids", "cornsirupsolids",
                  "driedcornsyrup", "hydrolyzedstarchsyrup",
                  "syrupshydrolyzedstarch", "hydrolysedstarchsyrup"],
        codes=[],
        not_after=["highfructose", "hifructose", "highfructos", "hfcs"],
        never_tokens=["highfructosecornsyrup", "hfcs", "cornstarch", "cornsugar",
                      "glucose-fructosesyrup", "glucosefructosesyrup"],
    ),
    "lecithin": dict(
        label="LECITHIN",
        keywords=["lecithin", "lecithine", "soylecithin", "soyalecithin",
                  "soybeanlecithin", "sunflowerlecithin", "eggyolklecithin",
                  "deoiledlecithin", "hydroxylatedlecithin",
                  "enzymemodifiedlecithin", "phosphatidylcholine"],
        codes=["e322", "ins322", "e-322", "322", "322i", "322ii", "322(i)", "322(ii)"],
        not_after=[], never_tokens=[],
    ),
    "sodium_carbonate": dict(
        label="SODIUM CARBONATE",
        keywords=["sodiumcarbonate", "sodiumcarbonateanhydrous",
                  "anhydroussodiumcarbonate", "disodiumcarbonate",
                  "carbonicaciddisodiumsalt", "sodaash", "washingsoda"],
        codes=["e500", "ins500", "e-500", "500", "e500i", "ins500i", "500i",
               "e500(i)", "ins500(i)", "500(i)"],
        not_after=[],
        never_tokens=["sodiumbicarbonate", "bicarbonateofsoda", "bakingsoda",
                      "sodiumacidcarbonate", "sodiumhydrogencarbonate",
                      "sodiumsesquicarbonate", "sodiumpercarbonate",
                      "calciumcarbonate", "potassiumcarbonate", "ammoniumcarbonate",
                      "magnesiumcarbonate", "sodiumbicarbonatesodaash"],
    ),
    "thiamine": dict(
        label="THIAMINE / VITAMIN B1",
        keywords=["thiamin", "thiamine", "thiaminmononitrate", "thiaminemononitrate",
                  "thiaminhydrochloride", "thiaminehydrochloride",
                  "thiaminmonochloride", "thiaminemonochloride", "thiaminchloride",
                  "vitaminb1", "aneurine", "aneurin"],
        codes=[], not_after=[], never_tokens=["thiaminase"],
    ),
    "pyridoxine_hcl": dict(
        label="PYRIDOXINE HYDROCHLORIDE / VITAMIN B6",
        keywords=["pyridoxinehydrochloride", "pyridoxinehcl",
                  "pyridoxinemonohydrochloride", "pyridoxine", "pyridoxol",
                  "pyridoxolhydrochloride", "vitaminb6", "vitaminb6hydrochloride",
                  "pyridinemethanol"],
        codes=[], not_after=[],
        never_tokens=["pyridoxal5phosphate", "pyridoxalphosphate", "pyridoxal",
                      "pyridoxamine", "pyridoxaminedihydrochloride"],
    ),
    "canola_oil": dict(
        label="CANOLA / RAPESEED OIL",
        keywords=["canolaoil", "canola", "rapeseedoil", "rapeseed",
                  "lowerucicacidrapeseedoil", "colzaoil",
                  "expellerpressedcanolaoil", "higholeiccanolaoil"],
        codes=[],
        not_after=["partiallyhydrogenated", "fullyhydrogenated"],
        never_tokens=["partiallyhydrogenatedcanolaoil",
                      "partiallyhydrogenatedrapeseedoil"],
    ),
}


# MATCHING
WORD = re.compile(r"[a-z0-9&#.]+")     # "words" of the cleaned text

def exact_ok(text, kw, spec):
    """True if at least one occurrence of kw is not a look-alike:
    not right after a not_after text, and kw is not part of a
    never_tokens word."""
    if any(kw in w and w in spec["never_tokens"] for w in WORD.findall(text)):
        return False
    start = text.find(kw)
    while start != -1:
        if not any(text[:start].endswith(x) for x in spec["not_after"]):
            return True
        start = text.find(kw, start + 1)
    return False

def code_present(text, code):
    """True if code (e.g. "e330") appears as a separate token."""
    return re.search(rf"(?<![a-z0-9]){re.escape(code)}(?![a-z0-9])", text) is not None

def find_match(text, spec):
    """Return (matched text, keyword, method, score), or None if no match."""
    # 1. Exact keyword
    for kw in spec["keywords"]:
        if kw in text and exact_ok(text, kw, spec):
            return kw, kw, "exact", 100.0

    # 2. E/INS code
    for code in spec["codes"]:
        if code_present(text, code):
            return code, code, "token_exact", 100.0

    # 3. Fuzzy: best keyword, then the first word close enough to it
    best, score, _ = process.extractOne(text, spec["keywords"], scorer=fuzz.partial_ratio)
    if score >= THRESHOLD:
        for w in WORD.findall(text):
            if w in spec["never_tokens"] or any(w.startswith(x) for x in spec["not_after"]):
                continue
            w_score = fuzz.partial_ratio(w, best)
            if w_score >= THRESHOLD:
                return w, best, "fuzzy", float(w_score)
    return None

# RUN
products = pd.read_stata(STATA_PATH, columns=[ID_COL, TEXT_COL])
texts = products[TEXT_COL].fillna("").astype(str).str.lower().str.replace(r"\s+", "", regex=True)

summary = []
for additive, spec in ADDITIVES.items():
    hits = [find_match(t, spec) for t in texts]
    found = [h is not None for h in hits]
    matched = products.loc[found, [ID_COL, TEXT_COL]].join(pd.DataFrame(
        [h for h in hits if h is not None],
        columns=["additive_match_text", "additive_match_keyword", "match_method", "match_score"],
        index=products.index[found]))

    out_path = OUTPUT_DIR / f"{additive}_matches.csv"
    out_path.unlink(missing_ok=True)
    if len(matched):
        matched.to_csv(out_path, index=False)

    methods = matched["match_method"].value_counts()
    summary.append({
        "additive": additive,
        "label": spec["label"],
        "matched_rows": len(matched),
        "unique_gtin_upc": matched[ID_COL].dropna().astype(str).nunique(),
        "exact": int(methods.get("exact", 0)),
        "token_exact": int(methods.get("token_exact", 0)),
        "fuzzy": int(methods.get("fuzzy", 0)),
    })

summary = pd.DataFrame(summary)
summary.to_csv(OUTPUT_DIR / "_summary.csv", index=False)
print(summary.to_string(index=False))


# UNIQUE MATCHED NAMINGS: each matched text and how many products have it
tables = []
for additive, spec in ADDITIVES.items():
    path = OUTPUT_DIR / f"{additive}_matches.csv"
    if not path.exists():
        continue
    m = pd.read_csv(path, dtype={ID_COL: str})
    t = (m.groupby(["additive_match_text", "additive_match_keyword", "match_method"], dropna=False)
          .size().reset_index(name="n_products")
          .rename(columns={"additive_match_text": "matched_text",
                           "additive_match_keyword": "matched_keyword"}))
    t.insert(0, "additive", additive)
    t.insert(1, "additive_label", spec["label"])
    tables.append(t)

if tables:
    namings = pd.concat(tables, ignore_index=True).sort_values(
        ["additive", "match_method", "n_products", "matched_text"],
        ascending=[True, True, False, True])
    with pd.ExcelWriter(OUTPUT_DIR / "unique_matched_namings.xlsx") as writer:
        namings.to_excel(writer, sheet_name="All_additives", index=False)
        for additive in ADDITIVES:
            part = namings[namings["additive"] == additive]
            if not part.empty:
                part.to_excel(writer, sheet_name=additive[:31], index=False)