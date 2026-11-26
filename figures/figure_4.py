# ==============================================================================
# Paper:   Food additives in the U.S. food supply: Regulatory divergence,
#          market concentration, and exposure patterns
#
# Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
#          Vincenzina Caputo
#
# Code:    Sevval Buse Sariman
#
# Purpose: Draws Figure 4, a heatmap of the share of products (%) containing
#          each targeted additive, by USDA food category. Additive labels are
#          colored by regulatory group (red = EU-unauthorized, orange =
#          EU-restricted, blue = flagged-permitted).
#
# Input:   results_additive.csv (columns: categories, additive, percentage)
# Output:  figure_4.png and figure_4.pdf
# ==============================================================================

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns
from matplotlib.lines import Line2D

plt.rcParams['font.family'] = 'Arial'
plt.rcParams['pdf.fonttype'] = 42
plt.rcParams['font.size'] = 7

INPUT = ("../results_additive.csv")
OUTPUT = Path(".../figure_4") 

# 1. Load
df = pd.read_csv(INPUT)
df["percentage"] = pd.to_numeric(df["percentage"], errors="coerce")

# 2. Categories: display name and number of products (rows, in this order)
category_names = {
    "Bakery": "Bakery products", "Baby": "Baby/infant foods",
    "Baking": "Baking supplies", "Cereals": "Cereals",
    "Breakfast": "Breakfast foods", "Pickled": "Pickled foods",
    "Snack": "Snacks, sweet or savory", "Dessert": "Desserts & ice creams",
    "Convenience": "Convenience/prepared foods", "Dairy": "Dairy products",
    "Egg": "Egg products & substitutes", "Meat": "Meat products",
    "PlantBasedMeat": "Plant-based meat products", "Seafood": "Seafood products",
    "Deli": "Deli foods", "Sauce": "Sauces & condiments",
    "Oil": "Edible oils & fats", "Fruit": "Fruits & vegetables",
    "Pasta": "Pasta, noodles & rice", "Seasoning": "Seasonings",
    "Stuffing": "Stuffings & gravy", "Syrup": "Syrups & molasses",
    "Honey": "Honey", "Nut": "Nuts, seeds & grains",
    "Supplement": "Supplements & vitamins", "MilkAdditive": "Milk additives",
    "Alcohol": "Alcoholic beverages", "Soft": "Soft beverages",
    "Energy": "Energy drinks", "TeaCoffee": "Tea & coffee beverages",
    "NonAlcohol": "Other non-alcoholic beverages",
    "PlantBasedMilk": "Plant-based milk products", "Water": "Water beverages",
    "WaterEnhancer": "Liquid water enhancers",
}

# Number of products in each category, shown as (N=...) in the row labels.
USDA = (".../brandedfood_6.dta")
row_order = [
    "Alcoholic beverages", "Energy drinks", "Other non-alcoholic beverages",
    "Soft beverages", "Tea & coffee beverages", "Water beverages",
    "Liquid water enhancers", "Cereals", "Breakfast foods",
    "Convenience/prepared foods", "Bakery products", "Deli foods",
    "Pickled foods", "Dairy products", "Egg products & substitutes",
    "Plant-based milk products", "Milk additives", "Desserts & ice creams",
    "Snacks, sweet or savory", "Baby/infant foods", "Supplements & vitamins",
    "Honey", "Nuts, seeds & grains", "Edible oils & fats",
    "Sauces & condiments", "Baking supplies", "Seasonings",
    "Stuffings & gravy", "Syrups & molasses", "Pasta, noodles & rice",
    "Meat products", "Plant-based meat products", "Seafood products",
    "Fruits & vegetables",
]
cats = pd.read_stata(USDA, columns=["categories"])["categories"].replace(category_names)
category_counts = {c: int((cats == c).sum()) for c in row_order}
assert all(n > 0 for n in category_counts.values()), "a category name does not match"
print(category_counts, "total =", sum(category_counts.values()))   

# 3. Additives: display name (from the flag variable) and regulatory group
#    (columns, in this order)
additive_names = {
    "blue_1_flag": "Blue 1", "blue_2_flag": "Blue 2", "green_3_flag": "Green 3",
    "red_3_flag": "Red 3", "red_40_flag": "Red 40", "yellow_5_flag": "Yellow 5",
    "yellow_6_flag": "Yellow 6", "titanium_dioxide_flag": "Titanium dioxide",
    "caramel_color_flag": "Caramel color", "bha_flag": "BHA", "bht_flag": "BHT",
    "propyl_gallate_flag": "Propyl gallate", "tbhq_flag": "TBHQ",
    "benzoate_flag": "Benzoates", "propylparaben_flag": "Propylparaben",
    "nitrite_nitrate_flag": "Nitrites & nitrates", "aspartame_flag": "Aspartame",
    "saccharin_flag": "Saccharin", "sucralose_flag": "Sucralose",
    "acesulfame_k_flag": "Acesulfame potassium",
    "azodicarbonamide_flag": "Azodicarbonamide",
    "potassium_bromate_flag": "Potassium bromate",
    "potassium_iodate_flag": "Potassium iodate", "carrageenan_flag": "Carrageenan",
    "partially_oil_flag": "Partially hydrogenated vegetable oil",
    "brominated_oil_flag": "Brominated vegetable oil", "olestra_flag": "Olestra",
    "hfcs_flag": "High fructose corn syrup", "pg_flag": "Propylene glycol",
    "msg_flag": "Monosodium glutamate", "allsulfites_flag": "Sulfites",
    "citrus_red_2_flag": "Citrus Red 2", "orange_b_flag": "Orange B",
    "glycerin_flag": "Glycerin", "All Additives": "All additives",
}

