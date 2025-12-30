///|
pub fn Profile2D::new(outer : Array[Vec2]) -> Profile2D {
  { outer, holes: [] }
}

///|
pub fn Profile2D::add_hole(self : Profile2D, hole : Array[Vec2]) -> Profile2D {
  let holes = self.holes.copy()
  holes.push(hole)
  { ..self, holes, }
}

///|
pub fn Profile2D::add_holes_at(
  self : Profile2D,
  locs : Array[Vec2],
  hole_profile : Array[Vec2],
) -> Profile2D {
  let holes = self.holes.copy()
  for loc in locs {
    let (lx, ly) = loc
    holes.push(translate_pts(hole_profile, lx, ly).rev())
  }
  { ..self, holes, }
}

///|
pub fn translate_pts(pts : Array[Vec2], x : Double, y : Double) -> Array[Vec2] {
  pts.map(fn(p) { (p.0 + x, p.1 + y) })
}

///|
pub fn SceneNode::repeat_at(
  self : SceneNode,
  locs : Array[Vec3],
) -> Array[SceneNode] {
  locs.map(fn(loc) {
    let (lx, ly, lz) = loc
    self.translate(x=lx, y=ly, z=lz)
  })
}

///|
pub fn Cuboid::new(sx : Double, sy : Double, sz : Double) -> Shape {
  Shape::Cuboid({ sx, sy, sz })
}

///|
pub fn CalibrationChamferBlock::new(
  length_mm : Double,
  width_mm : Double,
  height_mm : Double,
  chamfer_size_mm? : Double = 1.0,
  fillet_radius_mm? : Double = 0.0,
  fillet_segments? : Int = 8,
) -> Shape {
  Shape::CalibrationChamferBlock({
    length_mm,
    width_mm,
    height_mm,
    chamfer_size_mm,
    fillet_radius_mm,
    fillet_segments,
  })
}

///|
pub fn Profile2D::rect(width : Double, height : Double) -> Array[Vec2] {
  [(0.0, 0.0), (width, 0.0), (width, height), (0.0, height)]
}

///|
pub fn Profile2D::centered_rect(width : Double, height : Double) -> Array[Vec2] {
  let hw = width / 2.0
  let hh = height / 2.0
  [(-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh)]
}

///|
pub fn Profile2D::rounded_rect(
  width : Double,
  height : Double,
  radius : Double,
  segments? : Int = 32,
) -> Array[Vec2] {
  if radius <= 0.0 {
    return Profile2D::rect(width, height)
  }
  let r = if radius > width / 2.0 {
    width / 2.0
  } else if radius > height / 2.0 {
    height / 2.0
  } else {
    radius
  }
  let n = if segments < 4 { 4 } else { segments }
  let qn = n / 4
  let pts = []
  // Bottom-right arc: 270 to 360 degrees
  pts.push_iter(
    Profile2D::arc(2.0 * r, 1.5 * @math.PI, 2.0 * @math.PI, segments=qn)
    .iter()
    .map(fn(p : Vec2) { (p.0 + width - r, p.1 + r) }),
  )
  // Top-right arc: 0 to 90 degrees
  pts.push_iter(
    Profile2D::arc(2.0 * r, 0.0, 0.5 * @math.PI, segments=qn)
    .iter()
    .map(fn(p : Vec2) { (p.0 + width - r, p.1 + height - r) }),
  )
  // Top-left arc: 90 to 180 degrees
  pts.push_iter(
    Profile2D::arc(2.0 * r, 0.5 * @math.PI, @math.PI, segments=qn)
    .iter()
    .map(fn(p : Vec2) { (p.0 + r, p.1 + height - r) }),
  )
  // Bottom-left arc: 180 to 270 degrees
  pts.push_iter(
    Profile2D::arc(2.0 * r, @math.PI, 1.5 * @math.PI, segments=qn)
    .iter()
    .map(fn(p : Vec2) { (p.0 + r, p.1 + r) }),
  )
  pts
}

