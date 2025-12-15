///|
// Represents an ORIENTED_EDGE entity.
// Example from simple-box.step:
//   ORIENTED_EDGE('',*,*,#90,.T.)
// Note: STEP uses the 2nd and 3rd args for edge_start/edge_end; in the fixture these are `*`.
pub struct OrientedEdge {
  name : String
  edge_start : String
  edge_end : String
  edge_element : @step.Ref
  orientation : Bool
}

///|
pub fn OrientedEdge::new(
  name : String,
  edge_start : String,
  edge_end : String,
  edge_element : @step.Ref,
  orientation : Bool,
) -> OrientedEdge {
  OrientedEdge::{ name, edge_start, edge_end, edge_element, orientation }
}

///|
pub impl @step.Entity for OrientedEdge with to_step(self) {
  let edge_element_str = "#\{self.edge_element.id.value}"
  let ori_str = bool_to_step(self.orientation)
  "ORIENTED_EDGE(\{step_str_or_dollar(self.name)},\{self.edge_start},\{self.edge_end},\{edge_element_str},\{ori_str})"
}
