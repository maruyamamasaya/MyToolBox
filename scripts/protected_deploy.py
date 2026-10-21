#!/usr/bin/python3
"""Root-owned deployment gate. Run with /usr/bin/python3 -I; no repo imports.

Install requires interactive administrator authentication. No daemon, sudoers
entry, TCC change, or application launch/termination is performed.
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import plistlib
import pwd
import re
import shutil
import stat
import subprocess
import sys
import tempfile

STATE = Path('/Library/Application Support/MyToolBoxDeployment')
TARGET = Path('/Applications/MyToolBox.app')
PROGRAM = STATE / 'protected_deploy.py'
POLICY = STATE / 'policy.json'
ENV = {'PATH': '/usr/bin:/bin:/usr/sbin:/sbin', 'LANG': 'en_US.UTF-8'}
APP_ID = 'local.MyToolBox'


def run(args):
    return subprocess.run([str(a) for a in args], check=True, capture_output=True, text=True, env=ENV)


def tree(path):
    """Never chown/chmod/follow links or special files supplied by a build."""
    paths = [path] + list(path.rglob('*'))
    for item in paths:
        mode = item.lstat().st_mode
        if not (stat.S_ISDIR(mode) or stat.S_ISREG(mode)):
            raise RuntimeError('Links/special files refused: ' + str(item))
    return paths


def stopped():
    active = [line for line in run(['/bin/ps', '-axo', 'pid=,comm=']).stdout.splitlines()
              if line.strip().endswith('.app/Contents/MacOS/MyToolBox')]
    if active:
        raise RuntimeError('本体・全helperを通常終了してください。\n' + '\n'.join(active))


def requirement(app):
    result = run(['/usr/bin/codesign', '-d', '-r-', app])
    lines = (result.stdout + result.stderr).splitlines()
    value = next((s.split('=>', 1)[1].strip() for s in lines if s.startswith('designated =>')), '')
    if not value.startswith('identifier "local.MyToolBox" and anchor apple generic and certificate '):
        raise RuntimeError('固定した証明書署名が必要です')
    return value


def validate(app, req):
    tree(app)
    run(['/usr/bin/codesign', '--verify', '--deep', '--strict', '-R', '=' + req, app])
    with (app / 'Contents/Info.plist').open('rb') as f:
        if plistlib.load(f).get('CFBundleIdentifier') != APP_ID:
            raise RuntimeError('Wrong parent identity')
    helpers = app / 'Contents/Helpers'
    names = set()
    for helper in helpers.iterdir():
        name = helper.stem
        if not helper.is_dir() or helper.suffix != '.app' or not re.fullmatch('[A-Za-z][A-Za-z0-9]*', name):
            raise RuntimeError('Unexpected helper: ' + str(helper))
        with (helper / 'Contents/Info.plist').open('rb') as f:
            info = plistlib.load(f)
        identity = APP_ID + '.tool.' + name
        if info.get('CFBundleIdentifier') != identity or info.get('MyToolBoxTool') != name:
            raise RuntimeError('Wrong helper identity: ' + name)
        helper_req = req.replace('identifier "' + APP_ID + '"', 'identifier "' + identity + '"', 1)
        run(['/usr/bin/codesign', '--verify', '--strict', '-R', '=' + helper_req, helper])
        names.add(name)
    if 'windowManager' not in names:
        raise RuntimeError('Window manager missing')
    return names


def owned_directory(path):
    s = path.lstat()
    if not stat.S_ISDIR(s.st_mode) or s.st_uid != 0 or s.st_mode & 0o022:
        raise RuntimeError('Unsafe privileged directory: ' + str(path))


def secure_state():
    for path in [Path('/Library'), Path('/Library/Application Support'), STATE]:
        owned_directory(path)
    for path in [POLICY, PROGRAM]:
        s = path.lstat()
        if not stat.S_ISREG(s.st_mode) or s.st_uid != 0 or s.st_mode & 0o022:
            raise RuntimeError('Unsafe privileged file: ' + str(path))


def protect(app):
    paths = tree(app)
    run(['/bin/chmod', '-RN', app])
    for path in paths:
        os.chown(path, 0, 0)
        os.chmod(path, stat.S_IMODE(path.stat().st_mode) & ~0o022)
    os.chflags(app, app.stat().st_flags | stat.UF_IMMUTABLE)


def unlock(app):
    os.chflags(app, app.stat().st_flags & ~stat.UF_IMMUTABLE)


def verify_protection(app):
    for path in tree(app):
        s = path.stat()
        if s.st_uid != 0 or s.st_mode & 0o022:
            raise RuntimeError('Writable/incorrect owner: ' + str(path))
    if not app.stat().st_flags & stat.UF_IMMUTABLE:
        raise RuntimeError('移動・削除禁止フラグがありません')


def os_probe(uid, gid):
    """Test the real OS boundary as the original user in a writable parent."""
    folder = Path(tempfile.mkdtemp(prefix='mytoolbox-protection-test-', dir='/private/tmp'))
    app = folder / 'fixture.app'
    app.mkdir(); (app / 'file').write_text('unchanged')
    os.chmod(folder, 0o777)
    protect(app)
    code = '''import os,sys,stat
from pathlib import Path
p=Path(sys.argv[1]); failed=[]
checks=[('write',lambda:os.close(os.open(p/'file',os.O_WRONLY))),
('create',lambda:os.mkdir(p/'new')),
('rename',lambda:os.rename(p,p.with_name('moved.app'))),
('unlock',lambda:os.chflags(p,0)),
('chmod',lambda:os.chmod(p/'file',0o777))]
for name,op in checks:
 try: op();failed.append(name)
 except PermissionError: print('PASS: OS denied '+name)
if failed: raise SystemExit('Protection bypass: '+','.join(failed))
'''
    def demote():
        os.setgroups([]); os.setgid(gid); os.setuid(uid)
    try:
        result = subprocess.run(['/usr/bin/python3', '-I', '-c', code, str(app)],
                                preexec_fn=demote, env=ENV, capture_output=True, text=True)
        print(result.stdout, end='')
        if result.returncode:
            raise RuntimeError(result.stderr)
    finally:
        for name in ['fixture.app', 'moved.app']:
            path = folder / name
            if path.exists():
                unlock(path)
        shutil.rmtree(folder)


def install():
    if STATE.exists():
        raise RuntimeError('Already installed; privileged gate replacement requires explicit administrator maintenance')
    uid = int(os.environ.get('SUDO_UID', '-1'))
    if uid <= 0:
        raise RuntimeError('Run install using sudo from the intended account')
    user = pwd.getpwuid(uid)
    req = requirement(TARGET)
    validate(TARGET, req)
    # Prove the protection works before touching the production bundle.
    os_probe(uid, user.pw_gid)
    source = Path(__file__).resolve().parent.parent / 'build/Build/Products/Release/MyToolBox.app'
    policy = {'uid': uid, 'gid': user.pw_gid, 'source': str(source), 'requirement': req}
    STATE.mkdir(mode=0o755)
    try:
        shutil.copyfile(Path(__file__).resolve(), PROGRAM)
        os.chmod(PROGRAM, 0o555)
        POLICY.write_text(json.dumps(policy, indent=2) + '\n')
        os.chmod(POLICY, 0o644)
        secure_state()
        protect(TARGET)
        verify_protection(TARGET)
    except Exception:
        if TARGET.exists():
            unlock(TARGET)
            for path in tree(TARGET):
                os.chown(path, uid, user.pw_gid)
        shutil.rmtree(STATE)
        raise
    print('PASS: OS protection installed. No app restarted or TCC changed.')


def update(policy, apply):
    verify_protection(TARGET)
    stopped()
    old_names = validate(TARGET, policy['requirement'])
    source = Path(policy['source'])
    if not source.is_dir():
        raise RuntimeError('Build output missing: ' + str(source))
    # Root-private staging prevents mutation by the build owner after validation.
    stage = Path(tempfile.mkdtemp(prefix='transaction-', dir=STATE))
    candidate, backup = stage / 'new.app', stage / 'previous.app'
    try:
        run(['/usr/bin/ditto', '--noacl', source, candidate])
        tree(candidate)
        protect(candidate)
        unlock(candidate)  # Only the installed top-level bundle needs this flag.
        names = validate(candidate, policy['requirement'])
        if not old_names.issubset(names):
            raise RuntimeError('既存helperの削除を伴う更新は管理者による別途確認が必要です')
        stopped()
        if not apply:
            shutil.rmtree(stage)
            print('PASS: 停止・署名継続・全helper・OS保護。配置には apply を指定。')
            return
        unlock(TARGET)
        try:
            TARGET.rename(backup)
        except Exception:
            protect(TARGET)
            raise
        try:
            candidate.rename(TARGET)
            protect(TARGET)
            validate(TARGET, policy['requirement'])
            verify_protection(TARGET)
        except Exception:
            stopped()  # Preserve both copies if an app raced the transaction.
            if TARGET.exists():
                unlock(TARGET); TARGET.rename(candidate)
            backup.rename(TARGET); protect(TARGET)
            raise
        stopped()
        shutil.rmtree(stage)
        print('PASS: 更新・署名・OS保護を確認。旧版整理済み。本体を通常起動し実キー確認を行ってください。')
    except Exception:
        print('停止。復旧資料を保持：' + str(stage), file=sys.stderr)
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['install', 'status', 'check', 'apply', 'remove-protection'])
    args = parser.parse_args()
    if os.geteuid() != 0:
        raise RuntimeError('Administrator authentication required; use sudo /usr/bin/python3 -I')
    if args.action == 'install':
        install(); return
    if Path(__file__).resolve() != PROGRAM:
        raise RuntimeError('Use the installed root-owned gate: ' + str(PROGRAM))
    secure_state()
    # No user-controlled imports, path parameters, shell commands or hooks.
    with (STATE / 'operation.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        policy = json.loads(POLICY.read_text())
        if args.action == 'status':
            verify_protection(TARGET)
            print('PASS: root-owned, non-writable, immutable production app')
        elif args.action == 'remove-protection':
            stopped()
            unlock(TARGET)
            for path in tree(TARGET):
                os.chown(path, policy['uid'], policy['gid'])
            print('OS protection removed by administrator. Gate files retained for audit.')
        else:
            update(policy, args.action == 'apply')


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print('ERROR: ' + str(error), file=sys.stderr)
        if isinstance(error, subprocess.CalledProcessError):
            print(error.stderr or '', file=sys.stderr)
        sys.exit(1)
