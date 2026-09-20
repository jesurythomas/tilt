## test_types.gd
## PORTS: nothing — new file, covers src/core/types.gd
extends GutTest
## Covers the enum shapes and proves typed arrays of inner record classes
## compile, which every later module depends on.


func test_enum_members_match_the_typescript_unions() -> void:
	assert_eq(Types.GamePhase.size(), 5, "Types.ts:5 lists five phases")
	assert_eq(Types.GameMode.size(), 3, "Types.ts:7 lists three modes")
	assert_eq(Types.WeaponType.size(), 7, "Types.ts:9-16 lists seven weapons")
	assert_eq(Types.EnemyType.size(), 13, "Types.ts:18-31 lists thirteen enemies")


func test_typed_array_of_inner_record_compiles_and_holds() -> void:
	var enemies: Array[Types.Enemy] = []
	var e: Types.Enemy = Types.Enemy.new()
	e.type = Types.EnemyType.SEEKER
	e.radius = 5.0
	enemies.append(e)
	assert_eq(enemies.size(), 1, "typed array of an inner class accepts an element")
	assert_eq(enemies[0].type, Types.EnemyType.SEEKER, "element keeps its typed field")


func test_optional_fields_use_the_absent_sentinel() -> void:
	var e: Types.Enemy = Types.Enemy.new()
	assert_eq(e.state, Types.ABSENT, "state? is absent until a module sets it")
	assert_eq(e.leader_id, Types.ABSENT, "leaderId? is absent until a module sets it")
