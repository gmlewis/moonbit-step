///|
/// A parsed STEP file that can be placed as a rigid solid in a `Design`.
///
/// The imported entity graph is kept intact, including its original product,
/// shape-representation, and presentation entities. `Design::compile` seeds
/// its `StepContext` with this repository before compiling the DSL nodes, so
/// every imported `@step.Ref` still resolves. The scene node's transform is
/// applied by baking it into the imported `CARTESIAN_POINT`/`DIRECTION`
/// entities and resetting the file's shape-representation placements to the
/// identity, so readers (which apply those placements on top of the baked
/// geometry) do not apply the transform a second time.
///
/// One imported STEP per design is supported. Use it for static purchased parts
/// whose exact vendor B-Rep must appear in the flat STEP output; DSL bodies
/// remain the source of the parametric geometry.
pub struct ImportedStep {
  repository : @repository.Repository
  min_pt : (Double, Double, Double)
  max_pt : (Double, Double, Double)
  source : String
}

///|
/// ImportedStep::from_repository wraps an already parsed STEP repository.
///
/// The source is recorded for provenance and appears in the node metadata.
pub fn ImportedStep::from_repository(
  repository : @repository.Repository,
  source~ : String = "",
) -> ImportedStep {
  // Only points referenced by vertices describe geometry; other points
  // (placement origins, construction geometry) are ignored so the bounding
  // box reflects the solid, not the frame around it.
  let vertex_points : Map[Int32, Unit] = Map([])
  repository.each(fn(entity) {
    match entity {
      @repository.AnyEntity::VertexPoint(v) =>
        vertex_points.set(v.vertex_geometry_ref().id.value, ())
      _ => ()
    }
  })
  let filter_by_vertices = vertex_points.length() > 0
  let mut x0 = @double.max_value
  let mut y0 = @double.max_value
  let mut z0 = @double.max_value
  let mut x1 = @double.min_value
  let mut y1 = @double.min_value
  let mut z1 = @double.min_value
  let mut found = 0
  repository.each_with_id(fn(id, entity) {
    match entity {
      @repository.AnyEntity::CartesianPoint(p) =>
        if p.coordinates.length() >= 3 &&
          (!filter_by_vertices || vertex_points.contains(id.value)) {
          let x = p.coordinates[0]
          let y = p.coordinates[1]
          let z = p.coordinates[2]
          if x < x0 {
            x0 = x
          }
          if x > x1 {
            x1 = x
          }
          if y < y0 {
            y0 = y
          }
          if y > y1 {
            y1 = y
          }
          if z < z0 {
            z0 = z
          }
          if z > z1 {
            z1 = z
          }
          found += 1
        }
      _ => ()
    }
  })
  if found == 0 || x0 > x1 || y0 > y1 || z0 > z1 {
    ImportedStep::{
      repository,
      min_pt: (0.0, 0.0, 0.0),
      max_pt: (0.0, 0.0, 0.0),
      source,
    }
  } else {
    ImportedStep::{
      repository,
      min_pt: (x0, y0, z0),
      max_pt: (x1, y1, z1),
      source,
    }
  }
}

///|
/// ImportedStep::from_string parses ISO 10303-21 text into an importable solid.
///
/// The parser is lossless, so the imported entities are re-emitted unchanged
/// except for the rigid placement applied by `Design::compile`.
pub fn ImportedStep::from_string(
  text : String,
  source~ : String = "",
) -> Result[ImportedStep, @parse.StepParseErrorInfo] {
  match @parse.parse_repository_from_string_result(text) {
    @parse.ParseRepositoryResult::Ok(repo) =>
      Ok(ImportedStep::from_repository(repo, source~))
    @parse.ParseRepositoryResult::Err(info) => Err(info)
  }
}

///|
/// ImportedStep::source is the provenance string recorded at import time.
pub fn ImportedStep::source(self : ImportedStep) -> String {
  self.source
}

///|
/// ImportedStep::bounding_box is the bounding box of the imported geometry
/// (in whatever frame the repository is currently in).
pub fn ImportedStep::bounding_box(
  self : ImportedStep,
) -> (Double, Double, Double, Double, Double, Double) {
  let (x0, y0, z0) = self.min_pt
  let (x1, y1, z1) = self.max_pt
  (x0, x1, y0, y1, z0, z1)
}

///|
/// ImportedStep::as_shape returns the `Shape` wrapper for scene nodes.
pub fn ImportedStep::as_shape(self : ImportedStep) -> Shape {
  Shape::ImportedStep(self)
}

///|
/// transform_imported_entity applies a rigid transform to the two entities that
/// own coordinates or directions. Placement, surface, curve, and topology
/// entities reference these by id, so rotating/translating the points and
/// directions places the whole B-Rep.
fn transform_imported_entity(
  entity : @repository.AnyEntity,
  xform : Transform,
) -> @repository.AnyEntity {
  match entity {
    @repository.AnyEntity::CartesianPoint(p) =>
      if p.coordinates.length() >= 3 {
        let (x, y, z) = xform.apply(
          (p.coordinates[0], p.coordinates[1], p.coordinates[2]),
        )
        @repository.any_entity_cartesian_point(
          @geometry.CartesianPoint::new(p.name, [x, y, z]),
        )
      } else if p.coordinates.length() == 2 {
        let (x, y, _) = xform.apply((p.coordinates[0], p.coordinates[1], 0.0))
        @repository.any_entity_cartesian_point(
          @geometry.CartesianPoint::new(p.name, [x, y]),
        )
      } else {
        entity
      }
    @repository.AnyEntity::Direction(d) =>
      if d.ratios.length() >= 3 {
        let (x, y, z) = xform.apply_dir((d.ratios[0], d.ratios[1], d.ratios[2]))
        @repository.any_entity_direction(
          @geometry.Direction::new(d.name, [x, y, z]),
        )
      } else if d.ratios.length() == 2 {
        let (x, y, _) = xform.apply_dir((d.ratios[0], d.ratios[1], 0.0))
        @repository.any_entity_direction(
          @geometry.Direction::new(d.name, [x, y]),
        )
      } else {
        entity
      }
    _ => entity
  }
}

