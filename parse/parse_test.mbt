///|
test "parse_repository_from_string_minimal" {
  let content = "ISO-10303-21;\nDATA;\n#10=CARTESIAN_POINT('CP1',(1.0,2.0,3.0));\n#11=DIRECTION('DIR1',(0.0,0.0,1.0));\n#12=AXIS2_PLACEMENT_3D('A2P3D',#10,#11,#11);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="3")

  // Roundtrip the parsed entities back to STEP-style lines.
  inspect(
    repo.to_step_data_section(),
    content="#10=CARTESIAN_POINT('CP1',(1.0,2.0,3.0));\n#11=DIRECTION('DIR1',(0.0,0.0,1.0));\n#12=AXIS2_PLACEMENT_3D('A2P3D',#10, #11, #11);",
  )
}

///|
test "parse_repository_from_string_result_ok" {
  let content = "ISO-10303-21;\nDATA;\n#10=CARTESIAN_POINT('CP1',(1.0,2.0,3.0));\nENDSEC;\nEND-ISO-10303-21;\n"
  let res = parse_repository_from_string_result(content)
  match res {
    ParseRepositoryResult::Ok(repo) => inspect(repo.len(), content="1")
    ParseRepositoryResult::Err(info) =>
      fail("unexpected parse error: " + format_step_parse_error(info))
  }
}

///|
test "parse_repository_from_string_result_err" {
  // Missing '=' after the id.
  let content = "ISO-10303-21;\nDATA;\n#10CARTESIAN_POINT('CP1',(1.0,2.0,3.0));\nENDSEC;\nEND-ISO-10303-21;\n"
  let res = parse_repository_from_string_result(content)
  match res {
    ParseRepositoryResult::Ok(_) => fail("expected parse failure")
    ParseRepositoryResult::Err(info) => {
      let msg = format_step_parse_error(info)
      assert_true(msg.length() > 0)
    }
  }
}

///|
test "parse_error_reports_file_line_col_for_data" {
  // The invalid statement is on line 3, col 1 of the full file.
  let content = "ISO-10303-21;\nDATA;\n#2FOO('B');\nENDSEC;\nEND-ISO-10303-21;\n"
  match parse_repository_from_string_result(content) {
    ParseRepositoryResult::Ok(_) => fail("expected parse failure")
    ParseRepositoryResult::Err(info) => {
      match (info.line, info.col) {
        (Some(3), Some(1)) => ()
        _ => fail("expected file position @3:1")
      }
      let msg = format_step_parse_error(info)
      assert_true(msg.contains("@3:1"))
      assert_true(msg.contains("missing '='"))
      // Caret points at the likely missing '=' location in the statement.
      assert_true(msg.contains("\n    ^"))
      assert_true(msg.contains("Hint:"))
    }
  }
}

///|
test "unterminated_comment_is_reported" {
  let content = "ISO-10303-21;\n/* unterminated comment\nDATA;\n#1=FOO('A');\nENDSEC;\nEND-ISO-10303-21;\n"
  match parse_repository_from_string_result(content) {
    ParseRepositoryResult::Ok(_) => fail("expected parse failure")
    ParseRepositoryResult::Err(info) => {
      let msg = format_step_parse_error(info)
      assert_true(msg.contains("unterminated"))
      assert_true(msg.contains("comment"))
      assert_true(msg.contains("Hint:"))
    }
  }
}

///|
test "unterminated_string_is_reported" {
  let content = "ISO-10303-21;\nDATA;\n#1=FOO('unterminated);\nENDSEC;\nEND-ISO-10303-21;\n"
  match parse_repository_from_string_result(content) {
    ParseRepositoryResult::Ok(_) => fail("expected parse failure")
    ParseRepositoryResult::Err(info) => {
      let msg = format_step_parse_error(info)
      assert_true(msg.contains("unterminated"))
      assert_true(msg.contains("string"))
      assert_true(msg.contains("Hint:"))
    }
  }
}

///|
test "comments_can_contain_semicolons_and_keywords" {
  let content = "ISO-10303-21;\n" +
    "DATA;\n" +
    "#1=FOO('A');/* comment with ; and ENDSEC; and DATA; */#2=BAR('B');\n" +
    "ENDSEC;\n" +
    "END-ISO-10303-21;\n"
  match parse_repository_from_string_result(content) {
    ParseRepositoryResult::Err(info) =>
      fail("unexpected parse error: " + format_step_parse_error(info))
    ParseRepositoryResult::Ok(repo) => {
      inspect(repo.len(), content="2")
      let out = repo.to_step_data_section()
      assert_true(out.contains("#1=FOO('A');"))
      assert_true(out.contains("#2=BAR('B');"))
    }
  }
}

///|
test "comment_like_sequences_inside_strings_are_preserved" {
  let content = "ISO-10303-21;\n" +
    "DATA;\n" +
    "#1=FOO('/* not a comment; ENDSEC; */');\n" +
    "ENDSEC;\n" +
    "END-ISO-10303-21;\n"
  match parse_repository_from_string_result(content) {
    ParseRepositoryResult::Err(info) =>
      fail("unexpected parse error: " + format_step_parse_error(info))
    ParseRepositoryResult::Ok(repo) => {
      let out = repo.to_step_data_section()
      assert_true(out.contains("'/* not a comment; ENDSEC; */'"))
    }
  }
}

