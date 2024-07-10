; ============================================================================
; Archie-Verse: a Acorn Archimedes demo/trackmo framework.
; ============================================================================

; ============================================================================
; Defines for a specific build.
; ============================================================================

.equ _DEBUG,                    1
.equ _SMALL_EXE,                0       ; TODO: Configure from Makefile?
.equ _SLOW_CPU,                 0       ; ARM2 @ 8MHz. TODO: Set dynamically.

.equ _LOG_SAMPLES,              (_SMALL_EXE && 1)

.equ _DEBUG_RASTERS,            (_DEBUG && 1)
.equ _DEBUG_SHOW,               (_DEBUG && 1)
.equ _CHECK_FRAME_DROP,         (!_DEBUG && 0)
.equ _SYNC_EDITOR,              (_DEBUG && 1)   ; sync driven by external editor.

.equ DebugDefault_PlayPause,    1		; play
.equ DebugDefault_ShowRasters,  1
.equ DebugDefault_ShowVars,     0		; slow

; ============================================================================
; Includes.
; ============================================================================

.include "src/app_config.h.asm"
.include "lib/swis.h.asm"
.include "lib/lib_config.h.asm"
.include "lib/maths.h.asm"
.include "lib/macros.h.asm"
.include "lib/debug.h.asm"

; ============================================================================
; Code Start
; ============================================================================

.org 0x8000

; ============================================================================
; Main
; ============================================================================

Start:
main:
    ldr sp, stack_p

	; Claim the Event vector.
    .if !AppConfig_UseRasterCore
	MOV r0, #EventV
	ADR r1, event_handler
	MOV r2, #0
	SWI OS_Claim
    .endif

	; Claim the Error vector.
	MOV r0, #ErrorV
	ADR r1, error_handler
	MOV r2, #0
	SWI OS_Claim
    ; TODO: Do we need this outside of _DEBUG?

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

	; Bootstrap the main sequence.
    ; Does one tick of the script!
    bl sequence_init

	; LATE INITALISATION HERE!
	bl get_next_bank_for_writing    ; NB. Replace with bl get_screen_addr to see font plotting.

    ; Can now write to the screen for final init.
    ldr r12, screen_addr
    bl app_late_init

    .if !AppConfig_UseRasterCore
	; Enable key pressed event.
	mov r0, #OSByte_EventEnable
	mov r1, #Event_KeyPressed
	SWI OS_Byte
    .endif

	; Play music!
	QTMSWI QTM_Start

	; Install our own IRQ handler - thanks Steve! :)
    .if AppConfig_InstallIrqHandler
	bl rastercore_install_irq_handler
    .else
	mov r0, #OSByte_EventEnable
	mov r1, #Event_VSync
	SWI OS_Byte
    .endif

    ; Show whatever app_init set up as the first frame.
    bl mark_write_bank_as_pending_display

    ; Reset vsync count.
    ldr r0, vsync_count
    str r0, last_vsync

    mov r0, #1
    mov r1, #0
    ldr r12, screen_addr

background_loop:
	; repeat!
    
    bl math_rand
    strb r0, [r12], #1
    add r0, r0, #1
    add r1, r1, #1
    cmp r1, #Screen_Bytes
    movge r1, #0
    ldrge r12, screen_addr

    ; Until Escape is pressed.
    ldrb r11, app_exit
    cmp r11, #0
    beq background_loop

    ; Wait until main_loop completed.
    .1:
    ldrb r11, app_main_loop
    cmp r11, #0
    bne .1

    ; Then exit.
    b exit


