; ============================================================================
; 2D Scene.
; 2D Wireframe objects that move in 3D space but are camera facing.
; Assume single face, no culling.
; Assume multiple objects with independent position, rotation, scale.
; TODO: Remove code specific to previous demos etc.
; Used in: Three-Dee Demo (Mikroreise)
; ============================================================================

.equ Scene2D_ObjectBuffer_Size, 10 * VECTOR3_SIZE * 10 + 10 * 4 ; 10 objects with max 10 verts each.
.equ Scene2D_MaxVerts, 32

; ============================================================================
; Scene data.
; Reuse most variables from 3d-scene?
;   camera_pos
;   LeftEye_X_Pos
;   RightEye_X_Pos
; etc.
; Assume a scene has multiple objects
; Can a scene contain a variety of objects?
; ============================================================================

.equ Model_Circle_Num_Verts, 8
.equ Model_Circle_Num_Faces, 0
.equ Model_Circle_Radius, 48

scene2d_colour_index:
    .long 0

scene2d_reciprocal_table_p:
    .long reciprocal_table_no_adr

scene2d_object_buffer_p:
    .long scene2d_object_buffer_no_adr

scene2d_object_list_p:
    .long scene2d_object_buffer_no_adr

scene2d_verts_buffer_p:
    .long scene2d_verts_buffer_no_adr

.equ SQ_BACK, 128   ; furthest
.equ SQ_GAP, 32     ; gap between squares
.equ SQ_NUM, 6     ; how many
.equ SQ_SCALE, 1    ; size of squares
.equ SQ_SPEED, 1.152  ; move forward at.
.equ SQ_TWIST, 16   ; between squares.
.equ SQ_ROT, 0.5    ; rotation speed.

scene2d_object_pos:
    VECTOR3 0.0, 0.0, SQ_BACK

scene2d_object_rot:
    .long 0

scene2d_object_scale:
    FLOAT_TO_FP SQ_SCALE

scene2d_object_vert_p:
    .long model_square_verts

scene2d_object_num_verts:
    .long 4

scene2d_object_z_speed:
    FLOAT_TO_FP SQ_SPEED

scene2d_object_rot_speed:
    FLOAT_TO_FP SQ_ROT

scene2d_object_spawn_adjust_rot:
    FLOAT_TO_FP SQ_ROT*SQ_GAP;/SQ_SPEED)

scene2d_object_num:
    .long SQ_NUM

scene2d_object_max:
    .long SQ_NUM

scene2d_object_twist:
    FLOAT_TO_FP SQ_TWIST

scene2d_object_gap:
    FLOAT_TO_FP SQ_GAP

scene2d_object_spawn_z:
    FLOAT_TO_FP SQ_BACK

; ============================================================================

