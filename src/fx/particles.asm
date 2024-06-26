; ============================================================================
; Particle system.
; 2D particles only.
; Not used, although inspired Push.
; ============================================================================

.equ _PARTICLES_MINIMAL_CODE,   _SMALL_EXE

; Particle variables block:
.equ Particle_Next,             0       ; R0 = pointer to next active/free.
.equ Particle_XPos,             4       ; R1
.equ Particle_YPos,             8       ; R2
.equ Particle_Life,             12      ; R3
.equ Particle_Colour,           14      ; R3
.equ Particle_Radius,           15      ; R3
.equ Particle_XVel,             16      ; R4
.equ Particle_YVel,             20      ; R5
.equ Particle_SIZE,             24

.equ Particles_Max,             680     ; ARM2 ~= 680. ARM250 ~= 1024.
.equ Particles_DefaultG,        -2.0

.equ Particles_CentreX,         (160.0 * MATHS_CONST_1)
.equ Particles_CentreY,         (128.0 * MATHS_CONST_1)

.equ Particles_CollideLeft,     (-160.0 * MATHS_CONST_1)
.equ Particles_CollideRight,    (160.0 * MATHS_CONST_1)
.equ Particles_CollideTop,      (128.0 * MATHS_CONST_1)
.equ Particles_CollideBottom,   (-128.0 * MATHS_CONST_1)

.equ _PARTICLES_ASSERT_SPAWN,   (_DEBUG && 0)
.equ _PARTICLES_ADD_DRAG,       1

.if !_PARTICLES_MINIMAL_CODE

; ============================================================================

; Ptr to the particle array in bss.
particles_array_p:
    .long particles_array_no_adr

; Forward linked list of free particles.
; First word of particle context points to the next free particle.
particles_next_free:
    .long 0

; Forward linked list of active particles.
; First word of particle context points to the next active particle.
particles_first_active:
    .long 0

.if _DEBUG
particles_alive_count:
    .long 0
.endif

; ============================================================================

