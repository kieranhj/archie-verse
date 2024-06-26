; ============================================================================
; Particle system.
; Free particles but adhering to Dave's dynamics equation.
; 2D particles only.
; Used in: Push.
; ============================================================================

.equ _PARTICLE_DAVE_FULL_EDGE_CLIP, 0

.equ ParticleDave_Next,     0       ; R0 = pointer to next active/free.
.equ ParticleDave_XPos,     4       ; R1
.equ ParticleDave_YPos,     8       ; R2
.equ ParticleDave_XVel,     12      ; R4
.equ ParticleDave_YVel,     16      ; R5
.equ ParticleDave_XOrigin,  20      ; R5
.equ ParticleDave_YOrigin,  24      ; R6
.equ ParticleDave_Dist,     28      ; R3
.equ ParticleDave_SIZE,     32

.equ ParticleDave_Max,      500

.equ ParticleDave_CentreX,         (160.0 * MATHS_CONST_1)
.equ ParticleDave_CentreY,         (128.0 * MATHS_CONST_1)

.equ ParticleDave_CollideLeft,     (-160.0 * MATHS_CONST_1)
.equ ParticleDave_CollideRight,    (160.0 * MATHS_CONST_1)
.equ ParticleDave_CollideTop,      (128.0 * MATHS_CONST_1)
.equ ParticleDave_CollideBottom,   (-128.0 * MATHS_CONST_1)

; ============================================================================

; Ptr to the particle array in bss.
particle_dave_array_p:
    .long particle_dave_array_no_adr

; Forward linked list of free particles.
; First word of particle context points to the next free particle.
particle_dave_next_free:
    .long 0

; Forward linked list of active particles.
; First word of particle context points to the next active particle.
particle_dave_first_active:
    .long 0

.if _DEBUG
particle_dave_alive_count:
    .long 0
.endif

particle_dave_constant_force:
    FLOAT_TO_FP 0.0                             ; f.x
; Fall through!
particle_dave_gravity:    
    FLOAT_TO_FP (Particles_DefaultG / 50.0)       ; f.y (pixels/frame not pixels/sec) 

; ============================================================================

