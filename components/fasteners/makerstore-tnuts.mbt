///|
/// makerstore_hex_tnut builds a Maker Store 20-series sliding T-nut and attaches
/// Maker Store provenance.
///
/// Geometry is the generic `extrusion_tnut` hex body; this wrapper only adds the
/// real SKU, source URL, material, and price for the `HARD-TNUT-SLIDING` product
/// (M3, M4, M5; $0.65). The 20-series slot is 5 mm.
pub fn makerstore_hex_tnut(
  thread : String,
  slot_width_mm~ : Double = 5.0,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let spec = match extrusion_tnut_spec(thread, slot_width_mm~) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let part = match extrusion_tnut(spec, color~) {
    Err(e) => return Err(e)
    Ok(c) => c
  }
  let source = "https://makerstore.cc/product/sliding-t-nut/ | SKU HARD-TNUT-SLIDING | $0.65 | steel | \{spec.thread} hex-body sliding T-nut, slot \{@cad.fmt_double(slot_width_mm, None)} mm | product variants M3/M4/M5"
  Ok(
    part
    .with_name("makerstore-tnut-\{spec.thread}")
    .with_metadata(
      @common.Metadata::new(
        designation="Maker Store sliding T-nut \{spec.thread}, slot \{@cad.fmt_double(slot_width_mm, None)} mm (HARD-TNUT-SLIDING)",
        standard="Maker Store sliding T-nut (HARD-TNUT-SLIDING)",
        family="Maker Store sliding T-nut",
        size=spec.thread,
        length_mm=spec.thickness_mm,
        material="steel (label only; not a structural claim)",
        source~,
      ),
    ),
  )
}

