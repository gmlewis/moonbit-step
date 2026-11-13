///|
// Component-level evaluated-solid export.
//
// The default `Component::to_step` / `write_step` keep the explicit layers:
// a layered accessory exports as several touching closed solids. This opt-in
// module fuses a layered component into one boolean union and asks
// `@cad.Design::to_step_evaluated` to evaluate it with OCCT, producing a single
// flat, trimmed, watertight solid. The library stays kernel-free; the
// evaluated path requires `python3`, OCCT (`occt-draw` or `DRAWEXE`), and
// `$MOONBIT_STEP_ROOT` (or `root`).

///|
/// node_is_boolean reports whether a scene node compiles to a real STEP
/// boolean (or an edge feature the evaluator can fold), as opposed to a plain
/// closed solid.
fn node_is_boolean(node : @cad.SceneNode) -> Bool {
  match node.shape {
    @cad.Shape::Union(_) => true
    @cad.Shape::Difference(_) => true
    @cad.Shape::Fillet(_) => true
    @cad.Shape::Chamfer(_) => true
    _ => false
  }
}

///|
/// json_escape escapes the two characters that would break a JSON string
/// literal. Component and layer names are simple ASCII identifiers, so this is
/// deliberately minimal.
fn json_escape(s : String) -> String {
  s.replace(old="\\", new="\\\\").replace(old="\"", new="\\\"")
}

///|
/// component_layers_json serialises the component's layers (name, colour, and
/// local-frame bounding box) for the evaluated exporter. OCCT's plain STEP
/// writer drops presentation styles, so the evaluator uses this record to
/// restore a per-solid colour when the evaluated result is a disjoint
/// one-solid-per-layer compound.
pub fn Component::layers_json(self : Component) -> String {
  let entries = self
    .layers()
    .map(fn(layer) {
      let (rx, ry, rz) = layer.placement.to_euler()
      let (tx, ty, tz) = layer.placement.trans
      let node = layer.shape
        .with_name(layer.name)
        .with_color(layer.color)
        .rotate_x(rx)
        .rotate_y(ry)
        .rotate_z(rz)
        .translate(x=tx, y=ty, z=tz)
      let (x0, x1, y0, y1, z0, z1) = node.bounding_box()
      let (r, g, b) = layer.color.channels()
      "{\"name\":\"" +
      json_escape(layer.name) +
      "\",\"color\":[" +
      r.to_string() +
      "," +
      g.to_string() +
      "," +
      b.to_string() +
      "],\"bbox\":[" +
      x0.to_string() +
      "," +
      x1.to_string() +
      "," +
      y0.to_string() +
      "," +
      y1.to_string() +
      "," +
      z0.to_string() +
      "," +
      z1.to_string() +
      "]}"
    })
  "[" + entries.join(",") + "]"
}

///|
/// Component::to_step_evaluated evaluates the component with OCCT and returns
/// one flat, trimmed STEP document.
///
/// A component with two or more layers is fused into one boolean union, so a
/// layered accessory (for example a counterbored plate) evaluates to one
/// closed solid with the same physical volume as the layer sum. A single-layer
/// component whose one body is a boolean or edge feature is evaluated
/// directly; a single flat body is already one closed solid and its nominal
/// STEP text is returned unchanged. The default layered STEP export is never
/// affected.
///
/// The layer colours and bounding boxes are passed to the evaluator so a
/// disjoint evaluated compound keeps its per-solid presentation colours; a
/// fused result is left uncoloured.
///
/// Raises `@cad.CsgEvalError` when the evaluator script, OCCT, or
/// `$MOONBIT_STEP_ROOT` is missing.
pub async fn Component::to_step_evaluated(
  self : Component,
  root~ : String? = None,
) -> String {
  let nodes = self.nodes()
  if nodes.length() == 1 && !node_is_boolean(nodes[0]) {
    // Already one closed solid; evaluation would add nothing.
    return self.to_step()
  }
  let merged = if nodes.length() > 1 {
    [@cad.union_all(nodes, name=self.name)]
  } else {
    nodes
  }
  let design = @cad.Design::new(
    name=self.name,
    description=self.metadata.summary(),
    documentation=self.documentation(),
  ).add_iter(merged.iter())
  design.to_step_evaluated(root~, layers_json=self.layers_json())
}

///|
/// Component::write_step_evaluated writes the OCCT-evaluated single solid to
/// `out_path` (or stdout). Errors from the evaluator propagate as
/// `@cad.CsgEvalError`; the nominal `write_step` is unchanged.
///
/// Like `write_step`, it writes a sibling `<out>.connectors.tsv` sidecar when
/// `STEP_CONNECTOR_SIDECAR` is set, so `compare-golden.sh` can show the
/// connector frames for an evaluated artifact too.
pub async fn Component::write_step_evaluated(
  self : Component,
  out_path : String?,
  root~ : String? = None,
) -> Unit {
  let text = self.to_step_evaluated(root~)
  @cad.write_text_file(text, out_path)
  match (out_path, @env.get_env_var("STEP_CONNECTOR_SIDECAR")) {
    (Some(path), Some(_)) =>
      @cad.write_text_file(
        self.connector_sidecar(),
        Some(path + ".connectors.tsv"),
      )
    _ => ()
  }
}
