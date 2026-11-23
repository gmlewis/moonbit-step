///|
fn parse_ref_ids(arg : String) -> Array[@step.EntityId] raise StepParseError {
  split_args(arg).map(parse_ref_int)
}

///|
fn parse_surface_side(s : String) -> String raise StepParseError {
  let t = s.trim().to_owned()
  if t == ".BOTH." {
    t
  } else if t == ".POSITIVE." {
    t
  } else if t == ".NEGATIVE." {
    t
  } else {
    fail_parse()
  }
}

///|
fn parse_fill_area_style_color(
  args : String,
) -> @presentation.FillAreaStyleColor raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let color_id = parse_ref_int(parts[1])
  @presentation.FillAreaStyleColor::new(name, @step.Ref::{ id: color_id, })
}

///|
fn parse_fill_area_style(
  args : String,
) -> @presentation.FillAreaStyle raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let style_ids = parse_ref_ids(parts[1])
  let styles = style_ids.map(fn(id) { @step.Ref::{ id, } })
  @presentation.FillAreaStyle::new(name, styles)
}

///|
fn parse_surface_style_fill_area(
  args : String,
) -> @presentation.SurfaceStyleFillArea raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 1 {
    fail_parse()
  }
  let fa_id = parse_ref_int(parts[0])
  @presentation.SurfaceStyleFillArea::new(@step.Ref::{ id: fa_id, })
}

///|
fn parse_surface_side_style(
  args : String,
) -> @presentation.SurfaceSideStyle raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let style_ids = parse_ref_ids(parts[1])
  let styles = style_ids.map(fn(id) { @step.Ref::{ id, } })
  @presentation.SurfaceSideStyle::new(name, styles)
}

///|
fn parse_surface_style_usage(
  args : String,
) -> @presentation.SurfaceStyleUsage raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let side = parse_surface_side(parts[0])
  let style_id = parse_ref_int(parts[1])
  @presentation.SurfaceStyleUsage::new(side, @step.Ref::{ id: style_id, })
}

///|
fn parse_presentation_style_assignment(
  args : String,
) -> @presentation.PresentationStyleAssignment raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 1 {
    fail_parse()
  }
  let style_ids = parse_ref_ids(parts[0])
  let styles = style_ids.map(fn(id) { @step.Ref::{ id, } })
  @presentation.PresentationStyleAssignment::new(styles)
}

///|
fn parse_presentation_layer_assignment(
  args : String,
) -> @presentation.PresentationLayerAssignment raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let description = strip_quotes(parts[1])
  let item_ids = parse_ref_ids(parts[2])
  let items = item_ids.map(fn(id) { @step.Ref::{ id, } })
  @presentation.PresentationLayerAssignment::new(name, description, items)
}

///|
fn parse_text_literal(
  args : String,
) -> @presentation.TextLiteral raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 6 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let literal = strip_quotes(parts[1])
  let placement_id = parse_ref_int(parts[2])
  let alignment = strip_quotes(parts[3])
  let path_str = parts[4].trim().to_owned()
  let path = match @presentation.TextPath::from_string(path_str) {
    Some(p) => p
    None => fail_parse()
  }
  let font_id = parse_ref_int(parts[5])
  @presentation.TextLiteral::new(
    name,
    literal,
    @step.Ref::{ id: placement_id, },
    alignment,
    path,
    @step.Ref::{ id: font_id, },
  )
}

///|
fn parse_mechanical_design_geometric_presentation_representation(
  args : String,
) -> @presentation.MechanicalDesignGeometricPresentationRepresentation raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let item_ids = parse_ref_ids(parts[1])
  let items = item_ids.map(fn(id) { @step.Ref::{ id, } })
  let ctx_id = parse_ref_int(parts[2])
  @presentation.MechanicalDesignGeometricPresentationRepresentation::new(
    name,
    items,
    @step.Ref::{ id: ctx_id, },
  )
}

///|
fn parse_styled_item(
  args : String,
) -> @presentation.StyledItem raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let style_ids = parse_ref_ids(parts[1])
  let styles = style_ids.map(fn(id) { @step.Ref::{ id, } })
  let item_id = parse_ref_int(parts[2])
  @presentation.StyledItem::new(name, styles, @step.Ref::{ id: item_id, })
}

