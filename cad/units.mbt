///|
/// Length is a dimension in millimetres, used to make unit mixing a
/// compile-time error instead of a silent modelling mistake.
///
/// Construct with `Length::mm`, `Length::cm`, `Length::m`, or
/// `Length::inches`; there is deliberately no conversion from a bare `Double`,
/// so `Length::mm(3.0) + 0.25` does not type-check. Read back with `to_mm`.
pub struct Length {
  priv mm : Double
}

///|
pub fn Length::mm(v : Double) -> Length {
  Length::{ mm: v, }
}

///|
pub fn Length::cm(v : Double) -> Length {
  Length::{ mm: v * 10.0, }
}

///|
pub fn Length::m(v : Double) -> Length {
  Length::{ mm: v * 1000.0, }
}

///|
pub fn Length::inches(v : Double) -> Length {
  Length::{ mm: v * 25.4, }
}

///|
pub fn Length::to_mm(self : Length) -> Double {
  self.mm
}

///|
pub fn Length::scale(self : Length, factor : Double) -> Length {
  Length::{ mm: self.mm * factor, }
}

///|
pub impl Add for Length with fn add(self, other) {
  Length::{ mm: self.mm + other.mm, }
}

///|
pub impl Sub for Length with fn sub(self, other) {
  Length::{ mm: self.mm - other.mm, }
}

///|
pub impl Neg for Length with fn neg(self) {
  Length::{ mm: -self.mm, }
}

///|
/// Angle is an angle in radians, used to make degree/radian mixing explicit.
pub struct Angle {
  priv rad : Double
}

///|
pub fn Angle::rad(v : Double) -> Angle {
  Angle::{ rad: v, }
}

///|
pub fn Angle::deg(v : Double) -> Angle {
  Angle::{ rad: v * @math.PI / 180.0, }
}

///|
pub fn Angle::to_rad(self : Angle) -> Double {
  self.rad
}

///|
pub fn Angle::to_deg(self : Angle) -> Double {
  self.rad * 180.0 / @math.PI
}
