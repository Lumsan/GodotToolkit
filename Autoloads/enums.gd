# game/shared/enums.gd
## Centralized enums for the entire project.
class_name Enums

enum Team {
	PLAYER,
	ENEMY,
	NEUTRAL,
}

enum DamageType {
	PHYSICAL,
	FIRE,
	ICE,
	ELECTRIC,
	POISON,
	HOLY,
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

enum InteractionType {
	PICKUP,
	TOGGLE,
	HOLD,
	TALK,
}

enum BuffTag {
	BUFF,
	DEBUFF,
	MOVEMENT,
	DEFENSIVE,
	OFFENSIVE,
	HEAL_OVER_TIME,
	DAMAGE_OVER_TIME,
	POISON,
	FIRE,
	ICE,
	ELECTRIC,
	STUN,
}
