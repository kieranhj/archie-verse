; ============================================================================
; The actual sequence for the demo.
; NB. First tick of the script happens at init before music is started etc.
; ============================================================================

; TODO: Put these in separate sequence files?

; ============================================================================

.if _DEMO_PART==_PART_DONUT
.macro donut_lerp_over_secs palette_A, palette_B, secs
    math_make_var seq_palette_blend, 0.0, 1.0, math_clamp, 0.0, 1.0/(\secs*50.0)  ; seconds.
    math_make_palette seq_palette_id, \palette_A, \palette_B, seq_palette_blend, seq_palette_lerped
    write_addr raster_donut_palette_p, seq_palette_lerped
    fork_and_wait \secs*50.0-1, seq_unlink_palette_lerp
    ; NB. Subtract a frame to avoid race condition.
.endm

seq_donut_part:

    ; Init FX modules.
    call_0      scene3d_init
    call_0      rasters_donut_init
    .if LibTriangle_EnableFutz
    call_0      futz_table_init
    .endif
    ;                               RingRadius          CircleRadius        RingSegments   CircleSegments  MeshPtr                      Flags
    call_6      mesh_make_torus,    32.0*MATHS_CONST_1, 16.0*MATHS_CONST_1, 12,            8,              mesh_header_torus,           0x0 ; not flat inner
    call_6      mesh_make_torus,    32.0*MATHS_CONST_1, 16.0*MATHS_CONST_1, 12,            8,              mesh_header_torus_flipped,   0x2 ; flipped

    ; Reset logo palette in Vsync.
    write_addr  palette_array_p,    three_logo_pal_no_adr

    ; Show donut.
    call_3      fx_set_layer_fns,   0, scene3d_rotate_entity,           screen_cls_from_line
;    call_3      fx_set_layer_fns,   1, scene3d_move_entity_to_target,  0
    call_3      fx_set_layer_fns,   1, rasters_tick,                    0
    call_3      fx_set_layer_fns,   2, scene3d_bodge_torus_draw_order,  0                 ; Must come before transform.
    call_3      fx_set_layer_fns,   3, scene3d_transform_entity,        scene3d_draw_entity_as_solid_quads

    write_vec3  torus_entity+Entity_Pos,    0.0, 0.0, -16.0
    write_vec3  object_rot_speed,           1.0, 0.0, 2.0

    ; Update a VECTOR3 using three math_funcs.
    ;math_make_vec3 torus_entity+Entity_Pos, my_func_for_x, my_func_for_y, my_func_for_z

    ; Don't move light for now.
    ;math_make_vec3 light_direction, light_func_x, light_func_y, light_func_z

    ; 20 patterns at 5.12s per pattern = 102.4s for loop.

    write_vec3 light_direction, 0.577, 0.577, -0.577

seq_donut_loop:
    wait_patterns 4.0
    donut_lerp_over_secs seq_palette_red_additive, seq_palette_green_white_ramp, SeqConfig_PatternLength_Secs

    wait_patterns 1.0
    write_addr raster_donut_palette_p, 0

    wait_patterns 4.0
    donut_lerp_over_secs seq_palette_green_white_ramp, seq_palette_blue_cyan_ramp, SeqConfig_PatternLength_Secs

    wait_patterns 1.0
    write_addr raster_donut_palette_p, 0

    wait_patterns 4.0
    donut_lerp_over_secs seq_palette_blue_cyan_ramp, seq_palette_red_magenta_ramp, SeqConfig_PatternLength_Secs

    wait_patterns 1.0
    write_addr raster_donut_palette_p, 0

    wait_patterns 4.0
    donut_lerp_over_secs seq_palette_red_magenta_ramp, seq_palette_red_additive, SeqConfig_PatternLength_Secs

    wait_patterns 1.0
    write_addr raster_donut_palette_p, 0

    goto seq_donut_loop
    end_script

my_func_for_x:
    math_func   0.0,    40.0,      math_sin,   0.0,    1.0/(MATHS_2PI*40.0)

my_func_for_y:
    math_func   0.0,    40.0,      math_cos,   0.0,    1.0/(MATHS_2PI*30.0)

my_func_for_z:
    math_func   0.0,    26.0,      math_cos,   0.0,    1.0/(MATHS_2PI*900.0)

light_func_x:
    math_func   0.0,    1.0,       math_sin,   0.0,    1.0/(MATHS_2PI*200.0)

light_func_y:
    math_func   0.0,    1.0,       math_cos,   0.0,    1.0/(MATHS_2PI*200.0)

light_func_z:
    math_const  0.0

; ============================================================================
; SCROLLTEXT TEXT. TODO: Move to data segment.
; ============================================================================

