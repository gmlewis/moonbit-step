///|
/// MateKind classifies the mechanical interface a `MateConnector` describes.
///
/// The kind is CAD metadata. It never changes exported geometry: a connector is
/// a named frame, not a solid feature.
#derive(Debug, Eq)
pub(all) enum MateKind {
  /// Planar contact face. `axis` is the outward normal.
  PlaneFace
  /// Round hole. `axis` points into the bore.
  CylindricalBore
  /// Round shaft. `axis` runs along the shaft, toward the free end.
  CylindricalShaft
  /// Threaded interface. `axis` is the engagement axis.
  Threaded
  /// Extrusion or channel slot. `axis` is the insertion direction.
  ProfileSlot
  /// Reference frame with no contact claim.
  Datum
}

///|
pub extend MateKind with @debug.Debug::{to_repr}

///|
pub extend MateKind with Eq::{not_equal, equal}

///|
/// MateKind::to_string returns a stable lowercase token.
pub fn MateKind::to_string(self : MateKind) -> String {
  match self {
    PlaneFace => "plane-face"
    CylindricalBore => "cylindrical-bore"
    CylindricalShaft => "cylindrical-shaft"
    Threaded => "threaded"
    ProfileSlot => "profile-slot"
    Datum => "datum"
  }
}

///|
/// MateKind::requires_gender reports whether the kind describes geometric
/// engagement that should be declared male or female rather than neutral.
pub fn MateKind::requires_gender(self : MateKind) -> Bool {
  match self {
    CylindricalBore | CylindricalShaft | Threaded => true
    PlaneFace | ProfileSlot | Datum => false
  }
}

///|
/// MateGender describes geometric engagement, not strength or load capacity.
///
/// A male shaft engages a female bore. `Neutral` is correct for datum frames,
/// plane faces, and slots that do not carry an insertion gender.
#derive(Debug, Eq)
pub(all) enum MateGender {
  Neutral
  Male
  Female
}

///|
pub extend MateGender with @debug.Debug::{to_repr}

///|
pub extend MateGender with Eq::{not_equal, equal}

///|
/// MateGender::to_string returns a stable lowercase token.
pub fn MateGender::to_string(self : MateGender) -> String {
  match self {
    Neutral => "neutral"
    Male => "male"
    Female => "female"
  }
}

///|
/// MateError is the typed failure for connector lookup and validation.
#derive(Debug, Eq)
pub(all) enum MateError {
  /// No connector with this name exists on the component.
  UnknownConnector(String)
  /// A connector with this name is already registered on the component.
  DuplicateConnector(String)
  /// The connector is structurally invalid; the message names the reason.
  InvalidConnector(String)
}

///|
pub extend MateError with @debug.Debug::{to_repr}

///|
pub extend MateError with Eq::{not_equal, equal}

///|
/// MateError::message returns a human-readable message.
pub fn MateError::message(self : MateError) -> String {
  match self {
    UnknownConnector(name) => "unknown mate connector: \{name}"
    DuplicateConnector(name) => "duplicate mate connector: \{name}"
    InvalidConnector(reason) => "invalid mate connector: \{reason}"
  }
}

///|
/// MateError::to_string is an alias for `message`.
pub fn MateError::to_string(self : MateError) -> String {
  self.message()
}

///|
/// MateConnector is a named attachment frame (port) on one component.
///
/// `placement` is a full rigid frame in the component-local frame, in
/// millimetres and degrees. `axis` is an independent unit direction in the
/// component-local frame: the approach, insertion, or joint axis. It defaults to
/// +Z but is not required to be the placement's +Z; this matches the URDF
/// `MateConnector`, whose origin (`rpy`) and axis are independent.
///
/// Connector names are stable, unique within a component, and lower-case
/// kebab-case by convention (`shaft`, `bore`, `mount-front`, `bolt-hole-1`).
///
/// Connectors are metadata. Adding one never changes the component's exported
/// STEP geometry, bounding box, layer count, or volume.
#derive(Debug, Eq)
pub(all) struct MateConnector {
  name : String
  placement : Placement
  axis : @cad.Vec3
  kind : MateKind
  gender : MateGender
  diameter_mm : Double?
  depth_mm : Double?
  fit : @cad.Fit
  description : String
}

///|
pub extend MateConnector with @debug.Debug::{to_repr}

///|
pub extend MateConnector with Eq::{not_equal, equal}

///|
/// fit_token returns the stable token for a declared fit.
pub fn fit_token(fit : @cad.Fit) -> String {
  match fit {
    @cad.Fit::Nominal => "nominal"
    @cad.Fit::Close => "close"
    @cad.Fit::Free => "free"
    @cad.Fit::Press => "press"
  }
}

