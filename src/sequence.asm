; ============================================================================
; The actual sequence for the demo.
; ============================================================================


seq_main_program:

    ; TODO: Setup music etc. here also?

    ; Init FX modules.
    call_0 init_3d_scene

	; Setup layers of FX.
    call_3 fx_set_layer_fns, 0, 0,     screen_cls
;    call_3 fx_set_layer_fns, 1, update_3d_scene,     anaglyph_draw_3d_scene
    call_3 fx_set_layer_fns, 1, 0,     width_plot_test

    ; THE END.
    end_script

    ; TODO: End demo or loop etc.
