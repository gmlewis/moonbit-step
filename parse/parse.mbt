///|
priv struct EntityParser((String) -> @repository.AnyEntity raise StepParseError)

///|
let parsers : Map[String, EntityParser] = Map::new()

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
    @repository.any_entity_b_spline_surface_with_knots(
      parse_b_spline_surface_with_knots(args),
    )
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
    @repository.any_entity_draughting_pre_defined_colour(
      parse_draughting_pre_defined_colour(args),
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
  let t = s.trim().to_string()
  // Use core string->double parsing for correct rounding and stable roundtrips.
  @strconv.parse_double(t) catch {
    _ => fail_parse()
  }
}

///|
fn strip_quotes(s : String) -> String {
  let t = s.trim().to_string()
  if t.length() >= 2 &&
    cu_at(t, 0) == Char::to_int('\'') &&
    cu_at(t, t.length() - 1) == Char::to_int('\'') {
    return substr(t, 1, t.length() - 1)
  }
  t
}

///|
// Parse a STEP string literal of the form '...'
// and unescape doubled quotes '' -> '.
//
// Returns None if the input isn't a valid STEP string literal.
fn parse_step_string_literal_unescaped(s : String) -> String? {
  let t = s.trim().to_string()
  if t.length() >= 2 &&
    cu_at(t, 0) == Char::to_int('\'') &&
    cu_at(t, t.length() - 1) == Char::to_int('\'') {
    let inner = substr(t, 1, t.length() - 1)
    let builder = StringBuilder::new()
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
  let t = s.trim().to_string()
  if t.length() < 2 || cu_at(t, 0) != Char::to_int('#') {
    fail_parse()
  }
  let v = parse_int_dec(substr(t, 1, t.length()))
  @step.EntityId::{ value: v }
}

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
    @step.Ref::{ id: location_id },
    @step.Ref::{ id: axis_id },
    @step.Ref::{ id: ref_dir_id },
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
  let axis_id_str = parts[2].trim().to_string()
  let axis = if axis_id_str == "$" {
    None
  } else {
    Some(@step.Ref::{ id: parse_ref_int(axis_id_str) })
  }
  @geometry.Axis1Placement::new(name, @step.Ref::{ id: location_id }, axis~)
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
  let dir_id_str = parts[2].trim().to_string()
  let ref_direction = if dir_id_str == "$" {
    None
  } else {
    Some(@step.Ref::{ id: parse_ref_int(dir_id_str) })
  }
  @geometry.Axis2Placement2D::new(
    name,
    @step.Ref::{ id: location_id },
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
  @geometry.Vector::new(name, @step.Ref::{ id: dir_id }, magnitude)
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
  @geometry.Line::new(name, @step.Ref::{ id: pnt_id }, @step.Ref::{ id: vec_id })
}

///|
fn parse_circle(args : String) -> @geometry.Circle raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let pos_id = parse_ref_int(parts[1])
  let radius_literal = parts[2].trim().to_string()
  @geometry.Circle::new(name, @step.Ref::{ id: pos_id }, radius_literal)
}

