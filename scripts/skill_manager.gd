extends Node

## Owns the permanent skill collection. Definitions are read-only resources;
## only the owned IDs are persisted.

const SAVE_SECTION := "skills"
const OWNED_KEY := "owned_skill_ids"
const QUEEN_AURA_INTERVAL_MULTIPLIER := 0.85

const DEFINITIONS: Array[SkillDefinition] = [
	preload("res://resources/skills/royal_reserve.tres"),
	preload("res://resources/skills/pawn_push.tres"),
	preload("res://resources/skills/material_ledger.tres"),
	preload("res://resources/skills/pawn_phalanx.tres"),
	preload("res://resources/skills/bishops_bind.tres"),
	preload("res://resources/skills/knight_tempo.tres"),
	preload("res://resources/skills/rook_rebuff.tres"),
	preload("res://resources/skills/queens_command.tres"),
	preload("res://resources/skills/royal_tempo.tres")
]

var _owned_skill_ids: Array[String] = []


func _ready() -> void:
	var stored_value = SaveData.get_value(SAVE_SECTION, OWNED_KEY, [])
	if stored_value is Array:
		for skill_id in stored_value:
			if skill_id is String and get_definition(skill_id) != null:
				_owned_skill_ids.append(skill_id)


func get_definitions() -> Array[SkillDefinition]:
	return DEFINITIONS


func get_definition(skill_id: String) -> SkillDefinition:
	for definition in DEFINITIONS:
		if definition.skill_id == skill_id:
			return definition
	return null


func has_skill(skill_id: String) -> bool:
	return skill_id in _owned_skill_ids


func get_skill_value(skill_id: String) -> float:
	var definition := get_definition(skill_id)
	if definition == null or not has_skill(skill_id):
		return 0.0
	return definition.effect_value


func get_effect_value(effect_type: SkillDefinition.EffectType) -> float:
	for definition in DEFINITIONS:
		if definition.effect_type == effect_type and has_skill(definition.skill_id):
			return definition.effect_value
	return 0.0


func purchase_skill(skill_id: String) -> bool:
	var definition := get_definition(skill_id)
	if definition == null or has_skill(skill_id):
		return false
	if not OfficeMaterialManager.spend_office_material(definition.cost):
		return false

	_owned_skill_ids.append(skill_id)
	SaveData.set_value(SAVE_SECTION, OWNED_KEY, _owned_skill_ids)
	return true


func get_attack_interval(base_interval: float, piece: BasePiece, game: Node) -> float:
	var multiplier := 1.0
	multiplier *= _get_multiplier(SkillDefinition.EffectType.GLOBAL_INTERVAL_MULTIPLIER)

	var script_path = piece.get_script().resource_path
	if script_path.ends_with("knight.gd"):
		multiplier *= _get_multiplier(SkillDefinition.EffectType.KNIGHT_INTERVAL_MULTIPLIER)
	elif script_path.ends_with("pawn.gd") and _has_adjacent_pawn(piece, game):
		multiplier *= _get_multiplier(SkillDefinition.EffectType.PAWN_PHALANX_INTERVAL_MULTIPLIER)

	if _is_in_queen_aura(piece, game):
		multiplier *= QUEEN_AURA_INTERVAL_MULTIPLIER

	return base_interval * multiplier


func apply_projectile_effects(source_piece_type: String, target: BaseEnemy) -> void:
	if source_piece_type == null or target == null:
		return

	if source_piece_type == "Bishop":
		var slow_percent := get_effect_value(SkillDefinition.EffectType.BISHOP_SLOW_PERCENT)
		if slow_percent > 0.0:
			target.apply_slow(1.0 - slow_percent, 1.5)
	elif source_piece_type == "Rook":
		var pushback_distance := int(get_effect_value(SkillDefinition.EffectType.ROOK_PUSHBACK_DISTANCE))
		if pushback_distance > 0:
			target.push_away_from_king(pushback_distance)


func _get_multiplier(effect_type: SkillDefinition.EffectType) -> float:
	var value := get_effect_value(effect_type)
	return value if value > 0.0 else 1.0


func _has_adjacent_pawn(piece: BasePiece, game: Node) -> bool:
	if not has_skill("pawn_phalanx"):
		return false
	for other_piece in game.piece_parent.get_children():
		if other_piece == piece or not other_piece is BasePiece:
			continue
		if not other_piece.get_script().resource_path.ends_with("pawn.gd"):
			continue
		var other_cell: Vector2i = other_piece.get("current_cell")
		var piece_cell: Vector2i = piece.get("current_cell")
		if max(abs(other_cell.x - piece_cell.x), abs(other_cell.y - piece_cell.y)) == 1:
			return true
	return false


func _is_in_queen_aura(piece: BasePiece, game: Node) -> bool:
	var radius := int(get_effect_value(SkillDefinition.EffectType.QUEEN_AURA_RADIUS))
	if radius <= 0:
		return false
	var piece_cell: Vector2i = piece.get("current_cell")
	for other_piece in game.piece_parent.get_children():
		if other_piece == piece or not other_piece is BasePiece:
			continue
		if not other_piece.get_script().resource_path.ends_with("queen.gd"):
			continue
		var queen_cell: Vector2i = other_piece.get("current_cell")
		if max(abs(queen_cell.x - piece_cell.x), abs(queen_cell.y - piece_cell.y)) <= radius:
			return true
	return false
