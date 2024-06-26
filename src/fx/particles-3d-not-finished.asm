; ============================================================================
; Particle system.
; Not used, and not finished!!
; ============================================================================

; Particle variables block (VECTOR3):
.equ Particle_Next,     0       ; R0 = pointer to next active/free.
.equ Particle_XPos,     4       ; R1
.equ Particle_YPos,     8       ; R2
.equ Particle_ZPos,     12      ; R3
.equ Particle_XVel,     16      ; R4
.equ Particle_YVel,     20      ; R5
.equ Particle_ZVel,     24      ; R6
.equ Particle_Life,     28      ; R7
.equ Particle_Colour,   30      ; R7
.equ Particle_Radius,   31      ; R7
.equ Particle_SIZE,     32

.equ Particles_Max,     680     ; ARM2 ~= 680. ARM250 ~= 1024.
.equ Particle_Gravity, -5.0     ; Or some sort of particle force fn.
                                ; TODO: Drive with math_func?

.equ Particles_CentreX,          (160.0 * MATHS_CONST_1)
.equ Particles_CentreY,          (255.0 * MATHS_CONST_1)

.equ _PARTICLES_PLOT_CHUNKY,    0  ; only works in MODE 12/13.
.equ _PARTICLES_ASSERT_SPAWN,   (_DEBUG && 0)

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

