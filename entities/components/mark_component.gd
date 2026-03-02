# a Mark is an npc that can be bumped by the player and pickpocketed.

class_name MarkComponent
extends AIBehaviorComponent

@export var lootTable: String = "mark_loot_table_01"

var lootsRemaining: int = 1;

func onAttached() -> void:
	super.onAttached()
	var bumpable := entity.getComponent(&"BumpableComponent") as BumpableComponent
	if bumpable:
		bumpable.bumped.connect(_onBumped)
	else:
		push_warning("MarkComponent: no BumpableComponent found on entity '%s'." % entity.name)

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
# Currently: choose a random passable adjacent tile to wander into.
func decideWhatToDo() -> void:
	nextStepTile      = Vector3i(-1, -1, -1)
	nextStepDirection = Vector2i.ZERO

	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover == null:
		return

	var cardinals := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	cardinals.shuffle()

	for dir: Vector2i in cardinals:
		var target := mover.resolveTargetWorldPosition(dir)
		if target.z < 0:
			continue
		nextStepTile      = target
		nextStepDirection = dir
		return

func _enter_tree() -> void:
	updateSpriteBorderByLootability();
