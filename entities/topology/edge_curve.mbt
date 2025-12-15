///|
// Represents an EDGE_CURVE entity.
// Example from simple-box.step:
//   EDGE_CURVE('',#82,#83,#102,.T.)
pub struct EdgeCurve {
  name : String
  edge_start : @step.Ref
  edge_end : @step.Ref
  edge_geometry : @step.Ref
  same_sense : Bool
}

///|
pub fn EdgeCurve::new(
  name : String,
  edge_start : @step.Ref,
  edge_end : @step.Ref,
  edge_geometry : @step.Ref,
  same_sense : Bool,
) -> EdgeCurve {
  EdgeCurve::{ name, edge_start, edge_end, edge_geometry, same_sense }
}

///|
pub impl @step.Entity for EdgeCurve with to_step(self) {
  let start_str = "#\{self.edge_start.id.value}"
  let end_str = "#\{self.edge_end.id.value}"
  let geom_str = "#\{self.edge_geometry.id.value}"
  let ss_str = bool_to_step(self.same_sense)
  "EDGE_CURVE(\{step_str_or_dollar(self.name)},\{start_str},\{end_str},\{geom_str},\{ss_str})"
}