///|
test "parse_repository_from_string_header_and_file_roundtrip" {
  let content = "ISO-10303-21;\nHEADER;\nFILE_DESCRIPTION(('Example header'),'2;1');\nFILE_NAME('test.step','2025-01-01T00:00:00',('Alice'),('ACME'),'pp','sys','auth');\nFILE_SCHEMA(('CONFIG_CONTROL_DESIGN'));\nENDSEC;\nDATA;\n#10=CARTESIAN_POINT('CP1',(1.0,2.0,3.0));\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let header_out = repo.get_header().to_step_header_section()
  assert_true(
    header_out.contains("FILE_DESCRIPTION(('Example header'),'2;1');"),
  )
  assert_true(
    header_out.contains(
      "FILE_NAME('test.step','2025-01-01T00:00:00',('Alice'),('ACME'),'pp','sys','auth');",
    ),
  )
  assert_true(header_out.contains("FILE_SCHEMA(('CONFIG_CONTROL_DESIGN'));"))
  let file_out = repo.to_step_file()
  assert_true(file_out.contains("ISO-10303-21;"))
  assert_true(file_out.contains("HEADER;"))
  assert_true(file_out.contains("DATA;"))
  assert_true(file_out.contains("END-ISO-10303-21;"))
  assert_true(file_out.contains("#10=CARTESIAN_POINT('CP1',(1.0,2.0,3.0));"))
}

///|
test "parse_repository_from_string_preserves_unknown_data_entities" {
  let content = "ISO-10303-21;\nDATA;\n#5=FOO_BAR(1,$,'X');\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#5=FOO_BAR(1,$,'X');"))
}

///|
test "parse_repository_from_string_shape_representation_relationship" {
  let content = "ISO-10303-21;\nDATA;\n#10=SHAPE_REPRESENTATION_RELATIONSHIP('None','relationship between cube-None and cube-None',#22,#11);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(
    out.contains(
      "#10=SHAPE_REPRESENTATION_RELATIONSHIP('None','relationship between cube-None and cube-None',#22,#11);",
    ),
  )
}

///|
test "parse_repository_from_string_complex_rel_parts" {
  let content = "ISO-10303-21;\nDATA;\n#187=(\nREPRESENTATION_RELATIONSHIP('','',#40,#10)\nREPRESENTATION_RELATIONSHIP_WITH_TRANSFORMATION(#435)\nSHAPE_REPRESENTATION_RELATIONSHIP()\n);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let e = repo.get(@step.EntityId::{ value: 187 })
  match e {
    Some(@repository.AnyEntity::ComplexInstance(ci)) => {
      inspect(ci.parts.length(), content="3")
      match ci.parts[0] {
        @context.ComplexPart::RepRel(_) => ()
        _ => fail_parse()
      }
      match ci.parts[1] {
        @context.ComplexPart::RepRelWT(_) => ()
        _ => fail_parse()
      }
      match ci.parts[2] {
        @context.ComplexPart::ShapeRepRel => ()
        _ => fail_parse()
      }
    }
    _ => fail_parse()
  }
}

///|
test "parse_repository_from_string_representation_relationship" {
  let content = "ISO-10303-21;\nDATA;\n#40=REPRESENTATION_RELATIONSHIP('','',#1,#2);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#40=REPRESENTATION_RELATIONSHIP('','',#1,#2);"))
}

///|
test "parse_repository_from_string_representation_relationship_with_transformation" {
  let content = "ISO-10303-21;\nDATA;\n#41=REPRESENTATION_RELATIONSHIP_WITH_TRANSFORMATION(#435);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(
    out.contains("#41=REPRESENTATION_RELATIONSHIP_WITH_TRANSFORMATION(#435);"),
  )
}

///|
test "parse_repository_from_string_polyline" {
  let content = "ISO-10303-21;\nDATA;\n#10=POLYLINE('poly',(#1,#2,#3));\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#10=POLYLINE('poly',(#1,#2,#3));"))
}

///|
test "parse_repository_from_string_boolean_result" {
  let content = "ISO-10303-21;\nDATA;\n#10=BOOLEAN_RESULT('result',.UNION.,#20,#30);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#10=BOOLEAN_RESULT('result',.UNION.,#20,#30);"))
}

///|
test "parse_repository_from_string_csg_solid" {
  let content = "ISO-10303-21;\nDATA;\n#10=CSG_SOLID('solid',#20);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#10=CSG_SOLID('solid',#20);"))
}

///|
test "parse_repository_from_string_csg_primitives" {
  let content = "ISO-10303-21;\nDATA;\n#1=BLOCK('b',#10,1.,2.,3.);\n#2=SPHERE('s',#10,5.);\n#3=RIGHT_CIRCULAR_CYLINDER('cyl',#10,50.,10.);\n#4=RIGHT_CIRCULAR_CONE('cone',#10,50.,10.,0.5);\n#5=TORUS('t',#10,20.,5.);\n#6=RECTANGULAR_PYRAMID('p',#10,10.0,20.0,30.0);\n#7=RIGHT_ANGULAR_WEDGE('w',#10,10.0,20.0,30.0,5.0);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="7")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#1=BLOCK('b',#10,1.0,2.0,3.0);"))
  assert_true(out.contains("#2=SPHERE('s',#10,5.0);"))
  assert_true(out.contains("#3=RIGHT_CIRCULAR_CYLINDER('cyl',#10,50.0,10.0);"))
  assert_true(out.contains("#4=RIGHT_CIRCULAR_CONE('cone',#10,50.0,10.0,0.5);"))
  assert_true(out.contains("#5=TORUS('t',#10,20.0,5.0);"))
  assert_true(out.contains("#6=RECTANGULAR_PYRAMID('p',#10,10.0,20.0,30.0);"))
  assert_true(
    out.contains("#7=RIGHT_ANGULAR_WEDGE('w',#10,10.0,20.0,30.0,5.0);"),
  )
}