///|
fn parse_over_riding_styled_item(
  args : String,
) -> @presentation.OverRidingStyledItem raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let style_ids = parse_ref_ids(parts[1])
  let styles = style_ids.map(fn(id) { @step.Ref::{ id, } })
  let item_id = parse_ref_int(parts[2])
  let over_id = parse_ref_int(parts[3])
  @presentation.OverRidingStyledItem::new(
    name,
    styles,
    @step.Ref::{ id: item_id, },
    @step.Ref::{ id: over_id, },
  )
}

///|
fn parse_hidden_element_over_riding_styled_item(
  args : String,
) -> @presentation.HiddenElementOverRidingStyledItem raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let style_ids = parse_ref_ids(parts[1])
  let styles = style_ids.map(fn(id) { @step.Ref::{ id, } })
  let item_id = parse_ref_int(parts[2])
  let over_id = parse_ref_int(parts[3])
  @presentation.HiddenElementOverRidingStyledItem::new(
    name,
    styles,
    @step.Ref::{ id: item_id, },
    @step.Ref::{ id: over_id, },
  )
}

///|
fn parse_annotation_occurrence(
  args : String,
) -> @presentation.AnnotationOccurrence raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let style_ids = parse_ref_ids(parts[1])
  let styles = style_ids.map(fn(id) { @step.Ref::{ id, } })
  let item_id = parse_ref_int(parts[2])
  @presentation.AnnotationOccurrence::new(name, styles, @step.Ref::{
    id: item_id,
  })
}

///|
fn parse_dimensional_exponents(
  args : String,
) -> @units.DimensionalExponents raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 7 {
    fail_parse()
  }
  @units.DimensionalExponents::new(
    parse_double(parts[0]),
    parse_double(parts[1]),
    parse_double(parts[2]),
    parse_double(parts[3]),
    parse_double(parts[4]),
    parse_double(parts[5]),
    parse_double(parts[6]),
  )
}

///|
fn parse_length_measure_literal(arg : String) -> String raise StepParseError {
  let t = arg.trim().to_owned()
  if !t.has_prefix("LENGTH_MEASURE(") {
    fail_parse()
  }
  if t.length() < 16 || !t.has_suffix(")") {
    fail_parse()
  }
  // Inner literal (preserve scientific notation like `2.E-005`).
  // "LENGTH_MEASURE(" is 15 chars; the opening paren is index 14.
  substr(t, 15, t.length() - 1).trim().to_owned()
}

///|
fn parse_uncertainty_measure_with_unit(
  args : String,
) -> @units.UncertaintyMeasureWithUnit raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let length_measure_literal = parse_length_measure_literal(parts[0])
  let unit_id = parse_ref_int(parts[1])
  let name = strip_quotes(parts[2])
  let description = strip_quotes(parts[3])
  @units.UncertaintyMeasureWithUnit::new(
    length_measure_literal,
    @step.Ref::{ id: unit_id, },
    name,
    description,
  )
}

///|
fn parse_plane_angle_measure_literal(
  arg : String,
) -> String raise StepParseError {
  let t = arg.trim().to_owned()
  if !t.has_prefix("PLANE_ANGLE_MEASURE(") {
    fail_parse()
  }
  if t.length() < 22 || !t.has_suffix(")") {
    fail_parse()
  }
  // Inner literal (preserve formatting).
  // "PLANE_ANGLE_MEASURE(" is 20 chars.
  substr(t, 20, t.length() - 1).trim().to_owned()
}

///|
fn parse_plane_angle_measure_with_unit(
  args : String,
) -> @units.PlaneAngleMeasureWithUnit raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let plane_angle_measure_literal = parse_plane_angle_measure_literal(parts[0])
  let unit_id = parse_ref_int(parts[1])
  @units.PlaneAngleMeasureWithUnit::new(plane_angle_measure_literal, @step.Ref::{
    id: unit_id,
  })
}

///|
fn parse_derived_unit_element(
  args : String,
) -> @units.DerivedUnitElement raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let unit_id = parse_ref_int(parts[0])
  let exponent = parse_double(parts[1])
  @units.DerivedUnitElement::new(@step.Ref::{ id: unit_id, }, exponent)
}

