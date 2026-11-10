///|
// Opt-in CSG export of boolean intent.
//
// The flat B-Rep export (`Design::to_step_file`) is nominal: a `Union` or
// `Difference` concatenates its children's faces and never trims them. This
// module instead emits a real STEP boolean tree (`BOOLEAN_RESULT` nodes wrapped
// in a `CSG_SOLID`), which a kernel that understands CSG can evaluate.
//
// The flat export is deliberately left untouched; `to_csg_step` is a separate,
// opt-in entry point.

///|
/// csg_boolean appends one BOOLEAN_RESULT and returns its reference.
fn csg_boolean(
  ctx : StepContext,
  name : String,
  op : @geometry.BooleanOperator,
  first : @step.Ref,
  second : @step.Ref,
) -> @step.Ref {
  let result = @geometry.BooleanResult::new(name, op, first, second)
  ctx.add(@repository.any_entity_boolean_result(result))
}

///|
/// union_operands folds an operand list left-associatively with `.UNION.`.
/// A single operand is returned unwrapped.
fn union_operands(
  ctx : StepContext,
  name : String,
  operands : Array[@step.Ref],
) -> @step.Ref? {
  if operands.is_empty() {
    return None
  }
  let mut acc = operands[0]
  for i in 1..<operands.length() {
    acc = csg_boolean(
      ctx,
      "\{name}-bool-\{i}",
      @geometry.BooleanOperator::Union,
      acc,
      operands[i],
    )
  }
  Some(acc)
}

///|
/// compile_csg_operand compiles one node to a CSG operand.
///
/// A leaf becomes its `MANIFOLD_SOLID_BREP` (a legal `boolean_operand`). A
/// boolean node becomes nested `BOOLEAN_RESULT`s; an empty boolean returns
/// `None` and the caller skips it (matching the flat compiler's fast paths).
fn compile_csg_operand(
  ctx : StepContext,
  node : SceneNode,
  parent : Transform?,
) -> @step.Ref? {
  match node.shape {
    Union(u) => {
      if u.nodes.length() == 0 {
        return None
      }
      let child_parent = Some(node_transform(node, parent))
      let operands : Array[@step.Ref] = []
      for child in u.nodes {
        match compile_csg_operand(ctx, child, child_parent) {
          Some(r) => operands.push(r)
          None => ()
        }
      }
      union_operands(ctx, node.name, operands)
    }
    Difference(d) => {
      let child_parent = Some(node_transform(node, parent))
      let base = match compile_csg_operand(ctx, d.base, child_parent) {
        Some(r) => r
        None =>
          abort(
            "CSG difference '\{node.name}' has an empty base solid; there is nothing to subtract from",
          )
      }
      let cutters : Array[@step.Ref] = []
      for cutter in d.cutters {
        match compile_csg_operand(ctx, cutter, child_parent) {
          Some(r) => cutters.push(r)
          None => ()
        }
      }
      match union_operands(ctx, node.name + "-cutters", cutters) {
        None => Some(base)
        Some(cutters_ref) =>
          Some(
            csg_boolean(
              ctx,
              node.name + "-bool",
              @geometry.BooleanOperator::Difference,
              base,
              cutters_ref,
            ),
          )
      }
    }
    Fillet(f) => compile_edge_feature(ctx, node, f, "fillet", parent)
    Chamfer(c) => compile_edge_feature(ctx, node, c, "chamfer", parent)
    _ => Some(compile_node_to_brep(ctx, node, parent~))
  }
}

///|
/// step_quote escapes a single quote in a STEP string by doubling it.
fn step_quote(s : String) -> String {
  s.replace(old="'", new="''")
}

///|
fn edge_json_num(v : Double) -> String {
  v.to_string()
}

///|
fn edge_json_vec3(v : Vec3) -> String {
  "[" +
  edge_json_num(v.0) +
  "," +
  edge_json_num(v.1) +
  "," +
  edge_json_num(v.2) +
  "]"
}

///|
fn edge_selector_json(selector : EdgeSelector) -> String {
  match selector {
    AllEdges => "{\"kind\":\"all\"}"
    EdgesByDirection(dir, tolerance_deg) =>
      "{\"kind\":\"direction\",\"dir\":" +
      edge_json_vec3(dir) +
      ",\"tol_deg\":" +
      edge_json_num(tolerance_deg) +
      "}"
    EdgesNearPoint(point, radius_mm) =>
      "{\"kind\":\"near_point\",\"point\":" +
      edge_json_vec3(point) +
      ",\"radius\":" +
      edge_json_num(radius_mm) +
      "}"
    EdgeIndices(indices) =>
      "{\"kind\":\"indices\",\"indices\":[" +
      indices.map(fn(i) { i.to_string() }).join(",") +
      "]}"
  }
}

