///|
/// AssemblyItem is one placed component instance in an assembly.
///
/// `instance_name` is unique within the assembly; component metadata is kept so
/// a BOM can be reconstructed without re-parsing the STEP file.
pub(all) struct AssemblyItem {
  component : @common.Component
  placement : @common.Placement
  instance_name : String
}

///|
/// Assembly is an ordered list of placed component instances.
///
/// Each item keeps its own rigid placement and parametric component identity.
/// `to_step()` writes a flat STEP design with one solid per component layer;
/// `to_assembly_step()` uses the repository's assembly writer, which emits one
/// product occurrence per **materialised layer** with an
/// `ITEM_DEFINED_TRANSFORMATION`. A multi-layer component such as a screw
/// therefore appears as several products, named `instance/layer`; component
/// instance identity is preserved in that name, not by a one-product-per-instance
/// grouping.
pub struct Assembly {
  priv name : String
  priv items : Array[AssemblyItem]
  priv description : String
  priv documentation : String
}

///|
/// Assembly::new builds an empty assembly.
pub fn Assembly::new(
  name~ : String,
  description~ : String = "",
  documentation~ : String = "",
) -> Assembly {
  { name, items: [], description, documentation, }
}

///|
/// Assembly::name returns the assembly name.
pub fn Assembly::name(self : Assembly) -> String {
  self.name
}

///|
/// Assembly::items returns a copy of the placed items.
pub fn Assembly::items(self : Assembly) -> Array[AssemblyItem] {
  self.items.copy()
}

///|
/// Assembly::count returns the number of component instances.
pub fn Assembly::count(self : Assembly) -> Int32 {
  self.items.length()
}

///|
/// Assembly::with_description returns a copy with a new description.
pub fn Assembly::with_description(
  self : Assembly,
  description : String,
) -> Assembly {
  { ..self, description, }
}

///|
/// Assembly::with_documentation returns a copy with additional header
/// documentation.
pub fn Assembly::with_documentation(
  self : Assembly,
  documentation : String,
) -> Assembly {
  { ..self, documentation, }
}

///|
/// unique_instance_name returns `base` or `base-2`, `base-3`, ... so every
/// assembly item has a stable, unique product name.
fn unique_instance_name(items : Array[AssemblyItem], base : String) -> String {
  let mut candidate = base
  let mut suffix = 2
  let mut taken = true
  while taken {
    taken = false
    for item in items {
      if item.instance_name == candidate {
        taken = true
        break
      }
    }
    if taken {
      candidate = base + "-" + suffix.to_string()
      suffix = suffix + 1
    }
  }
  candidate
}

///|
/// Assembly::add places a component instance.
pub fn Assembly::add(
  self : Assembly,
  component : @common.Component,
  placement~ : @common.Placement = @common.Placement::identity(),
  instance_name~ : String = "",
) -> Assembly {
  let base = if instance_name == "" { component.name() } else { instance_name }
  let name = unique_instance_name(self.items, base)
  let items = self.items.copy()
  items.push({ component, placement, instance_name: name, })
  { ..self, items, }
}

///|
/// Assembly::add_at places a component at a translation and Euler rotation.
pub fn Assembly::add_at(
  self : Assembly,
  component : @common.Component,
  x~ : Double = 0.0,
  y~ : Double = 0.0,
  z~ : Double = 0.0,
  rx~ : Double = 0.0,
  ry~ : Double = 0.0,
  rz~ : Double = 0.0,
  instance_name~ : String = "",
) -> Assembly {
  self.add(
    component,
    placement=@common.Placement::at(x, y, z, rx~, ry~, rz~),
    instance_name~,
  )
}

///|
/// find_item returns the placed instance with `instance_name`, if any.
fn find_item(assembly : Assembly, instance_name : String) -> AssemblyItem? {
  for item in assembly.items {
    if item.instance_name == instance_name {
      return Some(item)
    }
  }
  None
}

///|
/// Assembly::add_mate_pair places `child` by resolving `pair` between a named
/// connector on an already-placed parent instance and a named connector on the
/// child.
///
/// The parent connector is transformed into the assembly frame first. The
/// returned `MateAlignment` reports the resolved child placement, the child-frame
/// axis, and any interface-convention axis flip. The pair is geometric: this
/// places a part, it does not claim structural strength.
pub fn Assembly::add_mate_pair(
  self : Assembly,
  parent_instance : String,
  child : @common.Component,
  pair : @common.MatePair,
  instance_name~ : String = "",
) -> Result[(Assembly, @common.MateAlignment), @common.MatePairError] {
  let parent_item = match find_item(self, parent_instance) {
    Some(item) => item
    None => return Err(@common.MatePairError::MissingInstance(parent_instance))
  }
  let parent_connector = match parent_item.component.connector(pair.parent) {
    Ok(connector) => connector.transformed(parent_item.placement)
    Err(_) => return Err(@common.MatePairError::MissingConnector(pair.parent))
  }
  let child_connector = match child.connector(pair.child) {
    Ok(connector) => connector
    Err(_) => return Err(@common.MatePairError::MissingConnector(pair.child))
  }
  let alignment = match pair.resolve(parent_connector, child_connector) {
    Ok(alignment) => alignment
    Err(e) => return Err(e)
  }
  let assembly = self.add(child, placement=alignment.placement, instance_name~)
  Ok((assembly, alignment))
}

