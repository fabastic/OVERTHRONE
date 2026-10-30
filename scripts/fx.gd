extends RefCounted
## Small helpers for building low-poly meshes, materials, and particles in code.


static func mat(color: Color, emission: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.roughness = 0.9
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


## An impact: a shockwave ring that races out along the ground, a puff of dark smoke rising,
## a white-hot core flash and embers. Frees itself.
static var _vig: ShaderMaterial


## The material for a hurt overlay ColorRect: red only toward the screen edges.
static func vignette_material() -> ShaderMaterial:
	if _vig == null:
		_vig = ShaderMaterial.new()
		_vig.shader = load("res://scripts/vignette.gdshader")
	return _vig


static func impact(parent: Node, pos: Vector3, color: Color, s: float = 1.0) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos
	var ring_m := TorusMesh.new()
	ring_m.inner_radius = 0.85
	ring_m.outer_radius = 1.0
	ring_m.rings = 24
	ring_m.ring_segments = 4
	var ring := MeshInstance3D.new()
	ring.mesh = ring_m
	var rm := mat(color, 4.0, 0.8)
	ring.material_override = rm
	ring.scale = Vector3(0.2, 0.15, 0.2) * s
	root.add_child(ring)
	var core := sphere(0.35 * s, mat(color.lightened(0.6), 8.0, 0.9))
	root.add_child(core)
	var smoke := particles(color.darkened(0.7), int(8 * s) + 4, 0.9, 1.2, 0.18 * s, true)
	smoke.gravity = Vector3(0, 1.5, 0)
	(smoke.mesh as BoxMesh).material = mat(color.darkened(0.75), 0.0, 0.55)
	root.add_child(smoke)
	var embers := particles(color.lightened(0.3), int(10 * s), 0.7, 5.0 * s, 0.04, true)
	embers.gravity = Vector3(0, -6.0, 0)
	root.add_child(embers)
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(2.2, 0.15, 2.2) * s, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(rm, "albedo_color:a", 0.0, 0.35)
	tw.tween_property(core, "scale", Vector3.ONE * 1.8, 0.15)
	tw.tween_callback(core.hide).set_delay(0.15)
	tw.chain().tween_interval(0.8)
	tw.chain().tween_callback(root.queue_free)


static func box(size: Vector3, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _instance(bm, material, pos)


static func sphere(radius: float, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	return _instance(sm, material, pos)


static func cylinder(top: float, bottom: float, height: float, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = height
	cm.radial_segments = 6
	cm.rings = 1
	return _instance(cm, material, pos)


static func _instance(mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	return mi


static func particles(color: Color, amount: int, lifetime: float, speed: float, size: float = 0.08, one_shot: bool = false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = 1.0 if one_shot else 0.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -3.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	p.local_coords = false
	var m := BoxMesh.new()
	m.size = Vector3.ONE * size
	m.material = mat(color, 4.0)
	p.mesh = m
	p.emitting = true
	return p


## A procedural pixel texture: checkered stone tiles or offset bricks with mortar lines.
static func stone_texture(c1: Color, c2: Color, size: int = 32, tiles: int = 4, bricks: bool = false) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var cell := size / tiles
	for y in size:
		for x in size:
			var row := y / cell
			var xx := x + (cell / 2 if bricks and row % 2 == 1 else 0)
			var col := xx / cell
			var c := c1 if (row + col) % 2 == 0 or bricks else c2
			if bricks and randf() < 0.3:
				c = c.lerp(c2, 0.5)
			var n := randf_range(-0.035, 0.035)
			c = Color(c.r + n, c.g + n, c.b + n)
			if y % cell == 0 or xx % cell == 0:
				c = c.darkened(0.5)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func textured(tex: Texture2D, uv_scale: Vector3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_scale = uv_scale
	m.roughness = 0.95
	return m
