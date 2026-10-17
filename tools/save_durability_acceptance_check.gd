extends Node

const ISOLATED_SAVE_PATH: String = "user://save_durability_acceptance.json"

var failures: Array[String] = []
var checks: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("SAVE_DURABILITY_USER_DIR=%s" % ProjectSettings.globalize_path("user://"))
	var isolated_path_set: bool = SaveManager.set_save_path_for_test(ISOLATED_SAVE_PATH)
	_expect(isolated_path_set, "Durability acceptance uses an isolated user:// save path")
	if not isolated_path_set:
		_finish()
		return
	GameApp.load_data_tables()
	_test_atomic_rename_overwrite()
	_test_interruption_points()
	_test_backup_rotation_timing()
	_test_newest_recovery_candidate_wins()
	_test_migration_preserves_fresh_backups()
	_test_empty_main_recovers_from_backup()
	_test_two_invalid_files_block_and_preserve_bytes()
	_test_backup_reset_cleanup()
	_reset_case()
	SaveManager.use_production_save_path()
	_finish()


func _test_atomic_rename_overwrite() -> void:
	var source_path: String = "user://save_durability_rename_source.tmp"
	var target_path: String = "user://save_durability_rename_target.bin"
	var source_absolute: String = ProjectSettings.globalize_path(source_path)
	var target_absolute: String = ProjectSettings.globalize_path(target_path)
	if FileAccess.file_exists(source_path):
		DirAccess.remove_absolute(source_absolute)
	if FileAccess.file_exists(target_path):
		DirAccess.remove_absolute(target_absolute)
	_expect(_write_text(target_path, "previous-target-bytes"), "Atomic-overwrite fixture writes an existing target")
	_expect(_write_text(source_path, "replacement-source-bytes"), "Atomic-overwrite fixture writes its source")
	var rename_error: Error = DirAccess.rename_absolute(source_absolute, target_absolute)
	_expect(rename_error == OK, "DirAccess.rename_absolute atomically overwrites an existing target")
	_expect(_read_text(target_path) == "replacement-source-bytes", "Overwritten target contains the complete replacement bytes")
	_expect(not FileAccess.file_exists(source_path), "Successful atomic overwrite consumes the source temp file")
	if FileAccess.file_exists(source_path):
		DirAccess.remove_absolute(source_absolute)
	if FileAccess.file_exists(target_path):
		DirAccess.remove_absolute(target_absolute)


