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
  entries
}

///|
/// motion_catalog returns representative motion entries: a keyed shaft with a
/// real keyway and the matching key.
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
/// motor_catalog returns the NEMA 17 and NEMA 23 envelopes.
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