///|
fn parse_ellipse(args : String) -> @geometry.Ellipse raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let pos_id = parse_ref_int(parts[1])
  let semi_axis_1_literal = parts[2].trim().to_string()
  let semi_axis_2_literal = parts[3].trim().to_string()
  @geometry.Ellipse::new(
    name,
    @step.Ref::{ id: pos_id },
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
  @geometry.Parabola::new(name, @step.Ref::{ id: pos_id }, focal_dist)
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
  @geometry.Hyperbola::new(name, @step.Ref::{ id: pos_id }, semi, semi_imag)
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
  let radius_literal = parts[2].trim().to_string()
  @geometry.CylindricalSurface::new(
    name,
    @step.Ref::{ id: pos_id },
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
  let radius_literal = parts[2].trim().to_string()
  let semi_angle_literal = parts[3].trim().to_string()
  @geometry.ConicalSurface::new(
    name,
    @step.Ref::{ id: pos_id },
    radius_literal,
    semi_angle_literal,
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
  let major_radius_literal = parts[2].trim().to_string()
  let minor_radius_literal = parts[3].trim().to_string()
  @geometry.ToroidalSurface::new(
    name,
    @step.Ref::{ id: pos_id },
    major_radius_literal,
    minor_radius_literal,
  )
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
  let curve_form = parts[3].trim().to_string()
  let closed_str = parts[4].trim().to_string()
  let self_i_str = parts[5].trim().to_string()
  let closed_curve = if closed_str == ".T." {
    true
  } else if closed_str == ".F." {
    false
  } else {
    fail_parse()
  }
  let self_intersect = if self_i_str == ".T." {
    true
  } else if self_i_str == ".F." {
    false
  } else {
    fail_parse()
  }
  @geometry.BSplineCurve::new(
    name, degree, control_points, curve_form, closed_curve, self_intersect,
  )
}

///|
fn parse_int_list(arg : String) -> Array[Int] {
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
  let curve_form = parts[3].trim().to_string()
  let closed_str = parts[4].trim().to_string()
  let self_i_str = parts[5].trim().to_string()
  let closed_curve = if closed_str == ".T." {
    true
  } else if closed_str == ".F." {
    false
  } else {
    fail_parse()
  }
  let self_intersect = if self_i_str == ".T." {
    true
  } else if self_i_str == ".F." {
    false
  } else {
    fail_parse()
  }
  let knot_multiplicities = parse_int_list(parts[6])
  let knots = parse_literal_list(parts[7])
  let knot_spec = parts[8].trim().to_string()
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
  let si_str = parts[2].trim().to_string()
  let self_intersect = if si_str == ".T." {
    true
  } else if si_str == ".F." {
    false
  } else {
    fail_parse()
  }
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
  let trans_str = parts[0].trim().to_string()
  let transition = match @geometry.TransitionCode::from_string(trans_str) {
    Some(t) => t
    None => fail_parse()
  }
  let ss_str = parts[1].trim().to_string()
  let same_sense = if ss_str == ".T." {
    true
  } else if ss_str == ".F." {
    false
  } else {
    fail_parse()
  }
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
fn parse_b_spline_surface(
  args : String,
) -> @geometry.BSplineSurface raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 7 {
    fail_parse()
  }
  let u_degree = parse_int_dec(parts[0])
  let v_degree = parse_int_dec(parts[1])
  let row_parts = split_args(parts[2])
  let control_points_list = row_parts.map(fn(row_part) {
    parse_ref_ids(row_part).map(fn(id) { @step.Ref::{ id, } })
  })
  let surface_form = parts[3].trim().to_string()
  let u_closed_str = parts[4].trim().to_string()
  let v_closed_str = parts[5].trim().to_string()
  let self_i_str = parts[6].trim().to_string()
  let u_closed = if u_closed_str == ".T." {
    true
  } else if u_closed_str == ".F." {
    false
  } else {
    fail_parse()
  }
  let v_closed = if v_closed_str == ".T." {
    true
  } else if v_closed_str == ".F." {
    false
  } else {
    fail_parse()
  }
  let self_intersect = if self_i_str == ".T." {
    true
  } else if self_i_str == ".F." {
    false
  } else {
    fail_parse()
  }
  @geometry.BSplineSurface::new(
    u_degree, v_degree, control_points_list, surface_form, u_closed, v_closed, self_intersect,
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
  let u_mults = parse_int_list(parts[0])
  let v_mults = parse_int_list(parts[1])
  let u_knots = parse_literal_list(parts[2])
  let v_knots = parse_literal_list(parts[3])
  let knot_spec = parts[4].trim().to_string()
  @geometry.BSplineSurfaceWithKnots::new(
    u_mults, v_mults, u_knots, v_knots, knot_spec,
  )
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
  let trim_1 = parts[2].trim().to_string()
  let trim_2 = parts[3].trim().to_string()
  let sense_str = parts[4].trim().to_string()
  let sense = if sense_str == ".T." {
    true
  } else if sense_str == ".F." {
    false
  } else {
    fail_parse()
  }
  let master_rep = parts[5].trim().to_string()
  @geometry.TrimmedCurve::new(
    name,
    @step.Ref::{ id: basis_id },
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
  @geometry.OffsetCurve3D::new(name, @step.Ref::{ id: basis_id }, distance, @step.Ref::{
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
  let si_str = parts[3].trim().to_string()
  let self_intersect = if si_str == ".T." {
    true
  } else if si_str == ".F." {
    false
  } else {
    fail_parse()
  }
  @geometry.OffsetSurface::new(
    name,
    @step.Ref::{ id: basis_id },
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
  @geometry.SurfaceOfLinearExtrusion::new(name, @step.Ref::{ id: curve_id }, @step.Ref::{
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
  @geometry.SurfaceOfRevolution::new(name, @step.Ref::{ id: curve_id }, @step.Ref::{
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
  @geometry.SweptSurface::new(name, @step.Ref::{ id: curve_id })
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
  let u1 = parts[2].trim().to_string()
  let u2 = parts[3].trim().to_string()
  let v1 = parts[4].trim().to_string()
  let v2 = parts[5].trim().to_string()
  let usense_str = parts[6].trim().to_string()
  let usense = if usense_str == ".T." {
    true
  } else if usense_str == ".F." {
    false
  } else {
    fail_parse()
  }
  let vsense_str = parts[7].trim().to_string()
  let vsense = if vsense_str == ".T." {
    true
  } else if vsense_str == ".F." {
    false
  } else {
    fail_parse()
  }
  @geometry.RectangularTrimmedSurface::new(
    name,
    @step.Ref::{ id: basis_id },
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

///|
fn parse_boolean_result(
  args : String,
) -> @geometry.BooleanResult raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let op_str = parts[1].trim().to_string()
  let operator = match @geometry.BooleanOperator::from_string(op_str) {
    Some(op) => op
    None => fail_parse()
  }
  let op1_id = parse_ref_int(parts[2])
  let op2_id = parse_ref_int(parts[3])
  @geometry.BooleanResult::new(name, operator, @step.Ref::{ id: op1_id }, @step.Ref::{
    id: op2_id,
  })
}

///|
fn parse_csg_solid(args : String) -> @geometry.CsgSolid raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let root_id = parse_ref_int(parts[1])
  @geometry.CsgSolid::new(name, @step.Ref::{ id: root_id })
}

///|
fn parse_block(args : String) -> @geometry.Block raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 5 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let pos_id = parse_ref_int(parts[1])
  let x = parse_double(parts[2])
  let y = parse_double(parts[3])
  let z = parse_double(parts[4])
  @geometry.Block::new(name, @step.Ref::{ id: pos_id }, x, y, z)
}

///|
fn parse_sphere(args : String) -> @geometry.Sphere raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let pos_id = parse_ref_int(parts[1])
  let radius = parse_double(parts[2])
  @geometry.Sphere::new(name, @step.Ref::{ id: pos_id }, radius)
}

///|
fn parse_right_circular_cylinder(
  args : String,
) -> @geometry.RightCircularCylinder raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let pos_id = parse_ref_int(parts[1])
  let height = parse_double(parts[2])
  let radius = parse_double(parts[3])
  @geometry.RightCircularCylinder::new(
    name,
    @step.Ref::{ id: pos_id },
    height,
    radius,
  )
}

///|
fn parse_right_circular_cone(
  args : String,
) -> @geometry.RightCircularCone raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 5 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let pos_id = parse_ref_int(parts[1])
  let height = parse_double(parts[2])
  let radius = parse_double(parts[3])
  let semi_angle = parse_double(parts[4])
  @geometry.RightCircularCone::new(
    name,
    @step.Ref::{ id: pos_id },
    height,
    radius,
    semi_angle,
  )
}

///|
fn parse_torus(args : String) -> @geometry.Torus raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let pos_id = parse_ref_int(parts[1])
  let major = parse_double(parts[2])
  let minor = parse_double(parts[3])
  @geometry.Torus::new(name, @step.Ref::{ id: pos_id }, major, minor)
}

///|
fn parse_rectangular_pyramid(
  args : String,
) -> @geometry.RectangularPyramid raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 5 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let pos_id = parse_ref_int(parts[1])
  let x = parse_double(parts[2])
  let y = parse_double(parts[3])
  let height = parse_double(parts[4])
  @geometry.RectangularPyramid::new(
    name,
    @step.Ref::{ id: pos_id },
    x,
    y,
    height,
  )
}

///|
fn parse_right_angular_wedge(
  args : String,
) -> @geometry.RightAngularWedge raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 6 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let pos_id = parse_ref_int(parts[1])
  let x = parse_double(parts[2])
  let y = parse_double(parts[3])
  let z = parse_double(parts[4])
  let ltx = parse_double(parts[5])
  @geometry.RightAngularWedge::new(
    name,
    @step.Ref::{ id: pos_id },
    x,
    y,
    z,
    ltx,
  )
}

///|
fn parse_half_space_solid(
  args : String,
) -> @geometry.HalfSpaceSolid raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let surf_id = parse_ref_int(parts[1])
  let flag_str = parts[2].trim().to_string()
  let flag = if flag_str == ".T." {
    true
  } else if flag_str == ".F." {
    false
  } else {
    fail_parse()
  }
  @geometry.HalfSpaceSolid::new(name, @step.Ref::{ id: surf_id }, flag)
}

///|
fn parse_plane(args : String) -> @geometry.Plane raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let pos_id = parse_ref_int(parts[1])
  @geometry.Plane::new(name, @step.Ref::{ id: pos_id })
}

///|
fn parse_representation_relationship(
  args : String,
) -> @product.RepresentationRelationship raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let description = strip_quotes(parts[1])
  let rep_1_id = parse_ref_int(parts[2])
  let rep_2_id = parse_ref_int(parts[3])
  @product.RepresentationRelationship::new(
    name,
    description,
    @step.Ref::{ id: rep_1_id },
    @step.Ref::{ id: rep_2_id },
  )
}

///|
fn parse_representation_relationship_with_transformation(
  args : String,
) -> @product.RepresentationRelationshipWithTransformation raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 1 {
    fail_parse()
  }
  let t_id = parse_ref_int(parts[0])
  @product.RepresentationRelationshipWithTransformation::new(@step.Ref::{
    id: t_id,
  })
}

