# SSA-HPM SCCodeTable

`microcode.S` is the canonical source for the injected ROM in
`src/main/scala/rocket/RocketCore.scala`. From the Rocket Chip root:

```sh
python3 scripts/gen-ssa-rom.py
python3 scripts/gen-ssa-rom.py --check
```

This needs `riscv64-unknown-elf-{gcc,objdump}` on PATH. `CROSS_COMPILE` overrides
the prefix. ROM generation disables compressed instructions and relaxation;
application instructions may be compressed. The private ROM currently fits in
an 8-bit instruction index. The test/loader integration lives in Chipyard's
`ssa/` directory on the matching delivery branch.

Enable by writing a valid exclusive upper bound to CSR `0x800` (SCBaseReg);
zero disables monitoring. The caller must reserve 36 MiB of accessible memory,
zero the dictionary, and initialize metadata `{depth=0, next_id=1,
spilled_depth=0, allocation_errors=0}`. Memory faults in private microcode are
fatal in this prototype; the reservation must remain mapped and accessible.
The verified platform is a single RV64GC Rocket in Chipyard `RocketConfig`,
bare-metal M mode with interrupts disabled. Interrupts are deferred during
microcode execution; kernel scheduling, VM faults, debug entry, coroutines,
non-local unwinds, and multicore ownership are not validated.

Offsets relative to SCBaseReg (all byte offsets, little-endian):

| Region | Location | Size |
| --- | --- | --- |
| Metadata | `base-64` | 64 B |
| SCStack | below metadata, descending | 256 x 64 B |
| SCDict | `base-1065024` | 262144 x u32 |
| HPERecords | `base-37748736` | 262144 x 128 B |

Record 0 is reserved. Each record has full callee PC at 0, parent id at 8,
cycle at 16, instret at 24, CLINT mtime at 32, six reserved u64s at 40..80,
next id at 88, the seventh reserved HPM slot at 96, and padding at 104..120. All ids fit in 18 bits.
Hash: `(parent_id ^ (callee_pc >> 1)) & 262143`. The full key is compared
while traversing the collision chain. Allocation prepends to the bucket.
Halfword-aligned RVC function addresses are preserved without aliasing.

The nth frame (n starts at 1) is `base-64-n*64`, containing record id at 0
and entry snapshots cycle/instret/mtime at 8/16/24. Stack overflow folds deeper
calls into the current top context until the excess calls unwind. Exhausted
records similarly skip the unavailable subtree and increment an explicit
error count. Neither case writes outside the reservation. A root return with
an empty stack is ignored.

Counters are inclusive, accumulated on return, with 64-bit modular deltas.
They include monitor overhead within the snapshot interval and child calls;
these are not overhead-subtracted estimates of application-only work. `mtime`
is read from the verified platform's CLINT at `0x200bff8`, not synthesized from
cycles. Its short-interval delta may be zero. The seven future HPM slots are reserved only; no cache, TLB, or data-access
classification is claimed. The 128-byte ABI is explicit
rather than the draft's underspecified packed key/padding.

Calls are retired JAL/JALR writing x1 or x5. Returns are JALR with rd=x0,
rs1=x1/x5 and immediate zero. Other indirect jumps leave context intact.
Tail calls, coroutine pop+push hints, exceptions and longjmp need a future ABI.
Each ROM instruction completes (including delayed loads) or replays before
the next issues. Branch/CSR redirects use the actual pipeline PC. Private
branches do not train frontend prediction. Late integer writes retain the
issuing register bank across monitor entry. There is no watchdog success
fallback that silently discards profiling work.
