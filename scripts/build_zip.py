#!/usr/bin/env python3
from pathlib import Path
import hashlib
import stat
import zipfile

root = Path(__file__).resolve().parents[1]
properties = dict(line.split('=', 1) for line in (root / 'module.prop').read_text().splitlines() if '=' in line)
output = root / 'dist' / f"Xiaomi17-4K120FPS-Unlocker-v{properties['version']}.zip"
output.parent.mkdir(exist_ok=True)
files = ['module.prop', 'customize.sh', 'post-fs-data.sh', 'skip_mount', 'payload/sensormodule.bin']

with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for name in files:
        info = zipfile.ZipInfo(name)
        info.create_system = 3
        info.compress_type = zipfile.ZIP_DEFLATED
        mode = 0o755 if name.endswith('.sh') else 0o644
        info.external_attr = (stat.S_IFREG | mode) << 16
        archive.writestr(info, (root / name).read_bytes())

with zipfile.ZipFile(output) as archive:
    if archive.testzip() is not None:
        raise RuntimeError('ZIP validation failed')

checksum = hashlib.sha256(output.read_bytes()).hexdigest()
output.with_suffix(output.suffix + '.sha256').write_text(f'{checksum}  {output.name}\n')
print(output)
print(checksum)
