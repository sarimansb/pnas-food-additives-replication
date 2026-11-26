# ==============================================================================
# Paper:   Food additives in the U.S. food supply: Regulatory divergence,
#          market concentration, and exposure patterns
#
# Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
#          Vincenzina Caputo
#
# Code:    Sevval Buse Sariman
#
# Purpose: Match 2023 NielsenIQ purchases to USDA branded food products.
#          STEP 1  Match NielsenIQ food and beverage products to USDA products
#          STEP 2  Keep the 2023 purchases of matched products
#          STEP 3  Add trip, household and USDA information to each purchase;
#                   write one CSV per food group (9)
# ==============================================================================

import csv
import shutil
import time
from pathlib import Path

import duckdb
import pandas as pd

# SETTINGS
# Project directories
NIELSEN  = Path(".../2023_nielsen/Annual_Files")
USDA_DTA = Path(".../brandedfood_6.dta")
OUT      = Path(".../scanner")
CSV_DIR  = OUT / "csv"
MATCHED  = OUT / "matched_products.csv"

# Temporary files
WORK      = Path(".../scanner_usda_temp")
USDA_CSV  = WORK / "usda.csv"
PURCHASES = WORK / "purchases.csv"
JOINED    = WORK / "purchases_all.parquet"

# NielsenIQ files
PRODUCTDESC   = NIELSEN / "productdesc.tsv"
PRODUCTATTR   = NIELSEN / "productattributes.tsv"
PURCHASE      = NIELSEN / "purchase.tsv"
TRIP          = NIELSEN / "trip.tsv"
PANELIST      = NIELSEN / "panelist.tsv"
XREF_MASKED   = NIELSEN / "Private Label Masked UPCs 2020-2021.txt"
XREF_UNMASKED = NIELSEN / "Private_Label_2020_Unmasked_2021_Masked_UPCs.txt"

# Product modules outside the food and beverage universe (identified manually)
DROP_MODULES = [
    4501, 7003, 7008, 7012, 7014, 7020, 7025, 4502, 8444, 4503, 7116, 7215, 7224, 7226, 7229, 4504,
    7100, 7105, 7106, 7115, 7117, 7118, 7125, 7126, 7135, 7140, 7141, 7142, 7145, 7150, 7155, 7160,
    7170, 7175, 7194, 7809, 4505, 6014, 6068, 7030, 7040, 7043, 7120, 7130, 7161, 7180, 7190, 7195,
    7200, 7521, 7522, 7529, 7702, 7742, 7748, 7795, 7796, 7825, 7845, 7846, 7847, 7885, 4506, 7015,
    7041, 7045, 7060, 7061, 7062, 7065, 7070, 7075, 7076, 7080, 7085, 7090, 7095, 7098, 7176, 7240,
    7850, 7851, 7855, 4507, 7242, 7245, 7250, 7260, 7320, 7332, 7335, 7340, 7345, 7734, 7804, 4508,
    7034, 7035, 7036, 7037, 7038, 7039, 8454, 8602, 4509, 1694, 6025, 7452, 7453, 7454, 7455, 7456,
    7457, 7458, 7459, 7811, 4510, 6028, 7380, 7381, 7460, 7462, 7464, 7465, 7466, 7467, 7468, 7469,
    7798, 4511, 7275, 7280, 7284, 7285, 7290, 7295, 7301, 7302, 7305, 7306, 7307, 7308, 7802, 5505,
    7360, 7370, 7371, 7373, 7375, 7385, 5501, 7415, 7416, 7531, 5502, 7870, 7871, 5503, 8902, 5507,
    7736, 8614, 8621, 5516, 6029, 7872, 7880, 7882, 5517, 6057, 6060, 7410, 7421, 5518, 7044, 7735,
    5519, 6013, 5520, 7799, 7801, 5521, 7805, 5522, 6010, 6011, 6033, 6034, 6035, 6036, 6047, 7445,
    7450, 7630, 7631, 7632, 7633, 7634, 7635, 7636, 7646, 7652, 7653, 7659, 7660, 7722, 7723, 7727,
    7728, 7733, 5524, 6038, 7572, 9599, 6073, 9999, 1699, 1722, 6001, 6003, 7747, 7812, 8445, 8446,
    8447, 8525, 8526, 8527, 8548, 8551, 6002, 6037, 8451, 8453, 8455, 8456, 8457, 8462, 8463, 8467,
    8468, 8476, 8484, 8550, 8603, 8607, 1490, 8417, 8418, 8419, 8423, 8425, 8502, 8546, 6004, 8449,
    8552, 6005, 1530, 1531, 6006, 8486, 8604, 6007, 8416, 8426, 8428, 8438, 6008, 8411, 8435, 8440,
    8512, 8518, 8524, 8530, 8531, 8532, 8533, 8553, 6009, 8465, 8496, 8611, 6030, 7179, 7181,
    8464, 8466, 8475, 8470, 8471, 8472, 8473, 8474, 8477, 8478, 8479, 8485, 8529, 8535, 8554,
    8557, 8777, 7790, 7791, 7807, 8300, 8301, 8350, 8396, 8402, 8412, 8420, 8421, 8422, 8424, 8427,
    8429, 8430, 8432, 8433, 8434, 8436, 8437, 8441, 8442, 8443, 8450, 8500, 8501, 8510, 8513, 8514,
    8515, 8516, 8517, 8520, 8528, 8534, 8536, 8538, 8540, 8541, 8542, 8543, 8544, 8545, 8559, 8601,
    8605, 8606, 8612, 8615, 8622, 8491, 8492, 8494, 8539, 8403, 8404, 8406, 8409, 8410, 8511, 8522,
    8547, 8613, 8617, 8618, 8619, 6015, 7265, 7270, 8439, 6016, 6026, 8452, 8487, 8488, 8490, 8493,
    8498, 8556, 6017, 8431, 8448, 8459, 8460, 8461, 8499, 8503, 8504, 8519, 8616,
]

