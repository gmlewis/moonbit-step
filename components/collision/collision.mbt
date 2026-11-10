///|
/// TolerancePolicy is the named tolerance set used by geometric validation.
///
/// Centralising the values keeps arbitrary epsilons out of the component
/// builders and makes every reported measurement interpretable. Lengths are
/// millimetres, angles are degrees, volumes are cubic millimetres.
pub(all) struct TolerancePolicy {
  /// General linear tolerance for dimensions and placements.
  linear_mm : Double
  /// Angular tolerance for axes and orientations.
  angular_deg : Double
  /// Volume tolerance for common-volume checks.
  volume_mm3 : Double
  /// Two surfaces closer than this are in contact rather than clear.
  contact_mm : Double
  /// Allowed deviation between equivalent surfaces in golden comparisons.
  surface_deviation_mm : Double
}

///|
/// TolerancePolicy::default returns the validation tolerances used by the
/// component tests. The contact tolerance is deliberately small (1 micrometre)
/// so that a nominal face-to-face joint is contact, not penetration.
pub fn TolerancePolicy::default() -> TolerancePolicy {
  {
    linear_mm: 1.0e-6,
    angular_deg: 1.0e-6,
    volume_mm3: 1.0e-6,
    contact_mm: 1.0e-6,
    surface_deviation_mm: 1.0e-3,
  }
}

///|
/// TolerancePolicy::coarse returns looser tolerances for large assemblies or
/// tessellated references.
pub fn TolerancePolicy::coarse() -> TolerancePolicy {
  {
    linear_mm: 1.0e-3,
    angular_deg: 1.0e-3,
    volume_mm3: 1.0e-3,
    contact_mm: 1.0e-3,
    surface_deviation_mm: 1.0e-2,
  }
}

///|
/// Aabb is a world-axis-aligned bounding box.
pub(all) struct Aabb {
  min_pt : @cad.Vec3
  max_pt : @cad.Vec3
}

///|
/// Aabb::volume returns the box volume (zero when degenerate).
pub fn Aabb::volume(self : Aabb) -> Double {
  let dx = self.max_pt.0 - self.min_pt.0
  let dy = self.max_pt.1 - self.min_pt.1
  let dz = self.max_pt.2 - self.min_pt.2
  if dx <= 0.0 || dy <= 0.0 || dz <= 0.0 {
    0.0
  } else {
    dx * dy * dz
  }
}

///|
/// Aabb::intersection returns the overlapping box, or None when disjoint.
pub fn Aabb::intersection(self : Aabb, other : Aabb) -> Aabb? {
  let min_pt = (
    max_d(self.min_pt.0, other.min_pt.0),
    max_d(self.min_pt.1, other.min_pt.1),
    max_d(self.min_pt.2, other.min_pt.2),
  )
  let max_pt = (
    min_d(self.max_pt.0, other.max_pt.0),
    min_d(self.max_pt.1, other.max_pt.1),
    min_d(self.max_pt.2, other.max_pt.2),
  )
  if min_pt.0 > max_pt.0 || min_pt.1 > max_pt.1 || min_pt.2 > max_pt.2 {
    None
  } else {
    Some({ min_pt, max_pt, })
  }
}

///|
/// Aabb::overlaps is a broad-phase test with separation tolerance.
pub fn Aabb::overlaps(self : Aabb, other : Aabb, tol_mm : Double) -> Bool {
  self.min_pt.0 <= other.max_pt.0 + tol_mm &&
  self.max_pt.0 >= other.min_pt.0 - tol_mm &&
  self.min_pt.1 <= other.max_pt.1 + tol_mm &&
  self.max_pt.1 >= other.min_pt.1 - tol_mm &&
  self.min_pt.2 <= other.max_pt.2 + tol_mm &&
  self.max_pt.2 >= other.min_pt.2 - tol_mm
}

///|
/// Obb is an oriented bounding box: a local axis-aligned box transformed by a
/// rigid placement. `axes` are unit vectors (the world directions of the local
/// X, Y, and Z axes); `half_extents` are the half sizes along those axes.
pub(all) struct Obb {
  center : @cad.Vec3
  half_extents : @cad.Vec3
  axes : (@cad.Vec3, @cad.Vec3, @cad.Vec3)
}