particle_gravity:
    FLOAT_TO_FP (Particle_Gravity / 50.0)     ; (pixels/frame not pixels/sec)

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
    str r10, [r12, #0]                  ; last particle has zero pointer.
    ldr pc, [sp], #4


particles_tick_all:
    str lr, [sp, #-4]!
    adr r12, particles_first_active     ; R12=current_p
    ldr r0, [r12, #0]                   ; R0=next_p

    ldr r9, particle_gravity

.1:
    mov r11, r12                        ; r11 = prev_p = current_p
    movs r12, r0                        ; current_p = next_p
    beq .2

    ldmia r12, {r0-r7}                  ; load particle context

    ; Particle lifetime.
    sub r7, r7, #1
    movs r10, r7, asl #16

    ; If lifetime<0 then add this context to free list.
    adrmi lr, .1
    bmi particle_destroy

    ; Particle dynamics.

    ; vel += acceleration
    add r5, r5, r9

    ; pos += vel
    add r1, r1, r4
    add r2, r2, r5
    add r3, r3, r6

    ; TODO: Collision detection.
    cmp r1, #160<<16
    rsbge r4, r4, #0
    cmp r1, #-160<<16
    rsble r4, r4, #0

    ; If y<0 then destroy.
    cmp r2, #0
    adrmi lr, .1
    bmi particle_destroy

    ; TODO: Update particle colour.

    ; Save particle state.
    stmia r12, {r0-r7}

    ; TODO: Calculate screen (x,y) whilst context is loaded.

    b .1

.2:
    ldr pc, [sp], #4

; Params:
;  R0 =next particle_p
;  R12=current particle_p
;  R11=prev particle_p
particle_destroy:
    ; Remove the current particle from the active list.
    str r0,  [r11, #0]                  ; prev->next = current->next

    ; Insert this particle at the front of the free list.
    ldr r10, particles_next_free        ; next free particle_p
    str r10, [r12, #0]                  ; curr->next = next_free_p
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
    beq .2

    ; TODO: Don't need to load the full context.
    ldmia r11, {r0-r7}                  ; load particle context

    ; TODO: Plot 3D.

    ; For now just plot 2D particles.
    add r1, r1, #Particles_CentreX               ; [s15.16]
    rsb r2, r2, #Particles_CentreY               ; [s15.16]

    mov r1, r1, lsr #16
    cmp r1, #0
    blt .3                              ; clip left - TODO: destroy particle?
    cmp r1, #Screen_Width
    bge .3                              ; clip right - TODO: destroy particle?

    mov r2, r2, lsr #16
    cmp r2, #0
    blt .3                              ; clip top - TODO: destroy particle?
    cmp r2, #Screen_Height
    bge .3                              ; clip bottom - TODO: destroy particle?

    ; TODO: If eroniously replace R2 with R1 above then Arculator exists without warning!
    ;       Debug this for Sarah and test on Arculator v2.2.

    add r10, r12, r2, lsl #7
    add r10, r10, r2, lsl #5            ; screen_y=screen_addr+y*160
    mov r7, r7, lsr #16                 ; colour is upper 16 bits.

    ldrb r8, [r10, r1, lsr #1]          ; screen_y[screen_x/2]

    ; TODO: If we want individual pixels then MODE 12/13 is faster!
    tst r1, #1
	andeq r8, r8, #0xf0		    ; mask out left hand pixel
	orreq r8, r8, r7			; mask in colour as left hand pixel
	andne r8, r8, #0x0f		    ; mask out right hand pixel
	orrne r8, r8, r7, lsl #4	; mask in colour as right hand pixel

    strb r8, [r10, r1, lsr #1]!         ; screen_y[screen_x]=colour index.

    .if _PARTICLES_PLOT_CHUNKY
    strb r7, [r10, #1]                  ; screen_y[screen_x+1]=colour index.
    strb r7, [r10, #Screen_Stride]      ; (screen_y+1)[screen_x]=colour index.
    strb r7, [r10, #Screen_Stride+1]    ; (screen_y+1)[screen_x+1]=colour index.
    .endif

.3:
    b .1

.2:
    ldr pc, [sp], #4


; R12=screen addr
particles_draw_all_as_circles:
    str lr, [sp, #-4]!

    adr r11, particles_first_active     ; curr_p
    ldr r11, [r11]                      ; next_p
.1:
    cmp r11, #0
    beq .2

    ; TODO: Don't need to load the full context.
    ldmia r11, {r0-r7}                  ; load particle context
    mov r11, r0                         ; curr_p=next_p

    ; TODO: Plot 3D.

    ; For now just plot 2D particles.
    add r1, r1, #Particles_CentreX               ; [s15.16]
    rsb r2, r2, #Particles_CentreY               ; [s15.16]

    mov r1, r1, asr #16
    mov r2, r2, asr #16

    .if 0
    cmp r1, #0
    blt .3                              ; clip left - TODO: destroy particle?
    cmp r1, #Screen_Width
    bge .3                              ; clip right - TODO: destroy particle?

    cmp r2, #0
    blt .3                              ; clip top - TODO: destroy particle?
    cmp r2, #Screen_Height-1            ; WHY -1?
    bge .3                              ; clip bottom - TODO: destroy particle?
    .endif

    ;  r0 = X centre
    ;  r1 = Y centre
    ;  r2 = radius of circle
    ;  r9 = tint
    mov r0, r1
    mov r1, r2
    mov r2, r7, lsr #24                 ; radius.
    mov r9, r7, lsr #16                 ; colour.
    bic r9, r9, #0xff00
    bl circles_add_to_plot_by_Y

.3:
    b .1

.2:
    ldr pc, [sp], #4


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

    ; TODO: Don't need to load the full context. Reorder vars?
    ldmia r11, {r0-r7}                  ; load particle context
    str r0, particles_draw_next_p       ; next_p

    ; TODO: Plot 3D.

    ; For now just plot 2D particles.
    add r1, r1, #Particles_CentreX               ; [s15.16]
    rsb r2, r2, #Particles_CentreY               ; [s15.16]

    mov r1, r1, lsr #16
    mov r2, r2, lsr #16

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
    mov r14, r7, lsr #16                ; colour tint.
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

    ; TODO: More versatile scheme for sprite_num. Radius?
    mov r7, r7, lsr #4
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

    ; TODO: Don't need to load the full context. Reorder vars?
    ldmia r11, {r0-r7}                  ; load particle context
    str r0, particles_draw_next_p       ; next_p

    ; TODO: Plot 3D.

    ; For now just plot 2D particles.
    add r1, r1, #Particles_CentreX               ; [s15.16]
    rsb r2, r2, #Particles_CentreY               ; [s15.16]

    mov r1, r1, lsr #16
    mov r2, r2, lsr #16

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

; ============================================================================

; Spawn a particle.
;  R1=x position, R2=y position, R3=z position
;  R4=x velocity, R5=y velocity, R6=z velocity
;  R7=lifetime | colour index
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
    stmia r9, {r0-r7}
    str r9, particles_first_active

    str r8, particles_next_free

    .if _DEBUG
    ldr r8, particles_alive_count
    add r8, r8, #1
    str r8, particles_alive_count
    .endif

    mov pc, lr

; ============================================================================

.if _DEBUG
emiterror: ;The error block
.long 18
.byte "Out of particles!"
.align 4
.long 0
.endif

; ============================================================================
