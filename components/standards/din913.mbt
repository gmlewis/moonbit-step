///|
/// DIN913Size carries the DIN 913 hexagon socket set-screw (flat point)
/// dimensions for one nominal size.
///
/// `socket_across_flats_mm` is the nominal hex key size; the model uses the
/// upper limit `socket_across_flats_max_mm` so a standard key fits. The point
/// is a flat of `point_flat_diameter_mm` with a 90-degree included cone break
/// (`point_angle_deg`). See `components/DATA_SOURCES.md`.
pub(all) struct DIN913Size {
  size : MetricSize
  thread : ThreadSpec
  socket_across_flats_mm : Double
  socket_across_flats_max_mm : Double
  socket_depth_mm : Double
  point_flat_diameter_mm : Double
  point_angle_deg : Double
  min_length_mm : Double
  max_length_mm : Double
}

///|
/// din913_size returns the DIN 913 dimensions for one size.
pub fn din913_size(size : MetricSize) -> Result[DIN913Size, @common.SpecError] {
  let dims = match size {
    // (s nominal, s max, t reference, point flat d_p, point angle,
    //  min length, max length)
    M3 => (1.5, 1.545, 2.0, 2.0, 90.0, 2.0, 20.0)
    _ =>
      return Err(
        @common.SpecError::InvalidSize(
          "DIN 913 does not carry size " + size.designation(),
        ),
      )
  }
  let (s, s_max, t, point_flat, angle, lo, hi) = dims
  Ok({
    size,
    thread: ThreadSpec::coarse(size),
    socket_across_flats_mm: s,
    socket_across_flats_max_mm: s_max,
    socket_depth_mm: t,
    point_flat_diameter_mm: point_flat,
    point_angle_deg: angle,
    min_length_mm: lo,
    max_length_mm: hi,
  })
}

///|
/// DIN913Spec is a validated DIN 913 set-screw specification.
pub(all) struct DIN913Spec {
  size_dims : DIN913Size
  length_mm : Double
}

///|
/// din913_spec validates a size and length for DIN 913.
pub fn din913_spec(
  size : MetricSize,
  length_mm : Double,
) -> Result[DIN913Spec, @common.SpecError] {
  match din913_size(size) {
    Err(e) => Err(e)
    Ok(dims) =>
      match
        @common.require_in_range(
          "DIN 913 length",
          length_mm,
          dims.min_length_mm,
          dims.max_length_mm,
        ) {
        Err(e) => Err(e)
        Ok(_) => Ok({ size_dims: dims, length_mm, })
      }
  }
}

///|
/// DIN913Spec::size returns the nominal size.
pub fn DIN913Spec::size(self : DIN913Spec) -> MetricSize {
  self.size_dims.size
}

///|
/// DIN913Spec::thread returns the thread specification.
pub fn DIN913Spec::thread(self : DIN913Spec) -> ThreadSpec {
  self.size_dims.thread
}

///|
/// DIN913Spec::designation returns the standard part designation.
pub fn DIN913Spec::designation(self : DIN913Spec) -> String {
  "DIN 913 - \{self.size_dims.size.designation()} x \{self.length_mm}"
}

///|
/// DIN913Spec::standard returns the exact standard used.
pub fn DIN913Spec::standard() -> String {
  "DIN 913"
}

///|
/// DIN913Spec::source returns the dimensional provenance note.
pub fn DIN913Spec::source() -> String {
  "DIN 913 hexagon socket set screw with flat point; s, t, and point flat from the DIN 913 table, see components/DATA_SOURCES.md"
}

///|
/// DIN913Spec::metadata builds component metadata for this specification.
pub fn DIN913Spec::metadata(self : DIN913Spec) -> @common.Metadata {
  @common.Metadata::new(
    designation=self.designation(),
    standard=DIN913Spec::standard(),
    family="hexagon socket set screw with flat point",
    size=self.size_dims.size.designation(),
    length_mm=self.length_mm,
    source=DIN913Spec::source(),
  )
}