func _test_interruption_points() -> void:
	_reset_case()
	var original_main: String = _save_currency(10, "Initial save succeeds before temp interruption")
	GameState.set_currency("bubble_coin", 11)
	_expect(
		SaveManager.set_write_interruption_point_for_test("after_save_temp_verified"),
		"Temp-before-rename interruption point is supported"
	)
	_expect(not SaveManager.save_game(), "Interrupted write before rename reports failure")
	_expect(_read_text(SaveManager.get_save_path()) == original_main, "Previous main stays intact before rename")
	_expect(_main_or_primary_backup_valid(), "Pre-rename interruption retains a valid main or primary backup")
	var interrupted_temp: String = _read_text(SaveManager.get_save_path() + ".tmp")
	_expect(_is_supported_save(interrupted_temp), "Pre-rename temp is complete valid JSON")
	_expect(_currency_from_text(interrupted_temp) == 11, "Pre-rename temp contains the requested state")
	GameState.reset_to_default()
	_expect(SaveManager.load_game(), "Main remains loadable after pre-rename interruption")
	_expect(GameState.get_currency("bubble_coin") == 10, "Pre-rename interruption restores the previous state")

	_reset_case()
	var backup_temp_main: String = _save_currency(10, "Backup-temp fixture saves its main generation")
	var backup_temp_old_backup: String = _read_text(SaveManager.get_backup_path())
	var backup_temp_secondary: String = SaveManager.get_save_path() + ".bak2"
	_expect(
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_temp_secondary)) == OK,
		"Backup-temp fixture leaves one existing backup slot"
	)
	GameState.set_currency("bubble_coin", 11)
	_expect(
		SaveManager.set_write_interruption_point_for_test("after_backup_temp_verified"),
		"Backup-temp interruption point is supported"
	)
	_expect(not SaveManager.save_game(), "Interrupted backup seeding before rename reports failure")
	_expect(_read_text(SaveManager.get_save_path()) == backup_temp_main, "Main survives backup-temp interruption")
	_expect(_read_text(SaveManager.get_backup_path()) == backup_temp_old_backup, "Existing backup survives backup-temp interruption")
	_expect(_main_or_primary_backup_valid(), "Backup-temp interruption retains a valid main or primary backup")
	var backup_temp: String = _read_text(backup_temp_secondary + ".tmp")
	_expect(_is_supported_save(backup_temp), "Backup temp is complete valid JSON before rename")
	_expect(_currency_from_text(backup_temp) == 10, "Backup temp preserves the prior main generation")
	GameState.reset_to_default()
	_expect(SaveManager.load_game(), "Main remains loadable after backup-temp interruption")
	_expect(GameState.get_currency("bubble_coin") == 10, "Backup-temp interruption preserves the current generation")

	_reset_case()
	var backup_rename_main: String = _save_currency(10, "Backup-promotion fixture saves its main generation")
	var backup_rename_secondary: String = SaveManager.get_save_path() + ".bak2"
	_expect(
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_rename_secondary)) == OK,
		"Backup-promotion fixture leaves one existing backup slot"
	)
	GameState.set_currency("bubble_coin", 11)
	_expect(
		SaveManager.set_write_interruption_point_for_test("after_backup_promotion"),
		"After-backup-rename interruption point is supported"
	)
	_expect(not SaveManager.save_game(), "Interruption after backup promotion reports failure")
	_expect(_read_text(SaveManager.get_save_path()) == backup_rename_main, "Main survives after backup promotion")
	_expect(_read_text(backup_rename_secondary) == backup_rename_main, "Promoted secondary backup is the previous main")
	_expect(_is_supported_save(_read_text(backup_rename_secondary)), "Promoted backup is valid JSON")
	_expect(_main_or_primary_backup_valid(), "Backup-promotion interruption retains a valid main or primary backup")
	GameState.reset_to_default()
	_expect(SaveManager.load_game(), "Main remains loadable after backup rename")
	_expect(GameState.get_currency("bubble_coin") == 10, "Backup-promotion interruption preserves the current generation")

	_reset_case()
	_save_currency(10, "Pre-replace fixture saves generation one")
	var previous_generation: String = _save_currency(11, "Pre-replace fixture saves generation two")
	GameState.set_currency("bubble_coin", 12)
	_expect(
		SaveManager.set_write_interruption_point_for_test("before_main_replace"),
		"Before-main-replace interruption point is supported"
	)
	_expect(not SaveManager.save_game(), "Interrupted write before atomic replacement reports failure")
	_expect(FileAccess.file_exists(SaveManager.get_save_path()), "Main remains present before atomic replacement")
	_expect(_read_text(SaveManager.get_save_path()) == previous_generation, "Previous main survives before atomic replacement")
	_expect(_main_or_primary_backup_valid(), "Pre-replacement interruption retains a valid main or primary backup")
	_expect(_is_supported_save(_read_text(SaveManager.get_save_path() + ".tmp")), "New main temp is complete before atomic replacement")
	_expect(_is_supported_save(_read_text(SaveManager.get_backup_path())), "Backup remains valid before atomic replacement")
	GameState.reset_to_default()
	_expect(SaveManager.load_game(), "Main reloads after interruption before atomic replacement")
	_expect(GameState.get_currency("bubble_coin") == 11, "Pre-replace interruption keeps the prior generation")
	_expect(_is_supported_save(_read_text(SaveManager.get_save_path())), "Prior main remains valid JSON")
	_expect(not FileAccess.file_exists(SaveManager.get_save_path() + ".previous"), "Atomic replacement does not create a missing-main window")

	_reset_case()
	_save_currency(10, "Main-replace fixture saves generation one")
	_save_currency(11, "Main-replace fixture saves generation two")
	GameState.set_currency("bubble_coin", 12)
	_expect(
		SaveManager.set_write_interruption_point_for_test("after_main_replace"),
		"After-main-replace interruption point is supported"
	)
	_expect(not SaveManager.save_game(), "Interruption after atomic main replacement reports failure")
	_expect(_is_supported_save(_read_text(SaveManager.get_save_path())), "Atomically replaced main is complete valid JSON")
	_expect(_currency_from_text(_read_text(SaveManager.get_save_path())) == 12, "Atomically replaced main contains the new generation")
	_expect(_is_supported_save(_read_text(SaveManager.get_backup_path())), "Old valid backup remains available after main replacement")
	_expect(_main_or_primary_backup_valid(), "Post-replacement interruption retains a valid main or primary backup")
	GameState.reset_to_default()
	_expect(SaveManager.load_game(), "Atomically replaced main reloads after interruption")
	_expect(GameState.get_currency("bubble_coin") == 12, "Post-replace interruption keeps the new generation")


