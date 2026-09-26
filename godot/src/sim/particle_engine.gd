## particle_engine.gd
## PORTS: web/src/tilt-to-live/ParticleEngine.ts (235 lines, source commit 7be9614)
class_name ParticleEngine
extends RefCounted
## Pooled vector particles.
##
## PORT-NOTE: partial port. M1 needs only what PlayerShip.update() calls
## (web/src/tilt-to-live/PlayerShip.ts:243-257), so this file carries reset(), update() and
## emit_sparks() alone. The remaining emitters and the draw body are M2's, per
## spec §8 Module 2. The members present are in TypeScript source order so the
## completed file still diffs side by side (Law 3).
##
## Instantiated twice concurrently once MenuBackdrop lands (spec §5.2).

## PORT: web/src/tilt-to-live/ParticleEngine.ts:14
enum Shape { CIRCLE, STREAK, RING, SHARD }

# DIVERGENCE(M2.5 §10): capped pool to 400 down from 900 to prevent
# garbage collection and GPU spikes on mobile.
const MAX_PARTICLES: int = 400

# PORT-NOTE: private in ParticleEngine.ts:20; public here because
# ParticleEngine.render() relocates to render/effect_layer.gd (spec §4.2/D4).
## Live particles, oldest first.
var particles: Array[Particle] = []
## DIVERGENCE(M11c P12): retired particles, reused by the next emit instead of
## allocating (the TS relies on its GC; a GDScript object per spark costs ~2 us).
var _pool: Array[Particle] = []


## Empties the pool. PORT: web/src/tilt-to-live/ParticleEngine.ts:23-25
func reset() -> void:
	_pool.append_array(particles)
	particles = []


## Retired particles waiting for reuse (M11c P12).
func pooled_count() -> int:
	return _pool.size()


## A fresh or recycled particle; every emitter sets every field it reads.
## DIVERGENCE(M11c P12): replaces Particle.new() at each emit site.
func _take() -> Particle:
	if _pool.is_empty():
		return Particle.new()
	return _pool.pop_back()


## Integrates and retires particles. PORT: web/src/tilt-to-live/ParticleEngine.ts:27-44
# DIVERGENCE(M11c P12): one forward pass compacts survivors in place (oldest first,
# as before) instead of remove_at per death, which shifted the array each time.
func update(dt: float) -> void:
	var kept: int = 0
	for i: int in range(particles.size()):
		var p: Particle = particles[i]
		p.x += p.vx * dt
		p.y += p.vy * dt
		p.vx *= p.friction
		p.vy *= p.friction
		p.life -= dt

		if p.shape == Shape.RING:
			p.size += 220.0 * dt  # PORT: web/src/tilt-to-live/ParticleEngine.ts:37

		if p.life <= 0.0:
			_pool.append(p)
		else:
			particles[kept] = p
			kept += 1
	particles.resize(kept)


## Emits omnidirectional sparks. PORT: web/src/tilt-to-live/ParticleEngine.ts:46-67
func emit_sparks(x: float, y: float, count: int, color: Color, speed_max: float = 180.0) -> void:
	for i: int in range(count):
		if particles.size() >= MAX_PARTICLES:
			break
		var angle: float = randf() * PI * 2.0
		var speed: float = 20.0 + randf() * speed_max  # PORT: web/src/tilt-to-live/ParticleEngine.ts:50
		var life: float = 0.3 + randf() * 0.45  # PORT: web/src/tilt-to-live/ParticleEngine.ts:51

		var p: Particle = _take()
		p.x = x
		p.y = y
		p.vx = cos(angle) * speed
		p.vy = sin(angle) * speed
		p.life = life
		p.max_life = life
		p.size = 2.0 + randf() * 2.5  # PORT: web/src/tilt-to-live/ParticleEngine.ts:60
		p.color = color
		# PORT: web/src/tilt-to-live/ParticleEngine.ts:62
		p.shape = Shape.STREAK if randf() < 0.4 else Shape.CIRCLE
		p.decay = 1.0
		p.friction = 0.94  # PORT: web/src/tilt-to-live/ParticleEngine.ts:64
		particles.append(p)


