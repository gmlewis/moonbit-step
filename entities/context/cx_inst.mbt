///|
// Represents a STEP Part 21 complex entity instance: #<id>=( <part1> <part2> ... );
//
// We parse the wrapper into a sequence of parts, each like `NAME(<args>)`, and
// serialize back to the parenthesized multi-line form.

///|
pub(all) enum ComplexPart {
  GeomRepCtx(GeometricRepresentationContext)
  RepCtx(RepresentationContext)
  GlobUncCtx(GlobalUncertaintyAssignedContext)
  GlobUnitCtx(GlobalUnitAssignedContext)
  ConversionBasedUnit(@units.ConversionBasedUnit)
  NamedUnit(@units.NamedUnit)
  SiUnit(@units.SiUnit)
  LengthUnit(@units.LengthUnit)
  MassUnit(@units.MassUnit)
  PlaneAngleUnit(@units.PlaneAngleUnit)
  SolidAngleUnit(@units.SolidAngleUnit)
  RepRel(@product.RepresentationRelationship)
  RepRelWT(@product.RepresentationRelationshipWithTransformation)
  ShapeRepRel
  RepresentationItem(String)
  GeometricRepresentationItem
  Surface
  BoundedSurface
  RatBSpline(@geometry.RationalBSplineCurve)
  BSplineSurf(@geometry.BSplineSurface)
  BSplineSurfKnots(@geometry.BSplineSurfaceWithKnots)
  RatBSplineSurf(@geometry.RationalBSplineSurface)
  Raw(String, String)
}

///|
pub struct ComplexInstance {
  parts : Array[ComplexPart]
}

///|
pub fn ComplexInstance::new(parts : Array[ComplexPart]) -> ComplexInstance {
  ComplexInstance::{ parts, }
}

///|
pub impl @step.Entity for ComplexInstance with to_step(self) {
  let lines = self.parts
    .map(fn(p) {
      match p {
        GeomRepCtx(e) => @step.Entity::to_step(e)
        RepCtx(e) => @step.Entity::to_step(e)
        GlobUncCtx(e) => @step.Entity::to_step(e)
        GlobUnitCtx(e) => @step.Entity::to_step(e)
        ConversionBasedUnit(e) => @step.Entity::to_step(e)
        NamedUnit(e) => @step.Entity::to_step(e)
        SiUnit(e) => @step.Entity::to_step(e)
        LengthUnit(e) => @step.Entity::to_step(e)
        MassUnit(e) => @step.Entity::to_step(e)
        PlaneAngleUnit(e) => @step.Entity::to_step(e)
        SolidAngleUnit(e) => @step.Entity::to_step(e)
        RepRel(e) => @step.Entity::to_step(e)
        RepRelWT(e) => @step.Entity::to_step(e)
        ShapeRepRel => "SHAPE_REPRESENTATION_RELATIONSHIP()"
        RepresentationItem(arg) => "REPRESENTATION_ITEM(\{arg})"
        GeometricRepresentationItem => "GEOMETRIC_REPRESENTATION_ITEM()"
        Surface => "SURFACE()"
        BoundedSurface => "BOUNDED_SURFACE()"
        RatBSpline(e) => @step.Entity::to_step(e)
        BSplineSurf(e) => @step.Entity::to_step(e)
        BSplineSurfKnots(e) => @step.Entity::to_step(e)
        RatBSplineSurf(e) => @step.Entity::to_step(e)
        Raw(name, args) => "\{name}\{args}"
      }
    })
    .join("\n")
  "(\n\{lines}\n)"
}
