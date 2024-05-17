; ============================================================================
; Line drawing routines.
; ============================================================================

.equ LibLine_IncludeMode_9, 1
.equ LibLine_IncludeMode_12, 1
.equ LibLine_IncludeBatch, 0

line_reciprocal_table_p:
    .long reciprocal_table_no_adr

.if LibLine_IncludeMode_12
.if LibLine_IncludeBatch
; Plot a batch of lines.
; Parameters:
;  R0=number of lines
;  R1=screen addr
;  R2=ptr to array containining x1,y1,x2,y2
;  [Assumes colour index is just incremented.]
mode12_drawline_batch:
	str lr, [sp, #-4]!			; push lr on stack

    mov r12, r1

    mov r6, r2
    mov r5, r0
    mov r4, #0
.1:
    ldmia r6!, {r0-r3}

    stmfd sp!, {r4-r6}
    ;bl mode9_drawline
    bl mode12_drawline
    ldmfd sp!, {r4-r6}

    add r4, r4, #1
    and r4, r4, #15
    subs r5, r5, #1
    bne .1

    ldr pc, [sp], #4
.endif
.endif

.if LibLine_IncludeMode_9
; R0=startx, R1=starty, R2=endx, R3=endy, R4=colour, R12=screen_addr
; Trashes r5-r9
mode9_drawline_with_clip:
    ldr r9, line_reciprocal_table_p
    cmp r1, r3                  ; starty>endy?
    ble .10
    
    ; Swap ends so ystart<yend
    mov r5, r0
    mov r0, r2
    mov r2, r5
    mov r5, r1
    mov r1, r3
    mov r3, r5

.10:
    cmp r1, #Screen_Height      ; fully off screen?
    movge pc, lr
    cmp r3, #0                  ; fully off screen?
    movlt pc, lr

    ; Need to clip if ystart<0 or yend>=screen height
    cmp r1, #0
    blt .11                      ; top off screen, need clip
    cmp r3, #Screen_Height
    blt .2                      ; bottom off screen, need clip

.11:
    sub r5, r2, r0              ; r5 = dx = endx - startx
    sub r6, r3, r1              ; r6 = dy = endy - starty [+ve]

    ldr r8, [r9, r6, lsl #2+LibDivide_Reciprocal_s] ; r8 = 1/dy [0.16]

    mul r8, r5, r8              ; dx/dy [s9.16]
    cmp r1, #0                  ;
    bge .12
    ; ystart<0
    rsblt r6, r1, #0            ; y_to_zero=-ystart
    mul r5, r8, r6              ; y_to_zero*dx/dy
    add r0, r0, r5, asr #16     ; xstart += y_to_zero*dx/dy
    mov r1, #0                  ; ystart = 0

.12:
    cmp r3, #Screen_Height
    blt .2
    ; yend>=screen height
    sub r6, r3, #Screen_Height-1; y_to_zero=yend-255
    mul r5, r8, r6              ; y_to_zero*dx/dy
    sub r2, r2, r5, asr #16     ; xend -= y_to_zero*dx/dy
    mov r3, #Screen_Height-1    ; yend = 255

.2:
    ; Clipped in Y. Now Clip in X.

    cmp r0, r2                  ; startx>endx?
    ble .20
    
    ; Swap ends so xstart<xend
    mov r5, r0
    mov r0, r2
    mov r2, r5
    mov r5, r1
    mov r1, r3
    mov r3, r5

.20:
    cmp r0, #Screen_Width      ; fully off screen?
    movge pc, lr
    cmp r2, #0                  ; fully off screen?
    movlt pc, lr

    ; Need to clip if xstart<0 or xend>=screen width
    cmp r0, #0
    blt .21                      ; top off screen, need clip
    cmp r2, #Screen_Width
    blt .3                      ; bottom off screen, need clip

.21:
    sub r5, r2, r0              ; r5 = dx = endx - startx [+ve]
    sub r6, r3, r1              ; r6 = dy = endy - starty

    ldr r8, [r9, r5, lsl #2+LibDivide_Reciprocal_s] ; r8 = 1/dx [0.16]

    mul r8, r6, r8              ; dy/dx [s9.16]
    cmp r0, #0                  ;
    bge .22
    ; xstart<0
    rsblt r5, r0, #0            ; x_to_zero=-xstart
    mul r6, r8, r5              ; x_to_zero*dy/dx
    add r1, r1, r6, asr #16     ; ystart += x_to_zero*dy/dx
    mov r0, #0                  ; xstart = 0

.22:
    cmp r2, #Screen_Width
    blt .3
    ; xend>=screen width
    sub r5, r2, #Screen_Width-1 ; x_to_zero=xend-319
    mul r6, r8, r5              ; x_to_zero*dy/dx
    sub r3, r3, r6, asr #16     ; yend -= x_to_zero*dy/dx
    mov r2, #Screen_Width-1     ; xend = 319

.3:
	str lr, [sp, #-4]!			; push lr on stack

    ; Clipped in X & Y. \o/
    ; We also know that startx<endx.
	sub r5, r2, r0				; r5 = dx = endx - startx
	subs r6, r3, r1				; r6 = dy = endy - starty
	rsbmi r6, r6, #0			; r6 = abs(dy)

    cmp r5, r6
    blt .4                      ; dy>dx steep line

    ; dx>=dy shallow line.
	subs r6, r3, r1				; r6 = dy = endy - starty
    ldr r8, [r9, r5, lsl #2+LibDivide_Reciprocal_s] ; r8 = 1/dx [0.16]
    mul r8, r6, r8              ; dy/dx [s9.16]

    mov r1, r1, asl #16         ; y     [9.16]

	tst r0, #1					; odd or even pixel?
    bne .32

    ; for x=xstart to xend
.31:
    cmp r0, r2                  ; xstart==xend?
    ldreq pc, [sp], #4          ; rts

    mov r9, r1, asr #16         ; y [9.0]
	add r5, r12, r9, lsl #7
	add r5, r5, r9, lsl #5	    ; y*stride

  	ldrb r14, [r5, r0, lsr #1]	; load screen byte
	orr r14, r14, r4			; mask in colour as left hand pixel
	strb r14, [r5, r0, lsr #1]	; store screen byte

    add r0, r0, #1              ; x+=1
    add r1, r1, r8              ; y+=dy/dx

.32:
    cmp r0, r2                  ; xstart==xend?
    ldreq pc, [sp], #4          ; rts

    mov r9, r1, asr #16         ; y [9.0]
	add r5, r12, r9, lsl #7
	add r5, r5, r9, lsl #5	    ; scr_addr+y*stride

  	ldrb r14, [r5, r0, lsr #1]	; load screen byte
	orr r14, r14, r4, lsl #4	; mask in colour as right hand pixel
	strb r14, [r5, r0, lsr #1]	; store screen byte

    add r0, r0, #1              ; x+=1
    add r1, r1, r8              ; y+=dy/dx

    b .31

.4:
    ; dx<dy steep line.
    ldr r8, [r9, r6, lsl #2+LibDivide_Reciprocal_s] ; r8 = 1/dy [0.16]
    mul r8, r5, r8              ; dx/dy [s9.16]

    mov r9, #Screen_Stride
	subs r6, r3, r1				; r6 = dy = endy - starty
    rsbmi r9, r9, #0            ; -stride

	add r14, r12, r1, lsl #7	; 
	add r1, r14, r1, lsl #5	    ; replace current_y with current_y_ptr

	add r14, r12, r3, lsl #7	; 
	add r3, r14, r3, lsl #5	    ; replace endy with end_y_ptr

    mov r0, r0, asl #16         ; x     [9.16]

    ; for y=ystart to yend
.41:
    cmp r1, r3                  ; ystart==yend
    ldreq pc, [sp], #4          ; rts

  	ldrb r14, [r1, r0, lsr #17]	; load screen byte
	tst r0, #1<<16				; odd or even pixel?
	orreq r14, r14, r4			; mask in colour as left hand pixel
	orrne r14, r14, r4, lsl #4	; mask in colour as right hand pixel
	strb r14, [r1, r0, lsr #17]	; store screen byte

    add r0, r0, r8              ; x+=dx/dy
    add r1, r1, r9              ; y+=1
    b .41

; FALL THROUGH FOR NOW!

; R0=startx, R1=starty, R2=endx, R3=endy, R4=colour, R12=screen_addr
; Trashes r5-r9
mode9_drawline_orr:
    .if _DEBUG
    cmp r1, #0
    adrlt r0,errneedclip          ; and flag an error
    swilt OS_GenerateError      ; when necessary
    cmp r3, #0
    adrlt r0,errneedclip          ; and flag an error
    swilt OS_GenerateError      ; when necessary
    cmp r1, #Screen_Height
    adrge r0,errneedclip          ; and flag an error
    swige OS_GenerateError      ; when necessary
    cmp r3, #Screen_Height
    adrge r0,errneedclip          ; and flag an error
    swige OS_GenerateError      ; when necessary
    .endif

	str lr, [sp, #-4]!			; push lr on stack
	subs r5, r2, r0				; r5 = dx = endx - startx
	orrs r7, r5, #1<<30			; int sx = dx > 0 ? 1 : -1;
	rsbmi r5, r5, #0			; r5 = abs(dx)

	mov r8, #Screen_Stride      ; r8 = sy = +stride
	subs r6, r3, r1				; r6 = dy = endy - starty
	rsbpl r6, r6, #0			; r6 = -abs(dy)
	rsbmi r8, r8, #0            ; r8 = sy = -stride

	add r9, r5, r6				; r9 = dx + dy = err

	add r14, r12, r1, lsl #7	; 
	add r1, r14, r1, lsl #5	    ; replace current_y with current_y_ptr

	add r14, r12, r3, lsl #7	; 
	add r3, r14, r3, lsl #5	    ; replace endy with end_y_ptr

mode9_drawline_loop:
	cmp r0, r2					; x0 == x1?
	cmpeq r1, r3				; y0 == y1?
    ldreq pc, [sp], #4          ; rts

	ldrb r14, [r1, r0, lsr #1]	; load screen byte

	tst r0, #1					; odd or even pixel?

mode9_drawline_patch:
	orreq r14, r14, r4			; mask in colour as left hand pixel
	orrne r14, r14, r4, lsl #4	; mask in colour as right hand pixel

	strb r14, [r1, r0, lsr #1]	; store screen byte

	mov r14, r9, lsl #1			; r10 = err * 2
	cmp r14, r6					; e2 >= dy?
	addge r9, r9, r6			; err += dy
	addge r0, r0, r7, asr #30   ; x0 += sx

	cmp r14, r5					; e2 <= dx?
	addle r9, r9, r5			; err += dx
	addle r1, r1, r8			; y0 += stride_y

	b mode9_drawline_loop

drawline_set_to_orr:
    adr r0, drawline_patch_orr
drawline_do_patch:
    ldmia r0, {r1-r2}
    str r1, mode9_drawline_patch+0
    str r2, mode9_drawline_patch+4
    mov pc, lr

drawline_patch_orr:
	orreq r14, r14, r4			; mask in colour as left hand pixel
	orrne r14, r14, r4, lsl #4	; mask in colour as right hand pixel

drawline_set_to_bic:
    adr r0, drawline_patch_bic
    b drawline_do_patch

drawline_patch_bic:
	biceq r14, r14, r4			; mask out olour as left hand pixel
	bicne r14, r14, r4, lsl #4	; mask out colour as right hand pixel

.if _DEBUG
    errneedclip: ;The error block
    .long 0
    .byte "Line needs clipping in Y."
	.align 4
	.long 0
.endif

.if 0
; R0=x, R1=y, R4=colour, R12=screen_addr, trashes r10, r11
mode9_plot_pixel:
	; ptr = screen_addr + starty * screen_stride + startx DIV 2
	add r10, r12, r1, lsl #7	; r10 = screen_addr + starty * 128
	add r10, r10, r1, lsl #5	; r10 += starty * 32 = starty * 160
	add r10, r10, r0, lsr #1	; r10 += startx DIV 2

	ldrb r11, [r10]				; load screen byte

	tst r0, #1					; odd or even pixel?
	andeq r11, r11, #0xF0		; mask out left hand pixel
	orreq r11, r11, r4			; mask in colour as left hand pixel

	andne r11, r11, #0x0F		; mask out right hand pixel
	orrne r11, r11, r4, lsl #4	; mask in colour as right hand pixel

	strb r11, [r10]				; store screen byte
	mov pc, lr
.endif
.endif

.if LibLine_IncludeMode_12
; R0=startx, R1=starty, R2=endx, R3=endy, R4=colour, R12=screen_addr
; Trashes r5-r10
mode12_drawline:
	orr r4, r4, r4, lsl #4      ; make byte

	subs r5, r2, r0				; r5 = dx = endx - startx
	orrs r7, r5, #1<<30			; int sx = dx > 0 ? 1 : -1;
	rsbmi r5, r5, #0			; r5 = abs(dx)

	mov r8, #320                ; r8 = sy = +stride
	subs r6, r3, r1				; r6 = dy = endy - starty
	rsbpl r6, r6, #0			; r6 = -abs(dy)
	rsbmi r8, r8, #0            ; r8 = sy = -stride

	add r9, r5, r6				; r9 = err = dx + dy

	add r10, r12, r1, lsl #8	; 
	add r1, r10, r1, lsl #6	    ; replace current_y with current_y_ptr

	add r10, r12, r3, lsl #8	; 
	add r3, r10, r3, lsl #6	    ; replace endy with end_y_ptr

    ; ~13c setup per line.

    ; R0=current_x
    ; R1=current_y_ptr
    ; R2=end_x
    ; R3=end_y_ptr
    ; R4=colour byte
    ; R5=dx
    ; R6=dy
    ; R7=sx
    ; R8=stride_y
    ; R9=err
    ; R10=e2 (temp)
    ; R11=<free>
    ; R12=screen base
    ; R14=scanline ptr
.1:
	cmp r0, r2					; x0 == x1?                 ; 1c
	cmpeq r1, r3				; y0 == y1?                 ; 1c
	moveq pc, lr       			; rts                       ; 1c

	; NOTE: Aligning this write to address xxxxxxx4 has measurable
	;       speed improvements over any other alignment. Worth testing! 
	strb r4, [r1, r0]     	    ; store screen byte         ; 4c

	mov r10, r9, lsl #1			; r10 = err * 2 = e2        ; 1c
	cmp r10, r6					; e2 >= dy?                 ; 1c
	addge r9, r9, r6			; err += dy                 ; 1c
	addge r0, r0, r7, asr #30	; x0 += sx                  ; 1c

	cmp r10, r5					; e2 <= dx?                 ; 1c
	addle r9, r9, r5			; err += dx                 ; 1c
	addle r1, r1, r8			; y0 += stride_y            ; 1c

	b .1                                                    ; 4c
    ; ~18c per pixel?

; PONDER: Unroll this loop to maximum length (320)
;         Compute number of loop iterations (max(dx,dy))
;         Poke in a return instruction after N iterations.
;         Restore original instruction upon completion.
.endif