; Initialise all particles in the free list.
particle_dave_init:
    str lr, [sp, #-4]!
    DEBUG_REGISTER_VAR particle_dave_alive_count    ; TODO: Make this not a bl call!

    ldr r12, particle_dave_array_p

    ; Start with first free particle as particles_array[0].
    str r12, particle_dave_next_free

    mov r11, #ParticleDave_Max-1
.1:
    add r10, r12, #ParticleDave_SIZE
    str r10, [r12], #ParticleDave_SIZE      ; first word is pointer to next particle.
    subs r11, r11, #1
    bne .1

    mov r10, #0
    str r10, [r12, #ParticleDave_Next]      ; last particle has zero pointer.
    str r10, particle_dave_first_active     ; none active!!
    .if _DEBUG
    str r10, particle_dave_alive_count
    .endif

    ldr pc, [sp], #4

; ============================================================================

particle_dave_tick_all:
    str lr, [sp, #-4]!

    ; R0=sqrt_table
    ; R1=pos.x
    ; R2=pos.y
    ; R3=spare?
    ; R4=temp_x
    ; R5=temp_y
    ; R6=object.x
    ; R7=object.y
    ; R8=delta_x
    ; R9=delta_y
    ; R10=object.radius
    ; R11=current_p
    ; R12=prev_p
    ; R14=temp / clamp_dist
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

    ; R12=ptr to prev particle.
    ; R11=ptr to current particle.
    adr r11, particle_dave_first_active     ; R11=current_p
particle_dave_tick_all_loop:
    mov r12, r11                        ; r12 = prev_p = current_p
    ldr r11, [r11, #ParticleDave_Next]  ; current_p = prev_p->next
    cmp r11, #0                         ; current_p==0?
    ldreq pc, [sp], #4                  ; return

    ; Particle dynamics as per Dave's Blender graph.

    ldr r1, [r11, #ParticleDave_XPos]   ; pos.x, pos.y
    ldr r2, [r11, #ParticleDave_YPos]

    ; Compute delta_vec to object.
    subs r8, r6, r1                      ; dx = obj.x - pos.x

    ; Early out if abs(dx) > radius or abs(dy) > radius.
    rsbmi r4, r8, #0
    movpl r4, r8                        ; abs(dx)
    cmp r4, r10                         ; abs(dx)>radius?
    bgt particle_dave_tick_all_clamp_zero                              ; clamp_dist=0.0

    subs r9, r7, r2                      ; dy = obj.y - pos.y

    rsbmi r4, r9, #0
    movpl r4, r9                        ; abs(dy)
    cmp r4, r10                         ; abs(dy)>radius?
    bgt particle_dave_tick_all_clamp_zero                              ; clamp_dist=0.0

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
    .if _DEBUG
    cmp r5, #LibSqrt_Entries    ; Test for numerator too large
    adrge r0,sqrtrange           ; and flag an error
    swige OS_GenerateError      ; when necessary
    bge particle_dave_tick_all_clamp_zero
    .endif

    subs r5, r5, #1
    movmi r14, #MATHS_CONST_1       ; should be 0 but avoid div by 0.
    ldrpl r14, [r0, r5, lsl #2]     ; dist=sqrt4(distsq) [16.16]

    ; Clamp dist. [0.0, radius] => [-max_push, 0.0]

    ; if dist > radius, cd = 0.0
    cmp r14, r10                    ; dist > radius?
    bge particle_dave_tick_all_clamp_zero                          ; clamp_dist = 0.0

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

    ; NB. Skip this bit if clamp_dist == 0.0

    ; Calculate offset vec = delta_vec * clamp_dist
    mov r14, r14, asr #8            ; clamp_dist [8.8]
    mov r8, r8, asr #8              ; dx [~9.8]
    mov r9, r9, asr #8              ; dy [~9.8]

    ; Calculate desired position = current_pos + offset_vec.

    mla r1, r14, r8, r1             ; desired.x = pos.x + off.x [16.16]
    mla r2, r14, r9, r2             ; desired.y = pos.y + off.y [16.16]

particle_dave_tick_all_clamp_zero:

    ; Original position.
    ldr r8, [r11, #ParticleDave_XOrigin]    ; orig.x
    ldr r9, [r11, #ParticleDave_YOrigin]    ; orig.y

    ; Calculate offset vec = desired position - original position:
    sub r1, r1, r8                  ; desired.x - orig.x
    sub r2, r2, r9                  ; desired.y - orig.y

    ; Calculate the length of this vector for colour!

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
    cmp r5, #LibSqrt_Entries    ; Test for numerator too large
    movgt r5, #LibSqrt_Entries  ; This can happen with fast moving particles.
    .if _DEBUG && 0
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

    str r5, [r11, #ParticleDave_Dist]

    ; Load particle context. TODO: Make this ldmia again.

particle_dave_tick_all_velocity_load:    
    ldr r4, [r11, #ParticleDave_XVel]
    ldr r5, [r11, #ParticleDave_YVel]

    ; Particle dynamics.

.if _PARTICLES_ADD_DRAG
    ; Apply drag to acceleration. F = -kv
    sub r4, r4, r4, asr #9               ; k = 1/512
    sub r5, r5, r5, asr #9
.endif

    ; vel += acceleration
    ldr r3, particles_constant_force+0   ; acc.x
    add r4, r4, r3
    ldr r3, particles_constant_force+4   ; acc.y
    add r5, r5, r3

    ; pos += vel
    add r8, r8, r4
    add r9, r9, r5

    ; Lerp between desired and original position (along offset vec).

    ; TODO: factor might be const?
    ldr r3, particle_grid_gloop_factor       ; factor [1.16]
    mov r14, r3, asr #8             ; factor [1.8]
    mov r1, r1, asr #8              ; [~9.8]
    mov r2, r2, asr #8              ; [~9.8]

    mla r1, r14, r1, r8             ; pos.x = orig.x - f * (desired.x - orig.x) [16.16]
    mla r2, r14, r2, r9             ; pos.x = orig.x - f * (desired.x - orig.x) [16.16]

    adr lr, particle_dave_tick_all_loop

    ; TODO: Make collision detection less hardcoded?
    cmp r4, #0
    cmpgt r1, #ParticleDave_CollideRight    ; only check rhs if particle is moving right.
    bgt particle_dave_destroy             ; loads R0.

    cmp r4, #0
    cmplt r1, #ParticleDave_CollideLeft     ; only check lhs if particle is moving left.
    blt particle_dave_destroy             ; loads R0.

    ; If y>512 then destroy.
    cmp r5, #0
    cmpgt r2, #ParticleDave_CollideTop      ; only check top if particle is moving upwards.
    bgt particle_dave_destroy             ; loads R0.

    ; If y<0 then destroy.
    cmp r5, #0
    cmplt r2, #ParticleDave_CollideBottom   ; only check bottom of screen if particle is moving downwards.
    blt particle_dave_destroy             ; loads R0.

    ; Save particle state.
    add r11, r11, #ParticleDave_XPos        ; step over next ptr.
    stmia r11, {r1-r2, r4-r5, r8-r9}
    sub r11, r11, #ParticleDave_XPos

    b particle_dave_tick_all_loop

; ============================================================================

; Destroy a particle and remove from active list.
; Params
;  R11=current particle_p
;  R12=prev particle_p
; Trashes: R1.
particle_dave_destroy:
    ; Remove the current particle from the active list.
    ldr r1, [r11, #ParticleDave_Next]       ; current->next
    str r1, [r12, #ParticleDave_Next]       ; prev->next = current->next

    ; Insert this particle at the front of the free list.
    ldr r1, particle_dave_next_free         ; next free particle_p
    str r1, [r11, #ParticleDave_Next]       ; curr->next = next_free_p
    str r11, particle_dave_next_free        ; next_free_p = curr

    mov r11, r12                        ; step back to previous particle

    .if _DEBUG
    ; Safe to use R11 here as it will be immediately set to R12 curr=next.
    ldr r1, particle_dave_alive_count
    sub r1, r1, #1
    str r1, particle_dave_alive_count
    .endif

    mov pc, lr

; ============================================================================

; Spawn a particle.
;  R1=x position, R2=y position
;  R3=<ignored>
;  R4=x velocity, R5=y velocity
; Returns:
;  R0=next active particle.
;  R8=alive count.
;  R9=ptr to particle.
particle_dave_spawn:
    ldr r9, particle_dave_next_free    ; particle_p

    ; Emit particles.
    cmp r9, #0
    .if _PARTICLES_ASSERT_SPAWN
    adreq r0, emiterror
    swieq OS_GenerateError
    .else
    moveq pc, lr                   ; ran out of particle space!
    .endif

    ldr r8, [r9, #ParticleDave_Next]   ; curr_p->next_p

    mov r3, r4
    mov r4, r5

    ; Insert this particle at the front of the active list.
    ldr r0, particle_dave_first_active
    stmia r9, {r0-r4}
    str r1, [r9, #ParticleDave_XOrigin]
    str r2, [r9, #ParticleDave_YOrigin]
    str r9, particle_dave_first_active

    str r8, particle_dave_next_free

    .if _DEBUG
    ldr r8, particle_dave_alive_count
    add r8, r8, #1
    str r8, particle_dave_alive_count
    .endif

    mov pc, lr

; ============================================================================

; R12=screen addr
particle_dave_draw_all_as_2x2:
    str lr, [sp, #-4]!

;    bl particle_dave_draw_origin_as_points ; DEBUG!

    mov r4, #0xff                       ; const
    mov r8, #Screen_Width-1             ; const

    adr r11, particle_dave_first_active     ; curr_p
    ldr r0, [r11, #ParticleDave_Next]       ; next_p
.1:
    movs r11, r0                        ; curr=next
    ldreq pc, [sp], #4                  ; return

    ldmia r11, {r0-r2}                  ; load particle context for draw
    ldr r14, [r11, #ParticleDave_Dist]

    ; Clamp distance to calculate colour index.
    mov r14, r14, asr #17                 ; ((int) dist) / 2 [0-30] -> [1.15]
    cmp r14, #13
    movgt r14, #13
    add r14, r14, #1
    orr r14, r14, r14, lsl #4

    ; For now just plot 2D particles.
    add r1, r1, #ParticleDave_CentreX               ; [s15.16]
    rsb r2, r2, #ParticleDave_CentreY               ; [s15.16]

    mov r1, r1, asr #16
    mov r2, r2, asr #16

    .if _PARTICLE_DAVE_FULL_EDGE_CLIP
    cmp r1, #-1
    blt .1                              ; cull left
    beq .6                              ; full clip to edge
    cmp r1, r8                          ; #Screen_Width-1
    bgt .1                              ; cull right
    beq .6                              ; full clip to edge

    cmp r2, #Screen_Height-1
    bgt .1                              ; cull bottom
    beq .7                              ; full clip to edge
    cmp r2, #-1
    blt .1                              ; cull top
    beq .7                              ; full clip to edge
    .else
    cmp r1, #-1
    ble .1                              ; cull left
    cmp r1, r8                          ; #Screen_Width-1
    bge .1                              ; cull right

    cmp r2, #Screen_Height-1
    bge .1                              ; cull bottom
    cmp r2, #-1
    ble .1                              ; cull top
    .endif

    ; Calculate screen ptr to the byte.
    add r10, r12, r2, lsl #7
    add r10, r10, r2, lsl #5            ; y*160
    add r10, r10, r1, lsr #1

    ; Odd or even?
    tst r1, #1
    beq .5

    ; [1, 3, 5, 7]
    and r5, r1, #7                  ; x shift
    cmp r5, #7
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
    mov r5, r5, lsl #2              ; shift*4
    bic r10, r10, #3                ; word

    ldr r3, [r10]
    bic r3, r3, r4, lsl r5
    orr r3, r3, r14, lsl r5
    str r3, [r10]
    ldr r3, [r10, #Screen_Stride]
    bic r3, r3, r4, lsl r5
    orr r3, r3, r14, lsl r5
    str r3, [r10, #Screen_Stride]
    b .1

.5:
    ; [0, 2, 4, 6] => best case! 2x2 in same byte.
    strb r14, [r10]                   ; 4c
    strb r14, [r10, #Screen_Stride]   ; 4c
    b .1

.if _PARTICLE_DAVE_FULL_EDGE_CLIP
    ; Full clipping to screen edges.
.6:
    ; We know that at least one of these is true!
    ; X=-1 or X=319 but Y is not yet checked.
    cmp r2, #Screen_Height-1
    bgt .1                              ; cull bottom
    cmp r2, #-1
    blt .1                              ; cull top

.7:
    ; We know that Y>=-1 and Y<=255.

    ; Calculate screen ptr to the first line.
    add r10, r12, r2, lsl #7
    add r10, r10, r2, lsl #5            ; y*160

    ; Do we need the first line?
    cmp r2, #-1
    beq .9                              ; skip first line.

    ; Do we need the first pixel?
    cmp r1, #-1
    beq .8                              ; skip first pixel.

    ; First line, first pixel.
    ldrb r3, [r10, r1, lsr #1]
    tst r1, #1
    biceq r3, r3, #0x0f
    orreq r3, r3, r14, lsr #4
    bicne r3, r3, #0xf0
    orrne r3, r3, r14, lsl #4
    strb r3, [r10, r1, lsr #1]

    ; Do we need second pixel?
    cmp r1, r8                          ; #Screen_Width-1
    beq .9

.8:
    ; First line, second pixel.
    add r1, r1, #1

    ldrb r3, [r10, r1, lsr #1]
    tst r1, #1
    biceq r3, r3, #0x0f
    orreq r3, r3, r14, lsr #4
    bicne r3, r3, #0xf0
    orrne r3, r3, r14, lsl #4
    strb r3, [r10, r1, lsr #1]

    sub r1, r1, #1

    ; Do we need the second line?
    cmp r2, #Screen_Height-1
    beq .1

.9:
    ; Move to second line.
    add r10, r10, #Screen_Stride

    cmp r1, #-1
    beq .10                              ; skip first pixel.

    ; Second line, first pixel.
    ldrb r3, [r10, r1, lsr #1]
    tst r1, #1
    biceq r3, r3, #0x0f
    orreq r3, r3, r14, lsr #4
    bicne r3, r3, #0xf0
    orrne r3, r3, r14, lsl #4
    strb r3, [r10, r1, lsr #1]

    ; Do we need second pixel?
    cmp r1, r8                          ; #Screen_Width-1
    beq .1

.10:
    ; Second line, second pixel.
    add r1, r1, #1

    ldrb r3, [r10, r1, lsr #1]
    tst r1, #1
    biceq r3, r3, #0x0f
    orreq r3, r3, r14, lsr #4
    bicne r3, r3, #0xf0
    orrne r3, r3, r14, lsl #4
    strb r3, [r10, r1, lsr #1]

    b .1
.endif

.if _DEBUG
particle_dave_draw_origin_as_points:
    str lr, [sp, #-4]!

    mov r4, #0xff                       ; const
    mov r8, #Screen_Width-1             ; const

    adr r11, particle_dave_first_active     ; curr_p
    ldr r0, [r11, #ParticleDave_Next]       ; next_p
.1:
    movs r11, r0                        ; curr=next
    ldreq pc, [sp], #4                  ; return

    ; Load particle context for draw.
    ldr r0, [r11, #ParticleDave_Next]
    ldr r1, [r11, #ParticleDave_XOrigin]
    ldr r2, [r11, #ParticleDave_YOrigin]

    ; Fixed colour for debug.
    mov r14, #0xf

    ; For now just plot 2D particles.
    add r1, r1, #ParticleDave_CentreX               ; [s15.16]
    rsb r2, r2, #ParticleDave_CentreY               ; [s15.16]

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

    ; Calculate screen ptr to the byte.
    add r10, r12, r2, lsl #7
    add r10, r10, r2, lsl #5            ; y*160

    ldrb r8, [r10, r1, lsr #1]          ; screen_y[screen_x/2]

    ; TODO: If we want individual pixels then MODE 12/13 is faster!
    tst r1, #1
	andeq r8, r8, #0xf0		    ; mask out left hand pixel
	orreq r8, r8, r14			; mask in colour as left hand pixel
	andne r8, r8, #0x0f		    ; mask out right hand pixel
	orrne r8, r8, r14, lsl #4	; mask in colour as right hand pixel

    strb r8, [r10, r1, lsr #1]!         ; screen_y[screen_x]=colour index.
    b .1
.endif

; ============================================================================
