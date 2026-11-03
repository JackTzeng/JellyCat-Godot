extends Node

const SHOP_SCENE := preload("res://scenes/ui/shop_panel.tscn")
const AQUARIUM_SCENE := preload("res://scenes/aquarium/aquarium.tscn")
const DECOR_IDS := ["decor_seaweed", "decor_stone", "decor_shell", "decor_lamp", "decor_castle"]
const ASSETS := {
	"res://assets/gems/gem_diamond_idle_v1_32x32_2x.png": ["b431a1190b4c0f4bbc13acbdf8f46c0a03b10edc1ff06f50bc9ef8def4815d99", Vector2i(64,32)],
	"res://assets/gems/gem_diamond_pickup_v1_32x32.png": ["9dcb001e96a6fe72347e2211890d11d5a0065f81fdba9dbf4f13f4a80c3a6eb5", Vector2i(32,32)],
	"res://assets/gems/gem_pearl_idle_v1_32x32_2x.png": ["768aea1fe81a2bddbca5668856b640ea07a10aeac848b92d0ceff77fd8243045", Vector2i(64,32)],
	"res://assets/gems/gem_pearl_pickup_v1_32x32.png": ["fac23d16608456a33cf620722a82b0308f9c49b78acaf725e66fae36c8222187", Vector2i(32,32)],
	"res://assets/decor/decor_castle_icon_v1_32x32.png": ["193ea788319431d0a60563004050d913eec34c61be40b5a222572d81e074e4a2", Vector2i(32,32)],
	"res://assets/decor/decor_castle_v1_96x96.png": ["d0ebbf5d6e68657c7a98d99feb706d4d45b7b8cce6339df0bb0b8ff3adf8fc43", Vector2i(96,96)],
	"res://assets/decor/decor_lamp_glow_v1_64x96_2x.png": ["83d258a591a80e4f41bfe4f8ba0a3c318f55d0e1e8014d5c09e6f499186b5c4b", Vector2i(128,96)],
	"res://assets/decor/decor_lamp_icon_v1_32x32.png": ["43f361a8f7141d5f934f7c3af4d3a9edc6a9c62ac8ed2bd246131cc693165eef", Vector2i(32,32)],
	"res://assets/decor/decor_lamp_v1_64x96.png": ["c2db003f446253d10ddba92dd4b12e979a81abc2b6faf42a1a6111067ab903ca", Vector2i(64,96)],
	"res://assets/decor/decor_seaweed_icon_v3_32x32.png": ["3b98eb4f4430af0e592eb8531365fea18e59a1eacc757674d930d39ef15c4a9b", Vector2i(32,32)],
	"res://assets/decor/decor_seaweed_sway_v3_64x96_2x.png": ["7733e16e1f5abe9418cc1814c1064ff142ad4f69e27849eac217e9f029cc2edd", Vector2i(128,96)],
	"res://assets/decor/decor_seaweed_v3_64x96.png": ["3555ae83ca4943181b624a75ade2fe827ecc5fef7c0ce6b9a6d974abee42a91f", Vector2i(64,96)],
	"res://assets/decor/decor_shell_icon_v1_32x32.png": ["df514fcbe6e9152cd635c35f0e2fd4525d693bb02403e991cf37004d1d786daf", Vector2i(32,32)],
	"res://assets/decor/decor_shell_v1_64x96.png": ["048d7c428b39afa1f610a1244bb15b9da99ee974527cfd28808003ae28646967", Vector2i(64,96)],
	"res://assets/decor/decor_stone_icon_v1_32x32.png": ["af982308feedcd785f2df62999641a154ce49ea5e8db4f4c50a9bba568a627e8", Vector2i(32,32)],
	"res://assets/decor/decor_stone_v1_64x96.png": ["9d41baa8ef63a7b602fd420f59279b147f4d4524718ded98616c32966248b0fa", Vector2i(64,96)],
}
var checks := 0
var timed_out := false

func _ready() -> void:
	print("G2_ART_ACCEPTANCE_PROGRESS assets")
	get_tree().create_timer(120.0).timeout.connect(_watchdog)
	_run.call_deferred()

func _watchdog() -> void:
	if not timed_out:
		timed_out = true
		print("WATCHDOG_TIMEOUT")
		get_tree().quit(2)