///|
fn parse_derived_unit(args : String) -> @units.DerivedUnit raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 1 {
    fail_parse()
  }
  let elem_ids = parse_ref_ids(parts[0])
  let elems = elem_ids.map(fn(id) { @step.Ref::{ id, } })
  @units.DerivedUnit::new(elems)
}

///|
fn parse_measure_with_unit(
  args : String,
) -> @units.MeasureWithUnit raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let val = parts[0].trim().to_owned()
  let unit_id = parse_ref_int(parts[1])
  @units.MeasureWithUnit::new(val, @step.Ref::{ id: unit_id, })
}

///|
fn is_complex_ws(ci : Int32) -> Bool {
  ci == Char::to_int(' ') ||
  ci == Char::to_int('\t') ||
  ci == Char::to_int('\n') ||
  ci == Char::to_int('\r')
}

///|
fn is_complex_name_char(ci : Int32) -> Bool {
  (ci >= Char::to_int('A') && ci <= Char::to_int('Z')) ||
  (ci >= Char::to_int('0') && ci <= Char::to_int('9')) ||
  ci == Char::to_int('_')
}

///|
fn split_complex_parts(body : String) -> Array[String] {
  // A complex instance is a whitespace-separated sequence of
  // `NAME(<args>)` parts. Parts may be separated by spaces, newlines, or both;
  // some writers put several parts on one line, so splitting on newlines alone
  // is not sufficient. Scan each `NAME` and its balanced parenthesised args.
  let out : Array[String] = []
  let n = body.length()
  let quote = Char::to_int('\'')
  let lparen = Char::to_int('(')
  let rparen = Char::to_int(')')
  let mut i = 0
  while i < n {
    while i < n && is_complex_ws(cu_at(body, i)) {
      i = i + 1
    }
    if i >= n {
      break
    }
    let start = i
    while i < n && is_complex_name_char(cu_at(body, i)) {
      i = i + 1
    }
    while i < n && is_complex_ws(cu_at(body, i)) {
      i = i + 1
    }
    if i >= n || cu_at(body, i) != lparen {
      let rest = substr(body, start, n).trim().to_owned()
      if rest.length() > 0 {
        out.push(rest)
      }
      break
    }
    let mut depth = 0
    let mut in_str = false
    let mut skip_quote = false
    let mut j = i
    let mut closed = -1
    while j < n {
      let cj = cu_at(body, j)
      if cj == quote {
        if skip_quote {
          skip_quote = false
        } else if in_str {
          if j + 1 < n && cu_at(body, j + 1) == quote {
            skip_quote = true
          } else {
            in_str = false
          }
        } else {
          in_str = true
        }
      } else if !in_str {
        if cj == lparen {
          depth = depth + 1
        } else if cj == rparen {
          depth = depth - 1
          if depth == 0 {
            closed = j
            break
          }
        }
      }
      j = j + 1
    }
    if closed < 0 {
      let rest = substr(body, start, n).trim().to_owned()
      if rest.length() > 0 {
        out.push(rest)
      }
      break
    }
    let part = substr(body, start, closed + 1).trim().to_owned()
    if part.length() > 0 {
      out.push(part)
    }
    i = closed + 1
  }
  out
}

///|
fn strip_outer_parens(arg : String) -> String raise StepParseError {
  let t = arg.trim().to_owned()
  if t.length() < 2 ||
    cu_at(t, 0) != Char::to_int('(') ||
    cu_at(t, t.length() - 1) != Char::to_int(')') {
    fail_parse()
  }
  substr(t, 1, t.length() - 1)
}

///|
fn expect_empty_parens(arg : String) -> Unit raise StepParseError {
  let inner = strip_outer_parens(arg).trim().to_owned()
  if inner.length() != 0 {
    fail_parse()
  }
}

