///|
/// One unique part definition and the design-node indices that instance it.
priv struct InstanceGroup {
  key : String
  name : String
  indices : Array[Int32]
  part_step : String
}

///|
fn assembly_color_key(color : Rgb) -> String {
  fmt_double(color.r, Some(1.0e-9)) +
  "," +
  fmt_double(color.g, Some(1.0e-9)) +
  "," +
  fmt_double(color.b, Some(1.0e-9))
}

///|
fn assembly_data_section(step : String) -> String {
  let parts = step.split("DATA;").collect()
  if parts.length() > 1 {
    parts[1].to_owned()
  } else {
    step
  }
}

///|
/// Compiles one node at the origin into a standalone STEP string. This is the
/// per-part definition: it handles ordinary shapes, nominal booleans, and
/// imported vendor STEPs through the same flat compiler.
fn assembly_part_step(node : SceneNode) -> String {
  let placed = {
    ..node,
    name: "part",
    tx: 0.0,
    ty: 0.0,
    tz: 0.0,
    rx: 0.0,
    ry: 0.0,
    rz: 0.0,
  }
  Design::new(name="part").add(placed).to_step_file()
}

///|
/// Returns false for product-structure and assembly entities that must not be
/// carried from a standalone part STEP into an assembly. Geometry, topology,
/// representation contexts/units, presentation, and raw entities are kept.
fn keep_assembly_geometry(entity : @repository.AnyEntity) -> Bool {
  match entity {
    @repository.AnyEntity::RepresentationRelationship(_)
    | @repository.AnyEntity::RepresentationRelationshipWithTransformation(_)
    | @repository.AnyEntity::ShapeRepresentationRelationship(_)
    | @repository.AnyEntity::AdvancedBrepShapeRepresentation(_)
    | @repository.AnyEntity::CsgShapeRepresentation(_)
    | @repository.AnyEntity::ShapeRepresentation(_)
    | @repository.AnyEntity::Representation(_)
    | @repository.AnyEntity::ShapeDefinitionRepresentation(_)
    | @repository.AnyEntity::DescriptiveRepresentationItem(_)
    | @repository.AnyEntity::MeasureRepresentationItem(_)
    | @repository.AnyEntity::ContextDependentShapeRepresentation(_)
    | @repository.AnyEntity::ItemDefinedTransformation(_)
    | @repository.AnyEntity::NextAssemblyUsageOccurrence(_)
    | @repository.AnyEntity::ProductDefinitionShape(_)
    | @repository.AnyEntity::ProductDefinition(_)
    | @repository.AnyEntity::ProductDefinitionContext(_)
    | @repository.AnyEntity::ProductDefinitionFormation(_)
    | @repository.AnyEntity::ProductDefinitionFormationWithSpecifiedSource(_)
    | @repository.AnyEntity::PropertyDefinition(_)
    | @repository.AnyEntity::PropertyDefinitionRepresentation(_)
    | @repository.AnyEntity::ProductRelatedProductCategory(_)
    | @repository.AnyEntity::Product(_)
    | @repository.AnyEntity::ProductContext(_)
    | @repository.AnyEntity::ApplicationProtocolDefinition(_)
    | @repository.AnyEntity::ApplicationContext(_)
    | @repository.AnyEntity::Approval(_)
    | @repository.AnyEntity::ApprovalStatus(_)
    | @repository.AnyEntity::ApprovalRole(_)
    | @repository.AnyEntity::ApprovalPersonOrganization(_)
    | @repository.AnyEntity::Person(_)
    | @repository.AnyEntity::Organization(_)
    | @repository.AnyEntity::PersonAndOrganization(_)
    | @repository.AnyEntity::DateAndTime(_)
    | @repository.AnyEntity::LocalTime(_)
    | @repository.AnyEntity::CalendarDate(_)
    | @repository.AnyEntity::CoordinatedUniversalTimeOffset(_)
    | @repository.AnyEntity::SecurityClassification(_)
    | @repository.AnyEntity::SecurityClassificationLevel(_)
    | @repository.AnyEntity::Certification(_)
    | @repository.AnyEntity::CertificationType(_)
    | @repository.AnyEntity::Document(_)
    | @repository.AnyEntity::DocumentType(_)
    | @repository.AnyEntity::DocumentReference(_)
    | @repository.AnyEntity::KinematicLink(_)
    | @repository.AnyEntity::KinematicJoint(_)
    | @repository.AnyEntity::KinematicPair(_)
    | @repository.AnyEntity::GeometricTolerance(_)
    | @repository.AnyEntity::Datum(_)
    | @repository.AnyEntity::DatumFeature(_)
    | @repository.AnyEntity::DimensionalSize(_)
    | @repository.AnyEntity::ShapeAspect(_) => false
    _ => true
  }
}

