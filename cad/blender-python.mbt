///|
pub async fn Design::create_blender_file(
  self : Design,
  out_path : String,
  keep_curves? : Bool,
  keep_modifiers? : Bool,
) -> Unit {
  let bpy_code = self.to_blender_python(keep_curves?, keep_modifiers?)
  let temp_py_path = "/tmp/temp_blender_script.py"
  write_text_file(bpy_code, Some(temp_py_path))
  // Now run: ./scripts/validate-bpy.py {temp_py_path} --blend out_path
  let args = [temp_py_path, "--blend", out_path]
  match
    @process.run(
      "./scripts/validate-bpy.py",
      args,
      stdout=@stdio.stdout,
      stderr=@stdio.stderr,
    ) {
    0 => ()
    _ => println("failed to write '\{out_path}'")
  }
}

///|
pub async fn Design::write_blender_python(
  self : Design,
  out_path : String?,
  keep_curves? : Bool,
  keep_modifiers? : Bool,
) -> Unit {
  let bpy_code = self.to_blender_python(keep_curves?, keep_modifiers?)
  write_text_file(bpy_code, out_path)
}

///|
fn py_string(s : String) -> String {
  let escaped = s.replace(old="\\", new="\\\\").replace(old="'", new="\\'")
  "'" + escaped + "'"
}

///|
fn mm_to_m(x : Double) -> Double {
  x * 0.001
}

///|
fn py_bool(b : Bool) -> String {
  if b {
    "True"
  } else {
    "False"
  }
}

///|
fn py_vec3(v : Vec3) -> String {
  "(\{v.0}, \{v.1}, \{v.2})"
}

///|
fn py_mm(x : Double) -> String {
  "\{mm_to_m(x)}"
}

///|
fn py_mm_vec2(v : Vec2) -> String {
  "(\{mm_to_m(v.0)}, \{mm_to_m(v.1)})"
}

///|
fn py_mm_vec3(v : Vec3) -> String {
  "(\{mm_to_m(v.0)}, \{mm_to_m(v.1)}, \{mm_to_m(v.2)})"
}

///|
fn py_vec3_list(pts : Array[Vec3]) -> String {
  "[" + pts.map(py_vec3).join(", ") + "]"
}

///|
fn py_mm_vec2_list(pts : Array[Vec2]) -> String {
  "[" + pts.map(py_mm_vec2).join(", ") + "]"
}

///|
fn py_mm_vec3_list(pts : Array[Vec3]) -> String {
  "[" + pts.map(py_mm_vec3).join(", ") + "]"
}

///|
fn py_mm_vec2_list_list(loops : Array[Array[Vec2]]) -> String {
  "[" + loops.map(py_mm_vec2_list).join(", ") + "]"
}

///|
fn py_bezier_anchor(a : BezierAnchor) -> String {
  let pos = py_mm_vec2(a.position)
  let hi = py_mm_vec2(a.handle_in)
  let ho = py_mm_vec2(a.handle_out)
  "{'pos': \{pos}, 'hi': \{hi}, 'ho': \{ho}}"
}

///|
fn py_bezier_path(path : BezierPath) -> String {
  let anchors = "[" + path.anchors.map(py_bezier_anchor).join(", ") + "]"
  "{'anchors': \{anchors}, 'closed': \{py_bool(path.closed)}, 'clear': \{py_bool(path.clear)}}"
}

///|
fn py_bezier_paths(paths : Array[BezierPath]) -> String {
  "[" + paths.map(py_bezier_path).join(", ") + "]"
}

///|
fn py_color(color : Rgb) -> String {
  "(\{color.r}, \{color.g}, \{color.b}, 1.0)"
}

///|
fn next_var(prefix : String, idx : Int) -> (String, Int) {
  (prefix + idx.to_string(), idx + 1)
}