func _test_backup_rotation_timing() -> void:
	_reset_case()
	_save_currency(10, "Backup-rotation fixture saves generation one")
	_save_currency(11, "Backup-rotation fixture saves generation two")
	var backup_one: String = SaveManager.get_backup_path()
	var backup_two: String = SaveManager.get_save_path() + ".bak2"
	var original_one_mtime: int = FileAccess.get_modified_time(backup_one)
	var original_two_mtime: int = FileAccess.get_modified_time(backup_two)
	var original_newest_mtime: int = maxi(original_one_mtime, original_two_mtime)
	var amount: int = 12
	var all_saves_succeeded: bool = true
	var start_ticks: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ticks < 61000:
		GameState.set_currency("bubble_coin", amount)
		all_saves_succeeded = SaveManager.save_game() and all_saves_succeeded
		amount += 1
		OS.delay_msec(1000)
	_expect(all_saves_succeeded, "Continuous saves succeed without refreshing either backup inside the first 60 seconds")
	_expect(FileAccess.get_modified_time(backup_one) == original_one_mtime, "First backup is not rewritten within the first minute")
	_expect(FileAccess.get_modified_time(backup_two) == original_two_mtime, "Second backup is not rewritten within the first minute")
	_expect(
		int(Time.get_unix_time_from_system()) - mini(original_one_mtime, original_two_mtime) > 60,
		"At least one complete backup has aged beyond 60 seconds during continuous saves"
	)
	while int(Time.get_unix_time_from_system()) - original_newest_mtime < SaveManager.BACKUP_ROTATION_SECONDS:
		OS.delay_msec(100)
	var oldest_backup: String = backup_one
	var other_backup: String = backup_two
	if original_two_mtime < original_one_mtime:
		oldest_backup = backup_two
		other_backup = backup_one
	var main_before_backup_refresh: String = _read_text(SaveManager.get_save_path())
	var backup_refresh_target_before: String = _read_text(oldest_backup)
	var current_currency: int = _currency_from_text(main_before_backup_refresh)
	GameState.set_currency("bubble_coin", current_currency + 1)
	_expect(
		SaveManager.set_write_interruption_point_for_test("after_backup_temp_verified"),
		"Backup temp interruption remains available during timed rotation"
	)
	_expect(not SaveManager.save_game(), "Interrupted timed backup temp does not commit the main")
	_expect(_read_text(SaveManager.get_save_path()) == main_before_backup_refresh, "Main remains unchanged before backup promotion")
	_expect(_read_text(oldest_backup) == backup_refresh_target_before, "Existing rotation target remains unchanged before promotion")
	var pending_backup: String = _read_text(oldest_backup + ".tmp")
	_expect(_is_supported_save(pending_backup), "Timed rotation temp is a complete valid backup")
	_expect(_currency_from_text(pending_backup) == current_currency, "Timed rotation temp holds the prior main generation")
	_expect(
		SaveManager.set_write_interruption_point_for_test("after_backup_promotion"),
		"Backup promotion interruption remains available during timed rotation"
	)
	_expect(not SaveManager.save_game(), "Interrupted timed backup promotion does not commit the main")
	_expect(_read_text(SaveManager.get_save_path()) == main_before_backup_refresh, "Main remains intact after backup promotion")
	_expect(_read_text(oldest_backup) == main_before_backup_refresh, "Timed backup rotation atomically overwrites the existing slot")
	_expect(_is_supported_save(_read_text(other_backup)), "Other backup remains valid during rotation")
	_expect(
		int(Time.get_unix_time_from_system()) - FileAccess.get_modified_time(other_backup) > 60,
		"Rotation retains a backup older than 60 seconds"
	)
	GameState.reset_to_default()
	_expect(SaveManager.load_game(), "Main remains loadable after a rotated-backup interruption")
	_expect(GameState.get_currency("bubble_coin") == current_currency, "Backup rotation failure keeps the previous main state")

	GameState.set_currency("bubble_coin", current_currency + 1)
	_expect(
		SaveManager.set_write_interruption_point_for_test("before_main_replace"),
		"Atomic main replacement has a pre-operation interruption point"
	)
	_expect(not SaveManager.save_game(), "Pre-replacement interruption leaves the prior main intact")
	_expect(_read_text(SaveManager.get_save_path()) == main_before_backup_refresh, "Main is never absent before atomic replacement")
	_expect(_is_supported_save(_read_text(oldest_backup)), "Valid backup survives immediately before main replacement")
	GameState.reset_to_default()
	_expect(SaveManager.load_game(), "Prior main reloads after pre-replacement interruption")
	_expect(GameState.get_currency("bubble_coin") == current_currency, "Pre-replacement interruption retains the previous generation")

	var first_rotated_mtime: int = FileAccess.get_modified_time(oldest_backup)
	var second_interval_start: int = Time.get_ticks_msec()
	var second_interval_iterations: int = 0
	var second_interval_invariant_checks: int = 0
	all_saves_succeeded = true
	while Time.get_ticks_msec() - second_interval_start < 61000:
		GameState.set_currency("bubble_coin", amount)
		all_saves_succeeded = SaveManager.save_game() and all_saves_succeeded
		amount += 1
		var checks_before_age_invariants: int = checks
		_expect_backup_age_invariants("Continuous saves in the second rotation interval")
		second_interval_iterations += 1
		second_interval_invariant_checks += checks - checks_before_age_invariants
		OS.delay_msec(1000)
	_expect(
		second_interval_invariant_checks == second_interval_iterations * 3,
		"Every second-interval save retains all three backup-age invariant checks"
	)
	print("SAVE_DURABILITY_VARIABLE_LOOP second_interval_iterations=%d age_invariant_checks=%d expected_checks=%d checks_through_second_interval=%d" % [
		second_interval_iterations,
		second_interval_invariant_checks,
		second_interval_iterations * 3,
		checks,
	])
	_expect(all_saves_succeeded, "Continuous saves succeed through the second backup interval")
	_expect(FileAccess.get_modified_time(oldest_backup) == first_rotated_mtime, "A rotated backup is not rewritten again within 60 seconds")
	while int(Time.get_unix_time_from_system()) - first_rotated_mtime < SaveManager.BACKUP_ROTATION_SECONDS:
		OS.delay_msec(100)
	var main_before_second_rotation: String = _read_text(SaveManager.get_save_path())
	_expect(SaveManager.save_game(), "The second backup slot rotates after the 62-second guard")
	_expect(FileAccess.get_modified_time(other_backup) >= first_rotated_mtime, "The alternate backup slot is refreshed on the next interval")
	_expect(_read_text(other_backup) == main_before_second_rotation, "The alternate slot stores the prior main generation")
	_expect(_is_supported_save(_read_text(oldest_backup)), "First rotated backup stays valid after alternation")
	var oldest_backup_mtime: int = mini(FileAccess.get_modified_time(oldest_backup), FileAccess.get_modified_time(other_backup))
	var oldest_backup_age: int = int(Time.get_unix_time_from_system()) - oldest_backup_mtime
	_expect(oldest_backup_age > 60, "At least one backup remains older than 60 seconds after rotation")
	_expect(oldest_backup_age <= 125, "Oldest valid backup remains within the approximately two-minute recovery window")
	var latest_backup: String = oldest_backup
	if FileAccess.get_modified_time(other_backup) > FileAccess.get_modified_time(oldest_backup):
		latest_backup = other_backup
	var latest_backup_currency: int = _currency_from_text(_read_text(latest_backup))
	var empty_main: FileAccess = FileAccess.open(SaveManager.get_save_path(), FileAccess.WRITE)
	_expect(empty_main != null, "Latest-backup recovery fixture can truncate the main")
	if empty_main != null:
		empty_main.close()
	GameState.reset_to_default()
	_expect(SaveManager.load_game(), "Zero-byte main automatically recovers from the newest valid backup")
	_expect(GameState.get_currency("bubble_coin") == latest_backup_currency, "Newest backup slot restores the most recently rotated generation")
	_expect(_is_supported_save(_read_text(SaveManager.get_save_path())), "Newest-backup recovery creates a valid main file")
	_expect(_is_supported_save(_read_text(backup_one)), "Recovery retains the primary backup")
	_expect(_is_supported_save(_read_text(backup_two)), "Recovery retains the secondary backup")


