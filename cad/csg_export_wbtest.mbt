///|
priv struct CsgBool {
  id : Int32
  op : String
  first : Int32
  second : Int32
}

///|
/// leading_int parses the digit run at the start of a string view (after an
/// optional leading '#'), stopping at the first other character.
fn leading_int(s : StringView) -> Int32 {
  let mut n = 0
  let mut i = 0
  let len = s.length()
  while i < len {
    match s.get_char(i) {
      Some(c) =>
        if c >= '0' && c <= '9' {
          n = n * 10 + (c.to_int() - '0'.to_int())
          i = i + 1
        } else if i == 0 && c == '#' {
          i = i + 1
        } else {
          i = len
        }
      None => i = len
    }
  }
  n
}

///|
fn csg_booleans(step : String) -> Array[CsgBool] {
  let out : Array[CsgBool] = []
  for line in step.split("\n") {
    if line.contains("BOOLEAN_RESULT(") {
      let parts = line.split("BOOLEAN_RESULT(").collect()
      let id = leading_int(parts[0])
      let fields = parts[1].split(",").collect()
      if fields.length() >= 4 {
        out.push({
          id,
          op: fields[1].to_owned(),
          first: leading_int(fields[2]),
          second: leading_int(fields[3]),
        })
      }
    }
  }
  out
}

///|
fn csg_solid_root(step : String) -> Int32? {
  for line in step.split("\n") {
    if line.contains("CSG_SOLID(") {
      let parts = line.split("CSG_SOLID(").collect()
      let refs = parts[1].split("#").collect()
      if refs.length() > 1 {
        return Some(leading_int(refs[1]))
      }
      return None
    }
  }
  None
}

///|
fn find_boolean(booles : Array[CsgBool], id : Int32) -> CsgBool {
  for b in booles {
    if b.id == id {
      return b
    }
  }
  abort("no BOOLEAN_RESULT with id #\{id}")
}

///|
fn entity_type_of(step : String, id : Int32) -> String {
  for line in step.split("\n") {
    let parts = line.split("=").collect()
    if parts.length() >= 2 &&
      parts[0].get_char(0) == Some('#') &&
      leading_int(parts[0]) == id {
      return parts[1].split("(").collect()[0].to_owned()
    }
  }
  ""
}

///|
fn check_refs_resolve(step : String) -> Unit {
  let defined : Map[Int32, Bool] = Map([])
  for line in step.split("\n") {
    let parts = line.split("=").collect()
    if parts.length() >= 2 && parts[0].get_char(0) == Some('#') {
      defined.set(leading_int(parts[0]), true)
    }
  }
  for chunk in step.split("#") {
    let id = leading_int(chunk)
    if id > 0 && defined.get(id) != Some(true) {
      abort("dangling reference #\{id}")
    }
  }
}

///|
test "difference exports a boolean tree" {
  let base = Cuboid::new(20.0, 20.0, 5.0).with_name("base")
  let c1 = Cuboid::new(4.0, 4.0, 10.0).with_name("c1").translate(z=-2.0)
  let c2 = Cuboid::new(4.0, 4.0, 10.0).with_name("c2").translate(x=10.0, z=-2.0)
  let step = Design::new(name="cut")
    .add(difference(base, [c1, c2], name="cut"))
    .to_csg_step()
  inspect(step.split("CSG_SHAPE_REPRESENTATION(").count() - 1, content="1")
  inspect(step.split("CSG_SOLID(").count() - 1, content="1")
  inspect(step.split("BOOLEAN_RESULT(").count() - 1, content="2")
  let booles = csg_booleans(step)
  let root = match csg_solid_root(step) {
    Some(r) => r
    None => abort("no CSG_SOLID")
  }
  let outer = find_boolean(booles, root)
  assert_eq(outer.op, ".DIFFERENCE.")
  let cutters = find_boolean(booles, outer.second)
  assert_eq(cutters.op, ".UNION.")
  assert_eq(entity_type_of(step, outer.first), "MANIFOLD_SOLID_BREP")
}

