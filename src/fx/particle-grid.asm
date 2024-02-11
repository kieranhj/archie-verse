; ============================================================================
; Particle grid.
; 2D particles only.
; Fixed number of particles (not created/destroyed).
; Not necessarily in a grid arrangement but typically.
; Apply forces to each particle, including a spring force to return to origin.
; ============================================================================

; Particle variables block:
.equ ParticleGrid_XPos,     0       ; R1
.equ ParticleGrid_YPos,     4       ; R2
.equ ParticleGrid_Colour,   8
.equ ParticleGrid_XVel,     8       ; R3
.equ ParticleGrid_YVel,     12      ; R4
.equ ParticleGrid_XOrigin,  16      ; R5
.equ ParticleGrid_YOrigin,  20      ; R6
.equ ParticleGrid_SIZE,     24
; TODO: Sprite per particle etc.?

.equ ParticleGrid_Max,          (24*18)     ; runs at 50Hz with the Dave equation.

.equ ParticleGrid_CentreX,      (160.0 * MATHS_CONST_1)
.equ ParticleGrid_CentreY,      (90.0 * MATHS_CONST_1)

.equ ParticleGrid_Minksy_Rotation,  12      ; 12=slow, 0=none
.equ ParticleGrid_Minksy_Expansion, 12      ; 12=slow, 0=none

; ============================================================================

; Ptr to the particle array in bss.
particle_grid_array_p:
    .long particle_grid_array_no_adr

particle_grid_sqrt_p:
    .long sqrt_table_no_adr

particle_grid_recip_p:
    .long reciprocal_table_no_adr

particle_grid_total:
    .long 0

; ============================================================================

particle_grid_collider_pos:
    VECTOR2 0.0, 128.0

particle_grid_collider_radius:
    FLOAT_TO_FP 48.0        ;Particles_CircleCollider_Radius

particle_grid_gloop_factor:
    FLOAT_TO_FP 0.95

particle_grid_dave_maxpush:
    FLOAT_TO_FP 1.21

; ============================================================================

