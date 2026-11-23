///|
fn mbracket_ok(
  result : Result[@common.Component, @common.SpecError],
) -> @common.Component {
  match result {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
}

///|
fn[T] mbracket_spec(result : Result[T, @common.SpecError]) -> T {
  match result {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
}

///|
test "Maker Store 20-series corner bracket envelope" {
  let part = mbracket_ok(@profiles.makerstore_corner_bracket())
  let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
  assert_true((x0 + 10.0).abs() < 1.0e-6)
  assert_true((x1 - 10.0).abs() < 1.0e-6)
  assert_true((y0 + 10.0).abs() < 1.0e-6)
  assert_true((y1 - 10.0).abs() < 1.0e-6)
  assert_true(z0.abs() < 1.0e-6)
  assert_true((z1 - 20.0).abs() < 1.0e-6)
  for
    name in ["base-face", "side-face", "base-slot", "side-slot", "inner-corner"] {
    let mut found = false
    for connector in part.connectors() {
      if connector.name == name {
        found = true
      }
    }
    assert_true(found)
  }
  assert_true(part.metadata().source.contains("BRAC-90CAST"))
}

///|
test "Maker Store corner bracket family presets" {
  let family = mbracket_spec(@profiles.makerstore_corner_bracket_family())
  let names = family.variant_names()
  assert_true(names.contains("brac-90cast"))
  assert_true(names.contains("brac-40s-90cast-b"))
  let part = mbracket_ok(family.build_variant("brac-40s-90cast-b"))
  let (x0, x1, _y0, _y1, _z0, z1) = part.bounding_box()
  assert_true((x0 + 20.0).abs() < 1.0e-6)
  assert_true((x1 - 20.0).abs() < 1.0e-6)
  assert_true((z1 - 40.0).abs() < 1.0e-6)
}