///|
fn edge_feature_payload(op : String, feat : EdgeFeature) -> String {
  let angle = match feat.angle_deg {
    Some(a) => edge_json_num(a)
    None => "null"
  }
  "{\"op\":\"" +
  op +
  "\",\"size\":" +
  edge_json_num(feat.size_mm) +
  ",\"angle\":" +
  angle +
  ",\"selector\":" +
  edge_selector_json(feat.selector) +
  "}"
}

///|
/// compile_edge_feature emits a `MOONBIT_EDGE_FEATURE` node that
/// `scripts/csg_eval.py` evaluates with OCCT.
///
/// The flat STEP writer refuses these nodes with an error diagnostic; only the
/// opt-in evaluated CSG path understands them. The base must be a single solid
/// (not a boolean), because the evaluator selects edges of one loaded leaf.
fn compile_edge_feature(
  ctx : StepContext,
  node : SceneNode,
  feat : EdgeFeature,
  op : String,
  parent : Transform?,
) -> @step.Ref? {
  let child_parent = Some(node_transform(node, parent))
  let base = match feat.base.shape {
    Union(_) | Difference(_) =>
      abort(
        "edge feature '\{node.name}' must wrap a single solid; wrap the boolean result first",
      )
    _ =>
      match compile_csg_operand(ctx, feat.base, child_parent) {
        Some(r) => r
        None => abort("edge feature '\{node.name}' has an empty base solid")
      }
  }
  let payload = edge_feature_payload(op, feat)
  let args = "('" +
    step_quote(node.name) +
    "',#" +
    base.id.value.to_string() +
    ",'" +
    step_quote(payload) +
    "')"
  let raw = @step.RawEntity::new("MOONBIT_EDGE_FEATURE", args)
  Some(ctx.add(@repository.any_entity_raw_entity(raw)))
}

///|
/// Design::to_csg_step compiles the design to ISO 10303-21 text with real
/// boolean trees.
///
/// Top-level boolean nodes whose root folds to a `BOOLEAN_RESULT` are wrapped
/// in a `CSG_SOLID` and referenced by a `CSG_SHAPE_REPRESENTATION`; leaves and
/// degenerate booleans keep the ordinary flat B-Rep path. Geometry is never
/// evaluated: the consuming kernel computes the boolean.
///
/// The flat export is unchanged; use `to_step_file` for the portable nominal
/// representation.
pub fn Design::to_csg_step(self : Design) -> String {
  let ctx = StepContext::new(snapping?=self.snapping)
  ctx.init_standard_context(self.name)
  let product_defs : Array[@step.Ref] = []
  let shape_reps : Array[@step.Ref] = []
  for node in self.nodes {
    match compile_csg_operand(ctx, node, None) {
      None => ()
      Some(root_ref) => {
        let root_is_boolean = match ctx.entities.get(root_ref.id.value) {
          Some(@repository.AnyEntity::BooleanResult(_)) => true
          // Edge features are emitted as a raw `MOONBIT_EDGE_FEATURE` entity
          // that the evaluator understands; treat them as CSG roots too.
          Some(@repository.AnyEntity::RawEntity(_)) => true
          _ => false
        }
        if root_is_boolean {
          let csg = @geometry.CsgSolid::new(node.name, root_ref)
          let csg_ref = ctx.add(@repository.any_entity_csg_solid(csg))
          add_solid_node_to_ctx(
            ctx,
            node,
            csg_ref,
            product_defs,
            shape_reps,
            is_csg=true,
          )
        } else {
          add_solid_node_to_ctx(
            ctx,
            node,
            root_ref,
            product_defs,
            shape_reps,
            is_csg=false,
          )
        }
      }
    }
  }
  ctx.repo = ctx.repo.set_header(
    default_header(
      self.name + ".step",
      self.description,
      self.documentation,
      nominal=false,
    ),
  )
  ctx.repo.to_step_file()
}

///|
/// Design::write_csg_step writes the CSG STEP document to `out_path`.
pub async fn Design::write_csg_step(self : Design, out_path : String?) -> Unit {
  write_text_file(self.to_csg_step(), out_path)
}
