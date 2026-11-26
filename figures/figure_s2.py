# ==============================================================================
# Paper:   Food additives in the U.S. food supply: Regulatory divergence,
#          market concentration, and exposure patterns
#
# Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
#          Vincenzina Caputo
#
# Code:    Sevval Buse Sariman
#
# Purpose: Draws SI Figure S2, the number of products containing each of the
#          10 benchmark ingredients and additives.
#
# Output:  figure_s2.png and figure_s2.pdf
# ==============================================================================

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.ticker import StrMethodFormatter

plt.rcParams['font.family'] = 'Arial'
plt.rcParams['pdf.fonttype'] = 42
plt.rcParams['font.size'] = 7

OUTPUT = Path(".../figure_s2")   # saved as figure_s2.png and figure_s2.pdf

# 1. Data: number of products containing each benchmark ingredient/additive
counts = {
    "Canola oil": 61084,
    "Citric acid": 116719,
    "Corn syrup": 70725,
    "Folic acid": 73323,
    "Lecithin": 83778,
    "Niacin": 76313,
    "Pyridoxine HCl": 12776,
    "Riboflavin": 72568,
    "Sodium carbonate": 1263,
    "Thiamine": 74362,
}
df = pd.DataFrame({"Benchmark additive": list(counts), "N": list(counts.values())})
df_sorted = df.sort_values("N", ascending=False)

# 2. Plot: bars sorted from most to least common, with the count on each bar
fig, ax = plt.subplots(figsize=(4.5, 3.5))
bars = ax.bar(df_sorted["Benchmark additive"], df_sorted["N"])
ax.margins(x=0.02)
ax.set_ylabel("Number of products")
ax.yaxis.set_major_formatter(StrMethodFormatter("{x:,.0f}"))
plt.xticks(rotation=45, ha="right", fontsize=7)

for bar, n in zip(bars, df_sorted["N"]):
    ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height(), f"{n:,}",
            ha="center", va="bottom", fontsize=7)

plt.tight_layout()

# 3. Save
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
plt.savefig(OUTPUT.with_suffix(".png"), dpi=300, bbox_inches="tight")
plt.savefig(OUTPUT.with_suffix(".pdf"), bbox_inches="tight")
plt.show()