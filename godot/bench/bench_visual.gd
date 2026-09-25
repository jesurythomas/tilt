## bench_visual.gd — old primitives (left) vs CircleSprites (right), zoomed (scratch).
extends GutTest

class Pair:
	extends Node2D
	func _dot(old: bool, at: Vector2, r: float, pulse: float) -> void:
		draw_set_transform(at, 0.0, Vector2.ONE * 6.0)
		var cols: Array[Color] = [Color(1, 30.0/255, 60.0/255, 0.7), Color(1, 30.0/255, 60.0/255, 0.35), Color("#ee1133"), Color("#ff6677"), Color("#ff8899"), Color("#110005")]
		if old:
			draw_arc(Vector2.ZERO, (r + 5.0) * pulse, 0.0, TAU, 24, cols[0], 1.2)
			draw_circle(Vector2.ZERO, (r + 4.0) * pulse, cols[1])
			draw_circle(Vector2.ZERO, r, cols[2])
			draw_circle(Vector2.ZERO, r * 0.65, cols[3])
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, cols[4], 1.2)
			draw_circle(Vector2.ZERO, r * 0.38, cols[5])
		else:
			CircleSprites.draw_ring(self, Vector2.ZERO, (r + 5.0) * pulse, 1.2, cols[0])
			CircleSprites.draw_disc(self, Vector2.ZERO, (r + 4.0) * pulse, cols[1])
			CircleSprites.draw_disc(self, Vector2.ZERO, r, cols[2])
			CircleSprites.draw_disc(self, Vector2.ZERO, r * 0.65, cols[3])
			CircleSprites.draw_ring(self, Vector2.ZERO, r, 1.2, cols[4])
			CircleSprites.draw_disc(self, Vector2.ZERO, r * 0.38, cols[5])
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color("#0b0d14"))
		_dot(true, Vector2(160, 250), 8.75, 1.0)
		_dot(false, Vector2(460, 250), 8.75, 1.0)
		_dot(true, Vector2(160, 540), 7.0, 0.85)
		_dot(false, Vector2(460, 540), 7.0, 0.85)

func test_capture() -> void:
	var n: Pair = Pair.new()
	add_child_autofree(n)
	for f: int in range(5):
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OS.get_environment("OUT_PNG"))
	pass_test("ok")
