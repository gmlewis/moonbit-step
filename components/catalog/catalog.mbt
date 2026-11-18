///|
/// CatalogEntry is one machine-readable catalogue record.
///
/// It carries the same identity and provenance as the component metadata plus
/// the supported parameters, detail levels, and the component's
/// `FeatureRecord`. A BOM or search tool can therefore answer "what does this
/// designation support, and what is modeled?" without generating geometry.
pub(all) struct CatalogEntry {
  designation : String
  standard : String
  family : String
  size : String
  supported_parameters : Array[String]
  detail_levels : Array[String]
  features : @common.FeatureRecord
  provenance : String
}

///|
/// CatalogError reports a failed catalogue lookup.
pub(all) enum CatalogError {
  UnknownDesignation(String)
}

///|
/// CatalogError::message returns a human-readable diagnostic.
pub fn CatalogError::message(self : CatalogError) -> String {
  match self {
    UnknownDesignation(name) => "no catalogue entry for designation '\{name}'"
  }
}

///|
fn entry_from_component(
  component : @common.Component,
  supported_parameters : Array[String],
  detail_levels : Array[String],
) -> CatalogEntry {
  let metadata = component.metadata()
  {
    designation: metadata.designation,
    standard: metadata.standard,
    family: metadata.family,
    size: metadata.size,
    supported_parameters,
    detail_levels,
    features: component.features(),
    provenance: metadata.source,
  }
}

///|
/// supported_fastener_parameters lists the fasteners catalogue parameters.
fn supported_fastener_parameters() -> Array[String] {
  ["standard", "size", "length", "detail", "threads"]
}

///|
/// fastener_catalog returns a representative Detailed catalogue entry for each
/// supported ISO fastener size.
///
/// The entries are built from the real component builders, so their feature
/// records and provenance cannot drift from the generated parts.
pub fn fastener_catalog() -> Array[CatalogEntry] {
  let entries : Array[CatalogEntry] = []
  let details = ["Simplified", "Detailed", "FullyModeled"]
  for size in [@standards.M3, @standards.M4, @standards.M5] {
    let length = size.nominal_diameter_mm() * 5.0
    match @fasteners.iso4762_screw(size, length, detail=@common.Detailed) {
      Ok(c) =>
        entries.push(
          entry_from_component(c, supported_fastener_parameters(), details),
        )
      Err(_) => ()
    }
    match @fasteners.iso4032_nut(size, detail=@common.Detailed) {
      Ok(c) =>
        entries.push(
          entry_from_component(
            c,
            ["standard", "size", "detail", "threads", "clearance_mm"],
            details,
          ),
        )
      Err(_) => ()
    }
    match @fasteners.iso7089_washer(size, detail=@common.Detailed) {
      Ok(c) =>
        entries.push(
          entry_from_component(c, ["standard", "size", "detail"], details),
        )
      Err(_) => ()
    }
  }
  entries
}

///|
/// bearing_catalog returns a Detailed catalogue entry for every supported
/// bearing designation.
pub fn bearing_catalog() -> Array[CatalogEntry] {
  let entries : Array[CatalogEntry] = []
  for designation in @motion.bearing_designations() {
    match @motion.bearing_by_designation(designation, detail=@common.Detailed) {
      Ok(c) =>
        entries.push(
          entry_from_component(c, ["bearing", "rollers", "detail"], [
            "Simplified", "Detailed", "FullyModeled",
          ]),
        )
      Err(_) => ()
    }
  }
  entries
}

///|
/// profile_catalog returns a catalogue entry for each generic extrusion series.
pub fn profile_catalog() -> Array[CatalogEntry] {
  let entries : Array[CatalogEntry] = []
  for
    profile in [
      @profiles.TSlotProfile::generic_2020(),
      @profiles.TSlotProfile::generic_2040(),
      @profiles.TSlotProfile::generic_2060(),
      @profiles.TSlotProfile::generic_2080(),
      @profiles.TSlotProfile::generic_3030(),
      @profiles.TSlotProfile::generic_3060(),
      @profiles.TSlotProfile::generic_4040(),
      @profiles.TSlotProfile::generic_4080(),
    ] {
    match @profiles.extrusion(profile, 100.0, detail=@common.Simplified) {
      Ok(c) =>
        entries.push(
          entry_from_component(
            c,
            ["series", "length", "detail", "corner_radius"],
            ["Simplified", "Detailed"],
          ),
        )
      Err(_) => ()
    }
  }
  entries
}

