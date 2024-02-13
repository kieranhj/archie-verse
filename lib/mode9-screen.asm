; ============================================================================
; MODE 9 screen routines
; ============================================================================

; R12 = screen address
; trashes r0-r9
screen_cls:
    mov r0, #0

; R0 = word to fill screen.
screen_cls_with_word:
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
    .rept Screen_Bytes / 48
	stmia r12!, {r0-r11}
    .endr
    .if Screen_Bytes-48*(Screen_Bytes/48)==32
	stmia r12!, {r0-r7}
    .endif
    .if Screen_Bytes-48*(Screen_Bytes/48)==16
	stmia r12!, {r0-r3}
    .endif
	mov pc, lr

screen_cls_grey:
    .long 0x33333333

screen_cls_to_grey:
    ldr r0, screen_cls_grey
    b screen_cls_with_word

.if 0
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

static_screen_p:
    .long 0

static_palette_p:
    .long 0

static_set_palette:
    ldr r2, static_palette_p
    cmp r2, #0
    moveq pc, lr
    b palette_set_block

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
