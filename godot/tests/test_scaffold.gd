## test_scaffold.gd
## PORTS: nothing — new file, scaffold verification per spec §6.3
extends GutTest
## Proves the GUT harness executes headless. Also carries the warning
## enforcement proof in Task 4.


func test_gut_executes_headless() -> void:
	assert_true(true, "GUT ran this assertion headless")