///|
/// gear_catalog returns representative spur and internal-ring gear entries.
pub fn gear_catalog() -> Array[CatalogEntry] {
  let entries : Array[CatalogEntry] = []
  match
    @gears.SpurGearParams::new(
      module_mm=2.0,
      teeth=20,
      pressure_angle_deg=20.0,
      face_width_mm=10.0,
      bore_diameter_mm=8.0,
    ) {
    Ok(params) =>
      match @gears.spur_gear(params, detail=@common.Detailed) {
        Ok(c) =>
          entries.push(
            entry_from_component(
              c,
              [
                "module", "teeth", "pressure_angle", "face_width", "bore", "backlash",
                "root_fillet", "tip_chamfer", "detail",
              ],
              ["Detailed", "FullyModeled"],
            ),
          )
        Err(_) => ()
      }
    Err(_) => ()
  }
  match
    @gears.internal_ring_gear_exact(
      2.0,
      36,
      10.0,
      pressure_angle_deg=20.0,
      backlash_mm=0.1,
      detail=@common.Detailed,
    ) {
    Ok(c) =>
      entries.push(
        entry_from_component(
          c,
          [
            "module", "teeth", "pressure_angle", "face_width", "backlash", "addendum_factor",
            "dedendum_factor", "detail",
          ],
          ["Detailed", "FullyModeled"],
        ),
      )
    Err(_) => ()
  }
  match
    @gears.BevelGearParams::new(
      module_mm=2.0,
      teeth=20,
      mate_teeth=20,
      shaft_angle_deg=90.0,
      pressure_angle_deg=20.0,
      face_width_mm=10.0,
      bore_diameter_mm=15.0,
      hub_diameter_mm=34.0,
      hub_length_mm=14.0,
      end_face=@gears.BevelEndFace::BackCone,
    ) {
    Ok(params) =>
      match @gears.bevel_gear(params, detail=@common.Detailed) {
        Ok(c) =>
          entries.push(
            entry_from_component(
              c,
              [
                "module", "teeth", "mate_teeth", "shaft_angle", "pressure_angle",
                "face_width", "bore", "backlash", "addendum_factor", "dedendum_factor",
                "involute_points", "arc_points", "root_fillet", "fillet_segments",
                "tip_chamfer", "hub_diameter", "hub_length", "end_face", "detail",
              ],
              ["Detailed"],
            ),
          )
        Err(_) => ()
      }
    Err(_) => ()
  }
  entries
}

///|
/// motion_catalog returns representative motion entries: a keyed shaft with a
/// real keyway, the matching key, and the measured wheel/tire envelope.
pub fn motion_catalog() -> Array[CatalogEntry] {
  let entries : Array[CatalogEntry] = []
  match @motion.keyed_shaft(20.0, 40.0, 6.0, 3.5) {
    Ok(c) =>
      entries.push(
        entry_from_component(
          c,
          ["diameter", "length", "keyway_width", "keyway_depth", "segments"],
          ["Detailed"],
        ),
      )
    Err(_) => ()
  }
  match @motion.key_for_keyway(6.0, 3.5, 20.0) {
    Ok(c) =>
      entries.push(
        entry_from_component(
          c,
          ["keyway_width", "keyway_depth", "key_length", "width_clearance"],
          ["Detailed"],
        ),
      )
    Err(_) => ()
  }
  match @motion.measured_tire() {
    Ok(c) =>
      entries.push(
        entry_from_component(
          c,
          [
            "tire_outer_diameter", "tire_inner_diameter", "tire_width", "hub_outer_diameter",
            "hub_bore_diameter", "hub_length", "hub_inset", "inset_thickness", "rib_thickness",
            "rib_count", "rib_phase",
          ],
          ["Detailed"],
        ),
      )
    Err(_) => ()
  }
  entries
}