func _test_empty_main_recovers_from_backup() -> void:
	_reset_case()
	_save_currency(10, "Zero-byte recovery fixture saves generation one")
	_save_currency(11, "Zero-byte recovery fixture saves generation two")
	var backup_before: String = _read_text(SaveManager.get_backup_path())
	var empty_main: FileAccess = FileAccess.open(SaveManager.get_save_path(), FileAccess.WRITE)
	_expect(empty_main != null, "Zero-byte main fixture can be opened")
	if empty_main != null:
		empty_main.close()
	_expect(FileAccess.file_exists(SaveManager.get_save_path()), "Zero-byte main fixture remains present")
	_expect(_read_text(SaveManager.get_save_path()).is_empty(), "Zero-byte main fixture is empty")
	GameState.reset_to_default()
	_expect(SaveManager.load_game(), "Empty main automatically recovers from a valid backup")
	_expect(GameState.get_currency("bubble_coin") == 10, "Backup recovery restores its saved currency state")
	_expect(not SaveManager.load_blocked, "Successful backup recovery unblocks saving")
	_expect(_is_supported_save(_read_text(SaveManager.get_save_path())), "Recovered main is valid JSON")
	_expect(FileAccess.file_exists(SaveManager.get_save_path() + ".corrupt"), "Original empty main is retained as a corrupt marker")
	_expect(_read_text(SaveManager.get_save_path() + ".corrupt").is_empty(), "Corrupt marker preserves the original zero bytes")
	_expect(_read_text(SaveManager.get_backup_path()) == backup_before, "Recovery does not overwrite the valid backup")


