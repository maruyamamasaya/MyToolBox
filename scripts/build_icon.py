#!/usr/bin/env python3
"""Package the saved original artwork with native macOS tools; no network access."""
from pathlib import Path
import subprocess
ROOT = Path(__file__).resolve().parent.parent
source = ROOT / 'Resources/AppIcon/source.png'
iconset = ROOT / 'build/MyToolBox.iconset'
iconset.mkdir(parents=True, exist_ok=True)
for points in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        pixels = str(points * scale)
        suffix = '@2x' if scale == 2 else ''
        target = iconset / f'icon_{points}x{points}{suffix}.png'
        subprocess.run(['sips', '-z', pixels, pixels, str(source), '--out', str(target)], check=True, stdout=subprocess.DEVNULL)
subprocess.run(['iconutil', '-c', 'icns', str(iconset), '-o', str(ROOT / 'Resources/MyToolBox.icns')], check=True)
print('Generated Resources/MyToolBox.icns (16–1024px)')
