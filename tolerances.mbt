///|
/// Shared numeric tolerances for STEP geometry.
///
/// Every magnitude has exactly one named definition so it can be tuned
/// centrally. Prefer these over bare `1.0e-*` literals in production code.
/// `StepContext::near_zero_double` separately clears trigonometric residue
/// when DSL primitives are created; these constants cover the remaining
/// coincidence, discriminant, area and degeneracy comparisons.

///|
pub const TOL_1E2 : Double = 1.0e-2

///|
pub const TOL_1E3 : Double = 1.0e-3

///|
pub const TOL_1E4 : Double = 1.0e-4

///|
pub const TOL_1E6 : Double = 1.0e-6

///|
pub const TOL_1E7 : Double = 1.0e-7

///|
pub const TOL_1E8 : Double = 1.0e-8

///|
pub const TOL_1E9 : Double = 1.0e-9

///|
pub const TOL_1E12 : Double = 1.0e-12

///|
pub const TOL_1E14 : Double = 1.0e-14

///|
pub const TOL_1E15 : Double = 1.0e-15

///|
pub const TOL_1E18 : Double = 1.0e-18

///|
pub const TOL_1E24 : Double = 1.0e-24
