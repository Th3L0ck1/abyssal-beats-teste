extends Control

var timer_preview: float = 0.0
var frame_preview: int = 0

@onready var squetch_preview: Sprite2D = $Decor/SquetchPreview
@onready var peixoto_preview: Sprite2D = $Decor/PeixotoPreview
@onready var plat_left: Sprite2D = $Decor/PlatLeft
@onready var plat_right: Sprite2D = $Decor/PlatRight

func _ready() -> void:
	GameState.fade_out()
	GameState.spawn_ambient_bubbles($Decor, Vector2(480, 270), Vector2(240, 275), 14)

func _process(delta: float) -> void:
	timer_preview += delta
	if timer_preview >= 0.16:
		timer_preview = 0.0
		frame_preview = (frame_preview + 1) % 4
		squetch_preview.frame = 8 + frame_preview
		peixoto_preview.frame = 8 + frame_preview
		plat_left.frame = frame_preview % 2
		plat_right.frame = (frame_preview + 1) % 2

func _on_play_pressed() -> void:
	if GameState.is_transitioning:
		return
	GameState.play_ui_sfx("click")
	GameState.reset_world_progress()
	GameState.fade_to_scene("res://Scenes/world.tscn")

func _on_settings_pressed() -> void:
	if GameState.is_transitioning:
		return
	GameState.play_ui_sfx("click")
	GameState.fade_to_scene("res://Scenes/settings.tscn")

func _on_quit_pressed() -> void:
	if GameState.is_transitioning:
		return
	get_tree().quit()
