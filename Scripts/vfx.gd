extends RefCounted
class_name VFX

## Toca uma spritesheet horizontal uma unica vez e se auto-remove.
static func play(parent: Node, tex: Texture2D, hframes: int, fps: float, pos: Vector2, scale_f: Vector2 = Vector2.ONE, flip: bool = false, z: int = 0, rot: float = 0.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.hframes = hframes
	s.position = pos
	s.scale = scale_f
	s.flip_h = flip
	s.z_index = z
	s.rotation = rot
	parent.add_child(s)
	var tw := s.create_tween()
	tw.tween_method(func(v: float): s.frame = clampi(int(v), 0, hframes - 1), 0.0, float(hframes) - 0.001, float(hframes) / fps)
	tw.tween_callback(s.queue_free)
	return s