tipsy_scroller_message_no_adr:
; At 1 pixel/frame = 6.4s to traverse the screen.
; Speed = 40 chars/6.4s = 6.25 chars/s
; 16 patterns at 6 ticks/row = 122.88s
; So in 122.88s 122.88s * 6.25 chars/s = 768 chars.
;                                                                                                             1
;                   1         2         3         4         5         6         7         8         9         0
;          1........0.........0.........0.........0.........0.........0.........0.........0.........0.........0
    .byte "    Eat my doughnut! This is a typically belated entry to the Buxton Bytes cracktro showcase to show "
    .byte "how much better the mightly Acorn Archimedes is than your puny Atari ST machines at 8MHz! ARM FTW :) "
    .byte "Gfx by Hammerfist, music by ne7, code by kieran, and the soft-copper magic (RasterMan) by "
    .byte "Phoenix^Quantum. Tasty sprinkles go out to Tom, SMFX, Desire, Spice Boys (is that chip spice?), "
    .byte "Evvvil (not a pity greet :) and all doughnut lovers from around the scene. "
    .byte "Apologies to Hammerfist for keeping the awful programmer colours - I just ran "
    .byte "out of time... the doughnut was also supposed to do loads of fun things but never mind!! "
    .byte "Speaking of Hammerfist, you better strap yourselves in...                    "
    ;
    .byte "ALRIGHT, IT'S ABOUT TIME TO MAKE THESE FINGERS BLEED...  BUT FIRST, PARTY ORGANIZERS, THIS PART IS "
    .byte "JUST THE DOUGHNUT. SO CHECK OUT THE MUSIC, AND THAT'S PROBABLY ENOUGH.  YOU CAN LET THE SCROLLER RUN, "
    .byte "BUT YOU BETTER MAKE SURE THIS IS THE LAST DEMO OF THE COMPO, BECAUSE I PLAN TO GO ON FOR A WHILE.    "
    .byte "YES, HAMMERFIST/DESIRE ON THE KEYS, WHICH SHOULD BE ENOUGH OF A WARNING.  "
    .byte "SHOUT OUT TO ALIEN^PDX, JADE, AND SPKR, FOR THE INSPIRATION FOR THE LOGO.   THE FONT IS A PIMPED UP "
    .byte "VERSION OF MY ORIGINAL, MADE FOR 1991 DONUT IN 2013.   I FEEL THIS DONUT IS BECOMING A BIT OF A MEME, "
    .byte "AND I AM HERE FOR IT!     I GUESS THE BIGGEST TRICK FOR THE LOGO WAS KEEPING IT 16 COLORS, AND I AM "
    .byte "VERY PLEASED HOW IT TURNED OUT.     THIS WHOLE MEGADEMO PRODUCTION WAS A NICE EXPERIENCE FOR ME.  "
    .byte "LOTS OF EXCELLENT CODERS WHO GAVE ME ROOM TO SUGGEST ALL SORTS OF IDEAS FOR THE DESIGN, AND TRUSTED "
    .byte "ME TO DELIVER.   REALLY A PLEASANT WAY TO WORK I AM VERY GRATEFUL FOR!    I FEEL I SHOULD STRESS, "
    .byte "THOUGH, THAT I AM NOT THE MAIN DESIGNER OR ANYTHING.  THE OVERALL THEME WAS SET, AND MY INPUT WAS "
    .byte "OFFERING SUGGESTION FOR THE SMALL STUFF. DETAILS LIKE THE LOOK OF THE ICONS, CERTAIN CHOICES LIKE "
    .byte "THE 'WARNING, SPEED BUMP' ICON FOR THE CREDITS PART, WHICH IS ALL BUMP MAPPING, STUFF LIKE THAT.   "
    .byte "AND EVEN WITHOUT THAT, I WOULD HAVE BEEN HAPPY IF ONLY THEY'D PUT UP WITH MY ENDLESS BRAINSTORMS AND "
    .byte "ALL MY (REPEATED) QUESTIONS ABOUT GRAPHICS RESTRICTIONS.    I DIDN'T REALLY KNOW THE ARCHIMEDES WAS "
    .byte "EVEN A THING UNTIL I WORKED ON FATHOM LAST YEAR, AND MY AMIGA AND C64 BACKGROUND DIDN'T NECESSARILY "
    .byte "HELP EITHER.     SO, TODAY IS SUNDAY, JUNE 1ST 2025, AND I SPENT THE MORNING WITH MY FAMILY AT A SORT "
    .byte "OF STREET FAIR. THE NEIGHBOURHOOD MY NIECES LIVE IN WAS ORGANIZING IT. LOTS OF PEOPLE IN FRONT OF "
    .byte "THEIR HOMES TO SELL ALL SORTS OF KNICKNACKS, OLD CLOTHES AND TOYS, OLD BOOKS, MAYBE VINYL OR ACTUAL "
    .byte "COLLECTIBLES AND TOO MANY YOUNG KIDS SELLING CUPCAKES, LEMONADE, OR ACTING LIKE STREET PERFORMERS.   "
    .byte "ALL VERY ADORABLE, AND THE WEATHER WAS GREAT.   THE AFTERNOON WAS MOSTLY PLAYING INDOORS WITH PLAYMOBIL.  "
    .byte "I LET MY KIDS PLAY TOO, DON'T WORRY!    NOW IT'S EVENING, AND THEY ARE ASLEEP.   SO I'M GRABBING MY "
    .byte "CHANCE TO TYPE SOMETHING FOR MY PERSONAL ENTERTAINMENT.  AND TO ANNOY ALL THOSE HEROES THAT CAPTURE "
    .byte "THESE DEMOS FOR YOUTUBE.   BECAUSE LETTING THIS RUN ALL THE WAY TO THE END IS GOING TO REQUIRE SOME "
    .byte "PATIENCE.  AND THIS ISN'T THE ONLY SCROLLER I WAS ALLOWED TO FILL, SO BUCKLE UP, LADS AND LADIES!    "
    .byte "-- TIME JUMP -- IT'S EVENING NOW, STILL SUNDAY THOUGH.  I AM GOING TO SAVE THIS AND TYPE MORE LATER "
    .byte "THIS WEEK. I STILL NEED TO FINISH AN ANIMATION FOR A DISCO BALL.  LET'S SEE IF THAT WILL MAKE THE CUT, "
    .byte "AS I'M NOT NEARLY AS PLEASED WITH THOSE GRAPHICS AS I AM WITH OTHER STUFF I DID.   BUT MAYBE I CAN "
    .byte "FIGURE IT OUT IN TIME AND MAKE IT LOOK GOOD... GO CHECK OUT THAT PART, BUT KNOW YOU'LL HAVE TO REREAD "
    .byte "ALL OF THIS IF YOU QUIT NOW.    HEHE, THERE'S A NICE LITTLE DILEMMA.   NOTHING TOO GRAND ON A COSMIC "
    .byte "SCALE, BUT WHAT WILL YOU DO IF YOU HAVEN'T SEEN THE MOCAP PART YET?  GO THERE NOW, AND HOPE TO RETURN "
    .byte "TO THIS FOR THE REST OF MY SCROLLER?  OR EVEN HOPE THIS IS NEARING THE END ALREADY?   OR STAY HERE UNTIL "
    .byte "I'M DONE WITH MY RAMBLINGS - NOT KNOWING HOW MUCH MORE TIME IT WILL BE?    HM, UNLESS BETWEEN NOW AND "
    .byte "NOVA PARTY, WE INCLUDE SOME KIND OF INFO ON THE LENGTH OF THIS, OR BETTER YET, WE INCLUDE A WAY FOR THE "
    .byte "DEMO TO KEEP TRACK OF HOW FAR YOU GOT WITH THE SCROLLER, AND WE START THERE WHEN YOU OPEN A PART AGAIN...   "
    .byte "YES. I SHOULD DEFINITELY ASK OUR CODERS IF THAT'S AN OPTION.  I'LL GO DO THAT NOW, AND CONTINUE THIS LATER.  "
    .byte "OOH, I LOVE THIS PERSPECTIVE DIFFERENCE.  I WON'T KNOW THE RESULT UNTIL AFTER THEY REPLY.  AND YOU OBVIOUSLY "
    .byte "KNOW LATER THAN ME, BUT FOR YOU THE TIME PASSING BETWEEN WHEN YOU FIRST LEARN OF THIS, AND ME SHOWING THE "
    .byte "ANSWER A FEW CHARACTERS FURTHER DOWN THE SCROLLER IS ACTUALLY NOT THAT LONG..   BUT IF IT IS. WE REALLY "
    .byte "OUGHT TO HAVE SPED UP THIS SCROLLER. SORRY ABOUT THAT!   ANYWAY...  FOR NOW, SOME TIME PASSED BY FOR ME - "
    .byte "IT'S THE 6TH OF JUNE NOW, FRIDAY EVENING - AND I FOUND SOME TIME AGAIN TO WRITE MORE USELESS BANTER.  "
    .byte "I AM RUNNING ON MORPHINE ATM - THE DOCTOR THINKS IT MAY BE A HERNIA, AND ALL I KNOW IS IT FEELS LIKE A "
    .byte "NERVE BEING PINCHED AND THE PAIN RADIATING FROM MY LOWER BACK TO MY LEG, SO YEAH... IT'S DEFINITELY AGE "
    .byte "RELATED.   NOT THAT I AM -THAT- OLD YET, AT 48, BUT YOU KNOW, I AM NOT AS SPRY AS BACK IN YE OL' COMP-JOOTER "
    .byte "DAYS.  OR WHATEVER. I'M ON DRUGS, REMEMBER?  CUT ME SOME SLACK. OR SOME PIE.   WHO DOESN'T LIKE GOOD PIE.   "
    .byte "AND BEFORE YOU THINK THE DRUGS MAKE ME A RAMBLING MESS, YOU CLEARLY DON'T KNOW ME THAT WELL. I AM ALWAYS "
    .byte "A RAMBLING MESS. I DO NOT NEED DRUGS TO DO THAT FOR ME, HA!     RIGHT, TELL YOU WHAT. I HAVE MORE STUFF "
    .byte "TO DO, YOU HAVE MORE STUFF TO DO, LET'S CALL THIS A NIGHT.  I WILL SAVE THE REST OF MY AMMO FOR ANOTHER "
    .byte "PART OF THIS MEGA DEMO.  PROBABLY THE MAIN MENU, POSSIBLY THE VECTORBALLS PART.  IT'S NOT THAT I THINK "
    .byte "EVERY PART NEEDS MY INPUT, IT'S JUST THAT APPARENTLY NOBODY ELSE LIKES TO WRITE SCROLLERS THAT MUCH - "
    .byte "BUT THEY ARE SUCH A DEMOSCENE STAPLE, I WAS ABLE TO CONVINCE THEM TO ADD A COUPLE....  BY PROMISING "
    .byte "I WOULD FILL THEM MYSELF, SO THEY WOULDN'T HAVE TO, HEHE....   SO THERE. YOU READ IT HERE FIRST. "
    .byte "HAMMERFIST RAMBLES FOR FUN.   OK, SIGNING OFF, SCROLLER WILL PROBABLY RESTART. MAYBE WE'LL ERASE YOUR "
    .byte "HARD DRIVE. LET'S FIND OUT TOGETHER!  THANKS FOR STICKING AROUND, YOU HAVE MY EVERLASTING GRATITUDE!  "
    .byte "-X-           "
    .byte 0
    .p2align 2

