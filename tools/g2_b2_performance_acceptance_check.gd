extends Node

const AQUARIUM_SCENE: PackedScene = preload("res://scenes/aquarium/aquarium.tscn")
const TICKS: int = 600 # 10 simulated minutes at one-second game ticks
var errors: int = 0

func _ready() -> void:
	get_tree().create_timer(240).timeout.connect(func():
		print("WATCHDOG_TIMEOUT")
		get_tree().quit(2)
	)
	print("G2-B-2 PERF START")
	call_deferred("_run")

func _run() -> void:
	print("G2-B-2 PERF loading data")
	GameApp.load_data_tables()
	var template: Dictionary = {
		"pet_id": "perf_template",
		"nickname": "Perf Template",
		"species_id": "normal_jellycat",
		"personality_id": "curious",
		"care_stats": {},
		"visual_params": {},
		"hunger": 40,
		"mood": 70,
		"age_days": 0,
		"growth_stage": "baby"
	}
	for count in [4, 8, 12]:
		for scale in [1, 60]:
			print("G2-B-2 PERF preparing pets=%d scale=x%d" % [count, scale])
			GameState.reset_to_default()
			while GameState.get_pet_ids().size() < count:
				var index: int = GameState.get_pet_ids().size()
				var pet: Dictionary = template.duplicate(true)
				pet["pet_id"] = "perf_%02d" % (index + 1)
				pet["nickname"] = "Perf %02d" % (index + 1)
				if not GameState.add_pet(pet):
					errors += 1
					break
			if GameState.get_pet_ids().size() != count:
				errors += 1
				print("G2-B-2 PERF ERROR fixture pet count expected=%d actual=%d" % [count, GameState.get_pet_ids().size()])
			TimeManager.set_time_scale(scale)
			var aquarium: Control = AQUARIUM_SCENE.instantiate() as Control
			get_tree().root.add_child(aquarium)
			await get_tree().process_frame
			print("G2-B-2 PERF running pets=%d scale=x%d ticks=%d" % [count, scale, TICKS])
			var total_usec: int = 0
			var max_usec: int = 0
			for tick in range(TICKS):
				var start_usec: int = Time.get_ticks_usec()
				aquarium.call("_process", 1.0)
				var elapsed_usec: int = Time.get_ticks_usec() - start_usec
				total_usec += elapsed_usec
				max_usec = maxi(max_usec, elapsed_usec)
				if not is_instance_valid(aquarium):
					errors += 1
					break
			print("G2-B-2 PERF pets=%d scale=x%d simulated_seconds=%d avg_ms=%.6f max_ms=%.6f errors=%d" % [count, scale, TICKS * scale, float(total_usec) / TICKS / 1000.0, float(max_usec) / 1000.0, errors])
			print("G2-B-2 PERF completed pets=%d scale=x%d" % [count, scale])
			aquarium.queue_free()
			await get_tree().process_frame
		TimeManager.set_time_scale(1)
	GameState.reset_to_default()
	print("G2-B-2 PERF SUMMARY errors=%d real_device_fps=NOT_RUN" % errors)
	get_tree().quit(0 if errors == 0 else 1)
