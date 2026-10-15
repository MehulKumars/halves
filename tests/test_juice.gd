extends GutTest
## Juice tweens must always settle back to the node's original scale, even when
## effects are retriggered mid-animation (rapid matches, combo chains).


func after_each() -> void:
	Juice.motion_scale = 1.0


func test_single_pop_returns_to_rest_scale() -> void:
	var node: Node2D = add_child_autofree(Node2D.new())
	node.scale = Vector2(2.0, 2.0)
	Juice.pop(node)
	await wait_seconds(0.3)
	assert_almost_eq(node.scale, Vector2(2.0, 2.0), Vector2(0.001, 0.001))


func test_rapid_pops_do_not_drift() -> void:
	var node: Node2D = add_child_autofree(Node2D.new())
	for i in 4:
		Juice.pop(node)
		await wait_seconds(0.04)
	await wait_seconds(0.3)
	assert_almost_eq(node.scale, Vector2.ONE, Vector2(0.001, 0.001))


func test_squash_interrupted_by_pop_returns_to_rest() -> void:
	var node: Node2D = add_child_autofree(Node2D.new())
	Juice.squash(node)
	await wait_seconds(0.03)
	Juice.pop(node)
	await wait_seconds(0.3)
	assert_almost_eq(node.scale, Vector2.ONE, Vector2(0.001, 0.001))


func test_reduced_motion_skips_effects() -> void:
	var node: Node2D = add_child_autofree(Node2D.new())
	Juice.motion_scale = 0.0
	assert_null(Juice.pop(node))
	assert_eq(node.scale, Vector2.ONE)
