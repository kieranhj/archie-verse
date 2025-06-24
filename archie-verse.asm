; ============================================================================
; Archie-Verse: a Acorn Archimedes demo/trackmo framework.
; ============================================================================

.equ _PART_DONUT,               0
.equ _PART_SPACE,               1
.equ _PART_TEST,                2

; ============================================================================
; Defines for a specific build.
; ============================================================================

.ifndef _WIMP_SLOT
.equ _WIMP_SLOT,                1250*1024
.endif

.ifndef _DEMO_PART
.equ _DEMO_PART,                _PART_SPACE       ; 0=donut, 1=tables, 2=test
.endif

.ifndef _DEBUG
.equ _DEBUG,                    1
.endif

.ifndef _SMALL_EXE
.equ _SMALL_EXE,                !_DEBUG
.endif

.equ _SLOW_CPU,                 1       ; ARM2 @ 8MHz. TODO: Set dynamically.
.equ _LOG_SAMPLES,              (_SMALL_EXE && 0)

.equ _DEBUG_RASTERS,            (_DEBUG && 1)
.equ _CHECK_FRAME_DROP,         (!_DEBUG && 0)  ; only works for 50Hz
.equ _SYNC_EDITOR,              (_DEBUG && 0)   ; sync driven by external editor.

.equ DebugDefault_PlayPause,    1		; play
.equ DebugDefault_ShowRasters,  0
.equ DebugDefault_ShowVars,     1		; slow

.equ Debug_TopOfWimpSlot,       0x8000 + _WIMP_SLOT

; ============================================================================
; Includes.
; ============================================================================

.include "src/app_config.h.asm"
.include "lib/swis.h.asm"
.include "lib/lib_config.h.asm"
.include "lib/maths.h.asm"
.include "lib/macros.h.asm"
.include "lib/debug.h.asm"
.include "lib/mesh.h.asm"
.include "lib/script.h.asm"
.include "lib/sequence.h.asm"
; TODO: Put all these into a single lib header?

; ============================================================================
; Code Start
; ============================================================================

.org 0x10000                    ; NB. Not 0x8000!

; ============================================================================
; Main
; ============================================================================

Start:
main:
    .if AppConfig_ReturnMainToCaller
    str lr, [sp, #-4]!
    str sp, callers_stack_p
    .endif
    ldr sp, stack_p

	; Claim the Error vector.
    .if _DEBUG
	MOV r0, #ErrorV
	ADR r1, error_handler
	MOV r2, #0
	SWI OS_Claim
    .endif

    .if !AppConfig_UseRasterMan
	; Claim the Event vector.
	MOV r0, #EventV
	ADR r1, event_handler
	MOV r2, #0
	SWI OS_Claim

	; Install our own IRQ handler - thanks Steve! :)
    .if AppConfig_InstallIrqHandler
	bl install_irq_handler
    .else
	mov r0, #OSByte_EventEnable
	mov r1, #Event_VSync
	SWI OS_Byte
    .endif
    .endif

    ; Generate sample data first?
    .if AppConfig_UseArchieKlang
    bl archieklang_init
    .endif

	; Library initialisation.
	bl lib_init
	; Returns R12=top of RAM used.

    ; Allocate and clear screen buffers etc.
    bl app_init_video

    ; Initialise the music player etc.
	; Param R12=top of RAM used.
    bl app_init_audio

    ; EARLY INIT - LOAD STUFF HERE!
    .if _DEBUG
    mov r0, #Debug_TopOfWimpSlot
    sub r0, r0, r12
    mov r0, r0, lsr #10         ; /1024
    str r0, debug_free_ram
    .endif

	; Bootstrap the main sequence.
    ; Does one tick of the script!
    bl sequence_init

	; LATE INITALISATION HERE!
	bl get_next_bank_for_writing    ; NB. Replace with bl get_screen_addr to see font plotting.

    ; Can now write to the screen for final init.
    ldr r12, screen_addr
    bl app_late_init

    .if !AppConfig_UseRasterMan
	; Enable key pressed event.
	mov r0, #OSByte_EventEnable
	mov r1, #Event_KeyPressed
	SWI OS_Byte
    .else
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

	; Play music!
	QTMSWI QTM_Start

    ; Show whatever app_init set up as the first frame.
    bl mark_write_bank_as_pending_display

    ; Reset vsync count.
    ldr r0, vsync_count
    str r0, last_vsync

