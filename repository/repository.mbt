///|
pub enum AnyEntity {
  RawEntity(@step.RawEntity)
  CartesianPoint(@geometry.CartesianPoint)
  Direction(@geometry.Direction)
  Axis1Placement(@geometry.Axis1Placement)
  Axis2Placement3D(@geometry.Axis2Placement3D)
  Plane(@geometry.Plane)
  Vector(@geometry.Vector)
  Line(@geometry.Line)
  Circle(@geometry.Circle)
  Ellipse(@geometry.Ellipse)
  Parabola(@geometry.Parabola)
  Hyperbola(@geometry.Hyperbola)
  CylindricalSurface(@geometry.CylindricalSurface)
  ConicalSurface(@geometry.ConicalSurface)
  ToroidalSurface(@geometry.ToroidalSurface)
  BSplineCurve(@geometry.BSplineCurve)
  BSplineCurveWithKnots(@geometry.BSplineCurveWithKnots)
  BSplineSurface(@geometry.BSplineSurface)
  BSplineSurfaceWithKnots(@geometry.BSplineSurfaceWithKnots)
  RationalBSplineCurve(@geometry.RationalBSplineCurve)
  RationalBSplineSurface(@geometry.RationalBSplineSurface)
  TrimmedCurve(@geometry.TrimmedCurve)
  OffsetCurve3D(@geometry.OffsetCurve3D)
  OffsetSurface(@geometry.OffsetSurface)
  SurfaceOfLinearExtrusion(@geometry.SurfaceOfLinearExtrusion)
  SurfaceOfRevolution(@geometry.SurfaceOfRevolution)
  SweptSurface(@geometry.SweptSurface)
  RectangularTrimmedSurface(@geometry.RectangularTrimmedSurface)
  Polyline(@geometry.Polyline)
  BooleanResult(@geometry.BooleanResult)
  CsgSolid(@geometry.CsgSolid)
  Block(@geometry.Block)
  Sphere(@geometry.Sphere)
  RightCircularCylinder(@geometry.RightCircularCylinder)
  RightCircularCone(@geometry.RightCircularCone)
  Torus(@geometry.Torus)
  RectangularPyramid(@geometry.RectangularPyramid)
  RightAngularWedge(@geometry.RightAngularWedge)
  HalfSpaceSolid(@geometry.HalfSpaceSolid)
  RepresentationRelationship(@product.RepresentationRelationship)
  RepresentationRelationshipWithTransformation(
    @product.RepresentationRelationshipWithTransformation
  )
  ShapeRepresentationRelationship(@product.ShapeRepresentationRelationship)
  AdvancedBrepShapeRepresentation(@product.AdvancedBrepShapeRepresentation)
  ShapeRepresentation(@product.ShapeRepresentation)
  Representation(@product.Representation)
  ShapeDefinitionRepresentation(@product.ShapeDefinitionRepresentation)
  DescriptiveRepresentationItem(@product.DescriptiveRepresentationItem)
  MeasureRepresentationItem(@product.MeasureRepresentationItem)
  ContextDependentShapeRepresentation(
    @product.ContextDependentShapeRepresentation
  )
  ItemDefinedTransformation(@product.ItemDefinedTransformation)
  NextAssemblyUsageOccurrence(@product.NextAssemblyUsageOccurrence)
  ProductDefinitionShape(@product.ProductDefinitionShape)
  ProductDefinition(@product.ProductDefinition)
  ProductDefinitionContext(@product.ProductDefinitionContext)
  ProductDefinitionFormation(@product.ProductDefinitionFormation)
  ProductDefinitionFormationWithSpecifiedSource(
    @product.ProductDefinitionFormationWithSpecifiedSource
  )
  PropertyDefinition(@product.PropertyDefinition)
  PropertyDefinitionRepresentation(@product.PropertyDefinitionRepresentation)
  ProductRelatedProductCategory(@product.ProductRelatedProductCategory)
  Product(@product.Product)
  ProductContext(@product.ProductContext)
  ApplicationProtocolDefinition(@product.ApplicationProtocolDefinition)
  ApplicationContext(@product.ApplicationContext)
  ManifoldSolidBrep(@topology.ManifoldSolidBrep)
  ClosedShell(@topology.ClosedShell)
  OpenShell(@topology.OpenShell)
  ShellBasedSurfaceModel(@topology.ShellBasedSurfaceModel)
  AdvancedFace(@topology.AdvancedFace)
  FaceSurface(@topology.FaceSurface)
  Subface(@topology.Subface)
  FaceOuterBound(@topology.FaceOuterBound)
  FaceBound(@topology.FaceBound)
  EdgeLoop(@topology.EdgeLoop)
  OrientedEdge(@topology.OrientedEdge)
  EdgeCurve(@topology.EdgeCurve)
  VertexPoint(@topology.VertexPoint)
  ColorRgb(@presentation.ColorRgb)
  FillAreaStyleColor(@presentation.FillAreaStyleColor)
  FillAreaStyle(@presentation.FillAreaStyle)
  SurfaceStyleFillArea(@presentation.SurfaceStyleFillArea)
  SurfaceSideStyle(@presentation.SurfaceSideStyle)
  SurfaceStyleUsage(@presentation.SurfaceStyleUsage)
  PresentationStyleAssignment(@presentation.PresentationStyleAssignment)
  PresentationLayerAssignment(@presentation.PresentationLayerAssignment)
  MechanicalDesignGeometricPresentationRepresentation(
    @presentation.MechanicalDesignGeometricPresentationRepresentation
  )
  StyledItem(@presentation.StyledItem)
  DimensionalExponents(@units.DimensionalExponents)
  UncertaintyMeasureWithUnit(@units.UncertaintyMeasureWithUnit)
  PlaneAngleMeasureWithUnit(@units.PlaneAngleMeasureWithUnit)
  DerivedUnitElement(@units.DerivedUnitElement)
  DerivedUnit(@units.DerivedUnit)
  CtxWrap(@context.CtxWrap)
  ComplexInstance(@context.ComplexInstance)
}

