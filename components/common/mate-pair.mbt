///|
/// The diameter tolerance used when two connectors declare a nominal diameter.
/// Two nominal diameters within this tolerance describe the same interface.
const MATE_DIAMETER_TOLERANCE_MM : Double = 1.0e-6

///|
/// MatePairError is the typed failure for validating or resolving a mate pair.
#derive(Debug, Eq)
pub(all) enum MatePairError {
  /// One of the pair's named connectors is missing from the supplied values.
  MissingConnector(String)
  /// The assembly instance named by a caller does not exist.
  MissingInstance(String)
  /// A supplied connector's name does not match the pair. Payload is
  /// `(expected, found)`.
  ConnectorNameMismatch(String, String)
  /// The two interface kinds cannot mate. Payload is
  /// `(parent kind, child kind)`.
  IncompatibleKind(String, String)
  /// The declared genders cannot engage. Payload is
  /// `(parent gender, child gender)`.
  IncompatibleGender(String, String)
  /// The declared nominal diameters differ. Payload is
  /// `(parent diameter, child diameter)`.
  DiameterMismatch(Double, Double)
  /// The pair's declared fit contradicts the connectors' declared fits.
  FitMismatch(String)
  /// A connector is structurally invalid.
  InvalidConnector(String)
  /// The pair itself is malformed (empty names, non-finite values).
  InvalidPair(String)
}

///|
pub extend MatePairError with @debug.Debug::{to_repr}

///|
pub extend MatePairError with Eq::{not_equal, equal}

///|
/// MatePairError::message returns a human-readable message.
pub fn MatePairError::message(self : MatePairError) -> String {
  match self {
    MissingConnector(name) => "missing mate connector: \{name}"
    MissingInstance(name) => "missing assembly instance: \{name}"
    ConnectorNameMismatch(expected, found) =>
      "connector name mismatch: expected \{expected}, got \{found}"
    IncompatibleKind(parent, child) =>
      "incompatible mate kinds: \{parent} cannot mate \{child}"
    IncompatibleGender(parent, child) =>
      "incompatible mate genders: \{parent} cannot mate \{child}"
    DiameterMismatch(parent, child) =>
      "diameter mismatch: \{parent} mm does not match \{child} mm"
    FitMismatch(reason) => "incompatible declared fit: \{reason}"
    InvalidConnector(reason) => "invalid connector: \{reason}"
    InvalidPair(reason) => "invalid mate pair: \{reason}"
  }
}

///|
/// MatePairError::to_string is an alias for `message`.
pub fn MatePairError::to_string(self : MatePairError) -> String {
  self.message()
}

///|
/// MatePair is the relationship between two named connectors.
///
/// It owns the parent connector name, the child connector name, the offset
/// along the parent axis (millimetres), the twist about the parent axis
/// (degrees), the axis-flip flag, and the declared fit. It does not duplicate
/// either connector's frame: the frames live on the connectors.
///
/// A pair is geometric. Kinematic kind, limits, dynamics, mimic, and
/// transmission data stay in the URDF/CAD joint types.
#derive(Debug, Eq)
pub(all) struct MatePair {
  parent : String
  child : String
  offset_mm : Double
  twist_deg : Double
  flip_axis : Bool
  fit : @cad.Fit
  description : String
}

///|
pub extend MatePair with @debug.Debug::{to_repr}

///|
pub extend MatePair with Eq::{not_equal, equal}

///|
/// MatePair::new builds a relationship record. Defaults describe a nominal,
/// unshifted, untwisted pair whose axes are not flipped.
pub fn MatePair::new(
  parent~ : String,
  child~ : String,
  offset_mm~ : Double = 0.0,
  twist_deg~ : Double = 0.0,
  flip_axis~ : Bool = false,
  fit~ : @cad.Fit = @cad.Fit::Nominal,
  description~ : String = "",
) -> MatePair {
  { parent, child, offset_mm, twist_deg, flip_axis, fit, description, }
}