///|
test "parse_repository_from_string_half_space_solid" {
  let content = "ISO-10303-21;\nDATA;\n#1=HALF_SPACE_SOLID('hs',#10,.T.);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#1=HALF_SPACE_SOLID('hs',#10,.T.);"))
}

///|
test "parse_repository_from_string_advanced_brep_shape_representation" {
  let content = "ISO-10303-21;\nDATA;\n#11=ADVANCED_BREP_SHAPE_REPRESENTATION('cube-None',(#32),#187);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(
    out.contains(
      "#11=ADVANCED_BREP_SHAPE_REPRESENTATION('cube-None',(#32),#187);",
    ),
  )
}

///|
test "parse_repository_from_string_open_shell" {
  let content = "ISO-10303-21;\nDATA;\n#10=OPEN_SHELL('open',(#1,#2));\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#10=OPEN_SHELL('open',(#1,#2));"))
}

///|
test "parse_repository_from_string_connected_face_set" {
  let content = "ISO-10303-21;\nDATA;\n#10=CONNECTED_FACE_SET('cfs',(#1,#2));\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#10=CONNECTED_FACE_SET('cfs',(#1,#2));"))
}

///|
test "parse_repository_from_string_shell_based_surface_model" {
  let content = "ISO-10303-21;\nDATA;\n#10=SHELL_BASED_SURFACE_MODEL('model',(#1,#2));\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#10=SHELL_BASED_SURFACE_MODEL('model',(#1,#2));"))
}

///|
test "parse_repository_from_string_face_surface" {
  let content = "ISO-10303-21;\nDATA;\n#10=FACE_SURFACE('face',(#1,#2),#3,.T.);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#10=FACE_SURFACE('face',(#1,#2),#3,.T.);"))
}

///|
test "parse_repository_from_string_subface" {
  let content = "ISO-10303-21;\nDATA;\n#10=SUBFACE('sub',(#1,#2),#3);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#10=SUBFACE('sub',(#1,#2),#3);"))
}

///|
test "parse_repository_from_string_approval" {
  let content = "ISO-10303-21;\nDATA;\n#1=APPROVAL_STATUS('approved');\n#2=APPROVAL(#1,'level');\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="2")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#1=APPROVAL_STATUS('approved');"))
  assert_true(out.contains("#2=APPROVAL(#1,'level');"))
}

///|
test "parse_repository_from_string_approval_person_org" {
  let content = "ISO-10303-21;\nDATA;\n#1=PERSON('p1','Doe','John',('M'),('Mr'),('Jr'));\n#2=ORGANIZATION('o1','ACME','Acme Corp');\n#3=PERSON_AND_ORGANIZATION(#1,#2);\n#4=APPROVAL_STATUS('approved');\n#5=APPROVAL(#4,'level');\n#6=APPROVAL_ROLE('approver');\n#7=APPROVAL_PERSON_ORGANIZATION(#3,#5,#6);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="7")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#1=PERSON('p1','Doe','John',('M'),('Mr'),('Jr'));"))
  assert_true(out.contains("#2=ORGANIZATION('o1','ACME','Acme Corp');"))
  assert_true(out.contains("#3=PERSON_AND_ORGANIZATION(#1,#2);"))
  assert_true(out.contains("#4=APPROVAL_STATUS('approved');"))
  assert_true(out.contains("#5=APPROVAL(#4,'level');"))
  assert_true(out.contains("#6=APPROVAL_ROLE('approver');"))
  assert_true(out.contains("#7=APPROVAL_PERSON_ORGANIZATION(#3,#5,#6);"))
}

///|
test "parse_repository_from_string_date_time" {
  let content = "ISO-10303-21;\nDATA;\n#1=CALENDAR_DATE(2025,22,12);\n#2=COORDINATED_UNIVERSAL_TIME_OFFSET(0,0,.EXACT.);\n#3=LOCAL_TIME(12,30,0.0,#2);\n#4=DATE_AND_TIME(#1,#3);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="4")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#1=CALENDAR_DATE(2025,22,12);"))
  assert_true(
    out.contains("#2=COORDINATED_UNIVERSAL_TIME_OFFSET(0,0,.EXACT.);"),
  )
  assert_true(out.contains("#3=LOCAL_TIME(12,30,0.0,#2);"))
  assert_true(out.contains("#4=DATE_AND_TIME(#1,#3);"))
}

///|
test "parse_repository_from_string_security" {
  let content = "ISO-10303-21;\nDATA;\n#1=SECURITY_CLASSIFICATION_LEVEL('top secret');\n#2=SECURITY_CLASSIFICATION('sc','confidential',#1);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="2")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#1=SECURITY_CLASSIFICATION_LEVEL('top secret');"))
  assert_true(
    out.contains("#2=SECURITY_CLASSIFICATION('sc','confidential',#1);"),
  )
}

