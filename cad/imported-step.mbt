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
/// Several imports per design are supported; compile() shifts each
/// import's entity ids apart and merges them into one repository. Use it for
/// static purchased parts whose exact vendor B-Rep must appear in the flat
/// STEP output; DSL bodies remain the source of the parametric geometry.
pub struct ImportedStep {
  repository : @repository.Repository
  min_pt : (Double, Double, Double)
  max_pt : (Double, Double, Double)
  source : String
  /// The original STEP text, kept so the same file can be re-imported with
  /// shifted entity ids when several imports are merged into one design.
  text : String?
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
      text: None,
    }
  } else {
    ImportedStep::{
      repository,
      min_pt: (x0, y0, z0),
      max_pt: (x1, y1, z1),
      source,
      text: None,
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
    @parse.ParseRepositoryResult::Ok(repo) => {
      let imported = ImportedStep::from_repository(repo, source~)
      Ok(ImportedStep::{ ..imported, text: Some(text), })
    }
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
/// item of a shape representation is replaced in that representation's `items`
/// list with a fresh identity AXIS2_PLACEMENT_3D, because readers apply
/// representation placements on top of the (baked) coordinates — leaving them
/// non-identity would apply the motion twice, while overwriting the original
/// placement entity in place would corrupt any face or curve that shares its
/// entity id. Entity ids of everything else are preserved, so every internal
/// reference remains valid.
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
  // Pass 2: point shape-representation placement items at fresh identity
  // placements so readers do not re-apply the transform without mutating any
  // shared geometry placement entities in place.
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
  let pid_map : Map[Int32, Int32] = Map([])
  let staged : Array[(Int32, @repository.AnyEntity)] = []
  for pid in placement_ids {
    let name = match lookup.get(pid) {
      Some(@repository.AnyEntity::Axis2Placement3D(p)) => p.name_of()
      _ => ""
    }
    let id_origin = next_id
    let id_z = next_id + 1
    let id_x = next_id + 2
    let id_ax = next_id + 3
    next_id = next_id + 4
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
    staged.push(
      (
        id_ax,
        @repository.any_entity_axis2_placement_3d(
          @geometry.Axis2Placement3D::new(
            name,
            @step.Ref::{ id: @step.EntityId::{ value: id_origin, }, },
            @step.Ref::{ id: @step.EntityId::{ value: id_z, }, },
            @step.Ref::{ id: @step.EntityId::{ value: id_x, }, },
          ),
        ),
      ),
    )
    pid_map.set(pid, id_ax)
  }
  let map_items = fn(items : Array[@step.Ref]) -> Array[@step.Ref] {
    items.map(fn(item) {
      match pid_map.get(item.id.value) {
        Some(new_id) => @step.Ref::{ id: @step.EntityId::{ value: new_id, }, }
        None => item
      }
    })
  }
  let out = @repository.new()
  baked.each_with_id(fn(id, entity) {
    let e = match entity {
      @repository.AnyEntity::ShapeRepresentation(r) =>
        @repository.any_entity_shape_representation(
          r.with_items(map_items(r.items_view())),
        )
      @repository.AnyEntity::AdvancedBrepShapeRepresentation(r) =>
        @repository.any_entity_advanced_brep_shape_representation(
          r.with_items(map_items(r.items_view())),
        )
      @repository.AnyEntity::CsgShapeRepresentation(r) =>
        @repository.any_entity_csg_shape_representation(
          r.with_items(map_items(r.items_view())),
        )
      _ => entity
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

///|
/// Re-issues every `#id` reference in a STEP text as `#(id + delta)` so the
/// entity range of one file can be shifted out of another's. Single-quoted
/// strings are copied verbatim, so ids mentioned inside strings are never
/// touched. `delta` must be at least the largest entity id in use.
fn shift_step_ids_text(text : String, delta : Int32) -> String {
  if delta <= 0 {
    return text
  }
  let out = StringBuilder()
  let n = text.length()
  let mut i = 0
  let mut in_str = false
  while i < n {
    let c = String::code_unit_at(text, i).to_int()
    if c == Char::to_int('\'') {
      out.write_char('\'')
      if in_str {
        // Doubled quote is an escaped quote; copy both and stay in string.
        if i + 1 < n &&
          String::code_unit_at(text, i + 1).to_int() == Char::to_int('\'') {
          out.write_char('\'')
          i = i + 2
          continue
        }
        in_str = false
        i = i + 1
        continue
      }
      in_str = true
      i = i + 1
      continue
    }
    if !in_str && c == Char::to_int('#') {
      let mut j = i + 1
      let mut value = 0
      let mut digits = 0
      while j < n {
        let d = String::code_unit_at(text, j).to_int()
        if d >= Char::to_int('0') && d <= Char::to_int('9') {
          value = value * 10 + (d - Char::to_int('0'))
          j = j + 1
          digits = digits + 1
        } else {
          break
        }
      }
      if digits == 0 {
        out.write_char('#')
        i = i + 1
        continue
      }
      out.write_string("#" + (value + delta).to_string())
      i = j
      continue
    }
    out.write_char(c.unsafe_to_char())
    i = i + 1
  }
  out.to_string()
}

///|
/// The largest entity id in the import's repository, or 0 for an empty one.
pub fn ImportedStep::max_id(self : ImportedStep) -> Int32 {
  let mut max_id = 0
  self.repository.each_with_id(fn(id, _) {
    if id.value > max_id {
      max_id = id.value
    }
  })
  max_id
}

///|
/// ImportedStep::shifted re-parses this import with every entity id moved up
/// by `delta`, so several imports can be merged into one repository without
/// id collisions. Imports built from `from_repository` (no source text)
/// cannot be shifted and abort.
pub fn ImportedStep::shifted(
  self : ImportedStep,
  delta : Int32,
) -> ImportedStep {
  if delta <= 0 {
    return self
  }
  match self.text {
    Some(text) =>
      match
        ImportedStep::from_string(
          shift_step_ids_text(text, delta),
          source=self.source,
        ) {
        Ok(shifted) => shifted
        Err(info) =>
          abort(
            "could not re-parse shifted STEP text for '\{self.source}': \{info.message}",
          )
      }
    None =>
      abort(
        "ImportedStep::shifted requires STEP source text; '\{self.source}' was not imported from a string",
      )
  }
}

///|
/// ImportedStep::merge unions several imports into one. Each input must
/// already have disjoint entity id ranges (use `shifted`); entities are
/// copied verbatim, so internal references keep resolving. The combined
/// bounding box covers all inputs.
pub fn ImportedStep::merge(parts : Array[ImportedStep]) -> ImportedStep {
  let mut min_x = @double.max_value
  let mut min_y = @double.max_value
  let mut min_z = @double.max_value
  let mut max_x = @double.min_value
  let mut max_y = @double.min_value
  let mut max_z = @double.min_value
  let repo = @repository.new()
  let mut source = ""
  for part in parts {
    part.repository.each_with_id(fn(id, entity) {
      let _ = repo.insert_with_id(id, entity)
    })
    let (x0, x1, y0, y1, z0, z1) = part.bounding_box()
    if x0 < min_x {
      min_x = x0
    }
    if y0 < min_y {
      min_y = y0
    }
    if z0 < min_z {
      min_z = z0
    }
    if x1 > max_x {
      max_x = x1
    }
    if y1 > max_y {
      max_y = y1
    }
    if z1 > max_z {
      max_z = z1
    }
    source = if source == "" { part.source } else { source + "+" + part.source }
  }
  ImportedStep::{
    repository: repo,
    min_pt: (min_x, min_y, min_z),
    max_pt: (max_x, max_y, max_z),
    source,
    text: None,
  }
}

///|
/// Escape a string for embedding in a STEP single-quoted string.
fn escape_step_string(value : String) -> String {
  let out = StringBuilder()
  for c in value {
    if c == '\'' {
      out.write_char('\'')
      out.write_char('\'')
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
/// Rewrite the first quoted string of every `PRODUCT(...)` entity in `text`
/// to the new name, in document order. Keeps the source text of a renamed
/// import in sync with its repository so it can be re-parsed later.
fn rename_products_in_text(
  text : String,
  name : String,
  count : Int32,
) -> String {
  let needle : ReadOnlyArray[_] = ['P', 'R', 'O', 'D', 'U', 'C', 'T', '(']
  let out = StringBuilder()
  let n = text.length()
  let mut i = 0
  let mut index = 0
  let cu = fn(i : Int32) -> Int32 { String::code_unit_at(text, i).to_int() }
  let is_ws = fn(c : Int32) -> Bool {
    c == Char::to_int(' ') ||
    c == Char::to_int('\n') ||
    c == Char::to_int('\r') ||
    c == Char::to_int('\t')
  }
  let quote = Char::to_int('\'')
  while i < n {
    let mut matched = i + needle.length() <= n
    if matched {
      for k in 0..<needle.length() {
        if cu(i + k) != Char::to_int(needle[k]) {
          matched = false
          break
        }
      }
    }
    if !matched {
      out.write_char(cu(i).unsafe_to_char())
      i = i + 1
      continue
    }
    out.write_string("PRODUCT(")
    i = i + needle.length()
    while i < n && is_ws(cu(i)) {
      out.write_char(cu(i).unsafe_to_char())
      i = i + 1
    }
    if i < n && cu(i) == quote {
      index = index + 1
      let pname = if count > 1 { name + "_" + index.to_string() } else { name }
      // PRODUCT('name','id',...) — rename both fields to match the repository
      // (the description string, if any, is left alone).
      for _ in 0..<2 {
        out.write_char('\'')
        i = i + 1
        let mut in_str = true
        while i < n && in_str {
          if cu(i) == quote {
            if i + 1 < n && cu(i + 1) == quote {
              i = i + 2
              continue
            }
            in_str = false
            i = i + 1
            continue
          }
          i = i + 1
        }
        out.write_string(escape_step_string(pname))
        out.write_char('\'')
        // Skip the comma and whitespace before the next quoted field.
        while i < n && is_ws(cu(i)) {
          out.write_char(cu(i).unsafe_to_char())
          i = i + 1
        }
        if i < n && cu(i) == Char::to_int(',') {
          out.write_char(',')
          i = i + 1
          while i < n && is_ws(cu(i)) {
            out.write_char(cu(i).unsafe_to_char())
            i = i + 1
          }
        } else {
          break
        }
        if i >= n || cu(i) != quote {
          break
        }
      }
    }
  }
  out.to_string()
}

///|
/// ImportedStep::renamed returns a copy whose PRODUCT entities are renamed to
/// `name` (suffixed `_2`, `_3`, ... when the file carries several products).
///
/// OCCT-written STEP files give every product the generic name
/// `Open CASCADE STEP translator 7.x y`, which then leaks into the emitted
/// file's product structure. Renaming to the importing body's name keeps the
/// output identifiable in downstream viewers and reports. The retained source
/// text is rewritten in lockstep so a later re-parse stays consistent.
pub fn ImportedStep::renamed(
  self : ImportedStep,
  name : String,
) -> ImportedStep {
  let mut count = 0
  self.repository.each(fn(entity) {
    match entity {
      @repository.AnyEntity::Product(_) => count += 1
      _ => ()
    }
  })
  if count == 0 {
    return self
  }
  let mut index = 0
  let out = @repository.new()
  self.repository.each_with_id(fn(id, entity) {
    let replaced = match entity {
      @repository.AnyEntity::Product(p) => {
        index += 1
        let pname = if count > 1 {
          name + "_" + index.to_string()
        } else {
          name
        }
        @repository.any_entity_product(
          @product.Product::new(
            pname,
            pname,
            p.description,
            p.frame_of_reference,
          ),
        )
      }
      _ => entity
    }
    let _ = out.insert_with_id(id, replaced)
  })
  let _ = out.set_header(self.repository.get_header())
  let text = match self.text {
    Some(t) => Some(rename_products_in_text(t, name, count))
    None => None
  }
  let base = ImportedStep::from_repository(out, source=self.source)
  ImportedStep::{ ..base, text, }
}
