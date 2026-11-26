///|
/// Default print-in-place gear flank/clearance tolerance in millimetres.
/// Shared across all gear components and downstream CAD/URDF repositories so
/// tuning for a specific 3D printer or filament only requires changing one value.
pub const DEFAULT_GEAR_TOLERANCE_MM : Double = 0.075

// 2026-11-25 - 0.075 failed on m=0.5 planetary gearbox with resolution=5.
// 2026-11-25 - 0.090 failed on m=0.5 planetary gearbox with resolution=5.
// 2026-11-25 - 0.100 failed on m=0.5 planetary gearbox with resolution=5.
// 2026-11-25 - 0.075 PASSED on m=1.0 planetary gearbox with resolution=5!!!