///|
/// sr_placement_ids returns the ids of the AXIS2_PLACEMENT_3D entities that
/// appear as items of any shape representation in the file. STEP readers
/// apply those placements on top of the representation's geometry, so they
/// must be neutralized when the geometry is baked into world coordinates.
fn sr_placement_ids(repo : @repository.Repository) -> Array[Int32] {
  let lookup : Map[Int32, @repository.AnyEntity] = Map([])
  repo.each_with_id(fn(id, entity) { lookup.set(id.value, entity) })
  let hits : Map[Int32, Unit] = Map([])
  repo.each_with_id(fn(_id, entity) {
    let refs = match entity {
      @repository.AnyEntity::ShapeRepresentation(r) => Some(r.items_view())
      @repository.AnyEntity::AdvancedBrepShapeRepresentation(r) =>
        Some(r.items_view())
      @repository.AnyEntity::CsgShapeRepresentation(r) => Some(r.items_view())
      _ => None
    }
    match refs {
      Some(items) =>
        for item in items {
          match lookup.get(item.id.value) {
            Some(@repository.AnyEntity::Axis2Placement3D(_)) =>
              hits.set(item.id.value, ())
            _ => ()
          }
        }
      None => ()
    }
  })
  let out : Array[Int32] = []
  for id, _ in hits {
    out.push(id)
  }
  out
}

///|
/// ImportedStep::transformed returns a copy whose geometry is rigidly placed.
///
/// The rigid motion is baked into the imported `CARTESIAN_POINT` and
/// `DIRECTION` entities, exactly as before. In addition, every AXIS2_PLACEMENT_3D
/// that is an item of a shape representation is reset to the identity, because
/// readers apply those placements on top of the (baked) coordinates — leaving
/// them in place would apply the motion twice. Entity ids of everything else
/// are preserved, so every internal reference remains valid.
///
/// The file's own product/assembly structure, when present, is preserved
/// verbatim; a vendor STEP that positions its part through its own
/// representation placement is unaffected because that placement carries the
/// vendor frame, not the import placement.
pub fn ImportedStep::transformed(
  self : ImportedStep,
  xform : Transform,
) -> ImportedStep {
  // Pass 1: bake the transform into the geometry.
  let baked = @repository.new()
  self.repository.each_with_id(fn(id, entity) {
    let _ = baked.insert_with_id(id, transform_imported_entity(entity, xform))
  })
  // Pass 2: reset every shape-representation placement to the identity so it
  // does not re-apply the transform on read.
  let placement_ids = sr_placement_ids(baked)
  if placement_ids.length() == 0 {
    let _ = baked.set_header(self.repository.get_header())
    return ImportedStep::from_repository(baked, source=self.source)
  }
  let lookup : Map[Int32, @repository.AnyEntity] = Map([])
  let mut max_id = 0
  baked.each_with_id(fn(id, entity) {
    lookup.set(id.value, entity)
    if id.value > max_id {
      max_id = id.value
    }
  })
  let mut next_id = max_id + 1
  let replacements : Map[Int32, @repository.AnyEntity] = Map([])
  let staged : Array[(Int32, @repository.AnyEntity)] = []
  for pid in placement_ids {
    let name = match lookup.get(pid) {
      Some(@repository.AnyEntity::Axis2Placement3D(p)) => p.name_of()
      _ => ""
    }
    let id_origin = next_id
    let id_z = next_id + 1
    let id_x = next_id + 2
    next_id = next_id + 3
    staged.push(
      (
        id_origin,
        @repository.any_entity_cartesian_point(
          @geometry.CartesianPoint::new("", [0.0, 0.0, 0.0]),
        ),
      ),
    )
    staged.push(
      (
        id_z,
        @repository.any_entity_direction(
          @geometry.Direction::new("", [0.0, 0.0, 1.0]),
        ),
      ),
    )
    staged.push(
      (
        id_x,
        @repository.any_entity_direction(
          @geometry.Direction::new("", [1.0, 0.0, 0.0]),
        ),
      ),
    )
    replacements.set(
      pid,
      @repository.any_entity_axis2_placement_3d(
        @geometry.Axis2Placement3D::new(
          name,
          @step.Ref::{ id: @step.EntityId::{ value: id_origin, }, },
          @step.Ref::{ id: @step.EntityId::{ value: id_z, }, },
          @step.Ref::{ id: @step.EntityId::{ value: id_x, }, },
        ),
      ),
    )
  }
  let out = @repository.new()
  baked.each_with_id(fn(id, entity) {
    let e = match replacements.get(id.value) {
      Some(r) => r
      None => entity
    }
    let _ = out.insert_with_id(id, e)
  })
  for entry in staged {
    let (id, entity) = entry
    let _ = out.insert_with_id(@step.EntityId::{ value: id, }, entity)
  }
  let _ = out.set_header(self.repository.get_header())
  ImportedStep::from_repository(out, source=self.source)
}
