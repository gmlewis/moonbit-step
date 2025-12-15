///|
test "measure_representation_item to_step" {
  let unit = @step.Ref::{ id: @step.EntityId::{ value: 589 } }
  let entity = MeasureRepresentationItem::new(
    "density measure",
    MeasureValueComponent::PositiveRatioMeasure(
      @units.PositiveRatioMeasure::new("7850."),
    ),
    unit,
  )
  inspect(
    entity.to_step(),
    content="MEASURE_REPRESENTATION_ITEM('density measure',POSITIVE_RATIO_MEASURE(7850.),#589)",
  )
}
