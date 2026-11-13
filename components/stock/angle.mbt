///|
/// AngleSection describes an equal or unequal steel angle section.
///
/// The section has two legs along +X and +Y, a concave root radius at the
/// inner corner, and a toe radius at each leg tip. The toe rounding leaves a
/// short flat at the end of each leg.
///
/// Dimensions are millimetres. `angle_bar` extrudes the section along +Z with
/// the outer corner at `(0, 0, 0)`.
pub(all) struct AngleSection {
  leg_a_mm : Double
  leg_b_mm : Double
  thickness_mm : Double
  root_radius_mm : Double
  toe_radius_mm : Double
}

///|
/// angle_section validates an angle section.
pub fn angle_section(
  leg_a_mm~ : Double,
  leg_b_mm~ : Double,
  thickness_mm~ : Double,
  root_radius_mm~ : Double,
  toe_radius_mm~ : Double,
) -> Result[AngleSection, @common.SpecError] {
  let checks : Array[Result[Unit, @common.SpecError]] = [
    @common.require_positive("angle leg A", leg_a_mm),
    @common.require_positive("angle leg B", leg_b_mm),
    @common.require_positive("angle thickness", thickness_mm),
    @common.require_non_negative("angle root radius", root_radius_mm),
    @common.require_non_negative("angle toe radius", toe_radius_mm),
  ]
  for check in checks {
    match check {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }
  if thickness_mm >= leg_a_mm || thickness_mm >= leg_b_mm {
    return Err(
      @common.InvalidDimension("angle thickness must be smaller than both legs"),
    )
  }
  if toe_radius_mm >= thickness_mm {
    return Err(
      @common.InvalidDimension(
        "angle toe radius must be smaller than the thickness so a toe flat remains",
      ),
    )
  }
  let root_center = thickness_mm + root_radius_mm
  if root_center >= leg_a_mm || root_center >= leg_b_mm {
    return Err(
      @common.InvalidDimension(
        "angle root radius does not fit between the inner corner and the leg tips",
      ),
    )
  }
  if root_center >= leg_a_mm - toe_radius_mm ||
    root_center >= leg_b_mm - toe_radius_mm {
    return Err(
      @common.InvalidDimension(
        "angle root radius and toe radius overlap along a leg",
      ),
    )
  }
  Ok({ leg_a_mm, leg_b_mm, thickness_mm, root_radius_mm, toe_radius_mm, })
}

///|
/// en10056_equal_angle_40x40x4 returns the EN 10056 40 x 40 x 4 equal angle.
///
/// EN 10056-1 gives a 6 mm root radius and a 3 mm toe radius for this size;
/// the step.parts reference uses the same values.
pub fn en10056_equal_angle_40x40x4() -> AngleSection {
  {
    leg_a_mm: 40.0,
    leg_b_mm: 40.0,
    thickness_mm: 4.0,
    root_radius_mm: 6.0,
    toe_radius_mm: 3.0,
  }
}

///|
/// angle_profile returns the line-and-arc outer loop of an angle section.
///
/// The loop starts at the outer corner and runs counter-clockwise. The concave
/// root fillet is sampled as short lines because the arc profile only accepts
/// counter-clockwise minor arcs; the convex toe radii stay analytic arcs.
fn angle_profile(section : AngleSection) -> Array[@cad.ProfileSegment] {
  let a = section.leg_a_mm
  let b = section.leg_b_mm
  let t = section.thickness_mm
  let r_root = section.root_radius_mm
  let r_toe = section.toe_radius_mm
  let toe_flat = t - r_toe
  let root_center = t + r_root
  let segments : Array[@cad.ProfileSegment] = [
    @cad.SegmentLine((0.0, 0.0), (a, 0.0)),
  ]
  if r_toe > 0.0 {
    segments.push(@cad.SegmentLine((a, 0.0), (a, toe_flat)))
    segments.push(
      @cad.SegmentArc((a, toe_flat), (a - r_toe, t), (a - r_toe, toe_flat)),
    )
  } else {
    segments.push(@cad.SegmentLine((a, 0.0), (a, t)))
  }
  segments.push(@cad.SegmentLine((a - r_toe, t), (root_center, t)))
  if r_root > 0.0 {
    // Concave fillet, traversed clockwise on a counter-clockwise boundary.
    // Sample it from -90 degrees to -180 degrees about the fillet centre.
    let steps = 16
    let mut previous = (root_center, t)
    for i in 1..<=steps {
      let angle = -@math.PI / 2.0 -
        @math.PI / 2.0 * Double::from_int(i) / Double::from_int(steps)
      let point = (
        root_center + r_root * @math.cos(angle),
        root_center + r_root * @math.sin(angle),
      )
      segments.push(@cad.SegmentLine(previous, point))
      previous = point
    }
  } else {
    segments.push(@cad.SegmentLine((root_center, t), (t, root_center)))
  }
  segments.push(@cad.SegmentLine((t, root_center), (t, b - r_toe)))
  if r_toe > 0.0 {
    segments.push(
      @cad.SegmentArc((t, b - r_toe), (toe_flat, b), (toe_flat, b - r_toe)),
    )
    segments.push(@cad.SegmentLine((toe_flat, b), (0.0, b)))
  } else {
    segments.push(@cad.SegmentLine((t, b), (0.0, b)))
  }
  segments.push(@cad.SegmentLine((0.0, b), (0.0, 0.0)))
  segments
}

///|
/// angle_bar builds an equal or unequal angle section of the requested length.
///
/// Geometry: outer corner at `(0, 0, 0)`, legs along +X and +Y, extrusion along
/// +Z. The root fillet and both toe radii are true cylindrical surfaces.
pub fn angle_bar(
  section : AngleSection,
  length_mm : Double,
  color~ : @cad.Rgb = @cad.Rgb::grey(),
) -> Result[@common.Component, @common.SpecError] {
  match @common.require_positive("angle bar length", length_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let profile = angle_profile(section)
  let body = @cad.ExtrudedArcProfile::new(profile, length_mm)
  if !body.validate() {
    return Err(
      @common.InvalidParameter(
        "angle section did not produce a valid closed profile",
      ),
    )
  }
  let approximations : Array[@common.Approximation] = []
  if section.root_radius_mm > 0.0 {
    approximations.push(
      @common.Approximation::new(
        feature="root-fillet",
        kind=@common.ApproximationKind::PolylineArc,
        deviation_mm=@common.chord_deviation(section.root_radius_mm, 64),
        control="root_fillet_segments=16 over 90 degrees",
      ),
    )
  }
  let features = @common.FeatureRecord::new(
    modeled=["body", "leg-a", "leg-b", "toe-radii"],
    approximated=approximations,
    omitted=[
      @common.Omission::new(
        feature="mill-scale-and-tolerances",
        reason="the section is nominal; rolling tolerances are not modelled",
      ),
      @common.Omission::new(
        feature="end-cuts-and-holes",
        reason="no end machining or hole pattern is asserted",
      ),
    ],
  )
  let (suffix, standard) = if section.leg_a_mm == section.leg_b_mm &&
    section.thickness_mm > 0.0 {
    ("equal", "EN 10056-1 equal angle section proportions")
  } else {
    ("unequal", "angle-section geometry; no standard table is implied")
  }
  let name = "angle-\{suffix}-\{@cad.fmt_double(section.leg_a_mm, None)}x\{@cad.fmt_double(section.leg_b_mm, None)}x\{@cad.fmt_double(section.thickness_mm, None)}-L\{@cad.fmt_double(length_mm, None)}"
  Ok(
    @common.Component::new(
      name~,
      metadata=@common.Metadata::new(
        designation="\{suffix} angle \{@cad.fmt_double(section.leg_a_mm, None)} x \{@cad.fmt_double(section.leg_b_mm, None)} x \{@cad.fmt_double(section.thickness_mm, None)}, L=\{@cad.fmt_double(length_mm, None)}",
        standard~,
        family="steel angle section",
        size="\{@cad.fmt_double(section.leg_a_mm, None)}x\{@cad.fmt_double(section.leg_b_mm, None)}x\{@cad.fmt_double(section.thickness_mm, None)}",
        length_mm~,
        material="steel (label only; not a structural claim)",
        source="Angle-section geometry with a root fillet and toe radii. The 40 x 40 x 4 EN 10056 preset uses root radius 6 mm and toe radius 3 mm, confirmed against the step.parts reference.",
      ),
      description="Steel angle section with legs along +X and +Y, a concave root fillet, and rounded toe flats. End cuts, holes, and rolling tolerances are not modelled.",
      features~,
    ).add_layer(body.as_shape(), name="body", color~),
  )
}
