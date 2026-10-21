#!/usr/bin/env python3
"""Deploy only while MyToolBox and every embedded helper are stopped.

Default is a read-only preflight. --apply performs the verified replacement.
Never terminates processes, changes TCC, or starts applications.
"""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from app_verify import validate_tool_apps
from tool_catalog import tool_catalog

ROOT = Path(__file__).resolve().parent.parent


def run(args):
    return subprocess.run(args, check=True, capture_output=True, text=True)


def assert_stopped(processes=None):
    # comm, not args: command-line references to a path must not count as apps.
    # Include development copies: they can also hold the same global keys.
    if processes is None:
        processes = run(['/bin/ps', '-axo', 'pid=,comm=']).stdout
    active = []
    for row in processes.splitlines():
        fields = row.strip().split(None, 1)
        if len(fields) == 2 and fields[1].endswith('.app/Contents/MacOS/MyToolBox'):
            active.append(fields[0] + ': ' + fields[1])
    if active:
        raise RuntimeError('配置を中止：本体と全独立ツールを通常終了してください。'
                           'ウィンドウマネージャーは×では常駐するため⌘Qで終了します。\n' + '\n'.join(active))


def validate(app):
    validate_tool_apps(app)
    run(['codesign', '--verify', '--deep', '--strict', str(app)])


def validate_identity(source, target):
    for relative in [Path('.')] + [Path('Contents/Helpers') / (tool + '.app') for tool in tool_catalog()]:
        old = target / relative
        result = run(['codesign', '-d', '-r-', str(old)])
        text = result.stdout + result.stderr
        requirement = next((line.split('=>', 1)[1].strip() for line in text.splitlines()
                            if line.startswith('designated =>')), None)
        if not requirement or requirement.startswith('cdhash '):
            raise RuntimeError('権限維持を保証できない旧署名です：' + str(old))
        # Evaluate the installed identity against the new code; do not merely
        # check that both builds have some certificate or the same bundle ID.
        run(['codesign', '--verify', '--strict', '-R', '=' + requirement, str(source / relative)])


def deploy(source, target, apply=False):
    source, target = source.resolve(), target.resolve()
    privileged = Path('/Library/Application Support/MyToolBoxDeployment/protected_deploy.py')
    if target == Path('/Applications/MyToolBox.app') and privileged.exists():
        raise RuntimeError('OS保護済みです。管理者認証で root 所有の専用更新処理を使ってください：'
                           'sudo /usr/bin/python3 -I "' + str(privileged) + '" '
                           + ('apply' if apply else 'check'))
    if source == target or source in target.parents or target in source.parents:
        raise RuntimeError('source and target must be separate app bundles')
    if not source.is_dir() or not target.is_dir():
        raise RuntimeError('更新元と既存の配置先.appが必要です')
    assert_stopped()
    validate(source)
    validate(target)
    validate_identity(source, target)
    if not apply:
        print('PASS: 停止・全helper・署名継続。配置する場合は --apply を指定してください。')
        return
    stage = Path(tempfile.mkdtemp(prefix='.mytoolbox-deploy-', dir=target.parent))
    candidate, backup = stage / 'new.app', stage / 'previous.app'
    exchanged = False
    try:
        run(['/usr/bin/ditto', str(source), str(candidate)])
        validate(candidate)
        validate_identity(candidate, target)
        assert_stopped()  # Copying/signature checks can take time.
        target.rename(backup)
        try:
            candidate.rename(target)
        except OSError:
            backup.rename(target)
            raise
        exchanged = True
        try:
            validate(target)
        except Exception:
            # Never remove a bundle used by a process that raced the update.
            assert_stopped()
            target.rename(candidate)
            backup.rename(target)
            exchanged = False
            raise
        assert_stopped()
        shutil.rmtree(stage)
        # The verified build is disposable only after successful replacement.
        if source == ROOT / 'build/Build/Products/Release/MyToolBox.app':
            shutil.rmtree(source)
        print('PASS: 配置・署名確認完了。旧版を整理しました。本体を通常起動してください。')
    except Exception:
        print(f'配置失敗。復旧用ファイルを保持：{stage} (replacement={exchanged})', file=sys.stderr)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=ROOT / 'build/Build/Products/Release/MyToolBox.app')
    parser.add_argument('--target', type=Path, default=Path('/Applications/MyToolBox.app'))
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    try:
        deploy(args.source, args.target, args.apply)
        return 0
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f'ERROR: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
