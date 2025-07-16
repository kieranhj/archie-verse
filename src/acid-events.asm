; ============================================================================
; App Events.
; ============================================================================

acid_palettes_p:
    .long acid_palettes_table_no_adr

acid_lights_p:
    .long acid_lights_table_no_adr

; R0=event data.
; R1=event code.
acid_event_set_palette:
    cmp r0, #AcidPalettes_MAX

    .if Events_Strict
    adrge r0, errevent_paletteoutofrange
    swige OS_GenerateError
    .else
    movge pc, lr
    .endif

    ldr r1, acid_palettes_p
    ldr r1, [r1, r0, lsl #2]
    str r1, palette_array_p
    mov pc, lr

.if _DEBUG
errevent_paletteoutofrange:
    .long 0
	.byte "Palette index out of range."
	.align 4
	.long 0
.endif

; R0=event data.
; R1=event code.
acid_event_set_scale:
    ; Sign extend R0 byte.
    mov r0, r0, asl #24
    mov r0, r0, asr #8
    sub r0, r0, #MATHS_CONST_HALF
    mov r0, r0, asr #1

    ldr r11, scene3d_entity_p
    str r0, [r11, #Entity_Scale]
    mov pc, lr

; Tick fn.
acid_events_entity_tick:

    ; Converge entity scale back to 1.0.
    ldr r11, scene3d_entity_p
    ldr r0, [r11, #Entity_Scale]
    mov r1, #MATHS_CONST_1
    sub r2, r1, r0              ; 1.0 - scale
    ; Some fraction of that.
    mov r2, r2, asr #3          ; 1/4?
    add r0, r0, r2
    str r0, [r11, #Entity_Scale]
    mov pc, lr

; R0=event data.
; R1=event code.
acid_event_set_lightdir:
    cmp r0, #AcidLights_MAX

    .if Events_Strict
    adrge r0, errevent_lightsoutofrange
    swige OS_GenerateError
    .else
    movge pc, lr
    .endif

    ldr r1, acid_lights_p
    add r1, r1, r0, lsl #3  ; i*8
    add r1, r1, r0, lsl #2  ; +i*4 = i*12

    adr r0, light_direction
    ldmia r1, {r2-r4}
    stmia r0, {r2-r4}

    mov pc, lr

.if _DEBUG
errevent_lightsoutofrange:
    .long 0
	.byte "Light dir index out of range."
	.align 4
	.long 0
.endif