///|
test "parse_repository_from_string_certification" {
  let content = "ISO-10303-21;\nDATA;\n#1=CERTIFICATION_TYPE('kind');\n#2=CERTIFICATION('cert','purpose',#1);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="2")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#1=CERTIFICATION_TYPE('kind');"))
  assert_true(out.contains("#2=CERTIFICATION('cert','purpose',#1);"))
}

///|
test "parse_repository_from_string_document" {
  let content = "ISO-10303-21;\nDATA;\n#1=DOCUMENT_TYPE('kind');\n#2=DOCUMENT('d1','name','desc',#1);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="2")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#1=DOCUMENT_TYPE('kind');"))
  assert_true(out.contains("#2=DOCUMENT('d1','name','desc',#1);"))
}

///|
test "parse_repository_from_string_doc_ref" {
  let content = "ISO-10303-21;\nDATA;\n#1=DOCUMENT_TYPE('kind');\n#2=DOCUMENT('d1','name','desc',#1);\n#3=DOCUMENT_REFERENCE('dr1','ref','ref_desc',#2);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="3")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#1=DOCUMENT_TYPE('kind');"))
  assert_true(out.contains("#2=DOCUMENT('d1','name','desc',#1);"))
  assert_true(out.contains("#3=DOCUMENT_REFERENCE('dr1','ref','ref_desc',#2);"))
}

///|
test "parse_repository_from_string_draughting_pre_defined_colour" {
  let content = "ISO-10303-21;\nDATA;\n#1=DRAUGHTING_PRE_DEFINED_COLOUR('red');\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#1=DRAUGHTING_PRE_DEFINED_COLOUR('red');"))
}

///|
test "parse_repository_from_string_shape_definition_representation" {
  let content = "ISO-10303-21;\nDATA;\n#12=SHAPE_DEFINITION_REPRESENTATION(#13,#22);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#12=SHAPE_DEFINITION_REPRESENTATION(#13,#22);"))
}

///|
test "parse_repository_from_string_edge_curve" {
  let content = "ISO-10303-21;\nDATA;\n#90=EDGE_CURVE('',#82,#83,#102,.T.);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#90=EDGE_CURVE('',#82,#83,#102,.T.);"))
}

///|
test "parse_repository_from_string_face_bound" {
  let content = "ISO-10303-21;\nDATA;\n#125=FACE_BOUND('',#158,.T.);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#125=FACE_BOUND('',#158,.T.);"))
}

///|
test "parse_repository_from_string_vertex_point" {
  let content = "ISO-10303-21;\nDATA;\n#82=VERTEX_POINT('',#161);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#82=VERTEX_POINT('',#161);"))
}

///|
test "parse_repository_from_string_derived_unit_element" {
  let content = "ISO-10303-21;\nDATA;\n#586=DERIVED_UNIT_ELEMENT(#588,1.);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#586=DERIVED_UNIT_ELEMENT(#588,1.0);"))
}

///|
test "parse_repository_from_string_derived_unit" {
  let content = "ISO-10303-21;\nDATA;\n#589=DERIVED_UNIT((#586,#587));\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#589=DERIVED_UNIT((#586,#587));"))
}

///|
test "parse_repository_from_string_circle" {
  let content = "ISO-10303-21;\nDATA;\n#189=CIRCLE('',#600,0.435);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#189=CIRCLE('',#600,0.435);"))
}

///|
test "parse_repository_from_string_ellipse" {
  let content = "ISO-10303-21;\nDATA;\n#15=ELLIPSE('',#613,0.123303040813508,0.117733653429061);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(
    out.contains("#15=ELLIPSE('',#613,0.123303040813508,0.117733653429061);"),
  )
}

///|
test "parse_repository_from_string_parabola" {
  let content = "ISO-10303-21;\nDATA;\n#10=PARABOLA('par',#1,5.0);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#10=PARABOLA('par',#1,5.0);"))
}

///|
test "parse_repository_from_string_hyperbola" {
  let content = "ISO-10303-21;\nDATA;\n#10=HYPERBOLA('hyp',#1,10.0,5.0);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#10=HYPERBOLA('hyp',#1,10.0,5.0);"))
}

///|
test "parse_repository_from_string_cylindrical_surface" {
  let content = "ISO-10303-21;\nDATA;\n#123=CYLINDRICAL_SURFACE('',#602,0.435);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#123=CYLINDRICAL_SURFACE('',#602,0.435);"))
}

///|
test "parse_repository_from_string_conical_surface" {
  let content = "ISO-10303-21;\nDATA;\n#27=CONICAL_SURFACE('',#611,0.3500599520011,0.140686945962564);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(
    out.contains(
      "#27=CONICAL_SURFACE('',#611,0.3500599520011,0.140686945962564);",
    ),
  )
}

///|
test "parse_repository_from_string_toroidal_surface" {
  let content = "ISO-10303-21;\nDATA;\n#97=TOROIDAL_SURFACE('',#98,0.4,0.4);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#97=TOROIDAL_SURFACE('',#98,0.4,0.4);"))
}

///|
test "parse_repository_from_string_bspline_curve" {
  let content = "ISO-10303-21;\nDATA;\n#10=B_SPLINE_CURVE('curve',3,(#1,#2,#3,#4),.UNSPECIFIED.,.F.,.F.);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(
    out.contains(
      "#10=B_SPLINE_CURVE('curve',3,(#1,#2,#3,#4),.UNSPECIFIED.,.F.,.F.);",
    ),
  )
}

