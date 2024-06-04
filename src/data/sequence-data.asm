; ============================================================================
; Sequence helper macros.
; ============================================================================

.macro on_pattern pattern_no, do_thing
    fork_and_wait_secs SeqConfig_PatternLength_Secs*\pattern_no, \do_thing
.endm

.macro wait_patterns pats
    wait_secs SeqConfig_PatternLength_Secs*\pats
.endm

.macro palette_lerp_over_secs palette_A, palette_B, secs
    math_make_var seq_palette_blend, 0.0, 1.0, math_clamp, 0.0, 1.0/(\secs*50.0)  ; seconds.
    math_make_palette seq_palette_id, \palette_A, \palette_B, seq_palette_blend, seq_palette_lerped
    write_addr palette_array_p, seq_palette_lerped
    fork_and_wait \secs*50.0-1, seq_unlink_palette_lerp
    ; NB. Subtract a frame to avoid race condition.
.endm

.macro rgb_lerp_over_secs rgb_addr, from_rgb, to_rgb, secs
    math_make_var seq_rgb_blend, 0.0, 1.0, math_clamp, 0.0, 1.0/(\secs*50.0)  ; 5 seconds.
    math_make_rgb \rgb_addr, \from_rgb, \to_rgb, seq_rgb_blend
.endm

; ============================================================================
; The actual sequence for the demo.
; ============================================================================

    ; Init FX modules.
    call_0 scope_init

    ; Screen setup.
    write_addr palette_array_p, seq_palette_red_additive

	; Setup layers of FX.
    call_3 fx_set_layer_fns, 0, 0,                          screen_cls_from_line
    call_3 fx_set_layer_fns, 1, 0,                          bits_draw_text
    call_3 fx_set_layer_fns, 2, scope_tick_with_history,    scope_draw_with_history
    call_3 fx_set_layer_fns, 3, 0,                          0

    ; Simple logo.
    fork seq_header

    ; Drive y pos from a sine fn.
    ;math_make_var bits_text_ypos, 0.0, 64.0, math_sin, 0.0, 1.0/200.0
    ;write_fp bits_text_ypos, 96.0
    write_fp scroll_text_y_pos, 4.0 ; NB. Must match mode9-screen.asm defines. :\
    write_addr scroller_speed, 4

    math_make_var scope_yscale, 0.5, 0.25, math_sin, 0.0, 1.0/400.0

seq_loop:
    ; Start!

    wait_secs 10.0
    ; Fade to B&W.
    palette_lerp_over_secs seq_palette_red_additive, seq_palette_all_white, 5.0

    wait_secs 10.0
    ; Fade to fire palette.
    palette_lerp_over_secs seq_palette_all_white, seq_palette_red_additive, 5.0

    ; Loop.
    fork seq_loop

    ; END HERE
    end_script

seq_header:
    write_addr bits_text_curr, 0            ; bitshifters
    wait_secs 2.5
    write_addr bits_text_curr, 1            ; alcatraz
    wait_secs 2.5
    write_addr bits_text_curr, 2            ; torment
    wait_secs 2.5
    write_addr bits_text_curr, 3            ; present
    wait_secs 2.5
    write_addr bits_text_curr, 4            ; ArchieKlang
    wait_secs 2.5
    write_addr bits_text_curr, 5            ; code
    wait_secs 2.5
    write_addr bits_text_curr, 6            ; kieran
    wait_secs 2.5
    write_addr bits_text_curr, 7            ; music
    wait_secs 2.5
    write_addr bits_text_curr, 8            ; Rhino
    wait_secs 2.5
    write_addr bits_text_curr, 9            ; samples & synth
    wait_secs 2.5
    write_addr bits_text_curr, 10           ; Virgill
    wait_secs 2.5

    ; Switch to scroller!
    call_3 fx_set_layer_fns, 1, scroller_tick,              scroller_draw
    end_script
    ;fork seq_header

; ============================================================================
; Support functions.
; ============================================================================

seq_unlink_palette_lerp:
    math_kill_var seq_palette_blend
    math_kill_var seq_palette_id
    end_script

; ============================================================================
; Sequence tasks can be forked and self-terminate on completion.
; Rather than have a task management system it just uses the existing script
; system and therefore supports any arbitrary sequence of fn calls.
;
;  Use 'yield <label>' to continue the script on the next frame from a given label.
;  Use 'end_script_if_zero <var>' to terminate a script conditionally.
;
; (Yes I know this is starting to head into 'real language' territory.)
;
; ==> NB. This example is now better done by using palette_lerp macros above.
; ============================================================================

.if 0
seq_test_fade_down:
    call_3 palette_init_fade, 0, 1, seq_palette_red_additive

seq_test_fade_down_loop:
    call_0 palette_update_fade_to_black
    end_script_if_zero palette_interp
    yield seq_test_fade_down_loop

seq_test_fade_up:
    call_3 palette_init_fade, 0, 1, seq_palette_red_additive

seq_test_fade_up_loop:
    call_0 palette_update_fade_from_black
    end_script_if_zero palette_interp
    yield seq_test_fade_up_loop
.endif

; ============================================================================
; Text.
; ============================================================================

