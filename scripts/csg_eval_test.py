#!/usr/bin/env python3
"""Self-tests for scripts/csg_eval.py (stdlib unittest)."""

import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent
sys.path.insert(0, str(SCRIPTS))

import csg_eval as c  # noqa: E402

HAVE_DRAW = bool(shutil.which("DRAWEXE") or shutil.which("occt-draw"))


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


# A left-folded union ((a UNION b) UNION c), then a difference with d.
NESTED = wrap(
    "\n".join(
        [
            "#10=MANIFOLD_SOLID_BREP('a',#11);",
            "#20=MANIFOLD_SOLID_BREP('b',#21);",
            "#30=MANIFOLD_SOLID_BREP('c',#31);",
            "#40=MANIFOLD_SOLID_BREP('d',#41);",
            "#50=BOOLEAN_RESULT('ab',.UNION.,#10,#20);",
            "#51=BOOLEAN_RESULT('abc',.UNION.,#50,#30);",
            "#52=BOOLEAN_RESULT('root',.DIFFERENCE.,#51,#40);",
            "#60=CSG_SOLID('root',#52);",
        ]
    )
)


class ParsingTests(unittest.TestCase):
    def test_parses_booleans_and_roots(self):
        records = c.parse_records(NESTED)
        self.assertEqual(records[50].type, "BOOLEAN_RESULT")
        self.assertEqual(records[10].type, "MANIFOLD_SOLID_BREP")
        self.assertEqual(c.csg_roots(records), [52])
        self.assertEqual(c.boolean_operands(records[52]), (".DIFFERENCE.", 51, 40))

    def test_plan_is_post_order_left_fold(self):
        records = c.parse_records(NESTED)
        plan = c.evaluation_plan(records, 52)
        self.assertEqual(
            [(s.kind, s.ref, s.op) for s in plan],
            [
                ("leaf", 10, ""),
                ("leaf", 20, ""),
                ("boolean", 50, ".UNION."),
                ("leaf", 30, ""),
                ("boolean", 51, ".UNION."),
                ("leaf", 40, ""),
                ("boolean", 52, ".DIFFERENCE."),
            ],
        )

    def test_rejects_unknown_operator(self):
        text = wrap(
            "#10=MANIFOLD_SOLID_BREP('a',#11);\n"
            "#20=MANIFOLD_SOLID_BREP('b',#21);\n"
            "#30=BOOLEAN_RESULT('bad',.XOR.,#10,#20);\n"
        )
        records = c.parse_records(text)
        with self.assertRaises(c.CsgEvalError):
            c.evaluation_plan(records, 30)

    def test_rejects_missing_entity(self):
        records = c.parse_records(NESTED)
        with self.assertRaises(c.CsgEvalError):
            c.evaluation_plan(records, 999)

    def test_requires_a_root(self):
        text = wrap("#10=MANIFOLD_SOLID_BREP('a',#11);")
        with self.assertRaises(c.CsgEvalError):
            c.require_single_root(c.parse_records(text))

    def test_split_top_level_args(self):
        self.assertEqual(
            c.split_top_level("'a,b',.UNION.,#1,#2"),
            ["'a,b'", ".UNION.", "#1", "#2"],
        )

    def test_file_schema_is_reemitted_as_one_list(self):
        text = (
            "ISO-10303-21;\n"
            "HEADER;\n"
            "FILE_SCHEMA(('AP242'));\n"
            "ENDSEC;\n"
            "DATA;\n"
            "ENDSEC;\n"
            "END-ISO-10303-21;\n"
        )
        self.assertEqual(c.file_schema(text), "('AP242')")


@unittest.skipUnless(HAVE_DRAW, "OCCT DRAWEXE/occt-draw is not installed")
class IntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="csg-eval-test-")
        cls.tmpdir = Path(cls.tmp.name)
        cls.fixture = cls.tmpdir / "fixture.step"
        cls.output = cls.tmpdir / "evaluated.step"
        gen = subprocess.run(
            [
                "moon",
                "run",
                "--target",
                "native",
                "scripts/csg-fixture",
                "--",
                str(cls.fixture),
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=900,
        )
        if gen.returncode != 0 or not cls.fixture.exists():
            raise unittest.SkipTest(
                "could not generate the CSG fixture: " + (gen.stderr or gen.stdout)
            )
        cls.proc = subprocess.run(
            [
                sys.executable,
                str(SCRIPTS / "csg_eval.py"),
                str(cls.fixture),
                "-o",
                str(cls.output),
            ],
            capture_output=True,
            text=True,
            timeout=1800,
        )

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_evaluates_to_a_flat_brep(self):
        self.assertEqual(
            self.proc.returncode, 0, self.proc.stdout + self.proc.stderr
        )
        text = self.output.read_text()
        self.assertIn("MANIFOLD_SOLID_BREP", text)
        self.assertNotIn("CSG_SOLID", text)
        self.assertNotIn("BOOLEAN_RESULT", text)

    def test_result_passes_the_full_validator(self):
        self.assertEqual(
            self.proc.returncode, 0, self.proc.stdout + self.proc.stderr
        )
        proc = subprocess.run(
            [sys.executable, str(SCRIPTS / "validate_step.py"), str(self.output)],
            capture_output=True,
            text=True,
            timeout=1800,
        )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("[PASS] occt checkshape", proc.stdout)
        self.assertIn("[PASS] occt mesh", proc.stdout)


if __name__ == "__main__":
    sys.exit(unittest.main())
