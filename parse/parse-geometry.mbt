///|
fn parse_cartesian_point(
  args : String,
) -> @geometry.CartesianPoint raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let coord_parts = split_args(parts[1])
  let coords = coord_parts.map(parse_double)
  @geometry.CartesianPoint::new(name, coords)
}

///|
fn parse_direction(args : String) -> @geometry.Direction raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let ratio_parts = split_args(parts[1])
  let ratios = ratio_parts.map(parse_double)
  @geometry.Direction::new(name, ratios)
}

///|
fn parse_axis2_placement_3d(
  args : String,
) -> @geometry.Axis2Placement3D raise StepParseError {
  let parts = split_args(args)
  if parts.length() < 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let location_id = parse_ref_int(parts[1])
  let axis_id = parse_ref_int(parts[2])
  let ref_dir_id = parse_ref_int(parts[3])
  @geometry.Axis2Placement3D::new(
    name,
    @step.Ref::{ id: location_id, },
    @step.Ref::{ id: axis_id, },
    @step.Ref::{ id: ref_dir_id, },
  )
}

///|
fn parse_axis1_placement(
  args : String,
) -> @geometry.Axis1Placement raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let location_id = parse_ref_int(parts[1])
  let axis_id_str = parts[2].trim().to_owned()
  let axis = if axis_id_str == "$" {
    None
  } else {
    Some(@step.Ref::{ id: parse_ref_int(axis_id_str), })
  }
  @geometry.Axis1Placement::new(name, @step.Ref::{ id: location_id, }, axis~)
}

///|
fn parse_axis2_placement_2d(
  args : String,
) -> @geometry.Axis2Placement2D raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let location_id = parse_ref_int(parts[1])
  let dir_id_str = parts[2].trim().to_owned()
  let ref_direction = if dir_id_str == "$" {
    None
  } else {
    Some(@step.Ref::{ id: parse_ref_int(dir_id_str), })
  }
  @geometry.Axis2Placement2D::new(
    name,
    @step.Ref::{ id: location_id, },
    ref_direction~,
  )
}

///|
fn parse_vector(args : String) -> @geometry.Vector raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let dir_id = parse_ref_int(parts[1])
  let magnitude = parse_double(parts[2])
  @geometry.Vector::new(name, @step.Ref::{ id: dir_id, }, magnitude)
}

///|
fn parse_line(args : String) -> @geometry.Line raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let pnt_id = parse_ref_int(parts[1])
  let vec_id = parse_ref_int(parts[2])
  @geometry.Line::new(name, @step.Ref::{ id: pnt_id, }, @step.Ref::{
    id: vec_id,
  })
}

///|
fn parse_circle(args : String) -> @geometry.Circle raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let pos_id = parse_ref_int(parts[1])
  let radius_literal = parts[2].trim().to_owned()
  @geometry.Circle::new(name, @step.Ref::{ id: pos_id, }, radius_literal)
}

///|
fn parse_ellipse(args : String) -> @geometry.Ellipse raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let pos_id = parse_ref_int(parts[1])
  let semi_axis_1_literal = parts[2].trim().to_owned()
  let semi_axis_2_literal = parts[3].trim().to_owned()
  @geometry.Ellipse::new(
    name,
    @step.Ref::{ id: pos_id, },
    semi_axis_1_literal,
    semi_axis_2_literal,
  )
}

///|
fn parse_parabola(args : String) -> @geometry.Parabola raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let pos_id = parse_ref_int(parts[1])
  let focal_dist = parse_double(parts[2])
  @geometry.Parabola::new(name, @step.Ref::{ id: pos_id, }, focal_dist)
}

///|
fn parse_hyperbola(args : String) -> @geometry.Hyperbola raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let pos_id = parse_ref_int(parts[1])
  let semi = parse_double(parts[2])
  let semi_imag = parse_double(parts[3])
  @geometry.Hyperbola::new(name, @step.Ref::{ id: pos_id, }, semi, semi_imag)
}

