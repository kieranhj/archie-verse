; ============================================================================
; Scroller: single character y position for fixed sized glyphs.
; Pre-shift glyph data 8 times (per pixel).
; Copy and mask word-aligned glyph data to screen.
; Used in: Chipo Django musicdisk.
; ============================================================================

; TODO: Make these params.
.equ Dj_Scroller_Y_Pos, 			240
.equ Dj_Scroller_Max_Glyphs, 		60

.equ Dj_Scroller_Glyph_Width, 		16
.equ Dj_Scroller_Glyph_Height, 		16

.equ Dj_Scroller_Code_EOF, 			0
.equ Dj_Scroller_Code_Wait, 		1
.equ Dj_Scroller_Code_Speed, 		2

.equ Dj_Scroller_Sine_Glyph_Delta, 	4096
.equ Dj_Scroller_Sine_Tick_Delta, 	1024
.equ Dj_Scroller_Sine_Shift, 		13			; [-8,+8]

.equ _SCROLLER_SINE, 1

dj_scroller_enable_sine:
	.long 0

dj_scroller_speed:
    .long 1

dj_scroller_delay:
    .long 0

dj_scroller_shift:
	.long 0

dj_scroller_text_ptr:
	.long dj_scroller_text_string_end_no_adr - 2

dj_scroller_ctrl_ptr:
	.long dj_scroller_text_string_end_no_adr - 2

dj_scroller_text_start_p:
	.long dj_scroller_text_string_no_adr

dj_scroller_font_data_p:
	.long dj_scroller_font_data_no_adr

dj_scroller_font_data_shifted_p:
	.long dj_scroller_font_data_shifted_no_adr

dj_scroller_font_colour:
	.long 0x88888888

dj_scroller_font_shift_table:
	.skip 8*4


