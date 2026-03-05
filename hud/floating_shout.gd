class_name FloatingShout
extends Control

enum EShoutType
{
	shout,
	think
}

@export var outerMargin : MarginContainer;
@export var txtMessage : RichTextLabel;
@export var img9Patch : NinePatchRect;
@export var numFrames : int = 2;
@export var timePerFrame : Dictionary[EShoutType,float];
@export var frameWidth : float = 32.0;
@export var frameHeight : float = 32.0;

# How long the shout stays visible before freeing itself.
var lifetime : float = 3.0;

var frameTime : float
var currentFrame : int;

var speaker : Node2D;

var shoutType : EShoutType;


func setMessage(msg : String) -> void:
	if( msg.length() > 7 ):
		outerMargin.custom_minimum_size = Vector2(48.0, 24.0);
	else:
		outerMargin.custom_minimum_size = Vector2(36.0, 24.0);
		
	txtMessage.text = msg;
	
func setShoutType(newType : EShoutType ) -> void:
	shoutType = newType;
	updateSpeechBubbleAnim();
	
func _ready() -> void:
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func attachToSpeaker(target : Node2D) -> void:
	speaker = target;
	position = Vector2(0, -1);
	speaker.add_child(self);
	
func updateSpeechBubbleAnim() -> void: 
	var atlas = img9Patch.texture as AtlasTexture;
	atlas.region = Rect2(frameWidth * currentFrame, frameHeight * (int)(shoutType),
			frameWidth, frameHeight); 
	
func _process(delta: float) -> void:
	frameTime += delta;
	if frameTime > timePerFrame[shoutType]:
		currentFrame += 1;
		currentFrame %= numFrames;
		frameTime -= timePerFrame[shoutType];
		updateSpeechBubbleAnim();