main_loop:

	; ========================================================================
	; PREPARE
	; ========================================================================

    ;bl app_pre_tick_frame

    .if _DEBUG

    .if AppConfig_UseRasterMan
    swi RasterMan_ScanKeyboard
    str r0, debug_rm_key        ; R0=(low key nibble << 8) | (high key nibble)
    mov r1, r0, lsr #12         ; 0xc=key down 0xd=key up
    and r1, r1, #1
    eor r1, r1, #1              ; 1=key down 0=key up
    mov r2, r0, lsr #8
    and r2, r2, #0xf
    and r0, r0, #0xf
    orrs r2, r2, r0, lsl #4     ; combine nibbles back into RMKey_* value
    bl debug_handle_keypress
    .endif

    bl debug_do_key_callbacks

    ldrb r0, debug_restart_flag
    cmp r0, #0
    blne debug_restart_sequence

	ldrb r0, debug_main_loop_pause
	cmp r0, #0
	bne .3

	ldrb r0, debug_main_loop_step
	cmp r0, #0
	beq main_loop_skip_tick
	.3:
	.endif

    .if AppConfig_UseSyncTracks
    bl sync_update_vars
    .endif

	; ========================================================================
	; TICK
	; ========================================================================

	bl script_tick_all
    .if LibConfig_IncludeMathVar
    ; Tick after script as this is where vars will be added/removed.
    ldr r0, vsync_delta
    bl math_var_tick                ; TODO: Here or app_tick or lib_tick?
    ; Tick before layers as this is where the vars will be used.
    .endif
	bl fx_tick_layers

    ; Update frame counter.
    ldr r0, frame_counter
    ldr r1, max_frames
    add r0, r0, #1
    cmp r0, r1
    .if SeqConfig_EnableLoop
    movge r0, #0
    str r0, frame_counter
    .if _DEMO_PART != _PART_DONUT
    blge sequence_init
    .endif
    .else
    str r0, frame_counter
    .endif

    .if _DEBUG
    ; Calculate frame rate = frames / second.
    ands r0, r0, #0x1f           ; every 32 frames
    bne .4

    ldr r0, vsync_count
    ldr r1, vsyncs_since_last_count
    str r0, vsyncs_since_last_count
    sub r0, r0, r1              ; number of vsyncs for last N frames.
    
    ; Frame rate = frames * 50 / vsyncs
    mov r1, #50*32              ; every 32 frames
    mov r2, #-1
    .5:
    subs r1, r1, r0
    add r2, r2, #1
    bpl .5

    str r2, debug_frame_rate
    .4:
    .endif

    .if AppConfig_UseSyncTracks
    ldr r0, frame_counter       ; TODO: frames vs syncs ==> secs!
    bl sync_set_time
    .endif

    .if _DEBUG
    mov r0, #-1
    mov r1, #-1
    QTMSWI QTM_Pos         ; read position.

    strb r1, music_pos+0
    strb r0, music_pos+1
    .endif

main_loop_skip_tick:

    .if _DEBUG
    mov r0, #0
    strb r0, debug_main_loop_step
    .endif

	; ========================================================================
	; VSYNC
	; ========================================================================

	; This will block if there isn't a bank available to write to.
    ; I.e. we're running too fast and our next buffer is the one being displayed.
	; bl get_next_bank_for_writing

	; Useful to determine frame rate for debug or frame-rate independent animation.

	ldr r1, last_vsync
	ldr r2, vsync_count
	sub r0, r2, r1
	str r2, last_vsync

    ldr r1, reset_vsync_delta
    cmp r1, #0
    movne r0, #1
    mov r1, #0
    str r1, reset_vsync_delta
	str r0, vsync_delta

    .if _DEBUG
    ldr r1, vsyncs_missed
    sub r0, r0, #1
    add r1, r1, r0
    str r1, vsyncs_missed
    .endif

	; R0 = vsync delta since last frame.
	.if _CHECK_FRAME_DROP
    .if 0
	; This flashes if vsync IRQ has no pending buffer to display.
	ldr r2, last_dropped_frame
	ldr r1, last_last_dropped_frame
	cmp r2, r1
	moveq r4, #0x000
	movne r4, #0x00f
	strne r2, last_last_dropped_frame
	bl debug_set_border
    .else
    ldr r2, vsync_delta
    cmp r2, #2
    movgt r4, #0x00f
    movle r4, #0x000
	bl debug_set_border
    .endif
    .endif

	; ========================================================================
	; DRAW
	; ========================================================================

    ; TODO: app_pre_draw_frame if needed.
	bl fx_draw_layers

	; show debug
	.if _DEBUG
    ldr r12, screen_addr
    bl debug_plot_vars
	.endif

	; Swap screens!
    ; NB. This blocks if there is already a bank pending display.
    ;     This also now fetches the next bank to write to.
	bl mark_write_bank_as_pending_display

    ldr r1, end_the_demo
    cmp r1, #0
    bne exit

	; repeat!
    .if AppConfig_UseRasterMan
	swi RasterMan_ScanKeyboard
	mov r1, #0xc0c0
	cmp r0, r1
    bne main_loop
    .else
	swi OS_ReadEscapeState
	bcc main_loop                   ; exit if Escape is pressed
    .endif

