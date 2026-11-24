///|
/// 3D-printable split-ring compound planetary (Wolfrom / 3K) herringbone
/// gearbox primitive.
///
/// Designed as TWO support-free, print-in-place 4-elbow herringbone cartridges
/// that snap permanently together via `@fasteners.AxialSnapFit`:
/// - **Cartridge 1 (Lower — Fixed Ring Stage):** Sun (`Z_s`) + N lower planets
///   (`Z_p1`, with male 45-deg split snap pins on their top face) + Fixed Ring
///   (`Z_r1`, shortened by `ring_axial_gap_mm` at the top so it never rubs the
///   rotating output ring).
/// - **Cartridge 2 (Upper — Rotating Output Stage, no sun):** N upper planets
///   (`Z_p2`, with matching female 45-deg snap sockets cut into their bottom
///   face) + Rotating Output Ring (`Z_r2`).
///
/// Because both stages share the exact same center distance
/// (`Z_r1 - Z_p1 == Z_r2 - Z_p2`) and each upper planet is rigidly locked to
/// its lower planet by the snap-fit pins, the differential reduction ratio is:
///
///   `i = (1 + Z_r1 / Z_s) / (1 - (Z_r1 * Z_p2) / (Z_p1 * Z_r2))`

///|
/// Parameters for a 3D-printable two-cartridge split-ring compound herringbone
/// planetary gearbox.
pub(all) struct SplitRingPlanetaryParams {
  module_mm : Double
  stage1_length_mm : Double
  stage2_length_mm : Double
  ring_axial_gap_mm : Double
  helix_angle_deg : Double
  pressure_angle_deg : Double
  num_elbows : Int32
  resolution : Int32
  sun_hole_type : String
  sun_hole_radius_mm : Double
  tolerance_mm : Double
  outer_thickness_mm : Double
  sun_teeth : Int32
  planet1_teeth : Int32
  ring1_teeth : Int32
  planet2_teeth : Int32
  ring2_teeth : Int32
  planet_count : Int32
  snap_pins_per_planet : Int32
  poka_yoke_snap_angles : Bool
  snap_pin_params : @fasteners.AxialSnapPinParams?
}