///|
/// Profile2D::polygon returns a regular polygon with the given number of sides,
/// diameter, and optional rotation in degrees.
pub fn Profile2D::polygon(
  sides : Int,
  diameter : Double,
  rotation? : Double = 0.0,
) -> Array[Vec2] {
  let n = if sides < 3 { 3 } else { sides }
  let radius = diameter / 2.0
  let angle_step = 2.0 * @math.PI / Double::from_int(n)
  let rotation_rad = rotation * @math.PI / 180.0
  let out = []
  for i in 0..<n {
    let phi = Double::from_int(i) * angle_step + rotation_rad
    out.push((radius * @math.cos(phi), radius * @math.sin(phi)))
  }
  out
}

///|
/// tube returns a Shape representing a hollow (or solid) cylinder.
/// If inner_diameter <= 0, it returns a solid cylinder.
pub fn tube(
  outer_diameter : Double,
  inner_diameter : Double,
  height : Double,
  segments? : Int = 64,
) -> Shape {
  let outer = Profile2D::circle(outer_diameter, segments~)
  if inner_diameter <= 0.0 {
    ExtrudedProfile::new(outer, height)
  } else {
    let hole = Profile2D::circle(inner_diameter, segments~).rev()
    ExtrudedProfile::new(outer, height, holes=[hole])
  }
}

///|
/// text_at returns an array of SceneNodes representing the given text
/// rendered at the specified position and orientation.
///
/// Note that the 'draw' package represents all glyphs as type `CompoundPath`
/// where it explicitly labels each included `Path` as either `clear=true`
/// (meaning that this represents a cut-out or hole like the two holes in
/// the "8") or `clear=false` which would represent the outer path, for
/// example. Some glyphs (like "%") have multiple `clear=true` AND
/// `clear=false` `Path`s due to detached geometry. Note that WINDING
/// ORDER IS NOT GUARANTEED in the 'draw' package! So the 'cad' package
/// in THIS repo should understand this critical information, and build
/// proper STEP representations of these extruded `CompoundPath`s.
pub fn text_at(
  text : String,
  x : Double,
  y : Double,
  z : Double,
  font~ : @draw.Font,
  font_size? : Double = 5.0,
  max_width? : Double = 1000.0,
  emboss_depth? : Double = 0.5,
  rx? : Double = 0.0,
  ry? : Double = 0.0,
  rz? : Double = 0.0,
) -> Array[SceneNode] {
  let fs = font_size
  let mw = max_width
  let bbox = @draw.bbox(-mw / 2.0, -fs / 2.0, mw / 2.0, fs / 2.0)
  let text_graphic = @draw.to_graphic(font, text, alignment=Center, y_up=true).scale_to_fit(
    bbox,
    anchor=Center,
  ) catch {
    _ => return []
  }
  let all_paths = text_graphic.all_paths_and_compound_paths()
  let nodes = []
  for g in all_paths {
    let profiles = collect_profiles(g, 8)
    for profile in profiles {
      let (outer, holes) = profile
      if outer.length() < 3 {
        continue
      }
      let solid = ExtrudedProfile::new(outer, emboss_depth, holes~)
        .with_name("text")
        .with_color(Rgb::orange())
        .rotate_x(rx)
        .rotate_y(ry)
        .rotate_z(rz)
        .translate(x~, y~, z~)
      nodes.push(solid)
    }
  }
  nodes
}