///|
pub fn any_entity_raw_entity(e : @step.RawEntity) -> AnyEntity {
  AnyEntity::RawEntity(e)
}

///|
pub fn any_entity_cartesian_point(p : @geometry.CartesianPoint) -> AnyEntity {
  AnyEntity::CartesianPoint(p)
}

///|
pub fn any_entity_direction(d : @geometry.Direction) -> AnyEntity {
  AnyEntity::Direction(d)
}

///|
pub fn any_entity_axis1_placement(a : @geometry.Axis1Placement) -> AnyEntity {
  AnyEntity::Axis1Placement(a)
}

///|
pub fn any_entity_axis2_placement_3d(
  a : @geometry.Axis2Placement3D,
) -> AnyEntity {
  AnyEntity::Axis2Placement3D(a)
}

///|
pub fn any_entity_plane(p : @geometry.Plane) -> AnyEntity {
  AnyEntity::Plane(p)
}

///|
pub fn any_entity_vector(v : @geometry.Vector) -> AnyEntity {
  AnyEntity::Vector(v)
}

///|
pub fn any_entity_line(l : @geometry.Line) -> AnyEntity {
  AnyEntity::Line(l)
}

///|
pub fn any_entity_circle(c : @geometry.Circle) -> AnyEntity {
  AnyEntity::Circle(c)
}

///|
pub fn any_entity_ellipse(e : @geometry.Ellipse) -> AnyEntity {
  AnyEntity::Ellipse(e)
}

///|
pub fn any_entity_parabola(p : @geometry.Parabola) -> AnyEntity {
  AnyEntity::Parabola(p)
}

///|
pub fn any_entity_hyperbola(h : @geometry.Hyperbola) -> AnyEntity {
  AnyEntity::Hyperbola(h)
}

///|
pub fn any_entity_cylindrical_surface(
  s : @geometry.CylindricalSurface,
) -> AnyEntity {
  AnyEntity::CylindricalSurface(s)
}

