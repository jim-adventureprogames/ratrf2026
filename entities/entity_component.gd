class_name EntityComponent
extends Node

# Set in _initialize() when this component is linked to its parent Entity.
var entity: Entity


# Registers this component with its parent Entity.  Called explicitly by Entity._initialize()
# so that off-tree entities (spawned before entering the scene) still set up correctly.
func _initialize() -> void:
	entity = get_parent() as Entity
	if entity == null:
		push_error("EntityComponent '%s' must be a direct child of an Entity node." % name)
		return
	entity.components[get_script().get_global_name()] = self


func _ready() -> void:
	_initialize()


func _exit_tree() -> void:
	onDetached()


# Called by Entity._initialize() after all sibling components have registered themselves.
# Use this to connect signals to sibling components via entity.getComponent().
func onAttached() -> void:
	pass


# Called when this component leaves the scene tree (queue_free or parent freed).
# Use this to disconnect signals and free any manually created resources.
func onDetached() -> void:
	pass


# Called by MapManager.processTurn() via Entity.onTakeTurn().
# Override in AI or behaviour components.
func onTakeTurn() -> void:
	pass


# Called by GameManager at the end of every turn for all entities.
# Override to reset per-turn state, trigger passive effects, etc.
func onEndOfTurn() -> void:
	pass
