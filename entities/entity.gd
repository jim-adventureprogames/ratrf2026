class_name Entity
extends RefCounted

var entityId: int = -1
var worldPosition: Vector3i = Vector3i.ZERO
var components: Dictionary = {}  # StringName → EntityComponent


func addComponent(component: EntityComponent) -> void:
	var key: StringName = component.get_script().get_global_name()
	components[key] = component
	component.entity = self
	component.onAttached()


func getComponent(componentName: StringName) -> EntityComponent:
	return components.get(componentName, null)


func removeComponent(componentName: StringName) -> void:
	var c: EntityComponent = components.get(componentName, null)
	if c:
		c.onDetached()
		components.erase(componentName)


func onTakeTurn() -> void:
	for c: EntityComponent in components.values():
		c.onTakeTurn()
