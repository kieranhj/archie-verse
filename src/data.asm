; ============================================================================
; DATA.
; ============================================================================

.data   ; TODO: Do we need an rodata segment?

.p2align 6

; ============================================================================

.include "lib/lib_data.asm"

; ============================================================================

.p2align 2
logo_data_no_adr:
.incbin "build/logo.bin"

.if 0
.p2align 2
logo_mask_no_adr:
.incbin "build/logo.bin.mask"
.endif

; ============================================================================

.if 0
.p2align 2
scroller_font_data_no_adr:
.incbin "build/big-font.bin"
.endif

; ============================================================================

.p2align 2
changing_waves_mod_no_adr:
.incbin "build/changing_waves.mod"

; ============================================================================

.if 0
.p2align 2
scroller_text_string_no_adr:
; Add 20 blank chars so that scroller begins on RHS of the screen, as per Amiga.
.byte "                    "
.include "src/scrolltxt-final.asm"
scroller_text_string_end_no_adr:
.p2align 2
.endif

; ============================================================================

.if 0
.p2align 6
dots_y_table_1_no_adr:
.incbin "data/dots_y_table_1.bin"
dots_y_table_1_end_no_adr:
.incbin "data/dots_y_table_1.bin"

dots_y_table_2_no_adr:
.incbin "data/dots_y_table_2.bin"
dots_y_table_2_end_no_adr:
.incbin "data/dots_y_table_2.bin"

; ============================================================================

.p2align 6
dot_tunnel_offset_x_no_adr:
    .incbin "data\dot_tunnel_x_offset.bin"

dot_tunnel_offset_y_no_adr:
    .incbin "data\dot_tunnel_y_offset.bin"

dot_tunnel_x_no_adr:
    .incbin "data\dot_tunnel_x.bin"

dot_tunnel_y_no_adr:
    .incbin "data\dot_tunnel_y.bin"
.endif
