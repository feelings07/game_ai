extends Node

static func build_walk_frames(frame_paths: Array[String], fps: float = 6.0) -> SpriteFrames:
	return build_sprite_frames({"walk": frame_paths}, fps)

static func build_sprite_frames(animations: Dictionary, fps: float = 6.0) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim_name: String in animations.keys():
		var paths: Array = animations[anim_name]
		if paths.is_empty():
			continue
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, fps)
		frames.set_animation_loop(anim_name, anim_name == "walk")
		for path in paths:
			var tex := load(str(path)) as Texture2D
			frames.add_frame(anim_name, tex)
	return frames
