///|
/// HexHeadSize carries the shared ISO 4014 / ISO 4017 hexagon head dimensions:
/// width across flats `s` and head height `k`.
pub(all) struct HexHeadSize {
  size : MetricSize
  thread : ThreadSpec
  width_across_flats_mm : Double
  head_height_mm : Double
  min_length_mm : Double
  max_length_mm : Double
}

///|
/// hex_head_size returns the verified hexagon head dimensions for one size.
pub fn hex_head_size(
  size : MetricSize,
) -> Result[HexHeadSize, @common.SpecError] {
  let dims = match size {
    M2 => (4.0, 1.4, 4.0, 30.0)
    M2_5 => (5.0, 1.6, 5.0, 40.0)
    M3 => (5.5, 2.0, 6.0, 60.0)
    M4 => (7.0, 2.8, 8.0, 80.0)
    M5 => (8.0, 3.5, 10.0, 100.0)
    M6 => (10.0, 4.0, 12.0, 120.0)
    M8 => (13.0, 5.3, 16.0, 150.0)
    M10 => (16.0, 6.4, 20.0, 200.0)
    M12 => (18.0, 7.5, 25.0, 200.0)
    M16 => (24.0, 10.0, 30.0, 200.0)
    M20 => (30.0, 12.5, 40.0, 200.0)
  }
  let (s, k, lo, hi) = dims
  Ok({
    size,
    thread: ThreadSpec::coarse(size),
    width_across_flats_mm: s,
    head_height_mm: k,
    min_length_mm: lo,
    max_length_mm: hi,
  })
}

///|
/// bolt_thread_length returns the ISO 4014 nominal thread length `b` for a
/// shank length, using the standard length ranges.
pub fn bolt_thread_length(diameter : Double, length_mm : Double) -> Double {
  if length_mm <= 125.0 {
    2.0 * diameter + 6.0
  } else if length_mm <= 200.0 {
    2.0 * diameter + 12.0
  } else {
    2.0 * diameter + 25.0
  }
}

///|
/// ISO4017Spec is a validated fully threaded hexagon head screw.
pub(all) struct ISO4017Spec {
  size_dims : HexHeadSize
  length_mm : Double
}

///|
/// iso4017_spec validates a size and length for ISO 4017.
pub fn iso4017_spec(
  size : MetricSize,
  length_mm : Double,
) -> Result[ISO4017Spec, @common.SpecError] {
  match hex_head_size(size) {
    Err(e) => Err(e)
    Ok(dims) =>
      match
        @common.require_in_range(
          "ISO 4017 length",
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
/// ISO4017Spec::thread returns the thread specification.
pub fn ISO4017Spec::thread(self : ISO4017Spec) -> ThreadSpec {
  self.size_dims.thread
}

///|
/// ISO4017Spec::designation returns the standard part designation.
pub fn ISO4017Spec::designation(self : ISO4017Spec) -> String {
  "ISO 4017 - \{self.size_dims.size.designation()} x \{self.length_mm}"
}

///|
pub fn ISO4017Spec::standard() -> String {
  "ISO 4017:2014"
}

///|
pub fn ISO4017Spec::source() -> String {
  "ISO 4017:2014 hexagon head screw, product grades A and B; nominal values, see components/DATA_SOURCES.md"
}

///|
/// ISO4017Spec::metadata builds component metadata.
pub fn ISO4017Spec::metadata(self : ISO4017Spec) -> @common.Metadata {
  @common.Metadata::new(
    designation=self.designation(),
    standard=ISO4017Spec::standard(),
    family="hexagon head screw, fully threaded",
    size=self.size_dims.size.designation(),
    length_mm=self.length_mm,
    source=ISO4017Spec::source(),
  )
}

///|
/// ISO4014Spec is a validated partially threaded hexagon head bolt.
pub(all) struct ISO4014Spec {
  size_dims : HexHeadSize
  length_mm : Double
  thread_length_mm : Double
  fully_threaded : Bool
}

///|
/// iso4014_spec validates a size and length for ISO 4014.
pub fn iso4014_spec(
  size : MetricSize,
  length_mm : Double,
) -> Result[ISO4014Spec, @common.SpecError] {
  match hex_head_size(size) {
    Err(e) => Err(e)
    Ok(dims) =>
      match
        @common.require_in_range(
          "ISO 4014 length",
          length_mm,
          dims.min_length_mm,
          dims.max_length_mm,
        ) {
        Err(e) => Err(e)
        Ok(_) => {
          let b = bolt_thread_length(dims.thread.nominal_diameter_mm, length_mm)
          let fully_threaded = length_mm <= b
          let thread_length = if fully_threaded { length_mm } else { b }
          Ok({
            size_dims: dims,
            length_mm,
            thread_length_mm: thread_length,
            fully_threaded,
          })
        }
      }
  }
}

///|
/// ISO4014Spec::thread returns the thread specification.
pub fn ISO4014Spec::thread(self : ISO4014Spec) -> ThreadSpec {
  self.size_dims.thread
}

///|
/// ISO4014Spec::designation returns the standard part designation.
pub fn ISO4014Spec::designation(self : ISO4014Spec) -> String {
  "ISO 4014 - \{self.size_dims.size.designation()} x \{self.length_mm}"
}

///|
pub fn ISO4014Spec::standard() -> String {
  "ISO 4014:2011"
}

///|
pub fn ISO4014Spec::source() -> String {
  "ISO 4014:2011 hexagon head bolt, product grades A and B; nominal values, see components/DATA_SOURCES.md"
}

///|
/// ISO4014Spec::metadata builds component metadata.
pub fn ISO4014Spec::metadata(self : ISO4014Spec) -> @common.Metadata {
  @common.Metadata::new(
    designation=self.designation(),
    standard=ISO4014Spec::standard(),
    family="hexagon head bolt, partially threaded",
    size=self.size_dims.size.designation(),
    length_mm=self.length_mm,
    source=ISO4014Spec::source(),
  )
}

///|
/// DIN976Spec is a validated DIN 976-1 threaded rod specification.
pub(all) struct DIN976Spec {
  thread : ThreadSpec
  length_mm : Double
}

///|
/// din976_spec validates a size and length for a DIN 976-1 threaded rod.
pub fn din976_spec(
  size : MetricSize,
  length_mm : Double,
) -> Result[DIN976Spec, @common.SpecError] {
  match @common.require_in_range("DIN 976 length", length_mm, 10.0, 3000.0) {
    Err(e) => Err(e)
    Ok(_) => Ok({ thread: ThreadSpec::coarse(size), length_mm, })
  }
}

///|
/// DIN976Spec::designation returns the standard part designation.
pub fn DIN976Spec::designation(self : DIN976Spec) -> String {
  "DIN 976-1 - \{self.thread.size.designation()} x \{self.length_mm}"
}

///|
pub fn DIN976Spec::standard() -> String {
  "DIN 976-1:2016"
}

///|
pub fn DIN976Spec::source() -> String {
  "DIN 976-1:2016 metric threaded rod with ISO metric coarse thread; nominal values, see components/DATA_SOURCES.md"
}

///|
/// DIN976Spec::metadata builds component metadata.
pub fn DIN976Spec::metadata(self : DIN976Spec) -> @common.Metadata {
  @common.Metadata::new(
    designation=self.designation(),
    standard=DIN976Spec::standard(),
    family="threaded rod",
    size=self.thread.size.designation(),
    length_mm=self.length_mm,
    source=DIN976Spec::source(),
  )
}
