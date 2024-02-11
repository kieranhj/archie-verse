; ============================================================================
; The Ball.
; ============================================================================

.equ TheBall_Next,     0       ; R0 = pointer to next active/free.
.equ TheBall_x,        4       ; R1
.equ TheBall_y,        8       ; R2
.equ TheBall_vx,       12      ; R3
.equ TheBall_vy,       16      ; R4
.equ TheBall_ix,       20      ; R5
.equ TheBall_iy,       24      ; R6
.equ TheBall_radius,   28      ; R7
.equ TheBall_colour,   30      ; R7
.equ TheBall_SIZE,     32

the_ball_p:
    .long the_ball_block

the_ball_block:
    .long 0
    VECTOR2 80.0, 280.0         ; position
    VECTOR2 0.5, 0.0            ; velocity
    VECTOR2 0.0, 0.0            ; accumulated force
    .short 16                   ; radius
    .short 15                   ; colour

; ============================================================================

.equ TheEnv_CentreX,            (160.0 * MATHS_CONST_1)
.equ TheEnv_CentreY,            (90.0 * MATHS_CONST_1)
.equ TheEnv_MaxPlanes,          8

.equ EnvPlane_Next,     0
.equ EnvPlane_nx,       4
.equ EnvPlane_ny,       8
.equ EnvPlane_nd,       12
.equ EnvPlane_e,        16      ; elasticity [0,1]
.equ EnvPlane_f,        20      ; 1-friction [0,1]
.equ EnvPlane_SIZE,     24

the_env_constant_force:
    VECTOR2 0.0, -(Ball_Gravity / 50.0)

; ============================================================================
; TODO: Visualise collision planes (at least for _DEBUG).

the_env_planes_p:
    .long 0

; ============================================================================

the_ball_init:
    mov pc, lr

; ============================================================================