///|
fn parse_complex_instance(
  args : String,
) -> @context.ComplexInstance raise StepParseError {
  // args is the raw parenthesized complex instance body, like:
  //   (\nNAME(...)\nNAME(...)\n)
  let t = args.trim().to_owned()
  if t.length() < 2 ||
    cu_at(t, 0) != Char::to_int('(') ||
    cu_at(t, t.length() - 1) != Char::to_int(')') {
    fail_parse()
  }
  let inner = substr(t, 1, t.length() - 1)
  let part_strs = split_complex_parts(inner)
  let parts = part_strs.map(fn(s) raise StepParseError {
    let lp_idx = match String::find(s, "(") {
      Some(j) => j
      None => fail_parse()
    }
    let name = substr(s, 0, lp_idx).trim().to_owned()
    let a = substr(s, lp_idx, s.length()).trim().to_owned()
    if name == "GEOMETRIC_REPRESENTATION_CONTEXT" {
      let inner_args = strip_outer_parens(a)
      let dim = parse_int_dec(inner_args.trim().to_owned())
      @context.ComplexPart::GeomRepCtx(
        @context.GeometricRepresentationContext::new(dim),
      )
    } else if name == "REPRESENTATION_CONTEXT" {
      let inner_args = strip_outer_parens(a)
      let args_parts = split_args(inner_args)
      if args_parts.length() != 2 {
        fail_parse()
      }
      let ident = strip_quotes(args_parts[0])
      let ctx_type = strip_quotes(args_parts[1])
      @context.ComplexPart::RepCtx(
        @context.RepresentationContext::new(ident, ctx_type),
      )
    } else if name == "NAMED_UNIT" {
      let inner_args = strip_outer_parens(a).trim().to_owned()
      @context.ComplexPart::NamedUnit(@units.NamedUnit::new(inner_args))
    } else if name == "SI_UNIT" {
      let inner_args = strip_outer_parens(a)
      let args_parts = split_args(inner_args)
      if args_parts.length() != 2 {
        fail_parse()
      }
      let prefix = args_parts[0].trim().to_owned()
      let si_name = args_parts[1].trim().to_owned()
      @context.ComplexPart::SiUnit(@units.SiUnit::new(prefix, si_name))
    } else if name == "SOLID_ANGLE_UNIT" {
      expect_empty_parens(a)
      @context.ComplexPart::SolidAngleUnit(@units.SolidAngleUnit::new())
    } else if name == "CONVERSION_BASED_UNIT" {
      let inner_args = strip_outer_parens(a)
      let args_parts = split_args(inner_args)
      if args_parts.length() != 2 {
        fail_parse()
      }
      let unit_name = strip_quotes(args_parts[0])
      let factor_id = parse_ref_int(args_parts[1])
      @context.ComplexPart::ConversionBasedUnit(
        @units.ConversionBasedUnit::new(unit_name, @step.Ref::{ id: factor_id, }),
      )
    } else if name == "LENGTH_UNIT" {
      expect_empty_parens(a)
      @context.ComplexPart::LengthUnit(@units.LengthUnit::new())
    } else if name == "MASS_UNIT" {
      expect_empty_parens(a)
      @context.ComplexPart::MassUnit(@units.MassUnit::new())
    } else if name == "PLANE_ANGLE_UNIT" {
      expect_empty_parens(a)
      @context.ComplexPart::PlaneAngleUnit(@units.PlaneAngleUnit::new())
    } else if name == "GLOBAL_UNCERTAINTY_ASSIGNED_CONTEXT" {
      // args look like: ((#188))
      let inner_args = strip_outer_parens(a) // -> (#188)
      let ids = parse_ref_ids(inner_args)
      @context.ComplexPart::GlobUncCtx(
        @context.GlobalUncertaintyAssignedContext::new(ids),
      )
    } else if name == "GLOBAL_UNIT_ASSIGNED_CONTEXT" {
      // args look like: ((#194,#190,#189))
      let inner_args = strip_outer_parens(a) // -> (#194,#190,#189)
      let ids = parse_ref_ids(inner_args)
      @context.ComplexPart::GlobUnitCtx(
        @context.GlobalUnitAssignedContext::new(ids),
      )
    } else if name == "REPRESENTATION_RELATIONSHIP" {
      let inner_args = strip_outer_parens(a)
      let args_parts = split_args(inner_args)
      if args_parts.length() != 4 {
        fail_parse()
      }
      let rr_name = strip_quotes(args_parts[0])
      let rr_desc = strip_quotes(args_parts[1])
      let rep_1_id = parse_ref_int(args_parts[2])
      let rep_2_id = parse_ref_int(args_parts[3])
      @context.ComplexPart::RepRel(
        @product.RepresentationRelationship::new(
          rr_name,
          rr_desc,
          @step.Ref::{ id: rep_1_id, },
          @step.Ref::{ id: rep_2_id, },
        ),
      )
    } else if name == "REPRESENTATION_RELATIONSHIP_WITH_TRANSFORMATION" {
      let inner_args = strip_outer_parens(a)
      let args_parts = split_args(inner_args)
      if args_parts.length() != 1 {
        fail_parse()
      }
      let t_id = parse_ref_int(args_parts[0])
      @context.ComplexPart::RepRelWT(
        @product.RepresentationRelationshipWithTransformation::new(@step.Ref::{
          id: t_id,
        }),
      )
    } else if name == "SHAPE_REPRESENTATION_RELATIONSHIP" {
      expect_empty_parens(a)
      @context.ComplexPart::ShapeRepRel
    } else if name == "REPRESENTATION_ITEM" {
      let inner_args = strip_outer_parens(a)
      @context.ComplexPart::RepresentationItem(inner_args.trim().to_owned())
    } else if name == "GEOMETRIC_REPRESENTATION_ITEM" {
      expect_empty_parens(a)
      @context.ComplexPart::GeometricRepresentationItem
    } else if name == "SURFACE" {
      expect_empty_parens(a)
      @context.ComplexPart::Surface
    } else if name == "BOUNDED_SURFACE" {
      expect_empty_parens(a)
      @context.ComplexPart::BoundedSurface
    } else if name == "RATIONAL_B_SPLINE_CURVE" {
      let inner_args = strip_outer_parens(a)
      let weights = parse_literal_list(inner_args)
      @context.ComplexPart::RatBSpline(
        @geometry.RationalBSplineCurve::new(weights),
      )
    } else if name == "B_SPLINE_SURFACE" {
      let inner_args = strip_outer_parens(a)
      let inner = parse_b_spline_surface(inner_args)
      @context.ComplexPart::BSplineSurf(inner)
    } else if name == "B_SPLINE_SURFACE_WITH_KNOTS" {
      let inner_args = strip_outer_parens(a)
      let inner = parse_b_spline_surface_with_knots(inner_args)
      @context.ComplexPart::BSplineSurfKnots(inner)
    } else if name == "RATIONAL_B_SPLINE_SURFACE" {
      let inner = parse_rational_b_spline_surface(a)
      @context.ComplexPart::RatBSplineSurf(inner)
    } else {
      @context.ComplexPart::Raw(name, a)
    }
  })
  @context.ComplexInstance::new(parts)
}

