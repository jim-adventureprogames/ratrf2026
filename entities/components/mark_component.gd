# a Mark is an npc that can be bumped by the player and pickpocketed.

class_name MarkComponent
extends AIBehaviorComponent

@export var lootTable: String = "mark_loot_table_01"

# How many turns to keep walking in the same direction before picking a new one.
@export var minStepsInDirection: int = 2
@export var maxStepsInDirection: int = 5

# 0.0–1.0 chance to do nothing on a given turn (still costs AP).
@export var idleChance: float = 0.15

var lootsRemaining: int = 1

var _currentDirection:       Vector2i = Vector2i.ZERO
var _stepsRemainingInDirection: int   = 0

func onAttached() -> void:
	super.onAttached()
	var bumpable := entity.getComponent(&"BumpableComponent") as BumpableComponent
	if bumpable:
		bumpable.bumped.connect(_onBumped)
	else:
		push_warning("MarkComponent: no BumpableComponent found on entity '%s'." % entity.name)
	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover:
		mover.movementBlocked.connect(_onMovementBlocked)


func onDetached() -> void:
	var bumpable := entity.getComponent(&"BumpableComponent") as BumpableComponent
	if bumpable and bumpable.bumped.is_connected(_onBumped):
		bumpable.bumped.disconnect(_onBumped)
	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover and mover.movementBlocked.is_connected(_onMovementBlocked):
		mover.movementBlocked.disconnect(_onMovementBlocked)


# Walking into the same wall twice looks dumb — pick a new direction immediately.
func _onMovementBlocked(_direction: Vector2i) -> void:
	_stepsRemainingInDirection = 0

func _onBumped(by: Entity) -> void:
	var playerCharacter := by.getComponent(&"PlayerCharacterComponent") as PlayerCharacterComponent
	if playerCharacter:
		GameManager.handlePlayerDoPickPocket(playerCharacter, self)

# mugScore is a measure of how risky the attempt was. 
# 0 : from behind
# 1 : from the side
# 2 : head on! 
# returns: success if this mugging is allowed
func onMugAttempt(mugger: PlayerCharacterComponent, mugScore: int) -> bool:
	if( lootsRemaining < 1) :
		return false;
		
	lootsRemaining -= 1;
	updateSpriteBorderByLootability();
	return true;
	
func updateSpriteBorderByLootability() -> void:
	var sprite = entity.getComponent(&"SpriteComponent") as SpriteComponent;
	if sprite:
		sprite.setBorderState( 
			SpriteComponent.ESpriteBorderStyle.has_loot if 
			lootsRemaining > 0 else 
			SpriteComponent.ESpriteBorderStyle.none )

func onEndOfTurn() -> void:
	super();
	updateSpriteBorderByLootability();
	
# Examines the world and picks the best action for this turn.
# Marks walk in one direction for minStepsInDirection–maxStepsInDirection turns,
# then pick a new direction.  Each turn has idleChance to stand still instead.
func decideWhatToDo() -> void:
	nextStepTile      = Vector3i(-1, -1, -1)
	nextStepDirection = Vector2i.ZERO

	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover == null:
		return

	# Random idle — still costs AP, mark just pauses briefly.
	if randf() < idleChance:
		return

	# Time for a new direction?
	if _stepsRemainingInDirection <= 0:
		_pickNewDirection(mover)

	# If the current direction is blocked (wall, entity, or world edge), pick a fresh one now.
	if _currentDirection != Vector2i.ZERO:
		var target := mover.resolveTargetWorldPosition(_currentDirection)
		var bBlocked := target.z < 0 or MapManager.testDestinationTile(target, false) != Globals.EMoveTestResult.OK
		if bBlocked:
			_stepsRemainingInDirection = 0
			_pickNewDirection(mover)

	if _currentDirection == Vector2i.ZERO:
		return

	nextStepDirection            = _currentDirection
	_stepsRemainingInDirection  -= 1


# Shuffles the four cardinals and commits to the first passable one.
# Sets _currentDirection to ZERO and _stepsRemainingInDirection to 0 if none found.
func _pickNewDirection(mover: MoverComponent) -> void:
	var cardinals := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	cardinals.shuffle()
	for dir: Vector2i in cardinals:
		var target := mover.resolveTargetWorldPosition(dir)
		if target.z < 0:
			continue
		_currentDirection          = dir
		_stepsRemainingInDirection = randi_range(minStepsInDirection, maxStepsInDirection)
		return
	# All directions blocked — stay put next turn too.
	_currentDirection          = Vector2i.ZERO
	_stepsRemainingInDirection = 0

func _enter_tree() -> void:
	super._enter_tree()
	updateSpriteBorderByLootability()
