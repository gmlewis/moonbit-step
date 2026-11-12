///|
// Represents a SURFACE_CURVE entity: a 3D curve with pcurves on the adjacent
// surfaces, so importers can relate the edge to both faces.
//
// Example:
//   SURFACE_CURVE('',#27,(#40,#72),.PCURVE_S1.)
pub struct SurfaceCurve {
  name : String
  curve_3d : @step.Ref
  associated_geometry : Array[@step.Ref]
  master_representation : String
}

///|
pub fn SurfaceCurve::new(
  name : String,
  curve_3d : @step.Ref,
  associated_geometry : Array[@step.Ref],
  master_representation : String,
) -> SurfaceCurve {
  { name, curve_3d, associated_geometry, master_representation, }
}

///|
pub impl @step.Entity for SurfaceCurve with fn to_step(self) {
  let refs = self.associated_geometry.map(fn(r) { "#\{r.id.value}" }).join(",")
  "SURFACE_CURVE(\{@step.step_str(self.name)},#\{self.curve_3d.id.value},(\{refs}),\{self.master_representation})"
}
