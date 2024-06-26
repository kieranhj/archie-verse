; ============================================================================
; Balls (inspired/ripped from Marble Merger on PICO-8): 
; https://www.lexaloffle.com/bbs/?tid=54837
; Not used yet!
; ============================================================================

.equ Ball_Next,     0       ; R0 = pointer to next active/free.
.equ Ball_x,        4       ; R1
.equ Ball_y,        8       ; R2
.equ Ball_vx,       12      ; R3
.equ Ball_vy,       16      ; R4
.equ Ball_ix,       20      ; R5
.equ Ball_iy,       24      ; R6
.equ Ball_radius,   28      ; R7
.equ Ball_colour,   30      ; R7
.equ Ball_ymax,     32      ; R8
.equ Ball_SIZE,     36

.equ Balls_Max,     30      ; ?
.equ Ball_Gravity,  5.0     ; ? 

.equ Balls_CentreX,     (0.0 * MATHS_CONST_1)
.equ Balls_CentreY,     (0.0 * MATHS_CONST_1)

.equ Balls_BoardWidth,  (320 * MATHS_CONST_1)
.equ Balls_BoardHeight, (256 * MATHS_CONST_1)

.equ Balls_HaveRadiusAsMass,  1     ; otherwise all balls have the same mass.
.equ Balls_ResolveAgainstAll, 0     ; slower and more jittery.

; ============================================================================

; Ptr to the balls array in bss.
balls_array_p:
    .long balls_array_no_adr

; Forward linked list of free balls.
; First word of ball context points to the next free ball.
balls_next_free:
    .long 0

; Forward linked list of active balls.
; First word of ball context points to the next active ball.
balls_first_active:
    .long 0

balls_alive_count:
    .long 0

ball_gravity:
    FLOAT_TO_FP (Ball_Gravity / 50.0)     ; (pixels/frame not pixels/sec)

; ============================================================================

