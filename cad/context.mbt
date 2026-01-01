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
  axis2_placements : Map[String, @step.Ref]
  oriented_edges : Map[String, @step.Ref]
  edge_loops : Map[String, @step.Ref]
  face_bounds : Map[String, @step.Ref]
  advanced_faces : Map[String, @step.Ref]
}

///|
fn snap_double(v : Double) -> Double {
  let eps = 1.e-5
  let sign = if v < 0.0 { -1.0 } else { 1.0 }
  let abs_v = v.abs()
  let scaled = (abs_v / eps + 0.5).to_int().to_double()
  sign * scaled * eps
}

///|
fn fmt_double(v : Double) -> String {
  let eps = 1.e-5
  let snapped = snap_double(v)
  let abs_snapped = snapped.abs()
  let scaled = (abs_snapped / eps + 0.5).to_int()
  let whole = scaled / 100000
  let frac = scaled % 100000
  let mut frac_str = frac.to_string()
  while frac_str.length() < 5 {
    frac_str = "0" + frac_str
  }
  let sign_str = if snapped < -eps / 2.0 { "-" } else { "" }
  "\{sign_str}\{whole}.\{frac_str}"
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
    axis2_placements: Map::new(),
    oriented_edges: Map::new(),
    edge_loops: Map::new(),
    face_bounds: Map::new(),
    advanced_faces: Map::new(),
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
  let sx = snap_double(x)
  let sy = snap_double(y)
  let sz = snap_double(z)
  let key = "DIR:\{fmt_double(sx)},\{fmt_double(sy)},\{fmt_double(sz)}"
  match self.directions.get(key) {
    Some(r) => r
    None => {
      let r = self.add(
        @repository.any_entity_direction(
          @geometry.Direction::new("", [sx, sy, sz]),
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
  let smag = snap_double(magnitude)
  let key = "VEC:\{dir.id.value},\{fmt_double(smag)}"
  match self.vectors.get(key) {
    Some(r) => r
    None => {
      let r = self.add(
        @repository.any_entity_vector(@geometry.Vector::new("", dir, smag)),
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
  let sx = snap_double(x)
  let sy = snap_double(y)
  let sz = snap_double(z)
  let key = "PNT:\{fmt_double(sx)},\{fmt_double(sy)},\{fmt_double(sz)}"
  match self.cartesian_points.get(key) {
    Some(r) => r
    None => {
      let r = self.add(
        @repository.any_entity_cartesian_point(
          @geometry.CartesianPoint::new("", [sx, sy, sz]),
        ),
      )
      self.cartesian_points.set(key, r)
      r
    }
  }
}

///|
pub fn StepContext::axis2_placement_3d(
  self : StepContext,
  origin : @step.Ref,
  axis : @step.Ref,
  ref_direction : @step.Ref,
) -> @step.Ref {
  let key = "\{origin.id.value},\{axis.id.value},\{ref_direction.id.value}"
  match self.axis2_placements.get(key) {
    Some(r) => r
    None => {
      let a2p = @geometry.Axis2Placement3D::new("", origin, axis, ref_direction)
      let r = self.add(@repository.any_entity_axis2_placement_3d(a2p))
      self.axis2_placements.set(key, r)
      r
    }
  }
}

///|
pub fn StepContext::oriented_edge(
  self : StepContext,
  edge_element : @step.Ref,
  orientation : Bool,
) -> @step.Ref {
  let key = "\{edge_element.id.value},\{orientation}"
  match self.oriented_edges.get(key) {
    Some(r) => r
    None => {
      let oe = @topology.OrientedEdge::new(
        "", "*", "*", edge_element, orientation,
      )
      let r = self.add(@repository.any_entity_oriented_edge(oe))
      self.oriented_edges.set(key, r)
      r
    }
  }
}

///|
pub fn StepContext::edge_loop(
  self : StepContext,
  edge_list : Array[@step.Ref],
) -> @step.Ref {
  let key = edge_list.map(fn(r) { r.id.value.to_string() }).join(",")
  match self.edge_loops.get(key) {
    Some(r) => r
    None => {
      let el = @topology.EdgeLoop::new("", edge_list)
      let r = self.add(@repository.any_entity_edge_loop(el))
      self.edge_loops.set(key, r)
      r
    }
  }
}

///|
pub fn StepContext::face_bound(
  self : StepContext,
  bound : @step.Ref,
  orientation : Bool,
) -> @step.Ref {
  let key = "\{bound.id.value},\{orientation}"
  match self.face_bounds.get(key) {
    Some(r) => r
    None => {
      let fb = @topology.FaceBound::new("", bound, orientation)
      let r = self.add(@repository.any_entity_face_bound(fb))
      self.face_bounds.set(key, r)
      r
    }
  }
}

///|
pub fn StepContext::face_outer_bound(
  self : StepContext,
  bound : @step.Ref,
  orientation : Bool,
) -> @step.Ref {
  let key = "OUTER:\{bound.id.value},\{orientation}"
  match self.face_bounds.get(key) {
    Some(r) => r
    None => {
      let fob = @topology.FaceOuterBound::new("", bound, orientation)
      let r = self.add(@repository.any_entity_face_outer_bound(fob))
      self.face_bounds.set(key, r)
      r
    }
  }
}

///|
pub fn StepContext::advanced_face(
  self : StepContext,
  bounds : Array[@step.Ref],
  face_geometry : @step.Ref,
  same_sense : Bool,
) -> @step.Ref {
  let bounds_key = bounds.map(fn(r) { r.id.value.to_string() }).join(",")
  let key = "\{face_geometry.id.value},\{same_sense}:\{bounds_key}"
  match self.advanced_faces.get(key) {
    Some(r) => r
    None => {
      let af = @topology.AdvancedFace::new(
        "", bounds, face_geometry, same_sense,
      )
      let r = self.add(@repository.any_entity_advanced_face(af))
      self.advanced_faces.set(key, r)
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