; Initialise all particles in the free list.
particles_init:
    str lr, [sp, #-4]!
    DEBUG_REGISTER_VAR particles_alive_count    ; TODO: Make this not a bl call!

    ldr r12, particles_array_p

    ; Start with first free particle as particles_array[0].
    str r12, particles_next_free

    mov r11, #Particles_Max-1
.1:
    add r10, r12, #Particle_SIZE
    str r10, [r12], #Particle_SIZE      ; first word is pointer to next particle.
    subs r11, r11, #1
    bne .1

    mov r10, #0
    str r10, [r12, #Particle_Next]      ; last particle has zero pointer.
    str r10, particles_first_active     ; no particles active!
    .if _DEBUG
    str r10, particles_alive_count
    .endif

    ldr pc, [sp], #4


particles_tick_all_under_gravity:
; FALL THROUGH!
particles_tick_all_under_constant_force:
    str lr, [sp, #-4]!

    ; R8 = acceleration.x
    ; R9 = acceleration.y
    ldr r8, particles_constant_force+0   ; acc.x
    ldr r9, particles_constant_force+4   ; acc.y

    adr r12, particles_first_active     ; R12=current_p
    ldr r0, [r12, #Particle_Next]       ; R0=next_p

.1:
    mov r11, r12                        ; r11 = prev_p = current_p
    movs r12, r0                        ; current_p = next_p
    beq .2

    ldmia r12, {r0-r5}                  ; load full particle context

    ; Particle lifetime.
    sub r3, r3, #1
    movs r10, r3, asl #16

    ; If lifetime<0 then add this context to free list.
    adrmi lr, .1
    bmi particle_destroy

    ; Particle dynamics.

    ; TODO: Make the particle dynamics a function call to remove duplicated code?
    ;       How much of an overhead is the bl per particle vs the maths involved?

.if _PARTICLES_ADD_DRAG
    ; Apply drag to acceleration. F = -kv
    ldr r8, particles_constant_force+0   ; acc.x
    ldr r9, particles_constant_force+4   ; acc.y
    ; TOOD: Can't this just be sub r4, r4, r4, asr #9 etc.?
    sub r8, r8, r4, asr #9               ; k = 1/512
    sub r9, r9, r5, asr #9
.endif

    ; vel += acceleration
    add r4, r4, r8
    add r5, r5, r9

    ; pos += vel
    add r1, r1, r4
    add r2, r2, r5

    ; TODO: Make collision detection less hardcoded?
    cmp r4, #0
    cmpge r1, #Particles_CollideRight    ; only check rhs if particle is moving right.
    rsbge r4, r4, #0

    cmp r4, #0
    cmple r1, #Particles_CollideLeft     ; only check lhs if particle is moving left.
    rsble r4, r4, #0

    ; If y>512 then destroy.
    cmp r5, #0
    cmpgt r2, #Particles_CollideTop      ; only check top if particle is moving upwards.
    adrgt lr, .1
    bgt particle_destroy

    ; If y<0 then destroy.
    cmp r5, #0
    cmplt r2, #Particles_CollideBottom   ; only check bottom of screen if particle is moving downwards.
    adrlt lr, .1
    blt particle_destroy

    ; TODO: Update particle colour?

    ; Save particle state.
    stmia r12, {r0-r5}

    b .1

.2:
    ldr pc, [sp], #4

; TODO: Add rsqrt table?
particles_sqrt_p:
    .long sqrt_table_no_adr

particles_recip_p:
    .long reciprocal_table_no_adr


.equ Particles_CircleCollider_XPos,     0.0
.equ Particles_CircleCollider_YPos,     128.0
.equ Particles_CircleCollider_Radius,   32

particles_collider_radius:
    .long 0

; R6=object.x
; R7=object.y
; R10=object.radius
particles_tick_all_with_circle_collider:
    str lr, [sp, #-4]!

    mov r10, #Particles_CircleCollider_Radius*MATHS_CONST_1

    .if !_DEBUG
    mov r6, #Particles_CircleCollider_XPos*MATHS_CONST_1
    mov r7, #Particles_CircleCollider_YPos*MATHS_CONST_1
    .else
    swi OS_Mouse
    mov r6, r0, asl #14
    mov r7, r1, asl #14                  ; [16.16] pixel coords.
    sub r6, r6, #Particles_CentreX

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
    .endif

    str r10, particles_collider_radius
    mov r10, r10, asr #8                ; [8.8]
    mov r14, r10                        ; [8.8]
    mul r10, r14, r10                   ; [16.16]
    mov r10, r10, asr #18               ; sqradius/4 [14.0]

    adr r12, particles_first_active     ; R12=current_p
    ldr r0, [r12, #Particle_Next]       ; R0=next_p

.1:
    mov r11, r12                        ; r11 = prev_p = current_p
    movs r12, r0                        ; current_p = next_p
    beq .2

    ldmia r12, {r0-r3}                  ; load full particle context

    ; Particle lifetime.
    sub r3, r3, #1
    movs r14, r3, asl #16

    ; If lifetime<0 then add this context to free list.
    adrmi lr, .1
    bmi particle_destroy

    ; Particle dynamics.

    ; Compute distance to object.
    sub r8, r1, r6                      ; dx = pos.x - obj.x
    sub r9, r2, r7                      ; dy = pox.y - obj.y

    ; Calcluate dist^2=dx*dx + dy*dy

    mov r4, r8, asr #10             ; [10.6]
    mov r14, r4
    mul r4, r14, r4                 ; dx*dx [20.12]

    mov r5, r9, asr #10
    mov r14, r5
    mul r5, r14, r5                 ; dy*dy [20.12]

    add r5, r4, r5                  ; distsq=dx*dx + dy*dy [20.12]
    mov r5, r5, asr #14             ; distsq/4             [16.0]

    ; Test for collision against object radius.
    cmp r5, r10                     ; distsq/4 > sqradius/4?
    movgt r8, #0
    movgt r9, #0                    ; no object force applied.
    bgt .3

    ; Calculate dist=sqrt(dx*dx + dy*dy)

    ; SQRT table goes from [1, 512*512) = [0x00001, 0x40000) (18 bits)
    ; Contains 65536 = 0x10000 entries                       (16 bits)
    ; Values are in 16.16 format.

    .if _DEBUG
    ; Limited precision.
    cmp r5, #LibSqrt_Entries    ; Test for numerator too large
    adrge r0,sqrtrange           ; and flag an error
    swige OS_GenerateError      ; when necessary
    .endif

    subs r5, r5, #1
    movmi r14, #MATHS_CONST_1       ; should be 0 but avoid div by 0.
    ldrpl r4, particles_sqrt_p
    ldrpl r14, [r4, r5, lsl #2]     ; sqrt(distsq / 4) [16.16]

    ; Calculate push value = radius - dist.
    ldr r5, particles_collider_radius
    sub r5, r5, r14

    ; Calculate 1/dist.
    ldr r4, particles_recip_p

    ; Put divisor in table range.
    mov r14, r14, asr #16-LibDivide_Reciprocal_s    ; [16.6]    (b<<s)

    .if _DEBUG
    cmp r14, #0
    adrle r0,divbyzero          ; and flag an error
    swile OS_GenerateError      ; when necessary

    ; Limited precision.
    cmp r14, #1<<LibDivide_Reciprocal_t    ; Test for numerator too large
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

     ; Calculate displacement.
    mov r5, r5, asr #8              ; push = (radius-dist)
    mov r8, r8, asr #8
    mul r8, r5, r8                  ; dx*push
    mov r9, r9, asr #8
    mul r9, r5, r9                  ; dy*push

    ; This code implements crude collision against a circle.
    ; Not strictly correct, as it does not do any contact points
    ; or calculate reflected normals etc.

    ; Add a push force away from the centre of the circle.
    ; The larger this force the 'bouncier' the particles are.
    mov r8, r8, asr #6
    mov r9, r9, asr #6              ; push * 0.0625 (1/16)

    ; Subtract a drag force to stop the particle penetrating the circle.
    ; The larger this force the 'stickier' the circle is.
    ldr r4, [r12, #Particle_XVel]
    ldr r5, [r12, #Particle_YVel]
    sub r8, r8, r4, asr #3          ; acc -= -vel/8
    sub r9, r9, r5, asr #3

    ; NB. You'll probably want to tune the two factors above together to
    ;     achieve the desired effect.

.3:
    ldr r4, [r12, #Particle_XVel]
    ldr r5, [r12, #Particle_YVel]

    ; [R8,R9] = force from object

    ldr r14, particles_gravity
    add r9, r9, r14                ; acc.y += gravity

    ; vel += acceleration (is in units per frame so *50)
    add r4, r4, r8
    add r5, r5, r9

    ; pos += vel          (is in pixels per frame so *50)
    add r1, r1, r4
    add r2, r2, r5

    ; TODO: Make collision detection less hardcoded?
    cmp r4, #0
    cmpge r1, #Particles_CollideRight      ; only check rhs if particle is moving right.
    rsbge r4, r4, #0

    cmp r4, #0
    cmple r1, #Particles_CollideLeft       ; only check lhs if particle is moving left.
    rsble r4, r4, #0

    ; If y>512 then destroy.
    cmp r5, #0
    cmpgt r2, #Particles_CollideTop        ; only check top if particle is moving upwards.
    adrgt lr, .1
    bgt particle_destroy

    ; If y<0 then destroy.
    cmp r5, #0
    cmplt r2, #Particles_CollideBottom     ; only check bottom of screen if particle is moving downwards.
    adrlt lr, .1
    blt particle_destroy

    ; TODO: Update particle colour?

    ; Save particle state.
    stmia r12, {r0-r5}
    b .1

.2:
    ldr pc, [sp], #4


; R6=attractor.x
; R7=attractor.y
; R10=attractor.mass
particles_tick_all_with_attractor:
    str lr, [sp, #-4]!

    mov r10, #Particles_CircleCollider_Radius*MATHS_CONST_1

    .if !_DEBUG
    mov r6, #Particles_CircleCollider_XPos*MATHS_CONST_1
    mov r7, #Particles_CircleCollider_YPos*MATHS_CONST_1
    .else
    swi OS_Mouse
    mov r6, r0, asl #14
    mov r7, r1, asl #14                  ; [16.16] pixel coords.
    sub r6, r6, #Particles_CentreX

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
    .endif

    str r10, particles_collider_radius
    mov r10, r10, asr #8                ; [8.8]
    mov r14, r10                        ; [8.8]
    mul r10, r14, r10                   ; [16.16]
    mov r10, r10, asr #18               ; sqradius/4 [14.0]

    adr r12, particles_first_active     ; R12=current_p
    ldr r0, [r12, #Particle_Next]       ; R0=next_p

.1:
    mov r11, r12                        ; r11 = prev_p = current_p
    movs r12, r0                        ; current_p = next_p
    beq .2

    ldmia r12, {r0-r3}                  ; load full particle context

    ; Particle lifetime.
    sub r3, r3, #1
    movs r14, r3, asl #16

    ; If lifetime<0 then add this context to free list.
    adrmi lr, .1
    bmi particle_destroy

    ; Particle dynamics.

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

    .if _DEBUG
    ; Limited precision.
    cmp r5, #LibSqrt_Entries    ; Test for numerator too large
    adrge r0,sqrtrange           ; and flag an error
    swige OS_GenerateError      ; when necessary
    .endif

    subs r5, r5, #1
    movmi r14, #MATHS_CONST_1       ; should be 0 but avoid div by 0.
    ldrpl r4, particles_sqrt_p
    ldrpl r14, [r4, r5, lsl #2]     ; dist=sqrt4(distsq) [16.16]

    ; Calculate 1/dist.
    ldr r4, particles_recip_p

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
    bge .3

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
    mov r5, r14, asl #5                     ; push=M/distsq where M=4<<5=128 [7.23]

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

.3:
    ldr r4, [r12, #Particle_XVel]
    ldr r5, [r12, #Particle_YVel]

    ; [R8,R9] = force from object

    ldr r14, particles_gravity
    add r9, r9, r14                ; acc.y += gravity

    ; vel += acceleration (is in units per frame so *50)
    add r4, r4, r8
    add r5, r5, r9

    ; pos += vel          (is in pixels per frame so *50)
    add r1, r1, r4
    add r2, r2, r5

    ; TODO: Make collision detection less hardcoded?
    cmp r4, #0
    cmpge r1, #Particles_CollideRight      ; only check rhs if particle is moving right.
    rsbge r4, r4, #0

    cmp r4, #0
    cmple r1, #Particles_CollideLeft       ; only check lhs if particle is moving left.
    rsble r4, r4, #0

    ; If y>512 then destroy.
    cmp r5, #0
    cmpgt r2, #Particles_CollideTop        ; only check top if particle is moving upwards.
    adrgt lr, .1
    bgt particle_destroy

    ; If y<0 then destroy.
    cmp r5, #0
    cmplt r2, #Particles_CollideBottom     ; only check bottom of screen if particle is moving downwards.
    adrlt lr, .1
    blt particle_destroy

    ; TODO: Update particle colour?

    ; Save particle state.
    stmia r12, {r0-r5}
    b .1

.2:
    ldr pc, [sp], #4


; Params:
;  R0 =next particle_p
;  R12=current particle_p
;  R11=prev particle_p
particle_destroy:
    ; Remove the current particle from the active list.
    str r0,  [r11, #Particle_Next]      ; prev->next = current->next

    ; Insert this particle at the front of the free list.
    ldr r1, particles_next_free         ; next free particle_p
    str r1, [r12, #Particle_Next]       ; curr->next = next_free_p
    str r12, particles_next_free        ; next_free_p = curr

    mov r12, r11                        ; step back to previous particle

    .if _DEBUG
    ; Safe to use R11 here as it will be immediately set to R12 curr=next.
    ldr r11, particles_alive_count
    sub r11, r11, #1
    str r11, particles_alive_count
    .endif

    mov pc, lr

; ============================================================================

; R12=screen addr
particles_draw_all_as_points:
    str lr, [sp, #-4]!

    adr r11, particles_first_active     ; curr_p
    ldr r0, [r11, #0]                   ; next_p
.1:
    movs r11, r0                        ; curr=next
    ldreq pc, [sp], #4

    ldmia r11, {r0-r3}                  ; load particle context for draw

    ; For now just plot 2D particles.
    add r1, r1, #Particles_CentreX               ; [s15.16]
    rsb r2, r2, #Particles_CentreY               ; [s15.16]

    mov r1, r1, asr #16
    cmp r1, #0
    blt .1                              ; clip left - TODO: destroy particle?
    cmp r1, #Screen_Width
    bge .1                              ; clip right - TODO: destroy particle?

    mov r2, r2, asr #16
    cmp r2, #0
    blt .1                              ; clip top - TODO: destroy particle?
    cmp r2, #Screen_Height
    bge .1                              ; clip bottom - TODO: destroy particle?

    ; TODO: If eroniously replace R2 with R1 above then Arculator exists without warning!
    ;       Debug this for Sarah and test on Arculator v2.2.

    add r10, r12, r2, lsl #7
    add r10, r10, r2, lsl #5            ; screen_y=screen_addr+y*160
    mov r7, r3, lsr #16                 ; colour is upper 16 bits.

    ldrb r8, [r10, r1, lsr #1]          ; screen_y[screen_x/2]

    ; TODO: If we want individual pixels then MODE 12/13 is faster!
    tst r1, #1
	andeq r8, r8, #0xf0		    ; mask out left hand pixel
	orreq r8, r8, r7			; mask in colour as left hand pixel
	andne r8, r8, #0x0f		    ; mask out right hand pixel
	orrne r8, r8, r7, lsl #4	; mask in colour as right hand pixel

    strb r8, [r10, r1, lsr #1]!         ; screen_y[screen_x]=colour index.
    b .1


; R12=screen addr
particles_draw_all_as_2x2:
    str lr, [sp, #-4]!

    mov r8, #Screen_Width-1             ; const

    adr r11, particles_first_active     ; curr_p
    ldr r0, [r11, #0]                   ; next_p
.1:
    movs r11, r0                        ; curr=next
    ldreq pc, [sp], #4                  ; return

    ldmia r11, {r0-r3}                  ; load particle context for draw

    ; For now just plot 2D particles.
    add r1, r1, #Particles_CentreX               ; [s15.16]
    rsb r2, r2, #Particles_CentreY               ; [s15.16]

    mov r1, r1, asr #16
    mov r2, r2, asr #16

    cmp r1, #0
    blt .1                              ; clip left
    cmp r1, r8  ;#Screen_Width-1
    bge .1                              ; clip right

    cmp r2, #0
    blt .1                              ; clip top
    cmp r2, #Screen_Height-1
    bge .1                              ; clip bottom

    ; Get tint.
    mov r14, r3, lsr #16                ; colour is upper 16 bits.
    and r14, r14, #0xf
    orr r14, r14, r14, lsl #4

    ; Calculate screen ptr to the byte.
    add r10, r12, r2, lsl #7
    add r10, r10, r2, lsl #5            ; y*160
    add r10, r10, r1, lsr #1

    ; Odd or even?
    tst r1, #1
    beq .5

    ; [1, 3, 5, 7]
    and r4, r1, #7                  ; x shift
    cmp r4, #7
    bne .4

    ; [7] => worst case! 2x2 across 2 words.
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
    b .1

.4:
    ; [1, 3, 5] => 2x2 in same word.
    mov r4, r4, lsl #2              ; shift*4
    bic r10, r10, #3                ; word

    ldr r3, [r10]
    bic r3, r3, r4, lsl r4
    orr r3, r3, r14, lsl r4
    str r3, [r10]
    ldr r3, [r10, #Screen_Stride]
    bic r3, r3, r4, lsl r4
    orr r3, r3, r14, lsl r4
    str r3, [r10, #Screen_Stride]
    b .1

.5:
    ; [0, 2, 4, 6] => best case! 2x2 in same byte.
    strb r14, [r10]                   ; 4c
    strb r14, [r10, #Screen_Stride]   ; 4c
    b .1


; R12=screen addr
particles_draw_all_as_circles:
    str lr, [sp, #-4]!

    adr r11, particles_first_active     ; curr_p
    ldr r11, [r11]                      ; next_p
.1:
    cmp r11, #0
    beq .2

    ldmia r11, {r0-r3}                  ; load particle context for draw
    mov r11, r0                         ; curr_p=next_p

    ; For now just plot 2D particles.
    add r1, r1, #Particles_CentreX               ; [s15.16]
    rsb r2, r2, #Particles_CentreY               ; [s15.16]

    ; NB. Clipping done in circle routine.

    ;  r0 = X centre
    ;  r1 = Y centre
    ;  r2 = radius of circle
    ;  r9 = tint
    mov r0, r1, asr #16
    mov r1, r2, asr #16
    mov r2, r3, lsr #24                 ; radius.
    mov r9, r3, lsr #16                 ; colour.
    bic r9, r9, #0xff00
    bl circles_add_to_plot_by_order

.3:
    b .1

.2:
    ldr pc, [sp], #4

.if 0
particles_draw_next_p:
    .long 0

particles_sprite_table_p:
    .long 0

particles_sprite_def_p:
    .long 0

.macro mask_and_tint_pixels src, dst, tint
    bic \dst, \dst, \src                ; mask out src.
    and \src, \src, \tint               ; add tint to src.
    orr \dst, \dst, \src                ; mask into dst.
.endm


; R12=screen addr
particles_draw_all_as_8x8_tinted:
    str lr, [sp, #-4]!

    adr r11, particles_first_active     ; curr_p
    ldr r11, [r11]                      ; next_p
.1:
    cmp r11, #0
    beq .2

    ldmia r11, {r0-r3}                  ; load particle context for draw
    str r0, particles_draw_next_p       ; next_p

    ; For now just plot 2D particles.
    add r1, r1, #Particles_CentreX               ; [s15.16]
    rsb r2, r2, #Particles_CentreY               ; [s15.16]

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
    mov r14, r3, lsr #16                ; colour tint.
    bic r14, r14, #0xff00
    orr r14, r14, r14, lsl #4
    orr r14, r14, r14, lsl #8
    orr r14, r14, r14, lsl #16          ; colour word.

    and r0, r1, #7                      ; x shift

    ; Calculate screen ptr.
    add r10, r12, r2, lsl #7
    add r10, r10, r2, lsl #5            ; y*160
    mov r1, r1, lsr #3                  ; xw=x div 8
    add r10, r10, r1, lsl #2            ; xw*4

    ; Calculate src ptr.
    ldr r11, particles_sprite_def_p

    ; TODO: More versatile scheme for sprite_num. Radius? Currently (life DIV 32) MOD 7.
    mov r7, r3, lsr #5                      ; max lifetime=512
    and r7, r7, #7                          ; sprite_num~=f(life)
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

.3:
    ldr r11, particles_draw_next_p
    b .1

.2:
    ldr pc, [sp], #4


.macro additive_blend src, dst, tmp
; With or without max nibble clamping.
.if 1
    mvn \dst, \dst                      ; invert bits.
    tst \dst, #0x0000000f               ; test dst nibble bits.
    biceq \src, \src, #0x0000000f       ; exclude src nibble bits if dst nibble==0.
    tst \dst, #0x000000f0
    biceq \src, \src, #0x000000f0
    tst \dst, #0x00000f00
    biceq \src, \src, #0x00000f00
    tst \dst, #0x0000f000
    biceq \src, \src, #0x0000f000
    tst \dst, #0x000f0000
    biceq \src, \src, #0x000f0000
    tst \dst, #0x00f00000
    biceq \src, \src, #0x00f00000
    tst \dst, #0x0f000000
    biceq \src, \src, #0x0f000000
    tst \dst, #0xf0000000
    biceq \src, \src, #0xf0000000
    sub \dst, \dst, \src                ; subtract src nibbles.
    mvn \dst, \dst                      ; invert bits (make additive).
    ; TODO: Might be possible to do in fewer cycles with whole word twiddling.
.else
    add \dst, \dst, \src                ; don't worry about nibble overflow.
.endif
.endm

; R12=screen addr
particles_draw_all_as_8x8_additive:
    str lr, [sp, #-4]!

    adr r11, particles_first_active     ; curr_p
    ldr r11, [r11]                      ; next_p
.1:
    cmp r11, #0
    beq .2

    ldmia r11, {r0-r2}                  ; load particle context for draw
    str r0, particles_draw_next_p       ; next_p

    ; For now just plot 2D particles.
    add r1, r1, #Particles_CentreX               ; [s15.16]
    rsb r2, r2, #Particles_CentreY               ; [s15.16]

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
    ; Radius is ignored.
    ; Tint is ignored.

    and r0, r1, #7                      ; x shift

    ; Calculate screen ptr.
    add r10, r12, r2, lsl #7
    add r10, r10, r2, lsl #5            ; y*160
    mov r1, r1, lsr #3                  ; xw=x div 8
    add r10, r10, r1, lsl #2            ; xw*4

    ; Calculate src ptr.
    ldr r11, particles_sprite_table_p
    ldr r11, [r11, r0, lsl #2]          ; ptr[x_shift]
    ; TODO: Convert particle sprite index into sprite table ptr.

    ; Plot 2x8 words of additive sprite data (mask orr 0x11111111) to screen.
    ldmia r11!, {r0-r7}                 ; read 8 src words.
    ldmia r10, {r8-r9}                  ; read 2 screen words.
    additive_blend r0, r8, r14
    additive_blend r1, r9, r14
    stmia r10, {r8-r9}                  ; store 2 screen words.
    add r10, r10, #Screen_Stride

    ldmia r10, {r8-r9}                  ; read 2 screen words.
    additive_blend r2, r8, r14
    additive_blend r3, r9, r14
    stmia r10, {r8-r9}                  ; store 2 screen words.
    add r10, r10, #Screen_Stride

    ldmia r10, {r8-r9}                  ; read 2 screen words.
    additive_blend r4, r8, r14
    additive_blend r5, r9, r14
    stmia r10, {r8-r9}                  ; store 2 screen words.
    add r10, r10, #Screen_Stride

    ldmia r10, {r8-r9}                  ; read 2 screen words.
    additive_blend r6, r8, r14
    additive_blend r7, r9, r14
    stmia r10, {r8-r9}                  ; store 2 screen words.
    add r10, r10, #Screen_Stride

    ldmia r11!, {r0-r7}                 ; read 8 src words.
    ldmia r10, {r8-r9}                  ; read 2 screen words.
    additive_blend r0, r8, r14
    additive_blend r1, r9, r14
    stmia r10, {r8-r9}                  ; store 2 screen words.
    add r10, r10, #Screen_Stride

    ldmia r10, {r8-r9}                  ; read 2 screen words.
    additive_blend r2, r8, r14
    additive_blend r3, r9, r14
    stmia r10, {r8-r9}                  ; store 2 screen words.
    add r10, r10, #Screen_Stride

    ldmia r10, {r8-r9}                  ; read 2 screen words.
    additive_blend r4, r8, r14
    additive_blend r5, r9, r14
    stmia r10, {r8-r9}                  ; store 2 screen words.
    add r10, r10, #Screen_Stride

    ldmia r10, {r8-r9}                  ; read 2 screen words.
    additive_blend r6, r8, r14
    additive_blend r7, r9, r14
    stmia r10, {r8-r9}                  ; store 2 screen words.

.3:
    ldr r11, particles_draw_next_p
    b .1

.2:
    ldr pc, [sp], #4
.endif

; ============================================================================

; Spawn a particle.
;  R1=x position, R2=y position
;  R3=lifetime | colour index
;  R4=x velocity, R5=y velocity
; Returns:
;  R0=next active particle.
;  R8=alive count.
;  R9=ptr to particle.
particle_spawn:
    ldr r9, particles_next_free    ; particle_p

    ; Emit particles.
    cmp r9, #0
    .if _PARTICLES_ASSERT_SPAWN
    adreq r0, emiterror
    swieq OS_GenerateError
    .else
    moveq pc, lr                   ; ran out of particle space!
    .endif

    ldr r8, [r9, #Particle_Next]   ; curr_p->next_p

    ; Insert this particle at the front of the active list.
    ldr r0, particles_first_active
    stmia r9, {r0-r5}
    str r9, particles_first_active

    str r8, particles_next_free

    .if _DEBUG
    ldr r8, particles_alive_count
    add r8, r8, #1
    str r8, particles_alive_count
    .endif

    mov pc, lr

.endif ; _PARTICLE_MINIMAL_CODE

; ============================================================================

.if _DEBUG
emiterror: ;The error block
.long 18
.byte "Out of particles!"
.align 4
.long 0
.endif

; ============================================================================
; Script helpers.
; ============================================================================

; R0=force x
; R1=force y
particles_set_constant_force:
    str r0, particles_constant_force + 0
    str r1, particles_constant_force + 4
    mov pc, lr

.if 0   ; REPLACED BY PARTICLE_DAVE...
; R0=0 always reset positions, otherwise just origin (morph)
particles_transfer_to_grid:
    movs r10, r0
    ldrne r10, particle_grid_total      ; morph?
    mov r9, #0                          ; count
    ldr r12, particle_grid_array_p

    mov r3, #0
    mov r4, #0                          ; vel

    adr r11, particles_first_active     ; curr_p
    ldr r0, [r11, #0]                   ; next_p
.1:
    movs r11, r0                        ; curr=next
    beq .2

    ldmia r11, {r0-r2}                  ; load particle context

    subs r10, r10, #1
    addpl r12, r12, #16
    stmmiia r12!, {r1-r4}   ; pos, vel
    stmia r12!, {r1-r2}     ; origin

    add r9, r9, #1
    b .1

.2:
    str r9, particle_grid_total
    mov pc, lr
.endif

; ============================================================================

particles_constant_force:
    FLOAT_TO_FP 0.0                             ; f.x
; Fall through!
particles_gravity:    
    FLOAT_TO_FP (Particles_DefaultG / 50.0)       ; f.y (pixels/frame not pixels/sec) 

; ============================================================================