the_ball_tick:
    str lr, [sp, #-4]!

    bl the_ball_move

    ldr pc, [sp], #4

the_ball_move:
    str lr, [sp, #-4]!

    ldr r12, the_ball_p
    ldmia r12, {r0-r7}                  ; load ball context
    ; R0=next
    ; R1=x
    ; R2=y
    ; R3=vx
    ; R4=vy
    ; R5=ix
    ; R6=iy
    ; R7=radius + colour
    ;mov r9, r7, lsr #16                 ; colour
    mov r7, r7, lsl #16                 ; radius [16.16]

    ; Ball dynamics.

    ; Constant force from the environment.
    ldr r8, the_env_constant_force+0
    ldr r9, the_env_constant_force+4

    ; acc += F
    add r5, r5, r8
    add r6, r6, r9

    ; vel += acceleration
    add r3, r3, r5
    add r4, r4, r6

    ; pos += vel
    add r1, r1, r3
    add r2, r2, r4

    ; Collisions - balls / plane(s).
    adr r11, the_env_planes_p
.1:
    ldr r11, [r11, #EnvPlane_Next]
    cmp r11, #0
    beq .2

    adr lr, .1
    b the_ball_collide_with_plane
.2:

    ; Zero ix, iy.
    mov r5, #0
    mov r6, #0

    ; Save ball state w/out radius/colour.
    stmia r12, {r0-r6}
    ldr pc, [sp], #4

; ============================================================================

; (R0=next ball)
; R1=x
; R2=y
; R3=vx
; R4=vy
; R7=radius
; R11=plane_p
; R12=ball_p
the_ball_collide_with_plane:
    str lr, [sp, #-4]!

    ldmia r11, {r0,r5-r6,r10}   ; TODO: Reconcile use of R0 next pointer if multiple balls.
    ; R5=nx
    ; R6=ny
    ; R10=nd
    mov r5, r5, asr #8          ; nx [1.8]
    mov r6, r6, asr #8          ; ny [1.8]

    ; Calculate d=pos.n
    mov r8, r1, asr #8          ; x [15.8]
    mov r9, r2, asr #8          ; y [15.8]

    mul r8, r5, r8              ; x*nx [16.16]
    mla r8, r9, r6, r8          ; d=x*nx + y*ny [16.16]

    ; Test ball distance d against plane distance nd.
    sub r8, r8, r10             ; d-nd
    cmp r8, r7                  
    ldrge pc, [sp], #4          ; no collision when p.n-nd > radius

    ; Calculate penetration depth.
    sub r10, r7, r8              ; pen_depth = radius - distance_from_plane

    ; Push the ball out by the penetration depth to the surface of the plane.
    ; This will add energy to the system but we'll deal with that elsewhere.
    ; If pen_depth > radius then ball is inside the plane and could get icky...

    mov r10, r10, asr #8
    mla r1, r5, r10, r1         ; x+=pen_depth * nx
    mla r2, r6, r10, r2         ; y+=pen_depth * ny

    ; Calculate vn=component of velocity in direction of normal.

    ; Calculate v.n
    mov r8, r3, asr #8          ; vx [15.8]
    mov r9, r4, asr #8          ; vy [15.8]

    mul r8, r5, r8              ; vx*nx [16.16]
    mla r8, r9, r6, r8          ; v.n=vx*nx + vy*ny [16.16]

    ; Calculate vn=(v.n)n
    mov r8, r8, asr #8          ; v.n [16.8]
    mul r9, r8, r5              ; vnx
    mul r10, r8, r6             ; vny

    ; mv' = mvt - mvn = (1-f).mvt - e.mvn
    ; TODO: Add friction and elasticity for ball / plane collisions.

    ; v' = v-2vn where vn=(v.n)n
    sub r3, r3, r9, asl #1      ; vx=vx-2vnx
    sub r4, r4, r10, asl #1     ; vy=vy-2vny

    ldr pc, [sp], #4

; ============================================================================

; R12=screen addr
the_ball_draw:
    str lr, [sp, #-4]!

    ldr r11, the_ball_p
    ldmia r11, {r0-r2}
    ldr r7, [r11, #TheBall_radius]

    ; Plot 2D ball.
    add r1, r1, #TheEnv_CentreX               ; [s15.16]
    rsb r2, r2, #TheEnv_CentreY               ; [s15.16]

    ;  r0 = X centre
    ;  r1 = Y centre
    mov r0, r1, asr #16
    mov r1, r2, asr #16

    ;  r2 = radius of circle
    ;  r9 = tint
    mov r9, r7, lsr #16                 ; colour
    eor r2, r7, r9, lsl #16             ; radius

    ; Schedule our ball to be drawn.
    bl circles_add_to_plot_by_order

    ldr pc, [sp], #4

; ============================================================================
; Sequence helper functions.
; ============================================================================

; R0=force x
; R1=force y
the_env_set_constant_force:
    str r0, the_env_constant_force + 0
    str r1, the_env_constant_force + 4
    mov pc, lr

; Add a plane into the environment.
; R0=plane block ptr
; R1=px
; R2=py
; R3=brad [0,255] angle
the_env_make_plane:
    ; Calculate [nx,ny] from angle.
    stmfd sp!, {r0-r1,lr}
    mov r0, r3
    bl sin_cos
    ; R0=sin(a), R1=cos(a)
    mov r3, r0
    mov r4, r1
    ldmfd sp!, {r0-r1,lr}

    str r3, [r0, #EnvPlane_nx]
    str r4, [r0, #EnvPlane_ny]

    ; Compute nd=p.n
    mov r1, r1, asr #8          ; px [16.8]
    mov r2, r2, asr #8          ; py [16.8]

    mov r3, r3, asr #8          ; nx [1.8]
    mov r4, r4, asr #8          ; ny [1.8]

    mul r1, r3, r1              ; x*nx [16.16]
    mla r1, r4, r2, r1          ; nd=px*nx + py*ny [16.16]
    str r1, [r0, #EnvPlane_nd]

    mov r2, #0
    str r2, [r0, #EnvPlane_Next]
    str r2, [r0, #EnvPlane_e]
    str r2, [r0, #EnvPlane_f]
    mov pc, lr

; R0=plane ptr
the_env_add_plane:
    ldr r1, the_env_planes_p
    str r1, [r0, #EnvPlane_Next]
    str r0, the_env_planes_p
    mov pc, lr

; R0=plane ptr
the_env_remove_plane:
    adr r2, the_env_planes_p        ; prev_p
.1:
    movs r1, r2
    beq .2                          ; end of list.
    ldr r2, [r1, #EnvPlane_Next]    ; curr_p=prev_p->next
    cmp r2, r0                      ; curr_p==this_p?
    bne .1                          ; not matched.

    ; Unlink curr_p.
    ldr r3, [r2, #EnvPlane_Next]    ; curr_p->next
    str r3, [r1, #EnvPlane_Next]    ; prev_p->next=curr_p->next
    mov r3, #0
    str r3, [r0, #EnvPlane_Next]    ; this_p->next=0
.2:
    mov pc, lr

.macro make_and_add_env_plane plane, px, py, brad
    call_4 the_env_make_plane, \plane, MATHS_CONST_1*\px, MATHS_CONST_1*\py, MATHS_CONST_1*\brad
    call_1 the_env_add_plane, \plane
.endm

; ============================================================================

; R0=x pos
; R1=y pos
the_ball_set_pos:
    str r0, the_ball_block + TheBall_x
    str r1, the_ball_block + TheBall_y
    mov pc, lr

; R0=x vel
; R1=y vel
the_ball_set_vel:
    str r0, the_ball_block + TheBall_vx
    str r1, the_ball_block + TheBall_vy
    mov pc, lr

; R0=radius
the_ball_set_radius:
    ldr r1, the_ball_block + TheBall_radius
    bic r1, r1, #0x00ff
    bic r1, r1, #0xff00
    orr r1, r1, r0
    str r1, the_ball_block + TheBall_radius
    mov pc, lr

; R0=colour
the_ball_set_colour:
    ldr r1, the_ball_block + TheBall_radius
    bic r1, r1, #0x00ff0000
    bic r1, r1, #0xff000000
    orr r1, r1, r0, lsr #16
    str r1, the_ball_block + TheBall_radius
    mov pc, lr

; Adds a force to the ball for one frame.
; R0=fx
; R1=fy
the_ball_add_impulse:
    ldr r2, the_ball_block + TheBall_ix
    ldr r3, the_ball_block + TheBall_iy
    add r2, r2, r0
    add r3, r3, r1
    str r2, the_ball_block + TheBall_ix
    str r3, the_ball_block + TheBall_iy
    mov pc, lr

; ============================================================================
