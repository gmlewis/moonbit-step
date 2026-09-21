///|
// Explicit trait-method promotion declarations.
//
// MoonBit no longer promotes a trait's methods to direct methods on a type
// implicitly: every promoted method needs an explicit `extend` declaration,
// otherwise moonc warns (implicit_impl_as_method). `Entity::to_step` is this
// package's public API, so it is promoted plainly.

///|
pub extend Axis1Placement with @step.Entity::{to_step}

///|
pub extend Axis2Placement2D with @step.Entity::{to_step}

///|
pub extend Axis2Placement3D with @step.Entity::{to_step}

///|
pub extend Block with @step.Entity::{to_step}

///|
pub extend BooleanOperator with @step.Entity::{to_step}

///|
pub extend BooleanResult with @step.Entity::{to_step}

///|
pub extend BSplineCurve with @step.Entity::{to_step}

///|
pub extend BSplineCurveWithKnots with @step.Entity::{to_step}

///|
pub extend BSplineSurface with @step.Entity::{to_step}

///|
pub extend BSplineSurfaceWithKnots with @step.Entity::{to_step}

///|
pub extend CartesianPoint with @step.Entity::{to_step}

///|
pub extend Circle with @step.Entity::{to_step}

///|
pub extend TransitionCode with @step.Entity::{to_step}

///|
pub extend CompositeCurveSegment with @step.Entity::{to_step}

///|
pub extend CompositeCurve with @step.Entity::{to_step}

///|
pub extend ConicalSurface with @step.Entity::{to_step}

///|
pub extend CsgSolid with @step.Entity::{to_step}

///|
pub extend CylindricalSurface with @step.Entity::{to_step}

///|
pub extend Direction with @step.Entity::{to_step}

///|
pub extend Ellipse with @step.Entity::{to_step}

///|
pub extend HalfSpaceSolid with @step.Entity::{to_step}

///|
pub extend Hyperbola with @step.Entity::{to_step}

///|
pub extend Line with @step.Entity::{to_step}

///|
pub extend OffsetCurve3D with @step.Entity::{to_step}

///|
pub extend OffsetSurface with @step.Entity::{to_step}

///|
pub extend Parabola with @step.Entity::{to_step}

///|
pub extend Plane with @step.Entity::{to_step}

///|
pub extend Polyline with @step.Entity::{to_step}

///|
pub extend RationalBSplineCurve with @step.Entity::{to_step}

///|
pub extend RationalBSplineSurface with @step.Entity::{to_step}

///|
pub extend RectangularTrimmedSurface with @step.Entity::{to_step}

///|
pub extend RectangularPyramid with @step.Entity::{to_step}

///|
pub extend RightAngularWedge with @step.Entity::{to_step}

///|
pub extend RightCircularCone with @step.Entity::{to_step}

///|
pub extend RightCircularCylinder with @step.Entity::{to_step}

///|
pub extend Sphere with @step.Entity::{to_step}

///|
pub extend SurfaceOfLinearExtrusion with @step.Entity::{to_step}

///|
pub extend SurfaceOfRevolution with @step.Entity::{to_step}

///|
pub extend SweptSurface with @step.Entity::{to_step}

///|
pub extend ToroidalSurface with @step.Entity::{to_step}

///|
pub extend Torus with @step.Entity::{to_step}

///|
pub extend TrimmedCurve with @step.Entity::{to_step}

///|
pub extend Vector with @step.Entity::{to_step}
