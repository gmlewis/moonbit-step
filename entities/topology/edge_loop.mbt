///|
// Represents an EDGE_LOOP entity.
// Example from simple-box.step:
//   EDGE_LOOP('',(#58,#59,#60,#61))
pub struct EdgeLoop {
  name : String
  edges : Array[@step.Ref]
}

///|
pub fn EdgeLoop::new(name : String, edges : Array[@step.Ref]) -> EdgeLoop {
  EdgeLoop::{ name, edges }
}

///|
pub impl @step.Entity for EdgeLoop with to_step(self) {
  let edges_str = self.edges.map(fn(r) { "#\{r.id.value}" }).join(",")
  "EDGE_LOOP(\{step_str_or_dollar(self.name)},(\{edges_str}))"
}
