///|
// Represents a SURFACE_STYLE_FILL_AREA entity.
pub struct SurfaceStyleFillArea {
  fill_area : @step.Ref
}

///|
pub fn SurfaceStyleFillArea::new(fill_area : @step.Ref) -> SurfaceStyleFillArea {
  SurfaceStyleFillArea::{ fill_area, }
}

///|
pub impl @step.Entity for SurfaceStyleFillArea with to_step(self) {
  let fa = "#\{self.fill_area.id.value}"
  "SURFACE_STYLE_FILL_AREA(\{fa})"
}
