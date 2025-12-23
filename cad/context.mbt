///|
// Internal helper to manage the repository and shared STEP entities.
pub struct StepContext {
  mut repo : @repository.Repository
  // Shared references
  mut length_unit_id : @step.EntityId
  mut plane_angle_unit_id : @step.EntityId
  mut solid_angle_unit_id : @step.EntityId
  mut uncertainty_id : @step.EntityId
  mut repo_ctx_id : @step.EntityId

  // Deduplication caches
  directions : Map[String, @step.Ref]
  vectors : Map[String, @step.Ref]
  cartesian_points : Map[String, @step.Ref]
  vertex_points : Map[Int, @step.Ref]
  lines : Map[String, @step.Ref]
  edge_curves : Map[String, @step.Ref]
}

///|
pub fn StepContext::new() -> StepContext {
  {
    repo: @repository.new(),
    length_unit_id: { value: 0 },
    plane_angle_unit_id: { value: 0 },
    solid_angle_unit_id: { value: 0 },
    uncertainty_id: { value: 0 },
    repo_ctx_id: { value: 0 },
    directions: Map::new(),
    vectors: Map::new(),
    cartesian_points: Map::new(),
    vertex_points: Map::new(),
    lines: Map::new(),
    edge_curves: Map::new(),
  }
}

///|
fn StepContext::add(
  self : StepContext,
  entity : @repository.AnyEntity,
) -> @step.Ref {
  let (repo, id) = self.repo.add(entity)
  self.repo = repo
  @step.Ref::{ id, }
}

///|
pub fn StepContext::direction(
  self : StepContext,
  x : Double,
  y : Double,
  z : Double,
) -> @step.Ref {
  let key = "\{x},\{y},\{z}"
  match self.directions.get(key) {
    Some(r) => r
    None => {
      let r = self.add(
        @repository.any_entity_direction(
          @geometry.Direction::new("", [x, y, z]),
        ),
      )
      self.directions.set(key, r)
      r
    }
  }
}

///|
pub fn StepContext::vector(
  self : StepContext,
  dir : @step.Ref,
  magnitude : Double,
) -> @step.Ref {
  let key = "\{dir.id.value},\{magnitude}"
  match self.vectors.get(key) {
    Some(r) => r
    None => {
      let r = self.add(
        @repository.any_entity_vector(@geometry.Vector::new("", dir, magnitude)),
      )
      self.vectors.set(key, r)
      r
    }
  }
}

///|
pub fn StepContext::cartesian_point(
  self : StepContext,
  x : Double,
  y : Double,
  z : Double,
) -> @step.Ref {
  let key = "\{x},\{y},\{z}"
  match self.cartesian_points.get(key) {
    Some(r) => r
    None => {
      let r = self.add(
        @repository.any_entity_cartesian_point(
          @geometry.CartesianPoint::new("", [x, y, z]),
        ),
      )
      self.cartesian_points.set(key, r)
      r
    }
  }
}

///|
pub fn StepContext::vertex_point(
  self : StepContext,
  cp_ref : @step.Ref,
) -> @step.Ref {
  match self.vertex_points.get(cp_ref.id.value) {
    Some(r) => r
    None => {
      let vp = @topology.VertexPoint::new("", cp_ref)
      let r = self.add(@repository.any_entity_vertex_point(vp))
      self.vertex_points.set(cp_ref.id.value, r)
      r
    }
  }
}

///|
pub fn StepContext::line(
  self : StepContext,
  pnt : @step.Ref,
  dir : @step.Ref,
) -> @step.Ref {
  let key = "\{pnt.id.value},\{dir.id.value}"
  match self.lines.get(key) {
    Some(r) => r
    None => {
      let line = @geometry.Line::new("", pnt, dir)
      let r = self.add(@repository.any_entity_line(line))
      self.lines.set(key, r)
      r
    }
  }
}

///|
pub fn StepContext::edge_curve(
  self : StepContext,
  start : @step.Ref,
  end : @step.Ref,
  curve : @step.Ref,
  same_sense : Bool,
) -> @step.Ref {
  let key = "\{start.id.value},\{end.id.value},\{curve.id.value},\{same_sense}"
  match self.edge_curves.get(key) {
    Some(r) => r
    None => {
      let ec = @topology.EdgeCurve::new("", start, end, curve, same_sense)
      let r = self.add(@repository.any_entity_edge_curve(ec))
      self.edge_curves.set(key, r)
      r
    }
  }
}

