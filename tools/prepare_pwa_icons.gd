extends SceneTree
## 使用现有草莓图标生成标准尺寸，实色背景及遮罩安全留白。

func _init() -> void:
	var source := Image.load_from_file("res://assets/icons/ios.png")
	if source == null:
		push_error("Missing existing strawberry icon")
		quit(1)
		return
	source.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute("res://web/icons")
	for spec in [["icon-192.png", 192, 0.84], ["icon-512.png", 512, 0.84], ["icon-maskable-512.png", 512, 0.64], ["apple-touch-icon.png", 180, 0.84]]:
		var size: int = spec[1]
		var artwork: Image = source.duplicate()
		var side: int = roundi(float(size) * float(spec[2]))
		artwork.resize(side, side, Image.INTERPOLATE_LANCZOS)
		var icon := Image.create(size, size, false, Image.FORMAT_RGBA8)
		icon.fill(Color("eaf4de"))
		icon.blend_rect(artwork, Rect2i(0, 0, side, side), Vector2i((size - side) / 2, (size - side) / 2))
		if icon.save_png("res://web/icons/" + str(spec[0])) != OK:
			quit(1)
			return
	print("PWA_ICONS_READY: 192, 512, maskable 512, Apple 180")
	quit()
