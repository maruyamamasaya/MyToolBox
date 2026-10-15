#!/usr/bin/env python3
"""Compile theme renderers/probe; optional screenshots never change user preferences."""
import argparse
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--render', action='store_true')
    parser.add_argument('--probe', action='store_true')
    args = parser.parse_args()
    sources = sorted(str(p.relative_to(ROOT)) for p in (ROOT / 'Sources').rglob('*.swift')
                     if 'Probe' not in p.parts and p.name != 'MyToolBoxApp.swift')
    environment = dict(os.environ, CLANG_MODULE_CACHE_PATH=str(ROOT / '.build/clang-cache'))
    binaries = [('RenderLocalTools', 'render-local-tools'), ('RenderDashboard', 'render-dashboard'), ('ThemeSwitchProbe', 'theme-switch-probe')]
    (ROOT / 'build').mkdir(exist_ok=True)
    for source, binary in binaries:
        subprocess.run(['xcrun', 'swiftc', '-module-cache-path', '.build/clang-cache', '-parse-as-library', '-whole-module-optimization', *sources, f'tools/{source}.swift', '-o', f'build/{binary}'], cwd=ROOT, env=environment, check=True)
        print(f'Compiled {source}', flush=True)
    if args.probe:
        subprocess.run(['build/theme-switch-probe'], cwd=ROOT, check=True)
    if args.render:
        for theme in ['blue-cosmos', 'living-aurora', 'windows-98']:
            for binary in ['render-local-tools', 'render-dashboard']:
                subprocess.run([f'build/{binary}', theme], cwd=ROOT, check=True)

if __name__ == '__main__':
    main()
