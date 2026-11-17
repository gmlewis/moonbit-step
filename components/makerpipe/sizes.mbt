///|
/// MakerPipeSize carries the nominal envelope of one native Maker Pipe
/// structural connector size.
///
/// Maker Pipe sells two native connector sizes, 3/4 in and 1 in EMT. The 1/2 in
/// products are the 3/4 in connector plus 2-5 adapter shims, so a native 1/2 in
/// fitting is deliberately not offered here.
///
/// The 3/4 in values come from the manufacturer's published dimension drawings
/// (T, 90, 180, and 45 degree sheets). The 1 in values are derived from the 3/4
/// in drawing by the EMT outside-diameter ratio and are marked `derived = true`;
/// they are approximate until calibrated against a 1 in part or drawing.
pub(all) struct MakerPipeSize {
  trade_size : String
  /// EMT outside diameter used for the pipe seat.
  through_pipe_od_mm : Double
  /// Socket bore: the pipe slides into this.
  socket_bore_mm : Double
  /// Socket shell outside diameter.
  socket_outer_mm : Double
  /// Through-saddle bore: the continuous pipe is clamped in this.
  saddle_bore_mm : Double
  /// Through-saddle shell outside diameter.
  saddle_outer_mm : Double
  /// T branch socket depth from the pipe seat to the mouth (1.22 in at 3/4).
  tee_branch_depth_mm : Double
  /// Saddle connectors: fitting centre to branch socket mouth (2.5 in at 3/4).
  branch_centre_to_mouth_mm : Double
  /// Through-saddle width along the through pipe (1.3 in at 3/4).
  saddle_width_mm : Double
  /// T run-sleeve length (3.07 in at 3/4).
  run_length_mm : Double
  /// Nominal shell wall.
  wall_mm : Double
  /// True when the dimensions are derived rather than published.
  derived : Bool
}

///|
/// EMT outside diameter for 3/4 in, ANSI C80.3 / UL 797.
///
/// This repeats the value in `@motion.emt_size`; a test cross-checks the two so
/// the connector package cannot drift from the pipe table.
let emt_3_4_od_mm : Double = 23.4188

///|
/// EMT outside diameter for 1 in, ANSI C80.3 / UL 797.
let emt_1_od_mm : Double = 29.5402

///|
/// Socket bore clearance over the EMT outside diameter, from the 3/4 in
/// drawing: 0.94 in bore over a 0.922 in pipe is 0.46 mm on diameter.
let socket_clearance_mm : Double = 0.46

///|
/// Through-saddle bore clearance over the EMT outside diameter, from the 3/4 in
/// drawing: 0.93 in bore over a 0.922 in pipe is 0.20 mm on diameter.
let saddle_clearance_mm : Double = 0.20

///|
/// Nominal stamped-shell wall from the 3/4 in drawing: (1.14 - 0.94) / 2 in.
let makerpipe_wall_mm : Double = 2.54

///|
/// makerpipe_size looks up one native Maker Pipe connector size.
///
/// `"1/2"` is refused with a message explaining the real product: a 3/4 in
/// connector plus shims. It is not a native fitting.
pub fn makerpipe_size(
  trade_size : String,
) -> Result[MakerPipeSize, @common.SpecError] {
  match trade_size {
    "3/4" =>
      Ok({
        trade_size,
        through_pipe_od_mm: emt_3_4_od_mm,
        socket_bore_mm: 23.876,
        socket_outer_mm: 28.956,
        saddle_bore_mm: 23.622,
        saddle_outer_mm: 28.702,
        tee_branch_depth_mm: 30.988,
        branch_centre_to_mouth_mm: 63.500,
        saddle_width_mm: 33.020,
        run_length_mm: 77.978,
        wall_mm: makerpipe_wall_mm,
        derived: false,
      })
    "1" => {
      // Derive the larger connector from the 3/4 in drawing by the EMT OD
      // ratio. Diameters follow the pipe; lengths scale with the fitting.
      let k = emt_1_od_mm / emt_3_4_od_mm
      let socket_bore = emt_1_od_mm + socket_clearance_mm
      let saddle_bore = emt_1_od_mm + saddle_clearance_mm
      Ok({
        trade_size,
        through_pipe_od_mm: emt_1_od_mm,
        socket_bore_mm: socket_bore,
        socket_outer_mm: socket_bore + 2.0 * makerpipe_wall_mm,
        saddle_bore_mm: saddle_bore,
        saddle_outer_mm: saddle_bore + 2.0 * makerpipe_wall_mm,
        tee_branch_depth_mm: 30.988 * k,
        branch_centre_to_mouth_mm: 63.500 * k,
        saddle_width_mm: 33.020 * k,
        run_length_mm: 77.978 * k,
        wall_mm: makerpipe_wall_mm,
        derived: true,
      })
    }
    "1/2" =>
      Err(
        @common.InvalidSize(
          "Maker Pipe does not sell a native 1/2 in connector: use a 3/4 in connector with the 3/4 to 1/2 adapter shims",
        ),
      )
    other =>
      Err(
        @common.InvalidSize(
          "unsupported Maker Pipe connector size: \{other}; native sizes: 3/4, 1 (1/2 in is a 3/4 in connector plus shims)",
        ),
      )
  }
}

///|
/// makerpipe_trade_sizes returns the native connector sizes.
pub fn makerpipe_trade_sizes() -> Array[String] {
  ["3/4", "1"]
}