///|
/// Validated constructor for `SplitRingPlanetaryParams`.
///
/// Default is a compact 4-planet `-18.2:1` Wolfrom set with generous
/// planet-to-planet clearance (~5 mm between upper planets):
/// `Z_s = 20`, `Z_p1 = 14`, `Z_r1 = 48`, `Z_p2 = 18`, `Z_r2 = 52`.
pub fn SplitRingPlanetaryParams::new(
  module_mm~ : Double = 1.25,
  stage1_length_mm~ : Double = 10.0,
  stage2_length_mm~ : Double = 10.0,
  ring_axial_gap_mm~ : Double = 0.5,
  helix_angle_deg~ : Double = 30.0,
  pressure_angle_deg~ : Double = 20.0,
  num_elbows~ : Int32 = 4,
  resolution~ : Int32 = 5,
  sun_hole_type~ : String = "Hexagonal",
  sun_hole_radius_mm~ : Double = 3.5,
  tolerance_mm~ : Double = 0.10,
  outer_thickness_mm~ : Double = 5.0,
  sun_teeth~ : Int32 = 20,
  planet1_teeth~ : Int32 = 14,
  ring1_teeth~ : Int32 = 48,
  planet2_teeth~ : Int32 = 18,
  ring2_teeth~ : Int32 = 52,
  planet_count~ : Int32 = 4,
  snap_pins_per_planet~ : Int32 = 3,
  poka_yoke_snap_angles~ : Bool = true,
  snap_pin_params? : @fasteners.AxialSnapPinParams,
) -> Result[SplitRingPlanetaryParams, @common.SpecError] {
  if module_mm <= 0.0 {
    return Err(@common.InvalidParameter("module_mm must be positive"))
  }
  if stage1_length_mm <= 4.0 || stage2_length_mm <= 4.0 {
    return Err(
      @common.InvalidParameter(
        "stage1_length_mm and stage2_length_mm must be > 4 mm",
      ),
    )
  }
  if ring_axial_gap_mm < 0.0 || ring_axial_gap_mm >= stage1_length_mm * 0.4 {
    return Err(
      @common.InvalidParameter(
        "ring_axial_gap_mm must be in [0, 0.4 * stage1_length_mm)",
      ),
    )
  }
  if planet_count < 2 {
    return Err(@common.InvalidParameter("planet_count must be >= 2"))
  }
  if sun_teeth < 6 || planet1_teeth < 6 || planet2_teeth < 6 {
    return Err(@common.InvalidParameter("tooth counts must be >= 6"))
  }
  if ring1_teeth != sun_teeth + 2 * planet1_teeth {
    return Err(
      @common.InvalidParameter(
        "stage 1 meshing requires ring1_teeth == sun_teeth + 2 * planet1_teeth (\{ring1_teeth} != \{sun_teeth + 2 * planet1_teeth})",
      ),
    )
  }
  if ring2_teeth - planet2_teeth != ring1_teeth - planet1_teeth {
    return Err(
      @common.InvalidParameter(
        "same center distance requires ring2_teeth - planet2_teeth == ring1_teeth - planet1_teeth (\{ring2_teeth - planet2_teeth} != \{ring1_teeth - planet1_teeth})",
      ),
    )
  }
  let virtual_sun2 = ring2_teeth - 2 * planet2_teeth
  if virtual_sun2 < 4 {
    return Err(
      @common.InvalidParameter(
        "stage 2 virtual sun (ring2_teeth - 2 * planet2_teeth = \{virtual_sun2}) is too small",
      ),
    )
  }
  if planet1_teeth * ring2_teeth == ring1_teeth * planet2_teeth {
    return Err(
      @common.InvalidParameter(
        "stage 1 and stage 2 have identical tooth ratios (infinite/degenerate reduction)",
      ),
    )
  }
  if (sun_teeth + ring1_teeth) % planet_count != 0 {
    return Err(
      @common.InvalidParameter(
        "stage 1 assembly requires (sun_teeth + ring1_teeth) divisible by planet_count",
      ),
    )
  }
  // Verify adjacent planets do not collide in either stage.
  let orbit_r = module_mm * (sun_teeth + planet1_teeth).to_double() / 2.0
  let chord = 2.0 * orbit_r * @math.sin(@math.PI / planet_count.to_double())
  let max_planet_teeth = if planet1_teeth > planet2_teeth {
    planet1_teeth
  } else {
    planet2_teeth
  }
  let max_planet_od = module_mm * (max_planet_teeth.to_double() + 2.0)
  if chord <= max_planet_od + 0.5 {
    return Err(
      @common.InvalidParameter(
        "planets collide: adjacent center spacing \{@cad.fmt_double(chord, Some(0.1))} mm <= max planet OD \{@cad.fmt_double(max_planet_od, Some(0.1))} mm + 0.5 mm (use fewer planets or larger sun_teeth)",
      ),
    )
  }
  if snap_pins_per_planet < 1 {
    return Err(@common.InvalidParameter("snap_pins_per_planet must be >= 1"))
  }
  Ok({
    module_mm,
    stage1_length_mm,
    stage2_length_mm,
    ring_axial_gap_mm,
    helix_angle_deg,
    pressure_angle_deg,
    num_elbows,
    resolution,
    sun_hole_type,
    sun_hole_radius_mm,
    tolerance_mm,
    outer_thickness_mm,
    sun_teeth,
    planet1_teeth,
    ring1_teeth,
    planet2_teeth,
    ring2_teeth,
    planet_count,
    snap_pins_per_planet,
    poka_yoke_snap_angles,
    snap_pin_params,
  })
}

///|
/// Default 4-planet `-32:1` split-ring compound herringbone planetary preset.
pub fn SplitRingPlanetaryParams::default() -> SplitRingPlanetaryParams {
  SplitRingPlanetaryParams::new().unwrap()
}

