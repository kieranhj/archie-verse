; ============================================================================
; Keyboard handling.
; May or may not be _DEBUG.
; ============================================================================

.equ Keys_MaxCallbacks, 32

keys_num:
    .long 0

keys_pressed_mask:
    .long 0

keys_prev_mask:
    .long 0

keys_rm_code:
    .long 0

; R0=key code to register.
; R1=addr of function to call.
; R2=param to call the function with.
; Trashes: R3-R4.
keys_register_callback:
    adr r4, keys_callback_stack
    ldr r3, keys_num
    cmp r3, #Keys_MaxCallbacks
    adrge r0, error_out_of_keys
    swige OS_GenerateError

    add r4, r4, r3, lsl #3
    add r4, r4, r3, lsl #2
    stmia r4, {r0-r2}

    add r3, r3, #1
    str r3, keys_num
    mov pc, lr

; R1=0 key up or 1 key down
; R2=internal key number (RMKey_*)
keys_handle_keypress:
    stmfd sp!, {r3-r6}
    adr r4, keys_callback_stack
    ldr r3, keys_num
    add r4, r4, r3, lsl #3
    add r4, r4, r3, lsl #2
    mov r5, #1
    mov r5, r5, lsl r3      ; key bit.
    ldr r3, keys_pressed_mask
.1:
    ; Any bits left?
    movs r5, r5, lsr #1
    beq .2                  ; no more bits.

    ; Check key code.
    ldr r6, [r4, #-12]!
    cmp r6, r2
    bne .1

    ; Key matches so mask bit in/out.
    cmp r1, #0
    biceq r3, r3, r5
    orrne r3, r3, r5
    b .1

.2:
    str r3, keys_pressed_mask
    ldmfd sp!, {r3-r6}
    mov pc, lr

keys_do_callbacks:
	str lr, [sp, #-4]!

    ldr r0, keys_pressed_mask
	ldr r2, keys_prev_mask
	mvn r2, r2				; ~old
	and r2, r0, r2			; new & ~old		; diff bits
	str r0, keys_prev_mask
	and r4, r2, r0			; diff bits & key down bits	

    adr r3, keys_callback_stack
    ldr r0, keys_num
    add r3, r3, r0, lsl #3
    add r3, r3, r0, lsl #2

    mov r5, #1
    mov r5, r5, lsl r0      ; key bit.
.1:
    ; Any bits left?
    movs r5, r5, lsr #1
    beq .2                  ; no more bits.

    ; Key down?
    sub r3, r3, #12
    tst r4, r5
    beq .1

    ; Make key callback.
    ldr r0, [r3, #4]        ; func.
    ldr r1, [r3, #8]        ; data.
    adr lr, .1
    mov pc, r0

.2:
    ldr pc, [sp], #4

keys_callback_stack:
    .skip 12*Keys_MaxCallbacks

error_out_of_keys:
    .long 0
    .byte "Out of keys!"
    .p2align 2
    .long 0
