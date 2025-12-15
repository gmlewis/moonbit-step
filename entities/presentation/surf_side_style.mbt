///|
// Represents a SURFACE_SIDE_STYLE entity.
pub struct SurfaceSideStyle {
  name : String
  styles : Array[@step.Ref]
}

///|
pub fn SurfaceSideStyle::new(
  name : String,
  styles : Array[@step.Ref],
) -> SurfaceSideStyle {
  SurfaceSideStyle::{ name, styles }
}

///|
pub impl @step.Entity for SurfaceSideStyle with to_step(self) {
  let styles_str = self.styles.map(fn(r) { "#\{r.id.value}" }).join(",")
  "SURFACE_SIDE_STYLE(\{@step.step_str(self.name)},(\{styles_str}))"
}
