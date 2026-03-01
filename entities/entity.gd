class_name Entity
extends Node2D

# Assigned by MapManager.registerEntity(). -1 until registered.
var entityId: int = -1

# x/y = tile coordinates within the zone, z = zone ID.
var worldPosition: Vector3i = Vector3i.ZERO

# Keyed by each component's script global class name as a StringName.
# Components register themselves here in their own _initialize().
var components: Dictionary = {}

# Guard so _initialize() is idempotent — safe to call from both _ready()
# (in-tree entities) and MapManager.registerEntity() (off-tree entities).
var _initialized: bool = false


# Initializes all child components and fires onAttached() on each.
# Called automatically by _ready() when the entity enters the scene tree,
# and explicitly by MapManager.registerEntity() for off-tree entities.
func _initialize() -> void:
	if _initialized:
		return
	_initialized = true
	for child in get_children():
		if child.has_method("_initialize"):
			child._initialize()
	for child in get_children():
		if child.has_method("onAttached"):
			child.onAttached()


func _ready() -> void:
	_initialize()


# Adds a component node at runtime (entity already in the scene tree).
# For scene-defined components, addComponent is not needed — they wire
# themselves up automatically via their _ready() and this entity's _ready().
func addComponent(component: Node) -> void:
	add_child(component)
	if is_inside_tree() and component.has_method("onAttached"):
		component.onAttached()


func getComponent(componentName: StringName) -> Node:
	return components.get(componentName, null)


func removeComponent(componentName: StringName) -> void:
	var c: Node = components.get(componentName, null)
	if c:
		components.erase(componentName)
		c.queue_free()


func onTakeTurn() -> void:
	for c in components.values():
		if c.has_method("onTakeTurn"):
			c.onTakeTurn()


func onEndOfTurn() -> void:
	for c in components.values():
		if c.has_method("onEndOfTurn"):
			c.onEndOfTurn()
