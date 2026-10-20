#!/usr/bin/env python3
"""Package generated tool artwork as native multi-resolution macOS icons."""
from pathlib import Path
import subprocess
import tempfile
from tool_catalog import ROOT, tool_catalog


def main():
    icons = ROOT / 'Resources/ToolIcons'
    catalog = tool_catalog()
    missing = [tool for tool in catalog if not (icons / 'sources' / (tool + '.png')).is_file()]
    if missing:
        raise RuntimeError('missing tool artwork: ' + ', '.join(missing))
    for tool in catalog:
        source = icons / 'sources' / (tool + '.png')
        with tempfile.TemporaryDirectory() as temporary:
            iconset = Path(temporary) / (tool + '.iconset')
            iconset.mkdir()
            for points in (16, 32, 128, 256, 512):
                for scale in (1, 2):
                    pixels = str(points * scale)
                    suffix = '@2x' if scale == 2 else ''
                    target = iconset / f'icon_{points}x{points}{suffix}.png'
                    subprocess.run(['sips', '-z', pixels, pixels, str(source), '--out', str(target)],
                                   check=True, stdout=subprocess.DEVNULL)
            subprocess.run(['iconutil', '-c', 'icns', str(iconset), '-o', str(icons / (tool + '.icns'))], check=True)
        print('Generated ' + tool + '.icns', flush=True)


if __name__ == '__main__':
    main()