///|
fn find_literal_outside_step_strings_with_state(
  haystack : String,
  needle : String,
) -> (Int32?, Int32?) {
  let n = haystack.length()
  let m = needle.length()
  if m == 0 {
    return (Some(0), None)
  }
  let needle0 = cu_at(needle, 0)
  let quote = Char::to_int('\'')
  let mut in_string = false
  let mut string_start = 0
  let mut i = 0
  while i < n {
    let ci = cu_at(haystack, i)
    if in_string {
      if ci == quote {
        // STEP string escaping: doubled quotes '' represent a literal '.
        if i + 1 < n && cu_at(haystack, i + 1) == quote {
          i = i + 2
          continue
        }
        in_string = false
      }
      i = i + 1
      continue
    }
    if ci == quote {
      in_string = true
      string_start = i
      i = i + 1
      continue
    }
    if ci == needle0 && i + m <= n {
      let mut j = 1
      let mut ok = true
      while j < m {
        if cu_at(haystack, i + j) != cu_at(needle, j) {
          ok = false
          break
        }
        j = j + 1
      }
      if ok {
        return (Some(i), None)
      }
    }
    i = i + 1
  }
  if in_string {
    (None, Some(string_start))
  } else {
    (None, None)
  }
}

///|
fn line_slice_at(s : String, idx : Int32) -> String {
  let n = s.length()
  let mut start = if idx < 0 { 0 } else { idx }
  if start > n {
    start = n
  }
  let mut i = start
  while i > 0 {
    if cu_at(s, i - 1) == Char::to_int('\n') {
      break
    }
    i = i - 1
  }
  let line_start = i
  let mut j = start
  while j < n {
    if cu_at(s, j) == Char::to_int('\n') {
      break
    }
    j = j + 1
  }
  substr(s, line_start, j)
}

