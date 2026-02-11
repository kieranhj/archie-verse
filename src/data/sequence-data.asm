; ============================================================================
; The actual sequence for the demo.
; NB. First tick of the script happens at init before music is started etc.
; ============================================================================

; TODO: Is this even needed for a music disk? Maybe the intro?

; ============================================================================

seq_django3:
    ; Palette.
    write_addr  palette_array_p,    seq_pal_logo

    ; Setup FX Layers.
    call_3      fx_set_layer_fns,   0, 0,           screen_cls
    call_3      fx_set_layer_fns,   1, 0,           logo_glitch_plot
    end_script



seq_pal_logo:
    .include "build/cd3-logo1.bin.asm"
