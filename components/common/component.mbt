///|
/// ComponentLayer is one solid body of a component, expressed in the
/// component's local frame.
///
/// Many mechanically correct parts are naturally built from stacked bodies
/// (for example a screw head with a blind socket is a socket ring over a floor
/// disc). Keeping the layers explicit makes that construction visible instead
/// of pretending a nominal boolean trimmed it.
pub(all) struct ComponentLayer {
  shape : @cad.Shape
  name : String
  color : @cad.Rgb
  placement : Placement
}

///|
/// Component is a named, metadata-bearing collection of placed solid layers in
/// a local millimetre frame.
///
/// Components are immutable values: `translate`, `rotate_x`, and friends return
/// a new component. `nodes()` materialises the layers as `@cad.SceneNode`
/// values for a `Design`, preserving order and names.
pub struct Component {
  priv name : String
  priv metadata : Metadata
  priv layers : Array[ComponentLayer]
  priv description : String
  priv features : FeatureRecord
  priv connectors : Array[MateConnector]
}

///|
/// Component::new builds an empty component with a name and metadata.
///
/// `features` is the machine-readable feature record. When omitted it is empty
/// and `documentation()` states no modelled features.
pub fn Component::new(
  name~ : String,
  metadata~ : Metadata,
  description~ : String = "",
  features? : FeatureRecord,
) -> Component {
  let record = match features {
    Some(f) => f
    None => FeatureRecord::empty()
  }
  { name, metadata, layers: [], description, features: record, connectors: [], }
}

///|
/// Component::add_layer appends one solid body. Layers are evaluated in the
/// order they were added.
pub fn Component::add_layer(
  self : Component,
  shape : @cad.Shape,
  name~ : String = "",
  color~ : @cad.Rgb = @cad.Rgb::orange(),
  placement~ : Placement = Placement::identity(),
) -> Component {
  let layer_name = if name == "" {
    "\{self.name}/layer-\{self.layers.length()}"
  } else {
    "\{self.name}/\{name}"
  }
  let layers = self.layers.copy()
  layers.push({ shape, name: layer_name, color, placement, })
  { ..self, layers, }
}

///|
/// Component::add_layers appends every layer in `layers`.
pub fn Component::add_layers(
  self : Component,
  layers : Array[ComponentLayer],
) -> Component {
  let out = self.layers.copy()
  out.push_iter(layers.iter())
  { ..self, layers: out, }
}

///|
/// Component::name returns the component's canonical name.
pub fn Component::name(self : Component) -> String {
  self.name
}

///|
/// Component::metadata returns the component metadata.
pub fn Component::metadata(self : Component) -> Metadata {
  self.metadata
}

///|
/// Component::description returns the free-form component description.
pub fn Component::description(self : Component) -> String {
  self.description
}

///|
/// Component::features returns the machine-readable feature record.
pub fn Component::features(self : Component) -> FeatureRecord {
  self.features
}

///|
/// Component::with_features returns a copy with a new feature record.
pub fn Component::with_features(
  self : Component,
  features : FeatureRecord,
) -> Component {
  { ..self, features, }
}

///|
/// Component::layers returns a copy of the component layers in local
/// coordinates.
pub fn Component::layers(self : Component) -> Array[ComponentLayer] {
  self.layers.copy()
}