///|
/// extrusion_hardware_catalog returns representative extrusion T-nuts and
/// heat-set inserts.
pub fn extrusion_hardware_catalog() -> Array[CatalogEntry] {
  let entries : Array[CatalogEntry] = []
  for thread in ["M3", "M4", "M5"] {
    match @fasteners.extrusion_tnut_spec(thread, slot_width_mm=5.0) {
      Ok(spec) =>
        match @fasteners.extrusion_tnut(spec, detail=@common.Detailed) {
          Ok(c) =>
            entries.push(
              entry_from_component(
                c,
                ["thread", "slot_width", "thickness", "across_flats", "detail"],
                ["Detailed"],
              ),
            )
          Err(_) => ()
        }
      Err(_) => ()
    }
  }
  for length_kind in ["short", "long"] {
    match @fasteners.heat_set_insert_m3(length_kind) {
      Ok(c) =>
        entries.push(
          entry_from_component(
            c,
            ["thread", "length", "body_diameter", "knurl_diameter", "bore"],
            ["Detailed"],
          ),
        )
      Err(_) => ()
    }
  }
  entries
}

///|
/// linear_bearing_catalog returns the plain and flanged LM8UU envelopes.
pub fn linear_bearing_catalog() -> Array[CatalogEntry] {
  let entries : Array[CatalogEntry] = []
  match @motion.linear_bearing_size("LM8UU") {
    Ok(size) => {
      match @motion.linear_bearing(size) {
        Ok(c) =>
          entries.push(
            entry_from_component(
              c,
              ["designation", "bore", "outer_diameter", "length", "orientation"],
              ["Detailed"],
            ),
          )
        Err(_) => ()
      }
      match @motion.flanged_linear_bearing(size) {
        Ok(c) =>
          entries.push(
            entry_from_component(
              c,
              ["designation", "bore", "flange_diameter", "flange_thickness"],
              ["Detailed"],
            ),
          )
        Err(_) => ()
      }
    }
    Err(_) => ()
  }
  entries
}

///|
/// motor_catalog returns the NEMA 17/23 envelopes, the NEMA-to-extrusion
/// adapter, the measured 360KV outrunner envelope, and the measured A12 8318
/// agricultural outrunner envelope.
pub fn motor_catalog() -> Array[CatalogEntry] {
  let entries : Array[CatalogEntry] = []
  for designation in @motors.nema_designations() {
    match @motors.nema_motor_by_designation(designation, 40.0) {
      Ok(c) =>
        entries.push(
          entry_from_component(
            c,
            ["frame", "body_length", "shaft_length", "shaft_diameter", "detail"],
            ["Detailed"],
          ),
        )
      Err(_) => ()
    }
  }
  match @motors.nema_frame("NEMA17") {
    Ok(frame) =>
      match @motors.motor_to_extrusion_adapter(frame, 60.0, 50.0, 6.0, 40.0) {
        Ok(c) =>
          entries.push(
            entry_from_component(
              c,
              [
                "frame", "plate_width", "plate_height", "thickness", "extrusion_pitch",
                "extrusion_hole_diameter", "hole_clearance", "detail",
              ],
              ["Detailed"],
            ),
          )
        Err(_) => ()
      }
    Err(_) => ()
  }
  match @motors.brushless_motor_360kv() {
    Ok(c) =>
      entries.push(
        entry_from_component(
          c,
          [
            "bell_outer_diameter", "bell_wall_thickness", "bell_face_thickness",
            "bell_cone_thickness", "bell_cone_run", "window_count", "window_inner_diameter",
            "window_outer_diameter", "prop_hole_count", "prop_hole_circle_diameter",
            "stator_hub_diameter", "mount_hole_count", "shaft_diameter", "shaft_rear_extension",
            "shaft_front_extension",
          ],
          ["Detailed"],
        ),
      )
    Err(_) => ()
  }
  match @motors.a12_motor_100kv() {
    Ok(c) =>
      entries.push(
        entry_from_component(
          c,
          [
            "bell_outer_diameter", "bell_wall_thickness", "bell_skirt_length", "bell_window_count",
            "magnet_count", "magnet_outer_diameter", "stator_outer_diameter", "stator_stack_length",
            "stator_tooth_count", "prop_hole_circle_diameter", "mount_m3_circle_diameter",
            "mount_m4_circle_diameter", "shaft_diameter",
          ],
          ["Detailed"],
        ),
      )
    Err(_) => ()
  }
  entries
}

