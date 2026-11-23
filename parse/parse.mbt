///|
priv struct EntityParser((String) -> @repository.AnyEntity raise StepParseError)

///|
let parsers : Map[String, EntityParser] = Map([])

///|
fn init {
  parsers.set("CARTESIAN_POINT", fn(args) raise StepParseError {
    @repository.any_entity_cartesian_point(parse_cartesian_point(args))
  })
  parsers.set("DIRECTION", fn(args) raise StepParseError {
    @repository.any_entity_direction(parse_direction(args))
  })
  parsers.set("AXIS1_PLACEMENT", fn(args) raise StepParseError {
    @repository.any_entity_axis1_placement(parse_axis1_placement(args))
  })
  parsers.set("AXIS2_PLACEMENT_2D", fn(args) raise StepParseError {
    @repository.any_entity_axis2_placement_2d(parse_axis2_placement_2d(args))
  })
  parsers.set("AXIS2_PLACEMENT_3D", fn(args) raise StepParseError {
    @repository.any_entity_axis2_placement_3d(parse_axis2_placement_3d(args))
  })
  parsers.set("PLANE", fn(args) raise StepParseError {
    @repository.any_entity_plane(parse_plane(args))
  })
  parsers.set("CIRCLE", fn(args) raise StepParseError {
    @repository.any_entity_circle(parse_circle(args))
  })
  parsers.set("ELLIPSE", fn(args) raise StepParseError {
    @repository.any_entity_ellipse(parse_ellipse(args))
  })
  parsers.set("PARABOLA", fn(args) raise StepParseError {
    @repository.any_entity_parabola(parse_parabola(args))
  })
  parsers.set("HYPERBOLA", fn(args) raise StepParseError {
    @repository.any_entity_hyperbola(parse_hyperbola(args))
  })
  parsers.set("CYL_SURF", fn(args) raise StepParseError {
    @repository.any_entity_cylindrical_surface(parse_cylindrical_surface(args))
  })
  parsers.set("CYLINDRICAL_SURFACE", fn(args) raise StepParseError {
    @repository.any_entity_cylindrical_surface(parse_cylindrical_surface(args))
  })
  parsers.set("CONICAL_SURFACE", fn(args) raise StepParseError {
    @repository.any_entity_conical_surface(parse_conical_surface(args))
  })
  parsers.set("SPHERICAL_SURFACE", fn(args) raise StepParseError {
    @repository.any_entity_spherical_surface(parse_spherical_surface(args))
  })
  parsers.set("TOROIDAL_SURFACE", fn(args) raise StepParseError {
    @repository.any_entity_toroidal_surface(parse_toroidal_surface(args))
  })
  parsers.set("B_SPLINE_CURVE", fn(args) raise StepParseError {
    @repository.any_entity_b_spline_curve(parse_b_spline_curve(args))
  })
  parsers.set("B_SPLINE_CURVE_WITH_KNOTS", fn(args) raise StepParseError {
    @repository.any_entity_b_spline_curve_with_knots(
      parse_b_spline_curve_with_knots(args),
    )
  })
  parsers.set("COMPOSITE_CURVE", fn(args) raise StepParseError {
    @repository.any_entity_composite_curve(parse_composite_curve(args))
  })
  parsers.set("COMPOSITE_CURVE_SEGMENT", fn(args) raise StepParseError {
    @repository.any_entity_composite_curve_segment(
      parse_composite_curve_segment(args),
    )
  })
  parsers.set("B_SPLINE_SURFACE", fn(args) raise StepParseError {
    @repository.any_entity_b_spline_surface(parse_b_spline_surface(args))
  })
  parsers.set("B_SPLINE_SURFACE_WITH_KNOTS", fn(args) raise StepParseError {
    parse_b_spline_surface_with_knots_entity(args)
  })
  parsers.set("RATIONAL_B_SPLINE_CURVE", fn(args) raise StepParseError {
    @repository.any_entity_rational_b_spline_curve(
      parse_rational_b_spline_curve(args),
    )
  })
  parsers.set("RATIONAL_B_SPLINE_SURFACE", fn(args) raise StepParseError {
    @repository.any_entity_rational_b_spline_surface(
      parse_rational_b_spline_surface(args),
    )
  })
  parsers.set("TRIMMED_CURVE", fn(args) raise StepParseError {
    @repository.any_entity_trimmed_curve(parse_trimmed_curve(args))
  })
  parsers.set("OFFSET_CURVE_3D", fn(args) raise StepParseError {
    @repository.any_entity_offset_curve_3d(parse_offset_curve_3d(args))
  })
  parsers.set("OFFSET_SURFACE", fn(args) raise StepParseError {
    @repository.any_entity_offset_surface(parse_offset_surface(args))
  })
  parsers.set("SURFACE_OF_LINEAR_EXTRUSION", fn(args) raise StepParseError {
    @repository.any_entity_surface_of_linear_extrusion(
      parse_surface_of_linear_extrusion(args),
    )
  })
  parsers.set("SURFACE_OF_REVOLUTION", fn(args) raise StepParseError {
    @repository.any_entity_surface_of_revolution(
      parse_surface_of_revolution(args),
    )
  })
  parsers.set("SWEPT_SURFACE", fn(args) raise StepParseError {
    @repository.any_entity_swept_surface(parse_swept_surface(args))
  })
  parsers.set("RECTANGULAR_TRIMMED_SURFACE", fn(args) raise StepParseError {
    @repository.any_entity_rectangular_trimmed_surface(
      parse_rectangular_trimmed_surface(args),
    )
  })
  parsers.set("POLYLINE", fn(args) raise StepParseError {
    @repository.any_entity_polyline(parse_polyline(args))
  })
  parsers.set("VECTOR", fn(args) raise StepParseError {
    @repository.any_entity_vector(parse_vector(args))
  })
  parsers.set("LINE", fn(args) raise StepParseError {
    @repository.any_entity_line(parse_line(args))
  })
  parsers.set("REPRESENTATION_RELATIONSHIP", fn(args) raise StepParseError {
    @repository.any_entity_representation_relationship(
      parse_representation_relationship(args),
    )
  })
  parsers.set("REPRESENTATION_RELATIONSHIP_WITH_TRANSFORMATION", fn(
    args,
  ) raise StepParseError {
    @repository.any_entity_representation_relationship_with_transformation(
      parse_representation_relationship_with_transformation(args),
    )
  })
  parsers.set("SHAPE_REPRESENTATION_RELATIONSHIP", fn(
    args,
  ) raise StepParseError {
    @repository.any_entity_shape_representation_relationship(
      parse_shape_representation_relationship(args),
    )
  })
  parsers.set("ADVANCED_BREP_SHAPE_REPRESENTATION", fn(
    args,
  ) raise StepParseError {
    @repository.any_entity_advanced_brep_shape_representation(
      parse_advanced_brep_shape_representation(args),
    )
  })
  parsers.set("SHAPE_DEFINITION_REPRESENTATION", fn(args) raise StepParseError {
    @repository.any_entity_shape_definition_representation(
      parse_shape_definition_representation(args),
    )
  })
  parsers.set("SHAPE_REPRESENTATION", fn(args) raise StepParseError {
    @repository.any_entity_shape_representation(
      parse_shape_representation(args),
    )
  })
  parsers.set("REPRESENTATION", fn(args) raise StepParseError {
    @repository.any_entity_representation(parse_representation(args))
  })
  parsers.set("DESCRIPTIVE_REPRESENTATION_ITEM", fn(args) raise StepParseError {
    @repository.any_entity_descriptive_representation_item(
      parse_descriptive_representation_item(args),
    )
  })
  parsers.set("MEASURE_REPRESENTATION_ITEM", fn(args) raise StepParseError {
    @repository.any_entity_measure_representation_item(
      parse_measure_representation_item(args),
    )
  })
  parsers.set("CONTEXT_DEPENDENT_SHAPE_REPRESENTATION", fn(
    args,
  ) raise StepParseError {
    @repository.any_entity_context_dependent_shape_representation(
      parse_context_dependent_shape_representation(args),
    )
  })
  parsers.set("ITEM_DEFINED_TRANSFORMATION", fn(args) raise StepParseError {
    @repository.any_entity_item_defined_transformation(
      parse_item_defined_transformation(args),
    )
  })
  parsers.set("NEXT_ASSEMBLY_USAGE_OCCURRENCE", fn(args) raise StepParseError {
    @repository.any_entity_next_assembly_usage_occurrence(
      parse_next_assembly_usage_occurrence(args),
    )
  })
  parsers.set("PRODUCT_DEFINITION_SHAPE", fn(args) raise StepParseError {
    @repository.any_entity_product_definition_shape(
      parse_product_definition_shape(args),
    )
  })
  parsers.set("PRODUCT_DEFINITION", fn(args) raise StepParseError {
    @repository.any_entity_product_definition(parse_product_definition(args))
  })
  parsers.set("PRODUCT_DEFINITION_CONTEXT", fn(args) raise StepParseError {
    @repository.any_entity_product_definition_context(
      parse_product_definition_context(args),
    )
  })
  parsers.set("PRODUCT_DEFINITION_FORMATION", fn(args) raise StepParseError {
    @repository.any_entity_product_definition_formation(
      parse_product_definition_formation(args),
    )
  })
  parsers.set("PRODUCT_DEFINITION_FORMATION_WITH_SPECIFIED_SOURCE", fn(
    args,
  ) raise StepParseError {
    @repository.any_entity_product_definition_formation_with_specified_source(
      parse_product_definition_formation_with_specified_source(args),
    )
  })
  parsers.set("PROPERTY_DEFINITION", fn(args) raise StepParseError {
    @repository.any_entity_property_definition(parse_property_definition(args))
  })
  parsers.set("PROPERTY_DEFINITION_REPRESENTATION", fn(
    args,
  ) raise StepParseError {
    @repository.any_entity_property_definition_representation(
      parse_property_definition_representation(args),
    )
  })
  parsers.set("PRODUCT_RELATED_PRODUCT_CATEGORY", fn(
    args,
  ) raise StepParseError {
    @repository.any_entity_product_related_product_category(
      parse_product_related_product_category(args),
    )
  })
  parsers.set("PRODUCT", fn(args) raise StepParseError {
    @repository.any_entity_product(parse_product(args))
  })
  parsers.set("PRODUCT_CONTEXT", fn(args) raise StepParseError {
    @repository.any_entity_product_context(parse_product_context(args))
  })
  parsers.set("APPLICATION_PROTOCOL_DEFINITION", fn(args) raise StepParseError {
    @repository.any_entity_application_protocol_definition(
      parse_application_protocol_definition(args),
    )
  })
  parsers.set("APPLICATION_CONTEXT", fn(args) raise StepParseError {
    @repository.any_entity_application_context(parse_application_context(args))
  })
  parsers.set("APPROVAL", fn(args) raise StepParseError {
    @repository.any_entity_approval(parse_approval(args))
  })
  parsers.set("APPROVAL_STATUS", fn(args) raise StepParseError {
    @repository.any_entity_approval_status(parse_approval_status(args))
  })
  parsers.set("APPROVAL_ROLE", fn(args) raise StepParseError {
    @repository.any_entity_approval_role(parse_approval_role(args))
  })
  parsers.set("APPROVAL_PERSON_ORGANIZATION", fn(args) raise StepParseError {
    @repository.any_entity_approval_person_organization(
      parse_approval_person_organization(args),
    )
  })
  parsers.set("PERSON", fn(args) raise StepParseError {
    @repository.any_entity_person(parse_person(args))
  })
  parsers.set("ORGANIZATION", fn(args) raise StepParseError {
    @repository.any_entity_organization(parse_organization(args))
  })
  parsers.set("PERSON_AND_ORGANIZATION", fn(args) raise StepParseError {
    @repository.any_entity_person_and_organization(
      parse_person_and_organization(args),
    )
  })
  parsers.set("DATE_AND_TIME", fn(args) raise StepParseError {
    @repository.any_entity_date_and_time(parse_date_and_time(args))
  })
  parsers.set("LOCAL_TIME", fn(args) raise StepParseError {
    @repository.any_entity_local_time(parse_local_time(args))
  })
  parsers.set("CALENDAR_DATE", fn(args) raise StepParseError {
    @repository.any_entity_calendar_date(parse_calendar_date(args))
  })
  parsers.set("COORDINATED_UNIVERSAL_TIME_OFFSET", fn(
    args,
  ) raise StepParseError {
    @repository.any_entity_coordinated_universal_time_offset(
      parse_coordinated_universal_time_offset(args),
    )
  })
  parsers.set("SECURITY_CLASSIFICATION", fn(args) raise StepParseError {
    @repository.any_entity_security_classification(
      parse_security_classification(args),
    )
  })
  parsers.set("SECURITY_CLASSIFICATION_LEVEL", fn(args) raise StepParseError {
    @repository.any_entity_security_classification_level(
      parse_security_classification_level(args),
    )
  })
  parsers.set("CERTIFICATION", fn(args) raise StepParseError {
    @repository.any_entity_certification(parse_certification(args))
  })
  parsers.set("CERTIFICATION_TYPE", fn(args) raise StepParseError {
    @repository.any_entity_certification_type(parse_certification_type(args))
  })
  parsers.set("DOCUMENT", fn(args) raise StepParseError {
    @repository.any_entity_document(parse_document(args))
  })
  parsers.set("DOCUMENT_REFERENCE", fn(args) raise StepParseError {
    @repository.any_entity_document_reference(parse_document_reference(args))
  })
  parsers.set("DOCUMENT_TYPE", fn(args) raise StepParseError {
    @repository.any_entity_document_type(parse_document_type(args))
  })
  parsers.set("KINEMATIC_LINK", fn(args) raise StepParseError {
    @repository.any_entity_kinematic_link(parse_kinematic_link(args))
  })
  parsers.set("KINEMATIC_JOINT", fn(args) raise StepParseError {
    @repository.any_entity_kinematic_joint(parse_kinematic_joint(args))
  })
  parsers.set("KINEMATIC_PAIR", fn(args) raise StepParseError {
    @repository.any_entity_kinematic_pair(parse_kinematic_pair(args))
  })
  parsers.set("GEOMETRIC_TOLERANCE", fn(args) raise StepParseError {
    @repository.any_entity_geometric_tolerance(parse_geometric_tolerance(args))
  })
  parsers.set("DATUM", fn(args) raise StepParseError {
    @repository.any_entity_datum(parse_datum(args))
  })
  parsers.set("DATUM_FEATURE", fn(args) raise StepParseError {
    @repository.any_entity_datum_feature(parse_datum_feature(args))
  })
  parsers.set("DIMENSIONAL_SIZE", fn(args) raise StepParseError {
    @repository.any_entity_dimensional_size(parse_dimensional_size(args))
  })
  parsers.set("MANIFOLD_SOLID_BREP", fn(args) raise StepParseError {
    @repository.any_entity_manifold_solid_brep(parse_manifold_solid_brep(args))
  })
  parsers.set("CLOSED_SHELL", fn(args) raise StepParseError {
    @repository.any_entity_closed_shell(parse_closed_shell(args))
  })
  parsers.set("OPEN_SHELL", fn(args) raise StepParseError {
    @repository.any_entity_open_shell(parse_open_shell(args))
  })
  parsers.set("CONNECTED_FACE_SET", fn(args) raise StepParseError {
    @repository.any_entity_connected_face_set(parse_connected_face_set(args))
  })
  parsers.set("SHELL_BASED_SURFACE_MODEL", fn(args) raise StepParseError {
    @repository.any_entity_shell_based_surface_model(
      parse_shell_based_surface_model(args),
    )
  })
  parsers.set("ADVANCED_FACE", fn(args) raise StepParseError {
    @repository.any_entity_advanced_face(parse_advanced_face(args))
  })
  parsers.set("FACE_SURFACE", fn(args) raise StepParseError {
    @repository.any_entity_face_surface(parse_face_surface(args))
  })
  parsers.set("SUBFACE", fn(args) raise StepParseError {
    @repository.any_entity_subface(parse_subface(args))
  })
  parsers.set("SHAPE_ASPECT", fn(args) raise StepParseError {
    @repository.any_entity_shape_aspect(parse_shape_aspect(args))
  })
  parsers.set("FACE_OUTER_BOUND", fn(args) raise StepParseError {
    @repository.any_entity_face_outer_bound(parse_face_outer_bound(args))
  })
  parsers.set("FACE_BOUND", fn(args) raise StepParseError {
    @repository.any_entity_face_bound(parse_face_bound(args))
  })
  parsers.set("EDGE_LOOP", fn(args) raise StepParseError {
    @repository.any_entity_edge_loop(parse_edge_loop(args))
  })
  parsers.set("ORIENTED_EDGE", fn(args) raise StepParseError {
    @repository.any_entity_oriented_edge(parse_oriented_edge(args))
  })
  parsers.set("EDGE_CURVE", fn(args) raise StepParseError {
    @repository.any_entity_edge_curve(parse_edge_curve(args))
  })
  parsers.set("VERTEX_POINT", fn(args) raise StepParseError {
    @repository.any_entity_vertex_point(parse_vertex_point(args))
  })
  parsers.set("COLOUR_RGB", fn(args) raise StepParseError {
    @repository.any_entity_color_rgb(parse_color_rgb(args))
  })
  parsers.set("DRAUGHTING_PRE_DEFINED_COLOUR", fn(args) raise StepParseError {
    @repository.any_entity_draughting_pre_defined_color(
      parse_draughting_pre_defined_color(args),
    )
  })
  parsers.set("FILL_AREA_STYLE_COLOUR", fn(args) raise StepParseError {
    @repository.any_entity_fill_area_style_color(
      parse_fill_area_style_color(args),
    )
  })
  parsers.set("FILL_AREA_STYLE", fn(args) raise StepParseError {
    @repository.any_entity_fill_area_style(parse_fill_area_style(args))
  })
  parsers.set("SURFACE_STYLE_FILL_AREA", fn(args) raise StepParseError {
    @repository.any_entity_surface_style_fill_area(
      parse_surface_style_fill_area(args),
    )
  })
  parsers.set("SURFACE_SIDE_STYLE", fn(args) raise StepParseError {
    @repository.any_entity_surface_side_style(parse_surface_side_style(args))
  })
  parsers.set("SURFACE_STYLE_USAGE", fn(args) raise StepParseError {
    @repository.any_entity_surface_style_usage(parse_surface_style_usage(args))
  })
  parsers.set("PRESENTATION_LAYER_ASSIGNMENT", fn(args) raise StepParseError {
    @repository.any_entity_presentation_layer_assignment(
      parse_presentation_layer_assignment(args),
    )
  })
  parsers.set("MECHANICAL_DESIGN_GEOMETRIC_PRESENTATION_REPRESENTATION", fn(
    args,
  ) raise StepParseError {
    @repository.any_entity_mechanical_design_geometric_presentation_representation(
      parse_mechanical_design_geometric_presentation_representation(args),
    )
  })
  parsers.set("PRESENTATION_STYLE_ASSIGNMENT", fn(args) raise StepParseError {
    @repository.any_entity_presentation_style_assignment(
      parse_presentation_style_assignment(args),
    )
  })
  parsers.set("STYLED_ITEM", fn(args) raise StepParseError {
    @repository.any_entity_styled_item(parse_styled_item(args))
  })
  parsers.set("OVER_RIDING_STYLED_ITEM", fn(args) raise StepParseError {
    @repository.any_entity_over_riding_styled_item(
      parse_over_riding_styled_item(args),
    )
  })
  parsers.set("HIDDEN_ELEMENT_OVER_RIDING_STYLED_ITEM", fn(
    args,
  ) raise StepParseError {
    @repository.any_entity_hidden_element_over_riding_styled_item(
      parse_hidden_element_over_riding_styled_item(args),
    )
  })
  parsers.set("ANNOTATION_OCCURRENCE", fn(args) raise StepParseError {
    @repository.any_entity_annotation_occurrence(
      parse_annotation_occurrence(args),
    )
  })
  parsers.set("TEXT_LITERAL", fn(args) raise StepParseError {
    @repository.any_entity_text_literal(parse_text_literal(args))
  })
  parsers.set("DIMENSIONAL_EXPONENTS", fn(args) raise StepParseError {
    @repository.any_entity_dimensional_exponents(
      parse_dimensional_exponents(args),
    )
  })
  parsers.set("UNCERTAINTY_MEASURE_WITH_UNIT", fn(args) raise StepParseError {
    @repository.any_entity_uncertainty_measure_with_unit(
      parse_uncertainty_measure_with_unit(args),
    )
  })
  parsers.set("PLANE_ANGLE_MEASURE_WITH_UNIT", fn(args) raise StepParseError {
    @repository.any_entity_plane_angle_measure_with_unit(
      parse_plane_angle_measure_with_unit(args),
    )
  })
  parsers.set("MEASURE_WITH_UNIT", fn(args) raise StepParseError {
    @repository.any_entity_measure_with_unit(parse_measure_with_unit(args))
  })
  parsers.set("DERIVED_UNIT_ELEMENT", fn(args) raise StepParseError {
    @repository.any_entity_derived_unit_element(
      parse_derived_unit_element(args),
    )
  })
  parsers.set("DERIVED_UNIT", fn(args) raise StepParseError {
    @repository.any_entity_derived_unit(parse_derived_unit(args))
  })
  parsers.set("BOOLEAN_RESULT", fn(args) raise StepParseError {
    @repository.any_entity_boolean_result(parse_boolean_result(args))
  })
  parsers.set("CSG_SOLID", fn(args) raise StepParseError {
    @repository.any_entity_csg_solid(parse_csg_solid(args))
  })
  parsers.set("BLOCK", fn(args) raise StepParseError {
    @repository.any_entity_block(parse_block(args))
  })
  parsers.set("SPHERE", fn(args) raise StepParseError {
    @repository.any_entity_sphere(parse_sphere(args))
  })
  parsers.set("RIGHT_CIRCULAR_CYLINDER", fn(args) raise StepParseError {
    @repository.any_entity_right_circular_cylinder(
      parse_right_circular_cylinder(args),
    )
  })
  parsers.set("RIGHT_CIRCULAR_CONE", fn(args) raise StepParseError {
    @repository.any_entity_right_circular_cone(parse_right_circular_cone(args))
  })
  parsers.set("TORUS", fn(args) raise StepParseError {
    @repository.any_entity_torus(parse_torus(args))
  })
  parsers.set("RECTANGULAR_PYRAMID", fn(args) raise StepParseError {
    @repository.any_entity_rectangular_pyramid(parse_rectangular_pyramid(args))
  })
  parsers.set("RIGHT_ANGULAR_WEDGE", fn(args) raise StepParseError {
    @repository.any_entity_right_angular_wedge(parse_right_angular_wedge(args))
  })
  parsers.set("HALF_SPACE_SOLID", fn(args) raise StepParseError {
    @repository.any_entity_half_space_solid(parse_half_space_solid(args))
  })
}