///|
fn[T] raise_unterminated_string_in_source(
  content : String,
  quote_idx : Int32,
) -> T raise StepParseError {
  let (line, col) = index_to_line_col(content, quote_idx)
  let stmt = line_slice_at(content, quote_idx)
  fail_parse_at("unterminated STEP string literal", line, col, stmt)
}

///|
fn index_to_line_col(s : String, idx : Int32) -> (Int32, Int32) {
  let mut line = 1
  let mut col = 1
  let mut i = 0
  while i < idx && i < s.length() {
    let ci = cu_at(s, i)
    if ci == Char::to_int('\n') {
      line = line + 1
      col = 1
    } else {
      col = col + 1
    }
    i = i + 1
  }
  (line, col)
}

///|
fn extract_data_section_with_pos(
  content : String,
) -> (String, Int32, Int32) raise StepParseError {
  let data_idx = match
    find_literal_outside_step_strings_with_state(content, "DATA;") {
    (Some(i), _) => i
    (None, Some(q0)) => raise_unterminated_string_in_source(content, q0)
    (None, None) => fail_parse_msg("missing DATA section")
  }
  let after_data = data_idx + 5
  let tail = substr(content, after_data, content.length())
  let end_idx_local = match
    find_literal_outside_step_strings_with_state(tail, "ENDSEC;") {
    (Some(i), _) => i
    (None, Some(q0)) =>
      raise_unterminated_string_in_source(content, after_data + q0)
    (None, None) => fail_parse_msg("missing ENDSEC; for DATA section")
  }
  let (line, col) = index_to_line_col(content, after_data)
  (substr(tail, 0, end_idx_local), line, col)
}

///|
fn extract_header_section(content : String) -> String? raise StepParseError {
  let header_idx = match
    find_literal_outside_step_strings_with_state(content, "HEADER;") {
    (Some(i), _) => i
    (None, Some(q0)) =>
      // Prefer surfacing a real parse error over silently ignoring HEADER.
      raise_unterminated_string_in_source(content, q0)
    (None, None) => return None
  }
  let after_header = header_idx + 7
  let tail = substr(content, after_header, content.length())
  let end_idx_local = match
    find_literal_outside_step_strings_with_state(tail, "ENDSEC;") {
    (Some(i), _) => i
    (None, Some(q0)) =>
      raise_unterminated_string_in_source(content, after_header + q0)
    (None, None) => return None
  }
  Some(substr(tail, 0, end_idx_local).trim().to_owned())
}

///|
fn parse_step_string_literal(s : String) -> String? {
  let t = s.trim().to_owned()
  if t.length() >= 2 &&
    cu_at(t, 0) == Char::to_int('\'') &&
    cu_at(t, t.length() - 1) == Char::to_int('\'') {
    let inner = substr(t, 1, t.length() - 1)
    let builder = StringBuilder()
    let n = inner.length()
    let mut i = 0
    while i < n {
      let ci = cu_at(inner, i)
      if ci == Char::to_int('\'') {
        // STEP string escaping: doubled quotes '' represent a literal '.
        if i + 1 < n && cu_at(inner, i + 1) == Char::to_int('\'') {
          builder.write_char('\'')
          i = i + 2
          continue
        } else {
          // Unescaped quote in the middle is invalid; fall back.
          return None
        }
      }
      builder.write_char(ci.unsafe_to_char())
      i = i + 1
    }
    return Some(builder.to_string())
  }
  None
}

///|
fn parse_string_or_dollar(arg : String) -> @header.StringOrDollar? {
  let t = arg.trim().to_owned()
  if t == "$" {
    return Some(@header.StringOrDollar::Dollar)
  }
  match parse_step_string_literal(t) {
    Some(v) => Some(@header.StringOrDollar::Str(v))
    None => None
  }
}

///|
fn parse_string_list_or_dollar(arg : String) -> @header.StringListOrDollar? {
  let t = arg.trim().to_owned()
  if t == "$" {
    return Some(@header.StringListOrDollar::Dollar)
  }
  // Expect something like ('a','b') or ().
  if !(t.length() >= 2 &&
    cu_at(t, 0) == Char::to_int('(') &&
    cu_at(t, t.length() - 1) == Char::to_int(')')) {
    return None
  }
  let parts = split_args(t)
  let values : Array[String] = []
  for p in parts {
    match parse_step_string_literal(p) {
      Some(v) => values.push(v)
      None => return None
    }
  }
  Some(@header.StringListOrDollar::List(values))
}

