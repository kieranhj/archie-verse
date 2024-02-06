; ============================================================================
; The actual sequence for the demo.
; ============================================================================

    ; Init FX modules.
    call_0 math_emitter_init
    call_0 particles_init
    call_0 balls_init
    call_0 sprite_utils_init
    call_0 the_ball_init

    ; Make sprites.
    call_5 sprite_utils_make_table, additive_block_sprite, temp_sprite_ptrs_no_adr, 1, 8, additive_block_sprite_buffer_no_adr
    call_1 sprite_utils_make_shifted_sheet, block_sprite_sheet_def_no_adr

    ; Screen setup.

	; Setup layers of FX.
    call_3 fx_set_layer_fns, 0, 0,                          screen_cls
    ;
    call_3 fx_set_layer_fns, 2, the_ball_tick,              the_ball_draw
    call_3 fx_set_layer_fns, 3, 0,                          circles_plot_all_in_order

    write_fp particle_grid_gloop_factor,    0.99            ; 0.0=won't move, 1.0=won't return, higher is slower.
    write_fp particle_grid_collider_radius, 48.0            ;
    write_fp particle_grid_dave_maxpush,    1.21            ; displacement radius multiplier

    ; Call each part in turn.

seq_loop:
    call_3 palette_set_block, 0, 0, seq_palette_green_white_ramp
    gosub seq_part4
    gosub seq_part1

    call_3 palette_set_block, 0, 0, seq_palette_black_on_white
    gosub seq_part2

    call_3 palette_set_block, 0, 0, seq_palette_red_additive
    gosub seq_part3

    yield seq_loop
    end_script

; Ball moves in a spiral through the particle grid.
seq_part1:

.if 0
    ; Make particle grid.
    ; X [-138, 138] step 12 (border 22)
    ; Y [26,   230] step 12 (border 26)
    call_6 particle_grid_make, 24, 18, MATHS_CONST_1*-138.0, MATHS_CONST_1*-102.0, MATHS_CONST_1*12.0, MATHS_CONST_1*12.0

	; Setup layers of FX.
    call_3 fx_set_layer_fns, 1, particle_grid_tick_all_dave_equation,    particle_grid_draw_all_as_points
.else
    call_6 particle_grid_make, 22, 16, MATHS_CONST_1*-147.0, MATHS_CONST_1*-105.0, MATHS_CONST_1*14.0, MATHS_CONST_1*14.0
    write_addr particle_grid_sprite_def_p, block_sprite_sheet_def_no_adr
    call_3 fx_set_layer_fns, 1, particle_grid_tick_all_dave_equation,    particle_grid_draw_all_as_2x2_tinted
.endif

    ; Setup the ball.
    call_2f the_env_set_constant_force, 0.0, 0.0    ; zero gravity
    call_2f the_ball_set_pos, 0.0, 0.0              ; centre ball
    call_2f the_ball_set_vel, 0.0, 0.0

    ; Make the ball the particle grid collider.
    ; particle_grid_collider_pos.x = the_ball.x
    ; particle_grid_collider_pos.y = the_ball.y
    math_link_vars particle_grid_collider_pos+0, 0.0, 1.0, the_ball_block+TheBall_x
    math_link_vars particle_grid_collider_pos+4, 0.0, 1.0, the_ball_block+TheBall_y

    ; Equation of the ball.
    ; x=radius * sin(t/speed)
    ; y=128 + radius * cos(t/speed)
    ; Where radius = t/speed as well.
    ; ~20 seconds to get to max radius 100. 1000/speed=100;speed=10.

    ; radius = i/10
    math_register_var seq_ball_radius, 0.0, 1.0, math_no_func, 0.0, 1.0/15.0

    ; Want this to be the radius value -----------------------v
    math_register_var2 the_ball_block+TheBall_x,   0.0, seq_ball_radius, math_sin, 0.0, 1.0/(MATHS_2PI*50.0)
    math_register_var2 the_ball_block+TheBall_y,   0.0, seq_ball_radius, math_cos, 0.0, 1.0/(MATHS_2PI*50.0)

    wait_secs 30.0

    math_unregister_var the_ball_block+TheBall_x
    math_unregister_var the_ball_block+TheBall_y
    math_unregister_var seq_ball_radius

    call_2f the_ball_set_pos, 300.0, 0.0
    wait_secs 2.0
    math_unlink_vars particle_grid_collider_pos+0
    math_unlink_vars particle_grid_collider_pos+4
    end_script

seq_ball_radius:
    .long 0

; Ball moves in a spiral through the particle grid.
seq_part2:

.if 0
    ; Make particle grid.
    ; X [-138, 138] step 12 (border 22)
    ; Y [26,   230] step 12 (border 26)
    call_6 particle_grid_make, 24, 18, MATHS_CONST_1*-138.0, MATHS_CONST_1*-102.0, MATHS_CONST_1*12.0, MATHS_CONST_1*12.0

	; Setup layers of FX.
    call_3 fx_set_layer_fns, 1, particle_grid_tick_all_dave_equation,    particle_grid_draw_all_as_points
.else
    call_6 particle_grid_make, 22, 16, MATHS_CONST_1*-147.0, MATHS_CONST_1*-105.0, MATHS_CONST_1*14.0, MATHS_CONST_1*14.0
    write_addr particle_grid_sprite_def_p, block_sprite_sheet_def_no_adr
    call_3 fx_set_layer_fns, 1, particle_grid_tick_all_dave_equation,    particle_grid_draw_all_as_2x2_tinted
.endif

    ; Setup the ball.
    call_2f the_env_set_constant_force, 0.0, 0.0    ; zero gravity
    call_2f the_ball_set_pos, 0.0, 0.0              ; centre ball
    call_2f the_ball_set_vel, 0.0, 0.0

    ; Make the ball the particle grid collider but inverted!
    ; particle_grid_collider_pos.x = -the_ball.x
    ; particle_grid_collider_pos.y = -the_ball.y

    ; Inverted (part2)
    math_link_vars particle_grid_collider_pos+0,   0.0, -1.0, the_ball_block+TheBall_x
    math_link_vars particle_grid_collider_pos+4,   0.0, -1.0, the_ball_block+TheBall_y

    ; radius = i/10
    math_register_var seq_ball_radius, 0.0, 1.0, math_no_func, 0.0, 1.0/15.0

    ; Want this to be the radius value -----------------------v
    math_register_var2 the_ball_block+TheBall_x,   0.0, seq_ball_radius, math_sin, 0.0, 1.0/(MATHS_2PI*50.0)
    math_register_var2 the_ball_block+TheBall_y,   0.0, seq_ball_radius, math_cos, 0.0, 1.0/(MATHS_2PI*50.0)

    wait_secs 30.0

    math_unregister_var the_ball_block+TheBall_x
    math_unregister_var the_ball_block+TheBall_y
    math_unregister_var seq_ball_radius

    call_2f the_ball_set_pos, 300.0, 0.0
    wait_secs 2.0
    math_unlink_vars particle_grid_collider_pos+0
    math_unlink_vars particle_grid_collider_pos+4
    end_script

; Ball moves in straight lines through the particle grid.
seq_part3:

.if 0
    ; Make particle grid.
    ; X [-138, 138] step 12 (border 22)
    ; Y [26,   230] step 12 (border 26)
    call_6 particle_grid_make, 24, 18, MATHS_CONST_1*-138.0, MATHS_CONST_1*-102.0, MATHS_CONST_1*12.0, MATHS_CONST_1*12.0

	; Setup layers of FX.
    call_3 fx_set_layer_fns, 1, particle_grid_tick_all_dave_equation,    particle_grid_draw_all_as_points
.else
    call_6 particle_grid_make, 22, 16, MATHS_CONST_1*-147.0, MATHS_CONST_1*-105.0, MATHS_CONST_1*14.0, MATHS_CONST_1*14.0
    write_addr particle_grid_sprite_def_p, block_sprite_sheet_def_no_adr
    call_3 fx_set_layer_fns, 1, particle_grid_tick_all_dave_equation,    particle_grid_draw_all_as_2x2_tinted
.endif

    ; Setup the ball.
    call_2f the_env_set_constant_force, 0.0, 0.0    ; zero gravity

    ; Connect the ball to the particle grid collider.
    math_link_vars particle_grid_collider_pos+0, 0.0, 1.0, the_ball_block+TheBall_x
    math_link_vars particle_grid_collider_pos+4, 0.0, 1.0, the_ball_block+TheBall_y

    ; Start off right side of the screen and move left.
    call_2f the_ball_set_pos, 200.0,-80.0
    call_2f the_ball_set_vel,  -2.0, 0.0
    wait_secs 5.0

    ; Top and move down.
    call_2f the_ball_set_pos, -138.0, 160.0
    call_2f the_ball_set_vel,  0.0, -2.0
    wait_secs 5.0

    ; Bottom and move up.
    call_2f the_ball_set_pos, 64.0, -160.0
    call_2f the_ball_set_vel,  0.0, 2.0
    wait_secs 5.0

    ; Right and move left again.
    call_2f the_ball_set_pos, 200.0, 44.0
    call_2f the_ball_set_vel,  -2.0, 0.0
    wait_secs 5.0

    ; Left and move right again.
    call_2f the_ball_set_pos, -200.0, -80.0
    call_2f the_ball_set_vel,  2.0, 0.0
    wait_secs 5.0

    ; Bottom and move up.
    call_2f the_ball_set_pos, -48.0, -160.0
    call_2f the_ball_set_vel,  0.0, 2.0
    wait_secs 5.0

    ; Top and move down.
    call_2f the_ball_set_pos, 64.0, 160.0
    call_2f the_ball_set_vel,  0.0, -2.0
    wait_secs 5.0

    ; Right and move left again.
    call_2f the_ball_set_pos, 200.0, -32.0
    call_2f the_ball_set_vel,  -2.0, 0.0
    wait_secs 5.0

    ; Left and move right again.
    call_2f the_ball_set_pos, -200.0, 10.0
    call_2f the_ball_set_vel,  2.0, 0.0
    wait_secs 5.0

    ; Right and move left again.
    call_2f the_ball_set_pos, 200.0, -64.0
    call_2f the_ball_set_vel,  -2.0, 0.0
    wait_secs 5.0

    ; Top and move down.
    call_2f the_ball_set_pos, -64.0, 160.0
    call_2f the_ball_set_vel,  0.0, -2.0
    wait_secs 3.0

    ; Settle.
    call_2f the_ball_set_vel,  0.0, 0.0
    wait_secs 3.0

    math_unlink_vars particle_grid_collider_pos+0
    math_unlink_vars particle_grid_collider_pos+4

    end_script

