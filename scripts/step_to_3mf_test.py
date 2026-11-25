#!/usr/bin/env python3
"""Unit tests for scripts/step_to_3mf.py."""

import struct
import tempfile
import unittest
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

import step_to_3mf as s3


def _write_tetra_stl(path: Path) -> None:
    verts = [
        (0.0, 0.0, 0.0),
        (10.0, 0.0, 0.0),
        (0.0, 10.0, 0.0),
        (0.0, 0.0, 10.0),
    ]
    tris = [(0, 2, 1), (0, 1, 3), (1, 2, 3), (2, 0, 3)]
    buf = bytearray(80)
    buf.extend(struct.pack("<I", len(tris)))
    for a, b, c in tris:
        buf.extend(struct.pack("<3f", 0.0, 0.0, 0.0))
        for idx in (a, b, c):
            buf.extend(struct.pack("<3f", *verts[idx]))
        buf.extend(struct.pack("<H", 0))
    path.write_bytes(bytes(buf))


class StepTo3mfTest(unittest.TestCase):
    def test_binary_stl_to_3mf_creates_valid_archive(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            stl = Path(tmp) / "tetra.stl"
            out = Path(tmp) / "tetra.3mf"
            _write_tetra_stl(stl)
            count = s3.binary_stl_to_3mf(stl, out, "tetra")
            self.assertEqual(count, 4)
            with zipfile.ZipFile(out, "r") as zf:
                names = set(zf.namelist())
                self.assertIn("[Content_Types].xml", names)
                self.assertIn("_rels/.rels", names)
                self.assertIn("3D/3dmodel.model", names)
                root = ET.fromstring(zf.read("3D/3dmodel.model"))
                self.assertEqual(root.attrib.get("unit"), "millimeter")

    def test_postprocess_wraps_multibody_assembly(self) -> None:
        ns = s3.MODEL_NS
        model_xml = (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<model unit="millimeter" xmlns="{ns}">\n'
            "  <resources>\n"
            '    <object id="1" type="model"><mesh/></object>\n'
            '    <object id="2" type="model"><mesh/></object>\n'
            "  </resources>\n"
            "  <build>\n"
            '    <item objectid="1"/>\n'
            '    <item objectid="2"/>\n'
            "  </build>\n"
            "</model>\n"
        )
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "cartridge.3mf"
            with zipfile.ZipFile(out, "w") as zf:
                zf.writestr("[Content_Types].xml", s3.CONTENT_TYPES_XML)
                zf.writestr("_rels/.rels", s3.RELS_XML)
                zf.writestr("3D/3dmodel.model", model_xml)
            s3.postprocess_3mf_assembly(out)
            with zipfile.ZipFile(out, "r") as zf:
                root = ET.fromstring(zf.read("3D/3dmodel.model"))
                build = root.find(f"{{{ns}}}build")
                assert build is not None
                items = build.findall(f"{{{ns}}}item")
                self.assertEqual(len(items), 1)
                self.assertEqual(items[0].attrib["objectid"], "3")


if __name__ == "__main__":
    unittest.main()
