# Standards and Supported Data

This document lists what the library actually carries. Dimensions are nominal
product dimensions unless explicitly stated otherwise. The library does **not**
claim tolerance-class compliance, material certification, or interchangeability
beyond the stated tables.

## Metric thread data (ISO 261 / ISO 68-1)

- Sizes: M2, M2.5, M3, M4, M5, M6, M8, M10, M12, M16, M20.
- Coarse pitch series from ISO 261.
- One commonly stocked fine pitch per size (ISO 261 fine series).
- Basic profile dimensions use ISO 68-1. Everything is derived from
  `H = sqrt(3)/2 * P`, so the diameter/depth pairs are exactly consistent:
  - pitch diameter `d2 = D2 = d - (3/4) H`
  - external minor `d3 = d - (17/12) H = d - 2 h3`
  - internal minor `D1 = d - (5/4) H = d - 2 H1`
  - external depth `h3 = (17/24) H`, internal depth `H1 = (5/8) H`
  - flank angle: 60 degrees included. The external ridge is `P/8` wide at the
    major diameter and `5P/6` at the basic minor diameter; the internal ridge
    is `P/4` wide at the minor diameter and `7P/8` at the major diameter. These
    widths give `tan(30 deg) = (root_width - crest_width) / (2 * depth)`.
- Right-hand and left-hand thread direction are modeled by the swept helix.

The library computes these derived values; it does not embed a full tolerance
table (6g/6H limits are not modeled as limits).

## Fasteners

### ISO 4762 — hexagon socket head cap screws

- Revision used: ISO 4762:2004.
- Supported sizes: M2, M2.5, M3, M4, M5, M6, M8, M10, M12, M16, M20.
- Data: head diameter `dk`, head height `k`, socket width across flats `s`,
  minimum socket depth `t`.
- Supported length ranges are listed in `components/standards/iso4762.mbt`;
  configurations outside them are rejected with an explicit error.
- Threaded length follows the standard `b` ranges (`2d + 6`, `2d + 12`,
  `2d + 25` by length band); short screws are fully threaded.

### ISO 4032 — hexagon regular nuts

- Revision used: ISO 4032:2023.
- Supported sizes: M2, M2.5, M3, M4, M5, M6, M8, M10, M12, M16, M20.
- Data: width across flats `s`, nut height `m`.
- The modeled bore is a clearance bore or, in fully modeled mode, a helical
  internal thread ridge.

### ISO 7089 — plain washers, normal series

- Revision used: ISO 7089:2000.
- Supported sizes: M2, M2.5, M3, M4, M5, M6, M8, M10, M12, M16, M20.
- Data: inner diameter `d1`, outer diameter `d2`, thickness `h`.

### ISO 4017 / ISO 4014 — hexagon head screws and bolts

- Revisions used: ISO 4017:2014 and ISO 4014:2011.
- Supported sizes: M2, M2.5, M3, M4, M5, M6, M8, M10, M12, M16, M20.
- Data: width across flats `s`, head height `k`.
- ISO 4017 is fully threaded. ISO 4014 uses the nominal `b` thread length.

### DIN 976-1 — metric threaded rods

- Revision used: DIN 976-1:2016.
- Supported sizes: the same metric size set; lengths 10 mm to 3000 mm.
- Fully threaded rod; no plain end sections or chamfers.

### ISO 7380-1 — button head hexagon socket screws

- Revision used: ISO 7380-1:2022 (designation).
- Supported sizes: M3, M4, M5, M6, M8, M10.
- Data: head diameter `dk`, head height `k`, socket width across flats `s`,
  socket depth `t`, and a practical length range.
- The head is a spherical-cap dome with a flat top and a modeled hexagon
  socket. The flat-top radius and dome profile are engineering approximations;
  the four dimensions above are the standard's nominal values.

### ISO 10642 — countersunk head hexagon socket screws

- Revision used: ISO 10642:2004 (designation).
- Supported sizes: M3, M4, M5, M6, M8, M10.
- Data: head diameter `dk`, head height `k`, 90° head angle, socket across
  flats `s`, socket depth `t`, and a practical length range.
- The head is an analytic 90° countersink frustum (45° half-angle) with a flat
  top and a modeled hexagon socket.

