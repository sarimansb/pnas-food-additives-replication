# ==============================================================================
# Paper:   Food additives in the U.S. food supply: Regulatory divergence,
#          market concentration, and exposure patterns
#
# Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
#          Vincenzina Caputo
#
# Code:    Sevval Buse Sariman
#
# Purpose: Draws Figure 1, the regulatory status of the 34 targeted additives
#          in the EU, the U.S. and California.
#
# Output:  figure_1.png (300 dpi) and figure_1.pdf
# ==============================================================================

import matplotlib.pyplot as plt
from matplotlib.offsetbox import (AnchoredOffsetbox, DrawingArea, HPacker,
                                  TextArea, VPacker)
import pandas as pd

plt.rcParams['font.family'] = 'Arial'
plt.rcParams['pdf.fonttype'] = 42

OUTPUT = ".../figure_1"   # saved as figure_1.png and figure_1.pdf

# ------------------------------------------------------------------------------
# Regulatory status of each additive
# Codes:
#   1    Not allowed
#   2    Restricted or requires warning label in all food
#   2.1  Requires a warning label
#   2.2  Restricted in a specific food category
#   2.3  Not allowed in schools
#   3    Allowed
# ------------------------------------------------------------------------------
data = {
    'Additive': [
        'Red 3', 'Azodicarbonamide', 'Potassium bromate', 'Green 3', 'Titanium dioxide',
        'Propylparaben', 'Brominated vegetable oil (BVO)', 'Olestra', 'Citrus Red 2', 'Orange B', 'Aspartame', 'Saccharin',
        'Sucralose', 'Acesulfame potassium', 'Carrageenan', 'Red 40', 'Yellow 5', 'Yellow 6',
        'Nitrites and nitrates', 'Sulfites', 'Partially hydrogenated oil', 'Potassium iodate', 'Caramel color',
        'Butylated hydroxyanisole (BHA)', 'Butylated hydroxytoluene (BHT)', 'Propyl gallate', 'Tert-butylhydroquinone (TBHQ)', 'Benzoates', 'Monosodium glutamate (MSG)', 'Propylene glycol', 'High fructose corn syrup',
        'Blue 1', 'Blue 2', 'Glycerin'
    ],
    'EU': [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.2, 2.2, 2.2, 2.2, 2.2, 2.1, 2.1, 2.1, 2, 2.1, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3],
    'US': [1, 3, 3, 3, 3, 3, 1, 3, 2, 1, 3, 3, 3, 3, 3, 3, 3, 3, 3, 2.2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3],
    'California': [1, 3, 1, 2.3, 3, 1, 1, 3, 2, 1, 3, 3, 3, 3, 3, 2.3, 2.3, 2.3, 3, 2.2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 2.3, 2.3, 3]}
df = pd.DataFrame(data)

df_melt = df.melt(id_vars='Additive', var_name='Region', value_name='Status')

status_labels = {
    1: 'Not allowed',
    2: 'Restricted or requires warning label in all food',
    2.1: 'Requires a warning label',
    2.2: 'Restricted in a specific food category',
    2.3: 'Not allowed in schools',
    3: 'Allowed'
}
color_map = {1: '#D62728', 2: '#FFBF00', 2.1: '#FFBF00', 2.2: '#FFBF00',
             2.3: '#FFBF00', 3: '#1F77B4'}
hatch_map = {1: '', 2: '', 2.1: '///', 2.2: '||', 2.3: 'XXX', 3: ''}

additives = df['Additive'].tolist()
additive_to_y = {add: i for i, add in enumerate(additives)}
region_positions = {'EU': 0, 'US': 0.1, 'California': 0.2}
spacing = 1.5  # vertical spacing between rows

# Plot: one box per additive and region
fig, ax = plt.subplots(figsize=(4.4, 8.8))
for _, row in df_melt.iterrows():
    y = additive_to_y[row['Additive']] * spacing
    x = region_positions[row['Region']]
    ax.add_patch(plt.Rectangle(
        (x - 0.016, y - 0.2), 0.03, 0.99,
        facecolor=color_map[row['Status']],
        edgecolor='black',
        hatch=hatch_map[row['Status']]
    ))

ax.set_xticks(list(region_positions.values()))
ax.set_xticklabels(list(region_positions.keys()))
ax.set_yticks([i * spacing for i in range(len(additives))])
ax.set_yticklabels(additives)
ax.set_ylim(-0.5, (len(additives) - 1) * spacing + 1)
ax.invert_yaxis()
ax.set_xlim(-0.1, 0.3)

def legend_row(status, indent):
    box = DrawingArea(20, 10)
    box.add_artist(plt.Rectangle((0, 0), 20, 10, facecolor=color_map[status],
                                 edgecolor='black', linewidth=0,
                                 hatch=hatch_map[status]))
    row = [DrawingArea(indent, 10), box,
           TextArea(status_labels[status], textprops=dict(size=10))]
    return HPacker(children=row, align='center', pad=0, sep=8)

rows = [legend_row(s, 18 if s in (2.1, 2.2, 2.3) else 0) for s in status_labels]
legend = AnchoredOffsetbox(
    loc='upper right', child=VPacker(children=rows, align='left', pad=0, sep=7),
    pad=0.6, frameon=True, bbox_to_anchor=(1, -0.08),
    bbox_transform=ax.transAxes, borderpad=0)
legend.patch.set_boxstyle('round,pad=0,rounding_size=0.2')
legend.patch.set_edgecolor('0.8')
ax.add_artist(legend)

plt.tight_layout(pad=0.5)
plt.savefig(OUTPUT + '.png', dpi=300, bbox_inches='tight')
plt.savefig(OUTPUT + '.pdf', bbox_inches='tight')
plt.show()
