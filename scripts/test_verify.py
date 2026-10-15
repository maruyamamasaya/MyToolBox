#!/usr/bin/env python3
"""Negative fixtures in isolated copies: never damages repository originals."""
from pathlib import Path
import tempfile
import unittest
import shutil
from verify import check, ROOT

class VerifyTests(unittest.TestCase):
    def fixture(self, destination):
        for path in ROOT.rglob('*.md'):
            relative = path.relative_to(ROOT)
            if any(part.startswith('.') for part in relative.parts) or relative.parts[0] == 'build': continue
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(path, target)
        # File links represent real artifacts; only existence matters to documentation check.
        for folder in ['Sources', 'Tests', 'scripts', 'MyToolBox.xcodeproj', 'Resources', 'evidence']:
            shutil.copytree(ROOT / folder, destination / folder, ignore=shutil.ignore_patterns('__pycache__'), dirs_exist_ok=True)
        (destination / 'build/Build/Products/Release/MyToolBox.app').mkdir(parents=True)
    def testBrokenLinkFailsFast(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name); self.fixture(root)
            self.assertEqual(check(root, fast=True), [])
            (root / 'CURRENT.md').unlink()
            errors = check(root, fast=True)
            self.assertTrue(any('required file missing' in e for e in errors))
            self.assertTrue(any('broken link' in e for e in errors))
    def testOversizeOnlyFailsFull(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name); self.fixture(root)
            with (root / 'CURRENT.md').open('a') as out: out.write('\n' * 81)
            self.assertEqual(check(root, fast=True), [])
            self.assertTrue(any('exceeds 80' in e for e in check(root)))
    def testGeneratedAppCanBeAbsentBeforeFirstBuild(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name); self.fixture(root); shutil.rmtree(root / 'build')
            self.assertEqual(check(root, fast=True), [])
            with (root / 'README.md').open('a') as out: out.write('\n[unknown](build/not-a-declared-artifact.txt)\n')
            self.assertTrue(any('broken link' in e for e in check(root)))
    def testBuildReferenceDocumentsAreExcluded(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name); self.fixture(root)
            reference = root / 'build/reference/README.md'; reference.parent.mkdir(parents=True)
            reference.write_text('[unrelated](missing.txt)')
            self.assertEqual(check(root), [])
    def testOutsideLinkFails(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name); self.fixture(root)
            with (root / 'README.md').open('a') as out: out.write('\n[escape](../../outside.md)\n')
            self.assertTrue(any('escapes repository' in e for e in check(root)))

if __name__ == '__main__': unittest.main()