; Font def, points size, point size height, text string, null terminated.
text_pool_defs_no_adr:
    TextDef homerton_bold_italic,   64, 64*1.5, 0xf, "BITSHIFTERS",     text_nums_no_adr+0  ; 0
    TextDef homerton_bold,          64, 64*1.5, 0xf, "ALCATRAZ",        text_nums_no_adr+4  ; 1
    TextDef trinity_bold,           72, 90*1.2, 0xf, "TORMENT",         text_nums_no_adr+8  ; 2
    TextDef homerton_bold,          72, 80*1.2, 0xf, "present",         text_nums_no_adr+12 ; 3
    TextDef homerton_bold,          80, 80*1.2, 0xf, "ArchieKlang",     text_nums_no_adr+16 ; 4
    TextDef homerton_bold,          48, 48*1.2, 0xf, "code",            text_nums_no_adr+20 ; 5
    TextDef homerton_bold,          48, 48*1.2, 0xf, "kieran",          text_nums_no_adr+24 ; 6
    TextDef homerton_bold,          48, 48*1.2, 0xf, "samples & synth", text_nums_no_adr+28 ; 7
    TextDef homerton_bold,          48, 48*1.2, 0xf, "Virgill",         text_nums_no_adr+32 ; 8
    TextDef homerton_bold,          48, 48*1.2, 0xf, "music",           text_nums_no_adr+36 ; 9
    TextDef homerton_bold,          48, 48*1.2, 0xf, "Rhino & Virgill", text_nums_no_adr+40 ; 10
.long -1

; ============================================================================
; Sequence specific data.
; ============================================================================

.if 0
math_emitter_config_1:
    math_const 50.0/80                                                  ; emission rate=80 particles per second fixed.
    math_func  0.0,    100.0,  math_sin,  0.0,   1.0/(MATHS_2PI*60.0)   ; emitter.pos.x = 100.0 * math.sin(f/60)
    math_func  128.0,  60.0,   math_cos,  0.0,   1.0/(MATHS_2PI*80.0)   ; emitter.pos.y = 128.0 + 60.0 * math.cos(f/80)
    math_func  0.0,    2.0,    math_sin,  0.0,   1.0/(MATHS_2PI*100.0)  ; emitter.dir.x = 2.0 * math.sin(f/100)
    math_func  1.0,    5.0,    math_rand, 0.0,   0.0                    ; emitter.dir.y = 1.0 + 5.0 * math.random()
    math_const 255                                                      ; emitter.life
    math_func  0.0,    1.0,    math_and15,0.0,   1.0                    ; emitter.colour = (emitter.colour + 1) & 15
    math_func  8.0,    6.0,    math_sin,  0.0,   1.0/(MATHS_2PI*10.0)   ; emitter.radius = 8.0 + 6 * math.sin(f/10)

math_emitter_config_2:
    math_const 50.0/80                                                  ; emission rate=80 particles per second fixed.
    math_const 0.0                                                      ; emitter.pos.x = 0
    math_const 0.0                                                      ; emitter.pos.y = 192.0
    math_func -1.0,    2.0,    math_rand,  0.0,  0.0                    ; emitter.dir.x = 4.0 + 3.0 * math.random()
    math_func  1.0,    3.0,    math_rand,  0.0,  0.0                    ; emitter.dir.y = 1.0 + 5.0 * math.random()
    math_const 512                                                      ; emitter.life
    math_func  0.0,    1.0,    math_and15, 0.0,  1.0                    ; emitter.colour = (emitter.colour + 1) & 15
    math_const 8.0                                                      ; emitter.radius = 8.0
.endif

; ============================================================================

seq_palette_red_additive:
    .long 0x00000000                    ; 00 = 0000 = black
    .long 0x00000020                    ; 01 = 0001 =
    .long 0x00000040                    ; 02 = 0010 =
    .long 0x00000060                    ; 03 = 0011 =
    .long 0x00000080                    ; 04 = 0100 =
    .long 0x000000a0                    ; 05 = 0101 =
    .long 0x000000c0                    ; 06 = 0110 =
    .long 0x000020e0                    ; 07 = 0111 = reds
    .long 0x000040e0                    ; 08 = 1000 =
    .long 0x000060e0                    ; 09 = 1001 =
    .long 0x000080e0                    ; 10 = 1010 =
    .long 0x0000a0e0                    ; 11 = 1011 =
    .long 0x0000c0e0                    ; 12 = 1100 =
    .long 0x0000d0e0                    ; 13 = 1101 =
    .long 0x00c0e0e0                    ; 14 = 1110 = oranges
    .long 0x00f0f0f0                    ; 15 = 1111 = white

seq_palette_all_black:
    .rept 16
    .long 0x00000000
    .endr

seq_palette_all_white:
    .rept 16
    .long 0x00ffffff
    .endr

seq_palette_lerped:
    .skip 15*4
    .long 0x00ffffff

; ============================================================================
; Sequence specific bss.
; ============================================================================

seq_rgb_blend:
    .long 0

seq_palette_blend:
    .long 0

seq_palette_id:
    .long 0

text_nums_no_adr:
    .skip 4*11

; ============================================================================
