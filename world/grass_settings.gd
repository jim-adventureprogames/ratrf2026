class_name GrassSettings
extends Resource

# Probability (0.0–1.0) that any individual grass tile receives a decoration.
@export_range(0.0, 1.0, 0.01) var grassDecorationChance: float = 0.15

# Each entry pairs a tile ID with a relative weight.
# Higher weight = more likely to be chosen. Weights need not sum to 1.0.
@export var grassDecorations: Array[TileDecorationEntry] = []


@export var dirtDecorations: Array[TileDecorationEntry] = []