.endif

; ============================================================================

.if _DEMO_PART==_PART_SPACE
; SeqConfig_PatternLength_Secs = 4.48s

.equ SpaceScene_FadeUp,     1.12
.equ SpaceScene_FadeDown,   1.12
.equ SpaceScene_Flash,      4.04
.equ SpaceScene_FlashDown,  2.24
.equ SpaceScene_Short,      1.0*SeqConfig_PatternLength_Secs-SpaceScene_FadeDown
.equ SpaceScene_Medium,     2.0*SeqConfig_PatternLength_Secs-SpaceScene_FadeDown
.equ SpaceScene_Long,       3.0*SeqConfig_PatternLength_Secs-SpaceScene_FadeDown

seq_space_part:

    ; Init FX modules.
    call_0      rotate_init

    ; UV tunnel aka UV table fx.
    call_3      fx_set_layer_fns,     0, uv_table_tick          uv_table_draw

    .if _DEBUG
    ;goto seq_space_rotate
    ;goto seq_space_tunnel
    ;goto seq_space_black_hole
    ;goto seq_space_spin
    ;goto seq_space_warp
    ;goto seq_space_greets
    ;goto seq_space_relax
    ;goto seq_space_torus
    ;goto seq_space_monolith
    .endif
  
    ; ================================
    ; Apollo
    ; ================================
    gradient_fade_up_over_secs        gradient_grey,   2.0

    ; Decomp the UV data.
    call_2      unlz4,                uv_apollo_map_no_adr,     uv_table_data_no_adr
    ; Set UV data ptr.
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    ; Generate the unrolled code with default 128x128 texture size.
    call_1      uv_table_init_shader, UV_Table_TexDim_128_128
    ; Override texture offset calculation for first offset value.
    call_1      uv_table_set_texture_wrap, UV_Table_TexDim_128_512

    ; Decompress large texture to end of unrolled code buffer.
    call_2      unlz4,                uv_apollo_384_texture_no_adr,     uv_texture_data_no_adr-(384*128)
    ; Set base texture pointer manually.
    write_addr  uv_table_texture_p,   uv_texture_data_no_adr-(384*128)
    ; Copy 16K of the texture data for wrap.
    call_3      mem_copy_fast         uv_texture_data_no_adr-(384*128),   uv_texture_data_no_adr, 16384

    write_fp    uv_table_fp_u,        0.0
    write_fp    uv_table_fp_v,        0.0