///|
/// Component::with_connector registers a named mate connector.
///
/// The component is immutable; a successful call returns a copy with one more
/// connector. Invalid connectors and duplicate names are rejected with a typed
/// error. Registering a connector never changes layers, geometry, or metadata.
pub fn Component::with_connector(
  self : Component,
  connector : MateConnector,
) -> Result[Component, MateError] {
  match connector.validate() {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  for existing in self.connectors {
    if existing.name == connector.name {
      return Err(DuplicateConnector(connector.name))
    }
  }
  let connectors = self.connectors.copy()
  connectors.push(connector)
  Ok({ ..self, connectors, })
}

///|
/// Component::with_connectors registers several connectors, rejecting the first
/// invalid or duplicate name. Nothing is changed when any connector fails.
pub fn Component::with_connectors(
  self : Component,
  connectors : Array[MateConnector],
) -> Result[Component, MateError] {
  let mut component = self
  for connector in connectors {
    match component.with_connector(connector) {
      Ok(next) => component = next
      Err(e) => return Err(e)
    }
  }
  Ok(component)
}

///|
/// Component::with_connector_unchecked registers a connector that the caller has
/// already constructed correctly.
///
/// Component builders use this for their own documented metadata, where a
/// failure means the builder itself is broken rather than the caller's
/// parameters. Caller-supplied connectors should use `with_connector`.
pub fn Component::with_connector_unchecked(
  self : Component,
  connector : MateConnector,
) -> Component {
  match self.with_connector(connector) {
    Ok(component) => component
    Err(e) => abort(e.message())
  }
}

///|
/// Component::connectors returns a copy of the component's mate connectors.
pub fn Component::connectors(self : Component) -> Array[MateConnector] {
  self.connectors.copy()
}

///|
/// Component::connector looks up a connector by name.
pub fn Component::connector(
  self : Component,
  name : String,
) -> Result[MateConnector, MateError] {
  for connector in self.connectors {
    if connector.name == name {
      return Ok(connector)
    }
  }
  Err(UnknownConnector(name))
}

///|
/// Component::connector_placed returns a connector transformed by `parent`,
/// for snapping against a component that is already placed in an assembly.
pub fn Component::connector_placed(
  self : Component,
  name : String,
  parent : Placement,
) -> Result[MateConnector, MateError] {
  match self.connector(name) {
    Ok(connector) => Ok(connector.transformed(parent))
    Err(e) => Err(e)
  }
}

///|
/// Component::rebase_to_connector applies the inverse of a named connector's
/// placement to every layer and every connector, making that connector frame the
/// component origin.
///
/// Only frames move. Layer geometry, volume, layer count, and shape identity are
/// unchanged, as are the relative positions of all connectors.
pub fn Component::rebase_to_connector(
  self : Component,
  name : String,
) -> Result[Component, MateError] {
  let connector = match self.connector(name) {
    Ok(c) => c
    Err(e) => return Err(e)
  }
  let inv = Placement::inverse(connector.placement)
  let layers = self.layers.map(fn(layer) {
    { ..layer, placement: Placement::compose(inv, layer.placement), }
  })
  let connectors = self.connectors.map(fn(c) { c.transformed(inv) })
  Ok({ ..self, layers, connectors, })
}

///|
/// Component::with_name returns a copy with a new name.
///
/// Existing layer names are not rewritten; callers that need a fully consistent
/// name should build the component under the final name.
pub fn Component::with_name(self : Component, name : String) -> Component {
  { ..self, name, }
}

///|
/// Component::with_metadata returns a copy with new metadata.
pub fn Component::with_metadata(
  self : Component,
  metadata : Metadata,
) -> Component {
  { ..self, metadata, }
}

///|
/// Component::with_description returns a copy with a new description.
pub fn Component::with_description(
  self : Component,
  description : String,
) -> Component {
  { ..self, description, }
}

///|
/// Component::translate moves the whole component by `(x, y, z)` millimetres in
/// its parent frame.
pub fn Component::translate(
  self : Component,
  x~ : Double = 0.0,
  y~ : Double = 0.0,
  z~ : Double = 0.0,
) -> Component {
  self.transform_with(Placement::translation(x, y, z))
}

///|
/// Component::rotate_x rotates the component about its local +X axis by
/// `angle` degrees.
pub fn Component::rotate_x(self : Component, angle : Double) -> Component {
  self.transform_with(Placement::rotation_x(angle))
}

///|
/// Component::rotate_y rotates the component about its local +Y axis by
/// `angle` degrees.
pub fn Component::rotate_y(self : Component, angle : Double) -> Component {
  self.transform_with(Placement::rotation_y(angle))
}

///|
/// Component::rotate_z rotates the component about its local +Z axis by
/// `angle` degrees.
pub fn Component::rotate_z(self : Component, angle : Double) -> Component {
  self.transform_with(Placement::rotation_z(angle))
}

///|
/// Component::transform_with prepends `outer` to every layer placement.
pub fn Component::transform_with(
  self : Component,
  outer : Placement,
) -> Component {
  let layers = self.layers.map(fn(layer) {
    { ..layer, placement: Placement::compose(outer, layer.placement), }
  })
  let connectors = self.connectors.map(fn(connector) {
    connector.transformed(outer)
  })
  { ..self, layers, connectors, }
}

///|
/// Component::nodes materialises the component in its own local frame.
pub fn Component::nodes(self : Component) -> Array[@cad.SceneNode] {
  self.nodes_under(Placement::identity())
}

///|
/// Component::nodes_under materialises the component with `parent` applied to
/// every layer. This is the hook the assembly layer uses.
pub fn Component::nodes_under(
  self : Component,
  parent : Placement,
) -> Array[@cad.SceneNode] {
  self.layers.map(fn(layer) {
    let combined = Placement::compose(parent, layer.placement)
    let (rx, ry, rz) = combined.to_euler()
    layer.shape
    .with_name(layer.name)
    .with_color(layer.color)
    .rotate_x(rx)
    .rotate_y(ry)
    .rotate_z(rz)
    .translate(x=combined.trans.0, y=combined.trans.1, z=combined.trans.2)
  })
}

///|
/// Component::bounding_box returns the world-axis-aligned bounds of the
/// materialised component in its local frame, as
/// `(x_min, x_max, y_min, y_max, z_min, z_max)`.
pub fn Component::bounding_box(
  self : Component,
) -> (Double, Double, Double, Double, Double, Double) {
  let nodes = self.nodes()
  let mut x0 = 1.0e300
  let mut x1 = -1.0e300
  let mut y0 = 1.0e300
  let mut y1 = -1.0e300
  let mut z0 = 1.0e300
  let mut z1 = -1.0e300
  for node in nodes {
    let (a0, a1, b0, b1, c0, c1) = node.bounding_box()
    if a0 < x0 {
      x0 = a0
    }
    if a1 > x1 {
      x1 = a1
    }
    if b0 < y0 {
      y0 = b0
    }
    if b1 > y1 {
      y1 = b1
    }
    if c0 < z0 {
      z0 = c0
    }
    if c1 > z1 {
      z1 = c1
    }
  }
  if nodes.is_empty() {
    (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
  } else {
    (x0, x1, y0, y1, z0, z1)
  }
}

///|
/// Component::size returns the bounding-box extent `(dx, dy, dz)`.
pub fn Component::size(self : Component) -> @cad.Vec3 {
  let (x0, x1, y0, y1, z0, z1) = self.bounding_box()
  (x1 - x0, y1 - y0, z1 - z0)
}

///|
/// Component::documentation returns the metadata plus any family description
/// and the machine-readable feature record, suitable for a STEP header.
pub fn Component::documentation(self : Component) -> String {
  let meta = self.metadata.documentation()
  let lines : Array[String] = [meta]
  if self.description != "" {
    lines.push("Notes:      " + self.description)
  }
  lines.push(self.features.documentation())
  lines.join("\n")
}

///|
/// Component::to_design materialises the component as a `@cad.Design`.
pub fn Component::to_design(
  self : Component,
  name? : String,
  documentation? : String,
) -> @cad.Design {
  let design_name = match name {
    Some(n) => n
    None => self.name
  }
  let doc = match documentation {
    Some(d) => d + "\n" + self.documentation()
    None => self.documentation()
  }
  @cad.Design::new(
    name=design_name,
    description=self.metadata.summary(),
    documentation=doc,
  ).add_iter(self.nodes().iter())
}

///|
/// Component::to_step renders the component as flat STEP text.
pub fn Component::to_step(self : Component, checked~ : Bool = false) -> String {
  let design = self.to_design()
  if checked {
    design.to_step_file_checked()
  } else {
    design.to_step_file()
  }
}

///|
/// Component::write_step writes the component as a STEP file. Pass
/// `checked=true` to refuse designs with error diagnostics.
pub async fn Component::write_step(
  self : Component,
  out_path : String?,
  checked~ : Bool = false,
) -> Unit {
  self.to_design().write_step(out_path, checked~)
}