exit:
    .if _DEMO_PART==_PART_DONUT
    mov r0, #0
    str r0, app_ready
    .endif

    .if !AppConfig_UseRasterMan
	; Remove our IRQ handler
    .if AppConfig_InstallIrqHandler
	bl uninstall_irq_handler
    .else
	; Disable vsync event
	mov r0, #OSByte_EventDisable
	mov r1, #Event_VSync
	swi OS_Byte
    .endif

	; Disable key press event
	mov r0, #OSByte_EventDisable
	mov r1, #Event_KeyPressed
	swi OS_Byte

	; Release our event handler
	mov r0, #EventV
	adr r1, event_handler
	mov r2, #0
	swi OS_Release
    .else
	swi RasterMan_Wait
  	swi RasterMan_Release
	swi RasterMan_Wait
	swi RasterMan_Wait
    .endif

	; Disable music
	mov r0, #0
	QTMSWI QTM_Clear

    .if _DEBUG
	; Release our error handler
	mov r0, #ErrorV
	adr r1, error_handler
	mov r2, #0
	swi OS_Release
    .endif

	; Display whichever bank we've just written to
	mov r0, #OSByte_WriteDisplayBank
	ldr r1, write_bank
	swi OS_Byte
	; and write to it
	mov r0, #OSByte_WriteVduBank
	ldr r1, write_bank
	swi OS_Byte

	; Flush keyboard buffer.
	mov r0, #15
	mov r1, #1
	swi OS_Byte

.if AppConfig_UseQtmEmbedded
    adr lr, .1
    ldr pc, QtmEmbedded_Exit
    .1:
.endif

    ; Goodbye.
    .if AppConfig_ReturnMainToCaller
    ; For Megademo need to exit to caller with R0=0.
    ldr sp, callers_stack_p
    mov r0, #0
    ldr pc, [sp], #4
    .else
	SWI OS_Exit
    .endif

; ============================================================================
; Debug helpers.
; ============================================================================

.if _DEBUG
debug_toggle_main_loop_pause:
	ldrb r0, debug_main_loop_pause
	eor r0, r0, #1
	strb r0, debug_main_loop_pause

    ; Toggle music.
    cmp r0, #0
.if AppConfig_UseQtmEmbedded
    stmfd sp!, {r11,lr}
    moveq r11, #QTM_Pause-QTM_SwiBase			    ; pause
    movne r11, #QTM_Start-QTM_SwiBase             ; play
    mov lr, pc
    ldr pc, QtmEmbedded_Swi
    ldmfd sp!, {r11,lr}
.else
    swieq QTM_Pause			    ; pause
    swine QTM_Start             ; play
.endif

    .if AppConfig_UseSyncTracks
    b sync_set_is_playing
    .else
    mov pc, lr
    .endif

debug_restart_sequence:
    ; Start music again.
    mov r0, #0
    strb r0, debug_restart_flag
    mov r1, #0
	QTMSWI QTM_Pos

    ; Start script again.
    b sequence_init

