; ============================================================================
; App standard code.
; Hack as necessary per prod.
; Want this file to be hackable.
; ============================================================================

.equ AppVsync_IrqRasterLine,    56+90			; 56 lines from vsync to screen start

; ============================================================================
; App specific variables and tables.
; ============================================================================

; ============================================================================
; App debug code.
; ============================================================================

.if _DEBUG
app_init_debug:
    str lr, [sp, #-4]!

    bl debug_init

;    DEBUG_REGISTER_VAR_EX debug_frame_rate, debug_plot_addr_as_dec4
    DEBUG_REGISTER_VAR_EX vsync_delta, debug_plot_addr_as_dec4
    DEBUG_REGISTER_VAR music_pos
;    DEBUG_REGISTER_VAR frame_counter
;    DEBUG_REGISTER_VAR_EX debug_free_ram, debug_plot_addr_as_dec4

    DEBUG_REGISTER_KEY          RMKey_Space,      debug_toggle_main_loop_pause,  0
    DEBUG_REGISTER_KEY_WITH_VAR RMKey_A,          debug_set_byte_true,           debug_restart_flag
    DEBUG_REGISTER_KEY_WITH_VAR RMKey_S,          debug_set_byte_true,           debug_main_loop_step
    DEBUG_REGISTER_KEY_WITH_VAR RMKey_D,          debug_toggle_byte,             debug_show_info
    DEBUG_REGISTER_KEY_WITH_VAR RMKey_R,          debug_toggle_byte,             debug_show_rasters
; Not really safe to call this in event handler...
;    DEBUG_REGISTER_KEY          RMKey_ArrowRight, debug_skip_to_next_pattern,    0
    DEBUG_REGISTER_KEY_WITH_VAR RMKey_ArrowRight, debug_set_byte_three,          debug_restart_flag

; Doesn't work as we'll skip the tempo commands in pattern 0. :\
;    DEBUG_REGISTER_KEY_WITH_VAR RMKey_ArrowUp,    debug_set_byte_two,            debug_restart_flag

;    DEBUG_REGISTER_VAR math_var_active_count
    ldr pc, [sp], #4
.endif

; ============================================================================
; App late initialisation for things that require access to the screen.
; ============================================================================

; R12=screen addr.
app_late_init:
    str lr, [sp, #-4]!

    ldr r12, screen_addr

    ldr pc, [sp], #4

app_exit:
    mov pc, lr

; ============================================================================
; App main loop.
; ============================================================================

; Always called, regardless of tick status (add if needed).
;app_pre_tick_frame:
;    mov pc, lr

; Ditto.
;app_pre_draw_frame:
;    mov pc, lr

; ============================================================================
; App vsync callback.
; Do any app specific logic in here.
; Up to the app to call the screen bank swap and any palette logic.
; ============================================================================

; Entered in IRQ mode.
; Registers R0, R1, R11, R12 are stashed on the stack and free to use.
; They do not need to be restored before exiting.
app_vsync_callback:
    str lr, [sp, #-4]!

    bl video_display_pending_bank

    ; NB. Donut wants to set palette always.
    ; Normally only set palette when there's a new bank.
    ; Actually does it matter if we're ready from vidc_buffer[displayed_bank]?

    bl video_set_display_bank_palette

    .if 0
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

    ; Do scrolltext?!
    ldr r0, app_ready
    cmp r0, #0
    beq .4

    ; Switch to SVC mode with IRQs enabled.
    str r14, tipsy_r14_irq
	TEQP PC,#FIQ_Disable | ProcMode_Svc
    mov r0, r0

    stmfd sp!, {r2-r10,lr}
    bl tipsy_scroller_tick
    ; Write scroller to static buffer.
    ldr r12, app_scroller_logical
    bl tipsy_scroller_draw_fast
    ldmfd sp!, {r2-r10,lr}

    ; Back to IRQ mode
	TEQP PC,#IRQ_Disable | FIQ_Disable | ProcMode_IRQ
    mov r0, r0
    ldr r14, tipsy_r14_irq
    .4:
    .endif

    ldr pc, [sp], #4

; ============================================================================
; FX code modules.
; ============================================================================

.include "lib/screen.asm"
