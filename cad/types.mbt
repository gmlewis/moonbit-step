///|
pub type Vec2 = (Double, Double)

///|
pub type Vec3 = (Double, Double, Double)

///|
#derive(Debug)
pub struct Rgb {
  r : Double
  g : Double
  b : Double
}

///|
pub fn Rgb::new(r : Double, g : Double, b : Double) -> Rgb {
  { r, g, b, }
}

///|
/// Rgb::channels returns the red, green, and blue components, each in 0..1.
pub fn Rgb::channels(self : Rgb) -> (Double, Double, Double) {
  (self.r, self.g, self.b)
}

///|
pub fn Rgb::orange() -> Rgb {
  { r: 1.0, g: 0.6, b: 0.0, }
}

///|
pub fn Rgb::blue() -> Rgb {
  { r: 0.2, g: 0.6, b: 1.0, }
}

///|
pub fn Rgb::grey() -> Rgb {
  { r: 0.2, g: 0.2, b: 0.2, }
}

///|
pub fn Rgb::purple() -> Rgb {
  { r: 0.5, g: 0.0, b: 0.5, }
}

///|
pub fn Rgb::magenta() -> Rgb {
  { r: 1.0, g: 0.0, b: 1.0, }
}

///|
pub fn Rgb::white() -> Rgb {
  { r: 1.0, g: 1.0, b: 1.0, }
}

///|
pub fn Rgb::black() -> Rgb {
  { r: 0.0, g: 0.0, b: 0.0, }
}

///|
pub fn Rgb::green() -> Rgb {
  { r: 0.0, g: 0.8, b: 0.0, }
}

///|
pub fn Rgb::red() -> Rgb {
  { r: 0.8, g: 0.0, b: 0.0, }
}

///|
pub fn Rgb::cyan() -> Rgb {
  { r: 0.0, g: 0.8, b: 0.8, }
}

///|
pub struct Profile2D {
  outer : Array[(Double, Double)]
  holes : Array[Array[(Double, Double)]]
}

///|
pub struct Cuboid {
  sx : Double
  sy : Double
  sz : Double
}

///|
/// Cylinder is a solid right circular cylinder whose base lies on the local
/// Z = 0 plane and whose axis follows +Z through the origin.
pub struct Cylinder {
  diameter : Double
  height : Double
}

///|
pub struct CalibrationChamferBlock {
  length_mm : Double
  width_mm : Double
  height_mm : Double
  chamfer_size_mm : Double
  fillet_radius_mm : Double
  fillet_segments : Int32
}

///|
pub struct ExtrudedProfile {
  profile : Profile2D
  height_mm : Double
  /// Optional analytic circular through-bore `(center, diameter)`. It compiles
  /// to a real `CYLINDRICAL_SURFACE` with `CIRCLE` bounds, so a gear bore is
  /// never a sampled polygon. Only one round bore is supported; polygonal holes
  /// in `profile.holes` remain available for other features.
  round_bore : (Vec2, Double)?
}

///|
/// ProfileSegment is one boundary segment of a planar profile: a straight line
/// or a counter-clockwise minor circular arc (sweep at most 180 degrees).
pub(all) enum ProfileSegment {
  SegmentLine(Vec2, Vec2)
  SegmentArc(Vec2, Vec2, Vec2)
}

///|
/// ExtrudedArcProfile is an extruded closed profile whose boundary contains
/// circular arcs, so a genuinely circular side becomes an analytic
/// `CYLINDRICAL_SURFACE` instead of a polygon of planar facets.
///
/// `segments` is one closed counter-clockwise outer loop. `round_bore` is an
/// optional analytic circular through-bore. This is the representation for a
/// keyed shaft (a circular body with a real keyway notch) and for other
/// line-plus-arc sections.
pub struct ExtrudedArcProfile {
  segments : Array[ProfileSegment]
  height_mm : Double
  round_bore : (Vec2, Double)?
  /// Closed counter-clockwise inner loops of lines and minor arcs, each a
  /// through-hole with analytic cylindrical faces on its arcs.
  holes : Array[Array[ProfileSegment]]
}

