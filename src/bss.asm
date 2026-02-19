; ============================================================================
; BSS Segment (Uninitialised data, not stored in the exe.)
; Hack as necessary per prod.
; ============================================================================

.bss

; ============================================================================
; Dj Scroller

dj_scroller_font_data_shifted_no_adr:
	.skip Dj_Scroller_Max_Glyphs * Dj_Scroller_Glyph_Height * 12 * 8

; ============================================================================
; Dj Font

dj_font_map_no_adr:
	.skip 256			; maps ASCII to small font glyph no.

; ============================================================================
; Dj Menu

dj_menu_sprite_buffer_no_adr:
	.skip 20 * 4 * Dj_Font_GlyphHeight * Dj_Menu_MaxSprites ; 20 chars * 4 bytes * 5 rows * 15 strings * 2 versions.

dj_menu_sprite_code_pointers_no_adr:
	.skip Dj_Menu_MaxSpriteStride * 4

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

.if AppConfig_UsingRasterMan
.p2align 2
vidc_table_1_no_adr:
	.skip 256*4*4       ; 4 regs per scanline.
    ; TODO: Define the buffer size somewhere related to the code that fills it.

;memc_table_no_adr:
;    .skip 256*2*4       ; 2 regs per scaline.
.endif

; ============================================================================
; Library BSS (must come last)
; ============================================================================

.include "lib/lib_bss.asm"

; ============================================================================
