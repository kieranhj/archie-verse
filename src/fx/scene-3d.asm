; ============================================================================
; 3D Scene.
; Note camera is fixed to view down +z axis.
; Does not support camera rotation / look at.
; Single 3D object per scene.
; Supports position, rotation & scale of the object within the scene.
; Used in: Chipo Django musicdisk, Three-Dee Demo (mikroreise)
; ============================================================================

.equ Scene3d_UseLighting,       1       ; TODO: Should be a separate draw func.
.equ Scene3d_UseLightDirection, 1       ; TODO: Should be a separate draw func.

.equ Entity_Pos,                0
.equ Entity_PosX,               0
.equ Entity_PosY,               4
.equ Entity_PosZ,               8
.equ Entity_Rot,                12
.equ Entity_RotX,               12
.equ Entity_RotY,               16
.equ Entity_RotZ,               20
.equ Entity_Scale,              24
.equ Entity_MeshPtr,            28
.equ Entity_SIZE,               32

; ============================================================================
; The camera viewport is assumed to be [-1,+1] across its widest axis.
; Therefore we multiply all projected coordinates by the screen width/2
; in order to map the viewport onto the entire screen.

; TODO: Define these somewhere else?
.equ VIEWPORT_SCALE,            (Screen_Width /2) * PRECISION_MULTIPLIER
.equ VIEWPORT_CENTRE_X,         (Screen_Width /2) * PRECISION_MULTIPLIER
.equ VIEWPORT_CENTRE_Y,         (Screen_Height /2) * PRECISION_MULTIPLIER

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

camera_pos:
    VECTOR3 0.0, 0.0, -80.0

; ============================================================================
; Pointer to a single 3D object in the scene.
; ============================================================================

scene3d_entity_p:
    .long torus_entity

cube_entity:
    VECTOR3 0.0, 0.0, 16.0      ; object_pos
    VECTOR3 0.0, 0.0, 0.0       ; object_rot
    FLOAT_TO_FP 1.0             ; object_scale
    .long mesh_header_cube      ; mesh ptr      ; put this first?

cobra_entity:
    VECTOR3 0.0, 0.0, 16.0      ; object_pos
    VECTOR3 0.0, 0.0, 0.0       ; object_rot
    FLOAT_TO_FP 2.0             ; object_scale
    .long mesh_header_cobra     ; mesh ptr

torus_entity:
    VECTOR3 0.0, 0.0, 0.0       ; object_pos
    VECTOR3 0.0, 0.0, 0.0       ; object_rot
    FLOAT_TO_FP 1.0             ; object_scale
    .long mesh_header_torus_flipped     ; mesh ptr

torus_mesh_regular_p:
    .long mesh_header_torus     ; mesh ptr

torus_mesh_flipped_p:
    .long mesh_header_torus_flipped     ; mesh ptr

; ============================================================================
; Ptrs to buffers / tables.
; ============================================================================

.equ OBJ_MAX_VERTS, 128
.equ OBJ_MAX_FACES, 128

; These are stored as [s9.7] fixed point format (ready for MUL).
transformed_verts_p:
    .long transformed_verts_no_adr

; These are stored as [s1.8] fixed point format (ready for MUL).
transformed_normals_p:
    .long transformed_verts_no_adr

; These are stored as [s15.0] fixed point format (ready for screen).
projected_verts_p:
    .long projected_verts_no_adr

scene3d_reciprocal_table_p:
    .long reciprocal_table_no_adr

; ============================================================================
; ============================================================================

.if _DEBUG
scene3d_stats_quads_plotted:
    .long 0
.endif

; ============================================================================