///|
pub struct SweptProfile {
  path : SweepPath
  profile : SweepProfile
  make_start_cap : Bool
  make_end_cap : Bool
  straight_holes : Bool
  straight_outline : Bool
  /// Emit a smooth helical B-rep for a rectangular profile on a helical path:
  /// four B-spline side surfaces and two planar caps (six faces). The mesh,
  /// section, and mass-property analysis keep using the sampled path.
  smooth_helix : Bool
  /// Emit a smooth B-rep for an arbitrary (polygonal) profile: one ruled
  /// B-spline side surface per profile edge (degree 1 across the edge, cubic
  /// along the path) and planar start/end caps. The mesh, section, and
  /// mass-property analysis keep using the sampled path.
  smooth_sides : Bool
  /// Path point indices where a `smooth_sides` sweep must stay sharp. The
  /// vertex curves use the one-sided chord tangent there instead of the
  /// averaged central tangent, which keeps a piecewise-linear elbow a sharp
  /// crease instead of rounding it into a wave.
  sharp_creases : Array[Int32]
  /// Optional start/end corner positions (inner-top, inner-bottom, outer-top,
  /// outer-bottom) that override the sampled corner endpoints. The corner
  /// curves are blended to meet them, which reproduces a reference's split-cap
  /// vertices while keeping smooth B-spline sides.
  corner_override : (Array[Vec3], Array[Vec3])?
}

///|
pub struct BooleanUnion {
  nodes : Array[SceneNode]
}

///|
pub struct BooleanDifference {
  base : SceneNode
  cutters : Array[SceneNode]
}

///|
/// BezierAnchor represents a single anchor point in a Bezier curve.
/// The handles are absolute positions (not relative offsets).
pub struct BezierAnchor {
  position : Vec2
  handle_in : Vec2 // Absolute position of incoming handle
  handle_out : Vec2 // Absolute position of outgoing handle
}

///|
/// BezierPath represents a 2D path made of cubic Bezier curves.
pub struct BezierPath {
  anchors : Array[BezierAnchor]
  closed : Bool
  clear : Bool // True for holes (cut-outs)
}

///|
/// ExtrudedBezierProfile represents an extruded shape from Bezier paths.
pub struct ExtrudedBezierProfile {
  paths : Array[BezierPath] // First non-clear path is outer, clear paths are holes
  height_mm : Double
}

///|
/// EdgeSelector chooses which edges of a base solid an edge fillet or chamfer
/// applies to.
///
/// The selector is intent, not geometry: the flat STEP writer cannot evaluate
/// it. Only the optional OCCT-backed evaluated export (`Design::to_step_evaluated`)
/// or the Blender backend can apply the operation. Selectors are evaluated
/// against the base solid's straight/curved edge bounds:
///
/// - `AllEdges` selects every edge.
/// - `EdgesByDirection` selects edges whose bounding-box diagonal is parallel
///   to `dir` within `tolerance_deg`.
/// - `EdgesNearPoint` selects edges whose bounding box is within `radius_mm`
///   of `point`.
/// - `EdgeIndices` selects 1-based edge indices in the solid's edge order.
pub(all) enum EdgeSelector {
  AllEdges
  EdgesByDirection(Vec3, Double)
  EdgesNearPoint(Vec3, Double)
  EdgeIndices(Array[Int32])
}

///|
/// EdgeFeature is the intent to fillet or chamfer the selected edges of a base
/// solid.
///
/// `size_mm` is the fillet radius or chamfer distance. `angle_deg` is an
/// optional chamfer angle; `None` means an equal-distance chamfer.
pub(all) struct EdgeFeature {
  base : SceneNode
  selector : EdgeSelector
  size_mm : Double
  angle_deg : Double?
}

