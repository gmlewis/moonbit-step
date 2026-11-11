///|
/// ISO10642Size carries the ISO 10642 countersunk head hexagon socket screw
/// dimensions for one nominal size.
///
/// `d_k` is the head diameter, `k` the head height, `s` the socket width across
/// flats, `t` the socket depth, and the head has a 90 degree (45 degree
/// half-angle) countersink. These are nominal values transcribed from commonly
/// published dimension summaries; verify against the current standard or a
/// manufacturer drawing before manufacturing (see `DATA_SOURCES.md`).
pub(all) struct ISO10642Size {
  size : MetricSize
  thread : ThreadSpec
  head_diameter_mm : Double
  head_height_mm : Double
  head_angle_deg : Double
  socket_across_flats_mm : Double
  /// Upper ISO limit of the socket width across flats (nominal + tolerance).
  socket_across_flats_max_mm : Double
  socket_depth_mm : Double
  min_length_mm : Double
  max_length_mm : Double
}

///|
/// iso10642_size returns the nominal dimensions for one metric size.
pub fn iso10642_size(
  size : MetricSize,
) -> Result[ISO10642Size, @common.SpecError] {
  let dims = match size {
    // M3 starts at 5 mm: the downloaded countersunk reference is an M3 x 5.
    M3 => (6.0, 1.70, 2.0, 2.08, 1.30, 5.0, 30.0)
    M4 => (8.4, 2.30, 2.5, 2.58, 2.00, 6.0, 40.0)
    M5 => (10.4, 2.80, 3.0, 3.08, 2.50, 8.0, 50.0)
    M6 => (12.6, 3.30, 4.0, 4.095, 3.00, 12.0, 60.0)
    M8 => (16.8, 4.40, 5.0, 5.14, 4.00, 16.0, 80.0)
    M10 => (20.8, 5.50, 6.0, 6.14, 5.00, 20.0, 100.0)
    _ =>
      return Err(
        @common.SpecError::InvalidSize(
          "ISO 10642 does not carry size " + size.designation(),
        ),
      )
  }
  let (dk, k, s, s_max, t, lo, hi) = dims
  Ok({
    size,
    thread: ThreadSpec::coarse(size),
    head_diameter_mm: dk,
    head_height_mm: k,
    head_angle_deg: 90.0,
    socket_across_flats_mm: s,
    socket_across_flats_max_mm: s_max,
    socket_depth_mm: t,
    min_length_mm: lo,
    max_length_mm: hi,
  })
}

///|
/// ISO10642Spec is a validated countersunk head screw specification.
pub(all) struct ISO10642Spec {
  size_dims : ISO10642Size
  length_mm : Double
}

///|
/// iso10642_spec validates a size and length for ISO 10642.
pub fn iso10642_spec(
  size : MetricSize,
  length_mm : Double,
) -> Result[ISO10642Spec, @common.SpecError] {
  match iso10642_size(size) {
    Err(e) => Err(e)
    Ok(dims) =>
      match
        @common.require_in_range(
          "ISO 10642 length",
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
/// ISO10642Spec::size returns the nominal size.
pub fn ISO10642Spec::size(self : ISO10642Spec) -> MetricSize {
  self.size_dims.size
}

///|
/// ISO10642Spec::thread returns the thread specification.
pub fn ISO10642Spec::thread(self : ISO10642Spec) -> ThreadSpec {
  self.size_dims.thread
}

///|
/// ISO10642Spec::designation returns the standard part designation.
pub fn ISO10642Spec::designation(self : ISO10642Spec) -> String {
  "ISO 10642 - \{self.size_dims.size.designation()} x \{self.length_mm}"
}

///|
/// ISO10642Spec::standard returns the exact standard used.
pub fn ISO10642Spec::standard() -> String {
  "ISO 10642:2004"
}

///|
/// ISO10642Spec::source returns the dimensional provenance note.
pub fn ISO10642Spec::source() -> String {
  "ISO 10642 countersunk head table; nominal values transcribed from published summaries, see components/DATA_SOURCES.md"
}

///|
/// ISO10642Spec::metadata builds component metadata.
pub fn ISO10642Spec::metadata(self : ISO10642Spec) -> @common.Metadata {
  @common.Metadata::new(
    designation=self.designation(),
    standard=ISO10642Spec::standard(),
    family="countersunk head hexagon socket screw",
    size=self.size_dims.size.designation(),
    length_mm=self.length_mm,
    source=ISO10642Spec::source(),
  )
}
