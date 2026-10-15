extends GutTest
## Responsive layout helpers: grid columns per width, the max-width column, safe-area margins.


func test_level_grid_columns_for_phone_tablet_and_foldable() -> void:
	# Content widths: phone 720 - 2*32 margins, a 3:4 tablet, a near-square foldable.
	assert_eq(AdaptiveGridContainer.columns_for(656, 136, 20, 3, 6), 4)
	assert_eq(AdaptiveGridContainer.columns_for(896, 136, 20, 3, 6), 5)
	assert_eq(AdaptiveGridContainer.columns_for(1016, 136, 20, 3, 6), 6)
	assert_eq(AdaptiveGridContainer.columns_for(300, 136, 20, 3, 6), 3, "never fewer than min_columns")
	assert_eq(AdaptiveGridContainer.columns_for(0, 136, 20, 3, 6), 3)


func test_max_width_container_centres_its_child() -> void:
	var column := MaxWidthContainer.new()
	column.max_width = 600.0
	var child := Control.new()
	column.add_child(child)
	add_child_autofree(column)
	column.size = Vector2(960, 1280)
	await wait_process_frames(2)
	assert_eq(child.size.x, 600.0)
	assert_eq(child.position.x, 180.0)
	column.size = Vector2(500, 1280)
	await wait_process_frames(2)
	assert_eq(child.size.x, 500.0, "narrower than max_width: use the full width")


func test_safe_area_margin_applies_simulated_insets() -> void:
	var margin := SafeAreaMargin.new()
	margin.extra_margin = 10
	add_child_autofree(margin)
	SafeAreaMargin.set_simulated_insets(get_tree(), Vector4i(0, 64, 0, 32))
	assert_eq(margin.get_theme_constant(&"margin_top"), 74)
	assert_eq(margin.get_theme_constant(&"margin_bottom"), 42)
	assert_eq(margin.get_theme_constant(&"margin_left"), 10)
	SafeAreaMargin.set_simulated_insets(get_tree(), Vector4i.ZERO)
	assert_eq(margin.get_theme_constant(&"margin_top"), 10, "insets removed again")