///|
test "union chain is nested" {
  let a = Cuboid::new(2.0, 2.0, 2.0).with_name("a")
  let b = Cuboid::new(2.0, 2.0, 2.0).with_name("b").translate(x=3.0)
  let c = Cuboid::new(2.0, 2.0, 2.0).with_name("c").translate(x=6.0)
  let step = Design::new(name="chain")
    .add(union_all([a, b, c], name="chain"))
    .to_csg_step()
  let booles = csg_booleans(step)
  inspect(booles.length(), content="2")
  let root = match csg_solid_root(step) {
    Some(r) => r
    None => abort("no CSG_SOLID")
  }
  let outer = find_boolean(booles, root)
  assert_eq(outer.op, ".UNION.")
  let inner = find_boolean(booles, outer.first)
  assert_eq(inner.op, ".UNION.")
  // Left fold: ((a UNION b) UNION c).
  assert_eq(entity_type_of(step, inner.second), "MANIFOLD_SOLID_BREP")
  assert_eq(entity_type_of(step, outer.second), "MANIFOLD_SOLID_BREP")
}

///|
test "degenerate booleans emit no boolean" {
  let a = Cuboid::new(2.0, 2.0, 2.0).with_name("a")
  let single = Design::new(name="one")
    .add(union_all([a], name="one"))
    .to_csg_step()
  assert_false(single.contains("BOOLEAN_RESULT("))
  assert_false(single.contains("CSG_SOLID("))
  let none = Design::new(name="none")
    .add(difference(a, [], name="none"))
    .to_csg_step()
  assert_false(none.contains("BOOLEAN_RESULT("))
  assert_false(none.contains("CSG_SOLID("))
}

///|
test "nested booleans are representable in csg" {
  let base = Cuboid::new(10.0, 10.0, 5.0).with_name("base")
  let cutter = Cuboid::new(2.0, 2.0, 10.0).with_name("cutter").translate(z=-2.0)
  let inner = difference(base, [cutter], name="inner")
  let c = Cuboid::new(2.0, 2.0, 2.0).with_name("c").translate(x=12.0)
  let step = Design::new(name="outer")
    .add(union_all([inner, c], name="outer"))
    .to_csg_step()
  let booles = csg_booleans(step)
  inspect(booles.length(), content="2")
  let root = match csg_solid_root(step) {
    Some(r) => r
    None => abort("no CSG_SOLID")
  }
  let outer = find_boolean(booles, root)
  assert_eq(outer.op, ".UNION.")
  let inner_bool = find_boolean(booles, outer.first)
  assert_eq(inner_bool.op, ".DIFFERENCE.")
}

///|
test "csg output references resolve" {
  let base = Cuboid::new(20.0, 20.0, 5.0).with_name("base")
  let cutter = Cylinder::new(4.0, 10.0).with_name("hole").translate(z=-2.0)
  let step = Design::new(name="cut")
    .add(difference(base, [cutter], name="cut"))
    .to_csg_step()
  let repo = @parse.parse_repository_from_string(step) catch {
    _ => abort("CSG output failed to parse")
  }
  check_refs_resolve(repo.to_step_file())
}

///|
test "flat export is unchanged" {
  let base = Cuboid::new(20.0, 20.0, 5.0).with_name("base")
  let cutter = Cuboid::new(4.0, 4.0, 10.0).with_name("cutter").translate(z=-2.0)
  let design = Design::new(name="cut").add(
    difference(base, [cutter], name="cut"),
  )
  let before = design.to_step_file().split("DATA;").collect()[1]
  let _ = design.to_csg_step()
  let after = design.to_step_file().split("DATA;").collect()[1]
  assert_eq(before, after)
}

///|
test "csg header has no nominal notice" {
  let base = Cuboid::new(20.0, 20.0, 5.0).with_name("base")
  let cutter = Cuboid::new(4.0, 4.0, 10.0).with_name("cutter").translate(z=-2.0)
  let step = Design::new(name="cut")
    .add(difference(base, [cutter], name="cut"))
    .to_csg_step()
  assert_false(step.contains("NOMINAL BOOLEANS"))
  assert_false(step.contains("nominal"))
}
