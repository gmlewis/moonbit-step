///|
/// Assembly::placed_shapes materialises every component layer as a world-space
/// oriented bounding box for geometric validation.
pub fn Assembly::placed_shapes(
  self : Assembly,
) -> Array[@collision.PlacedShape] {
  let out : Array[@collision.PlacedShape] = []
  for item in self.items {
    out.push_iter(
      @collision.placed_shapes(
        item.instance_name,
        item.component,
        item.placement,
      ).iter(),
    )
  }
  out
}

///|
/// Assembly::collision_reports classifies every pair of distinct component
/// instances as clearance, contact, or collision.
///
/// The classification uses a narrow-phase separating-axis test on oriented
/// bounding boxes. Bounding-box overlap alone is not reported as a collision.
pub fn Assembly::collision_reports(
  self : Assembly,
  tol~ : @collision.TolerancePolicy = @collision.TolerancePolicy::default(),
  policy~ : @collision.ContactPolicy = @collision.ContactPolicy::none(),
) -> Array[@collision.CollisionReport] {
  @collision.pair_reports(self.placed_shapes(), tol~, policy~)
}

///|
/// Assembly::collisions returns only unintended positive-volume overlaps.
pub fn Assembly::collisions(
  self : Assembly,
  tol~ : @collision.TolerancePolicy = @collision.TolerancePolicy::default(),
) -> Array[@collision.CollisionReport] {
  self.collision_reports(tol~).filter(fn(r) { r.is_collision() })
}

///|
/// Assembly::contacts returns only the pairs that meet within tolerance.
pub fn Assembly::contacts(
  self : Assembly,
  tol~ : @collision.TolerancePolicy = @collision.TolerancePolicy::default(),
) -> Array[@collision.CollisionReport] {
  self.collision_reports(tol~).filter(fn(r) { r.is_contact() })
}

///|
/// Assembly::interference_fits returns only declared permitted overlaps.
pub fn Assembly::interference_fits(
  self : Assembly,
  tol~ : @collision.TolerancePolicy = @collision.TolerancePolicy::default(),
  policy~ : @collision.ContactPolicy = @collision.ContactPolicy::none(),
) -> Array[@collision.CollisionReport] {
  self
  .collision_reports(tol~, policy~)
  .filter(fn(r) { r.is_interference_fit() })
}

///|
/// Assembly::disconnected_instances returns the instance names that are not
/// reachable through contact or overlap from the first instance.
///
/// A floating member has no contact with the rest of the assembly. The check is
/// purely geometric and does not assume the generator's intended joint list.
pub fn Assembly::disconnected_instances(
  self : Assembly,
  tol~ : @collision.TolerancePolicy = @collision.TolerancePolicy::default(),
) -> Array[String] {
  let names = self.component_names()
  if names.is_empty() {
    return []
  }
  let reports = self.collision_reports(tol~)
  let visited : Array[Bool] = []
  for _ in names {
    visited.push(false)
  }
  let queue : Array[Int32] = [0]
  visited[0] = true
  let mut head = 0
  while head < queue.length() {
    let current = queue[head]
    head = head + 1
    for report in reports {
      let connected = report.kind is @collision.CollisionKind::Contact ||
        report.kind is @collision.CollisionKind::Collision ||
        report.kind is @collision.CollisionKind::InterferenceFit
      if connected {
        let other = if report.instance_a == names[current] {
          report.instance_b
        } else if report.instance_b == names[current] {
          report.instance_a
        } else {
          ""
        }
        if other != "" {
          let index = index_of_name(names, other)
          match index {
            Some(k) =>
              if !visited[k] {
                visited[k] = true
                queue.push(k)
              }
            None => ()
          }
        }
      }
    }
  }
  let out : Array[String] = []
  for i in 0..<names.length() {
    if !visited[i] {
      out.push(names[i])
    }
  }
  out
}

///|
/// Assembly::is_connected reports whether every instance is reachable through
/// contacts or overlaps.
pub fn Assembly::is_connected(
  self : Assembly,
  tol~ : @collision.TolerancePolicy = @collision.TolerancePolicy::default(),
) -> Bool {
  self.disconnected_instances(tol~).is_empty()
}

//|

///|
fn index_of_name(names : Array[String], name : String) -> Int32? {
  for i in 0..<names.length() {
    if names[i] == name {
      return Some(i)
    }
  }
  None
}
