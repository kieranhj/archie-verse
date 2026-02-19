; ============================================================================
; The actual sequence for the demo.
; NB. First tick of the script happens at init before music is started etc.
; ============================================================================

; TODO: Is this even needed for a music disk? Maybe the intro?

; ============================================================================

seq_django3:
    ; Setup.
    call_0      rasters_init
    call_0      vu_bars_init
    call_0      dj_scroller_init

    ; Palette.
    write_addr  palette_array_p,    seq_pal_logo

    ; Setup FX Layers.
    call_3      fx_set_layer_fns,   0, vu_bars_tick,        screen_cls
    call_3      fx_set_layer_fns,   1, check_autoplay,      logo_glitch_plot
    call_3      fx_set_layer_fns,   2, dj_scroller_tick,    dj_scroller_draw
    call_3      fx_set_layer_fns,   3, dj_menu_tick,        dj_menu_draw
    end_script



seq_pal_logo:
    .include "build/cd3-logo1.bin.asm"
