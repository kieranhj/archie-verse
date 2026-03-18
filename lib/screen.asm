; ============================================================================
; Screen routines, clear, copy, etc.
; ============================================================================

.if Cls_Bytes != Screen_Bytes
; For custom CLS from line N to line M.
; Calculate write address.
; Calculate size in bytes.
; Write left over bytes.
; Jump into unrolled code for large block.
screen_cls_from_line:
    .if Cls_Bytes != 30080
    .err "Expected Cls_Bytes == 30080!"
    .endif

    add r12, r12, #Cls_FirstLine*Screen_Stride

    ; 30080 bytes = 578 * 52 bytes + 24 bytes

    ; NB. Looks bad but Shrinkler will eat this.
    str lr, [sp, #-4]!
	mov r1, r0
	mov r2, r0
	mov r3, r0
	mov r4, r0
	mov r5, r0
	mov r6, r0
	mov r7, r0
	mov r8, r0
	mov r9, r0
	mov r10, r0
	mov r11, r0
    mov r14, r0

    stmia r12!, {r0-r5}             ; 24 bytes
    add pc, pc, #223*4              ; skip 15 + (787-578) = 224 instructions
    ; TODO: Watch out if this is more than one instruction! Replace with ADR!
.endif

; ====================================
; NB. Code must be in this order or add pc instruction needs altering above!
; ====================================

; A full MODE 9 screen is 160*256=40960 bytes.
; At 13 registers per write = 52 bytes per instruction.
; 
; 787 STM writes = 787 * (3 + 1.25*13) = 787 * 19.25c = 15149.75c
; To write 40924 bytes + 36 bytes left over = 40960
;
; R12 = screen address
; trashes R0-R11, R14
screen_cls:
    mov r0, #0

; NB. Shrinkler compresses this code better than generating it at runtime.
; R0 = word to fill screen.
screen_cls_with_word:
    str lr, [sp, #-4]!
	mov r1, r0
	mov r2, r0
	mov r3, r0
	mov r4, r0
	mov r5, r0
	mov r6, r0
	mov r7, r0
	mov r8, r0
	mov r9, r0
	mov r10, r0
	mov r11, r0
    mov r14, r0
    .if Screen_Bytes != 40960
    .err "Expected ScreenMode == 9!"
    .endif
	stmia r12!, {r0-r8}                 ; 36 bytes

; ====================================
; NB. Code must be in this order or add pc instruction needs altering above!
; ====================================

screen_cls_unrolled_stores:
    .rept Screen_Bytes / 52             ; 787 * 52 bytes
	stmia r12!, {r0-r11,r14}
    .endr
    ldr pc, [sp], #4

; ============================================================================

.if 0
screen_cls_grey:
    .long 0x33333333

screen_cls_to_grey:
    ldr r0, screen_cls_grey
    b screen_cls_with_word

; R12 = screen address
screen_dup_lines:
	add r9, r12, #Screen_Bytes
	add r11, r12, #Screen_Stride
.1:
	.rept Screen_Stride / 32
	ldmia r12!, {r0-r7}
	stmia r11!, {r0-r7}
	.endr
	add r12, r12, #Screen_Stride
	add r11, r11, #Screen_Stride
	cmp r12, r9
	blt .1
	mov pc, lr

static_palette_p:
    .long 0

static_set_palette:
    ldr r2, static_palette_p
    cmp r2, #0
    moveq pc, lr
    b palette_set_block

static_screen_p:
    .long 0

; R12=screen address
static_copy_screen:
    ldr r11, static_screen_p
    cmp r11, #0
    moveq pc, lr

; R11=source address
; R12=screen address
screen_copy:
    mov r10, #Screen_Height
.1:
    .rept Screen_Stride / 40
	ldmia r11!, {r0-r9}
	stmia r12!, {r0-r9}
    .endr
    subs r10, r10, #1
    bne .1
    mov pc, lr
.endif

; ============================================================================
