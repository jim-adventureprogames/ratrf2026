class_name SpriteComponent
extends AnimatedSprite2D

const BUMP_DURATION := 0.06

var entity:           Entity
var activeTween:      Tween
var _savedMaterial:   Material
var _hasEnteredTree:  bool = false

enum ESpriteBorderStyle 
{
	none = 0,
	has_loot = 1,
	observant = 2,
	hostile = 3,
	is_merchant = 4,
	mouse_over = 999
}

var lastSetBorderStyle: ESpriteBorderStyle;

func _initialize() -> void:
	entity = get_parent() as Entity
	if entity == null:
		push_error("SpriteComponent must be a direct child of an Entity node.")
		return
	entity.components[&"SpriteComponent"] = self
	# If the entity is off-tree at init time, park the material so we don't
	# consume shader instance variable slots for entities that aren't rendering.
	if not is_inside_tree() and material != null:
		_savedMaterial = material
		material       = null


func _enter_tree() -> void:
	# Restore the material now that this node will actually be rendered.
	if _savedMaterial != null:
		material       = _savedMaterial
		_savedMaterial = null
		set_instance_shader_parameter("border_state", lastSetBorderStyle)
	if entity != null and _hasEnteredTree:
		# Re-entering the scene tree after remove_child — re-run onAttached so
		# mover signals and sprite position are restored.
		# Deferred so siblings finish _enter_tree and _ready before onAttached runs.
		onAttached.call_deferred()


func _ready() -> void:
	if _hasEnteredTree:
		return
	_hasEnteredTree = true
	_initialize()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		# Park the material so this node stops consuming shader instance slots.
		if material != null:
			_savedMaterial = material
			material       = null


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
		activeTween = null
	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover:
		if mover.movementCommitted.is_connected(onMovementCommitted):
			mover.movementCommitted.disconnect(onMovementCommitted)
		if mover.movementBlocked.is_connected(onMovementBlocked):
			mover.movementBlocked.disconnect(onMovementBlocked)
		if mover.state != MoverComponent.EState.Idle:
			# Tween was killed mid-flight — snap to the actual tile position and
			# reset mover state so the entity is ready to act next turn.
			entity.position = MoverComponent.tileToPixel(entity.worldPosition)
			mover.setMovingComplete()


func onMovementCommitted(from: Vector2, to: Vector2, bZoneChange: bool, newZoneId: int, direction: Vector2i) -> void:
	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if not entity.is_inside_tree():
		# Entity is off-screen — teleport to destination so position is correct
		# if it re-enters the scene tree later, then settle state immediately.
		entity.position = to
		if mover: mover.setMovingComplete()
		return
	if activeTween:
		activeTween.kill()
	entity.position = _entryPixel(to, direction) if bZoneChange else from
	activeTween = entity.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	activeTween.tween_property(entity, "position", to, MoverComponent.TWEEN_DURATION)
	activeTween.tween_callback(_onTweenFinished)
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
	if not entity.is_inside_tree():
		# Entity is off-screen — skip the bump tween and settle state immediately.
		mover.setBumpComplete()
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

func setBorderState(chosenStyle: ESpriteBorderStyle ) -> void:
	lastSetBorderStyle = chosenStyle;
	if is_inside_tree() and material != null:
		set_instance_shader_parameter("border_state", lastSetBorderStyle)

func onHovered() -> void:
	set_instance_shader_parameter("border_state", ESpriteBorderStyle.mouse_over)

func onUnhovered() -> void:
	set_instance_shader_parameter("border_state", lastSetBorderStyle)
