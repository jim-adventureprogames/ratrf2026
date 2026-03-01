class_name BumpableComponent
extends EntityComponent

# Emitted when another entity walks into this entity's tile.
# 'by' is the entity that initiated the bump.
signal bumped(by: Entity)


# Called by the bumping entity's MoverComponent.
# Triggers the bumped signal so other components on this entity can react.
func trigger(by: Entity) -> void:
	bumped.emit(by)
