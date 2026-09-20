"""Reject direct equality comparisons involving runtime SceneGraph nodes."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = [*sorted((ROOT / "source").glob("*.brs")), *sorted((ROOT / "components").glob("*.brs"))]

# SceneGraph IDs are cached as m.<id> in component scripts, including MainScene's
# compact `for each id ... m[id] = findNode(id)` initialization.
node_names = set()
for xml in (ROOT / "components").glob("*.xml"):
    node_names.update(f"m.{value}" for value in re.findall(r'\bid="([A-Za-z_][A-Za-z0-9_]*)"', xml.read_text()))

sources = {path: path.read_text() for path in RUNTIME}
assignment = re.compile(r"(?m)^\s*([A-Za-z_][A-Za-z0-9_.]*)\s*=\s*(.+)$")
node_factory = re.compile(r'CreateObject\(\s*"roSGNode"|\.(?:findNode|getRoSGNode|getChild|createChild)\s*\(', re.I)

# Local variable names belong to a BrightScript function, not every component.
# Otherwise a node named `title` in one renderer marks string titles everywhere.
comparison = re.compile(r"(?<![<>=])\b([A-Za-z_][A-Za-z0-9_.]*)\s*(=|<>)\s*([A-Za-z_][A-Za-z0-9_.]*)\b(?!\s*=)", re.I)
violations = []
for path, text in sources.items():
    members = set(node_names)
    for match in assignment.finditer(text):
        target, value = match.groups()
        if target.lower().startswith("m.") and node_factory.search(value):
            members.add(target)
    blocks = re.split(r"(?mi)(?=^(?:sub|function)\s)", text)
    line_offset = 0
    for block in blocks:
        scoped_nodes = set(members)
        changed = True
        while changed:
            changed = False
            for match in assignment.finditer(block):
                target, value = match.groups()
                simple = re.fullmatch(r"([A-Za-z_][A-Za-z0-9_.]*)", value.strip())
                is_node = bool(node_factory.search(value)) or bool(simple and simple.group(1) in scoped_nodes)
                if is_node and target not in scoped_nodes:
                    scoped_nodes.add(target)
                    changed = True
        for number, line in enumerate(block.splitlines(), line_offset + 1):
            stripped = line.strip()
            lowered = stripped.lower()
            condition = ""
            if lowered.startswith("if ") or lowered.startswith("else if "):
                condition = re.split(r"\bthen\b", stripped, maxsplit=1, flags=re.I)[0]
            elif lowered.startswith("while ") or lowered.startswith("return "):
                condition = stripped
            for left, operator, right in comparison.findall(condition):
                if left.lower() == "invalid" or right.lower() == "invalid":
                    continue
                if left in scoped_nodes or right in scoped_nodes:
                    violations.append(f"{path.relative_to(ROOT)}:{number}: {left} {operator} {right}")
        line_offset += len(block.splitlines())

assert not violations, "SceneGraph node identity must use isSameNode():\n" + "\n".join(violations)
main = sources[ROOT / "components/PlaybackScene.brs"]
assert "node.isSameNode(m.video)" in main
print("ROKU_SGNODE_IDENTITY_CONTRACT_OK")
