///|
/// Default print-in-place gear flank/clearance tolerance in millimetres.
/// Shared across all gear components and downstream CAD/URDF repositories so
/// tuning for a specific 3D printer or filament only requires changing one value.
///
/// Even though a tolerance of 1 micron works on the IVI Closed-loop (Kickstarter) 3D printer,
/// the resulting planetary gear does break free but is very stiff with high friction.
/// Therefore, continue to back off this value until I find a nice balance between minimized
/// wobble and easy gear movement.
pub const DEFAULT_GEAR_TOLERANCE_MM : Double = 0.0020 // 2 microns
