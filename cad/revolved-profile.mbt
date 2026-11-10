///|
/// RevSegment is one band of a profile in the (r, z) half-plane that is revolved
/// about the Z axis.
///
/// `r` is the radius (along +X), `z` is the axial coordinate. `RevLine` is a
/// straight band; `RevArc` is a circular arc band defined by its start point,
/// end point, and center. An arc is always the minor arc (sweep at most 180
/// degrees), which makes the trim unambiguous.
pub(all) enum RevSegment {
  RevLine(Vec2, Vec2)
  RevArc(Vec2, Vec2, Vec2)
}

///|
/// RevolvedProfile is a solid of revolution.
///
/// The profile is a chain of `RevSegment` values in the (r, z) half-plane with
/// `r >= 0`. The chain must either begin and end on the axis (`r = 0`, yielding
/// poles) or close on itself away from the axis (yielding an annular solid such
/// as a washer or a ring). The result is compiled into one closed STEP solid
/// whose lateral faces are true `CYLINDRICAL_SURFACE`, `CONICAL_SURFACE`,
/// `SPHERICAL_SURFACE`, and `TOROIDAL_SURFACE` bands, with planar caps.
pub struct RevolvedProfile {
  segments : Array[RevSegment]
}

///|
/// RevProfileError reports why a revolved profile cannot be compiled.
pub(all) enum RevProfileError {
  EmptyProfile
  DiscontinuousChain(Int32)
  NegativeRadius(Int32)
  ArcEndpointMismatch(Int32)
  DegenerateArc(Int32)
  NotClosed
  DegenerateArea
}

///|
/// RevProfileError::message returns a human-readable diagnostic.
pub fn RevProfileError::message(self : RevProfileError) -> String {
  match self {
    EmptyProfile => "revolved profile has no segments"
    DiscontinuousChain(i) =>
      "revolved profile segment \{i} does not start where the previous one ended"
    NegativeRadius(i) => "revolved profile point \{i} has a negative radius"
    ArcEndpointMismatch(i) =>
      "revolved profile arc \{i} does not have equal start/end radii about its center"
    DegenerateArc(i) => "revolved profile arc \{i} has a zero radius"
    NotClosed =>
      "revolved profile must end on the axis or close on itself to bound a solid"
    DegenerateArea => "revolved profile encloses zero area"
  }
}

///|
/// RevolvedProfile::new stores a chain of segments without validating it.
pub fn RevolvedProfile::new(segments : Array[RevSegment]) -> RevolvedProfile {
  { segments, }
}

///|
/// RevolvedProfile::polyline builds a chain of straight bands through `points`
/// in the (r, z) half-plane. When `closed` is true the last point is joined
/// back to the first, which produces an annular solid.
pub fn RevolvedProfile::polyline(
  points : Array[Vec2],
  closed~ : Bool = false,
) -> RevolvedProfile {
  let n = points.length()
  let segments : Array[RevSegment] = []
  for i in 0..<(n - 1) {
    segments.push(RevLine(points[i], points[i + 1]))
  }
  if closed && n > 2 {
    segments.push(RevLine(points[n - 1], points[0]))
  }
  { segments, }
}

///|
/// RevolvedProfile::cylinder builds a solid right circular cylinder with its
/// base at z = 0 and its axis on +Z.
pub fn RevolvedProfile::cylinder(
  diameter : Double,
  height : Double,
) -> RevolvedProfile {
  let r = diameter / 2.0
  RevolvedProfile::new([
    RevLine((0.0, 0.0), (r, 0.0)),
    RevLine((r, 0.0), (r, height)),
    RevLine((r, height), (0.0, height)),
  ])
}

///|
/// RevolvedProfile::frustum builds a solid frustum between `radius_bottom` at
/// z = 0 and `radius_top` at z = `height`. Either radius may be zero, which
/// makes that end a pole, but not both.
pub fn RevolvedProfile::frustum(
  radius_bottom : Double,
  radius_top : Double,
  height : Double,
) -> RevolvedProfile {
  let segs : Array[RevSegment] = []
  if radius_bottom > 0.0 {
    segs.push(RevLine((0.0, 0.0), (radius_bottom, 0.0)))
    segs.push(RevLine((radius_bottom, 0.0), (radius_top, height)))
  } else if radius_top > 0.0 {
    segs.push(RevLine((0.0, 0.0), (radius_top, height)))
  }
  if radius_top > 0.0 {
    segs.push(RevLine((radius_top, height), (0.0, height)))
  }
  RevolvedProfile::new(segs)
}

///|
/// RevolvedProfile::cone builds a solid cone with base radius `radius` at z = 0
/// and apex on the axis at z = `height`.
pub fn RevolvedProfile::cone(
  radius : Double,
  height : Double,
) -> RevolvedProfile {
  RevolvedProfile::frustum(radius, 0.0, height)
}

///|
/// RevolvedProfile::sphere builds a solid sphere of the given diameter centred
/// on the origin. It is two hemispherical `SPHERICAL_SURFACE` bands sharing the
/// equator circle.
pub fn RevolvedProfile::sphere(diameter : Double) -> RevolvedProfile {
  let r = diameter / 2.0
  RevolvedProfile::new([
    RevArc((0.0, -r), (r, 0.0), (0.0, 0.0)),
    RevArc((r, 0.0), (0.0, r), (0.0, 0.0)),
  ])
}

