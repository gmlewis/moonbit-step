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
  /// Optional per-band face colors, indexed by the segment order given to
  /// `new`/`polyline`. The compiler styles those faces individually (a STEP
  /// face-level `STYLED_ITEM`) so a single solid can carry more than one
  /// color, for example a black shield groove on a grey bearing.
  band_colors : Array[(Int32, Rgb)]
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
  { segments, band_colors: [], }
}

///|
/// RevolvedProfile::with_band_color returns a copy in which the face emitted
/// for segment `band` carries `color`. Band indices follow the segment order
/// passed to `new`/`polyline`; the compiler remaps them if it reverses the
/// profile winding. The flat STEP writer emits a face-level `STYLED_ITEM` for
/// each colored band, so the solid stays one closed B-rep.
pub fn RevolvedProfile::with_band_color(
  self : RevolvedProfile,
  band : Int32,
  color : Rgb,
) -> RevolvedProfile {
  let colors : Array[(Int32, Rgb)] = []
  let mut replaced = false
  for entry in self.band_colors {
    let (index, _existing) = entry
    if index == band {
      colors.push((band, color))
      replaced = true
    } else {
      colors.push(entry)
    }
  }
  if !replaced {
    colors.push((band, color))
  }
  { ..self, band_colors: colors, }
}