///|
// Initialize the standard STEP context (units, precision, etc.)
pub fn StepContext::init_standard_context(
  self : StepContext,
  name : String,
) -> Unit {
  let dim_exp = @units.DimensionalExponents::new(
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  )
  let dim_exp_id = self.add(
      @repository.any_entity_dimensional_exponents(dim_exp),
    ).id

  // Radian
  let cx_radian = @context.ComplexInstance::new([
    @context.ComplexPart::NamedUnit(@units.NamedUnit::new("*")),
    @context.ComplexPart::PlaneAngleUnit(@units.PlaneAngleUnit::new()),
    @context.ComplexPart::SiUnit(@units.SiUnit::new("$", ".RADIAN.")),
  ])
  let radian_ref = self.add(@repository.any_entity_complex_instance(cx_radian))

  // Degree
  let pa_meas = @units.PlaneAngleMeasureWithUnit::new(
    "0.0174532925", radian_ref,
  )
  let pa_meas_ref = self.add(
    @repository.any_entity_plane_angle_measure_with_unit(pa_meas),
  )
  let cx_degree = @context.ComplexInstance::new([
    @context.ComplexPart::ConversionBasedUnit(
      @units.ConversionBasedUnit::new("DEGREE", pa_meas_ref),
    ),
    @context.ComplexPart::NamedUnit(
      @units.NamedUnit::new("#\{dim_exp_id.value}"),
    ),
    @context.ComplexPart::PlaneAngleUnit(@units.PlaneAngleUnit::new()),
  ])
  self.plane_angle_unit_id = self.add(
      @repository.any_entity_complex_instance(cx_degree),
    ).id

  // Steradian
  let cx_steradian = @context.ComplexInstance::new([
    @context.ComplexPart::NamedUnit(@units.NamedUnit::new("*")),
    @context.ComplexPart::SiUnit(@units.SiUnit::new("$", ".STERADIAN.")),
    @context.ComplexPart::SolidAngleUnit(@units.SolidAngleUnit::new()),
  ])
  self.solid_angle_unit_id = self.add(
      @repository.any_entity_complex_instance(cx_steradian),
    ).id

  // Millimetre
  let cx_mm = @context.ComplexInstance::new([
    @context.ComplexPart::LengthUnit(@units.LengthUnit::new()),
    @context.ComplexPart::NamedUnit(@units.NamedUnit::new("*")),
    @context.ComplexPart::SiUnit(@units.SiUnit::new(".MILLI.", ".METRE.")),
  ])
  let mm_ref = self.add(@repository.any_entity_complex_instance(cx_mm))
  self.length_unit_id = mm_ref.id

  // Uncertainty
  let unc = @units.UncertaintyMeasureWithUnit::new(
    "2.E-005", mm_ref, "DISTANCE_ACCURACY_VALUE", "Maximum Tolerance applied to model",
  )
  self.uncertainty_id = self.add(
      @repository.any_entity_uncertainty_measure_with_unit(unc),
    ).id

  // Global Context
  let cx_ctx = @context.ComplexInstance::new([
    @context.ComplexPart::GeomRepCtx(
      @context.GeometricRepresentationContext::new(3),
    ),
    @context.ComplexPart::GlobUncCtx(
      @context.GlobalUncertaintyAssignedContext::new([self.uncertainty_id]),
    ),
    @context.ComplexPart::GlobUnitCtx(
      @context.GlobalUnitAssignedContext::new([
        self.length_unit_id,
        self.plane_angle_unit_id,
        self.solid_angle_unit_id,
      ]),
    ),
    @context.ComplexPart::RepCtx(
      @context.RepresentationContext::new(name, "TOP_LEVEL_ASSEMBLY_PART"),
    ),
  ])
  self.repo_ctx_id = self.add(@repository.any_entity_complex_instance(cx_ctx)).id
}

///|
// Helper to create the product structure for a part.
pub fn StepContext::add_product_definition(
  self : StepContext,
  name : String,
) -> @step.Ref {
  let app_ctx = @product.ApplicationContext::new(
    "core data for automotive mechanical design processes",
  )
  let app_ctx_ref = self.add(
    @repository.any_entity_application_context(app_ctx),
  )
  let app_proto = @product.ApplicationProtocolDefinition::new(
    "international standard", "automotive_design", 2010, app_ctx_ref,
  )
  let _ = self.add(
    @repository.any_entity_application_protocol_definition(app_proto),
  )
  let prod_ctx = @product.ProductContext::new(" ", app_ctx_ref, "mechanical")
  let prod_ctx_ref = self.add(@repository.any_entity_product_context(prod_ctx))
  let product = @product.Product::new(name, name, " ", [prod_ctx_ref])
  let product_ref = self.add(@repository.any_entity_product(product))
  let cat = @product.ProductRelatedProductCategory::new("part", "", [
    product_ref,
  ])
  let _ = self.add(@repository.any_entity_product_related_product_category(cat))
  let form = @product.ProductDefinitionFormationWithSpecifiedSource::new(
    " ", " ", product_ref, ".NOT_KNOWN.",
  )
  let form_ref = self.add(
    @repository.any_entity_product_definition_formation_with_specified_source(
      form,
    ),
  )
  let def_ctx = @product.ProductDefinitionContext::new(
    "part definition", app_ctx_ref, "design",
  )
  let def_ctx_ref = self.add(
    @repository.any_entity_product_definition_context(def_ctx),
  )
  let prod_def = @product.ProductDefinition::new(" ", "", form_ref, def_ctx_ref)
  self.add(@repository.any_entity_product_definition(prod_def))
}