func _run() -> void:
	for path in ASSETS:
		var file_path := ProjectSettings.globalize_path(path)
		_assert(FileAccess.file_exists(path), "file exists " + path)
		_assert(FileAccess.get_sha256(file_path) == str(ASSETS[path][0]), "approved sha256 " + path)
		var texture := load(path) as Texture2D
		_assert(texture != null, "Texture2D loads " + path)
		if texture != null:
			_assert(texture.get_size() == Vector2(ASSETS[path][1]), "dimensions " + path)
	print("G2_ART_ACCEPTANCE_PROGRESS asset hashes and dimensions")
	GameApp.load_data_tables()
	var aquarium := AQUARIUM_SCENE.instantiate()
	aquarium.set_process(false)
	aquarium.set_physics_process(false)
	add_child(aquarium)
	await get_tree().process_frame
	for kind in ["pearl", "diamond"]:
		var path: String = "res://assets/gems/gem_%s_idle_v1_32x32_2x.png" % kind
		var bubble: Button = aquarium.COIN_BUBBLE_SCENE.instantiate() as Button
		bubble.configure({"token_id": kind, "kind": kind, "x": 200.0, "y": 200.0, "expires_at": Time.get_unix_time_from_system() + 120.0})
		aquarium.coin_bubble_container.add_child(bubble)
		await get_tree().process_frame
		var idle_atlas := bubble.get_node("IdleArt").texture as AtlasTexture
		_assert(idle_atlas != null and idle_atlas.atlas.resource_path == path, kind + " uses official idle texture")
		_assert(bubble.modulate == Color.WHITE, kind + " is not color-tinted")
		bubble.collect()
		_assert(bubble.get_node("PickupFxArt").texture.resource_path == "res://assets/gems/gem_%s_pickup_v1_32x32.png" % kind, kind + " uses official pickup texture")
		bubble.queue_free()
	var owned: Array[Dictionary] = []
	for i in DECOR_IDS.size():
		owned.append({"item_id": DECOR_IDS[i], "slot": i, "purchased_at": "acceptance"})
	GameState.data["aquarium"]["owned_decor"] = owned
	GameState.state_changed.emit()
	await get_tree().process_frame
	_assert(aquarium.decor_visuals.size() == 5, "all decoration slots populated")
	var expected := {
		"decor_seaweed":"res://assets/decor/decor_seaweed_sway_v3_64x96_2x.png",
		"decor_stone":"res://assets/decor/decor_stone_v1_64x96.png",
		"decor_shell":"res://assets/decor/decor_shell_v1_64x96.png",
		"decor_lamp":"res://assets/decor/decor_lamp_glow_v1_64x96_2x.png",
		"decor_castle":"res://assets/decor/decor_castle_v1_96x96.png"}
	var sizes := [Vector2(1280,720), Vector2(1280,591), Vector2(1600,720)]
	for size in sizes:
		aquarium.call("_layout_ui", size, Rect2(Vector2.ZERO,size))
		aquarium.call("_refresh_decor", size)
		await get_tree().process_frame
		for visual_index in aquarium.decor_visuals.size():
			var visual: TextureRect = aquarium.decor_visuals[visual_index]
			var expected_path: String = expected[DECOR_IDS[visual_index]]
			var actual_texture := visual.texture as AtlasTexture
			var actual_path: String = actual_texture.atlas.resource_path if actual_texture != null else visual.texture.resource_path
			_assert(actual_path == expected_path, "official decor texture " + visual.name)
			_assert(visual.mouse_filter == Control.MOUSE_FILTER_IGNORE, "decor ignores input")
			_assert(visual.size.y <= size.y / 3.0, "decor within tank height cap")
			var rect: Rect2 = visual.get_global_rect()
			_assert(not rect.intersects(aquarium.pet_roster_scroll.get_global_rect()), "no nameplate overlap " + str(size))
			_assert(not rect.intersects(aquarium.inventory_backdrop.get_global_rect()), "no HUD overlap " + str(size))
			_assert(not rect.intersects(aquarium.action_scroll.get_global_rect()), "no button overlap " + str(size))
	var shop := SHOP_SCENE.instantiate()
	add_child(shop)
	await get_tree().process_frame
	for item_id in DECOR_IDS:
		var texture_rect: TextureRect = shop.cards[item_id].name.get_parent().get_node("Icon") as TextureRect
		_assert(texture_rect != null and texture_rect.texture.resource_path == shop.call("_decor_icon_path", item_id), "official shop icon " + item_id)
	print("G2_ART_ACCEPTANCE_PROGRESS runtime checks complete")
	if not timed_out:
		print("G2_ART_ACCEPTANCE_OK checks=%d" % checks)
		get_tree().quit(0)

func _assert(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("G2 art acceptance failed: " + message)
