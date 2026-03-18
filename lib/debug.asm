; ============================================================================
; Debug helpers.
; TODO: Could do log to open file (on HostFS) if useful.
; ============================================================================

.if _DEBUG
.equ Debug_TempLen, 16
.equ Debug_MaxVars, 8
.equ Debug_MaxGlyphs, 96
.equ Debug_Colour, 0xf

.equ Debug_PlotYPos, 20

; Plot a string to the screen at the current cursor position.
; R0=ptr to null terminated string.
.if Screen_Mode==9
.equ debug_plot_string, debug_plot_string_mode9
.else
.equ debug_plot_string, debug_plot_string_slow
.endif
; TODO: debug font for MODE!=9

; R0=address of value to plot as %04x
; Trashes R1-R2,R8-R12.
debug_plot_addr_as_hex4:
    ldr r0, [r0]
    adr r1, debug_temp_string
    mov r2, #Debug_TempLen
    swi OS_ConvertHex4

    adr r0, debug_temp_string
    b debug_plot_string

; R0=address of value to plot as %04x
; Trashes R1-R2,R8-R12.
debug_plot_addr_as_hex8:
    ldr r0, [r0]
    adr r1, debug_temp_string
    mov r2, #Debug_TempLen
    swi OS_ConvertHex8

    adr r0, debug_temp_string
    b debug_plot_string

; R0=address of value to plot as %04x
; Trashes R1-R2,R8-R12.
debug_plot_addr_as_dec4:
    ldr r0, [r0]
    adr r1, debug_temp_string
    mov r2, #Debug_TempLen
    swi OS_ConvertCardinal4

    adr r0, debug_temp_string
    b debug_plot_string

