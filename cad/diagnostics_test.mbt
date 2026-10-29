///|
fn nominal_union_count(diags : Array[@cad.Diagnostic]) -> Int32 {
  diags
  .iter()
  .filter(fn(d) {
    match d {
      NominalUnion(_) => true
      _ => false
    }
  })
  .count()
}

///|
fn nominal_difference_count(diags : Array[@cad.Diagnostic]) -> Int32 {
  diags
  .iter()
  .filter(fn(d) {
    match d {
      NominalDifference(_) => true
      _ => false
    }
  })
  .count()
}

///|
fn dropped_nested_count(diags : Array[@cad.Diagnostic]) -> Int32 {
  diags
  .iter()
  .filter(fn(d) {
    match d {
      DroppedNestedBoolean(_) => true
      _ => false
    }
  })
  .count()
}

///|
test "union_all at top level is a nominal union" {
  let a = @cad.Cuboid::new(10.0, 10.0, 10.0).with_name("a")
  let b = @cad.Cuboid::new(10.0, 10.0, 10.0).with_name("b")
  let design = @cad.Design::new(name="unioned").add(
    @cad.union_all([a, b], name="pair"),
  )
  let diags = design.diagnostics()
  inspect(nominal_union_count(diags), content="1")
  inspect(dropped_nested_count(diags), content="0")
  let messages = diags.map(fn(d) { d.message() }).join(" ")
  assert_true(messages.contains("'pair'"))
  assert_true(messages.contains("concatenated"))
}

///|
test "difference at top level is a nominal difference" {
  let base = @cad.Cuboid::new(20.0, 20.0, 5.0).with_name("base")
  let cutter = @cad.Cuboid::new(2.0, 2.0, 10.0).with_name("cutter")
  let design = @cad.Design::new(name="cut").add(
    @cad.difference(base, [cutter], name="tag-engraved"),
  )
  let diags = design.diagnostics()
  inspect(nominal_difference_count(diags), content="1")
  let messages = diags.map(fn(d) { d.message() }).join(" ")
  assert_true(messages.contains("'tag-engraved'"))
  assert_true(messages.contains("subtracted"))
}

///|
test "nested boolean is reported as an error" {
  let base = @cad.Cuboid::new(20.0, 20.0, 5.0).with_name("base")
  let cutter = @cad.Cuboid::new(2.0, 2.0, 10.0).with_name("cutter")
  let inner = @cad.difference(base, [cutter], name="inner")
  let other = @cad.Cuboid::new(3.0, 3.0, 3.0).with_name("other")
  let design = @cad.Design::new(name="nested").add(
    @cad.union_all([inner, other], name="outer"),
  )
  let diags = design.diagnostics()
  inspect(dropped_nested_count(diags), content="1")
  let nested = diags.filter(fn(d) {
    match d {
      DroppedNestedBoolean(_) => true
      _ => false
    }
  })
  inspect(nested[0].severity().is_error(), content="true")
  assert_true(nested[0].message().contains("'inner'"))
  assert_true(nested[0].message().contains("nested"))
}

///|
test "diagnostics is a pure observation" {
  let base = @cad.Cuboid::new(20.0, 20.0, 5.0).with_name("base")
  let cutter = @cad.Cuboid::new(2.0, 2.0, 10.0).with_name("cutter")
  let design = @cad.Design::new(name="pure").add(
    @cad.difference(base, [cutter], name="cut"),
  )
  let before = design.to_step_file()
  let first = design.diagnostics().map(fn(d) { d.message() })
  let second = design.diagnostics().map(fn(d) { d.message() })
  assert_eq(first, second)
  let after = design.to_step_file()
  assert_eq(before, after)
}