; Initialise all balls in the free list.
balls_init:
    str lr, [sp, #-4]!

    DEBUG_REGISTER_VAR balls_debug_pos      ; TODO: Make this not a bl call!
    DEBUG_REGISTER_VAR balls_alive_count    ; TODO: Make this not a bl call!

    DEBUG_REGISTER_KEY RMKey_Z, balls_debug_cursor, -4
    DEBUG_REGISTER_KEY RMKey_X, balls_debug_cursor,  4
    DEBUG_REGISTER_KEY RMKey_1, balls_debug_drop,    1
    DEBUG_REGISTER_KEY RMKey_2, balls_debug_drop,    2
    DEBUG_REGISTER_KEY RMKey_3, balls_debug_drop,    3
    DEBUG_REGISTER_KEY RMKey_4, balls_debug_drop,    4
    DEBUG_REGISTER_KEY RMKey_5, balls_debug_drop,    5
    DEBUG_REGISTER_KEY RMKey_6, balls_debug_drop,    6
    DEBUG_REGISTER_KEY RMKey_7, balls_debug_drop,    7
    DEBUG_REGISTER_KEY RMKey_8, balls_debug_drop,    8
    DEBUG_REGISTER_KEY RMKey_9, balls_debug_drop,    9

    ldr r12, balls_array_p

    ; Start with first free ball as balls_array[0].
    str r12, balls_next_free

    mov r11, #Balls_Max-1
.1:
    add r10, r12, #Ball_SIZE
    str r10, [r12], #Ball_SIZE      ; first word is pointer to next ball.
    subs r11, r11, #1
    bne .1

    mov r10, #0
    str r10, [r12, #0]              ; last ball has zero pointer.
    str r10, balls_first_active     ; no balls active.
    str r10, balls_alive_count

    ldr pc, [sp], #4


balls_tick_all:
    str lr, [sp, #-4]!

    bl balls_move_all
    ; Sort balls by y (descending i.e. bottom to top).
    bl balls_sort
    bl balls_resolve_collisions

    ldr pc, [sp], #4


balls_move_all:
    str lr, [sp, #-4]!

    ldr r9, ball_gravity

    adr r12, balls_first_active         ; R12=current_p
    ldr r0, [r12, #Ball_Next]           ; R0=next_p
.1:
    mov r11, r12                        ; r11 = prev_p = current_p
    movs r12, r0                        ; current_p = next_p
    beq .2

    ldmia r12, {r0-r4}                  ; load ball context
    ; R0=next
    ; R1=x
    ; R2=y
    ; R3=vx
    ; R4=vy
    ; R5=ix
    ; R6=iy
    ; R7=radius + colour
    ; R8=ymax
    ldr r7, [r12, #Ball_radius]
    ;mov r9, r7, lsr #16                 ; colour
    mov r7, r7, lsl #16                 ; radius [16.16]

    ; Ball dynamics.

    ; vel += acceleration
    add r4, r4, r9

    ; pos += vel
    add r1, r1, r3
    add r2, r2, r4

    ; Collide with edges.

    ; if ball.y+ball.radius>boardheight then
    add r10, r2, r7
    cmp r10, #Balls_BoardHeight
    blt .3

    rsb r2, r7, #Balls_BoardHeight
    movs r4, r4, asr #1
    mvnpl r4, r4

.3:
    ; if ball.x<ball.radius then
    cmp r1, r7
    bgt .4

    mov r1, r7
    movs r3, r3, asr #1
    rsbmi r3, r3, #0

.4:
    ; if ball.x+ball.radius>boardwidth then
    add r10, r1, r7
    cmp r10, #Balls_BoardWidth
    blt .5

    rsb r1, r7, #Balls_BoardWidth
    movs r3, r3, asr #1
    rsbpl r3, r3, #0

.5:
    ; Destroy balls that escape too high!
    cmp r2, #-Balls_BoardHeight
    bgt .6
    
    bl ball_destroy
    b .1

.6:
    ; Zero ix, iy.
    mov r5, #0
    mov r6, #0

    ; Save ball state w/out radius/colour.
    stmia r12, {r0-r6}

    ; Calculate ymax.
    add r8, r2, r7                  ; ymax=y+radius    
    str r8, [r12, #Ball_ymax]

    b .1

.2:
    ldr pc, [sp], #4

; Params:
;  R0 =next ball_p
;  R12=current ball_p
;  R11=prev ball_p
ball_destroy:
    ; Remove the current ball from the active list.
    str r0,  [r11, #0]                  ; prev->next = current->next

    ; Insert this ball at the front of the free list.
    ldr r10, balls_next_free            ; next free ball_p
    str r10, [r12, #0]                  ; curr->next = next_free_p
    str r12, balls_next_free            ; next_free_p = curr

    mov r12, r11                        ; step back to previous ball

    ; Safe to use R11 here as it will be immediately set to R12 curr=next.
    ldr r11, balls_alive_count
    sub r11, r11, #1
    str r11, balls_alive_count

    mov pc, lr

; ============================================================================

balls_sort:
    ; Bubble sort FTW!
    ldr r9, balls_alive_count
    mov r0, #0                      ; i
.1:
    cmp r0, r9                      ; i >= count
    bge .4

    adr r10, balls_first_active     ; h (prev)
    mov r3, #0                      ; swapped

    sub r2, r9, r0                  ; count-i
    sub r2, r2, #1                  ; count-i-i
    mov r1, #0                      ; j
.2:
    cmp r1, r2
    bge .3

    ldr r11, [r10, #Ball_Next]      ; p1=*h (prev->next)
    ldr r12, [r11, #Ball_Next]      ; p2=p1->next

    ldr r8, [r11, #Ball_ymax]       ; p1->ymax
    ldr r7, [r12, #Ball_ymax]       ; p2->ymax

    cmp r8, r7                      ; p1->ymax > p2->ymax?
    bge .5

    ; Swap p1 & p2.
    ldr r6, [r12, #Ball_Next]       ; tmp=p2->next
    str r11, [r12, #Ball_Next]      ; p2->next=p1
    str r6, [r11, #Ball_Next]       ; p1->next=tmp
    str r12, [r10, #Ball_Next]      ; *h=p2 (prev->next=p2)

    add r3, r3, #1                  ; swapped++

.5:
    ldr r10, [r10, #Ball_Next]      ; h=&(*h)->next (prev=prev->next)
    add r1, r1, #1                  ; j++
    b .2

.3:
    cmp r3, #0
    beq .4

    add r0, r0, #1                  ; i++
    b .1

.4:
    mov pc, lr


balls_sqrt_p:
    .long sqrt_table_no_adr

balls_recip_p:
    .long reciprocal_table_no_adr

balls_resolve_collisions:
    str lr, [sp, #-4]!

    ldr r11, balls_first_active
.1:
    cmp r11, #0
    beq .2

    ; Load ball context.
    ldr r0, [r11, #Ball_x]          ; ball.x
    ldr r1, [r11, #Ball_y]          ; ball.y

    ldr r14, [r11, #Ball_radius]    ; TODO: Remove repeated LDR below?
    mov r14, r14, lsl #16           ; ball.radius [16.16]
    rsb r14, r1, r14                ; ymin=ball.y-ball.radius

    .if Balls_ResolveAgainstAll
    ldr r12, balls_first_active
    .else
    ; Go through all other balls above us.
    ldr r12, [r11, #Ball_Next]      ; other=ball->next
    .endif
.3:
    cmp r12, #0
    beq .4

    .if Balls_ResolveAgainstAll
    cmp r11, r12                    ; don't test against self!
    beq .5
    .endif

    ldr r8, [r12, #Ball_ymax]       ; other.ymax
    cmp r8, r14                     ; other.ymax < ymin?
    .if Balls_ResolveAgainstAll
    blt .5                          ; assume no collision.
    .else
    blt .4                          ; terminate early as all remaining balls are above our miny.
    .endif

    ; Load other context.
    ldr r4, [r12, #Ball_x]          ; other.x
    ldr r5, [r12, #Ball_y]          ; other.y

    ; Calc distance.
    sub r8, r0, r4                  ; dx=ball.x-other.x
    sub r9, r1, r5                  ; dy=ball.y-other.y

    ; Calculate dist=sqrt(dx*dx + dy*dy)

    mov r6, r8, asr #10             ; [10.6]
    mov r10, r6
    mul r6, r10, r6                 ; dx*dx [20.12]

    mov r7, r9, asr #10
    mov r10, r7
    mul r7, r10, r7                 ; dy*dy [20.12]

    add r7, r6, r7                  ; distsq=dx*dx + dy*dy [20.12]
    mov r7, r7, asr #16             ; distsq/4             [16.0]
    ; TODO: ERROR    ^^ SHOULD BE #14 so distsq/4  TEST THIS!!

    ; SQRT table goes from [1, 512*512) = [0x00001, 0x40000) (18 bits)
    ; Contains 65536 = 0x10000 entries                       (16 bits)
    ; Values are in 16.16 format.

    subs r7, r7, #1
    movmi r10, #MATHS_CONST_1       ; should be 0 but avoid div by 0.
    ldrpl r3, balls_sqrt_p
    ldrpl r10, [r3, r7, lsl #2]     ; sqrt(distsq / 4) [16.16]

    mov r10, r10, asl #1            ; dist=2*sqrt(distsq / 4)
    ; TODO: ERROR    ^^ can just remove this line  TEST THIS!!

    ; Calc combined distance.
    ldr r7, [r11, #Ball_radius]
    mov r7, r7, lsl #16             ; ball.radius [16.16]
    ldr r6, [r12, #Ball_radius]
    add r6, r7, r6, lsl #16         ; ball.radius+other.radius

    ; If dist<ball.radius+other.radius then balls touching ;)
    cmp r10, r6
    bge .5

    ; Collision!
    sub r2, r6, r10                 ; push=ball.radius+other.radius-dist
    cmp r2, r7                      ; push > ball.radius?
    movgt r2, r7                    ; limit push to our own radius.

   ; Calculate 1/dist.
    ldr r3, balls_recip_p

    ; Put divisor in table range.
    mov r10, r10, asr #16-LibDivide_Reciprocal_s    ; [16.6]    (b<<s)

    .if _DEBUG
    cmp r10, #0
    adrle r0,divbyzero          ; and flag an error
    swile OS_GenerateError      ; when necessary

    ; Limited precision.
    cmp r10, #1<<LibDivide_Reciprocal_t    ; Test for numerator too large
    adrge r0,divrange           ; and flag an error
    swige OS_GenerateError      ; when necessary
    .endif

    ; Lookup 1/dist.
    ldr r10, [r3, r10, lsl #2]    ; [0.16]    (1<<16+s)/(b<<s) = (1<<16)/b

    ; dx/=dist
    mov r8, r8, asr #16-LibDivide_Reciprocal_s    ; [16.6]    (a<<s)
    mul r8, r10, r8                      ; [10.22]   (a<<s)*(1<<16)/b = (a<<16+s)/b
    mov r8, r8, asr #LibDivide_Reciprocal_s       ; [10.16]   (a<<16)/b = (a/b)<<16

    ; dy/=dist
    mov r9, r9, asr #16-LibDivide_Reciprocal_s    ; [16.6]    (a<<s)
    mul r9, r10, r9                      ; [10.22]   (a<<s)*(1<<16)/b = (a<<16+s)/b
    mov r9, r9, asr #LibDivide_Reciprocal_s       ; [10.16]   (a<<16)/b = (a/b)<<16

    .if Balls_HaveRadiusAsMass
    ; Calculate str1 as ratio between ball weights(=radius).
    ; TODO: Ball mass should probably be proportional to radius^2.
    sub r7, r6, r7              ; other.radius

    ; Calculate 1/(ball.radius+other.radius)
    mov r6, r6, asr #16-LibDivide_Reciprocal_s    ; [16.6]    (b<<s)

    .if _DEBUG
    cmp r6, #0
    adrle r0,divbyzero          ; and flag an error
    swile OS_GenerateError      ; when necessary

    ; Limited precision.
    cmp r6, #1<<LibDivide_Reciprocal_t    ; Test for numerator too large
    adrge r0,divrange           ; and flag an error
    swige OS_GenerateError      ; when necessary
    .endif

    ; Lookup 1/(ball.radius+other.radius).
    ldr r6, [r3, r6, lsl #2]    ; [0.16]    (1<<16+s)/(b<<s) = (1<<16)/b

    mov r7, r7, asr #16-LibDivide_Reciprocal_s    ; [16.6]    (a<<s)
    mul r7, r6, r7                  ; str1=other.radius/(ball.radius+other.radius)
    mov r7, r7, asr #LibDivide_Reciprocal_s       ; [10.16]   (a<<16)/b = (a/b)<<16
    .else
    mov r7, #MATHS_CONST_HALF       ; str1=0.5 (equal weights)
    .endif

     ; Calculate displacement.
    mov r2, r2, asr #8              ; push
    mov r8, r8, asr #8
    mul r8, r2, r8                  ; dx*push
    mov r9, r9, asr #8
    mul r9, r2, r9                  ; dy*push

    mov r7, r7, asr #8              ; str1
    mov r10, r8, asr #8             ; dx*push
    mul r10, r7, r10                ; dx*push*str1
    mov r6, r9, asr #8              ; dx*push
    mul r6, r7, r6                  ; dy*push*str1

    ; ball.ix+=dx*push*str1
    ; ball.iy+=dy*push*str1
    ldr r2, [r11, #Ball_ix]
    ldr r3, [r11, #Ball_iy]
    add r2, r2, r10
    add r3, r3, r6
    str r2, [r11, #Ball_ix]
    str r3, [r11, #Ball_iy]

    rsb r7, r7, #MATHS_CONST_1>>8   ; (1-str1)
    mov r10, r8, asr #8             ; dx*push
    mul r10, r7, r10                ; dx*push*(1-str1)
    mov r6, r9, asr #8              ; dy*push
    mul r6, r7, r6                  ; dy*push*(1-str1)

    ; other.ix-=dx*push*(1-str1)
    ; other.iy-=dy*push*(1-str1)
    ldr r2, [r12, #Ball_ix]
    ldr r3, [r12, #Ball_iy]
    sub r2, r2, r10
    sub r3, r3, r6
    str r2, [r12, #Ball_ix]
    str r3, [r12, #Ball_iy]

.5:
    ldr r12, [r12, #Ball_Next]
    b .3

.4:
    ; Compared with all other balls.
    ; Resolve next ball.
    ldr r11, [r11, #Ball_Next]
    b .1

.2:

    ; Finally make all collision adjustments.
    ldr r11, balls_first_active     ; curr_p
.10:
    cmp r11, #0
    beq .20

    ; Don't need to load the full context.
    ldmia r11, {r0-r6}              ; load ball context

    ; TODO: This is approximated as *0.5 and *0.25.
    add r1, r1, r5, asr #1          ; ball.x+=ball.ix*.7
    add r2, r2, r6, asr #1          ; ball.y+=ball.iy*.7
    add r3, r3, r5, asr #2          ; ball.vx+=ball.ix*.35
    add r4, r4, r6, asr #2          ; ball.vy+=ball.iy*.35

    stmia r11, {r0-r4}
    mov r11, r0                     ; curr_p=next_p
    b .10

.20:
    ldr pc, [sp], #4

; ============================================================================

; R12=screen addr
balls_draw_all:
    str lr, [sp, #-4]!

    adr r11, balls_first_active         ; curr_p
    ldr r11, [r11]                      ; next_p
.1:
    cmp r11, #0
    beq .2

    ; Don't need to load the full context.
    ldmia r11, {r0-r2}                  ; load ball context
    ldr r7, [r11, #Ball_radius]
    mov r11, r0                         ; curr_p=next_p

    ; For now just plot 2D balls.
    add r1, r1, #Balls_CentreX          ; [s15.16]
    add r2, r2, #Balls_CentreY          ; [s15.16]

    ;  r0 = X centre
    ;  r1 = Y centre
    mov r0, r1, asr #16
    mov r1, r2, asr #16

    ;  r2 = radius of circle
    ;  r9 = tint
    mov r9, r7, lsr #16                 ; colour
    eor r2, r7, r9, lsl #16             ; radius
    bl circles_add_to_plot_by_order

.3:
    b .1

.2:
    ldr pc, [sp], #4

; ============================================================================

.if _DEBUG
balls_debug_pos:
    .long 60

; R1=dir.
balls_debug_cursor:
    ldr r0, balls_debug_pos
    add r0, r0, r1
    cmp r0, #0
    movlt r0, #0
    cmp r0, #Screen_Width
    movge r0, #Screen_Width-1
    str r0, balls_debug_pos
    mov pc, lr

; R1=size.
balls_debug_drop:
    ldr r10, balls_next_free    ; ball_p
    cmp r10, #0
    moveq pc, lr

    ; Ball vars.
    mov r7, r1, asl #2          ; radius
    mvn r2, r7, asl #16         ; ball.y=-radius [16.16]
    add r1, r1, #6              ; colour 7-15
    orr r7, r7, r1, lsl #16     ;

    ldr r1, balls_debug_pos
    mov r1, r1, asl #16         ; ball.x [16.16]

    mov r3, #0                  ; ball.vx
    mov r4, #0                  ; ball.vy
    mov r5, #0                  ; ball.ix
    mov r6, #0                  ; ball.iy

    ; Spawn a ball pointed to by R10.
    ldr r8, [r10, #0]               ; curr_p->next_p

    ; Insert this ball at the front of the active list.
    ldr r0, balls_first_active
    stmia r10, {r0-r7}
    str r10, balls_first_active

    mov r10, r8                     ; curr_p = next_p
    ; Safe to use R8 here as just assigned to r10 above.
    ldr r8, balls_alive_count
    add r8, r8, #1
    str r8, balls_alive_count
    str r10, balls_next_free

    mov pc, lr
.endif

; ============================================================================
