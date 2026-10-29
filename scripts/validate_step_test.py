#!/usr/bin/env python3
"""Self-tests for scripts/validate_step.py (stdlib unittest)."""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import validate_step as v  # noqa: E402


def wrap(data: str) -> str:
    return (
        "ISO-10303-21;\n"
        "HEADER;\n"
        "FILE_DESCRIPTION((''),'2;1');\n"
        "ENDSEC;\n"
        "DATA;\n"
        f"{data}\n"
        "ENDSEC;\n"
        "END-ISO-10303-21;\n"
    )


class LexicalTests(unittest.TestCase):
    def test_valid_reals(self):
        text = wrap("#1=CARTESIAN_POINT('',(1.0E-9,2.,3.0));")
        self.assertTrue(v.check_reals(text).ok)

    def test_lowercase_exponent(self):
        text = wrap("#1=CARTESIAN_POINT('',(1.0e-9,2.,3.0));")
        self.assertFalse(v.check_reals(text).ok)

    def test_exponent_needs_decimal_point(self):
        text = wrap("#1=CARTESIAN_POINT('',(1E-9,2.,3.0));")
        self.assertFalse(v.check_reals(text).ok)

    def test_real_needs_leading_digit(self):
        text = wrap("#1=CARTESIAN_POINT('',(.5,2.,3.0));")
        self.assertFalse(v.check_reals(text).ok)

    def test_strings_and_comments_are_ignored(self):
        text = wrap(
            "#1=CARTESIAN_POINT('name 1.0e-9',(0.0,0.0,0.0)); /* 1.0e-9 */"
        )
        self.assertTrue(v.check_reals(text).ok)

    def test_envelope(self):
        self.assertTrue(v.check_envelope(wrap("")).ok)
        self.assertFalse(v.check_envelope("DATA;").ok)


class TopologyTests(unittest.TestCase):
    def cylinder(self, seam_down: str = "F", bottom_lateral: str = "T") -> str:
        """Minimal analytic cylinder with a seam edge.

        The lateral face traverses the seam up, the top circle backwards, the
        seam down, and the bottom circle forwards. `seam_down` and
        `bottom_lateral` let a test flip one use to break the topology.
        """
        return wrap(
            "\n".join(
                [
                    "#1=CARTESIAN_POINT('',(5.0,0.0,0.0));",
                    "#2=CARTESIAN_POINT('',(5.0,0.0,10.0));",
                    "#3=CARTESIAN_POINT('',(0.0,0.0,0.0));",
                    "#4=CARTESIAN_POINT('',(0.0,0.0,10.0));",
                    "#5=DIRECTION('',(0.0,0.0,1.0));",
                    "#6=DIRECTION('',(1.0,0.0,0.0));",
                    "#7=AXIS2_PLACEMENT_3D('',#3,#5,#6);",
                    "#8=AXIS2_PLACEMENT_3D('',#4,#5,#6);",
                    "#9=VERTEX_POINT('',#1);",
                    "#10=VERTEX_POINT('',#2);",
                    "#11=CIRCLE('',#7,5.0);",
                    "#12=CIRCLE('',#8,5.0);",
                    "#13=VECTOR('',#5,1.0);",
                    "#14=LINE('',#1,#13);",
                    "#20=EDGE_CURVE('',#9,#10,#14,.T.);",
                    "#21=EDGE_CURVE('',#9,#9,#11,.T.);",
                    "#22=EDGE_CURVE('',#10,#10,#12,.T.);",
                    "#30=ORIENTED_EDGE('',*,*,#20,.T.);",
                    "#31=ORIENTED_EDGE('',*,*,#22,.F.);",
                    f"#32=ORIENTED_EDGE('',*,*,#20,.{seam_down}.);",
                    f"#33=ORIENTED_EDGE('',*,*,#21,.{bottom_lateral}.);",
                    "#34=ORIENTED_EDGE('',*,*,#21,.F.);",
                    "#35=ORIENTED_EDGE('',*,*,#22,.T.);",
                    "#40=EDGE_LOOP('',(#30,#31,#32,#33));",
                    "#41=EDGE_LOOP('',(#34));",
                    "#42=EDGE_LOOP('',(#35));",
                    "#50=FACE_OUTER_BOUND('',#40,.T.);",
                    "#51=FACE_OUTER_BOUND('',#41,.T.);",
                    "#52=FACE_OUTER_BOUND('',#42,.T.);",
                    "#60=CYLINDRICAL_SURFACE('',#7,5.0);",
                    "#61=PLANE('',#7);",
                    "#62=PLANE('',#8);",
                    "#70=ADVANCED_FACE('',(#50),#60,.T.);",
                    "#71=ADVANCED_FACE('',(#51),#61,.T.);",
                    "#72=ADVANCED_FACE('',(#52),#62,.T.);",
                    "#80=CLOSED_SHELL('',(#70,#71,#72));",
                    "#81=MANIFOLD_SOLID_BREP('',#80);",
                ]
            )
        )

    def test_seam_edge_is_valid_topology(self):
        checks = v.check_topology(v.parse_entities(self.cylinder()))
        self.assertTrue(all(c.ok for c in checks), [c.detail for c in checks])

    def test_seam_with_same_orientation_still_fails(self):
        # Both seam uses belong to the lateral face but have the same sense, so
        # this is not a valid seam.
        checks = v.check_topology(
            v.parse_entities(self.cylinder(seam_down="T"))
        )
        failing = [c for c in checks if not c.ok]
        self.assertTrue(failing, "same-sense seam uses must fail")
        self.assertTrue(any(c.name == "orientation" for c in failing))

    def test_bottom_edge_used_same_direction_fails_orientation(self):
        checks = v.check_topology(
            v.parse_entities(self.cylinder(bottom_lateral="F"))
        )
        failing = [c for c in checks if not c.ok]
        self.assertTrue(failing, "same-direction uses must fail")
        self.assertTrue(any(c.name == "orientation" for c in failing))


if __name__ == "__main__":
    sys.exit(unittest.main())
