///|
// Represents a SURFACE_STYLE_USAGE entity.
pub struct SurfaceStyleUsage {
  // STEP enumeration literal, e.g. ".BOTH.".
  side : String
  style : @step.Ref
}

///|
pub fn SurfaceStyleUsage::new(
  side : String,
  style : @step.Ref,
) -> SurfaceStyleUsage {
  SurfaceStyleUsage::{ side, style }
}

///|
pub impl @step.Entity for SurfaceStyleUsage with to_step(self) {
  let style = "#\{self.style.id.value}"
  "SURFACE_STYLE_USAGE(\{self.side},\{style})"
}
