///|
fn pvc_entry_from(
  component : @common.Component,
  parameters : Array[String],
) -> CatalogEntry {
  entry_from_component(component, parameters, [
    "Simplified", "Detailed", "FullyModeled",
  ])
}

///|
fn push_pvc_entry(
  entries : Array[CatalogEntry],
  result : Result[@common.Component, @common.SpecError],
  parameters : Array[String],
) -> Unit {
  match result {
    Ok(component) => entries.push(pvc_entry_from(component, parameters))
    Err(_) => ()
  }
}

///|
/// pvc_catalog returns the Schedule 40 PVC pipe and fitting catalogue entries.
pub fn pvc_catalog() -> Array[CatalogEntry] {
  let entries : Array[CatalogEntry] = []
  let pipe_params = ["size", "schedule", "length", "detail"]
  let fitting_params = ["size", "schedule", "clearance", "detail"]
  let mut prev : @pvc.PvcSize? = None
  for size_name in @pvc.pvc_trade_sizes() {
    let size = match @pvc.pvc_size(size_name) {
      Ok(s) => s
      Err(_) => continue
    }
    push_pvc_entry(entries, @pvc.pvc_pipe(size, 304.8), pipe_params)
    push_pvc_entry(entries, @pvc.coupling(size), fitting_params)
    push_pvc_entry(entries, @pvc.cap(size), fitting_params)
    push_pvc_entry(entries, @pvc.elbow_90(size), fitting_params)
    push_pvc_entry(entries, @pvc.elbow_45(size), fitting_params)
    push_pvc_entry(entries, @pvc.tee(size), fitting_params)
    push_pvc_entry(entries, @pvc.cross(size), fitting_params)
    push_pvc_entry(entries, @pvc.corner_3way(size), fitting_params)
    push_pvc_entry(entries, @pvc.four_way_tee(size), fitting_params)
    push_pvc_entry(entries, @pvc.five_way(size), fitting_params)
    push_pvc_entry(entries, @pvc.flange(size), [
      "size", "schedule", "baseDiameter", "baseThickness", "boltCircle", "boltHole",
      "detail",
    ])
    match prev {
      Some(small) =>
        push_pvc_entry(entries, @pvc.reducer_coupling(size, small), [
          "size", "toSize", "schedule", "clearance", "detail",
        ])
      None => ()
    }
    prev = Some(size)
  }
  entries
}