///|
fn emit_node_python(
  builder : StringBuilder,
  node : SceneNode,
  idx : Int,
  keep_curves~ : Bool,
) -> (String, Int) {
  match node.shape {
    Cuboid(c) => {
      let (obj_var, next_idx) = next_var("obj", idx)
      builder.write_string(
        (
          $|    \{obj_var} = finalize_object(create_cuboid_object(\{py_string(node.name)}, \{py_mm(c.sx)}, \{py_mm(c.sy)}, \{py_mm(c.sz)}, collection), get_material(\{py_color(node.color)}), (\{py_mm(node.tx)}, \{py_mm(node.ty)}, \{py_mm(node.tz)}), (\{node.rx}, \{node.ry}, \{node.rz}))
          $|
        ),
      )
      (obj_var, next_idx)
    }
    CalibrationChamferBlock(b) => {
      let (obj_var, next_idx) = next_var("obj", idx)
      builder.write_string(
        (
          $|    \{obj_var} = finalize_object(create_chamfer_block_object(\{py_string(node.name)}, \{py_mm(b.length_mm)}, \{py_mm(b.width_mm)}, \{py_mm(b.height_mm)}, \{py_mm(b.chamfer_size_mm)}, \{py_mm(b.fillet_radius_mm)}, \{b.fillet_segments}, collection), get_material(\{py_color(node.color)}), (\{py_mm(node.tx)}, \{py_mm(node.ty)}, \{py_mm(node.tz)}), (\{node.rx}, \{node.ry}, \{node.rz}))
          $|
        ),
      )
      (obj_var, next_idx)
    }
    ExtrudedProfile(e) => {
      let (obj_var, next_idx) = next_var("obj", idx)
      let loops = [e.profile.outer, ..e.profile.holes]
      builder.write_string(
        (
          $|    \{obj_var} = finalize_object(create_extruded_profile_object(\{py_string(node.name)}, \{py_mm_vec2_list_list(loops)}, \{py_mm(e.height_mm)}, collection), get_material(\{py_color(node.color)}), (\{py_mm(node.tx)}, \{py_mm(node.ty)}, \{py_mm(node.tz)}), (\{node.rx}, \{node.ry}, \{node.rz}))
          $|
        ),
      )
      (obj_var, next_idx)
    }
    ExtrudedBezierProfile(e) => {
      let (obj_var, next_idx) = next_var("obj", idx)
      let paths_data = py_bezier_paths(e.paths)
      builder.write_string(
        (
          $|    \{obj_var} = finalize_object(create_extruded_bezier_object(\{py_string(node.name)}, \{paths_data}, \{py_mm(e.height_mm)}, collection), get_material(\{py_color(node.color)}), (\{py_mm(node.tx)}, \{py_mm(node.ty)}, \{py_mm(node.tz)}), (\{node.rx}, \{node.ry}, \{node.rz}))
          $|
        ),
      )
      (obj_var, next_idx)
    }
    SweptProfile(s) => {
      let (obj_var, next_idx) = next_var("obj", idx)
      builder.write_string(
        (
          $|    \{obj_var} = finalize_object(create_swept_profile_object(\{py_string(node.name)}, \{py_mm_vec3_list(s.path.points)}, \{py_vec3_list(s.path.normals)}, \{py_vec3_list(s.path.tangents)}, \{py_mm_vec3(s.profile.center)}, \{py_mm_vec3_list(s.profile.vertices)}, \{py_vec3(s.profile.normal_dir)}, \{py_vec3(s.profile.right_dir)}, \{py_bool(s.make_start_cap)}, \{py_bool(s.make_end_cap)}, collection), get_material(\{py_color(node.color)}), (\{py_mm(node.tx)}, \{py_mm(node.ty)}, \{py_mm(node.tz)}), (\{node.rx}, \{node.ry}, \{node.rz}))
          $|
        ),
      )
      (obj_var, next_idx)
    }
    Union(u) => {
      let child_vars : Array[String] = []
      let mut cur_idx = idx
      for child in u.nodes {
        let (child_var, next_idx) = emit_node_python(
          builder,
          child,
          cur_idx,
          keep_curves~,
        )
        child_vars.push(child_var)
        cur_idx = next_idx
      }
      let (list_var, next_idx) = next_var("union_objs", cur_idx)
      builder.write_string(
        (
          $|    \{list_var} = [\{child_vars.join(", ")}]
          $|
        ),
      )
      let (obj_var, final_idx) = next_var("obj", next_idx)
      builder.write_string(
        (
          $|    \{obj_var} = finalize_object(join_objects(\{list_var}, \{py_string(node.name)}), get_material(\{py_color(node.color)}), (\{py_mm(node.tx)}, \{py_mm(node.ty)}, \{py_mm(node.tz)}), (\{node.rx}, \{node.ry}, \{node.rz}))
          $|
        ),
      )
      (obj_var, final_idx)
    }
    Difference(d) => {
      let (base_var, next_idx) = emit_node_python(
        builder,
        d.base,
        idx,
        keep_curves~,
      )
      let cutter_vars : Array[String] = []
      let mut cur_idx = next_idx
      for cutter in d.cutters {
        let (cutter_var, cutter_idx) = emit_node_python(
          builder,
          cutter,
          cur_idx,
          keep_curves~,
        )
        cutter_vars.push(cutter_var)
        cur_idx = cutter_idx
      }
      let (list_var, next_idx) = next_var("diff_cutters", cur_idx)
      builder.write_string(
        (
          $|    \{list_var} = [\{cutter_vars.join(", ")}]
          $|
        ),
      )
      let (obj_var, final_idx) = next_var("obj", next_idx)
      builder.write_string(
        (
          $|    \{obj_var} = finalize_object(boolean_difference(\{base_var}, \{list_var}, \{py_string(node.name)}), get_material(\{py_color(node.color)}), (\{py_mm(node.tx)}, \{py_mm(node.ty)}, \{py_mm(node.tz)}), (\{node.rx}, \{node.ry}, \{node.rz}))
          $|
        ),
      )
      (obj_var, final_idx)
    }
  }
}

