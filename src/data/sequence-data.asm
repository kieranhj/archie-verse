; ============================================================================
; The actual sequence for the demo.
; NB. First tick of the script happens at init before music is started etc.
; ============================================================================

; TODO: Put these in separate sequence files?

; ============================================================================


seq_acid_demo:

    ; Init FX modules.
    call_1      events_init,        events_data_no_adr  

    ; Event handlers.
    call_2      events_set_fns,     1, acid_event_set_palette
    call_2      events_set_fns,     2, acid_event_set_scale
    call_2      events_set_fns,     3, acid_event_set_lightdir

    ; Init 3D scene.
    ;                               RingRadius          CircleRadius        RingSegments   CircleSegments  MeshPtr                      Flags
    call_0      scene3d_init
    call_6      mesh_make_torus,    32.0*MATHS_CONST_1, 16.0*MATHS_CONST_1, 12,            8,              mesh_header_torus,           0x0 ; not flat inner
    call_6      mesh_make_torus,    32.0*MATHS_CONST_1, 16.0*MATHS_CONST_1, 12,            8,              mesh_header_torus_flipped,   0x2 ; flipped

    ; Setup FX Layers.
    call_3      fx_set_layer_fns,   0, scene3d_rotate_entity,           screen_cls
    call_3      fx_set_layer_fns,   1, acid_events_entity_tick,         0
    call_3      fx_set_layer_fns,   2, scene3d_bodge_torus_draw_order,  0                 ; Must come before transform.
    call_3      fx_set_layer_fns,   3, scene3d_transform_entity,        scene3d_draw_entity_as_solid_quads

    ; Palette.
    write_addr  palette_array_p,    seq_palette_red_additive

    ; Entity transform.
    write_vec3  torus_entity+Entity_Pos,    0.0, 0.0, 0.0
    write_vec3  torus_entity+Entity_Rot,    0.0, 0.0, 0.0
    write_fp    torus_entity+Entity_Scale,  1.0
    write_vec3  object_rot_speed,           0.5, 0.0, 1.0

    ; Scene setup.
    write_vec3  light_direction,            0.577, 0.577, -0.577

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
    call_3              palette_init_fade, 0, 1, seq_palette_red_additive

seq_test_fade_down_loop:
    call_0              palette_update_fade_to_black
    end_script_if_zero  palette_interp
    yield               seq_test_fade_down_loop
.endif

; ============================================================================
; Sequence specific data.
; ============================================================================

.equ AcidPalettes_MAX, 7

acid_palettes_table_no_adr:
    .long seq_palette_red_additive
    .long seq_palette_red_yellow
    .long seq_palette_green_white_ramp
    .long seq_palette_red_magenta_ramp
    .long seq_palette_blue_cyan_ramp
    .long seq_palette_grey
    .long gradient_default

.equ AcidLights_MAX, 7

acid_lights_table_no_adr:
    VECTOR3 0.577, 0.577, -0.577
    VECTOR3 1.0, 0.0, 0.0
    VECTOR3 -1.0, 0.0, 0.0
    VECTOR3 0.0, 1.0, 0.0
    VECTOR3 0.0, -1.0, 0.0
    VECTOR3 -0.577, -0.577, -0.577
    VECTOR3 0.0, 0.0, -1.0

; ============================================================================
; Colour palettes.
; ============================================================================

seq_palette_standard:
    osword_to_vidc 0x00000000, 0x000000f0, 0x0000f000, 0x0000f0f0, 0x00f00000, 0x00f000f0, 0x00f0f000, 0x00f0f0f0, 0x00000080, 0x00008000, 0x00008080, 0x00800000, 0x00800080, 0x00808000, 0x00808080, 0x00c0c0c0

seq_palette_red_additive:
    osword_to_vidc 0x00000000, 0x00000020, 0x00000040, 0x00000060, 0x00000080, 0x000000a0, 0x000000c0, 0x000020e0, 0x000040e0, 0x000060e0, 0x000080e0, 0x0000a0e0, 0x0000c0e0, 0x0000d0e0, 0x00c0e0e0, 0x00f0f0f0

seq_palette_grey:
    osword_to_vidc 0x00000000, 0x00101010, 0x00202020, 0x00303030, 0x00404040, 0x00505050, 0x00606060, 0x00707070, 0x00808080, 0x00909090, 0x00a0a0a0, 0x00b0b0b0, 0x00c0c0c0, 0x00d0d0d0, 0x00e0e0e0, 0x00f0f0f0

seq_palette_red_yellow:
    osword_to_vidc 0x00000000, 0x00001080, 0x00002080, 0x00003080, 0x00004080, 0x00005080, 0x00006080, 0x00007080, 0x000080a0, 0x000090b0, 0x0000a0c0, 0x0000b0d0, 0x0000c0e0, 0x0000d0f0, 0x0000e0f0, 0x00f0f0f0

seq_palette_green_white_ramp:
    osword_to_vidc 0x00000000, 0x00008000, 0x00108010, 0x00208020, 0x00308030, 0x00408040, 0x00509050, 0x0060a060, 0x0070b070, 0x0080c080, 0x0090d090, 0x00a0e0a0, 0x00b0e0b0, 0x00c0e0c0, 0x00d0e0d0, 0x00f0f0f0

seq_palette_red_magenta_ramp:
    osword_to_vidc 0x00000000, 0x00000080, 0x00100080, 0x00200080, 0x00300080, 0x00400080, 0x00500080, 0x00600080, 0x00700080, 0x00800080, 0x00900090, 0x008040a0, 0x007050b0, 0x006060c0, 0x005070d0, 0x00f0f0f0

seq_palette_blue_cyan_ramp:
    osword_to_vidc 0x00000000, 0x00a03000, 0x00a04000, 0x00a05000, 0x00a06000, 0x00b07000, 0x00b08000, 0x00c09000, 0x00c0a000, 0x00d0b020, 0x00d0c040, 0x00e0d060, 0x00e0e080, 0x00f0f0a0, 0x00f0f0c0, 0x00f0f0f0

seq_palette_all_black:
    vidc_palette 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000

seq_palette_all_white:
    vidc_palette 0xfff, 0xfff, 0xfff, 0xfff, 0xfff, 0xfff, 0xfff, 0xfff, 0xfff, 0xfff, 0xfff, 0xfff, 0xfff, 0xfff, 0xfff, 0xfff

; ============================================================================
; Or use https://gradient-blaster.grahambates.com/ by Gigabates to generate nice palettes!
; ============================================================================

; https://gradient-blaster.grahambates.com/?points=000@0,a61@8,fff@15&steps=16&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40
gradient_default:
	grad_to_vidc 0x000,0x100,0x110,0x310,0x421,0x530,0x740,0x950, 0xa61,0xb84,0xc86,0xda8,0xdb9,0xedb,0xfee,0xfff

; ============================================================================
; Palette blending - required if using palette_lerp_over_secs macro.
; ============================================================================

.if 0
seq_unlink_palette_lerp:
    write_fp      seq_palette_blend, 1.0
    destroy seq_palette_blend
    destroy seq_palette_id
    end_script

; Used as the destination palette for all fading operations.
seq_palette_lerped:
    vidc_palette 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000

; TODO: Maybe set these to a 'BAD' colour to check they are not used before being set?
seq_palette_copy:
    vidc_palette 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000

seq_rgb_blend:
    FLOAT_TO_FP 0.0

seq_palette_blend:
    FLOAT_TO_FP 0.0

seq_palette_id:
    .long 0
.endif

; ============================================================================
; Sequence specific bss.
; ============================================================================

; ============================================================================