;    write_addr  reset_vsync_delta,    1

    wait_secs   2.0

    math_make_var uv_table_fp_v,      0.0, 384.0, math_clamp, 0.0, 1.0/(2*384)    ; v=i/200

    wait        668;    2*384
    gradient_fade_down_over_secs      gradient_grey,  2.0

    wait_secs   2.56
    destroy uv_table_fp_v
    ; ================================

    gosub seq_unlink_palette_lerp

    ; ================================
    ; Ship over surface.
    ; ================================
    gradient_fade_up_over_secs        gradient_ship,     2.0

    call_2      unlz4,                uv_ship_map_no_adr,       uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_64
    call_2      uv_texture_unlz4,     uv_ship_texture_no_adr,   8192

    write_fp    uv_table_fp_u,        0.0
    math_make_var seq_dv, 1.0, 3.0, math_clamp, 0.0, 1.0/(SpaceScene_Medium*50.0)
    math_add_vars uv_table_fp_v, seq_dv, 1.0, uv_table_fp_v       ; v'=1.0+1.0*v

;    write_addr  reset_vsync_delta,    1

    wait_secs   SpaceScene_Medium

    gradient_fade_down_over_secs      gradient_ship,  1.0
    wait_secs   1.0
    destroy uv_table_fp_v
    destroy seq_dv
    ; ================================

    gosub seq_unlink_palette_lerp

    ; ================================
    ; Planet, flying away from.
    ; ================================
    gradient_fade_up_over_secs        gradient_space,   SpaceScene_FadeUp

    call_2      unlz4,                uv_planet_map_no_adr,     uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_64
    call_2      uv_texture_unlz4,     uv_ship_texture_no_adr,   8192

    write_fp    uv_table_fp_u,        0.0
    math_link_vars uv_table_fp_v,     1.0, 1.0, uv_table_fp_v   ; v'=1.0+1.0*v

;    write_addr  reset_vsync_delta,    1

    wait_secs   SpaceScene_Medium

    gradient_fade_down_over_secs      gradient_space,  SpaceScene_FadeDown
    wait_secs   SpaceScene_FadeDown
    destroy uv_table_fp_v
    ; ================================

    gosub seq_unlink_palette_lerp

seq_space_warp:
    ; ================================
    ; Warp.
    ; ================================
    gradient_fade_up_over_secs        gradient_sun,   SpaceScene_FadeUp

    call_2      unlz4,                uv_warp_map_no_adr,       uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_8_256
    call_2      uv_texture_unlz4,     uv_warp_texture_no_adr,   2048

    write_fp    uv_table_fp_u,        0.0
    write_fp    seq_dv,               1.0
    math_add_vars uv_table_fp_v, seq_dv, 1.0, uv_table_fp_v       ; v'=1.0+1.0*v

;    write_addr  reset_vsync_delta,    1

    ; Gets faster over time.
    math_make_var seq_dv, 1.0, 9.0, math_clamp, 0.0, 1.0/(4.0*50.0)
    wait_secs   SpaceScene_Medium/2
    math_make_var seq_dv, 10.0, -9.0, math_clamp, 0.0, 1.0/(4.0*50.0)
    wait_secs   SpaceScene_Medium/2

    gradient_fade_down_over_secs      gradient_sun,   SpaceScene_FadeDown
    wait_secs   SpaceScene_FadeDown
    destroy uv_table_fp_v
    destroy seq_dv
    ; ================================

    gosub seq_unlink_palette_lerp

seq_space_black_hole:
    ; ================================
    ; Black hole.
    ; ================================
    gradient_fade_up_over_secs        gradient_black_hole,   SpaceScene_FadeUp

    call_2      unlz4,                uv_black_hole_map_no_adr, uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_128
    call_2      uv_texture_unlz4,     uv_disk_texture_no_adr,   16384

    write_fp    uv_table_fp_u,        0.0
    math_link_vars uv_table_fp_v,     1.0, 1.0, uv_table_fp_v   ; v'=1.0+1.0*v

;    write_addr  reset_vsync_delta,    1

    wait        50*(SpaceScene_Medium-SpaceScene_Flash)
    gosub       seq_space_do_flash

    gradient_fade_down_over_secs      gradient_black_hole,  SpaceScene_FadeDown
    wait_secs   SpaceScene_FadeDown
    ; ================================

    gosub seq_unlink_palette_lerp

    ; ================================
    ; Wormhole.
    ; ================================
    gradient_fade_up_over_secs        gradient_wormhole,   SpaceScene_FadeUp

    call_2      unlz4,                uv_wormhole_map_no_adr,   uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_128
    call_2      uv_texture_unlz4,     uv_space_texture_no_adr,  16384

    write_fp    uv_table_fp_u,        0.0
    math_link_vars uv_table_fp_v,     1.0, 1.0, uv_table_fp_v   ; v'=1.0+1.0*v

;    write_addr  reset_vsync_delta,    1

    wait_secs   SpaceScene_Short

    gradient_fade_down_over_secs      gradient_wormhole,  SpaceScene_FadeDown
    wait_secs   SpaceScene_FadeDown
    destroy uv_table_fp_v
    ; ================================

    gosub seq_unlink_palette_lerp

seq_space_tunnel:
    ; ================================
    ; Tunnel.
    ; ================================
    gradient_fade_up_over_secs        gradient_tunnel,   SpaceScene_FadeUp

    call_2      unlz4,                uv_tunnel_map_no_adr,     uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_128
    call_2      uv_texture_unlz4,     uv_space_texture_no_adr,  16384

    write_fp    uv_table_fp_u,        0.0
    math_link_vars uv_table_fp_v,     1.0, 1.0, uv_table_fp_v   ; v'=1.0+1.0*v