///|
/// SocketedSolid is a solid of revolution with a blind vertical hexagonal
/// pocket cut into its flat top face.
///
/// `body` is a closed `RevolvedProfile` whose final segment is the radial flat
/// top cap from `(top_radius, top_z)` to `(0, top_z)`. The compiler suppresses
/// that cap and replaces it with a true single-shell pocket boundary: an
/// annular planar top face, six planar socket walls, an optional ruled 45-degree
/// lead-in, and a planar hexagonal floor. The result is one closed solid, not a
/// stack of layered bodies, and every surface stays analytic (no polygon
/// substitutes for the body's cylinders, cones, spheres, or tori).
///
/// The socket mouth lies on the body's flat top, so `top_radius` must exceed the
/// socket circumradius. `lead_in_mm` is a parallel 45-degree break on the six
/// socket flats; it is a ruled approximation of the conical rim and is recorded
/// as such by the caller.
pub struct SocketedSolid {
  body : RevolvedProfile
  across_flats_mm : Double
  socket_floor_z_mm : Double
  lead_in_mm : Double
  rotation_deg : Double
  /// When true the socket rim and floor are true cones (`rim_angle_deg`,
  /// `floor_angle_deg`) trimmed by the hexagon flats, and
  /// `socket_floor_z_mm` is the drill-point apex rather than a flat floor.
  conical : Bool
  rim_angle_deg : Double
  floor_angle_deg : Double
}

///|
/// SquareHoleWasher is a plain circular washer with a centered square through
/// hole. The outer surface is one analytic cylinder; the hole walls are four
/// planes and the two end faces are planes with a square hole.
pub struct SquareHoleWasher {
  outer_diameter_mm : Double
  square_side_mm : Double
  thickness_mm : Double
}

///|
/// SquareHoleWasher::new builds a square-hole washer intent.
pub fn SquareHoleWasher::new(
  outer_diameter_mm~ : Double,
  square_side_mm~ : Double,
  thickness_mm~ : Double,
) -> SquareHoleWasher {
  { outer_diameter_mm, square_side_mm, thickness_mm, }
}

///|
/// SquareHoleWasher::as_shape wraps the washer as a Shape.
pub fn SquareHoleWasher::as_shape(self : SquareHoleWasher) -> Shape {
  Shape::SquareHoleWasher(self)
}

///|
/// TabWasher is a plain circular washer with a rectangular external tab. The
/// tab blends into the washer with two concave analytic cylinders; the bore is
/// a cylinder and the tab sides/end and the two faces are planes.
pub struct TabWasher {
  outer_diameter_mm : Double
  bore_diameter_mm : Double
  tab_width_mm : Double
  tab_length_mm : Double
  fillet_radius_mm : Double
  thickness_mm : Double
}

///|
/// TabWasher::new builds a tab-washer intent.
pub fn TabWasher::new(
  outer_diameter_mm~ : Double,
  bore_diameter_mm~ : Double,
  tab_width_mm~ : Double,
  tab_length_mm~ : Double,
  fillet_radius_mm~ : Double,
  thickness_mm~ : Double,
) -> TabWasher {
  {
    outer_diameter_mm,
    bore_diameter_mm,
    tab_width_mm,
    tab_length_mm,
    fillet_radius_mm,
    thickness_mm,
  }
}

///|
/// TabWasher::as_shape wraps the tab washer as a Shape.
pub fn TabWasher::as_shape(self : TabWasher) -> Shape {
  Shape::TabWasher(self)
}

///|
/// HexHeadWasherFace is a hexagon head trimmed by a conical washer face: the
/// top is a circle of radius `across_flats / 2`, the chamfer is a 75-degree
/// cone, and the flat/cone intersections are hyperbolas.
pub struct HexHeadWasherFace {
  across_flats_mm : Double
  head_height_mm : Double
  /// Conical washer-face semi-angle (75 degrees for the simple hex heads, 65
  /// for the detailed ISO 4017 references).
  face_angle_deg : Double
  /// Optional shank below the head. `shank_diameter_mm <= 0` keeps the
  /// head-only solid. When positive the head, under-head washer face and shank
  /// are emitted as one closed shell.
  shank_diameter_mm : Double
  shank_length_mm : Double
  /// Optional under-head washer face `(diameter, height)`. Diameter 0 uses the
  /// full hexagon underside.
  washer_face_diameter_mm : Double
  washer_face_height_mm : Double
  tip_chamfer_mm : Double
}