///|
fn parse_cylindrical_surface(
  args : String,
) -> @geometry.CylindricalSurface raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let pos_id = parse_ref_int(parts[1])
  let radius_literal = parts[2].trim().to_owned()
  @geometry.CylindricalSurface::new(
    name,
    @step.Ref::{ id: pos_id, },
    radius_literal,
  )
}

///|
fn parse_conical_surface(
  args : String,
) -> @geometry.ConicalSurface raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let pos_id = parse_ref_int(parts[1])
  let radius_literal = parts[2].trim().to_owned()
  let semi_angle_literal = parts[3].trim().to_owned()
  @geometry.ConicalSurface::new(
    name,
    @step.Ref::{ id: pos_id, },
    radius_literal,
    semi_angle_literal,
  )
}

///|
fn parse_spherical_surface(
  args : String,
) -> @geometry.SphericalSurface raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let pos_id = parse_ref_int(parts[1])
  let radius_literal = parts[2].trim().to_owned()
  @geometry.SphericalSurface::new(
    name,
    @step.Ref::{ id: pos_id, },
    radius_literal,
  )
}

///|
fn parse_toroidal_surface(
  args : String,
) -> @geometry.ToroidalSurface raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let pos_id = parse_ref_int(parts[1])
  let major_radius_literal = parts[2].trim().to_owned()
  let minor_radius_literal = parts[3].trim().to_owned()
  @geometry.ToroidalSurface::new(
    name,
    @step.Ref::{ id: pos_id, },
    major_radius_literal,
    minor_radius_literal,
  )
}

///|
/// Parses a STEP BOOLEAN (`'.T.'`, `'.F.'`) or LOGICAL (`'.T.'`, `'.F.'`, `'.U.'`).
/// External AP242 exporters (e.g. SMLib) emit `.U.` ("unknown") on spline
/// `closed_*` and `self_intersect` flags, which maps to `false`.
fn parse_step_bool(raw : String) -> Bool raise StepParseError {
  let trimmed = raw.trim().to_owned()
  if trimmed == ".T." {
    true
  } else if trimmed == ".F." || trimmed == ".U." {
    false
  } else {
    fail_parse()
  }
}

///|
fn parse_b_spline_curve(
  args : String,
) -> @geometry.BSplineCurve raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 6 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let degree = parse_int_dec(parts[1])
  let cp_ids = parse_ref_ids(parts[2])
  let control_points = cp_ids.map(fn(id) { @step.Ref::{ id, } })
  let curve_form = parts[3].trim().to_owned()
  let closed_curve = parse_step_bool(parts[4])
  let self_intersect = parse_step_bool(parts[5])
  @geometry.BSplineCurve::new(
    name, degree, control_points, curve_form, closed_curve, self_intersect,
  )
}

///|
fn parse_int_list(arg : String) -> Array[Int32] {
  split_args(arg).map(parse_int_dec)
}

///|
fn parse_literal_list(arg : String) -> Array[String] {
  split_args(arg).map(parse_step_string_or_strip)
}

///|
fn parse_b_spline_curve_with_knots(
  args : String,
) -> @geometry.BSplineCurveWithKnots raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 9 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let degree = parse_int_dec(parts[1])
  let cp_ids = parse_ref_ids(parts[2])
  let control_points = cp_ids.map(fn(id) { @step.Ref::{ id, } })
  let curve_form = parts[3].trim().to_owned()
  let closed_curve = parse_step_bool(parts[4])
  let self_intersect = parse_step_bool(parts[5])
  let knot_multiplicities = parse_int_list(parts[6])
  let knots = parse_literal_list(parts[7])
  let knot_spec = parts[8].trim().to_owned()
  @geometry.BSplineCurveWithKnots::new(
    name, degree, control_points, curve_form, closed_curve, self_intersect, knot_multiplicities,
    knots, knot_spec,
  )
}

