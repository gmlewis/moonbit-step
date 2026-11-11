///|
/// MetricSize enumerates the ISO metric coarse-thread nominal diameters this
/// library carries verified data for.
pub(all) enum MetricSize {
  M2
  M2_5
  M3
  M4
  M5
  M6
  M8
  M10
  M12
  M16
  M20
}

///|
/// MetricSize::all returns every supported size in ascending order.
pub fn MetricSize::all() -> Array[MetricSize] {
  [M2, M2_5, M3, M4, M5, M6, M8, M10, M12, M16, M20]
}

///|
/// MetricSize::designation returns the standard token, e.g. "M4".
pub fn MetricSize::designation(self : MetricSize) -> String {
  match self {
    M2 => "M2"
    M2_5 => "M2.5"
    M3 => "M3"
    M4 => "M4"
    M5 => "M5"
    M6 => "M6"
    M8 => "M8"
    M10 => "M10"
    M12 => "M12"
    M16 => "M16"
    M20 => "M20"
  }
}

///|
/// MetricSize::nominal_diameter_mm returns the nominal major diameter.
pub fn MetricSize::nominal_diameter_mm(self : MetricSize) -> Double {
  match self {
    M2 => 2.0
    M2_5 => 2.5
    M3 => 3.0
    M4 => 4.0
    M5 => 5.0
    M6 => 6.0
    M8 => 8.0
    M10 => 10.0
    M12 => 12.0
    M16 => 16.0
    M20 => 20.0
  }
}

///|
/// MetricSize::coarse_pitch_mm returns the ISO metric coarse pitch (ISO 261).
pub fn MetricSize::coarse_pitch_mm(self : MetricSize) -> Double {
  match self {
    M2 => 0.40
    M2_5 => 0.45
    M3 => 0.50
    M4 => 0.70
    M5 => 0.80
    M6 => 1.00
    M8 => 1.25
    M10 => 1.50
    M12 => 1.75
    M16 => 2.00
    M20 => 2.50
  }
}

///|
/// MetricSize::fine_pitch_mm returns one common fine pitch (ISO 261) for the
/// size. Fine pitches are a series, not a single value; this is the commonly
/// stocked first choice.
pub fn MetricSize::fine_pitch_mm(self : MetricSize) -> Double {
  match self {
    M2 => 0.25
    M2_5 => 0.35
    M3 => 0.35
    M4 => 0.50
    M5 => 0.50
    M6 => 0.75
    M8 => 1.00
    M10 => 1.25
    M12 => 1.25
    M16 => 1.50
    M20 => 1.50
  }
}

///|
/// MetricSize::from_diameter maps a nominal diameter in millimetres to a size.
pub fn MetricSize::from_diameter(d : Double) -> MetricSize? {
  for size in MetricSize::all() {
    if @common.near(size.nominal_diameter_mm(), d, tol=1.0e-6) {
      return Some(size)
    }
  }
  None
}

///|
fn ascii_upper_char(c : Char) -> Char {
  if c >= 'a' && c <= 'z' {
    Int32::unsafe_to_char(Char::to_int(c) - 32)
  } else {
    c
  }
}

///|
/// MetricSize::parse parses designations such as "M4" or "m4".
pub fn MetricSize::parse(text : String) -> MetricSize? {
  let raw = text.trim().to_owned()
  if raw.length() == 0 {
    return None
  }
  let first = ascii_upper_char(raw.get_char(0).unwrap())
  let token = if first == 'M' {
    String::unsafe_substring(raw, start=1, end=raw.length())
  } else {
    raw
  }
  match token {
    "2" => Some(M2)
    "2.5" => Some(M2_5)
    "3" => Some(M3)
    "4" => Some(M4)
    "5" => Some(M5)
    "6" => Some(M6)
    "8" => Some(M8)
    "10" => Some(M10)
    "12" => Some(M12)
    "16" => Some(M16)
    "20" => Some(M20)
    _ => None
  }
}

///|
/// ThreadHand distinguishes a right-hand thread (advances in +Z for a
/// counter-clockwise rotation looking down +Z) from a left-hand thread.
pub(all) enum ThreadHand {
  Right
  Left
}

///|
/// ThreadSeries names the pitch series a thread belongs to.
pub(all) enum ThreadSeries {
  Coarse
  Fine
  Custom
}

///|
/// ThreadSpec carries the ISO metric thread dimensions used by every threaded
/// component. Derived diameters use the ISO 68-1 basic profile.
pub(all) struct ThreadSpec {
  size : MetricSize
  nominal_diameter_mm : Double
  pitch_mm : Double
  hand : ThreadHand
  series : ThreadSeries
}

///|
/// ThreadSpec::coarse returns the coarse-thread specification for `size`.
pub fn ThreadSpec::coarse(size : MetricSize) -> ThreadSpec {
  {
    size,
    nominal_diameter_mm: size.nominal_diameter_mm(),
    pitch_mm: size.coarse_pitch_mm(),
    hand: Right,
    series: Coarse,
  }
}

///|
/// ThreadSpec::fine returns the first-choice fine thread for `size`.
pub fn ThreadSpec::fine(size : MetricSize) -> ThreadSpec {
  {
    size,
    nominal_diameter_mm: size.nominal_diameter_mm(),
    pitch_mm: size.fine_pitch_mm(),
    hand: Right,
    series: Fine,
  }
}

