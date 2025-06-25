; ============================================================================
; App video module.
; Hack as necessary per prod?
; ============================================================================

; ============================================================================
; App video code.
; ============================================================================

; R12=top of RAM used.
app_init_video:
    str lr, [sp, #-4]!

	; Set screen MODE & disable cursor
    swi OS_WriteI+22
    swi OS_WriteI+VideoConfig_VduMode
    swi OS_RemoveCursors

    ; Blank our palette for MODE switch glitch? 
    ldr r0, black_palette_p
    str r0, palette_array_p
    ; TODO: Check whether the one-frame default palette glitch comes back
    ;       Might need to tell RISCOS about the palette in the first N vsyncs after MODE cange.
    
    .if !AppConfig_ReturnMainToCaller   ; assume caller handles this for us.
	; Set screen size for number of buffers
	MOV r0, #DynArea_Screen
	SWI OS_ReadDynamicArea
	MOV r0, #DynArea_Screen
	MOV r2, #Mode_Bytes * VideoConfig_ScreenBanks
    ; NB. This gets rounded up to page size = Total RAM / 128
    ;     So 3x40K MODE 9 buffers = 128K not 120K!
	SUBS r1, r2, r1
	SWI OS_ChangeDynamicArea
	MOV r0, #DynArea_Screen
	SWI OS_ReadDynamicArea
	CMP r1, r2
	ADRCC r0, error_noscreenmem
	SWICC OS_GenerateError
    .endif

	; Clear all screen buffers
    ldr r10, vidc_buffers_p
	mov r1, #1
.1:
	str r1, write_bank

	; CLS bank N
	mov r0, #OSByte_WriteVduBank
	swi OS_Byte
	SWI OS_WriteI + 12		; cls

    ; Void VIDC buffer for bank N.
    mov r0, #-1
    str r0, [r10, r1, lsl #6]            ; 64 bytes per bank

	add r1, r1, #1
	cmp r1, #VideoConfig_ScreenBanks
	ble .1

    ; Display prev bank.
    subs r1, r1, #1
    movle r1, #VideoConfig_ScreenBanks
    mov r0, #OSByte_WriteDisplayBank
    swi OS_Byte
    str r1, displayed_bank

    ; Get address of the displayed bank.
    bl get_screen_addr
    ldr r0, screen_addr
    str r0, init_screen_addr

    ; No flashing colours (FFS).
    mov r0, #9
    mov r1, #0
    swi OS_Byte

.if AppConfig_UseQtmEmbedded
    mov lr, pc
    ldr pc, QtmEmbedded_Init
.endif

.if AppConfig_UseRasterMan
    bl rasters_init
.endif

    ldr pc, [sp], #4

; TODO: Junk this for non_DEBUG?
error_noscreenmem:
	.long 0
	.byte "Cannot allocate screen memory!"
	.p2align 2
	.long 0

black_palette_p:
    .long seq_palette_all_black

