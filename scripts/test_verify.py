#!/usr/bin/env python3
"""Negative fixtures in isolated copies: never damages repository originals."""
from pathlib import Path
import tempfile
import plistlib
import unittest
import shutil
from unittest.mock import patch
import embed_tool_apps
from verify import check, ROOT
from app_verify import validate_signing_transition, validate_tool_apps
from tool_catalog import tool_catalog, HOLIDAY_TOOLS

class VerifyTests(unittest.TestCase):
    def testSigningDowngradeIsRejected(self):
        stable = '# designated => identifier "local.MyToolBox" and anchor apple generic'
        adhoc = '# designated => cdhash H"1234"'
        with self.assertRaisesRegex(RuntimeError, 'ad hoc fallback refused'):
            validate_signing_transition(stable, adhoc)
        with self.assertRaisesRegex(RuntimeError, 'ad hoc fallback refused'):
            validate_signing_transition(stable, adhoc.removeprefix('# '))
        validate_signing_transition(adhoc, stable)
        validate_signing_transition(stable, stable)
        validate_signing_transition(adhoc, adhoc)

    def testAllCatalogToolsArePackagedWithoutParentPlist(self):
        with tempfile.TemporaryDirectory() as name:
            app = Path(name) / 'MyToolBox.app'
            contents = app / 'Contents'
            (contents / 'MacOS').mkdir(parents=True)
            (contents / 'MacOS/MyToolBox').write_bytes(b'fixture executable')
            resources = contents / 'Resources'; resources.mkdir()
            for resource in ['MyToolBox.icns', 'PrivacyInfo.xcprivacy', 'Stats-LICENSE.txt', 'JapaneseHolidays.json']:
                (resources / resource).write_bytes(resource.encode())
            # Xcode may run the embed phase before generating the outer Info.plist.
            with patch.dict('os.environ', {'TARGET_BUILD_DIR': name, 'WRAPPER_NAME': 'MyToolBox.app', 'EXPANDED_CODE_SIGN_IDENTITY': '-'}), patch('embed_tool_apps.subprocess.run') as signing:
                embed_tool_apps.main()
            catalog = tool_catalog()
            self.assertEqual(set(p.stem for p in (contents / 'Helpers').glob('*.app')), set(catalog))
            self.assertEqual(signing.call_count, len(catalog))
            validate_tool_apps(app)
            for tool, title in catalog.items():
                helper = contents / 'Helpers' / (tool + '.app') / 'Contents'
                info = plistlib.loads((helper / 'Info.plist').read_bytes())
                self.assertEqual(info['CFBundleDisplayName'], title)
                self.assertEqual(info['CFBundleIconFile'], 'ToolIcon.icns')
                self.assertEqual((helper / 'Resources/ToolIcon.icns').read_bytes(),
                                 (ROOT / 'Resources/ToolIcons' / (tool + '.icns')).read_bytes())
                self.assertEqual((helper / 'MacOS/MyToolBox').read_bytes(), b'fixture executable')
            microphone_calls = [call for call in signing.call_args_list if call.args[0][-1].endswith('/microphoneCheck.app')]
            self.assertEqual(len(microphone_calls), 1)
            self.assertIn('--entitlements', microphone_calls[0].args[0])

    def testHelperIdentityAndMissingExecutableAreRejected(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            for tool in tool_catalog():
                contents = root / 'Contents/Helpers' / (tool + '.app') / 'Contents'
                (contents / 'MacOS').mkdir(parents=True)
                (contents / 'MacOS/MyToolBox').touch()
                with (contents / 'Info.plist').open('wb') as file:
                    plistlib.dump({'MyToolBoxTool': tool, 'CFBundleIdentifier': 'local.MyToolBox.tool.' + tool, 'CFBundleIconFile': 'ToolIcon.icns',
                                  **({'NSMicrophoneUsageDescription': 'マイクチェック'} if tool == 'microphoneCheck' else {})}, file)
            (root / 'Contents/Resources').mkdir(parents=True)
            (root / 'Contents/Resources/JapaneseHolidays.json').write_text('{}')
            for tool in HOLIDAY_TOOLS:
                resources = root / 'Contents/Helpers' / (tool + '.app') / 'Contents/Resources'
                resources.mkdir()
                (resources / 'JapaneseHolidays.json').write_text('{}')
            for tool in tool_catalog():
                resources = root / 'Contents/Helpers' / (tool + '.app') / 'Contents/Resources'
                resources.mkdir(exist_ok=True)
                shutil.copy2(ROOT / 'Resources/ToolIcons' / (tool + '.icns'), resources / 'ToolIcon.icns')
            holiday = root / 'Contents/Helpers/businessDays.app/Contents/Resources/JapaneseHolidays.json'
            validate_tool_apps(root)
            icon = root / 'Contents/Helpers/localMemo.app/Contents/Resources/ToolIcon.icns'
            original_icon = icon.read_bytes()
            icon.unlink()
            with self.assertRaisesRegex(RuntimeError, 'icon missing or mismatched: localMemo'):
                validate_tool_apps(root)
            icon.write_bytes(b'incorrect icon')
            with self.assertRaisesRegex(RuntimeError, 'icon missing or mismatched: localMemo'):
                validate_tool_apps(root)
            icon.write_bytes(original_icon)
            for tool in tool_catalog():
                executable = root / 'Contents/Helpers' / (tool + '.app') / 'Contents/MacOS/MyToolBox'
                executable.unlink()
                with self.assertRaisesRegex(RuntimeError, 'executable missing: ' + tool):
                    validate_tool_apps(root)
                executable.touch()
            holiday.unlink()
            with self.assertRaisesRegex(RuntimeError, 'holiday data'):
                validate_tool_apps(root)
            holiday.write_text('{"different":true}')
            with self.assertRaisesRegex(RuntimeError, 'holiday data'):
                validate_tool_apps(root)
            holiday.write_text('{}')
            microphone = root / 'Contents/Helpers/microphoneCheck.app/Contents/Info.plist'
            original = microphone.read_bytes()
            info = plistlib.loads(original); del info['NSMicrophoneUsageDescription']
            microphone.write_bytes(plistlib.dumps(info))
            with self.assertRaisesRegex(RuntimeError, 'usage description missing'):
                validate_tool_apps(root)
            microphone.write_bytes(original)
            memo = root / 'Contents/Helpers/localMemo.app/Contents'
            with (memo / 'Info.plist').open('wb') as file:
                plistlib.dump({'MyToolBoxTool': 'timerBoard', 'CFBundleIdentifier': 'local.MyToolBox.tool.localMemo'}, file)
            with self.assertRaisesRegex(RuntimeError, 'identity mismatch'):
                validate_tool_apps(root)
            (memo / 'MacOS/MyToolBox').unlink()
            with self.assertRaisesRegex(RuntimeError, 'executable missing'):
                validate_tool_apps(root)

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
