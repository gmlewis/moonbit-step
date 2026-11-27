///|
/// Target manufacturing process for Design-for-Manufacturing (DFM) features
/// such as 45-degree teardrop horizontal bores for support-free FDM printing.
#derive(Eq)
pub(all) enum MfgProcess {
  /// Exact nominal CAD geometry (round horizontal bores, sharp corners).
  Nominal
  /// Fused Deposition Modeling (FDM) 3D printing: adds support-free DFM
  /// features such as 45-degree tangent teardrop peaks on horizontal bores.
  Fdm
  /// Selective Laser Sintering / powder-bed metal or polymer printing:
  /// self-supporting powder bed, so horizontal bores remain exact circles.
  Sls
  /// Subtractive CNC machining: exact circular bores.
  Cnc
}

///|
pub impl Show for MfgProcess with fn to_string(self : MfgProcess) -> String {
  match self {
    Nominal => "nominal"
    Fdm => "fdm"
    Sls => "sls"
    Cnc => "cnc"
  }
}

///|
pub extend MfgProcess with Show::{to_string}

///|
/// Parses a CLI manufacturing process name (`fdm`, `sls`, `cnc`, `nominal`).
pub fn MfgProcess::parse(raw : String) -> MfgProcess? {
  match raw.trim().to_lower() {
    "fdm" => Some(Fdm)
    "sls" => Some(Sls)
    "cnc" => Some(Cnc)
    "nominal" | "exact" | "none" => Some(Nominal)
    _ => None
  }
}

///|
/// Returns true when horizontal bores should use 45-degree teardrop peaks so
/// parts print cleanly without support material.
pub fn MfgProcess::needs_fdm_teardrops(self : MfgProcess) -> Bool {
  match self {
    Fdm => true
    Nominal | Sls | Cnc => false
  }
}