///|
fn parse_double(s : String) -> Double raise StepParseError {
  let t = s.trim().to_owned()
  // Use core string->double parsing for correct rounding and stable roundtrips.
  @string.parse_double(t) catch {
    _ => fail_parse()
  }
}

///|
fn strip_quotes(s : String) -> String {
  // STEP strings escape a literal apostrophe by doubling it. Unescape on the
  // way in so `step_str` (which re-escapes) reproduces the original text.
  // Every call site passes a STEP string literal, so fixing it here covers
  // all typed entities at once.
  match parse_step_string_literal_unescaped(s) {
    Some(v) => v
    None => {
      // Malformed literal: keep the old best-effort behavior.
      let t = s.trim().to_owned()
      if t.length() >= 2 &&
        cu_at(t, 0) == Char::to_int('\'') &&
        cu_at(t, t.length() - 1) == Char::to_int('\'') {
        return substr(t, 1, t.length() - 1)
      }
      t
    }
  }
}

///|
// Parse a STEP string literal of the form '...'
// and unescape doubled quotes '' -> '.
//
// Returns None if the input isn't a valid STEP string literal.
fn parse_step_string_literal_unescaped(s : String) -> String? {
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
        // STEP escaping: doubled quotes '' represent a literal '.
        if i + 1 < n && cu_at(inner, i + 1) == Char::to_int('\'') {
          builder.write_char('\'')
          i = i + 2
          continue
        } else {
          // Unescaped quote in the middle is invalid.
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
// Best-effort STEP string parsing: returns decoded string when possible,
// otherwise falls back to the previous strip_quotes behavior.
fn parse_step_string_or_strip(s : String) -> String {
  match parse_step_string_literal_unescaped(s) {
    Some(v) => v
    None => strip_quotes(s)
  }
}

///|
fn parse_ref_int(s : String) -> @step.EntityId raise StepParseError {
  let t = s.trim().to_owned()
  if t.length() < 2 || cu_at(t, 0) != Char::to_int('#') {
    fail_parse()
  }
  let digits = substr(t, 1, t.length())
  if !all_decimal_digits(digits) {
    fail_parse()
  }
  let v = parse_int_dec(digits)
  @step.EntityId::{ value: v, }
}
