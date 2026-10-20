#!/usr/bin/env python3
"""Native app validation; local SDK only, no third-party dependencies."""
from pathlib import Path
import os
import plistlib
import re
import subprocess
import sys
from tool_catalog import tool_catalog, HOLIDAY_TOOLS
ROOT = Path(__file__).resolve().parent.parent

def run(args, log, env):
    with log.open('w') as out:
        result = subprocess.run(args, cwd=ROOT, env=env, stdout=out, stderr=subprocess.STDOUT)
    if result.returncode:
        print(log.read_text()[-12000:], file=sys.stderr)
        raise RuntimeError(f'failed: {args}; log: {log}')
    print(f'PASS: {args[0]} {args[1]} ({log.relative_to(ROOT)})', flush=True)

def validate_signing_transition(installed_requirement, built_requirement):
    is_ad_hoc = lambda value: re.search(r'\bdesignated\s*=>\s*cdhash\b', value) is not None
    if not is_ad_hoc(installed_requirement) and is_ad_hoc(built_requirement):
        raise RuntimeError('installed app uses a certificate; restore .local-signing.xcconfig before updating (ad hoc fallback refused)')

def validate_tool_apps(app):
    for tool in tool_catalog():
        contents = app / 'Contents/Helpers' / (tool + '.app') / 'Contents'
        if not (contents / 'MacOS/MyToolBox').is_file():
            raise RuntimeError(f'helper executable missing: {tool}')
        with (contents / 'Info.plist').open('rb') as file:
            info = plistlib.load(file)
        if info.get('MyToolBoxTool') != tool or info.get('CFBundleIdentifier') != 'local.MyToolBox.tool.' + tool:
            raise RuntimeError(f'helper identity mismatch: {tool}')
        icon = contents / 'Resources/ToolIcon.icns'
        expected_icon = ROOT / 'Resources/ToolIcons' / (tool + '.icns')
        if info.get('CFBundleIconFile') != 'ToolIcon.icns' or not icon.is_file() or icon.read_bytes() != expected_icon.read_bytes():
            raise RuntimeError(f'helper icon missing or mismatched: {tool}')
        if tool == 'microphoneCheck' and not info.get('NSMicrophoneUsageDescription'):
            raise RuntimeError('microphone helper usage description missing')
        if tool in HOLIDAY_TOOLS:
            holiday = contents / 'Resources/JapaneseHolidays.json'
            if not holiday.is_file() or holiday.read_bytes() != (app / 'Contents/Resources/JapaneseHolidays.json').read_bytes():
                raise RuntimeError(f'{tool} helper holiday data missing or mismatched')


def verify(fast=False):
    logs = ROOT / 'build/validation'; logs.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env['CLANG_MODULE_CACHE_PATH'] = str(ROOT / '.build/clang-cache')
    env['SWIFTPM_MODULECACHE_OVERRIDE'] = str(ROOT / '.build/module-cache')
    run(['swift', 'test', '--disable-sandbox', '--scratch-path', '.build'], logs / 'tests.log', env)
    if not fast:
        run(['xcodebuild', '-project', 'MyToolBox.xcodeproj', '-scheme', 'MyToolBox', '-configuration', 'Release', '-derivedDataPath', 'build', 'build'], logs / 'xcodebuild.log', env)
        app = ROOT / 'build/Build/Products/Release/MyToolBox.app'
        if not (app / 'Contents/MacOS/MyToolBox').is_file(): raise RuntimeError('app executable missing')
        validate_tool_apps(app)
        run(['codesign', '--verify', '--deep', '--strict', str(app)], logs / 'codesign.log', env)
        microphone = app / 'Contents/Helpers/microphoneCheck.app'
        signed = subprocess.run(['codesign', '-d', '--entitlements', ':-', str(microphone)], capture_output=True)
        if signed.returncode or not plistlib.loads(signed.stdout).get('com.apple.security.device.audio-input'):
            raise RuntimeError('microphone helper audio-input entitlement missing')
        print(f'PASS: {len(tool_catalog())} helper identities/resources, deep signatures and microphone entitlement')
        # Never silently fall back to ad hoc signing after installing a certificate-signed app.
        installed = Path('/Applications/MyToolBox.app')
        if installed.exists():
            def requirement(path):
                result = subprocess.run(['codesign', '-d', '-r-', str(path)], capture_output=True, text=True)
                if result.returncode: raise RuntimeError(f'cannot read signing requirement: {path}')
                return result.stdout + result.stderr
            validate_signing_transition(requirement(installed), requirement(app))
        print(f'PASS: native .app generated: {app}')
    return 0

if __name__ == '__main__':
    try: sys.exit(verify('--fast' in sys.argv))
    except (RuntimeError, OSError) as error:
        print(f'ERROR: {error}', file=sys.stderr); sys.exit(1)