///|
/// stock_catalog returns the verified angle and plate stock primitives.
pub fn stock_catalog() -> Array[CatalogEntry] {
  let entries : Array[CatalogEntry] = []
  match @stock.angle_bar(@stock.en10056_equal_angle_40x40x4(), 50.0) {
    Ok(c) =>
      entries.push(
        entry_from_component(
          c,
          ["leg_a", "leg_b", "thickness", "root_radius", "toe_radius", "length"],
          ["Detailed"],
        ),
      )
    Err(_) => ()
  }
  match @stock.plate(50.0, 50.0, 3.0) {
    Ok(c) =>
      entries.push(
        entry_from_component(c, ["width", "height", "thickness", "holes"], [
          "Detailed",
        ]),
      )
    Err(_) => ()
  }
  match
    @stock.channel_to_extrusion_adapter(41.3, 47.6, 14.3, 20.0, 70.0, 48.0, 6.0) {
    Ok(c) =>
      entries.push(
        entry_from_component(
          c,
          [
            "channel_width", "channel_hole_pitch", "channel_hole_diameter", "extrusion_pitch",
            "plate_width", "plate_height", "thickness", "extrusion_hole_diameter",
          ],
          ["Detailed"],
        ),
      )
    Err(_) => ()
  }
  match @stock.extrusion_to_tube_clamp(17.9324, 20.0) {
    Ok(c) =>
      entries.push(
        entry_from_component(
          c,
          [
            "tube_outside_diameter", "length", "clearance", "wall", "gap", "ear_length",
            "ear_height", "ear_embed", "clamp_bolt_diameter", "base_width", "base_thickness",
            "extrusion_pitch", "bolt_diameter", "embed",
          ],
          ["Detailed"],
        ),
      )
    Err(_) => ()
  }
  entries
}

