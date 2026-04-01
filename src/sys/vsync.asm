; ============================================================================
; App VSYNC code.
; Ideally don't want this file hackable.
; Rename to main_vsync or something?
; ============================================================================

.equ AppVsync_UseEvents,        AppConfig_VsyncHandler==AppVsyncHandler_Events
.equ AppVsync_UseIrq,           AppConfig_VsyncHandler==AppVsyncHandler_Irq
.equ AppVsync_UseRasterMan,     AppConfig_UsingRasterMan
.equ AppVsync_KeyEvents,        !AppVsync_UseRasterMan

; ============================================================================

vsync_init:
    str lr, [sp, #-4]!

    .if AppVsync_KeyEvents
	; Claim the Event vector.
	MOV r0, #EventV
	ADR r1, eventv_handler
	MOV r2, #0
	SWI OS_Claim

	; Enable key pressed event.
	mov r0, #OSByte_EventEnable
	mov r1, #Event_KeyPressed
	SWI OS_Byte
    .endif

    .if AppVsync_UseEvents
    ; Enable vsync event.
	mov r0, #OSByte_EventEnable
	mov r1, #Event_VSync
	SWI OS_Byte
    .endif

    .if AppVsync_UseIrq
	; Install our own IRQ handler - thanks Steve! :)
	bl vsync_install_irq_handler
    .endif

    .if AppVsync_UseRasterMan
   	; Required to make QTM play nicely with RasterMan.
	mov r0, #4
	mov r1, #-1
	mov r2, #-1
	QTMSWI QTM_SoundControl
    .endif

    ldr pc, [sp], #4

vsync_late_init:
    .if AppVsync_UseRasterMan
    ; Note from Steve: QTM's DMA routine needs to be enabled for a few VSyncs after the final mode 
    ;                  change before RM starts - hence need for QTM_SoundControl.

    adr r0, vsync_do_callback
    swi RasterMan_Callback
    swi RasterMan_Wait
    swi RasterMan_Wait

	; Fire up the RasterMan!
	swi RasterMan_Install
    .endif
    mov pc, lr

