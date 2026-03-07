# Session Notes

---

## 2026-03-06 (session 2)

### Accomplished

**SellToVendorTransaction** (`gamesystems/sell_to_vendor_transaction.gd` — new)
- `RefCounted`; signal `stagedItemsChanged`; `valueMultiplier: float` (0.0 = no change, 0.2 = +20%, -0.2 = -20%)
- `addItem()`, `removeItem()`, `isStaged()`, `getStagedItems()`
- `getBaseValue()`, `getTotalValue()` (applies multiplier, clamps to 0)
- `cancel()` clears + emits; `complete(inventory)` pays out, removes items, emits, returns payout int

**HUD_SellToMerchant** (`hud/hud_sell_to_merchant.gd` — new)
- Static singleton (`summon()`); `beginTransaction(inventory, transaction)` sets Merchant phase + shows
- `gridSoldItems` shows staged items; right-clicking a slot calls `_transaction.removeItem(item)`
- `txtValue` live-updates; `txtBonus` shows multiplier % with BBCode color (#6688ff positive / #ff5555 negative)
- `applyHaggleResult(newMultiplier)` — pushes haggle outcome into live transaction + refreshes labels
- `isItemStaged(item) -> bool` — used by main inventory grid for dimming
- `turnOff()` restores Player phase; `_onTransactionChanged()` also calls `mainHud.inventoryGrid.refresh()`

**Right-click to stage from main inventory**
- `ItemDisplayContainer`: `signal item_right_clicked(item)` + `_gui_input` handler
- `InventoryGrid`: `signal item_right_clicked(item)`; `refresh()` connects slot signal with `.emit`
- `HUD_Main._ready()`: connects `inventoryGrid.item_right_clicked` → `_onInventoryItemRightClicked`; handler checks `sellHud.visible` before forwarding

**50% alpha for staged items**
- `ItemDisplayContainer.setDimmed(bool)` → `modulate.a = 0.5 or 1.0`
- `InventoryGrid.shouldDimItem: Callable` predicate; evaluated per slot in `refresh()`
- Predicate set in `HUD_Main._ready()` as lambda referencing `HUD_SellToMerchant.summon()`

**HUD_CoinFlipContest mouse filter**
- `_ready()` and `turnOff()`: `mouse_filter = MOUSE_FILTER_IGNORE`
- `turnOn()`: `mouse_filter = MOUSE_FILTER_STOP`

**Haggle result → transaction**
- `challenge_manager.gd` `"haggle_merchant"` branch: after `onHaggleSuccess/Fail()`, calls `HUD_SellToMerchant.summon().applyHaggleResult(mc.haggleMultiplier)`

**BumpRelayComponent** (`entities/components/bump_relay_component.gd`)
- Connects to entity's `BumpableComponent.bumped` signal in `onAttached()`
- `setRelayTarget(entity)` sets relay; `_onBumped(by)` looks up `BumpableComponent` on target and calls `trigger(by)`
- `onPostStampCleanup()`: reads `relay_target` property from TMX, matches by `peer.name`, calls `setRelayTarget()`

**postStampCleanup system**
- `EntityComponent.onPostStampCleanup(stampedEntities, properties)` — new virtual
- `Entity.postStampCleanup(stampedEntities, properties)` — duck-typed dispatch to all components
- `MapManager.stampTmx()`: all objectgroups processed (removed `== "spawn"` name restriction); per-object `spawnProps` dict collected; after parse, calls `postStampCleanup` on each stamped entity with full peer list + its own TMX properties
- `_spawnEntityFromPrefab` return type changed `void` → `Entity`

**Building stamping in gate zones**
- `MapManager.getTmxSize(tmxName)` — parses `<map>` header only, returns `Vector2i`
- `MapManager.findClearRectInZone(zoneId, w, h, faireBounds)` — shuffled candidates, returns first clear position
- `MapManager._isTileClearForBuilding(tile)` — rejects wall, paved ground, or dirt decoration tiles
- `WorldGenerator._stampBuildings()` — called from `generateWorld()`; iterates `gateZoneIds`
- `WorldGenerator._getFaireInteriorBounds(zoneId)` — clips search area to inside perimeter walls using `WALL_INSET`; edge zones only restricted on their outer sides

**deco_pennant directional variants**
- `entity_prefabs/deco_pennant_east.tscn` — row 1 (y=12), 11 frames
- `entity_prefabs/deco_pennant_south.tscn` — row 2 (y=24), 11 frames
- `entity_prefabs/deco_pennant_west.tscn` — row 3 (y=36), 11 frames
- All: `decoration_objects.png`, 12 fps, loop, BlocksMovementComponent + AnimatedSprite2D(SpriteComponent)
- West TMX (`entrance_gate_west.tmx`) already referenced `deco_pennant_west` (pre-updated by user)

### Gotchas
- `postStampCleanup` peers matched by `entity.name` (Node name, not a custom property) — scene root node name must be unique within a stamp if relay_target lookup is used
- `_isTileClearForBuilding` rejects paved ground tiles by checking `MapDataInfo.wallTileIds` — verify this dict contains the right tile IDs as more tile types are added
- All objectgroups in TMX are now processed (not just `name="spawn"`); building TMX files can use any objectgroup name

### In Progress / Open Decisions (carry-forward from prior sessions)
- **AlartBark audio** — needs audio file assigned in inspector
- **Game over screen** — `goToGameOver()` still skips to `resetForNewGame()` immediately
- **`getPlayerComponent()` bug** — `game_manager.gd` ~line 653: `getComponent("&PlayerCharacterComponent")` should be `getComponent(&"PlayerCharacterComponent")`
- **South/west/east gates** — WorldGenerator only places north gate; `_stampBuildings` iterates `gateZoneIds` which currently may only have the north gate zone
- **LOS for guard sight** — no wall occlusion yet

---

## 2026-03-06

### Accomplished

**Guard Alert System**
- Added `signal cancelGuardAlert` to `GameManager`; guards subscribe on `registerAIComponent`, unsubscribe on `unregisterAIComponent`
- `GuardComponent.onCancelAlert()` zeroes alertLevel and cancels chase/follow/investigate states
- When a chasing guard zone-crosses into the player's zone, `_alertGuardsInZone()` fires — all non-chasing guards in that zone start chasing too

**CrimeManager Chase Mode**
- New fields: `bChaseMode`, `chaseAlertValue` (0–100 float), `_bPlayerSeenThisTurn`, constants `CHASE_ALERT_DECAY=10.0`, `CHASE_MAX_ALART=100.0`
- `enterChaseMode()` — sets state + emits `signal chaseStarted` only on first entry
- `reportPlayerSighted() -> bool` — returns true only if first re-sighting after an unseen turn; guards use this to fire information arrows without spamming
- `onEndOfTurn()` — decays alart value; at 0, exits chase mode and emits `GameManager.cancelGuardAlert`
- `_onCancelGuardAlert()` — zeroes all chase state, calls `HUD_Main.summon().updateAlartMeter()`

**AlartMeter HUD**
- User-added `AlartMeter` Control + `progressBar` TextureProgressBar wired via exports in `hud_main.gd`
- `updateAlartMeter()` called from: `_onTurnAdvanced`, `_onChaseStarted`, `resetForNewGame`, `_onCancelGuardAlert`

**RedInformationArrow**
- `hud/red_information_arrow.gd` — `_process`-driven lerp from source to target; rotates to face target; dismisses on zone change
- Uses `global_position` of target entity for smooth tracking across tile tweens
- `GameManager.spawnInformationArrow(entitySource, entityTarget, moveDuration, waitDuration)`
- Fires when guard starts chasing player, or re-spots player after unseen turn (`reportPlayerSighted` returns true)
- Constants: `ARROW_MOVE_DURATION=0.35`, `ARROW_WAIT_DURATION=1.2`

**AudioManager** (`audio/scripts/audio_manager.gd` — new autoload)
- Two `AudioStreamPlayer` children on "Music" bus; crossfade via parallel Tween; `_swapPlayers()` after fade
- `EMusicState` enum: None (default), Normal, Alart, MainMenu, Victory, Defeat, Romance
- `EMusicState.None` prevents early-return guard from blocking the first `setMusicState(Normal)` call
- Normal mode: random track from BackgroundMusic; 3-min timer rotates with crossfade; fade-in from silence vs crossfade if already playing
- Alart mode: instant stop → 3s SceneTreeTimer → random AlartMusic track instant-play
- `playAlartBark()`, `playRandomGuardGrumble()`, `playSfx()` (one-shot on SFX bus)
- Console prints all state changes and track start/stop/fade events
- Started from `GameManager.startGame()`

**AudioData** (`audio/scripts/audio_data.gd` + `audio/AudioData.tres`)
- `BackgroundMusic: Array[AudioStream]` — 10 OGG tracks
- `GuardGrumbles: Array[AudioStream]` — 5 WAV grumble clips
- `AlartMusic: Array[AudioStream]` — 2 MP3 tracks (Array, NOT Dictionary)
- `AlartBark: AudioStream` — single one-shot bark (needs audio file assigned in inspector)

**Audio Tooling** (Python scripts)
- `audio/music/*.ogg.import` — all 10 set to `loop=true`
- `audio/sfx/split_grumbles.py` — silence-detection WAV splitter (stdlib only)
- `audio/sfx/normalize_grumbles.py` — peak normalization to -1.0 dBFS (stdlib only, no numpy)
- `audio/equalize_alart_music.py` — RMS-equalizes alart MP3s to exploration average (-18.6 dBFS); requires ffmpeg on PATH

**TutorialManager** (`gamesystems/tutorial_manager.gd` — new autoload)
- `mapTutorialSteps: Dictionary[String, int]`; `getTutorialSteps(key)` / `advanceTutorial(key)`

**Fence Spawning**
- `MapManager.gateZoneIds: Array[int]` populated by WorldGenerator after `_buildPerimeterWall()`
- `GameManager._spawnFencesAtGates()` — one `npc_fence.tscn` per gate zone, called from `startGame()`

### New Files This Session
- `audio/scripts/audio_manager.gd`, `audio/scripts/audio_data.gd`, `audio/AudioData.tres`
- `audio/sfx/split_grumbles.py`, `audio/sfx/normalize_grumbles.py`, `audio/equalize_alart_music.py`
- `gamesystems/crime_manager.gd`, `gamesystems/tutorial_manager.gd`
- `hud/red_information_arrow.gd`, `hud/red_information_arrow.tscn`

### In Progress / Immediate Next Steps
- **AlartBark audio** — `AlartBark` field exists in AudioData.tres but needs an audio file assigned in the Godot inspector
- **Game over screen** — still a TODO from previous session (see 2026-03-04 notes)
- **`getPlayerComponent()` bug** — `game_manager.gd` line ~653: `getComponent("&PlayerCharacterComponent")` should be `getComponent(&"PlayerCharacterComponent")`

### Deferred / Open Decisions
- **LOS for guard sight** — current `_canSeePlayer()` uses Chebyshev distance + dot product; no wall occlusion yet
- **AlartMeter visual** — Control structure exists; final art/animation not designed
- **Fence behavior** — `npc_fence` prefab used; no FenceComponent or collision behavior confirmed beyond the prefab
- **TutorialManager usage** — infrastructure only; no steps wired to UI or game events yet
- **South/west/east gates** — WorldGenerator only places north gate
- **Music volume UI** — `musicVolumeDb` on AudioManager not exposed to any settings menu

### Gotchas
- "Alart" is an **intentional misspelling** — do not autocorrect to "Alert"
- `AlartMusic` is `Array[AudioStream]`, NOT a Dictionary
- `EMusicState.None` must remain as initial default so first `setMusicState(Normal)` isn't swallowed
- Guard grumble plays **after** the alertLevel threshold check in `onSoftDetectCrime` (user moved it there deliberately)
- `MapManager.gateZoneIds` is the canonical list for gate-related spawning
- Python audio scripts use stdlib only — ffmpeg must be on PATH for equalize_alart_music.py

---

## 2026-03-04

### Accomplished

**HUD / Coin Flip Challenge**
- `hud_coin_flip_contest.tscn` — wired all new exports (`prefabResult`, `hboxResults`, `txtChallenge`, `txtStat`, `txtScore`, `txtLucky`, `btnFlip`) to scene nodes; removed static placeholder `coinResultControl` instance (now created dynamically by `setRequiredSuccesses`)
- `hud_coin_flip_contest.gd` — added `setChallenge(title, stat, luckyCoins, requiredSuccesses)` which reads stat score from `PlayerCharacterComponent.getStat()`, populates all labels, and stores total flip coin count; added `_onClickFlip()` which hides button, generates random results, calls `flip()`; added `_statName()` replaced by `tr("stat_<key>_name")` localization lookup; `_onCoinLanded` now sets `flipState = done` and calls `_onChallengeComplete()` when last coin lands; `_onChallengeComplete()` shows WIN!/FAIL! on button and shakes on failure; flip button hides during flip and reappears when all coins land
- `Globals.shakeControl(control, radius, duration)` — new static utility that snaps a Control through random offsets then returns to origin

**PlayerCharacterComponent**
- Added `super._initialize()` call — without it the component never registered in `entity.components`, causing all `getComponent(&"PlayerCharacterComponent")` calls to return null
- Stats moved from `_initialize()` into `onNewGame()` so they reset cleanly on new runs; `getLuckyCoins()` accessor added

**ChallengeManager** (new autoload in `gamesystems/`)
- `startChallenge()` / `BeginChallenge()` — entry points for launching a coin flip challenge
- `HandleChallengeComplete()` — tracks success count per challenge type
- `challengeSuccessCount` — escalating difficulty (fast_talk_guard gets harder each time player is caught)
- `resetForNewGame()` — clears all per-run challenge state
- Registered as autoload in `project.godot`
- `test_challenge` console command moved here from GameManager

**GameManager**
- `onDialogueFinished(result)` — parses `"challenge:type"` and `"gameover"` result strings from dialogue
- `goToGameOver()` — closes HUDs, unpauses, stubs game over (currently calls `resetForNewGame()` immediately; game over screen is a TODO)
- `resetForNewGame()` — full reset orchestrator (see `docs/game_reset_plan.md`); tears down world, clears all per-run state, returns to MainMenu state
- `_cmdResetGame()` / `reset_game` console command — debug shortcut to trigger full reset from anywhere in gameplay
- Removed scattered `get_tree().paused` calls from `HandleGuardApprehendPlayer`, `_cmdTestDialog`, and `_advanceDialog` — pause lifecycle now owned by `HUDDialog`

**HUDDialog — input / pause fix**
- `turnOn()` now calls `get_tree().paused = true` so game input is blocked the moment dialog appears, regardless of caller
- `_animateOut()` finished callback now calls `get_tree().paused = false` — game only resumes after dialog has fully slid off screen

**MapManager**
- `resetForNewGame()` — frees all entities, clears zones/spawnPoints/waypointRegistry, resets `currentZoneId`, clears all tilemap layers

**WorldTileMap**
- `clearAllLayers()` — convenience method clearing all 4 render layers; used by `MapManager.resetForNewGame()`

**TimeKeeper**
- `resetForNewGame()` — zeros `_turnsTaken` and `_lastHalfHourSlot`

**HUD_Main**
- `resetForNewGame()` — disconnects `timeKeeper.turnAdvanced`, shows start button, blanks time/coin labels

**Docs**
- `docs/game_reset_plan.md` — written with full state inventory, new methods, implementation order, and gotchas

**Git**
- Committed and pushed: `41f93a7` — "Dialog system, coin flip challenge, crime system, guard AI, ChallengeManager" (141 files)

---

### In Progress / Immediate Next Steps

- **Game over screen** — `goToGameOver()` currently skips straight to `resetForNewGame()`. A proper screen (score summary, cause of death, "Play Again" button) should be inserted before the reset call.
- **`getPlayerComponent()` bug** — `game_manager.gd` line 653 calls `getComponent("&PlayerCharacterComponent")` (string literal with `&` inside the string, not a StringName literal). Should be `getComponent(&"PlayerCharacterComponent")`.
- **`capture_player` dialogue branch** — `guard_dialog.dialogue` needs a `~ capture_player` title added for the guard apprehension flow to work end-to-end.
- **`test_dialog` flow** — confirm the full async dialogue loop works correctly with the new pause ownership (HUDDialog now pauses/unpauses, callers no longer do).

---

### Deferred / Open Decisions

- **Game over screen design** — what info to show, how the player dismisses it (button? any key?), whether there's a score/time display.
- **`btnDebugStart` vs real main menu** — the start button is a debug placeholder; at some point a proper main menu scene will replace it. `HUD_Main.resetForNewGame()` shows it for now.
- **`timeKeeper` recreation vs reset** — currently `startGame()` only creates `timeKeeper` if null; after the first game it reuses the existing instance and calls `resetForNewGame()` on it. This is fine but worth noting if TimeKeeper gains more complex state.
- **Challenge difficulty persistence** — `challengeSuccessCount` is cleared on full reset. If per-session persistence across multiple resets is ever wanted, this needs to move to a save file.
- **Stat system** — `PlayerCharacterComponent.getStat()` returns hardcoded `2` for all stats (set in `onNewGame()`). Real stat progression (leveling, equipment bonuses) is not yet designed.
- **`_spawnDebugMarks` / `_spawnDebugGuards`** — still called from `startGame()`; these are placeholder spawners and will need to be replaced with a proper world population system.
