; ============================================================================
; The actual sequence for the demo.
; ============================================================================

    ; Init QTM. NB: This could be in app.asm.
    call_swi QTM_VUBarControl, AudioConfig_VuBars_Effect, AudioConfig_VuBars_Gravity
    call_swi QTM_Stereo, 1, AudioConfig_StereoPos_Ch1
    call_swi QTM_Stereo, 2, AudioConfig_StereoPos_Ch2
    call_swi QTM_Stereo, 3, AudioConfig_StereoPos_Ch3
    call_swi QTM_Stereo, 4, AudioConfig_StereoPos_Ch4

    .if SeqConfig_EnableLoop
    call_swi QTM_MusicOptions, 0b0010, 0b0000
    .else
    call_swi QTM_MusicOptions, 0b0010, 0b0010
    .endif

    ; Init FX modules.
    call_0 math_emitter_init
    call_0 particles_init
    call_0 balls_init
    call_0 sprite_utils_init

    ; Make sprites.
    call_5 sprite_utils_make_table, additive_block_sprite, temp_sprite_ptrs_no_adr, 1, 8, additive_block_sprite_buffer_no_adr
    call_1 sprite_utils_make_shifted_sheet, block_sprite_sheet_def_no_adr

    ; Screen setup.
    call_3 palette_set_block, 0, 0, seq_palette_red_additive

	; Setup layers of FX.
    call_3 fx_set_layer_fns, 0, 0,                      screen_cls
    call_3 fx_set_layer_fns, 1, 0,                      0

.if 0
    ; Cube!
    write_addr scene3d_entity_p, cube_entity
    call_3 fx_set_layer_fns, 2, scene3d_rotate_entity,  scene3d_draw_entity_as_solid_quads
    call_3 fx_set_layer_fns, 3, 0,                          0

    wait_secs 10.0
    write_addr scene3d_entity_p, cobra_entity
    wait_secs 10.0
    write_addr scene3d_entity_p, cube_entity
    wait_secs 10.0
    write_addr scene3d_entity_p, cobra_entity
    wait_secs 10.0
.endif

    ; Balls!
    call_3 fx_set_layer_fns, 2, balls_tick_all,         balls_draw_all
    call_3 fx_set_layer_fns, 3, circles_reset_for_frame,circles_plot_all
    end_script

    wait_secs 10.0

    fork seq_loop
    end_script

; Particles!
seq_loop:
    call_3 fx_set_layer_fns, 1, math_emitter_tick_all   0
;    call_3 fx_set_layer_fns, 3, 0,                      0
    call_3 fx_set_layer_fns, 3, circles_reset_for_frame,circles_plot_all

    write_addr particles_sprite_def_p, block_sprite_sheet_def_no_adr
    call_3 fx_set_layer_fns, 2, particles_tick_all_with_circle_collider,     particles_draw_all_as_8x8_tinted
    wait_secs 10.0

.if 0
    write_addr particles_sprite_table_p, temp_sprite_ptrs_no_adr
    call_3 fx_set_layer_fns, 2, particles_tick_all_with_circle_collider,     particles_draw_all_as_8x8_additive
    wait_secs 10.0

    call_3 fx_set_layer_fns, 2, particles_tick_all_with_circle_collider,     particles_draw_all_as_points
    wait_secs 5.0

    call_3 fx_set_layer_fns, 2, particles_tick_all_with_circle_collider,     particles_draw_all_as_circles
    call_3 fx_set_layer_fns, 3, circles_reset_for_frame,circles_plot_all
    wait_secs 5.0
.endif

    fork seq_loop

    ; THE END.
    end_script

; ============================================================================
; Sequence tasks can be forked and self-terminate on completion.
; Rather than have a task management system it just uses the existing script
; system and therefore supports any arbitrary sequence of fn calls.
;
;  Use 'yield <label>' to continue the script on the next from a given label.
;  Use 'end_script_if_zero <var>' to terminate a script conditionally.
;
; (Yes I know this is starting to head into 'real language' territory.)
; ============================================================================

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

; ============================================================================
; Sequence specific data.
; ============================================================================

seq_palette_red_additive:
    .long 0x00000000                    ; 00 = 0000 = black
    .long 0x00000020                    ; 01 = 0001 =
    .long 0x00000040                    ; 02 = 0010 =
    .long 0x00000060                    ; 03 = 0011 =
    .long 0x00000080                    ; 04 = 0100 =
    .long 0x000000a0                    ; 05 = 0101 =
    .long 0x000000c0                    ; 06 = 0110 =
    .long 0x000000e0                    ; 07 = 0111 = reds
    .long 0x000020e0                    ; 08 = 1000 =
    .long 0x000040e0                    ; 09 = 1001 =
    .long 0x000060e0                    ; 10 = 1010 =
    .long 0x000080e0                    ; 11 = 1011 =
    .long 0x0000a0e0                    ; 12 = 1100 =
    .long 0x0000c0e0                    ; 13 = 1101 =
    .long 0x0000e0e0                    ; 14 = 1110 = oranges
    .long 0x00e0e0e0                    ; 15 = 1111 = white

block_sprite_sheet_def_no_adr:
    ; 8 sprites at 2 words (8 pixels) x 8 rows.
    SpriteSheetDef_Mode9 8, 1, 8, block_sprites_no_adr

; ============================================================================
; ============================================================================