///|
/// ThreadSpec::custom validates an explicit pitch for a nominal size.
pub fn ThreadSpec::custom(
  size : MetricSize,
  pitch_mm : Double,
  hand~ : ThreadHand = Right,
) -> Result[ThreadSpec, @common.SpecError] {
  let d = size.nominal_diameter_mm()
  match @common.require_positive("thread pitch", pitch_mm) {
    Err(e) => Err(e)
    Ok(_) =>
      if pitch_mm >= d {
        Err(
          @common.InvalidParameter(
            "thread pitch (\{pitch_mm}) must be smaller than the nominal diameter (\{d})",
          ),
        )
      } else {
        Ok({ size, nominal_diameter_mm: d, pitch_mm, hand, series: Custom, })
      }
  }
}

///|
/// ThreadSpec::with_hand returns a copy with the requested hand.
pub fn ThreadSpec::with_hand(
  self : ThreadSpec,
  hand : ThreadHand,
) -> ThreadSpec {
  { ..self, hand, }
}

///|
/// ThreadSpec::height_h_mm returns the ISO 68-1 fundamental triangle height
/// `H = sqrt(3)/2 * P`.
pub fn ThreadSpec::height_h_mm(self : ThreadSpec) -> Double {
  0.8660254037844386 * self.pitch_mm
}

///|
/// ThreadSpec::pitch_diameter_mm returns the basic pitch diameter
/// `d2 = D2 = d - (3/4)H`.
pub fn ThreadSpec::pitch_diameter_mm(self : ThreadSpec) -> Double {
  self.nominal_diameter_mm - 0.75 * self.height_h_mm()
}

///|
/// ThreadSpec::external_minor_diameter_mm returns the basic external minor
/// diameter `d3 = d - (17/12)H`, exactly `d - 2 * h3`.
pub fn ThreadSpec::external_minor_diameter_mm(self : ThreadSpec) -> Double {
  self.nominal_diameter_mm - 17.0 / 12.0 * self.height_h_mm()
}

///|
/// ThreadSpec::internal_minor_diameter_mm returns the basic internal minor
/// diameter `D1 = D - (5/4)H`, exactly `d - 2 * H1`.
pub fn ThreadSpec::internal_minor_diameter_mm(self : ThreadSpec) -> Double {
  self.nominal_diameter_mm - 1.25 * self.height_h_mm()
}

///|
/// ThreadSpec::external_thread_depth_mm returns the basic external thread
/// depth `h3 = (17/24)H = 0.613435P`.
pub fn ThreadSpec::external_thread_depth_mm(self : ThreadSpec) -> Double {
  17.0 / 24.0 * self.height_h_mm()
}

///|
/// ThreadSpec::internal_thread_depth_mm returns the basic internal thread
/// depth `H1 = (5/8)H = 0.541266P`.
pub fn ThreadSpec::internal_thread_depth_mm(self : ThreadSpec) -> Double {
  5.0 / 8.0 * self.height_h_mm()
}

///|
/// ThreadSpec::crest_flat_mm returns the basic crest flat width `P/8`. This is
/// also the axial width of the external thread ridge at the major diameter.
pub fn ThreadSpec::crest_flat_mm(self : ThreadSpec) -> Double {
  self.pitch_mm / 8.0
}

///|
/// ThreadSpec::root_flat_mm returns the basic external-thread *groove* root
/// flat `P/6`. Do not confuse it with the material ridge width at the root,
/// which is `5P/6`; using `P/4` here (as an earlier approximation did) gives a
/// ~12-degree included flank angle instead of the 60-degree ISO basic profile.
pub fn ThreadSpec::root_flat_mm(self : ThreadSpec) -> Double {
  self.pitch_mm / 6.0
}

///|
/// ThreadSpec::external_thread_crest_width_mm returns the axial width of the
/// external thread ridge at the major diameter, `P/8`.
pub fn ThreadSpec::external_thread_crest_width_mm(self : ThreadSpec) -> Double {
  self.pitch_mm / 8.0
}

///|
/// ThreadSpec::external_thread_root_width_mm returns the axial width of the
/// external thread ridge at the basic minor diameter, `5P/6`. With the depth
/// `h3 = 17H/24` this gives the ISO 68-1 60-degree included flank angle.
pub fn ThreadSpec::external_thread_root_width_mm(self : ThreadSpec) -> Double {
  5.0 * self.pitch_mm / 6.0
}

///|
/// ThreadSpec::internal_thread_crest_width_mm returns the axial width of the
/// internal thread ridge at the basic minor diameter, `P/4`.
pub fn ThreadSpec::internal_thread_crest_width_mm(self : ThreadSpec) -> Double {
  self.pitch_mm / 4.0
}

///|
/// ThreadSpec::internal_thread_root_width_mm returns the axial width of the
/// internal thread ridge at the major diameter, `7P/8`. With the depth
/// `H1 = 5H/8` this gives the ISO 68-1 60-degree included flank angle.
pub fn ThreadSpec::internal_thread_root_width_mm(self : ThreadSpec) -> Double {
  7.0 * self.pitch_mm / 8.0
}

///|
/// ThreadSpec::lead_angle_deg returns the helix lead angle at the pitch
/// diameter: `atan(P / (pi * d2))`.
pub fn ThreadSpec::lead_angle_deg(self : ThreadSpec) -> Double {
  @math.atan(self.pitch_mm / (@math.PI * self.pitch_diameter_mm())) *
  180.0 /
  @math.PI
}

///|
/// ThreadSpec::designation returns a compact thread designation, e.g.
/// "M4x0.7-6H" for internal or "M4x0.7-6g" for external.
pub fn ThreadSpec::designation(
  self : ThreadSpec,
  external~ : Bool = true,
) -> String {
  let tolerance = if external { "6g" } else { "6H" }
  let hand = match self.hand {
    Right => ""
    Left => "-LH"
  }
  "\{self.size.designation()}x\{self.pitch_mm}-\{tolerance}\{hand}"
}
