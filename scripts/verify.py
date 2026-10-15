#!/usr/bin/env python3
"""Documentation, Swift tests and native Xcode build validation."""
import argparse
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
REQUIRED = {
    'AGENTS.md': ['開始と探索', '変更と安全', '検証・終了'],
    'CURRENT.md': ['Project', '現在のフェーズ', '実装済み', '進行中', '未実装', '既知の問題', '技術的負債', '次に行うこと'],
    'ARCHITECTURE.md': ['System Overview', 'Technology Stack', 'Directory Structure', 'Data Flow', 'API Structure', 'Deployment'],
    'CODEMAP.md': ['Primary paths', 'Search keywords', 'Key entry points', 'Related tests'],
    'TESTING.md': ['Test Strategy', 'Fast Validation', 'Full Validation', 'Change Type'],
    'OPERATIONS.md': ['Local Development', 'Environment Variables', 'Build', 'Troubleshooting'],
    'README.md': [],
    'decisions/README.md': ['Context', 'Decision', 'Reason', 'Alternatives', 'Consequences'],
    'sessions/README.md': ['Request', 'Investigation', 'Changes', 'Files Changed', 'Validation', 'Result', 'Remaining Issues'],
}
LIMITS = {'AGENTS.md': 120, 'CURRENT.md': 80, 'CODEMAP.md': 160}


def check(root, fast=False):
    errors = []
    for name, sections in REQUIRED.items():
        path = root / name
        if not path.is_file():
            errors.append(f'{name}: required file missing')
            continue
        body = path.read_text(encoding='utf-8')
        for section in sections:
            if section not in body:
                errors.append(f'{name}: required topic missing: {section}')
    for path in sorted(root.rglob('*.md')):
        relative = path.relative_to(root)
        if any(part.startswith('.') for part in relative.parts):
            continue
        body = path.read_text(encoding='utf-8')
        # The repository uses inline Markdown links. Anchors and remote URLs are not checked.
        for target in re.findall(r'!?\[[^\]\n]*\]\(([^)\n]+)\)', body):
            target = target.strip().strip('<>')
            parsed = urlsplit(target)
            if parsed.scheme or parsed.netloc or not parsed.path:
                continue
            destination = (path.parent / unquote(parsed.path)).resolve()
            if not destination.is_relative_to(root.resolve()):
                errors.append(f'{relative}: link escapes repository: {target}')
            elif not destination.exists():
                errors.append(f'{relative}: broken link: {target}')
        if not fast:
            limit = LIMITS.get(str(relative))
            if relative.parts[0] == 'sessions' and path.name != 'README.md':
                limit = 100
            if limit and len(body.splitlines()) > limit:
                errors.append(f'{relative}: exceeds {limit} lines')
    readme = root / 'README.md'
    if readme.is_file():
        body = readme.read_text(encoding='utf-8')
        for name in REQUIRED:
            if name != 'README.md' and f']({name})' not in body:
                errors.append(f'README.md: navigation link missing: {name}')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fast', action='store_true', help='skip document size limits')
    args = parser.parse_args()
    errors = check(ROOT, fast=args.fast)
    for error in errors:
        print(f'ERROR: {error}', file=sys.stderr)
    if errors:
        return 1
    print(f'PASS: documentation {"fast" if args.fast else "full"} validation', flush=True)
    from app_verify import verify
    try:
        return verify(fast=args.fast)
    except (RuntimeError, OSError) as error:
        print(f'ERROR: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