///|
/// The `-51:1` 3-planet split-ring compound planetary preset from Manafish
/// Notes Section 6 (`Z_s = 12`, `Z_p1 = 18`, `Z_r1 = 48`, `Z_p2 = 21`,
/// `Z_r2 = 51`).
pub fn SplitRingPlanetaryParams::manafish_51(
  module_mm~ : Double = 1.25,
  stage1_length_mm~ : Double = 10.0,
  stage2_length_mm~ : Double = 10.0,
) -> SplitRingPlanetaryParams {
  SplitRingPlanetaryParams::new(
    module_mm~,
    stage1_length_mm~,
    stage2_length_mm~,
    sun_teeth=12,
    planet1_teeth=18,
    ring1_teeth=48,
    planet2_teeth=21,
    ring2_teeth=51,
    planet_count=3,
  ).unwrap()
}

///|
/// Exact signed reduction ratio `omega_sun / omega_ring2` (negative means
/// output ring turns opposite to input sun).
pub fn SplitRingPlanetaryParams::ratio(
  self : SplitRingPlanetaryParams,
) -> Double {
  let zs = self.sun_teeth.to_double()
  let zp1 = self.planet1_teeth.to_double()
  let zr1 = self.ring1_teeth.to_double()
  let zp2 = self.planet2_teeth.to_double()
  let zr2 = self.ring2_teeth.to_double()
  (1.0 + zr1 / zs) / (1.0 - zr1 * zp2 / (zp1 * zr2))
}

///|
/// Computed layout and snap-fit sizing for a split-ring compound planetary
/// gearbox.
pub(all) struct SplitRingPlanetaryLayout {
  stage1 : HerringbonePlanetaryLayout
  stage2 : HerringbonePlanetaryLayout
  ratio : Double
  outer_radius_mm : Double
  total_length_mm : Double
  ring1_length_mm : Double
  snap_pin_params : @fasteners.AxialSnapPinParams
  snap_bcd_mm : Double
  planet_centers_xy : Array[(Double, Double)]
  planets_identical : Bool
}

///|
fn split_ring_auto_snap_params(
  planet_root_radius_mm : Double,
  stage2_length_mm : Double,
  pins_per_planet : Int32,
) -> (@fasteners.AxialSnapPinParams, Double) {
  // Size snap-pin ring and pin radius proportionally to the smaller planet's
  // root circle so pins sit comfortably inside the solid planet core with
  // >= 1.5 mm radial wall margin to the tooth roots.
  let usable_r = planet_root_radius_mm - 1.5
  let bcd_r = if pins_per_planet == 1 { 0.0 } else { usable_r * 0.54 }
  let max_pin_r = if pins_per_planet == 1 {
    usable_r * 0.45
  } else {
    let radial_cap = usable_r - bcd_r
    let chord_cap = bcd_r *
      @math.sin(@math.PI / pins_per_planet.to_double()) *
      0.68
    let raw = if radial_cap < chord_cap { radial_cap } else { chord_cap }
    if raw > 2.6 {
      2.6
    } else if raw < 1.5 {
      1.5
    } else {
      raw
    }
  }
  let base_r = max_pin_r
  let neck_r = base_r * 0.82
  let undercut = if base_r >= 2.2 { 0.28 } else { 0.22 }
  let tip_r = base_r * 0.60
  let max_h = stage2_length_mm - 2.2
  let flare_plus_lead = neck_r + undercut - neck_r + (neck_r + undercut - tip_r)
  let raw_neck_h = max_h - flare_plus_lead - 0.5
  let neck_h = if raw_neck_h > 3.6 {
    3.6
  } else if raw_neck_h < 1.8 {
    1.8
  } else {
    raw_neck_h
  }
  let slot_w = if base_r >= 2.2 { 0.8 } else { 0.65 }
  let params = @fasteners.AxialSnapPinParams::new(
    base_radius_mm=base_r,
    neck_radius_mm=neck_r,
    neck_height_mm=neck_h,
    undercut_mm=undercut,
    tip_radius_mm=tip_r,
    clearance_mm=0.10,
    num_slots=2,
    slot_width_mm=slot_w,
    slot_bottom_z_mm=0.6,
  ).unwrap()
  (params, 2.0 * bcd_r)
}

