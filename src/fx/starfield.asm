; ============================================================================
; Starfield. 3D, fixed looking down Z axis.
; Used in: Three-Dee Demo (Mikroreise)
; ============================================================================

.equ Starfield_Total, 512
.equ Starfield_CentreX, 160
.equ Starfield_CentreY, 128

starfield_t:
    .long 0

starfield_speed:
    .long 1

starfield_x_p:
    .long starfield_x_no_adr

starfield_y_p:
    .long starfield_y_no_adr


starfield_init:
    ldr r8, rnd_seed
	ldr r7, bits_mask			; bit

    ldr r4, starfield_x_p
    ldr r5, starfield_y_p

    mov r10, #Starfield_Total
.1:
    ; Generate 2x random numbers for x,y.
    RND r8, r7, r6              ; seed, bit, temp
    mov r0, r8, asr #8          ; cap at +/=256 [s15.16]

    RND r8, r7, r6              ; seed, bit, temp
    mov r1, r8, asr #8          ; cap at +/=256 [s15.16]

    str r0, [r4], #4
    str r1, [r5], #4

    subs r10, r10, #1
    bne .1

    mov pc, lr

bits_mask:
	.long 0x11111111

starfield_update:
    ldr r11, starfield_t
    ldr r0, starfield_speed
    add r11, r11, r0
    cmp r11, #Starfield_Total
    movge r11, #0
    str r11, starfield_t
    mov pc, lr

; R12=screen addr
; TODO: Dedupe from dot_tunnel_draw_anaglyph_spiral?
starfield_draw_anaglyph:
    str lr, [sp, #-4]!

    ; Left eye.
    ldr r0, LeftEye_X_Pos

    ; Subtract blue & green.
    mov r4, #7                  ; brightest red
    bl starfield_draw

    ; Right eye.
    ldr r0, RightEye_X_Pos

    ; Subtract red.
    mov r4, #11                 ; brightest cyan
    bl starfield_draw

    ldr pc, [sp], #4

starfield_skew_offset:
    .long 0

; R0=eye offset.
; R4=colour index.
; R12=screen addr
starfield_draw:
    str lr, [sp, #-4]!

    mov r7, r4                      ; colour
    ldr r11, starfield_t            ; t

    ldr r9, starfield_x_p
    ldr r10, starfield_y_p

    adr r14, starfield_recip_z

    ; TODO: Any camera path.
    mov r5, #0                      ; TEMP: Force camera to (0,0) 
    add r5, r5, r0                  ; eye offset.
    str r0, tunnel_skew_offset      ; TODO: Not needed if camera is forced to (0,0)
    mov r6, #0                      ; TEMP: Force camera to (0,0) 

    mov r8, #0
.1:
    ldr r2, [r14], #4               ; 80/z [7.16]
    ldr r3, [r9, r11, lsl #2]       ; x[i+t] [s8.16]
    ldr r4, [r10, r11, lsl #2]      ; y[i+t] [s8.16]

    ; NB. No tunnel offset!

    sub r3, r3, r5                  ; x+ox-cx
    sub r4, r4, r6                  ; y+oy-cy

    mov r2, r2, asr #8              ; [7.8]
    mov r3, r3, asr #8              ; [s8.8]
    mov r4, r4, asr #8              ; [s8.8]
    mul r0, r3, r2                  ; x/z   [s15.16]
    mul r1, r4, r2                  ; y/z   [s15.16]

    ldrb r3, Anaglyph_Enable_Skew
    cmp r3, #0
    ldrne r5, tunnel_skew_offset    ; TODO: No LDR required.
    movne r3, r5, asl #1
    addne r0, r0, r3

    mov r0, r0, asr #16             ; [s15.0]
    mov r1, r1, asr #16             ; [s15.0]

    add r0, r0, #Starfield_CentreX
    add r1, r1, #Starfield_CentreY

    ; Clip.
    cmp r0, #0
    blt .2
    cmp r0, #Screen_Width
    bge .2
    cmp r1, #0
    blt .2
    cmp r1, #Screen_Height-1
    bge .2

    .if Screen_Mode==13
    add r3, r12, r1, lsl #8
    add r3, r3, r1, lsl #6

    ;mov r2, #0xff
    strb r2, [r3, r0]!
    ;strb r2, [r3, #1]
    ;strb r2, [r3, #Screen_Stride]!
    .else
    ; Assume MODE 9!
    add r3, r12, r1, lsl #7
    add r3, r3, r1, lsl #5
	add r3, r3, r0, lsr #1	; r10 += startx DIV 2

	ldrb r2, [r3]				; load screen byte
	tst r0, #1					; odd or even pixel?
	orreq r2, r2, r7			; mask in colour as left hand pixel
	orrne r2, r2, r7, lsl #4	; mask in colour as right hand pixel
	strb r2, [r3]				; store screen byte
    .endif

.2:
    add r11, r11, #1
    cmp r11, #Starfield_Total
    movge r11, #0

    ; Fade colour with distance.
    add r8, r8, #1
    cmp r8, #Starfield_Total/4
    subge r7, r7, #1
    movge r8, #0

    ; Could probably terminate based on colour bits.
    adr r0, starfield_recip_z_end
    cmp r14, r0
    blt .1

    ldr pc, [sp], #4

; ============================================================================

starfield_recip_z:
.set dz, 40.0               ; distance to start of tunnel.
                            ; zero parallax plane at dz=80.0
.rept Starfield_Total
    FLOAT_TO_FP (160.0/dz)  ; scale to screen.
    .set dz, dz+2           ; larger steps = further into screen.
.endr
starfield_recip_z_end:

; ============================================================================
