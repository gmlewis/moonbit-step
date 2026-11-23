///|
let nominal_notice : String = "NOMINAL BOOLEANS: difference()/union_all() concatenate faces; they do not trim or subtract."

///|
fn count_occurrences(haystack : String, needle : String) -> Int32 {
  haystack.split(needle).count() - 1
}

///|
test "checked export rejects dropped nested booleans" {
  let base = @cad.Cuboid::new(20.0, 20.0, 5.0).with_name("base")
  let cutter = @cad.Cuboid::new(2.0, 2.0, 10.0).with_name("cutter")
  let inner = @cad.difference(base, [cutter], name="inner")
  let other = @cad.Cuboid::new(3.0, 3.0, 3.0).with_name("other")
  let design = @cad.Design::new(name="nested").add(
    @cad.union_all([inner, other], name="outer"),
  )
  assert_true(design.has_errors())
}

///|
test "checked export accepts a plain cuboid" {
  let design = @cad.Design::new(name="plain").add(
    @cad.Cuboid::new(10.0, 10.0, 10.0).with_name("cube"),
  )
  assert_false(design.has_errors())
  let step = design.to_step_file_checked()
  assert_true(step.contains("MANIFOLD_SOLID_BREP"))
}

///|
test "checked_result returns Ok for a clean design" {
  let design = @cad.Design::new(name="plain").add(
    @cad.Cuboid::new(10.0, 10.0, 10.0).with_name("cube"),
  )
  match design.to_step_file_checked_result() {
    Ok(text) => assert_eq(text, design.to_step_file())
    Err(_) => fail("clean design should not produce an error diagnostic")
  }
}

///|
test "checked_result returns the error diagnostic instead of aborting" {
  let base = @cad.Cuboid::new(20.0, 20.0, 5.0).with_name("base")
  let cutter = @cad.Cuboid::new(2.0, 2.0, 10.0).with_name("cutter")
  let inner = @cad.difference(base, [cutter], name="inner")
  let other = @cad.Cuboid::new(3.0, 3.0, 3.0).with_name("other")
  let design = @cad.Design::new(name="nested").add(
    @cad.union_all([inner, other], name="outer"),
  )
  match design.to_step_file_checked_result() {
    Ok(_) => fail("nested boolean must be rejected")
    Err(d) => {
      assert_true(d.severity().is_error())
      assert_true(d.message().contains("nested"))
    }
  }
}

///|
test "header carries the nominal-boolean notice" {
  let base = @cad.Cuboid::new(20.0, 20.0, 5.0).with_name("base")
  let cutter = @cad.Cuboid::new(2.0, 2.0, 10.0).with_name("cutter")
  let design = @cad.Design::new(name="cut").add(
    @cad.difference(base, [cutter], name="cut"),
  )
  assert_false(design.has_errors())
  inspect(count_occurrences(design.to_step_file(), nominal_notice), content="1")
}

///|
test "plain designs do not carry the notice" {
  let design = @cad.Design::new(name="plain").add(
    @cad.Cuboid::new(10.0, 10.0, 10.0).with_name("cube"),
  )
  inspect(count_occurrences(design.to_step_file(), nominal_notice), content="0")
}
