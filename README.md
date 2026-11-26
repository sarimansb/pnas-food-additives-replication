Code for:

> Sariman, S. B., Rudi-Polloshka, J., Just, D. R., and Caputo, V. 2026. *Food additives in the U.S. food supply: Regulatory divergence, market concentration, and exposure patterns.* Proceedings of the National Academy of Sciences.

---

## Repository structure

```
main_analysis/                        Data construction and main-text tables (Tables 1-4)
SI_analysis/
    S5-S7/                            SI Tables S5-S7 
    S8/                               SI Table 
    S12-S14/                          SI Tables S12-S14 
    S15/                              SI Table S15 
    S16-S17/                          SI Tables S16-S17 
    S18-S20/                          SI Tables S18-S20 
    S21-S23/                          SI Tables S21-S23 
```
---

## Data


1. **USDA Global Branded Food Products Database (GBFPD)**, FoodData Central, U.S. Department of Agriculture, Agricultural Research Service. Publicly available at https://fdc.nal.usda.gov. The analysis uses the release of April 24, 2025 (`branded_food.csv`).

2. **NielsenIQ Consumer Panel data, 2023**, including the purchase, trip, panelist, product description, product attribute, and private-label UPC crosswalk files. These data are proprietary and available to licensed users through the Kilts Center for Marketing Data Center at the University of Chicago Booth School of Business. https://www.chicagobooth.edu/research/kilts/research-data/nielseniq

Researchers' own analyses calculated (or derived) based in part on data from Nielsen Consumer LLC and marketing databases provided through the NielsenIQ Datasets at the Kilts Center for Marketing Data Center at The University of Chicago Booth School of Business. The conclusions drawn from the NielsenIQ data are those of the researchers and do not reflect the views of NielsenIQ. NielsenIQ is not responsible for, had no role in, and was not involved in analyzing and preparing the results reported herein.

---

## Software

- **Stata** 17 or later
- **Python 3** with `pandas`, `duckdb`, `rapidfuzz`, `pyreadstat`, and `openpyxl`

```
pip install pandas duckdb rapidfuzz pyreadstat openpyxl
```

---

## Run order

Run the scripts in the order below. Each step uses the output of the previous one.

### Part 1. USDA GBFPD: food categories and additive identification (`main_analysis/`)

| Step | Script | What it does |
|---|---|---|---|---|
| 1 | `duplicateremoval_1.do` | Cleans UPCs and removes duplicate records. Among duplicates, keeps records with a food category and an ingredient list, then the most recently modified record. Keeps U.S. products. |
| 2 | `categorydefinition_2.do` | Groups the GBFPD branded food categories into 34 food categories (SI Appendix, Table S2) and drops products without a usable category. |
| 3 | `ingredientcount_3.do` | Drops products without ingredient information, corrects ingredient lists with unusual separators, cleans the ingredient text, and counts ingredients. |
| 4 | `fuzzy_match_4.py` | Searches ingredient lists for each targeted additive by exact matching, then fuzzy matching (RapidFuzz `partial_ratio`, threshold 90). The list of matched spellings was used to build the search terms in step 5. |
| 5 | `additiveidentification_5.do` | Identifies the 34 targeted additives using names, spelling variants, abbreviations, E-numbers, and exclusion rules. Creates `<additive>_flag` (1 = present) and `<additive>_match` (the term that matched). |
| 6 | `caseidentification_6.do` | Creates an indicator for each regulatory group and for any targeted additive. |
| 7 | `distribution_7.do` | Share of products in each regulatory group and containing each additive, by food category (used for the figures on additive prevalence). |
| 8 | `renamingvariables_8.do` | Renames the regulatory group variables, counts targeted additives in each group, and labels all variables. |

### Part 2. Linking to NielsenIQ and main results (`main_analysis/`)

| Step | Script | What it does |
|---|---|---|---|---|
| 9 | `match_scanner_usda_9.py` | Matches NielsenIQ food and beverage products to GBFPD products by UPC (exact match, then check-digit match; private-label UPCs through the NielsenIQ crosswalks). Keeps purchases of matched products, adds trip, household, and USDA information, and writes one file per food group (9 groups). |
| 10 | `import_categories_10.do` |  Imports the 9 food-group files into Stata. |
| 11 | `build_analysis_data_11.do` |  Builds the regulatory case (most stringent group present), fills missing package sizes, converts package size to ounces, computes price per ounce, and builds household variables, sampling weights, and purchase month. |
| 12 | `manuscript_analysis_12.do` | Table 1 (purchase-based exposure), Table 2 (mean price per ounce), Table 3 (OLS of log price per ounce), Table 4 (household monthly expenditure, Poisson QMLE), and SI Tables S9-S10. |


### Part 3. Supporting Information (`SI_analysis/`)

Run after Part 2. The folders can be run in any order. Within a folder, run the scripts in the order listed.

| Folder | Script(s), in order | What it does |
|---|---|---|---|
| `S5-S7/` | `Tables_S5_S6_S7.do` | Number of products containing each additive (S5), distribution of products by number of targeted additives (S6), and mean ingredient count (S7), by food category. Uses `brandedfood_6.dta`. |
| `S8/` | `match_rate_table_SI8.py` | Match rates between the GBFPD and NielsenIQ by food category (SI Table S8). |
| `S12-S14/` | 1. `rank_additives.do` 2. `Tables_S12-S14.do` | Finds the position (rank) of each targeted additive in the ingredient list, then repeats the exposure, price, and expenditure analyses counting only additives among the first 3, 5, and 10 ingredients. |
| `S15/` | `Table_S15.do` | Computes calories per package and price per calorie, and compares price regressions per calorie and per ounce. |
| `S16-S17/` | `Tables_S16_S17.do` | Prices and price regressions under the dominant-count classification (each product assigned to the group with the most targeted additives). |
| `S18-S20/` | 1. `fuzzy_match_benchmark10.py` 2. `additiveidentification_benchmark10.do` 3. `Tables_S18_S20.do` | Identifies 10 commonly used benchmark ingredients (citric acid, riboflavin, folic acid, niacin, corn syrup, lecithin, sodium carbonate, thiamine, pyridoxine hydrochloride, canola oil) and compares exposure, prices, and expenditure with the targeted additives. |
| `S21-S23/` | `Tables_S21_S23.do` | Repeats the main analyses for products last modified in or before 2023 and compares them with the full sample. |
---

### Part 4. Figures (`figures/`)

Figures 3 and 4 read the data created in Part 1 (run after step 8). The other figures contain their values in the script and can be run at any time. Each script saves a PNG (300 dpi) and a PDF.

| Script | Figure | What it does |
|---|---|---|---|
| `figure_1.py` | Figure 1 | Regulatory status of the 34 targeted additives in the EU, the U.S., and California. | 
| `figure_2.py` | Figure 2 | Number of products containing each targeted additive, colored by regulatory group. |
| `figure_3.py` | Figure 3 | (A) Number of ingredients, all products vs. products with targeted additives; (B) share of products by number of targeted additives, by food category. |
| `figure_4.py` | Figure 4 | Heatmap of the share of products containing each targeted additive, by food category. | 
| `figure_s2.py` | SI Figure S2 | Number of products containing each of the 10 benchmark ingredients and additives. |
| `figure_s3.py` | SI Figure S3 | (A) Map of state bills on food additives (passed and pending); (B) number of state bills that include each additive. |
---

## Contact

Sevval Buse Sariman, Michigan State University (sarimans@msu.edu)
