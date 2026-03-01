class_name GrassSettings
extends Resource

# Probability (0.0–1.0) that any individual grass tile receives a decoration.
@export_range(0.0, 1.0, 0.01) var grassDecorationChance: float = 0.15

# Each entry pairs a tile ID with a relative weight.
# Higher weight = more likely to be chosen. Weights need not sum to 1.0.
@export var grassDecorations: Array[TileDecorationEntry] = []

@export var dirtDecorations: Array[TileDecorationEntry] = []

# Probability that the next step in dirtalizeLine will drift instead of going directly to the goal.
@export_range(0.0, 1.0, 0.01) var dirtalizeDriftChance: float = 0.45;

# Probablility that a tile that is not the center of a dirtalizeSection call is converted to dirt.
@export_range(0.0, 1.0, 0.01) var dirtalizeGroundNotCenterChance: float = 0.2;
