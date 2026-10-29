///|
/// Severity classifies a `Diagnostic` produced by `Design::diagnostics`.
pub enum Severity {
  Info
  Warning
  Error
}

///|
/// Diagnostic describes something surprising about a `Design` without
/// compiling it.
///
/// The STEP backend never trims or subtracts: a top-level `Union` or
/// `Difference` concatenates its children's faces. Those nodes are reported as
/// nominal (a warning). A boolean nested inside another boolean contributes no
/// faces at all and is reported as an error.
pub enum Diagnostic {
  /// A top-level `Union` whose faces are concatenated, not merged.
  NominalUnion(String)
  /// A top-level `Difference` whose faces are concatenated, not subtracted.
  NominalDifference(String)
  /// A boolean nested inside another boolean; it contributes no faces.
  DroppedNestedBoolean(String)
  /// A shape whose compiler produces no faces (empty or degenerate).
  EmptySolid(String)
}

///|
/// Severity::is_error reports whether this severity blocks checked export.
pub fn Severity::is_error(self : Severity) -> Bool {
  match self {
    Error => true
    _ => false
  }
}

///|
/// Severity::all lists the severity levels from least to most urgent.
pub fn Severity::all() -> Array[Severity] {
  [Info, Warning, Error]
}

///|
/// Diagnostic::is_nominal reports whether the diagnostic describes a nominal
/// (face-concatenating) boolean.
pub fn Diagnostic::is_nominal(self : Diagnostic) -> Bool {
  match self {
    NominalUnion(_) | NominalDifference(_) => true
    _ => false
  }
}

///|
pub fn Diagnostic::severity(self : Diagnostic) -> Severity {
  match self {
    NominalUnion(_) => Warning
    NominalDifference(_) => Warning
    DroppedNestedBoolean(_) => Error
    EmptySolid(_) => Error
  }
}

///|
pub fn Diagnostic::message(self : Diagnostic) -> String {
  match self {
    NominalUnion(name) =>
      "union '\{name}' is nominal: faces are concatenated, not merged. Use an ExtrudedProfile with inner loops, or export via the Blender backend."
    NominalDifference(name) =>
      "difference '\{name}' is nominal: faces are concatenated, not subtracted. Use an ExtrudedProfile with inner loops, or export via the Blender backend."
    DroppedNestedBoolean(name) =>
      "boolean '\{name}' is nested inside another boolean and contributes no faces. Flatten the design or split it into separate nodes."
    EmptySolid(name) =>
      "shape '\{name}' produced no faces. Check its dimensions, profile, or path."
  }
}

///|
/// collect_diagnostics walks a shape tree, reporting nominal booleans at the
/// top level and dropped booleans deeper down.
fn collect_diagnostics(
  shape : Shape,
  name : String,
  depth : Int32,
  out : Array[Diagnostic],
) -> Unit {
  match shape {
    Union(u) => {
      if depth == 0 {
        out.push(NominalUnion(name))
      } else {
        out.push(DroppedNestedBoolean(name))
      }
      if u.nodes.is_empty() {
        out.push(EmptySolid(name))
      }
      for child in u.nodes {
        collect_diagnostics(child.shape, child.name, depth + 1, out)
      }
    }
    Difference(d) => {
      if depth == 0 {
        out.push(NominalDifference(name))
      } else {
        out.push(DroppedNestedBoolean(name))
      }
      collect_diagnostics(d.base.shape, d.base.name, depth + 1, out)
      for cutter in d.cutters {
        collect_diagnostics(cutter.shape, cutter.name, depth + 1, out)
      }
    }
    Cylinder(c) =>
      if c.diameter <= 0.0 || c.height <= 0.0 {
        out.push(EmptySolid(name))
      }
    ExtrudedProfile(e) =>
      if e.height_mm == 0.0 || e.profile.outer.length() < 3 {
        out.push(EmptySolid(name))
      }
    ExtrudedBezierProfile(e) =>
      if e.height_mm == 0.0 {
        out.push(EmptySolid(name))
      }
    SweptProfile(s) =>
      if s.path.points.length() < 2 || s.profile.vertices.length() < 3 {
        out.push(EmptySolid(name))
      }
    _ => ()
  }
}

///|
/// Design::diagnostics reports nominal and dropped booleans plus shapes that
/// would compile to nothing. It is a pure observation and does not compile or
/// mutate the design.
pub fn Design::diagnostics(self : Design) -> Array[Diagnostic] {
  let out : Array[Diagnostic] = []
  for node in self.nodes {
    collect_diagnostics(node.shape, node.name, 0, out)
  }
  out
}