///|
/// normalize_dir returns a unit direction, or the zero vector when `v` has no
/// usable length.
pub fn normalize_dir(v : @cad.Vec3) -> @cad.Vec3 {
  let (x, y, z) = v
  let len = (x * x + y * y + z * z).sqrt()
  if len < 1.0e-12 {
    (0.0, 0.0, 0.0)
  } else {
    (x / len, y / len, z / len)
  }
}

///|
/// dir_dot returns the dot product of two directions.
pub fn dir_dot(a : @cad.Vec3, b : @cad.Vec3) -> Double {
  a.0 * b.0 + a.1 * b.1 + a.2 * b.2
}

///|
/// MateConnector::new builds a connector, normalizing a usable axis.
///
/// Structural problems (empty name, non-finite placement, zero axis, negative
/// diameter) are reported by `validate` and by `Component::with_connector`; the
/// constructor itself is total so it can be used to build test values.
pub fn MateConnector::new(
  name : String,
  placement~ : Placement = Placement::identity(),
  axis~ : @cad.Vec3 = (0.0, 0.0, 1.0),
  kind~ : MateKind = Datum,
  gender~ : MateGender = Neutral,
  diameter_mm? : Double,
  depth_mm? : Double,
  fit~ : @cad.Fit = @cad.Fit::Nominal,
  description~ : String = "",
) -> MateConnector {
  {
    name,
    placement,
    axis: normalize_dir(axis),
    kind,
    gender,
    diameter_mm,
    depth_mm,
    fit,
    description,
  }
}

///|
/// MateConnector::from_mm_deg builds a connector from millimetre translations
/// and degree rotations plus an optional component-local axis.
pub fn MateConnector::from_mm_deg(
  name : String,
  x~ : Double = 0.0,
  y~ : Double = 0.0,
  z~ : Double = 0.0,
  rx_deg~ : Double = 0.0,
  ry_deg~ : Double = 0.0,
  rz_deg~ : Double = 0.0,
  axis~ : @cad.Vec3 = (0.0, 0.0, 1.0),
  kind~ : MateKind = Datum,
  gender~ : MateGender = Neutral,
  diameter_mm? : Double,
  depth_mm? : Double,
  fit~ : @cad.Fit = @cad.Fit::Nominal,
  description~ : String = "",
) -> MateConnector {
  MateConnector::new(
    name,
    placement=Placement::at(x, y, z, rx=rx_deg, ry=ry_deg, rz=rz_deg),
    axis~,
    kind~,
    gender~,
    diameter_mm?,
    depth_mm?,
    fit~,
    description~,
  )
}

///|
/// MateConnector::from_m_rad builds a connector from URDF units: metres and
/// radians. The connector stores millimetres and degrees internally.
pub fn MateConnector::from_m_rad(
  name : String,
  xyz_m : @cad.Vec3,
  rpy_rad : @cad.Vec3,
  axis~ : @cad.Vec3 = (0.0, 0.0, 1.0),
  kind~ : MateKind = Datum,
  gender~ : MateGender = Neutral,
  diameter_mm? : Double,
  depth_mm? : Double,
  fit~ : @cad.Fit = @cad.Fit::Nominal,
  description~ : String = "",
) -> MateConnector {
  let (x, y, z) = xyz_m
  let (roll, pitch, yaw) = rpy_rad
  let to_deg = 180.0 / @math.PI
  MateConnector::new(
    name,
    placement=Placement::at(
      x * 1000.0,
      y * 1000.0,
      z * 1000.0,
      rx=roll * to_deg,
      ry=pitch * to_deg,
      rz=yaw * to_deg,
    ),
    axis~,
    kind~,
    gender~,
    diameter_mm?,
    depth_mm?,
    fit~,
    description~,
  )
}

///|
/// MateConnector::to_m_rad returns `(xyz_m, rpy_rad)` at the URDF boundary.
pub fn MateConnector::to_m_rad(self : MateConnector) -> (@cad.Vec3, @cad.Vec3) {
  let (x, y, z) = self.placement.trans
  let (rx, ry, rz) = self.placement.to_euler()
  let to_rad = @math.PI / 180.0
  ((x * 0.001, y * 0.001, z * 0.001), (rx * to_rad, ry * to_rad, rz * to_rad))
}

///|
/// MateConnector::transformed composes `parent` into the connector frame and
/// rotates its axis as a direction.
///
/// Use this before snapping connectors that belong to components already placed
/// in a common assembly frame.
pub fn MateConnector::transformed(
  self : MateConnector,
  parent : Placement,
) -> MateConnector {
  {
    ..self,
    placement: Placement::compose(parent, self.placement),
    axis: normalize_dir(parent.apply_dir(self.axis)),
  }
}