///|
fn parse_shape_representation_relationship(
  args : String,
) -> @product.ShapeRepresentationRelationship raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let description = strip_quotes(parts[1])
  let rep_1_id = parse_ref_int(parts[2])
  let rep_2_id = parse_ref_int(parts[3])
  @product.ShapeRepresentationRelationship::new(
    name,
    description,
    @step.Ref::{ id: rep_1_id },
    @step.Ref::{ id: rep_2_id },
  )
}

///|
fn parse_advanced_brep_shape_representation(
  args : String,
) -> @product.AdvancedBrepShapeRepresentation raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let item_ids = parse_ref_ids(parts[1])
  let items = item_ids.map(fn(id) { @step.Ref::{ id, } })
  let ctx_id = parse_ref_int(parts[2])
  @product.AdvancedBrepShapeRepresentation::new(name, items, @step.Ref::{
    id: ctx_id,
  })
}

///|
fn parse_shape_definition_representation(
  args : String,
) -> @product.ShapeDefinitionRepresentation raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let def_id = parse_ref_int(parts[0])
  let rep_id = parse_ref_int(parts[1])
  @product.ShapeDefinitionRepresentation::new(@step.Ref::{ id: def_id }, @step.Ref::{
    id: rep_id,
  })
}

///|
fn parse_shape_representation(
  args : String,
) -> @product.ShapeRepresentation raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let item_ids = parse_ref_ids(parts[1])
  let items = item_ids.map(fn(id) { @step.Ref::{ id, } })
  let ctx_id = parse_ref_int(parts[2])
  @product.ShapeRepresentation::new(name, items, @step.Ref::{ id: ctx_id })
}

///|
fn parse_representation(
  args : String,
) -> @product.Representation raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let item_ids = parse_ref_ids(parts[1])
  let items = item_ids.map(fn(id) { @step.Ref::{ id, } })
  let ctx_id = parse_ref_int(parts[2])
  @product.Representation::new(name, items, @step.Ref::{ id: ctx_id })
}

///|
fn parse_descriptive_representation_item(
  args : String,
) -> @product.DescriptiveRepresentationItem raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse_msg(
      "DESCRIPTIVE_REPRESENTATION_ITEM expected 2 args, got " +
      Int::to_string(parts.length()) +
      ": " +
      args,
    )
  }
  // Use proper STEP string unescaping so roundtrip is stable for values
  // containing doubled quotes (''), semicolons, or comment-like sequences.
  let name = parse_step_string_or_strip(parts[0])
  let description = parse_step_string_or_strip(parts[1])
  @product.DescriptiveRepresentationItem::new(name, description)
}

