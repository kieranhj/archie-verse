; ============================================================================
; Memory functions.
; ============================================================================

; R0=src
; R1=dst
; R2=src end
mem_copy_words_to_end_ptr:
    sub r2, r2, r0      ; bytes
    mov r2, r2, lsr #2  ; words

; R0=src
; R1=dst
; R2=num words.
mem_copy_words:
    .if _DEBUG
    ; TODO: Check for call with <=0
    .endif
.1:
    ldr r3, [r0], #4
    str r3, [r1], #4
    subs r2, r2, #1
    bne .1
    mov pc, lr

; R0=dst
; R1=num words.
mem_clr_words:
    mov r2, #0

; R0=dst
; R1=num repts
; R2=word
mem_rept_word:
    .if _DEBUG
    ; TODO: Check for call with <=0
    .endif
.1:
    str r2, [r0], #4
    subs r1, r1, #1
    bne .1
    mov pc, lr

; ============================================================================

; R0=src
; R1=dst
; R2=bytes
mem_copy_fast:
    ; Or jump table.
    cmp r2, #2048
    beq mem_copy_2K_fast
    cmp r2, #4096
    beq mem_copy_4K_fast
    cmp r2, #8192
    beq mem_copy_8K_fast
    cmp r2, #16384
    beq mem_copy_16K_fast
    .if _DEBUG
    adr r0, error_memcopysize
    swi OS_GenerateError
    .endif
    mov pc, lr

.if _DEBUG
error_memcopysize:
	.long 0
	.byte "Copy size not implemented for mem_copy_fast!"
	.p2align 2
	.long 0
.endif

; TODO: Switch these around so we don't need the stack.
;       Copy the left over bytes first.
;       Then jump into the unrolled code with all registers.
;       And mov pc, lr at the end.
; TODO: Why can't we also use R2 for 44 bytes per instruction?
; TODO: And use R14 and pull the return off the stack? for 48 bytes?

; R0=src
; R1=dst
mem_copy_2K_fast:
    str lr, [sp, #-4]!
    adr lr, .1
    add pc, pc, #732*4              ; jump 359*2+15=733 instructions
    .1:                             ; return
    ldmia r0!, {r3-r8}              ; 24 bytes
    stmia r1!, {r3-r8}
    ldr pc, [sp], #4
; ====================================
; NB. Code must be in this order or add pc instruction needs altering above!
; ====================================

; R0=src
; R1=dst
mem_copy_4K_fast:
    str lr, [sp, #-4]!
    adr lr, .1
    add pc, pc, #624*4              ; jump 308*2+9=625 instructions
    .1:                             ; return
    ldmia r0!, {r3-r10}             ; 32 bytes
    stmia r1!, {r3-r10}
    ldr pc, [sp], #4
; ====================================
; NB. Code must be in this order or add pc instruction needs altering above!
; ====================================

; R0=src
; R1=dst
mem_copy_8K_fast:
    str lr, [sp, #-4]!
    adr lr, .1
    add pc, pc, #412*4              ; jump 205*2+3=413 instructions
    .1:                             ; return
    ldmia r0!, {r3-r4}              ; 8 bytes
    stmia r1!, {r3-r4}
    ldr pc, [sp], #4
; ====================================
; NB. Code must be in this order or add pc instruction needs altering above!
; ====================================

; R0=src
; R1=dst
mem_copy_16K_fast:
    .rept 409                       ; 409*40=16360 bytes
    ldmia r0!, {r3-r12}             ; 40 bytes
    stmia r1!, {r3-r12}
    .endr                           ; 25c*40=1000c
    ldmia r0!, {r3-r8}              ; 24 bytes
    stmia r1!, {r3-r8}
    mov pc, lr
; ====================================
; NB. Code must be in this order or add pc instruction needs altering above!
; ====================================

; ============================================================================
