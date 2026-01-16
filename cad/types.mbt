///|
pub type Vec2 = (Double, Double)

///|
pub type Vec3 = (Double, Double, Double)

///|
pub struct Rgb {
  r : Double
  g : Double
  b : Double
}

///|
pub fn Rgb::new(r : Double, g : Double, b : Double) -> Rgb {
  { r, g, b }
}

///|
pub fn Rgb::orange() -> Rgb {
  { r: 1.0, g: 0.6, b: 0.0 }
}

///|
pub fn Rgb::blue() -> Rgb {
  { r: 0.2, g: 0.6, b: 1.0 }
}

///|
pub fn Rgb::grey() -> Rgb {
  { r: 0.2, g: 0.2, b: 0.2 }
}

///|
pub fn Rgb::purple() -> Rgb {
  { r: 0.5, g: 0.0, b: 0.5 }
}

///|
pub fn Rgb::magenta() -> Rgb {
  { r: 1.0, g: 0.0, b: 1.0 }
}

///|
pub fn Rgb::white() -> Rgb {
  { r: 1.0, g: 1.0, b: 1.0 }
}

///|
pub fn Rgb::black() -> Rgb {
  { r: 0.0, g: 0.0, b: 0.0 }
}

///|
pub fn Rgb::green() -> Rgb {
  { r: 0.0, g: 0.8, b: 0.0 }
}

///|
pub fn Rgb::red() -> Rgb {
  { r: 0.8, g: 0.0, b: 0.0 }
}

///|
pub fn Rgb::cyan() -> Rgb {
  { r: 0.0, g: 0.8, b: 0.8 }
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
pub struct CalibrationChamferBlock {
  length_mm : Double
  width_mm : Double
  height_mm : Double
  chamfer_size_mm : Double
  fillet_radius_mm : Double
  fillet_segments : Int
}

///|
pub struct ExtrudedProfile {
  profile : Profile2D
  height_mm : Double
}

///|
pub struct SweptProfile {
  path : SweepPath
  profile : SweepProfile
  make_start_cap : Bool
  make_end_cap : Bool
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
pub enum Shape {
  Cuboid(Cuboid)
  CalibrationChamferBlock(CalibrationChamferBlock)
  ExtrudedProfile(ExtrudedProfile)
  SweptProfile(SweptProfile)
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
pub(all) struct SweepProfile {
  center : Vec3
  vertices : Array[Vec3]
  // normal_dir points in the direction of extrusion
  normal_dir : Vec3
  // right_dir points to the "right" side of the profile when looking along normal_dir
  right_dir : Vec3
}

///|
/// SweepProfile::new returns a new SweepProfile.
pub fn SweepProfile::new(
  vertices : Array[Vec3],
  center? : Vec3 = (0.0, 0.0, 0.0),
  normal_dir? : Vec3 = (0.0, 1.0, 0.0),
  right_dir? : Vec3 = (1.0, 0.0, 0.0),
) -> SweepProfile {
  { center, vertices, normal_dir, right_dir }
}

///|
pub fn Shape::bounding_box(
  self : Shape,
) -> (Double, Double, Double, Double, Double, Double) {
  match self {
    Cuboid(c) => (0.0, c.sx, 0.0, c.sy, 0.0, c.sz)
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
    Difference(d) => d.base.shape.bounding_box()
    SweptProfile(s) => {
      let mut x0 = @double.max_value
      let mut x1 = @double.min_value
      let mut y0 = @double.max_value
      let mut y1 = @double.min_value
      let mut z0 = @double.max_value
      let mut z1 = @double.min_value
      for pt in s.path.points {
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
        if pt.2 < z0 {
          z0 = pt.2
        }
        if pt.2 > z1 {
          z1 = pt.2
        }
      }
      // Expand by a reasonable amount for the profile
      (x0 - 5.0, x1 + 5.0, y0 - 5.0, y1 + 5.0, z0 - 5.0, z1 + 5.0)
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