func _test_newest_recovery_candidate_wins() -> void:
	_reset_case()
	var older_save: String = _save_currency(10, "Newest-candidate fixture saves an older generation")
	var previous_path: String = SaveManager.get_save_path() + ".previous"
	_expect(_write_text(previous_path, older_save), "Newest-candidate fixture writes a valid legacy previous file")
	var previous_mtime: int = FileAccess.get_modified_time(previous_path)
	OS.delay_msec(1200)
	var newer_save: String = _save_currency(11, "Newest-candidate fixture saves a newer main generation")
	var secondary_backup: String = SaveManager.get_save_path() + ".bak2"
	_expect(_write_text(secondary_backup, newer_save), "Newest-candidate fixture stores the newer secondary backup")
	_expect(FileAccess.get_modified_time(secondary_backup) > previous_mtime, "Secondary backup is newer than the legacy previous file")
	var empty_main: FileAccess = FileAccess.open(SaveManager.get_save_path(), FileAccess.WRITE)
	_expect(empty_main != null, "Newest-candidate fixture can truncate the main")
	if empty_main != null:
		empty_main.close()
	GameState.reset_to_default()
	_expect(SaveManager.load_game(), "Recovery chooses the newest valid candidate across previous and backup generations")
	_expect(GameState.get_currency("bubble_coin") == 11, "Newest secondary backup wins over an older valid previous file")
	_expect(_is_supported_save(_read_text(SaveManager.get_save_path())), "Newest-candidate recovery restores a valid main")
	_expect(_read_text(previous_path) == older_save, "Recovery does not erase the older valid previous file")