;    write_addr  reset_vsync_delta,    1

    wait        50*(2*4.48+0.96)         ; second pattern
;    gosub       seq_space_do_flash
    math_make_var seq_palette_blend,   0.0, 15.0, math_clamp, 0.0,  1.0/16.0
    wait 16
    destroy uv_table_fp_v     ; pause motion
    math_make_var seq_palette_blend,   15.0, -15.0, math_clamp, 0.0,  1.0/SpaceScene_FlashDown
    wait 50*2.4-16

    gradient_fade_down_over_secs      gradient_tunnel,  SpaceScene_FadeDown
    wait_secs   SpaceScene_FadeDown
    destroy uv_table_fp_v
    ; ================================

    gosub seq_unlink_palette_lerp

    ; ================================
    ; Trippy.
    ; ================================
    gradient_fade_up_over_secs        gradient_wormhole,    SpaceScene_FadeUp
    
    call_2      unlz4,                uv_fractal_map_no_adr,    uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    ;call_1      uv_table_init_shader, UV_Table_TexDim_128_128  ; <== inherits shader data from previous!
    call_0      uv_table_init
    call_2      uv_texture_unlz4,     uv_space_texture_no_adr,  16384

    call_3      fx_set_layer_fns,     0, uv_table_tick          uv_table_draw

    math_make_var uv_table_fp_u,      0.0, 1.0, 0, 0.0, -1.0
    math_make_var uv_table_fp_v,      0.0, 1.0, 0, 0.0, 1.0

;    write_addr  reset_vsync_delta,    1

    wait_secs   SpaceScene_Medium

    gradient_fade_down_over_secs      gradient_wormhole,  SpaceScene_FadeDown
    wait_secs   SpaceScene_FadeDown
    destroy uv_table_fp_u
    destroy uv_table_fp_v
    ; ================================

    gosub seq_unlink_palette_lerp

seq_space_torus:
    ; ================================
    ; Torus.
    ; ================================
    gradient_fade_up_over_secs        gradient_red_alert,    SpaceScene_FadeUp
    
    call_2      unlz4,                uv_torus_map_no_adr,      uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    ;call_1      uv_table_init_shader, UV_Table_TexDim_128_128  ; <== inherits shader data from previous!
    call_0      uv_table_init
    call_2      uv_texture_unlz4,     rotate_texture_no_adr,  16384

    call_3      fx_set_layer_fns,     0, uv_table_tick          uv_table_draw

    math_make_var uv_table_fp_u,      0.0, -1.0, 0, 0.0, 1.0
    math_make_var uv_table_fp_v,      0.0, 1.0, 0, 0.0, 1.0

;    write_addr  reset_vsync_delta,    1

    wait_secs   SpaceScene_Medium

    gradient_fade_down_over_secs      gradient_red_alert,  SpaceScene_FadeDown
    wait_secs   SpaceScene_FadeDown
    destroy uv_table_fp_u
    destroy uv_table_fp_v
    ; ================================

    gosub seq_unlink_palette_lerp

seq_space_rotate:
    ; ================================
    ; Rotate & scale.
    ; ================================
    gradient_fade_up_over_secs        gradient_red_alert,   SpaceScene_FadeUp

    call_2      uv_texture_unlz4,     rotate_texture_no_adr,    16384
    call_3      fx_set_layer_fns, 0,  rotate_tick,              rotate_draw

    math_make_var rotate_angle,       0.0,   1.5, 0,            0.0,    1.0    ; speed 1.0 brad / frame
    math_make_var rotate_scale,       0.1,   2.0, math_clamp,   0.0,    1.0/(50.0*9.0) ; zoom out
;    write_fp      rotate_scale,     1.0
;    write_fp      rotate_angle,     32

    math_make_var rotate_tl_x,      -80,   -32, math_sin,   0.0,    1.0/(50.0*8.0)
    math_make_var rotate_tl_y,      -64,   -32, math_cos,   0.0,    1.0/(50.0*8.0)
;    write_fp rotate_tl_x,      -64-80
;    write_fp rotate_tl_y,      -64-64

;    write_addr  reset_vsync_delta,    1
    
    wait_secs   SpaceScene_Medium

    ; Spinning
    gradient_fade_down_over_secs      gradient_red_alert,  SpaceScene_FadeDown
    wait_secs   SpaceScene_FadeDown

    destroy rotate_scale
    destroy rotate_angle
    destroy rotate_tl_x
    destroy rotate_tl_y

    ; Back to LUT FX
    call_3      fx_set_layer_fns,     0, uv_table_tick          uv_table_draw
    ; ================================

    gosub seq_unlink_palette_lerp

seq_space_spin:
    ; ================================
    ; Spinning ship.
    ; ================================
    gradient_fade_up_over_secs        gradient_tunnel,   SpaceScene_FadeUp

    call_2      unlz4,                uv_spin_map_no_adr,       uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_128
    call_2      uv_texture_unlz4,     uv_space_texture_no_adr,  16384

    write_fp    uv_table_fp_u,        0.0
    math_link_vars uv_table_fp_v,     2.0, 1.0, uv_table_fp_v   ; v'=1.0+1.0*v

