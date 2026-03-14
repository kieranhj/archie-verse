; ============================================================================
; The actual sequence for the demo.
; NB. First tick of the script happens at init before music is started etc.
; ============================================================================

; TODO: Is this even needed for a music disk? Maybe the intro?

; ============================================================================

seq_django3:
    ; Setup.
.if AppConfig_UsingRasterMan
    call_0      rasters_init
    call_3      rasters_abc_pal_to_rasters, dj_logo_raster_pal_no_adr, 0, 74
.endif
    call_0      vu_bars_init
    call_0      dj_scroller_init

    ; Setup FX Layers.
    call_3      fx_set_layer_fns,   0, vu_bars_tick,        screen_cls
    call_3      fx_set_layer_fns,   1, check_autoplay,      logo_glitch_plot
    call_3      fx_set_layer_fns,   2, dj_scroller_tick,    dj_scroller_draw
    call_3      fx_set_layer_fns,   3, dj_menu_tick,        dj_menu_draw

    wait 1      ; Stop here after init.
    wait 1      ; Draw one frame.

    ; Don't need to draw all layers.
    call_3      fx_set_layer_fns,   0, vu_bars_tick,        dj_scroller_cls
.if Dj_Menu_Use_Rasters
    call_3      fx_set_layer_fns,   3, dj_menu_tick,        dj_menu_update_rasters
.endif

    gosub seq_wait_for_quit

    call_3      fx_set_layer_fns,   0, 0,                   dj_scroller_cls
    call_3      fx_set_layer_fns,   1, 0,                   logo_glitch_plot
    call_3      fx_set_layer_fns,   2, dj_scroller_tick,    dj_scroller_draw
    call_3      fx_set_layer_fns,   3, rasters_sub_all_to_zero, 0   

    wait 32
    end_script

seq_wait_for_quit:
    end_script_if_zero dj_menu_still_playing
    yield seq_wait_for_quit
