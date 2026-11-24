///|
/// 40-split-ring-planetary
///
/// Print-in-place, two-cartridge, 4-elbow herringbone split-ring compound
/// planetary (Wolfrom) gearbox with integrated 45-degree revolved axial
/// snap-fit planet couplers.
///
/// Modes (`--mode`):
///   - `exploded` (default): Cartridge 1 at z = 0 (male snap pins pointing up)
///     and Cartridge 2 coaxially floating above by `--gap` mm so you can see
///     exactly how the two printed cartridges snap together.
///   - `lower`: Print-ready Cartridge 1 (Sun + lower planets w/ male snap pins
///     + fixed lower ring).
///   - `upper`: Print-ready Cartridge 2 (upper planets w/ female snap sockets
///     + rotating output ring, no sun).
///   - `assembled`: Both cartridges snapped flush together.

///|
async fn main {
  let spec = {
    "preset": @cli.opt_string(
      help="Preset: 'default' (4-planet -32:1) or 'manafish51' (3-planet -51:1)",
    ),
    "mode": @cli.opt_string(
      help="Output mode: exploded, lower, upper, or assembled (default exploded)",
    ),
    "module": @cli.opt_double(
      1.25,
      help="Gear module in mm (default 1.25)",
      min=0.5,
    ),
    "elbows": @cli.opt_int(
      4,
      help="Herringbone elbow count (0 = straight, 4 = print-in-place herringbone, default 4)",
      min=0,
    ),
    "gap": @cli.opt_double(
      25.0,
      help="Axial explode separation between Cartridge 1 and Cartridge 2 in mm (default 25.0)",
      min=0.0,
    ),
    "out": @cli.opt_string(
      help="Output evaluated STEP path (default /tmp/40-split-ring-planetary.step)",
      short='o',
    ),
  }
  guard @cli.parse(
      spec,
      prog="40-split-ring-planetary",
      description="Two-cartridge print-in-place herringbone split-ring compound planetary gearbox.",
    )
    is Some(args) else {
    return
  }

  let preset = args.string_opt("preset").unwrap_or("default")
  let mode = args.string_opt("mode").unwrap_or("exploded")
  let module_mm = args.double("module")
  let num_elbows = args.int("elbows")
  let gap_mm = args.double("gap")
  let out_path = args
    .string_opt("out")
    .unwrap_or("/tmp/40-split-ring-planetary.step")

  let base = if preset == "manafish51" {
    @planetary.SplitRingPlanetaryParams::manafish_51(module_mm~)
  } else {
    @planetary.SplitRingPlanetaryParams::new(module_mm~).unwrap()
  }
  let params : @planetary.SplitRingPlanetaryParams = { ..base, num_elbows, }
  let layout = @planetary.split_ring_planetary_layout(params)
  println(
    "Split-ring compound planetary: ratio=\{@cad.fmt_double(layout.ratio, Some(0.1))}:1, OD=Ø\{@cad.fmt_double(layout.outer_radius_mm * 2.0, Some(0.1))} mm, total height=\{@cad.fmt_double(layout.total_length_mm, Some(0.1))} mm",
  )

  let design_res = if mode == "lower" {
    @planetary.split_ring_lower_cartridge_design(params)
  } else if mode == "upper" {
    @planetary.split_ring_upper_cartridge_design(params)
  } else if mode == "assembled" {
    @planetary.split_ring_exploded_design(params, gap_mm=0.0)
  } else {
    @planetary.split_ring_exploded_design(params, gap_mm~)
  }
  let design = match design_res {
    Ok(d) => d
    Err(e) => {
      @cli.eprintln("error: invalid split-ring params: " + e.to_string())
      abort("")
    }
  }

  let step_text = design.to_step_evaluated() catch {
    e => {
      @cli.eprintln("error: OCCT evaluation failed: " + e.to_string())
      abort("")
    }
  }
  @cad.write_text_file(step_text, Some(out_path))
  println("Wrote evaluated STEP (\{mode}): " + out_path)
}
