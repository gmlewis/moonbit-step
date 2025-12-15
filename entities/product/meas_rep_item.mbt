///|
// Represents a MEASURE_REPRESENTATION_ITEM entity.
// Example from MachineContactMedium.step:
//   MEASURE_REPRESENTATION_ITEM('density measure',POSITIVE_RATIO_MEASURE(7850.),#589)
pub(all) enum MeasureValueComponent {
  PositiveRatioMeasure(@units.PositiveRatioMeasure)
  Raw(String)
}

///|
pub struct MeasureRepresentationItem {
  name : String
  value_component : MeasureValueComponent
  unit_component : @step.Ref
}

///|
pub fn MeasureRepresentationItem::new(
  name : String,
  value_component : MeasureValueComponent,
  unit_component : @step.Ref,
) -> MeasureRepresentationItem {
  MeasureRepresentationItem::{ name, value_component, unit_component }
}

///|
pub impl @step.Entity for MeasureRepresentationItem with to_step(self) {
  let unit_str = "#\{self.unit_component.id.value}"
  let value_str = match self.value_component {
    PositiveRatioMeasure(m) => @step.Entity::to_step(m)
    Raw(s) => s
  }
  "MEASURE_REPRESENTATION_ITEM(\{@step.step_str(self.name)},\{value_str},\{unit_str})"
}
