; ============================================================================
; FX handler.
; Calls tick functions in order with R0=frame counter, R1=vsync delta.
; Calls draw functions in order with R12=screen base address.
; ============================================================================

.equ Fx_MaxLayers, 4

fx_tick_callbacks:
.skip 4*Fx_MaxLayers

fx_draw_callbacks:
.skip 4*Fx_MaxLayers

; TODO: Might need fx_init_layers for sequence restart?

; Call all tick functions in order.
fx_tick_layers:
    str lr, [sp, #-4]!

    mov r9, #0
.1:
    adr r10, fx_tick_callbacks
    ldr r11, [r10, r9, lsl #2]
    cmp r11, #0
    beq .3

	.if _DEBUG_RASTERS
	ldrb r0, debug_show_rasters
	cmp r0, #0
    beq .10
    mov r4, #0                  ; rgb
    add r8, r9, #1
    tst r8, #1
    orrne r4, r4, #0x8
    tst r8, #2
    orrne r4, r4, #0x80
    tst r8, #4
    orrne r4, r4, #0x800
    IRQ_MODE_SET_BORDER_R4           ;bl palette_set_border
    .10:
	.endif

    ; Call tick fn.
    ldr r0, frame_counter
    ldr r1, vsync_delta
    str r9, [sp, #-4]!
    adr lr, .2
    mov pc, r11
    .2:
    ldr r9, [sp], #4

    .3:
    add r9, r9, #1
    cmp r9, #Fx_MaxLayers
    blt .1

	IRQ_MODE_SET_BORDER 0x000

    ldr pc, [sp], #4

; Call all draw functions in order.
fx_draw_layers:
    str lr, [sp, #-4]!

    mov r9, #0
.1:
    adr r10, fx_draw_callbacks
    ldr r11, [r10, r9, lsl #2]
    cmp r11, #0
    beq .3

    str r9, [sp, #-4]!

	.if _DEBUG_RASTERS
	ldrb r0, debug_show_rasters
	cmp r0, #0
    beq .10
    mov r4, #0                  ; rgb
    add r8, r9, #1
    tst r8, #1
    orrne r4, r4, #0xf
    tst r8, #2
    orrne r4, r4, #0xf0
    tst r8, #4
    orrne r4, r4, #0xf00
    IRQ_MODE_SET_BORDER_R4           ;bl palette_set_border
    .10:
	.endif

    ; Call draw fn.
    ldr r12, screen_addr
    adr lr, .2
    mov pc, r11
    .2:
    ldr r9, [sp], #4

    .3:
    add r9, r9, #1
    cmp r9, #Fx_MaxLayers
    blt .1

	IRQ_MODE_SET_BORDER 0x000

    ldr pc, [sp], #4

; R0=layer no.
; Trashes: R1-R3
fx_clear_layer:
    mov r1, #0
    mov r2, #0
    ; FALL THROUGH!

; R0=layer no.
; R1=tick fn.
; R2=draw fn.
; Trashes: R3
fx_set_layer_fns:
    adr r3, fx_tick_callbacks
    str r1, [r3, r0, lsl #2]
    adr r3, fx_draw_callbacks
    str r2, [r3, r0, lsl #2]
    mov pc, lr
