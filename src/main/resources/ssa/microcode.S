# SCCodeTable ABI: shadow a0=SCBaseReg (exclusive upper bound),
# a1=call, a2=resume/callee PC. No user register is modified.
# Metadata at base-64: depth, next_id, spilled_depth, allocation_errors.
# Stack: 256 x 64 B below metadata. Dict: 256K x u32 below stack.
# Records: 256K x 128 B at base-36 MiB. Record 0 is reserved.
.option norvc
.text
.globl _start
_start:
    addi t2, a0, -64
    ld t3, 0(t2)
    ld t4, 16(t2)
    beqz a1, handle_ret
    bnez t4, spill
    li t0, 256
    bgeu t3, t0, spill
    li a3, 0
    beqz t3, hash
    slli t0, t3, 6
    sub t0, t2, t0
    ld a3, 0(t0)             # parent record id
hash:
    srli t0, a2, 1          # preserve halfword addresses (RVC)
    xor t0, t0, a3
    li t1, 262143
    and t0, t0, t1
    slli t0, t0, 2
    li t1, -1065024         # -(64 + 256*64 + 262144*4)
    add t1, a0, t1
    add a4, t1, t0          # bucket address
    lwu t5, 0(a4)
    li a5, -37748736        # -36 MiB
    add a5, a0, a5          # records base
lookup:
    beqz t5, allocate
    slli t0, t5, 7
    add t6, a5, t0
    ld t0, 0(t6)
    bne t0, a2, next
    ld t0, 8(t6)
    beq t0, a3, push
next:
    ld t5, 88(t6)
    j lookup
allocate:
    ld t5, 8(t2)
    li t0, 262144
    bgeu t5, t0, full
    addi t0, t5, 1
    sd t0, 8(t2)
    slli t0, t5, 7
    add t6, a5, t0
    sd a2, 0(t6)
    sd a3, 8(t6)
    sd zero, 16(t6)
    sd zero, 24(t6)
    sd zero, 32(t6)
    lwu t0, 0(a4)
    sd t0, 88(t6)
    sw t5, 0(a4)
push:
    addi t3, t3, 1
    sd t3, 0(t2)
    slli t0, t3, 6
    sub t6, t2, t0
    sd t5, 0(t6)
    csrr t0, mcycle
    csrr t1, minstret
    li a3, 0x200bff8       # RocketConfig CLINT mtime, not a synthetic event
    ld a3, 0(a3)
    sd t0, 8(t6)
    sd t1, 16(t6)
    sd a3, 24(t6)
    j normal_exit
full:
    ld t0, 24(t2)
    addi t0, t0, 1
    sd t0, 24(t2)
spill:
    addi t4, t4, 1
    sd t4, 16(t2)
    j normal_exit
handle_ret:
    beqz t4, pop
    addi t4, t4, -1
    sd t4, 16(t2)
    j normal_exit
pop:
    beqz t3, normal_exit
    csrr t0, mcycle
    csrr t1, minstret
    li a3, 0x200bff8
    ld a3, 0(a3)
    slli t6, t3, 6
    sub t6, t2, t6
    ld t5, 0(t6)
    ld t4, 8(t6)
    sub t0, t0, t4
    ld t4, 16(t6)
    sub t1, t1, t4
    ld t4, 24(t6)
    sub a3, a3, t4
    li t6, -37748736
    add t6, a0, t6
    slli t5, t5, 7
    add t6, t6, t5
    ld t4, 16(t6)
    add t4, t4, t0
    sd t4, 16(t6)
    ld t4, 24(t6)
    add t4, t4, t1
    sd t4, 24(t6)
    ld t4, 32(t6)
    add t4, t4, a3
    sd t4, 32(t6)
    addi t3, t3, -1
    sd t3, 0(t2)
normal_exit:
    .word 0x00060067