///|
/// HexHeadWasherFace::new builds a conical-washer-face hex head.
pub fn HexHeadWasherFace::new(
  across_flats_mm~ : Double,
  head_height_mm~ : Double,
  face_angle_deg~ : Double = 75.0,
  shank_diameter_mm~ : Double = 0.0,
  shank_length_mm~ : Double = 0.0,
  washer_face_diameter_mm~ : Double = 0.0,
  washer_face_height_mm~ : Double = 0.0,
  tip_chamfer_mm~ : Double = 0.0,
) -> HexHeadWasherFace {
  {
    across_flats_mm,
    head_height_mm,
    face_angle_deg,
    shank_diameter_mm,
    shank_length_mm,
    washer_face_diameter_mm,
    washer_face_height_mm,
    tip_chamfer_mm,
  }
}

///|
/// HexHeadWasherFace::as_shape wraps the head as a Shape.
pub fn HexHeadWasherFace::as_shape(self : HexHeadWasherFace) -> Shape {
  Shape::HexHeadWasherFace(self)
}

///|

///|
/// ConicalNut is a hexagon nut with a 75/60-degree conical washer face on each
/// bearing face and a circular through bore. The face chamfer is a true
/// `CONICAL_SURFACE` trimmed by the six flats (hyperbola edges with pcurves),
/// not a parallel-inset ring stack.
pub struct ConicalNut {
  across_flats_mm : Double
  height_mm : Double
  bore_diameter_mm : Double
  face_angle_deg : Double
  /// 45-degree bore lead-in depth at each face; 0 for a straight bore.
  lead_in_mm : Double
  /// Corner clocking in degrees (vertices at rotation + 60 i; flats at
  /// rotation + 30 + 60 i).
  rotation_deg : Double
}

///|
/// SlitTube is a straight tube with a full-length parallel-sided slot cut
/// through one side (an ISO 8752 slotted spring pin). The outer and inner
/// surfaces are analytic cylinders, the slot walls are planes, and the two end
/// faces are C-shaped planes. The slot is centred on +X with parallel walls at
/// `y = +/- slot_width/2`.
pub struct SlitTube {
  outer_diameter_mm : Double
  inner_diameter_mm : Double
  length_mm : Double
  slot_width_mm : Double
}

///|
/// AcornNut is a DIN 1587 hexagon domed cap nut: the ISO 4032/DIN 934 hexagon
/// body with conical washer faces on both ends, a through bore, and a domed
/// cap. The cap is a spherical cap that starts at the hexagon top rim and
/// reaches `total_height_mm`; inside it, a concentric spherical cavity leaves
/// `wall_mm` of cap wall above the bore.
pub struct AcornNut {
  across_flats_mm : Double
  /// Height of the hexagon body (DIN 1587 `m`), excluding the dome.
  body_height_mm : Double
  bore_diameter_mm : Double
  /// Overall height including the dome (DIN 1587 `h`).
  total_height_mm : Double
  /// Diameter of the dome where it meets the hexagon top (DIN 1587 `dk`).
  dome_diameter_mm : Double
  /// Radial thickness of the domed cap above the bore.
  wall_mm : Double
  face_angle_deg : Double
  /// Corner clocking in degrees (vertices at rotation + 60 i; flats at
  /// rotation + 30 + 60 i).
  rotation_deg : Double
}

///|
/// SquareNut is a DIN 557 square nut: a square prism with a conical washer
/// face on the top bearing face and a circular through bore. The bottom face
/// is flat, as DIN 557 specifies a chamfer on one face only.
pub struct SquareNut {
  across_flats_mm : Double
  height_mm : Double
  bore_diameter_mm : Double
  face_angle_deg : Double
  /// Corner clocking in degrees (vertices at rotation + 90 i; flats at
  /// rotation + 45 + 90 i).
  rotation_deg : Double
}

