# components/combat/health_component.gd
## Reusable health component. Works with any Node — not just characters.
## Attach to players, enemies, destructibles, anything with health.
class_name HealthComponent
extends Node

@export_group("Health")
@export var max_health: int = 100
## If true, starts at max_health. If false, set starting_health.
@export var start_at_max: bool = true
@export var starting_health: int = 100

@export_group("Invincibility")
## Brief invincibility after taking damage
@export var enable_iframes: bool = false
@export var iframe_duration: float = 0.5

@export_group("Damage Modifiers")
## Multiplier applied to all incoming damage (0.5 = half damage, 2.0 = double)
@export var damage_multiplier: float = 1.0
## If true, a single hit can never do more than max_health
@export var cap_damage_to_max: bool = true
## Minimum damage that can be dealt (after multiplier). 0 = no minimum.
@export var minimum_damage: int = 0

@export_group("Death")
## If true, automatically calls queue_free on the parent when health reaches 0
@export var auto_destroy: bool = false
## Delay before auto destroy (for death animations)
@export var auto_destroy_delay: float = 0.0

var current_health: int
var is_dead: bool = false
var is_invincible: bool = false

var _iframe_timer: float = 0.0

# ── Signals ──
signal health_changed(old_value: int, new_value: int)
signal damaged(amount: int, source: Node)
signal healed(amount: int, source: Node)
signal died(killing_source: Node)
signal revived

# ── Convenience properties ──
var health_percentage: float:
	get:
		if max_health <= 0:
			return 0.0
		return float(current_health) / float(max_health)

var is_full_health: bool:
	get:
		return current_health >= max_health

var missing_health: int:
	get:
		return max_health - current_health

func _ready() -> void:
	if start_at_max:
		current_health = max_health
	else:
		current_health = mini(starting_health, max_health)

func _physics_process(delta: float) -> void:
	if _iframe_timer > 0.0:
		_iframe_timer -= delta
		if _iframe_timer <= 0.0:
			is_invincible = false

## Deal damage to this entity. Returns actual damage dealt.
func take_damage(amount: int, source: Node = null) -> int:
	if is_dead:
		return 0
	if is_invincible:
		return 0
	if amount <= 0:
		return 0

	# Apply multiplier
	var actual := int(ceil(amount * damage_multiplier))

	# Apply minimum
	if minimum_damage > 0:
		actual = maxi(actual, minimum_damage)

	# Cap to max health
	if cap_damage_to_max:
		actual = mini(actual, max_health)

	# Don't deal more than current health
	actual = mini(actual, current_health)

	var old_health := current_health
	current_health -= actual

	health_changed.emit(old_health, current_health)
	damaged.emit(actual, source)

	# Start iframes
	if enable_iframes and not is_dead:
		is_invincible = true
		_iframe_timer = iframe_duration

	# Check death
	if current_health <= 0:
		_die(source)

	return actual

## Heal this entity. Returns actual amount healed.
func heal(amount: int, source: Node = null) -> int:
	if is_dead:
		return 0
	if amount <= 0:
		return 0

	var actual := mini(amount, missing_health)

	if actual <= 0:
		return 0

	var old_health := current_health
	current_health += actual

	health_changed.emit(old_health, current_health)
	healed.emit(actual, source)

	return actual

## Set health directly. Bypasses damage multiplier and iframes.
func set_health(value: int) -> void:
	var old_health := current_health
	current_health = clampi(value, 0, max_health)

	if old_health != current_health:
		health_changed.emit(old_health, current_health)

	if current_health <= 0 and not is_dead:
		_die(null)

## Kill instantly regardless of health or invincibility.
func kill(source: Node = null) -> void:
	if is_dead:
		return

	var old_health := current_health
	current_health = 0
	health_changed.emit(old_health, 0)
	_die(source)

## Bring back from death with specified health.
func revive(health: int = -1) -> void:
	if not is_dead:
		return

	is_dead = false
	is_invincible = false
	_iframe_timer = 0.0

	var revive_health := health if health > 0 else max_health
	var old_health := current_health
	current_health = mini(revive_health, max_health)

	health_changed.emit(old_health, current_health)
	revived.emit()

## Change max health. Can optionally scale current health proportionally.
func set_max_health(new_max: int, scale_current: bool = false) -> void:
	if new_max <= 0:
		return

	var old_health := current_health

	if scale_current and max_health > 0:
		var ratio := float(current_health) / float(max_health)
		max_health = new_max
		current_health = int(ceil(ratio * max_health))
	else:
		max_health = new_max
		current_health = mini(current_health, max_health)

	if old_health != current_health:
		health_changed.emit(old_health, current_health)

func _die(source: Node) -> void:
	is_dead = true
	is_invincible = false
	_iframe_timer = 0.0
	died.emit(source)

	if auto_destroy:
		if auto_destroy_delay > 0.0:
			await get_tree().create_timer(auto_destroy_delay).timeout
		get_parent().queue_free()
