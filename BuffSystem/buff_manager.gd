# components/buffs/buff_manager.gd
class_name BuffManager
extends Node

@export var priority: int = 22

var active_buffs: Array[ActiveBuff] = []

var _character: CharacterBody3D
var _health: HealthComponent

signal buff_applied(buff: ActiveBuff)
signal buff_removed(buff: ActiveBuff)
signal buff_stacked(buff: ActiveBuff)
signal buff_refreshed(buff: ActiveBuff)

func _ready() -> void:
	_character = _find_character_body()
	if _character:
		_health = _find_health()

func _find_character_body() -> CharacterBody3D:
	var node := get_parent()
	while node:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null

func _find_health() -> HealthComponent:
	if not _character:
		return null
	for child in _character.get_children():
		if child is HealthComponent:
			return child
	return null

func apply_buff(effect: BuffEffect) -> ActiveBuff:
	var existing := get_buff(effect.buff_name)

	if existing:
		if effect.stackable:
			if existing.add_stack():
				buff_stacked.emit(existing)
			if effect.refresh_on_reapply:
				existing.refresh()
				buff_refreshed.emit(existing)
			return existing
		elif effect.refresh_on_reapply:
			existing.refresh()
			buff_refreshed.emit(existing)
			return existing
		else:
			return existing

	var buff := ActiveBuff.new(effect)
	active_buffs.append(buff)
	buff_applied.emit(buff)
	return buff

func remove_buff(buff_name: String) -> void:
	for i in range(active_buffs.size() - 1, -1, -1):
		if active_buffs[i].effect.buff_name == buff_name:
			var buff := active_buffs[i]
			active_buffs.remove_at(i)
			buff_removed.emit(buff)
			return

func clear_all_buffs() -> void:
	for buff in active_buffs.duplicate():
		active_buffs.erase(buff)
		buff_removed.emit(buff)

func remove_buffs_with_tag(tag: Enums.BuffTag) -> void:
	for i in range(active_buffs.size() - 1, -1, -1):
		if tag in active_buffs[i].effect.tags:
			var buff := active_buffs[i]
			active_buffs.remove_at(i)
			buff_removed.emit(buff)

func get_buff(buff_name: String) -> ActiveBuff:
	for buff in active_buffs:
		if buff.effect.buff_name == buff_name:
			return buff
	return null

func has_buff(buff_name: String) -> bool:
	return get_buff(buff_name) != null

func has_buff_with_tag(tag: Enums.BuffTag) -> bool:
	for buff in active_buffs:
		if tag in buff.effect.tags:
			return true
	return false

func get_speed_multiplier() -> float:
	var mult := 1.0
	for buff in active_buffs:
		if buff.effect.modify_speed:
			mult *= pow(buff.effect.speed_multiplier, buff.stacks)
	return mult

func get_jump_multiplier() -> float:
	var mult := 1.0
	for buff in active_buffs:
		if buff.effect.modify_jump:
			mult *= pow(buff.effect.jump_multiplier, buff.stacks)
	return mult

func get_gravity_multiplier() -> float:
	var mult := 1.0
	for buff in active_buffs:
		if buff.effect.modify_gravity:
			mult *= pow(buff.effect.gravity_multiplier, buff.stacks)
	return mult

func get_damage_taken_multiplier() -> float:
	var mult := 1.0
	for buff in active_buffs:
		if buff.effect.modify_damage_taken:
			mult *= pow(buff.effect.damage_taken_multiplier, buff.stacks)
	return mult

func process_physics(data: CharacterData, delta: float) -> void:
	for i in range(active_buffs.size() - 1, -1, -1):
		var buff := active_buffs[i]
		var should_tick := buff.tick(delta)

		if should_tick and _health and buff.effect.health_per_tick != 0:
			var amount := buff.effect.health_per_tick * buff.stacks
			if amount > 0:
				_health.heal(amount)
			else:
				_health.take_damage(-amount)

		if buff.is_expired:
			active_buffs.remove_at(i)
			buff_removed.emit(buff)

	data.move_speed *= get_speed_multiplier()