///|
pub enum Shape {
  Cuboid(Cuboid)
  Cylinder(Cylinder)
  RevolvedProfile(RevolvedProfile)
  ChamferedPrism(ChamferedPrism)
  SocketedSolid(SocketedSolid)
  ConicalNut(ConicalNut)
  SlitTube(SlitTube)
  AcornNut(AcornNut)
  SquareNut(SquareNut)
  CalibrationChamferBlock(CalibrationChamferBlock)
  ExtrudedProfile(ExtrudedProfile)
  ExtrudedArcProfile(ExtrudedArcProfile)
  SquareHoleWasher(SquareHoleWasher)
  TabWasher(TabWasher)
  HexHeadWasherFace(HexHeadWasherFace)
  ExtrudedBezierProfile(ExtrudedBezierProfile)
  SweptProfile(SweptProfile)
  Fillet(EdgeFeature)
  Chamfer(EdgeFeature)
  Union(BooleanUnion)
  Difference(BooleanDifference)
}

///|
pub struct SceneNode {
  shape : Shape
  name : String
  color : Rgb
  tx : Double
  ty : Double
  tz : Double
  rx : Double // rotation X in degrees
  ry : Double // rotation Y in degrees
  rz : Double // rotation Z in degrees
}

///|
pub(all) enum Face {
  Top
  Bottom
  Front
  Back
  Left
  Right
}

///|
/// SweepPath represents the information needed to sweep a profile along a path.
pub(all) struct SweepPath {
  points : Array[Vec3]
  normals : Array[Vec3]
  tangents : Array[Vec3]
}

///|
/// SweepProfile represents a 2D profile to be swept along a path.
///
/// `vertices` is the outer boundary of the profile; `holes` holds optional
/// inner boundaries (e.g. the bore of a ring gear). All loops are given in the
/// same coordinate system as `vertices`. Loops must be wound so that the outer
/// boundary and every hole have opposite orientation; with the default
/// `normal_dir`/`right_dir` the swept side faces then point out of the solid.
pub(all) struct SweepProfile {
  center : Vec3
  vertices : Array[Vec3]
  holes : Array[Array[Vec3]]
  // normal_dir points in the direction of extrusion
  normal_dir : Vec3
  // right_dir points to the "right" side of the profile when looking along normal_dir
  right_dir : Vec3
}

///|
/// SweepProfile::new returns a new SweepProfile.
pub fn SweepProfile::new(
  vertices : Array[Vec3],
  center~ : Vec3 = (0.0, 0.0, 0.0),
  holes~ : Array[Array[Vec3]] = [],
  normal_dir~ : Vec3 = (0.0, 1.0, 0.0),
  right_dir~ : Vec3 = (1.0, 0.0, 0.0),
) -> SweepProfile {
  { center, vertices, holes, normal_dir, right_dir, }
}

