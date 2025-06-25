; ============================================================================
; Sequence helper macros.
; TODO: Nice detailed descriptions of how to use each MACRO.
; ============================================================================

; ============================================================================
; Synchronise timing with MOD.
; ============================================================================

.macro on_pattern pattern_no, do_thing
    fork_and_wait_secs SeqConfig_PatternLength_Secs*\pattern_no, \do_thing
.endm

.macro wait_patterns pats
    wait_secs SeqConfig_PatternLength_Secs*\pats
.endm

; ============================================================================
; Palette blending operations.
; ============================================================================

; LERP a single RGB value.
.macro rgb_lerp_over_secs rgb_addr, from_rgb, to_rgb, secs
    math_make_var seq_rgb_blend, 0.0, 1.0, math_clamp, 0.0, 1.0/(\secs*50.0)  ; 5 seconds.
    math_make_rgb \rgb_addr, \from_rgb, \to_rgb, seq_rgb_blend
.endm

; LERP an entire 16 entry palette.
.macro palette_lerp_over_secs palette_A, palette_B, secs
    math_make_var seq_palette_blend, 0.0, 1.0, math_clamp, 0.0, 1.0/(\secs*50.0)  ; seconds.
    math_make_palette seq_palette_id, \palette_A, \palette_B, seq_palette_blend, seq_palette_lerped
    write_addr palette_array_p, seq_palette_lerped
    fork_and_wait \secs*50.0-1, seq_unlink_palette_lerp
    ; NB. Subtract a frame to avoid race condition.
.endm

; LERP a palette from the palette used for a previous LERP.
.macro palette_lerp_from_existing palette_B, secs
    palette_copy seq_palette_lerped, seq_palette_copy
    palette_lerp_over_secs seq_palette_copy, \palette_B, \secs
.endm

; Fade up a palette that is assumed to be a brightness gradient.
.macro gradient_fade_up_over_secs palette_B, secs
    ; Create a variable: offset = -15.0 + 15.0 * clamp(i/2.0*50.0) ; lerp over 2.0 secs
    math_make_var seq_palette_blend,    -15.0, 15.0, math_clamp, 0.0,  1.0/(\secs*50.0)
    ; RGB[d][i] = RGB[a][i+c]
    call_7      math_var_register_ex, seq_palette_id, \palette_B, 0, seq_palette_blend, seq_palette_lerped, 0, math_evaluate_palette_offset    
    write_addr palette_array_p, seq_palette_lerped
    ;fork_and_wait \secs*50.0-1, seq_unlink_palette_lerp
    ; NB. Subtract a frame to avoid race condition.
.endm

; Fade down a palette that is assumed to be a brightness gradient.
.macro gradient_fade_down_over_secs palette_A, secs
    ; Create a variable: offset = -15.0 + 15.0 * clamp(i/2.0*50.0) ; lerp over 2.0 secs
    math_make_var seq_palette_blend,    0.0, -15.0, math_clamp, 0.0,  1.0/(\secs*50.0)
    ; RGB[d][i] = RGB[a][i+c]
    call_7      math_var_register_ex, seq_palette_id, \palette_A, 0, seq_palette_blend, seq_palette_lerped, 0, math_evaluate_palette_offset    
    write_addr palette_array_p, seq_palette_lerped
    ;fork_and_wait \secs*50.0-1, seq_unlink_palette_lerp
    ; NB. Subtract a frame to avoid race condition.
.endm

; Copy a palette block of 16 words.
.macro palette_copy palette_src, palette_dst
    call_3 mem_copy_words, \palette_src, \palette_dst, 16
.endm

; ============================================================================
; MACROs to declare palettes from various formats to our VIDC reg format.
; ============================================================================