///|
fn parse_measure_representation_item(
  args : String,
) -> @product.MeasureRepresentationItem raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let value_component_str = parts[1].trim().to_string()
  let value_component = if String::has_prefix(
      value_component_str, "POSITIVE_RATIO_MEASURE",
    ) {
    // Looks like: POSITIVE_RATIO_MEASURE(7850.)
    // Keep the inner literal as raw string to preserve formatting.
    let args_part = substr(
      value_component_str,
      "POSITIVE_RATIO_MEASURE".length(),
      value_component_str.length(),
    )
    let inner = strip_outer_parens(args_part).trim().to_string()
    @product.MeasureValueComponent::PositiveRatioMeasure(
      @units.PositiveRatioMeasure::new(inner),
    )
  } else {
    @product.MeasureValueComponent::Raw(value_component_str)
  }
  let unit_id = parse_ref_int(parts[2])
  @product.MeasureRepresentationItem::new(name, value_component, @step.Ref::{
    id: unit_id,
  })
}

///|
fn parse_context_dependent_shape_representation(
  args : String,
) -> @product.ContextDependentShapeRepresentation raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let rr_id = parse_ref_int(parts[0])
  let rpr_id = parse_ref_int(parts[1])
  @product.ContextDependentShapeRepresentation::new(@step.Ref::{ id: rr_id }, @step.Ref::{
    id: rpr_id,
  })
}

///|
fn parse_item_defined_transformation(
  args : String,
) -> @product.ItemDefinedTransformation raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let description = strip_quotes(parts[1])
  let i1_id = parse_ref_int(parts[2])
  let i2_id = parse_ref_int(parts[3])
  @product.ItemDefinedTransformation::new(
    name,
    description,
    @step.Ref::{ id: i1_id },
    @step.Ref::{ id: i2_id },
  )
}

///|
fn parse_next_assembly_usage_occurrence(
  args : String,
) -> @product.NextAssemblyUsageOccurrence raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 6 {
    fail_parse()
  }
  let id = strip_quotes(parts[0])
  let name = strip_quotes(parts[1])
  let description = strip_quotes(parts[2])
  let relating_id = parse_ref_int(parts[3])
  let related_id = parse_ref_int(parts[4])
  let designator = strip_quotes(parts[5])
  @product.NextAssemblyUsageOccurrence::new(
    id,
    name,
    description,
    @step.Ref::{ id: relating_id },
    @step.Ref::{ id: related_id },
    designator,
  )
}

///|
fn parse_product_definition_shape(
  args : String,
) -> @product.ProductDefinitionShape raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let description = strip_quotes(parts[1])
  let def_id = parse_ref_int(parts[2])
  @product.ProductDefinitionShape::new(name, description, @step.Ref::{
    id: def_id,
  })
}

///|
fn parse_product_definition(
  args : String,
) -> @product.ProductDefinition raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let id = strip_quotes(parts[0])
  let description = strip_quotes(parts[1])
  let formation_id = parse_ref_int(parts[2])
  let ctx_id = parse_ref_int(parts[3])
  @product.ProductDefinition::new(
    id,
    description,
    @step.Ref::{ id: formation_id },
    @step.Ref::{ id: ctx_id },
  )
}

///|
fn parse_product_definition_context(
  args : String,
) -> @product.ProductDefinitionContext raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let app_id = parse_ref_int(parts[1])
  let life_cycle_stage = strip_quotes(parts[2])
  @product.ProductDefinitionContext::new(
    name,
    @step.Ref::{ id: app_id },
    life_cycle_stage,
  )
}

///|
fn parse_product_definition_formation(
  args : String,
) -> @product.ProductDefinitionFormation raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let id = strip_quotes(parts[0])
  let description = strip_quotes(parts[1])
  let product_id = parse_ref_int(parts[2])
  @product.ProductDefinitionFormation::new(id, description, @step.Ref::{
    id: product_id,
  })
}

///|
fn parse_property_definition(
  args : String,
) -> @product.PropertyDefinition raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let description = strip_quotes(parts[1])
  let def_id = parse_ref_int(parts[2])
  @product.PropertyDefinition::new(name, description, @step.Ref::{ id: def_id })
}

///|
fn parse_property_definition_representation(
  args : String,
) -> @product.PropertyDefinitionRepresentation raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let def_id = parse_ref_int(parts[0])
  let rep_id = parse_ref_int(parts[1])
  @product.PropertyDefinitionRepresentation::new(@step.Ref::{ id: def_id }, @step.Ref::{
    id: rep_id,
  })
}

///|
fn parse_product_definition_formation_with_specified_source(
  args : String,
) -> @product.ProductDefinitionFormationWithSpecifiedSource raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let id = strip_quotes(parts[0])
  let description = strip_quotes(parts[1])
  let product_id = parse_ref_int(parts[2])
  let make_or_buy = parts[3].trim().to_string()
  // Enumeration like .NOT_KNOWN.
  if make_or_buy != ".NOT_KNOWN." &&
    make_or_buy != ".MAKE." &&
    make_or_buy != ".BUY." {
    fail_parse()
  }
  @product.ProductDefinitionFormationWithSpecifiedSource::new(
    id,
    description,
    @step.Ref::{ id: product_id },
    make_or_buy,
  )
}