///|
test "parse_repository_from_string_b_spline_curve_with_knots" {
  let content = "ISO-10303-21;\nDATA;\n#39=B_SPLINE_CURVE_WITH_KNOTS('',3,(#10,#11,#12,#13),.UNSPECIFIED.,.F.,.F.,(4,4),(0.,1.),.UNSPECIFIED.);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(
    out.contains(
      "#39=B_SPLINE_CURVE_WITH_KNOTS('',3,(#10,#11,#12,#13),.UNSPECIFIED.,.F.,.F.,(4,4),(0.,1.),.UNSPECIFIED.);",
    ),
  )
}

///|
test "parse_repository_from_string_b_spline_surface_with_knots" {
  let content = "ISO-10303-21;\nDATA;\n#51=B_SPLINE_SURFACE_WITH_KNOTS((3,3),(3,2,3),(-0.1,0.2),(-3.14159,0.0,3.14159),.UNSPECIFIED.);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(
    out.contains(
      "#51=B_SPLINE_SURFACE_WITH_KNOTS((3,3),(3,2,3),(-0.1,0.2),(-3.14159,0.0,3.14159),.UNSPECIFIED.);",
    ),
  )
}

///|
test "parse_repository_from_string_complex_b_spline_surface_with_knots_part" {
  let content = "ISO-10303-21;\nDATA;\n#52=(\nB_SPLINE_SURFACE_WITH_KNOTS((3,3),(3,2,3),(-0.1,0.2),(-3.14159,0.0,3.14159),.UNSPECIFIED.)\n);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let e = repo.get(@step.EntityId::{ value: 52 })
  match e {
    Some(@repository.AnyEntity::ComplexInstance(ci)) => {
      inspect(ci.parts.length(), content="1")
      match ci.parts[0] {
        @context.ComplexPart::BSplineSurfKnots(_) => ()
        _ => fail_parse()
      }
    }
    _ => fail_parse()
  }
}

///|
test "parse_repository_from_string_rational_b_spline_surface" {
  let content = "ISO-10303-21;\nDATA;\n#53=RATIONAL_B_SPLINE_SURFACE(((1.,0.5,2.),(0.25,1.,0.25)));\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(
    out.contains("#53=RATIONAL_B_SPLINE_SURFACE(((1.,0.5,2.),(0.25,1.,0.25)));"),
  )
}

///|
test "parse_repository_from_string_complex_rational_b_spline_surface_part" {
  let content = "ISO-10303-21;\nDATA;\n#54=(\nRATIONAL_B_SPLINE_SURFACE(((1.,0.5,2.),(0.25,1.,0.25)))\n);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let e = repo.get(@step.EntityId::{ value: 54 })
  match e {
    Some(@repository.AnyEntity::ComplexInstance(ci)) => {
      inspect(ci.parts.length(), content="1")
      match ci.parts[0] {
        @context.ComplexPart::RatBSplineSurf(_) => ()
        _ => fail_parse()
      }
    }
    _ => fail_parse()
  }
}

///|
test "parse_repository_from_string_b_spline_surface" {
  let content = "ISO-10303-21;\nDATA;\n#55=B_SPLINE_SURFACE(2,2,((#1,#2),(#3,#4)),.UNSPECIFIED.,.F.,.F.,.F.);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(
    out.contains(
      "#55=B_SPLINE_SURFACE(2,2,((#1,#2),(#3,#4)),.UNSPECIFIED.,.F.,.F.,.F.);",
    ),
  )
}

///|
test "parse_repository_from_string_complex_b_spline_surface_part" {
  let content = "ISO-10303-21;\nDATA;\n#56=(\nB_SPLINE_SURFACE(2,2,((#1,#2),(#3,#4)),.UNSPECIFIED.,.F.,.F.,.F.)\n);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let e = repo.get(@step.EntityId::{ value: 56 })
  match e {
    Some(@repository.AnyEntity::ComplexInstance(ci)) => {
      inspect(ci.parts.length(), content="1")
      match ci.parts[0] {
        @context.ComplexPart::BSplineSurf(_) => ()
        _ => fail_parse()
      }
    }
    _ => fail_parse()
  }
}

///|
test "parse_repository_from_string_complex_marker_surface_chain_parts" {
  let content = "ISO-10303-21;\nDATA;\n#57=(\nREPRESENTATION_ITEM('')\nGEOMETRIC_REPRESENTATION_ITEM()\nSURFACE()\nBOUNDED_SURFACE()\n);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let e = repo.get(@step.EntityId::{ value: 57 })
  match e {
    Some(@repository.AnyEntity::ComplexInstance(ci)) => {
      inspect(ci.parts.length(), content="4")
      match ci.parts[0] {
        @context.ComplexPart::RepresentationItem("''") => ()
        _ => fail_parse()
      }
      match ci.parts[1] {
        @context.ComplexPart::GeometricRepresentationItem => ()
        _ => fail_parse()
      }
      match ci.parts[2] {
        @context.ComplexPart::Surface => ()
        _ => fail_parse()
      }
      match ci.parts[3] {
        @context.ComplexPart::BoundedSurface => ()
        _ => fail_parse()
      }
    }
    _ => fail_parse()
  }
}

