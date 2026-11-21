extends SceneTree

const SHEET := "res://assets/fonts/Font-grayscale.png"
const OUTPUT := "res://assets/fonts/pixel_font.tres"
const FALLBACK := "res://assets/fonts/Super Arcade.ttf"
const CHARACTERS := "PresSACEtoaHI0123456789+c"
const CELL := 32
const COLUMNS := 5
const SPACING := 2
const SPACE_ADVANCE := 10


func _initialize() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	image.convert(Image.FORMAT_RGBA8)
	var used_rects := {}
	var tallest := 0
	for i in CHARACTERS.length():
		var cell := Rect2i((i % COLUMNS) * CELL, (i / COLUMNS) * CELL, CELL, CELL)
		var used := image.get_region(cell).get_used_rect()
		used.position += cell.position
		used_rects[CHARACTERS[i]] = used
		tallest = maxi(tallest, used.size.y)
	var size := Vector2i(tallest, 0)
	var font := FontFile.new()
	font.fixed_size = tallest
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
	font.generate_mipmaps = true
	font.set_texture_image(0, size, 0, image)
	font.set_cache_ascent(0, tallest, tallest)
	font.set_cache_descent(0, tallest, 2)
	for character in used_rects:
		var rect: Rect2i = used_rects[character]
		var glyph: int = String(character).unicode_at(0)
		font.set_glyph_advance(0, tallest, glyph, Vector2(rect.size.x + SPACING, 0))
		font.set_glyph_offset(0, size, glyph, Vector2(0, -rect.size.y))
		font.set_glyph_size(0, size, glyph, Vector2(rect.size))
		font.set_glyph_uv_rect(0, size, glyph, Rect2(rect))
		font.set_glyph_texture_idx(0, size, glyph, 0)
	font.set_glyph_advance(0, tallest, 32, Vector2(SPACE_ADVANCE, 0))
	font.fallbacks = [load(FALLBACK)]
	var error := ResourceSaver.save(font, OUTPUT)
	print("saved %s with %d characters, height %d px: %s" % [OUTPUT, used_rects.size(), tallest, error_string(error)])
	quit()