///|
fn parse_product_related_product_category(
  args : String,
) -> @product.ProductRelatedProductCategory raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let description = strip_quotes(parts[1])
  let product_ids = parse_ref_ids(parts[2])
  let products = product_ids.map(fn(id) { @step.Ref::{ id, } })
  @product.ProductRelatedProductCategory::new(name, description, products)
}

///|
fn parse_product(args : String) -> @product.Product raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let id = strip_quotes(parts[1])
  let description = strip_quotes(parts[2])
  let ref_ids = parse_ref_ids(parts[3])
  let refs = ref_ids.map(fn(id) { @step.Ref::{ id, } })
  @product.Product::new(name, id, description, refs)
}

///|
fn parse_product_context(
  args : String,
) -> @product.ProductContext raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let frame_id = parse_ref_int(parts[1])
  let discipline_type = strip_quotes(parts[2])
  @product.ProductContext::new(
    name,
    @step.Ref::{ id: frame_id },
    discipline_type,
  )
}

///|
fn parse_application_protocol_definition(
  args : String,
) -> @product.ApplicationProtocolDefinition raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let status = strip_quotes(parts[0])
  let schema_name = strip_quotes(parts[1])
  let year = parse_int_dec(parts[2])
  let application_id = parse_ref_int(parts[3])
  @product.ApplicationProtocolDefinition::new(status, schema_name, year, @step.Ref::{
    id: application_id,
  })
}

///|
fn parse_application_context(
  args : String,
) -> @product.ApplicationContext raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 1 {
    fail_parse()
  }
  let application = strip_quotes(parts[0])
  @product.ApplicationContext::new(application)
}

///|
fn parse_approval(args : String) -> @product.Approval raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let status_id = parse_ref_int(parts[0])
  let level = strip_quotes(parts[1])
  @product.Approval::new(@step.Ref::{ id: status_id }, level)
}

///|
fn parse_approval_status(
  args : String,
) -> @product.ApprovalStatus raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 1 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  @product.ApprovalStatus::new(name)
}

///|
fn parse_approval_role(
  args : String,
) -> @product.ApprovalRole raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 1 {
    fail_parse()
  }
  let role = strip_quotes(parts[0])
  @product.ApprovalRole::new(role)
}

///|
fn parse_approval_person_organization(
  args : String,
) -> @product.ApprovalPersonOrganization raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let po_id = parse_ref_int(parts[0])
  let approval_id = parse_ref_int(parts[1])
  let role_id = parse_ref_int(parts[2])
  @product.ApprovalPersonOrganization::new(
    @step.Ref::{ id: po_id },
    @step.Ref::{ id: approval_id },
    @step.Ref::{ id: role_id },
  )
}

///|
fn parse_person(args : String) -> @product.Person raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 6 {
    fail_parse()
  }
  let id = strip_quotes(parts[0])
  let last = strip_quotes(parts[1])
  let first = strip_quotes(parts[2])
  let middles = parse_literal_list(parts[3])
  let prefixes = parse_literal_list(parts[4])
  let suffixes = parse_literal_list(parts[5])
  @product.Person::new(id, last, first, middles, prefixes, suffixes)
}

///|
fn parse_organization(
  args : String,
) -> @product.Organization raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let id = strip_quotes(parts[0])
  let name = strip_quotes(parts[1])
  let desc = strip_quotes(parts[2])
  @product.Organization::new(id, name, desc)
}

///|
fn parse_person_and_organization(
  args : String,
) -> @product.PersonAndOrganization raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let person_id = parse_ref_int(parts[0])
  let org_id = parse_ref_int(parts[1])
  @product.PersonAndOrganization::new(@step.Ref::{ id: person_id }, @step.Ref::{
    id: org_id,
  })
}

///|
fn parse_date_and_time(
  args : String,
) -> @product.DateAndTime raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let date_id = parse_ref_int(parts[0])
  let time_id = parse_ref_int(parts[1])
  @product.DateAndTime::new(@step.Ref::{ id: date_id }, @step.Ref::{
    id: time_id,
  })
}

///|
fn parse_local_time(args : String) -> @product.LocalTime raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let hour = parse_int_dec(parts[0])
  let minute = parse_int_dec(parts[1])
  let second = parse_double(parts[2])
  let zone_id = parse_ref_int(parts[3])
  @product.LocalTime::new(hour, minute, second, @step.Ref::{ id: zone_id })
}

///|
fn parse_calendar_date(
  args : String,
) -> @product.CalendarDate raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let year = parse_int_dec(parts[0])
  let day = parse_int_dec(parts[1])
  let month = parse_int_dec(parts[2])
  @product.CalendarDate::new(year, day, month)
}

///|
fn parse_coordinated_universal_time_offset(
  args : String,
) -> @product.CoordinatedUniversalTimeOffset raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let hour = parse_int_dec(parts[0])
  let minute = parse_int_dec(parts[1])
  let sense = parts[2].trim().to_string()
  @product.CoordinatedUniversalTimeOffset::new(hour, minute, sense)
}

///|
fn parse_security_classification(
  args : String,
) -> @product.SecurityClassification raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let purpose = strip_quotes(parts[1])
  let level_id = parse_ref_int(parts[2])
  @product.SecurityClassification::new(name, purpose, @step.Ref::{
    id: level_id,
  })
}

///|
fn parse_security_classification_level(
  args : String,
) -> @product.SecurityClassificationLevel raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 1 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  @product.SecurityClassificationLevel::new(name)
}

///|
fn parse_certification(
  args : String,
) -> @product.Certification raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let purpose = strip_quotes(parts[1])
  let kind_id = parse_ref_int(parts[2])
  @product.Certification::new(name, purpose, @step.Ref::{ id: kind_id })
}