///|
/// MateAlignment is the resolved relationship of a mate pair.
///
/// `placement` maps the child component's local frame into the parent's frame
/// at the mated pose. `axis` is the joint/approach axis expressed in the child
/// frame. `axis_flipped` records that `resolve` applied the interface's
/// anti-parallel convention on top of the caller's `flip_axis` request, so the
/// extra half-turn is never silent.
#derive(Debug, Eq)
pub(all) struct MateAlignment {
  placement : Placement
  axis : @cad.Vec3
  parent_connector : MateConnector
  child_connector : MateConnector
  fit : @cad.Fit
  /// True for shaft-into-bore and plane-on-plane interfaces, whose insertion
  /// axes or outward normals are anti-parallel when assembled.
  insertion_anti_parallel : Bool
  /// True when `resolve` negated the returned axis to enforce the interface
  /// convention beyond the caller's `flip_axis` request.
  axis_flipped : Bool
}

///|
pub extend MateAlignment with @debug.Debug::{to_repr}

///|
pub extend MateAlignment with Eq::{not_equal, equal}

///|
/// MateAlignment::declared_clearance_mm returns the per-face clearance implied
/// by the pair's declared fit. It is intent metadata, not a modelled offset.
pub fn MateAlignment::declared_clearance_mm(self : MateAlignment) -> Double {
  self.fit.per_face_mm()
}

///|
/// MateAlignment::nominal_diameter_gap_mm returns the absolute difference of
/// the two declared nominal diameters, or zero when either is unspecified.
pub fn MateAlignment::nominal_diameter_gap_mm(self : MateAlignment) -> Double {
  match (self.parent_connector.diameter_mm, self.child_connector.diameter_mm) {
    (Some(a), Some(b)) => (a - b).abs()
    _ => 0.0
  }
}

///|
/// interface_anti_parallel reports whether the assembled interface has
/// anti-parallel axes: a shaft entering a bore, or two plane faces in contact
/// with outward normals facing each other.
pub fn interface_anti_parallel(a : MateKind, b : MateKind) -> Bool {
  match (a, b) {
    (CylindricalShaft, CylindricalBore) | (CylindricalBore, CylindricalShaft) =>
      true
    (PlaneFace, PlaneFace) => true
    _ => false
  }
}

///|
/// kinds_compatible reports whether two interface kinds can mate. A `Datum`
/// mates with anything because it makes no contact claim.
pub fn kinds_compatible(parent : MateKind, child : MateKind) -> Bool {
  match (parent, child) {
    (Datum, _) | (_, Datum) => true
    (PlaneFace, PlaneFace) => true
    (CylindricalShaft, CylindricalBore) | (CylindricalBore, CylindricalShaft) =>
      true
    (Threaded, Threaded) => true
    (ProfileSlot, ProfileSlot) => true
    _ => false
  }
}

///|
/// genders_compatible reports whether two genders can engage. Neutral mates
/// with anything; plane faces and datums carry no gender requirement.
pub fn genders_compatible(
  parent : MateKind,
  parent_gender : MateGender,
  child : MateKind,
  child_gender : MateGender,
) -> Bool {
  if parent == Datum || child == Datum {
    return true
  }
  if parent == PlaneFace && child == PlaneFace {
    return true
  }
  match (parent_gender, child_gender) {
    (Neutral, _) | (_, Neutral) => true
    (Male, Female) | (Female, Male) => true
    _ => false
  }
}

///|
/// fits_compatible reports whether the pair's declared fit agrees with the
/// connectors' declarations.
///
/// When both connectors leave the fit at `Nominal`, the pair owns the intent and
/// any value is allowed. Otherwise the pair's fit must match at least one
/// explicitly declared connector fit.
pub fn fits_compatible(
  parent_fit : @cad.Fit,
  child_fit : @cad.Fit,
  pair_fit : @cad.Fit,
) -> Bool {
  let parent_declared = parent_fit != @cad.Fit::Nominal
  let child_declared = child_fit != @cad.Fit::Nominal
  if !parent_declared && !child_declared {
    return true
  }
  pair_fit == parent_fit || pair_fit == child_fit
}