///|
fn collect_profiles(
  g : @draw.Graphic,
  segments : Int,
) -> Array[(Array[Vec2], Array[Array[Vec2]])] {
  match g {
    CompoundPath(cp) => {
      let outers = []
      let holes = []
      for p in cp.paths {
        let pts_tuples = @draw.Graphic::Path(p).to_profiles_tuples(segments)
        for pt_tuple in pts_tuples {
          let (poly, _) = pt_tuple
          if p.clear {
            holes.push(poly)
          } else {
            outers.push(poly)
          }
        }
      }
      let results = []
      for outer in outers {
        let ccw_outer = force_ccw(outer)
        let my_holes = []
        for hole in holes {
          if hole.length() > 0 && is_point_in_polygon(hole[0], ccw_outer) {
            my_holes.push(force_cw(hole))
          }
        }
        results.push((ccw_outer, my_holes))
      }
      results
    }
    Group(group) => {
      let results = []
      for item in group.items {
        results.push_iter(collect_profiles(item, segments).iter())
      }
      results
    }
    Path(p) => {
      let pts_tuples = @draw.Graphic::Path(p).to_profiles_tuples(segments)
      pts_tuples.map(fn(pt_tuple) {
        let (poly, _) = pt_tuple
        (force_ccw(poly), [])
      })
    }
  }
}

///|
pub fn Profile2D::ellipse(
  width : Double,
  height : Double,
  segments? : Int = 64,
) -> Array[Vec2] {
  let rx = width / 2.0
  let ry = height / 2.0
  let n = if segments < 3 { 3 } else { segments }
  let angle_step = 2.0 * @math.PI / Double::from_int(n)
  let out = []
  for i in 0..<n {
    let phi = Double::from_int(i) * angle_step
    out.push((rx * @math.cos(phi), ry * @math.sin(phi)))
  }
  out
}

///|
pub fn Profile2D::circle(
  diameter : Double,
  segments? : Int = 64,
) -> Array[Vec2] {
  let radius = diameter / 2.0
  let n = if segments < 3 { 3 } else { segments }
  let angle_step = 2.0 * @math.PI / Double::from_int(n)
  let out = []
  for i in 0..<n {
    let phi = Double::from_int(i) * angle_step
    out.push((radius * @math.cos(phi), radius * @math.sin(phi)))
  }
  out
}

///|
pub fn Profile2D::arc(
  diameter : Double,
  start_angle : Double,
  end_angle : Double,
  segments? : Int = 32,
) -> Array[Vec2] {
  let radius = diameter / 2.0
  let n = if segments < 2 { 2 } else { segments }
  let angle_step = (end_angle - start_angle) / Double::from_int(n)
  let out = []
  for i in 0..=n {
    let phi = start_angle + Double::from_int(i) * angle_step
    out.push((radius * @math.cos(phi), radius * @math.sin(phi)))
  }
  out
}

///|
pub fn ExtrudedProfile::new(
  outer : Array[Vec2],
  height_mm : Double,
  holes? : Array[Array[Vec2]] = [],
) -> Shape {
  Shape::ExtrudedProfile({ profile: { outer, holes }, height_mm })
}

///|
pub fn Shape::with_name(self : Shape, name : String) -> SceneNode {
  SceneNode::{
    shape: self,
    name,
    color: Rgb::orange(),
    tx: 0.0,
    ty: 0.0,
    tz: 0.0,
    rx: 0.0,
    ry: 0.0,
    rz: 0.0,
  }
}

///|
pub fn Shape::with_color(self : Shape, color : Rgb) -> SceneNode {
  self.with_name("unnamed").with_color(color)
}

///|
pub fn SceneNode::with_color(self : SceneNode, color : Rgb) -> SceneNode {
  { ..self, color, }
}

///|
pub fn SceneNode::with_name(self : SceneNode, name : String) -> SceneNode {
  { ..self, name, }
}

///|
pub fn SceneNode::translate(
  self : SceneNode,
  x? : Double = 0.0,
  y? : Double = 0.0,
  z? : Double = 0.0,
) -> SceneNode {
  { ..self, tx: self.tx + x, ty: self.ty + y, tz: self.tz + z }
}

///|
pub fn SceneNode::rotate_x(self : SceneNode, angle : Double) -> SceneNode {
  { ..self, rx: self.rx + angle }
}

///|
pub fn SceneNode::rotate_y(self : SceneNode, angle : Double) -> SceneNode {
  { ..self, ry: self.ry + angle }
}