///|
fn parse_certification_type(
  args : String,
) -> @product.CertificationType raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 1 {
    fail_parse()
  }
  let desc = strip_quotes(parts[0])
  @product.CertificationType::new(desc)
}

///|
fn parse_document(args : String) -> @product.Document raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let id = strip_quotes(parts[0])
  let name = strip_quotes(parts[1])
  let description = strip_quotes(parts[2])
  let kind_id = parse_ref_int(parts[3])
  @product.Document::new(id, name, description, @step.Ref::{ id: kind_id })
}

///|
fn parse_document_reference(
  args : String,
) -> @product.DocumentReference raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let id = strip_quotes(parts[0])
  let name = strip_quotes(parts[1])
  let description = strip_quotes(parts[2])
  let doc_id = parse_ref_int(parts[3])
  @product.DocumentReference::new(id, name, description, @step.Ref::{
    id: doc_id,
  })
}

///|
fn parse_document_type(
  args : String,
) -> @product.DocumentType raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 1 {
    fail_parse()
  }
  let desc = strip_quotes(parts[0])
  @product.DocumentType::new(desc)
}

///|
fn parse_kinematic_link(
  args : String,
) -> @kinematics.KinematicLink raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 1 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  @kinematics.KinematicLink::new(name)
}

///|
fn parse_kinematic_joint(
  args : String,
) -> @kinematics.KinematicJoint raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let l1_id = parse_ref_int(parts[1])
  let l2_id = parse_ref_int(parts[2])
  @kinematics.KinematicJoint::new(name, @step.Ref::{ id: l1_id }, @step.Ref::{
    id: l2_id,
  })
}

///|
fn parse_kinematic_pair(
  args : String,
) -> @kinematics.KinematicPair raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let desc = strip_quotes(parts[1])
  let joint_id = parse_ref_int(parts[2])
  @kinematics.KinematicPair::new(name, desc, @step.Ref::{ id: joint_id })
}

///|
fn parse_geometric_tolerance(
  args : String,
) -> @tolerancing.GeometricTolerance raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let desc = strip_quotes(parts[1])
  let mag_id = parse_ref_int(parts[2])
  let shape_id = parse_ref_int(parts[3])
  @tolerancing.GeometricTolerance::new(name, desc, @step.Ref::{ id: mag_id }, @step.Ref::{
    id: shape_id,
  })
}

///|
fn parse_manifold_solid_brep(
  args : String,
) -> @topology.ManifoldSolidBrep raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let outer_id = parse_ref_int(parts[1])
  @topology.ManifoldSolidBrep::new(name, @step.Ref::{ id: outer_id })
}

///|
fn parse_closed_shell(
  args : String,
) -> @topology.ClosedShell raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let face_ids = parse_ref_ids(parts[1])
  let faces = face_ids.map(fn(id) { @step.Ref::{ id, } })
  @topology.ClosedShell::new(name, faces)
}

///|
fn parse_open_shell(args : String) -> @topology.OpenShell raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let face_ids = parse_ref_ids(parts[1])
  let faces = face_ids.map(fn(id) { @step.Ref::{ id, } })
  @topology.OpenShell::new(name, faces)
}

///|
fn parse_connected_face_set(
  args : String,
) -> @topology.ConnectedFaceSet raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let face_ids = parse_ref_ids(parts[1])
  let faces = face_ids.map(fn(id) { @step.Ref::{ id, } })
  @topology.ConnectedFaceSet::new(name, faces)
}

///|
fn parse_face_surface(
  args : String,
) -> @topology.FaceSurface raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let bound_ids = parse_ref_ids(parts[1])
  let bounds = bound_ids.map(fn(id) { @step.Ref::{ id, } })
  let geom_id = parse_ref_int(parts[2])
  let ss_str = parts[3].trim().to_string()
  let same_sense = if ss_str == ".T." {
    true
  } else if ss_str == ".F." {
    false
  } else {
    fail_parse()
  }
  @topology.FaceSurface::new(
    name,
    bounds,
    @step.Ref::{ id: geom_id },
    same_sense,
  )
}

///|
fn parse_subface(args : String) -> @topology.Subface raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let bound_ids = parse_ref_ids(parts[1])
  let bounds = bound_ids.map(fn(id) { @step.Ref::{ id, } })
  let parent_id = parse_ref_int(parts[2])
  @topology.Subface::new(name, bounds, @step.Ref::{ id: parent_id })
}

///|
fn parse_shape_aspect(
  args : String,
) -> @product.ShapeAspect raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let desc = strip_quotes(parts[1])
  let shape_id = parse_ref_int(parts[2])
  let definitional = parts[3].trim().to_string()
  @product.ShapeAspect::new(
    name,
    desc,
    @step.Ref::{ id: shape_id },
    definitional,
  )
}

///|
fn parse_shell_based_surface_model(
  args : String,
) -> @topology.ShellBasedSurfaceModel raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let bound_ids = parse_ref_ids(parts[1])
  let bounds = bound_ids.map(fn(id) { @step.Ref::{ id, } })
  @topology.ShellBasedSurfaceModel::new(name, bounds)
}

///|
fn parse_advanced_face(
  args : String,
) -> @topology.AdvancedFace raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let bound_ids = parse_ref_ids(parts[1])
  let bounds = bound_ids.map(fn(id) { @step.Ref::{ id, } })
  let surface_id = parse_ref_int(parts[2])
  let ss = parts[3].trim().to_string()
  let same_sense = if ss == ".T." {
    true
  } else if ss == ".F." {
    false
  } else {
    fail_parse()
  }
  @topology.AdvancedFace::new(
    name,
    bounds,
    @step.Ref::{ id: surface_id },
    same_sense,
  )
}