## Motion and hardware components (parametric, no standard table)

- Shafts, stepped shafts, spacers, bushings, dowel pins, hex standoffs, and
  compression springs are parametric components with explicit dimensions.
- They do **not** imply a standard part number, tolerance class, spring rate,
  or material. Verify against the applicable standard or manufacturer data.
- Bearings use the ISO 15 boundary table described below.

## Extrusion profiles

`components/profiles` provides **generic** T-slot envelopes named
`generic-2020`, `generic-2040`, `generic-3030`, and `generic-4040`.

These are not a standard. Slot width, neck depth, cavity width, wall thickness,
and core bore vary by manufacturer and series. The presets are documented
engineering assumptions for parametric experiments, and every dimension is
available through `TSlotProfile::custom`. A model built from a preset must be
checked against the intended vendor's drawing before it is used to buy or cut
aluminum.

## Bearings

`components/motion` carries boundary dimensions for common ISO 15 radial ball
bearings:

- 608, 6000–6006, 6200–6206, 6300–6305.

Bore `d`, outside diameter `D`, and width `B` are catalogue boundary values.
Internal ring thickness, roller count, and rolling elements are parametric and
simplified; they are not catalogue geometry for a specific manufacturer.

## Gears

- Involute geometry follows standard external gear practice and ISO 21771
  terminology.
- Supported: external spur gears with module, tooth count, pressure angle,
  face width, bore, backlash, and polygonal resolution controls.
- Supported: an approximate straight-spur planetary set (sun, equally spaced
  planets, ring). The ring tooth form is a trapezoidal approximation, not an
  exact internal involute envelope; the set enforces `ring = sun + 2 * planet`
  and `(sun + ring) % planet_count == 0`.
- Not supported yet: helical gears, exact internal involute ring gears,
  bevel/worm gears, profile shift, and root fillets.

The existing `examples/38-planetary-gearbox` herringbone planetary generator is
preserved and is not replaced by this package.

The planetary set phases each planet against the sun tooth phase at its radial,
so valid layouts whose planet angles are not multiples of the sun pitch (such
as 18/12/42 with five planets) mesh without tooth interference. External model
cross-checks and the two candidates rejected for contradicting their claimed
standards are recorded in `GOLDEN_REFERENCES.md`.

## What is deliberately not claimed

- No ISO tolerance-class conformity (6g/6H limits, fits, gauging).
- No material or strength data.
- No vendor-compatible T-slot geometry.
- No exact bearing internal geometry.
- No gear load-capacity rating. Gear root fillets and tip chamfers are modelled
  as documented polyline arcs, and the internal ring is an exact internal
  involute envelope, but neither implies a rating or an ISO profile-tolerance
  claim.

## Golden corroboration (2026-11-10)

The step.parts ISO 7380 references (M4 x 10 and M5 x 12) corroborate the
`iso7380_size` head diameter (`dk` 7.6 / 9.5 mm) and the `L + k` overall length
(12.2 / 14.75 mm). The ISO 10642 references corroborate the 90 degree
countersink and the nominal overall length (10.0 / 12.0 mm); their measured
head diameters (8.131 / 10.181 mm) sit slightly below the nominal `dk` maxima,
which is consistent with countersink edge rounding but is not used to change
the table. See `GOLDEN_REFERENCES.md` for the full verdicts.

## Round 7: chamfer and thread-length semantics

- ISO 4762 and ISO 4014 measure the thread length `b` from the **tip**. The
  builders place the thread at `z = 0..b` and any plain shank under the head.
  This was corrected in round 7; see `SESSION_REPORT_07.md`.
- ISO 4762 head diameter, ISO 7380-1 head diameter, and ISO 10642 head diameter
  are **maxima** in their standards. The matrix comparison treats a vendor head
  below the maximum as permitted, not as a contradiction.
- ISO 7089 specifies no edge chamfer or deburr. The washer is sharp at every
  detail level and the record says so.
- The head/socket/tip chamfers are engineering defaults where a standard is
  silent. The sizes are documented in `FEATURES.md` and `GEOMETRY.md`; they are
  not claimed as standard dimensions.
- No ISO tolerance class (6g/6H), material property, or strength value is
  claimed.
