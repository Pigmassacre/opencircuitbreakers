#!/usr/bin/env python3
import hashlib
import os
import re
import shutil
import struct
import subprocess
import sys

# Release export for one platform. The Godot project must not contain any
# extracted Circuit Breakers files; this script reads the pack and refuses to
# finish if any of them were included. Every packed file has to trace
# back to a git-tracked file under Project/, and when the extracted data folder
# is present no packed file may have the same bytes as anything in it.
#
# Usage: python3 Tools/package.py linux
#        python3 Tools/package.py windows

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..'))
PROJECT = os.path.join(ROOT, 'Project')
BUILDS = os.path.join(ROOT, 'Builds')
DATA = os.path.join(ROOT, 'data')
TEMPLATES = os.path.expanduser('~/.local/share/godot/export_templates/4.7.2.stable')

PLATFORMS = {
    'linux': ('Linux', 'OpenCircuitBreakers', 'linux_release.x86_64'),
    'windows': ('Windows', 'OpenCircuitBreakers.exe', 'windows_release_x86_64.exe'),
}

FORBIDDEN = (
    'res://tracks/',
    'res://cars/',
    'res://vehicles/',
    'res://audio/',
    'res://textures/',
    'res://data/',
    'res://tilesets/wild_west/',
    'res://tilesets/grand_prix/',
    'res://tilesets/venice/',
    'res://tilesets/swamp/',
    'res://tilesets/jungle/',
    'res://tilesets/persia/',
    'res://tilesets/aqua/',
    'res://tilesets/snow/',
    'res://tilesets/castle/',
    'res://tilesets/rooftop/',
)

REQUIRED = (
    'res://scenes/main_menu.tscn.remap',
    'res://scripts/data.gdc',
    'res://tilesets/racing/tileset.json',
    'res://tilesets/racing/pieces.bin',
    'res://tilesets/racing/atlas.png.import',
    'res://tilesets/city/tileset.json',
    'res://tilesets/city/pieces.bin',
    'res://tilesets/city/atlas.png.import',
)

ENGINE_FILES = {
    'res://project.binary': 'res://project.godot',
    'res://.godot/global_script_class_cache.cfg': 'res://project.godot',
    'res://.godot/uid_cache.bin': 'res://project.godot',
}

LICENSES = (
    ('LICENSE', 'LICENSE.txt'),
    ('CustomTilesets/racing/License.txt', 'Kenney-Racing-Kit-License.txt'),
    ('CustomTilesets/city/roads/License.txt', 'Kenney-City-Kit-Roads-License.txt'),
    ('CustomTilesets/city/suburban/License.txt', 'Kenney-City-Kit-Suburban-License.txt'),
    ('CustomTilesets/city/commercial/License.txt', 'Kenney-City-Kit-Commercial-License.txt'),
    ('CustomTilesets/city/industrial/License.txt', 'Kenney-City-Kit-Industrial-License.txt'),
    ('Project/icons/License.txt', 'Kenney-Game-Icons-License.txt'),
)


def godot():
    folder = os.path.join(ROOT, 'Godot')
    if os.path.isdir(folder):
        names = sorted(name for name in os.listdir(folder) if name.startswith('Godot_v') and 'linux' in name and os.path.isfile(os.path.join(folder, name)))
        if names:
            return os.path.join(folder, names[-1])
    found = shutil.which('godot')
    if found:
        return found
    raise SystemExit('Godot editor not found in Godot/ or on PATH')


def pck_entries(path):
    with open(path, 'rb') as handle:
        blob = handle.read()
    if not blob.startswith(b'GDPC'):
        raise SystemExit('no PCK header in %s' % path)
    version, major, minor, patch, flags, file_base, dir_offset = struct.unpack_from('<5I2Q', blob, 4)
    if version < 3 or version > 4:
        raise SystemExit('unsupported PCK version %s in %s' % (version, path))
    directory = dir_offset
    count = struct.unpack_from('<I', blob, directory)[0]
    if count > 100000:
        raise SystemExit('PCK directory in %s is not a file table' % path)
    cursor = directory + 4
    entries = []
    for _ in range(count):
        length = struct.unpack_from('<I', blob, cursor)[0]
        cursor += 4
        raw = blob[cursor:cursor + length]
        cursor += length
        name = raw.split(b'\x00', 1)[0].decode('utf-8')
        if not name.startswith('res://'):
            name = 'res://' + name
        digest = blob[cursor + 16:cursor + 32].hex()
        cursor += 8 + 8 + 16 + 4
        entries.append((name, digest))
    if (major, minor) != (4, 7):
        raise SystemExit('PCK was packed by Godot %s.%s.%s' % (major, minor, patch))
    return entries


