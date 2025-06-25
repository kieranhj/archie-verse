; ============================================================================
; App VSYNC code.
; Hack as necessary per prod?
; ============================================================================

.equ AppVsync_UseEvents,        AppConfig_VsyncHandler==AppVsyncHandler_Events
.equ AppVsync_UseIrq,           AppConfig_VsyncHandler==AppVsyncHandler_Irq
.equ AppVsync_UseRasterMan,     AppConfig_VsyncHandler==AppVsyncHandler_RasterMan
.equ AppVsync_KeyEvents,        !AppVsync_UseRasterMan

.equ AppVsync_IrqRasterLine,    56+90			; 56 lines from vsync to screen start

; ============================================================================

app_vsync_init:
    str lr, [sp, #-4]!

    .if AppVsync_KeyEvents
	; Claim the Event vector.
	MOV r0, #EventV
	ADR r1, event_handler
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
	bl install_irq_handler
    .endif

    .if AppVsync_UseRasterMan
   	; Required to make QTM play nicely with RasterMan.
	mov r0, #4
	mov r1, #-1
	mov r2, #-1
	QTMSWI QTM_SoundControl
    .endif

    ldr pc, [sp], #4

app_vsync_late_init:
    .if AppVsync_UseRasterMan
    ; TODO: Sort out the screen mode / QTM / RasterMan init timing.
    ; From Steve: QTM's DMA routine needs to be enabled for a few VSyncs after the final mode 
    ;             change before RM starts - hence need for QTM_SoundControl.
    ; TODO: Does this mean QTM_Start has to run for a few frames?

    adr r0, app_vsync_code
    swi RasterMan_Callback
    swi RasterMan_Wait
    swi RasterMan_Wait

	; Fire up the RasterMan!
	swi RasterMan_Install
    .endif
    mov pc, lr

app_vsync_exit:
    str lr, [sp, #-4]!

    .if AppVsync_UseIrq
	bl uninstall_irq_handler
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
	ADR r1, event_handler
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
event_handler:
    .if _DEBUG
	cmp r0, #Event_KeyPressed
	; R1=0 key up or 1 key down
	; R2=internal key number (RMKey_*)
    beq debug_handle_keypress
    .endif

    .if AppVsync_UseEvents
	cmp r0, #Event_VSync
	bne event_handler_return

	STMDB sp!, {r0-r1,r11-r12,lr}
    b app_vsync_code
exitVs:
	LDMIA sp!, {r0-r1,r11-r12,lr}
    .endif

event_handler_return:
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

install_irq_handler:
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
	adr r0, irq_handler
	sub r0, r0, #32
	mov r0, r0, lsr #2
	add r0, r0, #0xea000000			; B irq_handler.
	str r0, [r1]
	swi OS_IntOn

	mov pc, lr

uninstall_irq_handler:
	mov r1, #0x18					; IRQ vector.
	
	; Restore previous IRQ branch call.
	ldr r0, oldirqjumper
	str r0, [r1]

	mov pc, lr

irq_handler:
	STMFD   R13!,{R0-R1,R11-R12}
	MOV     R12,#0x3200000           ;IOC address
	LDRB    R0,[R12,#0x14+0]
	TST     R0,#1<<6 | (1<<3)
	BEQ     nottimer1orVs           ;not T1 or Vs, back to RISCOS

	TEQP    PC,#0b11<<26 | 0b11
	MOV     R0,R0

	MOV     R11,#VIDC_Write
	TST     R0,#1<<3
	BNE     handle_vsync                   ;...Vs higher priority than T1

timer1:
	mov r0, #0
	str r0, vsync_bodge

	; WRITE VIDC REGS HERE!

	LDRB    R0,[R12,#0x18]
	BIC     R0,R0,#1<<6
	STRB    R0,[R12,#0x18]           ;stop T1 irq...

exittimer1:
	TEQP    PC,#0b10<<26 | 0b10
	MOV     R0,R0
	LDMFD   R13!,{R0-R1,R11-R12}
	SUBS    PC,R14,#4

handle_vsync:
	ldr r0, vsync_bodge
	cmp r0, #0
	beq .3
	b exitVs
.3:
	mov r0, #1
	str r0, vsync_bodge

	STRB    R0,[R12,#0x58]           ;T1 GO (latch already set up)
	LDRB    R0,[R12,#0x18]
	ORR     R0,R0,#1<<6
	STRB    R0,[R12,#0x18]           ;enable T1 irq...
	MOV     R0,#1<<6
	STRB    R0,[R12,#0x14]           ;clear any pending T1 irq

    b app_vsync_code

exitVs:
	TEQP    PC,#0b10<<26 | 0b10
	MOV     R0,R0

nottimer1orVs:
	LDMFD   R13!,{R0-R1,R11-R12}
	ldr pc, oldirqhandler

vsync_bodge:
	.long 0
.endif

; ============================================================================
; RasterMan handling.
; ============================================================================

.if _DEBUG
app_vsync_scankeys:
    .if AppVsync_UseRasterMan
    swi RasterMan_ScanKeyboard
    str r0, debug_rm_key        ; R0=(low key nibble << 8) | (high key nibble)
    mov r1, r0, lsr #12         ; 0xc=key down 0xd=key up
    and r1, r1, #1
    eor r1, r1, #1              ; 1=key down 0=key up
    mov r2, r0, lsr #8
    and r2, r2, #0xf
    and r0, r0, #0xf
    orrs r2, r2, r0, lsl #4     ; combine nibbles back into RMKey_* value
    b debug_handle_keypress
    .else
    mov pc, lr
    .endif
.endif

app_vsync_checkescape:
    .if AppVsync_UseRasterMan
	swi RasterMan_ScanKeyboard
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
; ============================================================================

app_vsync_code:

.if AppVsync_UseRasterMan
	STMDB sp!, {r0-r1,r11-r12,lr}
.endif

	; Update the vsync counter.
	ldr r0, vsync_count
	add r0, r0, #1
	str r0, vsync_count

	; Pending bank will now be displayed.
	ldr r1, pending_bank
	cmp r1, #0
	.if _CHECK_FRAME_DROP
	streq r0, last_dropped_frame
	.endif
	beq .2

    ; Set MEMC Vinit here if we're managing screen buffers manually.
    .if AppConfig_UseMemcBanks && _DEMO_PART!=_PART_DONUT
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

    ; NB. May want to set palette for pending bank or every vsync.
    ; TODO: Sort out all this crap of conditionally assembled code.
    .if _DEMO_PART==_PART_DONUT
    .2:     ; always set palette for donut.
    .endif

.if !AppVsync_UseRasterMan || _DEMO_PART==_PART_DONUT
    mov r11, pc                     ; Save processor mode.
    orr r12, r11, #ProcMode_Svc
    teqp r12, #0                    ; Set Supervisor mode.
    mov r0, r0
    str r11, [sp, #-4]!

    .if _DEMO_PART==_PART_DONUT
    ; Custom screen split code for donut.

    ; Set Vinit to const logo addr.
    ldr r11, app_logo_phys
    mov r0, r11, lsl #2
    orr r0, r0, #MEMC_Vinit
    str r0, [r0]

    ; Set Vend to end of logo.
    ldr r0, app_scroller_phys
    sub r0, r0, #1
    mov r0, r0, lsl #2
    orr r0, r0, #MEMC_Vend
    str r0, [r0]

    ; Set Vstart to start of screen buffer.
    adr r12, screen_addr_phys
    ldr r1, displayed_bank
    ldr r0, [r12, r1, lsl #2]       ; physical RAM address of pending bank
    add r1, r0, r11                 ; size of donut area for future Vend

    mov r0, r0, lsl #2
    orr r0, r0, #MEMC_Vinit
    orr r0, r0, #MEMC_Vstart^MEMC_Vinit
    str r0, [r0]

    ; Inside donut space (line 128) set Vend to end of screen buffer.
    sub r0, r1, #1
    mov r0, r0, lsl #2
    orr r0, r0, #MEMC_Vend

    ldr r12, raster_table_memc_p
    str r0, [r12, #128*8]           ; line 128
    .endif

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

    teqp r11, #0                    ; Restore previous processor mode.
    mov r0, r0
.endif

    .if _DEMO_PART!=_PART_DONUT
    .2:     ; only set palette for a new frame otherwise.
    .endif

    .if  _DEMO_PART==_PART_DONUT
    ; Do scrolltext?!
    ldr r0, app_ready
    cmp r0, #0
    beq .4

    ; Switch to SVC mode with IRQs enabled.
    str r14, tipsy_r14_irq
	TEQP PC,#FIQ_Disable | ProcMode_Svc
    mov r0, r0

    stmfd sp!, {r0-r12,lr}
    bl tipsy_scroller_tick
    ; Write scroller to static buffer.
    ldr r12, app_scroller_logical
    bl tipsy_scroller_draw_fast
    ldmfd sp!, {r0-r12,lr}

	TEQP PC,#IRQ_Disable | FIQ_Disable | ProcMode_IRQ
    mov r0, r0
    ldr r14, tipsy_r14_irq
    .4:
    .endif

.if !AppVsync_UseRasterMan
.3:
    b exitVs
.else
.3:
    ; Correct exit for RasterMan vsync callback.
	LDMIA sp!, {r0-r1,r11-r12,lr}
    SUBS PC,R14,#4
.endif