///|
/// Obb::from_placement builds an OBB from a local box and a rigid placement.
pub fn Obb::from_placement(
  placement : @common.Placement,
  bounds : (Double, Double, Double, Double, Double, Double),
) -> Obb {
  let (x0, x1, y0, y1, z0, z1) = bounds
  let local_center = ((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0)
  let half_extents = ((x1 - x0) / 2.0, (y1 - y0) / 2.0, (z1 - z0) / 2.0)
  let center = placement.apply_point(local_center)
  let ax = placement.apply_dir((1.0, 0.0, 0.0))
  let ay = placement.apply_dir((0.0, 1.0, 0.0))
  let az = placement.apply_dir((0.0, 0.0, 1.0))
  { center, half_extents, axes: (ax, ay, az), }
}

///|
/// Obb::aabb returns the world-axis-aligned box enclosing the OBB.
pub fn Obb::aabb(self : Obb) -> Aabb {
  let (ax, ay, az) = self.axes
  let (hx, hy, hz) = self.half_extents
  let ex = hx * ax.0.abs() + hy * ay.0.abs() + hz * az.0.abs()
  let ey = hx * ax.1.abs() + hy * ay.1.abs() + hz * az.1.abs()
  let ez = hx * ax.2.abs() + hy * ay.2.abs() + hz * az.2.abs()
  {
    min_pt: (self.center.0 - ex, self.center.1 - ey, self.center.2 - ez),
    max_pt: (self.center.0 + ex, self.center.1 + ey, self.center.2 + ez),
  }
}

///|
/// Obb::volume returns the box volume.
pub fn Obb::volume(self : Obb) -> Double {
  8.0 * self.half_extents.0 * self.half_extents.1 * self.half_extents.2
}

///|
/// CollisionKind is the geometric relationship between two placed solids.
pub(all) enum CollisionKind {
  /// A positive gap separates the solids.
  Clearance
  /// Surfaces meet within the contact tolerance (zero-volume intersection).
  Contact
  /// An explicitly permitted overlap (declared interference fit).
  InterferenceFit
  /// Unintended positive-volume overlap.
  Collision
  /// Geometry that cannot be classified reliably.
  Indeterminate
}

///|
/// CollisionKind::to_string returns a stable display token.
pub fn CollisionKind::to_string(self : CollisionKind) -> String {
  match self {
    Clearance => "clearance"
    Contact => "contact"
    InterferenceFit => "interference-fit"
    Collision => "collision"
    Indeterminate => "indeterminate"
  }
}

///|
/// CollisionKind::severity orders kinds from least to most serious.
pub fn CollisionKind::severity(self : CollisionKind) -> Int32 {
  match self {
    Clearance => 0
    Contact => 1
    InterferenceFit => 2
    Collision => 3
    Indeterminate => 4
  }
}

///|
/// PairGeometry is the narrow-phase result for one pair of OBBs.
pub(all) struct PairGeometry {
  kind : CollisionKind
  /// Minimum penetration depth along the minimum-overlap separating axis.
  penetration_mm : Double
  /// Lower bound on the gap along the best separating axis (zero otherwise).
  separation_mm : Double
  /// Upper bound on the common volume, from the AABB intersection.
  overlap_volume_mm3 : Double
  /// AABB intersection region when the broad phase overlaps.
  region : Aabb?
}

///|
/// classify_obb_pair performs a narrow-phase separating-axis test on two
/// oriented boxes.
///
/// AABB overlap is only used to report a region and an upper bound on the
/// common volume. The classification itself uses all 15 box separating axes
/// (three per box plus nine edge-cross axes), so a face-to-face joint is
/// contact and a positive-volume overlap is a collision.
///
/// For a non-convex cross-section (for example a T-slot extrusion) the OBB is
/// the convex envelope of the solid. A reported collision is therefore
/// conservative: every reported collision lies inside the envelopes, and
/// contact at the envelope is still a valid contact for the corner material
/// that actually meets at a frame joint.
pub fn classify_obb_pair(
  a : Obb,
  b : Obb,
  tol~ : TolerancePolicy = TolerancePolicy::default(),
) -> PairGeometry {
  let aa = Obb::axes_array(a)
  let ba = Obb::axes_array(b)
  let ha = Obb::half_array(a)
  let hb = Obb::half_array(b)
  let delta = sub3(b.center, a.center)
  let axes_to_test : Array[@cad.Vec3] = [
    aa[0],
    aa[1],
    aa[2],
    ba[0],
    ba[1],
    ba[2],
  ]
  for i in 0..<3 {
    for j in 0..<3 {
      let c = cross3(aa[i], ba[j])
      if length3(c) > 1.0e-9 {
        axes_to_test.push(normalize3(c))
      }
    }
  }
  let mut min_overlap = 1.0e300
  let mut separated = false
  let mut best_gap = -1.0e300
  for axis in axes_to_test {
    let ra = ha[0] * dot3(aa[0], axis).abs() +
      ha[1] * dot3(aa[1], axis).abs() +
      ha[2] * dot3(aa[2], axis).abs()
    let rb = hb[0] * dot3(ba[0], axis).abs() +
      hb[1] * dot3(ba[1], axis).abs() +
      hb[2] * dot3(ba[2], axis).abs()
    let distance = dot3(delta, axis).abs()
    let overlap = ra + rb - distance
    if overlap < min_overlap {
      min_overlap = overlap
    }
    if overlap < -tol.linear_mm {
      separated = true
      let gap = -overlap
      if gap > best_gap {
        best_gap = gap
      }
    }
  }
  let aabb_a = Obb::aabb(a)
  let aabb_b = Obb::aabb(b)
  let region = aabb_a.intersection(aabb_b)
  let overlap_volume = match region {
    Some(r) => r.volume()
    None => 0.0
  }
  if separated {
    let gap = if best_gap > 0.0 { best_gap } else { 0.0 }
    if gap <= tol.contact_mm {
      {
        kind: Contact,
        penetration_mm: 0.0,
        separation_mm: 0.0,
        overlap_volume_mm3: 0.0,
        region: None,
      }
    } else {
      {
        kind: Clearance,
        penetration_mm: 0.0,
        separation_mm: gap,
        overlap_volume_mm3: 0.0,
        region: None,
      }
    }
  } else if min_overlap <= tol.contact_mm {
    {
      kind: Contact,
      penetration_mm: 0.0,
      separation_mm: 0.0,
      overlap_volume_mm3: 0.0,
      region: None,
    }
  } else {
    {
      kind: Collision,
      penetration_mm: min_overlap,
      separation_mm: 0.0,
      overlap_volume_mm3: overlap_volume,
      region,
    }
  }
}

///|
/// PlacedShape is one component layer placed in world coordinates, ready for
/// collision validation.
pub(all) struct PlacedShape {
  instance_name : String
  layer_name : String
  obb : Obb
}

///|
/// ContactPolicy declares component-instance pairs whose overlap is an
/// explicitly permitted interference fit.
///
/// A permitted pair is still measured (penetration depth and region are
/// reported) but is classified as `InterferenceFit` instead of `Collision`.
/// Pairs are matched in either order.
pub(all) struct ContactPolicy {
  permitted_interference : Array[(String, String)]
}

///|
/// ContactPolicy::none permits no interference.
pub fn ContactPolicy::none() -> ContactPolicy {
  { permitted_interference: [], }
}

///|
/// ContactPolicy::permit returns a policy that also permits the named pair.
pub fn ContactPolicy::permit(
  self : ContactPolicy,
  a : String,
  b : String,
) -> ContactPolicy {
  let pairs = self.permitted_interference.copy()
  pairs.push((a, b))
  { permitted_interference: pairs, }
}

//|

///|
fn interference_permitted(
  policy : ContactPolicy,
  a : String,
  b : String,
) -> Bool {
  for (x, y) in policy.permitted_interference {
    if (x == a && y == b) || (x == b && y == a) {
      return true
    }
  }
  false
}

///|
/// placed_shapes materialises every layer of one component instance as a
/// placed OBB. The OBB uses the shape's local bounding box, which is exact for
/// box-like extrusions and conservative for curved or slotted shapes.
pub fn placed_shapes(
  instance_name : String,
  component : @common.Component,
  placement : @common.Placement,
) -> Array[PlacedShape] {
  component
  .layers()
  .map(fn(layer) {
    let combined = @common.Placement::compose(placement, layer.placement)
    {
      instance_name,
      layer_name: layer.name,
      obb: Obb::from_placement(combined, layer.shape.bounding_box()),
    }
  })
}

///|
/// placed_shapes_for_parts builds placed OBBs from an explicit part list.
pub fn placed_shapes_for_parts(
  parts : Array[(String, @common.Component, @common.Placement)],
) -> Array[PlacedShape] {
  let out : Array[PlacedShape] = []
  for (name, component, placement) in parts {
    out.push_iter(placed_shapes(name, component, placement).iter())
  }
  out
}

///|
/// CollisionReport is the aggregated relationship between two component
/// instances.
pub(all) struct CollisionReport {
  instance_a : String
  instance_b : String
  kind : CollisionKind
  penetration_mm : Double
  separation_mm : Double
  overlap_volume_mm3 : Double
  region : Aabb?
}

///|
/// CollisionReport::is_collision reports whether the pair is an unintended
/// positive-volume overlap.
pub fn CollisionReport::is_collision(self : CollisionReport) -> Bool {
  self.kind is Collision
}

///|
/// CollisionReport::is_contact reports whether the pair is in contact.
pub fn CollisionReport::is_contact(self : CollisionReport) -> Bool {
  self.kind is Contact
}

///|
/// CollisionReport::is_interference_fit reports whether the pair is a declared
/// permitted overlap.
pub fn CollisionReport::is_interference_fit(self : CollisionReport) -> Bool {
  self.kind is InterferenceFit
}

///|
/// CollisionReport::summary returns a one-line diagnostic.
pub fn CollisionReport::summary(self : CollisionReport) -> String {
  let region_text = match self.region {
    Some(r) =>
      " region=[(\{r.min_pt.0}, \{r.min_pt.1}, \{r.min_pt.2})..(\{r.max_pt.0}, \{r.max_pt.1}, \{r.max_pt.2})]"
    None => ""
  }
  "\{self.instance_a} vs \{self.instance_b}: \{self.kind.to_string()}" +
  " penetration=\{self.penetration_mm}mm separation=\{self.separation_mm}mm" +
  " overlap_volume<=\{self.overlap_volume_mm3}mm^3" +
  region_text
}

//|
// Aggregate is the mutable accumulator used while grouping layer pairs by
// component instance pair.

///|
priv struct Aggregate {
  instance_a : String
  instance_b : String
  mut kind : CollisionKind
  mut penetration_mm : Double
  mut separation_mm : Double
  mut overlap_volume_mm3 : Double
  mut region_min : @cad.Vec3
  mut region_max : @cad.Vec3
  mut has_region : Bool
}

///|
/// pair_reports validates every pair of distinct component instances.
///
/// Layer pairs belonging to the same instance are skipped. Results are
/// aggregated per instance pair, taking the most serious kind, the deepest
/// penetration, the closest clearance, and an upper bound on the common volume.
/// A pair listed in `policy` as a permitted interference fit is classified as
/// `InterferenceFit` while keeping its measured penetration and region.
pub fn pair_reports(
  shapes : Array[PlacedShape],
  tol~ : TolerancePolicy = TolerancePolicy::default(),
  policy~ : ContactPolicy = ContactPolicy::none(),
) -> Array[CollisionReport] {
  let aggregates : Array[Aggregate] = []
  for i in 0..<shapes.length() {
    for j in (i + 1)..<shapes.length() {
      let a = shapes[i]
      let b = shapes[j]
      if a.instance_name == b.instance_name {
        continue
      }
      let broad = Obb::aabb(a.obb).overlaps(Obb::aabb(b.obb), tol.linear_mm)
      let geom = if broad {
        classify_obb_pair(a.obb, b.obb, tol~)
      } else {
        let aa = Obb::aabb(a.obb)
        let bb = Obb::aabb(b.obb)
        {
          kind: Clearance,
          penetration_mm: 0.0,
          separation_mm: aabb_gap(aa, bb),
          overlap_volume_mm3: 0.0,
          region: None,
        }
      }
      let index = find_aggregate(aggregates, a.instance_name, b.instance_name)
      match index {
        None =>
          aggregates.push({
            instance_a: a.instance_name,
            instance_b: b.instance_name,
            kind: geom.kind,
            penetration_mm: geom.penetration_mm,
            separation_mm: geom.separation_mm,
            overlap_volume_mm3: geom.overlap_volume_mm3,
            region_min: match geom.region {
              Some(r) => r.min_pt
              None => (0.0, 0.0, 0.0)
            },
            region_max: match geom.region {
              Some(r) => r.max_pt
              None => (0.0, 0.0, 0.0)
            },
            has_region: geom.region is Some(_),
          })
        Some(k) => merge_aggregate(aggregates[k], geom)
      }
    }
  }
  aggregates.map(fn(agg) {
    let kind = if agg.kind is Collision &&
      interference_permitted(policy, agg.instance_a, agg.instance_b) {
      InterferenceFit
    } else {
      agg.kind
    }
    {
      instance_a: agg.instance_a,
      instance_b: agg.instance_b,
      kind,
      penetration_mm: agg.penetration_mm,
      separation_mm: agg.separation_mm,
      overlap_volume_mm3: agg.overlap_volume_mm3,
      region: if agg.has_region {
        Some({ min_pt: agg.region_min, max_pt: agg.region_max, })
      } else {
        None
      },
    }
  })
}

//|

///|
fn find_aggregate(
  aggregates : Array[Aggregate],
  a : String,
  b : String,
) -> Int32? {
  for i in 0..<aggregates.length() {
    let agg = aggregates[i]
    if agg.instance_a == a && agg.instance_b == b {
      return Some(i)
    }
  }
  None
}

//|

///|
fn merge_aggregate(agg : Aggregate, geom : PairGeometry) -> Unit {
  if geom.kind.severity() > agg.kind.severity() {
    agg.kind = geom.kind
  }
  match geom.kind {
    Collision => {
      if geom.penetration_mm > agg.penetration_mm {
        agg.penetration_mm = geom.penetration_mm
      }
      agg.overlap_volume_mm3 = agg.overlap_volume_mm3 + geom.overlap_volume_mm3
    }
    Clearance =>
      if agg.kind is Clearance {
        if geom.separation_mm < agg.separation_mm {
          agg.separation_mm = geom.separation_mm
        }
      }
    _ => ()
  }
  match geom.region {
    Some(r) =>
      if agg.has_region {
        agg.region_min = (
          min_d(agg.region_min.0, r.min_pt.0),
          min_d(agg.region_min.1, r.min_pt.1),
          min_d(agg.region_min.2, r.min_pt.2),
        )
        agg.region_max = (
          max_d(agg.region_max.0, r.max_pt.0),
          max_d(agg.region_max.1, r.max_pt.1),
          max_d(agg.region_max.2, r.max_pt.2),
        )
      } else {
        agg.region_min = r.min_pt
        agg.region_max = r.max_pt
        agg.has_region = true
      }
    None => ()
  }
}

//|

///|
fn aabb_gap(a : Aabb, b : Aabb) -> Double {
  let dx = max_d(max_d(a.min_pt.0 - b.max_pt.0, b.min_pt.0 - a.max_pt.0), 0.0)
  let dy = max_d(max_d(a.min_pt.1 - b.max_pt.1, b.min_pt.1 - a.max_pt.1), 0.0)
  let dz = max_d(max_d(a.min_pt.2 - b.max_pt.2, b.min_pt.2 - a.max_pt.2), 0.0)
  Double::sqrt(dx * dx + dy * dy + dz * dz)
}

//|

///|
fn max_d(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

//|

///|
fn min_d(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

//|

///|
fn sub3(a : @cad.Vec3, b : @cad.Vec3) -> @cad.Vec3 {
  (a.0 - b.0, a.1 - b.1, a.2 - b.2)
}

//|

///|
fn dot3(a : @cad.Vec3, b : @cad.Vec3) -> Double {
  a.0 * b.0 + a.1 * b.1 + a.2 * b.2
}

//|

///|
fn cross3(a : @cad.Vec3, b : @cad.Vec3) -> @cad.Vec3 {
  (a.1 * b.2 - a.2 * b.1, a.2 * b.0 - a.0 * b.2, a.0 * b.1 - a.1 * b.0)
}

//|

///|
fn length3(a : @cad.Vec3) -> Double {
  Double::sqrt(dot3(a, a))
}

//|

///|
fn normalize3(a : @cad.Vec3) -> @cad.Vec3 {
  let l = length3(a)
  if l <= 1.0e-12 {
    a
  } else {
    (a.0 / l, a.1 / l, a.2 / l)
  }
}

//|

///|
fn Obb::axes_array(self : Obb) -> Array[@cad.Vec3] {
  let (x, y, z) = self.axes
  [x, y, z]
}

//|

///|
fn Obb::half_array(self : Obb) -> Array[Double] {
  [self.half_extents.0, self.half_extents.1, self.half_extents.2]
}