; R0=Num X
; R1=Num Y
; R2=X Start
; R3=Y Start
; R4=X Step
; R5=Y Step
particle_grid_make:
    stmfd sp!, {r0-r5}

    mul r6, r0, r1                  ; total = NumX * NumY
    .if _DEBUG
    cmp r6, #ParticleGrid_Max
    adrgt r0, error_gridtoolarge
    swigt OS_GenerateError
    .endif
    str r6, particle_grid_total

    ldr r11, particle_grid_array_p

    mov r9, r4                      ; XStep
    mov r10, r5                     ; YStep

    ; XVel, YVel.
    mov r3, #0
    mov r4, #0
    mov r12, #0                     ; Colour

    ; Y loop.
    ldr r2, [sp, #12]               ; YPos
    ldr r8, [sp, #4]                ; NumY
.1:
    ldr r1, [sp, #8]                ; XPos
    ldr r7, [sp, #0]                ; NumX

    ; X loop.
.2:
    mov r5, r1
    mov r6, r2                      ; Origin

    stmia r11!, {r1-r6}

    add r1, r1, r9
    subs r7, r7, #1
    bne .2

    add r2, r2, r10
    subs r8, r8, #1
    bne .1

    ldmfd sp!, {r0-r5}
    mov pc, lr

.if _DEBUG
error_gridtoolarge:
	.long 0
	.byte "Particle grid too large!"
	.p2align 2
	.long 0
.endif

; Fill a line.
; R0=Count
; R1=X Pos
; R2=Y Pos
; R7=X Inc.
; R8=Y Inc.
; R11=array ptr
; R12=count
particle_gridlines_fill:
    mov r3, #0      ; X Vel
    mov r4, #0      ; Y Vel
.1:
    mov r5, r1      ; X Origin
    mov r6, r2      ; Y Origin

    stmia r11!, {r1-r6}

    add r1, r1, r7
    add r2, r2, r8

    add r12, r12, #1
    .if _DEBUG
    cmp r12, #ParticleGrid_Max
    adrgt r0, error_gridtoolarge
    swigt OS_GenerateError
    .endif

    subs r0, r0, #1
    bne .1
    mov pc, lr

; R0=Num X          #0
; R1=Num Y          #4
; R2=X Start        #8
; R3=Y Start        #12
; R4=Minor Step     #16
; R5=Minors per Major    #20
particle_gridlines_make:
    stmfd sp!, {r0-r5, lr}

    ldr r11, particle_grid_array_p
    mov r12, #0

    ; Y loop.
    ldr r2, [sp, #12]               ; YPos
    ldr r10, [sp, #4]               ; NumY
    sub r10, r10, #1
.1:
    ldr r8, [sp, #16]               ; YInc
    ldr r0, [sp, #20]               ; Minors per major
    mul r0, r8, r0                  ; YInc*MpM
    add r2, r2, r0                  ; YPos+=YInc*MpM

    ldr r1, [sp, #8]                ; XPos
    ldr r7, [sp, #16]               ; XInc
    mov r8, #0                      ; YInc

    ldr r9, [sp, #0]                ; NumX
    ldr r0, [sp, #20]               ; Minors per major
    mul r0, r9, r0                  ; NumX*MpM
    add r0, r0, #1

    bl particle_gridlines_fill

    subs r10, r10, #1
    bne .1

    ; X loop.
    ldr r1, [sp, #8]                ; XPos
    ldr r9, [sp, #0]                ; NumX
    sub r9, r9, #1
.2:
    ldr r7, [sp, #16]               ; XInc
    ldr r0, [sp, #20]               ; Minors per major
    mul r0, r7, r0                  ; YInc*MpM
    add r1, r1, r0                  ; XPos+=XInc*MpM

    ldr r2, [sp, #12]               ; YPos
    mov r7, #0                      ; XInc
    ldr r8, [sp, #16]               ; YInc

    ldr r10, [sp, #4]               ; NumY
    ldr r0, [sp, #20]               ; Minors per major
    mul r0, r10, r0                  ; NumY*MpM
    add r0, r0, #1

    bl particle_gridlines_fill

    subs r9, r9, #1
    bne .2

    str r12, particle_grid_total

    ldmfd sp!, {r0-r5, pc}

; R0=total particles
; R1=angle increment [brads]
; R2=start radius
; R3=radius increment
; R4=centre X
; R5=centre Y
particle_grid_make_spiral:
    str lr, [sp, #-4]!

   .if _DEBUG
    cmp r0, #ParticleGrid_Max
    adrgt r0, error_gridtoolarge
    swigt OS_GenerateError
    .endif
    str r0, particle_grid_total

    mov r2, r2, asr #8
    mov r3, r3, asr #8

    ldr r11, particle_grid_array_p
    mov r12, r0
    mov r10, r1
    mov r8, #0
.1:
    mov r0, r8          ; angle
    bl sin_cos
    ; R0=sin(angle)
    ; R1=cos(angle)

    mov r0, r0, asr #8
    mov r1, r1, asr #8

    mla r6, r0, r2, r4  ; x = cx + r * sin(a)
    mla r7, r1, r2, r5  ; y = cy + r * cos(a)

    ; Write particle block.
    stmia r11!, {r6-r7}
    mov r0, #0
    mov r1, #0
    stmia r11!, {r0-r1}
    stmia r11!, {r6-r7}

    add r8, r8, r10     ; a+=inc_a
    add r2, r2, r3      ; r+=inc_r

    subs r12, r12, #1
    bne .1
    
    ldr pc, [sp], #4

; ============================================================================

particle_grid_tick_all:
    str lr, [sp, #-4]!

    ; R6=object.x
    ; R7=object.y
    ; R10=object.radius
    ldr r10, particle_grid_collider_radius

    .if 0
    swi OS_Mouse
    mov r6, r0, asl #14
    mov r7, r1, asl #14                  ; [16.16] pixel coords.
    sub r6, r6, #ParticleGrid_CentreX
    sub r7, r7, #ParticleGrid_CentreY

    ;  r0 = X centre
    ;  r1 = Y centre
    ;  r2 = radius of circle
    ;  r9 = tint
    mov r0, r0, asr #2
    mov r1, r1, asr #2
    rsb r1, r1, #255
    mov r2, #Particles_CircleCollider_Radius
    mov r9, #1
    bl circles_add_to_plot_by_order
    .else
    ldr r6, particle_grid_collider_pos+0
    ldr r7, particle_grid_collider_pos+4
    .endif

    mov r10, r10, asr #8                ; [8.8]
    mov r14, r10                        ; [8.8]
    mul r10, r14, r10                   ; [16.16]
    mov r10, r10, asr #18               ; sqradius/4 [14.0]

    ldr r12, particle_grid_total
    ldr r11, particle_grid_array_p
.1:
    ldmia r11, {r1-r2}

    ; Particle dynamics.

    ; Compute displacement force from attractor etc.
    ; F = G * m1 * m2 / |p2-p1|^2

    ; Compute distance to object.
    sub r8, r6, r1                      ; dx = pos.x - obj.x
    sub r9, r7, r2                      ; dy = pox.y - obj.y

    ; Calcluate dist^2=dx*dx + dy*dy
    mov r4, r8, asr #10             ; [10.6]
    mov r14, r4
    mul r4, r14, r4                 ; dx*dx [20.12]

    mov r5, r9, asr #10
    mov r14, r5
    mul r5, r14, r5                 ; dy*dy [20.12]

    add r5, r4, r5                  ; distsq=dx*dx + dy*dy [20.12]
    mov r5, r5, asr #14             ; distsq/4             [16.0]

    ; Calculate dist=sqrt(dx*dx + dy*dy)

    ; SQRT table goes from [1, 512*512) = [0x00001, 0x40000) (18 bits)
    ; Contains 65536 = 0x10000 entries                       (16 bits)
    ; Values are in 16.16 format.

    ; Limited precision.
    cmp r5, #LibSqrt_Entries    ; Test for numerator too large
    movge r8, #0
    movge r9, #0
    bge .2

    .if _DEBUG
    adrge r0,sqrtrange           ; and flag an error
    swige OS_GenerateError      ; when necessary
    .endif

    subs r5, r5, #1
    movmi r14, #MATHS_CONST_1       ; should be 0 but avoid div by 0.
    ldrpl r4, particle_grid_sqrt_p
    ldrpl r14, [r4, r5, lsl #2]     ; dist=sqrt4(distsq) [16.16]

    ; Calculate 1/dist.
    ldr r4, particle_grid_recip_p

    ; Put divisor in table range.
    mov r14, r14, asr #16-LibDivide_Reciprocal_s    ; [16.6]    (b<<s)

    .if _DEBUG
    cmp r14, #0
    adrle r0,divbyzero          ; and flag an error
    swile OS_GenerateError      ; when necessary
    .endif

    ; Limited precision.
    cmp r14, #1<<LibDivide_Reciprocal_t    ; Test for numerator too large
    movge r8, #0
    movge r9, #0
    bge .2

    .if _DEBUG
    adrge r0,divrange           ; and flag an error
    swige OS_GenerateError      ; when necessary
    .endif

    ; Lookup 1/dist.
    ldr r14, [r4, r14, lsl #2]    ; [0.16]    (1<<16+s)/(b<<s) = (1<<16)/b

    ; dx/=dist
    mov r8, r8, asr #16-LibDivide_Reciprocal_s    ; [16.6]    (a<<s)
    mul r8, r14, r8                      ; [10.22]   (a<<s)*(1<<16)/b = (a<<16+s)/b
    mov r8, r8, asr #LibDivide_Reciprocal_s       ; [10.16]   (a<<16)/b = (a/b)<<16

    ; dy/=dist
    mov r9, r9, asr #16-LibDivide_Reciprocal_s    ; [16.6]    (a<<s)
    mul r9, r14, r9                      ; [10.22]   (a<<s)*(1<<16)/b = (a<<16+s)/b
    mov r9, r9, asr #LibDivide_Reciprocal_s       ; [10.16]   (a<<16)/b = (a/b)<<16

    ; [R8,R9]=normalised vector between particle and object.

    ; Lookup 1/(distsq/4) = 4/distsq.

    ; Constrain min distsq to radius? Seems to work better.
    cmp r5, r10
    movlt r5, r10

    ; Constrain max distsq.
    ; TODO: Can probably early out here for a large set where push eventually == 0.
    cmp r5, #1<<LibDivide_Reciprocal_t      ; Test for numerator too large
    movge r5, #1<<LibDivide_Reciprocal_t
    subge r5, r5, #1                        ; Clamp to 65535.

    ldr r14, [r4, r5, lsl #2]               ; 4/distsq [0.16+s]

    ; TODO: Make attractor mass variable?
    ; NOTE: Use mvn to make this a repulsor not attractor.
    mvn r5, r14, asl #6                     ; push=M/distsq where M=4<<5=128 [7.23]

    .if LibDivide_Reciprocal_s != 7
    .err "Expected LibDivide_Reciprocal_s==7!"
    .endif

    ; Calculate displacement.
    mov r5, r5, asr #7              ; push [7.16]
    mov r8, r8, asr #8              ; dx [~1.8]
    mul r8, r5, r8                  ; dx*push [8.24]
    mov r9, r9, asr #8              ; dy [~1.8]
    mul r9, r5, r9                  ; dy*push [8.24]

    mov r8, r8, asr #8              ; [8.16]
    mov r9, r9, asr #8              ; [8.16]

.2:

    ; Spring force to return to origin (r0,r3).
    ldr r0, [r11, #ParticleGrid_XOrigin]
    ldr r3, [r11, #ParticleGrid_YOrigin]

    ; Compute distance to object.
    sub r0, r0, r1                      ; dx = pos.x - obj.x
    sub r3, r3, r2                      ; dy = pox.y - obj.y

    ; Calcluate dist^2=dx*dx + dy*dy
    mov r4, r0, asr #10             ; [10.6]
    mov r14, r4
    mul r4, r14, r4                 ; dx*dx [20.12]

    mov r5, r3, asr #10
    mov r14, r5
    mul r5, r14, r5                 ; dy*dy [20.12]

    add r5, r4, r5                  ; distsq=dx*dx + dy*dy [20.12]
    mov r5, r5, asr #14             ; distsq/4             [16.0]

    ; Calculate dist=sqrt(dx*dx + dy*dy)

    ; SQRT table goes from [1, 512*512) = [0x00001, 0x40000) (18 bits)
    ; Contains 65536 = 0x10000 entries                       (16 bits)
    ; Values are in 16.16 format.

    ; Limited precision.
    cmp r5, #LibSqrt_Entries    ; Test for numerator too large
    bge .3

    .if _DEBUG
    adrge r0,sqrtrange           ; and flag an error
    swige OS_GenerateError      ; when necessary
    .endif

    subs r5, r5, #1
    movmi r14, #MATHS_CONST_1       ; should be 0 but avoid div by 0.
    ldrpl r4, particle_grid_sqrt_p
    ldrpl r14, [r4, r5, lsl #2]     ; dist=sqrt4(distsq) [16.16]

    ; Calculate 1/dist.
    ldr r4, particle_grid_recip_p

    ; Put divisor in table range.
    mov r14, r14, asr #16-LibDivide_Reciprocal_s    ; [16.6]    (b<<s)

    .if _DEBUG
    cmp r14, #0
    adrle r0,divbyzero          ; and flag an error
    swile OS_GenerateError      ; when necessary
    .endif

    ; Limited precision.
    cmp r14, #1<<LibDivide_Reciprocal_t    ; Test for numerator too large
    bge .3

    .if _DEBUG
    adrge r0,divrange           ; and flag an error
    swige OS_GenerateError      ; when necessary
    .endif

    ; Lookup 1/dist.
    ldr r14, [r4, r14, lsl #2]    ; [0.16]    (1<<16+s)/(b<<s) = (1<<16)/b

    ; R0=dx/dist
    mov r0, r0, asr #16-LibDivide_Reciprocal_s    ; [16.6]    (a<<s)
    mul r0, r14, r0                      ; [10.22]   (a<<s)*(1<<16)/b = (a<<16+s)/b
    mov r0, r0, asr #LibDivide_Reciprocal_s       ; [10.16]   (a<<16)/b = (a/b)<<16

    ; R3=dy/dist
    mov r3, r3, asr #16-LibDivide_Reciprocal_s    ; [16.6]    (a<<s)
    mul r3, r14, r3                      ; [10.22]   (a<<s)*(1<<16)/b = (a<<16+s)/b
    mov r3, r3, asr #LibDivide_Reciprocal_s       ; [10.16]   (a<<16)/b = (a/b)<<16
    
    ; F=k.d where k=0.25
    add r8, r8, r0, asr #5
    add r9, r9, r3, asr #5

.3:
    ; [R8,R9] = force from object

    ldr r3, [r11, #ParticleGrid_XVel]
    ldr r4, [r11, #ParticleGrid_YVel]

    ; Subtract a drag force to remove some energy from the system.
    sub r8, r8, r3, asr #5          ; acc -= -vel/32
    sub r9, r9, r4, asr #5

    ; vel += acceleration
    add r3, r3, r8
    add r4, r4, r9

    ; pos += vel
    add r1, r1, r3
    add r2, r2, r4

    ; Presume no collision detection?
    ; TODO: Would it be faster to plot immediately here?

    ; Save particle state.
    stmia r11, {r1-r4}
    add r11, r11, #ParticleGrid_SIZE

    subs r12, r12, #1
    bne .1

    ldr pc, [sp], #4

; ============================================================================

particle_grid_inv_radius:
    .long 0

particle_grid_tick_all_dave_equation:
    str lr, [sp, #-4]!

    ; R6=object.x
    ; R7=object.y
    ; R10=object.radius
    ldr r6, particle_grid_collider_pos+0

    ; Clamp distance of collider to avoid overflows.
    cmp r6, #MATHS_CONST_1*255.0
    movgt r6, #MATHS_CONST_1*255.0
    cmp r6, #MATHS_CONST_1*-255.0
    movlt r6, #MATHS_CONST_1*-255.0

    ldr r7, particle_grid_collider_pos+4

    cmp r7, #MATHS_CONST_1*-255.0
    movlt r7, #MATHS_CONST_1*-255.0
    cmp r7, #MATHS_CONST_1*512.0
    movgt r7, #MATHS_CONST_1*512.0

    ldr r10, particle_grid_collider_radius

    ; Calculate 1/radius.
    ldr r4, particle_grid_recip_p

    ; Put divisor in table range.
    mov r14, r10, asr #16-LibDivide_Reciprocal_s    ; [16.6]    (b<<s)

    .if _DEBUG
    cmp r14, #0
    adrle r0,divbyzero          ; and flag an error
    swile OS_GenerateError      ; when necessary

    cmp r14, #1<<LibDivide_Reciprocal_t    ; Test for numerator too large
    adrge r0,divrange           ; and flag an error
    swige OS_GenerateError      ; when necessary
    .endif

    ; Lookup 1/radius.
    ldr r0, [r4, r14, lsl #2]    ; [0.16]    (1<<16+s)/(b<<s) = (1<<16)/b
    mov r0, r0, asr #4
    str r0, particle_grid_inv_radius        ; [1.12]

    ldr r0, particle_grid_sqrt_p

    ldr r3, particle_grid_gloop_factor       ; factor [1.16]
    ldr r12, particle_grid_total
    ldr r11, particle_grid_array_p

particle_grid_tick_all_dave_loop:
    ldmia r11, {r1-r2}                  ; pos.x, pos.y

    ; Particle dynamics as per Dave's Blender graph.

    ; Compute delta_vec to object.
    sub r8, r6, r1                      ; dx = obj.x - pos.x
    sub r9, r7, r2                      ; dy = obj.y - pos.y

    ; Calcluate dist^2=dx*dx + dy*dy
    mov r4, r8, asr #10             ; [10.6]
    mov r14, r4
    mul r4, r14, r4                 ; dx*dx [20.12]

    mov r5, r9, asr #10
    mov r14, r5
    mla r5, r14, r5, r4             ; distsq=dx*dx + dy*dy [20.12]

    ; TODO: Can early out here if distsq > radiussq. See R10 above.

    mov r5, r5, asr #14             ; distsq/4             [16.0]

    ; Calculate dist=sqrt(dx*dx + dy*dy)

    ; SQRT table goes from [1, 512*512) = [0x00001, 0x40000) (18 bits)
    ; Contains 65536 = 0x10000 entries                       (16 bits)
    ; Values are in 16.16 format.

    ; Limited precision.
    cmp r5, #LibSqrt_Entries    ; Test for numerator too large
    movge r8, #0
    movge r9, #0
    bge .2

    .if _DEBUG
    adrge r0,sqrtrange           ; and flag an error
    swige OS_GenerateError      ; when necessary
    .endif

    subs r5, r5, #1
    movmi r14, #MATHS_CONST_1       ; should be 0 but avoid div by 0.
    ldrpl r14, [r0, r5, lsl #2]     ; dist=sqrt4(distsq) [16.16]

    ; Clamp dist. [0.0, radius] => [-max_push, 0.0]

    ; if dist > radius, cd = 0.0
    cmp r14, r10                    ; dist > radius?
    movge r14, #0
    bge .2

    ; if dist < 0.0 cd = -max_push (not possible anyway)

    ; cd = -max_push + (dist/radius) * max_push
    ; cd = max_push * dist * (1/radius) - max_push

    ldr r5, particle_grid_inv_radius    ; 1/radius [1.12]
    mov r14, r14, asr #4            ; dist [8.12]
    mul r14, r5, r14                ; dist / radius [1.24]
    mov r14, r14, asr #8            ; [1.16]

    ; TODO: Keep in reg? Or might be const.
    ldr r5, particle_grid_dave_maxpush  ; max_push   [8.16]
    mov r5, r5, asr #8              ; [8.8]

    mul r14, r5, r14                ; max_push * dist / radius [8.24]
    mov r14, r14, asr #8

    sub r14, r14, r5, asl #8        ; clamp_dist = (max_push * dist / radius) - max_push [8.16]

.2:
    ; Calculate offset vec = delta_vec * clamp_dist

    mov r14, r14, asr #8            ; clamp_dist [8.8]
    mov r8, r8, asr #8              ; dx [~9.8]
    mov r9, r9, asr #8              ; dy [~9.8]

    ; Calculate desired position = current_pos + offset_vec.

    mla r1, r14, r8, r1             ; desired.x = pos.x + off.x [16.16]
    mla r2, r14, r9, r2             ; desired.y = pos.y + off.y [16.16]

    ; Original position.

    ldr r8, [r11, #ParticleGrid_XOrigin]    ; orig.x
    ldr r9, [r11, #ParticleGrid_YOrigin]    ; orig.y

    ; NB. Updating the original position here with rotation
    ;     and expansion, causes the desired vector to get large
    ;     and therefore changes the colour of the particles.
    ;     This is an interesting effect which may or may not be
    ;     intended!!

    ; Calculate desired position - original position:
    sub r1, r1, r8                  ; desired.x - orig.x
    sub r2, r2, r9                  ; desired.y - orig.y

    ; Calculate the length of this vector for colour!
    .if 1
    ; Calcluate dist^2=dx*dx + dy*dy
    mov r4, r1, asr #10             ; [10.6]
    mov r14, r4
    mul r4, r14, r4                 ; dx*dx [20.12]

    mov r5, r2, asr #10
    mov r14, r5
    mla r5, r14, r5, r4             ; distsq=dx*dx + dy*dy [20.12]

    mov r5, r5, asr #14             ; distsq/4             [16.0]

    ; Calculate dist=sqrt(dx*dx + dy*dy)

    ; SQRT table goes from [1, 512*512) = [0x00001, 0x40000) (18 bits)
    ; Contains 65536 = 0x10000 entries                       (16 bits)
    ; Values are in 16.16 format.

    ; Limited precision.
    .if _DEBUG
    cmp r5, #LibSqrt_Entries    ; Test for numerator too large
    adrge r0,sqrtrange           ; and flag an error
    swige OS_GenerateError      ; when necessary
    .endif

    subs r5, r5, #1
    movmi r5, #MATHS_CONST_1       ; should be 0 but avoid div by 0.
    ldrpl r5, [r0, r5, lsl #2]     ; dist=sqrt4(distsq) [16.16]

    ; Interesting experiement - store max distance - sort of like mixing paint.
    ;ldr r14, [r11, #ParticleGrid_Colour]
    ;cmp r5, r14
    ;movlt r5, r14
    .endif

    ; TODO: factor might be const?
    mov r14, r3, asr #8             ; factor [1.8]
    mov r1, r1, asr #8              ; [~9.8]
    mov r2, r2, asr #8              ; [~9.8]

    ; Minksy rotation.
    ; xnew = xold - (yold >> k)
    ; ynew = yold + (xnew >> k)
particle_grid_tick_all_dave_rotation_code:
    sub r8, r8, r9, asr #ParticleGrid_Minksy_Rotation
    add r9, r9, r8, asr #ParticleGrid_Minksy_Rotation

    ; Minksy expansion.
    ; xnew = xold + (xold >> k)
    ; ynew = yold + (yold >> k)
particle_grid_tick_all_dave_expansion_code:
    add r8, r8, r8, asr #ParticleGrid_Minksy_Expansion
    add r9, r9, r9, asr #ParticleGrid_Minksy_Expansion

    ; Lerp between desired and original position.
    mla r1, r14, r1, r8             ; pos.x = orig.x - f * (desired.x - orig.x) [16.16]
    mla r2, r14, r2, r9             ; pos.x = orig.x - f * (desired.x - orig.x) [16.16]

    ; Presume no collision detection?
    ; TODO: Would it be faster to plot immediately here? A: Probably.

    ; Save particle state.
    stmia r11!, {r1-r2, r5-r6, r8-r9}       ; note just pos.x, pos.y - no velocity!

    subs r12, r12, #1
    bne particle_grid_tick_all_dave_loop

    ldr pc, [sp], #4

; ============================================================================

; R0=Minksy shift value for rotation.
particle_grid_set_dave_rotation:
    cmp r0, #0
    adreq r1, particle_grid_minsky_no_rotate
    adrgt r1, particle_grid_minsky_rotate_left
    adrlt r1, particle_grid_minsky_rotate_right
    adr r2, particle_grid_tick_all_dave_rotation_code
particle_grid_poke_dave_code:
    ldmia r1!, {r3-r4}
    rsbmi r0, r0, #0
    beq .1                      ; skip for NOP
    bic r3, r3, #0x00000F80     ; mask out bits 7-11
    bic r4, r4, #0x00000F80     ; mask out bits 7-11
    orr r3, r3, r0, lsl #7      ; mask shift value into bits 7-11
    orr r4, r4, r0, lsl #7      ; mask shift value into bits 7-11
    .1:
    stmia r2, {r3-r4}
    mov pc, lr

; R0=Minksy shift value for expansion.
particle_grid_set_dave_expansion:
    cmp r0, #0
    adreq r1, particle_grid_minsky_no_expand
    adrgt r1, particle_grid_minsky_expand
    adrlt r1, particle_grid_minsky_contract
    adr r2, particle_grid_tick_all_dave_expansion_code
    b particle_grid_poke_dave_code

particle_grid_minsky_no_expand:
particle_grid_minsky_no_rotate:
    mov r8, r8
    mov r9, r9

particle_grid_minsky_rotate_left:
    sub r8, r8, r9, asr #ParticleGrid_Minksy_Rotation
    add r9, r9, r8, asr #ParticleGrid_Minksy_Rotation

particle_grid_minsky_rotate_right:
    add r8, r8, r9, asr #ParticleGrid_Minksy_Rotation
    sub r9, r9, r8, asr #ParticleGrid_Minksy_Rotation

particle_grid_minsky_expand:
    add r8, r8, r8, asr #ParticleGrid_Minksy_Expansion
    add r9, r9, r9, asr #ParticleGrid_Minksy_Expansion

particle_grid_minsky_contract:
    sub r8, r8, r8, asr #ParticleGrid_Minksy_Expansion
    sub r9, r9, r9, asr #ParticleGrid_Minksy_Expansion

; ============================================================================

; R12=screen addr
particle_grid_draw_all_as_points:
    str lr, [sp, #-4]!

    mov r7, #15                         ; colour.

    ldr r9, particle_grid_total
    ldr r11, particle_grid_array_p
.1:
    ldmia r11, {r1-r2,r7}

    ; Clamp distance to calculate colour index.
    mov r7, r7, asr #17                 ; ((int) dist) / 2 [0-30] -> [1.15]
    cmp r7, #14
    movgt r7, #14
    add r7, r7, #1

    ; For now just plot 2D particles.
    add r1, r1, #ParticleGrid_CentreX               ; [s15.16]
    rsb r2, r2, #ParticleGrid_CentreY               ; [s15.16]

    mov r1, r1, asr #16
    cmp r1, #0
    blt .3                              ; clip left - TODO: destroy particle?
    cmp r1, #Screen_Width
    bge .3                              ; clip right - TODO: destroy particle?

    mov r2, r2, asr #16
    cmp r2, #0
    blt .3                              ; clip top - TODO: destroy particle?
    cmp r2, #Screen_Height
    bge .3                              ; clip bottom - TODO: destroy particle?

    add r10, r12, r2, lsl #7
    add r10, r10, r2, lsl #5            ; screen_y=screen_addr+y*160

    ldrb r8, [r10, r1, lsr #1]          ; screen_y[screen_x/2]

    ; TODO: If we want individual pixels then MODE 12/13 is faster!
    tst r1, #1
	andeq r8, r8, #0xf0		    ; mask out left hand pixel
	orreq r8, r8, r7			; mask in colour as left hand pixel
	andne r8, r8, #0x0f		    ; mask out right hand pixel
	orrne r8, r8, r7, lsl #4	; mask in colour as right hand pixel

    strb r8, [r10, r1, lsr #1]!         ; screen_y[screen_x]=colour index.

.3:
    add r11, r11, #ParticleGrid_SIZE
    subs r9, r9, #1
    bne .1

    ldr pc, [sp], #4

; ============================================================================

particle_grid_sprite_def_p:
    .long 0

; R12=screen addr
particle_grid_draw_all_as_8x8_tinted:
    str lr, [sp, #-4]!

    ldr r9, particle_grid_total
    ldr r11, particle_grid_array_p
.1:
    ldmia r11, {r1-r2, r14}

    ; Clamp distance to calculate colour index.
    mov r14, r14, asr #17                 ; ((int) dist) / 2 [0-30] -> [1.15]
    cmp r14, #14
    movgt r14, #14
    add r14, r14, #1
    orr r14, r14, r14, lsl #4
    orr r14, r14, r14, lsl #8
    orr r14, r14, r14, lsl #16          ; colour word.

    ; For now just plot 2D particles.
    add r1, r1, #ParticleGrid_CentreX               ; [s15.16]
    rsb r2, r2, #ParticleGrid_CentreY               ; [s15.16]

    mov r1, r1, asr #16
    mov r2, r2, asr #16

    ; Centre sprite.
    sub r1, r1, #4
    sub r2, r2, #4

    ; Clipping.
    cmp r1, #0
    blt .3                              ; cull left
    cmp r1, #Screen_Width-8
    bge .3                              ; cull right

    cmp r2, #0
    blt .3                              ; cull top
    cmp r2, #Screen_Height-8
    bge .3                              ; cull bottom
    ; TODO: Clip to sides of screen..?

    ; Plot as 16x8 sprite.
    ;  r1 = X centre
    ;  r2 = Y centre
    ;  r14 = tint
    and r0, r1, #7                      ; x shift

    ; Calculate screen ptr.
    add r10, r12, r2, lsl #7
    add r10, r10, r2, lsl #5            ; y*160
    mov r1, r1, lsr #3                  ; xw=x div 8
    add r10, r10, r1, lsl #2            ; xw*4

    stmfd sp!, {r9,r11}                 ; TODO: Reg optimisation.

    ; Calculate src ptr.
    ldr r11, particle_grid_sprite_def_p

    ; TODO: More versatile scheme for sprite_num. Radius? Currently (life DIV 32) MOD 7.
    mov r7, #4                              ; sprite_num
    SPRITE_UTILS_GETPTR r11, r7, r0, r11    ; def->table[sprite_num*8+shift]

    ; Plot 2x8 words of tinted mask data to screen.
    ldmia r11!, {r0-r7}                 ; read 8 src words.
    ldmia r10, {r8-r9}                  ; read 2 screen words.
    mask_and_tint_pixels r0, r8, r14
    mask_and_tint_pixels r1, r9, r14
    stmia r10, {r8-r9}                  ; store 2 screen words.
    add r10, r10, #Screen_Stride
    ldmia r10, {r8-r9}                  ; read 2 screen words.
    mask_and_tint_pixels r2, r8, r14
    mask_and_tint_pixels r3, r9, r14
    stmia r10, {r8-r9}                  ; store 2 screen words.
    add r10, r10, #Screen_Stride
    ldmia r10, {r8-r9}                  ; read 2 screen words.
    mask_and_tint_pixels r4, r8, r14
    mask_and_tint_pixels r5, r9, r14
    stmia r10, {r8-r9}                  ; store 2 screen words.
    add r10, r10, #Screen_Stride
    ldmia r10, {r8-r9}                  ; read 2 screen words.
    mask_and_tint_pixels r6, r8, r14
    mask_and_tint_pixels r7, r9, r14
    stmia r10, {r8-r9}                  ; store 2 screen words.
    add r10, r10, #Screen_Stride

    ldmia r11!, {r0-r7}                 ; read 8 src words.
    ldmia r10, {r8-r9}                  ; read 2 screen words.
    mask_and_tint_pixels r0, r8, r14
    mask_and_tint_pixels r1, r9, r14
    stmia r10, {r8-r9}                  ; store 2 screen words.
    add r10, r10, #Screen_Stride
    ldmia r10, {r8-r9}                  ; read 2 screen words.
    mask_and_tint_pixels r2, r8, r14
    mask_and_tint_pixels r3, r9, r14
    stmia r10, {r8-r9}                  ; store 2 screen words.
    add r10, r10, #Screen_Stride
    ldmia r10, {r8-r9}                  ; read 2 screen words.
    mask_and_tint_pixels r4, r8, r14
    mask_and_tint_pixels r5, r9, r14
    stmia r10, {r8-r9}                  ; store 2 screen words.
    add r10, r10, #Screen_Stride
    ldmia r10, {r8-r9}                  ; read 2 screen words.
    mask_and_tint_pixels r6, r8, r14
    mask_and_tint_pixels r7, r9, r14
    stmia r10, {r8-r9}                  ; store 2 screen words.

    ldmfd sp!, {r9,r11}

.3:
    add r11, r11, #ParticleGrid_SIZE
    subs r9, r9, #1
    bne .1

    ldr pc, [sp], #4

; R12=screen addr
particle_grid_draw_all_as_2x2_tinted:
    str lr, [sp, #-4]!

    mov r8, #Screen_Width-1
    ldr r9, particle_grid_total
    ldr r11, particle_grid_array_p
.1:
    ldmia r11, {r1-r2, r14}

    ; Clamp distance to calculate colour index.
    mov r14, r14, asr #17                 ; ((int) dist) / 2 [0-30] -> [1.15]
    cmp r14, #14
    movgt r14, #14
    add r14, r14, #1
    orr r14, r14, r14, lsl #4

    ; For now just plot 2D particles.
    add r1, r1, #ParticleGrid_CentreX               ; [s15.16]
    rsb r2, r2, #ParticleGrid_CentreY               ; [s15.16]

    mov r1, r1, asr #16
    mov r2, r2, asr #16

    ; Clipping.
    cmp r1, #0
    blt .3                              ; cull left
    cmp r1, r8  ;#Screen_Width-1
    bge .3                              ; cull right

    cmp r2, #0
    blt .3                              ; cull top
    cmp r2, #Screen_Height-1
    bge .3                              ; cull bottom
    ; TODO: Clip to sides of screen..?

    ;  r1 = X centre
    ;  r2 = Y centre
    ;  r14 = tint

    ; Calculate screen ptr.
    add r10, r12, r2, lsl #7
    add r10, r10, r2, lsl #5            ; y*160
    add r10, r10, r1, lsr #1

    and r0, r1, #7                      ; x shift
    tst r0, #1

    ; [0, 2, 4, 6]
    streqb r14, [r10]                   ;
    streqb r14, [r10, #Screen_Stride]   ;
    beq .3

    ; [1, 3, 5, 7]
    cmp r0, #7
    bne .4

    ; [7] - worst case!
    ldrb r3, [r10]
    bic r3, r3, #0xf0
    orr r3, r3, r14, lsl #4
    strb r3, [r10]
    ldrb r3, [r10, #Screen_Stride]
    bic r3, r3, #0xf0
    orr r3, r3, r14, lsl #4
    strb r3, [r10, #Screen_Stride]
    ldrb r3, [r10, #1]
    bic r3, r3, #0x0f
    orr r3, r3, r14, lsr #4
    strb r3, [r10, #1]
    ldrb r3, [r10, #Screen_Stride+1]
    bic r3, r3, #0x0f
    orr r3, r3, r14, lsr #4
    strb r3, [r10, #Screen_Stride+1]
    b .3

.4:
    ; [1, 3, 5]
    bic r10, r10, #3                ; word
    mov r0, r0, lsl #2              ; shift*4
    mov r4, #0xff
    ldr r3, [r10]
    bic r3, r3, r4, lsl r0
    orr r3, r3, r14, lsl r0
    str r3, [r10]
    ldr r3, [r10, #Screen_Stride]
    bic r3, r3, r4, lsl r0
    orr r3, r3, r14, lsl r0
    str r3, [r10, #Screen_Stride]

.3:
    add r11, r11, #ParticleGrid_SIZE
    subs r9, r9, #1
    bne .1

    ldr pc, [sp], #4

; ============================================================================