///|
/// Convert the Design to a Blender 5 Python3 script that will recreate the model
/// using the Blender Python3 API. This function keeps the STEP model as high-level
/// as possible, allowing Blender to handle as many modifier operations itself
/// as it can.
pub fn Design::to_blender_python(
  self : Design,
  keep_curves? : Bool = false,
  keep_modifiers? : Bool = false,
) -> String {
  let builder = StringBuilder::new()
  builder.write_string(PREAMBLE)
  if keep_modifiers {
    if keep_curves {
      builder.write_string(BOOLEAN_DIFFERENCE_KEEP_MODIFIERS_KEEP_CURVES)
    } else {
      builder.write_string(BOOLEAN_DIFFERENCE_KEEP_MODIFIERS)
    }
  } else if keep_curves {
    builder.write_string(BOOLEAN_DIFFERENCE_APPLY_MODIFIERS_KEEP_CURVES)
  } else {
    builder.write_string(BOOLEAN_DIFFERENCE_APPLY_MODIFIERS)
  }
  builder.write_string(
    (
      #|
      #|def create_model_objects(collection):
      #|
    ),
  )
  let mut obj_index = 0
  for node in self.nodes {
    let (_, next_idx) = emit_node_python(builder, node, obj_index, keep_curves~)
    obj_index = next_idx
  }
  builder.write_string(postscript(self.name))
  builder.to_string()
}

