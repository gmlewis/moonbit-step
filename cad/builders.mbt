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
pub fn Profile2D::rect(
  width : Double,
  height : Double,
) -> Array[(Double, Double)] {
  [(0.0, 0.0), (width, 0.0), (width, height), (0.0, height)]
}

///|
pub fn Profile2D::centered_rect(
  width : Double,
  height : Double,
) -> Array[(Double, Double)] {
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
) -> Array[(Double, Double)] {
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
    .map(fn(p : (Double, Double)) { (p.0 + width - r, p.1 + r) }),
  )
  // Top-right arc: 0 to 90 degrees
  pts.push_iter(
    Profile2D::arc(2.0 * r, 0.0, 0.5 * @math.PI, segments=qn)
    .iter()
    .map(fn(p : (Double, Double)) { (p.0 + width - r, p.1 + height - r) }),
  )
  // Top-left arc: 90 to 180 degrees
  pts.push_iter(
    Profile2D::arc(2.0 * r, 0.5 * @math.PI, @math.PI, segments=qn)
    .iter()
    .map(fn(p : (Double, Double)) { (p.0 + r, p.1 + height - r) }),
  )
  // Bottom-left arc: 180 to 270 degrees
  pts.push_iter(
    Profile2D::arc(2.0 * r, @math.PI, 1.5 * @math.PI, segments=qn)
    .iter()
    .map(fn(p : (Double, Double)) { (p.0 + r, p.1 + r) }),
  )
  pts
}

///|
pub fn Profile2D::dovetail(
  width : Double,
  height : Double,
  angle : Double, // angle in degrees from vertical
) -> Array[(Double, Double)] {
  let angle_rad = angle * @math.PI / 180.0
  let dx = height * @math.tan(angle_rad)
  let half_width = width / 2.0
  [
    (-half_width, 0.0),
    (half_width, 0.0),
    (half_width + dx, height),
    (-half_width - dx, height),
  ]
}

///|
pub fn dovetail_base(
  width : Double,
  height : Double,
  length : Double,
  dovetail_width : Double,
  dovetail_height : Double,
  dovetail_angle : Double,
) -> Shape {
  let hw = width / 2.0
  let hh = height / 2.0
  let dhw = dovetail_width / 2.0
  let angle_rad = dovetail_angle * @math.PI / 180.0
  let dx = dovetail_height * @math.tan(angle_rad)

  // Construct a single CCW loop including the dovetail cutout at the top.
  let outer = [
    (-hw, hh),
    (-hw, -hh),
    (hw, -hh),
    (hw, hh),
    (dhw, hh),
    (dhw + dx, hh - dovetail_height),
    (-dhw - dx, hh - dovetail_height),
    (-dhw, hh),
  ]
  ExtrudedProfile::new(outer, length)
}

///|
pub fn dovetail_slider(
  width : Double,
  height : Double,
  length : Double,
  angle : Double,
  clearance? : Double = 0.0,
) -> Shape {
  // Apply clearance: narrow the width and shorten the height.
  let dt = Profile2D::dovetail(
    width - 2.0 * clearance,
    height - clearance,
    angle,
  )
  // Flip Y to match the groove orientation (neck at the top, pointing down).
  // We also reverse the order to maintain CCW orientation.
  let n = dt.length()
  let flipped = []
  for i in 0..<n {
    let p = dt[n - 1 - i]
    flipped.push((p.0, -p.1))
  }
  ExtrudedProfile::new(flipped, length)
}

