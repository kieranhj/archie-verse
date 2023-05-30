; ============================================================================
; BSS.
; ============================================================================

.bss

.p2align 6

; ============================================================================

stack_no_adr:
    .skip 1024
stack_base_no_adr:

; ============================================================================

scroller_font_data_shifted_no_adr:
	.skip Scroller_Max_Glyphs * Scroller_Glyph_Height * 12 * 8

; ============================================================================

logo_data_shifted_no_adr:
	.skip Logo_Bytes * 7

logo_mask_shifted_no_adr:
	.skip Logo_Bytes * 7

; ============================================================================

.p2align 6
check_rows_pixel_0_no_adr:
	.skip Rows_Width_Bytes * Check_Num_Depths

.p2align 6
check_rows_pixel_1_no_adr:
	.skip Rows_Width_Bytes * Check_Num_Depths

.p2align 6
check_rows_pixel_2_no_adr:
	.skip Rows_Width_Bytes * Check_Num_Depths

.p2align 6
check_rows_pixel_3_no_adr:
	.skip Rows_Width_Bytes * Check_Num_Depths

.p2align 6
check_rows_pixel_4_no_adr:
	.skip Rows_Width_Bytes * Check_Num_Depths

.p2align 6
check_rows_pixel_5_no_adr:
	.skip Rows_Width_Bytes * Check_Num_Depths

.p2align 6
check_rows_pixel_6_no_adr:
	.skip Rows_Width_Bytes * Check_Num_Depths

.p2align 6
check_rows_pixel_7_no_adr:
	.skip Rows_Width_Bytes * Check_Num_Depths

.p2align 6
check_bitplane_0_line_combos_no_adr:
	.skip Screen_Stride * Check_Line_Combos

.p2align 6
check_bitplane_1_line_combos_no_adr:
	.skip Screen_Stride * Check_Line_Combos

.if check_bitplane_1_line_combos_no_adr - check_bitplane_0_line_combos_no_adr != Screen_Stride * Check_Line_Combos
.error "Expected check_line_combos_PF_no_adr to be immediately after check_line_combos_no_adr."
.endif

.p2align 6
check_scanline_bitmask_no_adr:
	.skip Screen_Height * 4

.p2align 6
check_depths_dx_no_adr:
	.skip Check_Num_Depths * 4

; ============================================================================

.include "lib/lib_bss.asm"

; ============================================================================
