; ============================================================================
; BSS Segment (Uninitialised data, not stored in the exe.)
; ============================================================================

.bss

; ============================================================================

sine_wave_table_no_adr:
    .skip SineScroller_TableSize*4

text_box_font_mode9_no_adr:
    .skip TextBox_MaxGlyphs * 4*8

text_screen_back_buffer_no_adr:
    .skip Screen_Bytes

; ============================================================================

.if AppConfig_UseArchieKlang
Generated_Samples_no_adr:
.skip AK_SMP_LEN
.p2align 2

AK_Temp_Buffer_no_adr:
.skip AK_TempBufferSize
.endif

; ============================================================================

.p2align 2
stack_no_adr:
    .skip AppConfig_StackSize
stack_base_no_adr:

; ============================================================================
; Palette buffers.
; ============================================================================

vidc_buffers_no_adr:
    .skip VideoConfig_ScreenBanks * 16 * 4

; ============================================================================
; Per FX BSS.
; ============================================================================

.if AppConfig_UseRasterMan
.p2align 2
vidc_table_1_no_adr:
	.skip 256*4*4 * 2

; TODO: Can we get rid of these?
vidc_table_2_no_adr:
	.skip 256*4*4

vidc_table_3_no_adr:
	.skip 256*8*4

memc_table_no_adr:
	.skip 256*2*4
.endif

; ============================================================================
; Library BSS (must come last)
; ============================================================================

.include "lib/lib_bss.asm"

; ============================================================================