///|
/// mechanisms_catalog returns one representative entry for every generic
/// mechanism and structural primitive family.
pub fn mechanisms_catalog() -> Array[CatalogEntry] {
  let entries : Array[CatalogEntry] = []
  let profile = match
    @mechanisms.linear_rail_profile(
      width_mm=20.0,
      height_mm=15.0,
      groove_width_mm=6.0,
      groove_depth_mm=2.0,
    ) {
    Ok(p) => Some(p)
    Err(_) => None
  }
  let direct : Array[(@common.Component, Array[String])] = []
  match @mechanisms.hinge(40.0, 20.0, 6.0, 4.0) {
    Ok(c) =>
      direct.push(
        (
          c,
          [
            "length", "width", "thickness", "pin_diameter", "knuckles", "leaf_angle",
          ],
        ),
      )
    Err(_) => ()
  }
  match @mechanisms.clevis(30.0, 20.0, 6.0, 5.0, 8.0, 6.0) {
    Ok(c) =>
      direct.push(
        (
          c,
          [
            "base_width", "base_depth", "base_thickness", "prong_thickness", "gap",
            "pin_diameter",
          ],
        ),
      )
    Err(_) => ()
  }
  match @mechanisms.clevis_pin(6.0, 30.0, 10.0, 2.0) {
    Ok(c) =>
      direct.push(
        (c, ["diameter", "length", "head_diameter", "head_thickness"]),
      )
    Err(_) => ()
  }
  match @mechanisms.rod_end(20.0, 6.0, 8.0, 8.0, 30.0) {
    Ok(c) =>
      direct.push(
        (
          c,
          [
            "eye_outer_diameter", "eye_bore_diameter", "eye_width", "shank_diameter",
            "shank_length",
          ],
        ),
      )
    Err(_) => ()
  }
  match @mechanisms.linkage_bar(100.0, 20.0, 5.0, 8.0) {
    Ok(c) =>
      direct.push(
        (
          c,
          [
            "length", "width", "thickness", "pivot_diameter", "pivot_spacing", "slot",
          ],
        ),
      )
    Err(_) => ()
  }
  match profile {
    Some(p) =>
      match @mechanisms.linear_rail(p, 300.0) {
        Ok(c) =>
          direct.push(
            (
              c,
              [
                "profile_width", "profile_height", "length", "mount_hole_count",
                "mount_hole_diameter", "base_thickness",
              ],
            ),
          )
        Err(_) => ()
      }
    None => ()
  }
  match profile {
    Some(p) =>
      match @mechanisms.linear_carriage(p, 80.0, 50.0, 30.0) {
        Ok(c) =>
          direct.push(
            (
              c,
              [
                "block_length", "block_width", "block_height", "clearance", "bolt_hole_diameter",
              ],
            ),
          )
        Err(_) => ()
      }
    None => ()
  }
  match @mechanisms.lead_screw(8.0, 200.0) {
    Ok(c) => direct.push((c, ["nominal_diameter", "length", "lead"]))
    Err(_) => ()
  }
  match @mechanisms.lead_screw_nut(16.0, 20.0, 24.0, 4.0, 8.0, 2.0) {
    Ok(c) =>
      direct.push(
        (
          c,
          [
            "outer_diameter", "length", "flange_diameter", "flange_thickness", "thread_diameter",
            "thread_pitch",
          ],
        ),
      )
    Err(_) => ()
  }
  match @mechanisms.belt_loop(20.0, 100.0, 2.0, 10.0) {
    Ok(c) =>
      direct.push(
        (
          c,
          [
            "pulley_pitch_diameter", "center_distance", "belt_thickness", "belt_width",
            "pitch_length",
          ],
        ),
      )
    Err(_) => ()
  }
  match @mechanisms.belt_loop_unequal(20.0, 40.0, 100.0, 2.0, 10.0) {
    Ok(c) =>
      direct.push(
        (
          c,
          [
            "pulley_a_pitch_diameter", "pulley_b_pitch_diameter", "center_distance",
            "belt_thickness", "belt_width", "pitch_length",
          ],
        ),
      )
    Err(_) => ()
  }
  match @mechanisms.eccentric_cam(20.0, 5.0, 8.0, 6.0) {
    Ok(c) =>
      direct.push(
        (c, ["base_radius", "eccentricity", "width", "bore_diameter"]),
      )
    Err(_) => ()
  }
  match @mechanisms.roller_follower(10.0, 8.0, 5.0, 4.0, 10.0) {
    Ok(c) =>
      direct.push(
        (
          c,
          [
            "roller_diameter", "width", "bore_diameter", "pin_diameter", "pin_length",
          ],
        ),
      )
    Err(_) => ()
  }
  match @mechanisms.oldham_coupling(5.0, 20.0, 8.0, 18.0, 3.0, 4.0) {
    Ok(c) =>
      direct.push(
        (
          c,
          [
            "bore", "hub_outer_diameter", "hub_length", "disc_diameter", "disc_thickness",
            "tongue_width", "slot_clearance",
          ],
        ),
      )
    Err(_) => ()
  }
  match @mechanisms.extension_spring(20.0, 2.0, 40.0, 8) {
    Ok(c) =>
      direct.push(
        (
          c,
          [
            "mean_diameter", "wire_diameter", "free_length", "active_coils", "leg_length",
            "hook_loop_radius",
          ],
        ),
      )
    Err(_) => ()
  }
  match @mechanisms.torsion_spring(20.0, 2.0, 40.0, 8) {
    Ok(c) =>
      direct.push(
        (
          c,
          [
            "mean_diameter", "wire_diameter", "free_length", "active_coils", "leg_length",
          ],
        ),
      )
    Err(_) => ()
  }
  match @mechanisms.snap_latch(40.0, 2.0, 10.0, 3.0, 5.0) {
    Ok(c) =>
      direct.push(
        (
          c,
          [
            "beam_length", "beam_thickness", "beam_width", "hook_depth", "ramp_length",
          ],
        ),
      )
    Err(_) => ()
  }
  match @mechanisms.o_ring(20.0, 4.0) {
    Ok(c) => direct.push((c, ["inner_diameter", "cross_section"]))
    Err(_) => ()
  }
  match @mechanisms.grooved_shaft(20.0, 50.0, 4.0, 2.0, 20.0) {
    Ok(c) =>
      direct.push(
        (
          c,
          [
            "shaft_diameter", "length", "groove_width", "groove_depth", "groove_center_z",
          ],
        ),
      )
    Err(_) => ()
  }
  match @mechanisms.l_bracket(60.0, 50.0, 30.0, 4.0, 5.0) {
    Ok(c) =>
      direct.push(
        (
          c,
          [
            "leg_a", "leg_b", "width", "thickness", "hole_diameter", "holes_per_leg",
            "gusset",
          ],
        ),
      )
    Err(_) => ()
  }
  match @mechanisms.u_bracket(100.0, 40.0, 60.0, 4.0, 5.0) {
    Ok(c) =>
      direct.push(
        (
          c,
          [
            "base_length", "leg_height", "width", "thickness", "hole_diameter", "holes_per_leg",
          ],
        ),
      )
    Err(_) => ()
  }
  match @mechanisms.z_bracket(60.0, 50.0, 40.0, 30.0, 4.0, 5.0) {
    Ok(c) =>
      direct.push(
        (
          c,
          [
            "lower_length", "upper_length", "height", "width", "thickness", "hole_diameter",
            "holes_per_flange",
          ],
        ),
      )
    Err(_) => ()
  }
  match @mechanisms.tapped_boss(16.0, 20.0, 24.0, 4.0, 6.0, 1.0, 10.0) {
    Ok(c) =>
      direct.push(
        (
          c,
          [
            "body_diameter", "body_height", "flange_diameter", "flange_thickness",
            "thread_diameter", "thread_pitch", "thread_depth",
          ],
        ),
      )
    Err(_) => ()
  }
  match @mechanisms.rack_gear(2.0, 10, 6.0, 10.0) {
    Ok(c) =>
      direct.push(
        (
          c,
          [
            "module", "teeth", "base_thickness", "thickness", "pressure_angle", "mount_hole_diameter",
          ],
        ),
      )
    Err(_) => ()
  }
  for teeth in [16, 24] {
    match @mechanisms.ansi40_sprocket(teeth) {
      Ok(c) =>
        direct.push(
          (
            c,
            [
              "pitch", "teeth", "roller_diameter", "seat_clearance", "plate_thickness",
              "hub_diameter", "hub_height", "bore_diameter", "tip_arc_half_angle",
            ],
          ),
        )
      Err(_) => ()
    }
  }
  match @mechanisms.ansi40_chain_segment(10) {
    Ok(c) =>
      direct.push(
        (
          c,
          [
            "pitch", "pitches", "roller_diameter", "roller_bore", "roller_length",
            "pin_diameter", "pin_length", "plate_thickness", "plate_end_radius",
            "plate_hole_diameter", "plate_center_z",
          ],
        ),
      )
    Err(_) => ()
  }
  for entry in direct {
    let (component, parameters) = entry
    entries.push(entry_from_component(component, parameters, ["Detailed"]))
  }
  entries
}