///|
/// Drops the standalone STEP's product structure, leaving only geometry,
/// topology, contexts, presentation, and raw entities.
fn strip_product_structure(imp : ImportedStep) -> ImportedStep {
  let repo = @repository.new()
  imp.repository.each_with_id(fn(id, entity) {
    if keep_assembly_geometry(entity) {
      let _ = repo.insert_with_id(id, entity)
    }
  })
  let _ = repo.set_header(imp.repository.get_header())
  ImportedStep::from_repository(repo, source=imp.source)
}

///|
fn collect_brep_refs(imp : ImportedStep) -> Array[@step.Ref] {
  let refs : Array[@step.Ref] = []
  imp.repository.each_with_id(fn(id, entity) {
    match entity {
      @repository.AnyEntity::ManifoldSolidBrep(_)
      | @repository.AnyEntity::BrepWithVoids(_) => refs.push(@step.Ref::{ id, })
      _ => ()
    }
  })
  refs
}

///|
/// Groups nodes by their standalone part definition and colour, ignoring
/// placement. Every node is compiled once; identical definitions share one
/// group and therefore one B-Rep in the output.
fn assembly_groups(design : Design, instanced : Bool) -> Array[InstanceGroup] {
  let groups : Array[InstanceGroup] = []
  for i in 0..<design.nodes.length() {
    let node = design.nodes[i]
    let part_step = assembly_part_step(node)
    let key = if instanced {
      assembly_color_key(node.color) + "|" + assembly_data_section(part_step)
    } else {
      "\{i}|\{node.name}"
    }
    let mut found = false
    for group in groups {
      if group.key == key {
        group.indices.push(i)
        found = true
        break
      }
    }
    if !found {
      groups.push({ key, name: node.name, indices: [i], part_step, })
    }
  }
  groups
}

