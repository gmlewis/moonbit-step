///|
/// json_field returns an object member, or JSON null when absent.
fn json_field(j : Json, key : String) -> Json {
  match j {
    Object(m) =>
      match m.get(key) {
        Some(v) => v
        None => Json::null()
      }
    _ => Json::null()
  }
}

///|
fn json_arr_field(j : Json, key : String) -> Array[Json] {
  match json_field(j, key) {
    Array(a) => a
    _ => []
  }
}

///|
fn json_num_field(j : Json, key : String) -> Double {
  match json_field(j, key) {
    Number(n, ..) => n
    _ => -1.0
  }
}

///|
fn json_str_field(j : Json, key : String) -> String {
  match json_field(j, key) {
    String(s) => s
    _ => ""
  }
}

///|
/// gltf_buffer_bytes decodes the embedded binary buffer of a glTF document.
fn gltf_buffer_bytes(doc : Json) -> FixedArray[Byte] {
  let buffers = json_arr_field(doc, "buffers")
  if buffers.is_empty() {
    return []
  }
  let uri = json_str_field(buffers[0], "uri")
  let prefix = "data:application/octet-stream;base64,"
  let b64 = uri.replace(old=prefix, new="")
  let bytes = @base64.std_decode2bytes(b64) catch { _ => Bytes::from_array([]) }
  bytes.to_fixedarray()
}

///|
fn read_float_le(arr : FixedArray[Byte], off : Int32) -> Double {
  let bits = read_uint_le(arr, off)
  Float::reinterpret_from_uint(bits).to_double()
}

///|
fn read_uint_le(arr : FixedArray[Byte], off : Int32) -> UInt32 {
  arr[off].to_uint() |
  (arr[off + 1].to_uint() << 8) |
  (arr[off + 2].to_uint() << 16) |
  (arr[off + 3].to_uint() << 24)
}

///|
/// gltf_accessor_view resolves an accessor to its bytes, offset, and count.
fn gltf_accessor_view(
  doc : Json,
  accessor_index : Int32,
) -> (FixedArray[Byte], Int32, Int32) {
  let accessors = json_arr_field(doc, "accessors")
  let acc = accessors[accessor_index]
  let bv_i = json_num_field(acc, "bufferView").to_int()
  let bv = json_arr_field(doc, "bufferViews")[bv_i]
  let off = json_num_field(bv, "byteOffset").to_int()
  let count = json_num_field(acc, "count").to_int()
  (gltf_buffer_bytes(doc), off, count)
}

///|
fn gltf_accessor_vec3(doc : Json, accessor_index : Int32) -> Array[Vec3] {
  let (arr, off, count) = gltf_accessor_view(doc, accessor_index)
  let out : Array[Vec3] = []
  for i in 0..<count {
    let b = off + i * 12
    out.push(
      (
        read_float_le(arr, b),
        read_float_le(arr, b + 4),
        read_float_le(arr, b + 8),
      ),
    )
  }
  out
}

///|
fn gltf_accessor_indices(doc : Json, accessor_index : Int32) -> Array[Int32] {
  let (arr, off, count) = gltf_accessor_view(doc, accessor_index)
  let out : Array[Int32] = []
  for i in 0..<count {
    out.push(read_uint_le(arr, off + i * 4).reinterpret_as_int())
  }
  out
}

///|
/// gltf_primitive resolves mesh 0's primitive into positions, normals, and
/// indices.
fn gltf_primitive(doc : Json) -> (Array[Vec3], Array[Vec3], Array[Int32]) {
  let meshes = json_arr_field(doc, "meshes")
  let prim = json_arr_field(meshes[0], "primitives")[0]
  let attrs = json_field(prim, "attributes")
  let pos = json_num_field(attrs, "POSITION").to_int()
  let nrm = json_num_field(attrs, "NORMAL").to_int()
  let idx = json_num_field(prim, "indices").to_int()
  (
    gltf_accessor_vec3(doc, pos),
    gltf_accessor_vec3(doc, nrm),
    gltf_accessor_indices(doc, idx),
  )
}

///|
fn bump_edge(counts : Map[String, Int32], a : Int32, b : Int32) -> Unit {
  let key = if a < b { "\{a}:\{b}" } else { "\{b}:\{a}" }
  counts.set(key, counts.get(key).unwrap_or(0) + 1)
}

///|
/// assert_mesh_closed verifies every edge is used by exactly two triangles.
fn assert_mesh_closed(indices : Array[Int32]) -> Unit {
  if indices.length() % 3 != 0 {
    abort("index count is not a multiple of three")
  }
  let counts : Map[String, Int32] = Map([])
  for t in 0..<(indices.length() / 3) {
    let a = indices[t * 3]
    let b = indices[t * 3 + 1]
    let c = indices[t * 3 + 2]
    bump_edge(counts, a, b)
    bump_edge(counts, b, c)
    bump_edge(counts, c, a)
  }
  for _key, count in counts {
    if count != 2 {
      abort("edge #\{_key} is used \{count} times (expected 2)")
    }
  }
}

///|
fn near3(a : Vec3, b : Vec3) -> Bool {
  (a.0 - b.0).abs() < 1.0e-4 &&
  (a.1 - b.1).abs() < 1.0e-4 &&
  (a.2 - b.2).abs() < 1.0e-4
}

