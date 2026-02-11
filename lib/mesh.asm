; ============================================================================
; Mesh utils.
; ============================================================================

; ============================================================================
; Torus.
; ============================================================================
;    y
;    ^  z
;    |/
;    +--> x
;
; Radius of the ring = a
; Radius of the circle = b
; Number segments of the ring = c
; Number segments of the circle = d
; Ring segments rotate around y (aligned in x,z) // TODO: Error, actually around Z?
; Circle segments rotate the ring (perpendicular to x,z)
; Outer loop around the circle radius, starting from the centre.
; Inner loop around the ring.
; ============================================================================

torus_ringradius:
    FLOAT_TO_FP 0.0                     ; a

torus_circleradius:
    FLOAT_TO_FP 0.0                     ; b

torus_ringsegments:
    .long 0                             ; c

torus_circlesegments:
    .long 0                             ; d

torus_mesh_p:
    .long 0

torus_flags:
    .long 0

torus_circleradius_recip:
    .long 0                             ; 1/b

; R0=ring radius
; R1=circle radius
; R2=ring segments
; R3=circle segments
; R4=ptr to mesh header (assumes the BSS is preallocated!)
; R5=flags 0x1=flat inner face, 0x2=flip face order
mesh_make_torus:
    str lr, [sp, #-4]!

    ; Cache parameters.

    adr r6, torus_ringradius
    stmia r6, {r0-r5}                       ; str r4, torus_mesh_p!

    ; Calculate num verts/faces.

    mul r6, r2, r3                          ; ring * circle segments

    .if _DEBUG
    cmp r6, #MeshTorus_MaxVertsFaces
    adrgt r0, errtorustoobig
    swigt OS_GenerateError
    .endif

    ; Fill out the mesh header.

    mov r12, r4
    str r6, [r12, #MeshHeader_NumVerts]
    str r6, [r12, #MeshHeader_NumFaces]
    ldr r11, [r12, #MeshHeader_VertsPtr]    ; ptr to verts

    ; Normals must come after verts.

    add r3, r11, r6, lsl #3
    add r3, r3, r6, lsl #2
    str r3, [r12, #MeshHeader_NormalsPtr]   ; ptr to normals

    ; Calculate all vertices.

    bl mesh_make_torus_verts

    ; Calculate the face indices and colours.

    ldr r12, torus_mesh_p
    ldr r11, [r12, #MeshHeader_FaceIndices] ; face indices array [4 bytes]
    ldr r5, torus_flags
    bl mesh_make_torus_faces_and_colours

    ; Calculate normals.

    ldr r12, torus_mesh_p
    ldr r0, [r12, #MeshHeader_NormalsPtr]  ; normals array [3*4 bytes]
    bl mesh_calc_normals_from_faces

    ; TODO: Perhaps sort out the ptrs that get passed into these functions.

    ldr pc, [sp], #4

; Assumes that torus params are cached.
; R5=flat inner face flag.
; R11=ptr to verts array
mesh_make_torus_verts:
    str lr, [sp, #-4]!

    ; Calculate reciprocals.

    mov r0, #MATHS_CONST_1
    ldr r1, torus_ringsegments              ; c
    mov r1, r1, asl #16
    bl divide                               ; trashes R8-R10
    mov r7, r0                              ; dt = 1.0/c

    mov r0, #MATHS_CONST_1
    ldr r1, torus_circlesegments            ; d
    mov r1, r1, asl #16
    bl divide                               ; trashes R8-R10
    mov r6, r0                              ; dp = 1.0/d

    ; Flat inner face flag.
    tst r5, #0x1            ; and
    moveq r3, #0
    movne r3, r6, asr #1

    mov r0, #MATHS_CONST_1
    ldr r1, torus_circleradius              ; b
    bl divide                               ; trashes R8-R10
    mov r0, r0, asr #8
    str r0, torus_circleradius_recip        ; 1.0/b [1.8]

    ; Outer ring.

    mov r10, #0                             ; theta
.1:
    ;theta = (2*PI/d) * stack [0, d]
    mov r0, r10, asl #8                     ; theta in brads
    bl sin_cos
    ; Keep precision as long as possible.
    mov r4, r0                              ; R4=sin(theta) [s1.16]
    mov r5, r1                              ; R5=cos(theta) [s1.16]

    ; Inner circle.
    
    mov r8, #0                              ; phi
.2:
    ;phi = (2*PI/c) * slice [0, c]
    sub r0, r8, #MATHS_CONST_HALF           ; start in the middle
    sub r0, r0, r3                          ; 0.5/d [1.16]
    mov r0, r0, asl #8                      ; phi in brads
    bl sin_cos
    ; R0=sin(phi) [s1.16]
    ; R1=cos(phi) [s1.16]

    ldr r14, torus_circleradius             ; b
    mov r14, r14, asr #8                    ; TODO: MicroOpt- preshift this.
    mul r2, r0, r14                         ; v.z = sin(phi) * b
    mov r2, r2, asr #8
    mul r14, r1, r14                        ; cos(phi) * b [s15.16]
    mov r14, r14, asr #8

    ldr r12, torus_ringradius               ; a
    add r14, r14, r12                       ; a + cos(phi) * b

    ; Calculate point on the circle.

    mov r14, r14, asr #8
    mul r0, r14, r5                         ; v.x = cos(theta) * (a + cos(phi) * b)
    mul r1, r14, r4                         ; v.y = sin(theta) * (a + cos(phi) * b)
    mov r0, r0, asr #8
    mov r1, r1, asr #8

    stmia r11!, {r0-r2}                     ; write {x,y,z}
    
    ; Next vert in the circle.

    add r8, r8, r6                          ; phi+=dp
    cmp r8, #MATHS_CONST_1
    blt .2

    ; Next circle in the ring.

    add r10, r10, r7                          ; theta+=dt
    cmp r10, #MATHS_CONST_1
    blt .1
    ldr pc, [sp], #4

; Assumes that torus params are cached.
; R0=regular or flipped (non-zero) face order
; R11=ptr to face indices array [4 bytes per face]
; R12=mesh header.
; Trashes: R12
mesh_make_torus_faces_and_colours:
    str lr, [sp, #-4]!

    ; Pre-sort the face order to avoid sorting at render time!
    ; NB. This isn't strictly possible with a fully symmetric torus.
    ;     So we can create two with the two possible draw orders and
    ;     Flip between them at render time depending on rotation.

    tst r5, #0x2    ; and
    adreq r1, mesh_make_torus_regular_face_order
    adrne r1, mesh_make_torus_flipped_face_order
    ldmia r1, {r2-r3}
    adr r0, .333
    stmia r0, {r2-r3}

    ; Calculate vertices per face.
    ; 'd' verts per ring repeated 'c' times.
    ; Each face will be made of verts:
    ;   n, (n+1) MOD d (around the circle), (n+d) MOD c (next segment of the ring), (n+d+1) MOD c
    ldr r10, [r12, #MeshHeader_FaceColours] ; face colours array [1 byte]
    ldr r14, [r12, #MeshHeader_NumVerts]

    ldr r6, torus_circlesegments            ; d
    ldr r7, torus_ringsegments              ; c

    mov r4, #1                              ; colour.
    mov r12, #0                             ; circle index
.3:
    ; Alternate circle segments from inside to outside.

    mov r8, r12, lsr #1                     ; i DIV 2
    tst r12, #1 ; NE=bit set

    ; NB. Just flip this condition to 'eq' to switch draw order.
.333:
    subne r8, r6, r8
    subne r8, r8, #1                        ; (N-1)-(i DIV 2)

    mov r5, #0                              ; let's say this is ring base (vb)
    mov r9, #0                              ; ring segment 
.4:
    ; v0 = vb + vi
    ; v1 = vb + (vi + 1) MOD d
    ; v2 = (vb + d) MOD cd + (vi + 1) MOD d
    ; v3 = (vb + d) MOD cd + vi

    add r1, r8, #1                          ; (vi + 1)
    cmp r1, r6                              ; v1 > d
    movge r1, #0                            ; (vi + 1) MOD d

    add r3, r5, r6                          ; (vb + d)
    cmp r3, r14                             ; v3 > (c*d)
    subge r3, r3, r14                       ; (vb + d) MOD cd

    add r0, r5, r8                          ; v0 = vb + vi

    add r2, r3, r1                          ; v2 = (vb + d) MOD cd + (vi + 1) MOD d
    cmp r2, r14                             ; v2 > (c*d)
    subge r2, r2, r14                       ; MOD (c*d)

    add r3, r3, r8                          ; v3 += vi
    add r1, r5, r1                          ; v1 += vb

    ; Store face indices.

    strb r0, [r11], #1
    strb r1, [r11], #1
    strb r2, [r11], #1
    strb r3, [r11], #1

    ; Store colour.
    strb r4, [r10], #1

    add r4, r4, #1
    cmp r4, #16
    movge r4, #1

    ; Next segment of the ring.
    add r5, r5, r6

    add r9, r9, #1
    cmp r9, r7
    blt .4

    ; Next colour.

    ; Next face in the circle.

    add r12, r12, #1
    cmp r12, r6
    blt .3

    ldr pc, [sp], #4

mesh_make_torus_regular_face_order:
    subne r8, r6, r8
    subne r8, r8, #1                        ; (N-1)-(i DIV 2)

mesh_make_torus_flipped_face_order:
    subeq r8, r6, r8
    subeq r8, r8, #1                        ; (N-1)-(i DIV 2)

; ============================================================================
; ============================================================================

.if _DEBUG
    errtorustoobig: ;The error block
    .long 0
	.byte "Torus has too many verts/faces."
	.align 4
	.long 0
.endif

; ============================================================================
; ============================================================================

; R0 = ptr to normals array.
; R12 = ptr to mesh header.
; Compute normals from vertex array and mesh faces indices.
mesh_calc_normals_from_faces:
    str lr, [sp, #-4]!

    ldr r8, [r12, #MeshHeader_NumFaces]     ; number normals
    ldr r10, [r12, #MeshHeader_VertsPtr]    ; vertex array [3*4 bytes]
    ldr r11, [r12, #MeshHeader_FaceIndices] ; face indices array [4 bytes]
    mov r12, r0

    ; Assume R0-R7, R9 gets trashed!

    ; For each face.
.1:
    ; Use face indices to get vector A and B. [v1-v0], [v3-v0]
    ldrb r6, [r11, #0]                      ; i0
    add r7, r10, r6, lsl #3                 ; v0_ptr = vertex[i0]
    add r7, r7, r6, lsl #2
    ldmia r7, {r3-r5}                       ; v0

    ldrb r6, [r11, #3]                      ; i3
    add r9, r10, r6, lsl #3                 ; v3_ptr = vertex[i3]
    add r9, r9, r6, lsl #2
    ldmia r9, {r0-r2}                       ; v3

    ; Calculate A=v3-v0
    sub r0, r0, r3
    sub r1, r1, r4
    sub r2, r2, r5

    ldrb r6, [r11, #1]                      ; i1
    add r9, r10, r6, lsl #3                 ; v1_ptr = vertex[i1]
    add r9, r9, r6, lsl #2
    ldmia r9, {r6,r7,r9}                    ; v1

    ; Calculate B=v1-v0
    sub r3, r6, r3
    sub r4, r7, r4
    sub r5, r9, r5

    ; Calculate cross product vector.
    bl vector_cross_product
    ; [R0, R1, R2] = A ^ B

    ; Normalise cross product vector.
    bl vector_norm
    ; [R0, R1, R2] = A ^ B / |A ^ B|

    ; Store in normal array.
    stmia r12!, {r0-r2}

    ; Next face.
    add r11, r11, #4
    subs r8, r8, #1
    bne .1

    ldr pc, [sp], #4

; ============================================================================
