; ============================================================================
; Palette Utils (OLD)
; NOTE(09/05/23): Consider these a bit crusty and slow.
;                 Perhaps look at direct VIDC register poking in arc-django-2?
; NOTE(20/08/23): I'm amazed the fade functions work at all and they only do
;                 if RGB values are specified at the top nibble of each byte
;                 only! I'm not sure if the original implementation was clever
;                 or just lucky!!
; ============================================================================

; R3 = index
; R4 = RGBx word (actually 0x00BbGgRr) where bgr are ignored.
; Uses R0,R1 
palette_set_colour:
    adrl r1, palette_osword_block
    strb r3, [r1, #0]       ; logical colour
    mov r0, #16
    strb r0, [r1, #1]       ; physical colour
    and r0, r4, #0xff
    strb r0, [r1, #2]       ; red
    mov r0, r4, lsr #8
    strb r0, [r1, #3]       ; green
    mov r0, r4, lsr #16
    strb r0, [r1, #4]       ; blue

    mov r9, pc
    orr r8, r9, #ProcMode_Svc
    teqp r8, #0 ; enter Svc mode
    mov r0, r0
    str lr, [sp, #-4]!  ; store lr_svc

    mov r0, #12
    swi XOS_Word

    ldr lr, [sp], #4    ; restore lr_svc
    teqp r9, #0 ; reenter original mode
    mov r0, r0

    mov pc,lr

; R2 = palette block ptr
palette_set_block:
	str lr, [sp, #-4]!			; push lr on stack
    mov r3, #0
    .1:
    ldr r4, [r2], #4            ; rgbx
    bl palette_set_colour
    add r3, r3, #1
    cmp r3, #16
    blt .1
	ldr pc, [sp], #4			; rts

.if _DEBUG || _CHECK_FRAME_DROP
; R4 = colour as 0x00BBGGRR
; Uses R0,R1 
palette_set_border:
    adrl r1, palette_osword_block
    mov r0, #24
    strb r0, [r1, #0]       ; logical colour
    strb r0, [r1, #1]       ; mode
    strb r4, [r1, #2]       ; red
    mov r0, r4, lsr #8
    strb r0, [r1, #3]       ; green
    mov r0, r4, lsr #16
    strb r0, [r1, #4]       ; blue

    mov r9, pc
    orr r8, r9, #ProcMode_Svc
    teqp r8, #0 ; enter Svc mode
    mov r0, r0
    str lr, [sp, #-4]!  ; store lr_svc

    mov r0, #12
    swi OS_Word

    ldr lr, [sp], #4    ; restore lr_svc
    teqp r9, #0 ; reenter original mode
    mov r0, r0

    mov pc,lr
.endif

; R0 = [0-16] interpolation
; R2 = palette block ptr
palette_make_fade_to_black:
	str lr, [sp, #-4]!			; push lr on stack
    adr r1, palette_interp_block

    mov r3, #16
    .1:
    ldr r4, [r2], #4            ; rgbx

    mov r5, r4, lsr #4          ; rgbx / 16
    mul r6, r5, r0              ; r0 * rgbx / 16

    str r6, [r1], #4
    
    subs r3, r3, #1
    bne .1
	ldr pc, [sp], #4			; rts

; R2 = source palette block ptr
palette_init_fade:
    str r1, palette_speed
    str r1, palette_delay
    str r2, palette_source
    mov r0, #16
    str r0, palette_interp
    mov pc, lr

; TODO: Make this generic fade routine?
; Returns interp value in R0.
palette_update_fade_to_black:
   	str lr, [sp, #-4]!			; push lr on stack

    ldr r1, palette_delay
    subs r1, r1, #1
    strne r1, palette_delay
    ldrne pc, [sp], #4			; rts

    ldr r1, palette_speed
    str r1, palette_delay

    ldr r0, palette_interp
    cmp r0, #0
	ldreq pc, [sp], #4			; rts

    ldr r2, palette_source
    bl palette_make_fade_to_black

    adr r2, palette_interp_block
    bl palette_set_block

    ldr r0, palette_interp
    subs r0, r0, #1
    str r0, palette_interp
	ldr pc, [sp], #4			; rts

; Returns interp value in R0.
palette_update_fade_from_black:
   	str lr, [sp, #-4]!			; push lr on stack

    ldr r1, palette_delay
    subs r1, r1, #1
    strne r1, palette_delay
    ldrne pc, [sp], #4			; rts

    ldr r1, palette_speed
    str r1, palette_delay

    ldr r0, palette_interp
    cmp r0, #0
	ldreq pc, [sp], #4			; rts

    rsb r0, r0, #16             ; TODO: Only line different from palette_update_fade_to_black

    ldr r2, palette_source
    bl palette_make_fade_to_black

    adr r2, palette_interp_block
    bl palette_set_block

    ldr r0, palette_interp
    subs r0, r0, #1
    str r0, palette_interp
	ldr pc, [sp], #4			; rts

palette_source:
    .long 0

palette_interp:
    .long 0

palette_speed:
    .long 0

palette_delay:
    .long 0

.if 0
; R2 = palette block ptr
palette_make_greyscale:
	str lr, [sp, #-4]!			; push lr on stack
    adr r1, palette_interp_block

    mov r3, #16
    .1:
    ldr r4, [r2], #4            ; rgbx

    mov r5, r4, lsr #2          ; red * 0.25
    and r5, r5, #0xf0
    mov r6, r4, lsr #9          ; green * 0.5
    and r6, r6, #0xf0
    mov r7, r4, lsr #18         ; blue * 0.25
    and r7, r7, #0xf0
    
    add r0, r5, r6
    add r0, r0, r7
    orr r0, r0, r0, lsl #8
    orr r0, r0, r0, lsl #8

    str r0, [r1], #4
    
    subs r3, r3, #1
    bne .1
	ldr pc, [sp], #4			; rts

; R0 = [0-16] interpolation
; R2 = palette block ptr
palette_make_fade_to_white:
	str lr, [sp, #-4]!			; push lr on stack
    adr r1, palette_interp_block

    add r1, r1, #4              ; ignore 0
    add r2, r2, #4              ; ignore 0

    ldr r7, solid_white
    mov r3, #15
    .1:
    ldr r4, [r2], #4            ; rgbx

    sub r5, r7, r4              ; white - rgbx
    mov r5, r5, lsr #4          ; (white - rgbx) / 16
    mla r6, r5, r0, r4          ; rgbx + r0 * (white - rgbx) / 16

    str r6, [r1], #4
    
    subs r3, r3, #1
    bne .1
	ldr pc, [sp], #4			; rts

solid_white:
    .long 0x00f0f0f0
.endif

palette_interp_block:
    .skip 64

.p2align 2
palette_osword_block:
    .skip 8
    ; logical colour
    ; physical colour (16)
    ; red
    ; green
    ; blue
    ; (pad)
