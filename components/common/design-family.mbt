///|
/// ParamSpec describes one named, unit-tagged, bounded design parameter.
///
/// The unit is a label only (`"mm"`, `"deg"`, `"count"`); the numeric value is
/// stored as a bare `Double`. Dimensions in this library are millimetres unless
/// a spec says otherwise.
pub(all) struct ParamSpec {
  name : String
  unit : String
  default_mm : Double
  min_mm : Double
  max_mm : Double
  description : String
}

///|
/// ParamSpec::new builds a parameter declaration. `min_mm` is inclusive and
/// `default_mm` must lie inside the range; `ParamSpec::validate` checks that.
pub fn ParamSpec::new(
  name~ : String,
  default_mm~ : Double,
  min_mm~ : Double = 0.0,
  max_mm~ : Double = 1.0e9,
  unit~ : String = "mm",
  description~ : String = "",
) -> ParamSpec {
  { name, unit, default_mm, min_mm, max_mm, description, }
}

///|
/// ParamSpec::validate checks a spec declaration itself.
pub fn ParamSpec::validate(self : ParamSpec) -> Result[Unit, SpecError] {
  if self.name == "" {
    return Err(InvalidParameter("parameter spec has an empty name"))
  }
  if self.min_mm > self.max_mm {
    return Err(
      InvalidParameter(
        "parameter '\{self.name}' has min > max (\{self.min_mm} > \{self.max_mm})",
      ),
    )
  }
  match
    require_in_range(
      "parameter '\{self.name}' default",
      self.default_mm,
      self.min_mm,
      self.max_mm,
    ) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  Ok(())
}

///|
/// ParamSpec::documentation returns one human-readable spec line.
pub fn ParamSpec::documentation(self : ParamSpec) -> String {
  let unit = if self.unit == "" { "" } else { " " + self.unit }
  let range = if self.min_mm == 0.0 && self.max_mm == 1.0e9 {
    ""
  } else {
    " [\{self.min_mm}, \{self.max_mm}]"
  }
  let note = if self.description == "" {
    ""
  } else {
    " — " + self.description
  }
  "\{self.name} = \{self.default_mm}\{unit}\{range}\{note}"
}

///|
/// ParamSet is a validated name-to-value set declared by a list of specs.
///
/// Every spec is present exactly once. Values are validated against their spec
/// on construction and on every `with` update.
pub(all) struct ParamSet {
  specs : Array[ParamSpec]
  values : Map[String, Double]
}