///|
/// rotate_z adds the given angle in degrees to the SceneNode's rotation around
/// the Z-axis.
pub fn SceneNode::rotate_z(self : SceneNode, angle : Double) -> SceneNode {
  { ..self, rz: self.rz + angle }
}

///|
pub fn Design::add_text_on_face(
  self : Design,
  target : SceneNode,
  text : String,
  face : Face,
  font : @draw.Font,
  font_size? : Double,
  emboss_depth? : Double,
  offset_x? : Double = 0.0,
  offset_y? : Double = 0.0,
  rotation? : Double = 0.0,
  margin? : Double,
  color? : Rgb = Rgb::orange(),
) -> Design {
  let (min_x, max_x, min_y, max_y, min_z, max_z) = match target.shape {
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
  }
  let mid_x = (min_x + max_x) / 2.0
  let mid_y = (min_y + max_y) / 2.0
  let mid_z = (min_z + max_z) / 2.0
  let dx = max_x - min_x
  let dy = max_y - min_y
  let dz = max_z - min_z
  let m = match margin {
    Some(v) => v
    None => 2.0
  }

  // Local coordinates and rotations relative to shape origin (0,0,0)
  // We subtract 0.01 from the "outward" direction to embed the text slightly
  // and avoid Z-fighting.
  let (lx, ly, lz, lrx, lry, lrz, fw, fh) = match face {
    Top =>
      (mid_x + offset_x, mid_y + offset_y, max_z - 0.01, 0.0, 0.0, 0.0, dx, dy)
    Bottom =>
      (
        mid_x + offset_x,
        mid_y - offset_y,
        min_z + 0.01,
        180.0,
        0.0,
        180.0,
        dx,
        dy,
      )
    Front =>
      (
        mid_x + offset_x,
        max_y - 0.01,
        mid_z + offset_y,
        90.0,
        0.0,
        180.0,
        dx,
        dz,
      )
    Back =>
      (mid_x - offset_x, min_y + 0.01, mid_z + offset_y, 90.0, 0.0, 0.0, dx, dz)
    Left =>
      (
        min_x + 0.01,
        mid_y + offset_x,
        mid_z + offset_y,
        90.0,
        0.0,
        -90.0,
        dy,
        dz,
      )
    Right =>
      (
        max_x - 0.01,
        mid_y - offset_x,
        mid_z + offset_y,
        90.0,
        0.0,
        90.0,
        dy,
        dz,
      )
  }
  let fs = match font_size {
    Some(v) => v
    None => {
      let mut s = fh - 2.0 * m
      if s <= 0.0 {
        s = 1.0
      }
      s
    }
  }
  let mw = fw - 2.0 * m
  let ed = emboss_depth.unwrap_or(0.5)
  let (frx, fry, frz) = matrix_to_euler(
    multiply_matrices(
      rotation_matrix(lrx, lry, lrz),
      rotation_matrix(0.0, 0.0, rotation),
    ),
  )
  let text_nodes = text_at(
    text,
    lx,
    ly,
    lz,
    font~,
    font_size=fs,
    max_width=mw,
    emboss_depth=ed,
    rx=frx,
    ry=fry,
    rz=frz,
  )
  let final_nodes = text_nodes.map(fn(n) {
    let n = n.with_color(color)
    // Apply target's own local-to-global transform
    // We compose the rotations: R_target * R_local
    let m_local = rotation_matrix(n.rx, n.ry, n.rz)
    let m_target = rotation_matrix(target.rx, target.ry, target.rz)
    let m_combined = multiply_matrices(m_target, m_local)
    let (grx, gry, grz) = matrix_to_euler(m_combined)
    let (gx, gy, gz) = rotate_point(
      (n.tx, n.ty, n.tz),
      target.rx,
      target.ry,
      target.rz,
    )
    {
      ..n,
      tx: gx + target.tx,
      ty: gy + target.ty,
      tz: gz + target.tz,
      rx: grx,
      ry: gry,
      rz: grz,
    }
  })
  self.add_iter(final_nodes.iter())
}
