class_name SpriteComponent
extends AnimatedSprite2D

const BUMP_DURATION := 0.06

var entity:      Entity
var activeTween: Tween


func _ready() -> void:
	entity = get_parent() as Entity
	if entity == null:
		push_error("SpriteComponent must be a direct child of an Entity node.")
		return
	entity.components[&"SpriteComponent"] = self


func _exit_tree() -> void:
	onDetached()


func onAttached() -> void:
	entity.position = MoverComponent.tileToPixel(entity.worldPosition)
	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover:
		mover.movementCommitted.connect(onMovementCommitted)
		mover.movementBlocked.connect(onMovementBlocked)


func onDetached() -> void:
	if activeTween and is_instance_valid(activeTween):
		activeTween.kill()


func onMovementCommitted(from: Vector2, to: Vector2, bZoneChange: bool, newZoneId: int, direction: Vector2i) -> void:
	if activeTween:
		activeTween.kill()
	entity.position = _entryPixel(to, direction) if bZoneChange else from
	activeTween = entity.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	activeTween.tween_property(entity, "position", to, MoverComponent.TWEEN_DURATION)
	activeTween.tween_callback(_onTweenFinished)
	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover:
		play(_animationName("move", mover.facing))


func _onTweenFinished() -> void:
	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover == null:
		return
	mover.setMovingComplete()
	var inputComp := entity.getComponent(&"PlayerInputComponent") as PlayerInputComponent
	var inputDir  := inputComp.getInputDirection() if inputComp else Vector2i.ZERO
	if inputDir == Vector2i.ZERO:
		play(_animationName("idle", mover.facing))


func onMovementBlocked(direction: Vector2i) -> void:
	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover == null:
		return
	play(_animationName("idle", mover.facing))
	if activeTween:
		activeTween.kill()
	var startPos := entity.position
	var bumpPos  := startPos + Vector2(direction) * Globals.TILE_SIZE * 0.5
	activeTween  = entity.create_tween()
	activeTween.tween_property(entity, "position", bumpPos,  BUMP_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	activeTween.tween_property(entity, "position", startPos, BUMP_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	activeTween.tween_callback(_onBumpFinished)


func _onBumpFinished() -> void:
	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover == null:
		return
	mover.setBumpComplete()
	var inputComp := entity.getComponent(&"PlayerInputComponent") as PlayerInputComponent
	var inputDir  := inputComp.getInputDirection() if inputComp else Vector2i.ZERO
	if inputDir == Vector2i.ZERO:
		play(_animationName("idle", mover.facing))


func _animationName(prefix: String, facing: Globals.EFacing) -> StringName:
	match facing:
		Globals.EFacing.Right: return StringName(prefix + "_right")
		Globals.EFacing.Left:  return StringName(prefix + "_left")
		Globals.EFacing.Up:    return StringName(prefix + "_up")
		_:                     return StringName(prefix + "_down")


func _entryPixel(toPixel: Vector2, direction: Vector2i) -> Vector2:
	var ex := toPixel.x
	var ey := toPixel.y
	if   direction.x < 0: ex =  Globals.ZONE_PIXEL_WIDTH  + Globals.TILE_SIZE * 0.5
	elif direction.x > 0: ex = -Globals.TILE_SIZE * 0.5
	if   direction.y < 0: ey =  Globals.ZONE_PIXEL_HEIGHT + Globals.TILE_SIZE * 0.5
	elif direction.y > 0: ey = -Globals.TILE_SIZE * 0.5
	return Vector2(ex, ey)
