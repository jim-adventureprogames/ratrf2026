extends Node

enum EGamePhase {
	Player,
	Monster,
	EndOfTurnCleanup,
}

# Set by main.gd before startGame() is called.
var entityLayer: Node2D

var playerEntity: Entity
var currentPhase: EGamePhase = EGamePhase.Player


func startGame() -> void:
	generateWorld()
	MapManager.worldTileMap.loadZone(Globals.STARTING_ZONE)
	spawnPlayer()


func generateWorld() -> void:
	WorldGenerator.generateWorld()


func spawnPlayer() -> void:
	playerEntity               = load("res://entity_prefabs/player.tscn").instantiate()
	playerEntity.worldPosition  = Vector3i(
		Globals.ZONE_WIDTH_TILES  / 2,
		Globals.ZONE_HEIGHT_TILES / 2,
		Globals.STARTING_ZONE
	)
	MapManager.registerEntity(playerEntity)
	entityLayer.add_child(playerEntity)

	var mover := playerEntity.getComponent(&"MoverComponent") as MoverComponent
	if mover:
		mover.turnTaken.connect(_onPlayerTurnTaken)


# ── Main loop ────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	match currentPhase:
		EGamePhase.Player:
			_processPlayerPhase()
		EGamePhase.Monster:
			_processMonsterPhase()
		EGamePhase.EndOfTurnCleanup:
			_processEndOfTurnCleanup()


# ── Phase handlers ───────────────────────────────────────────────────────────

func _processPlayerPhase() -> void:
	if playerEntity == null:
		return
	var inputComp := playerEntity.getComponent(&"PlayerInputComponent") as PlayerInputComponent
	if inputComp:
		inputComp.processInput()
	# Phase transition is driven by mover.turnTaken → _onPlayerTurnTaken.


func _onPlayerTurnTaken() -> void:
	currentPhase = EGamePhase.Monster


func _processMonsterPhase() -> void:
	MapManager.processTurn()
	currentPhase = EGamePhase.EndOfTurnCleanup


func _processEndOfTurnCleanup() -> void:
	for entity: Entity in MapManager.entityRegistry.values():
		entity.onEndOfTurn()
	currentPhase = EGamePhase.Player