///|
/// Profile2D::polygon returns a regular polygon with the given number of sides,
/// diameter, and optional rotation in degrees.
pub fn Profile2D::polygon(
  sides : Int,
  diameter : Double,
  rotation? : Double = 0.0,
) -> Array[(Double, Double)] {
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
/// polygon_knob returns a Shape representing a polygonal knob with a polygonal
/// shaft hole.
pub fn polygon_knob(
  sides : Int,
  diameter : Double,
  height : Double,
  hole_sides : Int,
  hole_diameter : Double,
  hole_rotation? : Double = 0.0,
) -> Shape {
  let outer = Profile2D::polygon(sides, diameter)
  let hole = Profile2D::polygon(
    hole_sides,
    hole_diameter,
    rotation=hole_rotation,
  )
  // Hole must be reversed (CW) for standard STEP orientation if outer is CCW.
  let hole_reversed = hole.rev()
  ExtrudedProfile::new(outer, height, holes=[hole_reversed])
}

///|
/// hex_bit_holder returns a Shape representing a block with a grid of
/// hexagonal holes suitable for standard hex bits.
pub fn hex_bit_holder(
  rows : Int,
  cols : Int,
  bit_diameter_across_flats : Double,
  spacing : Double,
  height : Double,
) -> Shape {
  let d = bit_diameter_across_flats / @math.cos(30.0 * @math.PI / 180.0)
  let hex = Profile2D::polygon(6, d, rotation=30.0)
  let total_width = Double::from_int(cols) * spacing
  let total_length = Double::from_int(rows) * spacing
  let outer = Profile2D::rect(total_width, total_length)
  let holes = []
  for r in 0..<rows {
    for c in 0..<cols {
      let tx = Double::from_int(c) * spacing + spacing / 2.0
      let ty = Double::from_int(r) * spacing + spacing / 2.0
      holes.push(hex.map(fn(p) { (p.0 + tx, p.1 + ty) }).rev())
    }
  }
  ExtrudedProfile::new(outer, height, holes~)
}

///|
/// metric_nut_dimensions returns a tuple of (width_across_flats, height) for a
/// standard metric nut of the given bolt diameter.
pub fn metric_nut_dimensions(bolt_diameter : Double) -> (Double, Double) {
  if bolt_diameter <= 3.0 {
    (5.5, 2.4)
  } else if bolt_diameter <= 4.0 {
    (7.0, 3.2)
  } else if bolt_diameter <= 5.0 {
    (8.0, 4.0)
  } else if bolt_diameter <= 6.0 {
    (10.0, 5.0)
  } else if bolt_diameter <= 8.0 {
    (13.0, 6.5)
  } else if bolt_diameter <= 10.0 {
    (17.0, 8.0)
  } else if bolt_diameter <= 12.0 {
    (19.0, 10.0)
  } else {
    // Heuristic for larger bolts: S approx 1.7 * D, H approx 0.8 * D
    (bolt_diameter * 1.7, bolt_diameter * 0.8)
  }
}

///|
/// metric_nut returns a Shape representing a hexagonal metric nut with a
/// circular hole of (bolt_diameter + clearance).
pub fn metric_nut(
  bolt_diameter : Double,
  clearance : Double,
  height? : Double,
) -> Shape {
  let (s, h) = metric_nut_dimensions(bolt_diameter)
  let height = height.unwrap_or(h)
  let d = s / @math.cos(30.0 * @math.PI / 180.0)
  let outer = Profile2D::polygon(6, d, rotation=30.0)
  let hole = Profile2D::circle(bolt_diameter + clearance).rev()
  ExtrudedProfile::new(outer, height, holes=[hole])
}

///|
/// metric_nut_test_strip returns an array of SceneNodes representing a base
/// plate with several hexagonal metric nuts on top, each with a different
/// clearance to the central bolt hole.
pub fn metric_nut_test_strip(
  bolt_diameter : Double,
  base_clearance : Double,
  base_interference : Double,
  step_count : Int,
  clearance_step : Double,
  hole_spacing : Double,
  mount_thickness : Double,
  nut_height? : Double,
) -> Array[SceneNode] {
  let (s, h) = metric_nut_dimensions(bolt_diameter)
  let nut_h = nut_height.unwrap_or(h)
  let total_length = Double::from_int(step_count) * hole_spacing
  let base_width = s + 10.0
  let base = Cuboid::new(total_length, base_width, mount_thickness)
    .with_name("base")
    .with_color(Rgb::cyan())
    .translate(x=0.0, y=-base_width / 2.0, z=0.0)
  let nodes = [base]
  for i in 0..<step_count {
    let current_clearance = -base_interference +
      Double::from_int(i) * clearance_step +
      base_clearance
    let x = Double::from_int(i) * hole_spacing + hole_spacing / 2.0
    let nut = metric_nut(bolt_diameter, current_clearance, height=nut_h)
      .with_name("nut-\{i}")
      .with_color(Rgb::orange())
      .translate(x~, y=0.0, z=mount_thickness)
    nodes.push(nut)
  }
  nodes
}

///|
/// pin_gauge returns an array of SceneNodes representing a base plate with
/// holes and a corresponding set of pins, each stepping through clearance/interference
/// values to calibrate press fits.
pub fn pin_gauge(
  pin_diameter : Double,
  base_clearance : Double,
  base_interference : Double,
  step_count : Int,
  clearance_step : Double,
  spacing : Double,
  base_height : Double,
  pin_height : Double,
) -> Array[SceneNode] {
  let total_length = Double::from_int(step_count) * spacing
  let base_width = pin_diameter * 3.0

  // Base with holes
  let outer = Profile2D::rect(total_length, base_width)
  let holes = []
  for i in 0..<step_count {
    let current_clearance = -base_interference +
      Double::from_int(i) * clearance_step +
      base_clearance
    let x = Double::from_int(i) * spacing + spacing / 2.0
    let y = base_width / 2.0
    let hole = Profile2D::circle(pin_diameter + current_clearance).rev()
    holes.push(hole.map(fn(p) { (p.0 + x, p.1 + y) }))
  }
  let base = ExtrudedProfile::new(outer, base_height, holes~)
    .with_name("base")
    .with_color(Rgb::blue())
    .translate(x=0.0, y=-base_width / 2.0, z=0.0)
  let nodes = [base]

  // Pins
  for i in 0..<step_count {
    let x = Double::from_int(i) * spacing + spacing / 2.0
    let y = -base_width
    let pin = tube(pin_diameter, 0.0, pin_height)
      .with_name("pin-\{i}")
      .with_color(Rgb::magenta())
      .translate(x~, y~, z=0.0)
    nodes.push(pin)
  }
  nodes
}

///|
/// vented_enclosure returns an array of SceneNodes representing a box body
/// and a matching lid with vent slots and screw bosses.
pub fn vented_enclosure(
  width : Double,
  length : Double,
  height : Double,
  wall_thickness : Double,
  fillet_radius : Double,
  boss_diameter : Double,
  boss_hole_diameter : Double,
  lid_thickness : Double,
  vent_slot_width? : Double = 2.0,
  vent_slot_spacing? : Double = 4.0,
) -> Array[SceneNode] {
  let outer = Profile2D::rounded_rect(width, length, fillet_radius)
  let inner_r = if fillet_radius > wall_thickness {
    fillet_radius - wall_thickness
  } else {
    0.0
  }
  let inner = Profile2D::rounded_rect(
      width - 2.0 * wall_thickness,
      length - 2.0 * wall_thickness,
      inner_r,
    )
    .map(fn(p) { (p.0 + wall_thickness, p.1 + wall_thickness) })
    .rev()

  // 1. Body Bottom
  let bottom = ExtrudedProfile::new(outer, wall_thickness)
    .with_name("body-bottom")
    .with_color(Rgb::blue())

  // 2. Body Walls
  let walls = ExtrudedProfile::new(outer, height - wall_thickness, holes=[inner])
    .with_name("body-walls")
    .with_color(Rgb::blue())
    .translate(z=wall_thickness)
  let nodes = [bottom, walls]

  // 3. Screw Bosses
  let boss_h = height - wall_thickness
  let boss_offset = wall_thickness + boss_diameter / 2.0
  let boss_locs = [
    (boss_offset, boss_offset),
    (width - boss_offset, boss_offset),
    (width - boss_offset, length - boss_offset),
    (boss_offset, length - boss_offset),
  ]
  for i, loc in boss_locs {
    let (bx, by) = loc
    let boss = tube(boss_diameter, boss_hole_diameter, boss_h)
      .with_name("boss-\{i}")
      .with_color(Rgb::cyan())
      .translate(x=bx, y=by, z=wall_thickness)
    nodes.push(boss)
  }

  // 4. Lid with Vents
  let vent_w = vent_slot_width
  let vent_s = vent_slot_spacing
  let lid_holes = []

  // Add some vent slots in the middle
  let safe_margin = wall_thickness + boss_diameter + 2.0
  let vent_area_w = width - 2.0 * safe_margin
  let vent_area_l = length - 2.0 * safe_margin
  if vent_area_w > vent_w && vent_area_l > vent_w {
    let num_vents = (vent_area_w / vent_s).to_int()
    for i in 0..<num_vents {
      let vx = safe_margin + Double::from_int(i) * vent_s
      let hole = [
        (vx - vent_w / 2.0, safe_margin),
        (vx + vent_w / 2.0, safe_margin),
        (vx + vent_w / 2.0, safe_margin + vent_area_l),
        (vx - vent_w / 2.0, safe_margin + vent_area_l),
      ].rev()
      lid_holes.push(hole)
    }
  }

  // Add screw holes to lid
  for loc in boss_locs {
    let (bx, by) = loc
    let hole = Profile2D::circle(boss_hole_diameter)
      .map(fn(p) { (p.0 + bx, p.1 + by) })
      .rev()
    lid_holes.push(hole)
  }
  let lid = ExtrudedProfile::new(outer, lid_thickness, holes=lid_holes)
    .with_name("lid")
    .with_color(Rgb::orange())
    .translate(z=height + 10.0) // Exploded view
  nodes.push(lid)
  nodes
}

///|
/// living_hinge returns a Shape representing a plate with a lattice hinge
/// pattern (series of staggered slots) that allows the material to bend.
pub fn living_hinge(
  plate_length : Double,
  total_width : Double,
  thickness : Double,
  hinge_width : Double,
  slot_width : Double,
  slot_length : Double,
  num_rows : Int,
) -> Shape {
  let total_length = 2.0 * plate_length + hinge_width
  let outer = Profile2D::rect(total_length, total_width)
  let holes = []
  let row_spacing = hinge_width / Double::from_int(num_rows + 1)
  for i in 0..<num_rows {
    let row_x = plate_length + Double::from_int(i + 1) * row_spacing
    let is_offset = i % 2 == 1

    // Number of slots in this row
    let mut current_y = if is_offset { -slot_length / 2.0 } else { 0.0 }
    let spacing_y = slot_length * 1.2
    let padding = 1.0
    while current_y < total_width + slot_length {
      let y_start = if current_y < padding { padding } else { current_y }
      let y_end = if current_y + slot_length > total_width - padding {
        total_width - padding
      } else {
        current_y + slot_length
      }
      if y_end - y_start > 1.0 { // Minimum slot length
        let sw = slot_width
        let hole = [
          (row_x - sw / 2.0, y_start),
          (row_x + sw / 2.0, y_start),
          (row_x + sw / 2.0, y_end),
          (row_x - sw / 2.0, y_end),
        ].rev()
        holes.push(hole)
      }
      current_y = current_y + spacing_y
    }
  }
  ExtrudedProfile::new(outer, thickness, holes~)
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
/// Profile2D::rect_with_notches returns a rectangular profile of (width x height)
/// with rectangular notches cut out from the top edge (the edge at Y = height).
/// The notches are specified as a list of (x_offset, notch_width, notch_depth).
pub fn Profile2D::rect_with_notches(
  width : Double,
  height : Double,
  notches : Array[(Double, Double, Double)],
) -> Array[(Double, Double)] {
  let pts = [(0.0, 0.0), (width, 0.0), (width, height)]
  // Sort notches by X offset descending to process from right to left (maintaining CCW)
  let sorted_notches = notches.copy()
  sorted_notches.sort_by(fn(a, b) { b.0.compare(a.0) })
  for notch in sorted_notches {
    let (x, w, d) = notch
    if x + w < width {
      pts.push((x + w, height))
    }
    pts.push((x + w, height - d))
    pts.push((x, height - d))
    pts.push((x, height))
  }
  if pts[pts.length() - 1].0 > 0.0 {
    pts.push((0.0, height))
  }
  pts
}

///|
/// notched_block returns a Shape representing a block of (width x length x height)
/// with notches cut out from one of its faces. The block is centered in X.
pub fn notched_block(
  width : Double,
  length : Double,
  height : Double,
  notches : Array[(Double, Double, Double)],
) -> Shape {
  let hw = width / 2.0
  let profile = Profile2D::rect_with_notches(width, height, notches)
  let centered_profile = profile.map(fn(p) { (p.0 - hw, p.1) })
  ExtrudedProfile::new(centered_profile, length)
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
  emboss_depth? : Double = 0.5,
  rx? : Double = 0.0,
  ry? : Double = 0.0,
  rz? : Double = 0.0,
) -> Array[SceneNode] {
  let bbox = @draw.bbox(-500.0, -font_size / 2.0, 500.0, font_size / 2.0)
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
) -> Array[(Array[(Double, Double)], Array[Array[(Double, Double)]])] {
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
/// bolt_length_gauge_base returns a Shape representing the base block
/// of a bolt length gauge, with a central ruler slot and bolt holes.
pub fn bolt_length_gauge_base(
  width : Double,
  length : Double,
  height : Double,
  slot_width : Double,
  slot_depth : Double,
  _bolt_diameters : Array[Double],
) -> Shape {
  let hw = width / 2.0
  let slot_x = hw - slot_width / 2.0
  let profile = Profile2D::rect_with_notches(width, height, [
    (slot_x, slot_width, slot_depth),
  ])
  // Translate profile so it's centered in X
  let centered_profile = profile.map(fn(p) { (p.0 - hw, p.1) })
  ExtrudedProfile::new(centered_profile, length)
}

///|
pub fn Profile2D::circle(
  diameter : Double,
  segments? : Int = 64,
) -> Array[(Double, Double)] {
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
) -> Array[(Double, Double)] {
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
  outer : Array[(Double, Double)],
  height_mm : Double,
  holes? : Array[Array[(Double, Double)]] = [],
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
pub fn SceneNode::with_color(self : SceneNode, color : Rgb) -> SceneNode {
  { ..self, color, }
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