func _test_migration_preserves_fresh_backups() -> void:
	_reset_case()
	_save_currency(9, "Migration fixture creates supported pre-migration generations")
	var primary_before_migration: String = _read_text(SaveManager.get_backup_path())
	var secondary_path: String = SaveManager.get_save_path() + ".bak2"
	_expect(
		DirAccess.remove_absolute(ProjectSettings.globalize_path(secondary_path)) == OK,
		"Migration fixture uses the legacy single-backup layout"
	)
	var primary_mtime_before_migration: int = FileAccess.get_modified_time(SaveManager.get_backup_path())
	var legacy: Dictionary = {
		"schema_version": 1,
		"jellycat": {
			"id": "jc_007",
			"species_id": "normal_jellycat",
			"stage": 2,
			"hunger": 45,
			"mood": 62,
			"cleanliness": 81,
			"health": "healthy",
			"growth_exp": 120
		},
		"care_stats": {
			"touch_growth_exp_today": 4,
			"touch_exp_date": "2026-08-01",
			"last_touch_effect_at": 0.0,
			"touch_cap_notified_date": ""
		},
		"egg": {
			"egg_id": "egg_008",
			"species_id": "normal_jellycat",
			"current_clicks": 3,
			"required_clicks": 10,
			"is_hatched": false
		}
	}
	_expect(_write_text(SaveManager.get_save_path(), JSON.stringify(legacy)), "Migration fixture replaces main with supported schema-1 bytes")
	GameState.reset_to_default()
	_expect(SaveManager.load_game(), "Legacy save migrates while preserving the backup refresh interval")
	_expect(
		_read_text(SaveManager.get_backup_path()) == JSON.stringify(legacy),
		"Migration keeps the legacy main as the primary recovery backup"
	)
	_expect(
		_read_text(secondary_path) == primary_before_migration,
		"Migration preserves the prior primary backup in the secondary slot"
	)
	_expect(
		FileAccess.get_modified_time(secondary_path) == primary_mtime_before_migration,
		"Migration preserves the prior backup file's age while rotating its slot"
	)
	var migrated: Variant = JSON.parse_string(_read_text(SaveManager.get_save_path()))
	_expect(
		migrated is Dictionary and int((migrated as Dictionary).get("schema_version", 0)) == 2,
		"Migration still commits the current schema to the main file"
	)


func _test_two_invalid_files_block_and_preserve_bytes() -> void:
	_reset_case()
	var bad_main: String = "{broken-main-bytes"
	var bad_backup: String = "{broken-backup-bytes"
	var bad_backup_secondary: String = "{broken-secondary-backup-bytes"
	_expect(_write_text(SaveManager.get_save_path(), bad_main), "Malformed main fixture is written")
	_expect(_write_text(SaveManager.get_backup_path(), bad_backup), "Malformed backup fixture is written")
	_expect(_write_text(SaveManager.get_save_path() + ".bak2", bad_backup_secondary), "Malformed secondary backup fixture is written")
	GameState.reset_to_default()
	_expect(not SaveManager.load_game(), "Two invalid files block loading")
	_expect(SaveManager.load_blocked, "Two invalid files block later writes")
	_expect(_read_text(SaveManager.get_save_path()) == bad_main, "Blocked load preserves exact main bytes")
	_expect(_read_text(SaveManager.get_backup_path()) == bad_backup, "Blocked load preserves exact backup bytes")
	_expect(_read_text(SaveManager.get_save_path() + ".bak2") == bad_backup_secondary, "Blocked load preserves exact secondary backup bytes")
	GameState.set_currency("bubble_coin", 99)
	_expect(not SaveManager.save_game(), "Blocked load cannot overwrite the damaged files")
	_expect(_read_text(SaveManager.get_save_path()) == bad_main, "Rejected save leaves main bytes unchanged")
	_expect(_read_text(SaveManager.get_backup_path()) == bad_backup, "Rejected save leaves backup bytes unchanged")
	_expect(_read_text(SaveManager.get_save_path() + ".bak2") == bad_backup_secondary, "Rejected save leaves secondary backup bytes unchanged")