///|
test "parse_repository_from_string_rational_b_spline_curve" {
  let content = "ISO-10303-21;\nDATA;\n#50=RATIONAL_B_SPLINE_CURVE((1.,0.5,2.));\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#50=RATIONAL_B_SPLINE_CURVE((1.,0.5,2.));"))
}

///|
test "parse_repository_from_string_complex_rational_b_spline_curve_part" {
  let content = "ISO-10303-21;\nDATA;\n#60=(\nRATIONAL_B_SPLINE_CURVE((1.,1.,1.))\n);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let e = repo.get(@step.EntityId::{ value: 60 })
  match e {
    Some(@repository.AnyEntity::ComplexInstance(ci)) => {
      inspect(ci.parts.length(), content="1")
      match ci.parts[0] {
        @context.ComplexPart::RatBSpline(_) => ()
        _ => fail_parse()
      }
    }
    _ => fail_parse()
  }
}

///|
test "parse_repository_from_string_trimmed_curve" {
  let content = "ISO-10303-21;\nDATA;\n#13=TRIMMED_CURVE('',#12,(PARAMETER_VALUE(0.0)),(PARAMETER_VALUE(1.0)),.T.,.PARAMETER.);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(
    out.contains(
      "#13=TRIMMED_CURVE('',#12,(PARAMETER_VALUE(0.0)),(PARAMETER_VALUE(1.0)),.T.,.PARAMETER.);",
    ),
  )
}

///|
test "parse_repository_from_string_offset_curve_3d" {
  let content = "ISO-10303-21;\nDATA;\n#10=OFFSET_CURVE_3D('off',#1,5.0,#2);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#10=OFFSET_CURVE_3D('off',#1,5.0,#2);"))
}

///|
test "parse_repository_from_string_offset_surface" {
  let content = "ISO-10303-21;\nDATA;\n#10=OFFSET_SURFACE('off_surf',#1,5.0,.F.);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#10=OFFSET_SURFACE('off_surf',#1,5.0,.F.);"))
}

///|
test "parse_repository_from_string_surface_of_linear_extrusion" {
  let content = "ISO-10303-21;\nDATA;\n#10=SURFACE_OF_LINEAR_EXTRUSION('swept',#1,#2);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#10=SURFACE_OF_LINEAR_EXTRUSION('swept',#1,#2);"))
}

///|
test "parse_repository_from_string_axis1_placement" {
  let content = "ISO-10303-21;\nDATA;\n#1=AXIS1_PLACEMENT('a1',#10,$);\n#2=AXIS1_PLACEMENT('a2',#10,#20);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="2")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#1=AXIS1_PLACEMENT('a1',#10,$);"))
  assert_true(out.contains("#2=AXIS1_PLACEMENT('a2',#10,#20);"))
}

///|
test "parse_repository_from_string_surface_of_revolution" {
  let content = "ISO-10303-21;\nDATA;\n#10=SURFACE_OF_REVOLUTION('rev',#1,#2);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#10=SURFACE_OF_REVOLUTION('rev',#1,#2);"))
}

///|
test "parse_repository_from_string_swept_surface" {
  let content = "ISO-10303-21;\nDATA;\n#10=SWEPT_SURFACE('swept',#1);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#10=SWEPT_SURFACE('swept',#1);"))
}

///|
test "parse_repository_from_string_rectangular_trimmed_surface" {
  let content = "ISO-10303-21;\nDATA;\n#200=RECTANGULAR_TRIMMED_SURFACE('',#12,0.0,1.0,-0.5,0.5,.T.,.T.);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(
    out.contains(
      "#200=RECTANGULAR_TRIMMED_SURFACE('',#12,0.0,1.0,-0.5,0.5,.T.,.T.);",
    ),
  )
}

///|
test "parse_repository_from_string_product_definition_shape" {
  let content = "ISO-10303-21;\nDATA;\n#13=PRODUCT_DEFINITION_SHAPE('','',#14);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#13=PRODUCT_DEFINITION_SHAPE('','',#14);"))
}

///|
test "parse_repository_from_string_product_definition" {
  let content = "ISO-10303-21;\nDATA;\n#14=PRODUCT_DEFINITION(' ','',#16,#15);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#14=PRODUCT_DEFINITION(' ','',#16,#15);"))
}

///|
test "parse_repository_from_string_product_definition_context" {
  let content = "ISO-10303-21;\nDATA;\n#15=PRODUCT_DEFINITION_CONTEXT('part definition',#21,'design');\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(
    out.contains(
      "#15=PRODUCT_DEFINITION_CONTEXT('part definition',#21,'design');",
    ),
  )
}

///|
test "parse_repository_from_string_product_definition_formation_with_specified_source" {
  let content = "ISO-10303-21;\nDATA;\n#16=PRODUCT_DEFINITION_FORMATION_WITH_SPECIFIED_SOURCE(' ',' ',#18,.NOT_KNOWN.);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(
    out.contains(
      "#16=PRODUCT_DEFINITION_FORMATION_WITH_SPECIFIED_SOURCE(' ',' ',#18,.NOT_KNOWN.);",
    ),
  )
}

///|
test "parse_repository_from_string_product_definition_formation" {
  let content = "ISO-10303-21;\nDATA;\n#1653=PRODUCT_DEFINITION_FORMATION('',$,#1658);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#1653=PRODUCT_DEFINITION_FORMATION('',$,#1658);"))
}

