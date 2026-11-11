///|
/// keyed_shaft_cross_section builds the XY cross-section of a shaft with a
/// flat-bottomed rectangular keyway on the +Y side.
///
/// The keyway is a real geometric notch in the section, not a nominal boolean:
/// the outline is the shaft circle with a rectangular cutout of `keyway_width`
/// and `keyway_depth` (measured from the shaft surface). The two slot sides are
/// at `x = +- keyway_width / 2`; the flat bottom is at `y = radius - depth`.
///
/// The keyway is deliberately flat-bottomed with sharp corners. A real end-mill
/// keyway has a rounded bottom (the cutter radius); that is recorded as an
/// omission by the builder.
pub fn keyed_shaft_cross_section(
  diameter_mm : Double,
  keyway_width_mm : Double,
  keyway_depth_mm : Double,
  segments~ : Int32 = 64,
) -> Result[Array[@cad.Vec2], @common.SpecError] {
  match @common.require_positive("shaft diameter", diameter_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("keyway width", keyway_width_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("keyway depth", keyway_depth_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let radius = diameter_mm / 2.0
  let hw = keyway_width_mm / 2.0
  if !(hw < radius) {
    return Err(
      @common.InvalidParameter(
        "keyway width must be less than the shaft diameter",
      ),
    )
  }
  let y_top = Double::sqrt(radius * radius - hw * hw)
  let y_bottom = radius - keyway_depth_mm
  if !(y_bottom < y_top) {
    return Err(
      @common.InvalidParameter(
        "keyway depth is too small: the flat bottom is outside the shaft surface",
      ),
    )
  }
  if !(keyway_depth_mm < radius) {
    return Err(
      @common.InvalidParameter(
        "keyway depth must leave material above the shaft axis",
      ),
    )
  }
  let n = if segments < 8 { 8 } else { segments }
  let theta1 = @math.asin(hw / radius)
  let start = @math.PI / 2.0 + theta1
  let sweep = 2.0 * @math.PI - 2.0 * theta1
  let points : Array[@cad.Vec2] = []
  // Main circular arc, from the -x slot corner around the long way to +x.
  for k in 0..<=n {
    let phi = start + sweep * k.to_double() / n.to_double()
    points.push((radius * @math.cos(phi), radius * @math.sin(phi)))
  }
  // Right slot side, flat bottom, left slot side.
  points.push((hw, y_bottom))
  points.push((-hw, y_bottom))
  // The loop closes back to the first arc point at (-hw, y_top).
  Ok(points)
}

///|
/// keyed_shaft builds a cylindrical shaft with a real keyway along its length.
///
/// Axis +Z, base at z = 0, keyway centred on the +Y side. The keyway is cut into
/// the extruded section, so the STEP body is one watertight solid rather than a
/// union of a cylinder and a nominal subtraction.
pub fn keyed_shaft(
  diameter_mm : Double,
  length_mm : Double,
  keyway_width_mm : Double,
  keyway_depth_mm : Double,
  segments~ : Int32 = 64,
  color~ : @cad.Rgb = @cad.Rgb::blue(),
) -> Result[@common.Component, @common.SpecError] {
  match @common.require_positive("shaft length", length_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let used_segments = if segments < 8 { 8 } else { segments }
  let section = match
    keyed_shaft_cross_section(
      diameter_mm,
      keyway_width_mm,
      keyway_depth_mm,
      segments=used_segments,
    ) {
    Ok(p) => p
    Err(e) => return Err(e)
  }
  let name = "keyed-shaft-d\{@cad.fmt_double(diameter_mm, None)}x\{@cad.fmt_double(length_mm, None)}-kw\{@cad.fmt_double(keyway_width_mm, None)}x\{@cad.fmt_double(keyway_depth_mm, None)}"
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Keyed shaft d\{@cad.fmt_double(diameter_mm, None)} x \{@cad.fmt_double(length_mm, None)}, keyway \{@cad.fmt_double(keyway_width_mm, None)} x \{@cad.fmt_double(keyway_depth_mm, None)}",
        family="keyed shaft",
        size="d\{@cad.fmt_double(diameter_mm, None)}",
        length_mm~,
        source="Parametric shaft with a flat-bottom keyway generated from the section; verify the key size against the applicable shaft standard.",
      ),
      description="Cylindrical shaft with a real flat-bottomed rectangular keyway on +Y, running the full length. The keyway is a geometric notch in the extruded section; it is not a nominal boolean.",
      features=@common.FeatureRecord::new(
        modeled=["body", "keyway"],
        approximated=[
          @common.Approximation::new(
            feature="shaft-section-arc",
            kind=@common.ApproximationKind::PolylineArc,
            deviation_mm=@common.chord_deviation(
              diameter_mm / 2.0,
              used_segments,
            ),
            control="segments=\{used_segments}",
          ),
        ],
        omitted=[
          @common.Omission::new(
            feature="keyway-end-radius",
            reason="the keyway ends are square; an end-milled keyway has a cutter-radius bottom",
          ),
          @common.Omission::new(
            feature="shaft-chamfer",
            reason="not modelled by this builder",
          ),
        ],
      ),
    ).add_layer(
      @cad.ExtrudedProfile::new(section, length_mm),
      name="body",
      color~,
    ),
  )
}

///|
/// key_for_keyway builds a rectangular key sized to sit in a keyway of the given
/// width and depth.
///
/// Local frame: the cuboid occupies `x = 0..key_width`, `y = 0..key_height`,
/// and `z = 0..key_length`. The origin is the bottom-left-near corner, not the
/// shaft axis. To seat the key on the keyway floor at radius `R - depth`, place
/// it at `(-key_width/2, R - depth, ...)`; the `keyed_shaft` example does this.
///
/// `key_height_mm` defaults to the keyway depth, so the key fills the slot
/// without protruding above the shaft surface. Pass a larger value for a
/// standard parallel key that protrudes into the hub; the key width is
/// `keyway_width - width_clearance`.
pub fn key_for_keyway(
  keyway_width_mm : Double,
  keyway_depth_mm : Double,
  key_length_mm : Double,
  key_height_mm~ : Double = 0.0,
  width_clearance_mm~ : Double = 0.1,
  color~ : @cad.Rgb = @cad.Rgb::orange(),
) -> Result[@common.Component, @common.SpecError] {
  match @common.require_positive("keyway width", keyway_width_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("keyway depth", keyway_depth_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_positive("key length", key_length_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match
    @common.require_non_negative("key width clearance", width_clearance_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match @common.require_non_negative("key height", key_height_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let key_height = if key_height_mm > 0.0 {
    key_height_mm
  } else {
    keyway_depth_mm
  }
  match @common.require_positive("key height", key_height) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let key_width = keyway_width_mm - width_clearance_mm
  if !(key_width > 0.0) {
    return Err(
      @common.InvalidParameter("key width clearance leaves no key material"),
    )
  }
  let name = "key-\{@cad.fmt_double(key_length_mm, None)}x\{@cad.fmt_double(key_width, None)}x\{@cad.fmt_double(key_height, None)}"
  let protrusion_note = if key_height > keyway_depth_mm {
    " The key is taller than the keyway and protrudes into the hub."
  } else {
    " The key fills the keyway depth and does not protrude above the shaft surface."
  }
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Parallel key for keyway \{@cad.fmt_double(keyway_width_mm, None)} x \{@cad.fmt_double(keyway_depth_mm, None)}",
        family="key",
        source="Rectangular key sized from the keyway with a declared side clearance; not a standard key table.",
      ),
      description="Rectangular key with X = width, Y = height, Z = length, sized to the shaft keyway. Local origin is the bottom-left-near corner." +
        protrusion_note,
      features=@common.FeatureRecord::new(modeled=["body"], omitted=[
        @common.Omission::new(
          feature="edge-rounds",
          reason="not modelled by this builder",
        ),
      ]),
    ).add_layer(
      @cad.Cuboid::new(key_width, key_height, key_length_mm),
      name="body",
      color~,
    ),
  )
}
