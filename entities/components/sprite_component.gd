class_name SpriteComponent
extends EntityComponent

const TEXTURE_PATH := "res://textures/world.png"

var tileIndex: int
var entityLayer: Node2D
var sprite: Sprite2D
var activeTween: Tween


func _init(layer: Node2D, spriteIndex: int) -> void:
	entityLayer = layer
	tileIndex   = spriteIndex


func onAttached() -> void:
	_buildSprite()
	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover:
		mover.movementCommitted.connect(onMovementCommitted)


func onDetached() -> void:
	if activeTween:
		activeTween.kill()
	if sprite and is_instance_valid(sprite):
		sprite.queue_free()


func _buildSprite() -> void:
	sprite         = Sprite2D.new()
	sprite.texture = _buildAtlasTexture()
	entityLayer.add_child(sprite)
	sprite.position = MoverComponent.tileToPixel(entity.worldPosition)


func _buildAtlasTexture() -> AtlasTexture:
	var atlas  := AtlasTexture.new()
	atlas.atlas = load(TEXTURE_PATH)
	var coords  := Globals.tileIndexToAtlasCoords(tileIndex)
	atlas.region = Rect2(
		coords.x * Globals.TILE_SIZE,
		coords.y * Globals.TILE_SIZE,
		Globals.TILE_SIZE,
		Globals.TILE_SIZE
	)
	return atlas


func onMovementCommitted(from: Vector2, to: Vector2, bZoneChange: bool, newZoneId: int, direction: Vector2i) -> void:
	if activeTween:
		activeTween.kill()
	sprite.position = _entryPixel(to, direction) if bZoneChange else from
	activeTween = entityLayer.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	activeTween.tween_property(sprite, "position", to, MoverComponent.TWEEN_DURATION)
	activeTween.tween_callback(_onTweenFinished)


func _entryPixel(toPixel: Vector2, direction: Vector2i) -> Vector2:
	var ex := toPixel.x
	var ey := toPixel.y
	if   direction.x < 0: ex =  Globals.ZONE_PIXEL_WIDTH  + Globals.TILE_SIZE * 0.5
	elif direction.x > 0: ex = -Globals.TILE_SIZE * 0.5
	if   direction.y < 0: ey =  Globals.ZONE_PIXEL_HEIGHT + Globals.TILE_SIZE * 0.5
	elif direction.y > 0: ey = -Globals.TILE_SIZE * 0.5
	return Vector2(ex, ey)


func _onTweenFinished() -> void:
	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover:
		mover.setMovingComplete()
