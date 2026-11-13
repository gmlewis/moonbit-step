///|
/// CONNECTOR_SIDECAR_HEADER is the first line of the connector sidecar file.
const CONNECTOR_SIDECAR_HEADER : String = "# gmlewis/step connector sidecar v1"

///|
/// CONNECTOR_SIDECAR_COLUMNS documents the tab-separated columns.
const CONNECTOR_SIDECAR_COLUMNS : String = "# name\tox\toy\toz\tax\tay\taz\txx\txy\txz\tkind\tgender\tdiameter_mm\tdepth_mm"

///|
/// fmt_optional_mm formats an optional length for the sidecar.
fn fmt_optional_mm(value : Double?) -> String {
  match value {
    Some(v) => @cad.fmt_double(v, None)
    None => ""
  }
}

///|
/// sidecar_x_direction returns a deterministic secondary axis for a connector.
///
/// The primary axis is the connector's stated `axis`. The secondary axis is the
/// placement's local X projected perpendicular to it, so an intentional twist
/// (a keyed or rotated interface) is preserved. When the placement's local X is
/// parallel to the axis (the common axis-aligned case), a global axis is used
/// instead: global X for a Z axis, global Y for an X axis, and so on. This keeps
/// the displayed frame aligned with the global axes unless there is a reason
/// not to.
fn sidecar_x_direction(connector : MateConnector) -> @cad.Vec3 {
  let (ax, ay, az) = normalize_dir(connector.axis)
  let (px, py, pz) = connector.placement.apply_dir((1.0, 0.0, 0.0))
  let projection = px * ax + py * ay + pz * az
  let x = (px - projection * ax, py - projection * ay, pz - projection * az)
  let length = Double::sqrt(x.0 * x.0 + x.1 * x.1 + x.2 * x.2)
  if length > 1.0e-6 {
    return (x.0 / length, x.1 / length, x.2 / length)
  }
  let fallback = if ax.abs() < 0.9 {
    (1.0, 0.0, 0.0)
  } else if ay.abs() < 0.9 {
    (0.0, 1.0, 0.0)
  } else {
    (0.0, 0.0, 1.0)
  }
  let (fx, fy, fz) = fallback
  let fallback_projection = fx * ax + fy * ay + fz * az
  let raw = (
    fx - fallback_projection * ax,
    fy - fallback_projection * ay,
    fz - fallback_projection * az,
  )
  normalize_dir(raw)
}

///|
/// Component::connector_sidecar returns a tab-separated description of every
/// named connector: origin, primary axis, secondary axis, kind, gender,
/// diameter, and depth.
///
/// The sidecar is a visualization aid for developer tools. It is never part of
/// the component geometry, never written into the STEP file, and never used for
/// measurements. A tool may place a SolidCraft `joint.origin` (or another
/// viewer's datum marker) at each row.
pub fn Component::connector_sidecar(self : Component) -> String {
  let lines : Array[String] = [
    CONNECTOR_SIDECAR_HEADER,
    CONNECTOR_SIDECAR_COLUMNS,
  ]
  for connector in self.connectors {
    let (ox, oy, oz) = connector.placement.trans
    let (ax, ay, az) = connector.axis
    let (xx, xy, xz) = sidecar_x_direction(connector)
    let diameter = fmt_optional_mm(connector.diameter_mm)
    let depth = fmt_optional_mm(connector.depth_mm)
    lines.push(
      "\{connector.name}\t\{@cad.fmt_double(ox, None)}\t\{@cad.fmt_double(oy, None)}\t\{@cad.fmt_double(oz, None)}\t\{@cad.fmt_double(ax, None)}\t\{@cad.fmt_double(ay, None)}\t\{@cad.fmt_double(az, None)}\t\{@cad.fmt_double(xx, None)}\t\{@cad.fmt_double(xy, None)}\t\{@cad.fmt_double(xz, None)}\t\{connector.kind.to_string()}\t\{connector.gender.to_string()}\t\{diameter}\t\{depth}",
    )
  }
  lines.join("\n") + "\n"
}

///|
/// Component::write_connector_sidecar writes the connector sidecar to a file.
///
/// This is public for tools that want the frames without writing a STEP file.
/// It does not change the component or its geometry.
pub async fn Component::write_connector_sidecar(
  self : Component,
  out_path : String,
) -> Unit {
  @cad.write_text_file(self.connector_sidecar(), Some(out_path))
}