///|
fn parse_file_description(stmt : String, args : String) -> @header.HeaderEntity {
  let parts = split_args(args)
  if parts.length() != 2 {
    return @header.HeaderEntity::Raw(stmt)
  }
  let desc_opt = parse_string_list_or_dollar(parts[0])
  let impl_opt = parse_string_or_dollar(parts[1])
  match (desc_opt, impl_opt) {
    (
      Some(@header.StringListOrDollar::List(desc)),
      Some(@header.StringOrDollar::Str(impl_level)),
    ) =>
      @header.HeaderEntity::FileDescription(
        @header.FileDescription::new(desc, impl_level),
      )
    _ => @header.HeaderEntity::Raw(stmt)
  }
}

///|
fn parse_file_name(stmt : String, args : String) -> @header.HeaderEntity {
  let parts = split_args(args)
  if parts.length() != 7 {
    return @header.HeaderEntity::Raw(stmt)
  }
  let a0 = parse_string_or_dollar(parts[0])
  let a1 = parse_string_or_dollar(parts[1])
  let a2 = parse_string_list_or_dollar(parts[2])
  let a3 = parse_string_list_or_dollar(parts[3])
  let a4 = parse_string_or_dollar(parts[4])
  let a5 = parse_string_or_dollar(parts[5])
  let a6 = parse_string_or_dollar(parts[6])
  match (a0, a1, a2, a3, a4, a5, a6) {
    (Some(n), Some(ts), Some(auth), Some(org), Some(pp), Some(os), Some(az)) =>
      @header.HeaderEntity::FileName(
        @header.FileName::new(n, ts, auth, org, pp, os, az),
      )
    _ => @header.HeaderEntity::Raw(stmt)
  }
}

///|
fn parse_file_schema(stmt : String, args : String) -> @header.HeaderEntity {
  let parts = split_args(args)
  if parts.length() != 1 {
    return @header.HeaderEntity::Raw(stmt)
  }
  let list_opt = parse_string_list_or_dollar(parts[0])
  match list_opt {
    Some(@header.StringListOrDollar::List(schemas)) =>
      @header.HeaderEntity::FileSchema(@header.FileSchema::new(schemas))
    _ => @header.HeaderEntity::Raw(stmt)
  }
}

///|
fn parse_header_section(header_section : String) -> @header.HeaderSection {
  let stmts = split_statements(header_section)
  let entities = stmts.map(fn(stmt) {
    let lp_idx = String::find(stmt, "(")
    match lp_idx {
      None => @header.HeaderEntity::Raw(stmt)
      Some(j) => {
        let name = substr(stmt, 0, j).trim().to_owned()
        let args = substr(stmt, j, stmt.length()).trim().to_owned()
        if name == "FILE_DESCRIPTION" {
          parse_file_description(stmt, args)
        } else if name == "FILE_NAME" {
          parse_file_name(stmt, args)
        } else if name == "FILE_SCHEMA" {
          parse_file_schema(stmt, args)
        } else {
          @header.HeaderEntity::Raw(stmt)
        }
      }
    }
  })
  @header.HeaderSection::new(entities)
}

///|
// Async entrypoint: read a STEP file and parse it into a Repository.
// Uses moonbitlang/async for file I/O.
pub async fn parse_repository_from_file(
  path : StringView,
) -> @repository.Repository raise Error {
  // `.text()` decodes UTF-8. Decoding byte-by-byte instead would mojibake any
  // non-ASCII name or annotation in a third-party STEP file.
  let content = @fs.read_file(path).text()
  parse_repository_from_string(content)
}

///|
// A non-raising parse result for library consumers that prefer not to use `raise`.
pub enum ParseRepositoryResult {
  Ok(@repository.Repository)
  Err(StepParseErrorInfo)
}

///|
// A non-raising parse result for file parsing, capturing either parse errors or I/O.
pub enum ParseRepositoryFromFileResult {
  Ok(@repository.Repository)
  ParseErr(StepParseErrorInfo)
  IoErr(Error)
}

///|
pub fn parse_repository_from_string_result(
  content : String,
) -> ParseRepositoryResult {
  ParseRepositoryResult::Ok(parse_repository_from_string(content)) catch {
    StepParseError(info) => ParseRepositoryResult::Err(info)
  }
}

