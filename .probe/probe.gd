extends SceneTree
func _init():
	var root = (load("res://assets/models/hand_r.glb") as PackedScene).instantiate()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if mi.name != "sleeve" and mi.name != "forearm":
			continue
		for s in mi.mesh.get_surface_count():
			var m: BaseMaterial3D = mi.mesh.surface_get_material(s)
			var img: Image = m.albedo_texture.get_image()
			if img.is_compressed():
				img.decompress()
			var arr = mi.mesh.surface_get_arrays(s)
			var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var cols := {}
			for uv in uvs:
				var c := img.get_pixelv(Vector2i(int(uv.x * img.get_width()), int(uv.y * img.get_height())))
				cols[c.to_html(false)] = cols.get(c.to_html(false), 0) + 1
			print(mi.name, " s", s, " ", m.resource_name, " img ", img.get_size(), " fmt ", img.get_format(), " em ", m.emission_enabled, " colors ", cols)
	quit()
