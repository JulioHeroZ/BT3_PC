"""Audit PE imports without requiring external Python packages."""
import ast
import json
import struct
import sys
from pathlib import Path

stage = Path(sys.argv[1]).resolve()
gate = Path(sys.argv[2]) / 'tools/release-windows/check_windows_deps.py'
tree = ast.parse(gate.read_text(encoding='utf-8'))
system = next(ast.literal_eval(node.value) for node in tree.body
              if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'OS_COMPONENTS' for t in node.targets))
system.add('mscoree.dll')  # .NET Framework is a documented installer prerequisite.

def imports(path):
    data = path.read_bytes()
    pe = struct.unpack_from('<I', data, 60)[0]
    assert data[pe:pe+4] == b'PE\0\0'
    count = struct.unpack_from('<H', data, pe+6)[0]
    opt_size = struct.unpack_from('<H', data, pe+20)[0]
    opt = pe+24
    directories = opt + (112 if struct.unpack_from('<H', data, opt)[0] == 0x20b else 96)
    sections = []
    for n in range(count):
        offset = opt + opt_size + n*40
        size, rva, raw_size, raw = struct.unpack_from('<IIII', data, offset+8)
        sections.append((rva, max(size, raw_size), raw))
    def physical(rva):
        for start, size, raw in sections:
            if start <= rva < start+size:
                return raw+rva-start
        raise ValueError('Unmapped RVA')
    def name(rva):
        pos = physical(rva)
        return data[pos:data.index(b'\0', pos)].decode('ascii').lower()
    names = set()
    for index, stride, name_offset in [(1, 20, 12), (13, 32, 4)]:
        rva, size = struct.unpack_from('<II', data, directories+index*8)
        if not rva: continue
        pos = physical(rva)
        while any(data[pos:pos+stride]):
            names.add(name(struct.unpack_from('<I', data, pos+name_offset)[0]))
            pos += stride
    return names

files = {p.name.lower(): p for p in stage.iterdir() if p.suffix.lower() in ('.exe', '.dll')}
missing = {}
for filename, path in files.items():
    unresolved = imports(path) - files.keys() - system
    unresolved = {dll for dll in unresolved if not dll.startswith(('api-ms-', 'ext-ms-'))}
    if unresolved: missing[filename] = sorted(unresolved)
result = {'binaries_checked': len(files), 'missing_imports': missing}
(stage / 'verificacao-dependencias.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result, indent=2))
assert not missing, 'Missing dependencies'