; R0=address of value to plot as vec3
; Trashes R1-R3,R8-R12.
debug_plot_addr_as_vec3:
    str lr, [sp, #-4]!

    ; TODO: Make this nice FP view, e.g. "(XX.xx, YY.yy, ZZ.zz)" %02.2f in C parlance.

    mov r3, r0
    bl debug_plot_addr_as_hex8
    bl debug_cursor_right

    add r0, r3, #4
    bl debug_plot_addr_as_hex8
    bl debug_cursor_right

    add r0, r3, #8
    bl debug_plot_addr_as_hex8

    ldr pc, [sp], #4

.if 0
; R0=fp value.
debug_write_fp:
    stmfd sp!, {r1, r2}
	adr r1, debug_temp_string
	mov r2, #Debug_TempLen
	swi OS_ConvertHex8
	adr r0, debug_temp_string
	swi OS_Write0
    mov r0, #32
    swi OS_WriteC
    ldmfd sp!, {r1, r2}
    mov pc, lr

; R0=vector ptr.
debug_write_vector:
    stmfd sp!, {r0, r3, lr}
    mov r3, r0
    ldr r0, [r3, #0]
    bl debug_write_fp
    ldr r0, [r3, #4]
    bl debug_write_fp
    ldr r0, [r3, #8]
    bl debug_write_fp
    ldmfd sp!, {r0, r3, pc}
.endif


; R0=address of a variable to add to the debug display.
; R1=function used to display the variable.
; Trashes: R1-R4
debug_register_var:
    adr r4, debug_var_stack
    mov r2, #0
.1:
    ldr r3, [r4]
    cmp r3, r0
    moveq pc, lr        ; already registered.

    cmp r3, #0
    stmeqia r4, {r0,r1}
    moveq pc, lr

    add r4, r4, #8
    add r2, r2, #1
    cmp r2, #Debug_MaxVars
    blt .1

    adr r0, error_out_of_vars
    swi OS_GenerateError
    mov pc, lr

; R12=screen addr.
debug_plot_vars:
	ldrb r0, debug_show_info
	cmp r0, #0
	moveq pc, lr

	str lr, [sp, #-4]!

    ldr r12, screen_addr

	SET_BORDER 0xfff		; white = debug

    mov r1, #0
    mov r2, #Debug_PlotYPos
    bl debug_set_cursor

    adr r10, debug_var_stack
    mov r9, #0
.1:
    ldmia r10!, {r0, r1}    ; var addr, plot func
    cmp r0, #0
    beq .2

    adr lr, .3
    ; TODO: Store regs if necessary.
    mov pc, r1              ; call plot func.
    .3:
    bl debug_cursor_right

    add r9, r9, #1
    cmp r9, #Debug_MaxVars
    blt .1

.2:
	SET_BORDER 0x000
	ldr pc, [sp], #4

; R1=byte addr.
debug_toggle_byte:
    ldrb r0, [r1]
    eor r0, r0, #1
    strb r0, [r1]
    mov pc, lr

debug_set_byte_true:
    mov r0, #1
    strb r0, [r1]
    mov pc, lr

debug_set_byte_two:
    mov r0, #2
    strb r0, [r1]
    mov pc, lr

debug_set_byte_three:
    mov r0, #3
    strb r0, [r1]
    mov pc, lr

debug_temp_string:
	.skip Debug_TempLen

debug_var_stack:
    .skip 8*Debug_MaxVars

error_out_of_vars:
    .long 0
    .byte "Out of debug vars!"
    .p2align 2
    .long 0

; Font is 8 bytes per glyph, 1bpp.
debug_font_p:
    .long debug_font_no_adr

debug_font_mode9_p:
    .long debug_font_mode9_no_adr

debug_init:
    ; Reset debug keys & vars.
    mov r0, #0
    adr r1, debug_var_stack
    mov r2, #Debug_MaxVars
.3:
    str r0, [r1], #4                    ; var address
    str r0, [r1], #4                    ; plot func
    subs r2, r2, #1
    bne .3

    ; Explode font to MODE 9 for fast plotting.
    ldr r10, debug_font_p               ; src
    ldr r11, debug_font_mode9_p         ; dst

    mov r9, #Debug_MaxGlyphs
.1:

    ldr r0, [r10], #4                   ; src word = 4x8-bit rows.
    mov r2, #8                          ; glyph height.
.2:
    mov r1, #0                          ; dst word.
    .rept 8
    movs r0, r0, lsr #1
    orrcs r1, r1, #Debug_Colour         ; or 0xf for mask.
    mov r1, r1, lsl #4
    .endr
    str r1, [r11], #4

    cmp r2, #5
    ldreq r0, [r10], #4
    subs r2, r2, #1
    bne .2

    subs r9, r9, #1
    bne .1
    mov pc, lr


debug_cursor_x:
    .byte 0

debug_cursor_y:
    .byte 0
.p2align 2

; R0=ptr to string
; R12=screen addr
; Trashes: R1-R2, R8-R11.
debug_plot_string_mode9:
    stmfd sp!, {r1-r11, lr}

    bl debug_calc_scr_ptr
    ldr r9, debug_font_mode9_p

    mov r8, r0
    adr lr, .1
.1:
    ldrb r0, [r8], #1

    cmp r0, #0
    ldmeqfd sp!, {r1-r11, pc}   ; exit

    cmp r0, #ASCII_Space
    blt .2                      ; vdu code.

    subs r0, r0, #ASCII_Space
    cmp r0, #Debug_MaxGlyphs
    bge .10                     ; ascii>127

    ; Blit glyph.
    add r10, r9, r0, lsl #5    ; 32 bytes per glyph.
    ldmia r10, {r0-r7}
    str r0, [r11], #Screen_Stride
    str r1, [r11], #Screen_Stride
    str r2, [r11], #Screen_Stride
    str r3, [r11], #Screen_Stride
    str r4, [r11], #Screen_Stride
    str r5, [r11], #Screen_Stride
    str r6, [r11], #Screen_Stride
    str r7, [r11], #Screen_Stride

    .10:
    ; Update cursor.
    b debug_cursor_right

    ; Handle VDU codes.
.2:
    cmp r0, #VDU_SetPos                 ; set cursor
    bne .3

    ldrb r1, [r8], #1
    ldrb r2, [r8], #1
    b debug_set_cursor

.3:
    cmp r0, #VDU_TextColour             ; set colour
    bne .4

    ldrb r9, [r8], #1
    ; TODO: Support debug text colour at runtime.
    ;strb r9, debug_colour       ; not supported!
    b .1

.4:
    cmp r0, #VDU_Home                   ; home cursor
    b debug_cursor_home

debug_cursor_home:
.if Screen_Mode==9

    mov r1, #0
    mov r2, #0
    b debug_set_cursor
.else
    swi OS_WriteI+VDU_Home
    mov pc, lr
.endif

debug_cursor_right:
.if Screen_Mode==9
    ldrb r1, debug_cursor_x
    ldrb r2, debug_cursor_y
    add r1, r1, #1
    cmp r1, #40
    movge r1, #0
    addge r2, r2, #8
    cmp r2, #32
    movge r2, #0
; FALL THROUGH!
.else
    swi OS_WriteI+ASCII_Space
    mov pc, lr
.endif

; R1=x, R2=y
debug_set_cursor:
    strb r1, debug_cursor_x
    strb r2, debug_cursor_y
; FALL THROUGH!

; R12=screen addr.
debug_calc_scr_ptr:
    ldrb r1, debug_cursor_x
    ldrb r2, debug_cursor_y
    add r11, r12, r2, lsl #7
    add r11, r11, r2, lsl #5        ; y*160
    add r11, r11, r1, lsl #2        ; x*4
    mov pc, lr

debug_plot_string_slow:
    swi OS_Write0
    mov pc, lr
.endif

.if _DEBUG || _CHECK_FRAME_DROP
debug_set_border:
    orr r4, r4, #VIDC_Border

; R4=colour
; Uses R1
debug_write_vidc:
	SWI		OS_EnterOS
    mov r1, #VIDC_Write
    str r4, [r1]
	TEQP    PC,#0
	MOV     R0,R0
    mov     pc, lr

.endif
