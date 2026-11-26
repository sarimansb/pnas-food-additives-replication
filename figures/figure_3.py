# ==============================================================================
# Paper:   Food additives in the U.S. food supply: Regulatory divergence,
#          market concentration, and exposure patterns
#
# Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
#          Vincenzina Caputo
#
# Code:    Sevval Buse Sariman
#
# Purpose: Draws Figure 3, by USDA food category:
#            (A) Violin plot of the number of ingredients: all products in
#                the category vs. products with at least one targeted additive
#            (B) Stacked bars of the share of products by number of
#                targeted additives (0, 1, 2, 3, 4, 5 or more)
#          Brackets under the category names mark the nine food groups.
#
# Input:   brandedfood_6.dta
# Output:  figure_3.png and figure_3.pdf
# ==============================================================================

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

plt.rcParams['font.family'] = 'Arial'
plt.rcParams['pdf.fonttype'] = 42
plt.rcParams['font.size'] = 8

INPUT = ".../brandedfood_6.dta"
OUTPUT = Path(".../figure_3")   # saved as figure_3.png and figure_3.pdf

# 1. Data and categories
df = pd.read_stata(INPUT)
df = df[df["categories"] != "Other"]

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
df["category"] = df["categories"].replace(category_names)

# Category order on the x-axis (both panels)
ordered_cats = [
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

# Food groups shown with brackets: (label, number of categories in order above)
food_groups = [
    ("Beverages", 7),
    ("Breakfast\nproducts", 2),
    ("Prepared\nfoods", 4),
    ("Dairy,\neggs\n& alternatives", 4),
    ("Snacks\n& conf.", 2),
    ("Special\nnutrition", 2),
    ("Ingredients &\ncooking aids", 9),
    ("Meat,\nseafood\n& alternatives", 3),
    ("Produce", 1),
]
assert sum(n for _, n in food_groups) == len(ordered_cats)
label_shift = {"Snacks\n& conf.": -0.15, "Special\nnutrition": 0.25,
               "Meat,\nseafood\n& alternatives": -0.2}

def add_group_brackets(ax, fig, with_labels):
    """Draw a bracket under the tick labels for each food group."""
    fig.canvas.draw()
    renderer = fig.canvas.get_renderer()
    bottom = min(lbl.get_window_extent(renderer).y0 for lbl in ax.get_xticklabels())
    y = ax.transAxes.inverted().transform((0, bottom))[1] - 0.03   # just below labels
    trans = ax.get_xaxis_transform()   # x in data units, y in axes units
    start = 0
    for label, n in food_groups:
        x0, x1 = start - 0.4, start + n - 1 + 0.4
        ax.plot([x0, x0, x1, x1], [y + 0.02, y, y, y + 0.02], transform=trans,
                color="black", lw=0.5, clip_on=False)
        if with_labels:
            ax.text((x0 + x1) / 2 + label_shift.get(label, 0), y - 0.02, label, transform=trans,
                    ha="center", va="top", fontsize=8, clip_on=False)
        start += n

fig, (ax_a, ax_b) = plt.subplots(2, 1, figsize=(7.9, 8.3),
                                 gridspec_kw={"hspace": 0.8})

# 2. Panel A: number of ingredients, all products (green) vs. products with targeted
#    additives (brown).
cols = ["category", "ingredient_count"]
violin_df = pd.concat([
    df.loc[df["total_caseall_count"] > 0, cols].assign(group="Products with targeted additives"),
    df[cols].assign(group="All products in category"),
], ignore_index=True)
palette = {"All products in category": "#A1D76A",
           "Products with targeted additives": "#E08214"}

sns.violinplot(
    data=violin_df,
    x="category",
    y="ingredient_count",
    hue="group",
    hue_order=["Products with targeted additives", "All products in category"],
    order=ordered_cats,
    split=True,       
    cut=0,            
    scale="width",
    inner="quartile",
    linewidth=0.5,
    palette=palette,
    ax=ax_a,
)
ax_a.set_xlabel("")
ax_a.set_ylabel("Number of ingredients", fontsize=8)
ax_a.tick_params(axis="x", labelrotation=90, labelsize=8)
ax_a.tick_params(axis="y", labelsize=8)
ax_a.legend(title="", loc="upper left", fontsize=8)

# 3. Panel B: share of products by number of targeted additives
labels = ["0", "1", "2", "3", "4", "5 or more"]
df["bin"] = pd.cut(df["total_caseall_count"], bins=[0, 1, 2, 3, 4, 5, float("inf")],
                   labels=labels, right=False)

# Percentage of products in each bin, by category
shares = {}
for cat in df["category"].unique():
    counts = df.loc[df["category"] == cat, "bin"].value_counts().reindex(labels, fill_value=0)
    shares[cat] = counts / counts.sum() * 100
result_df = pd.DataFrame(shares).T.loc[ordered_cats]

colors = ["#A1D76A", "#91BFDB", "#E08214", "#B35806", "#762A83", "#5E3C99"]
result_df.plot(kind="bar", stacked=True, ax=ax_b, color=colors, edgecolor="black", linewidth=0.5)
ax_b.set_ylabel("Percentage (%)", fontsize=8)
ax_b.set_xticklabels(ordered_cats, rotation=90, fontsize=8)
ax_b.tick_params(axis="y", labelsize=8)
ax_b.set_ylim(0, 100)
ax_b.legend(
    title="Number of targeted additives",
    loc="lower left", bbox_to_anchor=(0, 0.02),
    fontsize=8, title_fontsize=8, frameon=True, edgecolor="black",
)

# 4. Food-group brackets, panel letters, save
# Same x-range in both panels, so each category lines up vertically
for ax in (ax_a, ax_b):
    ax.set_xlim(-0.5, len(ordered_cats) - 0.5)
add_group_brackets(ax_a, fig, with_labels=False)
add_group_brackets(ax_b, fig, with_labels=True)
for ax, letter in [(ax_a, "(A)"), (ax_b, "(B)")]:
    ax.text(-0.07, 1.03, letter, transform=ax.transAxes, fontsize=9,
            fontweight="bold", va="bottom")

OUTPUT.parent.mkdir(parents=True, exist_ok=True)
plt.savefig(OUTPUT.with_suffix(".png"), dpi=300, bbox_inches="tight")
plt.savefig(OUTPUT.with_suffix(".pdf"), bbox_inches="tight")
plt.show()
 