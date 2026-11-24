///|
/// Pipe-friendly `SceneNode` feature methods and the fluent `Plate` builder.
///
/// Designed so multi-feature parts read top-to-bottom as a clean pipeline:
/// ```moonbit
/// let flange = Plate::round(outer_diam_mm=46.0, thickness_mm=8.0, name="flange")
///   .with_bore(8.2)
///   .with_chamfer(bottom_mm=0.35)
///   .with_holes(PointPattern2D::ring(6, diam_mm=34.0), 4.5)
///   .with_color(Rgb::blue())
///   .to_node()
/// ```

///|
/// Unions `other` onto `self`, preserving `self`'s color and (by default) name.
pub fn SceneNode::union_with(
  self : SceneNode,
  other : SceneNode,
  name? : String,
) -> SceneNode {
  let out_name = name.unwrap_or(self.name)
  union_all([self, other], name=out_name).with_color(self.color)
}

///|
/// Subtracts `cutter` from `self`, preserving `self`'s color and (by default)
/// name.
pub fn SceneNode::cut_with(
  self : SceneNode,
  cutter : SceneNode,
  name? : String,
) -> SceneNode {
  let out_name = name.unwrap_or(self.name)
  difference(self, [cutter], name=out_name).with_color(self.color)
}

///|
/// Unions copies of `feature` at every `(x, y, z_mm)` point in `pattern` onto
/// `self`.
pub fn SceneNode::union_on(
  self : SceneNode,
  pattern : PointPattern2D,
  feature : SceneNode,
  z_mm~ : Double = 0.0,
  name? : String,
) -> SceneNode {
  pattern.union_onto(self, feature, z_mm~, name?)
}

///|
/// Subtracts copies of `cutter` at every `(x, y, z_mm)` point in `pattern` from
/// `self`.
pub fn SceneNode::cut_on(
  self : SceneNode,
  pattern : PointPattern2D,
  cutter : SceneNode,
  z_mm~ : Double = 0.0,
  name? : String,
) -> SceneNode {
  pattern.cut_from(self, cutter, z_mm~, name?)
}

///|
/// Drills cylindrical holes of diameter `hole_diam_mm` at every point in
/// `pattern`, starting at `z0_mm` and extending `depth_mm` in `+Z`.
pub fn SceneNode::drill(
  self : SceneNode,
  pattern : PointPattern2D,
  hole_diam_mm : Double,
  z0_mm~ : Double = -0.5,
  depth_mm~ : Double = 20.0,
  name? : String,
) -> SceneNode {
  pattern.drill_holes(self, hole_diam_mm, z0_mm~, depth_mm~, name?)
}

///|
/// Drills a single cylindrical bore centered at `(0, 0)` of diameter
/// `bore_diam_mm`.
pub fn SceneNode::drill_center_bore(
  self : SceneNode,
  bore_diam_mm : Double,
  z0_mm~ : Double = -0.5,
  depth_mm~ : Double = 20.0,
  name? : String,
) -> SceneNode {
  if bore_diam_mm <= 0.0 {
    return self
  }
  let cutter = Cylinder::new(bore_diam_mm / 2.0, depth_mm)
    .with_name("center_bore")
    .translate(z=z0_mm)
  self.cut_with(cutter, name?)
}

///|
/// Applies a 45-degree chamfer (e.g. `0.35 mm` elephant-foot compensation) to
/// all edges lying on the horizontal plane `z = z_mm` (default `0.0`).
/// Evaluated by the OCCT kernel (`to_step_evaluated`).
pub fn SceneNode::with_bottom_chamfer(
  self : SceneNode,
  size_mm~ : Double = 0.35,
  z_mm~ : Double = 0.0,
  tol_mm~ : Double = 0.1,
  name? : String,
) -> SceneNode {
  if size_mm <= 0.0 {
    return self
  }
  chamfer_edges(
    self,
    size_mm,
    selector=EdgesOnPlane(z_mm, tol_mm),
    name=name.unwrap_or(self.name),
  ).with_color(self.color)
}

///|
/// Applies a 45-degree chamfer to all edges lying on the horizontal plane
/// `z = z_mm`. Evaluated by the OCCT kernel (`to_step_evaluated`).
pub fn SceneNode::with_top_chamfer(
  self : SceneNode,
  size_mm : Double,
  z_mm : Double,
  tol_mm~ : Double = 0.1,
  name? : String,
) -> SceneNode {
  if size_mm <= 0.0 {
    return self
  }
  chamfer_edges(
    self,
    size_mm,
    selector=EdgesOnPlane(z_mm, tol_mm),
    name=name.unwrap_or(self.name),
  ).with_color(self.color)
}