;    write_addr  reset_vsync_delta,    1

    wait_secs   SpaceScene_Medium

    gradient_fade_down_over_secs      gradient_tunnel,  SpaceScene_FadeDown
    wait_secs   SpaceScene_FadeDown
    destroy uv_table_fp_v
    ; ================================

    gosub seq_unlink_palette_lerp

    ; ================================
    ; Reactor panic.
    ; Includes palette offset.
    ; ================================

    ; Create a variable: offset = -4.0 + 3.0 * sin (i/50)
    math_make_var seq_panic_offset,   -3.0, 2.0, math_sin, 0.0,  1.0/50.0
    ; Create a variable to fade up = -15.0 + 15.0 * clamp (i/4.0)
    math_make_var seq_palette_blend,  -15.0, 15.0, math_clamp, 0.0,  1.0/(2.0*50.0)
    ; Offset is these two variables combined.
    ; NB. Must be evaluated in the correct order...
    math_add_vars seq_panic_combined, seq_palette_blend, 1.0, seq_panic_offset
    ; RGB[d][i] = RGB[a][i+c]
    call_7      math_var_register_ex, seq_palette_id, gradient_red_alert, 0, seq_panic_combined, seq_palette_lerped, 0, math_evaluate_palette_offset
    write_addr palette_array_p, seq_palette_lerped

    call_2      unlz4,                uv_reactor_panic_map_no_adr, uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_128
    call_2      uv_texture_unlz4,     uv_disk_texture_no_adr,   16384

    write_fp    uv_table_fp_u,        0.0

    math_make_var seq_panic_speed,   3.0, 1.0, math_sin, 0.0,  1.0/200.0
    math_add_vars uv_table_fp_v,     seq_panic_speed, 1.0, uv_table_fp_v   ; v'=speed+1.0*v

;    write_addr  reset_vsync_delta,    1

    wait_secs   SpaceScene_Medium

    math_make_var seq_palette_blend,    0.0, -15.0, math_clamp, 0.0,  1.0/(SpaceScene_FadeDown*50.0)
    ; RGB[d][i] = RGB[a][i+c]
    call_7      math_var_register_ex, seq_palette_id, gradient_red_alert, 0, seq_panic_combined, seq_palette_lerped, 0, math_evaluate_palette_offset    
    wait_secs   SpaceScene_FadeDown

    destroy seq_panic_speed
    destroy seq_panic_offset
    destroy seq_panic_combined
    destroy seq_panic_handle
    destroy uv_table_fp_v
    ; ================================

    gosub seq_unlink_palette_lerp

    ; ================================
    ; Spinning to stop.
    ; ================================
    gradient_fade_up_over_secs        gradient_tunnel,   SpaceScene_FadeUp

    call_2      unlz4,                uv_spin_map_no_adr,       uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_128
    call_2      uv_texture_unlz4,     uv_space_texture_no_adr,  16384

    write_fp    uv_table_fp_u,        0.0
    math_add_vars uv_table_fp_v, seq_dv, 1.0, uv_table_fp_v       ; v'=1.0+1.0*v
    math_make_var seq_dv, 2.0, -2.0, math_clamp, 0.0, 1.0/(SpaceScene_Short*50.0)

;    write_addr  reset_vsync_delta,    1

    wait_secs   SpaceScene_Short

    gradient_fade_down_over_secs      gradient_tunnel,  SpaceScene_FadeDown
    wait_secs   SpaceScene_FadeDown
    destroy uv_table_fp_v
    destroy seq_dv
    ; ================================

    gosub seq_unlink_palette_lerp

    ; ================================
    ; Reactor core.
    ; ================================
    gradient_fade_up_over_secs        gradient_ship,   SpaceScene_FadeUp

    call_2      unlz4,                uv_reactor_ok_map_no_adr, uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_128
    call_2      uv_texture_unlz4,     uv_disk_texture_no_adr,   16384

    write_fp    uv_table_fp_u,        0.0
    math_link_vars uv_table_fp_v,     4.0, 1.0, uv_table_fp_v   ; v'=2.0+1.0*v

;    write_addr  reset_vsync_delta,    1

    wait        50*(2*4.48)         ; second pattern
;    gosub       seq_space_do_flash
    math_make_var seq_palette_blend,   0.0, 15.0, math_clamp, 0.0,  1.0/16.0
    wait 16
    destroy uv_table_fp_v     ; pause motion
    math_make_var seq_palette_blend,   15.0, -15.0, math_clamp, 0.0,  1.0/SpaceScene_FlashDown
    wait 50*3.36-16
 
    gradient_fade_down_over_secs      gradient_ship,  SpaceScene_FadeDown
    wait_secs   SpaceScene_FadeDown
    destroy uv_table_fp_v
    ; ================================

    gosub seq_unlink_palette_lerp

    ; ================================
    ; New: Space Travel II - More space travel (reusue warp again or something new),
    ; Greets
    ; ================================
.equ ShortGreets, 1

seq_space_greets:
    write_fp    uv_table_fp_v,        0.0
    call_3      lut_scroller_init,    nasa_font_no_adr,         seq_greets_text_no_adr, nasa_prop_no_adr
    call_3      fx_set_layer_fns,     1, lut_scroller_tick,     0

    gradient_fade_up_over_secs        gradient_default,   SpaceScene_FadeUp

    call_2      unlz4,                uv_greets_map_no_adr,     uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_32_256
    call_2      uv_texture_unlz4,     uv_greets_texture_no_adr, 8192

    write_fp    uv_table_fp_u,        0.0
    write_fp    seq_dv,               2.0
    math_add_vars uv_table_fp_v, seq_dv, 1.0, uv_table_fp_v       ; v'=1.0+1.0*v

;    write_addr  reset_vsync_delta,    1

.if ShortGreets
    wait_secs   1.0
    math_make_var seq_dv, 2.0, 2.0,   math_clamp, 0.0, 1.0/(2.0*50.0)
    wait_secs   14.8
    math_make_var seq_dv, 4.0, -2.0,  math_clamp, 0.0, 1.0/(2.0*50.0)
    wait_secs   1.0
.else
    wait_secs   6.0
    math_make_var seq_dv, 2.0, 2.0,   math_clamp, 0.0, 1.0/(4.0*50.0)
    wait_secs   21.72
    math_make_var seq_dv, 4.0, -2.0,  math_clamp, 0.0, 1.0/(4.0*50.0)
    wait_secs   7.0
.endif

    gradient_fade_down_over_secs      gradient_default,  SpaceScene_FadeDown
    wait_secs   SpaceScene_FadeDown
    destroy uv_table_fp_v
    destroy seq_dv

    call_3      fx_set_layer_fns,     1, 0,                     0
    ; ================================

    gosub seq_unlink_palette_lerp