///|
pub fn any_entity_conical_surface(s : @geometry.ConicalSurface) -> AnyEntity {
  AnyEntity::ConicalSurface(s)
}

///|
pub fn any_entity_toroidal_surface(s : @geometry.ToroidalSurface) -> AnyEntity {
  AnyEntity::ToroidalSurface(s)
}

///|
pub fn any_entity_b_spline_curve(c : @geometry.BSplineCurve) -> AnyEntity {
  AnyEntity::BSplineCurve(c)
}

///|
pub fn any_entity_b_spline_curve_with_knots(
  c : @geometry.BSplineCurveWithKnots,
) -> AnyEntity {
  AnyEntity::BSplineCurveWithKnots(c)
}

///|
pub fn any_entity_b_spline_surface(s : @geometry.BSplineSurface) -> AnyEntity {
  AnyEntity::BSplineSurface(s)
}

///|
pub fn any_entity_b_spline_surface_with_knots(
  s : @geometry.BSplineSurfaceWithKnots,
) -> AnyEntity {
  AnyEntity::BSplineSurfaceWithKnots(s)
}

///|
pub fn any_entity_rational_b_spline_curve(
  c : @geometry.RationalBSplineCurve,
) -> AnyEntity {
  AnyEntity::RationalBSplineCurve(c)
}

///|
pub fn any_entity_rational_b_spline_surface(
  s : @geometry.RationalBSplineSurface,
) -> AnyEntity {
  AnyEntity::RationalBSplineSurface(s)
}

///|
pub fn any_entity_trimmed_curve(c : @geometry.TrimmedCurve) -> AnyEntity {
  AnyEntity::TrimmedCurve(c)
}

///|
pub fn any_entity_offset_curve_3d(c : @geometry.OffsetCurve3D) -> AnyEntity {
  AnyEntity::OffsetCurve3D(c)
}

///|
pub fn any_entity_offset_surface(s : @geometry.OffsetSurface) -> AnyEntity {
  AnyEntity::OffsetSurface(s)
}

///|
pub fn any_entity_surface_of_linear_extrusion(
  s : @geometry.SurfaceOfLinearExtrusion,
) -> AnyEntity {
  AnyEntity::SurfaceOfLinearExtrusion(s)
}

///|
pub fn any_entity_surface_of_revolution(
  s : @geometry.SurfaceOfRevolution,
) -> AnyEntity {
  AnyEntity::SurfaceOfRevolution(s)
}

///|
pub fn any_entity_swept_surface(s : @geometry.SweptSurface) -> AnyEntity {
  AnyEntity::SweptSurface(s)
}

///|
pub fn any_entity_rectangular_trimmed_surface(
  s : @geometry.RectangularTrimmedSurface,
) -> AnyEntity {
  AnyEntity::RectangularTrimmedSurface(s)
}

///|
pub fn any_entity_polyline(p : @geometry.Polyline) -> AnyEntity {
  AnyEntity::Polyline(p)
}

///|
pub fn any_entity_boolean_result(b : @geometry.BooleanResult) -> AnyEntity {
  AnyEntity::BooleanResult(b)
}

///|
pub fn any_entity_csg_solid(c : @geometry.CsgSolid) -> AnyEntity {
  AnyEntity::CsgSolid(c)
}

///|
pub fn any_entity_block(b : @geometry.Block) -> AnyEntity {
  AnyEntity::Block(b)
}

///|
pub fn any_entity_sphere(s : @geometry.Sphere) -> AnyEntity {
  AnyEntity::Sphere(s)
}

///|
pub fn any_entity_right_circular_cylinder(
  c : @geometry.RightCircularCylinder,
) -> AnyEntity {
  AnyEntity::RightCircularCylinder(c)
}

///|
pub fn any_entity_right_circular_cone(
  c : @geometry.RightCircularCone,
) -> AnyEntity {
  AnyEntity::RightCircularCone(c)
}

///|
pub fn any_entity_torus(t : @geometry.Torus) -> AnyEntity {
  AnyEntity::Torus(t)
}

