///|
// Represents a POLYLINE entity.
// Example:
//   POLYLINE('name', (#10, #20, #30))
pub struct Polyline {
  name : String
  points : Array[@step.Ref]
}

///|
pub fn Polyline::new(name : String, points : Array[@step.Ref]) -> Polyline {
  Polyline::{ name, points }
}

///|
pub impl @step.Entity for Polyline with to_step(self) {
  let pts_str = self.points.map(fn(r) { "#\{r.id.value}" }).join(",")
  "POLYLINE(\{@step.step_str(self.name)},(\{pts_str}))"
}
