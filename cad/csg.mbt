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
    _ => Some(compile_node_to_brep(ctx, node, parent~))
  }
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
