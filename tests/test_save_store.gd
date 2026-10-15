extends GutTest
## SaveStore round-trips data, stamps a version, and survives a corrupt file.

const PATH: String = "user://test_save_store.json"


func after_each() -> void:
	SaveStore.delete_save(PATH)


func test_round_trip() -> void:
	var data := {"coins": 120, "levels": {"1": 3, "2": 2}, "haptics": true}
	assert_eq(SaveStore.save_data(data, PATH), OK)
	var loaded := SaveStore.load_data(PATH)
	assert_eq(int(loaded["coins"]), 120)
	assert_eq(int(loaded["levels"]["1"]), 3)
	assert_eq(loaded["haptics"], true)
	assert_eq(int(loaded["version"]), SaveStore.CURRENT_VERSION)


func test_missing_file_gives_fresh_save() -> void:
	var loaded := SaveStore.load_data(PATH)
	assert_eq(int(loaded["version"]), SaveStore.CURRENT_VERSION)
	assert_false(loaded.has("coins"))


func test_corrupt_file_gives_fresh_save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	var loaded := SaveStore.load_data(PATH)
	assert_false(loaded.has("coins"))
	assert_push_warning("unreadable save")
