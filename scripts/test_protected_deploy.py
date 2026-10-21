#!/usr/bin/env python3
"""Unprivileged tests. Real OS denial is tested by installer on a fixture."""
import contextlib
import io
from pathlib import Path
import plistlib
import subprocess
import shutil
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import protected_deploy as gate


class GateTests(unittest.TestCase):
    def transaction(self, apply=True, invalid=None, running=None):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        source, target, state = root / 'build.app', root / 'target.app', root / 'gate'
        for path in [source, target, state]:
            path.mkdir()
        (source / 'version').write_text('new')
        (target / 'version').write_text('old')
        validations, stops, protected, unlocked = [], [], [], []

        def validate(path, req):
            validations.append(path)
            if len(validations) == invalid:
                raise RuntimeError('bad signature')
            return {'windowManager'}

        def stopped():
            stops.append(True)
            if len(stops) == running:
                raise RuntimeError('app started')

        def run(args):
            self.assertEqual(args[:2], ['/usr/bin/ditto', '--noacl'])
            shutil.copytree(args[-2], args[-1])

        with patch.object(gate, 'TARGET', target), patch.object(gate, 'STATE', state), \
                patch.object(gate, 'verify_protection'), patch.object(gate, 'validate', validate), \
                patch.object(gate, 'protect', lambda p: protected.append(p)), \
                patch.object(gate, 'unlock', lambda p: unlocked.append(p)), \
                patch.object(gate, 'run', run), patch.object(gate, 'stopped', stopped), \
                contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            try:
                gate.update({'source': str(source), 'requirement': 'pinned'}, apply)
                error = None
            except RuntimeError as caught:
                error = caught
        return target, state, protected, unlocked, error

    def test_check_does_not_unlock_target(self):
        target, state, protected, unlocked, error = self.transaction(apply=False)
        self.assertIsNone(error)
        self.assertNotIn(target, unlocked)
        self.assertEqual((target / 'version').read_text(), 'old')
        self.assertFalse(list(state.iterdir()))

    def test_signed_candidate_failure_does_not_unlock_target(self):
        target, state, protected, unlocked, error = self.transaction(invalid=2)
        self.assertIsNotNone(error)
        self.assertNotIn(target, unlocked)
        self.assertEqual((target / 'version').read_text(), 'old')

    def test_post_validation_failure_restores_protected_original(self):
        target, state, protected, unlocked, error = self.transaction(invalid=3)
        self.assertIsNotNone(error)
        self.assertEqual((target / 'version').read_text(), 'old')
        self.assertEqual(protected[-1], target)

    def test_success_reprotects_and_removes_backup(self):
        target, state, protected, unlocked, error = self.transaction()
        self.assertIsNone(error)
        self.assertEqual((target / 'version').read_text(), 'new')
        self.assertEqual(protected[-1], target)
        self.assertFalse(list(state.iterdir()))

    def test_started_app_keeps_backup(self):
        target, state, protected, unlocked, error = self.transaction(running=3)
        self.assertIsNotNone(error)
        self.assertEqual((target / 'version').read_text(), 'new')
        self.assertEqual(next(state.glob('*/previous.app/version')).read_text(), 'old')

    def test_tree_rejects_symlink(self):
        with tempfile.TemporaryDirectory() as tmp:
            app = Path(tmp)
            (app / 'link').symlink_to('/etc')
            with self.assertRaises(RuntimeError):
                gate.tree(app)

    def test_owned_directory_rejects_writable_or_user_owned(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(RuntimeError):
                gate.owned_directory(Path(tmp))

    def test_process_check_includes_development_helper(self):
        for output in ['12 /Applications/MyToolBox.app/Contents/MacOS/MyToolBox',
                       '13 /tmp/build copy/MyToolBox.app/Contents/Helpers/windowManager.app/Contents/MacOS/MyToolBox']:
            with patch.object(gate, 'run', return_value=SimpleNamespace(stdout=output)):
                with self.assertRaises(RuntimeError):
                    gate.stopped()

    def test_validation_pins_new_helpers_to_installed_certificate(self):
        with tempfile.TemporaryDirectory() as tmp:
            app = Path(tmp)
            for name in ['windowManager', 'newTool']:
                folder = app / 'Contents/Helpers' / (name + '.app') / 'Contents'
                folder.mkdir(parents=True)
                (folder / 'Info.plist').write_bytes(plistlib.dumps({
                    'CFBundleIdentifier': gate.APP_ID + '.tool.' + name, 'MyToolBoxTool': name}))
            (app / 'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': gate.APP_ID}))
            req = 'identifier "local.MyToolBox" and anchor apple generic and certificate leaf = H"test"'
            with patch.object(gate, 'run') as run:
                self.assertEqual(gate.validate(app, req), {'windowManager', 'newTool'})
                commands = [c.args[0] for c in run.call_args_list]
                self.assertEqual(len(commands), 3)
                self.assertTrue(all(c[c.index('-R') + 1].startswith('=identifier ') for c in commands))
                self.assertTrue(all('certificate leaf = H"test"' in c[c.index('-R') + 1] for c in commands))
            (app / 'Contents/Helpers/newTool.app/Contents/Info.plist').write_bytes(plistlib.dumps({
                'CFBundleIdentifier': 'attacker.app', 'MyToolBoxTool': 'newTool'}))
            with patch.object(gate, 'run'), self.assertRaises(RuntimeError):
                gate.validate(app, req)

    def test_signed_code_failure_is_fatal(self):
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(gate, 'run', side_effect=subprocess.CalledProcessError(1, 'codesign')):
                with self.assertRaises(subprocess.CalledProcessError):
                    gate.validate(Path(tmp), 'pinned')

    def test_non_root_main_refuses_before_mutation(self):
        with patch('sys.argv', ['gate', 'apply']), patch.object(gate.os, 'geteuid', return_value=501):
            with self.assertRaises(RuntimeError):
                gate.main()

    def test_update_stops_before_staging_when_process_running(self):
        with patch.object(gate, 'verify_protection'), patch.object(gate, 'stopped', side_effect=RuntimeError('running')):
            with patch.object(gate.tempfile, 'mkdtemp') as stage:
                with self.assertRaises(RuntimeError):
                    gate.update({'requirement': 'pinned'}, True)
                stage.assert_not_called()


if __name__ == '__main__':
    unittest.main()