; Converts 16 values in 0x0RGB format (e.g. from Gradient Blaster) to 
; VIDC reg format = index << 26 | 0xBGR
.macro grad_to_vidc col0, col1, col2, col3, col4, col5, col6, col7, col8, col9, col10, col11, col12, col13, col14, col15
    .long 0<<26 | (\col0&0x00f)<<8 | (\col0&0x0f0) | (\col0&0xf00)>>8
    .long 1<<26 | (\col1&0x00f)<<8 | (\col1&0x0f0) | (\col1&0xf00)>>8
    .long 2<<26 | (\col2&0x00f)<<8 | (\col2&0x0f0) | (\col2&0xf00)>>8
    .long 3<<26 | (\col3&0x00f)<<8 | (\col3&0x0f0) | (\col3&0xf00)>>8
    .long 4<<26 | (\col4&0x00f)<<8 | (\col4&0x0f0) | (\col4&0xf00)>>8
    .long 5<<26 | (\col5&0x00f)<<8 | (\col5&0x0f0) | (\col5&0xf00)>>8
    .long 6<<26 | (\col6&0x00f)<<8 | (\col6&0x0f0) | (\col6&0xf00)>>8
    .long 7<<26 | (\col7&0x00f)<<8 | (\col7&0x0f0) | (\col7&0xf00)>>8
    .long 8<<26 | (\col8&0x00f)<<8 | (\col8&0x0f0) | (\col8&0xf00)>>8
    .long 9<<26 | (\col9&0x00f)<<8 | (\col9&0x0f0) | (\col9&0xf00)>>8
    .long 10<<26 | (\col10&0x00f)<<8 | (\col10&0x0f0) | (\col10&0xf00)>>8
    .long 11<<26 | (\col11&0x00f)<<8 | (\col11&0x0f0) | (\col11&0xf00)>>8
    .long 12<<26 | (\col12&0x00f)<<8 | (\col12&0x0f0) | (\col12&0xf00)>>8
    .long 13<<26 | (\col13&0x00f)<<8 | (\col13&0x0f0) | (\col13&0xf00)>>8
    .long 14<<26 | (\col14&0x00f)<<8 | (\col14&0x0f0) | (\col14&0xf00)>>8
    .long 15<<26 | (\col15&0x00f)<<8 | (\col15&0x0f0) | (\col15&0xf00)>>8
.endm

; Converts 16 values in 0x00BbGgRr format (used in OS_Word) to
; VIDC reg format = index << 26 | 0xBGR
.macro osword_to_vidc col0, col1, col2, col3, col4, col5, col6, col7, col8, col9, col10, col11, col12, col13, col14, col15
    .long  0<<26 | (\col0&0xf00000)>>12  | (\col0&0x00f000)>>8  | (\col0&0x0000f0)>>4
    .long  1<<26 | (\col1&0xf00000)>>12  | (\col1&0x00f000)>>8  | (\col1&0x0000f0)>>4
    .long  2<<26 | (\col2&0xf00000)>>12  | (\col2&0x00f000)>>8  | (\col2&0x0000f0)>>4
    .long  3<<26 | (\col3&0xf00000)>>12  | (\col3&0x00f000)>>8  | (\col3&0x0000f0)>>4
    .long  4<<26 | (\col4&0xf00000)>>12  | (\col4&0x00f000)>>8  | (\col4&0x0000f0)>>4
    .long  5<<26 | (\col5&0xf00000)>>12  | (\col5&0x00f000)>>8  | (\col5&0x0000f0)>>4
    .long  6<<26 | (\col6&0xf00000)>>12  | (\col6&0x00f000)>>8  | (\col6&0x0000f0)>>4
    .long  7<<26 | (\col7&0xf00000)>>12  | (\col7&0x00f000)>>8  | (\col7&0x0000f0)>>4
    .long  8<<26 | (\col8&0xf00000)>>12  | (\col8&0x00f000)>>8  | (\col8&0x0000f0)>>4
    .long  9<<26 | (\col9&0xf00000)>>12  | (\col9&0x00f000)>>8  | (\col9&0x0000f0)>>4
    .long 10<<26 | (\col10&0xf00000)>>12 | (\col10&0x00f000)>>8 | (\col10&0x0000f0)>>4
    .long 11<<26 | (\col11&0xf00000)>>12 | (\col11&0x00f000)>>8 | (\col11&0x0000f0)>>4
    .long 12<<26 | (\col12&0xf00000)>>12 | (\col12&0x00f000)>>8 | (\col12&0x0000f0)>>4
    .long 13<<26 | (\col13&0xf00000)>>12 | (\col13&0x00f000)>>8 | (\col13&0x0000f0)>>4
    .long 14<<26 | (\col14&0xf00000)>>12 | (\col14&0x00f000)>>8 | (\col14&0x0000f0)>>4
    .long 15<<26 | (\col15&0xf00000)>>12 | (\col15&0x00f000)>>8 | (\col15&0x0000f0)>>4
.endm

; Converts 16 values in 0x0BGR format (used in VIDC regs) to
; VIDC reg format = index << 26 | 0xBGR
.macro vidc_palette col0, col1, col2, col3, col4, col5, col6, col7, col8, col9, col10, col11, col12, col13, col14, col15
    .long 0<<26 | \col0
    .long 1<<26 | \col1
    .long 2<<26 | \col2
    .long 3<<26 | \col3
    .long 4<<26 | \col4
    .long 5<<26 | \col5
    .long 6<<26 | \col6
    .long 7<<26 | \col7
    .long 8<<26 | \col8
    .long 9<<26 | \col9
    .long 10<<26 | \col10
    .long 11<<26 | \col11
    .long 12<<26 | \col12
    .long 13<<26 | \col13
    .long 14<<26 | \col14
    .long 15<<26 | \col15
.endm

; ============================================================================