///|
/// RevolvedProfile::sphere_cap builds a flat-bottomed dome: a disc of radius
/// `rim_radius` at z = 0 and a spherical cap rising to the axis at z =
/// `height`. It is the natural representation of a button-head screw top.
pub fn RevolvedProfile::sphere_cap(
  rim_radius : Double,
  height : Double,
) -> RevolvedProfile {
  let k = (height * height - rim_radius * rim_radius) / (2.0 * height)
  RevolvedProfile::new([
    RevLine((0.0, 0.0), (rim_radius, 0.0)),
    RevArc((rim_radius, 0.0), (0.0, height), (0.0, k)),
  ])
}

///|
/// RevolvedProfile::segments returns the segment chain.
pub fn RevolvedProfile::segments(self : RevolvedProfile) -> Array[RevSegment] {
  self.segments.copy()
}

///|
/// RevolvedProfile::as_shape wraps the profile as a `Shape` so the fluent
/// `with_name`/`translate`/`rotate_*` builder methods apply.
pub fn RevolvedProfile::as_shape(self : RevolvedProfile) -> Shape {
  Shape::RevolvedProfile(self)
}

///|
fn rev_seg_start(seg : RevSegment) -> Vec2 {
  match seg {
    RevLine(a, _) => a
    RevArc(a, _, _) => a
  }
}

///|
fn rev_seg_end(seg : RevSegment) -> Vec2 {
  match seg {
    RevLine(_, b) => b
    RevArc(_, b, _) => b
  }
}

///|
fn rev_close2(a : Vec2, b : Vec2) -> Bool {
  (a.0 - b.0).abs() < 1.0e-9 && (a.1 - b.1).abs() < 1.0e-9
}

///|
/// RevolvedProfile::validate checks the segment chain and returns a typed error
/// when it cannot bound a solid.
pub fn RevolvedProfile::validate(
  self : RevolvedProfile,
) -> Result[Unit, RevProfileError] {
  let segs = self.segments
  let n = segs.length()
  if n == 0 {
    return Err(EmptyProfile)
  }
  for i in 0..<n {
    let a = rev_seg_start(segs[i])
    let b = rev_seg_end(segs[i])
    if a.0 < -1.0e-9 || b.0 < -1.0e-9 {
      return Err(NegativeRadius(i))
    }
    if rev_close2(a, b) {
      return Err(DegenerateArea)
    }
    match segs[i] {
      RevArc(s, e, c) => {
        let r1 = rev_dist2(s, c)
        let r2 = rev_dist2(e, c)
        if r1 < 1.0e-12 {
          return Err(DegenerateArc(i))
        }
        if (r1 - r2).abs() > 1.0e-6 {
          return Err(ArcEndpointMismatch(i))
        }
      }
      RevLine(_, _) => ()
    }
    if i > 0 {
      let prev = rev_seg_end(segs[i - 1])
      if !rev_close2(prev, a) {
        return Err(DiscontinuousChain(i))
      }
    }
  }
  let first = rev_seg_start(segs[0])
  let last = rev_seg_end(segs[n - 1])
  let open_on_axis = first.0 < 1.0e-9 && last.0 < 1.0e-9
  let closed = rev_close2(first, last)
  if !(open_on_axis || closed) {
    return Err(NotClosed)
  }
  // The profile must enclose a non-zero signed area.
  if rev_profile_signed_area(segs).abs() < 1.0e-12 {
    return Err(DegenerateArea)
  }
  Ok(())
}

///|
fn rev_dist2(a : Vec2, b : Vec2) -> Double {
  let dx = a.0 - b.0
  let dy = a.1 - b.1
  Double::sqrt(dx * dx + dy * dy)
}

///|
/// rev_profile_signed_area returns the signed area enclosed by the profile with
/// the axis closure. A positive value means the material is on the left when
/// walking the profile in (r, z).
fn rev_profile_signed_area(segs : Array[RevSegment]) -> Double {
  let mut sum = 0.0
  for seg in segs {
    match seg {
      RevLine(a, b) => sum = sum + a.0 * b.1 - b.0 * a.1
      RevArc(a, b, c) => {
        // Area contribution of a circular arc band about its chord: the
        // shoelace term plus the circular segment area. The segment area is
        // signed by the sweep direction.
        sum = sum + a.0 * b.1 - b.0 * a.1
        let rho = rev_dist2(a, c)
        let a0 = @math.atan2(a.1 - c.1, a.0 - c.0)
        let a1 = @math.atan2(b.1 - c.1, b.0 - c.0)
        let delta = rev_norm_angle(a1 - a0)
        sum = sum + rho * rho * (delta - @math.sin(delta))
      }
    }
  }
  sum / 2.0
}

///|
/// rev_norm_angle normalizes an angle to the interval (-pi, pi].
fn rev_norm_angle(a : Double) -> Double {
  let two_pi = 2.0 * @math.PI
  let mut x = a
  while x > @math.PI {
    x = x - two_pi
  }
  while x <= -@math.PI {
    x = x + two_pi
  }
  x
}