///|
fn parse_composite_curve(
  args : String,
) -> @geometry.CompositeCurve raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let seg_ids = parse_ref_ids(parts[1])
  let segments = seg_ids.map(fn(id) { @step.Ref::{ id, } })
  let self_intersect = parse_step_bool(parts[2])
  @geometry.CompositeCurve::new(name, segments, self_intersect)
}

///|
fn parse_composite_curve_segment(
  args : String,
) -> @geometry.CompositeCurveSegment raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let trans_str = parts[0].trim().to_owned()
  let transition = match @geometry.TransitionCode::from_string(trans_str) {
    Some(t) => t
    None => fail_parse()
  }
  let same_sense = parse_step_bool(parts[1])
  let curve_id = parse_ref_int(parts[2])
  @geometry.CompositeCurveSegment::new(transition, same_sense, @step.Ref::{
    id: curve_id,
  })
}

///|
fn parse_rational_b_spline_curve(
  args : String,
) -> @geometry.RationalBSplineCurve raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 1 {
    fail_parse()
  }
  let weights = parse_literal_list(parts[0])
  @geometry.RationalBSplineCurve::new(weights)
}

///|
fn parse_b_spline_surface_parts(
  parts : Array[String],
  offset : Int32,
) -> @geometry.BSplineSurface raise StepParseError {
  let u_degree = parse_int_dec(parts[offset])
  let v_degree = parse_int_dec(parts[offset + 1])
  let row_parts = split_args(parts[offset + 2])
  let control_points_list = row_parts.map(row_part => {
    parse_ref_ids(row_part).map(fn(id) { @step.Ref::{ id, } })
  })
  let surface_form = parts[offset + 3].trim().to_owned()
  let u_closed = parse_step_bool(parts[offset + 4])
  let v_closed = parse_step_bool(parts[offset + 5])
  let self_intersect = parse_step_bool(parts[offset + 6])
  @geometry.BSplineSurface::new(
    u_degree, v_degree, control_points_list, surface_form, u_closed, v_closed, self_intersect,
  )
}

///|
fn parse_b_spline_surface(
  args : String,
) -> @geometry.BSplineSurface raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 7 {
    fail_parse()
  }
  parse_b_spline_surface_parts(parts, 0)
}

///|
fn parse_b_spline_surface_with_knots_parts(
  parts : Array[String],
  offset : Int32,
) -> @geometry.BSplineSurfaceWithKnots {
  let u_mults = parse_int_list(parts[offset])
  let v_mults = parse_int_list(parts[offset + 1])
  let u_knots = parse_literal_list(parts[offset + 2])
  let v_knots = parse_literal_list(parts[offset + 3])
  let knot_spec = parts[offset + 4].trim().to_owned()
  @geometry.BSplineSurfaceWithKnots::new(
    u_mults, v_mults, u_knots, v_knots, knot_spec,
  )
}

///|
fn parse_b_spline_surface_with_knots(
  args : String,
) -> @geometry.BSplineSurfaceWithKnots raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 5 {
    fail_parse()
  }
  parse_b_spline_surface_with_knots_parts(parts, 0)
}

///|
fn parse_b_spline_surface_with_knots_entity(
  args : String,
) -> @repository.AnyEntity raise StepParseError {
  let parts = split_args(args)
  if parts.length() == 5 {
    @repository.any_entity_b_spline_surface_with_knots(
      parse_b_spline_surface_with_knots_parts(parts, 0),
    )
  } else if parts.length() == 13 {
    @repository.any_entity_complex_instance(
      @context.ComplexInstance::new([
        @context.ComplexPart::BoundedSurface,
        @context.ComplexPart::BSplineSurf(
          parse_b_spline_surface_parts(parts, 1),
        ),
        @context.ComplexPart::BSplineSurfKnots(
          parse_b_spline_surface_with_knots_parts(parts, 8),
        ),
        @context.ComplexPart::GeometricRepresentationItem,
        @context.ComplexPart::RepresentationItem(parts[0].trim().to_owned()),
        @context.ComplexPart::Surface,
      ]),
    )
  } else {
    fail_parse()
  }
}