scene3d_init:
    str lr, [sp, #-4]!

;    DEBUG_REGISTER_VEC3 object_target_pos
;    DEBUG_REGISTER_VEC3 torus_entity+Entity_Pos

    ; SHOW normal_transform Z vector!!
;    DEBUG_REGISTER_VEC3 normal_transform+MATRIX_20

    ldr pc, [sp], #4

; ============================================================================
; Transform the current object (not scene) into world space.
; ============================================================================

scene3d_transform_entity:
    str lr, [sp, #-4]!

    ldr r2, scene3d_entity_p
    ldr r12, [r2, #Entity_MeshPtr]
    ldr r14, [r12, #MeshHeader_NumVerts]
    ldr r3,  [r12, #MeshHeader_NumFaces]
    ldr r12, [r12, #MeshHeader_VertsPtr]

    ; TODO: Update transformed_normals_p at init.
    ldr r2, transformed_verts_p
    add r4, r2, r14, lsl #3
    add r4, r4, r14, lsl #2               ; transform_normals=&transformed_verts[object_num_verts]
    str r4, transformed_normals_p

    add r14, r14, r3                      ; object_num_verts + object_num_faces

    ; Load matrix.

    adr r0, normal_transform
    ldmia r0, {r0-r8}

    ; TODO: Pre-shift matrix elements.
    mov r0, r0, asr #MULTIPLICATION_SHIFT
    mov r1, r1, asr #MULTIPLICATION_SHIFT
    mov r2, r2, asr #MULTIPLICATION_SHIFT
    mov r3, r3, asr #MULTIPLICATION_SHIFT
    mov r4, r4, asr #MULTIPLICATION_SHIFT
    mov r5, r5, asr #MULTIPLICATION_SHIFT
    mov r6, r6, asr #MULTIPLICATION_SHIFT
    mov r7, r7, asr #MULTIPLICATION_SHIFT
    mov r8, r8, asr #MULTIPLICATION_SHIFT

    ; ASSUMES THAT VERTEX AND NORMAL ARRAYS ARE CONSECUTIVE!
    .1:
        ; 3x3 MATRIX MULTIPLICATION THANKS TO PROGEN!
        LDMIA r12!, {r9, r10} ;x, y
    
        ; TODO: Pre-shift vector elements.
        mov r9, r9, asr #MULTIPLICATION_SHIFT
        mov r10, r10, asr #MULTIPLICATION_SHIFT

        ORR r12, r14, r12, LSL #11  ; count | src_ptr << 11 (free up r14)

        ;r0-r8 - matrix
        ;r9, r10 - x, y
        ;r11 - temp
        ;r12 - source ptr
        ;r14 - temp

        MUL r11, r9, r6             ;z=x*m20 + y*m21
        MLA r11, r10, r7, r11

        MUL r14, r10, r1            ;x = y*m01

        MUL r10, r4, r10            ;y = y*m11
        MLA r10, r3, r9, r10        ;y = x*m00 + y*m11

        MLA r9, r0, r9, r14         ;x = x*m00 + y*m01

        MOV r14, r12, LSR #11       ; extract src_ptr
        LDR r14, [r14]              ;z

        ; TODO: Pre-shift vector elements.
        mov r14, r14, asr #MULTIPLICATION_SHIFT

        ADD r12, r12, #4<<11        ; increment embeded src_ptr

        MLA r9, r2, r14, r9         ;x = x*m00 + y*m01 + z*m02
        MLA r10, r5, r14, r10       ;y = x*m01 + y*m11 + z*m12
        MLA r11, r8, r14, r11       ;z = x*m02 + y*m21 + z*m22        

        MOV r14, r12, LSL #(32-11)
        MOV r14, r14, LSR #(32-11)  ; extract count
        MOV r12, r12, LSR #11       ; extract src_ptr

        ; Progen converts these to INTs but leave as s15.16 for now.
        ;MOV r9, r9, ASR #12         ; s7.12 after MUL
        ;MOV r10, r10, ASR #12
        ;MOV r11, r11, ASR #12
        STMFD sp!, {r9, r10, r11}   ; push on stack

        SUBS r14, r14, #1
    bne .1

    ; Pop these off the stack but write to correct position in the array.
    ldr r11, scene3d_entity_p

    ldr r12, [r11, #Entity_MeshPtr]
    ldr r10, [r12, #MeshHeader_NumFaces]

    ; Pop off normals into transformed_normals_p.
    ldr r9, transformed_normals_p
    sub r10, r10, #1
    add r9, r9, r10, lsl #3
    add r9, r9, r10, lsl #2             ; top of normals array

    ; Store preshifted ready for MULs.
    .2:
    ldmfd sp!, {r0-r2}                  ; [s1.16]
    mov r0, r0, asr #8                  ; [s1.8]
    mov r1, r1, asr #8
    mov r2, r2, asr #8
    stmia r9, {r0-r2}
    sub r9, r9, #12
    subs r10, r10, #1
    bpl .2

    ; Transform rotated verts to world coordinates.
    ldmia r11, {r6-r8}                  ; pos vector

    ; Move everything relative to the camera.
    adr r0, camera_pos
    ldmia r0, {r0-r2}                   ; camera_pos

    sub r6, r6, r0
    sub r7, r7, r1
    sub r8, r8, r2

    ; Apply object scale after rotation.
    ldr r0, [r11, #Entity_Scale]        ; object_scale
    mov r0, r0, asr #MULTIPLICATION_SHIFT

    ldr r2, transformed_verts_p
    ldr r12, [r12, #MeshHeader_NumVerts]

    sub r12, r12, #1
    add r2, r2, r12, lsl #3
    add r2, r2, r12, lsl #2         ; top of verts array

    .3:
    ldmfd sp!, {r3-r5}

    cmp r0, #MATHS_CONST_1
    beq .4

    ; Scale rotated verts.
    mov r3, r3, asr #MULTIPLICATION_SHIFT
    mov r4, r4, asr #MULTIPLICATION_SHIFT
    mov r5, r5, asr #MULTIPLICATION_SHIFT

    mul r3, r0, r3      ; x_scaled=x*object_scale
    mul r4, r0, r4      ; y_scaled=y*object_scale
    mul r5, r0, r5      ; z_scaled=z*object_scale

    .4:
    ; Move object vertices into world space.
    add r3, r3, r6      ; x_scaled + object_pos_x - camera_pos_x
    add r4, r4, r7      ; y_scaled + object_pos_y - camera_pos_y
    add r5, r5, r8      ; z_scaled + object_pos_z - camera_pos_z

    ; Store transformed verts preshifted ready for MULs.
    mov r3, r3, asr #9  ; [s8.7]
    mov r4, r4, asr #9  ; [s8.7]
    mov r5, r5, asr #9  ; [s8.7]

    ; Store from the end of the array to the start.
    stmia r2, {r3-r5}
    sub r2, r2, #12     ; VECTOR3_Size

    subs r12, r12, #1
    bpl .3

    ldr pc, [sp], #4

.if AppConfig_StackSize < (OBJ_MAX_VERTS+OBJ_MAX_FACES)*VECTOR3_SIZE
.err "Stack is too small for scene3d_transform_entity - will overflow when pushing verts!"
.endif

; ============================================================================
; Rotate the current object from either vars or VU bars.
; ============================================================================

object_rot_speed:
    VECTOR3 0.5, 0.0, 0.0

object_transform:           ; Inc. scale, no translate.
    MATRIX33_IDENTITY

normal_transform:           ; Rotation only.
    MATRIX33_IDENTITY

temp_matrix_1:
    MATRIX33_IDENTITY

temp_matrix_2:
    MATRIX33_IDENTITY

scene3d_rotate_entity:
    str lr, [sp, #-4]!

    ; Create rotation matrix as object transform.
    ldr r10, scene3d_entity_p

    ; TODO: Make rotation matrix directly.
    adr r2, temp_matrix_1
    ldr r0, [r10, #Entity_RotX]
    bl matrix_make_rotate_x     ; T1=rot_x

    adr r2, object_transform
    ldr r0, [r10, #Entity_RotY]
    bl matrix_make_rotate_y     ; OT=rot_y

    adr r0, temp_matrix_1
    adr r1, object_transform
    adr r2, temp_matrix_2
    bl matrix_multiply          ; T2=T1.OT
    ; Trashes R10

    ldr r10, scene3d_entity_p
    ldr r0, [r10, #Entity_RotZ]
    adr r2, temp_matrix_1
    bl matrix_make_rotate_z     ; T1=rot_z

    adr r0, temp_matrix_2
    adr r1, temp_matrix_1
    adr r2, normal_transform    ; NT=T2.T1  <== rotation only.
    bl matrix_multiply

.if 0                           ; NB. Object scale applied directly at entity transform.
    ldr r0, [r10, #Entity_Scale]
    adr r2, temp_matrix_2
    bl matrix_make_scale        ; T2=scale

    adr r0, temp_matrix_2
    adr r1, normal_transform
    adr r2, object_transform    ; OT=T2.NT
    bl matrix_multiply
.endif

    ; Transform the object into world space.
    ;    bl scene3d_transform_entity
    ; NB. Now do this explicitly in sequences script so entity updates can be composed.

    ; Update any scene vars, camera, object position etc. (Rocket?)
    ldr r10, scene3d_entity_p

    ldr r1, object_rot_speed + 0 ; ROTATION_X
    ldr r0, [r10, #Entity_RotX]
    add r0, r0, r1
    bic r0, r0, #0xff000000         ; brads
    str r0, [r10, #Entity_RotX]

    ldr r1, object_rot_speed + 4 ; ROTATION_Y
    ldr r0, [r10, #Entity_RotY]
    add r0, r0, r1
    bic r0, r0, #0xff000000         ; brads
    str r0, [r10, #Entity_RotY]

    ldr r1, object_rot_speed + 8 ; ROTATION_Z
    ldr r0, [r10, #Entity_RotZ]
    add r0, r0, r1
    bic r0, r0, #0xff000000         ; brads
    str r0, [r10, #Entity_RotZ]

    ldr pc, [sp], #4

object_target_pos:
    VECTOR3 0.0, 0.0, 0.0

object_target_lerp_factor:
    FLOAT_TO_FP 0.1

scene3d_bodge_torus_draw_order:
    adr r10, torus_entity
    ldr r0, normal_transform+MATRIX_22   ; norm[z].z
    cmp r0, #0
    ; MI=use regular
    ldrmi r1, torus_mesh_regular_p
    ; PL=use flipped
    ldrpl r1, torus_mesh_flipped_p
    str r1,  [r10, #Entity_MeshPtr]     ; torus_entity.meshptr
    mov pc, lr

; Lerp the entity towards a target position.
scene3d_move_entity_to_target:
    str lr, [sp, #-4]!

    ldr r10, scene3d_entity_p
    ldmia r10, {r0-r2}              ; Entity Pos

    adr r9, object_target_pos
    ldmia r9, {r3-r5}               ; target pos

    ; Calculate delta=(target-pos).
    sub r3, r3, r0
    sub r4, r4, r1
    sub r5, r5, r2

    ; Scale this by our lerp factor.
    ldr r6, object_target_lerp_factor

    ; Multiplication scaling.
    mov r3, r3, asr #8
    mov r4, r4, asr #8
    mov r5, r5, asr #8              ; s15.8

    ; Calculate new pos = pos + (target-pos) * lerp.
    mul r3, r6, r3
    mul r4, r6, r4
    mul r5, r6, r5

    add r0, r0, r3, asr #8
    add r1, r1, r4, asr #8
    add r2, r2, r5, asr #8

    ; Store new pos.
    stmia r10, {r0-r2}

    ldr pc, [sp], #4

.if 0
scene3d_update_entity_from_vubars:
    str lr, [sp, #-4]!

	mov r0, #0
	QTMSWI QTM_ReadVULevels

    ldr r2, scene3d_entity_p

	; R0 = word containing 1 byte per channel 1-4 VU bar heights 0-64
  	mov r10, r0, lsr #24            ; channel 4 = scale
	ands r10, r10, #0xff
    bne .1
    ldr r1, [r2, #Entity_Scale]     ; object_scale
    cmp r1, #MATHS_CONST_HALF
    subgt r1, r1, #MATHS_CONST_1*0.01
    b .2
    
    .1:
    mov r1, #MATHS_CONST_1
    add r1, r1, r10, asl #10         ; scale maps [1, 2]
    .2:
    str r1, [r2, #Entity_Scale]

    ; TODO: Make this code more compact?

  	mov r10, r0, lsr #8             ; channel 2 = inc_x
	and r10, r10, #0xff
    mov r10, r10, asl #11           ; inc_x maps [0, 2]
    ldr r1, [r2, #Entity_RotX]
    add r1, r1, r10                 ; object_rot_x += inc_x
    str r1, [r2, #Entity_RotX]

  	mov r10, r0, lsr #16            ; channel 3 = inc_y
	and r10, r10, #0xff
    mov r10, r10, asl #11           ; inc_y maps [0, 2]
    ldr r1, [r2, #Entity_RotY]
    add r1, r1, r10                 ; object_rot_y += inc_y
    str r1, [r2, #Entity_RotY]

    and r10, r0, #0xff              ; channel 1 = inc_z
    mov r10, r10, asl #11           ; inc_z maps [0, 2]
    ldr r1, [r2, #Entity_RotZ]
    add r1, r1, r10                 ; object_rot_z += inc_z
    str r1, [r2, #Entity_RotZ]

    ; Transform the object into world space.
    bl scene3d_transform_entity
    ldr pc, [sp], #4
.endif

; ============================================================================
; Project the transformed vertex array into screen space.
; ============================================================================

; Params:
;  R1=number of verts to project.
;  R2=ptr to transformed verts array.
;  R10=destination array for projected verts.
; Trashes: R0, R3-R5, R9.
; On exit: R1=0, R2=end of verts array, R10=end of projected array.
scene3d_project_verts:
    ; Project vertices to screen.
    ldr r9, scene3d_reciprocal_table_p
    .1:
    ; R2=ptr to world pos vector
    ; bl project_to_screen

    ; Load camera relative transformed verts [R3,R5,R5] = [x,y,z]
    ldmia r2!, {r3-r5}                  ; [s8.7]

    ; Project to screen.

    ; Put divisor in table range [9.7]
    .if LibDivide_Reciprocal_m != 9
    .err "Was expecting the reciprocal table to be [9.7]!"
    .endif

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
    ldr r5, [r9, r5, lsl #2]                      ; [0.16]    (1<<16+s)/(b<<s) = (1<<16)/b

    ; x'=x/z
    mul r3, r5, r3                                ; [s8.23]

    ; y'=y/z
    mul r4, r5, r4                                ; [s8.23]

    ; screen_x = vp_centre_x + vp_scale * (x-cx) / (z-cz)
    .if VIEWPORT_SCALE==160<<16
    ; x' is [s8.23] == 128*x' at [s15.16]
    add r3, r3, r3, asr #2          ; + x'*32 = 160*y' [s15.16]
    .else
    mov r3, r3, asr #7              ; [s7.16]
    mov r0, #VIEWPORT_SCALE>>16     ; [8.0]
    mul r3, r0, r3                  ; [s15.16]
    .endif
    add r3, r3, #VIEWPORT_CENTRE_X  ; [s15.16]

    ; screen_y = vp_centre_y - vp_scale * (y-cy) / (z-cz)
    .if VIEWPORT_SCALE==160<<16
    ; y' is [s8.23] == 128*y' at [s15.16]
    add r4, r4, r4, asr #2          ; + y'*32 = 160*y' [s15.16]
    .else
    mov r4, r4, asr #7              ; [s7.16]
    mov r0, #VIEWPORT_SCALE>>16     ; [8.0]
    mul r4, r0, r4                  ; [s15.16]
    .endif
    rsb r4, r4, #VIEWPORT_CENTRE_Y  ; [s15.16]

    ; R0=screen_x, R1=screen_y [16.16]
    mov r3, r3, asr #16             ; [16.0]
    mov r4, r4, asr #16             ; [16.0]

    stmia r10!, {r3, r4}
    subs r1, r1, #1
    bne .1

    mov pc, lr

; ============================================================================
; Draw the current object (not scene) using solid filled quads.
; ============================================================================

.if Scene3d_UseLightDirection
light_direction:                ; direction towards the light
    VECTOR3 0.0, 0.0, -1.0

light_dir_cached:
    VECTOR3 0.0, 0.0, 0.0
.endif

; R12=screen addr
scene3d_draw_entity_as_solid_quads:
    str lr, [sp, #-4]!

    .if _DEBUG
    mov r0, #0
    str r0, scene3d_stats_quads_plotted
    .endif

    ; Cache the screen address in the triangle plotter.

    bl triangle_prepare

    ; Other preparation, e.g. caching things or preshifting.

    .if Scene3d_UseLightDirection
    adr r1, light_direction
    ldmia r1, {r1,r4,r5}                ; [s1.16]
    mov r1, r1, asr #9                  ; [s1.7]
    mov r4, r4, asr #9
    mov r5, r5, asr #9
    adr r2, light_dir_cached
    stmia r2, {r1,r4,r5}                ; [s1.7]
    .endif

    ; Get ptr to the mesh header for our entity.

    ldr r12, scene3d_entity_p
    ldr r12, [r12, #Entity_MeshPtr]     ; scene3d_mesh_p

    ; Project world space verts to screen space.

    ldr r1, [r12, #MeshHeader_NumVerts]
    ldr r2, transformed_verts_p
    ldr r10, projected_verts_p
    bl scene3d_project_verts
    ; Trashes: R0, R3-R5, R9.

    ; Get ptrs to mesh arrays and tranformed normals for visibility.

    ldr r9, [r12, #MeshHeader_FaceIndices]
    ldr r10, transformed_normals_p
    ldr r11, [r12, #MeshHeader_NumFaces]
    .if !Scene3d_UseLighting
    ldr r12, [r12, #MeshHeader_FaceColours]
    .endif

    ; For each face.

    .2:

    ; Get vertex 0 for visibilty calculation.

    ldr r3, [r9], #4                    ; quad indices.
    and r5, r3, #0xff                   ; i0 of quad N.

    ldr r1, transformed_verts_p
    add r1, r1, r5, lsl #3
    add r1, r1, r5, lsl #2              ; v0 = transformed_verts[i0]

    ; Backfacing culling test.

    ; vector A [r1,r4,r5] = (v0 - camera_pos)
    ; vector B [r6,r7,r8] = face_normal
    ;  R0=dot product of (v0-cp).n
    ;     |v0-cp||n|cos theta
    ; Trashes: r3-r8

    ldmia r1,   {r1,r4,r5}              ; [s8.7]
    ldmia r10!, {r6-r8}                 ; [s1.8]

    ; Dot product A.B

    mul r0, r1, r6                      ; r0 = a1 * b1  [s9.15]
    mla r0, r4, r7, r0                  ;   += a2 * b2  [s9.15]

    .if !Scene3d_UseLighting
    ; Look up colour index per face (no lighting).
    ldrb r4, [r12], #1                  ; must increment ptr!
    .endif

    mlas r0, r5, r8, r0                 ;   += a3 * b3  [s9.15]
    bpl .3                              ; normal facing away from the view direction.

    .if Scene3d_UseLighting
    .if Scene3d_UseLightDirection
    ; Dynamic light source.
    ; Load light direction vector.
    adr r1, light_dir_cached
    ldmia r1, {r1,r4,r5}                ; [s1.7]

    ; Calculate L.N.
    ; N already in R6-E8.
    mul r0, r1, r6                      ; r0 = a1 * b1  [s1.15]
    mla r0, r4, r7, r0                  ;   += a2 * b2  [s1.15]
    mla r0, r5, r8, r0                  ;   += a3 * b3  [s1.15]
    movs r4, r0, asr #7
    movmi r4, #1                        ; clamp to min intensity
    .else
    ; Light intensity = L.N. Assume L=(0,0,-1) for now so intensity = -Nz.
    cmp r8, #0
    bpl .3                              ; cull poly if facing away (bit cheeky!)
    ;movpl r4, #0                       ; otherwise make it black.
    rsbmi r4, r8, #0                    ; -Nz [s1.8]
    .endif

    mov r4, r4, asr #4                  ;     [s1.4]
    cmp r4, #15                         ; clamp to max colour.
    movge r4, #15

    stmfd sp!, {r9-r11}                 ; no face colour ptr needed.
    .else
    stmfd sp!, {r9-r12}
    .endif

    ; TODO: MicroOpt- use screen space winding order test rather than dot product if no lighting calc.?
    ;       (y1 - y0) * (x2 - x1) - (x1 - x0) * (y2 - y1) > 0
    ;       Do this in quad plot routine as have to look up screen coordinates anyway?

    ;  R12=screen addr (now cached)
    ;  R2=ptr to projected vertex array (x,y) in screen coords [16.0]
    ldr r2, projected_verts_p   ; projected vertex array.
    ;  R3=4x vertex indices for quad
    ;  R4=colour index
    bl triangle_plot_quad_indexed   ; faster than polygon_plot_quad_indexed.
    ; Trashes: R0-R12.

    .if _DEBUG
    ldr r11, scene3d_stats_quads_plotted
    add r11, r11, #1
    str r11, scene3d_stats_quads_plotted
    .endif

    .if Scene3d_UseLighting
    ldmfd sp!, {r9-r11}             ; no face colour ptr needed.
    .else
    ldmfd sp!, {r9-r12}
    .endif

    .3:
    subs r11, r11, #1
    bne .2

    ldr pc, [sp], #4

; ============================================================================
; ============================================================================

.if _DEBUG
    errbehindcamera: ;The error block
    .long 0
	.byte "Vertex behind camera."
	.align 4
	.long 0
.endif

; ============================================================================
; ============================================================================

.if 0
    ; Do visibility calcs separately from triangle plot.

    ldr r0, transformed_verts_p
    ldr r2, visible_faces_p
    .if _DEBUG
    ldr r14, scene3d_stats_quads_plotted
    .endif
    .2:
    ; Get next face.

    ldr r3, [r9], #4                    ; quad indices.
    and r5, r3, #0xff                   ; i0 of quad N.

    add r1, r0, r5, lsl #3
    add r1, r1, r5, lsl #2              ; v0 = transformed_verts[i0]

    ldmia r1,   {r1,r4,r5}              ; [s8.7]
    ldmia r10!, {r6-r8}                 ; [s1.8]

    ; Dot product A.B

    mul r3, r1, r6                      ; r0 = a1 * b1  [s9.15]
    mla r3, r4, r7, r3                  ;   += a2 * b2  [s9.15]
    mlas r3, r5, r8, r3                 ;   += a3 * b3  [s9.15]
    str r3, [r2], #4                    ; store result as visibility

    .if _DEBUG
    addmi r14, r14, #1
    .endif

    subs r11, r11, #1
    bne .2

    .if _DEBUG
    str r14, scene3d_stats_quads_plotted
    .endif

    ; Plot visible faces.

    ldr r9,  [r12, #MeshHeader_FaceIndices]
    ldr r10, visible_faces_p
    ldr r11, [r12, #MeshHeader_NumFaces]
    ldr r12, [r12, #MeshHeader_FaceColours]
    .3:
    ; Could reduce this to a single base register.
    ; ldr r4, [r12, #Face_Colours_Offset]
    ; ldr r3, [r12, #Face_Indices_Offset]
    ; ldr r0, [r12], #4                 ; assumes vis is first.
    ; Could finagle the layout so other reads are conditional.
    ; But would still need to store 2x registers per face plotted.

    ldrb r4, [r12], #1                  ; must increment ptr!
    ldr r3, [r9], #4                    ; quad indices.
    ldr r0, [r10], #4
    cmp r0, #0
    bpl .4

    stmfd sp!, {r9-r12} 
    ldr r2, projected_verts_p       ; projected vertex array.
    bl triangle_plot_quad_indexed   ; faster than polygon_plot_quad_indexed.
    ldmfd sp!, {r9-r12}

    .4:
    subs r11, r11, #1
    bne .3

visible_faces_p:
    .long visible_faces_no_adr

visible_faces_no_adr:
    .skip OBJ_MAX_FACES * 4

.endif
