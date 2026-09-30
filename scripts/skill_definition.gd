class_name SkillDefinition
extends Resource

enum EffectType {
	PAWN_ATTACK_RANGE,
	KING_LIVES,
	RUN_MATERIAL_MULTIPLIER,
	PAWN_PHALANX_INTERVAL_MULTIPLIER,
	KNIGHT_INTERVAL_MULTIPLIER,
	BISHOP_SLOW_PERCENT,
	ROOK_PUSHBACK_DISTANCE,
	QUEEN_AURA_RADIUS,
	GLOBAL_INTERVAL_MULTIPLIER
}

@export var skill_id := ""
@export var display_name := ""
@export_multiline var description := ""
@export var icon: Texture2D
@export var cost := 0
@export var effect_type: EffectType
@export var effect_value := 0.0
