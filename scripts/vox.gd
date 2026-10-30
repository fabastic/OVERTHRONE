extends RefCounted
## Voxel models made in Blender (tools/voxel_models.py -> assets/models/*.glb).
## Each character model is a set of PARTS named after the joints the game animates (leg_l, leg_r,
## torso, head, arm_l, arm_r, fore_l, fore_r, face, hood). voxify() swaps a code-built body for the
## voxel one: it removes the box meshes hanging directly off each joint and hangs the matching
## voxel part there instead, so all the procedural animation keeps working.
## If a model is missing the code-built body simply stays.

static var _flash: StandardMaterial3D


## A white overlay for the hit flash (voxel parts have no emission to pump).
static func flash_material() -> StandardMaterial3D:
	if _flash == null:
		_flash = StandardMaterial3D.new()
		_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash.albedo_color = Color(1, 1, 1, 0.55)
		_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return _flash


static func exists(model: String) -> bool:
	return ResourceLoader.exists("res://assets/models/%s.glb" % model)


## The model's parts, detached and ready to parent: {part name: MeshInstance3D}.
static func parts(model: String) -> Dictionary:
	var path := "res://assets/models/%s.glb" % model
	if not ResourceLoader.exists(path):
		return {}
	var ps := load(path) as PackedScene
	if ps == null:
		return {}
	var root := ps.instantiate()
	var out := {}
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var nm := str(mi.name).get_slice(".", 0)
		mi.get_parent().remove_child(mi)
		mi.transform = Transform3D.IDENTITY
		_pixelate(mi)
		out[nm] = mi
	root.free()
	return out


## A single-piece prop (trees, rocks, barrels...): one node, or null.
static func prop(model: String) -> Node3D:
	var p := parts(model)
	if p.is_empty():
		return null
	var root := Node3D.new()
	for k in p:
		root.add_child(p[k])
	return root


## Nearest filtering on every material so each voxel reads as one crisp pixel.
static func _pixelate(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	for s in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(s) as BaseMaterial3D
		if m and m.texture_filter != BaseMaterial3D.TEXTURE_FILTER_NEAREST:
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			m.roughness = 0.95


## Replace the box body on these joints with the voxel model. keep: nodes never to remove.
## Returns the voxel meshes (for hit flashes), or [] if the model is missing.
static func voxify(model: String, joints: Dictionary, keep: Array = []) -> Array:
	var p := parts(model)
	if p.is_empty():
		return []
	var out: Array = []
	for jn in joints:
		var joint: Node3D = joints[jn]
		if joint == null or not p.has(jn):
			continue
		for c in joint.get_children():
			if c is MeshInstance3D and not keep.has(c):
				joint.remove_child(c)
				c.queue_free()
		joint.add_child(p[jn])
		out.append(p[jn])
	return out


static func set_flash(meshes: Array, on: bool) -> void:
	var m: Material = flash_material() if on else null
	for mi in meshes:
		if is_instance_valid(mi):
			(mi as MeshInstance3D).material_overlay = m
