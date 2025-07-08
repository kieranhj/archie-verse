; ============================================================================
; App video module.
; Ideally don't want this file hackable.
; ============================================================================

screen_addr:
	.long 0			    ; ptr to the current VIDC screen bank being written to.

; TODO: Make these bytes?
displayed_bank:
	.long 0				; VIDC sreen bank being displayed

write_bank:
	.long 0				; VIDC screen bank being written to

pending_bank:
	.long 0				; VIDC screen to be displayed next

palette_array_p:
    .long 0             ; pointer to the palette array for this frame.

vidc_buffers_p:
    .long vidc_buffers_no_adr - 64

screen_addr_input:
	.long VD_ScreenStart, -1

; ============================================================================
; App video code.
; ============================================================================

; R12=top of RAM used.
video_init:
    str lr, [sp, #-4]!

	; Set screen MODE & disable cursor
    swi OS_WriteI+22
    swi OS_WriteI+VideoConfig_VduMode
    swi OS_RemoveCursors

    ; Blank our palette for MODE switch glitch? 
    ; TODO: Check whether the one-frame default palette glitch comes back
    ;       Might need to tell RISCOS about the palette in the first N vsyncs after MODE cange.
    ; TODO: Clear screen RAM first before MODE change...

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
    bl video_get_screen_addr

    ; No flashing colours (FFS).
    mov r0, #9
    mov r1, #0
    swi OS_Byte

.if AppConfig_UseQtmEmbedded
    mov lr, pc
    ldr pc, QtmEmbedded_Init
.endif

    ldr pc, [sp], #4

error_noscreenmem:
	.long 0
	.byte "Cannot allocate screen memory!"
	.p2align 2
	.long 0

; ============================================================================

; NB. This may be entered in Supervisor mode if an error is raised.
video_exit:
    str lr, [sp, #-4]!

	; Display whichever bank we've just written to
	mov r0, #OSByte_WriteDisplayBank
	ldr r1, write_bank
	swi OS_Byte

	; and write to it
	mov r0, #OSByte_WriteVduBank
	ldr r1, write_bank
	swi OS_Byte

    ldr pc, [sp], #4

; ============================================================================

; TODO: Rename these.
video_mark_screen_as_pending_display:
	; Mark write bank as pending display.
	ldr r1, write_bank

	; What happens if there is already a pending bank?
	; At the moment we block but could also overwrite
	; the pending buffer with the newer one to catch up.
	; TODO: A proper fifo queue for display buffers.
.1:
	ldr r0, pending_bank
	cmp r0, #0
	bne .1
	str r1, pending_bank

    ; If there is a new palette for this frame then stash it ready
    ; for sending to the VIDC on the next vsync.

    ldr r2, vidc_buffers_p
    add r2, r2, r1, lsl #6              ; 64 bytes per bank

    ldr r3, palette_array_p
    cmp r3, #0
    moveq r0, #-1                       ; no palette to set.
    streq r0, [r2]
    beq .2

    ; TODO: Could think about a palette dirty flag? Although overhead lower now.

    ; Copy 16 words of VIDC register data.
    ldmia r3!, {r4-r11}
    stmia r2!, {r4-r11}
    ldmia r3!, {r4-r11}
    stmia r2!, {r4-r11}

.2:
	; Show pending bank at next vsync.
    .if !AppConfig_UseMemcBanks
	MOV r0, #OSByte_WriteDisplayBank
	swi OS_Byte
    .endif
;	mov pc, lr
; FALL THROUGH!

video_get_next_screen:
	; Increment to next bank for writing
	ldr r1, write_bank
	add r1, r1, #1
	cmp r1, #VideoConfig_ScreenBanks
	movgt r1, #1

	; Block here if trying to write to displayed bank.
    .if VideoConfig_ScreenBanks > 1
	.1:
	ldr r0, displayed_bank
	cmp r1, r0
	beq .1
    .endif

	str r1, write_bank

	; Now set the screen bank to write to
.if !AppConfig_UseMemcBanks
	mov r0, #OSByte_WriteVduBank
	swi OS_Byte
.endif
; FALL THROUGH!

video_get_screen_addr:
.if AppConfig_UseMemcBanks
    adr r0, screen_addr_logical
    ldr r1, write_bank
    ldr r0, [r0, r1, lsl #2]
    str r0, screen_addr
.else
	; Back buffer address for writing bank stored at screen_addr
	adrl r0, screen_addr_input
	adrl r1, screen_addr
	swi OS_ReadVduVariables
.endif
    mov pc, lr

.if AppConfig_UseMemcBanks
screen_addr_logical:
    .long 0
    .set BankNo, 0
    .rept VideoConfig_ScreenBanks
    .long MEMC_PhysRam - TotalScreenSize + Screen_Bytes * BankNo
    .set BankNo, BankNo+1
    .endr

screen_addr_phys:
    .long 0
    .set BankNo, 0
    .rept VideoConfig_ScreenBanks
    .long BankNo*Screen_Bytes >> 4
    .set BankNo, BankNo+1
    .endr
.endif

; ============================================================================

; Entered in IRQ mode.
; OK to use R0,R1,R11,R12 which are stashed on the stack.
; Enters with R0=vsync_count
video_display_pending_bank:
	; Pending bank will now be displayed.
	ldr r1, pending_bank
	cmp r1, #0
	beq .2

    ; Set MEMC Vinit here if we're managing screen buffers manually.
    .if AppConfig_UseMemcBanks
    adr r12, screen_addr_phys
    ldr r0, [r12, r1, lsl #2]       ; physical RAM address of pending bank
    mov r0, r0, lsl #2
    orr r0, r0, #MEMC_Vinit

    mov r11, pc                     ; Save processor mode.
    orr r12, r11, #ProcMode_Svc
    teqp r12, #0                    ; Set Supervisor mode.
    mov r0, r0
    str r0, [r0]                    ; Set MEMC register Vinit

    teqp r11, #0                    ; Restore previous processor mode.
    mov r0, r0
    .endif

    str r1, displayed_bank

	; Clear pending bank.
	mov r0, #0
	str r0, pending_bank

    ; Done pending bank.
.2:
    mov pc, lr


; Entered in IRQ mode.
; OK to use R0,R1,R11,R12 which are stashed on the stack.
video_set_display_bank_palette:
    mov r11, pc                     ; Save processor mode.
    orr r12, r11, #ProcMode_Svc
    teqp r12, #0                    ; Set Supervisor mode.
    mov r0, r0

.if 0
    str r11, [sp, #-4]!

    ; Set palette for bank to be displayed.
	mov r11, #VIDC_Write
    ldr r12, vidc_buffers_p
    ldr r1, displayed_bank
    cmp r1, #0                      ; avoid idiocy but make this better.
    beq .11
    add r12, r12, r1, lsl #6        ; 64 bytes per bank.
    mov r1, #16
.1:
    ldr r0, [r12], #4
    cmp r0, #-1
    beq .11
    str r0, [r11]                   ; VIDC_Write
    subs r1, r1, #1
    bne .1
.11:
    ldr r11, [sp], #4
.else
    stmfd sp!, {r2-r8}

    ldr r12, vidc_buffers_p
    ldr r1, displayed_bank
    cmp r1, #0                      ; avoid idiocy but make this better.
    beq .11
    add r12, r12, r1, lsl #6        ; 64 bytes per bank.

    ldmia r12!, {r0-r7}
    cmp r0, #-1
    beq .11

    ; Blat 16 palette regs to VIDC.
    mov r8, #VIDC_Write

    str r0, [r8]                    ; VIDC_Write
    str r1, [r8]                    ; VIDC_Write
    str r2, [r8]                    ; VIDC_Write
    str r3, [r8]                    ; VIDC_Write
    str r4, [r8]                    ; VIDC_Write
    str r5, [r8]                    ; VIDC_Write
    str r6, [r8]                    ; VIDC_Write
    str r7, [r8]                    ; VIDC_Write

    ldmia r12!, {r0-r7}

    str r0, [r8]                    ; VIDC_Write
    str r1, [r8]                    ; VIDC_Write
    str r2, [r8]                    ; VIDC_Write
    str r3, [r8]                    ; VIDC_Write
    str r4, [r8]                    ; VIDC_Write
    str r5, [r8]                    ; VIDC_Write
    str r6, [r8]                    ; VIDC_Write
    str r7, [r8]                    ; VIDC_Write

.11:
    ldmfd sp!, {r2-r8}
.endif

    teqp r11, #0                    ; Restore previous processor mode.
    mov r0, r0
    mov pc, lr

; ============================================================================
