///|
/// Metadata identifies a component instance and records where its dimensions
/// came from.
///
/// `source` is free-form but should name the standard, revision, and table (or
/// manufacturer catalogue) used. It is copied into the generated STEP header
/// documentation so a file never loses its provenance.
pub(all) struct Metadata {
  /// Human-facing designation, e.g. "ISO 4762 - M4 x 20".
  designation : String
  /// Exact standard/revision, e.g. "ISO 4762:2004".
  standard : String
  /// Component family, e.g. "socket head cap screw".
  family : String
  /// Nominal size token, e.g. "M4".
  size : String
  /// Nominal length in millimetres when the family has one.
  length_mm : Double?
  /// Material label, if the caller supplied one.
  material : String?
  /// Provenance note for the dimensional data.
  source : String
}

///|
/// Metadata::new builds a metadata record. Empty fields are allowed; callers
/// should fill everything they can verify.
pub fn Metadata::new(
  designation~ : String,
  standard~ : String = "",
  family~ : String = "",
  size~ : String = "",
  length_mm? : Double,
  material? : String,
  source~ : String = "",
) -> Metadata {
  { designation, standard, family, size, length_mm, material, source, }
}

///|
/// Metadata::with_material returns a copy with a material label.
pub fn Metadata::with_material(self : Metadata, material : String) -> Metadata {
  { ..self, material: Some(material), }
}

///|
/// Metadata::summary returns a one-line description used in component names and
/// documentation.
pub fn Metadata::summary(self : Metadata) -> String {
  if self.designation != "" {
    self.designation
  } else if self.family != "" && self.size != "" {
    "\{self.family} \{self.size}"
  } else if self.family != "" {
    self.family
  } else {
    self.standard
  }
}

///|
/// Metadata::documentation returns a multi-line provenance block for a STEP
/// file header.
pub fn Metadata::documentation(self : Metadata) -> String {
  let lines : Array[String] = [
    "Component:  " + self.designation,
    "Standard:   " + self.standard,
    "Family:     " + self.family,
    "Size:       " + self.size,
  ]
  match self.length_mm {
    Some(l) => lines.push("Length:     " + l.to_string() + " mm")
    None => ()
  }
  match self.material {
    Some(m) => lines.push("Material:   " + m)
    None => ()
  }
  if self.source != "" {
    lines.push("Data source: " + self.source)
  }
  lines.join("\n")
}
