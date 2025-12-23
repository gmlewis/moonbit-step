///|
test "color_rgb_to_step" {
  let c = ColorRgb::new("Orange", 1.0, 0.6, 0.0)
  inspect(@step.Entity::to_step(c), content="COLOUR_RGB('Orange',1.0,0.6,0.0)")
}

///|
test "draughting_pre_defined_colour_to_step" {
  let c = DraughtingPreDefinedColour::new("red")
  inspect(
    @step.Entity::to_step(c),
    content="DRAUGHTING_PRE_DEFINED_COLOUR('red')",
  )
}

///|
test "fill_area_style_color_to_step" {
  let c = FillAreaStyleColor::new("", @step.Ref::{
    id: @step.EntityId::{ value: 31 },
  })
  inspect(@step.Entity::to_step(c), content="FILL_AREA_STYLE_COLOUR('',#31)")
}

///|
test "fill_area_style_to_step" {
  let s = FillAreaStyle::new("", [
    @step.Ref::{ id: @step.EntityId::{ value: 30 } },
  ])
  inspect(@step.Entity::to_step(s), content="FILL_AREA_STYLE('',(#30))")
}

///|
test "surface_style_fill_area_to_step" {
  let s = SurfaceStyleFillArea::new(@step.Ref::{
    id: @step.EntityId::{ value: 29 },
  })
  inspect(@step.Entity::to_step(s), content="SURFACE_STYLE_FILL_AREA(#29)")
}

///|
test "surface_side_style_to_step" {
  let s = SurfaceSideStyle::new("", [
    @step.Ref::{ id: @step.EntityId::{ value: 28 } },
  ])
  inspect(@step.Entity::to_step(s), content="SURFACE_SIDE_STYLE('',(#28))")
}

///|
test "surface_style_usage_to_step" {
  let s = SurfaceStyleUsage::new(".BOTH.", @step.Ref::{
    id: @step.EntityId::{ value: 27 },
  })
  inspect(@step.Entity::to_step(s), content="SURFACE_STYLE_USAGE(.BOTH.,#27)")
}

///|
test "presentation_style_assignment_to_step" {
  let p = PresentationStyleAssignment::new([
    @step.Ref::{ id: @step.EntityId::{ value: 26 } },
  ])
  inspect(
    @step.Entity::to_step(p),
    content="PRESENTATION_STYLE_ASSIGNMENT((#26))",
  )
}

///|
test "styled_item_to_step" {
  let s = StyledItem::new(
    "",
    [@step.Ref::{ id: @step.EntityId::{ value: 25 } }],
    @step.Ref::{ id: @step.EntityId::{ value: 32 } },
  )
  inspect(@step.Entity::to_step(s), content="STYLED_ITEM('',(#25),#32)")
}

///|
test "over_riding_styled_item_to_step" {
  let s = OverRidingStyledItem::new(
    "",
    [@step.Ref::{ id: @step.EntityId::{ value: 25 } }],
    @step.Ref::{ id: @step.EntityId::{ value: 32 } },
    @step.Ref::{ id: @step.EntityId::{ value: 33 } },
  )
  inspect(
    @step.Entity::to_step(s),
    content="OVER_RIDING_STYLED_ITEM('',(#25),#32,#33)",
  )
}

///|
test "hidden_element_over_riding_styled_item_to_step" {
  let s = HiddenElementOverRidingStyledItem::new(
    "",
    [@step.Ref::{ id: @step.EntityId::{ value: 25 } }],
    @step.Ref::{ id: @step.EntityId::{ value: 32 } },
    @step.Ref::{ id: @step.EntityId::{ value: 33 } },
  )
  inspect(
    @step.Entity::to_step(s),
    content="HIDDEN_ELEMENT_OVER_RIDING_STYLED_ITEM('',(#25),#32,#33)",
  )
}

///|
test "annotation_occurrence_to_step" {
  let s = AnnotationOccurrence::new(
    "",
    [@step.Ref::{ id: @step.EntityId::{ value: 25 } }],
    @step.Ref::{ id: @step.EntityId::{ value: 32 } },
  )
  inspect(
    @step.Entity::to_step(s),
    content="ANNOTATION_OCCURRENCE('',(#25),#32)",
  )
}

///|
test "presentation_layer_assignment_to_step" {
  let p = PresentationLayerAssignment::new("1", "Layer 1", [
    @step.Ref::{ id: @step.EntityId::{ value: 32 } },
  ])
  inspect(
    @step.Entity::to_step(p),
    content="PRESENTATION_LAYER_ASSIGNMENT('1','Layer 1',(#32))",
  )
}

///|
test "md_geom_presrep_to_step" {
  let r = MechanicalDesignGeometricPresentationRepresentation::new(
    "",
    [@step.Ref::{ id: @step.EntityId::{ value: 24 } }],
    @step.Ref::{ id: @step.EntityId::{ value: 187 } },
  )
  inspect(
    @step.Entity::to_step(r),
    content="MECHANICAL_DESIGN_GEOMETRIC_PRESENTATION_REPRESENTATION('',(#24),#187)",
  )
}
