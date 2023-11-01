; ============================================================================
; The actual sequence for the demo.
; TODO: Should probably decide if frame_counter lives in here.
; ============================================================================

sequence_program_p:
    .long seq_main_program

sequence_init:
    str lr, [sp, #-4]!

    mov r0, #0
    str r0, frame_counter

    .if _DEBUG
    bl debug_init
    .endif

    bl script_init

    .if _DEBUG && 0
	; Load seq file.
	mov r0, #0xff
    ldr r2, sequence_program_p
	adr r1, filename
    mov r3, #0
	swi OS_File
    .endif

	ldr r0, sequence_program_p
	bl script_add_program
    ldr pc, [sp], #4

.if _DEBUG
filename:
	.byte "<Demo$Dir>.Seq",0
	.p2align 2

; R0=pattern no. [must preserve]
sequence_jump_to_pattern:
    str lr, [sp, #-4]!

    ; Update frame counter to match.
    adr r2, debug_pattern_to_frame
    ldr r2, [r2, r0, lsl #2]
    bl script_ffwd_to_frame

    ldr pc, [sp], #4

.macro frame_for_pattern pat, 
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