///|
/// Assembly::linear_pattern places `count` instances in a straight line.
///
/// Item `i` is at `base + i * (dx, dy, dz)`. `base` is applied first, so a
/// rotation in `base` rotates the whole pattern.
pub fn Assembly::linear_pattern(
  self : Assembly,
  component : @common.Component,
  count : Int32,
  dx~ : Double = 0.0,
  dy~ : Double = 0.0,
  dz~ : Double = 0.0,
  instance_name~ : String = "",
  base~ : @common.Placement = @common.Placement::identity(),
) -> Assembly {
  let mut assembly = self
  let stem = if instance_name == "" { component.name() } else { instance_name }
  for i in 0..<count {
    let t = i.to_double()
    let placement = @common.Placement::compose(
      base,
      @common.Placement::translation(t * dx, t * dy, t * dz),
    )
    assembly = assembly.add(
      component,
      placement~,
      instance_name="\{stem}-\{i + 1}",
    )
  }
  assembly
}

///|
/// Assembly::circular_pattern places `count` instances evenly around the Z axis
/// on a circle of `radius`. Each instance is rotated about Z by its angular
/// position plus `orientation_deg`.
pub fn Assembly::circular_pattern(
  self : Assembly,
  component : @common.Component,
  count : Int32,
  radius : Double,
  start_angle_deg~ : Double = 0.0,
  orientation_deg~ : Double = 0.0,
  instance_name~ : String = "",
  base~ : @common.Placement = @common.Placement::identity(),
) -> Assembly {
  let mut assembly = self
  let stem = if instance_name == "" { component.name() } else { instance_name }
  let step_deg = if count <= 0 { 0.0 } else { 360.0 / count.to_double() }
  for i in 0..<count {
    let angle = start_angle_deg + i.to_double() * step_deg
    let rad = angle * @math.PI / 180.0
    let x = radius * @math.cos(rad)
    let y = radius * @math.sin(rad)
    let placement = @common.Placement::compose(
      base,
      @common.Placement::at(x, y, 0.0, rz=angle + orientation_deg),
    )
    assembly = assembly.add(
      component,
      placement~,
      instance_name="\{stem}-\{i + 1}",
    )
  }
  assembly
}

///|
/// Assembly::nodes materialises every item, giving each node a unique
/// `instance/layer` name while preserving the component layer order.
pub fn Assembly::nodes(self : Assembly) -> Array[@cad.SceneNode] {
  let out : Array[@cad.SceneNode] = []
  for item in self.items {
    for layer in item.component.layers() {
      let combined = @common.Placement::compose(item.placement, layer.placement)
      let (rx, ry, rz) = combined.to_euler()
      let node = layer.shape
        .with_name(item.instance_name + "/" + layer.name)
        .with_color(layer.color)
        .rotate_x(rx)
        .rotate_y(ry)
        .rotate_z(rz)
        .translate(x=combined.trans.0, y=combined.trans.1, z=combined.trans.2)
      out.push(node)
    }
  }
  out
}

