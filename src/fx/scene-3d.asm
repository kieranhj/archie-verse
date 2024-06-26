; ============================================================================
; 3D Scene.
; Note camera is fixed to view down +z axis.
; Does not support camera rotation / look at.
; Single 3D object per scene.
; Supports position, rotation & scale of the object within the scene.
; Used in: Chipo Django musicdisk, Three-Dee Demo (mikroreise)
; ============================================================================

.equ MeshHeader_NumVerts,       0
.equ MeshHeader_NumFaces,       4
.equ MeshHeader_VertsPtr,       8
.equ MeshHeader_NormalsPtr,     12
.equ MeshHeader_FaceIndices,    16
.equ MeshHeader_FaceColours,    20
.equ MeshHeader_SIZE,           24

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

; TODO: Could also speed this up by choosing a viewport scale as a shift, e.g. 128.
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

camera_pos:
    VECTOR3 0.0, 0.0, -80.0

; ============================================================================
; Pointer to a single 3D object in the scene.
; ============================================================================

scene3d_entity_p:
    .long cube_entity

cube_entity:
    VECTOR3 0.0, 0.0, 16.0      ; object_pos
    VECTOR3 0.0, 0.0, 0.0       ; object_rot
    FLOAT_TO_FP 1.0             ; object_scale
    .long mesh_header_cube

cobra_entity:
    VECTOR3 0.0, 0.0, 16.0      ; object_pos
    VECTOR3 0.0, 0.0, 0.0       ; object_rot
    FLOAT_TO_FP 2.0             ; object_scale
    .long mesh_header_cobra

; ============================================================================
; Ptrs to buffers / tables.
; ============================================================================

.equ OBJ_MAX_VERTS, 128
.equ OBJ_MAX_FACES, 128

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