///|
fn parse_rational_b_spline_surface(
  args : String,
) -> @geometry.RationalBSplineSurface raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 1 {
    fail_parse()
  }
  // parts[0] looks like: ((1.,...),(...),(...))
  let row_parts = split_args(parts[0])
  let weights = row_parts.map(parse_literal_list)
  @geometry.RationalBSplineSurface::new(weights)
}

///|
fn parse_trimmed_curve(
  args : String,
) -> @geometry.TrimmedCurve raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 6 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let basis_id = parse_ref_int(parts[1])
  let trim_1 = parts[2].trim().to_owned()
  let trim_2 = parts[3].trim().to_owned()
  let sense = parse_step_bool(parts[4])
  let master_rep = parts[5].trim().to_owned()
  @geometry.TrimmedCurve::new(
    name,
    @step.Ref::{ id: basis_id, },
    trim_1,
    trim_2,
    sense,
    master_rep,
  )
}

///|
fn parse_offset_curve_3d(
  args : String,
) -> @geometry.OffsetCurve3D raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let basis_id = parse_ref_int(parts[1])
  let distance = parse_double(parts[2])
  let dir_id = parse_ref_int(parts[3])
  @geometry.OffsetCurve3D::new(name, @step.Ref::{ id: basis_id, }, distance, @step.Ref::{
    id: dir_id,
  })
}

///|
fn parse_offset_surface(
  args : String,
) -> @geometry.OffsetSurface raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let basis_id = parse_ref_int(parts[1])
  let distance = parse_double(parts[2])
  let self_intersect = parse_step_bool(parts[3])
  @geometry.OffsetSurface::new(
    name,
    @step.Ref::{ id: basis_id, },
    distance,
    self_intersect,
  )
}

///|
fn parse_surface_of_linear_extrusion(
  args : String,
) -> @geometry.SurfaceOfLinearExtrusion raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let curve_id = parse_ref_int(parts[1])
  let axis_id = parse_ref_int(parts[2])
  @geometry.SurfaceOfLinearExtrusion::new(name, @step.Ref::{ id: curve_id, }, @step.Ref::{
    id: axis_id,
  })
}

///|
fn parse_surface_of_revolution(
  args : String,
) -> @geometry.SurfaceOfRevolution raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let curve_id = parse_ref_int(parts[1])
  let axis_id = parse_ref_int(parts[2])
  @geometry.SurfaceOfRevolution::new(name, @step.Ref::{ id: curve_id, }, @step.Ref::{
    id: axis_id,
  })
}

///|
fn parse_swept_surface(
  args : String,
) -> @geometry.SweptSurface raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let curve_id = parse_ref_int(parts[1])
  @geometry.SweptSurface::new(name, @step.Ref::{ id: curve_id, })
}

///|
fn parse_rectangular_trimmed_surface(
  args : String,
) -> @geometry.RectangularTrimmedSurface raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 8 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let basis_id = parse_ref_int(parts[1])
  let u1 = parts[2].trim().to_owned()
  let u2 = parts[3].trim().to_owned()
  let v1 = parts[4].trim().to_owned()
  let v2 = parts[5].trim().to_owned()
  let usense = parse_step_bool(parts[6])
  let vsense = parse_step_bool(parts[7])
  @geometry.RectangularTrimmedSurface::new(
    name,
    @step.Ref::{ id: basis_id, },
    u1,
    u2,
    v1,
    v2,
    usense,
    vsense,
  )
}

///|
fn parse_polyline(args : String) -> @geometry.Polyline raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let ids = parse_ref_ids(parts[1])
  let points = ids.map(fn(id) { @step.Ref::{ id, } })
  @geometry.Polyline::new(name, points)
}
