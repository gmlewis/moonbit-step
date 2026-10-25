///|
/// 38-planetary-gearbox
///
/// A print-in-place herringbone planetary gearbox, ported from
/// `github.com/gmlewis/go-bjk/cmd/make-planetary-gearbox` and the Blackjack
/// `HerringboneGear` node (`herringbone_gear.lua`).
///
/// The center "sun" gear, three orbiting "planet" gears, and the enclosing
/// inward-facing "ring" gear are all herringbone gears. The ring gear is
/// generated as the envelope of the mating planet gear, exactly as the Lua node
/// does it.
///
/// Gear terminology and formulas follow the HerringboneGear node:
///
///   pitch radius = gear_module * num_teeth / 2
///   base radius  = pitch radius * cos(pressure_angle)
///   root radius  = pitch radius - 1.25 * module
///   outer radius = pitch radius + module
///
/// For a planetary set with a sun, Np planet gears, and an internal ring gear:
///
///   ring = sun + 2*planet
///   (sun + ring) % planets == 0
///
/// With all four inner gears identical (planet == sun) the second condition
/// becomes sun % 3 == 0 for three planets, so the default here is 12 teeth.
///
/// ## Why the STEP file is small
///
/// The Blackjack node evaluates every gear as a triangle mesh: it walks the
/// full gear length in `(num_elbows + 1) * 2 * resolution` horizontal slices,
/// regenerating every tooth facet per slice. Here each gear's 2D outline is
/// built exactly once and then swept through `num_elbows + 1` linearly twisted
/// extrusions - only the elbow vertices are needed as cross-sections, so the
/// model is much smaller than the equivalent STL. Non-coplanar swept bands are
/// split into planar triangles so every STEP face is planar and the model
/// tessellates without gaps. The exported design is Z-up (the gears are built
/// with their axes along +Y and rotated +90° about X), so it sits flat on a
/// build plate: 30 mm tall with a 136 mm footprint. Pass `--yUp` to keep the
/// native Y-up frame.
///
/// Usage (stdout):
///   moon run --target native examples/38-planetary-gearbox -- > gearbox.step
///
/// Usage (write file):
///   ./examples/run-example.sh 38 --numTeeth 12 -o gearbox.step
///
/// Parameter mapping (Go flag -> this program):
///   -mod   --module          -gl  --gearLength      -ha  --helixAngle
///   -hr    --holeRadius      -ht  --holeType        -ne  --numElbows
///   -nt    --numTeeth        -planets --numPlanets  -planetTeeth --planetTeeth
///   -pa    --pressureAngle   -ringTeeth --ringTeeth -tol --tolerance
///   -outerThickness --outerThickness                -res --resolution
///   -o     --out
///   (-obj, -stl, -swapyz, -repo and -debug are mesh-export options and have
///   no STEP equivalent.)

///|
let deg : Double = @math.PI / 180.0

///|
let points_in_involute : Int32 = 20

///|
let two_pi : Double = 2.0 * @math.PI

///|
/// Maximum profile rotation (degrees) between adjacent swept cross-sections.
/// Each adjacent pair becomes a ring of planar quads approximating the twisted
/// surface, so this bounds how far a quad can cut inside the true helix.
/// 24 deg keeps the chord sagitta below ~2% of the gear radius, which is about
/// the faceting the Blackjack mesh uses at its default settings.
let max_sweep_step_deg : Double = 24.0

///|
struct GearDims {
  num_teeth : Int32
  pitch_radius : Double
  base_radius : Double
  root_radius : Double
  outer_radius : Double
}

///|
struct PlanetPlacement {
  x : Double
  z : Double
  phi_deg : Double
}

///|
struct GearboxConfig {
  gear_module : Double
  gear_length : Double
  helix_angle_deg : Double
  helix_angle_sun : Double
  pressure_angle : Double
  num_elbows : Int32
  resolution : Int32
  hole_type : String
  hole_radius : Double
  tolerance : Double
  outer_thickness : Double
  sun : GearDims
  planet : GearDims
  ring : GearDims
  ring_teeth : Int32
  center_distance : Double
  center_delta : Double
  sun_direction : Double
  planet_direction : Double
  planets : Array[PlanetPlacement]
}

///|
struct GearParams {
  gear_module : Double
  gear_length : Double
  helix_angle : Double
  hole_radius : Double
  hole_type : String
  num_elbows : Int32
  num_teeth : Int32
  num_planets : Int32
  planet_teeth : Int32
  pressure_angle : Double
  ring_teeth : Int32
  tolerance : Double
  outer_thickness : Double
  resolution : Int32
}

