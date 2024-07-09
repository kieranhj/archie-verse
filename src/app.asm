; ============================================================================
; App standard code.
; Hack as necessary per prod.
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
; App debug code.
; ============================================================================

.if _DEBUG
app_init_debug:
    str lr, [sp, #-4]!

    bl debug_init

    DEBUG_REGISTER_VAR vsyncs_missed
    DEBUG_REGISTER_VAR frame_counter
    DEBUG_REGISTER_VAR music_pos
    DEBUG_REGISTER_KEY RMKey_Space,      debug_toggle_main_loop_pause,  0
    DEBUG_REGISTER_KEY RMKey_A,          debug_set_byte_true,           debug_restart_flag
    DEBUG_REGISTER_KEY RMKey_S,          debug_set_byte_true,           debug_main_loop_step
    DEBUG_REGISTER_KEY RMKey_D,          debug_toggle_byte,             debug_show_info
    DEBUG_REGISTER_KEY RMKey_R,          debug_toggle_byte,             debug_show_rasters
    DEBUG_REGISTER_KEY RMKey_ArrowRight, debug_skip_to_next_pattern,    0

    DEBUG_REGISTER_VAR math_var_active_count
    ldr pc, [sp], #4
.endif

; ============================================================================
; App video code.
; ============================================================================

vdu_screen_disable_cursor:
.byte 22, VideoConfig_VduMode, 23,1,0,0,0,0,0,0,0,0,17,7
.p2align 2

app_init_video:
    str lr, [sp, #-4]!

	; Set screen MODE & disable cursor
	adr r0, vdu_screen_disable_cursor
	mov r1, #14
	swi OS_WriteN

	; Set screen size for number of buffers
	MOV r0, #DynArea_Screen
	SWI OS_ReadDynamicArea
	MOV r0, #DynArea_Screen
	MOV r2, #Mode_Bytes * VideoConfig_ScreenBanks
	SUBS r1, r2, r1
	SWI OS_ChangeDynamicArea
	MOV r0, #DynArea_Screen
	SWI OS_ReadDynamicArea
	CMP r1, r2
	ADRCC r0, error_noscreenmem
	SWICC OS_GenerateError

	; Clear all screen buffers
	mov r3, #1
.1:
	str r3, write_bank

	; CLS bank N
	mov r0, #OSByte_WriteVDUBank
    mov r1, r3
	swi OS_Byte
    ; R1=previous bank!
    ; R2=corrupted
	SWI OS_WriteI + 12		; cls

	add r3, r3, #1
	cmp r3, #VideoConfig_ScreenBanks
	ble .1

    ; Display current bank for init.
    mov r0, #OSByte_WriteDisplayBank
    ; R1=previous bank!
    sub r1, r3, #1
    str r1, displayed_bank
    swi OS_Byte

    ; Get address of the displayed bank.
    bl get_screen_addr
    ldr r12, screen_addr
    str r12, init_screen_addr

    ; No flashing colours (FFS).
    mov r0, #9
    mov r1, #0
    swi OS_Byte

.if AppConfig_UseQtmEmbedded
    mov lr, pc
    ldr pc, QtmEmbedded_Init
.endif
    ldr pc, [sp], #4

; TODO: Junk this for non_DEBUG?
error_noscreenmem:
	.long 0
	.byte "Cannot allocate screen memory!"
	.p2align 2
	.long 0


; ============================================================================
; App audio code.
; ============================================================================

.if AppConfig_LoadModFromFile
music_filename:
	.byte "<Demo$Dir>.Music",0
	.p2align 2
.else
music_mod_p:
	.long music_mod_no_adr		; 14
.endif

music_sample_speed:
    .long 0

; R12=top of RAM used.
app_init_audio:
	; Required to make QTM play nicely with RasterMan.
	mov r0, #4
	mov r1, #-1
	mov r2, #-1
	QTMSWI_NOTIRQ QTM_SoundControl

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
	QTMSWI_NOTIRQ QTM_SetSampleSpeed

    .if 0
    mov r0, #AudioConfig_VuBars_Effect
    mov r1, #AudioConfig_VuBars_Gravity
    QTMSWI_NOTIRQ QTM_VUBarControl
    .endif

    mov r0, #1
    mov r1, #AudioConfig_StereoPos_Ch1
    QTMSWI_NOTIRQ QTM_Stereo

    mov r0, #2
    mov r1, #AudioConfig_StereoPos_Ch2
    QTMSWI_NOTIRQ QTM_Stereo

    mov r0, #3
    mov r1, #AudioConfig_StereoPos_Ch3
    QTMSWI_NOTIRQ QTM_Stereo

    mov r0, #4
    mov r1, #AudioConfig_StereoPos_Ch4
    QTMSWI_NOTIRQ QTM_Stereo

    mov r0, #0b0010
    .if SeqConfig_EnableLoop
    mov r1, #0b0000
    .else
    mov r1, #0b0010
    .endif
    QTMSWI_NOTIRQ QTM_MusicOptions

	; Load the music.
    .if AppConfig_LoadModFromFile
    adr r0, music_filename
    mov r1, r12             ; HIMEM.
    .else
	mov r0, #0              ; load from address, don't copy to RMA.
    ldr r1, music_mod_p
    .endif
	QTMSWI_NOTIRQ QTM_Load

    mov pc, lr


; ============================================================================
; App late initialisation.
; ============================================================================

; R12=screen addr.
app_late_init:
    str lr, [sp, #-4]!
    ldr r10, init_screen_addr
    bl text_pool_init
    ldr pc, [sp], #4
; TODO: Make this more generic or include in sequence?


; ============================================================================
; App main loop.
; ============================================================================

; Always called, regardless of tick status.
app_pre_tick_frame:
    mov pc, lr

; ============================================================================
; Code run at vsync.
; ============================================================================

app_vsync_code:
    str lr, [sp, #-4]!

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
	beq .4  ; NO PENDING BANK MEANS WE'RE STILL DRAWING?

	str r1, displayed_bank

    ; Set palette for pending bank.
	mov r11, #VIDC_Write
    ldr r12, vidc_buffers_p
    add r12, r12, r1, lsl #6        ; 64 bytes per bank.
    mov r1, #16
.1:
    ldr r0, [r12], #4
    cmp r0, #-1
    beq .2
    str r0, [r11]                   ; VIDC_Write
    subs r1, r1, #1
    bne .1
.2:

	; Clear pending bank.
	mov r0, #0
	str r0, pending_bank

.3:
	; Increment to next bank for writing
	ldr r1, write_bank
	add r1, r1, #1
	cmp r1, #VideoConfig_ScreenBanks
	movgt r1, #1

	; Skip main loop if would have blocked waiting for a free screen buffer.
.if VideoConfig_ScreenBanks > 1
	ldr r0, displayed_bank
	cmp r1, r0
	beq .4
.endif

    ; Do main loop tick and draw. BOOM!
    bl main_loop

    .4:
    ldr pc, [sp], #4

; ============================================================================
; RasterMan stuff.
; ============================================================================

.if AppConfig_UseRasterCore
.include "lib/rastercore.asm"
.endif

; ============================================================================
; FX code modules.
; ============================================================================

.include "src/fx/scope.asm"
.include "src/fx/bits.asm"
.include "src/fx/outline-scroller.asm"

; ============================================================================
; Support library code modules used by the FX sequence.
; ============================================================================

.if _DEBUG || _CHECK_FRAME_DROP
.include "lib/palette.asm"
.endif
.include "lib/screen.asm"
.include "lib/outline-font.asm"
.include "lib/text-pool.asm"

; ============================================================================
; ArchieKlang generated code.
; ============================================================================

.if AppConfig_UseArchieKlang
.include "lib/archieklang.asm"
.endif
