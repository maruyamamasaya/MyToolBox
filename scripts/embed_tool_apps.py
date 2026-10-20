#!/usr/bin/env python3
"""Package separate tool identities using the shared executable, before outer signing."""
import os
from pathlib import Path
import plistlib
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent

from tool_catalog import tool_catalog, HOLIDAY_TOOLS

TOOLS = tool_catalog()

def main():
    app = Path(os.environ['TARGET_BUILD_DIR']) / os.environ['WRAPPER_NAME']
    executable = app / 'Contents/MacOS/MyToolBox'
    for tool, title in TOOLS.items():
        contents = app / 'Contents/Helpers' / (tool + '.app') / 'Contents'
        (contents / 'MacOS').mkdir(parents=True, exist_ok=True)
        shutil.copy2(executable, contents / 'MacOS/MyToolBox')
        resources = contents / 'Resources'
        resources.mkdir(exist_ok=True)
        shutil.copy2(ROOT / 'Resources/ToolIcons' / (tool + '.icns'), resources / 'ToolIcon.icns')
        # Remove the shared icon left by earlier builds in the reused bundle.
        (resources / 'MyToolBox.icns').unlink(missing_ok=True)
        shutil.copy2(app / 'Contents/Resources/PrivacyInfo.xcprivacy', resources / 'PrivacyInfo.xcprivacy')
        shutil.copy2(app / 'Contents/Resources/Stats-LICENSE.txt', resources / 'Stats-LICENSE.txt')
        if tool in HOLIDAY_TOOLS:
            shutil.copy2(app / 'Contents/Resources/JapaneseHolidays.json', resources / 'JapaneseHolidays.json')
        privacy = {}
        if tool == 'microphoneCheck':
            with (ROOT / 'Resources/Info.plist').open('rb') as source:
                privacy['NSMicrophoneUsageDescription'] = plistlib.load(source)['NSMicrophoneUsageDescription']
        with (contents / 'Info.plist').open('wb') as file:
            plistlib.dump({
                'CFBundleIdentifier': 'local.MyToolBox.tool.' + tool,
                'CFBundleExecutable': 'MyToolBox', 'CFBundleName': title,
                'CFBundleDisplayName': title, 'CFBundlePackageType': 'APPL',
                'CFBundleShortVersionString': '0.1.0', 'CFBundleVersion': '1',
                'CFBundleIconFile': 'ToolIcon.icns', 'LSMinimumSystemVersion': '14.0',
                'NSHighResolutionCapable': True, 'MyToolBoxTool': tool, **privacy,
            }, file)
        identity = os.environ.get('EXPANDED_CODE_SIGN_IDENTITY') or '-'
        signing = ['codesign', '--force', '--sign', identity, '--options', 'runtime', '--timestamp=none']
        if tool == 'microphoneCheck':
            signing += ['--entitlements', str(ROOT / 'Resources/MyToolBox.entitlements')]
        subprocess.run(signing + [str(contents.parent)], check=True)

if __name__ == '__main__':
    main()
