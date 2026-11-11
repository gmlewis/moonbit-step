///|
/// ISO10642Size carries the ISO 10642 countersunk head hexagon socket screw
/// dimensions for one nominal size.
///
/// `d_k` is the reference sharp head diameter and `d_k_min`/`d_k_max` its ISO
/// range; `k` is the reference head height (at most the ISO maximum); `r_edge`
/// is the ISO head edge radius; `s`/`s_max` the socket across flats; and `t`
/// the socket depth (within the ISO `t_max`/`t_min` range). The head has a
/// 90 degree (45 degree half-angle) countersink. Reference values are chosen
/// within the ISO 10642:2026 limits; the downloaded M3/M5 profiles match
/// exactly, while the M4/M6/M8 references use the ISO minimum edge radius.
/// See `DATA_SOURCES.md`.
pub(all) struct ISO10642Size {
  size : MetricSize
  thread : ThreadSpec
  head_diameter_mm : Double
  head_diameter_min_mm : Double
  head_diameter_max_mm : Double
  head_height_mm : Double
  head_edge_radius_mm : Double
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
    // ISO 10642:2026 (dimensional values unchanged from 2019). The reference
    // head diameter/height/edge radius are within the ISO ranges and reproduce
    // the downloaded M3/M5 profiles exactly; M4/M6/M8 use the ISO minimum
    // edge radius (their references are slightly below it), and M4/M5/M8 use
    // t_max (their references are deeper than the standard allows).
    // (dk sharp, dk min, dk max, k reference, r edge, s nominal, s max, t,
    //  min length, max length)
    M3 => (6.0, 5.54, 6.72, 1.70, 0.1275, 2.0, 2.08, 1.20, 5.0, 30.0)
    M4 => (8.0, 7.53, 8.96, 2.30, 0.20, 2.5, 2.58, 1.65, 6.0, 40.0)
    M5 => (10.0, 9.43, 11.20, 2.80, 0.21, 3.0, 3.08, 2.00, 8.0, 50.0)
    M6 => (12.0, 11.34, 13.44, 3.30, 0.25, 4.0, 4.095, 2.50, 10.0, 60.0)
    M8 => (16.0, 15.24, 17.92, 4.40, 0.40, 5.0, 5.14, 3.20, 12.0, 80.0)
    M10 => (20.0, 19.22, 22.40, 5.50, 0.40, 6.0, 6.14, 3.90, 20.0, 100.0)
    _ =>
      return Err(
        @common.SpecError::InvalidSize(
          "ISO 10642 does not carry size " + size.designation(),
        ),
      )
  }
  let (dk, dk_min, dk_max, k, r_edge, s, s_max, t, lo, hi) = dims
  Ok({
    size,
    thread: ThreadSpec::coarse(size),
    head_diameter_mm: dk,
    head_diameter_min_mm: dk_min,
    head_diameter_max_mm: dk_max,
    head_height_mm: k,
    head_edge_radius_mm: r_edge,
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
  "ISO 10642:2026"
}

///|
/// ISO10642Spec::source returns the dimensional provenance note.
pub fn ISO10642Spec::source() -> String {
  "ISO 10642:2026 (edition 4); dimensional table unchanged from 2019. Reference sharp dk within the ISO range, ISO head edge radius, socket at s_max, depth within t_min..t_max. See components/DATA_SOURCES.md"
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