///|
pub async fn parse_repository_from_file_result(
  path : StringView,
) -> ParseRepositoryFromFileResult {
  try {
    let repo = parse_repository_from_file(path)
    ParseRepositoryFromFileResult::Ok(repo)
  } catch {
    StepParseError(info) => ParseRepositoryFromFileResult::ParseErr(info)
    e => ParseRepositoryFromFileResult::IoErr(e)
  }
}

///|
// Minimal parser: only supports the three entities currently ported.
// Unknown entity names are preserved as raw entities for round-trip support.
pub fn parse_repository_from_string(
  content : String,
) -> @repository.Repository raise StepParseError {
  // Normalize Windows CRLF (and stray CR) to keep parsing and serialization stable.
  let normalized = content.replace(old="\r", new="")
  // Strip STEP block comments (/* ... */) outside of string literals.
  let cleaned = strip_step_comments(normalized)
  let header = match extract_header_section(cleaned) {
    Some(h) => parse_header_section(h)
    None => @header.HeaderSection::empty()
  }
  let (data_section, base_line, base_col) = extract_data_section_with_pos(
    cleaned,
  )
  let rows = tokenize_step_data_section_with_base(
    data_section, base_line, base_col,
  )
  let mut repo = @repository.new()
  for row in rows {
    match parsers.get(row.name) {
      Some(parser_fn) => {
        let entity = parser_fn(row.args)
        repo = repo.insert_with_id(row.id, entity)
      }
      None =>
        if row.name == "__COMPLEX__" {
          let entity = parse_complex_instance(row.args)
          repo = repo.insert_with_id(
            row.id,
            @repository.any_entity_complex_instance(entity),
          )
        } else {
          let raw = @step.RawEntity::new(row.name, row.args)
          repo = repo.insert_with_id(
            row.id,
            @repository.any_entity_raw_entity(raw),
          )
        }
    }
  }
  repo.set_header(header)
}

///|
/// parse_repository_from_string_lenient parses a STEP file and keeps entities
/// whose typed parser rejects the standard spelling as lossless `RawEntity`
/// values. Tokenizer and grammar errors still fail. This is used by
/// `tools/step-stats` to inspect third-party golden files without weakening
/// the strict parser used by the library.
pub fn parse_repository_from_string_lenient(
  content : String,
) -> @repository.Repository raise StepParseError {
  let normalized = content.replace(old="\r", new="")
  let cleaned = strip_step_comments(normalized)
  let header = match extract_header_section(cleaned) {
    Some(h) => parse_header_section(h)
    None => @header.HeaderSection::empty()
  }
  let (data_section, base_line, base_col) = extract_data_section_with_pos(
    cleaned,
  )
  let rows = tokenize_step_data_section_with_base(
    data_section, base_line, base_col,
  )
  let mut repo = @repository.new()
  for row in rows {
    match parsers.get(row.name) {
      Some(parser_fn) => {
        let entity = parser_fn(row.args) catch {
          _ =>
            @repository.any_entity_raw_entity(
              @step.RawEntity::new(row.name, row.args),
            )
        }
        repo = repo.insert_with_id(row.id, entity)
      }
      None =>
        if row.name == "__COMPLEX__" {
          let entity = @repository.any_entity_complex_instance(
            parse_complex_instance(row.args),
          ) catch {
            _ =>
              // Keep the original complex instance text. An empty name makes
              // RawEntity::to_step emit just `row.args` (the parenthesized
              // complex body), rather than a bogus `__COMPLEX__(...)` entity.
              @repository.any_entity_raw_entity(
                @step.RawEntity::new("", row.args),
              )
          }
          repo = repo.insert_with_id(row.id, entity)
        } else {
          let raw = @step.RawEntity::new(row.name, row.args)
          repo = repo.insert_with_id(
            row.id,
            @repository.any_entity_raw_entity(raw),
          )
        }
    }
  }
  repo.set_header(header)
}

///|
/// parse_repository_from_string_lenient_result is the non-raising lenient
/// wrapper used by tooling.
pub fn parse_repository_from_string_lenient_result(
  content : String,
) -> ParseRepositoryResult {
  ParseRepositoryResult::Ok(parse_repository_from_string_lenient(content)) catch {
    StepParseError(info) => ParseRepositoryResult::Err(info)
  }
}