///|
/// makerstore_sliding_tnut builds a Maker Store 40-series sliding T-nut as a
/// published-envelope block with a central thread-envelope hole.
///
/// Dimensions come from the live product drawing for SKU
/// `HARD-40S-TNUT-STEEL-SLID-18`: A = 20.0 (length), B = 19.1 (across), D = 7.7
/// (slot width), E = 9.1 (thickness); threads M4, M5, M6, M8. The block is the
/// dimensioned outer envelope; the exact cavity/lip neck profile, spring-ball
/// retention, and the thread helix are not modelled. `slot_width_mm` records
/// the slot series the nut engages, matching `extrusion_tnut`.
///
/// Axis +Z with the bearing face at `z = 0` (bottom) facing the slot; the top
/// face is at `z = thickness`.
pub fn makerstore_sliding_tnut(
  thread : String,
  slot_width_mm~ : Double = 7.7,
  detail~ : @common.DetailLevel = @common.DetailLevel::Detailed,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  let _ = detail
  let token = thread.trim().to_owned().to_upper()
  let hole = match token {
    "M4" => 4.0
    "M5" => 5.0
    "M6" => 6.0
    "M8" => 8.0
    other =>
      return Err(
        @common.InvalidSize(
          "unsupported 40-series sliding T-nut thread: \{other}; supported: M4, M5, M6, M8",
        ),
      )
  }
  let length_mm = 20.0
  let width_mm = 19.1
  let thickness_mm = 9.1
  match @common.require_positive("40-series T-nut slot width", slot_width_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if slot_width_mm >= width_mm {
    return Err(
      @common.InvalidParameter(
        "40-series T-nut body width must exceed the slot width so it engages the cavity",
      ),
    )
  }
  let outer = @cad.Profile2D::centered_rect(length_mm, width_mm)
  let body = @cad.ExtrudedProfile::new(
    outer,
    thickness_mm,
    round_bore=((0.0, 0.0), hole),
  )
  let features = @common.FeatureRecord::new(
    modeled=["body", "rectangular-prism", "through-hole"],
    approximated=[
      @common.Approximation::new(
        feature="body-profile",
        kind=@common.ApproximationKind::EngineeringDefault,
        deviation_mm=0.0,
        control="published A/B/E block envelope; the exact cavity neck and lip relief are not modelled",
      ),
    ],
    omitted=[
      @common.Omission::new(
        feature="thread-helix",
        reason="the bore is the thread envelope, not a modeled helix",
      ),
      @common.Omission::new(
        feature="spring-ball",
        reason="retention hardware is not modelled",
      ),
      @common.Omission::new(
        feature="style-specific-retention",
        reason="the sliding retention feature is not modelled",
      ),
    ],
  )
  let name = "TNUT-40S-\{token}-slot\{@cad.fmt_double(slot_width_mm, None)}"
  Ok(
    with_tnut_connectors(
      @common.Component::new(
        name~,
        metadata=@common.Metadata::new(
          designation="Maker Store 40-series sliding T-nut \{token}, slot \{@cad.fmt_double(slot_width_mm, None)} mm (HARD-40S-TNUT-STEEL-SLID-18)",
          standard="Maker Store 40-series sliding T-nut (HARD-40S-TNUT-STEEL-SLID-18)",
          family="Maker Store 40-series sliding T-nut",
          size=token,
          length_mm=thickness_mm,
          material="steel (label only; not a structural claim)",
          source="https://makerstore.cc/product/hard-40s-tnut-steel-slid-18-1pc/ | SKU HARD-40S-TNUT-STEEL-SLID-18 | $0.60-$0.65 | drawing A 20, B 19.1, D 7.7, E 9.1 mm; threads M4/M5/M6/M8",
        ),
        description="Maker Store 40-series sliding T-nut envelope: a 20 x 19.1 x 9.1 mm block with a central thread-envelope hole. The exact cavity neck, spring-ball retention, and thread helix are not modelled.",
        features~,
      ).add_layer(body, name="body", color~),
      token,
      thickness_mm,
      width_mm,
      slot_width_mm,
    ),
  )
}

///|
/// tnut_thread_token maps a nominal thread diameter to a thread token, or
/// reports an unsupported size.
fn tnut_thread_token(diameter_mm : Double) -> Result[String, @common.SpecError] {
  let close = fn(reference : Double) {
    (diameter_mm - reference).abs() < 1.0e-6
  }
  if close(3.0) {
    Ok("M3")
  } else if close(4.0) {
    Ok("M4")
  } else if close(5.0) {
    Ok("M5")
  } else if close(6.0) {
    Ok("M6")
  } else if close(8.0) {
    Ok("M8")
  } else {
    Err(
      @common.InvalidSize(
        "unsupported T-nut thread diameter: \{diameter_mm} mm; supported: M3, M4, M5, M6, M8",
      ),
    )
  }
}

///|
/// makerstore_hex_tnut_family exposes the 20-series hex sliding T-nut as a
/// validated design family over the M3/M4/M5 thread sizes.
pub fn makerstore_hex_tnut_family() -> Result[
  @common.DesignFamily,
  @common.SpecError,
] {
  let specs : Array[@common.ParamSpec] = [
    @common.ParamSpec::new(
      name="thread",
      default_mm=5.0,
      min_mm=3.0,
      max_mm=5.0,
      description="nominal thread diameter (3=M3, 4=M4, 5=M5)",
    ),
  ]
  let family = match
    @common.DesignFamily::new(
      name="makerstore-hex-tnut",
      specs~,
      description="Maker Store 20-series hex sliding T-nut (HARD-TNUT-SLIDING).",
      build=fn(parameters) {
        let diameter = match parameters.get("thread") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let token = match tnut_thread_token(diameter) {
          Ok(t) => t
          Err(e) => return Err(e)
        }
        makerstore_hex_tnut(token)
      },
    ) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  let family = match family.with_variant("m3", [("thread", 3.0)]) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  let family = match family.with_variant("m4", [("thread", 4.0)]) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  family.with_variant("m5", [("thread", 5.0)])
}

///|
/// makerstore_slider_tnut_family exposes the 40-series sliding block T-nut as a
/// validated design family over the M4/M5/M6/M8 thread sizes.
pub fn makerstore_slider_tnut_family() -> Result[
  @common.DesignFamily,
  @common.SpecError,
] {
  let specs : Array[@common.ParamSpec] = [
    @common.ParamSpec::new(
      name="thread",
      default_mm=6.0,
      min_mm=4.0,
      max_mm=8.0,
      description="nominal thread diameter (4=M4, 5=M5, 6=M6, 8=M8)",
    ),
  ]
  let family = match
    @common.DesignFamily::new(
      name="makerstore-slider-tnut",
      specs~,
      description="Maker Store 40-series sliding block T-nut (HARD-40S-TNUT-STEEL-SLID-18).",
      build=fn(parameters) {
        let diameter = match parameters.get("thread") {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let token = match tnut_thread_token(diameter) {
          Ok(t) => t
          Err(e) => return Err(e)
        }
        makerstore_sliding_tnut(token)
      },
    ) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  let family = match family.with_variant("m4", [("thread", 4.0)]) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  let family = match family.with_variant("m5", [("thread", 5.0)]) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  let family = match family.with_variant("m6", [("thread", 6.0)]) {
    Ok(f) => f
    Err(e) => return Err(e)
  }
  family.with_variant("m8", [("thread", 8.0)])
}