## Emits explosion shockwave and sparks. PORT: web/src/tilt-to-live/ParticleEngine.ts:69-88
func emit_explosion(x: float, y: float, color: Color = Color("#ff3344"), count: int = 32) -> void:
	emit_sparks(x, y, count, color, 300.0)  # PORT: web/src/tilt-to-live/ParticleEngine.ts:70

	# Add expanding shockwave ring. PORT: web/src/tilt-to-live/ParticleEngine.ts:72-87
	if particles.size() < MAX_PARTICLES:
		var p: Particle = _take()
		p.x = x
		p.y = y
		p.vx = 0.0
		p.vy = 0.0
		p.life = 0.35  # PORT: web/src/tilt-to-live/ParticleEngine.ts:79
		p.max_life = 0.35  # PORT: web/src/tilt-to-live/ParticleEngine.ts:80
		p.size = 8.0  # PORT: web/src/tilt-to-live/ParticleEngine.ts:81
		p.color = color
		p.shape = Shape.RING  # PORT: web/src/tilt-to-live/ParticleEngine.ts:83
		p.decay = 1.0
		p.friction = 1.0
		particles.append(p)


## Emits smoke motes. PORT: web/src/tilt-to-live/ParticleEngine.ts:90-109
func emit_smoke(
	x: float, y: float, color: Color = Color(200.0 / 255.0, 210.0 / 255.0, 225.0 / 255.0, 0.4)
) -> void:
	if particles.size() >= MAX_PARTICLES:
		return
	var angle: float = randf() * PI * 2.0
	var speed: float = 10.0 + randf() * 30.0  # PORT: web/src/tilt-to-live/ParticleEngine.ts:93
	var life: float = 0.4 + randf() * 0.3  # PORT: web/src/tilt-to-live/ParticleEngine.ts:94

	var p: Particle = _take()
	p.x = x
	p.y = y
	p.vx = cos(angle) * speed
	p.vy = sin(angle) * speed
	p.life = life
	p.max_life = life
	p.size = 3.0 + randf() * 3.0  # PORT: web/src/tilt-to-live/ParticleEngine.ts:103
	p.color = color
	p.shape = Shape.CIRCLE  # PORT: web/src/tilt-to-live/ParticleEngine.ts:105
	p.decay = 1.0
	p.friction = 0.92  # PORT: web/src/tilt-to-live/ParticleEngine.ts:107
	particles.append(p)


## Emits shattering ice shards. PORT: web/src/tilt-to-live/ParticleEngine.ts:111-132
func emit_ice_shatter(x: float, y: float, count: int = 18) -> void:
	for i: int in range(count):
		if particles.size() >= MAX_PARTICLES:
			break
		var angle: float = randf() * PI * 2.0
		var speed: float = 60.0 + randf() * 220.0  # PORT: web/src/tilt-to-live/ParticleEngine.ts:115
		var life: float = 0.4 + randf() * 0.4  # PORT: web/src/tilt-to-live/ParticleEngine.ts:116

		var p: Particle = _take()
		p.x = x
		p.y = y
		p.vx = cos(angle) * speed
		p.vy = sin(angle) * speed
		p.life = life
		p.max_life = life
		p.size = 3.0 + randf() * 4.0  # PORT: web/src/tilt-to-live/ParticleEngine.ts:125
		# PORT: web/src/tilt-to-live/ParticleEngine.ts:126
		p.color = Color("#88eeff") if randf() < 0.6 else Color("#ffffff")
		p.shape = Shape.SHARD  # PORT: web/src/tilt-to-live/ParticleEngine.ts:127
		p.decay = 1.0
		p.friction = 0.95  # PORT: web/src/tilt-to-live/ParticleEngine.ts:129
		particles.append(p)


