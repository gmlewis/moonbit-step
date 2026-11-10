///|
/// ApproximationKind classifies how a modelled feature departs from the ideal
/// mathematical surface.
///
/// The list is deliberately short and explicit: a feature is either modelled
/// exactly (and listed in `FeatureRecord::modeled`), approximated by one of
/// these documented schemes, or omitted with a reason. Labelling a sharp edge
/// as a chamfer is not an option.
pub(all) enum ApproximationKind {
  /// A continuously curved feature sampled as a short polyline/arc chain.
  PolylineArc
  /// A curved surface of revolution represented by a polygon ring stack.
  PolygonRevolve
  /// A swept/lofted feature sampled along its path.
  SweptSpline
  /// A feature whose size is an engineering default rather than a standard
  /// dimension.
  EngineeringDefault
}

///|
/// ApproximationKind::to_string returns a stable machine-readable token.
pub fn ApproximationKind::to_string(self : ApproximationKind) -> String {
  match self {
    PolylineArc => "PolylineArc"
    PolygonRevolve => "PolygonRevolve"
    SweptSpline => "SweptSpline"
    EngineeringDefault => "EngineeringDefault"
  }
}

///|
/// Approximation records one approximated feature with its stated deviation
/// and the control that produced it, so a downstream consumer can decide
/// whether the model is good enough for its purpose.
pub(all) struct Approximation {
  /// Feature token, e.g. "head-socket-band".
  feature : String
  kind : ApproximationKind
  /// Maximum geometric deviation in millimetres (chord/sag error).
  deviation_mm : Double
  /// Generator control, e.g. "circle_segments=64".
  control : String
}

///|
/// Approximation::new builds an approximation record.
pub fn Approximation::new(
  feature~ : String,
  kind~ : ApproximationKind,
  deviation_mm~ : Double,
  control~ : String,
) -> Approximation {
  { feature, kind, deviation_mm, control, }
}

///|
/// Approximation::documentation returns a one-line human-readable record.
pub fn Approximation::documentation(self : Approximation) -> String {
  "\{self.feature} (\{self.kind.to_string()}, deviation \{self.deviation_mm} mm, control \{self.control})"
}

///|
/// Omission records a feature that is intentionally absent, with a reason.
///
/// A simplified part is not a liar only when it says what it left out.
pub(all) struct Omission {
  /// Feature token, e.g. "head-chamfer".
  feature : String
  /// Why the feature is absent, e.g. "omitted at Simplified detail level".
  reason : String
}

///|
/// Omission::new builds an omission record.
pub fn Omission::new(feature~ : String, reason~ : String) -> Omission {
  { feature, reason, }
}

///|
/// Omission::documentation returns a one-line human-readable record.
pub fn Omission::documentation(self : Omission) -> String {
  "\{self.feature} (\{self.reason})"
}

///|
/// FeatureRecord is the machine-readable statement of which features a
/// component models, approximates, or omits.
///
/// It is carried on every `Component`, copied into the STEP header
/// documentation, and asserted by tests. `tolerance_mm` is the component's
/// stated geometric tolerance for the modelled representation as a whole.
pub(all) struct FeatureRecord {
  /// Exactly modelled features (analytic surfaces or exact planar/ruled
  /// geometry).
  modeled : Array[String]
  /// Approximated features with a stated deviation and control.
  approximated : Array[Approximation]
  /// Omitted features with a documented reason.
  omitted : Array[Omission]
  /// Overall stated representation tolerance in millimetres.
  tolerance_mm : Double
}

///|
/// FeatureRecord::empty returns a record that claims no modelled features and
/// no approximations. Used as the default before a builder fills it in.
pub fn FeatureRecord::empty() -> FeatureRecord {
  { modeled: [], approximated: [], omitted: [], tolerance_mm: 0.01, }
}

///|
/// FeatureRecord::new builds a feature record.
pub fn FeatureRecord::new(
  modeled~ : Array[String] = [],
  approximated~ : Array[Approximation] = [],
  omitted~ : Array[Omission] = [],
  tolerance_mm~ : Double = 0.01,
) -> FeatureRecord {
  { modeled, approximated, omitted, tolerance_mm, }
}