///|
fn split_ring_stage_params(
  params : SplitRingPlanetaryParams,
) -> (HerringbonePlanetaryParams, HerringbonePlanetaryParams) {
  let virtual_sun2 = params.ring2_teeth - 2 * params.planet2_teeth
  // Match outer diameters of Ring 1 and Ring 2 so the assembled Wolfrom
  // gearbox forms one clean cylinder.
  let r1_extra = params.module_mm *
    (params.ring2_teeth - params.ring1_teeth).to_double() /
    2.0
  let r1_wall = params.outer_thickness_mm +
    (if r1_extra > 0.0 { r1_extra } else { 0.0 })
  let r2_wall = params.outer_thickness_mm +
    (if r1_extra < 0.0 { -r1_extra } else { 0.0 })
  let p1 = HerringbonePlanetaryParams::new(
    module_mm=params.module_mm,
    gear_length_mm=params.stage1_length_mm,
    helix_angle_deg=params.helix_angle_deg,
    pressure_angle_deg=params.pressure_angle_deg,
    num_elbows=params.num_elbows,
    resolution=params.resolution,
    hole_type="None",
    sun_hole_type=params.sun_hole_type,
    sun_hole_radius_mm=params.sun_hole_radius_mm,
    planet_hole_radius_mm=0.0,
    tolerance_mm=params.tolerance_mm,
    outer_thickness_mm=r1_wall,
    sun_teeth=params.sun_teeth,
    planet_count=params.planet_count,
    planet_teeth=params.planet1_teeth,
    ring_teeth=params.ring1_teeth,
  ).unwrap()
  let p2 = HerringbonePlanetaryParams::new(
    module_mm=params.module_mm,
    gear_length_mm=params.stage2_length_mm,
    helix_angle_deg=params.helix_angle_deg,
    pressure_angle_deg=params.pressure_angle_deg,
    num_elbows=params.num_elbows,
    resolution=params.resolution,
    hole_type="None",
    sun_hole_type="None",
    sun_hole_radius_mm=0.0,
    planet_hole_radius_mm=0.0,
    tolerance_mm=params.tolerance_mm,
    outer_thickness_mm=r2_wall,
    sun_teeth=virtual_sun2,
    planet_count=params.planet_count,
    planet_teeth=params.planet2_teeth,
    ring_teeth=params.ring2_teeth,
  ).unwrap()
  (p1, p2)
}

///|
/// Computes the complete geometric layout, ratio, and snap-fit pattern sizing
/// for a split-ring compound planetary gearbox.
pub fn split_ring_planetary_layout(
  params : SplitRingPlanetaryParams,
) -> SplitRingPlanetaryLayout {
  let (p1, p2) = split_ring_stage_params(params)
  let s1 = herringbone_planetary_layout(p1)
  let s2 = herringbone_planetary_layout(p2)
  let min_planet_root = if s1.planet.root_radius_mm < s2.planet.root_radius_mm {
    s1.planet.root_radius_mm
  } else {
    s2.planet.root_radius_mm
  }
  let (auto_snap, auto_bcd) = split_ring_auto_snap_params(
    min_planet_root,
    params.stage2_length_mm,
    params.snap_pins_per_planet,
  )
  let snap_pin_params = params.snap_pin_params.unwrap_or(auto_snap)
  let outer_radius_mm = if s1.ring_outer_radius_mm > s2.ring_outer_radius_mm {
    s1.ring_outer_radius_mm
  } else {
    s2.ring_outer_radius_mm
  }
  // In print-flat (+Z) orientation via rotate_x(90.0), native (x, 0, z) maps
  // to (x, -z, 0).
  let planet_centers_xy = s1.planets.map(fn(p) { (p.x, -p.z) })
  let planets_identical = (params.ring2_teeth - params.ring1_teeth) %
    params.planet_count ==
    0
  {
    stage1: s1,
    stage2: s2,
    ratio: params.ratio(),
    outer_radius_mm,
    total_length_mm: params.stage1_length_mm +
    params.ring_axial_gap_mm +
    params.stage2_length_mm,
    ring1_length_mm: params.stage1_length_mm,
    snap_pin_params,
    snap_bcd_mm: auto_bcd,
    planet_centers_xy,
    planets_identical,
  }
}

