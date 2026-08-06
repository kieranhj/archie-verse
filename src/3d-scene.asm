; ============================================================================
; 3D Scene.
; ============================================================================

.equ OBJ_MAX_VERTS, 164
.equ OBJ_MAX_FACES, 16

.equ Model_Cube_Num_Verts, 8
.equ Model_Cube_Num_Faces, 6

.equ Model_Cobra_Num_Verts, 22
.equ Model_Cobra_Num_Faces, 13

.equ Model_Circle_Num_Verts, 8
.equ Model_Circle_Num_Faces, 0
.equ Model_Circle_Radius, 48

; The camera viewport is assumed to be [-1,+1] across its widest axis.
; Therefore we multiply all projected coordinates by the screen width/2
; in order to map the viewport onto the entire screen.

.equ VIEWPORT_SCALE,    (Screen_Width /2) * PRECISION_MULTIPLIER
.equ VIEWPORT_CENTRE_X, 160 * PRECISION_MULTIPLIER
.equ VIEWPORT_CENTRE_Y, 128 * PRECISION_MULTIPLIER

; ============================================================================
; Scene data.
; ============================================================================

; For simplicity, we assume that the camera has a FOV of 90 degrees, so the
; distance to the view plane is 'd' is the same as the viewport scale. All
; coordinates (x,y) lying on the view plane +d from the camera map 1:1 with
; screen coordinates.
;
;   h = viewport_scale / d.
;
; However as much of our maths in the scene is calculated as [8.16] maximum
; precision, having a camera distance of 160 only leaves 96 untis of depth
; to place objects within z=[0, 96] before potential problems occur.
;
; To solve this we use a smaller camera distance. d=80, giving h=160/80=2.
; This means that all vertex coordinates will be multiplied up by 2 when
; transformed to screen coordinates. E.g. the point (32,32,0) will map
; to (64,64) on the screen.
;
; This now gives us z=[0,176] to play with before any overflow errors are
; likely to occur. If this does happen, then we can further reduce the
; coordinate space and use d=40, h=4, etc.

; TODO: Probably don't need 8.8 precision when doing division [which is the
;       cause of the overflow] - could likely reduce to 10.6 or similar.


camera_pos:
    VECTOR3 0.0, 0.0, -80.0

; Note camera is fixed to view down +z axis.
; TODO: Camera rotation/direction/look at?

object_pos:
    VECTOR3 0.0, 0.0, 16.0

object_rot:
    VECTOR3 0.0, 0.0, 0.0

object_scale:
    FLOAT_TO_FP 1.0

object_dir_z:
    FLOAT_TO_FP 1.0

object_dir_max_z:
    FLOAT_TO_FP 128.0

object_dir_min_z:
    FLOAT_TO_FP -24.0

object_rot_speed:
    VECTOR3 0.5, 0.5, 0.5

; ============================================================================

object_num_verts:
    .long Model_Cobra_Num_Verts

object_num_faces:
    .long Model_Cobra_Num_Faces

object_num_edges:
    .long 0

object_verts_p:
    .long model_cobra_verts

object_face_indices_p:
    .long model_cobra_face_indices

object_edge_list_per_face_p:
    .long model_cobra_edges_per_face

object_edge_indices_p:
    .long model_cobra_edge_indices

object_colour_p:
    .long model_cobra_colour_per_face
 
; ============================================================================

transformed_verts_p:
    .long transformed_verts_no_adr

transformed_normals_p:
    .long transformed_verts_no_adr

projected_verts_p:
    .long projected_verts_no_adr

scene3d_reciprocal_table_p:
    .long reciprocal_table_no_adr

; ============================================================================
; ============================================================================

eye_distance_table:
    FLOAT_TO_FP 0.0         ; 0
    FLOAT_TO_FP 0.3         ; 1
    FLOAT_TO_FP 0.6         ; 2
    FLOAT_TO_FP 0.9         ; 3
    FLOAT_TO_FP 1.2         ; 4
    FLOAT_TO_FP 1.5         ; 5
    FLOAT_TO_FP 1.8         ; 6
    FLOAT_TO_FP 2.1         ; 7
    FLOAT_TO_FP 2.4         ; 8
    FLOAT_TO_FP 2.7         ; 9