main_loop:
    str lr, [sp, #-4]!
    mov r0, #1
    strb r0, app_main_loop

	; ========================================================================
	; PREPARE
	; ========================================================================

    bl app_pre_tick_frame

    .if _DEBUG
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
    blge sequence_init
    .else
    str r0, frame_counter
    bge exit
    .endif

    .if AppConfig_UseSyncTracks
    ldr r0, frame_counter       ; TODO: frames vs syncs.
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
    ; THIS SHOULD NEVER BLOCK AS TESTED OUTSIDE IN VSYNC HANDLER.
	bl get_next_bank_for_writing

	; Useful to determine frame rate for debug or frame-rate independent animation.
	ldr r1, last_vsync
	ldr r2, vsync_count
	sub r0, r2, r1
	str r2, last_vsync
	str r0, vsync_delta

    .if _DEBUG
    ldr r1, vsyncs_missed
    sub r0, r0, #1
    add r1, r1, r0
    str r1, vsyncs_missed
    .endif

	; R0 = vsync delta since last frame.
	.if _CHECK_FRAME_DROP
	; This flashes if vsync IRQ has no pending buffer to display.
	ldr r2, last_dropped_frame
	ldr r1, last_last_dropped_frame
	cmp r2, r1
	moveq r4, #0x000000
	movne r4, #0x0000ff
	strne r2, last_last_dropped_frame
	bl palette_set_border
	.endif

	; ========================================================================
	; DRAW
	; ========================================================================

    ; TODO: app_pre_draw_frame if needed.
    ldr r12, screen_addr
	bl fx_draw_layers

	; show debug
	.if _DEBUG
    ldr r12, screen_addr
    bl debug_plot_vars
	.endif

	; Swap screens!
	bl mark_write_bank_as_pending_display

    mov r0, #0
    strb r0, app_main_loop
    ldr lr, [sp], #4    ; we actually want to restore the LR.
    mov pc, lr

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
    mov r9, pc
    orr r8, r9, #ProcMode_Svc
    teqp r8, #0 ; enter Svc mode
    mov r0, r0
    str lr, [sp, #-4]!  ; store lr_svc

    cmp r0, #0
    swieq QTM_Pause | XOS_Flag			    ; pause
    swine QTM_Start | XOS_Flag             ; play

    ldr lr, [sp], #4    ; restore lr_svc
    teqp r9, #0 ; reenter original mode
    mov r0, r0
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

screen_addr_input:
	.long VD_ScreenStart, -1

last_vsync:
	.long 0

vsync_delta:
	.long 0

.if _DEBUG
vsyncs_missed:
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

.if _DEBUG
music_pos:
    .long 0
.endif

.if !AppConfig_UseRasterCore
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

    .if _DEBUG
    b debug_handle_keypress
    .else
    mov pc, lr
    .endif
.endif

; ============================================================================
; Screen and palette buffer management.
; ============================================================================

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

    ; Convert palette buffer to VIDC writes here!
    ldr r2, vidc_buffers_p
    add r2, r2, r1, lsl #6              ; 64 bytes per bank

    ldr r3, palette_array_p
    cmp r3, #0
    moveq r0, #-1                       ; no palette to set.
    streq r0, [r2]
    beq .2

    ; TODO: Could think about a palette dirty flag.

    mov r4, #0
.3:
    ldr r0, [r3], #4            ; 0x00BbGgRr

    ; Convert from OSWORD to VIDC format.
    mov r7, r0, lsr #20
    and r7, r7, #0xf            ; 0xB
    mov r6, r0, lsr #12
    and r6, r6, #0xf            ; 0xG
    mov r5, r0, lsr #4
    and r5, r5, #0xf            ; 0xR

    orr r0, r5, r6, lsl #4
    orr r0, r0, r7, lsl #8      ; 0xBGR
    orr r0, r0, r4, lsl #26     ; VIDC_ColN = N << 26
    str r0, [r2], #4

    add r4, r4, #1
    cmp r4, #16
    blt .3

.2:
	; Show pending bank at next vsync.
	MOV r0, #OSByte_WriteDisplayBank
    IRQSWI OS_Byte

	mov pc, lr

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
    mov r9, pc
    orr r8, r9, #ProcMode_Svc
    teqp r8, #0 ; enter Svc mode
    mov r0, r0
    str lr, [sp, #-4]!  ; store lr_svc

	mov r0, #OSByte_WriteVDUBank
	swi XOS_Byte

	; Back buffer address for writing bank stored at screen_addr
	adrl r0, screen_addr_input
	adrl r1, screen_addr
	swi XOS_ReadVduVariables

    ldr lr, [sp], #4    ; restore lr_svc
    teqp r9, #0 ; reenter original mode
    mov r0, r0

    mov pc, lr

get_screen_addr:
	; Back buffer address for writing bank stored at screen_addr
	adrl r0, screen_addr_input
	adrl r1, screen_addr
	swi OS_ReadVduVariables
    mov pc, lr

; ============================================================================
; Error handling and exit
; ============================================================================

cleanup:
    str lr, [sp, #-4]!

	; Disable music
	mov r0, #0
	QTMSWI QTM_Clear

	; Remove our IRQ handler
    .if AppConfig_UseRasterCore
	bl rastercore_uninstall_irq_handler
    .else
	; Disable vsync event
	mov r0, #OSByte_EventDisable
	mov r1, #Event_VSync
	swi OS_Byte

	; Disable key press event
	mov r0, #OSByte_EventDisable
	mov r1, #Event_KeyPressed
	swi OS_Byte

	; Release our event handler
	mov r0, #EventV
	adr r1, event_handler
	mov r2, #0
	swi OS_Release
    .endif

	; Release our error handler
	mov r0, #ErrorV
	adr r1, error_handler
	mov r2, #0
	swi OS_Release

	; Display whichever bank we've just written to
	mov r0, #OSByte_WriteDisplayBank
	ldr r1, write_bank
	swi OS_Byte
	; and write to it
	mov r0, #OSByte_WriteVDUBank
	ldr r1, write_bank
	swi OS_Byte

    .if AppConfig_UseQtmEmbedded
    adr lr, .1
    ldr pc, QtmEmbedded_Exit
    .1:
    .endif

    ldr pc, [sp], #4

.if _DEBUG
; Called when OS_GenerateError is issued.
; Enter in SVC mode?
error_handler:
	STMDB sp!, {r0-r2, lr}

    bl cleanup

	LDMIA sp!, {r0-r2, lr}
	MOVS pc, lr
.endif

exit:
    bl cleanup

	; Flush keyboard buffer.
	mov r0, #15
	mov r1, #1
	swi OS_Byte

    ; Goodbye.
	SWI OS_Exit

; ============================================================================
; Core code modules
; ============================================================================

screen_addr:
	.long 0			    ; ptr to the current VIDC screen bank being written to.

init_screen_addr:
    .long 0             ; ptr to the screen displayed during [long] init.

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
.endif

app_main_loop:
    .byte 0

app_exit:
    .byte 0
.p2align 2

; ============================================================================
; Support library code modules used by the FX.
; ============================================================================

.include "lib/debug.asm"
.include "lib/script.asm"
.include "lib/sequence.asm"
.include "lib/fx.asm"
.include "src/app.asm"
.if AppConfig_UseSyncTracks
.include "src/sync.asm"
.endif
.include "lib/lib_code.asm"

; ============================================================================
; DATA Segment
; ============================================================================

.include "src/data.asm"

; ============================================================================
; BSS Segment
; ============================================================================

.include "src/bss.asm"
