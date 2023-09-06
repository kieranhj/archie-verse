; ============================================================================
; The actual sequence for the demo.
; ============================================================================


seq_main_program:

    ; TODO: Setup music etc. here also?

    ; Init FX modules.
    call_0 init_3d_scene
    call_0 starfield_init

	; Setup layers of FX.
    call_3 fx_set_layer_fns, 0, 0,                   screen_cls

.if 0
.if 1
    call_3 fx_set_layer_fns, 1, static_set_palette,  static_copy_screen
    write_addr static_palette_p, hammer_pal_no_adr
    write_addr static_screen_p, hammer_screen_no_adr
    wait_secs 5.0
.endif
.if 0
    write_addr static_palette_p, cactus_pal_no_adr
    write_addr static_screen_p, cactus_screen_no_adr
    wait_secs 5.0

    write_addr static_palette_p, house_pal_no_adr
    write_addr static_screen_p, house_screen_no_adr
    wait_secs 5.0

    write_addr static_palette_p, persepolis_pal_no_adr
    write_addr static_screen_p, persepolis_screen_no_adr
    wait_secs 5.0
.endif

    call_0 set_palette_for_3d_scene
    fork effect_loop
.endif

    ; THE END.
    end_script

.if 0
effect_loop:

    write_addr object_dir_z, MATHS_CONST_1

    ; Set Cobra model.
    write_addr object_scale, MATHS_CONST_1*1.9
    write_addr object_num_verts, Model_Cobra_Num_Verts
    write_addr object_num_faces, Model_Cobra_Num_Faces
    write_addr object_verts_p, model_cobra_verts
    write_addr object_face_indices_p, model_cobra_face_indices
    write_addr object_edge_list_per_face_p, model_cobra_edges_per_face
    write_addr object_edge_indices_p, model_cobra_edge_indices

    call_3 fx_set_layer_fns, 1, update_3d_scene,     anaglyph_draw_3d_scene_as_wire
    wait_secs 10.0

    call_3 fx_set_layer_fns, 1, scene2d_update,      scene2d_draw_anaglyph
    wait_secs 10.0

    call_3 fx_set_layer_fns, 1, 0,     dots_draw_all
    wait_secs 20.0

    call_3 fx_set_layer_fns, 1, starfield_update,    starfield_draw_anaglyph
    wait_secs 10.0

    call_3 fx_set_layer_fns, 1, dot_tunnel_update,   dot_tunnel_draw_anaglyph_spiral
    wait_secs 10.0

    ; Set Cube model.
    ; TODO: call_subroutine sequence_set_cube_model etc.
    write_addr object_scale, MATHS_CONST_1
    write_addr object_num_verts, Model_Cube_Num_Verts
    write_addr object_num_faces, Model_Cube_Num_Faces
    write_addr object_verts_p, model_cube_verts
    write_addr object_face_indices_p, model_cube_face_indices
    write_addr object_edge_list_per_face_p, model_cube_edges_per_face
    write_addr object_edge_indices_p, model_cube_edge_indices

    call_3 fx_set_layer_fns, 1, update_3d_scene,     anaglyph_draw_3d_scene_as_circles
    wait_secs 10.0

    call_3 fx_set_layer_fns, 1, update_3d_scene,     anaglyph_draw_3d_scene_as_solid
    wait_secs 10.0

    fork effect_loop
    end_script
.endif

event_show_hammer:
    call_3 fx_set_layer_fns, 1, static_set_palette,  static_copy_screen
    write_addr static_palette_p, hammer_pal_no_adr
    write_addr static_screen_p, hammer_screen_no_adr
    end_script

event_set_default_palette:
    call_0 set_palette_for_3d_scene
    end_script

event_set_cobra:
    ; Set Cobra model.
    write_addr object_scale, MATHS_CONST_1*1.9
    write_addr object_num_verts, Model_Cobra_Num_Verts
    write_addr object_num_faces, Model_Cobra_Num_Faces
    write_addr object_verts_p, model_cobra_verts
    write_addr object_face_indices_p, model_cobra_face_indices
    write_addr object_edge_list_per_face_p, model_cobra_edges_per_face
    write_addr object_edge_indices_p, model_cobra_edge_indices
    end_script

event_show_wireframe:
    call_3 fx_set_layer_fns, 1, update_3d_scene,     anaglyph_draw_3d_scene_as_wire
    end_script

event_show_twist_squares:
    call_3 fx_set_layer_fns, 1, scene2d_update,      scene2d_draw_anaglyph
    end_script

event_show_y_sine_dots:
    call_3 fx_set_layer_fns, 1, 0,     dots_draw_all
    end_script

event_show_starfield:
    call_3 fx_set_layer_fns, 1, starfield_update,    starfield_draw_anaglyph
    end_script

event_show_dot_tunnel:
    call_3 fx_set_layer_fns, 1, dot_tunnel_update,   dot_tunnel_draw_anaglyph_spiral
    end_script

event_set_cube:
    write_addr object_scale, MATHS_CONST_1
    write_addr object_num_verts, Model_Cube_Num_Verts
    write_addr object_num_faces, Model_Cube_Num_Faces
    write_addr object_verts_p, model_cube_verts
    write_addr object_face_indices_p, model_cube_face_indices
    write_addr object_edge_list_per_face_p, model_cube_edges_per_face
    write_addr object_edge_indices_p, model_cube_edge_indices
    end_script

event_show_circles:
    call_3 fx_set_layer_fns, 1, update_3d_scene,     anaglyph_draw_3d_scene_as_circles
    end_script

event_show_solid:
    call_3 fx_set_layer_fns, 1, update_3d_scene,     anaglyph_draw_3d_scene_as_solid
    end_script
