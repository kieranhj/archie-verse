; ============================================================================
; Debug MACROS.
; TODO: These should really push LR on the stack before calling.
; ============================================================================

.macro DEBUG_REGISTER_VAR addr
    .if _DEBUG
    ldr r0, [pc, #0]        ; read addr
    add pc, pc, #0          ; step over addr
    .long \addr
    adr r1, debug_plot_addr_as_hex4         ; default plot func.
    bl debug_register_var
    .endif
.endm

.macro DEBUG_REGISTER_VAR_EX addr, func
    .if _DEBUG
    ldr r0, [pc, #0]        ; read addr
    add pc, pc, #0          ; step over addr
    .long \addr
    adr r1, \func
    bl debug_register_var
    .endif
.endm

.macro DEBUG_REGISTER_VEC3 addr
    .if _DEBUG
    ldr r0, [pc, #0]        ; read addr
    add pc, pc, #0          ; step over addr
    .long \addr
    adr r1, debug_plot_addr_as_vec3
    bl debug_register_var
    .endif
.endm

.macro DEBUG_REGISTER_KEY keycode, func, param
    .if _DEBUG
    mov r0, #\keycode
    adr r1, \func
    mov r2, #\param
    bl debug_register_key
    .endif
.endm

.macro DEBUG_REGISTER_KEY_WITH_VAR keycode, func, addr
    .if _DEBUG
    mov r0, #\keycode
    adr r1, \func
    adr r2, \addr
    bl debug_register_key
    .endif
.endm
