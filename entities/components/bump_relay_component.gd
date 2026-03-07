class_name BumpRelayComponent
extends EntityComponent

# The entity whose BumpableComponent will receive forwarded bumps.
var _relayTarget: Entity = null


func onAttached() -> void:
	super.onAttached()
	var bumpable := entity.getComponent(&"BumpableComponent") as BumpableComponent
	if bumpable:
		bumpable.bumped.connect(_onBumped)
	else:
		push_warning("BumpRelayComponent: no BumpableComponent on entity '%s'." % entity.name)


func onDetached() -> void:
	var bumpable := entity.getComponent(&"BumpableComponent") as BumpableComponent
	if bumpable and bumpable.bumped.is_connected(_onBumped):
		bumpable.bumped.disconnect(_onBumped)


# Sets the entity that will receive forwarded bumps.
func setRelayTarget(target: Entity) -> void:
	_relayTarget = target


func _onBumped(by: Entity) -> void:
	if _relayTarget == null:
		return
	var bumpable := _relayTarget.getComponent(&"BumpableComponent") as BumpableComponent
	if bumpable:
		bumpable.trigger(by)
		
func onPostStampCleanup(stampedEntities: Array[Entity], properties: Dictionary) -> void:
	var targetName := String(properties.get("relay_target", ""))
	if targetName.is_empty():
		return
	for peer: Entity in stampedEntities:
		if peer.name == targetName:
			setRelayTarget(peer)
			return
