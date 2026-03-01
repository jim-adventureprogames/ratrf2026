extends Node2D

@onready var tileMapLayer:                WorldTileMap = $TileMapLayer
@onready var tileMapLayerGroundDecoration: TileMapLayer = $TileMapLayerGroundDecoration
@onready var tileMapLayerWall:            TileMapLayer = $TileMapLayerWall
@onready var tileMapLayerWallDecoration:  TileMapLayer = $TileMapLayerWallDecoration
@onready var entityLayer:                 Node2D       = $EntityLayer


func _ready() -> void:
	MapManager.worldTileMap            = tileMapLayer
	tileMapLayer.groundDecorationLayer = tileMapLayerGroundDecoration
	tileMapLayer.wallLayer             = tileMapLayerWall
	tileMapLayer.wallDecorationLayer   = tileMapLayerWallDecoration
	GameManager.entityLayer            = entityLayer
