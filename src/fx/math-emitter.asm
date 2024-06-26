; ============================================================================
; Math emitter.
; A particle emitter described by some simple maths functions.
; Used in: Push.
; ============================================================================

; Math Emitter context block:
; Describes the parameters of the next particle to be emitted.
.equ MathEmitter_Rate,   0       ; R0  0=not active.
.equ MathEmitter_XPos,   4       ; R1
.equ MathEmitter_YPos,   8       ; R2
.equ MathEmitter_Life,   12      ; R3
.equ MathEmitter_XDir,   16      ; R4  Q: would this be better as angles? (in brads?)
.equ MathEmitter_YDir,   20      ; R5
.equ MathEmitter_Colour, 24      ; R6
.equ MathEmitter_Radius, 28      ; R7
.equ MathEmitter_Timer,  32      ; counts up until next particle to be emitted.
.equ MathEmitter_Iter,   36      ; i(iteration)
.equ MathEmitter_SIZE,   40

; TODO: Decide when emitter iteration happens.
.equ _MATH_EMITTER_ITERATE_PER_FRAME, 0     ; otherwise per spawn.

; ============================================================================

math_emitter_p:
    .long math_emitter_config_3

math_emitter_spawn_fn:
    .long particle_dave_spawn

; ============================================================================

math_emitter_init:
    str lr, [sp, #-4]!

	; Seed RND.
	;swi OS_ReadMonotonicTime
	;str r0, rnd_seed

    SYNC_REGISTER_VAR 0, math_emitter_context_1+0
    SYNC_REGISTER_VAR 1, math_emitter_context_1+4
    SYNC_REGISTER_VAR 2, math_emitter_context_1+8
    SYNC_REGISTER_VAR 3, math_emitter_context_1+12
    SYNC_REGISTER_VAR 4, math_emitter_context_1+16
    SYNC_REGISTER_VAR 5, math_emitter_context_1+20
    SYNC_REGISTER_VAR 6, math_emitter_context_1+24
    SYNC_REGISTER_VAR 7, math_emitter_context_1+28
    SYNC_REGISTER_VAR 8, math_emitter_context_1+32
    SYNC_REGISTER_VAR 9, math_emitter_context_1+36
    ldr pc, [sp], #4

math_emitter_tick_all:
    str lr, [sp, #-4]!

    ; TODO: Support multiple emitters?
    adr r12, math_emitter_context_1
    ldr r10, math_emitter_p
    cmp r10, #0
    blne math_emitter_tick

    ldr pc, [sp], #4

; R10=ptr to emitter config.
; R12=ptr to emitter context.
math_emitter_tick:
    str lr, [sp, #-4]!

    .if _MATH_EMITTER_ITERATE_PER_FRAME
    bl math_emitter_iterate         ; iterate emitter.
    .endif

    ; Update time between particle emissions.
    ldr r11, [r12, #MathEmitter_Timer]
    subs r11, r11, #MATHS_CONST_1    ; timer-=1.0 (frame)
    bgt .2

    .if _MATH_EMITTER_ITERATE_PER_FRAME==0
    .3:
    bl math_emitter_iterate         ; iterate emitter.
    .endif

    ldmia r12, {r0-r7}              ; load emitter context.

    .if _MATH_EMITTER_ITERATE_PER_FRAME
    mov r10, r0                     ; junk config ptr.
    .endif

    mov r7, r7, asr #16             ; radius [16.0]
    orr r3, r3, r6, lsl #16         ; combine lifetime & colour into one word.
    orr r3, r3, r7, lsl #24         ; & radius.

    .if _MATH_EMITTER_ITERATE_PER_FRAME
    .3:
    adds r11, r11, r10              ; timer += frames between emissions.
    .else
    adds r11, r11, r0               ; timer += frames between emissions.
    .endif

    ; Call the spawn fn!
    adr lr, .1
    ldr pc, math_emitter_spawn_fn   ; trashes r0,r8-r9
    .1:

    ; Check the emissions timer - might have > 1 particle per frame!
    cmp r11, #0
    ble .3

.2:
    str r11, [r12, #MathEmitter_Timer]
    ldr pc, [sp], #4

; R10=ptr to emitter config.
; R12=ptr to emitter context.
; Trashes R0-R5,R7-R9
math_emitter_iterate:
    str lr, [sp, #-4]!

    .if AppConfig_UseSyncTracks==0
    mov r7, r10 ; stash config ptr.

    ; TODO: Some funcs might want to be f(time) not f(i).
    ldr r8, [r12, #MathEmitter_Iter]
    add r8, r8, #1
    str r8, [r12, #MathEmitter_Iter]

    ; R10=emitter.rate
    mov r0, r8
    bl math_evaluate_func
    str r0, [r12, #MathEmitter_Rate]

    ; R10=emitter.pos.x
    mov r0, r8
    bl math_evaluate_func
    str r0, [r12, #MathEmitter_XPos]

    ; R10=emitter.pos.y
    mov r0, r8
    bl math_evaluate_func
    str r0, [r12, #MathEmitter_YPos]

    ; R10=emitter.dir.x
    mov r0, r8
    bl math_evaluate_func
    str r0, [r12, #MathEmitter_XDir]

    ; R10=emitter.dir.y
    mov r0, r8
    bl math_evaluate_func
    str r0, [r12, #MathEmitter_YDir]

    ; R10=emitter.life
    mov r0, r8
    bl math_evaluate_func
    mov r0, r0, lsr #16             ; [16.0]
    str r0, [r12, #MathEmitter_Life]

    ; R10=emitter.colour
    mov r0, r8
    bl math_evaluate_func
    mov r0, r0, lsr #16             ; [16.0]
    str r0, [r12, #MathEmitter_Colour]

    ; R10=emitter.radius
    mov r0, r8
    bl math_evaluate_func
    str r0, [r12, #MathEmitter_Radius]

    mov r10, r7     ; restore config ptr.
    .endif

    ldr pc, [sp], #4

; ============================================================================

math_emitter_context_1:
    .skip MathEmitter_SIZE

; ============================================================================
