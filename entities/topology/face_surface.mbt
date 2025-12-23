///|
// Represents a FACE_SURFACE entity.
// Example:
//   FACE_SURFACE('name', (#10, #20), #30, .T.)
pub struct FaceSurface {
  name : String
  bounds : Array[@step.Ref]
  face_geometry : @step.Ref
  same_sense : Bool
}

///|
pub fn FaceSurface::new(
  name : String,
  bounds : Array[@step.Ref],
  face_geometry : @step.Ref,
  same_sense : Bool,
) -> FaceSurface {
  FaceSurface::{ name, bounds, face_geometry, same_sense }
}

///|
pub impl @step.Entity for FaceSurface with to_step(self) {
  let bounds_str = self.bounds.map(fn(r) { "#\{r.id.value}" }).join(",")
  let geom_str = "#\{self.face_geometry.id.value}"
  let ss_str = bool_to_step(self.same_sense)
  "FACE_SURFACE(\{@step.step_str(self.name)},(\{bounds_str}),\{geom_str},\{ss_str})"
}
