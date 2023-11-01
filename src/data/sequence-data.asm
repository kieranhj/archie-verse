; ============================================================================
; The actual sequence for the demo.
; ============================================================================

    ; Register debug vars.
    debug_var vsync_count
    debug_var frame_counter
    debug_var music_pos
    debug_key RMKey_Space,      debug_toggle_main_loop_pause,  0
    debug_key RMKey_A,          debug_restart_sequence,        0
    debug_key RMKey_S,          debug_set_byte_true,           debug_main_loop_step
    debug_key RMKey_D,          debug_toggle_byte,             debug_show_info
    debug_key RMKey_R,          debug_toggle_byte,             debug_show_rasters
    debug_key RMKey_ArrowRight, debug_skip_to_next_pattern,    0

    ; Init QTM.
    call_swi QTM_VUBarControl,  AudioConfig_VuBars_Effect,     AudioConfig_VuBars_Gravity
    call_swi QTM_Stereo, 1,     AudioConfig_StereoPos_Ch1
    call_swi QTM_Stereo, 2,     AudioConfig_StereoPos_Ch2
    call_swi QTM_Stereo, 3,     AudioConfig_StereoPos_Ch3
    call_swi QTM_Stereo, 4,     AudioConfig_StereoPos_Ch4

    .if SeqConfig_EnableLoop
    call_swi QTM_MusicOptions, 0b0010, 0b0000
    .else
    call_swi QTM_MusicOptions, 0b0010, 0b0010
    .endif

    ; Init FX modules.
    call_0 new_emitter_init
    call_0 particles_init

    ; Make sprites.
    call_5 sprite_utils_mode9_make_table, temp_sprite_data, temp_sprite_ptrs_no_adr, 1, 8, temp_sprite_data_buffer_no_adr
    call_5 sprite_utils_mode9_make_table, temp_mask_data, temp_mask_ptrs_no_adr, 1, 8, temp_sprite_mask_buffer_no_adr

    ; Screen setup.
    call_3 palette_set_block, 0, 0, seq_palette_red_additive

	; Setup layers of FX.
    call_3 fx_set_layer_fns, 0, new_emitter_tick,       screen_cls
    call_3 fx_set_layer_fns, 1, 0,                      circles_reset_for_frame

    fork seq_loop
    end_script

seq_loop:
    write_addr particles_sprite_table_p, temp_sprite_ptrs_no_adr
    call_3 fx_set_layer_fns, 2, particles_tick_all,     particles_draw_all_as_8x8_additive
    call_3 fx_set_layer_fns, 3, 0,                      0

    wait_secs 5.0

    write_addr particles_sprite_table_p, temp_mask_ptrs_no_adr
    call_3 fx_set_layer_fns, 2, particles_tick_all,     particles_draw_all_as_8x8_tinted

    wait_secs 5.0

    call_3 fx_set_layer_fns, 2, particles_tick_all,     particles_draw_all_as_points
    wait_secs 5.0

    call_3 fx_set_layer_fns, 2, particles_tick_all,     particles_draw_all_as_circles
    call_3 fx_set_layer_fns, 3, 0,                      circles_plot_all

    wait_secs 5.0
    fork seq_loop

    ; THE END.
    end_script

; ============================================================================
; Sequence tasks?
; ============================================================================

; This would make a neverending tick call for 6 words.
; No method for removing this though..!
; Could extend script context to call a fn for N iterations.
; Ideally have some sort of goto <script ptr> command to avoid
; forking and using two script contexts for a loop.
; This wouldn't support the concept of self-terminating tick fns.
; E.g. remove tick when fade has completed.
; Background tasks spread over arbitrary frames, e.g. decompress.
seq_test_tick_fn:
    call_0 palette_update_fade_to_black
    fork_and_wait 1, seq_test_tick_fn
    end_script
    ; wait 1                    ; yield (effectively).
    ; goto seq_test_tick_fn     ; loop.

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
    .long 0x000000e0                    ; 07 = 0111 =
    .long 0x000020e0                    ; 08 = 1000 =
    .long 0x000040e0                    ; 09 = 1001 =
    .long 0x000060e0                    ; 10 = 1010 =
    .long 0x000080e0                    ; 11 = 1011 =
    .long 0x0000a0e0                    ; 12 = 1100 =
    .long 0x0000c0e0                    ; 13 = 1101 =
    .long 0x0000e0e0                    ; 14 = 1110 =
    .long 0x00e0e0e0                    ; 15 = 1111 =

; ============================================================================
; ============================================================================
