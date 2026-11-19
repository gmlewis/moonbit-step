///|
/// Design::to_assembly_step emits the design as a STEP assembly: one parent
/// product for `assembly_name`, a child product per node, and a
/// `NEXT_ASSEMBLY_USAGE_OCCURRENCE` per node.
///
/// Each child's placement is carried by an `ITEM_DEFINED_TRANSFORMATION`
/// between the child's identity frame and the instance placement in the parent
/// shape representation, following the standard AP214 product-structure
/// pattern. Use `to_instanced_step_string()` to share one part definition
/// among repeated instances.
pub fn Design::to_assembly_step(
  self : Design,
  assembly_name~ : String,
) -> String {
  self.to_assembly_step_impl(assembly_name~, instanced=false)
}