///|
/// RevolvedProfile::emission_colors returns the per-face colors in the order
/// the compiler emits the faces. It applies the same winding normalization as
/// `compile_revolved_profile`, so callers do not have to know whether the
/// profile was reversed.
pub fn RevolvedProfile::emission_colors(self : RevolvedProfile) -> Array[Rgb?] {
  let n = self.segments.length()
  let out : Array[Rgb?] = []
  for _i in 0..<n {
    out.push(None)
  }
  let reversed = rev_profile_signed_area(self.segments) < 0.0
  for entry in self.band_colors {
    let (band, color) = entry
    if band >= 0 && band < n {
      let target = if reversed { n - 1 - band } else { band }
      out[target] = Some(color)
    }
  }
  out
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
  { segments, band_colors: [], }
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
  // A single pole-to-pole semicircle compiles to one spherical face with a
  // seam; two hemisphere bands would add an equator face boundary.
  RevolvedProfile::new([RevArc((0.0, -r), (0.0, r), (0.0, 0.0))])
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
/// RevolvedProfile::chamfered_cylinder builds a solid right circular cylinder
/// of `diameter` and `height` whose bottom and/or top rims carry a 45-degree
/// analytic chamfer of the given leg length.
///
/// The result is one `CYLINDRICAL_SURFACE`, one `CONICAL_SURFACE` per chamfer,
/// and planar caps. It never degenerates into a prism of planar facets: a
/// circular body's chamfer is a cone, not a ring stack.
pub fn RevolvedProfile::chamfered_cylinder(
  diameter : Double,
  height : Double,
  bottom_chamfer~ : Double = 0.0,
  top_chamfer~ : Double = 0.0,
) -> RevolvedProfile {
  let r = diameter / 2.0
  let cb = if bottom_chamfer > 0.0 && bottom_chamfer < r {
    bottom_chamfer
  } else {
    0.0
  }
  let ct = if top_chamfer > 0.0 && top_chamfer < r { top_chamfer } else { 0.0 }
  if cb <= 0.0 && ct <= 0.0 {
    return RevolvedProfile::cylinder(diameter, height)
  }
  let pts : Array[Vec2] = [(0.0, 0.0)]
  if cb > 0.0 {
    pts.push((r - cb, 0.0))
    pts.push((r, cb))
  } else {
    pts.push((r, 0.0))
  }
  if ct > 0.0 {
    pts.push((r, height - ct))
    pts.push((r - ct, height))
  } else {
    pts.push((r, height))
  }
  pts.push((0.0, height))
  RevolvedProfile::polyline(pts)
}

///|
/// RevolvedProfile::tube builds an annular solid (washer or plain ring) with
/// the given outside and inside diameters and axial height. Its lateral faces
/// are two analytic `CYLINDRICAL_SURFACE` bands and its ends are annular
/// `PLANE` faces. No polygon facets are emitted.
pub fn RevolvedProfile::tube(
  outer_diameter : Double,
  inner_diameter : Double,
  height : Double,
) -> RevolvedProfile {
  let ro = outer_diameter / 2.0
  let ri = inner_diameter / 2.0
  RevolvedProfile::polyline(
    [(ri, 0.0), (ro, 0.0), (ro, height), (ri, height)],
    closed=true,
  )
}

///|
/// RevolvedProfile::chamfered_tube builds an annular solid whose outer and
/// inner rims carry analytic 45-degree chamfers. Every chamfer is a
/// `CONICAL_SURFACE`, the bores are `CYLINDRICAL_SURFACE`s, and the ends are
/// annular planes. This is the correct representation of a bearing ring or a
/// chamfered washer.
pub fn RevolvedProfile::chamfered_tube(
  outer_diameter : Double,
  inner_diameter : Double,
  height : Double,
  outer_bottom_chamfer~ : Double = 0.0,
  outer_top_chamfer~ : Double = 0.0,
  inner_bottom_chamfer~ : Double = 0.0,
  inner_top_chamfer~ : Double = 0.0,
) -> RevolvedProfile {
  let ro = outer_diameter / 2.0
  let ri = inner_diameter / 2.0
  let ob = if outer_bottom_chamfer > 0.0 && outer_bottom_chamfer < ro - ri {
    outer_bottom_chamfer
  } else {
    0.0
  }
  let ot = if outer_top_chamfer > 0.0 && outer_top_chamfer < ro - ri {
    outer_top_chamfer
  } else {
    0.0
  }
  let ib = if inner_bottom_chamfer > 0.0 && inner_bottom_chamfer < ro - ri {
    inner_bottom_chamfer
  } else {
    0.0
  }
  let it = if inner_top_chamfer > 0.0 && inner_top_chamfer < ro - ri {
    inner_top_chamfer
  } else {
    0.0
  }
  let pts : Array[Vec2] = []
  // Outer bottom rim, walking up the outside.
  if ob > 0.0 {
    pts.push((ro - ob, 0.0))
    pts.push((ro, ob))
  } else {
    pts.push((ro, 0.0))
  }
  if ot > 0.0 {
    pts.push((ro, height - ot))
    pts.push((ro - ot, height))
  } else {
    pts.push((ro, height))
  }
  // Top annulus inward, walking down the bore.
  if it > 0.0 {
    pts.push((ri + it, height))
    pts.push((ri, height - it))
  } else {
    pts.push((ri, height))
  }
  if ib > 0.0 {
    pts.push((ri, ib))
    pts.push((ri + ib, 0.0))
  } else {
    pts.push((ri, 0.0))
  }
  RevolvedProfile::polyline(pts, closed=true)
}

///|
/// RevolvedProfile::cup builds a solid circular cup: an outer cylinder of
/// `outer_diameter` and height `height` with an optional 45-degree top rim
/// chamfer, a blind cylindrical bore of `bore_diameter` whose floor sits at
/// `floor_thickness` above the base, and an optional 45-degree conical lead-in
/// on the bore rim.
///
/// All lateral faces are analytic (`CYLINDRICAL_SURFACE` and
/// `CONICAL_SURFACE`); the base, the annular top, and the bore floor are planes.
/// It is the analytic outer shell of a socket-head fastener; the hexagonal
/// socket flats are added by the caller as planar facets over this shell.
pub fn RevolvedProfile::cup(
  outer_diameter : Double,
  height : Double,
  bore_diameter : Double,
  floor_thickness : Double,
  top_chamfer~ : Double = 0.0,
  bore_lead_in~ : Double = 0.0,
) -> RevolvedProfile {
  let ro = outer_diameter / 2.0
  let rb = bore_diameter / 2.0
  let ct = if top_chamfer > 0.0 && top_chamfer < ro - rb {
    top_chamfer
  } else {
    0.0
  }
  let lead = if bore_lead_in > 0.0 && bore_lead_in < height - floor_thickness {
    bore_lead_in
  } else {
    0.0
  }
  let pts : Array[Vec2] = [(0.0, 0.0)]
  if ct > 0.0 {
    pts.push((ro, 0.0))
    pts.push((ro, height - ct))
    pts.push((ro - ct, height))
  } else {
    pts.push((ro, 0.0))
    pts.push((ro, height))
  }
  if lead > 0.0 {
    pts.push((rb + lead, height))
    pts.push((rb, height - lead))
  } else {
    pts.push((rb, height))
  }
  pts.push((rb, floor_thickness))
  pts.push((0.0, floor_thickness))
  RevolvedProfile::polyline(pts)
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
