class_name DialogBox_Answer
extends Control

static var _instance: DialogBox_Answer

static func summon() -> DialogBox_Answer:
	return _instance

static func turnOn() -> void:
	if _instance:
		_instance.show()

static func turnOff() -> void:
	if _instance:
		_instance.hide()

@export var imgCharacter: TextureRect
@export var replyPrefab:  PackedScene
@export var vboxReplies:  VBoxContainer

var replies:       Array[DialogReply]
var selectedReply: DialogReply
var selectedIndex: int = -1

signal replyCommitted(reply: DialogReply)


func _ready() -> void:
	_instance    = self
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _input(event: InputEvent) -> void:
	if not visible or replies.is_empty():
		return
	if event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"move_up"):
		_selectByIndex(selectedIndex - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"move_down"):
		_selectByIndex(selectedIndex + 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept"):
		if selectedReply != null:
			replyCommitted.emit(selectedReply)
		get_viewport().set_input_as_handled()


func clearReplies() -> void:
	if selectedReply != null:
		selectedReply.deselect()
	selectedReply = null
	selectedIndex = -1
	for box in replies:
		box.queue_free()
	replies.clear()


func populateFromLine(line: DialogueLine) -> void:
	clearReplies()
	for r: DialogueResponse in line.responses:
		if r.is_allowed:
			addResponse(r.text, r)


func addResponse(text: String, dialogueResponse: DialogueResponse = null) -> void:
	var box := replyPrefab.instantiate() as DialogReply
	box.txtReply.text = text
	box.response      = dialogueResponse
	vboxReplies.add_child(box)
	replies.append(box)
	box.mouse_entered.connect(func(): _onReplyHovered(box))
	box.clicked.connect(func(): replyCommitted.emit(box))
	if replies.size() == 1:
		_selectByIndex(0)


func displayCharacter(entity: Entity) -> void:
	var sprite := entity.getComponent(&"SpriteComponent") as SpriteComponent
	if sprite == null or sprite.sprite_frames == null:
		imgCharacter.texture = null
		return
	imgCharacter.texture = sprite.sprite_frames.get_frame_texture(&"idle_down", 0)


func _selectByIndex(index: int) -> void:
	index = clamp(index, 0, replies.size() - 1)
	if selectedReply != null:
		selectedReply.deselect()
	selectedIndex = index
	selectedReply = replies[selectedIndex]
	selectedReply.select()


func _onReplyHovered(reply: DialogReply) -> void:
	var index := replies.find(reply)
	if index >= 0:
		_selectByIndex(index)