///|
test "cuboid exports one closed triangle mesh" {
  let design = Design::new(name="cube").add(
    Cuboid::new(2.0, 3.0, 4.0).with_name("cube"),
  )
  let text = design.to_gltf()
  assert_true(@json.valid(text))
  let doc = @json.parse(text) catch { _ => abort("invalid glTF JSON") }
  inspect(json_arr_field(doc, "meshes").length(), content="1")
  let (positions, normals, indices) = gltf_primitive(doc)
  inspect(positions.length(), content="8")
  inspect(indices.length(), content="36")
  for i in indices {
    assert_true(i >= 0 && i < positions.length())
  }
  let corners : Array[Vec3] = [
    (0.0, 0.0, 0.0),
    (2.0, 0.0, 0.0),
    (2.0, 3.0, 0.0),
    (0.0, 3.0, 0.0),
    (0.0, 0.0, 4.0),
    (2.0, 0.0, 4.0),
    (2.0, 3.0, 4.0),
    (0.0, 3.0, 4.0),
  ]
  for p in positions {
    assert_true(corners.any(fn(c) { near3(p, c) }))
  }
  // Normals point away from the box center.
  let center : Vec3 = (1.0, 1.5, 2.0)
  for i in 0..<positions.length() {
    let p = positions[i]
    let n = normals[i]
    let out = v_add(p, v_scale(center, -1.0))
    assert_true(v_dot(n, out) > 0.0)
  }
  assert_mesh_closed(indices)
}

///|
test "cylinder tessellates without gaps" {
  let design = Design::new(name="cyl").add(
    Cylinder::new(10.0, 5.0).with_name("pin"),
  )
  let doc = @json.parse(design.to_gltf()) catch {
    _ => abort("invalid glTF JSON")
  }
  let (positions, normals, indices) = gltf_primitive(doc)
  // 64-segment band (128 triangles) plus two 64-gon caps (62 each).
  inspect(indices.length() / 3, content="252")
  // Two rings of 64 welded vertices.
  inspect(positions.length(), content="128")
  assert_mesh_closed(indices)
  inspect(normals.length(), content="128")
  for i in 0..<normals.length() {
    let n = normals[i]
    let len = Double::sqrt(n.0 * n.0 + n.1 * n.1 + n.2 * n.2)
    assert_true((len - 1.0).abs() < 1.0e-4)
    // Radial component points away from the cylinder axis.
    let p = positions[i]
    assert_true(n.0 * p.0 + n.1 * p.1 > 0.0)
  }
}

///|
test "node colors are preserved" {
  let design = Design::new(name="two")
    .add(
      Cuboid::new(1.0, 1.0, 1.0)
      .with_name("red")
      .with_color(Rgb::new(1.0, 0.0, 0.0)),
    )
    .add(
      Cuboid::new(1.0, 1.0, 1.0)
      .with_name("blue")
      .with_color(Rgb::new(0.0, 0.0, 1.0))
      .translate(x=3.0),
    )
  let doc = @json.parse(design.to_gltf()) catch {
    _ => abort("invalid glTF JSON")
  }
  inspect(json_arr_field(doc, "meshes").length(), content="2")
  let materials = json_arr_field(doc, "materials")
  inspect(materials.length(), content="2")
  let colors : Array[Vec3] = []
  for m in materials {
    let pbr = json_field(m, "pbrMetallicRoughness")
    let factor = json_arr_field(pbr, "baseColorFactor")
    colors.push(
      (
        match factor[0] {
          Number(n, ..) => n
          _ => -1.0
        },
        match factor[1] {
          Number(n, ..) => n
          _ => -1.0
        },
        match factor[2] {
          Number(n, ..) => n
          _ => -1.0
        },
      ),
    )
  }
  assert_true(colors.any(fn(c) { near3(c, (1.0, 0.0, 0.0)) }))
  assert_true(colors.any(fn(c) { near3(c, (0.0, 0.0, 1.0)) }))
}

///|
test "gltf does not disturb step" {
  let design = Design::new(name="stable").add(
    Cuboid::new(2.0, 2.0, 2.0).with_name("cube"),
  )
  let before = design.to_step_file().split("DATA;").collect()[1]
  let _ = design.to_gltf()
  let after = design.to_step_file().split("DATA;").collect()[1]
  assert_eq(before, after)
}

///|
test "curved bezier solid tessellates watertight" {
  let circle = bs_circle_path(5.0, (0.0, 0.0), clear=false)
  let design = Design::new(name="disk").add(
    ExtrudedBezierProfile::new([circle], 3.0).with_name("disk"),
  )
  let doc = @json.parse(design.to_gltf()) catch {
    _ => abort("invalid glTF JSON")
  }
  let (_positions, _normals, indices) = gltf_primitive(doc)
  assert_true(indices.length() > 0)
  assert_mesh_closed(indices)
}

///|
test "bezier solid with hole tessellates watertight" {
  let outer = bs_straight_square(0.0, 0.0, 10.0, 10.0, clear=false)
  let hole = bs_circle_path(2.0, (5.0, 5.0), clear=true)
  let design = Design::new(name="plate").add(
    ExtrudedBezierProfile::new([outer, hole], 2.0).with_name("plate"),
  )
  let doc = @json.parse(design.to_gltf()) catch {
    _ => abort("invalid glTF JSON")
  }
  let (_positions, _normals, indices) = gltf_primitive(doc)
  assert_true(indices.length() > 0)
  assert_mesh_closed(indices)
}

///|
test "polyline tube with hole tessellates watertight" {
  let design = Design::new(name="tube").add(
    tube(10.0, 4.0, 5.0, segments=32).with_name("tube"),
  )
  let doc = @json.parse(design.to_gltf()) catch {
    _ => abort("invalid glTF JSON")
  }
  let (_positions, _normals, indices) = gltf_primitive(doc)
  assert_true(indices.length() > 0)
  assert_mesh_closed(indices)
}