def tracked_sources():
    listed = subprocess.run(['git', '-C', ROOT, 'ls-files', '-z', '--', 'Project'], check=True, capture_output=True).stdout
    return {'res://' + name[len('Project/'):] for name in listed.decode('utf-8').split('\0') if name}


def source_of(path, tracked, by_hash):
    if path in ENGINE_FILES:
        return ENGINE_FILES[path]
    name = path.rsplit('/', 1)[-1]
    if path.startswith('res://.godot/imported/'):
        match = re.fullmatch(r'(.+)-([0-9a-f]{32})\.\w+', name)
        source = by_hash.get(match.group(2)) if match else None
        return source if source and source.rsplit('/', 1)[-1] == match.group(1) else None
    if path.startswith('res://.godot/exported/'):
        match = re.fullmatch(r'export-([0-9a-f]{32})-(.+)\.\w+', name)
        source = by_hash.get(match.group(1)) if match else None
        return source if source and source.rsplit('/', 1)[-1].rsplit('.', 1)[0] == match.group(2) else None
    if path.endswith('.remap'):
        path = path[:-len('.remap')]
    if path.endswith('.gdc'):
        path = path[:-len('.gdc')] + '.gd'
    return path if path in tracked else None


def extracted_hashes():
    hashes = {}
    for folder, _dirs, files in os.walk(DATA):
        for name in files:
            full = os.path.join(folder, name)
            digest = hashlib.md5()
            with open(full, 'rb') as handle:
                for chunk in iter(lambda: handle.read(1 << 20), b''):
                    digest.update(chunk)
            hashes[digest.hexdigest()] = full
    return hashes


def verify(pck):
    entries = pck_entries(pck)
    paths = [path for path, _digest in entries]
    blocked = [path for path in paths if path.startswith(FORBIDDEN)]
    if blocked:
        raise SystemExit('pack contains copyrighted paths:\n%s' % '\n'.join(blocked[:30]))
    tracked = tracked_sources()
    by_hash = {hashlib.md5(source.encode('utf-8')).hexdigest(): source for source in tracked}
    unknown = [path for path in paths if source_of(path, tracked, by_hash) is None]
    if unknown:
        raise SystemExit('pack contains files that do not come from git-tracked project files:\n%s' % '\n'.join(unknown[:30]))
    if os.path.isdir(DATA):
        extracted = extracted_hashes()
        copied = ['%s (same bytes as %s)' % (path, extracted[digest]) for path, digest in entries if digest in extracted]
        if copied:
            raise SystemExit('pack contains extracted game files:\n%s' % '\n'.join(copied[:30]))
        print('checked against %d extracted files in %s' % (len(extracted), DATA))
    else:
        print('no %s folder, skipped the extracted-bytes check' % DATA)
    missing = [path for path in REQUIRED if path not in paths]
    if missing:
        raise SystemExit('pack is missing %s' % ', '.join(missing))
    print('pack %s: %d files, %d bytes' % (pck, len(paths), os.path.getsize(pck)))
    return paths


def package(platform):
    chosen = PLATFORMS.get(platform.lower())
    if chosen is None:
        raise SystemExit('platform must be linux or windows')
    preset, binary, template = chosen
    template_path = os.path.join(TEMPLATES, template)
    if not os.path.isfile(template_path):
        raise SystemExit('missing export template %s' % template_path)
    out_dir = os.path.join(BUILDS, preset)
    if os.path.isdir(out_dir):
        shutil.rmtree(out_dir)
    os.makedirs(out_dir)
    out = os.path.join(out_dir, binary)
    subprocess.run([
        godot(), '--headless', '--path', PROJECT,
        '--export-release', preset, out,
    ], check=True)
    pck = os.path.splitext(out)[0] + '.pck'
    if not os.path.isfile(pck):
        raise SystemExit('export did not write %s' % pck)
    verify(pck)
    for source, name in LICENSES:
        shutil.copyfile(os.path.join(ROOT, source), os.path.join(out_dir, name))
    with open(os.path.join(out_dir, 'README.txt'), 'w', encoding='utf-8') as readme:
        readme.write(
            'OpenCircuitBreakers\n'
            '\n'
            'This build does not include Circuit Breakers tracks, cars, or audio.\n'
            'On first launch, point the setup screen at your own copy of the game\n'
            '(a cue sheet, disc image, or extracted folder). An optional demo add-on\n'
            'disc adds Castle and Rooftop.\n'
            '\n'
            'OpenCircuitBreakers is MIT licensed, see LICENSE.txt. The Kenney Racing\n'
            'Kit, City Kit and Game Icons shipped with this build are CC0. See the\n'
            'Kenney-*-License.txt files.\n'
        )
    print(out)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('Usage: python3 Tools/package.py <linux|windows>')
    package(sys.argv[1])