///|
fn split_ring_planet_snap_pattern(
  params : SplitRingPlanetaryParams,
  layout : SplitRingPlanetaryLayout,
  cx : Double,
  cy : Double,
) -> @fasteners.AxialSnapFit {
  let n = params.snap_pins_per_planet
  if n == 1 || layout.snap_bcd_mm <= 0.0 {
    return @fasteners.AxialSnapFit::at_points(layout.snap_pin_params, [(cx, cy)])
  }
  let r = layout.snap_bcd_mm / 2.0
  let angles_deg : Array[Double] = if params.poka_yoke_snap_angles && n == 3 {
    // Asymmetric 0 / 110 / 230 deg poka-yoke spacing so each planet pair can
    // only snap together at the exact intended tooth phase.
    [0.0, 110.0, 230.0]
  } else {
    let arr : Array[Double] = []
    for i in 0..<n {
      arr.push(360.0 * i.to_double() / n.to_double())
    }
    arr
  }
  let pts = angles_deg.map(fn(deg) {
    let rad = deg * @math.PI / 180.0
    (cx + r * @math.cos(rad), cy + r * @math.sin(rad))
  })
  @fasteners.AxialSnapFit::at_points(layout.snap_pin_params, pts)
}

///|
fn split_ring_stage_nodes(
  layout : HerringbonePlanetaryLayout,
  ring_length_override : Double?,
  include_sun : Bool,
  prefix : String,
  planet_color : @cad.Rgb,
  ring_color : @cad.Rgb,
) -> (@cad.SceneNode?, Array[@cad.SceneNode], @cad.SceneNode) {
  let module_mm = layout.module_mm
  let length = layout.gear_length_mm
  let ring_len = ring_length_override.unwrap_or(length)
  let smooth = layout.num_elbows == 0

  let sun_node : @cad.SceneNode? = if include_sun {
    let sun_outline = hb_gear_outline(
      module_mm,
      layout.pressure_angle_deg,
      layout.sun.num_teeth,
      layout.resolution,
      layout.tolerance_mm,
    )
    let sun_holes = hb_gear_holes(
      layout,
      layout.sun,
      layout.sun_hole_radius_mm,
      hole_type_override=layout.sun_hole_type,
    )
    let sun_max_rot = @math.tan(hb_deg2rad(layout.helix_angle_sun_deg)) *
      (length / 2.0) /
      layout.sun.outer_radius_mm
    let shape = if smooth {
      hb_arc_gear_shape(sun_outline, sun_holes, length)
    } else {
      hb_swept_gear_shape(
        sun_outline,
        sun_holes,
        length,
        layout.num_elbows,
        sun_max_rot,
        layout.sun_direction,
        straight_holes=true,
        straight_outline=false,
        smooth_sides=true,
      )
    }
    let node = if smooth {
      shape.with_name("\{prefix}_sun").with_color(@cad.Rgb::orange())
    } else {
      shape
      .with_name("\{prefix}_sun")
      .with_color(@cad.Rgb::orange())
      .rotate_x(90.0)
    }
    Some(node)
  } else {
    None
  }

  let planet_outline = hb_gear_outline(
    module_mm,
    layout.pressure_angle_deg,
    layout.planet.num_teeth,
    layout.resolution,
    layout.tolerance_mm,
  )
  let planet_holes = hb_gear_holes(
    layout,
    layout.planet,
    layout.planet_hole_radius_mm,
  )
  let planet_max_rot = @math.tan(hb_deg2rad(layout.helix_angle_deg)) *
    (length / 2.0) /
    layout.planet.outer_radius_mm
  let planet_nodes : Array[@cad.SceneNode] = []
  for i in 0..<layout.planets.length() {
    let p = layout.planets[i]
    let shape = if smooth {
      hb_arc_gear_shape(planet_outline, planet_holes, length)
    } else {
      hb_swept_gear_shape(
        planet_outline,
        planet_holes,
        length,
        layout.num_elbows,
        planet_max_rot,
        layout.planet_direction,
        straight_holes=true,
        straight_outline=false,
        smooth_sides=true,
      )
    }
    let raw = shape
      .with_name("\{prefix}_planet_\{i + 1}")
      .with_color(planet_color)
    let placed = if smooth {
      raw.rotate_z(-p.phi_deg).translate(x=p.x, y=-p.z)
    } else {
      // SceneNode applies Rz * Ry * Rx, so Rx(90) tips the native +Y swept
      // gear onto +Z first, then Rz(-phi_deg) clocks its teeth around +Z —
      // identical to Rx(90) * Ry(-phi_deg) in herringbone_planetary_gearbox.
      raw.rotate_x(90.0).rotate_z(-p.phi_deg).translate(x=p.x, y=-p.z)
    }
    planet_nodes.push(placed)
  }

  let ring = hb_ring_geometry(layout)
  let outer_circle = hb_circle_outline(
    ring.outer_radius,
    layout.resolution * 8,
    true,
  )
  let inner_ccw = ring.inner.map(fn(pt) { hb_rotate_xz(pt, ring.phase) }).rev()
  let ring_max_rot = ring.ring_scale * ring.max_helix_mate * (ring_len / length)
  let ring_shape = if smooth {
    hb_arc_ring_shape(ring.outer_radius, inner_ccw, ring_len)
  } else {
    hb_swept_gear_shape(
      outer_circle,
      [inner_ccw],
      ring_len,
      layout.num_elbows,
      ring_max_rot,
      layout.planet_direction,
      smooth_sides=true,
    )
  }
  let ring_node = if smooth {
    ring_shape.with_name("\{prefix}_ring").with_color(ring_color)
  } else {
    ring_shape.with_name("\{prefix}_ring").with_color(ring_color).rotate_x(90.0)
  }

  (sun_node, planet_nodes, ring_node)
}