; Ball drops under gravity etc.
seq_part4:

    ; Make particle grid.
    ; X [-138, 138] step 12 (border 22)
    ; Y [26,   230] step 12 (border 26)
    call_6 particle_grid_make, 22, 16, MATHS_CONST_1*-147.0, MATHS_CONST_1*-105.0, MATHS_CONST_1*14.0, MATHS_CONST_1*14.0
     
    ;call_6 particle_grid_make_spiral, 400, MATHS_CONST_1*5.0, MATHS_CONST_1*1.0, MATHS_CONST_1*0.5, MATHS_CONST_1*0.0, MATHS_CONST_1*128.0

	; Setup layers of FX.
    call_3 fx_set_layer_fns, 1, particle_grid_tick_all_dave_equation,    particle_grid_draw_all_as_points

    ; Sprite version.
    write_addr particle_grid_sprite_def_p, block_sprite_sheet_def_no_adr
;    call_3 fx_set_layer_fns, 1, particle_grid_tick_all_dave_equation,    particle_grid_draw_all_as_2x2_tinted

    ; Environment setup.
    ;make_and_add_env_plane the_env_floor_plane, 0.0, 0.0, 0.0
    make_and_add_env_plane the_env_left_plane, -240.0, -128.0, 64.0        ; +90 degrees
    make_and_add_env_plane the_env_left_slope, -80.0, -128.0, 32.0         ; +45 degrees
    make_and_add_env_plane the_env_right_plane, 200.0, -128.0, -64.0       ; -90 degrees
    make_and_add_env_plane the_env_right_slope, 80.0, -128.0, -32.0        ; -45 degrees

    ; Setup the ball.
    call_2f the_env_set_constant_force  0.0, -(0.2/50.0)
    call_2f the_ball_set_pos, 80.0, 128.0            ; centre ball
    call_2f the_ball_set_vel,  0.0, 0.0

    ; Make the ball the particle grid collider.
    ; particle_grid_collider_pos.x = the_ball.x
    ; particle_grid_collider_pos.y = the_ball.y
    math_link_vars particle_grid_collider_pos+0, 0.0, 1.0, the_ball_block+TheBall_x
    math_link_vars particle_grid_collider_pos+4, 0.0, 1.0, the_ball_block+TheBall_y

    wait_secs 30.0

    ;call_1 the_env_remove_plane, the_env_floor_plane
    call_1 the_env_remove_plane, the_env_left_plane
    call_1 the_env_remove_plane, the_env_left_slope
    call_1 the_env_remove_plane, the_env_right_plane
    call_1 the_env_remove_plane, the_env_right_slope

    ; Settle.
    wait_secs 2.0

    call_2f the_ball_set_pos, 200.0, 0.0
    call_2f the_ball_set_vel, 0.0, 0.0
    call_2f the_env_set_constant_force, 0.0, 0.0    ; zero gravity

    math_unlink_vars particle_grid_collider_pos+0
    math_unlink_vars particle_grid_collider_pos+4
    end_script


; Particles examples!
.if 0
seq_loop:
    call_3 fx_set_layer_fns, 0, math_emitter_tick_all               screen_cls

    write_addr particles_sprite_def_p, block_sprite_sheet_def_no_adr
    call_3 fx_set_layer_fns, 1, particles_tick_all_under_gravity,     particles_draw_all_as_8x8_tinted
    wait_secs 5.0

    write_addr particles_sprite_table_p, temp_sprite_ptrs_no_adr
    call_3 fx_set_layer_fns, 1, particles_tick_all_under_gravity,     particles_draw_all_as_8x8_additive
    wait_secs 5.0

    call_3 fx_set_layer_fns, 1, particles_tick_all_under_gravity,     particles_draw_all_as_points
    wait_secs 5.0

