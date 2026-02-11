; ============================================================================
; VU bars
; ============================================================================

.equ VU_Bars_Y_Pos, 216
.equ VU_Bars_Height, 3
.equ VU_Bars_Gap, 4
.equ VU_Bars_Effect, 2	; 'effect'
.equ VU_Bars_Gravity, 2	; lines per vsync

vu_bars_init:
	mov r0, #VU_Bars_Effect
	mov r1, #VU_Bars_Gravity
	swi QTM_VUBarControl
	mov pc, lr

vu_bars_tick:
	str lr, [sp, #-4]!
	mov r0, #0
	swi QTM_ReadVULevels
	; R0 = word containing 1 byte per channel 1-4 VU bar heights 0-64

	and r10, r0, #0xff
	mov r11, #VU_Bars_Y_Pos
	bl plot_vu_bar

	mov r10, r0, lsr #8
	and r10, r10, #0xff
	mov r11, #VU_Bars_Y_Pos + 1 * VU_Bars_Gap
	bl plot_vu_bar

	mov r10, r0, lsr #16
	and r10, r10, #0xff
	mov r11, #VU_Bars_Y_Pos + 2 * VU_Bars_Gap
	bl plot_vu_bar

	mov r10, r0, lsr #24
	mov r11, #VU_Bars_Y_Pos + 3 * VU_Bars_Gap
	bl plot_vu_bar

.if 0
	ldr r12, screen_addr

    ; Blank sprite area.
    mov r1, #0
    bl copy_1_to_8
    mov r0, #Horizontal_Divider_2 + 1
	add r9, r12, r0, lsl #7	; y*128
	add r9, r9, r0, lsl #5	; +y*32 = y*160
    mov r10, #Horizontal_Divider_3 - Horizontal_Divider_2 - 2
    .1:
    bl plot_horizontal_line
    subs r10, r10, #1
    bne .1
.endif

	ldr pc, [sp], #4

; R10 = value (0-64).
; R11 = y pos on screen.
; Preserve R0 please.
plot_vu_bar:
	str lr, [sp, #-4]!

	mov r1, r10, lsr #2		    ; div 4 (0-16)
	cmp r1, #16
	movge r1, #15			    ; clamp to 15.
    mov r1, r1, lsl #8          ; blue

; R1 = VIDC colour.
; R10 = value (0-64).
; R11 = y pos on screen.
; Preserve R0 please.
vu_bar_set_raster:
    ; Raster version.
    adr r9, raster_tables
    ldr r8, [r9]

    add r8, r8, r11, lsl #4     ; raster line.
    str r1, [r8, #-16]          ; set bg colour on previous line.

	orr r1, r1, #0x40000000		; border colour.
    str r1, [r8, #-12]          ; on previous line.
    str r1, [r8, #-8]           ; on previous line.
    str r1, [r8, #-4]           ; on previous line.

	ldr pc, [sp], #4

copy_1_to_8:
	mov r2, r1
	mov r3, r1
	mov r4, r1
	mov r5, r1
	mov r6, r1
	mov r7, r1
	mov r8, r1
    mov pc, lr

; R0 = line no.
; R12 = screen address.
plot_horizontal_line_R0:
	add r9, r12, r0, lsl #7	; y*128
	add r9, r9, r0, lsl #5	; +y*32 = y*160
; FALL THROUGH!

; R9 = ptr to start of line.
; Assume R1-R8 contain screen data.
plot_horizontal_line:
	stmia r9!, {r1-r8}		; 32 bytes
	stmia r9!, {r1-r8}		; 32 bytes
	stmia r9!, {r1-r8}		; 32 bytes
	stmia r9!, {r1-r8}		; 32 bytes
	stmia r9!, {r1-r8}		; 32 bytes
	mov pc, lr
