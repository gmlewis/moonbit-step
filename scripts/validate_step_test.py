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


if __name__ == "__main__":
    sys.exit(unittest.main())
