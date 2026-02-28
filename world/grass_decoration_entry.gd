@tool
class_name GrassDecorationEntry
extends Resource

const TILE_SIZE              := 12
const TILESET_WIDTH_TILES    := 23
const TILESET_TEXTURE_PATH   := "res://textures/world.png"

@export_group("Settings")
@export var tileId: int = 0:
	set(value):
		tileId = value
		refreshPreview()
@export var weight: float = 1.0

# Backing variable — exposed read-only in the inspector via _get_property_list().
var preview: AtlasTexture


func _get_property_list() -> Array[Dictionary]:
	return [
		{
			"name":        "preview",
			"type":        TYPE_OBJECT,
			"usage":       PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY,
			"hint":        PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "AtlasTexture"
		}
	]


func refreshPreview() -> void:
	if not Engine.is_editor_hint():
		return
	var texture := load(TILESET_TEXTURE_PATH) as Texture2D
	if texture == null:
		preview = null
		return
	var atlas      := AtlasTexture.new()
	atlas.atlas     = texture
	var col         := tileId % TILESET_WIDTH_TILES
	var row         := tileId / TILESET_WIDTH_TILES
	atlas.region    = Rect2(col * TILE_SIZE, row * TILE_SIZE, TILE_SIZE, TILE_SIZE)
	preview         = atlas
	emit_changed()