///|
fn parse_face_outer_bound(
  args : String,
) -> @topology.FaceOuterBound raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let bound_id = parse_ref_int(parts[1])
  let ori_str = parts[2].trim().to_string()
  let orientation = if ori_str == ".T." {
    true
  } else if ori_str == ".F." {
    false
  } else {
    fail_parse()
  }
  @topology.FaceOuterBound::new(name, @step.Ref::{ id: bound_id }, orientation)
}

///|
fn parse_face_bound(args : String) -> @topology.FaceBound raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let bound_id = parse_ref_int(parts[1])
  let ori_str = parts[2].trim().to_string()
  let orientation = if ori_str == ".T." {
    true
  } else if ori_str == ".F." {
    false
  } else {
    fail_parse()
  }
  @topology.FaceBound::new(name, @step.Ref::{ id: bound_id }, orientation)
}

///|
fn parse_edge_loop(args : String) -> @topology.EdgeLoop raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let edge_ids = parse_ref_ids(parts[1])
  let edges = edge_ids.map(fn(id) { @step.Ref::{ id, } })
  @topology.EdgeLoop::new(name, edges)
}

///|
fn parse_oriented_edge(
  args : String,
) -> @topology.OrientedEdge raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 5 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let edge_start = parts[1].trim().to_string()
  let edge_end = parts[2].trim().to_string()
  let edge_element_id = parse_ref_int(parts[3])
  let ori_str = parts[4].trim().to_string()
  let orientation = if ori_str == ".T." {
    true
  } else if ori_str == ".F." {
    false
  } else {
    fail_parse()
  }
  @topology.OrientedEdge::new(
    name,
    edge_start,
    edge_end,
    @step.Ref::{ id: edge_element_id },
    orientation,
  )
}

///|
fn parse_edge_curve(args : String) -> @topology.EdgeCurve raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 5 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let start_id = parse_ref_int(parts[1])
  let end_id = parse_ref_int(parts[2])
  let geom_id = parse_ref_int(parts[3])
  let ss_str = parts[4].trim().to_string()
  let same_sense = if ss_str == ".T." {
    true
  } else if ss_str == ".F." {
    false
  } else {
    fail_parse()
  }
  @topology.EdgeCurve::new(
    name,
    @step.Ref::{ id: start_id },
    @step.Ref::{ id: end_id },
    @step.Ref::{ id: geom_id },
    same_sense,
  )
}

///|
fn parse_vertex_point(
  args : String,
) -> @topology.VertexPoint raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let geom_id = parse_ref_int(parts[1])
  @topology.VertexPoint::new(name, @step.Ref::{ id: geom_id })
}

///|
fn parse_color_rgb(
  args : String,
) -> @presentation.ColorRgb raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let r = parse_double(parts[1])
  let g = parse_double(parts[2])
  let b = parse_double(parts[3])
  @presentation.ColorRgb::new(name, r, g, b)
}

///|
fn parse_draughting_pre_defined_colour(
  args : String,
) -> @presentation.DraughtingPreDefinedColour raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 1 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  @presentation.DraughtingPreDefinedColour::new(name)
}

///|
fn parse_ref_ids(arg : String) -> Array[@step.EntityId] raise StepParseError {
  split_args(arg).map(parse_ref_int)
}

///|
fn parse_surface_side(s : String) -> String raise StepParseError {
  let t = s.trim().to_string()
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
  @presentation.FillAreaStyleColor::new(name, @step.Ref::{ id: color_id })
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
  @presentation.SurfaceStyleFillArea::new(@step.Ref::{ id: fa_id })
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
  @presentation.SurfaceStyleUsage::new(side, @step.Ref::{ id: style_id })
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
  let path_str = parts[4].trim().to_string()
  let path = match @presentation.TextPath::from_string(path_str) {
    Some(p) => p
    None => fail_parse()
  }
  let font_id = parse_ref_int(parts[5])
  @presentation.TextLiteral::new(
    name,
    literal,
    @step.Ref::{ id: placement_id },
    alignment,
    path,
    @step.Ref::{ id: font_id },
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
    @step.Ref::{ id: ctx_id },
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
  @presentation.StyledItem::new(name, styles, @step.Ref::{ id: item_id })
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
    @step.Ref::{ id: item_id },
    @step.Ref::{ id: over_id },
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
    @step.Ref::{ id: item_id },
    @step.Ref::{ id: over_id },
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
  let t = arg.trim().to_string()
  if !t.has_prefix("LENGTH_MEASURE(") {
    fail_parse()
  }
  if t.length() < 16 || !t.has_suffix(")") {
    fail_parse()
  }
  // Inner literal (preserve scientific notation like `2.E-005`).
  // "LENGTH_MEASURE(" is 15 chars; the opening paren is index 14.
  substr(t, 15, t.length() - 1).trim().to_string()
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
    @step.Ref::{ id: unit_id },
    name,
    description,
  )
}

///|
fn parse_plane_angle_measure_literal(
  arg : String,
) -> String raise StepParseError {
  let t = arg.trim().to_string()
  if !t.has_prefix("PLANE_ANGLE_MEASURE(") {
    fail_parse()
  }
  if t.length() < 22 || !t.has_suffix(")") {
    fail_parse()
  }
  // Inner literal (preserve formatting).
  // "PLANE_ANGLE_MEASURE(" is 20 chars.
  substr(t, 20, t.length() - 1).trim().to_string()
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
  @units.DerivedUnitElement::new(@step.Ref::{ id: unit_id }, exponent)
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
  let val = parts[0].trim().to_string()
  let unit_id = parse_ref_int(parts[1])
  @units.MeasureWithUnit::new(val, @step.Ref::{ id: unit_id })
}