///|
test "parse_repository_from_string_descriptive_representation_item" {
  let content = "ISO-10303-21;\nDATA;\n#595=DESCRIPTIVE_REPRESENTATION_ITEM('Steel','Steel');\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(
    out.contains("#595=DESCRIPTIVE_REPRESENTATION_ITEM('Steel','Steel');"),
  )
}

///|
test "parse_repository_from_string_measure_representation_item" {
  let content = "ISO-10303-21;\nDATA;\n#590=MEASURE_REPRESENTATION_ITEM('density measure',\nPOSITIVE_RATIO_MEASURE(7850.),#589);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(
    out.contains(
      "#590=MEASURE_REPRESENTATION_ITEM('density measure',POSITIVE_RATIO_MEASURE(7850.),#589);",
    ),
  )
}

///|
test "parse_repository_from_string_measure_representation_item_typed_value" {
  let content = "ISO-10303-21;\nDATA;\n#590=MEASURE_REPRESENTATION_ITEM('density measure',POSITIVE_RATIO_MEASURE(7850.),#589);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  let e = repo.get(@step.EntityId::{ value: 590 })
  match e {
    Some(@repository.AnyEntity::MeasureRepresentationItem(mri)) =>
      match mri.value_component {
        @product.MeasureValueComponent::PositiveRatioMeasure(pm) =>
          inspect(
            @step.Entity::to_step(pm),
            content="POSITIVE_RATIO_MEASURE(7850.)",
          )
        _ => fail_parse()
      }
    _ => fail_parse()
  }
}

///|
test "parse_repository_from_string_representation" {
  let content = "ISO-10303-21;\nDATA;\n#593=REPRESENTATION('material name',(#595),#1642);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(
    out.contains("#593=REPRESENTATION('material name',(#595),#1642);"),
  )
}

///|
test "parse_repository_from_string_property_definition" {
  let content = "ISO-10303-21;\nDATA;\n#596=PROPERTY_DEFINITION('material property','material name',#1652);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(
    out.contains(
      "#596=PROPERTY_DEFINITION('material property','material name',#1652);",
    ),
  )
}

///|
test "parse_repository_from_string_property_definition_representation" {
  let content = "ISO-10303-21;\nDATA;\n#591=PROPERTY_DEFINITION_REPRESENTATION(#596,#593);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(
    out.contains("#591=PROPERTY_DEFINITION_REPRESENTATION(#596,#593);"),
  )
}

///|
test "parse_repository_from_string_item_defined_transformation" {
  let content = "ISO-10303-21;\nDATA;\n#435=ITEM_DEFINED_TRANSFORMATION('','',#11,#15);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#435=ITEM_DEFINED_TRANSFORMATION('','',#11,#15);"))
}

///|
test "parse_repository_from_string_context_dependent_shape_representation" {
  let content = "ISO-10303-21;\nDATA;\n#433=CONTEXT_DEPENDENT_SHAPE_REPRESENTATION(#434,#436);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(
    out.contains("#433=CONTEXT_DEPENDENT_SHAPE_REPRESENTATION(#434,#436);"),
  )
}

///|
test "parse_repository_from_string_next_assembly_usage_occurrence" {
  let content = "ISO-10303-21;\nDATA;\n#437=NEXT_ASSEMBLY_USAGE_OCCURRENCE('1','R2',$,#5,#35,$);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(
    out.contains("#437=NEXT_ASSEMBLY_USAGE_OCCURRENCE('1','R2',$,#5,#35,$);"),
  )
}

///|
test "parse_repository_from_string_product_related_product_category" {
  let content = "ISO-10303-21;\nDATA;\n#17=PRODUCT_RELATED_PRODUCT_CATEGORY('part','',(#18));\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(
    out.contains("#17=PRODUCT_RELATED_PRODUCT_CATEGORY('part','',(#18));"),
  )
}

///|
test "parse_repository_from_string_complex_instance_wrapper" {
  let content = "ISO-10303-21;\nDATA;\n#187=(\nGEOMETRIC_REPRESENTATION_CONTEXT(3)\nGLOBAL_UNCERTAINTY_ASSIGNED_CONTEXT((#188))\nGLOBAL_UNIT_ASSIGNED_CONTEXT((#194,#190,#189))\nREPRESENTATION_CONTEXT('cube','TOP_LEVEL_ASSEMBLY_PART')\n);\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="1")
  let out = repo.to_step_data_section()
  assert_true(out.contains("#187=("))
  assert_true(out.contains("GEOMETRIC_REPRESENTATION_CONTEXT(3)"))
  assert_true(out.contains("GLOBAL_UNCERTAINTY_ASSIGNED_CONTEXT((#188))"))
  assert_true(out.contains("GLOBAL_UNIT_ASSIGNED_CONTEXT((#194,#190,#189))"))
  assert_true(
    out.contains("REPRESENTATION_CONTEXT('cube','TOP_LEVEL_ASSEMBLY_PART')"),
  )
  assert_true(out.contains("\n)"))
}

