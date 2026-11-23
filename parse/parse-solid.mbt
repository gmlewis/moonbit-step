///|
fn parse_boolean_result(
  args : String,
) -> @geometry.BooleanResult raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let op_str = parts[1].trim().to_owned()
  let operator = match @geometry.BooleanOperator::from_string(op_str) {
    Some(op) => op
    None => fail_parse()
  }
  let op1_id = parse_ref_int(parts[2])
  let op2_id = parse_ref_int(parts[3])
  @geometry.BooleanResult::new(name, operator, @step.Ref::{ id: op1_id, }, @step.Ref::{
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
  @geometry.CsgSolid::new(name, @step.Ref::{ id: root_id, })
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
  @geometry.Block::new(name, @step.Ref::{ id: pos_id, }, x, y, z)
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
  @geometry.Sphere::new(name, @step.Ref::{ id: pos_id, }, radius)
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
    @step.Ref::{ id: pos_id, },
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
    @step.Ref::{ id: pos_id, },
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
  @geometry.Torus::new(name, @step.Ref::{ id: pos_id, }, major, minor)
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
    @step.Ref::{ id: pos_id, },
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
    @step.Ref::{ id: pos_id, },
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
  let flag = parse_step_bool(parts[2])
  @geometry.HalfSpaceSolid::new(name, @step.Ref::{ id: surf_id, }, flag)
}

///|
fn parse_plane(args : String) -> @geometry.Plane raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let pos_id = parse_ref_int(parts[1])
  @geometry.Plane::new(name, @step.Ref::{ id: pos_id, })
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
    @step.Ref::{ id: rep_1_id, },
    @step.Ref::{ id: rep_2_id, },
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
    @step.Ref::{ id: rep_1_id, },
    @step.Ref::{ id: rep_2_id, },
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
  @product.ShapeDefinitionRepresentation::new(@step.Ref::{ id: def_id, }, @step.Ref::{
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
  @product.ShapeRepresentation::new(name, items, @step.Ref::{ id: ctx_id, })
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
  @product.Representation::new(name, items, @step.Ref::{ id: ctx_id, })
}

///|
fn parse_descriptive_representation_item(
  args : String,
) -> @product.DescriptiveRepresentationItem raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse_msg(
      "DESCRIPTIVE_REPRESENTATION_ITEM expected 2 args, got " +
      Int32::to_string(parts.length()) +
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
  let value_component_str = parts[1].trim().to_owned()
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
    let inner = strip_outer_parens(args_part).trim().to_owned()
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
  @product.ContextDependentShapeRepresentation::new(@step.Ref::{ id: rr_id, }, @step.Ref::{
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
    @step.Ref::{ id: i1_id, },
    @step.Ref::{ id: i2_id, },
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
    @step.Ref::{ id: relating_id, },
    @step.Ref::{ id: related_id, },
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
    @step.Ref::{ id: formation_id, },
    @step.Ref::{ id: ctx_id, },
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
    @step.Ref::{ id: app_id, },
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
  @product.PropertyDefinition::new(name, description, @step.Ref::{ id: def_id, })
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
  @product.PropertyDefinitionRepresentation::new(@step.Ref::{ id: def_id, }, @step.Ref::{
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
  let make_or_buy = parts[3].trim().to_owned()
  // Enumeration like .NOT_KNOWN.
  if make_or_buy != ".NOT_KNOWN." &&
    make_or_buy != ".MAKE." &&
    make_or_buy != ".BUY." {
    fail_parse()
  }
  @product.ProductDefinitionFormationWithSpecifiedSource::new(
    id,
    description,
    @step.Ref::{ id: product_id, },
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
    @step.Ref::{ id: frame_id, },
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
  @product.Approval::new(@step.Ref::{ id: status_id, }, level)
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
    @step.Ref::{ id: po_id, },
    @step.Ref::{ id: approval_id, },
    @step.Ref::{ id: role_id, },
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
  @product.PersonAndOrganization::new(@step.Ref::{ id: person_id, }, @step.Ref::{
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
  @product.DateAndTime::new(@step.Ref::{ id: date_id, }, @step.Ref::{
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
  @product.LocalTime::new(hour, minute, second, @step.Ref::{ id: zone_id, })
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
  let sense = parts[2].trim().to_owned()
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
  @product.Certification::new(name, purpose, @step.Ref::{ id: kind_id, })
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
  @product.Document::new(id, name, description, @step.Ref::{ id: kind_id, })
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
  @kinematics.KinematicJoint::new(name, @step.Ref::{ id: l1_id, }, @step.Ref::{
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
  @kinematics.KinematicPair::new(name, desc, @step.Ref::{ id: joint_id, })
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
  @tolerancing.GeometricTolerance::new(name, desc, @step.Ref::{ id: mag_id, }, @step.Ref::{
    id: shape_id,
  })
}

///|
fn parse_datum(args : String) -> @tolerancing.Datum raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 5 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let desc = strip_quotes(parts[1])
  let shape_id = parse_ref_int(parts[2])
  let definitional = parts[3].trim().to_owned()
  let identification = strip_quotes(parts[4])
  @tolerancing.Datum::new(
    name,
    desc,
    @step.Ref::{ id: shape_id, },
    definitional,
    identification,
  )
}

///|
fn parse_datum_feature(
  args : String,
) -> @tolerancing.DatumFeature raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 4 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let desc = strip_quotes(parts[1])
  let shape_id = parse_ref_int(parts[2])
  let definitional = parts[3].trim().to_owned()
  @tolerancing.DatumFeature::new(
    name,
    desc,
    @step.Ref::{ id: shape_id, },
    definitional,
  )
}

///|
fn parse_dimensional_size(
  args : String,
) -> @tolerancing.DimensionalSize raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 2 {
    fail_parse()
  }
  let shape_id = parse_ref_int(parts[0])
  let name = strip_quotes(parts[1])
  @tolerancing.DimensionalSize::new(@step.Ref::{ id: shape_id, }, name)
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
  @topology.ManifoldSolidBrep::new(name, @step.Ref::{ id: outer_id, })
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
  let same_sense = parse_step_bool(parts[3])
  @topology.FaceSurface::new(
    name,
    bounds,
    @step.Ref::{ id: geom_id, },
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
  @topology.Subface::new(name, bounds, @step.Ref::{ id: parent_id, })
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
  let definitional = parts[3].trim().to_owned()
  @product.ShapeAspect::new(
    name,
    desc,
    @step.Ref::{ id: shape_id, },
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
  let same_sense = parse_step_bool(parts[3])
  @topology.AdvancedFace::new(
    name,
    bounds,
    @step.Ref::{ id: surface_id, },
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
  let orientation = parse_step_bool(parts[2])
  @topology.FaceOuterBound::new(name, @step.Ref::{ id: bound_id, }, orientation)
}

///|
fn parse_face_bound(args : String) -> @topology.FaceBound raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 3 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  let bound_id = parse_ref_int(parts[1])
  let orientation = parse_step_bool(parts[2])
  @topology.FaceBound::new(name, @step.Ref::{ id: bound_id, }, orientation)
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
  let edge_start = parts[1].trim().to_owned()
  let edge_end = parts[2].trim().to_owned()
  let edge_element_id = parse_ref_int(parts[3])
  let orientation = parse_step_bool(parts[4])
  @topology.OrientedEdge::new(
    name,
    edge_start,
    edge_end,
    @step.Ref::{ id: edge_element_id, },
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
  let same_sense = parse_step_bool(parts[4])
  @topology.EdgeCurve::new(
    name,
    @step.Ref::{ id: start_id, },
    @step.Ref::{ id: end_id, },
    @step.Ref::{ id: geom_id, },
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
  @topology.VertexPoint::new(name, @step.Ref::{ id: geom_id, })
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
fn parse_draughting_pre_defined_color(
  args : String,
) -> @presentation.DraughtingPreDefinedColour raise StepParseError {
  let parts = split_args(args)
  if parts.length() != 1 {
    fail_parse()
  }
  let name = strip_quotes(parts[0])
  @presentation.DraughtingPreDefinedColour::new(name)
}
