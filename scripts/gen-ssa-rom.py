#!/usr/bin/env python3
"""Assemble the canonical SCCodeTable and update its Scala ROM, or check it."""
import argparse, os, pathlib, re, subprocess, tempfile
root = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
with tempfile.TemporaryDirectory() as d:
    obj = pathlib.Path(d) / 'microcode.elf'
    prefix = os.environ.get('CROSS_COMPILE', 'riscv64-unknown-elf-')
    subprocess.run([prefix+'gcc', '-nostdlib', '-march=rv64g', '-mabi=lp64d',
                    '-Wl,-Ttext=0', '-Wl,--no-relax', str(root/'src/main/resources/ssa/microcode.S'), '-o', str(obj)], check=True)
    dump = subprocess.check_output([prefix+'objdump', '-d', str(obj)], text=True)
words = re.findall(r'^\s*[0-9a-f]+:\s+([0-9a-f]{8})\s', dump, re.M)
assert 0 < len(words) <= 256
p = root/'src/main/scala/rocket/RocketCore.scala'
s = p.read_text()
rom = '    val ssa_rom_data = Seq(\n' + ',\n'.join('      "h'+w+'"' for w in words) + '\n    )'
updated = re.sub(r'    val ssa_rom_data = Seq\(.*?\n    \)', lambda _: rom, s, count=1, flags=re.S)
if args.check:
    assert s == updated, 'SCCodeTable differs from ssa/microcode.S; run ssa/gen_rom.py'
else:
    p.write_text(updated)
print(f'SCCodeTable: {len(words)} instructions ({len(words)*4} bytes)')