///|
test "parse_repository_from_string_styled_item_chain" {
  let content = "ISO-10303-21;\nDATA;\n#31=COLOUR_RGB('Orange',1.,0.6,0.);\n#30=FILL_AREA_STYLE_COLOUR('',#31);\n#29=FILL_AREA_STYLE('',(#30));\n#28=SURFACE_STYLE_FILL_AREA(#29);\n#27=SURFACE_SIDE_STYLE('',(#28));\n#26=SURFACE_STYLE_USAGE(.BOTH.,#27);\n#25=PRESENTATION_STYLE_ASSIGNMENT((#26));\n#24=STYLED_ITEM('',(#25),#32);\n#23=PRESENTATION_LAYER_ASSIGNMENT('1','Layer 1',(#32));\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="9")
  let out = repo.to_step_data_section()
  let expect_lines = [
    "#31=COLOUR_RGB('Orange',1.0,0.6,0.0);", "#30=FILL_AREA_STYLE_COLOUR('',#31);",
    "#29=FILL_AREA_STYLE('',(#30));", "#28=SURFACE_STYLE_FILL_AREA(#29);", "#27=SURFACE_SIDE_STYLE('',(#28));",
    "#26=SURFACE_STYLE_USAGE(.BOTH.,#27);", "#25=PRESENTATION_STYLE_ASSIGNMENT((#26));",
    "#24=STYLED_ITEM('',(#25),#32);", "#23=PRESENTATION_LAYER_ASSIGNMENT('1','Layer 1',(#32));",
  ]
  let mut all_found = true
  for line in expect_lines {
    let found = match String::find(out, line) {
      Some(_) => true
      None => false
    }
    all_found = all_found && found
  }
  inspect(all_found, content="true")
}

///|
test "parse_repository_from_string_units_and_unit_wrappers" {
  let content = "ISO-10303-21;\nDATA;\n#191=DIMENSIONAL_EXPONENTS(0.,0.,0.,0.,0.,0.,0.);\n#192=PLANE_ANGLE_MEASURE_WITH_UNIT(PLANE_ANGLE_MEASURE(0.0174532925),#193);\n#193=(\nNAMED_UNIT(*)\nPLANE_ANGLE_UNIT()\nSI_UNIT($,.RADIAN.)\n);\n#194=(\nLENGTH_UNIT()\nNAMED_UNIT(*)\nSI_UNIT(.MILLI.,.METRE.)\n);\n#189=(\nNAMED_UNIT(*)\nSI_UNIT($,.STERADIAN.)\nSOLID_ANGLE_UNIT()\n);\n#190=(\nCONVERSION_BASED_UNIT('DEGREE',#192)\nNAMED_UNIT(#191)\nPLANE_ANGLE_UNIT()\n);\n#188=UNCERTAINTY_MEASURE_WITH_UNIT(LENGTH_MEASURE(2.E-005),#194,'DISTANCE_ACCURACY_VALUE','Maximum Tolerance applied to model');\nENDSEC;\nEND-ISO-10303-21;\n"
  let repo = parse_repository_from_string(content)
  inspect(repo.len(), content="7")
  let out = repo.to_step_data_section()
  let expect_lines = [
    "#191=DIMENSIONAL_EXPONENTS(0.0,0.0,0.0,0.0,0.0,0.0,0.0);", "#192=PLANE_ANGLE_MEASURE_WITH_UNIT(PLANE_ANGLE_MEASURE(0.0174532925),#193);",
    "#188=UNCERTAINTY_MEASURE_WITH_UNIT(LENGTH_MEASURE(2.E-005),#194,'DISTANCE_ACCURACY_VALUE','Maximum Tolerance applied to model');",
  ]
  let mut all_found = true
  for line in expect_lines {
    let found = match String::find(out, line) {
      Some(_) => true
      None => false
    }
    all_found = all_found && found
  }
  let has_193_wrap = match String::find(out, "#193=(") {
    Some(_) => true
    None => false
  }
  let has_194_wrap = match String::find(out, "#194=(") {
    Some(_) => true
    None => false
  }
  let has_radian = match String::find(out, "SI_UNIT($,.RADIAN.)") {
    Some(_) => true
    None => false
  }
  let has_milli_metre = match String::find(out, "SI_UNIT(.MILLI.,.METRE.)") {
    Some(_) => true
    None => false
  }
  let has_named_unit_star = match String::find(out, "NAMED_UNIT(*)") {
    Some(_) => true
    None => false
  }
  let has_plane_angle_unit = match String::find(out, "PLANE_ANGLE_UNIT()") {
    Some(_) => true
    None => false
  }
  let has_length_unit = match String::find(out, "LENGTH_UNIT()") {
    Some(_) => true
    None => false
  }
  let has_189_wrap = match String::find(out, "#189=(") {
    Some(_) => true
    None => false
  }
  let has_190_wrap = match String::find(out, "#190=(") {
    Some(_) => true
    None => false
  }
  let has_steradian = match String::find(out, "SI_UNIT($,.STERADIAN.)") {
    Some(_) => true
    None => false
  }
  let has_solid_angle_unit = match String::find(out, "SOLID_ANGLE_UNIT()") {
    Some(_) => true
    None => false
  }
  let has_degree = match
    String::find(out, "CONVERSION_BASED_UNIT('DEGREE',#192)") {
    Some(_) => true
    None => false
  }
  let has_named_unit_191 = match String::find(out, "NAMED_UNIT(#191)") {
    Some(_) => true
    None => false
  }
  inspect(
    all_found &&
    has_193_wrap &&
    has_194_wrap &&
    has_189_wrap &&
    has_190_wrap &&
    has_radian &&
    has_milli_metre &&
    has_steradian &&
    has_named_unit_star &&
    has_plane_angle_unit &&
    has_length_unit &&
    has_solid_angle_unit &&
    has_degree &&
    has_named_unit_191,
    content="true",
  )
}
