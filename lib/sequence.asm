; ============================================================================
; The actual sequence for the demo.
; ============================================================================

frame_counter:
    .long 0

max_frames:
    .long SeqConfig_MaxFrames

music_pos:
    .long 0

end_the_demo:
    .long 0

sequence_program_p:
    .long seq_main_program

; ============================================================================

sequence_init:
    str lr, [sp, #-4]!

    ; Reset frame count.
    mov r0, #0
    str r0, frame_counter

    ; Reset music pos.
    mov r0, #-1
    mov r1, #-1
    QTMSWI QTM_Pos          ; read position.
    strb r1, music_pos+0    ; row
    strb r0, music_pos+1    ; pattern

    ; Install sync editor.
    .if AppConfig_UseSyncTracks
    bl sync_init
    .endif

    .if LibConfig_IncludeMathVar
    bl math_var_init
    .endif

    ; Initialise script system.
    bl script_init

    .if _DEBUG && 0                 ; TODO: Reinstate dynamic sequence load?
	; Load seq file.
	mov r0, #0xff
    ldr r2, sequence_program_p
	adr r1, filename
    mov r3, #0
	swi OS_File
    .endif

    ; Set the PC for the sequence.
	ldr r0, sequence_program_p
	bl script_add_program

    ; Tick script once for module init.
    bl script_tick_all

    ldr pc, [sp], #4

sequence_tick:
    str lr, [sp, #-4]!

    mov r0, #-1
    mov r1, #-1
    QTMSWI QTM_Pos          ; read position.

    strb r1, music_pos+0    ; row
    strb r0, music_pos+1    ; pattern

    .if AppConfig_UseSyncTracks
    ; Update in-memory variables from external track.
    bl sync_update_vars
    .endif

    .if AppConfig_UseEvents
    ; Call fns. from external events track.
    ldr r0, music_pos
    bl events_tick
    .endif

    ; Update the script.
    ldr r0, vsync_delta
	bl script_tick_all

    .if LibConfig_IncludeMathVar
    ; Tick after script as this is where vars will be added/removed.
    ldr r0, vsync_delta
    bl math_var_tick
    ; Tick before layers as this is where the vars will be used.
    .endif

    ; Tick the FX modules.
	bl fx_tick_layers

    ; Update frame counter.
    ; TODO: Should this come after draw?
    ldr r0, frame_counter
    ldr r1, max_frames
    add r0, r0, #1
    cmp r0, r1
    .if SeqConfig_EnableLoop
    movge r0, #0
    str r0, frame_counter
    .if SeqConfig_InitOnLoop
    blge sequence_init
    .endif
    .else
    str r0, frame_counter
    strge r0, end_the_demo
    .endif

    .if AppConfig_UseSyncTracks
    ldr r0, frame_counter       ; TODO: frames vs syncs ==> secs!
    bl sync_set_time
    .endif

    ldr pc, [sp], #4

; ============================================================================

.if _DEBUG
filename:
	.byte "<Demo$Dir>.Seq",0
	.p2align 2

; R0=pattern no. [must preserve]
sequence_jump_to_pattern:
    str lr, [sp, #-4]!

    ; Skip past events.
    bl events_ffwd_to_pattern

    ; Update frame counter to match.
    adr r2, debug_pattern_to_frame
    ldr r2, [r2, r0, lsl #2]
    bl script_ffwd_to_frame

    ldr pc, [sp], #4

.macro frame_for_pattern pat        ; TODO: Actually vsyncs.
    .long \pat*SeqConfig_PatternLength_Rows*SeqConfig_ProTracker_TicksPerRow*125.0/SeqConfig_ProTracker_Tempo
.endm

debug_pattern_to_frame:
    frame_for_pattern 0
    frame_for_pattern 1
    frame_for_pattern 2
    frame_for_pattern 3
    frame_for_pattern 4
    frame_for_pattern 5
    frame_for_pattern 6
    frame_for_pattern 7
    frame_for_pattern 8
    frame_for_pattern 9
    frame_for_pattern 10
    frame_for_pattern 11
    frame_for_pattern 12
    frame_for_pattern 13
    frame_for_pattern 14
    frame_for_pattern 15
    frame_for_pattern 16
    frame_for_pattern 17
    frame_for_pattern 18
    frame_for_pattern 19
    frame_for_pattern 20
    frame_for_pattern 21
    frame_for_pattern 22
    frame_for_pattern 23
    frame_for_pattern 24
    frame_for_pattern 25
    frame_for_pattern 26
    frame_for_pattern 27
    frame_for_pattern 28
    frame_for_pattern 29
    frame_for_pattern 30
    frame_for_pattern 31
    frame_for_pattern 32
    frame_for_pattern 33
    frame_for_pattern 34
    frame_for_pattern 35
    frame_for_pattern 36
    frame_for_pattern 37
    frame_for_pattern 38
    frame_for_pattern 39
.endif

; ============================================================================