; R3=radius [not fp!]
; R7=number of sides.
; R8=ptr to VECTOR3 buffer.
make_2d_object:
    str lr, [sp, #-4]!

    ldr r9, scene3d_reciprocal_table_p
    ldr r12, [r9, r7, lsl #2+LibDivide_Reciprocal_s]  ; 1/num
    mov r12, r12, asl #8        ; 256/num

    mov r10, #0     ; count.
    mov r11, #0     ; brads.
.1:
    mov r0, r11
    bl sin_cos
    ; R0=sin(a)
    ; R1=cos(a)

    mul r0, r3, r0          ; x=radius*sin(a)
    mul r1, r3, r1          ; y=radius*cos(a)
    mov r2, #0              ; z=0

    stmia r8!, {r0-r2}

    ; Increment brad.
    add r11, r11, r12

    add r10, r10, #1
    cmp r10, r7
    blt .1

    ldr pc, [sp], #4

scene2d_init:
    str lr, [sp, #-4]!

    mov r3, #16
    mov r7, #3
    adr r8, model_triangle_verts
    bl make_2d_object

    mov r3, #16
    mov r7, #5
    adr r8, model_pentagon_verts
    bl make_2d_object

    mov r3, #16
    mov r7, #6
    adr r8, model_hexagon_verts
    bl make_2d_object

    ; Make circle object.
    mov r3, #Model_Circle_Radius
    mov r7, #Model_Circle_Num_Verts
    adr r8, circle_verts
    bl make_2d_object

    ldr pc, [sp], #4

; ============================================================================

scene2d_update:
    str lr, [sp, #-4]!

    ; Reset object list.
    ldr r0, scene2d_object_buffer_p
    str r0, scene2d_object_list_p

    ldr r0, scene2d_object_pos+8    ; object_pos_z
    str r0, [sp, #-4]!              ; stash this on stack.

    ldr r11, scene2d_object_num
    ldr r1, scene2d_object_rot
.1:

    ; R0=Ptr to object position vector (3D).
    ; R1=Object rotation (just around Z for now).
    ; R2=Ptr to object data = a list of verts (currently VECTOR3)
    ; R3=Number of verts.
    ; R5=Object scale.

    adr r0, scene2d_object_pos
    ldr r2, scene2d_object_vert_p
    ldr r3, scene2d_object_num_verts
    ldr r5, scene2d_object_scale

    stmfd sp!, {r1,r11}
    bl scene2d_transform_object
    ldmfd sp!, {r1,r11}

    ; Twist.
    ldr r2, scene2d_object_twist
    sub r1, r1, r2
    bic r1, r1, #0xff000000         ; brads

    ; Step forward.
    ldr r2, scene2d_object_gap
    ldr r0, scene2d_object_pos+8    ; object_pos_z
    sub r0, r0, r2
    str r0, scene2d_object_pos+8    ; object_pos_z

    subs r11, r11, #1
    bne .1

    ; Terminate object list.
    ldr r0, scene2d_object_list_p
    mov r1, #-1
    str r1, [r0]

    ; Update rotation & position.
    ldr r1, scene2d_object_rot
    
    ; TODO: Move remaining params to vars and bulk load.
    ldr r2, scene2d_object_z_speed
    ldr r4, scene2d_object_rot_speed
    ldr r5, scene2d_object_spawn_z
    ldr r6, scene2d_object_gap

    ldr r0, [sp], #4                ; pull object_pos_z from stack.
    sub r0, r0, r2                  ; object_z_speed

    sub r7, r5, r0                  ; object_pos_z - object_spawn_z
    cmp r7, r6                      ; distance travelled >= gap?
    blt .2

    ; Respawn at spawn_z and adjust spawn rotation.
    mov r0, r5
    ldr r3, scene2d_object_spawn_adjust_rot
    add r1, r1, r3

    ldr r11, scene2d_object_num
    ldr r10, scene2d_object_max
    cmp r11, r10
    addlt r11, r11, #1
    str r11, scene2d_object_num
    
    .2:
    str r0, scene2d_object_pos+8    ; object_pos_z

    add r1, r1, r4                  ; object_rot_speed
    bic r1, r1, #0xff000000         ; brads
    str r1, scene2d_object_rot

    ldr pc, [sp], #4

.if 0
scene2d_draw_anaglyph:
    str lr, [sp, #-4]!

    ; Left eye.
    ldr r0, LeftEye_X_Pos
    str r0, camera_pos+0        ; camera_pos_x

    ; Subtract blue & green.
    mov r4, #7                  ; brightest red
    bl scene2d_draw

    ; Right eye.
    ldr r0, RightEye_X_Pos
    str r0, camera_pos+0        ; camera_pos_x

    ; Subtract red.
    mov r4, #11                 ; brightest cyan
    bl scene2d_draw

    ldr pc, [sp], #4
.endif

; Plot all objects in the scene.
; R4=colour index
; R12=screen addr
scene2d_draw:
    str lr, [sp, #-4]!

    str r4, scene2d_colour_index

    ldr r2, scene2d_object_buffer_p
.1:
    ldr r1, [r2], #4                       ; load num verts
    cmp r1, #0
    blt .3

    ; Load camera [x, y, z].
    adr r0, camera_pos
    ldmia r0, {r6-r8}

    ldr r9, scene2d_reciprocal_table_p
    ldr r10, scene2d_verts_buffer_p
.2:
    ; Load transformed verts [R3,R5,R5] = [x,y,z]
    ldmia r2!, {r3-r5}
    ; NOTE: Z is same for all verts currently.

    ; Subtract camera_pos from world_pos.
    sub r3, r3, r6
    sub r4, r4, r7
    sub r5, r5, r8

    ; Project to screen.

    ; Put divisor in table range.
    mov r5, r5, asr #16-LibDivide_Reciprocal_s    ; [16.6]    (b<<s)

    .if _DEBUG
    cmp r5, #0
    adrle r0,errbehindcamera    ; and flag an error
    swile OS_GenerateError      ; when necessary
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

    .if 0
    ldrb r0, Anaglyph_Enable_Skew
    cmp r0, #0
    ldrne r0, camera_pos+0      ; camera_pos_x
    movne r0, r0, asl #1
    addne r3, r3, r0
    .endif

    ; screen_y = vp_centre_y - vp_scale * (y-cy) / (z-cz)
    mov r0, #VIEWPORT_SCALE>>12 ; [16.4]
    mul r4, r0, r4              ; [12.20]
    mov r4, r4, asr #4           ; [12.16]
    mov r0, #VIEWPORT_CENTRE_Y  ; [16.16]
    sub r4, r0, r4              ; [16.16]

    mov r3, r3, asr #16         ; [16.0]
    mov r4, r4, asr #16         ; [16.0]
    ; TODO: Could pack these [x:y] into one word?
    stmia r10!, {r3-r4}           ; or push to stack?

    ; Next vertex.
    subs r1, r1, #1
    bne .2

    str r2, [sp, #-4]!          ; stash ptr in r2

    ; R10=top of buffer
    ldr r4, scene2d_colour_index
    ldr r11, scene2d_verts_buffer_p
.5:
    ldmia r11, {r0-r3}          ; (xstart,ystart,xend,yend)
    add r11, r11, #VECTOR2_SIZE
    cmp r11, r10
    bge .6

    bl mode9_drawline_with_clip  ; trashes r5-r9
    ; NOTE: Can't reuse R3=yend as gets scaled by Screen_Stride.
    b .5

.6:
    ; Load vertex 0 as (xend,yend) for last line.
    ldr r11, scene2d_verts_buffer_p
    ldmia r11, {r2-r3}

    bl mode9_drawline_with_clip  ; trashes r5-r9

    ; Next object.
    ldr r2, [sp], #4            ; unstash ptr in r2
    b .1

.3:
    ldr pc, [sp], #4

; Transform an object into world coordinates.
; And add it to the object draw list.
; R0=Ptr to object position vector (3D).
; R1=Object rotation (just around Z for now).
; R2=Ptr to object data = a list of verts (currently VECTOR3)
; R3=Number of verts.
; R5=Object scale.
; Trashes: R0-R12
scene2d_transform_object:
    str lr, [sp, #-4]!

    ldmia r0, {r6-r8}                       ; object_pos

    mov r12, r3                             ; num verts
    str r4, scene2d_colour_index

    mov r0, r1                              ; A=object_rot_z
    bl sin_cos                              ; Trashes R9!
    mov r10, r0, asr #MULTIPLICATION_SHIFT  ; r10 = sin(A)
    mov r11, r1, asr #MULTIPLICATION_SHIFT  ; r11 = cos(A)

    mov r9, r5, asr #MULTIPLICATION_SHIFT   ; object_scale [8.8]

    ldr r14, scene2d_object_list_p
    str r12, [r14], #4                      ; push num verts.

.1:
    ; Load vertex.
    ldmia r2!, {r3-r5}                      ; [R3,R4,R5] = [x,y,z=0.0]
    mov r3, r3, asr #MULTIPLICATION_SHIFT
    mov r4, r4, asr #MULTIPLICATION_SHIFT

    ; Rotate X & Y around Z.

	; x'  = x*cos(A) + y*sin(A)
	; y'  = x*sin(A) - y*cos(A)  
    mul r0, r3, r11                     ; x*cos(A)
    mla r0, r4, r10, r0                 ; x' = y*sin(A) + x*cos(A)

    mul r1, r4, r11                     ; y*cos(A)
    rsb r1, r1, #0                      ; -y*cos(A)
    mla r4, r3, r10, r1                 ; y' = x*sin(A) - y*cos(A)

    mov r3, r0                          ; [R3,R4,R5] = [x',y',z=0.0]

    ; Apply object scale after rotation.
    ; TODO: Can we do this with a shift instead of MUL?
    mov r3, r3, asr #MULTIPLICATION_SHIFT
    mov r4, r4, asr #MULTIPLICATION_SHIFT
    mov r5, r5, asr #MULTIPLICATION_SHIFT   ; z=0.0

    ; Transform vertex into world space.
    mla r3, r9, r3, r6  ; world_x=x'*object_scale + object_pos_x
    mla r4, r9, r4, r7  ; world_y=y'*object_scale + object_pos_y
    mla r5, r9, r5, r8  ; world_z=z *object_scale + object_pos_z

    ; Save transformed verts in buffer.
    stmia r14!, {r3-r5}

    subs r12, r12, #1
    bne .1

    ; Save ptr into object buffer.
    str r14, scene2d_object_list_p
    ; TODO: Check for buffer overflow!

    ldr pc, [sp], #4

; ============================================================================
; Model data: SQUARE
;
;     0 +------+ 1
;       |      |
;       |      |
;       |      |
;       +------+
;      3        2
; ============================================================================

; TODO: Use VECTOR2?
model_square_verts:
    VECTOR3 -16.0,  16.0, 0.0
    VECTOR3  16.0,  16.0, 0.0
    VECTOR3  16.0, -16.0, 0.0
    VECTOR3 -16.0, -16.0, 0.0

model_triangle_verts:
    .skip 3*VECTOR3_SIZE

model_pentagon_verts:
    .skip 5*VECTOR3_SIZE

model_hexagon_verts:
    .skip 6*VECTOR3_SIZE

model_circle_verts:             ; Technically an octagon. Used as a 3D object.
    .skip VECTOR3_SIZE*Model_Circle_Num_Verts

; ============================================================================
