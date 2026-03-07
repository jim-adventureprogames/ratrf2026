class_name ReadableSignComponent
extends EntityComponent

@export var message : String;

func onAttached() -> void:
	super.onAttached()
	var bumpable := entity.getComponent(&"BumpableComponent") as BumpableComponent
	if bumpable:
		bumpable.bumped.connect(_onBumped)
	else:
		push_warning("ReadableSignComponent: no BumpableComponent found on entity '%s'." % entity.name)

func onDetached() -> void:
	var bumpable := entity.getComponent(&"BumpableComponent") as BumpableComponent
	if bumpable and bumpable.bumped.is_connected(_onBumped):
		bumpable.bumped.disconnect(_onBumped)
		
func _onBumped(bumper: Entity) -> void:
	if( bumper == GameManager.playerEntity ) :
		DialogueStateManager.setActiveSignInformation(message);
		GameManager.spawnDialog("sign_dialog", "read_sign", entity);
