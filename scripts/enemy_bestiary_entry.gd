class_name EnemyBestiaryEntry
extends Resource

## Read-only presentation data for one enemy type. Illustration and flavor are
## intentionally optional placeholders for future art and writing passes.

@export var enemy_type := ""
@export var display_name := ""
@export_multiline var movement_description := ""
@export_multiline var flavor_text := ""
@export var illustration: Texture2D
