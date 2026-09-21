## progression_manager.gd
## PORTS: web/src/tilt-to-live/ProgressionManager.ts (940 lines, source commit 7be9614)
class_name ProgressionManager
extends RefCounted
## Perk ranks, ships, cursors, enemy skins, arenas, steering tuning and the
## points economy.
##
## PORT-NOTE: partial port for Module 4 per spec §8 M4. Only the WeaponPerks
## record (ProgressionManager.ts:8-44) is ported, so WeaponSystem can thread
## perk ranks into Tuning.get_tuned_value. Everything else in this file lands
## in Module 7, extending this file in place exactly as M4 extended M2's
## weapon_system.gd.
## TODO(M7): the full port per spec §8 M7 (perk cost curve, buy_*, catalogs,
## multipliers, save shape).
##
## PORT-NOTE: ProgressionManager.ts:9-43 types each weapon's perks as an
## anonymous nested object. GDScript needs named types, so each nesting is an
## inner class named <Weapon>Perks; the field names inside are the TS names
## snake_cased and unchanged. Ranks default to 0 and keystones to false, which
## is exactly what `perks?.x.y || 0` / `!!perks?.x.y` read when perks is absent.


## PORT: web/src/tilt-to-live/ProgressionManager.ts:9-15
class BlackholePerks:
	extends RefCounted
	var duration: int = 0
	var radius: int = 0
	var gravity: int = 0
	var invulnerable_inside: bool = false
	var supernova_collapse: bool = false


## PORT: web/src/tilt-to-live/ProgressionManager.ts:16-20
class NukePerks:
	extends RefCounted
	var radius: int = 0
	var speed: int = 0
	var fallout_zone: bool = false


## PORT: web/src/tilt-to-live/ProgressionManager.ts:21-25
class ShieldPerks:
	extends RefCounted
	var duration: int = 0
	var radius: int = 0
	var battering_ram: bool = false


## PORT: web/src/tilt-to-live/ProgressionManager.ts:26-30
class MissilesPerks:
	extends RefCounted
	var count: int = 0
	var blast_radius: int = 0
	var flight_speed: int = 0


## PORT: web/src/tilt-to-live/ProgressionManager.ts:31-35
class LaserPerks:
	extends RefCounted
	var length: int = 0
	var duration: int = 0
	var cross_beam: bool = false


## PORT: web/src/tilt-to-live/ProgressionManager.ts:36-39
class LightningPerks:
	extends RefCounted
	var max_targets: int = 0
	var chain_range: int = 0


## PORT: web/src/tilt-to-live/ProgressionManager.ts:40-43
class FreezePerks:
	extends RefCounted
	var duration: int = 0
	var shatter_cascade: bool = false


## Per-weapon perk ranks and keystones. PORT: web/src/tilt-to-live/ProgressionManager.ts:8-44
class WeaponPerks:
	extends RefCounted
	var blackhole: BlackholePerks = BlackholePerks.new()
	var nuke: NukePerks = NukePerks.new()
	var shield: ShieldPerks = ShieldPerks.new()
	var missiles: MissilesPerks = MissilesPerks.new()
	var laser: LaserPerks = LaserPerks.new()
	var lightning: LightningPerks = LightningPerks.new()
	var freeze: FreezePerks = FreezePerks.new()
