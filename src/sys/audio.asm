; ============================================================================
; App audio module.
; Ideally don't want this file hackable.
; Rename to main_audio or something?
; ============================================================================

.if AppConfig_UseQtmEmbedded
QtmEmbedded_Init:
    .long QtmEmbedded_Base + 52

QtmEmbedded_Swi:
    .long QtmEmbedded_Base + 56

QtmEmbedded_Service:
    .long QtmEmbedded_Base + 60

QtmEmbedded_Exit:
    .long QtmEmbedded_Base + 64
.endif

; ============================================================================
; App audio code.
; ============================================================================

.if AppConfig_LoadModFromFile
music_filename:
	.byte "<Obey$Dir>.Music",0
	.p2align 2

music_mod_p:
    .long 0
.else
music_mod_p:
	.long music_mod_no_adr
.endif

music_sample_speed:
    .long 0

; R12=top of RAM used.
audio_init:

.if AppConfig_DynamicSampleSpeed
	; Count how long the init takes as a very rough estimate of CPU speed.
	ldr r1, vsync_count
	cmp r1, #AudioConfig_SampleSpeed_CPUThreshold
	movge r0, #AudioConfig_SampleSpeed_SlowCPU
	movlt r0, #AudioConfig_SampleSpeed_FastCPU
.else
    mov r0, #AudioConfig_SampleSpeed_Default
.endif
    str r0, music_sample_speed      ; to query on real hw because I paranoid.

	; Setup QTM for our needs.
	QTMSWI QTM_SetSampleSpeed

    .if 0
    mov r0, #AudioConfig_VuBars_Effect
    mov r1, #AudioConfig_VuBars_Gravity
    QTMSWI QTM_VUBarControl
    .endif

    mov r0, #1
    mov r1, #AudioConfig_StereoPos_Ch1
    QTMSWI QTM_Stereo

    mov r0, #2
    mov r1, #AudioConfig_StereoPos_Ch2
    QTMSWI QTM_Stereo

    mov r0, #3
    mov r1, #AudioConfig_StereoPos_Ch3
    QTMSWI QTM_Stereo

    mov r0, #4
    mov r1, #AudioConfig_StereoPos_Ch4
    QTMSWI QTM_Stereo

    ; NOTE: Music looping flag is ignored if using the RasterMan version of QTM.
    ; From Steve: The stop code has to call a bunch of SWIs, and it cannot do that
    ;             from the RasterMan driven IRQ (or it would hang RasterMan), so it
    ;             skips the stop code and allows the track to loop.
    ;             Solution (as long as you *know* that RM will *not* be running at
    ;             the point the track ends)... Add a QTM MusicInterrupt and when you
    ;             receive the Song ended (0) then switch to SVC mode and issue QTM_Pause,
    ;             to stop the track.
    mov r0, #0b0010
    .if SeqConfig_EnableLoop
    mov r1, #0b0000
    .else
    mov r1, #0b0010
    .endif
    QTMSWI QTM_MusicOptions

	; Load the music.

    .if AppConfig_LoadModFromFile
    ; Get file size.
    mov r0, #5
	adr r1, music_filename
    swi OS_File
    cmp r0, #1
    swine OS_Exit           ; file not found.
    ; R4=file length.
    add r4, r4, #3
    bic r4, r4, #0b11       ; round up to 4 bytes

	; Load file.
	mov r0, #0xff
    mov r2, r12             ; Load to HIMEM.
    str r2, music_mod_p
    add r12, r12, r4        ; New HIMEM.
	adr r1, music_filename
    mov r3, #0
	swi OS_File
    .endif

	mov r0, #0              ; load from address, don't copy to RMA.
    ldr r1, music_mod_p
	QTMSWI QTM_Load

    mov pc, lr

.if _DYNAMIC_RELOAD
audio_reload:
.if AppConfig_LoadModFromFile
	; Reset QTM sound system
	mov r0, #0
	QTMSWI QTM_Clear

	; Re load file.
	mov r0, #0xff
	adr r1, music_filename
    ldr r2, music_mod_p
    mov r3, #0
	swi OS_File
    ; TODO: Check for file errors?

	mov r0, #0              ; load from address, don't copy to RMA.
    ldr r1, music_mod_p
	QTMSWI QTM_Load
.endif
    mov pc, lr
.endif

; NB. This may be entered in Supervisor mode if an error is raised.
audio_exit:
    str lr, [sp, #-4]!

	; Disable music
	mov r0, #0
	QTMSWI QTM_Clear

.if AppConfig_UseQtmEmbedded
    ldr lr, [sp], #4
    ldr pc, QtmEmbedded_Exit
.else
    ldr pc, [sp], #4
.endif

; ============================================================================
; ArchieKlang generated code.
; ============================================================================

.if AppConfig_UseArchieKlang
.include "lib/archieklang.asm"
.endif

; ============================================================================