///|
/// full_catalog returns every catalogue entry.
pub fn full_catalog() -> Array[CatalogEntry] {
  let entries : Array[CatalogEntry] = []
  entries.push_iter(fastener_catalog().iter())
  entries.push_iter(bearing_catalog().iter())
  entries.push_iter(profile_catalog().iter())
  entries.push_iter(gear_catalog().iter())
  entries.push_iter(motion_catalog().iter())
  entries.push_iter(extrusion_hardware_catalog().iter())
  entries.push_iter(linear_bearing_catalog().iter())
  entries.push_iter(motor_catalog().iter())
  entries.push_iter(stock_catalog().iter())
  entries.push_iter(mechanisms_catalog().iter())
  entries.push_iter(makerpipe_catalog().iter())
  entries
}

///|
/// lookup finds an entry by exact designation.
pub fn lookup(
  entries : Array[CatalogEntry],
  designation : String,
) -> Result[CatalogEntry, CatalogError] {
  for entry in entries {
    if entry.designation == designation {
      return Ok(entry)
    }
  }
  Err(UnknownDesignation(designation))
}

///|
/// query filters entries by family, standard, and size. A `None` filter matches
/// everything; a supplied filter matches exactly.
pub fn query(
  entries : Array[CatalogEntry],
  family? : String,
  standard? : String,
  size? : String,
) -> Array[CatalogEntry] {
  entries.filter(fn(entry) {
    let family_ok = match family {
      Some(f) => entry.family == f
      None => true
    }
    let standard_ok = match standard {
      Some(s) => entry.standard == s
      None => true
    }
    let size_ok = match size {
      Some(s) => entry.size == s
      None => true
    }
    family_ok && standard_ok && size_ok
  })
}