///|
pub fn any_entity_rectangular_pyramid(
  p : @geometry.RectangularPyramid,
) -> AnyEntity {
  AnyEntity::RectangularPyramid(p)
}

///|
pub fn any_entity_right_angular_wedge(
  w : @geometry.RightAngularWedge,
) -> AnyEntity {
  AnyEntity::RightAngularWedge(w)
}

///|
pub fn any_entity_half_space_solid(h : @geometry.HalfSpaceSolid) -> AnyEntity {
  AnyEntity::HalfSpaceSolid(h)
}

///|
pub fn any_entity_representation_relationship(
  r : @product.RepresentationRelationship,
) -> AnyEntity {
  AnyEntity::RepresentationRelationship(r)
}

///|
pub fn any_entity_representation_relationship_with_transformation(
  r : @product.RepresentationRelationshipWithTransformation,
) -> AnyEntity {
  AnyEntity::RepresentationRelationshipWithTransformation(r)
}

///|
pub fn any_entity_shape_representation_relationship(
  r : @product.ShapeRepresentationRelationship,
) -> AnyEntity {
  AnyEntity::ShapeRepresentationRelationship(r)
}

///|
pub fn any_entity_advanced_brep_shape_representation(
  r : @product.AdvancedBrepShapeRepresentation,
) -> AnyEntity {
  AnyEntity::AdvancedBrepShapeRepresentation(r)
}

///|
pub fn any_entity_shape_representation(
  r : @product.ShapeRepresentation,
) -> AnyEntity {
  AnyEntity::ShapeRepresentation(r)
}

///|
pub fn any_entity_representation(r : @product.Representation) -> AnyEntity {
  AnyEntity::Representation(r)
}

///|
pub fn any_entity_shape_definition_representation(
  r : @product.ShapeDefinitionRepresentation,
) -> AnyEntity {
  AnyEntity::ShapeDefinitionRepresentation(r)
}

///|
pub fn any_entity_descriptive_representation_item(
  d : @product.DescriptiveRepresentationItem,
) -> AnyEntity {
  AnyEntity::DescriptiveRepresentationItem(d)
}

///|
pub fn any_entity_measure_representation_item(
  m : @product.MeasureRepresentationItem,
) -> AnyEntity {
  AnyEntity::MeasureRepresentationItem(m)
}

///|
pub fn any_entity_context_dependent_shape_representation(
  c : @product.ContextDependentShapeRepresentation,
) -> AnyEntity {
  AnyEntity::ContextDependentShapeRepresentation(c)
}

///|
pub fn any_entity_item_defined_transformation(
  t : @product.ItemDefinedTransformation,
) -> AnyEntity {
  AnyEntity::ItemDefinedTransformation(t)
}

///|
pub fn any_entity_next_assembly_usage_occurrence(
  n : @product.NextAssemblyUsageOccurrence,
) -> AnyEntity {
  AnyEntity::NextAssemblyUsageOccurrence(n)
}

///|
pub fn any_entity_product_definition_shape(
  p : @product.ProductDefinitionShape,
) -> AnyEntity {
  AnyEntity::ProductDefinitionShape(p)
}

///|
pub fn any_entity_product_definition(
  p : @product.ProductDefinition,
) -> AnyEntity {
  AnyEntity::ProductDefinition(p)
}

///|
pub fn any_entity_product_definition_context(
  c : @product.ProductDefinitionContext,
) -> AnyEntity {
  AnyEntity::ProductDefinitionContext(c)
}

///|
pub fn any_entity_product_definition_formation(
  f : @product.ProductDefinitionFormation,
) -> AnyEntity {
  AnyEntity::ProductDefinitionFormation(f)
}

///|
pub fn any_entity_product_definition_formation_with_specified_source(
  f : @product.ProductDefinitionFormationWithSpecifiedSource,
) -> AnyEntity {
  AnyEntity::ProductDefinitionFormationWithSpecifiedSource(f)
}