seq_space_monolith:
    ; ================================
    ; Monolith.
    ; ================================
    gradient_fade_up_over_secs        gradient_default,   SpaceScene_FadeUp

    call_2      unlz4,                uv_monolith_map_no_adr,   uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_128
    call_2      uv_texture_unlz4,     uv_cloud_texture_no_adr,  16384

    write_fp    uv_table_fp_u,        0.0
    math_add_vars uv_table_fp_v, seq_dv, 1.0, uv_table_fp_v       ; v'=1.0+1.0*v
    math_make_var seq_dv, 0.9, -0.4, math_cos, 0.0, 1.0/(6.0*50.0)

;    write_addr  reset_vsync_delta,    1

    wait        50*(4.48)         ; second pattern
;    gosub       seq_space_do_flash
    math_make_var seq_palette_blend,   0.0, 15.0, math_clamp, 0.0,  1.0/16.0
    wait 16
    destroy uv_table_fp_v     ; pause motion
    math_make_var seq_palette_blend,   15.0, -15.0, math_clamp, 0.0,  1.0/SpaceScene_FlashDown
    wait 50*3.36-16

    gradient_fade_down_over_secs      gradient_default,  SpaceScene_FadeDown
    wait_secs   SpaceScene_FadeDown
    destroy uv_table_fp_v
    destroy seq_dv
    ; ================================

    gosub seq_unlink_palette_lerp

    ; ================================
    ; Sun.
    ; ================================
    gradient_fade_up_over_secs        gradient_sun,   SpaceScene_FadeUp

    call_2      unlz4,                uv_sun_map_no_adr,        uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_64
    call_2      uv_texture_unlz4,     uv_ship_texture_no_adr,   8192

;    write_addr  reset_vsync_delta,    1

    write_fp    uv_table_fp_u,        0.0
    math_link_vars uv_table_fp_v,     1.0, 1.0, uv_table_fp_v   ; v'=0.25+1.0*v

    wait        50*(4.48)         ; second pattern
;    gosub       seq_space_do_flash
    math_make_var seq_palette_blend,   0.0, 15.0, math_clamp, 0.0,  1.0/16.0
    wait 16
    destroy uv_table_fp_v     ; pause motion
    math_make_var seq_palette_blend,   15.0, -15.0, math_clamp, 0.0,  1.0/SpaceScene_FlashDown
    wait 50*3.36-16

    gradient_fade_down_over_secs      gradient_sun,  SpaceScene_FadeDown
    wait_secs   SpaceScene_FadeDown
    destroy uv_table_fp_v
    ; ================================

    gosub seq_unlink_palette_lerp

seq_space_relax:
    ; ================================
    ; Relax.
    ; ================================
    gradient_fade_up_over_secs        gradient_ship,   2.0

    ; Create code from UV data.
    call_2      unlz4,                uv_relax_map_no_adr,      uv_table_data_no_adr
    write_addr  uv_table_map_p,       uv_table_data_no_adr
    call_1      uv_table_init_shader, UV_Table_TexDim_128_128

    ; Decomp oversized texture manually into preceding buffer.
    call_2      unlz4,                uv_space_512_texture_no_adr,      uv_texture_data_no_adr-(512*128)
    ; TODO: Ideally need an assert to make sure we haven't tramped (but can see corruption).

    ; Create a regular 128*128 wrapping texture manually.
    call_3      mem_copy_fast,        uv_texture_data_no_adr-(512*128), uv_texture_data_no_adr,         16384
    call_3      mem_copy_fast,        uv_texture_data_no_adr,           uv_texture_data_no_adr+16384,   16384
    write_addr  uv_table_texture_p,   uv_texture_data_no_adr

    ; Scroll V with wrapping.
    write_fp    uv_table_fp_u,        0.0
    math_make_var uv_table_fp_v,      0.0, 128.0, math_modfp, 0.0, 1.0/(256)    ; v=i/200

;    write_addr  reset_vsync_delta,    1

    wait        256

    ; Reset texture base pointer to start of our oversized texture.
    write_addr  uv_table_texture_p,   uv_texture_data_no_adr-(512*128)
    ; Override the intial texture offset calculation.
    call_1      uv_table_set_texture_wrap, UV_Table_TexDim_128_512

    math_link_vars uv_table_fp_v,     0.5, 1.0, uv_table_fp_v   ; v'=0.25+1.0*v

    wait_secs   21.76

    gradient_fade_down_over_secs      gradient_ship,  4.48
    wait_secs   4.48
    destroy uv_table_fp_v
    ; ================================

    gosub seq_unlink_palette_lerp

    write_addr end_the_demo, 1

    end_script

seq_space_do_flash:
    math_make_var seq_palette_blend,   0.0, 15.0, math_clamp, 0.0,  1.0/16.0
    wait 16
    destroy uv_table_fp_v     ; pause motion
    math_make_var seq_palette_blend,   15.0, -15.0, math_clamp, 0.0,  1.0/SpaceScene_FlashDown
    wait 50*SpaceScene_Flash-16
    end_script

seq_dv:
    FLOAT_TO_FP 1.0

seq_panic_handle:
    .long 0

seq_panic_offset:
    FLOAT_TO_FP 0.0

seq_panic_speed:
    FLOAT_TO_FP 0.0

seq_panic_combined:
    FLOAT_TO_FP 0.0

seq_greets_text_no_adr:
.if ShortGreets
    .byte "Alcatraz - "
;    .byte "Ate-Bit - "
    .byte "AttentionWhore - "
    .byte "Bus Error - ";Collective - "
    .byte "CRTC - "
    .byte "Defekt - "
    .byte "DESiRE - " 
    .byte "Epoch & Ivory - "
    .byte "Gasman - "
    .byte "Inverse Phase - "
    .byte "IRIS - "
;   .byte "Logicoma - "
;   .byte "Loonies - "
;   .byte "NOVA orgas - "
    .byte "Proxima - "
;    .byte "Pulpo Corrosivo - "
;    .byte "Quantum - "
    .byte "Rabenauge - "
    .byte "RiFT - "
    .byte "Slipstream - "
    .byte "SMFX - "
    .byte "Spreadpoint - "
    .byte "TTE - "
    .byte "YM Rockerz "