///|
const PREAMBLE =
  #|#!/usr/bin/env python3
  #|"""
  #|Blender 5.0 Python3 script generated by `gmlewis/step` and MoonBit.
  #|Run this script from within Blender's scripting environment.
  #|This script is idempotent meaning that it can be run multiple times and
  #|only the created model will be replaced in the current scene.
  #|"""
  #|
  #|import bpy
  #|import math
  #|import sys
  #|
  #|config = {}
  #|_material_cache = {}
  #|
  #|
  #|def delete_default_cube():
  #|    obj = bpy.data.objects.get("Cube")
  #|    if obj is not None:
  #|        bpy.data.objects.remove(obj, do_unlink=True)
  #|        print("Removed default cube.")
  #|
  #|
  #|def set_up_collection(collection_name):
  #|    """
  #|    Set up the collection for the new model.
  #|    - If it exists, delete all objects within it.
  #|    - If it doesn't exist, create it.
  #|    """
  #|    scene = bpy.context.scene
  #|    collection = bpy.data.collections.get(collection_name)
  #|
  #|    if collection is not None:
  #|        print(f"Collection '{collection_name}' exists. Removing all objects...")
  #|        objects_to_delete = list(collection.objects)
  #|        for obj in objects_to_delete:
  #|            bpy.data.objects.remove(obj, do_unlink=True)
  #|        print(f"  Removed {len(objects_to_delete)} objects.")
  #|    else:
  #|        print(f"Creating new collection '{collection_name}'...")
  #|        collection = bpy.data.collections.new(collection_name)
  #|        scene.collection.children.link(collection)
  #|
  #|    return collection
  #|
  #|
  #|def get_material(color):
  #|    """Return a material for the given RGBA color tuple."""
  #|    key = f"mat_{int(color[0] * 255)}_{int(color[1] * 255)}_{int(color[2] * 255)}"
  #|    if key in _material_cache:
  #|        return _material_cache[key]
  #|    mat = bpy.data.materials.get(key)
  #|    if mat is None:
  #|        mat = bpy.data.materials.new(name=key)
  #|        mat.use_nodes = True
  #|    bsdf = mat.node_tree.nodes.get("Principled BSDF")
  #|    if bsdf is not None:
  #|        bsdf.inputs["Base Color"].default_value = color
  #|    _material_cache[key] = mat
  #|    return mat
  #|
  #|
  #|def assign_material(obj, material):
  #|    if obj is None or material is None:
  #|        return
  #|    if obj.data.materials:
  #|        obj.data.materials[0] = material
  #|    else:
  #|        obj.data.materials.append(material)
  #|
  #|
  #|def apply_transform(obj, location, rotation_deg):
  #|    if obj is None:
  #|        return
  #|    obj.location = location
  #|    obj.rotation_euler = (
  #|        math.radians(rotation_deg[0]),
  #|        math.radians(rotation_deg[1]),
  #|        math.radians(rotation_deg[2]),
  #|    )
  #|
  #|
  #|def finalize_object(obj, material, location, rotation_deg):
  #|    if obj is None:
  #|        return None
  #|    apply_transform(obj, location, rotation_deg)
  #|    assign_material(obj, material)
  #|    return obj
  #|
  #|
  #|def create_mesh_object(name, verts, faces, collection):
  #|    if len(verts) == 0 or len(faces) == 0:
  #|        return None
  #|    mesh = bpy.data.meshes.new(name + "_mesh")
  #|    mesh.from_pydata(verts, [], faces)
  #|    mesh.update()
  #|    obj = bpy.data.objects.new(name, mesh)
  #|    collection.objects.link(obj)
  #|    return obj
  #|
  #|
  #|def polygon_area_2d(loop):
  #|    area = 0.0
  #|    n = len(loop)
  #|    if n < 3:
  #|        return 0.0
  #|    for i in range(n):
  #|        x1, y1 = loop[i]
  #|        x2, y2 = loop[(i + 1) % n]
  #|        area += x1 * y2 - x2 * y1
  #|    return area / 2.0
  #|
  #|
  #|def ensure_ccw(loop):
  #|    return loop if polygon_area_2d(loop) >= 0.0 else list(reversed(loop))
  #|
  #|
  #|def ensure_cw(loop):
  #|    return loop if polygon_area_2d(loop) <= 0.0 else list(reversed(loop))
  #|
  #|
  #|def create_extruded_profile_object(name, loops, height, collection):
  #|    if not loops or len(loops[0]) < 3:
  #|        return None
  #|    outer = ensure_ccw(loops[0])
  #|    holes = [ensure_cw(h) for h in loops[1:] if len(h) >= 3]
  #|    curve = bpy.data.curves.new(name + "_curve", type="CURVE")
  #|    curve.dimensions = "2D"
  #|    curve.fill_mode = "BOTH"
  #|    curve.extrude = height
  #|    for loop in [outer] + holes:
  #|        spline = curve.splines.new("POLY")
  #|        spline.points.add(len(loop) - 1)
  #|        for i, (x, y) in enumerate(loop):
  #|            spline.points[i].co = (x, y, 0.0, 1.0)
  #|        spline.use_cyclic_u = True
  #|    obj = bpy.data.objects.new(name, curve)
  #|    collection.objects.link(obj)
  #|    return obj
  #|
  #|
  #|def create_extruded_bezier_object(name, bezier_paths, height, collection):
  #|    """Create an extruded object from native cubic Bezier paths."""
  #|    if not bezier_paths:
  #|        return None
  #|    curve = bpy.data.curves.new(name + "_curve", type="CURVE")
  #|    curve.dimensions = "2D"
  #|    curve.fill_mode = "BOTH"
  #|    curve.extrude = height
  #|    for path_data in bezier_paths:
  #|        anchors = path_data['anchors']
  #|        closed = path_data['closed']
  #|        # clear = path_data['clear']  # Used for holes, handled by winding order
  #|        if len(anchors) < 2:
  #|            continue
  #|        spline = curve.splines.new("BEZIER")
  #|        spline.bezier_points.add(len(anchors) - 1)
  #|        for i, anchor in enumerate(anchors):
  #|            bp = spline.bezier_points[i]
  #|            px, py = anchor['pos']
  #|            hix, hiy = anchor['hi']
  #|            hox, hoy = anchor['ho']
  #|            bp.co = (px, py, 0.0)
  #|            bp.handle_left = (hix, hiy, 0.0)
  #|            bp.handle_right = (hox, hoy, 0.0)
  #|            bp.handle_left_type = 'FREE'
  #|            bp.handle_right_type = 'FREE'
  #|        spline.use_cyclic_u = closed
  #|    obj = bpy.data.objects.new(name, curve)
  #|    collection.objects.link(obj)
  #|    return obj
  #|
  #|
  #|def build_cuboid_mesh(sx, sy, sz):
  #|    verts = [
  #|        (0.0, 0.0, 0.0),
  #|        (sx, 0.0, 0.0),
  #|        (sx, sy, 0.0),
  #|        (0.0, sy, 0.0),
  #|        (0.0, 0.0, sz),
  #|        (sx, 0.0, sz),
  #|        (sx, sy, sz),
  #|        (0.0, sy, sz),
  #|    ]
  #|    faces = [
  #|        [0, 1, 2, 3],
  #|        [4, 5, 6, 7],
  #|        [0, 1, 5, 4],
  #|        [1, 2, 6, 5],
  #|        [2, 3, 7, 6],
  #|        [3, 0, 4, 7],
  #|    ]
  #|    return verts, faces
  #|
  #|
  #|def create_cuboid_object(name, sx, sy, sz, collection):
  #|    verts, faces = build_cuboid_mesh(sx, sy, sz)
  #|    return create_mesh_object(name, verts, faces, collection)
  #|
  #|
  #|def build_chamfer_block_mesh(length_mm, width_mm, height_mm, chamfer_size_mm, fillet_radius_mm, fillet_segments):
  #|    rings = [(0.0, 0.0)]
  #|    if fillet_radius_mm > 0.0:
  #|        r = fillet_radius_mm
  #|        start_z = height_mm - r
  #|        rings.append((start_z, 0.0))
  #|        segs = 8 if fillet_segments <= 0 else fillet_segments
  #|        for i in range(1, segs + 1):
  #|            phi = i * (math.pi / 2.0) / segs
  #|            offset = r - r * math.cos(phi)
  #|            z = height_mm - r + r * math.sin(phi)
  #|            rings.append((z, offset))
  #|    elif chamfer_size_mm > 0.0:
  #|        c = chamfer_size_mm
  #|        rings.append((height_mm - c, 0.0))
  #|        rings.append((height_mm, c))
  #|    else:
  #|        rings.append((height_mm, 0.0))
  #|
  #|    verts = []
  #|    for rz, ro in rings:
  #|        px0 = ro
  #|        px1 = length_mm - ro
  #|        py0 = ro
  #|        py1 = width_mm - ro
  #|        verts.extend([(px0, py0, rz), (px1, py0, rz), (px1, py1, rz), (px0, py1, rz)])
  #|
  #|    faces = []
  #|    faces.append([0, 3, 2, 1])
  #|    top_base = (len(rings) - 1) * 4
  #|    faces.append([top_base + 0, top_base + 1, top_base + 2, top_base + 3])
  #|    for ri in range(len(rings) - 1):
  #|        a = ri * 4
  #|        b = (ri + 1) * 4
  #|        faces.append([a + 0, a + 1, b + 1, b + 0])
  #|        faces.append([a + 1, a + 2, b + 2, b + 1])
  #|        faces.append([a + 2, a + 3, b + 3, b + 2])
  #|        faces.append([a + 3, a + 0, b + 0, b + 3])
  #|    return verts, faces
  #|
  #|
  #|def create_chamfer_block_object(name, length_mm, width_mm, height_mm, chamfer_size_mm, fillet_radius_mm, fillet_segments, collection):
  #|    verts, faces = build_chamfer_block_mesh(length_mm, width_mm, height_mm, chamfer_size_mm, fillet_radius_mm, fillet_segments)
  #|    return create_mesh_object(name, verts, faces, collection)
  #|
  #|
  #|def v_sub(a, b):
  #|    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
  #|
  #|def v_cross(a, b):
  #|    return (
  #|        a[1] * b[2] - a[2] * b[1],
  #|        a[2] * b[0] - a[0] * b[2],
  #|        a[0] * b[1] - a[1] * b[0],
  #|    )
  #|
  #|def v_dot(a, b):
  #|    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
  #|
  #|def v_len(a):
  #|    return math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2])
  #|
  #|def v_norm(a):
  #|    l = v_len(a)
  #|    if l == 0.0:
  #|        return (1.0, 0.0, 0.0)
  #|    return (a[0] / l, a[1] / l, a[2] / l)
  #|
  #|def v_scale(a, s):
  #|    return (a[0] * s, a[1] * s, a[2] * s)
  #|
  #|def rotation_matrix(rx, ry, rz):
  #|    rad_x = math.radians(rx)
  #|    rad_y = math.radians(ry)
  #|    rad_z = math.radians(rz)
  #|    sx, cx = math.sin(rad_x), math.cos(rad_x)
  #|    sy, cy = math.sin(rad_y), math.cos(rad_y)
  #|    sz, cz = math.sin(rad_z), math.cos(rad_z)
  #|    return (
  #|        (cy * cz, sx * sy * cz - cx * sz, cx * sy * cz + sx * sz),
  #|        (cy * sz, sx * sy * sz + cx * cz, cx * sy * sz - sx * cz),
  #|        (-sy, sx * cy, cx * cy),
  #|    )
  #|
  #|def apply_matrix(m, p):
  #|    return (
  #|        m[0][0] * p[0] + m[0][1] * p[1] + m[0][2] * p[2],
  #|        m[1][0] * p[0] + m[1][1] * p[1] + m[1][2] * p[2],
  #|        m[2][0] * p[0] + m[2][1] * p[1] + m[2][2] * p[2],
  #|    )
  #|
  #|
  #|def polygon_normal_3d(pts, indices):
  #|    if len(indices) < 3:
  #|        return (0.0, 0.0, 0.0)
  #|    ax = ay = az = 0.0
  #|    n = len(indices)
  #|    for i in range(n):
  #|        x1, y1, z1 = pts[indices[i]]
  #|        x2, y2, z2 = pts[indices[(i + 1) % n]]
  #|        ax += y1 * z2 - z1 * y2
  #|        ay += z1 * x2 - x1 * z2
  #|        az += x1 * y2 - y1 * x2
  #|    return (ax / 2.0, ay / 2.0, az / 2.0)
  #|
  #|
  #|def build_swept_profile_mesh(path_points, path_normals, path_tangents, profile_center, profile_vertices, profile_normal_dir, profile_right_dir, make_start_cap, make_end_cap):
  #|    if len(path_points) < 2 or len(profile_vertices) < 3:
  #|        return [], []
  #|    prof_z = v_norm(profile_normal_dir)
  #|    prof_x = v_norm(profile_right_dir)
  #|    prof_y = v_norm(v_cross(prof_z, prof_x))
  #|    m_global_to_prof = (
  #|        (prof_x[0], prof_x[1], prof_x[2]),
  #|        (prof_y[0], prof_y[1], prof_y[2]),
  #|        (prof_z[0], prof_z[1], prof_z[2]),
  #|    )
  #|    local_verts = [apply_matrix(m_global_to_prof, v_sub(v, profile_center)) for v in profile_vertices]
  #|
  #|    pts = []
  #|    num_path_pts = len(path_points)
  #|    num_prof_verts = len(profile_vertices)
  #|    for i in range(num_path_pts):
  #|        p_origin = path_points[i]
  #|        p_tangent = v_norm(path_tangents[i])
  #|        p_normal = v_norm(path_normals[i])
  #|        p_right = v_norm(v_cross(p_tangent, p_normal))
  #|        m_path_to_global = (
  #|            (p_right[0], p_normal[0], p_tangent[0]),
  #|            (p_right[1], p_normal[1], p_tangent[1]),
  #|            (p_right[2], p_normal[2], p_tangent[2]),
  #|        )
  #|        for v in local_verts:
  #|            gv = apply_matrix(m_path_to_global, v)
  #|            pts.append((gv[0] + p_origin[0], gv[1] + p_origin[1], gv[2] + p_origin[2]))
  #|
  #|    faces = []
  #|    for i in range(num_path_pts - 1):
  #|        offset1 = i * num_prof_verts
  #|        offset2 = (i + 1) * num_prof_verts
  #|        for j in range(num_prof_verts):
  #|            k = (j + 1) % num_prof_verts
  #|            b1 = offset1 + j
  #|            b2 = offset1 + k
  #|            t1 = offset2 + j
  #|            t2 = offset2 + k
  #|            faces.append([b1, b2, t2, t1])
  #|
  #|    def add_cap(indices, expected_out):
  #|        n = polygon_normal_3d(pts, indices)
  #|        if v_dot(n, expected_out) < 0.0:
  #|            indices = list(reversed(indices))
  #|        faces.append(indices)
  #|
  #|    if make_start_cap:
  #|        expected = v_scale(v_norm(path_tangents[0]), -1.0)
  #|        add_cap(list(range(num_prof_verts)), expected)
  #|    if make_end_cap:
  #|        expected = v_norm(path_tangents[-1])
  #|        base = (num_path_pts - 1) * num_prof_verts
  #|        add_cap([base + i for i in range(num_prof_verts)], expected)
  #|    return pts, faces
  #|
  #|
  #|def create_swept_profile_object(name, path_points, path_normals, path_tangents, profile_center, profile_vertices, profile_normal_dir, profile_right_dir, make_start_cap, make_end_cap, collection):
  #|    verts, faces = build_swept_profile_mesh(
  #|        path_points,
  #|        path_normals,
  #|        path_tangents,
  #|        profile_center,
  #|        profile_vertices,
  #|        profile_normal_dir,
  #|        profile_right_dir,
  #|        make_start_cap,
  #|        make_end_cap,
  #|    )
  #|    return create_mesh_object(name, verts, faces, collection)
  #|
  #|
  #|def join_objects(objs, name):
  #|    objs = [o for o in objs if o is not None]
  #|    if not objs:
  #|        return None
  #|    if len(objs) == 1:
  #|        obj = objs[0]
  #|        obj.name = name
  #|        return obj
  #|    bpy.ops.object.select_all(action="DESELECT")
  #|    for obj in objs:
  #|        obj.select_set(True)
  #|    bpy.context.view_layer.objects.active = objs[0]
  #|    bpy.ops.object.join()
  #|    obj = bpy.context.view_layer.objects.active
  #|    obj.name = name
  #|    return obj
  #|
  #|def ensure_mesh_object(obj):
  #|    if obj is None:
  #|        return None
  #|    if obj.type == "MESH":
  #|        return obj
  #|    bpy.ops.object.select_all(action="DESELECT")
  #|    obj.select_set(True)
  #|    bpy.context.view_layer.objects.active = obj
  #|    try:
  #|        bpy.ops.object.convert(target="MESH")
  #|    except Exception as exc:
  #|        raise RuntimeError(f"Failed to convert '{obj.name}' to mesh: {exc}")
  #|    new_obj = bpy.context.view_layer.objects.active
  #|    if new_obj is None or new_obj.type != "MESH":
  #|        raise RuntimeError(f"Conversion to mesh failed for '{obj.name}'.")
  #|    return new_obj
  #|

