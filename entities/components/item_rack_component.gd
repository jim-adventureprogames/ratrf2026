class_name ItemRackComponent
extends Sprite2D

var entity:   Entity
var _item:    Item = null

var _hasEnteredTree: bool = false


func _initialize() -> void:
	entity = get_parent() as Entity
	if entity == null:
		push_error("ItemRackComponent must be a direct child of an Entity node.")
		return
	entity.components[&"ItemRackComponent"] = self


func _ready() -> void:
	if _hasEnteredTree:
		return
	_hasEnteredTree = true
	_initialize()


func _enter_tree() -> void:
	if entity != null and _hasEnteredTree:
		onAttached.call_deferred()


func _exit_tree() -> void:
	onDetached()


func onAttached() -> void:
	var bumpable := entity.getComponent(&"BumpableComponent") as BumpableComponent
	if bumpable:
		bumpable.bumped.connect(_onBumped)


func onDetached() -> void:
	var bumpable := entity.getComponent(&"BumpableComponent") as BumpableComponent
	if bumpable and bumpable.bumped.is_connected(_onBumped):
		bumpable.bumped.disconnect(_onBumped)


# Assigns an item to the rack and displays its image.
func assignItem(item: Item) -> void:
	_item   = item
	texture = item.getImage() if item != null else null
	visible = texture != null


# Clears the current item and hides the sprite.
func removeItem() -> void:
	_item   = null
	texture = null
	visible = false


func getItem() -> Item:
	return _item


func _onBumped(_bumper: Entity) -> void:
	pass