additive_groups = {
    "All additives": "neutral",
    "Red 3": "eu-unauthorized",
    "Azodicarbonamide": "eu-unauthorized",
    "Potassium bromate": "eu-unauthorized",
    "Green 3": "eu-unauthorized",
    "Titanium dioxide": "eu-unauthorized",
    "Propylparaben": "eu-unauthorized",
    "Brominated vegetable oil": "eu-unauthorized",
    "Olestra": "eu-unauthorized",
    "Citrus Red 2": "eu-unauthorized",
    "Orange B": "eu-unauthorized",
    "Aspartame": "eu-restricted",
    "Saccharin": "eu-restricted",
    "Sucralose": "eu-restricted",
    "Acesulfame potassium": "eu-restricted",
    "Carrageenan": "eu-restricted",
    "Red 40": "eu-restricted",
    "Yellow 5": "eu-restricted",
    "Yellow 6": "eu-restricted",
    "Nitrites & nitrates": "eu-restricted",
    "Sulfites": "eu-restricted",
    "Partially hydrogenated vegetable oil": "eu-restricted",
    "Potassium iodate": "eu-restricted",
    "Caramel color": "flagged-permitted",
    "BHA": "flagged-permitted",
    "BHT": "flagged-permitted",
    "Propyl gallate": "flagged-permitted",
    "TBHQ": "flagged-permitted",
    "Benzoates": "flagged-permitted",
    "Monosodium glutamate": "flagged-permitted",
    "Propylene glycol": "flagged-permitted",
    "High fructose corn syrup": "flagged-permitted",
    "Blue 1": "flagged-permitted",
    "Blue 2": "flagged-permitted",
    "Glycerin": "flagged-permitted",
}
group_colors = {
    "eu-unauthorized": "red",
    "eu-restricted": "orange",
    "flagged-permitted": "royalblue",
    "neutral": "black",
}

# 4. Table for the heatmap: rows = categories, columns = additives
df["categories"] = df["categories"].replace(category_names)
df["additive"] = df["additive"].replace(additive_names)
df = df[df["categories"] != "Other"]

pivot_df = (
    df.pivot_table(index="categories", columns="additive", values="percentage", aggfunc="mean")
      .fillna(0)
      .reindex(columns=list(additive_groups), fill_value=0)
)
pivot_df.index = [f"{c} (N={category_counts.get(c, 0):,})" for c in pivot_df.index]
pivot_df = pivot_df.reindex([f"{c} (N={n:,})" for c, n in category_counts.items()])

# 5. Plot
n_rows, n_cols = pivot_df.shape
fig, ax = plt.subplots(figsize=(0.18 * n_cols, 0.2 * n_rows))

sns.heatmap(
    pivot_df,
    cmap="Spectral_r",
    linewidths=0.5,
    vmin=0,
    vmax=100,
    cbar_kws={"shrink": 0.75, "label": "Percentage (%)"},
    ax=ax,
)
ax.set_xlabel("")
ax.set_ylabel("")

# Additive labels: colored by regulatory group, bold, rotated
for label in ax.get_xticklabels():
    label.set_color(group_colors[additive_groups.get(label.get_text(), "neutral")])
    label.set_fontweight("bold")
ax.set_xticklabels(ax.get_xticklabels(), rotation=90, ha="center", rotation_mode="default")

# Legend below the plot
legend_handles = [
    Line2D([0], [0], color=group_colors[g], lw=0, marker="s", markersize=6, label=lab)
    for g, lab in [("eu-unauthorized", "EU-unauthorized"),
                   ("eu-restricted", "EU-restricted"),
                   ("flagged-permitted", "Flagged-permitted")]
]
plt.tight_layout()
fig.subplots_adjust(bottom=0.35, left=0.30)  # space for the legend and the group labels
fig.legend(
    handles=legend_handles,
    loc="lower center",
    ncol=3,
    frameon=False,
    title="Regulatory classification",
    bbox_to_anchor=(0.5, 0.05),
)

# Food-group brackets to the left of the category labels
food_groups = [
    ("Beverages", 7),
    ("Breakfast\nproducts", 2),
    ("Prepared\nfoods", 4),
    ("Dairy, eggs\n& alternatives", 4),
    ("Snacks\n& confectionery", 2),
    ("Special nutrition", 2),
    ("Ingredients\n& cooking aids", 9),
    ("Meat, seafood\n& alternatives", 3),
    ("Produce", 1),
]
assert sum(n for _, n in food_groups) == n_rows

fig.canvas.draw()
renderer = fig.canvas.get_renderer()
left = min(lbl.get_window_extent(renderer).x0 for lbl in ax.get_yticklabels())
x = ax.transAxes.inverted().transform((left, 0))[0] - 0.01  
tick = 0.008                                                
trans = ax.get_yaxis_transform()   
start = 0
for label, n in food_groups:
    y0, y1 = start + 0.15, start + n - 0.15
    ax.plot([x + tick, x, x, x + tick], [y0, y0, y1, y1], transform=trans,
            color="black", lw=0.5, clip_on=False)
    ax.text(x - 0.008, start + n / 2, label, transform=trans, ha="right",
            va="center", fontsize=7, multialignment="center", clip_on=False)
    start += n

# 6. Save
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
plt.savefig(OUTPUT.with_suffix(".png"), dpi=300, bbox_inches="tight")
plt.savefig(OUTPUT.with_suffix(".pdf"), bbox_inches="tight")
plt.show()
