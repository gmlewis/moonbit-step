///|
fn probe_family() -> @common.DesignFamily {
  let specs : Array[@common.ParamSpec] = [
    @common.ParamSpec::new(
      name="length",
      default_mm=80.0,
      min_mm=20.0,
      max_mm=200.0,
      description="bar length",
    ),
    @common.ParamSpec::new(
      name="width",
      default_mm=16.0,
      min_mm=4.0,
      max_mm=60.0,
      description="bar width",
    ),
  ]
  match
    @common.DesignFamily::new(
      name="probe-bar",
      specs~,
      description="A test design family.",
      build=fn(parameters) {
        let length = match parameters.get("length") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let width = match parameters.get("width") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let part = @common.Component::new(
          name="probe-bar",
          metadata=@common.Metadata::new(designation="Probe bar"),
        ).add_layer(@cad.Cuboid::new(length, width, 5.0), name="bar")
        Ok(part)
      },
    ) {
    Ok(f) => f
    Err(e) => abort(e.message())
  }
}

///|
test "param specs validate their own declarations" {
  let spec = @common.ParamSpec::new(
    name="length",
    default_mm=10.0,
    min_mm=0.0,
    max_mm=20.0,
  )
  assert_true(spec.validate() is Ok(_))
  let bad = @common.ParamSpec::new(
    name="length",
    default_mm=30.0,
    min_mm=0.0,
    max_mm=20.0,
  )
  assert_true(bad.validate() is Err(_))
  let empty = @common.ParamSpec::new(name="", default_mm=1.0)
  assert_true(empty.validate() is Err(_))
  assert_true(spec.documentation().contains("length = 10"))
}

///|
test "param set validates defaults, overrides, and unknown names" {
  let specs : Array[@common.ParamSpec] = [
    @common.ParamSpec::new(name="a", default_mm=1.0, min_mm=0.0, max_mm=5.0),
    @common.ParamSpec::new(name="b", default_mm=2.0, min_mm=0.0, max_mm=5.0),
  ]
  let defaults = match @common.ParamSet::defaults(specs) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(defaults.get("a") is Ok(1.0))
  assert_true(defaults.get("missing") is Err(_))
  assert_true(defaults.set_value("a", 3.0) is Ok(_))
  assert_true(defaults.set_value("a", 9.0) is Err(_))
  let overridden = match @common.ParamSet::from_values(specs, [("b", 4.0)]) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(overridden.get("b") is Ok(4.0))
  assert_true(@common.ParamSet::from_values(specs, [("c", 1.0)]) is Err(_))
  assert_true(@common.ParamSet::defaults(specs) is Ok(_))
  let length = match defaults.length("a") {
    Ok(l) => l
    Err(e) => abort(e.message())
  }
  assert_true(close(length.to_mm(), 1.0))
}

///|
test "design family builds defaults, variants, and rejects bad values" {
  let family = probe_family()
  assert_eq(family.parameter_names().length(), 2)
  let part = match family.build_values([]) {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (x0, x1, y0, y1, _z0, _z1) = part.bounding_box()
  assert_true(close(x1 - x0, 80.0))
  assert_true(close(y1 - y0, 16.0))

  let variant = match
    family.with_variant("short", [("length", 40.0), ("width", 10.0)]) {
    Ok(f) => f
    Err(e) => abort(e.message())
  }
  assert_true(variant.variant_names().contains("short"))
  let short = match variant.build_variant("short") {
    Ok(c) => c
    Err(e) => abort(e.message())
  }
  let (sx0, sx1, sy0, sy1, _sz0, _sz1) = short.bounding_box()
  assert_true(close(sx1 - sx0, 40.0))
  assert_true(close(sy1 - sy0, 10.0))
  assert_true(variant.variant("missing") is Err(_))
  assert_true(family.build_values([("length", 500.0)]) is Err(_))
  assert_true(family.build_values([("unknown", 1.0)]) is Err(_))
  assert_true(family.documentation().contains("probe-bar"))
  assert_true(family.documentation().contains("length"))
}

///|
test "param set documents units and rejects non-length unit conversion" {
  let specs : Array[@common.ParamSpec] = [
    @common.ParamSpec::new(name="angle", default_mm=30.0, unit="deg"),
  ]
  let set = match @common.ParamSet::defaults(specs) {
    Ok(s) => s
    Err(e) => abort(e.message())
  }
  assert_true(set.length("angle") is Err(_))
  assert_true(set.documentation().contains("deg"))
}