///|
/// Builds **Cartridge 1** (lower fixed-ring stage) print-flat at `z = 0`:
/// sun + N lower planets (each with an integral `ring_axial_gap_mm` thrust
/// spacer boss inside the tooth root so fixed `ring1` and rotating `ring2`
/// never rub while preserving identical herringbone elbow heights, topped by
/// male 45-deg snap pins at `z = stage1_length_mm + ring_axial_gap_mm`) +
/// fixed ring (`z = [0, stage1_length_mm]`).
pub fn split_ring_lower_cartridge_design(
  params : SplitRingPlanetaryParams,
  include_snap_pins~ : Bool = true,
) -> Result[@cad.Design, @common.SpecError] {
  let layout = split_ring_planetary_layout(params)
  let (sun_opt, planets, ring1) = split_ring_stage_nodes(
    layout.stage1,
    None,
    true,
    "lower",
    @cad.Rgb::blue(),
    @cad.Rgb::grey(),
  )
  let snap_z = params.stage1_length_mm + params.ring_axial_gap_mm
  let boss_r = layout.stage1.planet.root_radius_mm - 0.4
  let mut design = @cad.Design::new(
    name="split-ring-lower-cartridge",
    description="Print-in-place lower fixed-ring herringbone cartridge with male axial snap-fit pins",
  )
  match sun_opt {
    Some(s) => design = design.add(s)
    None => ()
  }
  for i in 0..<planets.length() {
    let (cx, cy) = layout.planet_centers_xy[i]
    let with_boss = if params.ring_axial_gap_mm > 1.0e-6 && boss_r > 2.0 {
      let boss = @cad.Cylinder::new(boss_r, params.ring_axial_gap_mm + 0.5)
        .with_name("lower_planet_\{i + 1}_spacer")
        .with_color(planets[i].color)
        .translate(x=cx, y=cy, z=params.stage1_length_mm - 0.5)
      planets[i].union_with(boss)
    } else {
      planets[i]
    }
    let p_node = if include_snap_pins {
      let snap = split_ring_planet_snap_pattern(params, layout, cx, cy)
      snap.attach_male_to(with_boss, z_mm=snap_z)
    } else {
      with_boss
    }
    design = design.add(p_node)
  }
  design = design.add(ring1)
  Ok(design)
}

