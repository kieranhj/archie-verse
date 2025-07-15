; ============================================================================
; App Events.
; ============================================================================

acid_palettes_p:
    .long acid_palettes_table_no_adr

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