///|
/// MateConnector::has_finite_placement reports whether every part of the frame
/// is finite.
fn MateConnector::has_finite_placement(self : MateConnector) -> Bool {
  let (x, y, z) = self.placement.trans
  let m = self.placement.rot
  is_finite(x) &&
  is_finite(y) &&
  is_finite(z) &&
  is_finite(m.m00) &&
  is_finite(m.m01) &&
  is_finite(m.m02) &&
  is_finite(m.m10) &&
  is_finite(m.m11) &&
  is_finite(m.m12) &&
  is_finite(m.m20) &&
  is_finite(m.m21) &&
  is_finite(m.m22)
}

///|
/// is_mate_name_valid checks the documented connector naming convention without
/// requiring a full parser: non-empty and free of whitespace.
pub fn is_mate_name_valid(name : String) -> Bool {
  name != "" &&
  !name.contains(" ") &&
  !name.contains("\t") &&
  !name.contains("\n")
}

///|
/// MateConnector::validate checks the structural invariants of one connector.
///
/// It rejects empty or whitespace-bearing names, non-finite frames, zero or
/// non-unit axes, negative diameter/depth, and a kind/gender combination that
/// contradicts the interface (for example a `CylindricalBore` declared male).
pub fn MateConnector::validate(self : MateConnector) -> Result[Unit, MateError] {
  if !is_mate_name_valid(self.name) {
    return Err(
      InvalidConnector(
        "name must be non-empty and contain no whitespace, got \"\{self.name}\"",
      ),
    )
  }
  if !self.has_finite_placement() {
    return Err(InvalidConnector("placement must be finite in \{self.name}"))
  }
  let (ax, ay, az) = self.axis
  if !is_finite(ax) || !is_finite(ay) || !is_finite(az) {
    return Err(InvalidConnector("axis must be finite in \{self.name}"))
  }
  let len = (ax * ax + ay * ay + az * az).sqrt()
  if len < 1.0e-12 {
    return Err(InvalidConnector("axis must be non-zero in \{self.name}"))
  }
  if (len - 1.0).abs() > 1.0e-6 {
    return Err(InvalidConnector("axis must be unit length in \{self.name}"))
  }
  match self.diameter_mm {
    Some(d) =>
      if !is_finite(d) || d < 0.0 {
        return Err(
          InvalidConnector(
            "diameter must be finite and non-negative in \{self.name}",
          ),
        )
      }
    None => ()
  }
  match self.depth_mm {
    Some(d) =>
      if !is_finite(d) || d < 0.0 {
        return Err(
          InvalidConnector(
            "depth must be finite and non-negative in \{self.name}",
          ),
        )
      }
    None => ()
  }
  match (self.kind, self.gender) {
    (CylindricalBore, Male) =>
      return Err(
        InvalidConnector("a cylindrical bore cannot be male in \{self.name}"),
      )
    (CylindricalShaft, Female) =>
      return Err(
        InvalidConnector("a cylindrical shaft cannot be female in \{self.name}"),
      )
    (PlaneFace, Male) | (PlaneFace, Female) =>
      return Err(
        InvalidConnector(
          "a plane face is neutral, not male/female, in \{self.name}",
        ),
      )
    (ProfileSlot, Male) | (ProfileSlot, Female) =>
      return Err(
        InvalidConnector(
          "a profile slot is neutral, not male/female, in \{self.name}",
        ),
      )
    (Datum, Male) | (Datum, Female) =>
      return Err(
        InvalidConnector("a datum is neutral, not male/female, in \{self.name}"),
      )
    _ => ()
  }
  Ok(())
}

///|
/// MateConnector::documentation returns a one-line human-readable record.
pub fn MateConnector::documentation(self : MateConnector) -> String {
  let (x, y, z) = self.placement.trans
  let (rx, ry, rz) = self.placement.to_euler()
  let (ax, ay, az) = self.axis
  let gender = self.gender.to_string()
  let kind = self.kind.to_string()
  let mut text = "\{self.name}: \{kind} \{gender} at (\{x}, \{y}, \{z}) mm, rpy (\{rx}, \{ry}, \{rz}) deg, axis (\{ax}, \{ay}, \{az})"
  match self.diameter_mm {
    Some(d) => text = text + ", diameter \{d} mm"
    None => ()
  }
  match self.depth_mm {
    Some(d) => text = text + ", depth \{d} mm"
    None => ()
  }
  text = text + ", fit \{fit_token(self.fit)}"
  if self.description != "" {
    text = text + " — \{self.description}"
  }
  text
}
