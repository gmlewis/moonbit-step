///|
/// DIN916Size carries the DIN 916 hexagon socket set-screw (cup point)
/// dimensions for one nominal size.
///
/// `socket_across_flats_mm` is the modelled hex-key size; the values are the
/// upper limits measured from the reference family. `socket_depth_mm` is the
/// nominal socket depth; short screws reduce it (see `din916_socket_depth`).
/// `cup_diameter_mm` is the cup recess diameter.
pub(all) struct DIN916Size {
  size : MetricSize
  thread : ThreadSpec
  socket_across_flats_mm : Double
  socket_depth_mm : Double
  cup_diameter_mm : Double
  min_length_mm : Double
  max_length_mm : Double
}

///|
/// din916_size returns the DIN 916 dimensions for one size.
pub fn din916_size(size : MetricSize) -> Result[DIN916Size, @common.SpecError] {
  // (socket across flats, nominal socket depth, cup diameter, min length,
  //  max length). Socket and cup values are measured from the reference
  //  family and agree with the DIN 916 nominal envelope.
  let dims = match size {
    M3 => (1.65, 1.9, 1.32, 2.0, 20.0)
    M4 => (2.2, 2.5, 1.76, 3.0, 30.0)
    M5 => (2.75, 3.1, 2.2, 3.0, 40.0)
    M6 => (3.3, 3.7, 2.64, 4.0, 60.0)
    _ =>
      return Err(
        @common.SpecError::InvalidSize(
          "DIN 916 does not carry size " + size.designation(),
        ),
      )
  }
  let (af, depth, cup, lo, hi) = dims
  Ok({
    size,
    thread: ThreadSpec::coarse(size),
    socket_across_flats_mm: af,
    socket_depth_mm: depth,
    cup_diameter_mm: cup,
    min_length_mm: lo,
    max_length_mm: hi,
  })
}

///|
/// DIN916Spec is a validated DIN 916 set-screw specification.
pub(all) struct DIN916Spec {
  size_dims : DIN916Size
  length_mm : Double
}

///|
/// din916_spec validates a size and length for DIN 916.
pub fn din916_spec(
  size : MetricSize,
  length_mm : Double,
) -> Result[DIN916Spec, @common.SpecError] {
  match din916_size(size) {
    Err(e) => Err(e)
    Ok(dims) =>
      match
        @common.require_in_range(
          "DIN 916 length",
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
/// DIN916Spec::thread returns the thread specification.
pub fn DIN916Spec::thread(self : DIN916Spec) -> ThreadSpec {
  self.size_dims.thread
}

///|
/// DIN916Spec::size returns the nominal size.
pub fn DIN916Spec::size(self : DIN916Spec) -> MetricSize {
  self.size_dims.size
}

///|
/// DIN916Spec::designation returns the standard part designation.
pub fn DIN916Spec::designation(self : DIN916Spec) -> String {
  "DIN 916 - \{self.size_dims.size.designation()} x \{self.length_mm}"
}

///|
/// DIN916Spec::standard returns the exact standard used.
pub fn DIN916Spec::standard() -> String {
  "DIN 916"
}

///|
/// DIN916Spec::source returns the dimensional provenance note.
pub fn DIN916Spec::source() -> String {
  "DIN 916 hexagon socket set screw, cup point; socket and cup dimensions measured from the reference family"
}

///|
/// DIN916Spec::metadata builds component metadata for this specification.
pub fn DIN916Spec::metadata(self : DIN916Spec) -> @common.Metadata {
  @common.Metadata::new(
    designation=self.designation(),
    standard=DIN916Spec::standard(),
    family="hexagon socket set screw, cup point",
    size=self.size_dims.size.designation(),
    length_mm=self.length_mm,
    source=DIN916Spec::source(),
  )
}