///|
const BOOLEAN_DIFFERENCE_KEEP_MODIFIERS =
  #|def boolean_difference(base_obj, cutters, name):
  #|    if base_obj is None:
  #|        return None
  #|    base_obj = ensure_mesh_object(base_obj)
  #|    cutters = [ensure_mesh_object(c) for c in cutters if c is not None]
  #|    if not cutters:
  #|        base_obj.name = name
  #|        return base_obj
  #|    bpy.ops.object.select_all(action="DESELECT")
  #|    base_obj.select_set(True)
  #|    bpy.context.view_layer.objects.active = base_obj
  #|    for cutter in cutters:
  #|        if cutter is None:
  #|            continue
  #|        if cutter.type != "MESH":
  #|            raise RuntimeError(f"Cutter '{cutter.name}' is not a mesh after conversion.")
  #|        mod = base_obj.modifiers.new(name=f"Bool_{cutter.name}", type='BOOLEAN')
  #|        mod.operation = 'DIFFERENCE'
  #|        mod.object = cutter
  #|        if hasattr(mod, "show_expanded"):
  #|            mod.show_expanded = False
  #|        cutter.hide_set(True)
  #|        cutter.hide_render = True
  #|    base_obj.name = name
  #|    return base_obj
  #|

///|
const BOOLEAN_DIFFERENCE_KEEP_MODIFIERS_KEEP_CURVES =
  #|def convert_curve_to_mesh_copy(obj):
  #|    """Convert a curve to mesh, returning a new mesh object. Original curve is preserved."""
  #|    if obj is None or obj.type == "MESH":
  #|        return obj
  #|    if obj.type != "CURVE":
  #|        return ensure_mesh_object(obj)
  #|    # Create a copy of the curve object for conversion
  #|    bpy.ops.object.select_all(action="DESELECT")
  #|    obj.select_set(True)
  #|    bpy.context.view_layer.objects.active = obj
  #|    bpy.ops.object.duplicate()
  #|    copy_obj = bpy.context.view_layer.objects.active
  #|    copy_obj.name = obj.name + "_mesh"
  #|    # Convert the copy to mesh
  #|    try:
  #|        bpy.ops.object.convert(target="MESH")
  #|    except Exception as exc:
  #|        bpy.data.objects.remove(copy_obj, do_unlink=True)
  #|        raise RuntimeError(f"Failed to convert curve '{obj.name}' to mesh: {exc}")
  #|    mesh_obj = bpy.context.view_layer.objects.active
  #|    return mesh_obj
  #|
  #|def boolean_difference(base_obj, cutters, name):
  #|    if base_obj is None:
  #|        return None
  #|    # Track original curve objects to preserve them
  #|    original_curves = [c for c in cutters if c is not None and c.type == "CURVE"]
  #|    # Convert base and cutters to mesh for boolean operations
  #|    base_obj = ensure_mesh_object(base_obj)
  #|    mesh_cutters = [convert_curve_to_mesh_copy(c) for c in cutters if c is not None]
  #|    if not mesh_cutters:
  #|        base_obj.name = name
  #|        return base_obj
  #|    bpy.ops.object.select_all(action="DESELECT")
  #|    base_obj.select_set(True)
  #|    bpy.context.view_layer.objects.active = base_obj
  #|    for cutter in mesh_cutters:
  #|        if cutter is None:
  #|            continue
  #|        if cutter.type != "MESH":
  #|            raise RuntimeError(f"Cutter '{cutter.name}' is not a mesh after conversion.")
  #|        mod = base_obj.modifiers.new(name=f"Bool_{cutter.name}", type='BOOLEAN')
  #|        mod.operation = 'DIFFERENCE'
  #|        mod.object = cutter
  #|        if hasattr(mod, "show_expanded"):
  #|            mod.show_expanded = False
  #|        cutter.hide_set(True)
  #|        cutter.hide_render = True
  #|    # Also hide the original curves (they're preserved but not visible)
  #|    for curve in original_curves:
  #|        curve.hide_set(True)
  #|        curve.hide_render = True
  #|    base_obj.name = name
  #|    return base_obj
  #|

