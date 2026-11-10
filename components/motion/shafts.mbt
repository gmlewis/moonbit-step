///|
/// shaft builds a plain cylindrical shaft.
///
/// Axis +Z, base at z = 0.
pub fn shaft(
  diameter_mm : Double,
  length_mm : Double,
  color~ : @cad.Rgb = @cad.Rgb::blue(),
) -> Result[@common.Component, @common.SpecError] {
  match @common.require_positive("shaft diameter", diameter_mm) {
    Err(e) => Err(e)
    Ok(_) =>
      match @common.require_positive("shaft length", length_mm) {
        Err(e) => Err(e)
        Ok(_) => {
          let name = "shaft-d\{@cad.fmt_double(diameter_mm, None)}x\{@cad.fmt_double(length_mm, None)}"
          Ok(
            @common.Component::new(
              name~,
              metadata=@common.Metadata::new(
                designation="Shaft \{@cad.fmt_double(diameter_mm, None)} x \{@cad.fmt_double(length_mm, None)}",
                standard="",
                family="shaft",
                size="d\{@cad.fmt_double(diameter_mm, None)}",
                length_mm~,
                source="Parametric cylinder; no standard table is implied.",
              ),
              description="Plain cylindrical shaft with no keyway, shoulder, or chamfer.",
            ).add_layer(
              @cad.Cylinder::new(diameter_mm, length_mm),
              name="body",
              color~,
            ),
          )
        }
      }
  }
}

///|
/// ShaftSegment is one diameter/length step of a stepped shaft.
pub(all) struct ShaftSegment {
  diameter_mm : Double
  length_mm : Double
}

///|
/// ShaftSegment::new builds a validated segment specification.
pub fn ShaftSegment::new(
  diameter_mm : Double,
  length_mm : Double,
) -> Result[ShaftSegment, @common.SpecError] {
  match @common.require_positive("segment diameter", diameter_mm) {
    Err(e) => Err(e)
    Ok(_) =>
      match @common.require_positive("segment length", length_mm) {
        Err(e) => Err(e)
        Ok(_) => Ok({ diameter_mm, length_mm, })
      }
  }
}

///|
/// stepped_shaft builds a shaft from coaxial cylindrical segments stacked along
/// +Z.
///
/// Each segment is a separate closed cylinder body. Steps are sharp shoulders;
/// chamfers and fillets are not modeled.
pub fn stepped_shaft(
  segments : Array[ShaftSegment],
  color~ : @cad.Rgb = @cad.Rgb::blue(),
) -> Result[@common.Component, @common.SpecError] {
  if segments.is_empty() {
    return Err(
      @common.InvalidParameter("stepped shaft needs at least one segment"),
    )
  }
  let name = "stepped-shaft-\{segments.length()}-steps"
  let mut component = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Stepped shaft (\{segments.length()} steps)",
      family="stepped shaft",
      source="Parametric stack of cylinders; no standard table is implied.",
    ),
    description="Coaxial cylindrical segments with sharp shoulders. Keyways and chamfers are not modeled.",
  )
  let mut z = 0.0
  for i, segment in segments {
    component = component.add_layer(
      @cad.Cylinder::new(segment.diameter_mm, segment.length_mm),
      name="step-\{i + 1}",
      color~,
      placement=@common.Placement::translation(0.0, 0.0, z),
    )
    z = z + segment.length_mm
  }
  Ok(component)
}

///|
/// spacer builds a cylindrical spacer (a plain tube).
pub fn spacer(
  outer_diameter_mm : Double,
  inner_diameter_mm : Double,
  length_mm : Double,
  color~ : @cad.Rgb = @cad.Rgb::green(),
) -> Result[@common.Component, @common.SpecError] {
  match @common.require_positive("spacer outer diameter", outer_diameter_mm) {
    Err(e) => Err(e)
    Ok(_) =>
      match @common.require_positive("spacer length", length_mm) {
        Err(e) => Err(e)
        Ok(_) =>
          if inner_diameter_mm <= 0.0 || inner_diameter_mm >= outer_diameter_mm {
            Err(
              @common.InvalidDimension(
                "spacer inner diameter must be > 0 and smaller than the outer diameter",
              ),
            )
          } else {
            let body = @cad.tube(
              outer_diameter_mm, inner_diameter_mm, length_mm,
            )
            let name = "spacer-\{@cad.fmt_double(outer_diameter_mm, None)}x\{@cad.fmt_double(inner_diameter_mm, None)}x\{@cad.fmt_double(length_mm, None)}"
            Ok(
              @common.Component::new(
                name~,
                metadata=@common.Metadata::new(
                  designation="Spacer OD \{@cad.fmt_double(outer_diameter_mm, None)} / ID \{@cad.fmt_double(inner_diameter_mm, None)} x \{@cad.fmt_double(length_mm, None)}",
                  family="spacer",
                  length_mm~,
                  source="Parametric tube; no standard table is implied.",
                ),
                description="Plain cylindrical spacer with a through bore.",
              ).add_layer(body, name="body", color~),
            )
          }
      }
  }
}