# Nutrition-label columns from productattributes.tsv (for Table S15)
LABEL_COLS = ["CALORIES_PER_SERVING_SIZE", "SERVING_SIZE_METRIC", "SERVING_SIZE_HOUSEHOLD"]

# The 9 food groups and the USDA categories in each.
GROUPS = {
    "Beverages":               ["Alcohol", "Energy", "NonAlcohol", "Soft",
                                "TeaCoffee", "Water", "WaterEnhancer"],
    "BreakfastProducts":       ["Breakfast", "Cereals"],
    "PreparedFoods":           ["Bakery", "Convenience", "Deli", "Pickled"],
    "DairyEggsandMilkAlt":     ["Dairy", "Egg", "MilkAdditive", "PlantBasedMilk"],
    "SnacksandConfectionery":  ["Dessert", "Snack"],
    "SpecialNutrition":        ["Baby", "Supplement"],
    "Ingredients":             ["Baking", "Honey", "Nut", "Oil", "Pasta", "Sauce",
                                "Seasoning", "Stuffing", "Syrup"],
    "MeatSeafoodAlternatives": ["Meat", "PlantBasedMeat", "Seafood"],
    "Produce":                 ["Fruit"],
}

# Check: all 34 categories used once
_all = [c for cats in GROUPS.values() for c in cats]
assert len(_all) == len(set(_all)) == 34, "a category is missing or listed twice"

# HELPERS
def log(text):
    """Print a progress message with the time."""
    print(f"[{time.strftime('%H:%M:%S')}] {text}", flush=True)

def upc_no_zeros(s):
    """Key for comparing NielsenIQ and USDA UPCs: remove spaces, then leading
    zeros, then non-digits."""
    s = s.astype("string").str.replace(" ", "", regex=False)
    s = s.str.replace(r"^[0]+", "", regex=True)
    s = s.str.replace(r"[^0-9]", "", regex=True)
    return s.mask(s == "")

def upc_digits(s):
    """UPC with digits only, leading zeros kept (for linking NielsenIQ files)."""
    s = s.astype("string").str.strip().str.replace(r"[^0-9]", "", regex=True)
    return s.mask(s == "")