## Emits drifting blizzard snow particles. PORT: web/src/tilt-to-live/ParticleEngine.ts:134-154
func emit_blizzard_snow(bounds: Vector2, count: int = 2) -> void:
	for i: int in range(count):
		if particles.size() >= MAX_PARTICLES:
			break
		var x: float = randf() * bounds.x  # PORT: web/src/tilt-to-live/ParticleEngine.ts:137
		var y: float = -10.0  # PORT: web/src/tilt-to-live/ParticleEngine.ts:138
		var life: float = 3.5 + randf() * 2.0  # PORT: web/src/tilt-to-live/ParticleEngine.ts:139

		var p: Particle = _take()
		p.x = x
		p.y = y
		# PORT: web/src/tilt-to-live/ParticleEngine.ts:143-144
		p.vx = (randf() * 50.0 - 25.0) - 15.0
		p.vy = 45.0 + randf() * 55.0
		p.life = life
		p.max_life = life
		p.size = 1.5 + randf() * 2.2  # PORT: web/src/tilt-to-live/ParticleEngine.ts:147
		# PORT: web/src/tilt-to-live/ParticleEngine.ts:148
		p.color = Color("#c8f2ff") if randf() < 0.6 else Color("#ffffff")
		p.shape = Shape.CIRCLE  # PORT: web/src/tilt-to-live/ParticleEngine.ts:149
		p.decay = 1.0
		p.friction = 0.99  # PORT: web/src/tilt-to-live/ParticleEngine.ts:151
		particles.append(p)


## Emits radial kinetic ice shards. PORT: web/src/tilt-to-live/ParticleEngine.ts:156-176
func emit_kinetic_ice_shards(x: float, y: float, count: int = 8) -> void:
	for i: int in range(count):
		if particles.size() >= MAX_PARTICLES:
			break
		# PORT: web/src/tilt-to-live/ParticleEngine.ts:159-161
		var angle: float = (float(i) * PI * 2.0) / float(count) + (randf() * 0.2 - 0.1)
		var speed: float = 340.0 + randf() * 100.0
		var life: float = 0.45 + randf() * 0.25

		var p: Particle = _take()
		p.x = x
		p.y = y
		p.vx = cos(angle) * speed
		p.vy = sin(angle) * speed
		p.life = life
		p.max_life = life
		p.size = 3.5 + randf() * 2.5  # PORT: web/src/tilt-to-live/ParticleEngine.ts:169
		p.color = Color("#b8f0ff")  # PORT: web/src/tilt-to-live/ParticleEngine.ts:170
		p.shape = Shape.SHARD  # PORT: web/src/tilt-to-live/ParticleEngine.ts:171
		p.decay = 1.0
		p.friction = 0.96  # PORT: web/src/tilt-to-live/ParticleEngine.ts:173
		particles.append(p)


## Emits directional thruster exhaust sparks. PORT: web/src/tilt-to-live/ParticleEngine.ts:178-197
func emit_thruster_sparks(
	x: float, y: float, angle: float, color: Color = Color("#ff5500")
) -> void:
	if particles.size() >= MAX_PARTICLES:
		return
	var spread: float = (randf() - 0.5) * 0.6  # PORT: web/src/tilt-to-live/ParticleEngine.ts:180
	var final_angle: float = angle + spread
	var speed: float = 70.0 + randf() * 120.0  # PORT: web/src/tilt-to-live/ParticleEngine.ts:182
	var life: float = 0.2 + randf() * 0.2  # PORT: web/src/tilt-to-live/ParticleEngine.ts:183

	var p: Particle = _take()
	p.x = x
	p.y = y
	p.vx = cos(final_angle) * speed
	p.vy = sin(final_angle) * speed
	p.life = life
	p.max_life = life
	p.size = 2.0 + randf() * 2.0  # PORT: web/src/tilt-to-live/ParticleEngine.ts:191
	p.color = color
	p.shape = Shape.STREAK  # PORT: web/src/tilt-to-live/ParticleEngine.ts:193
	p.decay = 1.0
	p.friction = 0.92  # PORT: web/src/tilt-to-live/ParticleEngine.ts:195
	particles.append(p)


## PORT: web/src/tilt-to-live/ParticleEngine.ts:5-17
class Particle:
	extends RefCounted
	var x: float = 0.0
	var y: float = 0.0
	var vx: float = 0.0
	var vy: float = 0.0
	var life: float = 0.0
	var max_life: float = 0.0
	var size: float = 0.0
	# PORT-NOTE: ParticleEngine.ts:13 types this as a CSS colour string.
	var color: Color = Color.WHITE
	var shape: Shape = Shape.CIRCLE
	var decay: float = 0.0
	var friction: float = 0.0
