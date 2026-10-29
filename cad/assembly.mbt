///|
/// Design::to_assembly_step emits the design as an assembly: one parent product
/// for `assembly_name`, one child product per node, and a
/// `NEXT_ASSEMBLY_USAGE_OCCURRENCE` per child. Each child's placement is carried
/// by an `ITEM_DEFINED_TRANSFORMATION`, linked through a
/// `REPRESENTATION_RELATIONSHIP_WITH_TRANSFORMATION` and a
/// `CONTEXT_DEPENDENT_SHAPE_REPRESENTATION`.
///
/// Child geometry is compiled in its own local frame and positioned by the
/// transformation, which is the assembly convention. Composite nodes are not
/// supported here: export them flat with `to_step_file()` or split them into
/// separate nodes.
pub fn Design::to_assembly_step(
  self : Design,
  assembly_name~ : String,
) -> String {
  let ctx = StepContext::new(snapping?=self.snapping)
  ctx.init_standard_context(self.name)

  // Parent product and the assembly frame.
  let parent_pd_ref = ctx.add_product_definition(assembly_name)
  let parent_origin = ctx.cartesian_point(0.0, 0.0, 0.0)
  let parent_z = ctx.direction(0.0, 0.0, 1.0)
  let parent_x = ctx.direction(1.0, 0.0, 0.0)
  let parent_a2p_ref = ctx.axis2_placement_3d(parent_origin, parent_z, parent_x)
  let parent_sr_ref = ctx.add(
    @repository.any_entity_shape_representation(
      @product.ShapeRepresentation::new(
        assembly_name + "-SR",
        [parent_a2p_ref],
        { id: ctx.repo_ctx_id, },
      ),
    ),
  )
  let parent_pds_ref = ctx.add(
    @repository.any_entity_product_definition_shape(
      @product.ProductDefinitionShape::new("", "", parent_pd_ref),
    ),
  )
  let _ = ctx.add(
    @repository.any_entity_shape_definition_representation(
      @product.ShapeDefinitionRepresentation::new(parent_pds_ref, parent_sr_ref),
    ),
  )

  let mut index = 0
  for node in self.nodes {
    index = index + 1
    // Compile the child at its local origin; the assembly transform places it.
    let local_node = {
      ..node,
      tx: 0.0,
      ty: 0.0,
      tz: 0.0,
      rx: 0.0,
      ry: 0.0,
      rz: 0.0,
    }
    let brep_ref = compile_node_to_brep(ctx, local_node)
    let child_pd_ref = ctx.add_product_definition(node.name)

    let (zx, zy, zz) = rotate_point((0.0, 0.0, 1.0), node.rx, node.ry, node.rz)
    let (xx, xy, xz) = rotate_point((1.0, 0.0, 0.0), node.rx, node.ry, node.rz)
    let child_a2p_ref = ctx.axis2_placement_3d(
      ctx.cartesian_point(node.tx, node.ty, node.tz),
      ctx.direction(zx, zy, zz),
      ctx.direction(xx, xy, xz),
    )

    let child_sr_ref = ctx.add(
      @repository.any_entity_shape_representation(
        @product.ShapeRepresentation::new(
          node.name + "-SR",
          [brep_ref, child_a2p_ref],
          { id: ctx.repo_ctx_id, },
        ),
      ),
    )
    let child_pds_ref = ctx.add(
      @repository.any_entity_product_definition_shape(
        @product.ProductDefinitionShape::new("", "", child_pd_ref),
      ),
    )
    let _ = ctx.add(
      @repository.any_entity_shape_definition_representation(
        @product.ShapeDefinitionRepresentation::new(child_pds_ref, child_sr_ref),
      ),
    )

    // Placement: parent frame item 1, child frame item 2.
    let idt_ref = ctx.add(
      @repository.any_entity_item_defined_transformation(
        @product.ItemDefinedTransformation::new(
          "", "", parent_a2p_ref, child_a2p_ref,
        ),
      ),
    )
    let relationship_ref = ctx.add(
      @repository.any_entity_complex_instance(
        @context.ComplexInstance::new([
          @context.ComplexPart::RepRel(
            @product.RepresentationRelationship::new(
              "", "", parent_sr_ref, child_sr_ref,
            ),
          ),
          @context.ComplexPart::RepRelWT(
            @product.RepresentationRelationshipWithTransformation::new(idt_ref),
          ),
        ]),
      ),
    )
    let _ = ctx.add(
      @repository.any_entity_context_dependent_shape_representation(
        @product.ContextDependentShapeRepresentation::new(
          relationship_ref, child_pds_ref,
        ),
      ),
    )
    let _ = ctx.add(
      @repository.any_entity_next_assembly_usage_occurrence(
        @product.NextAssemblyUsageOccurrence::new(
          index.to_string(),
          node.name,
          "$",
          parent_pd_ref,
          child_pd_ref,
          "$",
        ),
      ),
    )
  }

  let file_name = self.name + ".step"
  let has_nominal_boolean = self.diagnostics().any(fn(d) { d.is_nominal() })
  ctx.repo = ctx.repo.set_header(
    default_header(
      file_name,
      self.description,
      self.documentation,
      nominal=has_nominal_boolean,
    ),
  )
  ctx.repo.to_step_file()
}
