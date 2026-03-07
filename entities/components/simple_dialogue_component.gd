class_name SimpleDialogueComponent
extends EntityComponent

@export var dialogFile : String;
@export var dialogKey : String;

func onAttached() -> void:
	super.onAttached()
	var bumpable := entity.getComponent(&"BumpableComponent") as BumpableComponent
	if bumpable:
		bumpable.bumped.connect(_onBumped)
	else:
		push_warning("SimpleDialogueComponent: no BumpableComponent found on entity '%s'." % entity.name)

func onDetached() -> void:
	var bumpable := entity.getComponent(&"BumpableComponent") as BumpableComponent
	if bumpable and bumpable.bumped.is_connected(_onBumped):
		bumpable.bumped.disconnect(_onBumped)
		
func _onBumped(bumper: Entity) -> void:
	GameManager.spawnDialog(dialogFile, dialogKey, entity);
