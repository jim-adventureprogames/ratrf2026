class_name AudioData
extends Resource

# Background music tracks available for random playback.
# Populate this array in the AudioData.tres inspector.
@export var BackgroundMusic: Array[AudioStream] = []

# Short grumble/react sounds played when a guard soft-detects a crime.
@export var GuardGrumbles: Array[AudioStream] = []

# Music tracks played (looping) while guards are in active pursuit.
# One is chosen at random when Alart state begins.
@export var AlartMusic: Array[AudioStream] = []

# Oh no we're in a tense discussion
@export var TensionMusic: Array[AudioStream] = []

# One-shot bark played by a guard the moment they decide to chase the player.
@export var AlartBark: AudioStream

# Played on the game-over screen for both victory and defeat.
@export var GameOverMusic: AudioStream

# Played on the title screen.
@export var TitleScreenMusic: AudioStream