debug_skip_to_next_pattern:
    mov r0, #-1
    mov r1, #-1
    QTMSWI QTM_Pos         ; read position.

    add r0, r0, #1
    cmp r0, #SeqConfig_MaxPatterns
    movge pc, lr

    bl sequence_jump_to_pattern

    mov r1, #0
    QTMSWI QTM_Pos         ; set position.
    mov pc, lr
.endif

; ============================================================================
; System stuff.
; ============================================================================

stack_p:
	.long stack_base_no_adr

.if AppConfig_ReturnMainToCaller
callers_stack_p:
    .long 0
.endif

screen_addr_input:
	.long VD_ScreenStart, -1

last_vsync:
	.long 0

vsync_delta:
	.long 0

reset_vsync_delta:
    .long 0

.if _DEBUG
vsyncs_missed:
    .long 0

vsyncs_since_last_count:
    .long 0

debug_frame_rate:
    .long 0
.endif

.if _CHECK_FRAME_DROP
last_dropped_frame:
	.long 0

last_last_dropped_frame:
	.long 0
.endif

frame_counter:
    .long 0

max_frames:
    .long SeqConfig_MaxFrames

end_the_demo:
    .long 0

.if _DEBUG
music_pos:
    .long 0
.endif

.if !AppConfig_UseRasterMan
; R0=event number
event_handler:
    .if _DEBUG
	cmp r0, #Event_KeyPressed
	; R1=0 key up or 1 key down
	; R2=internal key number (RMKey_*)
    beq debug_handle_keypress
    .endif

    .if !AppConfig_InstallIrqHandler
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


mark_write_bank_as_pending_display:
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

get_next_bank_for_writing:
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

get_screen_addr:
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

.if _DEBUG
error_handler:
	STMDB sp!, {r0-r2, lr}

    .if !AppConfig_UseRasterMan
    .if AppConfig_InstallIrqHandler
	bl uninstall_irq_handler
    .else
	mov r0, #OSByte_EventDisable
	mov r1, #Event_VSync
	SWI OS_Byte
    .endif

	; Release event handler.
	MOV r0, #OSByte_EventDisable
	MOV r1, #Event_KeyPressed
	SWI OS_Byte

	MOV r0, #EventV
	ADR r1, event_handler
	mov r2, #0
	SWI OS_Release
    .endif

	; Release error handler.
	MOV r0, #ErrorV
	ADR r1, error_handler
	MOV r2, #0
	SWI OS_Release

	; Write & display current screen bank.
	MOV r0, #OSByte_WriteDisplayBank
	LDR r1, write_bank
	SWI OS_Byte

	; Do these help?
;	QTMSWI QTM_Stop

    .if AppConfig_UseRasterMan
    ;swi RasterMan_Release
    .endif

	LDMIA sp!, {r0-r2, lr}
	MOVS pc, lr
.endif

; ============================================================================
; Core code modules
; ============================================================================

screen_addr:
	.long 0			    ; ptr to the current VIDC screen bank being written to.

init_screen_addr:
    .long 0             ; ptr to the screen displayed during [long] init.

; TODO: Make these bytes?
displayed_bank:
	.long 0				; VIDC sreen bank being displayed

write_bank:
	.long 0				; VIDC screen bank being written to

pending_bank:
	.long 0				; VIDC screen to be displayed next

vsync_count:
	.long 0				; current vsync count from start of exe.

palette_array_p:
    .long 0             ; pointer to the palette array for this frame.

vidc_buffers_p:
    .long vidc_buffers_no_adr - 64

.if _DEBUG
debug_main_loop_pause:
	.byte DebugDefault_PlayPause

debug_main_loop_step:
	.byte 0

debug_show_info:
	.byte DebugDefault_ShowVars

debug_show_rasters:
	.byte DebugDefault_ShowRasters

debug_restart_flag:
    .byte 0

.p2align 2

debug_free_ram:
    .long 0
.endif

; ============================================================================
; Support library code modules used by the FX.
; ============================================================================

.include "lib/debug.asm"
.include "lib/fx.asm"
.include "lib/script.asm"
.include "lib/sequence.asm"
.if AppConfig_UseSyncTracks
.include "src/sync.asm"
.endif
.include "src/app.asm"
.include "lib/lib_code.asm"

; ============================================================================
; DATA Segment
; ============================================================================

.include "src/data.asm"

; ============================================================================
; BSS Segment
; ============================================================================

.include "src/bss.asm"
