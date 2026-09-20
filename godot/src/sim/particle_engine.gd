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

const MAX_PARTICLES: int = 900  # PORT: web/src/tilt-to-live/ParticleEngine.ts:21

# PORT-NOTE: private in ParticleEngine.ts:20; public here because
# ParticleEngine.render() relocates to render/effect_layer.gd (spec §4.2/D4).
## Live particles, oldest first.
var particles: Array[Particle] = []


## Empties the pool. PORT: web/src/tilt-to-live/ParticleEngine.ts:23-25
func reset() -> void:
	particles = []


## Integrates and retires particles. PORT: web/src/tilt-to-live/ParticleEngine.ts:27-44
func update(dt: float) -> void:
	for i: int in range(particles.size() - 1, -1, -1):
		var p: Particle = particles[i]
		p.x += p.vx * dt
		p.y += p.vy * dt
		p.vx *= p.friction
		p.vy *= p.friction
		p.life -= dt

		if p.shape == Shape.RING:
			p.size += 220.0 * dt  # PORT: web/src/tilt-to-live/ParticleEngine.ts:37

		if p.life <= 0.0:
			particles.remove_at(i)


## Emits omnidirectional sparks. PORT: web/src/tilt-to-live/ParticleEngine.ts:46-67
func emit_sparks(x: float, y: float, count: int, color: Color, speed_max: float = 180.0) -> void:
	for i: int in range(count):
		if particles.size() >= MAX_PARTICLES:
			break
		var angle: float = randf() * PI * 2.0
		var speed: float = 20.0 + randf() * speed_max  # PORT: web/src/tilt-to-live/ParticleEngine.ts:50
		var life: float = 0.3 + randf() * 0.45  # PORT: web/src/tilt-to-live/ParticleEngine.ts:51

		var p: Particle = Particle.new()
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


# TODO(M2): port emit_explosion, emit_smoke, emit_ice_shatter,
# emit_blizzard_snow, emit_kinetic_ice_shards and emit_thruster_sparks
# (ParticleEngine.ts:69-197), and relocate render() (ParticleEngine.ts:199-234)
# into render/effect_layer.gd.


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