def check_digit(upc):
    """UPC check digit: digits weighted 3, 1, 3, 1, ... from the right; the
    check digit makes the total a multiple of 10."""
    total = sum(int(d) * (3 if i % 2 == 0 else 1) for i, d in enumerate(reversed(upc)))
    return str((10 - total % 10) % 10)

def read_xref(path, sep, names, key, value):
    """Private-label file as a lookup table {2021 masked UPC: other UPC}."""
    x = pd.read_csv(path, sep=sep, dtype=str, names=names, skiprows=1)
    log(f"STEP 1: {path.name}: {len(x):,} mappings")
    return dict(zip(upc_no_zeros(x[key]), upc_no_zeros(x[value])))

def product_sizes():
    """{UPC: PRODUCT_SIZE}: default quoting, unreadable lines skipped, 2023
    rows if there is a year column, UPC as trimmed text, first non-missing
    PRODUCT_SIZE per UPC."""
    cols = pd.read_csv(PRODUCTATTR, sep="\t", nrows=1).columns
    use = ["upc", "PRODUCT_SIZE"] + (["year"] if "year" in cols else [])
    pa = pd.read_csv(PRODUCTATTR, sep="\t", usecols=use, dtype=str,
                     on_bad_lines="skip")
    if "year" in pa.columns and (pa["year"] == "2023").any():
        pa = pa[pa["year"] == "2023"]
    pa["upc"] = pa["upc"].astype(str).str.strip()
    pa = pa.dropna(subset=["PRODUCT_SIZE"]).drop_duplicates(subset="upc", keep="first")
    log(f"STEP 2: UPCs with PRODUCT_SIZE {len(pa):,}")
    return pa.set_index("upc")["PRODUCT_SIZE"]

def label_key(s):
    """UPC key for the label columns: no trailing .0, digits only, no
    leading zeros."""
    s = s.astype(str).str.strip().str.replace(r"\.0$", "", regex=True)
    s = s.str.replace(r"\D", "", regex=True).str.lstrip("0")
    return s.replace("", pd.NA)

def label_columns():
    """Calories and serving sizes per UPC"""
    pa = pd.read_csv(PRODUCTATTR, sep="\t", dtype=str, quoting=csv.QUOTE_NONE,
                     usecols=lambda c: c.strip().lower() == "upc" or c in LABEL_COLS)
    pa = pa.rename(columns={c: "upc" for c in pa.columns if c.strip().lower() == "upc"})
    pa["key"] = label_key(pa["upc"])
    pa = pa.dropna(subset=["key"]).drop_duplicates("key", keep="last")
    log(f"STEP 2: UPCs with label information {len(pa):,}")
    return pa.set_index("key")[LABEL_COLS]

def csv_in_duckdb(path):
    """Read a comma-separated file in DuckDB, every column as text.

    We use DuckDB because the purchase files are too large for pandas to hold
    in memory; DuckDB reads and joins them straight from disk. Reading every
    column as text keeps UPCs from losing leading zeros."""
    return (f"read_csv('{path}', ALL_VARCHAR=TRUE, delim=',', quote='\"', "
            f"escape='\"', header=TRUE, MAX_LINE_SIZE=5000000)")

def tsv_in_duckdb(path):
    """Read a tab-separated NielsenIQ file in DuckDB, every column as text."""
    return (f"read_csv('{path}', ALL_VARCHAR=TRUE, delim='\\t', quote='', "
            f"header=TRUE, MAX_LINE_SIZE=5000000)")

def count(con, table):
    """Number of rows (DuckDB)."""
    return con.execute(f"SELECT COUNT(*) FROM {table}").fetchall()[0][0]

def columns(con, table):
    """Column names (DuckDB)."""
    return [r[0] for r in con.execute(f"DESCRIBE SELECT * FROM {table}").fetchall()]