func _test_backup_reset_cleanup() -> void:
	_reset_case()
	_save_currency(15, "Backup-reset fixture creates both generations")
	var secondary_backup: String = SaveManager.get_save_path() + ".bak2"
	var secondary_temporary: String = secondary_backup + ".tmp"
	_expect(FileAccess.file_exists(secondary_backup), "Secondary backup is created for reset coverage")
	_expect(_write_text(secondary_temporary, "stale backup temp"), "Secondary backup temp fixture is created")
	SaveManager.reset_save()
	_expect(not FileAccess.file_exists(secondary_backup), "Reset removes the secondary backup")
	_expect(not FileAccess.file_exists(secondary_temporary), "Reset removes the secondary backup temp")


func _reset_case() -> void:
	SaveManager.set_write_interruption_point_for_test("")
	SaveManager.reset_save()


func _main_or_primary_backup_valid() -> bool:
	return _is_supported_save(_read_text(SaveManager.get_save_path())) or _is_supported_save(_read_text(SaveManager.get_backup_path()))


func _expect_backup_age_invariants(label: String) -> void:
	var backup_paths: Array[String] = [SaveManager.get_backup_path(), SaveManager.get_save_path() + ".bak2"]
	var valid_mtimes: Array[int] = []
	for backup_path in backup_paths:
		if _is_supported_save(_read_text(backup_path)):
			valid_mtimes.append(FileAccess.get_modified_time(backup_path))
	_expect(not valid_mtimes.is_empty(), "%s retains at least one valid backup" % label)
	if valid_mtimes.is_empty():
		return
	var oldest_mtime: int = valid_mtimes[0]
	for backup_mtime in valid_mtimes:
		if backup_mtime < oldest_mtime:
			oldest_mtime = backup_mtime
	var oldest_age: int = int(Time.get_unix_time_from_system()) - oldest_mtime
	_expect(oldest_age > 60, "%s keeps a valid backup older than 60 seconds" % label)
	_expect(oldest_age <= 125, "%s keeps the oldest valid backup within about two minutes" % label)


func _save_currency(amount: int, label: String) -> String:
	GameState.set_currency("bubble_coin", amount)
	_expect(SaveManager.save_game(), label)
	var text: String = _read_text(SaveManager.get_save_path())
	_expect(_is_supported_save(text), "%s writes a valid save" % label)
	_expect(_currency_from_text(text) == amount, "%s stores the expected currency" % label)
	return text


func _is_supported_save(text: String) -> bool:
	if text.is_empty():
		return false
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return false
	var prepared: Dictionary = GameState.prepare_data(parsed as Dictionary)
	return bool(prepared.get("ok", false))


func _currency_from_text(text: String) -> int:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return -1
	var currency: Variant = (parsed as Dictionary).get("currency", {})
	if not (currency is Dictionary):
		return -1
	return int((currency as Dictionary).get("bubble_coin", -1))


func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _write_text(path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	return error == OK


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("SAVE_DURABILITY_ACCEPTANCE_OK checks=%d" % checks)
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("SAVE_DURABILITY_ACCEPTANCE_FAIL: %s" % failure)
	print("SAVE_DURABILITY_ACCEPTANCE_FAILED checks=%d failures=%d" % [checks, failures.size()])
	get_tree().quit(1)
