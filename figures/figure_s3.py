# ==============================================================================
# Paper:   Food additives in the U.S. food supply: Regulatory divergence,
#          market concentration, and exposure patterns
#
# Authors: Sevval Buse Sariman, Jeta Rudi-Polloshka, David R. Just,
#          Vincenzina Caputo
#
# Code:    Sevval Buse Sariman
#
# Purpose: Draws SI Figure S3 on state food-additive bills:
#            (A) U.S. map: number of additives covered by each state's passed
#                bills (orange shading) and states with pending bills (blue
#                circles)
#            (B) Number of state bills that include each additive
#
# Output:  figure_s3.png and figure_s3.pdf
# ==============================================================================

from pathlib import Path

import kaleido
import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots

OUTPUT = Path(".../figure_s3") 

# 1. Data
bills = pd.DataFrame(
    [
        # State, Not_passed, Pending, Passed, Additives_passed
        ("Alabama",        2, 0, 0,  0),
        ("Alaska",         1, 0, 0,  0),
        ("Arizona",        0, 0, 1, 11),
        ("Arkansas",       1, 0, 1,  2),
        ("California",     0, 0, 3, 10),
        ("Connecticut",    4, 0, 0,  0),
        ("Delaware",       0, 1, 1,  1),
        ("Florida",        6, 0, 0,  0),
        ("Georgia",        0, 1, 0,  0),
        ("Hawaii",         1, 1, 0,  0),
        ("Illinois",       1, 2, 0,  0),
        ("Indiana",        3, 4, 0,  0),
        ("Iowa",           1, 0, 0,  0),
        ("Kansas",         0, 1, 0,  0),
        ("Kentucky",       2, 1, 0,  0),
        ("Louisiana",      1, 1, 0,  0),
        ("Maryland",       2, 0, 0,  0),
        ("Massachusetts",  0, 3, 0,  0),
        ("Michigan",       0, 4, 0,  0),
        ("Minnesota",      1, 0, 0,  0),
        ("Missouri",       3, 4, 0,  0),
        ("Nebraska",       0, 1, 0,  0),
        ("New Hampshire",  0, 1, 0,  0),
        ("New Jersey",     1, 3, 0,  0),
        ("New York",       6, 7, 0,  0),
        ("North Carolina", 0, 2, 0,  0),
        ("Ohio",           0, 1, 0,  0),
        ("Oklahoma",       1, 1, 0,  0),
        ("Oregon",         1, 0, 0,  0),
        ("Pennsylvania",   2, 4, 0,  0),
        ("Rhode Island",   2, 0, 0,  0),
        ("South Carolina", 1, 2, 0,  0),
        ("South Dakota",   1, 0, 0,  0),
        ("Tennessee",      0, 0, 1,  1),
        ("Texas",          6, 5, 2, 45),
        ("Utah",           0, 0, 1,  9),
        ("Vermont",        2, 0, 0,  0),
        ("Virginia",       0, 0, 1,  7),
        ("Washington",     2, 0, 0,  0),
        ("West Virginia",  2, 1, 1,  9),
        ("Wisconsin",      1, 1, 0,  0),
    ],
    columns=["State", "Not_passed", "Pending", "Passed", "Additives_passed"],
)
additive_bills = pd.DataFrame(
    [
        ("Red dye no. 3",            85),
        ("Red dye no. 40",           78),
        ("Blue dye no. 1",           75),
        ("Yellow dye no. 6",         75),
        ("Yellow dye no. 5",         73),
        ("Blue dye no. 2",           71),
        ("Green dye no. 3",          68),
        ("Propylparaben",            68),
        ("Potassium bromate",        65),
        ("Brominated Vegetable Oil", 54),
        ("Titanium dioxide",         40),
        ("BHA",                      26),
        ("Azodicarbonamide",         18),
        ("BHT",                      14),
        ("Citrus red no. 2",          7),
    ],
    columns=["Additive", "Bills"],
)