# STEP 1  Match NielsenIQ food and beverage products to USDA products
def step1():
    # --- NielsenIQ food and beverage products
    products = pd.read_csv(PRODUCTDESC, sep="\t", dtype={"upc": "string"},
                           quoting=csv.QUOTE_NONE, escapechar="\\", low_memory=False)
    log(f"STEP 1: NielsenIQ products read {len(products):,}")
    for c in [c for c in products.columns if "upc" in c.lower()]:
        products[c] = products[c].astype("string")       # UPCs as text
    products["product_module_code"] = pd.to_numeric(products["product_module_code"], errors="coerce")
    products = products[~products["product_module_code"].isin(DROP_MODULES)]
    log(f"STEP 1: food and beverage products kept {len(products):,}")

    # --- USDA products: key upc_str, one row per key; saved for STEP 3
    usda = pd.read_stata(USDA_DTA, convert_categoricals=False)
    usda["upc_str"] = upc_no_zeros(usda["gtin_upc"])
    assert not usda["upc_str"].duplicated().any(), "Duplicate UPCs in USDA file."
    usda.to_csv(USDA_CSV, index=False)
    log(f"STEP 1: USDA unique UPCs {len(usda):,}")

    # --- Keys to try for each NielsenIQ product. Store-brand UPCs are masked
    #     since 2021; the two private-label files give their 2020 UPCs, and
    #     each store brand gets an extra row with each of them.
    to_unmasked = read_xref(XREF_UNMASKED, "\t", ["2020_Unmasked_UPC", "2021_Masked_UPC"],
                            key="2021_Masked_UPC", value="2020_Unmasked_UPC")
    to_masked = read_xref(XREF_MASKED, "|", ["2021_MASKED_UPC", "2020_MASKED_UPC"],
                          key="2021_MASKED_UPC", value="2020_MASKED_UPC")
    products["upc_str_using"] = upc_no_zeros(products["upc"])
    products["upc_type"] = "masked_2021"                  # the product's own 2023 UPC
    parts = [products]
    for mapping, label in [(to_unmasked, "unmasked_2020"), (to_masked, "masked_2020")]:
        alt = products["upc_str_using"].map(mapping)
        extra = products[alt.notna()].copy()
        extra["upc_str_using"] = alt[alt.notna()]
        extra["upc_type"] = label
        parts.append(extra)
        log(f"STEP 1: extra rows with {label} UPCs {len(extra):,}")
    keys = pd.concat(parts, ignore_index=True).drop_duplicates(subset=["upc_str_using"], keep="first")
    keys = keys.astype("string")
    keys["upc_str_using"] = upc_digits(keys["upc_str_using"])
    keys = keys.dropna(subset=["upc_str_using"]).copy()
    log(f"STEP 1: NielsenIQ UPC keys {len(keys):,}")
    print(keys["upc_type"].value_counts())

    # --- Match. Exact: the key equals the USDA UPC. Check digit: the key plus
    #     its check digit equals the USDA UPC (keys of 6+ digits).
    usda_upc = upc_digits(usda["upc_str"]).dropna().to_frame("upc_str")
    keys["_check_digit"] = keys["upc_str_using"].map(check_digit)
    exact = keys.merge(usda_upc, left_on="upc_str_using", right_on="upc_str")
    exact["_exact_match"], exact["_check_digit_match"] = 1, 0
    long = keys[keys["upc_str_using"].str.len() >= 6].copy()
    long["_key"] = long["upc_str_using"] + long["_check_digit"]
    check = long.merge(usda_upc, left_on="_key", right_on="upc_str").drop(columns="_key")
    check["_exact_match"], check["_check_digit_match"] = 0, 1
    log(f"STEP 1: exact matches {len(exact):,}; check-digit matches {len(check):,}")

    # --- One match per USDA UPC (exact first) and per key (exact first)
    matched = pd.concat([exact, check], ignore_index=True)
    usda_has_exact = matched.groupby("upc_str")["_exact_match"].transform("max")
    matched = matched[(usda_has_exact == 0) | (matched["_exact_match"] == 1)]
    matched = (matched.sort_values(["upc_str_using", "_exact_match"], ascending=[True, False])
                      .drop_duplicates(subset=["upc_str_using"], keep="first"))
    matched.to_csv(MATCHED, index=False)
    log(f"STEP 1: matched NielsenIQ UPCs {len(matched):,}")