///|
/// snap_connectors snaps a child connector frame onto a parent connector frame.
///
/// It reproduces the sibling URDF `snap_mates` semantics: translate along the
/// parent axis by `offset_mm`, rotate about the parent axis by `twist_rad`,
/// then apply the inverse child frame. It returns the child-component placement
/// at `q = 0` and the joint axis expressed in the child frame.
///
/// Both connectors must be expressed in the same parent frame. Call
/// `MateConnector::transformed(parent_placement)` first for placed components.
pub fn snap_connectors(
  parent : MateConnector,
  child : MateConnector,
  offset_mm~ : Double = 0.0,
  twist_rad~ : Double = 0.0,
  flip_axis~ : Bool = false,
) -> (Placement, @cad.Vec3) {
  let u = normalize_dir(parent.axis)
  let t_offset : Placement = {
    rot: Placement::rotation_axis_angle(u, twist_rad).rot,
    trans: (u.0 * offset_mm, u.1 * offset_mm, u.2 * offset_mm),
  }
  let placement = Placement::compose(
    Placement::compose(parent.placement, t_offset),
    Placement::inverse(child.placement),
  )
  let dir = if flip_axis { (-u.0, -u.1, -u.2) } else { u }
  (placement, normalize_dir(child.placement.apply_dir(dir)))
}

///|
/// MatePair::validate checks that the supplied connector values match the pair
/// and that their kinds, genders, diameters, and declared fits are compatible.
pub fn MatePair::validate(
  self : MatePair,
  parent : MateConnector,
  child : MateConnector,
) -> Result[Unit, MatePairError] {
  if self.parent == "" || self.child == "" {
    return Err(
      InvalidPair("parent and child connector names must be non-empty"),
    )
  }
  if !is_finite(self.offset_mm) || !is_finite(self.twist_deg) {
    return Err(InvalidPair("offset and twist must be finite"))
  }
  if parent.name != self.parent {
    return Err(ConnectorNameMismatch(self.parent, parent.name))
  }
  if child.name != self.child {
    return Err(ConnectorNameMismatch(self.child, child.name))
  }
  match parent.validate() {
    Err(e) => return Err(InvalidConnector(e.message()))
    Ok(_) => ()
  }
  match child.validate() {
    Err(e) => return Err(InvalidConnector(e.message()))
    Ok(_) => ()
  }
  if !kinds_compatible(parent.kind, child.kind) {
    return Err(
      IncompatibleKind(parent.kind.to_string(), child.kind.to_string()),
    )
  }
  if !genders_compatible(parent.kind, parent.gender, child.kind, child.gender) {
    return Err(
      IncompatibleGender(parent.gender.to_string(), child.gender.to_string()),
    )
  }
  match (parent.diameter_mm, child.diameter_mm) {
    (Some(a), Some(b)) =>
      if (a - b).abs() > MATE_DIAMETER_TOLERANCE_MM {
        return Err(DiameterMismatch(a, b))
      }
    _ => ()
  }
  if !fits_compatible(parent.fit, child.fit, self.fit) {
    return Err(
      FitMismatch(
        "pair fit \{fit_token(self.fit)} matches neither parent (\{fit_token(parent.fit)}) nor child (\{fit_token(child.fit)})",
      ),
    )
  }
  Ok(())
}

///|
/// MatePair::resolve validates the pair and snaps the child connector onto the
/// parent connector.
///
/// Unlike `snap_connectors`, this is interface-aware: it checks kind, gender,
/// diameter, and fit, converts the pair's degree twist to radians, and enforces
/// the anti-parallel insertion convention for shaft/bore and plane/plane
/// interfaces. When that enforcement changes the returned axis it is recorded
/// in `MateAlignment::axis_flipped`.
pub fn MatePair::resolve(
  self : MatePair,
  parent : MateConnector,
  child : MateConnector,
) -> Result[MateAlignment, MatePairError] {
  match self.validate(parent, child) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let anti = interface_anti_parallel(parent.kind, child.kind)
  let (placement, raw_axis) = snap_connectors(
    parent,
    child,
    offset_mm=self.offset_mm,
    twist_rad=self.twist_deg * @math.PI / 180.0,
    flip_axis=self.flip_axis,
  )
  let child_axis = normalize_dir(child.axis)
  let mut axis = raw_axis
  let mut axis_flipped = false
  if anti && dir_dot(axis, child_axis) > 0.0 {
    axis = (-axis.0, -axis.1, -axis.2)
    axis_flipped = true
  }
  Ok({
    placement,
    axis,
    parent_connector: parent,
    child_connector: child,
    fit: self.fit,
    insertion_anti_parallel: anti,
    axis_flipped,
  })
}
