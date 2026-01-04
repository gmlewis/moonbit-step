///|
/// Shared parameter types for the BFEM example.
///
/// This is intentionally non-geometry so it can be reused by reporting/export
/// helpers without pulling geometry construction along with it.

///|
struct Params {
  pos : Vec3
  inner_diam : Double
  num_pairs : Int
  num_segs : Int
  out_path : String?
  export_centerlines_path : String?
  wire_width : Double
  wire_gap : Double
  tolerance : Double
  report : Bool
  rho : Double
  connector_length : Double
  exit_wire_diameter : Double
  exit_wire_separation : Double
  back_thickness : Double
  front_thickness : Double
  radial_thickness : Double
  vert_turns : Double
  debug : Bool
  nocage : Bool
  nocoil : Bool
  nowires : Bool
  nosupport : Bool
  union : Bool
  snapping : Double
}