///|
pub fn any_entity_property_definition(
  p : @product.PropertyDefinition,
) -> AnyEntity {
  AnyEntity::PropertyDefinition(p)
}

///|
pub fn any_entity_property_definition_representation(
  p : @product.PropertyDefinitionRepresentation,
) -> AnyEntity {
  AnyEntity::PropertyDefinitionRepresentation(p)
}

///|
pub fn any_entity_product_related_product_category(
  c : @product.ProductRelatedProductCategory,
) -> AnyEntity {
  AnyEntity::ProductRelatedProductCategory(c)
}

///|
pub fn any_entity_product(p : @product.Product) -> AnyEntity {
  AnyEntity::Product(p)
}

///|
pub fn any_entity_product_context(c : @product.ProductContext) -> AnyEntity {
  AnyEntity::ProductContext(c)
}

///|
pub fn any_entity_application_protocol_definition(
  a : @product.ApplicationProtocolDefinition,
) -> AnyEntity {
  AnyEntity::ApplicationProtocolDefinition(a)
}

///|
pub fn any_entity_application_context(
  a : @product.ApplicationContext,
) -> AnyEntity {
  AnyEntity::ApplicationContext(a)
}

///|
pub fn any_entity_manifold_solid_brep(
  m : @topology.ManifoldSolidBrep,
) -> AnyEntity {
  AnyEntity::ManifoldSolidBrep(m)
}

///|
pub fn any_entity_closed_shell(c : @topology.ClosedShell) -> AnyEntity {
  AnyEntity::ClosedShell(c)
}

///|
pub fn any_entity_open_shell(o : @topology.OpenShell) -> AnyEntity {
  AnyEntity::OpenShell(o)
}

///|
pub fn any_entity_shell_based_surface_model(
  s : @topology.ShellBasedSurfaceModel,
) -> AnyEntity {
  AnyEntity::ShellBasedSurfaceModel(s)
}

///|
pub fn any_entity_advanced_face(a : @topology.AdvancedFace) -> AnyEntity {
  AnyEntity::AdvancedFace(a)
}

///|
pub fn any_entity_face_surface(f : @topology.FaceSurface) -> AnyEntity {
  AnyEntity::FaceSurface(f)
}

///|
pub fn any_entity_subface(f : @topology.Subface) -> AnyEntity {
  AnyEntity::Subface(f)
}

///|
pub fn any_entity_face_outer_bound(b : @topology.FaceOuterBound) -> AnyEntity {
  AnyEntity::FaceOuterBound(b)
}

///|
pub fn any_entity_face_bound(b : @topology.FaceBound) -> AnyEntity {
  AnyEntity::FaceBound(b)
}

///|
pub fn any_entity_edge_loop(e : @topology.EdgeLoop) -> AnyEntity {
  AnyEntity::EdgeLoop(e)
}

///|
pub fn any_entity_oriented_edge(e : @topology.OrientedEdge) -> AnyEntity {
  AnyEntity::OrientedEdge(e)
}

///|
pub fn any_entity_edge_curve(e : @topology.EdgeCurve) -> AnyEntity {
  AnyEntity::EdgeCurve(e)
}

///|
pub fn any_entity_vertex_point(e : @topology.VertexPoint) -> AnyEntity {
  AnyEntity::VertexPoint(e)
}

///|
pub fn any_entity_color_rgb(c : @presentation.ColorRgb) -> AnyEntity {
  AnyEntity::ColorRgb(c)
}

///|
pub fn any_entity_fill_area_style_color(
  c : @presentation.FillAreaStyleColor,
) -> AnyEntity {
  AnyEntity::FillAreaStyleColor(c)
}

///|
pub fn any_entity_fill_area_style(s : @presentation.FillAreaStyle) -> AnyEntity {
  AnyEntity::FillAreaStyle(s)
}

///|
pub fn any_entity_surface_style_fill_area(
  s : @presentation.SurfaceStyleFillArea,
) -> AnyEntity {
  AnyEntity::SurfaceStyleFillArea(s)
}