///|
/// ParamSet::defaults builds a set using every spec's default value.
pub fn ParamSet::defaults(
  specs : Array[ParamSpec],
) -> Result[ParamSet, SpecError] {
  let values : Map[String, Double] = Map([])
  for spec in specs {
    match spec.validate() {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    if values.get(spec.name) is Some(_) {
      return Err(InvalidParameter("duplicate parameter '\{spec.name}'"))
    }
    values.set(spec.name, spec.default_mm)
  }
  Ok({ specs, values, })
}

///|
/// ParamSet::from_values builds a set from defaults plus named overrides.
///
/// Unknown names are rejected rather than ignored.
pub fn ParamSet::from_values(
  specs : Array[ParamSpec],
  values : Array[(String, Double)],
) -> Result[ParamSet, SpecError] {
  let mut set = match ParamSet::defaults(specs) {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  for entry in values {
    let (name, value) = entry
    match set.set_value(name, value) {
      Err(e) => return Err(e)
      Ok(s) => set = s
    }
  }
  Ok(set)
}

///|
/// ParamSet::spec returns the declaration for a name.
pub fn ParamSet::spec(
  self : ParamSet,
  name : String,
) -> Result[ParamSpec, SpecError] {
  for spec in self.specs {
    if spec.name == name {
      return Ok(spec)
    }
  }
  Err(InvalidParameter("unknown parameter '\{name}'"))
}

///|
/// ParamSet::get returns a validated value.
pub fn ParamSet::get(
  self : ParamSet,
  name : String,
) -> Result[Double, SpecError] {
  match self.values.get(name) {
    Some(v) => Ok(v)
    None => Err(InvalidParameter("unknown parameter '\{name}'"))
  }
}

///|
/// ParamSet::set_value returns a copy with one parameter replaced and
/// validated.
pub fn ParamSet::set_value(
  self : ParamSet,
  name : String,
  value : Double,
) -> Result[ParamSet, SpecError] {
  let spec = match self.spec(name) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  match
    require_in_range("parameter '\{name}'", value, spec.min_mm, spec.max_mm) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let values = self.values.copy()
  values.set(name, value)
  Ok({ specs: self.specs, values, })
}

///|
/// ParamSet::length returns a parameter as a typed `@cad.Length`.
///
/// The parameter's unit must be `"mm"` or empty.
pub fn ParamSet::length(
  self : ParamSet,
  name : String,
) -> Result[@cad.Length, SpecError] {
  let spec = match self.spec(name) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  if spec.unit != "mm" && spec.unit != "" {
    return Err(
      InvalidParameter(
        "parameter '\{name}' has unit '\{spec.unit}', not a length",
      ),
    )
  }
  match self.get(name) {
    Err(e) => Err(e)
    Ok(v) => Ok(@cad.Length::mm(v))
  }
}

///|
/// ParamSet::names returns the declared parameter names in order.
pub fn ParamSet::names(self : ParamSet) -> Array[String] {
  self.specs.map(fn(spec) { spec.name })
}

///|
/// ParamSet::documentation returns one line per parameter.
pub fn ParamSet::documentation(self : ParamSet) -> String {
  let lines : Array[String] = []
  for spec in self.specs {
    let value = self.values.get(spec.name).unwrap_or(spec.default_mm)
    lines.push(
      "\{spec.name} = \{value}\{if spec.unit == "" { "" } else { " " + spec.unit }}",
    )
  }
  lines.join("\n")
}

///|
/// DesignFamily is a named parametric design with a validated parameter schema
/// and a builder from a `ParamSet` to a `Component`.
///
/// It is additive: existing builders keep their direct `Double` signatures, and
/// a family wraps one for interactive or scripted design exploration.
pub(all) struct DesignFamily {
  name : String
  description : String
  specs : Array[ParamSpec]
  build_fn : (ParamSet) -> Result[Component, SpecError]
  variants : Array[(String, ParamSet)]
}

///|
/// DesignFamily::new builds a design family and validates its parameter schema.
pub fn DesignFamily::new(
  name~ : String,
  specs~ : Array[ParamSpec],
  build~ : (ParamSet) -> Result[Component, SpecError],
  description~ : String = "",
) -> Result[DesignFamily, SpecError] {
  if name == "" {
    return Err(InvalidParameter("design family has an empty name"))
  }
  match ParamSet::defaults(specs) {
    Err(e) => Err(e)
    Ok(_) => Ok({ name, description, specs, build_fn: build, variants: [], })
  }
}

///|
/// DesignFamily::parameter_names returns the declared parameter names.
pub fn DesignFamily::parameter_names(self : DesignFamily) -> Array[String] {
  self.specs.map(fn(spec) { spec.name })
}

///|
/// DesignFamily::defaults returns the default parameter set.
pub fn DesignFamily::defaults(
  self : DesignFamily,
) -> Result[ParamSet, SpecError] {
  ParamSet::defaults(self.specs)
}

///|
/// DesignFamily::from_values validates a named override list.
pub fn DesignFamily::from_values(
  self : DesignFamily,
  values : Array[(String, Double)],
) -> Result[ParamSet, SpecError] {
  ParamSet::from_values(self.specs, values)
}

///|
/// DesignFamily::build validates and builds a component from a parameter set.
pub fn DesignFamily::build(
  self : DesignFamily,
  parameters : ParamSet,
) -> Result[Component, SpecError] {
  for spec in self.specs {
    match parameters.get(spec.name) {
      Err(e) => return Err(e)
      Ok(v) =>
        match require_in_range(spec.name, v, spec.min_mm, spec.max_mm) {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
    }
  }
  (self.build_fn)(parameters)
}

///|
/// DesignFamily::build_values validates overrides and builds in one step.
pub fn DesignFamily::build_values(
  self : DesignFamily,
  values : Array[(String, Double)],
) -> Result[Component, SpecError] {
  let parameters = match self.from_values(values) {
    Err(e) => return Err(e)
    Ok(p) => p
  }
  self.build(parameters)
}

///|
/// DesignFamily::with_variant registers a named parameter preset.
pub fn DesignFamily::with_variant(
  self : DesignFamily,
  variant_name : String,
  values : Array[(String, Double)],
) -> Result[DesignFamily, SpecError] {
  let parameters = match self.from_values(values) {
    Err(e) => return Err(e)
    Ok(p) => p
  }
  let variants = self.variants.copy()
  variants.push((variant_name, parameters))
  Ok({ ..self, variants, })
}

///|
/// DesignFamily::variant returns a named preset, or an error when absent.
pub fn DesignFamily::variant(
  self : DesignFamily,
  variant_name : String,
) -> Result[ParamSet, SpecError] {
  for entry in self.variants {
    let (name, parameters) = entry
    if name == variant_name {
      return Ok(parameters)
    }
  }
  Err(
    InvalidParameter(
      "unknown variant '\{variant_name}' in family '\{self.name}'",
    ),
  )
}

///|
/// DesignFamily::variant_names returns the registered preset names.
pub fn DesignFamily::variant_names(self : DesignFamily) -> Array[String] {
  self.variants.map(fn(entry) { entry.0 })
}

///|
/// DesignFamily::build_variant builds a registered preset.
pub fn DesignFamily::build_variant(
  self : DesignFamily,
  variant_name : String,
) -> Result[Component, SpecError] {
  let parameters = match self.variant(variant_name) {
    Err(e) => return Err(e)
    Ok(p) => p
  }
  self.build(parameters)
}

///|
/// DesignFamily::documentation returns the family description and every
/// parameter spec with its current default.
pub fn DesignFamily::documentation(self : DesignFamily) -> String {
  let lines : Array[String] = ["Design family: " + self.name]
  if self.description != "" {
    lines.push(self.description)
  }
  for spec in self.specs {
    lines.push("  " + spec.documentation())
  }
  if self.variants.length() > 0 {
    lines.push("Variants: " + self.variant_names().join(", "))
  }
  lines.join("\n")
}
