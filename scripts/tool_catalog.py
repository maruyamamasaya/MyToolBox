"""Read the native catalog for packaging; fail closed if its declaration changes."""
from pathlib import Path
import re
ROOT = Path(__file__).resolve().parent.parent

def tool_catalog(root=ROOT):
    source = (root / 'Sources/MyToolBox/App/ToolCatalog.swift').read_text()
    declaration = source.split('enum ToolID: String, CaseIterable, Identifiable {', 1)[1].split('var id:', 1)[0]
    identifiers = []
    for line in declaration.strip().splitlines():
        if not line.strip().startswith('case '):
            raise ValueError('unsupported ToolID declaration')
        identifiers.extend(part.strip() for part in line.strip()[5:].split(','))
    title_source = source.split('var title: String {', 1)[1].split('var subtitle:', 1)[0]
    titles = dict(re.findall(r'case \.(\w+): return "([^"\n]+)"', title_source))
    if not identifiers or len(set(identifiers)) != len(identifiers) or set(identifiers) != set(titles):
        raise ValueError('ToolID identifiers and titles must match exactly')
    return {identifier: titles[identifier] for identifier in identifiers}

HOLIDAY_TOOLS = {'personalCalendar', 'businessDays'}