///|
/// FeatureRecord::with_modeled returns a copy with the modelled feature list.
pub fn FeatureRecord::with_modeled(
  self : FeatureRecord,
  modeled : Array[String],
) -> FeatureRecord {
  { ..self, modeled, }
}

///|
/// FeatureRecord::with_approximated returns a copy with the approximations.
pub fn FeatureRecord::with_approximated(
  self : FeatureRecord,
  approximated : Array[Approximation],
) -> FeatureRecord {
  { ..self, approximated, }
}

///|
/// FeatureRecord::with_omitted returns a copy with the omissions.
pub fn FeatureRecord::with_omitted(
  self : FeatureRecord,
  omitted : Array[Omission],
) -> FeatureRecord {
  { ..self, omitted, }
}

///|
/// FeatureRecord::with_tolerance returns a copy with a new overall tolerance.
pub fn FeatureRecord::with_tolerance(
  self : FeatureRecord,
  tolerance_mm : Double,
) -> FeatureRecord {
  { ..self, tolerance_mm, }
}

///|
/// FeatureRecord::add_modeled returns a copy with one more modelled feature.
pub fn FeatureRecord::add_modeled(
  self : FeatureRecord,
  feature : String,
) -> FeatureRecord {
  let modeled = self.modeled.copy()
  modeled.push(feature)
  { ..self, modeled, }
}

///|
/// FeatureRecord::add_approximated returns a copy with one more approximation.
pub fn FeatureRecord::add_approximated(
  self : FeatureRecord,
  approximation : Approximation,
) -> FeatureRecord {
  let approximated = self.approximated.copy()
  approximated.push(approximation)
  { ..self, approximated, }
}

///|
/// FeatureRecord::add_omitted returns a copy with one more omission.
pub fn FeatureRecord::add_omitted(
  self : FeatureRecord,
  omission : Omission,
) -> FeatureRecord {
  let omitted = self.omitted.copy()
  omitted.push(omission)
  { ..self, omitted, }
}

///|
/// FeatureRecord::has_modeled reports whether `feature` is in the modelled
/// list.
pub fn FeatureRecord::has_modeled(
  self : FeatureRecord,
  feature : String,
) -> Bool {
  self.modeled.any(fn(f) { f == feature })
}

///|
/// FeatureRecord::has_approximated reports whether `feature` is approximated.
pub fn FeatureRecord::has_approximated(
  self : FeatureRecord,
  feature : String,
) -> Bool {
  self.approximated.any(fn(a) { a.feature == feature })
}

///|
/// FeatureRecord::omission_reason returns the documented reason a feature is
/// omitted, or `None` when it is not omitted.
pub fn FeatureRecord::omission_reason(
  self : FeatureRecord,
  feature : String,
) -> String? {
  for o in self.omitted {
    if o.feature == feature {
      return Some(o.reason)
    }
  }
  None
}

///|
/// FeatureRecord::documentation returns the multi-line STEP header block.
pub fn FeatureRecord::documentation(self : FeatureRecord) -> String {
  let lines : Array[String] = []
  if !self.modeled.is_empty() {
    lines.push("Features modeled:      " + self.modeled.join(", "))
  }
  if !self.approximated.is_empty() {
    lines.push(
      "Features approximated: " +
      self.approximated.map(fn(a) { a.documentation() }).join("; "),
    )
  }
  if !self.omitted.is_empty() {
    lines.push(
      "Features omitted:      " +
      self.omitted.map(fn(o) { o.documentation() }).join("; "),
    )
  }
  lines.push("Feature tolerance:     " + self.tolerance_mm.to_string() + " mm")
  lines.join("\n")
}

///|
/// chord_deviation returns the maximum sag (chord) error of a circle of
/// `radius` sampled into `segments` chords.
///
/// It is `r * (1 - cos(pi / segments))`, the exact deviation used to justify a
/// polyline approximation.
pub fn chord_deviation(radius : Double, segments : Int32) -> Double {
  let n = if segments < 3 { 3 } else { segments }
  radius * (1.0 - @math.cos(@math.PI / Double::from_int(n)))
}