;    .byte "Evvvil (not a pity greet :) - "
;    .byte "      Now let's take some more space selfies..."
    .byte "             "
    .byte 0 ; end.
.p2align 2
.else
    .byte "SPACE GREETS GO OUT TO... "
    .byte "Alcatraz - "
    .byte "Ate-Bit - "
    .byte "AttentionWhore - "
;   .byte "Bus Error Collective - "
    .byte "CRTC - "
    .byte "Defekt - "
    .byte "DESiRE - " 
    .byte "Epoch & Ivory - "
    .byte "Hooy Program - "
    .byte "Inverse Phase - "
    .byte "IRIS - "
;   .byte "Logicoma - "
    .byte "Loonies - "
;   .byte "NOVA orgas - "
    .byte "Proxima - "
    .byte "Pulpo Corrosivo - "
    .byte "Quantum - "
    .byte "Rabenauge - "
    .byte "RiFT - "
    .byte "Slipstream - "
    .byte "SMFX - "
    .byte "Spreadpoint - "
    .byte "TTE - "
    .byte "YM Rockerz - "
    .byte "Evvvil (not a pity greet :) - "
    .byte "      Now let's take some more space selfies..."
    .byte "             "
    .byte 0 ; end.
.p2align 2
.endif

.endif

; ============================================================================

.if _DEMO_PART==_PART_TEST
seq_test_part:

    ; Init FX modules.
    call_0      sine_scroller_init

    ; Screen setup.
    ; NB. Use write_addr palette_array_p, seq_palette_red_additive if setting per frame.

    ; Sine scroller.
    .if AppConfig_UseRasterMan
    call_3      fx_set_layer_fns,   0, rasters_tick,               screen_cls
    .else
    call_3      fx_set_layer_fns,   0, 0,                          screen_cls
    .endif
    call_3      fx_set_layer_fns,   2, sine_scroller_tick,         sine_scroller_draw

    end_script
.endif

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

.if _DEMO_PART==_PART_SPACE
; https://gradient-blaster.grahambates.com/?points=000@0,022@4,58c@11,fff@15&steps=16&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40
gradient_ship:
    grad_to_vidc 0x000,0x000,0x000,0x011,0x022,0x123,0x134,0x246, 0x357,0x469,0x47a,0x58c,0x7ad,0xace,0xdef,0xfff

; https://gradient-blaster.grahambates.com/?points=000@0,022@4,cb5@11,fff@15&steps=16&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40
gradient_space:
	grad_to_vidc 0x000,0x000,0x000,0x011,0x022,0x232,0x343,0x553, 0x773,0x984,0xaa4,0xdb5,0xdc7,0xeeb,0xfed,0xfff

; https://gradient-blaster.grahambates.com/?points=000@0,012@1,435@4,944@5,eeb@10,eff@14,fff@15&steps=16&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40
gradient_black_hole:
	grad_to_vidc 0x000,0x012,0x113,0x324,0x435,0x944,0xa65,0xc87, 0xda8,0xdda,0xeeb,0xffd,0xefe,0xfff,0xeff,0xfff

; https://gradient-blaster.grahambates.com/?points=000@0,a61@8,fff@15&steps=16&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40
gradient_default:
	grad_to_vidc 0x000,0x100,0x110,0x310,0x421,0x530,0x740,0x950, 0xa61,0xb84,0xc86,0xda8,0xdb9,0xedb,0xfee,0xfff

; https://gradient-blaster.grahambates.com/?points=000@0,200@2,c00@7,fc5@11,fff@15&steps=16&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40
gradient_red_alert:
	grad_to_vidc 0x000,0x100,0x200,0x400,0x600,0x800,0xa00,0xc00, 0xd52,0xe83,0xfa4,0xfc5,0xfd8,0xfeb,0xffd,0xfff

; https://gradient-blaster.grahambates.com/?points=000@0,100@1,200@2,310@3,840@7,c86@9,e95@10,ec6@11,ffc@13,fff@14,dff@15&steps=16&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40
gradient_sun:
	grad_to_vidc 0x000,0x100,0x200,0x310,0x410,0x520,0x730,0x840, 0xa63,0xc86,0xe95,0xfc6,0xfe9,0xffc,0xfff,0xeff

; https://gradient-blaster.grahambates.com/?points=000@0,600@3,710@5,b58@8,c7d@10,ecf@13,fff@15&steps=16&blendMode=oklab&ditherMode=goldenRatioMono&target=amigaOcs&ditherAmount=40
gradient_tunnel:
	grad_to_vidc 0x000,0x100,0x300,0x600,0x610,0x700,0x833,0xa45, 0xb58,0xc6b,0xc7d,0xd9e,0xeaf,0xecf,0xfef,0xfff

; https://gradient-blaster.grahambates.com/?points=000@0,fff@15&steps=16&blendMode=linear&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40
gradient_grey:
	grad_to_vidc 0x000,0x111,0x222,0x333,0x444,0x555,0x666,0x777, 0x888,0x999,0xaaa,0xbbb,0xccc,0xddd,0xeee,0xfff

; https://gradient-blaster.grahambates.com/?points=000@0,007@3,9cd@9,fdb@12,fff@15&steps=16&blendMode=oklab&ditherMode=goldenRatioMono&target=amigaOcs&ditherAmount=40
gradient_wormhole:
	grad_to_vidc 0x000,0x002,0x004,0x007,0x038,0x259,0x47a,0x59b, 0x8bd,0x9cd,0xbdd,0xedc,0xfdb,0xfec,0xffe,0xfff
.endif

; ============================================================================
; Palette blending - required if using palette_lerp_over_secs macro.
; ============================================================================

.if _DEMO_PART==_PART_SPACE || _DEMO_PART==_PART_DONUT
seq_unlink_palette_lerp:
    write_fp      seq_palette_blend, 1.0
    destroy seq_palette_blend
    destroy seq_palette_id
    end_script

; Used as the destination palette for all fading operations.
seq_palette_lerped:
    vidc_palette 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0xfff

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