///|
/// Applies a fillet of radius `radius_mm` to all edges lying on the horizontal
/// plane `z = z_mm`. Evaluated by the OCCT kernel (`to_step_evaluated`).
pub fn SceneNode::with_fillet_on_plane(
  self : SceneNode,
  radius_mm : Double,
  z_mm : Double,
  tol_mm~ : Double = 0.1,
  name? : String,
) -> SceneNode {
  if radius_mm <= 0.0 {
    return self
  }
  fillet_edges(
    self,
    radius_mm,
    selector=EdgesOnPlane(z_mm, tol_mm),
    name=name.unwrap_or(self.name),
  ).with_color(self.color)
}

///|
/// Builds an exact analytic CCW rectangular (or rounded-rectangle) outer loop
/// centered at `(0, 0)` for `ExtrudedArcProfile`.
pub fn arc_rounded_rect_loop(
  width_mm : Double,
  height_mm : Double,
  corner_radius_mm~ : Double = 0.0,
) -> Array[ProfileSegment] {
  let hx = width_mm / 2.0
  let hy = height_mm / 2.0
  let max_r = if hx < hy { hx } else { hy }
  let r = if corner_radius_mm < 0.0 {
    0.0
  } else if corner_radius_mm > max_r * 0.999 {
    max_r * 0.999
  } else {
    corner_radius_mm
  }
  if r <= 1.0e-6 {
    return [
      SegmentLine((hx, -hy), (hx, hy)),
      SegmentLine((hx, hy), (-hx, hy)),
      SegmentLine((-hx, hy), (-hx, -hy)),
      SegmentLine((-hx, -hy), (hx, -hy)),
    ]
  }
  let ix = hx - r
  let iy = hy - r
  [
    // Right edge -> top-right arc
    SegmentLine((hx, -iy), (hx, iy)),
    SegmentArc((hx, iy), (ix, hy), (ix, iy)),
    // Top edge -> top-left arc
    SegmentLine((ix, hy), (-ix, hy)),
    SegmentArc((-ix, hy), (-hx, iy), (-ix, iy)),
    // Left edge -> bottom-left arc
    SegmentLine((-hx, iy), (-hx, -iy)),
    SegmentArc((-hx, -iy), (-ix, -hy), (-ix, -iy)),
    // Bottom edge -> bottom-right arc
    SegmentLine((-ix, -hy), (ix, -hy)),
    SegmentArc((ix, -hy), (hx, -iy), (ix, -iy)),
  ]
}

///|
/// Outer outline kind for the fluent `Plate` builder.
pub(all) enum PlateOutline {
  Round(Double)
  Rect(Double, Double, Double)
}

///|
/// Fluent builder for round, rectangular, or rounded-rectangle structural
/// plates with optional center bore, 3D-print chamfers, and zero-`for`-loop
/// hole patterns.
///
/// Automatically picks the cleanest exact analytic primitive (`RevolvedProfile`
/// or `ExtrudedArcProfile`) when possible, falling back to boolean drilling
/// only when a revolved chamfered round plate also has off-center holes.
pub(all) struct Plate {
  outline : PlateOutline
  thickness_mm : Double
  bore_diam_mm : Double
  bottom_chamfer_mm : Double
  top_chamfer_mm : Double
  hole_groups : Array[(PointPattern2D, Double)]
  name : String
  color : Rgb
}

///|
/// Starts a circular plate of diameter `outer_diam_mm` and thickness
/// `thickness_mm`.
pub fn Plate::round(
  outer_diam_mm~ : Double,
  thickness_mm~ : Double,
  name~ : String = "plate",
) -> Plate {
  {
    outline: Round(outer_diam_mm),
    thickness_mm,
    bore_diam_mm: 0.0,
    bottom_chamfer_mm: 0.0,
    top_chamfer_mm: 0.0,
    hole_groups: [],
    name,
    color: Rgb::grey(),
  }
}

///|
/// Starts a rectangular (or rounded-rectangle when `corner_radius_mm > 0`)
/// plate centered at `(0, 0)`.
pub fn Plate::rect(
  width_mm~ : Double,
  height_mm~ : Double,
  thickness_mm~ : Double,
  corner_radius_mm~ : Double = 0.0,
  name~ : String = "plate",
) -> Plate {
  {
    outline: Rect(width_mm, height_mm, corner_radius_mm),
    thickness_mm,
    bore_diam_mm: 0.0,
    bottom_chamfer_mm: 0.0,
    top_chamfer_mm: 0.0,
    hole_groups: [],
    name,
    color: Rgb::grey(),
  }
}