scene3d_init:
    str lr, [sp, #-4]!
    ldr pc, [sp], #4

; ============================================================================
; Transform the current object (not scene) into world space.
; ============================================================================

scene3d_transform_entity:
    str lr, [sp, #-4]!

    ; Skip matrix multiplication altogether.
    ; Transform (x,y,z) into (x'',y'',z'') directly.
    ; Uses 12 muls / rotation.

    ldr r2, scene3d_entity_p
    ldr r0, [r2, #Entity_RotZ]              ; object_rot+8
    bl sin_cos                              ; trashes R9
    mov r10, r0, asr #MULTIPLICATION_SHIFT  ; r10 = sin(A)
    mov r11, r1, asr #MULTIPLICATION_SHIFT  ; r11 = cos(A)

    ldr r0, [r2, #Entity_RotX]              ; object_rot+0
    bl sin_cos                              ; trashes R9
    mov r6, r0, asr #MULTIPLICATION_SHIFT  ; r6 = sin(C)
    mov r7, r1, asr #MULTIPLICATION_SHIFT  ; r7 = cos(C)

    ldr r0, [r2, #Entity_RotY]              ; object_rot+4
    bl sin_cos                              ; trashes R9
    mov r8, r0, asr #MULTIPLICATION_SHIFT  ; r8 = sin(B)
    mov r9, r1, asr #MULTIPLICATION_SHIFT  ; r9 = cos(B)

    ldr r12, [r2, #Entity_MeshPtr]
    ldr r1, [r12, #MeshHeader_VertsPtr]
    ldr r3, [r12, #MeshHeader_NumFaces]
    ldr r12, [r12, #MeshHeader_NumVerts]

    ldr r2, transformed_verts_p
    add r4, r2, r12, lsl #3
    add r4, r4, r12, lsl #2               ; transform_normals=&transformed_verts[object_num_verts]
    str r4, transformed_normals_p

    add r12, r12, r3                      ; object_num_verts + object_num_faces

    ; ASSUMES THAT VERTEX AND NORMAL ARRAYS ARE CONSECUTIVE!
    .1:
    ldmia r1!, {r3-r5}                    ; x,y,z
    mov r3, r3, asr #MULTIPLICATION_SHIFT
    mov r4, r4, asr #MULTIPLICATION_SHIFT
    mov r5, r5, asr #MULTIPLICATION_SHIFT

	; x'  = x*cos(A) + y*sin(A)
	; y'  = x*sin(A) - y*cos(A)  
    mul r0, r3, r11                     ; x*cos(A)
    mla r0, r4, r10, r0                 ; x' = y*sin(A) + x*cos(A)
    mov r0, r0, asr #MULTIPLICATION_SHIFT

    mul r14, r4, r11                    ; y*cos(A)
    rsb r14, r14, #0                    ; -y*cos(A)
    mla r4, r3, r10, r14                ; y' = x*sin(A) - y*cos(A)
    mov r4, r4, asr #MULTIPLICATION_SHIFT

	; x'' = x'*cos(B) + z*sin(B)
	; z'  = x'*sin(B) - z*cos(B)

    mul r14, r0, r9                     ; x'*cos(B)
    mla r3, r5, r8, r14                 ; x'' = z*sin(B) + x'*cos(B)

    mul r14, r5, r9                     ; z*cos(B)
    rsb r14, r14, #0                    ; -z*cos(B)
    mla r5, r0, r8, r14                 ; z' = x'*sin(B) - z*cos(B)
    mov r5, r5, asr #MULTIPLICATION_SHIFT

	; y'' = y'*cos(C) + z'*sin(C)
	; z'' = y'*sin(C) - z'*cos(C)

    mul r14, r4, r7                     ; y'*cos(C)
    mla r0, r5, r6, r14                 ; y'' = y'*cos(C) + z'*sin(C)

    mul r14, r5, r7                     ; z'*cos(C)
    rsb r14, r14, #0                    ; -z'*cos(C)
    mla r5, r4, r6, r14                 ; z'' = y'*sin(C) - z'*cos(C)

    ; x''=r3, y''=r0, z''=r5
    mov r4, r0
    stmia r2!, {r3-r5}                  ; x'',y'',z'''
    subs r12, r12, #1
    bne .1

    ; Transform to world coordinates.
    ldr r11, scene3d_entity_p
    ldmia r11, {r6-r8}

    ; NB. No longer transformed to camera relative.

    ; Apply object scale after rotation.
    ldr r0, [r11, #Entity_Scale]        ; object_scale
    mov r0, r0, asr #MULTIPLICATION_SHIFT

    ldr r2, transformed_verts_p
    ldr r12, [r11, #Entity_MeshPtr]     ; scene3d_mesh_p
    ldr r12, [r12, #MeshHeader_NumVerts]
    .2:
    ldmia r2, {r3-r5}

    ; Scale rotated verts.
    mov r3, r3, asr #MULTIPLICATION_SHIFT
    mov r4, r4, asr #MULTIPLICATION_SHIFT
    mov r5, r5, asr #MULTIPLICATION_SHIFT

    mul r3, r0, r3      ; x_scaled=x*object_scale
    mul r4, r0, r4      ; y_scaled=y*object_scale
    mul r5, r0, r5      ; z_scaled=z*object_scale

    ; TODO: Make camera relative again for speed?

    ; Move object vertices into world space.
    add r3, r3, r6      ; x_scaled + object_pos_x - camera_pos_x
    add r4, r4, r7      ; y_scaled + object_pos_y - camera_pos_y
    add r5, r5, r8      ; z_scaled + object_pos_z - camera_pos_z

    stmia r2!, {r3-r5}
    subs r12, r12, #1
    bne .2

    ldr pc, [sp], #4

; ============================================================================
; Rotate the current object from either vars or VU bars.
; ============================================================================

object_rot_speed:
    VECTOR3 0.5, 0.5, 0.5

scene3d_rotate_entity:
    str lr, [sp, #-4]!

    ; Update any scene vars, camera, object position etc. (Rocket?)
    ldr r2, scene3d_entity_p
    ldr r1, object_rot_speed + 0 ; ROTATION_X
    ldr r0, [r2, #Entity_RotX]
    add r0, r0, r1
    bic r0, r0, #0xff000000         ; brads
    str r0, [r2, #Entity_RotX]

    ldr r1, object_rot_speed + 4 ; ROTATION_Y
    ldr r0, [r2, #Entity_RotY]
    add r0, r0, r1
    bic r0, r0, #0xff000000         ; brads
    str r0, [r2, #Entity_RotY]

    ldr r1, object_rot_speed + 8 ; ROTATION_Z
    ldr r0, [r2, #Entity_RotZ]
    add r0, r0, r1
    bic r0, r0, #0xff000000         ; brads
    str r0, [r2, #Entity_RotZ]

    ; Transform the object into world space.
    bl scene3d_transform_entity
    ldr pc, [sp], #4

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

; ============================================================================
; Project the transformed vertex array into screen space.
; ============================================================================

scene3d_project_verts:
    ; Load camera [x, y, z].
    adr r0, camera_pos
    ldmia r0, {r6-r8}

    ; Project vertices to screen.
    ldr r2, transformed_verts_p
    ldr r9, scene3d_reciprocal_table_p

    ldr r1, scene3d_entity_p
    ldr r1, [r1, #Entity_MeshPtr]           ; scene3d_mesh_p
    ldr r1, [r1, #MeshHeader_NumVerts]
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

; ============================================================================
; Draw the current object (not scene) using solid filled quads.
; ============================================================================

; R12=screen addr
scene3d_draw_entity_as_solid_quads:
    str lr, [sp, #-4]!

    ; Project world space verts to screen space.
    bl scene3d_project_verts
 
    ; Plot faces as polys.
    ldr r11, scene3d_entity_p
    ldr r11, [r11, #Entity_MeshPtr]     ; scene3d_mesh_p
    ldr r11, [r11, #MeshHeader_NumFaces]
    sub r11, r11, #1

    .2:
    ldr r9, scene3d_entity_p
    ldr r9, [r9, #Entity_MeshPtr]       ; scene3d_mesh_p
    ldr r9, [r9, #MeshHeader_FaceIndices]
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

    ; Look up colour index per face (no lighting).
    ldr r4, scene3d_entity_p
    ldr r4, [r4, #Entity_MeshPtr]       ; scene3d_mesh_p
    ldr r4, [r4, #MeshHeader_FaceColours]
    ldrb r4, [r4, r11]

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

; ============================================================================
; ============================================================================

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

    mov r8, #VIEWPORT_SCALE>>12 ; [16.4]
    mul r6, r0, r8              ; [12.20]
    mov r6, r6, asr #4          ; [12.16]
    mov r8, #VIEWPORT_CENTRE_X  ; [16.16]
    add r6, r6, r8

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

; ============================================================================
; ============================================================================

.if _DEBUG
    errbehindcamera: ;The error block
    .long 0
	.byte "Vertex behind camera."
	.align 4
	.long 0
.endif
