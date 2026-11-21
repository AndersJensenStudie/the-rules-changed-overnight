extends "res://obstacle.gd"

const IMAGES_DIR := "res://assets/images/asteriods"

static var _variants: Array[Dictionary] = []

var extent := Rect2()


func _ready() -> void:
	super()
	if _variants.is_empty():
		_build_variants()
	if _variants.is_empty():
		return
	var variant: Dictionary = _variants.pick_random()
	$Sprite2D.texture = variant.texture
	extent = variant.extent
	for polygon in variant.polygons:
		var shape := CollisionPolygon2D.new()
		shape.polygon = polygon
		add_child(shape)


static func _build_variants() -> void:
	for file in ResourceLoader.list_directory(IMAGES_DIR):
		var texture := load(IMAGES_DIR.path_join(file)) as Texture2D
		if texture == null:
			continue
		var image := texture.get_image()
		if image.is_compressed():
			image.decompress()
		var half := Vector2(image.get_size()) / 2.0
		var bitmap := BitMap.new()
		bitmap.create_from_image_alpha(image)
		var polygons: Array[PackedVector2Array] = []
		for outline in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, image.get_size()), 1.0):
			var centered := PackedVector2Array()
			for point in outline:
				centered.append(point - half)
			for shrunk in Geometry2D.offset_polygon(centered, -1.0):
				polygons.append(shrunk)
		var used := Rect2(image.get_used_rect())
		used.position -= half
		_variants.append({"texture": texture, "polygons": polygons, "extent": used})
