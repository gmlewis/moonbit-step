///|
test "GT2 tooth segments form a continuous non-degenerate closed loop" {
  let geom = match gt2_geometry(20) {
    Ok(g) => g
    Err(e) => abort(e.message())
  }
  let segs = gt2_tooth_segments(geom)
  assert_true(segs.length() == 100)
  let ends = fn(s : @cad.ProfileSegment) -> (@cad.Vec2, @cad.Vec2) {
    match s {
      @cad.SegmentLine(a, b) => (a, b)
      @cad.SegmentArc(a, b, _c) => (a, b)
    }
  }
  for i in 0..<segs.length() {
    let (a, b) = ends(segs[i])
    if (a.0 - b.0).abs() < 1.0e-12 && (a.1 - b.1).abs() < 1.0e-12 {
      fail("degenerate zero-length GT2 segment at \{i}")
    }
    let (next_a, _) = ends(segs[(i + 1) % segs.length()])
    if (b.0 - next_a.0).abs() > 1.0e-12 || (b.1 - next_a.1).abs() > 1.0e-12 {
      fail("disconnected GT2 segment at \{i}")
    }
  }
}
