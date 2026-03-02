class_name GuardComponent
extends AIBehaviorComponent

# Tile radius from anchor point within which the guard is considered "at home".
@export var centerRadius:          float   = 6.0

# Consecutive turns outside centerRadius before movement is weighted
# back toward the anchor point.
@export var turnsAwayBeforeReturn: int     = 12

# Anchor tile for guarding_location mode (x/y within the zone).
@export var guardLocation:         Vector2i = Vector2i.ZERO

var _turnsAwayFromCenter: int = 0
var targetEntity: Entity;

func _enter_tree() -> void:
	updateSpriteBorderByBehavior();

func onEndOfTurn() -> void:
	super();
	updateSpriteBorderByBehavior();

func onAttached() -> void:
	behaviorFlags |= EBehaviorFlags.observing;

func onDecideChaseCriminal(criminal: Entity) -> void:
	targetEntity = criminal
	if targetEntity:
		behaviorFlags &= ~EBehaviorFlags.observing
		behaviorFlags |= EBehaviorFlags.chasing_entity
	else:
		behaviorFlags &= ~EBehaviorFlags.chasing_entity
		behaviorFlags |= EBehaviorFlags.observing


# Examines the world and picks the best action for this turn.
# guarding_zone:     anchor = zone centre; zone-crossing moves are blocked.
# guarding_location: anchor = guardLocation; zone-crossing moves are blocked.
# Both flags apply the same radius/threshold pull back toward their anchor.
func decideWhatToDo() -> void:
	nextStepTile      = Vector3i(-1, -1, -1)
	nextStepDirection = Vector2i.ZERO

	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover == null:
		return

	var cardinals := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	cardinals.shuffle()

	if _isZoneLocked():
		_updateCenterTracking()
		if _turnsAwayFromCenter >= turnsAwayBeforeReturn:
			cardinals.sort_custom(_preferCenterDirection)

	for dir: Vector2i in cardinals:
		var target := mover.resolveTargetWorldPosition(dir)
		if target.z < 0:
			continue
		if _isZoneLocked() and target.z != entity.worldPosition.z:
			continue
		nextStepTile      = target
		nextStepDirection = dir
		return


func _updateCenterTracking() -> void:
	var guardPos := Vector2(entity.worldPosition.x, entity.worldPosition.y)
	if guardPos.distance_to(_activeCenter()) <= centerRadius:
		_turnsAwayFromCenter = 0
	else:
		_turnsAwayFromCenter += 1


# Sort comparator: directions that move the guard closer to the anchor sort first.
func _preferCenterDirection(a: Vector2i, b: Vector2i) -> bool:
	var center := _activeCenter()
	var distA  := Vector2(entity.worldPosition.x + a.x, entity.worldPosition.y + a.y).distance_to(center)
	var distB  := Vector2(entity.worldPosition.x + b.x, entity.worldPosition.y + b.y).distance_to(center)
	return distA < distB


# Returns the anchor point for whichever guarding mode is active.
# guarding_location takes priority if both flags are somehow set.
func _activeCenter() -> Vector2:
	if behaviorFlags & EBehaviorFlags.guarding_location:
		return Vector2(guardLocation)
	return Vector2(Globals.ZONE_WIDTH_TILES * 0.5, Globals.ZONE_HEIGHT_TILES * 0.5)


# True when either guarding flag is set — zone crossing is blocked for both.
func _isZoneLocked() -> bool:
	return behaviorFlags & (EBehaviorFlags.guarding_zone | EBehaviorFlags.guarding_location)


func updateSpriteBorderByBehavior() -> void:
	var sprite = entity.getComponent(&"SpriteComponent") as SpriteComponent
	if sprite:
		if behaviorFlags & EBehaviorFlags.chasing_entity:
			sprite.setBorderState(SpriteComponent.ESpriteBorderStyle.hostile)
		elif behaviorFlags & EBehaviorFlags.observing:
			sprite.setBorderState(SpriteComponent.ESpriteBorderStyle.observant)
		else:
			sprite.setBorderState(SpriteComponent.ESpriteBorderStyle.none)