; NB. This may be entered in Supervisor mode if an error is raised.
vsync_exit:
    str lr, [sp, #-4]!

    .if AppVsync_UseIrq
	bl vsync_uninstall_irq_handler
    .endif

	; Release event handler.

    .if AppVsync_UseEvents
	mov r0, #OSByte_EventDisable
	mov r1, #Event_VSync
	SWI OS_Byte
    .endif

    .if AppVsync_KeyEvents
	MOV r0, #OSByte_EventDisable
	MOV r1, #Event_KeyPressed
	SWI OS_Byte

	MOV r0, #EventV
	ADR r1, eventv_handler
	mov r2, #0
	SWI OS_Release
    .endif

    .if AppVsync_UseRasterMan
	swi RasterMan_Wait
  	swi RasterMan_Release
	swi RasterMan_Wait
	swi RasterMan_Wait
    .endif

    ldr pc, [sp], #4

; ============================================================================
; Event handler.
; ============================================================================

.if AppVsync_KeyEvents
; R0=event number
eventv_handler:
    .if AppConfig_UseKeys
	cmp r0, #Event_KeyPressed
	; R1=0 key up or 1 key down
	; R2=internal key number (RMKey_*)
    beq keys_handle_keypress
    .endif

    .if AppVsync_UseEvents
	cmp r0, #Event_VSync
	bne eventv_handler_return

    b vsync_do_callback
vsync_do_callback_return:
    .endif

eventv_handler_return:
	mov pc, lr
.endif

; ============================================================================
; IRQ handling.
; ============================================================================

.if AppVsync_UseIrq
oldirqhandler:
	.long 0

oldirqjumper:
	.long 0

vsyncstartdelay:
	.long 127*AppVsync_IrqRasterLine    ;2000000/50.08

vsync_install_irq_handler:
	mov r1, #0x18					    ; IRQ vector.
	
	; Remember previous IRQ branch call.
	ldr r0, [r1]					    ; old IRQ handler.
	str r0, oldirqjumper

	; Calculate old IRQ handler address from branch opcode.
	bic r0, r0, #0xff000000
	mov r0, r0, lsl #2
	add r0, r0, #32
	str r0, oldirqhandler

	; Set Timer 1.
	SWI		OS_EnterOS
	MOV     R12,#0x3200000           ;IOC address

	TEQP    PC,#0b11<<26 | 0b11  ;jam all interrupts!

	LDR     R0,vsyncstartdelay
	STRB    R0,[R12,#0x50]
	MOV     R0,R0,LSR#8
	STRB    R0,[R12,#0x54]           ;prepare timer 1 for waiting until screen start
									;don't start timer1, done on next Vs...
	TEQP    PC,#0
	MOV     R0,R0

	; Install our IRQ handler.
	swi OS_IntOff
	adr r0, vsync_irq_handler
	sub r0, r0, #32
	mov r0, r0, lsr #2
	add r0, r0, #0xea000000			; B vsync_irq_handler.
	str r0, [r1]
	swi OS_IntOn

	mov pc, lr

vsync_uninstall_irq_handler:
	mov r1, #0x18					; IRQ vector.
	
	; Restore previous IRQ branch call.
	ldr r0, oldirqjumper
	str r0, [r1]

	mov pc, lr

; Enters in ProcMode_IRQ
vsync_irq_handler:
	STMFD   R13!,{R0,R12}
	MOV     R12,#0x3200000          ;IOC address
	LDRB    R0,[R12,#0x14+0]
	TST     R0,#1<<6 | (1<<3)
	BEQ     vsync_irq_return_to_riscos           ;not T1 or Vs, back to RISCOS

	TEQP    PC,#0b11<<26 | 0b11     ; disable IRQ|disable FIQ|ProcMode_Svc
	MOV     R0,R0

	TST     R0,#1<<3
	BNE     vsync_irq_handle_vsync  ;...Vs higher priority than T1

    ; Handle Timer1.

	mov r0, #0
	str r0, vsync_lock_flag

	LDRB    R0,[R12,#0x18]
	BIC     R0,R0,#1<<6
	STRB    R0,[R12,#0x18]           ;stop T1 irq... (assume restarted in vsync)

	; WRITE VIDC REGS HERE!
	; MOV     R11,#VIDC_Write
    ; TODO: Timer1 Callback.
    ; Still in Svc mode!
    ; Still have R0,R12 on stack.
    ; bl app_timer1_callback

    ; Exit Timer1.
	LDMFD   R13!,{R0,R12}
	TEQP    PC,#0b10<<26 | 0b10     ; disable IRQ|enable FIQ|ProcMode_IRQ
	MOV     R0,R0
	SUBS    PC,R14,#4

; Entering in ProcMode_Svc with IRQ and FIQ disabled
vsync_irq_handle_vsync:
	ldr r0, vsync_lock_flag
	cmp r0, #0
	bne vsync_irq_no_reenter

    ; Stop this re-entering.
	mov r0, #1
	str r0, vsync_lock_flag

    ; Setup Timer1 again.
	STRB    R0,[R12,#0x58]           ;T1 GO (latch already set up)
	LDRB    R0,[R12,#0x18]
	ORR     R0,R0,#1<<6
	STRB    R0,[R12,#0x18]           ;enable T1 irq...
	MOV     R0,#1<<6
	STRB    R0,[R12,#0x14]           ;clear any pending T1 irq

    ; Call app vsync code.
	LDMFD   R13!,{R0,R12}

	TEQP    PC,#0b10<<26 | 0b10     ; disable IRQ|enable FIQ|ProcMode_IRQ
	MOV     R0,R0

    b vsync_do_callback

vsync_do_callback_return:
	ldr pc, oldirqhandler

vsync_irq_no_reenter:
	TEQP    PC,#0b10<<26 | 0b10     ; disable IRQ|enable FIQ|ProcMode_IRQ
	MOV     R0,R0

vsync_irq_return_to_riscos:
	LDMFD   R13!,{R0,R12}
	ldr pc, oldirqhandler

vsync_lock_flag:
	.long 0
.endif

; ============================================================================
; Keyboard handling (because RasterMan does this manually).
; ============================================================================

.if AppConfig_UseKeys
vsync_scankeyboard:
    .if AppVsync_UseRasterMan
    ldr r0, keys_rm_code        ; R0=(low key nibble << 8) | (high key nibble)
    mov r2, r0, lsr #12         ; 0xc=key down 0xd=key up
	cmp r2, #0xc
	moveq r1, #1
	beq .1

	cmp r2, #0xd	
	moveq r1, #0
	movne pc, lr

.1:
    mov r2, r0, lsr #8
    and r2, r2, #0xf
    and r0, r0, #0xf
    orrs r2, r2, r0, lsl #4     ; combine nibbles back into RMKey_* value
    b keys_handle_keypress
    .else
    mov pc, lr
    .endif
.endif

vsync_check_escape:
    .if AppVsync_UseRasterMan
	ldr r0, keys_rm_code
	mov r1, #0xc0c0             ; down and keycode 0x00
	cmp r0, r1
    moveq r0, #1
    movne r0, #0
    movs r0, r0, lsr #1
    .else
	swi OS_ReadEscapeState
    .endif
    mov pc, lr

; ============================================================================
; Code run at vsync.
; Can be entered three ways!
; - From the Event handler.
; - From the IRQ handler.
; - From RasterMan vsync callback.
; Always entered in IRQ processor mode? <== CHECK THIS FOR IRQ CASE.
; Must preserve all registers as necessary.
; ============================================================================

vsync_do_callback:
	stmfd sp!, {r0-r1,r11-r12,lr}

	; Update the vsync counter.
	ldr r0, vsync_count
	add r0, r0, #1
	str r0, vsync_count

	.if AppVsync_UseRasterMan
	; Keyboard scan.
    swi RasterMan_ScanKeyboard
    str r0, keys_rm_code        ; R0=(low key nibble << 8) | (high key nibble)
	.endif

    ; Call the app's vsync callback.
    bl app_vsync_callback

	LDMIA sp!, {r0-r1,r11-r12,lr}

.if AppVsync_UseRasterMan
    ; Correct exit for RasterMan vsync callback.
    SUBS PC,R14,#4
.else
    b vsync_do_callback_return
.endif
