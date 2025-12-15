///|
// Represents a VERTEX_POINT entity.
// Example from simple-box.step:
//   VERTEX_POINT('',#161)
pub struct VertexPoint {
  name : String
  vertex_geometry : @step.Ref
}

///|
pub fn VertexPoint::new(
  name : String,
  vertex_geometry : @step.Ref,
) -> VertexPoint {
  VertexPoint::{ name, vertex_geometry }
}

///|
pub impl @step.Entity for VertexPoint with to_step(self) {
  let geom_str = "#\{self.vertex_geometry.id.value}"
  "VERTEX_POINT(\{step_str_or_dollar(self.name)},\{geom_str})"
}