///|
/// Builds **Cartridge 2** (upper rotating output-ring stage, no sun) print-flat
/// at `z = 0`: N upper planets (with matching female 45-deg snap sockets cut
/// from `z = 0`) + rotating output ring (`z = [0, stage2_length_mm]`).
pub fn split_ring_upper_cartridge_design(
  params : SplitRingPlanetaryParams,
  include_snap_sockets~ : Bool = true,
) -> Result[@cad.Design, @common.SpecError] {
  let layout = split_ring_planetary_layout(params)
  let (_sun_opt, planets, ring2) = split_ring_stage_nodes(
    layout.stage2,
    None,
    false,
    "upper",
    @cad.Rgb::cyan(),
    @cad.Rgb::red(),
  )
  let mut design = @cad.Design::new(
    name="split-ring-upper-cartridge",
    description="Print-in-place upper output-ring herringbone cartridge with female axial snap-fit sockets",
  )
  for i in 0..<planets.length() {
    let p_node = if include_snap_sockets {
      let (cx, cy) = layout.planet_centers_xy[i]
      let snap = split_ring_planet_snap_pattern(params, layout, cx, cy)
      snap.cut_female_from(planets[i], z_mm=0.0)
    } else {
      planets[i]
    }
    design = design.add(p_node)
  }
  design = design.add(ring2)
  Ok(design)
}

///|
/// Builds a coaxial **exploded assembly view** showing Cartridge 1 at `z = 0`
/// (male snap pins pointing up) and Cartridge 2 floating coaxially at
/// `z = stage1_length_mm + gap_mm` (female snap sockets facing straight down)
/// so the snap-together assembly path is immediately obvious.
pub fn split_ring_exploded_design(
  params : SplitRingPlanetaryParams,
  gap_mm~ : Double = 25.0,
  include_snap_features~ : Bool = true,
) -> Result[@cad.Design, @common.SpecError] {
  let lower = match
    split_ring_lower_cartridge_design(
      params,
      include_snap_pins=include_snap_features,
    ) {
    Ok(d) => d
    Err(e) => return Err(e)
  }
  let upper = match
    split_ring_upper_cartridge_design(
      params,
      include_snap_sockets=include_snap_features,
    ) {
    Ok(d) => d
    Err(e) => return Err(e)
  }
  let upper_z = params.stage1_length_mm + params.ring_axial_gap_mm + gap_mm
  let mut design = @cad.Design::new(
    name="split-ring-exploded",
    description="Exploded view showing how Cartridge 2 snaps coaxially down onto Cartridge 1",
  )
  for n in lower.nodes {
    design = design.add(n)
  }
  for n in upper.nodes {
    design = design.add(n.translate(z=upper_z))
  }
  Ok(design)
}

