extends Node

enum EGamePhase {
	Player,
	Monster,
	EndOfTurnCleanup,
}

enum EGameState {
	MainMenu,
	Gameplay,
	GameOver,
}

# Set by main.gd before startGame() is called.
var entityLayer: Node2D

var playerEntity:        Entity
var currentPhase:        EGamePhase             = EGamePhase.Player

var gameState:			 EGameState				= EGameState.MainMenu

# All AI components in the world, registered when their entity is registered.
var aiComponents:        Array[AIBehaviorComponent] = []

# AIs that still need to finish their action this turn.
# Populated at the start of each Monster phase; shrinks as AIs report done.
var pendingAIComponents: Array[AIBehaviorComponent] = []


func startGame() -> void:
	generateWorld()
	spawnPlayer()
	_spawnDebugMarks()
	HUDMiniMap.summon().populate();
	HUDMiniMap.summon().setPlayerZone(playerEntity.worldPosition.z);
	MapManager.worldTileMap.loadZone(playerEntity.worldPosition.z)
	gameState = EGameState.Gameplay;


func generateWorld() -> void:
	WorldGenerator.generateWorld()


func _pickPlayerSpawn() -> Vector3i:
	var points: Array = MapManager.spawnPoints.get("player", [])
	if points.is_empty():
		push_warning("GameManager: no 'player' spawn points found, falling back to zone centre.")
		return Vector3i(
			Globals.ZONE_WIDTH_TILES  / 2,
			Globals.ZONE_HEIGHT_TILES / 2,
			Globals.STARTING_ZONE
		)
	return points[randi() % points.size()]


func spawnPlayer() -> void:
	playerEntity               = load("res://entity_prefabs/player.tscn").instantiate()
	playerEntity.worldPosition  = _pickPlayerSpawn()
	MapManager.registerEntity(playerEntity)
	entityLayer.add_child(playerEntity)

	var mover := playerEntity.getComponent(&"MoverComponent") as MoverComponent
	if mover:
		mover.turnTaken.connect(_onPlayerTurnTaken)
		mover.zoneCrossed.connect(_onPlayerZoneChanged)


# ── Debug helpers ────────────────────────────────────────────────────────────

func _spawnDebugMarks() -> void:
	var packed := load("res://entity_prefabs/mark.tscn") as PackedScene
	if packed == null:
		push_error("GameManager: could not load mark.tscn")
		return

	# Spawn marks in every zone.
	for zone: Zone in MapManager.zones:
		_spawnDebugMarksInZone(packed, zone.id, 6)


func _spawnDebugMarksInZone(packed: PackedScene, zoneId: int, count: int) -> void:
	var inset    := WorldGenerator.WALL_INSET + 1
	var spawned  := 0
	var attempts := 0
	while spawned < count and attempts < 200:
		attempts += 1
		var x        := randi_range(inset, Globals.ZONE_WIDTH_TILES  - 1 - inset)
		var y        := randi_range(inset, Globals.ZONE_HEIGHT_TILES - 1 - inset)
		var worldPos := Vector3i(x, y, zoneId)
		if MapManager.testDestinationTile(worldPos, false) != Globals.EMoveTestResult.OK:
			continue
		var mark := packed.instantiate() as Entity
		if mark == null:
			continue
		mark.worldPosition = worldPos
		MapManager.applySpawnVariant(mark)
		MapManager.registerEntity(mark)
		spawned += 1


# ── Player actions ───────────────────────────────────────────────────────────

func handlePlayerDoPickPocket(attacker: PlayerCharacterComponent, victim: MarkComponent) -> void:
	pass


# ── AI registration ───────────────────────────────────────────────────────────

func registerAIComponent(ai: AIBehaviorComponent) -> void:
	if not aiComponents.has(ai):
		aiComponents.append(ai)


func unregisterAIComponent(ai: AIBehaviorComponent) -> void:
	aiComponents.erase(ai)
	pendingAIComponents.erase(ai)


# ── Main loop ─────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	match gameState:
		EGameState.MainMenu:
			#wait
			_processMainMenu(_delta);
		EGameState.Gameplay:
			_processMainGameplay(_delta);

func _processMainMenu(_delta: float) -> void:
	pass

func _processMainGameplay(_delta: float) -> void:
	match currentPhase:
		EGamePhase.Player:
			_processPlayerPhase()
		EGamePhase.Monster:
			_processMonsterPhase()
		EGamePhase.EndOfTurnCleanup:
			_processEndOfTurnCleanup()

# ── Phase handlers ────────────────────────────────────────────────────────────

func _processPlayerPhase() -> void:
	if playerEntity == null:
		return
	var inputComp := playerEntity.getComponent(&"PlayerInputComponent") as PlayerInputComponent
	if inputComp:
		inputComp.processInput()
	# Phase transition is driven by mover.turnTaken → _onPlayerTurnTaken.


func _onPlayerTurnTaken() -> void:
	# Snapshot all AIs into the pending list for this turn.
	pendingAIComponents = aiComponents.duplicate()
	currentPhase = EGamePhase.Monster


func _onPlayerZoneChanged(newZoneId: int) -> void:
	HUDMiniMap.summon().setPlayerZone(newZoneId)


func _processMonsterPhase() -> void:
	# Each frame, give every pending AI a chance to act.
	# Remove ones that report done (true); keep ones still busy (false).
	# The phase holds here across as many frames as needed until all are done.
	var i := pendingAIComponents.size() - 1
	while i >= 0:
		if pendingAIComponents[i].takeAction():
			pendingAIComponents.remove_at(i)
		i -= 1

	if pendingAIComponents.is_empty():
		currentPhase = EGamePhase.EndOfTurnCleanup


func _processEndOfTurnCleanup() -> void:
	for entity: Entity in MapManager.entityRegistry.values():
		entity.onEndOfTurn()
	currentPhase = EGamePhase.Player