# State abbreviation and a point inside each state (for the blue circles)
STATES = {
    "Alabama": ("AL", -86.90, 32.32), "Alaska": ("AK", -152.40, 61.37),
    "Arizona": ("AZ", -111.43, 33.73), "Arkansas": ("AR", -92.37, 34.75),
    "California": ("CA", -119.42, 36.78), "Connecticut": ("CT", -72.76, 41.60),
    "Delaware": ("DE", -75.51, 38.91), "Florida": ("FL", -81.52, 27.66),
    "Georgia": ("GA", -83.50, 32.17), "Hawaii": ("HI", -157.50, 21.09),
    "Illinois": ("IL", -89.40, 40.63), "Indiana": ("IN", -86.13, 40.27),
    "Iowa": ("IA", -93.10, 41.88), "Kansas": ("KS", -98.48, 38.53),
    "Kentucky": ("KY", -84.87, 37.84), "Louisiana": ("LA", -91.96, 30.98),
    "Maryland": ("MD", -76.64, 39.05), "Massachusetts": ("MA", -71.38, 42.41),
    "Michigan": ("MI", -84.54, 44.31), "Minnesota": ("MN", -94.69, 46.73),
    "Missouri": ("MO", -92.60, 37.96), "Nebraska": ("NE", -99.90, 41.49),
    "New Hampshire": ("NH", -71.57, 43.19), "New Jersey": ("NJ", -74.41, 40.06),
    "New York": ("NY", -75.53, 43.30), "North Carolina": ("NC", -79.02, 35.76),
    "Ohio": ("OH", -82.91, 40.42), "Oklahoma": ("OK", -97.09, 35.01),
    "Oregon": ("OR", -120.55, 43.80), "Pennsylvania": ("PA", -77.19, 41.20),
    "Rhode Island": ("RI", -71.48, 41.58), "South Carolina": ("SC", -81.16, 33.84),
    "South Dakota": ("SD", -100.30, 44.37), "Tennessee": ("TN", -86.58, 35.52),
    "Texas": ("TX", -99.90, 31.97), "Utah": ("UT", -111.09, 39.32),
    "Vermont": ("VT", -72.58, 44.56), "Virginia": ("VA", -78.66, 37.43),
    "Washington": ("WA", -120.74, 47.75), "West Virginia": ("WV", -80.45, 38.60),
    "Wisconsin": ("WI", -89.62, 43.78),
}
bills["abbr"] = bills["State"].map(lambda s: STATES[s][0])
bills["lon"] = bills["State"].map(lambda s: STATES[s][1])
bills["lat"] = bills["State"].map(lambda s: STATES[s][2])
pending = bills[bills["Pending"] > 0]

# 2. Figure: map on top (A), bars below (B)
fig = make_subplots(
    rows=2, cols=1,
    specs=[[{"type": "geo"}], [{"type": "xy"}]],
    row_heights=[0.52, 0.48],
    vertical_spacing=0.06,
)

# (A) Orange shading: number of additives covered by passed bills
fig.add_trace(go.Choropleth(
    locations=bills["abbr"],
    locationmode="USA-states",
    z=bills["Additives_passed"],
    zmin=0,
    zmax=bills["Additives_passed"].max(),
    colorscale="Oranges",
    marker_line_color="white",
    marker_line_width=0.5,
    colorbar=dict(title="Additive Counts<br>in Passed Bills<br>&nbsp;",
                  len=0.4, y=0.78, x=0.85, thickness=15),
    showlegend=False,
), row=1, col=1)

# (A) Blue circles: states with pending bills
fig.add_trace(go.Scattergeo(
    lon=pending["lon"],
    lat=pending["lat"],
    mode="markers",
    marker=dict(size=6, color="blue", line=dict(color="black", width=0.5)),
    name="Pending bills",
), row=1, col=1)

# (B) Bills per additive
fig.add_trace(go.Bar(
    x=additive_bills["Bills"],
    y=additive_bills["Additive"],
    orientation="h",
    marker_color="#EE7733",
    text=additive_bills["Bills"],
    textposition="outside",
    textfont=dict(family="Arial", size=10.67, color="black"),
    showlegend=False,
), row=2, col=1)

fig.update_geos(scope="usa", projection_type="albers usa",
                showlakes=True, lakecolor="white",
                domain=dict(x=[0, 0.86], y=[0.58, 1]))
fig.update_yaxes(autorange="reversed", ticks="", showline=False, showgrid=False,
                 ticksuffix="  ",                       # space before the bars
                 tickfont=dict(family="Arial", size=10.67, color="black"), row=2, col=1)
fig.update_xaxes(visible=False, range=[0, additive_bills["Bills"].max() * 1.08],
                 row=2, col=1)
fig.update_layout(
    plot_bgcolor="white",   # white background for the bars; the map keeps its colors
    bargap=0.25,
    legend=dict(orientation="h", x=0.43, xanchor="center", y=0.565, yanchor="top"),
    margin=dict(l=10, r=10, t=20, b=10),
    font=dict(family="Arial", size=10.67, color="black"),
)

for letter, y in [("(A)", 1.0), ("(B)", 0.48)]:
    fig.add_annotation(text=letter, x=0, y=y, xref="paper", yref="paper",
                       xanchor="left", yanchor="bottom", showarrow=False,
                       font=dict(family="Arial", size=12, color="black"))

# 3. Save
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
kaleido.write_fig_sync(fig, path=OUTPUT.with_suffix(".png"),
                       opts=dict(width=672, height=700, scale=3.125))
kaleido.write_fig_sync(fig, path=OUTPUT.with_suffix(".pdf"),
                       opts=dict(width=672, height=700))
