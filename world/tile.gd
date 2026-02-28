class_name Tile
extends RefCounted

const EMPTY_TILE := -1

# Render layers, bottom to top.
# Each value is a flat tile index into world.png: (atlasY * TILESET_WIDTH_TILES + atlasX).
# EMPTY_TILE (-1) means the layer is unused.
var ground:           int = EMPTY_TILE
var groundDecoration: int = EMPTY_TILE
var wall:             int = EMPTY_TILE
var wallDecoration:   int = EMPTY_TILE

# Entities currently occupying this tile (characters, items, interactables, etc.)
var entities: Array[Entity] = []