///|
const BOOLEAN_DIFFERENCE_APPLY_MODIFIERS =
  #|def boolean_difference(base_obj, cutters, name):
  #|    if base_obj is None:
  #|        return None
  #|    base_obj = ensure_mesh_object(base_obj)
  #|    cutters = [ensure_mesh_object(c) for c in cutters if c is not None]
  #|    if not cutters:
  #|        base_obj.name = name
  #|        return base_obj
  #|    bpy.ops.object.select_all(action="DESELECT")
  #|    base_obj.select_set(True)
  #|    bpy.context.view_layer.objects.active = base_obj
  #|    for cutter in cutters:
  #|        if cutter is None:
  #|            continue
  #|        if cutter.type != "MESH":
  #|            raise RuntimeError(f"Cutter '{cutter.name}' is not a mesh after conversion.")
  #|        mod = base_obj.modifiers.new(name="Bool", type='BOOLEAN')
  #|        mod.operation = 'DIFFERENCE'
  #|        mod.object = cutter
  #|        try:
  #|            bpy.ops.object.modifier_apply(modifier=mod.name)
  #|        except Exception as exc:
  #|            raise RuntimeError(f"Boolean difference failed for '{cutter.name}': {exc}")
  #|    for cutter in cutters:
  #|        bpy.data.objects.remove(cutter, do_unlink=True)
  #|    base_obj.name = name
  #|    return base_obj
  #|

