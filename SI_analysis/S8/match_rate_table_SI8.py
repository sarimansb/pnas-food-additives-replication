# ==============================================================================
# Paper:   Food additives in the U.S. food supply: Regulatory divergence,
#          market concentration, and exposure patterns
#
# Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
#          Vincenzina Caputo
#
# Code:    Sevval Buse Sariman
#
# Purpose: Generates SI Table S8, the USDA GBFPD and NielsenIQ matching
#          results, by USDA food category.
#
# Output:  Table_S8.xlsx (in the SI Appendix)
# ==============================================================================
from pathlib import Path

import pandas as pd
import pyreadstat
from openpyxl.styles import Alignment, Font

# paths
USDA_DTA = Path(".../brandedfood_6.dta")                  # USDA products
MATCHED  = Path(".../scanner/matched_products.csv")  # NielsenIQ-USDA matches
ANALYSIS = Path(".../scanner/analysis")               # <category>_analysis.dta
OUT_XLSX = Path(".../tables/Table_S8.xlsx")

CATEGORIES = ["Beverages", "BreakfastProducts", "PreparedFoods", "DairyEggsandMilkAlt",
              "SnacksandConfectionery", "SpecialNutrition", "Ingredients",
              "MeatSeafoodAlternatives", "Produce"]

def read_cols(path, cols):
    """Read only some variables from a .dta file. If pyreadstat fails, read in chunks with pandas."""
    try:
        return pyreadstat.read_dta(str(path), usecols=cols)[0]
    except pyreadstat.ReadstatError:
        chunks = pd.read_stata(path, columns=cols, convert_categoricals=False,
                               chunksize=500_000)
        return pd.concat(chunks, ignore_index=True)

def upc_key(s):
    """UPC as digits only, without leading zeros."""
    return s.astype("string").str.strip().str.replace(r"[^0-9]", "", regex=True).str.lstrip("0")

# 1. USDA products (US)
usda = read_cols(USDA_DTA, ["gtin_upc", "category_name", "market_country"])
usda = usda[usda["market_country"] == "United States"]
usda["key"] = upc_key(usda["gtin_upc"])
usda = usda.dropna(subset=["key"]).drop_duplicates(subset="key")

# 2. matched to NielsenIQ product file
matched = pd.read_csv(MATCHED, dtype=str, usecols=["upc_str"])
usda["product_file"] = usda["key"].isin(set(upc_key(matched["upc_str"]).dropna()))

# 3. purchased, and with a valid price
purchased, priced = set(), set()
for cat in CATEGORIES:
    d = read_cols(ANALYSIS / f"{cat}_analysis.dta", ["upc_str", "price_oz"])
    k = upc_key(d["upc_str"])                    # USDA UPC matched to the purchase
    ok = k.notna() & (k != "")
    purchased |= set(k[ok])
    priced |= set(k[ok & d["price_oz"].notna()])
usda["purchases"] = usda["key"].isin(purchased)
usda["valid_price"] = usda["key"].isin(priced)

# 4. table in SI layout
t = (usda.groupby("category_name")
         .agg(n=("key", "size"), product_file=("product_file", "mean"),
              purchases=("purchases", "mean"), valid_price=("valid_price", "mean"))
         .sort_index()
         .reset_index())
table = pd.DataFrame({
    "Category": t["category_name"],
    "USDA GBFPD products (UPCs)": t["n"].map("{:,}".format),
    "Match rate with NielsenIQ product file (%)": (100 * t["product_file"]).map("{:.1f}".format),
    "Match rate with NielsenIQ consumer panel purchase file (%)": (100 * t["purchases"]).map("{:.1f}".format),
    "Match rate (%), valid prices only": (100 * t["valid_price"]).map("{:.1f}".format),
})

OUT_XLSX.parent.mkdir(parents=True, exist_ok=True)
with pd.ExcelWriter(OUT_XLSX, engine="openpyxl") as xw:
    table.to_excel(xw, sheet_name="Table", index=False)
    ws = xw.sheets["Table"]
    ws.column_dimensions["A"].width = 40
    for col in "BCDE":
        ws.column_dimensions[col].width = 22
    for cell in ws[1]:
        cell.alignment = Alignment(wrap_text=True)
        cell.font = Font(bold=True)
print(table.to_string(index=False))
