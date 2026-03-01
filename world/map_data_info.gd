class_name MapDataInfo
extends Resource

enum EWallColor {
	gray,
	purple,
	red,
	blue,
	green,
	orange,
	light_blue,
}

enum EWallStyle {
	normal,
	cracked,
	dotted,
}


# Tile IDs (flat indices into world.png) that block movement regardless of layer.
# Checked against tile.ground. Set in the editor.
@export var wallTileIds: Dictionary[EWallColor, int] = {}