# STEP 2  Keep the 2023 purchases of matched products
def step2():
    """purchase.tsv is read 5 million rows at a time. Purchases of matched
    products are kept (inner join on the UPC digits) and get the product
    variables; PRODUCT_SIZE and the label columns are then looked up with the
    purchase UPC (upc_x)."""
    matched = pd.read_csv(MATCHED, dtype="string")
    matched["_key"] = upc_digits(matched["upc"])
    assert matched["_key"].is_unique, "A product matched more than once."
    sizes = product_sizes()
    labels = label_columns()

    total = 0
    chunks = pd.read_csv(PURCHASE, sep="\t", dtype="string", chunksize=5_000_000)
    for i, chunk in enumerate(chunks, start=1):
        chunk["_key"] = upc_digits(chunk["upc"])
        df = chunk.merge(matched, on="_key", how="inner").drop(columns="_key")
        df["PRODUCT_SIZE"] = df["upc_x"].astype(str).str.strip().map(sizes)
        key = label_key(df["upc_x"])
        for c in LABEL_COLS:
            df[c] = key.map(labels[c])
        df.to_csv(PURCHASES, index=False, mode="w" if i == 1 else "a", header=(i == 1))
        total += len(df)
        log(f"STEP 2: chunk {i}: {len(chunk):,} purchases read, {len(df):,} matched")
    log(f"STEP 2: matched purchases {total:,}")

# STEP 3  Add trip, household and USDA information; one CSV per food group
def step3():
    """DuckDB joins the files on disk, so they do not need to fit in memory.
    All joins are left joins: every purchase is kept."""
    con = duckdb.connect()
    con.execute(f"PRAGMA temp_directory='{WORK}/duckdb_spill'")
    con.execute("SET threads=4")
    purchase, trip, panelist, usda = (csv_in_duckdb(PURCHASES), tsv_in_duckdb(TRIP),
                                      tsv_in_duckdb(PANELIST), csv_in_duckdb(USDA_CSV))

    # USDA variables the purchase data does not have yet
    have = (columns(con, purchase) + columns(con, trip) + columns(con, panelist))
    usda_extra = ", ".join(f'u."{c}"' for c in columns(con, usda) if c not in have)

    # Purchases + trips (trip_code_uc) + households (household_code) + USDA
    # (matched USDA UPC, digits only)
    digits = lambda col: f"regexp_replace(trim(coalesce({col}, '')), '[^0-9]', '', 'g')"
    con.execute(f"""
        COPY (
            SELECT p.*, t.* EXCLUDE (trip_code_uc), h.* EXCLUDE (household_code),
                   {digits('p.upc_str')} AS key_upc, {usda_extra}
            FROM {purchase} p
            LEFT JOIN {trip} t USING (trip_code_uc)
            LEFT JOIN {panelist} h USING (household_code)
            LEFT JOIN (SELECT *, {digits('upc_str')} AS key_upc FROM {usda}) u
                   ON {digits('p.upc_str')} = u.key_upc
        ) TO '{JOINED}' (FORMAT PARQUET, COMPRESSION ZSTD)
    """)
    n_in, n_out = count(con, purchase), count(con, f"read_parquet('{JOINED}')")
    assert n_out == n_in, f"Row count changed: {n_in:,} -> {n_out:,}"
    log(f"STEP 3: purchases {n_in:,} in, {n_out:,} out")

    # One CSV per food group
    CSV_DIR.mkdir(parents=True, exist_ok=True)
    category = "lower(trim(replace(categories, chr(160), ' ')))"
    for group, cats in GROUPS.items():
        rows = (f"SELECT * FROM read_parquet('{JOINED}') WHERE {category} IN "
                "(" + ", ".join(f"'{c.lower()}'" for c in cats) + ")")
        out = CSV_DIR / f"purchase_2023_panel_{group}.csv"
        con.execute(f"COPY ({rows}) TO '{out}' (HEADER, DELIMITER ',')")
        log(f"STEP 3: {group}: {count(con, '(' + rows + ')'):,} rows -> {out.name}")
    con.close()

# RUN
if __name__ == "__main__":
    WORK.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    step1()
    step2()
    step3()
    shutil.rmtree(WORK, ignore_errors=True)         # delete the temporary files
    log(f"Done. CSV files in {CSV_DIR}")
