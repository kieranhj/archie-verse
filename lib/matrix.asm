; ============================================================================
; Matrix functions.
; ============================================================================

; Need to decide our coordinate system!
; ==> LEFT HANDED COORDINATES.
; +x is across, +y is up and +z is INTO the screen.
;
;  +y   +z
;   ^  
;   | /
;   |/
;   +-----> +x
;
; Matrices elements are referenced as ROW, COLUMN:
;
;          col 0 col 1 col 2
; row 0  [  00    01    02   ]
; row 1  [  10    11    12   ]
; row 2  [  20    21    22   ]
;
; and stored in ROW ORDER: 00, 01, 02, 10, 11, 12, 20, 21, 22
; 
; Consecutive words: [ 0 1 2 ]  Byte offsets: [  0  4  8 ]
;                    [ 3 4 5 ]                [ 12 16 20 ]
;                    [ 6 7 8 ]                [ 24 28 32 ]
;

; R2=ptr to 9x9 matrix M
; Compute:
; M = [ 1   0   0 ]
;     [ 0   1   0 ]
;     [ 0   0   1 ]
matrix_make_identity:
    mov r0, #MATHS_CONST_1

; R0=scale value
; R2=ptr to 9x9 matrix M
; Compute:
; M = [ s   0   0 ]
;     [ 0   s   0 ]
;     [ 0   0   s ]
matrix_make_scale:
    str r0, [r2, #MATRIX_00]
    str r0, [r2, #MATRIX_11]
    str r0, [r2, #MATRIX_22]

    mov r0, #MATHS_CONST_0
    str r0, [r2, #MATRIX_01]
    str r0, [r2, #MATRIX_02]
    str r0, [r2, #MATRIX_10]
    str r0, [r2, #MATRIX_12]
    str r0, [r2, #MATRIX_20]
    str r0, [r2, #MATRIX_21]
    mov pc, lr

; R0=rotation clockwise around X axis in brads [0-255]
; R2=ptr to 9x9 matrix M
; Compute:
; M = [ 1   0        0      ]
;     [ 0   cos(a)   sin(a) ]
;     [ 0   -sin(a)  cos(a) ]
matrix_make_rotate_x:
    str lr, [sp, #-4]!

    ; R0=brads
    bl sin_cos
    ; R0=sin(brads), R1=cos(brads)

    str r1, [r2, #MATRIX_11]
    str r1, [r2, #MATRIX_22]
    str r0, [r2, #MATRIX_21]
    rsb r0, r0, #0              ; -sin(rads)
    str r0, [r2, #MATRIX_12]

    mov r0, #MATHS_CONST_0
    str r0, [r2, #MATRIX_01]
    str r0, [r2, #MATRIX_02]
    str r0, [r2, #MATRIX_10]
    str r0, [r2, #MATRIX_20]

    mov r0, #MATHS_CONST_1
    str r0, [r2, #MATRIX_00]
    ldr pc, [sp], #4


; R0=rotation clockwise around Y axis in brads [0-255]
; R2=ptr to 9x9 matrix M
; Compute:
; M = [ cos(a)  0  -sin(a) ]
;     [ 0       1   0      ]
;     [ sin(a)  0   cos(a) ]
matrix_make_rotate_y:
    str lr, [sp, #-4]!

    ; R0=brads
    bl sin_cos
    ; R0=sin(brads), R1=cos(brads)
    
    str r1, [r2, #MATRIX_00]
    str r1, [r2, #MATRIX_22]
    str r0, [r2, #MATRIX_20]
    rsb r0, r0, #0              ; -sin(rads)
    str r0, [r2, #MATRIX_02]

    mov r0, #MATHS_CONST_0
    str r0, [r2, #MATRIX_01]
    str r0, [r2, #MATRIX_10]
    str r0, [r2, #MATRIX_12]
    str r0, [r2, #MATRIX_21]

    mov r0, #MATHS_CONST_1
    str r0, [r2, #MATRIX_11]
    ldr pc, [sp], #4

; R0=rotation clockwise around Z axis in brads [0-255]
; R2=ptr to 9x9 matrix M
; Compute:
; M = [ cos(a)    sin(a)  0 ]
;     [ -sin(a)   cos(a)  0 ]
;     [ 0         0       1 ]
matrix_make_rotate_z:
    str lr, [sp, #-4]!

    ; R0=brads
    bl sin_cos
    ; R0=sin(brads), R1=cos(brads)
    
    str r1, [r2, #MATRIX_00]
    str r1, [r2, #MATRIX_11]
    str r0, [r2, #MATRIX_01]
    rsb r0, r0, #0              ; -sin(rads)
    str r0, [r2, #MATRIX_10]

    mov r0, #MATHS_CONST_0
    str r0, [r2, #MATRIX_02]
    str r0, [r2, #MATRIX_12]
    str r0, [r2, #MATRIX_20]
    str r0, [r2, #MATRIX_21]

    mov r0, #MATHS_CONST_1
    str r0, [r2, #MATRIX_22]
    ldr pc, [sp], #4

; Multiply vector by a matrix.
; Parameters:
;  R0=ptr to 9x9 matrix M stored in row order.
;  R1=ptr to vector A.
;  R2=ptr to vector B.
; Trashes: R3-R9
;
; Compute B = M.A where:
;
; M = [ a b c ]  A = [ x ]
;     [ d e f ]      [ y ]
;     [ g h i ]      [ z ]
;
; B = M . A = [ a.x + b.y + c.z ]
;             [ d.x + e.y + f.z ]
;             [ g.x + h.y + i.z ]
;
matrix_multiply_vector:
    ldmia r1, {r6-r8}                   ; [ x y z ][s7.16]
matrix_multiply_vector_loaded:
    mov r6, r6, asr #MULTIPLICATION_SHIFT    ; [s7.8]
    mov r7, r7, asr #MULTIPLICATION_SHIFT    ; [s7.8]
    mov r8, r8, asr #MULTIPLICATION_SHIFT    ; [s7.8]

    ldmia r0!, {r3-r5}                  ; [ a b c ][s7.16]
    mov r3, r3, asr #MULTIPLICATION_SHIFT    ; [s7.8]
    mov r4, r4, asr #MULTIPLICATION_SHIFT    ; [s7.8]
    mov r5, r5, asr #MULTIPLICATION_SHIFT    ; [s7.8]

    mul r9, r3, r6                      ; r9 = a * x  [s15.16]
    mla r9, r4, r7, r9                  ;   += b * y  [s15.16]
    mla r9, r5, r8, r9                  ;   += c * z  [s15.16]
    str r9, [r2, #0]                    ; vectorB[x] = r9

    ldmia r0!, {r3-r5}                  ; [ d e f ][s7.16]
    mov r3, r3, asr #MULTIPLICATION_SHIFT    ; [s7.8]
    mov r4, r4, asr #MULTIPLICATION_SHIFT    ; [s7.8]
    mov r5, r5, asr #MULTIPLICATION_SHIFT    ; [s7.8]

    mul r9, r3, r6                       ; r9 = d * x  [s15.16]
    mla r9, r4, r7, r9                  ;    += e * y  [s15.16]
    mla r9, r5, r8, r9                  ;    += f * z  [s15.16]
    str r9, [r2, #4]                    ; vectorB[y] = r9

    ldmia r0!, {r3-r5}                  ; [ g h i ][s7.16]
    mov r3, r3, asr #MULTIPLICATION_SHIFT    ; [s7.8]
    mov r4, r4, asr #MULTIPLICATION_SHIFT    ; [s7.8]
    mov r5, r5, asr #MULTIPLICATION_SHIFT    ; [s7.8]

    mul r9, r3, r6                      ; r9 = g * x  [s15.16]
    mla r9, r4, r7, r9                  ;   += h * y  [s15.16]
    mla r9, r5, r8, r9                  ;   += i * z  [s15.16]
    str r9, [r2, #8]                    ; vectorB[z] = r9

    sub r0, r0, #9*4                    ; reset ptr to M
    mov pc, lr

; Matrix multiplication.
; Parameters:
;  R0=ptr to 9x9 matrix A
;  R1=ptr to 9x9 matrix B
;  R2=ptr to 9x9 matrix M
; Trashes: R3-R10
;
; A = [ a1 b1 c1 ]  B = [ a2 b2 c2 ]
;     [ d1 e1 f1 ]      [ d2 e2 f2 ]
;     [ g1 h1 i1 ]      [ g2 h2 i2 ]
;
; Compute M = A. B = [ a1.a2 + b1.d2 + c1.g2  a1.b2 + b1.e2 + c1.h2  a1.c2 + b1.f2 + c1.i2 ]
;                    [ d1.a2 + e1.d2 + f1.g2  d1.b2 + e1.e2 + f1.h2  d1.c2 + e1.f2 + f1.i2 ]
;                    [ g1.a2 + h1.d2 + i1.g2  g1.b2 + h1.e2 + i1.h2  g1.c2 + h1.f2 + i1.i2 ]
matrix_multiply:
    str lr, [sp, #-4]!

    mov r10, r2         ; destination matrix.
    adr r2, .1          ; temp vector.

    ; R0=A
    ; R2=temp vector
    ; R6=a2
    ; R7=d2
    ; R8=g2
    ldr r6, [r1, #MATRIX_00]
    ldr r7, [r1, #MATRIX_10]
    ldr r8, [r1, #MATRIX_20]
    bl matrix_multiply_vector_loaded
    ldmia r2, {r6-r8}
    str r6, [r10, #MATRIX_00]
    str r7, [r10, #MATRIX_10]
    str r8, [r10, #MATRIX_20]

    ; R6=b2
    ; R7=e2
    ; R8=h2
    ldr r6, [r1, #MATRIX_01]
    ldr r7, [r1, #MATRIX_11]
    ldr r8, [r1, #MATRIX_21]
    bl matrix_multiply_vector_loaded
    ldmia r2, {r6-r8}
    str r6, [r10, #MATRIX_01]
    str r7, [r10, #MATRIX_11]
    str r8, [r10, #MATRIX_21]

    ; R6=c2
    ; R7=f2
    ; R8=i2
    ldr r6, [r1, #MATRIX_02]
    ldr r7, [r1, #MATRIX_12]
    ldr r8, [r1, #MATRIX_22]
    bl matrix_multiply_vector_loaded
    ldmia r2, {r6-r8}
    str r6, [r10, #MATRIX_02]
    str r7, [r10, #MATRIX_12]
    str r8, [r10, #MATRIX_22]

    ldr pc, [sp], #4

.1:
    .skip 12

; ============================================================================

.if 0
; R0=ptr to 9x9 unit matrix M stored in row order.
; R1=ptr to vector A.
; R2=ptr to vector B.
; Trashes: R3-R9
;
; Compute B = M.A where M is a unit matrix (all elements [-1.0,+1.0])
;
unit_matrix_multiply_vector:
    ldmia r0!, {r3-r5}                  ; [ a b c ]   [s1.16]
    ldmia r1, {r6-r8}                   ; [ x y z ]   [s15.16]

    mul r9, r3, r6                      ; r9 = a * x  [s30.32] overflow!
    mla r9, r4, r7, r9                  ;   += b * y  [s30.32] overflow!
    mla r9, r5, r8, r9                  ;   += c * z  [s30.32] overflow!
    mov r9, r9, asr #PRECISION_BITS     ; [s15.16]
    str r9, [r2, #0]                    ; vectorB[x] = r9

    ldmia r0!, {r3-r5}                  ; [ d e f ]   [s1.16]
    mul r9, r3, r6                      ; r9 = d * x  [s30.32] overflow!
    mla r9, r4, r7, r9                  ;   += e * y  [s30.32] overflow!
    mla r9, r5, r8, r9                  ;   += f * z  [s30.32] overflow!
    mov r9, r9, asr #PRECISION_BITS     ; [s15.16]
    str r9, [r2, #4]                    ; vectorB[y] = r9

    ldmia r0!, {r3-r5}                  ; [ g h i ]   [s1.16]
    mul r9, r3, r6                      ; r9 = g * x  [s30.32] overflow!
    mla r9, r4, r7, r9                  ;   += h * y  [s30.32] overflow!
    mla r9, r5, r8, r9                  ;   += i * z  [s30.32] overflow!
    mov r9, r9, asr #PRECISION_BITS     ; [s15.16]
    str r9, [r2, #8]                    ; vectorB[z] = r9

    mov pc, lr
.endif

; ============================================================================

.if 0
object_transform:
    MATRIX33_IDENTITY

normal_transform:           ; Rotation only.
    MATRIX33_IDENTITY

temp_matrix_1:
    MATRIX33_IDENTITY

temp_matrix_2:
    MATRIX33_IDENTITY

temp_vector_1:
    VECTOR3_ZERO

temp_vector_2:
    VECTOR3_ZERO

transform_3d_scene:
    str lr, [sp, #-4]!

    ; Create rotation matrix as object transform.
    adr r2, temp_matrix_1
    ldr r0, object_rot + 0
    bl matrix_make_rotate_x     ; T1=rot_x

    adr r2, object_transform
    ldr r0, object_rot + 4
    bl matrix_make_rotate_y     ; OT=rot_y

    adr r0, temp_matrix_1
    adr r1, object_transform
    adr r2, temp_matrix_2
    bl matrix_multiply          ; T2=T1.OT

    adr r2, temp_matrix_1
    ldr r0, object_rot + 8
    bl matrix_make_rotate_z     ; T1=rot_z

    adr r0, temp_matrix_2
    adr r1, temp_matrix_1
    adr r2, normal_transform    ; NT=T2.T1  <== rotation only.
    bl matrix_multiply

    ldr r0, object_scale
    adr r2, temp_matrix_2
    bl matrix_make_scale        ; T2=scale

    adr r0, temp_matrix_2
    adr r1, normal_transform
    adr r2, object_transform    ; OT=T2.NT
    bl matrix_multiply

    ; Subtract camera position from object position.
    adr r12, camera_pos
    ldmia r12, {r3-r5}

    adr r11, object_pos
    ldmia r11, {r6-r8}

    sub r6, r6, r3
    sub r7, r7, r4
    sub r8, r8, r5

    ; Camera relative object position.
    adr r11, object_pos_camera_relative
    stmia r11, {r6-r8}

    ; Transform vertices in scene.
    adr r0, object_transform
    adr r1, object_verts
    adr r2, transformed_verts
    mov r10, #object_num_verts
    .1:
    ; R0=ptr to matrix, R1=vector A, R2=vector B
    bl matrix_multiply_vector

    ldmia r2, {r3-r5}
    ; Add camera relative object position to transform vertex.
    ldmia r11, {r6-r8}
    add r3, r3, r6
    add r4, r4, r7
    add r5, r5, r8
    stmia r2!, {r3-r5}
    
    add r1, r1, #VECTOR3_SIZE
    subs r10, r10, #1
    bne .1

    ; Transform normals.
    adr r0, normal_transform
    adr r1, object_face_normals
    adr r2, transformed_normals
    mov r10, #object_num_faces
    .2:
    ; R0=ptr to matrix, R1=vector A, R2=vector B
    bl matrix_multiply_vector

    add r1, r1, #VECTOR3_SIZE
    add r2, r2, #VECTOR3_SIZE
    subs r10, r10, #1
    bne .2
.endif