///|
pub fn any_entity_surface_side_style(
  s : @presentation.SurfaceSideStyle,
) -> AnyEntity {
  AnyEntity::SurfaceSideStyle(s)
}

///|
pub fn any_entity_surface_style_usage(
  s : @presentation.SurfaceStyleUsage,
) -> AnyEntity {
  AnyEntity::SurfaceStyleUsage(s)
}

///|
pub fn any_entity_presentation_style_assignment(
  p : @presentation.PresentationStyleAssignment,
) -> AnyEntity {
  AnyEntity::PresentationStyleAssignment(p)
}

///|
pub fn any_entity_presentation_layer_assignment(
  p : @presentation.PresentationLayerAssignment,
) -> AnyEntity {
  AnyEntity::PresentationLayerAssignment(p)
}

///|
pub fn any_entity_mechanical_design_geometric_presentation_representation(
  r : @presentation.MechanicalDesignGeometricPresentationRepresentation,
) -> AnyEntity {
  AnyEntity::MechanicalDesignGeometricPresentationRepresentation(r)
}

///|
pub fn any_entity_styled_item(s : @presentation.StyledItem) -> AnyEntity {
  AnyEntity::StyledItem(s)
}

///|
pub fn any_entity_dimensional_exponents(
  d : @units.DimensionalExponents,
) -> AnyEntity {
  AnyEntity::DimensionalExponents(d)
}

///|
pub fn any_entity_uncertainty_measure_with_unit(
  u : @units.UncertaintyMeasureWithUnit,
) -> AnyEntity {
  AnyEntity::UncertaintyMeasureWithUnit(u)
}

///|
pub fn any_entity_plane_angle_measure_with_unit(
  p : @units.PlaneAngleMeasureWithUnit,
) -> AnyEntity {
  AnyEntity::PlaneAngleMeasureWithUnit(p)
}

///|
pub fn any_entity_derived_unit_element(
  d : @units.DerivedUnitElement,
) -> AnyEntity {
  AnyEntity::DerivedUnitElement(d)
}

///|
pub fn any_entity_derived_unit(d : @units.DerivedUnit) -> AnyEntity {
  AnyEntity::DerivedUnit(d)
}

///|
pub fn any_entity_ctx_wrap(c : @context.CtxWrap) -> AnyEntity {
  AnyEntity::CtxWrap(c)
}

///|
pub fn any_entity_complex_instance(c : @context.ComplexInstance) -> AnyEntity {
  AnyEntity::ComplexInstance(c)
}

///|
struct Entry {
  id : @step.EntityId
  entity : AnyEntity
}

///|
pub struct Repository {
  entities : Array[Entry]
  order : Array[@step.EntityId]
  mut header : @header.HeaderSection
  mut next_id : Int
}

///|
pub fn new() -> Repository {
  Repository::{
    entities: [],
    order: [],
    header: @header.HeaderSection::empty(),
    next_id: 1,
  }
}

///|
pub fn Repository::get_header(self : Repository) -> @header.HeaderSection {
  self.header
}

///|
pub fn Repository::set_header(
  self : Repository,
  header : @header.HeaderSection,
) -> Repository {
  let repo = self
  repo.header = header
  repo
}

///|
pub fn Repository::len(self : Repository) -> Int {
  self.order.length()
}

///|
pub fn Repository::get(self : Repository, id : @step.EntityId) -> AnyEntity? {
  for entry in self.entities {
    if entry.id.value == id.value {
      return Some(entry.entity)
    }
  }
  None
}

///|
pub fn Repository::add(
  self : Repository,
  entity : AnyEntity,
) -> (Repository, @step.EntityId) {
  let repo = self
  let id = @step.EntityId::{ value: repo.next_id }
  repo.next_id = repo.next_id + 1
  repo.entities.push(Entry::{ id, entity })
  repo.order.push(id)
  (repo, id)
}

