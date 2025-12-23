///|
// Represents a CONNECTED_FACE_SET entity.
// Example:
//   CONNECTED_FACE_SET('name', (#10, #20))
pub struct ConnectedFaceSet {
  name : String
  cfs_faces : Array[@step.Ref]
}

///|
pub fn ConnectedFaceSet::new(
  name : String,
  cfs_faces : Array[@step.Ref],
) -> ConnectedFaceSet {
  ConnectedFaceSet::{ name, cfs_faces }
}

///|
pub impl @step.Entity for ConnectedFaceSet with to_step(self) {
  let faces_str = self.cfs_faces.map(fn(r) { "#\{r.id.value}" }).join(",")
  "CONNECTED_FACE_SET(\{@step.step_str(self.name)},(\{faces_str}))"
}