///|
/// Adds a central shaft/clearance bore of diameter `bore_diam_mm`.
pub fn Plate::with_bore(self : Plate, bore_diam_mm : Double) -> Plate {
  { ..self, bore_diam_mm, }
}

///|
/// Sets bottom (default `0.35 mm` for elephant-foot compensation) and optional
/// top chamfers in millimetres.
pub fn Plate::with_chamfer(
  self : Plate,
  bottom_mm~ : Double = 0.35,
  top_mm~ : Double = 0.0,
) -> Plate {
  { ..self, bottom_chamfer_mm: bottom_mm, top_chamfer_mm: top_mm, }
}

///|
/// Adds a pattern of through-holes of diameter `diam_mm` to this plate.
pub fn Plate::with_holes(
  self : Plate,
  pattern : PointPattern2D,
  diam_mm : Double,
) -> Plate {
  let groups = self.hole_groups.copy()
  groups.push((pattern, diam_mm))
  { ..self, hole_groups: groups, }
}

///|
/// Adds a single through-hole of diameter `diam_mm` at `(x, y)`.
pub fn Plate::with_hole_at(
  self : Plate,
  x : Double,
  y : Double,
  diam_mm : Double,
) -> Plate {
  self.with_holes(PointPattern2D::from_points([(x, y)]), diam_mm)
}

///|
/// Sets the display color of the resulting `SceneNode`.
pub fn Plate::with_color(self : Plate, color : Rgb) -> Plate {
  { ..self, color, }
}

///|
/// Sets the name of the resulting `SceneNode`.
pub fn Plate::with_name(self : Plate, name : String) -> Plate {
  { ..self, name, }
}

///|
/// Builds the plate as a `SceneNode` spanning `z = [0, thickness_mm]`.
pub fn Plate::to_node(self : Plate) -> SceneNode {
  let has_chamfers = self.bottom_chamfer_mm > 0.0 || self.top_chamfer_mm > 0.0
  match self.outline {
    Round(od) => {
      if !has_chamfers && !self.hole_groups.is_empty() {
        // Pure analytic ExtrudedArcProfile: zero booleans, exact cylinders!
        let mut prof = ExtrudedArcProfile::new(
          arc_circle_loop(0.0, 0.0, od),
          self.thickness_mm,
          round_bore?=if self.bore_diam_mm > 0.0 {
            Some(((0.0, 0.0), self.bore_diam_mm))
          } else {
            None
          },
        )
        for group in self.hole_groups {
          prof = prof.with_pattern_holes(group.0, group.1)
        }
        return prof.as_shape().with_name(self.name).with_color(self.color)
      }
      // Exact revolved cylinder/tube with analytic chamfers.
      let base_shape = if self.bore_diam_mm > 0.0 {
        RevolvedProfile::chamfered_tube(
          od,
          self.bore_diam_mm,
          self.thickness_mm,
          outer_bottom_chamfer=self.bottom_chamfer_mm,
          outer_top_chamfer=self.top_chamfer_mm,
          inner_bottom_chamfer=self.bottom_chamfer_mm,
          inner_top_chamfer=self.top_chamfer_mm,
        ).as_shape()
      } else {
        RevolvedProfile::chamfered_cylinder(
          od,
          self.thickness_mm,
          bottom_chamfer=self.bottom_chamfer_mm,
          top_chamfer=self.top_chamfer_mm,
        ).as_shape()
      }
      let mut node = base_shape.with_name(self.name).with_color(self.color)
      for group in self.hole_groups {
        node = node.drill(
          group.0,
          group.1,
          z0_mm=-0.5,
          depth_mm=self.thickness_mm + 1.0,
        )
      }
      node
    }
    Rect(w, h, corner_r) => {
      let mut prof = ExtrudedArcProfile::new(
        arc_rounded_rect_loop(w, h, corner_radius_mm=corner_r),
        self.thickness_mm,
        round_bore?=if self.bore_diam_mm > 0.0 {
          Some(((0.0, 0.0), self.bore_diam_mm))
        } else {
          None
        },
      )
      for group in self.hole_groups {
        prof = prof.with_pattern_holes(group.0, group.1)
      }
      let mut node = prof.as_shape().with_name(self.name).with_color(self.color)
      if self.bottom_chamfer_mm > 0.0 {
        node = node.with_bottom_chamfer(size_mm=self.bottom_chamfer_mm)
      }
      if self.top_chamfer_mm > 0.0 {
        node = node.with_top_chamfer(self.top_chamfer_mm, self.thickness_mm)
      }
      node
    }
  }
}