///|
pub fn Repository::insert_with_id(
  self : Repository,
  id : @step.EntityId,
  entity : AnyEntity,
) -> Repository {
  let repo = self
  repo.entities.push(Entry::{ id, entity })
  repo.order.push(id)
  if id.value >= repo.next_id {
    repo.next_id = id.value + 1
  }
  repo
}

///|
fn entity_to_step(entity : AnyEntity) -> String {
  match entity {
    RawEntity(e) => @step.Entity::to_step(e)
    CartesianPoint(p) => @step.Entity::to_step(p)
    Direction(d) => @step.Entity::to_step(d)
    Axis1Placement(a) => @step.Entity::to_step(a)
    Axis2Placement3D(a) => @step.Entity::to_step(a)
    Plane(p) => @step.Entity::to_step(p)
    Vector(v) => @step.Entity::to_step(v)
    Line(l) => @step.Entity::to_step(l)
    Circle(c) => @step.Entity::to_step(c)
    Ellipse(e) => @step.Entity::to_step(e)
    Parabola(p) => @step.Entity::to_step(p)
    Hyperbola(h) => @step.Entity::to_step(h)
    CylindricalSurface(s) => @step.Entity::to_step(s)
    ConicalSurface(s) => @step.Entity::to_step(s)
    ToroidalSurface(s) => @step.Entity::to_step(s)
    BSplineCurve(c) => @step.Entity::to_step(c)
    BSplineCurveWithKnots(c) => @step.Entity::to_step(c)
    BSplineSurface(s) => @step.Entity::to_step(s)
    BSplineSurfaceWithKnots(s) => @step.Entity::to_step(s)
    RationalBSplineCurve(c) => @step.Entity::to_step(c)
    RationalBSplineSurface(s) => @step.Entity::to_step(s)
    TrimmedCurve(c) => @step.Entity::to_step(c)
    OffsetCurve3D(c) => @step.Entity::to_step(c)
    OffsetSurface(s) => @step.Entity::to_step(s)
    SurfaceOfLinearExtrusion(s) => @step.Entity::to_step(s)
    SurfaceOfRevolution(s) => @step.Entity::to_step(s)
    SweptSurface(s) => @step.Entity::to_step(s)
    RectangularTrimmedSurface(s) => @step.Entity::to_step(s)
    Polyline(p) => @step.Entity::to_step(p)
    BooleanResult(b) => @step.Entity::to_step(b)
    CsgSolid(c) => @step.Entity::to_step(c)
    Block(b) => @step.Entity::to_step(b)
    Sphere(s) => @step.Entity::to_step(s)
    RightCircularCylinder(c) => @step.Entity::to_step(c)
    RightCircularCone(c) => @step.Entity::to_step(c)
    Torus(t) => @step.Entity::to_step(t)
    RectangularPyramid(p) => @step.Entity::to_step(p)
    RightAngularWedge(w) => @step.Entity::to_step(w)
    HalfSpaceSolid(h) => @step.Entity::to_step(h)
    RepresentationRelationship(r) => @step.Entity::to_step(r)
    RepresentationRelationshipWithTransformation(r) => @step.Entity::to_step(r)
    ShapeRepresentationRelationship(r) => @step.Entity::to_step(r)
    AdvancedBrepShapeRepresentation(r) => @step.Entity::to_step(r)
    ShapeRepresentation(r) => @step.Entity::to_step(r)
    Representation(r) => @step.Entity::to_step(r)
    ShapeDefinitionRepresentation(r) => @step.Entity::to_step(r)
    DescriptiveRepresentationItem(d) => @step.Entity::to_step(d)
    MeasureRepresentationItem(m) => @step.Entity::to_step(m)
    ContextDependentShapeRepresentation(c) => @step.Entity::to_step(c)
    ItemDefinedTransformation(t) => @step.Entity::to_step(t)
    NextAssemblyUsageOccurrence(n) => @step.Entity::to_step(n)
    ProductDefinitionShape(p) => @step.Entity::to_step(p)
    ProductDefinition(p) => @step.Entity::to_step(p)
    ProductDefinitionContext(c) => @step.Entity::to_step(c)
    ProductDefinitionFormation(f) => @step.Entity::to_step(f)
    ProductDefinitionFormationWithSpecifiedSource(f) => @step.Entity::to_step(f)
    PropertyDefinition(p) => @step.Entity::to_step(p)
    PropertyDefinitionRepresentation(p) => @step.Entity::to_step(p)
    ProductRelatedProductCategory(c) => @step.Entity::to_step(c)
    Product(p) => @step.Entity::to_step(p)
    ProductContext(c) => @step.Entity::to_step(c)
    ApplicationProtocolDefinition(a) => @step.Entity::to_step(a)
    ApplicationContext(a) => @step.Entity::to_step(a)
    ManifoldSolidBrep(m) => @step.Entity::to_step(m)
    ClosedShell(c) => @step.Entity::to_step(c)
    OpenShell(o) => @step.Entity::to_step(o)
    ShellBasedSurfaceModel(s) => @step.Entity::to_step(s)
    AdvancedFace(a) => @step.Entity::to_step(a)
    FaceSurface(f) => @step.Entity::to_step(f)
    Subface(f) => @step.Entity::to_step(f)
    FaceOuterBound(b) => @step.Entity::to_step(b)
    FaceBound(b) => @step.Entity::to_step(b)
    EdgeLoop(e) => @step.Entity::to_step(e)
    OrientedEdge(e) => @step.Entity::to_step(e)
    EdgeCurve(e) => @step.Entity::to_step(e)
    VertexPoint(e) => @step.Entity::to_step(e)
    ColorRgb(c) => @step.Entity::to_step(c)
    FillAreaStyleColor(c) => @step.Entity::to_step(c)
    FillAreaStyle(s) => @step.Entity::to_step(s)
    SurfaceStyleFillArea(s) => @step.Entity::to_step(s)
    SurfaceSideStyle(s) => @step.Entity::to_step(s)
    SurfaceStyleUsage(s) => @step.Entity::to_step(s)
    PresentationStyleAssignment(p) => @step.Entity::to_step(p)
    PresentationLayerAssignment(p) => @step.Entity::to_step(p)
    MechanicalDesignGeometricPresentationRepresentation(r) =>
      @step.Entity::to_step(r)
    StyledItem(s) => @step.Entity::to_step(s)
    DimensionalExponents(d) => @step.Entity::to_step(d)
    UncertaintyMeasureWithUnit(u) => @step.Entity::to_step(u)
    PlaneAngleMeasureWithUnit(p) => @step.Entity::to_step(p)
    DerivedUnitElement(d) => @step.Entity::to_step(d)
    DerivedUnit(d) => @step.Entity::to_step(d)
    CtxWrap(c) => @step.Entity::to_step(c)
    ComplexInstance(c) => @step.Entity::to_step(c)
  }
}

///|
// Minimal serializer for now (DATA section only).
pub fn Repository::to_step_data_section(self : Repository) -> String {
  let lines : Array[String] = []
  for entry in self.entities {
    lines.push("#\{entry.id.value}=\{entity_to_step(entry.entity)};")
  }
  lines.join("\n")
}

///|
// Serialize a full ISO-10303-21 STEP file.
//
// - Always emits ISO-10303-21 wrapper lines.
// - Emits HEADER section using the repository's stored header.
// - Emits DATA section from the repository entities.
pub fn Repository::to_step_file(self : Repository) -> String {
  let header_section = self.header.to_step_header_section()
  let data_section = self.to_step_data_section()
  let out = if data_section.length() == 0 {
    "ISO-10303-21;\n\{header_section}\nDATA;\nENDSEC;\nEND-ISO-10303-21;"
  } else {
    "ISO-10303-21;\n\{header_section}\nDATA;\n\{data_section}\nENDSEC;\nEND-ISO-10303-21;"
  }
  // Normalize Windows CRLF (or stray CR) so output is stable/idempotent.
  let builder = StringBuilder::new()
  for c in out {
    if c != '\r' {
      builder.write_char(c)
    }
  }
  builder.to_string()
}