///|
fn split_complex_parts(body : String) -> Array[String] {
  // Split on newlines only when not inside nested parentheses or strings.
  let out : Array[String] = []
  let mut depth = 0
  let mut in_str = false
  let mut skip_quote = false
  let mut start = 0
  for i in 0..<body.length() {
    let ci = cu_at(body, i)
    if ci == Char::to_int('\'') {
      if skip_quote {
        skip_quote = false
      } else if in_str {
        if i + 1 < body.length() && cu_at(body, i + 1) == Char::to_int('\'') {
          skip_quote = true
        } else {
          in_str = false
        }
      } else {
        in_str = true
      }
    } else if !in_str {
      if ci == Char::to_int('(') {
        depth = depth + 1
      } else if ci == Char::to_int(')') {
        if depth > 0 {
          depth = depth - 1
        }
      } else if (ci == Char::to_int('\n') || ci == Char::to_int('\r')) &&
        depth == 0 {
        // Some STEP writers break a complex part like:
        //   REPRESENTATION_CONTEXT
        //   ('Context #1', ...)
        // In that case, the newline is NOT a separator between parts.
        let mut j = i + 1
        while j < body.length() {
          let cj = cu_at(body, j)
          if cj == Char::to_int(' ') ||
            cj == Char::to_int('\t') ||
            cj == Char::to_int('\n') ||
            cj == Char::to_int('\r') {
            j = j + 1
          } else {
            break
          }
        }
        let next_is_lparen = j < body.length() &&
          cu_at(body, j) == Char::to_int('(')
        if !next_is_lparen {
          let part = substr(body, start, i).trim().to_string()
          if part.length() > 0 {
            out.push(part)
          }
          start = i + 1
        }
      }
    }
  }
  if start <= body.length() {
    let part = substr(body, start, body.length()).trim().to_string()
    if part.length() > 0 {
      out.push(part)
    }
  }
  out
}

///|
fn strip_outer_parens(arg : String) -> String raise StepParseError {
  let t = arg.trim().to_string()
  if t.length() < 2 ||
    cu_at(t, 0) != Char::to_int('(') ||
    cu_at(t, t.length() - 1) != Char::to_int(')') {
    fail_parse()
  }
  substr(t, 1, t.length() - 1)
}

///|
fn expect_empty_parens(arg : String) -> Unit raise StepParseError {
  let inner = strip_outer_parens(arg).trim().to_string()
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
  let t = args.trim().to_string()
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
    let name = substr(s, 0, lp_idx).trim().to_string()
    let a = substr(s, lp_idx, s.length()).trim().to_string()
    if name == "GEOMETRIC_REPRESENTATION_CONTEXT" {
      let inner_args = strip_outer_parens(a)
      let dim = parse_int_dec(inner_args.trim().to_string())
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
      let inner_args = strip_outer_parens(a).trim().to_string()
      @context.ComplexPart::NamedUnit(@units.NamedUnit::new(inner_args))
    } else if name == "SI_UNIT" {
      let inner_args = strip_outer_parens(a)
      let args_parts = split_args(inner_args)
      if args_parts.length() != 2 {
        fail_parse()
      }
      let prefix = args_parts[0].trim().to_string()
      let si_name = args_parts[1].trim().to_string()
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
        @units.ConversionBasedUnit::new(unit_name, @step.Ref::{ id: factor_id }),
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
          @step.Ref::{ id: rep_1_id },
          @step.Ref::{ id: rep_2_id },
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
      @context.ComplexPart::RepresentationItem(inner_args.trim().to_string())
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
) -> (Int?, Int?) {
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
fn line_slice_at(s : String, idx : Int) -> String {
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
  quote_idx : Int,
) -> T raise StepParseError {
  let (line, col) = index_to_line_col(content, quote_idx)
  let stmt = line_slice_at(content, quote_idx)
  fail_parse_at("unterminated STEP string literal", line, col, stmt)
}

///|
fn index_to_line_col(s : String, idx : Int) -> (Int, Int) {
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
) -> (String, Int, Int) raise StepParseError {
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
  Some(substr(tail, 0, end_idx_local).trim().to_string())
}

///|
fn parse_step_string_literal(s : String) -> String? {
  let t = s.trim().to_string()
  if t.length() >= 2 &&
    cu_at(t, 0) == Char::to_int('\'') &&
    cu_at(t, t.length() - 1) == Char::to_int('\'') {
    let inner = substr(t, 1, t.length() - 1)
    let builder = StringBuilder::new()
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
  let t = arg.trim().to_string()
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
  let t = arg.trim().to_string()
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
        let name = substr(stmt, 0, j).trim().to_string()
        let args = substr(stmt, j, stmt.length()).trim().to_string()
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
fn bytes_ascii_to_string_preserve(ascii : Bytes) -> String {
  let builder = StringBuilder::new()
  for byte in ascii {
    // STEP files are typically ASCII; preserve CR/LF/tab literally.
    builder.write_char(byte.to_int().unsafe_to_char())
  }
  builder.to_string()
}

///|
// Async entrypoint: read a STEP file and parse it into a Repository.
// Uses moonbitlang/async for file I/O.
pub async fn parse_repository_from_file(
  path : StringView,
) -> @repository.Repository raise Error {
  let content_bytes = @fs.read_file(path)
  let content = bytes_ascii_to_string_preserve(content_bytes.binary())
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