///|
/// Assembly::bounding_box returns the axis-aligned bounds of all materialised
/// nodes.
pub fn Assembly::bounding_box(
  self : Assembly,
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
/// Assembly::documentation returns the assembly header notes, including one
/// line per placed component and the aggregated feature record.
pub fn Assembly::documentation(self : Assembly) -> String {
  let lines : Array[String] = [
    "Assembly:   " + self.name,
    "Instances:  " + self.items.length().to_string(),
  ]
  if self.description != "" {
    lines.push("Description: " + self.description)
  }
  if self.documentation != "" {
    lines.push(self.documentation)
  }
  for item in self.items {
    let meta = item.component.metadata()
    lines.push(
      "  " +
      item.instance_name +
      " = " +
      meta.designation +
      " (" +
      meta.standard +
      ")",
    )
  }
  lines.push(self.features().documentation())
  lines.join("\n")
}

///|
/// Assembly::features aggregates the feature records of every placed
/// component, de-duplicating by feature name.
pub fn Assembly::features(self : Assembly) -> @common.FeatureRecord {
  let modeled : Array[String] = []
  let approximated : Array[@common.Approximation] = []
  let omitted : Array[@common.Omission] = []
  for item in self.items {
    let record = item.component.features()
    for feature in record.modeled {
      if !modeled.any(fn(existing) { existing == feature }) {
        modeled.push(feature)
      }
    }
    for a in record.approximated {
      let mut replaced = false
      for i in 0..<approximated.length() {
        if approximated[i].feature == a.feature {
          // Keep the largest deviation so the assembly summary never
          // understates the approximation error under a shared feature name.
          if a.deviation_mm > approximated[i].deviation_mm {
            approximated[i] = a
          }
          replaced = true
          break
        }
      }
      if !replaced {
        approximated.push(a)
      }
    }
    for o in record.omitted {
      if !omitted.any(fn(existing) { existing.feature == o.feature }) {
        omitted.push(o)
      }
    }
  }
  @common.FeatureRecord::new(modeled~, approximated~, omitted~)
}

///|
/// Assembly::to_design compiles the assembly to a flat `@cad.Design`.
pub fn Assembly::to_design(
  self : Assembly,
  name? : String,
  documentation? : String,
) -> @cad.Design {
  let design_name = match name {
    Some(n) => n
    None => self.name
  }
  let doc = match documentation {
    Some(d) => self.documentation() + "\n" + d
    None => self.documentation()
  }
  @cad.Design::new(
    name=design_name,
    description=self.description,
    documentation=doc,
  ).add_iter(self.nodes().iter())
}

///|
/// Assembly::to_step renders the flat STEP representation.
pub fn Assembly::to_step(self : Assembly, checked~ : Bool = false) -> String {
  let design = self.to_design()
  if checked {
    design.to_step_file_checked()
  } else {
    design.to_step_file()
  }
}

///|
/// Assembly::to_assembly_step renders the STEP assembly representation with one
/// product per component instance and a placement transformation for each.
pub fn Assembly::to_assembly_step(
  self : Assembly,
  assembly_name? : String,
) -> String {
  let name = match assembly_name {
    Some(n) => n
    None => self.name
  }
  self.to_design().to_assembly_step(assembly_name=name)
}

///|
/// Assembly::write_step writes the flat STEP representation to `out_path`, or
/// stdout when it is `None`.
pub async fn Assembly::write_step(
  self : Assembly,
  out_path : String?,
  checked~ : Bool = false,
) -> Unit {
  self.to_design().write_step(out_path, checked~)
}

///|
/// Assembly::write_assembly_step writes the STEP assembly representation.
pub async fn Assembly::write_assembly_step(
  self : Assembly,
  out_path : String?,
) -> Unit {
  @cad.write_text_file(self.to_assembly_step(), out_path)
}

///|
/// Assembly::component_names returns the instance names in insertion order.
pub fn Assembly::component_names(self : Assembly) -> Array[String] {
  self.items.map(fn(item) { item.instance_name })
}

///|
/// PartScheduleEntry is one distinct part in an assembly schedule.
///
/// A schedule groups instances of the same parametric component, so a joint
/// with two identical plates reports one line with quantity 2 rather than two
/// unrelated entries.
pub(all) struct PartScheduleEntry {
  /// Canonical parametric component name.
  part_name : String
  designation : String
  standard : String
  quantity : Int32
  instances : Array[String]
}

///|
/// Assembly::schedule returns the grouped part schedule in first-seen order.
///
/// This is a BOM aid, not a manufacturing release: it reports the parametric
/// identity and instance names that the assembly actually contains.
pub fn Assembly::schedule(self : Assembly) -> Array[PartScheduleEntry] {
  let entries : Array[PartScheduleEntry] = []
  for item in self.items {
    let name = item.component.name()
    let mut found = false
    for i in 0..<entries.length() {
      if entries[i].part_name == name {
        let instances = entries[i].instances.copy()
        instances.push(item.instance_name)
        entries[i] = {
          ..entries[i],
          quantity: entries[i].quantity + 1,
          instances,
        }
        found = true
        break
      }
    }
    if !found {
      let meta = item.component.metadata()
      entries.push({
        part_name: name,
        designation: meta.designation,
        standard: meta.standard,
        quantity: 1,
        instances: [item.instance_name],
      })
    }
  }
  entries
}

///|
/// Assembly::schedule_text returns a human-readable part schedule, one line per
/// distinct part.
pub fn Assembly::schedule_text(self : Assembly) -> String {
  self
  .schedule()
  .map(fn(entry) {
    "\{entry.quantity} x \{entry.part_name} [\{entry.designation}] " +
    "instances: " +
    entry.instances.join(", ")
  })
  .join("\n")
}