///|
pub fn Shape::bounding_box(
  self : Shape,
) -> (Double, Double, Double, Double, Double, Double) {
  match self {
    Cuboid(c) => (0.0, c.sx, 0.0, c.sy, 0.0, c.sz)
    Cylinder(c) => {
      let r = c.diameter / 2.0
      (-r, r, -r, r, 0.0, c.height)
    }
    RevolvedProfile(rev) => {
      let samples : Array[Vec2] = []
      for seg in rev.segments {
        match seg {
          RevLine(a, b) => {
            samples.push(a)
            samples.push(b)
          }
          RevArc(a, b, c) => {
            // Sample the arc so its extreme radius and height are captured.
            let rho = rev_dist2(a, c)
            let a0 = @math.atan2(a.1 - c.1, a.0 - c.0)
            let a1 = @math.atan2(b.1 - c.1, b.0 - c.0)
            let delta = rev_norm_angle(a1 - a0)
            let count = 64
            for i in 0..<=count {
              let t = Double::from_int(i) / Double::from_int(count)
              let ang = a0 + delta * t
              samples.push(
                (c.0 + rho * @math.cos(ang), c.1 + rho * @math.sin(ang)),
              )
            }
          }
        }
      }
      let mut r_max = 0.0
      let mut z0 = @double.max_value
      let mut z1 = @double.min_value
      for p in samples {
        if p.0 > r_max {
          r_max = p.0
        }
        if p.1 < z0 {
          z0 = p.1
        }
        if p.1 > z1 {
          z1 = p.1
        }
      }
      if r_max <= 0.0 {
        (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
      } else {
        (-r_max, r_max, -r_max, r_max, z0, z1)
      }
    }
    ChamferedPrism(p) => {
      let mut x0 = @double.max_value
      let mut x1 = @double.min_value
      let mut y0 = @double.max_value
      let mut y1 = @double.min_value
      let mut z0 = @double.max_value
      let mut z1 = @double.min_value
      for level in p.levels {
        let (z, inset) = level
        let ring = match chamfer_inset(p.base, inset) {
          Some(r) => r
          None => p.base
        }
        for pt in ring {
          if pt.0 < x0 {
            x0 = pt.0
          }
          if pt.0 > x1 {
            x1 = pt.0
          }
          if pt.1 < y0 {
            y0 = pt.1
          }
          if pt.1 > y1 {
            y1 = pt.1
          }
        }
        if z < z0 {
          z0 = z
        }
        if z > z1 {
          z1 = z
        }
      }
      (x0, x1, y0, y1, z0, z1)
    }
    SocketedSolid(s) => Shape::RevolvedProfile(s.body).bounding_box()
    ConicalNut(n) => conical_nut_bounding_box(n)
    SlitTube(t) => {
      let r = t.outer_diameter_mm / 2.0
      (-r, r, -r, r, 0.0, t.length_mm)
    }
    AcornNut(n) => acorn_nut_bounding_box(n)
    SquareNut(n) => square_nut_bounding_box(n)
    CalibrationChamferBlock(b) =>
      (0.0, b.length_mm, 0.0, b.width_mm, 0.0, b.height_mm)
    ExtrudedProfile(e) => {
      let mut x0 = @double.max_value
      let mut x1 = @double.min_value
      let mut y0 = @double.max_value
      let mut y1 = @double.min_value
      for pt in e.profile.outer {
        if pt.0 < x0 {
          x0 = pt.0
        }
        if pt.0 > x1 {
          x1 = pt.0
        }
        if pt.1 < y0 {
          y0 = pt.1
        }
        if pt.1 > y1 {
          y1 = pt.1
        }
      }
      (x0, x1, y0, y1, 0.0, e.height_mm)
    }
    ExtrudedArcProfile(e) => {
      let mut x0 = @double.max_value
      let mut x1 = @double.min_value
      let mut y0 = @double.max_value
      let mut y1 = @double.min_value
      for seg in e.segments {
        match seg {
          SegmentLine(a, b) =>
            for pt in [a, b] {
              if pt.0 < x0 {
                x0 = pt.0
              }
              if pt.0 > x1 {
                x1 = pt.0
              }
              if pt.1 < y0 {
                y0 = pt.1
              }
              if pt.1 > y1 {
                y1 = pt.1
              }
            }
          SegmentArc(a, b, c) => {
            let rho = arc_dist2(a, c)
            let a0 = @math.atan2(a.1 - c.1, a.0 - c.0)
            let delta = arc_norm_sweep(@math.atan2(b.1 - c.1, b.0 - c.0) - a0)
            for k in 0..<=64 {
              let t = Double::from_int(k) / 64.0
              let ang = a0 + delta * t
              let px = c.0 + rho * @math.cos(ang)
              let py = c.1 + rho * @math.sin(ang)
              if px < x0 {
                x0 = px
              }
              if px > x1 {
                x1 = px
              }
              if py < y0 {
                y0 = py
              }
              if py > y1 {
                y1 = py
              }
            }
            // Axis extrema occur at the cardinal angles; include them exactly
            // rather than relying on the uniform samples to land on them.
            for base in [0.0, @math.PI / 2.0, @math.PI, 3.0 * @math.PI / 2.0] {
              for shift in -1..<=2 {
                let ang = base + 2.0 * @math.PI * Double::from_int(shift)
                if ang >= a0 - CAD_ANGLE_EPS &&
                  ang <= a0 + delta + CAD_ANGLE_EPS {
                  let px = c.0 + rho * @math.cos(ang)
                  let py = c.1 + rho * @math.sin(ang)
                  if px < x0 {
                    x0 = px
                  }
                  if px > x1 {
                    x1 = px
                  }
                  if py < y0 {
                    y0 = py
                  }
                  if py > y1 {
                    y1 = py
                  }
                }
              }
            }
          }
        }
      }
      (x0, x1, y0, y1, 0.0, e.height_mm)
    }
    SquareHoleWasher(w) => {
      let r = w.outer_diameter_mm / 2.0
      (-r, r, -r, r, 0.0, w.thickness_mm)
    }
    TabWasher(w) => {
      let r = w.outer_diameter_mm / 2.0
      (-w.tab_length_mm, r, -r, r, 0.0, w.thickness_mm)
    }
    HexHeadWasherFace(h) => {
      let r = h.across_flats_mm / Double::sqrt(3.0)
      let z0 = if h.shank_diameter_mm > 0.0 && h.shank_length_mm > 0.0 {
        -h.shank_length_mm
      } else {
        0.0
      }
      (-r, r, -r, r, z0, h.head_height_mm)
    }
    ExtrudedBezierProfile(e) => {
      let mut x0 = @double.max_value
      let mut x1 = @double.min_value
      let mut y0 = @double.max_value
      let mut y1 = @double.min_value
      for path in e.paths {
        for anchor in path.anchors {
          // Check position and handles for bounding box
          for pt in [anchor.position, anchor.handle_in, anchor.handle_out] {
            if pt.0 < x0 {
              x0 = pt.0
            }
            if pt.0 > x1 {
              x1 = pt.0
            }
            if pt.1 < y0 {
              y0 = pt.1
            }
            if pt.1 > y1 {
              y1 = pt.1
            }
          }
        }
      }
      (x0, x1, y0, y1, 0.0, e.height_mm)
    }
    Difference(d) => d.base.shape.bounding_box()
    Fillet(f) => f.base.bounding_box()
    Chamfer(c) => c.base.bounding_box()
    SweptProfile(s) => {
      // Sweep the actual profile vertices through the same frames the STEP
      // compiler uses. The old implementation expanded the path bounding box by
      // a fixed 5 mm, which made collision checks and component sizes
      // needlessly conservative (a thread or spring appeared 5 mm larger in
      // every direction).
      let path = s.path
      let profile = s.profile
      let n_path = path.points.length()
      if n_path == 0 || profile.vertices.length() < 3 {
        (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
      } else {
        // Profile-local frame: X = right_dir, Z = normal_dir, Y = Z x X.
        let prof_z = v_norm(profile.normal_dir)
        let prof_x = v_norm(profile.right_dir)
        let prof_y = v_cross(prof_z, prof_x)
        let m_global_to_prof = Matrix3x3::{
          m00: prof_x.0,
          m01: prof_x.1,
          m02: prof_x.2,
          m10: prof_y.0,
          m11: prof_y.1,
          m12: prof_y.2,
          m20: prof_z.0,
          m21: prof_z.1,
          m22: prof_z.2,
        }
        let loops : Array[Array[Vec3]] = [
          profile.vertices,
          ..profile.holes.filter(fn(h) { h.length() >= 3 }),
        ]
        let local_verts : Array[Vec3] = []
        let is_hole : Array[Bool] = []
        let mut loop_index = 0
        for lp in loops {
          for v in lp {
            local_verts.push(
              apply_matrix(m_global_to_prof, v_sub(v, profile.center)),
            )
            is_hole.push(loop_index > 0)
          }
          loop_index = loop_index + 1
        }
        // First path frame, used by straight outlines and straight holes.
        let t0 = v_norm(path.tangents[0])
        let n0 = v_norm(path.normals[0])
        let r0 = v_norm(v_cross(t0, n0))
        let m_start_to_global = Matrix3x3::{
          m00: r0.0,
          m01: n0.0,
          m02: t0.0,
          m10: r0.1,
          m11: n0.1,
          m12: t0.1,
          m20: r0.2,
          m21: n0.2,
          m22: t0.2,
        }
        let mut x0 = @double.max_value
        let mut x1 = @double.min_value
        let mut y0 = @double.max_value
        let mut y1 = @double.min_value
        let mut z0 = @double.max_value
        let mut z1 = @double.min_value
        for i in 0..<n_path {
          let p_origin = path.points[i]
          let p_tangent = v_norm(path.tangents[i])
          let p_normal = v_norm(path.normals[i])
          let p_right = v_norm(v_cross(p_tangent, p_normal))
          let m_path_to_global = Matrix3x3::{
            m00: p_right.0,
            m01: p_normal.0,
            m02: p_tangent.0,
            m10: p_right.1,
            m11: p_normal.1,
            m12: p_tangent.1,
            m20: p_right.2,
            m21: p_normal.2,
            m22: p_tangent.2,
          }
          for j, v in local_verts {
            let keep_straight = if is_hole[j] {
              s.straight_holes
            } else {
              s.straight_outline
            }
            let gv = if keep_straight {
              apply_matrix(m_start_to_global, v)
            } else {
              apply_matrix(m_path_to_global, v)
            }
            let px = gv.0 + p_origin.0
            let py = gv.1 + p_origin.1
            let pz = gv.2 + p_origin.2
            if px < x0 {
              x0 = px
            }
            if px > x1 {
              x1 = px
            }
            if py < y0 {
              y0 = py
            }
            if py > y1 {
              y1 = py
            }
            if pz < z0 {
              z0 = pz
            }
            if pz > z1 {
              z1 = pz
            }
          }
        }
        (x0, x1, y0, y1, z0, z1)
      }
    }
    Union(u) => {
      let mut x0 = @double.max_value
      let mut x1 = @double.min_value
      let mut y0 = @double.max_value
      let mut y1 = @double.min_value
      let mut z0 = @double.max_value
      let mut z1 = @double.min_value
      for child in u.nodes {
        let (cx0, cx1, cy0, cy1, cz0, cz1) = child.bounding_box()
        if cx0 < x0 {
          x0 = cx0
        }
        if cx1 > x1 {
          x1 = cx1
        }
        if cy0 < y0 {
          y0 = cy0
        }
        if cy1 > y1 {
          y1 = cy1
        }
        if cz0 < z0 {
          z0 = cz0
        }
        if cz1 > z1 {
          z1 = cz1
        }
      }
      (x0, x1, y0, y1, z0, z1)
    }
  }
}

///|
pub fn SceneNode::bounding_box(
  self : SceneNode,
) -> (Double, Double, Double, Double, Double, Double) {
  let (lx0, lx1, ly0, ly1, lz0, lz1) = self.shape.bounding_box()
  let corners = [
    (lx0, ly0, lz0),
    (lx1, ly0, lz0),
    (lx1, ly1, lz0),
    (lx0, ly1, lz0),
    (lx0, ly0, lz1),
    (lx1, ly0, lz1),
    (lx1, ly1, lz1),
    (lx0, ly1, lz1),
  ]
  let mut x0 = @double.max_value
  let mut x1 = @double.min_value
  let mut y0 = @double.max_value
  let mut y1 = @double.min_value
  let mut z0 = @double.max_value
  let mut z1 = @double.min_value
  for p in corners {
    let (tx, ty, tz) = rotate_point(p, self.rx, self.ry, self.rz)
    let gx = tx + self.tx
    let gy = ty + self.ty
    let gz = tz + self.tz
    if gx < x0 {
      x0 = gx
    }
    if gx > x1 {
      x1 = gx
    }
    if gy < y0 {
      y0 = gy
    }
    if gy > y1 {
      y1 = gy
    }
    if gz < z0 {
      z0 = gz
    }
    if gz > z1 {
      z1 = gz
    }
  }
  (x0, x1, y0, y1, z0, z1)
}
