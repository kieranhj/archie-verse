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

; R0=src
; R1=dst
mem_copy_2K_fast:
    str lr, [sp, #-4]!
    ldmia r0!, {r2-r9}              ; 32 bytes
    stmia r1!, {r2-r9}
                                    ; + 42*48=2048 bytes

    ; Skip 341-42 = 299 copy pairs to leave 42 copies.
    adr lr, mem_copy_unrolled_code+299*8
    mov pc, lr                      ; safer to use ADR than ADD!

; R0=src
; R1=dst
mem_copy_4K_fast:
    str lr, [sp, #-4]!
    ldmia r0!, {r2-r5}              ; 16 bytes
    stmia r1!, {r2-r5}
                                    ; + 85*48=4096 bytes

    ; Skip 341-85 = 256 copy pairs to leave 85 copies.
    adr lr, mem_copy_unrolled_code+256*8
    mov pc, lr                      ; safer to use ADR than ADD!

; R0=src
; R1=dst
mem_copy_8K_fast:
    str lr, [sp, #-4]!
    ldmia r0!, {r2-r9}              ; 32 bytes
    stmia r1!, {r2-r9}
                                    ; + 170*48=8192 bytes

    ; Skip 341-170 = 171 copy pairs to leave 170 copies
    adr lr, mem_copy_unrolled_code+171*8
    mov pc, lr                      ; safer to use ADR than ADD!

; R0=src
; R1=dst
mem_copy_16K_fast:
    str lr, [sp, #-4]!
    ldmia r0!, {r2-r5}              ; 16 bytes
    stmia r1!, {r2-r5}

mem_copy_unrolled_code:
    .rept 341                       ; + 341*48=1684 bytes
    ldmia r0!, {r2-r12,r14}         ; 48 bytes
    stmia r1!, {r2-r12,r14}
    .endr                           ; = 16384 bytes = 16K

    ldr pc, [sp], #4

; ============================================================================