; Use a separate ptr to check control codes so that these take effect
; when hit on the RHS of the screen as per Amiga specification.
check_scrolltext_ctrl_code:
	ldr r10, dj_scroller_ctrl_ptr
    
    .1:
	ldrb r0, [r10, #1]!
    cmp r0, #Dj_Scroller_Code_Wait
    bne .2

    ; Next byte is time.
	ldrb r0, [r10, #1]!
    mov r0, r0, lsl #3      ; wait value * 8 frames.
    str r0, dj_scroller_delay
    b .1

    .2:
    cmp r0, #Dj_Scroller_Code_Speed
    bne .3

    ; Next byte is speed.
	ldrb r0, [r10, #1]!
    str r0, dj_scroller_speed
    b .1

    .3:
	cmp r0, #Dj_Scroller_Code_EOF
	bne .5

    ; Loop text.
	ldr r10, dj_scroller_text_start_p
	sub r10, r10, #1
    b .1

	.5:
	str r10, dj_scroller_ctrl_ptr
	mov pc, lr


update_scrolltext_ptr:
    str lr, [sp, #-4]!

	; Check control codes first.
	bl check_scrolltext_ctrl_code

	; Get next ASCII.
	ldr r10, dj_scroller_text_ptr
    .1:
	ldrb r0, [r10, #1]!
    cmp r0, #Dj_Scroller_Code_EOF
    ldreq r10, dj_scroller_text_start_p
	subeq r10, r10, #1
    beq .1

	; Skip control codes.
	cmp r0, #ASCII_Space
	blt .1

	str r10, dj_scroller_text_ptr
    ldr pc, [sp], #4


dj_scroller_init:
    str lr, [sp, #-4]!

	ldr r11, dj_scroller_font_data_shifted_p	; write ptr
;	ldr r12, dj_scroller_font_colour
	adr r14, dj_scroller_font_shift_table

	mov r10, #0					; pixel shift
.1:
	str r11, [r14], #4			; store write ptr for shift.

    mov r8, r10, lsl #2         ; word shift
    rsb r7, r8, #32             ; reverse word shift

	ldr r9, dj_scroller_font_data_p			; read ptr
	mov r6, #0					; glyph number
.2:

	mov r5, #0					; glyph row
.3:
	ldmia r9!, {r0-r1}			; 2 glyph words

;	and r0, r0, r12
;	and r1, r1, r12				; mask font colour

	mov r2, r0, lsl r8			; shifting left moves pixels right
	mov r3, r0, lsr r7			; shift right to recover lost pixels to next word
	orr r3, r3, r1, lsl r8		; shift left to move pixels right
	mov r4, r1, lsr r7			; shift right to recover lost pixels to next word

	stmia r11!, {r2-r4}			; 3 glyph words shifted right by N pixels

	add r5, r5, #1
	cmp r5, #Dj_Scroller_Glyph_Height
	blt .3

	add r6, r6, #1
	cmp r6, #Dj_Scroller_Max_Glyphs
	blt .2

	add r10, r10, #1
	cmp r10, #8					; max shift
	blt .1

	; Move control code ptr to RHS of screen.
	mov r11, #20
.4:
	bl check_scrolltext_ctrl_code
	subs r11, r11, #1
	bne .4

    ldr pc, [sp], #4


; R0=glyph no.
; R8=pixel shift [0-7]
; R10=font colour
; R11=screen addr (updated for next glyph)
; Trashes: R0-R2,R4-R6, R9
dj_scroller_plot_glyph:
	; Calc base ptr to glyph data.
	adr r9, dj_scroller_font_shift_table
	ldr r9, [r9, r8, lsl #2]			; shift_table[shift]

	add r9, r9, r0, lsl #7				; glyph_no * 128
	add r9, r9, r0, lsl #6				; + glyph_no * 64
	; !ASSUMES GLYPH SIZE IS (8+4)x16 BYTES!
    .if Dj_Scroller_Glyph_Width!=16
    .err "dj_scroller_plot_glyph assumes glyphs are 2-3 words wide!"
    .endif

	.rept Dj_Scroller_Glyph_Height
	ldmia r9!, {r0-r2}					; read glyph words
	ldmia r11, {r4-r6}					; read screen words

	bic r4, r4, r0						; mask out glyph bits
	and r0, r0, r10						; set colour
	orr r4, r4, r0						; mask in glyph bits

	bic r5, r5, r1						; mask out glyph bits
	and r1, r1, r10						; set colour
	orr r5, r5, r1						; mask in glyph bits

	bic r6, r6, r2						; mask out glyph bits
	and r2, r2, r10						; set colour
	orr r6, r6, r2						; mask in glyph bits

	stmia r11, {r4-r6}					; write to screen
	add r11, r11, #Screen_Stride		; next line
	.endr

	sub r11, r11, #Dj_Scroller_Glyph_Height*Screen_Stride - 8
	mov pc, lr

; R0=glyph no.
; R7=1 (LHS) or 0 (RHS).
; R8=pixel shift [0-7]
; R10=font colour
; R11=screen addr (updated for next glyph)
; Trashes: R0-R2,R4-R6, R9
dj_scroller_plot_glyph_1_column:
	; Calc base ptr to glyph data.
	adr r9, dj_scroller_font_shift_table
	ldr r9, [r9, r8, lsl #2]			; shift_table[shift]

	add r9, r9, r0, lsl #7				; glyph_no * 128
	add r9, r9, r0, lsl #6				; + glyph_no * 64
	; !ASSUMES GLYPH SIZE IS (8+4)x16 BYTES!

	add r9, r9, r7, lsl #3				; (LHS) skip first two columns.

	.rept Dj_Scroller_Glyph_Height
	ldr r0, [r9], #12					; one glyph word
	ldr r4, [r11]						; one screen word

	bic r4, r4, r0						; mask out glyph bits
	and r0, r0, r10						; set colour
	orr r4, r4, r0						; mask in glyph bits

	str r4, [r11], #Screen_Stride		; write to screen
	.endr

	sub r11, r11, #Dj_Scroller_Glyph_Height*Screen_Stride
	mov pc, lr

; R0=glyph no.
; R7=1 (LHS) or 0 (RHS).
; R8=pixel shift [0-7]
; R10=font colour
; R11=screen addr (updated for next glyph)
; Trashes: R0-R2,R4-R6, R9
dj_scroller_plot_glyph_2_columns:
	; Calc base ptr to glyph data.
	adr r9, dj_scroller_font_shift_table
	ldr r9, [r9, r8, lsl #2]			; shift_table[shift]

	add r9, r9, r0, lsl #7				; glyph_no * 128
	add r9, r9, r0, lsl #6				; + glyph_no * 64
	; !ASSUMES GLYPH SIZE IS (8+4)x16 BYTES!

	add r9, r9, r7, lsl #2				; (LHS) skip first column word

	.rept Dj_Scroller_Glyph_Height
	ldmia r9, {r0-r1}					; read glyph words
	add r9, r9, #12						; skip to next row
	ldmia r11, {r4-r5}					; read screen words

	bic r4, r4, r0						; mask out glyph bits
	and r0, r0, r10						; set colour
	orr r4, r4, r0						; mask in glyph bits

	bic r5, r5, r1						; mask out glyph bits
	and r1, r1, r10						; set colour
	orr r5, r5, r1						; mask in glyph bits

	stmia r11, {r4-r5}					; write to screen
	add r11, r11, #Screen_Stride		; next line
	.endr

	sub r11, r11, #Dj_Scroller_Glyph_Height*Screen_Stride - 4
	mov pc, lr



; Returns R0 = glyph no.
dj_scroller_get_next_glyph_no:
    ldrb r0, [r12], #1

	; Loop end of text.
    cmp r0, #0
    ldreq r12, dj_scroller_text_start_p
    beq dj_scroller_get_next_glyph_no

	; Skip control codes.
	cmp r0, #ASCII_Space
	blt dj_scroller_get_next_glyph_no

	sub r0, r0, #ASCII_Space
	mov pc, lr

.if _SCROLLER_SINE
dj_scroller_sine_index:
	.long 0

dj_scroller_sine_last_y:
	.long 0
.endif

; Draw entire scroller.
; R12=screen addr
dj_scroller_draw:
    str lr, [sp, #-4]!

    ldr r3, dj_scroller_shift			; [0-15]
	and r8, r3, #7					; pixel shift [0-7]

	mov r1, #Dj_Scroller_Y_Pos
	.if _SCROLLER_SINE
	ldr r2, dj_scroller_enable_sine
	cmp r2, #0
	beq .10
	; Calc y=y_pos+8*sin(idx)
	ldr r0, dj_scroller_sine_index
	bl sine			; [s1.16]
	add r1, r1, r0, asr #Dj_Scroller_Sine_Shift
	str r1, dj_scroller_sine_last_y
	.10:
	.endif

	add r11, r12, r1, lsl #7
	add r11, r11, r1, lsl #5

	ldr r10, dj_scroller_font_colour
    ldr r12, dj_scroller_text_ptr
	bl dj_scroller_get_next_glyph_no

	; If shift > 0 then need to plot left & right hand side glyph.
	cmp r3, #0
	beq .2

	; LHS.
	mov r7, #1
	cmp r3, #8
	; Plot two column words?
	blge dj_scroller_plot_glyph_2_columns
	; Or just one?
	bllt dj_scroller_plot_glyph_1_column

.2:
	.if _SCROLLER_SINE
	ldr r3, dj_scroller_sine_index
	.endif

	mov r7, #19
	ldr r0, dj_scroller_shift
	cmp r0, #0

	; If glyph shift == 0 then plot 20 glyphs.
	addeq r7, r7, #1				; 20
	beq .4

.1:
	.if _SCROLLER_SINE
	ldr r1, dj_scroller_enable_sine
	cmp r1, #0
	beq .11

	; Update sine index
	add r3, r3, #Dj_Scroller_Sine_Glyph_Delta

	; Calc y'
	mov r0, r3
	bl sine
	mov r0, r0, asr #Dj_Scroller_Sine_Shift
	add r0, r0, #Dj_Scroller_Y_Pos

	; Update R11 += (y'-y)*160
	ldr r1, dj_scroller_sine_last_y
	str r0, dj_scroller_sine_last_y
	sub r0, r0, r1
	add r11, r11, r0, lsl #7
	add r11, r11, r0, lsl #5
	.11:
	.endif

.4:
	bl dj_scroller_get_next_glyph_no
	bl dj_scroller_plot_glyph

	subs r7, r7, #1
	bne .1

	; If shift > 0 then need to plot left & right hand side glyph.
    ldr r2, dj_scroller_shift			; [0-15]
	cmp r2, #0
	beq .3

	.if _SCROLLER_SINE
	ldr r1, dj_scroller_enable_sine
	cmp r1, #0
	beq .12

	; Update sine index.
	add r3, r3, #Dj_Scroller_Sine_Glyph_Delta

	; Calc y'
	mov r0, r3
	bl sine
	mov r0, r0, asr #Dj_Scroller_Sine_Shift
	add r0, r0, #Dj_Scroller_Y_Pos

	; Update R11 += (y'-y)*160
	ldr r1, dj_scroller_sine_last_y
	sub r0, r0, r1
	add r11, r11, r0, lsl #7
	add r11, r11, r0, lsl #5
	.12:
	.endif

	bl dj_scroller_get_next_glyph_no

	; RHS.
	mov r7, #0
	cmp r2, #8
	; Plot two column words?
	bllt dj_scroller_plot_glyph_2_columns
	; Or just one?
	blge dj_scroller_plot_glyph_1_column

.3:
	.if _SCROLLER_SINE
	ldr r1, dj_scroller_enable_sine
	cmp r1, #0
	beq .13

	ldr r3, dj_scroller_sine_index
	ldr r0, dj_scroller_speed
	sub r3, r3, #Dj_Scroller_Sine_Tick_Delta
	str r3, dj_scroller_sine_index
	.13:
	.endif

    ldr pc, [sp], #4


dj_scroller_tick:
	str lr, [sp, #-4]!

    ldr r0, dj_scroller_delay
    cmp r0, #0
    beq .1
    subs r0, r0, #1
    str r0, dj_scroller_delay
	ldrne pc, [sp], #4

    .1:
	; next column index
	ldr r0, dj_scroller_shift
    ldr r1, dj_scroller_speed
	subs r0, r0, r1
	bpl .2

	add r0, r0, #Dj_Scroller_Glyph_Width

	.if _SCROLLER_SINE
	ldr r2, dj_scroller_sine_index
	add r2, r2, #Dj_Scroller_Sine_Glyph_Delta
	str r2, dj_scroller_sine_index
	.endif

	.2:
	str r0, dj_scroller_shift

	; next string char?
	blmi update_scrolltext_ptr

	ldr pc, [sp], #4
