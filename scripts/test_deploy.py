#!/usr/bin/env python3
"""Deployment regressions, using disposable bundles and injected OS boundaries."""
from pathlib import Path
import shutil
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

import deploy


class DeploymentTests(unittest.TestCase):
    def test_certificate_identity_checked_for_parent_and_every_helper(self):
        requirement = 'identifier "example" and anchor apple generic'
        with patch.object(deploy, 'run', return_value=SimpleNamespace(stdout='', stderr='designated => ' + requirement)) as run:
            deploy.validate_identity(Path('/new.app'), Path('/old.app'))
            checks = [call.args[0] for call in run.call_args_list if '-R' in call.args[0]]
            self.assertEqual(len(checks), 1 + len(deploy.tool_catalog()))
            self.assertTrue(all(command[command.index('-R') + 1] == '=' + requirement for command in checks))

    def test_ad_hoc_identity_refused(self):
        with patch.object(deploy, 'run', return_value=SimpleNamespace(stdout='', stderr='designated => cdhash H"1234"')):
            with self.assertRaises(RuntimeError):
                deploy.validate_identity(Path('/new.app'), Path('/old.app'))

    def test_live_helper_blocks_even_without_parent(self):
        for path in ['/Applications/MyToolBox.app', '/tmp/development copy/MyToolBox.app']:
            with self.assertRaises(RuntimeError):
                deploy.assert_stopped(f'42 {path}/Contents/Helpers/windowManager.app/Contents/MacOS/MyToolBox\n')
        deploy.assert_stopped('12 /usr/bin/python3\n13 /bin/zsh\n')

    def exercise(self, *, stop_failure=None, validation_failure=None, apply=True):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        source, target = root / 'built.app', root / 'installed.app'
        source.mkdir(); target.mkdir()
        (source / 'version').write_text('new')
        (target / 'version').write_text('old')
        stops = 0
        validations = 0

        def stopped():
            nonlocal stops
            stops += 1
            if stops == stop_failure:
                raise RuntimeError('app started during deployment')

        def validate(app):
            nonlocal validations
            validations += 1
            if validations == validation_failure:
                raise RuntimeError('signature rejected')

        def copy(args):
            shutil.copytree(args[-2], args[-1])

        with patch.object(deploy, 'assert_stopped', stopped), patch.object(deploy, 'validate', validate), \
                patch.object(deploy, 'validate_identity'), patch.object(deploy, 'run', copy):
            try:
                deploy.deploy(source, target, apply)
                error = None
            except RuntimeError as caught:
                error = caught
        return root, source, target, error

    def test_preflight_never_replaces(self):
        root, source, target, error = self.exercise(apply=False)
        self.assertIsNone(error)
        self.assertEqual((target / 'version').read_text(), 'old')
        self.assertEqual(len(list(root.iterdir())), 2)

    def test_app_start_during_copy_prevents_replacement(self):
        root, source, target, error = self.exercise(stop_failure=2)
        self.assertIsNotNone(error)
        self.assertEqual((target / 'version').read_text(), 'old')

    def test_failed_post_validation_rolls_back(self):
        root, source, target, error = self.exercise(validation_failure=4)
        self.assertIsNotNone(error)
        self.assertEqual((target / 'version').read_text(), 'old')
        self.assertTrue(source.exists())

    def test_started_app_prevents_backup_deletion(self):
        root, source, target, error = self.exercise(stop_failure=3)
        self.assertIsNotNone(error)
        self.assertEqual((target / 'version').read_text(), 'new')
        self.assertEqual(next(root.glob('.mytoolbox-deploy-*/previous.app/version')).read_text(), 'old')

    def test_success_removes_backup_only(self):
        root, source, target, error = self.exercise()
        self.assertIsNone(error)
        self.assertEqual((target / 'version').read_text(), 'new')
        self.assertTrue(source.exists())
        self.assertEqual(len(list(root.iterdir())), 2)


if __name__ == '__main__':
    unittest.main()