///|
/// Builds the assembled split-ring compound herringbone planetary gearbox as a
/// reusable `@common.Component` (print-flat `+Z` axis) with full contact-plane
/// mate connectors for plug-and-play integration in `moonbit-19-cad`.
pub fn split_ring_planetary_gearbox(
  params : SplitRingPlanetaryParams,
  include_snap_features~ : Bool = true,
) -> Result[@common.Component, @common.SpecError] {
  let layout = split_ring_planetary_layout(params)
  let lower = match
    split_ring_lower_cartridge_design(
      params,
      include_snap_pins=include_snap_features,
    ) {
    Ok(d) => d
    Err(e) => return Err(e)
  }
  let upper = match
    split_ring_upper_cartridge_design(
      params,
      include_snap_sockets=include_snap_features,
    ) {
    Ok(d) => d
    Err(e) => return Err(e)
  }
  let ratio_str = @cad.fmt_double(layout.ratio.abs(), Some(0.1))
  let name = "split-ring-planetary-m\{@cad.fmt_double(params.module_mm, None)}-i\{ratio_str}"
  let features = @common.FeatureRecord::new(
    modeled=[
      "lower-sun", "lower-planets-with-male-snap-pins", "fixed-lower-ring", "upper-planets-with-female-snap-sockets",
      "rotating-upper-output-ring", "ring-to-ring-axial-clearance",
    ],
    approximated=[],
    omitted=[],
  )
  let mut comp = @common.Component::new(
    name~,
    metadata=@common.Metadata::new(
      designation="Split-ring compound planetary m\{@cad.fmt_double(params.module_mm, None)} \{params.sun_teeth}/\{params.planet1_teeth}-\{params.ring1_teeth}/\{params.planet2_teeth}-\{params.ring2_teeth} (\{ratio_str}:1)",
      family="split-ring compound planetary gearbox",
      size="Ø\{@cad.fmt_double(layout.outer_radius_mm * 2.0, Some(0.1))} x \{@cad.fmt_double(layout.total_length_mm, Some(0.1))} mm",
      length_mm=layout.total_length_mm,
      source="Two-cartridge print-in-place 4-elbow herringbone Wolfrom gearbox with axial snap-fit planet couplers.",
    ),
    description="Two-cartridge 3D-printable split-ring compound herringbone planetary gearbox (\{ratio_str}:1 reduction).",
    features~,
  )
  for n in lower.nodes {
    comp = comp.add_layer(
      n.shape,
      name=n.name,
      color=n.color,
      placement=@common.Placement::at(
        n.tx,
        n.ty,
        n.tz,
        rx=n.rx,
        ry=n.ry,
        rz=n.rz,
      ),
    )
  }
  let snap_z = params.stage1_length_mm + params.ring_axial_gap_mm
  for n in upper.nodes {
    comp = comp.add_layer(
      n.shape,
      name=n.name,
      color=n.color,
      placement=@common.Placement::at(
        n.tx,
        n.ty,
        n.tz + snap_z,
        rx=n.rx,
        ry=n.ry,
        rz=n.rz,
      ),
    )
  }

  // Contact-plane mate connectors in print-flat +Z frame.
  comp = comp
    .with_connector_unchecked(
      @common.MateConnector::new(
        "input-face",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, -1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=layout.outer_radius_mm * 2.0,
        description="Input-side flat mounting face at z = 0",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "sun-bore",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalBore,
        gender=@common.MateGender::Female,
        diameter_mm=params.sun_hole_radius_mm * 2.0,
        depth_mm=params.stage1_length_mm,
        description="Input sun shaft bore",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "snap-mating-plane",
        placement=@common.Placement::translation(0.0, 0.0, snap_z),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=layout.outer_radius_mm * 2.0,
        description="Flush snap-fit contact plane between Cartridge 1 and Cartridge 2",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "output-face",
        placement=@common.Placement::translation(
          0.0,
          0.0,
          layout.total_length_mm,
        ),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::PlaneFace,
        diameter_mm=layout.outer_radius_mm * 2.0,
        description="Rotating output ring top face at z = total_length_mm",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "fixed-ring-outer-seat",
        placement=@common.Placement::translation(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=layout.outer_radius_mm * 2.0,
        depth_mm=layout.ring1_length_mm,
        description="Fixed lower ring cylindrical outer seat",
      ),
    )
    .with_connector_unchecked(
      @common.MateConnector::new(
        "output-ring-outer-seat",
        placement=@common.Placement::translation(0.0, 0.0, snap_z),
        axis=(0.0, 0.0, 1.0),
        kind=@common.MateKind::CylindricalShaft,
        gender=@common.MateGender::Male,
        diameter_mm=layout.outer_radius_mm * 2.0,
        depth_mm=params.stage2_length_mm,
        description="Rotating upper output ring cylindrical outer seat",
      ),
    )
  Ok(comp)
}
