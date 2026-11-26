# ==============================================================================
# Paper:   Food additives in the U.S. food supply: Regulatory divergence,
#          market concentration, and exposure patterns
#
# Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
#          Vincenzina Caputo
#
# Code:    Sevval Buse Sariman
#
# Purpose: Draws Figure 2, the number of products containing each of the 34
#          targeted additives, colored by regulatory group.
#
# Output:  figure_2.png and figure_2.pdf
# ==============================================================================

from pathlib import Path

import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.ticker import StrMethodFormatter

plt.rcParams['font.family'] = 'Arial'
plt.rcParams['pdf.fonttype'] = 42
plt.rcParams['font.size'] = 8

OUTPUT = Path('.../figure_2')   # saved as figure_2.png and figure_2.pdf

# 1. Data: number of products containing each additive
counts = {
    "Red 3": 9273,
    "Azodicarbonamide": 828,
    "Potassium bromate": 599,
    "Green 3": 185,
    "Titanium dioxide": 12968,
    "Propylparaben": 372,
    "Brominated vegetable oil": 743,
    "Olestra": 2,
    "Citrus Red 2": 0,
    "Orange B": 0,
    "Aspartame": 4344,
    "Saccharin": 132,
    "Sucralose": 11683,
    "Acesulfame potassium": 8894,
    "Carrageenan": 24333,
    "Red 40": 37845,
    "Yellow 5": 34370,
    "Nitrites and nitrates": 14598,
    "Sulfites": 12904,
    "Partially hydrogenated vegetable oil": 8546,
    "Potassium iodate": 1158,
    "Caramel color": 31343,
    "BHA": 4596,
    "BHT": 8910,
    "Propyl gallate": 1264,
    "TBHQ": 7256,
    "Benzoates": 26521,
    "Monosodium glutamate": 11297,
    "Propylene glycol": 3632,
    "High fructose corn syrup": 30433,
    "Yellow 6": 25815,
    "Blue 1": 29617,
    "Blue 2": 6743,
    "Glycerin": 14654,
}
df = pd.DataFrame({"Food Additive/Substance": list(counts), "N": list(counts.values())})
df_sorted = df.sort_values("N", ascending=False)

# 2. Regulatory groups and colors
groups = {
    "Case 1": ["Red 3", "Azodicarbonamide", "Potassium bromate", "Green 3",
               "Titanium dioxide", "Propylparaben", "Brominated vegetable oil",
               "Olestra", "Citrus Red 2", "Orange B"],
    "Case 2": ["Aspartame", "Saccharin", "Sucralose", "Acesulfame potassium",
               "Carrageenan", "Red 40", "Yellow 5", "Yellow 6", "Nitrites and nitrates",
               "Sulfites", "Partially hydrogenated vegetable oil",
               "Potassium iodate"],
    "Case 3": ["Caramel color", "BHA", "BHT", "Propyl gallate", "TBHQ",
               "Benzoates", "Monosodium glutamate", "Propylene glycol",
               "High fructose corn syrup", "Blue 1", "Blue 2",
               "Glycerin"],
}
color_map = {"Case 1": "#D62728", "Case 2": "#FFBF00", "Case 3": "#1F77B4"}
legend_labels = {
    "Case 1": "EU-unauthorized",
    "Case 2": "EU-restricted",
    "Case 3": "Flagged-permitted",
}

# Color of each bar, from the additive's group
group_of = {a: g for g, additives in groups.items() for a in additives}
colors = [color_map[group_of[a]] for a in df_sorted["Food Additive/Substance"]]

# 3. Plot
fig, ax = plt.subplots(figsize=(7, 5))
ax.bar(df_sorted["Food Additive/Substance"], df_sorted["N"], color=colors)
ax.margins(x=0.01)
ax.set_ylabel("Number of products containing each additive")
ax.yaxis.set_major_formatter(StrMethodFormatter("{x:,.0f}"))
plt.xticks(rotation=45, ha="right", fontsize=8)

legend_handles = [mpatches.Patch(facecolor=color_map[g], label=legend_labels[g])
                  for g in groups]
ax.legend(handles=legend_handles, loc="upper right", fontsize=8)
plt.tight_layout()

# 4. Save
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
plt.savefig(OUTPUT.with_suffix(".png"), dpi=300, bbox_inches="tight")
plt.savefig(OUTPUT.with_suffix(".pdf"), bbox_inches="tight")
plt.show()