///|
const BOOLEAN_DIFFERENCE_APPLY_MODIFIERS_KEEP_CURVES =
  #|def boolean_difference(base_obj, cutters, name):
  #|    if base_obj is None:
  #|        return None
  #|    # Track original curve objects to preserve them
  #|    original_curves = [c for c in cutters if c is not None and c.type == "CURVE"]
  #|    # Convert base to mesh
  #|    base_obj = ensure_mesh_object(base_obj)
  #|    # For curves, create mesh copies; for non-curves, convert in place
  #|    mesh_cutters = []
  #|    for c in cutters:
  #|        if c is None:
  #|            continue
  #|        if c.type == "CURVE":
  #|            # Create a mesh copy, preserving the original curve
  #|            bpy.ops.object.select_all(action="DESELECT")
  #|            c.select_set(True)
  #|            bpy.context.view_layer.objects.active = c
  #|            bpy.ops.object.duplicate()
  #|            copy_obj = bpy.context.view_layer.objects.active
  #|            copy_obj.name = c.name + "_mesh"
  #|            bpy.ops.object.convert(target="MESH")
  #|            mesh_cutters.append(bpy.context.view_layer.objects.active)
  #|        else:
  #|            mesh_cutters.append(ensure_mesh_object(c))
  #|    if not mesh_cutters:
  #|        base_obj.name = name
  #|        return base_obj
  #|    bpy.ops.object.select_all(action="DESELECT")
  #|    base_obj.select_set(True)
  #|    bpy.context.view_layer.objects.active = base_obj
  #|    for cutter in mesh_cutters:
  #|        if cutter is None:
  #|            continue
  #|        if cutter.type != "MESH":
  #|            raise RuntimeError(f"Cutter '{cutter.name}' is not a mesh after conversion.")
  #|        mod = base_obj.modifiers.new(name="Bool", type='BOOLEAN')
  #|        mod.operation = 'DIFFERENCE'
  #|        mod.object = cutter
  #|        try:
  #|            bpy.ops.object.modifier_apply(modifier=mod.name)
  #|        except Exception as exc:
  #|            raise RuntimeError(f"Boolean difference failed for '{cutter.name}': {exc}")
  #|    # Remove mesh copies used for boolean
  #|    for cutter in mesh_cutters:
  #|        bpy.data.objects.remove(cutter, do_unlink=True)
  #|    # Hide original curves (preserved in scene)
  #|    for curve in original_curves:
  #|        curve.hide_set(True)
  #|        curve.hide_render = True
  #|    base_obj.name = name
  #|    return base_obj
  #|

///|
fn postscript(name : String) -> String {
  (
    $|
    $|    obj_count = len(collection.objects)
    $|    if obj_count == 0:
    $|        raise RuntimeError("No objects were created in the collection.")
    $|    bpy.ops.object.select_all(action="DESELECT")
    $|    for obj in collection.objects:
    $|        obj.select_set(True)
    $|    if collection.objects:
    $|        bpy.context.view_layer.objects.active = collection.objects[0]
    $|
    $|
    $|def main():
    $|    try:
    $|        delete_default_cube()
    $|        # Create or reuse a named collection (based upon the name of this model).
    $|        # Delete all children of the collection in the case that it already exists.
    $|        collection_name = config.get('collectionName', '\{name} Collection')
    $|        print(f"\\nSetting up collection '{collection_name}'...")
    $|        collection = set_up_collection(collection_name)
    $|
    $|        create_model_objects(collection)
    $|
    $|        print("Done.")
    $|    except Exception as exc:
    $|        print(f"ERROR: {exc}", file=sys.stderr)
    $|        sys.exit(1)
    $|
    $|
    $|if __name__ == "__main__":
    $|    main()
  )
}
