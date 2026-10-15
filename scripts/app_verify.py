#!/usr/bin/env python3
"""Native app validation; local SDK only, no third-party dependencies."""
from pathlib import Path
import os
import subprocess
import sys
ROOT = Path(__file__).resolve().parent.parent

def run(args, log, env):
    with log.open('w') as out:
        result = subprocess.run(args, cwd=ROOT, env=env, stdout=out, stderr=subprocess.STDOUT)
    if result.returncode:
        print(log.read_text()[-12000:], file=sys.stderr)
        raise RuntimeError(f'failed: {args}; log: {log}')
    print(f'PASS: {args[0]} {args[1]} ({log.relative_to(ROOT)})', flush=True)

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
        run(['codesign', '--verify', '--strict', str(app)], logs / 'codesign.log', env)
        print(f'PASS: native .app generated: {app}')
    return 0

if __name__ == '__main__':
    try: sys.exit(verify('--fast' in sys.argv))
    except (RuntimeError, OSError) as error:
        print(f'ERROR: {error}', file=sys.stderr); sys.exit(1)
