///|
/// A parsed STEP file that can be placed as a rigid solid in a `Design`.
///
/// The imported entity graph is kept intact, including its original product,
/// shape-representation, and presentation entities. `Design::compile` seeds
/// its `StepContext` with this repository before compiling the DSL nodes, so
/// every imported `@step.Ref` still resolves. The scene node's transform is
/// baked into the imported `CARTESIAN_POINT`/`DIRECTION` entities at compile
/// time.
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
  let mut x0 = @double.max_value
  let mut y0 = @double.max_value
  let mut z0 = @double.max_value
  let mut x1 = @double.min_value
  let mut y1 = @double.min_value
  let mut z1 = @double.min_value
  repository.each(fn(entity) {
    match entity {
      @repository.AnyEntity::CartesianPoint(p) =>
        if p.coordinates.length() >= 3 {
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
        }
      _ => ()
    }
  })
  if x0 > x1 || y0 > y1 || z0 > z1 {
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
/// ImportedStep::bounding_box is the local bounding box of the imported
/// geometry.
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
/// ImportedStep::transformed returns a copy whose geometry is rigidly placed.
///
/// Entity ids are preserved, so every internal reference remains valid.
pub fn ImportedStep::transformed(
  self : ImportedStep,
  xform : Transform,
) -> ImportedStep {
  let out = @repository.new()
  self.repository.each_with_id(fn(id, entity) {
    let _ = out.insert_with_id(id, transform_imported_entity(entity, xform))
  })
  let _ = out.set_header(self.repository.get_header())
  ImportedStep::from_repository(out, source=self.source)
}