;    call_3 fx_set_layer_fns, 1, particles_tick_all_under_gravity,     particles_draw_all_as_circles
;    wait_secs 5.0

;    call_1 the_env_remove_plane the_env_floor_plane
    math_unregister_var                  the_ball_block+TheBall_x
    call_2f the_ball_set_vel,            0.0, 0.0
    call_2f the_ball_add_impulse,        1.0, 1.0
    call_2f the_env_set_constant_force,  0.0, -(Ball_Gravity/50.0)

    fork seq_loop

    ; THE END.
    end_script
.endif

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

.if 0
    ; Balls!
    call_3 fx_set_layer_fns, 2, balls_tick_all,         balls_draw_all
    call_3 fx_set_layer_fns, 3, 0,                      circles_plot_all
    wait_secs 10.0
.endif

; ============================================================================
; Sequence specific data.
; ============================================================================

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

math_emitter_config_3:  ; attached to the_ball.
    math_const 50.0/50                                                  ; emission rate=80 particles per second fixed.
    math_func_read_addr 0.0, 1.0, the_ball_block+TheBall_x              ; emitter.x = 0.0 + 1.0 * the_ball_block.x
    math_func_read_addr 0.0, 1.0, the_ball_block+TheBall_y              ; emitter.y = 0.0 + 1.0 * the_ball_block.y
    math_const 0.0                                                      ; emitter.dir.x = 2.0 * math.sin(f/100)
    math_const 0.0                                                      ; emitter.dir.y = 2.0 * math.cos(f/100)
    math_const 128                                                      ; emitter.life
    math_func  0.0,    1.0,    math_and15, 0.0,  1.0                    ; emitter.colour = (emitter.colour + 1) & 15    [0.0+1.0*(0.0+1.0*i)]
    math_func  8.0,    6.0,    math_sin,   0.0,  1.0/(MATHS_2PI*10.0)   ; emitter.radius = 8.0 + 6 * math.sin(f/10)

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

seq_palette_green_white_ramp:
    .long 0x00000000                    ; 00 = 0000 = black
    .long 0x00008000                    ; 01 = 0001 =
    .long 0x00108010                    ; 02 = 0010 =
    .long 0x00208020                    ; 03 = 0011 =
    .long 0x00308030                    ; 04 = 0100 =
    .long 0x00408040                    ; 05 = 0101 =
    .long 0x00509050                    ; 06 = 0110 =
    .long 0x0060a060                    ; 07 = 0111 = reds
    .long 0x0070b070                    ; 08 = 1000 =
    .long 0x0080c080                    ; 09 = 1001 =
    .long 0x0090d090                    ; 10 = 1010 =
    .long 0x00a0e0a0                    ; 11 = 1011 =
    .long 0x00b0e0b0                    ; 12 = 1100 =
    .long 0x00c0e0c0                    ; 13 = 1101 =
    .long 0x00d0e0d0                    ; 14 = 1110 = oranges
    .long 0x00e0e0e0                    ; 15 = 1111 = white

seq_palette_black_on_white:
    .long 0x00f0f0f0                    ; 00 = 0000 = black
    .long 0x00000000                    ; 01 = 0001 =
    .long 0x00101010                    ; 02 = 0010 =
    .long 0x00202020                    ; 03 = 0011 =
    .long 0x00303030                    ; 04 = 0100 =
    .long 0x00404040                    ; 05 = 0101 =
    .long 0x00505050                    ; 06 = 0110 =
    .long 0x00606060                    ; 07 = 0111 = reds
    .long 0x00707070                    ; 08 = 1000 =
    .long 0x00808080                    ; 09 = 1001 =
    .long 0x00909090                    ; 10 = 1010 =
    .long 0x00a0a0a0                    ; 11 = 1011 =
    .long 0x00b0b0b0                    ; 12 = 1100 =
    .long 0x00c0c0c0                    ; 13 = 1101 =
    .long 0x00d0d0d0                    ; 14 = 1110 = oranges
    .long 0x00e0e0e0                    ; 15 = 1111 = white

block_sprite_sheet_def_no_adr:
    ; 8 sprites at 2 words (8 pixels) x 8 rows.
    SpriteSheetDef_Mode9 8, 1, 8, block_sprites_no_adr

; ============================================================================
; Sequence specific bss.
; ============================================================================

the_env_floor_plane:
    .skip EnvPlane_SIZE

the_env_left_plane:
    .skip EnvPlane_SIZE

the_env_left_slope:
    .skip EnvPlane_SIZE

the_env_right_plane:
    .skip EnvPlane_SIZE

the_env_right_slope:
    .skip EnvPlane_SIZE

; ============================================================================
