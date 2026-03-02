class_name RandomTable
extends RefCounted

# ── Static registry ───────────────────────────────────────────────────────────

static var _tables: Dictionary = {}  # String → RandomTable

# Returns a weighted random result from the named table.
# Tables are loaded at startup by Globals._ready().
static func rollOnTable(tableName: String) -> String:
	var table := _tables.get(tableName) as RandomTable
	if table == null:
		push_error("RandomTable: no table named '%s'" % tableName)
		return ""
	return table._roll()


# ── Instance data ─────────────────────────────────────────────────────────────

var archetypeName:    String
var _entries:     Array[String] = []
var _weights:     Array[int]    = []
var _totalWeight: int           = 0


func _addEntry(result: String, weight: int) -> void:
	_entries.append(result)
	_weights.append(weight)
	_totalWeight += weight


# Picks a weighted-random entry.
func _roll() -> String:
	if _totalWeight == 0:
		return ""
	var roll       := randi_range(0, _totalWeight - 1)
	var cumulative := 0
	for i in _entries.size():
		cumulative += _weights[i]
		if roll < cumulative:
			return _entries[i]
	return _entries[-1]  # should never be reached


# ── YAML loader ───────────────────────────────────────────────────────────────

# Parses the simple two-level YAML format used by random_tables.yaml:
#
#   table_name:        ← indent 0: new table
#     data:            ← indent 2: marks start of entry block
#       "result": 10   ← indent 4: weighted entry
#
static func _loadAllTables() -> void:
	var dir := DirAccess.open("res://tables")
	if dir == null:
		push_error("RandomTable: could not open res://tables directory")
		return
	dir.list_dir_begin()
	var fileName := dir.get_next()
	while fileName != "":
		if not dir.current_is_dir() and fileName.ends_with(".yaml"):
			_loadFile("res://tables/" + fileName)
		fileName = dir.get_next()
	dir.list_dir_end()
	# Register console command now that table names are known for autocomplete.
	Console.add_command("rt", _cmdRollOnTable, ["table_name"], 1, "Rolls on a named random table and prints the result.")
	Console.add_command_autocomplete_list("rt", PackedStringArray(_tables.keys()))


static func _cmdRollOnTable(tableName: String) -> void:
	var result := rollOnTable(tableName)
	if result.is_empty():
		Console.print_warning("Unknown table '%s'. Loaded tables:" % tableName)
		for name: String in _tables.keys():
			Console.print_line("  %s" % name)
		return
	Console.print_line("rt [%s] → %s" % [tableName, result])


static func _loadFile(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("RandomTable: could not open %s" % path)
		return

	var currentTable: RandomTable = null
	var bInData:      bool        = false
	# Detected from the first indented line — works with spaces, tabs, or any mix.
	var indentUnit:   int         = 0

	while not file.eof_reached():
		var line: String = file.get_line()

		# Skip blank lines and comments.
		var trimmed := line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue

		# Count leading whitespace characters (spaces and tabs both count as 1 unit).
		var indent := 0
		for ch in line:
			if ch == " " or ch == "\t": indent += 1
			else:                        break

		# Learn the indent unit from the first indented line we encounter.
		if indent > 0 and indentUnit == 0:
			indentUnit = indent

		var level := (indent / indentUnit) if indentUnit > 0 else 0

		if level == 0:
			# New table — top-level key is the table name.
			# Reset indentUnit so each table detects its own indentation style.
			currentTable = RandomTable.new()
			currentTable.archetypeName = trimmed.trim_suffix(":")
			_tables[currentTable.archetypeName] = currentTable
			bInData    = false
			indentUnit = 0

		elif level == 1:
			bInData = (trimmed == "data:")

		elif level == 2 and bInData and currentTable != null:
			# Entry line format — quoted:   "some text": 42
			#                    unquoted:  single_word: 42
			var key:    String
			var weight: int
			if trimmed.begins_with('"'):
				# Quoted key — split on the closing '": '.
				var sep := trimmed.rfind("\": ")
				if sep == -1:
					continue
				key    = trimmed.substr(1, sep - 1)  # strip surrounding quotes
				weight = trimmed.right(trimmed.length() - sep - 3).strip_edges().to_int()
			else:
				# Unquoted key — split on the first ': '.
				var sep := trimmed.find(": ")
				if sep == -1:
					continue
				key    = trimmed.left(sep)
				weight = trimmed.right(trimmed.length() - sep - 2).strip_edges().to_int()
			if weight > 0:
				currentTable._addEntry(key, weight)