///|
/// bushing builds a plain cylindrical bushing; it is a spacer with a bore by
/// another name.
pub fn bushing(
  outer_diameter_mm : Double,
  inner_diameter_mm : Double,
  length_mm : Double,
) -> Result[@common.Component, @common.SpecError] {
  spacer(outer_diameter_mm, inner_diameter_mm, length_mm)
}

///|
/// key builds a rectangular machine key.
pub fn key(
  length_mm : Double,
  width_mm : Double,
  height_mm : Double,
  color~ : @cad.Rgb = @cad.Rgb::orange(),
) -> Result[@common.Component, @common.SpecError] {
  match @common.require_positive("key length", length_mm) {
    Err(e) => Err(e)
    Ok(_) =>
      match @common.require_positive("key width", width_mm) {
        Err(e) => Err(e)
        Ok(_) =>
          match @common.require_positive("key height", height_mm) {
            Err(e) => Err(e)
            Ok(_) => {
              let name = "key-\{@cad.fmt_double(length_mm, None)}x\{@cad.fmt_double(width_mm, None)}x\{@cad.fmt_double(height_mm, None)}"
              Ok(
                @common.Component::new(
                  name~,
                  metadata=@common.Metadata::new(
                    designation="Machine key",
                    family="key",
                    length_mm~,
                    source="Plain rectangular key; verify the key size against the applicable shaft standard.",
                  ),
                  description="Rectangular machine key, sharp edges.",
                ).add_layer(
                  @cad.Cuboid::new(length_mm, width_mm, height_mm),
                  name="body",
                  color~,
                ),
              )
            }
          }
      }
  }
}

///|
/// filleted_stepped_shaft builds a stepped shaft whose increasing-diameter
/// shoulders carry a real circular fillet.
///
/// `segments` are `(diameter_mm, length_mm)` pairs from the base up. Each
/// increasing shoulder is rounded with a toroidal fillet of `fillet_radius_mm`
/// (a true `TOROIDAL_SURFACE` after revolution); decreasing shoulders and
/// shoulders where the fillet does not fit stay sharp. Axis +Z, base at z = 0.
pub fn filleted_stepped_shaft(
  segments : Array[(Double, Double)],
  fillet_radius_mm~ : Double = 0.0,
  color~ : @cad.Rgb = @cad.Rgb::blue(),
) -> Result[@common.Component, @common.SpecError] {
  if segments.is_empty() {
    return Err(@common.InvalidParameter("shaft needs at least one segment"))
  }
  match @common.require_non_negative("fillet radius", fillet_radius_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let n = segments.length()
  let radii : Array[Double] = []
  let zs : Array[Double] = [0.0]
  for seg in segments {
    let (dia, len) = seg
    match @common.require_positive("shaft segment diameter", dia) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    match @common.require_positive("shaft segment length", len) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    radii.push(dia / 2.0)
    zs.push(zs[zs.length() - 1] + len)
  }
  let f = fillet_radius_mm
  let segs : Array[@cad.RevSegment] = [
    @cad.RevLine((0.0, 0.0), (radii[0], 0.0)),
  ]
  let mut cur_r = radii[0]
  let mut cur_z = 0.0
  for i in 0..<n {
    let top = zs[i + 1]
    if i > 0 && radii[i] > cur_r + 1.0e-9 {
      let r_i = radii[i]
      if f > 0.0 && top - cur_z > f && r_i - f >= cur_r {
        let rf = r_i - f
        segs.push(@cad.RevLine((cur_r, cur_z), (rf, cur_z)))
        segs.push(@cad.RevArc((rf, cur_z), (r_i, cur_z + f), (rf, cur_z + f)))
        cur_z = cur_z + f
      } else {
        segs.push(@cad.RevLine((cur_r, cur_z), (r_i, cur_z)))
      }
      cur_r = r_i
    } else if i > 0 {
      segs.push(@cad.RevLine((cur_r, cur_z), (radii[i], cur_z)))
      cur_r = radii[i]
    }
    segs.push(@cad.RevLine((cur_r, cur_z), (cur_r, top)))
    cur_z = top
  }
  segs.push(@cad.RevLine((cur_r, cur_z), (0.0, cur_z)))
  let profile = @cad.RevolvedProfile::new(segs)
  match profile.validate() {
    Err(e) => return Err(@common.InvalidDimension(e.message()))
    Ok(_) => ()
  }
  let name = "filleted-shaft-\{n}-step"
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="Filleted stepped shaft",
        standard="",
        family="stepped shaft",
        size="\{n} steps",
        source="Parametric solid of revolution with circular shoulder fillets; no standard table is implied.",
      ),
      description="Stepped shaft with toroidal shoulder fillets on increasing steps. Decreasing steps and steps too short for the fillet stay sharp.",
    ).add_layer(profile.as_shape(), name="body", color~),
  )
}
