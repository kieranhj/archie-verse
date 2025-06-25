; ============================================================================
; App standard code.
; Hack as necessary per prod.
; ============================================================================

.equ RasterSplitLine,           56+90			; 56 lines from vsync to screen start

; ============================================================================
; App debug code.
; ============================================================================

.if _DEBUG
app_init_debug:
    str lr, [sp, #-4]!

    bl debug_init

    ; DEBUG_REGISTER_VAR debug_rm_key
    DEBUG_REGISTER_VAR_EX debug_frame_rate, debug_plot_addr_as_dec4
    DEBUG_REGISTER_VAR_EX vsync_delta, debug_plot_addr_as_dec4
    DEBUG_REGISTER_VAR music_pos
    DEBUG_REGISTER_VAR frame_counter
    .if _DEMO_PART==_PART_DONUT
;    DEBUG_REGISTER_VAR scene3d_stats_quads_plotted
    .endif
;    DEBUG_REGISTER_VAR music_pos
    DEBUG_REGISTER_VAR_EX debug_free_ram, debug_plot_addr_as_dec4
    .if _DEMO_PART==_PART_SPACE
;    DEBUG_REGISTER_VAR_EX uv_table_code_size, debug_plot_addr_as_dec4
    .endif

    DEBUG_REGISTER_KEY          RMKey_Space,      debug_toggle_main_loop_pause,  0
    DEBUG_REGISTER_KEY_WITH_VAR RMKey_A,          debug_set_byte_true,           debug_restart_flag
    DEBUG_REGISTER_KEY_WITH_VAR RMKey_S,          debug_set_byte_true,           debug_main_loop_step
    DEBUG_REGISTER_KEY_WITH_VAR RMKey_D,          debug_toggle_byte,             debug_show_info
    DEBUG_REGISTER_KEY_WITH_VAR RMKey_R,          debug_toggle_byte,             debug_show_rasters
    DEBUG_REGISTER_KEY          RMKey_ArrowRight, debug_skip_to_next_pattern,    0

;    DEBUG_REGISTER_VAR math_var_active_count
    ldr pc, [sp], #4
.endif

; ============================================================================
; App late initialisation for things that require access to the screen.
; ============================================================================

; R12=screen addr.
app_late_init:
    str lr, [sp, #-4]!

    ; Custom init for Donut.

    .if _DEMO_PART==_PART_DONUT
    ; Copy logo to static buffer.
    adr r0, app_logo_p
    ldmia r0, {r0-r3}
    mov r1, r3                  ; logical addr
    mov r2, r2, lsr #2          ; #words
    bl mem_copy_words

    mov r0, #1
    str r0, app_ready
    .endif

    ;ldr r10, init_screen_addr
    ;bl text_pool_init

    ldr pc, [sp], #4
; TODO: Make this more generic or include in sequence?

.if _DEMO_PART==_PART_DONUT
app_logo_p:
    .long three_logo_no_adr  ; src ptr
    .long 0                 ; offset
    .long 56*Screen_Stride  ; length
    .long MEMC_PhysRam - TotalScreenSize + 192*Screen_Stride ; logical 

app_logo_phys:
    .long 192*Screen_Stride >> 4                             ; physical

app_scroller_phys:
    .long 248*Screen_Stride >> 4                             ; physical

app_scroller_logical:
    .long MEMC_PhysRam - TotalScreenSize + 248*Screen_Stride ; logical 

app_ready:
    .long 0

tipsy_r14_irq:
    .long 0
.endif

; ============================================================================
; App main loop.
; ============================================================================

; Always called, regardless of tick status (add if needed).
;app_pre_tick_frame:
;    mov pc, lr

; ============================================================================
; Interrupt handling.
; ============================================================================

.if AppConfig_InstallIrqHandler
oldirqhandler:
	.long 0

oldirqjumper:
	.long 0

vsyncstartdelay:
	.long 127*RasterSplitLine  ;2000000/50.08

install_irq_handler:
	mov r1, #0x18					; IRQ vector.
	
	; Remember previous IRQ branch call.
	ldr r0, [r1]					; old IRQ handler.
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
; Code run at vsync.
; ============================================================================

app_vsync_code:

.if AppConfig_UseRasterMan
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

.if !AppConfig_UseRasterMan || _DEMO_PART==_PART_DONUT
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

.if !AppConfig_UseRasterMan
.3:
    b exitVs
.else
.3:
    ; Correct exit for RasterMan vsync callback.
	LDMIA sp!, {r0-r1,r11-r12,lr}
    SUBS PC,R14,#4
.endif

; ============================================================================
; App modules.
; ============================================================================

.include "src/app_audio.asm"
.include "src/app_video.asm"

; ============================================================================
; FX code modules.
; ============================================================================

.if _DEMO_PART==_PART_TEST
.include "src/fx/sine-scroller.asm"
.endif

.if _DEMO_PART==_PART_DONUT
    .include "src/fx/scene-3d.asm"
    .if AppConfig_UseRasterMan
    .include "src/rasters-donut.asm"
    .endif
.else
    .if AppConfig_UseRasterMan
    .include "src/rasters.asm"
    .endif
.endif
 
.if  _DEMO_PART==_PART_DONUT
.include "src/fx/tipsy-scroller.asm"
.endif

.if _DEMO_PART==_PART_SPACE
.include "src/fx/rotate.asm"
.include "src/fx/uv-table.asm"
.include "src/fx/lut-scroller.asm"
.endif

; ============================================================================
; Additional library code modules used by the FX sequence.
; ============================================================================

.include "lib/screen.asm"
.if _DEMO_PART==_PART_DONUT
.include "lib/mesh.asm"
.endif
.if _DEMO_PART==_PART_SPACE
.include "lib/lz4-decode.asm"
.endif

; ============================================================================
; ArchieKlang generated code.
; ============================================================================

.if AppConfig_UseArchieKlang
.include "lib/archieklang.asm"
.endif
