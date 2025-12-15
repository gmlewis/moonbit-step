///|
async test "can_parse_simple_box_from_file" {
  let repo = @parse.parse_repository_from_file("tests/testdata/simple-box.step")
  let repo_len = repo.len()
  let data_section = repo.to_step_data_section()
  inspect(repo_len > 0, content="true")
  let has_cartesian_point = match
    String::find(data_section, "CARTESIAN_POINT") {
    Some(_) => true
    None => false
  }
  let has_direction = match String::find(data_section, "DIRECTION") {
    Some(_) => true
    None => false
  }
  inspect(has_cartesian_point, content="true")
  inspect(has_direction, content="true")

  // Assert a specific known entity from the fixture is parsed.
  // From tests/testdata/simple-box.step:
  //   #133=DIRECTION('',(0.,0.,1.));
  // Our serializer normalizes numeric formatting to *.0 for integers.
  let has_direction_133 = match
    String::find(data_section, "#133=DIRECTION('',(0.0,0.0,1.0));") {
    Some(_) => true
    None => false
  }
  inspect(has_direction_133, content="true")

  // Fixture uses `AXIS2_PLACEMENT_3D`, and we serialize as `AXIS2_PLACEMENT_3D`.
  // From tests/testdata/simple-box.step:
  //   #126=AXIS2_PLACEMENT_3D('',#159,#133,#134);
  let has_axis2_126 = match
    String::find(data_section, "#126=AXIS2_PLACEMENT_3D('',#159, #133, #134);") {
    Some(_) => true
    None => false
  }
  inspect(has_axis2_126, content="true")

  // From tests/testdata/simple-box.step:
  //   #114=VECTOR('',#135,1.);
  let has_vector_114 = match
    String::find(data_section, "#114=VECTOR('',#135,1.0);") {
    Some(_) => true
    None => false
  }
  inspect(has_vector_114, content="true")

  // From tests/testdata/simple-box.step:
  //   #102=LINE('',#160,#114);
  let has_line_102 = match
    String::find(data_section, "#102=LINE('',#160,#114);") {
    Some(_) => true
    None => false
  }
  inspect(has_line_102, content="true")

  // From tests/testdata/simple-box.step:
  //   #40=PLANE('',#127);
  let has_plane_40 = match String::find(data_section, "#40=PLANE('',#127);") {
    Some(_) => true
    None => false
  }
  inspect(has_plane_40, content="true")

  // From tests/testdata/simple-box.step:
  //   #31=COLOUR_RGB('Orange',1.,0.6,0.);
  // Our serializer normalizes integers to *.0.
  let has_color_rgb_31 = match
    String::find(data_section, "#31=COLOUR_RGB('Orange',1.0,0.6,0.0);") {
    Some(_) => true
    None => false
  }
  inspect(has_color_rgb_31, content="true")

  // STYLED_ITEM chain (presentation) from tests/testdata/simple-box.step:
  //   #30=FILL_AREA_STYLE_COLOUR('',#31);
  let has_fill_area_style_colour_30 = match
    String::find(data_section, "#30=FILL_AREA_STYLE_COLOUR('',#31);") {
    Some(_) => true
    None => false
  }
  inspect(has_fill_area_style_colour_30, content="true")

  //   #29=FILL_AREA_STYLE('',(#30));
  let has_fill_area_style_29 = match
    String::find(data_section, "#29=FILL_AREA_STYLE('',(#30));") {
    Some(_) => true
    None => false
  }
  inspect(has_fill_area_style_29, content="true")

  //   #28=SURFACE_STYLE_FILL_AREA(#29);
  let has_surface_style_fill_area_28 = match
    String::find(data_section, "#28=SURFACE_STYLE_FILL_AREA(#29);") {
    Some(_) => true
    None => false
  }
  inspect(has_surface_style_fill_area_28, content="true")

  //   #27=SURFACE_SIDE_STYLE('',(#28));
  let has_surface_side_style_27 = match
    String::find(data_section, "#27=SURFACE_SIDE_STYLE('',(#28));") {
    Some(_) => true
    None => false
  }
  inspect(has_surface_side_style_27, content="true")

  //   #26=SURFACE_STYLE_USAGE(.BOTH.,#27);
  let has_surface_style_usage_26 = match
    String::find(data_section, "#26=SURFACE_STYLE_USAGE(.BOTH.,#27);") {
    Some(_) => true
    None => false
  }
  inspect(has_surface_style_usage_26, content="true")

  //   #25=PRESENTATION_STYLE_ASSIGNMENT((#26));
  let has_presentation_style_assignment_25 = match
    String::find(data_section, "#25=PRESENTATION_STYLE_ASSIGNMENT((#26));") {
    Some(_) => true
    None => false
  }
  inspect(has_presentation_style_assignment_25, content="true")

  //   #24=STYLED_ITEM('',(#25),#32);
  let has_styled_item_24 = match
    String::find(data_section, "#24=STYLED_ITEM('',(#25),#32);") {
    Some(_) => true
    None => false
  }
  inspect(has_styled_item_24, content="true")

  // From tests/testdata/simple-box.step:
  //   #23=PRESENTATION_LAYER_ASSIGNMENT('1','Layer 1',(#32));
  let has_presentation_layer_assignment_23 = match
    String::find(
      data_section, "#23=PRESENTATION_LAYER_ASSIGNMENT('1','Layer 1',(#32));",
    ) {
    Some(_) => true
    None => false
  }
  inspect(has_presentation_layer_assignment_23, content="true")

  // From tests/testdata/simple-box.step:
  //   #18=PRODUCT('cube','cube',' ',(#19));
  let has_product_18 = match
    String::find(data_section, "#18=PRODUCT('cube','cube',' ',(#19));") {
    Some(_) => true
    None => false
  }
  inspect(has_product_18, content="true")

  // From tests/testdata/simple-box.step:
  //   #19=PRODUCT_CONTEXT(' ',#21,'mechanical');
  let has_product_context_19 = match
    String::find(data_section, "#19=PRODUCT_CONTEXT(' ',#21,'mechanical');") {
    Some(_) => true
    None => false
  }
  inspect(has_product_context_19, content="true")

  // From tests/testdata/simple-box.step:
  //   #20=APPLICATION_PROTOCOL_DEFINITION('international standard',
  //   'automotive_design',2010,#21);
  let has_application_protocol_definition_20 = match
    String::find(
      data_section, "#20=APPLICATION_PROTOCOL_DEFINITION('international standard','automotive_design',2010,#21);",
    ) {
    Some(_) => true
    None => false
  }
  inspect(has_application_protocol_definition_20, content="true")

  // From tests/testdata/simple-box.step:
  //   #21=APPLICATION_CONTEXT('core data for automotive mechanical design processes');
  let has_application_context_21 = match
    String::find(
      data_section, "#21=APPLICATION_CONTEXT('core data for automotive mechanical design processes');",
    ) {
    Some(_) => true
    None => false
  }
  inspect(has_application_context_21, content="true")

  // From tests/testdata/simple-box.step:
  //   #22=SHAPE_REPRESENTATION('cube-None',(#126),#187);
  let has_shape_representation_22 = match
    String::find(
      data_section, "#22=SHAPE_REPRESENTATION('cube-None',(#126),#187);",
    ) {
    Some(_) => true
    None => false
  }
  inspect(has_shape_representation_22, content="true")

  // From tests/testdata/simple-box.step:
  //   #32=MANIFOLD_SOLID_BREP('',#33);
  let has_manifold_solid_brep_32 = match
    String::find(data_section, "#32=MANIFOLD_SOLID_BREP('',#33);") {
    Some(_) => true
    None => false
  }
  inspect(has_manifold_solid_brep_32, content="true")

  // From tests/testdata/simple-box.step:
  //   #33=CLOSED_SHELL('',(#34,#35,#36,#37,#38,#39));
  let has_closed_shell_33 = match
    String::find(
      data_section, "#33=CLOSED_SHELL('',(#34,#35,#36,#37,#38,#39));",
    ) {
    Some(_) => true
    None => false
  }
  inspect(has_closed_shell_33, content="true")

  // From tests/testdata/simple-box.step:
  //   #34=ADVANCED_FACE('',(#46),#40,.F.);
  let has_advanced_face_34 = match
    String::find(data_section, "#34=ADVANCED_FACE('',(#46),#40,.F.);") {
    Some(_) => true
    None => false
  }
  inspect(has_advanced_face_34, content="true")

  // From tests/testdata/simple-box.step:
  //   #38=ADVANCED_FACE('',(#50),#44,.T.);
  let has_advanced_face_38 = match
    String::find(data_section, "#38=ADVANCED_FACE('',(#50),#44,.T.);") {
    Some(_) => true
    None => false
  }
  inspect(has_advanced_face_38, content="true")

  // From tests/testdata/simple-box.step:
  //   #46=FACE_OUTER_BOUND('',#52,.T.);
  let has_face_outer_bound_46 = match
    String::find(data_section, "#46=FACE_OUTER_BOUND('',#52,.T.);") {
    Some(_) => true
    None => false
  }
  inspect(has_face_outer_bound_46, content="true")

  // From tests/testdata/simple-box.step:
  //   #52=EDGE_LOOP('',(#58,#59,#60,#61));
  let has_edge_loop_52 = match
    String::find(data_section, "#52=EDGE_LOOP('',(#58,#59,#60,#61));") {
    Some(_) => true
    None => false
  }
  inspect(has_edge_loop_52, content="true")

  // From tests/testdata/simple-box.step:
  //   #58=ORIENTED_EDGE('',*,*,#90,.T.);
  let has_oriented_edge_58 = match
    String::find(data_section, "#58=ORIENTED_EDGE('',*,*,#90,.T.);") {
    Some(_) => true
    None => false
  }
  inspect(has_oriented_edge_58, content="true")

  // From tests/testdata/simple-box.step:
  //   #90=EDGE_CURVE('',#82,#83,#102,.T.);
  let has_edge_curve_90 = match
    String::find(data_section, "#90=EDGE_CURVE('',#82,#83,#102,.T.);") {
    Some(_) => true
    None => false
  }
  inspect(has_edge_curve_90, content="true")

  // From tests/testdata/simple-box.step:
  //   #82=VERTEX_POINT('',#161);
  let has_vertex_point_82 = match
    String::find(data_section, "#82=VERTEX_POINT('',#161);") {
    Some(_) => true
    None => false
  }
  inspect(has_vertex_point_82, content="true")

  // From tests/testdata/simple-box.step:
  //   #186=MECHANICAL_DESIGN_GEOMETRIC_PRESENTATION_REPRESENTATION('',(#24),#187);
  let has_mechanical_design_geometric_presentation_representation_186 = match
    String::find(
      data_section, "#186=MECHANICAL_DESIGN_GEOMETRIC_PRESENTATION_REPRESENTATION('',(#24),#187);",
    ) {
    Some(_) => true
    None => false
  }
  inspect(
    has_mechanical_design_geometric_presentation_representation_186,
    content="true",
  )

  // From tests/testdata/simple-box.step:
  //   #191=DIMENSIONAL_EXPONENTS(0.,0.,0.,0.,0.,0.,0.);
  let has_dimensional_exponents_191 = match
    String::find(
      data_section, "#191=DIMENSIONAL_EXPONENTS(0.0,0.0,0.0,0.0,0.0,0.0,0.0);",
    ) {
    Some(_) => true
    None => false
  }
  inspect(has_dimensional_exponents_191, content="true")

  // From tests/testdata/simple-box.step:
  //   #188=UNCERTAINTY_MEASURE_WITH_UNIT(LENGTH_MEASURE(2.E-005),#194,
  //   'DISTANCE_ACCURACY_VALUE','Maximum Tolerance applied to model');
  let has_uncertainty_measure_with_unit_188 = match
    String::find(
      data_section, "#188=UNCERTAINTY_MEASURE_WITH_UNIT(LENGTH_MEASURE(2.E-005),#194,'DISTANCE_ACCURACY_VALUE','Maximum Tolerance applied to model');",
    ) {
    Some(_) => true
    None => false
  }
  inspect(has_uncertainty_measure_with_unit_188, content="true")

  // From tests/testdata/simple-box.step:
  //   #192=PLANE_ANGLE_MEASURE_WITH_UNIT(PLANE_ANGLE_MEASURE(0.0174532925),#193);
  let has_plane_angle_measure_with_unit_192 = match
    String::find(
      data_section, "#192=PLANE_ANGLE_MEASURE_WITH_UNIT(PLANE_ANGLE_MEASURE(0.0174532925),#193);",
    ) {
    Some(_) => true
    None => false
  }
  inspect(has_plane_angle_measure_with_unit_192, content="true")

  // From tests/testdata/simple-box.step:
  //   #187=(
  //     GEOMETRIC_REPRESENTATION_CONTEXT(3)
  //     ...
  //   );
  // We preserve complex entity instance wrappers as-is.
  let has_ctx_wrap_187_prefix = match String::find(data_section, "#187=(") {
    Some(_) => true
    None => false
  }
  inspect(has_ctx_wrap_187_prefix, content="true")
  let has_ctx_wrap_187_grc = match
    String::find(data_section, "GEOMETRIC_REPRESENTATION_CONTEXT(3)") {
    Some(_) => true
    None => false
  }
  inspect(has_ctx_wrap_187_grc, content="true")
}
