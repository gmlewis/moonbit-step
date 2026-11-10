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
}

///|
/// Component::new builds an empty component with a name and metadata.
pub fn Component::new(
  name~ : String,
  metadata~ : Metadata,
  description~ : String = "",
) -> Component {
  { name, metadata, layers: [], description, }
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
/// Component::layers returns a copy of the component layers in local
/// coordinates.
pub fn Component::layers(self : Component) -> Array[ComponentLayer] {
  self.layers.copy()
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
  { ..self, layers, }
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
/// Component::documentation returns the metadata plus any family description,
/// suitable for a STEP header.
pub fn Component::documentation(self : Component) -> String {
  let meta = self.metadata.documentation()
  if self.description == "" {
    meta
  } else {
    meta + "\nNotes:      " + self.description
  }
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
