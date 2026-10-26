extends Node2D
## Arcade projectiles: limes thrown by the taquero (lightly homing) and empty cans tossed by
## El Gorrón (dodge them with SPACE). Hits are resolved when a projectile lands.

const Pix = preload("res://scripts/art/pix.gd")

signal lime_hit(target)
signal can_hit_player()

var projectiles: Array = []
var splats: Array = []
var target_enemy = null
var player = null


func throw_lime(from: Vector2, to: Vector2) -> void:
	var dur := clampf(from.distance_to(to) / 300.0, 0.18, 0.45)
	projectiles.append({"kind": "lime", "from": from, "to": to, "t": 0.0, "dur": dur, "arc": 14.0, "pos": from})
	AudioManager.play("throw")


func throw_can(from: Vector2, to: Vector2) -> void:
	projectiles.append({"kind": "can", "from": from, "to": to, "t": 0.0, "dur": 0.8, "arc": 28.0, "pos": from})
	AudioManager.play("throw", -4.0, 0.8)


func step(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p: Dictionary = projectiles[i]
		p["t"] += delta
		if p["kind"] == "lime" and target_enemy != null and is_instance_valid(target_enemy) and target_enemy.is_active():
			p["to"] = (p["to"] as Vector2).lerp(target_enemy.position + Vector2(0, -16), minf(1.0, delta * 6.0))
		var k := clampf(p["t"] / p["dur"], 0.0, 1.0)
		var base: Vector2 = (p["from"] as Vector2).lerp(p["to"], k)
		base.y -= p["arc"] * 4.0 * k * (1.0 - k)
		p["pos"] = base
		if k >= 1.0:
			_land(p)
			projectiles.remove_at(i)
	for i in range(splats.size() - 1, -1, -1):
		splats[i]["t"] += delta
		if splats[i]["t"] > 0.5:
			splats.remove_at(i)
	queue_redraw()


func _land(p: Dictionary) -> void:
	var at: Vector2 = p["pos"]
	if p["kind"] == "lime":
		if target_enemy != null and is_instance_valid(target_enemy) and target_enemy.is_active() \
				and at.distance_to(target_enemy.position + Vector2(0, -16)) < 20.0:
			lime_hit.emit(target_enemy)
		splats.append({"pos": at, "t": 0.0, "col": Pix.C_LIME})
	else:
		if player != null and at.distance_to(player.position + Vector2(0, -12)) < 18.0 and player.invuln_t <= 0.0:
			can_hit_player.emit()
		else:
			AudioManager.play("can", -4.0)
		splats.append({"pos": at, "t": 0.0, "col": Color("c0c4c8")})


func _draw() -> void:
	for p in projectiles:
		var pos: Vector2 = p["pos"]
		if p["kind"] == "lime":
			Pix.icon_lime(self, pos, 3.5)
		else:
			var spin := int(p["t"] * 20.0) % 2 == 0
			if spin:
				Pix.r(self, pos.x - 2, pos.y - 4, 4, 8, Color("c0c4c8"))
				Pix.r(self, pos.x - 2, pos.y - 1, 4, 2, Color("c1121f"))
			else:
				Pix.r(self, pos.x - 4, pos.y - 2, 8, 4, Color("c0c4c8"))
				Pix.r(self, pos.x - 1, pos.y - 2, 2, 4, Color("c1121f"))
	for s in splats:
		var a: float = 1.0 - s["t"] / 0.5
		for i in 5:
			var ang := i * TAU / 5.0
			var rr: float = 3.0 + s["t"] * 18.0
			Pix.r(self, s["pos"].x + cos(ang) * rr - 1, s["pos"].y + sin(ang) * rr - 1, 2, 2, Color(s["col"], a))