///|
struct RingGeometry {
  /// Inner (toothed) profile in the XZ plane, clockwise.
  inner : Array[(Double, Double)]
  outer_radius : Double
  /// Angular phase that aligns the ring teeth with planet 0.
  phase : Double
  ring_scale : Double
  max_helix_mate : Double
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

///|
async fn main {
  let args_spec = {
    "module": @cli.opt_double(
      3.0,
      short='m',
      help="Gear module (tooth size), see https://www.stlgears.com/theory#module",
    ),
    "gearLength": @cli.opt_double(30.0, short='g', help="Gear length (mm)"),
    "helixAngle": @cli.opt_double(
      30.0,
      short='a',
      help="Helix angle in degrees (clamped to 0..45)",
    ),
    "holeRadius": @cli.opt_double(
      10.0,
      short='r',
      help="Hole minimum radius (mm)",
    ),
    "holeType": @cli.opt_string(
      short='t',
      help="Hole type: None, Squared, Hexagonal, Octagonal, Circular",
    ),
    "numElbows": @cli.opt_int(
      4,
      short='e',
      help="Number of elbows in each herringbone gear",
    ),
    "numTeeth": @cli.opt_int(
      12,
      short='n',
      help="Number of teeth on the sun gear",
    ),
    "numPlanets": @cli.opt_int(
      3,
      short='p',
      help="Number of orbiting planet gears",
    ),
    "planetTeeth": @cli.opt_int(
      0,
      short='P',
      help="Number of teeth on each planet gear (0 means same as --numTeeth)",
    ),
    "pressureAngle": @cli.opt_double(
      20.0,
      short='A',
      help="Pressure angle in degrees",
    ),
    "ringTeeth": @cli.opt_int(
      0,
      short='R',
      help="Number of teeth on the ring gear (0 means sun + 2*planet)",
    ),
    "tolerance": @cli.opt_double(
      0.25,
      short='T',
      help="Target minimum 3D-printer clearance between meshing flanks (mm)",
    ),
    "outerThickness": @cli.opt_double(
      10.0,
      short='w',
      help="Radial wall thickness from the closest ring notch to the outer surface (mm)",
    ),
    "resolution": @cli.opt_int(
      9,
      short='s',
      help="Number of points in each curved section of the tooth outline",
    ),
    "out": @cli.opt_string(
      short='o',
      help="Write output to a file (default: stdout)",
    ),
    "yUp": @cli.flag(
      help="Keep the native Y-up orientation (gear axes along +Y) instead of rotating the design flat for printing",
    ),
  }
  guard @cli.parse(
      args_spec,
      prog="38-planetary-gearbox",
      description="Generate a print-in-place herringbone planetary gearbox.",
    )
    is Some(args) else {
    return
  }
  let hole_type = args.string_opt("holeType").unwrap_or("None")
  let params : GearParams = {
    gear_module: args.double("module"),
    gear_length: args.double("gearLength"),
    helix_angle: args.double("helixAngle"),
    hole_radius: args.double("holeRadius"),
    hole_type,
    num_elbows: args.int("numElbows"),
    num_teeth: args.int("numTeeth"),
    num_planets: args.int("numPlanets"),
    planet_teeth: args.int("planetTeeth"),
    pressure_angle: args.double("pressureAngle"),
    ring_teeth: args.int("ringTeeth"),
    tolerance: args.double("tolerance"),
    outer_thickness: args.double("outerThickness"),
    resolution: args.int("resolution"),
  }
  let out_path = args.string_opt("out")
  let y_up = args.flag("yUp")
  let cfg = compute_config(params)
  let design = build_design(cfg, args.documentation(), y_up~)
  if out_path is Some(_) {
    print_config(cfg)
  }
  design.write_step(out_path)
}

///|
async fn fail(msg : String) -> Unit {
  @cli.eprintln("error: " + msg)
  abort("")
}

///|
async fn print_config(cfg : GearboxConfig) -> Unit {
  @cli.eprintln(
    "sun:    teeth=\{cfg.sun.num_teeth} pitch_radius=\{cfg.sun.pitch_radius} base_radius=\{cfg.sun.base_radius} root_radius=\{cfg.sun.root_radius} outer_radius=\{cfg.sun.outer_radius}",
  )
  @cli.eprintln(
    "planet: teeth=\{cfg.planet.num_teeth} pitch_radius=\{cfg.planet.pitch_radius} base_radius=\{cfg.planet.base_radius} root_radius=\{cfg.planet.root_radius} outer_radius=\{cfg.planet.outer_radius}",
  )
  @cli.eprintln(
    "ring:   teeth=\{cfg.ring.num_teeth} pitch_radius=\{cfg.ring.pitch_radius} base_radius=\{cfg.ring.base_radius} nominal_tooth_tip=\{cfg.ring.outer_radius} nominal_notch=\{cfg.ring.root_radius}",
  )
  @cli.eprintln(
    "center distance (sun-planet and ring-planet): \{cfg.center_distance} (zero-backlash center distance + \{cfg.center_delta})",
  )
  @cli.eprintln(
    "target minimum clearance: \{cfg.tolerance}, outer thickness: \{cfg.outer_thickness}",
  )
  for i, p in cfg.planets {
    @cli.eprintln(
      "planet \{i}: pos=(\{p.x}, 0, \{p.z}) rotation=\{p.phi_deg} deg",
    )
  }
  @cli.eprintln(
    "helix angle: \{cfg.helix_angle_deg} deg (sun generator: \{cfg.helix_angle_sun} deg)",
  )
}

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

///|
async fn compute_config(p : GearParams) -> GearboxConfig {
  if p.gear_module <= 0.0 {
    fail("--module must be > 0")
  }
  if p.gear_length <= 0.0 {
    fail("--gearLength must be > 0")
  }
  if p.num_teeth < 6 {
    fail("--numTeeth must be >= 6 (Blackjack's HerringboneGear minimum)")
  }
  if p.num_elbows < 1 {
    fail("--numElbows must be >= 1")
  }
  if p.resolution < 1 {
    fail("--resolution must be >= 1")
  }
  if p.num_planets < 1 {
    fail("--numPlanets must be >= 1")
  }
  if p.pressure_angle < 1.0 {
    fail("--pressureAngle must be >= 1")
  }
  if p.tolerance < 0.0 {
    fail("--tolerance must be >= 0")
  }
  if p.outer_thickness <= 0.0 {
    fail("--outerThickness must be > 0")
  }
  if p.hole_type == "Hollow" {
    fail(
      "--holeType=Hollow describes an open shell (no top or bottom cap) and cannot be written as a solid STEP body; use None or one of Squared, Hexagonal, Octagonal, Circular",
    )
  }

  let planet_teeth = if p.planet_teeth == 0 {
    p.num_teeth
  } else {
    p.planet_teeth
  }
  if planet_teeth < 6 {
    fail("--planetTeeth must be >= 6 (or 0 to use --numTeeth)")
  }

  let ring_teeth = if p.ring_teeth == 0 {
    p.num_teeth + 2 * planet_teeth
  } else {
    p.ring_teeth
  }
  if ring_teeth != p.num_teeth + 2 * planet_teeth {
    fail(
      "--ringTeeth (\{ring_teeth}) must equal --numTeeth + 2*--planetTeeth = \{p.num_teeth} + 2*\{planet_teeth} = \{p.num_teeth + 2 * planet_teeth} for a standard internal mesh",
    )
  }

  // Assembly condition for equally-spaced planets.
  if (p.num_teeth + ring_teeth) % p.num_planets != 0 {
    let suggested = suggest_planet_teeth(p.num_teeth, p.num_planets)
    fail(
      "tooth counts (sun=\{p.num_teeth}, planet=\{planet_teeth}, ring=\{ring_teeth}) cannot be equally spaced in \{p.num_planets} positions: (sun+ring)=\{p.num_teeth + ring_teeth} must be divisible by \{p.num_planets}.\n  With all four inner gears identical, this requires --numTeeth to be divisible by 3.\n  Try: --numTeeth 12, --numTeeth 15, or --planetTeeth \{suggested} (ring=\{p.num_teeth + 2 * suggested})",
    )
  }

  let pa = p.pressure_angle * deg
  let ha = clamp(p.helix_angle, 0.0, 45.0) * deg

  let sun = new_gear_dims(p.gear_module, pa, p.num_teeth)
  let planet = new_gear_dims(p.gear_module, pa, planet_teeth)
  let ring_nominal = new_gear_dims(p.gear_module, pa, ring_teeth)
  // Nominal internal-gear radii for reporting.
  let ring : GearDims = {
    ..ring_nominal,
    root_radius: ring_nominal.pitch_radius + p.gear_module,
    outer_radius: ring_nominal.pitch_radius - 1.25 * p.gear_module,
  }

  if p.hole_type != "None" {
    if p.hole_radius >= sun.root_radius || p.hole_radius >= planet.root_radius {
      fail(
        "--holeRadius (\{p.hole_radius}) must be less than the gear root radius (sun=\{sun.root_radius}, planet=\{planet.root_radius})",
      )
    }
  }

  // Increase the sun/planet center distance so the actual normal flank
  // clearance is the requested tolerance. The same center distance is used
  // for the ring envelope.
  let center_delta = if p.tolerance > 0.0 { p.tolerance * 2.0 } else { 0.0 }
  let center_distance = sun.pitch_radius + planet.pitch_radius + center_delta

  // Match the helix angle at the pitch circle. The Lua node defines the helix
  // angle at the outer radius, so the pitch-circle angle is
  // tan(beta_pitch) = tan(ha) * N/(N+2).
  let tan_beta_pitch = @math.tan(ha) *
    planet_teeth.to_double() /
    (planet_teeth + 2).to_double()
  let helix_angle_sun = clamp(
    @math.atan(
      tan_beta_pitch * (p.num_teeth + 2).to_double() / p.num_teeth.to_double(),
    ) /
    deg,
    0.0,
    45.0,
  )

  // Sun phase is 0: tooth 0 of the sun points along +X.
  let sun_direction = 1.0
  let planet_direction = -1.0 // opposite to the sun for an external mesh

  // Place the planets and compute their rotations.
  let planets : Array[PlanetPlacement] = []
  for j in 0..<p.num_planets {
    let theta = two_pi * j.to_double() / p.num_planets.to_double()
    let s = frac(p.num_teeth.to_double() * theta / two_pi)
    // External sun/planet mesh: frac_sun(theta) + frac_planet(theta+pi) = 1/2.
    let phi = theta + @math.PI - two_pi / planet_teeth.to_double() * (0.5 - s)
    planets.push({
      x: center_distance * @math.cos(theta),
      z: center_distance * @math.sin(theta),
      phi_deg: norm_angle(phi) / deg,
    })
  }

  {
    gear_module: p.gear_module,
    gear_length: p.gear_length,
    helix_angle_deg: ha / deg,
    helix_angle_sun,
    pressure_angle: p.pressure_angle,
    num_elbows: p.num_elbows,
    resolution: p.resolution,
    hole_type: p.hole_type,
    hole_radius: p.hole_radius,
    tolerance: p.tolerance,
    outer_thickness: p.outer_thickness,
    sun,
    planet,
    ring,
    ring_teeth,
    center_distance,
    center_delta,
    sun_direction,
    planet_direction,
    planets,
  }
}

///|
fn new_gear_dims(
  gear_module : Double,
  pressure_angle : Double,
  num_teeth : Int32,
) -> GearDims {
  let pitch = gear_module * num_teeth.to_double() / 2.0
  {
    num_teeth,
    pitch_radius: pitch,
    base_radius: pitch * @math.cos(pressure_angle),
    root_radius: pitch - 1.25 * gear_module,
    outer_radius: pitch + gear_module,
  }
}

///|
/// suggest_planet_teeth returns a planet tooth count close to sun_teeth that
/// makes (sun + ring) = 2*(sun + planet) divisible by the number of planets.
fn suggest_planet_teeth(sun_teeth : Int32, planets : Int32) -> Int32 {
  for offset in 1..<20 {
    for candidate in [sun_teeth - offset, sun_teeth + offset] {
      if candidate < 6 {
        continue
      }
      let ring = sun_teeth + 2 * candidate
      if (sun_teeth + ring) % planets == 0 {
        return candidate
      }
    }
  }
  sun_teeth
}

// ---------------------------------------------------------------------------
// Design
// ---------------------------------------------------------------------------

///|
fn build_design(
  cfg : GearboxConfig,
  documentation : String,
  y_up~ : Bool = false,
) -> @cad.Design {
  let mut design = @cad.Design::new(
    name="planetary-gearbox",
    description="Print-in-place herringbone planetary gearbox",
    documentation~,
  )

  // Sun gear.
  //
  // Fabrication sites and most slicers treat +Z as up, while the gear axes here
  // run along +Y. Rotate the whole design +90 deg about X to lay it flat on the
  // build plate: Rx(90) maps (x, y, z) -> (x, -z, y), so the 30 mm gear length
  // becomes the print height instead of the 136 mm ring diameter. `--yUp`
  // keeps the native orientation.
  let sun_outline = gear_outline(
    cfg.gear_module,
    cfg.pressure_angle,
    cfg.sun.num_teeth,
    cfg.resolution,
  )
  let sun_max_rot = @math.tan(deg2rad(cfg.helix_angle_sun)) *
    (cfg.gear_length / 2.0) /
    cfg.sun.outer_radius
  let sun_node = make_gear_shape(
      sun_outline,
      gear_holes(cfg, cfg.sun),
      cfg.gear_length,
      cfg.num_elbows,
      sun_max_rot,
      cfg.sun_direction,
      straight_holes=true,
      straight_outline=false,
    )
    .with_name("sun")
    .with_color(@cad.Rgb::orange())
  let sun_node = if y_up { sun_node } else { sun_node.rotate_x(90.0) }

  // Planets.
  let planet_outline = gear_outline(
    cfg.gear_module,
    cfg.pressure_angle,
    cfg.planet.num_teeth,
    cfg.resolution,
  )
  let planet_holes = gear_holes(cfg, cfg.planet)
  let planet_max_rot = @math.tan(deg2rad(cfg.helix_angle_deg)) *
    (cfg.gear_length / 2.0) /
    cfg.planet.outer_radius
  let planet_nodes : Array[@cad.SceneNode] = []
  for j, p in cfg.planets {
    let node = make_gear_shape(
        planet_outline,
        planet_holes,
        cfg.gear_length,
        cfg.num_elbows,
        planet_max_rot,
        cfg.planet_direction,
        straight_holes=true,
        straight_outline=false,
      )
      .with_name("planet-\{j}")
      .with_color(@cad.Rgb::blue())
    // The Lua rotates about +Y as (x,z) -> (x cos t - z sin t, x sin t + z cos t),
    // which is the CAD rotate_y by -t. Under the global Rx(90) above that
    // becomes Rz(-t)*Rx(90), and the placement (x, 0, z) becomes (x, -z, 0).
    let placed = if y_up {
      node.rotate_y(-p.phi_deg).translate(x=p.x, z=p.z)
    } else {
      node.rotate_x(90.0).rotate_z(-p.phi_deg).translate(x=p.x, y=-p.z)
    }
    planet_nodes.push(placed)
  }

  // Ring gear: a smooth outer cylinder with the inward-facing toothed profile
  // as a through hole. Its twist follows the mating planet at the pitch point.
  let ring = ring_geometry(cfg)
  let outer_circle = circle_outline(ring.outer_radius, cfg.resolution * 8, true)
  let inner_ccw = ring.inner.map(fn(pt) { rotate_xz(pt, ring.phase) }).rev()
  let ring_node = make_gear_shape(
      outer_circle,
      [inner_ccw],
      cfg.gear_length,
      cfg.num_elbows,
      ring.ring_scale * ring.max_helix_mate,
      cfg.planet_direction,
    )
    .with_name("ring")
    .with_color(@cad.Rgb::grey())
  let ring_node = if y_up { ring_node } else { ring_node.rotate_x(90.0) }

  design = design.add(sun_node)
  for node in planet_nodes {
    design = design.add(node)
  }
  design.add(ring_node)
}

///|
/// make_gear_shape builds a single solid by sweeping the gear outline through
/// `num_elbows + 1` linearly twisted extrusions.
///
/// `outline` and `holes` are in the XZ plane. `max_rotation` is the profile
/// rotation at an elbow vertex (radians); the first cross-section is at
/// rotation 0 and each following elbow alternates between 0 and max_rotation,
/// which reproduces the HerringboneGear's zig-zag.
///
/// `straight_outline` and `straight_holes` keep the corresponding loop aligned
/// with the first cross-section. External gears twist their outline and keep
/// their bore straight; the ring gear twists its toothed hole and keeps the
/// outer wall straight.
fn make_gear_shape(
  outline : Array[(Double, Double)],
  holes : Array[Array[(Double, Double)]],
  gear_length : Double,
  num_elbows : Int32,
  max_rotation : Double,
  direction : Double,
  straight_holes~ : Bool = false,
  straight_outline~ : Bool = true,
) -> @cad.Shape {
  let path = gear_sweep_path(gear_length, num_elbows, max_rotation, direction)
  let profile = @cad.SweepProfile::new(
    profile_points(outline),
    holes=holes.map(fn(hole) { profile_points(hole) }),
    normal_dir=(0.0, 0.0, 1.0),
    right_dir=(1.0, 0.0, 0.0),
  )
  @cad.SweptProfile::new(path~, profile~, straight_holes~, straight_outline~)
}

///|
/// gear_sweep_path returns the zig-zag cross-section path through the gear
/// length. Each of the `num_elbows + 1` chunks twists linearly from its start
/// rotation to its end rotation.
///
/// A chunk is subdivided into enough steps that each ring of swept side faces
/// spans at most `max_sweep_step_deg` of profile rotation. A ring of planar
/// quads approximates the twisted (helical) surface; when a single quad spans
/// a large rotation its corners are far from coplanar and the face folds
/// through itself. That is harmless for typical gears (one step at module 3),
/// but a small module with a long gear twists hundreds of degrees per chunk -
/// module 0.5 with gearLength 30 rotates 141.8 deg per elbow - and needs
/// subdivision to stay valid.
fn gear_sweep_path(
  gear_length : Double,
  num_elbows : Int32,
  max_rotation : Double,
  direction : Double,
) -> @cad.SweepPath {
  let chunks = num_elbows + 1
  let max_step = max_sweep_step_deg * deg
  let steps = if max_rotation <= max_step {
    1
  } else {
    let n = @math.ceil(max_rotation / max_step).to_int()
    if n < 1 {
      1
    } else {
      n
    }
  }
  let total = chunks * steps
  let points : Array[@cad.Vec3] = []
  let normals : Array[@cad.Vec3] = []
  let tangents : Array[@cad.Vec3] = []
  for i in 0..<(total + 1) {
    let y = gear_length * i.to_double() / total.to_double()
    let chunk = if i == total { chunks - 1 } else { i / steps }
    let within = if i == total {
      1.0
    } else {
      (i % steps).to_double() / steps.to_double()
    }
    let start_rotation = if chunk % 2 == 0 { 0.0 } else { max_rotation }
    let end_rotation = if chunk % 2 == 0 { max_rotation } else { 0.0 }
    let helix_rotation = start_rotation +
      (end_rotation - start_rotation) * within
    let angle = -direction * helix_rotation
    points.push((0.0, y, 0.0))
    normals.push((@math.cos(angle), 0.0, @math.sin(angle)))
    tangents.push((0.0, 1.0, 0.0))
  }
  { points, normals, tangents, }
}

///|
/// profile_points converts XZ-plane points into the sweep profile frame.
///
/// With `normal_dir=(0,0,1)` and `right_dir=(1,0,0)`, a profile point
/// (x, y, 0) maps to `x*right + y*normal`, so passing (-z, x, 0) makes the
/// swept cross-section equal to `rotate_xz((x, z), angle)`.
fn profile_points(pts : Array[(Double, Double)]) -> Array[@cad.Vec3] {
  pts.map(fn(pt) { (-pt.1, pt.0, 0.0) })
}

// ---------------------------------------------------------------------------
// Gear outlines
// ---------------------------------------------------------------------------

///|
/// gear_outline returns the complete external-gear boundary in the XZ plane,
/// clockwise, exactly as the HerringboneGear node builds its tooth faces:
/// involute flanks, tip arc, mirrored flank, and the root arc to the next
/// tooth.
fn gear_outline(
  gear_module : Double,
  pressure_angle_deg : Double,
  num_teeth : Int32,
  resolution : Int32,
) -> Array[(Double, Double)] {
  let pa = deg2rad(pressure_angle_deg)
  let n = num_teeth.to_double()
  let pitch_radius = gear_module * n / 2.0
  let base_radius = pitch_radius * @math.cos(pa)
  let root_radius = pitch_radius - 1.25 * gear_module
  let outer_radius = pitch_radius + gear_module

  // Angular extent of the tooth on the base radius.
  let backlash = 0.25 * @math.PI * @math.cos(pa) / (n * gear_module)
  let pitch_point = involute_xz(
    base_radius,
    involute_theta(base_radius, pitch_radius),
  )
  let face_angle = @math.atan2(pitch_point.1, pitch_point.0)
  let backlash_angle = backlash / (2.0 * pitch_radius)
  let center_angle = @math.PI / (2.0 * n) + face_angle - backlash_angle

  // Angles over which the involute is used.
  let start_angle = involute_theta(
    base_radius,
    if root_radius > base_radius {
      root_radius
    } else {
      base_radius
    },
  )
  let stop_angle = involute_theta(base_radius, outer_radius)
  let d_theta = (stop_angle - start_angle) / points_in_involute.to_double()

  let inv : Array[(Double, Double)] = []
  if root_radius < base_radius {
    inv.push(rotate_xz((root_radius, 0.0), -center_angle))
  }
  let mut angle = start_angle
  for _i in 0..<(points_in_involute + 1) {
    inv.push(rotate_xz(involute_xz(base_radius, angle), -center_angle))
    angle = angle + d_theta
  }
  let num_facets = inv.length()

  // Arc across the outer tooth edge.
  let arc_tip = inv[num_facets - 1]
  let arc_tip_angle = Double::abs(@math.atan2(arc_tip.1, arc_tip.0))
  for i in 1..<resolution {
    let phi = -arc_tip_angle +
      2.0 * arc_tip_angle * i.to_double() / resolution.to_double()
    inv.push(rotate_xz((outer_radius, 0.0), phi))
  }

  // Upper tooth face (mirror the lower points across the X axis).
  for i in 1..<=num_facets {
    let pt = inv[num_facets - i]
    inv.push((pt.0, -pt.1))
  }

  // Gap between adjacent teeth.
  let first_angle = @math.atan2(inv[0].1, inv[0].0)
  let last_angle = @math.atan2(inv[inv.length() - 1].1, inv[inv.length() - 1].0)
  let involute_arc_angle = Double::abs(last_angle - first_angle)
  let gap_arc_angle = two_pi / n - involute_arc_angle
  let gap_delta = gap_arc_angle / resolution.to_double()

  // Walk clockwise: each tooth from its upper flange to its lower root, then
  // the root arc on to the next tooth. The Blackjack mesh emits the same faces
  // tooth by tooth; here they form one closed outline.
  let outline : Array[(Double, Double)] = []
  let num_inv = inv.length()
  for i in 0..<num_teeth {
    let theta = -i.to_double() * two_pi / n
    for k in 0..<num_inv {
      outline.push(rotate_xz(inv[num_inv - 1 - k], theta))
    }
    let lower_root = rotate_xz(inv[0], theta)
    for j in 1..<resolution {
      outline.push(rotate_xz(lower_root, -j.to_double() * gap_delta))
    }
  }
  clean_polygon(outline, 1.0e-4)
}

///|
/// external_gear_boundary returns the complete clockwise outer boundary of an
/// external involute gear. Unlike gear_outline it does not add the tip arc,
/// matching the helper used for the internal (ring) gear envelope.
fn external_gear_boundary(
  gear_module : Double,
  pressure_angle_deg : Double,
  num_teeth : Int32,
  root_radius : Double,
  outer_radius : Double,
  resolution : Int32,
) -> Array[(Double, Double)] {
  let pa = deg2rad(pressure_angle_deg)
  let n = num_teeth.to_double()
  let pitch_radius = gear_module * n / 2.0
  let base_radius = pitch_radius * @math.cos(pa)
  let face_angle = @math.tan(pa) - pa
  let backlash = 0.25 * @math.PI * @math.cos(pa) / (n * gear_module)
  let backlash_angle = backlash / (2.0 * pitch_radius)
  let center_angle = @math.PI / (2.0 * n) + face_angle - backlash_angle

  let start_angle = involute_theta(
    base_radius,
    if root_radius > base_radius {
      root_radius
    } else {
      base_radius
    },
  )
  let stop_angle = involute_theta(base_radius, outer_radius)
  let d_theta = (stop_angle - start_angle) / points_in_involute.to_double()

  let inv : Array[(Double, Double)] = []
  if root_radius < base_radius {
    inv.push(rotate_xz((root_radius, 0.0), -center_angle))
  }
  let mut angle = start_angle
  for _i in 0..<(points_in_involute + 1) {
    inv.push(rotate_xz(involute_xz(base_radius, angle), -center_angle))
    angle = angle + d_theta
  }
  let num_facets = inv.length()

  // Arc across the outer tooth edge.
  let arc_tip = inv[num_facets - 1]
  let arc_tip_angle = Double::abs(@math.atan2(arc_tip.1, arc_tip.0))
  for i in 1..<resolution {
    let phi = -arc_tip_angle +
      2.0 * arc_tip_angle * i.to_double() / resolution.to_double()
    inv.push(rotate_xz((outer_radius, 0.0), phi))
  }

  // Mirror the tooth (num_facets covers only the root + lower flank, as in the
  // Lua node, so the mirrored flank starts at the tip of the lower involute).
  for i in 1..<=num_facets {
    let pt = inv[num_facets - i]
    inv.push((pt.0, -pt.1))
  }

  let first_angle = @math.atan2(inv[0].1, inv[0].0)
  let last_angle = @math.atan2(inv[inv.length() - 1].1, inv[inv.length() - 1].0)
  let involute_arc_angle = Double::abs(last_angle - first_angle)
  let gap_arc_angle = two_pi / n - involute_arc_angle
  let gap_delta = gap_arc_angle / resolution.to_double()

  let profile : Array[(Double, Double)] = []
  let num_inv = inv.length()
  for tooth in 0..<num_teeth {
    let tooth_angle = -two_pi * tooth.to_double() / n
    // Walk clockwise: upper root through the tip to the lower root.
    for k in 1..<=num_inv {
      profile.push(rotate_xz(inv[num_inv - k], tooth_angle))
    }
    let lower_root = rotate_xz(inv[0], tooth_angle)
    for j in 1..<resolution {
      profile.push(rotate_xz(lower_root, -j.to_double() * gap_delta))
    }
  }
  profile
}

///|
/// ring_geometry builds the ring's inner boundary as the outer boundary of a
/// phantom external gear with the ring tooth count. For an internal gear the
/// addendum and dedendum are reversed, so the phantom's root radius is the
/// ring tooth tip and its tip radius is the ring notch.
fn ring_geometry(cfg : GearboxConfig) -> RingGeometry {
  let gear_module = cfg.gear_module
  let n = cfg.ring_teeth.to_double()
  let ring_pitch = gear_module * n / 2.0
  let mate_pitch = gear_module * cfg.planet.num_teeth.to_double() / 2.0
  let mate_outer = mate_pitch + gear_module

  // Compensate for an increased ring/planet center distance.
  let nominal_center = ring_pitch - mate_pitch
  let center = if cfg.center_distance <= 0.0 {
    nominal_center
  } else {
    cfg.center_distance
  }
  let center_delta = if center > nominal_center {
    center - nominal_center
  } else {
    0.0
  }

  // Internal gear addendum/dedendum: use the standard shortened internal
  // addendum (tooth tip 1.0*module inside the pitch circle) and root/notch
  // 1.0*module outside it.
  let phantom_root = ring_pitch - gear_module
  let phantom_tip = ring_pitch + gear_module
  let profile = external_gear_boundary(
    gear_module,
    cfg.pressure_angle,
    cfg.ring_teeth,
    phantom_root,
    phantom_tip,
    cfg.resolution,
  )
  let profile = clean_polygon(profile, 1.0e-4)

  let mut max_r = 0.0
  for pt in profile {
    let r = radius_of(pt)
    if r > max_r {
      max_r = r
    }
  }

  // Apply the clearance as a smooth radial offset. A radial offset of d
  // produces a normal flank clearance of d*sin(pressure_angle).
  let radial_offset = center_delta +
    cfg.tolerance / @math.sin(deg2rad(cfg.pressure_angle))
  let offset_profile = profile.map(fn(pt) {
    let r = radius_of(pt)
    if r > 0.0 {
      let s = (r + radial_offset) / r
      (pt.0 * s, pt.1 * s)
    } else {
      pt
    }
  })
  let inner = clean_polygon(offset_profile, 1.0e-4)
  let outer_radius = max_r + radial_offset + cfg.outer_thickness

  // Align the phantom's tooth centers with the mating planet's tooth centers
  // at the ring/planet pitch point.
  let mate_pitch_angle = two_pi / cfg.planet.num_teeth.to_double()
  let ring_pitch_angle = two_pi / n
  let mate_rotation = deg2rad(cfg.planets[0].phi_deg)
  let mut phase = ring_pitch_angle * dmod(mate_rotation / mate_pitch_angle, 1.0)
  if phase < 0.0 {
    phase = phase + ring_pitch_angle
  }

  let max_helix_mate = @math.tan(deg2rad(cfg.helix_angle_deg)) *
    (cfg.gear_length / 2.0) /
    mate_outer
  {
    inner,
    outer_radius,
    phase,
    ring_scale: mate_pitch / ring_pitch,
    max_helix_mate,
  }
}

///|
/// gear_holes returns the central hole outlines for an external gear, wound
/// counter-clockwise (opposite to the gear outline).
fn gear_holes(
  cfg : GearboxConfig,
  g : GearDims,
) -> Array[Array[(Double, Double)]] {
  let hole_type = cfg.hole_type
  if hole_type == "None" {
    []
  } else if hole_type == "Circular" {
    [circle_outline(cfg.hole_radius, g.num_teeth * cfg.resolution, false)]
  } else if hole_type == "Squared" {
    [polygon_hole(4, cfg.hole_radius)]
  } else if hole_type == "Hexagonal" {
    [polygon_hole(6, cfg.hole_radius)]
  } else if hole_type == "Octagonal" {
    [polygon_hole(8, cfg.hole_radius)]
  } else {
    []
  }
}

///|
/// polygon_hole returns a regular polygon with the given inradius, with its
/// vertices on the X axis (matching the HerringboneGear hole generators).
fn polygon_hole(sides : Int32, inradius : Double) -> Array[(Double, Double)] {
  let circumradius = inradius / @math.cos(@math.PI / sides.to_double())
  let pts : Array[(Double, Double)] = []
  for i in 0..<sides {
    let a = two_pi * i.to_double() / sides.to_double()
    pts.push((circumradius * @math.cos(a), circumradius * @math.sin(a)))
  }
  pts
}

///|
fn circle_outline(
  radius : Double,
  segments : Int32,
  clockwise : Bool,
) -> Array[(Double, Double)] {
  let n = if segments < 3 { 3 } else { segments }
  let pts : Array[(Double, Double)] = []
  for i in 0..<n {
    let a = two_pi * i.to_double() / n.to_double()
    let angle = if clockwise { -a } else { a }
    pts.push((radius * @math.cos(angle), radius * @math.sin(angle)))
  }
  pts
}

// ---------------------------------------------------------------------------
// Geometry helpers
// ---------------------------------------------------------------------------

///|
fn deg2rad(degrees : Double) -> Double {
  degrees * deg
}

///|
fn clamp(value : Double, lo : Double, hi : Double) -> Double {
  if value < lo {
    lo
  } else if value > hi {
    hi
  } else {
    value
  }
}

///|
fn frac(x : Double) -> Double {
  x - x.floor()
}

///|
fn dmod(a : Double, b : Double) -> Double {
  a - b * (a / b).floor()
}

///|
fn norm_angle(a : Double) -> Double {
  let mut angle = dmod(a, two_pi)
  if angle < 0.0 {
    angle = angle + two_pi
  }
  angle
}

///|
fn radius_of(pt : (Double, Double)) -> Double {
  Double::sqrt(pt.0 * pt.0 + pt.1 * pt.1)
}

///|
fn sq_dist(a : (Double, Double), b : (Double, Double)) -> Double {
  let dx = a.0 - b.0
  let dz = a.1 - b.1
  dx * dx + dz * dz
}

///|
/// rotate_xz rotates a point in the XZ plane by `theta`, matching the Lua
/// node's rotate_point.
fn rotate_xz(pt : (Double, Double), theta : Double) -> (Double, Double) {
  let c = @math.cos(theta)
  let s = @math.sin(theta)
  (c * pt.0 - s * pt.1, s * pt.0 + c * pt.1)
}

///|
fn involute_xz(radius : Double, theta : Double) -> (Double, Double) {
  let c = @math.cos(theta)
  let s = @math.sin(theta)
  (radius * (c + theta * s), radius * (s - theta * c))
}

///|
fn involute_theta(radius : Double, distance : Double) -> Double {
  let x = distance / radius
  Double::sqrt(x * x - 1.0)
}

///|
/// clean_polygon removes consecutive and seam points closer than eps
/// (squared distance eps2), preventing degenerate STEP faces.
fn clean_polygon(
  pts : Array[(Double, Double)],
  eps2 : Double,
) -> Array[(Double, Double)] {
  let out : Array[(Double, Double)] = []
  for pt in pts {
    let keep = out.length() == 0 || sq_dist(out[out.length() - 1], pt) > eps2
    if keep {
      out.push(pt)
    }
  }
  while out.length() > 1 && sq_dist(out[0], out[out.length() - 1]) <= eps2 {
    let _ = out.pop()
  }
  out
}