///|
/// Emits an assembly product structure. With `instanced=true`, identical parts
/// share one `ADVANCED_BREP_SHAPE_REPRESENTATION`; every placement gets a
/// `NEXT_ASSEMBLY_USAGE_OCCURRENCE` and an `ITEM_DEFINED_TRANSFORMATION` from
/// the shared child identity frame to the instance placement in the parent.
fn Design::to_assembly_step_impl(
  self : Design,
  assembly_name~ : String,
  instanced~ : Bool,
) -> String {
  let groups = assembly_groups(self, instanced)

  // Compile one shifted repository per unique part, then merge them into the
  // assembly repository. Ids are disjoint, so the B-Rep references survive.
  let part_imports : Array[ImportedStep] = []
  let group_breps : Array[Array[@step.Ref]] = []
  let mut shift = 0
  for group in groups {
    let parsed = match
      ImportedStep::from_string(group.part_step, source=group.name) {
      Ok(imp) => imp
      Err(info) =>
        abort(
          "internal: could not parse the STEP for part '\{group.name}': \{info.message}",
        )
    }
    let shifted = parsed.shifted(shift)
    shift = shifted.max_id() + 1
    let stripped = strip_product_structure(shifted)
    group_breps.push(collect_brep_refs(stripped))
    part_imports.push(stripped)
  }
  let merged = if part_imports.length() == 0 {
    None
  } else {
    Some(ImportedStep::merge(part_imports))
  }
  let ctx = match merged {
    Some(imp) =>
      StepContext::new_with_repository(imp.repository, snapping?=self.snapping)
    None => StepContext::new(snapping?=self.snapping)
  }
  ctx.init_standard_context(self.name)

  let parent_pd_ref = ctx.add_product_definition(assembly_name)
  let identity = ctx.axis2_placement_3d(
    ctx.cartesian_point(0.0, 0.0, 0.0),
    ctx.direction(0.0, 0.0, 1.0),
    ctx.direction(1.0, 0.0, 0.0),
  )

  // Instance placements live in the parent's frame and are items of the
  // parent shape representation (the standard STEP assembly layout).
  let placements : Array[@step.Ref] = []
  for node in self.nodes {
    let (zx, zy, zz) = rotate_point((0.0, 0.0, 1.0), node.rx, node.ry, node.rz)
    let (xx, xy, xz) = rotate_point((1.0, 0.0, 0.0), node.rx, node.ry, node.rz)
    placements.push(
      ctx.axis2_placement_3d(
        ctx.cartesian_point(node.tx, node.ty, node.tz),
        ctx.direction(zx, zy, zz),
        ctx.direction(xx, xy, xz),
      ),
    )
  }
  let parent_items : Array[@step.Ref] = [identity]
  for placement in placements {
    parent_items.push(placement)
  }
  let parent_sr_ref = ctx.add(
    @repository.any_entity_shape_representation(
      @product.ShapeRepresentation::new(assembly_name + "-SR", parent_items, {
        id: ctx.repo_ctx_id,
      }),
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

  // One child product and shape representation per unique definition.
  let child_refs : Array[(@step.Ref, @step.Ref, @step.Ref)] = []
  for i in 0..<groups.length() {
    let group = groups[i]
    let child_identity = ctx.axis2_placement_3d(
      ctx.cartesian_point(0.0, 0.0, 0.0),
      ctx.direction(0.0, 0.0, 1.0),
      ctx.direction(1.0, 0.0, 0.0),
    )
    let items : Array[@step.Ref] = [child_identity]
    for brep in group_breps[i] {
      items.push(brep)
    }
    let child_pd_ref = ctx.add_product_definition(group.name)
    let child_sr_ref = ctx.add(
      @repository.any_entity_advanced_brep_shape_representation(
        @product.AdvancedBrepShapeRepresentation::new(
          group.name + "-SR",
          items,
          @step.Ref::{ id: ctx.repo_ctx_id, },
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
    child_refs.push((child_pd_ref, child_sr_ref, child_identity))
  }

  // One NAUO + IDT + CDSR per instance placement.
  let mut index = 0
  for i in 0..<groups.length() {
    let group = groups[i]
    let (child_pd_ref, child_sr_ref, child_identity) = child_refs[i]
    for node_index in group.indices {
      index = index + 1
      let node = self.nodes[node_index]
      let instance_a2p = placements[node_index]
      let nauo_ref = ctx.add(
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
      let placement_pds_ref = ctx.add(
        @repository.any_entity_product_definition_shape(
          @product.ProductDefinitionShape::new(
            "Placement", "Placement of an item", nauo_ref,
          ),
        ),
      )
      let idt_ref = ctx.add(
        @repository.any_entity_item_defined_transformation(
          @product.ItemDefinedTransformation::new(
            "", "", child_identity, instance_a2p,
          ),
        ),
      )
      let relationship_ref = ctx.add(
        @repository.any_entity_complex_instance(
          @context.ComplexInstance::new([
            @context.ComplexPart::RepRel(
              @product.RepresentationRelationship::new(
                "", "", child_sr_ref, parent_sr_ref,
              ),
            ),
            @context.ComplexPart::RepRelWT(
              @product.RepresentationRelationshipWithTransformation::new(
                idt_ref,
              ),
            ),
            @context.ComplexPart::ShapeRepRel,
          ]),
        ),
      )
      let _ = ctx.add(
        @repository.any_entity_context_dependent_shape_representation(
          @product.ContextDependentShapeRepresentation::new(
            relationship_ref, placement_pds_ref,
          ),
        ),
      )
    }
  }

  let file_name = self.name + ".step"
  let has_nominal_boolean = self.diagnostics().any(fn(d) { d.is_nominal() })
  ctx.repo = ctx.repo.set_header(
    default_header(
      file_name,
      self.description,
      self.documentation,
      nominal=has_nominal_boolean,
      timestamp?=self.timestamp,
    ),
  )
  ctx.repo.to_step_file()
}

///|
/// Emits a deduplicated, instanced STEP assembly: one part definition per
/// unique geometry + colour, and one usage/placement per design node.
pub fn Design::to_instanced_step_string(
  self : Design,
  assembly_name~ : String,
) -> String {
  self.to_assembly_step_impl(assembly_name~, instanced=true)
}