; R0=distance index.
set_eye_distance:
    strb r0, Anaglyph_Eye_setting

    adr r1, eye_distance_table
    ldr r0, [r1, r0, lsl #2]

    ; For now assume camera is fixed at X=0.
    str r0, RightEye_X_Pos
    mvn r0, r0
    str r0, LeftEye_X_Pos
    mov pc, lr

init_3d_scene:
    str lr, [sp, #-4]!

    mov r0, #EyeDistance_Default_Setting
    bl set_eye_distance

    bl set_palette_for_3d_scene

    ; Make circle object.
    mov r3, #Model_Circle_Radius
    mov r7, #Model_Circle_Num_Verts
    ldr r8, circle_verts_p 
    bl make_2d_object

    ldr pc, [sp], #4

circle_verts_p:
    .long model_circle_verts

set_palette_for_3d_scene:
    ldr r2, palette_p
    b palette_set_block

; ============================================================================
; ============================================================================

transform_3d_scene:
    str lr, [sp, #-4]!

    ; Skip matrix multiplication altogether.
    ; Transform (x,y,z) into (x'',y'',z'') directly.
    ; Uses 12 muls / rotation.

    ldr r0, object_rot + 8
    bl sin_cos
    mov r10, r0, asr #MULTIPLICATION_SHIFT  ; r10 = sin(A)
    mov r11, r1, asr #MULTIPLICATION_SHIFT  ; r11 = cos(A)

    ; See the note on cos(C) below - same trick, same reason.
    cmp r11, #0
    bpl transform_cosa_pos
    rsb r11, r11, #0                        ; r11 = |cos(A)|
    ldr r0, transform_op_rsb_r0
    str r0, transform_patch_cosa_1
    ldr r0, transform_op_mov_r14
    str r0, transform_patch_cosa_2
    b transform_cosa_done
transform_cosa_pos:
    ldr r0, transform_op_mov_r0
    str r0, transform_patch_cosa_1
    ldr r0, transform_op_rsb_r14
    str r0, transform_patch_cosa_2
transform_cosa_done:

    ldr r0, object_rot + 0
    bl sin_cos
    mov r6, r0, asr #MULTIPLICATION_SHIFT  ; r6 = sin(C)
    mov r7, r1, asr #MULTIPLICATION_SHIFT  ; r7 = cos(C)

    ; The ARM2/ARM250 multiplier only terminates early once the remaining bits
    ; of Rs have cleared, so a sign-extended negative Rs runs all 16 Booth
    ; cycles - measured at 16-17 cycles against 5-6 for a positive operand of
    ; the same magnitude. cos(C) sits in Rs for two multiplies per vertex, so
    ; when it is negative that is ~22 wasted cycles on every vertex.
    ;
    ; Keep |cos(C)| in r7 and move the sign into the accumulate instead. The
    ; sign is fixed for the whole frame, so patch the two sites once here
    ; rather than testing per vertex. Same idiom as drawline_set_to_orr.
    cmp r7, #0
    bpl transform_cosc_pos
    rsb r7, r7, #0                          ; r7 = |cos(C)|
    ldr r0, transform_op_rsb_r14
    str r0, transform_patch_cosc_1          ; negate y'*|cos(C)|
    ldr r0, transform_op_mov_r14
    str r0, transform_patch_cosc_2          ; -z'*cos(C) is now +z'*|cos(C)|
    b transform_cosc_done
transform_cosc_pos:
    ldr r0, transform_op_mov_r14
    str r0, transform_patch_cosc_1
    ldr r0, transform_op_rsb_r14
    str r0, transform_patch_cosc_2
transform_cosc_done:

    ldr r0, object_rot + 4
    bl sin_cos                  ; uses r9
    mov r8, r0, asr #MULTIPLICATION_SHIFT  ; r8 = sin(B)
    mov r9, r1, asr #MULTIPLICATION_SHIFT  ; r9 = cos(B)

    ; See the note on cos(C) above - same trick, same reason.
    cmp r9, #0
    bpl transform_cosb_pos
    rsb r9, r9, #0                          ; r9 = |cos(B)|
    ldr r0, transform_op_rsb_r14
    str r0, transform_patch_cosb_1
    ldr r0, transform_op_mov_r14
    str r0, transform_patch_cosb_2
    b transform_cosb_done
transform_cosb_pos:
    ldr r0, transform_op_mov_r14
    str r0, transform_patch_cosb_1
    ldr r0, transform_op_rsb_r14
    str r0, transform_patch_cosb_2
transform_cosb_done:

    ldr r1, object_verts_p
    ldr r2, transformed_verts_p
    ldr r12, object_num_verts

    add r4, r2, r12, lsl #3
    add r4, r4, r12, lsl #2               ; transform_normals=&transformed_verts[object_num_verts]
    str r4, transformed_normals_p

    ldr r3, object_num_faces
    add r12, r12, r3                      ; object_num_verts + object_num_faces

    ; ASSUMES THAT VERTEX AND NORMAL ARRAYS ARE CONSECUTIVE!
    transform_rot_loop:
    ldmia r1!, {r3-r5}                    ; x,y,z
    mov r3, r3, asr #MULTIPLICATION_SHIFT
    mov r4, r4, asr #MULTIPLICATION_SHIFT
    mov r5, r5, asr #MULTIPLICATION_SHIFT

	; x'  = x*cos(A) + y*sin(A)
	; y'  = x*sin(A) - y*cos(A)  
    mul r0, r3, r11                     ; x*|cos(A)|
transform_patch_cosa_1:
    mov r0, r0                          ; RSB when cos(A) is negative
    mla r0, r4, r10, r0                 ; x' = y*sin(A) + x*cos(A)
    mov r0, r0, asr #MULTIPLICATION_SHIFT

    mul r14, r4, r11                    ; y*|cos(A)|
transform_patch_cosa_2:
    rsb r14, r14, #0                    ; MOV when cos(A) is negative
    mla r4, r3, r10, r14                ; y' = x*sin(A) - y*cos(A)
    mov r4, r4, asr #MULTIPLICATION_SHIFT

	; x'' = x'*cos(B) + z*sin(B)
	; z'  = x'*sin(B) - z*cos(B)

    mul r14, r0, r9                     ; x'*|cos(B)|
transform_patch_cosb_1:
    mov r14, r14                        ; RSB when cos(B) is negative
    mla r3, r5, r8, r14                 ; x'' = z*sin(B) + x'*cos(B)

    mul r14, r5, r9                     ; z*|cos(B)|
transform_patch_cosb_2:
    rsb r14, r14, #0                    ; MOV when cos(B) is negative
    mla r5, r0, r8, r14                 ; z' = x'*sin(B) - z*cos(B)
    mov r5, r5, asr #MULTIPLICATION_SHIFT

	; y'' = y'*cos(C) + z'*sin(C)
	; z'' = y'*sin(C) - z'*cos(C)

    mul r14, r4, r7                     ; y'*|cos(C)|
transform_patch_cosc_1:
    mov r14, r14                        ; RSB when cos(C) is negative
    mla r0, r5, r6, r14                 ; y'' = y'*cos(C) + z'*sin(C)

    mul r14, r5, r7                     ; z'*|cos(C)|
transform_patch_cosc_2:
    rsb r14, r14, #0                    ; MOV when cos(C) is negative
    mla r5, r4, r6, r14                 ; z'' = y'*sin(C) - z'*cos(C)

    ; x''=r3, y''=r0, z''=r5
    mov r4, r0
    stmia r2!, {r3-r5}                  ; x'',y'',z'''
    subs r12, r12, #1
    bne transform_rot_loop

    ; Transform to world coordinates.
    adr r11, object_pos
    ldmia r11, {r6-r8}

    ; NB. No longer transformed to camera relative.

    ; Apply object scale after rotation.
    ldr r0, object_scale
    mov r0, r0, asr #MULTIPLICATION_SHIFT

    ldr r2, transformed_verts_p
    ldr r12, object_num_verts
    transform_scale_loop:
    ldmia r2, {r3-r5}

    ; Scale rotated verts.
    ; TODO: Can we do this with a shift instead of MUL?
    mov r3, r3, asr #MULTIPLICATION_SHIFT
    mov r4, r4, asr #MULTIPLICATION_SHIFT
    mov r5, r5, asr #MULTIPLICATION_SHIFT

    mul r3, r0, r3      ; x_scaled=x*object_scale
    mul r4, r0, r4      ; y_scaled=y*object_scale
    mul r5, r0, r5      ; z_scaled=z*object_scale

    ; Make object vertices camera relative.
    add r3, r3, r6      ; x_scaled + object_pos_x - camera_pos_x
    add r4, r4, r7      ; y_scaled + object_pos_y - camera_pos_y
    add r5, r5, r8      ; z_scaled + object_pos_z - camera_pos_z

    stmia r2!, {r3-r5}
    subs r12, r12, #1
    bne transform_scale_loop

    ldr pc, [sp], #4

; Instruction templates for the cos(C) sign patch above. Data, never executed
; from here - the function returns before reaching them.
transform_op_mov_r14:
    mov r14, r14
transform_op_rsb_r14:
    rsb r14, r14, #0
transform_op_mov_r0:
    mov r0, r0
transform_op_rsb_r0:
    rsb r0, r0, #0

update_3d_scene_move_in_z:
    ldr r0, object_pos+8            ; POSTION_Z
    ldr r1, object_dir_z
    add r0, r0, r1

    ; TODO: Easing functions when close to min/max.

    ldr r2, object_dir_max_z
    ldr r3, object_dir_min_z
    cmp r0, r2
    mvnge r1, r1                    ; invert dir
    cmp r0, r3
    mvnle r1, r1                    ; invert dir

    str r0, object_pos+8
    str r1, object_dir_z


update_3d_scene_from_vars:
    str lr, [sp, #-4]!

    ; Update any scene vars, camera, object position etc. (Rocket?)
    ldr r1, object_rot_speed + 0 ; ROTATION_X
    ldr r0, object_rot+0
    add r0, r0, r1
    bic r0, r0, #0xff000000         ; brads
    str r0, object_rot+0

    ldr r1, object_rot_speed + 4 ; ROTATION_Y
    ldr r0, object_rot+4
    add r0, r0, r1
    bic r0, r0, #0xff000000         ; brads
    str r0, object_rot+4

    ldr r1, object_rot_speed + 8 ; ROTATION_Z
    ldr r0, object_rot+8
    add r0, r0, r1
    bic r0, r0, #0xff000000         ; brads
    str r0, object_rot+8

    ; Transform the object into world space.
    bl transform_3d_scene
    ldr pc, [sp], #4

update_3d_scene_from_vu_bars:
    str lr, [sp, #-4]!

	mov r0, #0
	swi QTM_ReadVULevels
	; R0 = word containing 1 byte per channel 1-4 VU bar heights 0-64
    ; TODO: Finalise mapping of vu levels to scale & rotation deltas.
  	mov r10, r0, lsr #24            ; channel 4 = scale
	ands r10, r10, #0xff
    bne .1
    ldr r1, object_scale
    cmp r1, #MATHS_CONST_HALF
    subgt r1, r1, #MATHS_CONST_1*0.01
    b .2
    
    .1:
    mov r1, #MATHS_CONST_1
    add r1, r1, r10, asl #10         ; scale maps [1, 2]
    .2:
    str r1, object_scale

    ; TODO: Make this code more compact?
  	mov r10, r0, lsr #8             ; channel 2 = inc_x
	and r10, r10, #0xff
    mov r10, r10, asl #11           ; inc_x maps [0, 2]
    ldr r1, object_rot + 0
    add r1, r1, r10                 ; object_rot_x += inc_x
    str r1, object_rot + 0

  	mov r10, r0, lsr #16            ; channel 3 = inc_y
	and r10, r10, #0xff
    mov r10, r10, asl #11           ; inc_y maps [0, 2]
    ldr r1, object_rot + 4
    add r1, r1, r10                 ; object_rot_y += inc_y
    str r1, object_rot + 4

    and r10, r0, #0xff              ; channel 1 = inc_z
    mov r10, r10, asl #11           ; inc_z maps [0, 2]
    ldr r1, object_rot + 8
    add r1, r1, r10                 ; object_rot_z += inc_z
    str r1, object_rot + 8

    ; Transform the object into world space.
    bl transform_3d_scene
    ldr pc, [sp], #4

; ============================================================================
; ============================================================================

; R12=screen addr
anaglyph_draw_3d_scene_as_circles:             ; TODO: Dedupe this code!
    str lr, [sp, #-4]!

    ; Stash screen addr for now.
    str r12, [sp, #-4]!

	; Reset array of circles.
    bl reset_circles

    ; Left eye.
    ldr r0, LeftEye_X_Pos
    str r0, camera_pos+0        ; camera_pos_x

    ; Subtract blue & green.
    mov r4, #7                  ; brightest red
    bl draw_3d_object_as_circles

    ; Right eye.
    ldr r0, RightEye_X_Pos
    str r0, camera_pos+0        ; camera_pos_x

    ; Subtract red.
    mov r4, #11                 ; brightest cyan
    bl draw_3d_object_as_circles

    ; Then plot all the circles.
    ldr r12, [sp], #4           ; pop screen addr
    bl plot_all_circles

    ldr pc, [sp], #4

; R12=screen addr
anaglyph_draw_3d_scene_as_wire:             ; TODO: Dedupe this code!
    str lr, [sp, #-4]!

    ; Left eye.
    ldr r0, LeftEye_X_Pos
    str r0, camera_pos+0        ; camera_pos_x

    ; Subtract blue & green.
    mov r4, #7                 ; brightest red
    ;mov r4, #8                  ; bic 0b1000
    bl draw_3d_scene_wire

    ; Right eye.
    ldr r0, RightEye_X_Pos
    str r0, camera_pos+0        ; camera_pos_x

    ; Subtract red.
    mov r4, #11                ; brightest cyan
    ;mov r4, #4                  ; bic 0b0100
    bl draw_3d_scene_wire

    ldr pc, [sp], #4

; R12=screen addr
anaglyph_draw_3d_scene_as_outline:             ; TODO: Dedupe this code!
    str lr, [sp, #-4]!

    ; Left eye.
    ldr r0, LeftEye_X_Pos
    str r0, camera_pos+0        ; camera_pos_x

    ; Subtract blue & green.
    mov r4, #7                 ; brightest red
    ;mov r4, #8                  ; bic 0b1000
    bl draw_3d_scene_outline

    ; Right eye.
    ldr r0, RightEye_X_Pos
    str r0, camera_pos+0        ; camera_pos_x

    ; Subtract red.
    mov r4, #11                ; brightest cyan
    ;mov r4, #4                  ; bic 0b0100
    bl draw_3d_scene_outline

    ldr pc, [sp], #4

; R12=screen addr
anaglyph_draw_3d_scene_as_solid:             ; TODO: Dedupe this code!
    str lr, [sp, #-4]!

    ; Left eye.
    ldr r0, LeftEye_X_Pos
    str r0, camera_pos+0        ; camera_pos_x

    ; Subtract blue & green.
    mov r4, #7                  ; brightest red
    adr r4, colour_lookup_red
    bl draw_3d_scene_solid

    ; Right eye.
    ldr r0, RightEye_X_Pos
    str r0, camera_pos+0        ; camera_pos_x

    ; Subtract red.
    mov r4, #11                 ; brightest cyan
    adr r4, colour_lookup_cyan
    bl draw_3d_scene_solid

    ldr pc, [sp], #4

object_colour_index:
    .long 0

project_3d_scene:
    ; Load camera [x, y, z].
    adr r0, camera_pos
    ldmia r0, {r6-r8}

    ; Project vertices to screen.
    ldr r2, transformed_verts_p
    ldr r9, scene3d_reciprocal_table_p
    ldr r1, object_num_verts
    ldr r10, projected_verts_p
    .1:
    ; R2=ptr to world pos vector
    ; bl project_to_screen

    ; Load transformed verts [R3,R5,R5] = [x,y,z]
    ldmia r2!, {r3-r5}

    ; Subtract camera_pos from world_pos.
    sub r3, r3, r6
    sub r4, r4, r7
    sub r5, r5, r8

    ; Project to screen.

    ; Put divisor in table range.
    mov r5, r5, asr #16-LibDivide_Reciprocal_s    ; [16.6]    (b<<s)

    .if _DEBUG
    cmp r5, #0
    bgt .2
    adrle r0,errbehindcamera    ; and flag an error
    swile OS_GenerateError      ; when necessary
    .2:
    ; TODO: Probably just cull these objects?

    ; Limited precision.
    cmp r5, #1<<LibDivide_Reciprocal_t    ; Test for numerator too large
    adrge r0,divrange           ; and flag an error
    swige OS_GenerateError      ; when necessary
    .endif

    ; Lookup 1/z.
    ldr r5, [r9, r5, lsl #2]    ; [0.16]    (1<<16+s)/(b<<s) = (1<<16)/b

    ; x/z
    mov r3, r3, asr #16-LibDivide_Reciprocal_s    ; [16.6]    (a<<s)
    mul r3, r5, r3                      ; [10.22]   (a<<s)*(1<<16)/b = (a<<16+s)/b
    mov r3, r3, asr #LibDivide_Reciprocal_s       ; [10.16]   (a<<16)/b = (a/b)<<16

    ; y/z
    mov r4, r4, asr #16-LibDivide_Reciprocal_s    ; [16.6]    (a<<s)
    mul r4, r5, r4                      ; [10.22]   (a<<s)*(1<<16)/b = (a<<16+s)/b
    mov r4, r4, asr #LibDivide_Reciprocal_s       ; [10.16]   (a<<16)/b = (a/b)<<16

    ; screen_x = vp_centre_x + vp_scale * (x-cx) / (z-cz)
    mov r0, #VIEWPORT_SCALE>>12 ; [16.4]
    mul r3, r0, r3              ; [12.20]
    mov r3, r3, asr #4           ; [12.16]
    mov r0, #VIEWPORT_CENTRE_X  ; [16.16]
    add r3, r3, r0

    ldrb r0, Anaglyph_Enable_Skew
    cmp r0, #0
    addne r3, r3, r6, asl #1     ; camera_pos_x * 2

    ; screen_y = vp_centre_y - vp_scale * (y-cy) / (z-cz)
    mov r0, #VIEWPORT_SCALE>>12 ; [16.4]
    mul r4, r0, r4              ; [12.20]
    mov r4, r4, asr #4           ; [12.16]
    mov r0, #VIEWPORT_CENTRE_Y  ; [16.16]
    sub r4, r0, r4              ; [16.16]

    ; R0=screen_x, R1=screen_y [16.16]
    mov r3, r3, asr #16         ; [16.0]
    mov r4, r4, asr #16         ; [16.0]

    stmia r10!, {r3, r4}
    subs r1, r1, #1
    bne .1

    mov pc, lr

; R4=colour index
; R12=screen addr
draw_3d_scene_solid:             ; TODO: Dedupe this code!
    str lr, [sp, #-4]!
    str r4, object_colour_index

    ; Project world space verts to screen space.
    bl project_3d_scene
 
    ; Plot faces as polys.
    mov r9, #0                  ; face count
    str r9, edge_plot_cache

    ldr r11, object_num_faces
    sub r11, r11, #1

    .2:
    ldr r9, object_face_indices_p
    ldrb r5, [r9, r11, lsl #2]  ; vertex0 of polygon N.
    
    ldr r1, transformed_verts_p
    add r1, r1, r5, lsl #3
    add r1, r1, r5, lsl #2      ; transformed_verts + index*12
    ldr r2, transformed_normals_p
    add r2, r2, r11, lsl #3      ; face_normal for polygon N.
    add r2, r2, r11, lsl #2      ; face_normal for polygon N.

    ; Backfacing culling test (vertex - camera_pos).face_normal
    ; Parameters:
    ;  R1=ptr to transformed vertex in camera relative space
    ;  R2=ptr to face normal vector
    ; Return:
    ;  R0=dot product of (v0-cp).n
    ; Trashes: r3-r8
    ; vector A = (v0 - camera_pos)
    ; vector B = face_normal

    ldmia r1!, {r3-r5}          ; [tx, ty, tz]
    adr r0, camera_pos
    ldmia r0, {r6-r8}           ; camera_pos

    sub r3, r3, r6
    sub r4, r4, r7
    sub r5, r5, r8

    bl vector_dot_product_load_B ; trashes r3-r8
    cmp r0, #0                  
    bpl .3                      ; normal facing away from the view direction.

    ; TODO: Screen space winding order test:
    ;       (y1 - y0) * (x2 - x1) - (x1 - x0) * (y2 - y1) > 0

    ; SOLID
    ldr r2, projected_verts_p   ; projected vertex array.
    ldr r3, [r9, r11, lsl #2]   ; quad indices.

    stmfd sp!, {r11,r12}

    ; TODO: Sort out a colour per face scheme.
    ldr r4, object_colour_p
    ldrb r4, [r4, r11]
    ldr r0, object_colour_index     ; actually colour lookup
    ldrb r4, [r0, r4]

    ;  R12=screen addr
    ;  R2=ptr to projected vertex array (x,y) in screen coords [16.0]
    ;  R3=4x vertex indices for quad
    ;  R4=colour index
    bl triangle_plot_quad_indexed   ; faster than polygon_plot_quad_indexed.
    ldmfd sp!, {r11,r12}

    .3:
    subs r11, r11, #1
    bpl .2

    ldr pc, [sp], #4

colour_lookup_red:
    .byte 0,1,4,5,6,7,7,7

colour_lookup_cyan:
    .byte 0,2,8,9,10,11,11,11

; R4=colour index
; R12=screen addr
draw_3d_scene_wire:             ; TODO: Dedupe this code!
    str lr, [sp, #-4]!
    str r4, object_colour_index

    ; Project world space verts to screen space.
    bl project_3d_scene

    ; Plot faces as polys.
    mov r9, #0                  ; face count
    str r9, edge_plot_cache

    ldr r11, object_num_faces
    sub r11, r11, #1

    .2:
    ldr r9, object_face_indices_p
    ldrb r5, [r9, r11, lsl #2]   ; vertex0 of polygon N.
    
    ldr r1, transformed_verts_p
    add r1, r1, r5, lsl #3
    add r1, r1, r5, lsl #2       ; transformed_verts + index*12
    ldr r2, transformed_normals_p
    add r2, r2, r11, lsl #3      ; face_normal for polygon N.
    add r2, r2, r11, lsl #2      ; face_normal for polygon N.

    ; Backfacing culling test (vertex - camera_pos).face_normal
    ; Parameters:
    ;  R1=ptr to transformed vertex in camera relative space
    ;  R2=ptr to face normal vector
    ; Return:
    ;  R0=dot product of (v0-cp).n
    ; Trashes: r3-r8
    ; vector A = (v0 - camera_pos)
    ; vector B = face_normal

    ldmia r1!, {r3-r5}          ; [tx, ty, tz]
    adr r0, camera_pos
    ldmia r0, {r6-r8}           ; camera_pos

    sub r3, r3, r6
    sub r4, r4, r7
    sub r5, r5, r8

    bl vector_dot_product_load_B ; trashes r3-r8
    cmp r0, #0                  
    bpl .3                      ; normal facing away from the view direction.

    ; WIREFRAME
    ldr r4, object_colour_index
    ldr r5, object_edge_indices_p
    ldr r6, projected_verts_p   ; projected vertex array.
    ldr r7, object_edge_list_per_face_p
    ldr r7, [r7, r11, lsl #2]   ; edge list word for polygon N.

    stmfd sp!, {r11}
    bl plot_face_edge_list      ; trashes r0-r11
    ldmfd sp!, {r11}

    .3:
    subs r11, r11, #1
    bpl .2

    ldr pc, [sp], #4

edge_plot_cache:
    .long 0

; Plot all edges in a list.
; Parameters:
;  R12=screen addr
;  R4=colour index
;  R5=ptr to array of edge indices.
;  R6=ptr to projected vertex array (x,y) in screen coords [16.0]
;  R7=edge list word (one bit per edge to be plotted)
plot_face_edge_list:
	str lr, [sp, #-4]!			; push lr on stack

    ldr r11, edge_plot_cache
    mov r8, #0                  ; edge no.
.1:
    ; Convert edge no. to bit no.
    mov r9, #1

    ; Test edge list cache.
    tst r11, r9, lsl r8         ; already plotted?
    bne .2

    ; Test if this edge is in the face.
    tst r7, r9, lsl r8
    beq .2

    ; Look up vertex indices for edge.
    ldr r0, [r5, r8, lsl #1]    ; misaligned read!
    mov r2, r0, lsr #8          ; end index
    and r0, r0, #0xff           ; start index
    and r2, r2, #0xff

    ; Load (x,y) for start vertex
    add r9, r6, r0, lsl #3      ; projected_verts[start_index]
    ldmia r9, {r0,r1}           ; start_x, start_y

    ; Load (x,y) for end vertex
    add r9, r6, r2, lsl #3      ; projected_verts[start_index]
    ldmia r9, {r2,r3}           ; end_x, end_y

    stmfd sp!, {r5-r8}
    bl mode9_drawline_orr       ; trashes r5-r9
    ldmfd sp!, {r5-r8}

    ; Mark edge as plotted in cache.
    mov r9, #1
    orr r11, r11, r9, lsl r8

.2:
    ; Early out when edge list word is zero.
    bics r7, r7, r9, lsl r8
    beq .3

    ; Next edge no.
    add r8, r8, #1
    cmp r8, #32
    blt .1

.3:
    str r11, edge_plot_cache
    ldr pc, [sp], #4


; R4=colour index
; R12=screen addr
draw_3d_scene_outline:             ; TODO: Dedupe this code!
    str lr, [sp, #-4]!
    str r4, object_colour_index

    ; Project world space verts to screen space.
    bl project_3d_scene

    ldr r8, object_num_edges
    sub r8, r8, #1              ; edge no.

    ; OUTLINE
    .1:
    ldr r4, object_colour_index
    ldr r5, object_edge_indices_p
    ldr r6, projected_verts_p   ; projected vertex array.

    ; Look up vertex indices for edge.
    ldr r0, [r5, r8, lsl #1]    ; misaligned read!
    mov r2, r0, lsr #8          ; end index
    and r0, r0, #0xff           ; start index
    and r2, r2, #0xff

    ; Load (x,y) for start vertex
    add r9, r6, r0, lsl #3      ; projected_verts[start_index]
    ldmia r9, {r0,r1}           ; start_x, start_y

    ; Load (x,y) for end vertex
    add r9, r6, r2, lsl #3      ; projected_verts[start_index]
    ldmia r9, {r2,r3}           ; end_x, end_y

    stmfd sp!, {r8}
    bl mode9_drawline_with_clip       ; trashes r5-r9
    ldmfd sp!, {r8}

    subs r8, r8, #1
    bpl .1

    ldr pc, [sp], #4


; Project world position to screen coordinates.
; TODO: Try weak perspective model, i.e. a single distance for all vertices in the objects.
;       Means that we can calculate the reciprocal once (1/z) and use the same value in
;       all perspective calculations. Suspect this is what most Amiga & ST demos do...
;
; R2=ptr to camera relative transformed position
; Returns:
;  R0=screen x
;  R1=screen y
; Trashes: R3-R6,R8-R10
.if 0
project_to_screen:
    str lr, [sp, #-4]!

    ; Vertex already transformed and camera relative.
    ldmia r2, {r3-r5}           ; (x,y,z)

    ; vp_centre_x + vp_scale * (x-cx) / (z-cz)
    mov r0, r3                  ; (x-cx)
    mov r1, r5                  ; (z-cz)
    ; Trashes R8-R10!
    bl divide                   ; (x-cx)/(z-cz)
                                ; [0.16]

    ; TODO: Could also speed this up by choosing a viewport scale as a shift, e.g. 128.

    mov r8, #VIEWPORT_SCALE>>12 ; [16.4]
    mul r6, r0, r8              ; [12.20]
    mov r6, r6, asr #4          ; [12.16]
    mov r8, #VIEWPORT_CENTRE_X  ; [16.16]
    add r6, r6, r8

    ; TODO: Speed this up by doing one lookup for the reciprocal of the divisor (z-cz).
    ;       As this is constant. See scene2d_transform_object as example.

    ; Flip Y axis as we want +ve Y to point up the screen!
    ; vp_centre_y - vp_scale * (y-cy) / (z-cz)
    mov r0, r4                  ; (y-cy)
    mov r1, r5                  ; (z-cz)
    ; Trashes R8-R10!
    bl divide                   ; (y-cy)/(z-cz)
                                ; [0.16]
    mov r8, #VIEWPORT_SCALE>>12 ; [16.4]
    mul r1, r0, r8              ; [12.20]
    mov r1, r1, asr #4          ; [12.16]
    mov r8, #VIEWPORT_CENTRE_Y  ; [16.16]
    sub r1, r8, r1              ; [16.16]

    mov r0, r6
    ldr pc, [sp], #4
.endif

; R4=colour index
; R12=screen addr
draw_3d_object_as_circles:
    str lr, [sp, #-4]!
    str r4, object_colour_index

    ; Project world space verts to screen space.
    bl project_3d_scene

    ; Plot all verts as circles...
    ldr r6, projected_verts_p
    ldr r7, transformed_verts_p
    ldr r11, object_num_verts
    mov r5, #0
    ldr r4, camera_pos+8        ; camera_pos_z

    ; TODO: Would ultimately need to sort by Z.
    ; TODO: A fixed number of sprites with radius [1,16] would be faster, i.e. vector balls!

    ; TODO: Compute screen_radius alongside projected X,Y.

    .2:
    ; screen_radius = VP_SCALE * world_radius / (z-cz)
    mov r0, #VIEWPORT_SCALE
    ldr r1, [r7, #8]            ; (z)
    sub r1, r1, r4              ; (z-cz)
    bl divide                   ; [s7.16] (trashes r8-r10)
    mov r2, r0, asr #13         ; radius = VP_SCALE * world_radius / (z-cz) where world_radius=8 (r<<3>>16)

    ldmia r6!, {r0,r1}          ; screen_X & screen_Y.

    ldr r9, object_colour_index
    bl add_circle_to_2d_list    ; trashes r8,r12

    add r7, r7, #VECTOR3_SIZE
    add r5, r5, #1
    cmp r5, r11
    blt .2

    ldr pc, [sp], #4

; ============================================================================
; ============================================================================
