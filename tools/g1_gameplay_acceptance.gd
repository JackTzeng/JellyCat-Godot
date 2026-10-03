extends Node

const ISOLATED_SAVE_PATH: String = "user://jellycat_g1_gameplay_save.json"

var checks: int = 0
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(SaveManager.set_save_path_for_test(ISOLATED_SAVE_PATH), "Uses a separate user:// save file")
	SaveManager.reset_save()
	GameApp.load_data_tables()
	GameState.reset_to_default()
	var starter_eggs: Array[Dictionary] = EggSystem.ensure_starter_eggs()
	_expect(starter_eggs.size() == 3, "New game grants three starter eggs")
	for egg in starter_eggs:
		var egg_id: String = str(egg.get("egg_id", ""))
		_expect(EggSystem.select_starter_egg(egg_id), "%s can be selected" % egg_id)
		var hatched: Dictionary = {}
		for _tap in range(10):
			hatched = HatchSystem.tap_egg(egg_id)
		_expect(bool(hatched.get("is_hatched", false)), "%s hatches through the normal flow" % egg_id)
	for pet_id in GameState.get_active_pet_ids():
		var pet: Dictionary = GameState.get_pet(pet_id)
		pet["hunger"] = 35
		GameState.set_pet(pet_id, pet)

	var aquarium_scene: PackedScene = load("res://scenes/aquarium/aquarium.tscn") as PackedScene
	_expect(aquarium_scene != null, "Real Aquarium scene loads")
	if aquarium_scene == null:
		_finish()
		return
	var aquarium: Control = aquarium_scene.instantiate() as Control
	get_tree().root.add_child(aquarium)
	await get_tree().process_frame
	var actors: Dictionary = aquarium.get("actors_by_id") as Dictionary
	_expect(actors.size() == 3, "Aquarium creates three pet actors")
	_expect((aquarium.get_node("%ActorAnchor") as Node2D).get_child_count() == 3, "Actor scene tree has exactly three children")
	var hunger_before_by_pet: Dictionary = {}
	for pet_id in GameState.get_active_pet_ids():
		var actor: Node = actors.get(pet_id) as Node
		_expect(actor != null, "%s has an actor" % pet_id)
		if actor == null:
			continue
		_expect(str(actor.get("pet_id")) == pet_id, "%s actor has an explicit matching pet_id" % pet_id)
		_expect(int(actor.get("current_stage")) == int(GameState.get_pet(pet_id).get("stage", 0)), "%s actor uses its bound stage" % pet_id)
		var start_position: Vector2 = (actor as Node2D).global_position
		hunger_before_by_pet[pet_id] = int(GameState.get_pet(pet_id).get("hunger", 0))
		var click: InputEventScreenTouch = InputEventScreenTouch.new()
		click.pressed = true
		click.position = start_position
		aquarium.call("_unhandled_input", click)
		_expect(GameState.get_selected_pet_id() == pet_id, "Touching %s selects that pet" % pet_id)
		var old_hunger: int = int(GameState.get_pet(pet_id).get("hunger", 0))
		var old_inventory: int = GameState.get_inventory_count("food_basic")
		var actions: Dictionary = aquarium.get("last_action_time_by_name") as Dictionary
		actions["feed"] = -999999.0
		aquarium.set("last_action_time_by_name", actions)
		aquarium.call("_on_feed_pressed")
		_expect(int(GameState.get_pet(pet_id).get("hunger", 0)) == old_hunger, "Dropped food waits for an actor to eat")
		_expect(GameState.get_food_drops().size() == GameState.get_active_pet_ids().find(pet_id) + 1, "Feed button creates one persisted food token")
		_expect(GameState.get_inventory_count("food_basic") == old_inventory - 1, "One actor feed spends exactly one token")
	var wait_time: float = 0.0
	while not GameState.get_food_drops().is_empty() and wait_time < 25.0:
		await get_tree().create_timer(0.1).timeout
		wait_time += 0.1
	_expect(GameState.get_food_drops().is_empty(), "Three food tokens are consumed once in the real Aquarium scene")
	for pet_id in GameState.get_active_pet_ids():
		_expect(int(GameState.get_pet(pet_id).get("hunger", 0)) > int(hunger_before_by_pet.get(pet_id, 100)), "%s receives a fair feed" % pet_id)

	_expect(SaveManager.save_game(), "Three-pet Aquarium state saves to the isolated file")
	var actor_anchor: Node2D = aquarium.get_node("%ActorAnchor") as Node2D
	var pending_drop: Dictionary = FoodDropSystem.drop_food(actor_anchor.global_position + Vector2(140.0, 20.0))
	var pending_token: String = str(pending_drop.get("token_id", ""))
	var inventory_with_pending_drop: int = GameState.get_inventory_count("food_basic")
	var one_pet_id: String = GameState.get_active_pet_ids()[0]
	var hunger_before_pending_eat: int = int(GameState.get_pet(one_pet_id).get("hunger", 0))
	_expect(not pending_token.is_empty(), "One more food token is reserved before exit")
	_expect(SaveManager.save_game(), "Pending feed ledger is durable before simulated exit")
	GameState.reset_to_default()
	_expect(SaveManager.load_game(), "Three-pet Aquarium state reloads")
	_expect(GameState.get_active_pet_ids().size() == 3, "Reload retains the three active pet IDs")
	_expect(GameState.get_inventory_count("food_basic") == inventory_with_pending_drop, "Reload retains exact reserved food inventory")
	_expect(GameState.get_food_drops().size() == 1 and str(GameState.get_food_drops()[0].get("token_id", "")) == pending_token, "Reload restores an in-flight food token once")
	await get_tree().process_frame
	_expect((aquarium.get("actors_by_id") as Dictionary).size() == 3, "Reload reconciles exactly three live actors")
	_expect(FoodDropSystem.consume_food(pending_token, one_pet_id), "A restored token resolves to one explicit eater")
	_expect(not FoodDropSystem.consume_food(pending_token, one_pet_id), "A consumed token cannot be replayed")
	_expect(int(GameState.get_pet(one_pet_id).get("hunger", 0)) > hunger_before_pending_eat, "The replay attempt adds no second meal")
	_expect(GameState.get_inventory_count("food_basic") == inventory_with_pending_drop, "Consumption does not refund a spent token")
	_expect(GameState.get_food_drops().is_empty(), "Consumed token is removed from the save ledger")
	await get_tree().create_timer(0.6).timeout
	SaveManager.reset_save()
	SaveManager.use_production_save_path()
	aquarium.queue_free()
	await get_tree().process_frame
	_finish()


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("G1_GAMEPLAY_ACCEPTANCE_OK checks=%d" % checks)
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("G1_GAMEPLAY_ACCEPTANCE_FAIL: %s" % failure)
	print("G1_GAMEPLAY_ACCEPTANCE_FAILED checks=%d failures=%d" % [checks, failures.size()])
	get_tree().quit(1)
