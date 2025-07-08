; ============================================================================
; Archie-Verse: a Acorn Archimedes demo/trackmo framework.
; ============================================================================

; ============================================================================
; Defines for a specific build.
; ============================================================================

.ifndef _WIMP_SLOT
.equ _WIMP_SLOT,                1250*1024
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
.equ _CHECK_FRAME_DROP,         (!_DEBUG && 0)  ; TODO: Check this is still fit for purpose.
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

    ; Set up interrupt code.
    bl vsync_init

    ; Generate sample data first?
    .if AppConfig_UseArchieKlang
    bl archieklang_init
    .endif

	; Library initialisation.
	bl lib_init
	; Returns R12=top of RAM used.

    ; Allocate and clear screen buffers etc.
    bl video_init

    ; Initialise the music player etc.
	; Param R12=top of RAM used.
    bl audio_init

    .if _DEBUG
    mov r0, #Debug_TopOfWimpSlot
    sub r0, r0, r12
    mov r0, r0, lsr #10         ; /1024
    str r0, debug_free_ram
    .endif

	; ================================
    ; EARLY INIT == LOAD STUFF HERE!
	; ================================

    ; Register debug vars etc.
    .if _DEBUG
    bl app_init_debug               ; exact debug equired is app dependent.
    .endif

	; Bootstrap the main sequence.
    ; NB. Does one tick of the script!
    ;     But doesn't tick the FX layers.
    bl sequence_init

	; ================================
	; LATE INITALISATION == PREPARE FIRST FRAME
	; ================================
    
	bl video_get_next_screen    ; NB. Replace with bl video_get_screen_addr to see font plotting.

    ; TODO: Move sequence_init here and replace app_late_init?

    ; Can now write to the screen for final init.
    bl app_late_init

    ; Kick off anything that happens just before start.
    bl vsync_late_init

	; Play music!
	QTMSWI QTM_Start

    ; Show whatever the app set up as the first frame.
    bl video_mark_screen_as_pending_display

    ; Reset vsync count.
    ; TODO: Should this be mov r0, #0?
    ldr r0, vsync_count
    str r0, last_vsync

main_loop:

	; ========================================================================
	; PREPARE
	; ========================================================================

    .if _DEBUG
    bl vsync_scankeyboard               ; NOP w/out RasterMan
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

	; ========================================================================
	; TICK
	; ========================================================================

    bl sequence_tick
    ; Returns frame_counter in R0.

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

main_loop_skip_tick:

    .if _DEBUG
    mov r0, #0
    strb r0, debug_main_loop_step
    .endif

	; ========================================================================
	; PREPARE TO DRAW NEXT FRAME
	; ========================================================================

	ldr r1, last_vsync
	ldr r2, vsync_count
	sub r0, r2, r1
	str r2, last_vsync
	str r0, vsync_delta

	; R0 = vsync delta since last frame.

    .if _DEBUG
    ldr r1, vsyncs_missed
    sub r0, r0, #1
    add r1, r1, r0
    str r1, vsyncs_missed
    .endif

	.if _CHECK_FRAME_DROP
    cmp r0, #1              ; 25Hz
    movgt r4, #0x00f
    movle r4, #0x000
	bl debug_set_border
    .endif

	; ========================================================================
	; DRAW
	; ========================================================================

    ; TODO: app_pre_draw_frame if needed.
	bl fx_draw_layers

	; show debug
	.if _DEBUG
    bl debug_plot_vars
	.endif

	; Swap screens!
    ; NB. This blocks if there is already a bank pending display.
    ;     This also now fetches the next bank to write to.
	bl video_mark_screen_as_pending_display

    ldr r1, end_the_demo
    cmp r1, #0
    bne exit

	; repeat!
    bl vsync_check_escape
	bcc main_loop                   ; exit if Escape is pressed

exit:
    ; App custom exit.
    bl app_exit

    ; Release all interupt handling.
    bl vsync_exit

    bl audio_exit

    bl video_exit

    .if _DEBUG
	; Release our error handler
	mov r0, #ErrorV
	adr r1, error_handler
	mov r2, #0
	swi OS_Release
    .endif

	; Flush keyboard buffer.
	mov r0, #15
	mov r1, #1
	swi OS_Byte

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
; System stuff.
; ============================================================================

stack_p:
	.long stack_base_no_adr

.if AppConfig_ReturnMainToCaller
callers_stack_p:
    .long 0
.endif

vsync_count:
	.long 0				; current vsync count from start of exe.

last_vsync:
	.long 0

vsync_delta:
	.long 0

; ============================================================================
; Debug helpers.
; ============================================================================

.if _DEBUG
error_handler:
	STMDB sp!, {r0-r2, lr}

    ; Release any interrupt handlers.
    bl vsync_exit

	; Write & display current screen bank.
    bl video_exit

    ; Stop QTM.
    bl audio_exit

	; Release error handler.
	MOV r0, #ErrorV
	ADR r1, error_handler
	MOV r2, #0
	SWI OS_Release

	LDMIA sp!, {r0-r2, lr}
	MOVS pc, lr

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
; Debug stuff.
; ============================================================================

.if _DEBUG
vsyncs_missed:
    .long 0

vsyncs_since_last_count:
    .long 0

debug_frame_rate:
    .long 0

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
; Support library code modules used by the core app.
; ============================================================================

.include "lib/debug.asm"
.include "lib/fx.asm"
.include "lib/script.asm"
.include "lib/sequence.asm"
.if AppConfig_UseEvents
.include "lib/events.asm"
.endif
.if AppConfig_UseSyncTracks
.include "src/sync.asm"
.endif

; ============================================================================
; App modules.
; ============================================================================

.include "src/app_vsync.asm"
.include "src/audio.asm"
.include "src/video.asm"
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
