; ============================================================================
; Events system.
; Calls a fn with data when triggered by an event track.
; These are explicitly tied to the music MOD (pattern, row) position.
; ============================================================================

.equ Events_MaxCodes,       16

; Event 0 isn't used.
; Event 15 is probably problematic (ProTracker set tempo command).
event_triggers:
    .skip 4*Events_MaxCodes

events_base_p:
    .long 0

events_p:
    .long 0

.if _DEBUG
events_last_events:
    .skip 4*4

events_last_p:
    .long 0
.endif

; TODO: Add test callback fn. that just stores the event code & data.

; Each event row is 64 bits.
;  [0]    = seq#                  
;  [1]    = row#                  
;  [2][3] = bbbb AAAA aaaa aaaa
;  [4][5] = cccc cccc BBBB bbbb
;  [6][7] = DDDD dddd dddd CCCC
; Where AAAA is the command code.
; and   aaaa aaaa is the command data.

; R0=ptr to events data.
events_init:
    str lr, [sp, #-4]!

    str r0, events_base_p
    str r0, events_p

    ; These use 'bl'. I always forget this...
    DEBUG_REGISTER_VAR events_last_events+0
    DEBUG_REGISTER_VAR events_last_events+4
    DEBUG_REGISTER_VAR events_last_events+8
    DEBUG_REGISTER_VAR events_last_events+12

    ldr pc, [sp], #4

; R0=event #
; R1=trigger fn
; LATER: R2=preload fn
events_set_fns:
    adr r4, event_triggers
    str r1, [r4, r0, lsl #2]
    mov pc, lr
; TODO: Or just use macro?


; Call all fns on this music row with data.
events_tick:
    ; Check we have events data.
    ldr r10, events_p
    cmp r10, #0
    moveq pc, lr

    .if _DEBUG
    adr r0, events_last_events
    str r0, events_last_p
    .endif

    ; Read current music position.
    ldr r9, music_pos       ; 0xpprr

    ; Read current event data
    ldr r6, [r10], #4
    bic r8, r6, #0xff000000
    bic r8, r8, #0x00ff0000
    ; Left with  0x0000pprr

    ; EOF
    cmp r8, #0xff00
    movge pc, lr

    ; If music hasn't reached our event yet, then exit.
    cmp r9, r8
    movlt pc, lr

    ; If music is ahead of our events, then what?!
    .if _DEBUG
    beq .99
    adrgt r0, erreventsbehind
    swigt OS_GenerateError
    .99:
    .endif

    ; Matched pattern and row so call the events in order.
    str lr, [sp, #-4]!
    ldr r7, [r10], #4
    str r10, events_p

    ; R6 = BBBB aaaa aaaa AAAA PPPP PPPP RRRR RRRR
    ; R7 = dddd dddd DDDD cccc cccc CCCC bbbb bbbb

    mov r6, r6, lsr #16         ; strip out (pos,row)

    ; R6 = BBBB aaaa aaaa AAAA
    ; R7 = dddd dddd DDDD cccc cccc CCCC bbbb bbbb

    ands r1, r6, #0xf           ; code AAAA
    ldreq pc, [sp], #4          ; exit on code 0
    mov r6, r6, lsr #4
    and r0, r6, #0xff           ; R0=data aaaa aaaa
    mov r6, r6, lsr #8

    ; R6 = BBBB
    ; R7 = dddd dddd DDDD cccc cccc CCCC bbbb bbbb

    stmfd sp!, {r6,r7}
    adr r11, event_triggers
    adr lr, .1
    ldr r2, [r11, r1, lsl #2]
    .if _DEBUG
    cmp r2, #0
    adreq r0, errnoeventfn
    swieq OS_GenerateError
    .endif
    mov pc, r2
    .1:
    ldmfd sp!, {r6,r7}

    ; R6 = BBBB
    ; R7 = dddd dddd DDDD cccc cccc CCCC bbbb bbbb

    ands r1, r6, #0xf           ; code BBBB
    ldreq pc, [sp], #4          ; exit on code 0
    and r0, r7, #0xff           ; R0=data bbbb bbbb
    mov r7, r7, lsr #8

    ; R7 = dddd dddd DDDD cccc cccc CCCC

    str r7, [sp, #-4]!
    adr r11, event_triggers
    adr lr, .2
    ldr r2, [r11, r1, lsl #2]
    .if _DEBUG
    cmp r2, #0
    adreq r0, errnoeventfn
    swieq OS_GenerateError
    .endif
    mov pc, r2
    .2:
    ldr r7, [sp], #4

    ; R7 = dddd dddd DDDD cccc cccc CCCC

    ands r1, r7, #0xf           ; code CCCC
    ldreq pc, [sp], #4          ; exit on code 0
    mov r7, r7, lsr #4
    and r0, r7, #0xff           ; R0=data cccc cccc
    mov r7, r7, lsr #8

    ; R7 = dddd dddd DDDD

    str r7, [sp, #-4]!
    adr r11, event_triggers
    adr lr, .3
    ldr r2, [r11, r1, lsl #2]
    .if _DEBUG
    cmp r2, #0
    adreq r0, errnoeventfn
    swieq OS_GenerateError
    .endif
    mov pc, r2
    .3:
    ldr r7, [sp], #4

    ; R7 = dddd dddd DDDD

    ands r1, r7, #0xf           ; code DDDD
    ldreq pc, [sp], #4          ; exit on code 0
    mov r7, r7, lsr #4
    and r0, r7, #0xff           ; R0=data dddd dddd

    adr r11, event_triggers
    adr lr, .4
    ldr r2, [r11, r1, lsl #2]
    .if _DEBUG
    cmp r2, #0
    adreq r0, errnoeventfn
    swieq OS_GenerateError
    .endif
    mov pc, r2
    .4:

    ldr pc, [sp], #4

.if _DEBUG
erreventsbehind:
    .long 0
	.byte "Music got ahead of the events track."
	.align 4
	.long 0

errnoeventfn:
    .long 0
	.byte "No event callback fn for code."
	.align 4
	.long 0

; R0=data
; R1=code
events_test_fn:
    orr r0, r0, r1, lsl #8
    ldr r2, events_last_p
    str r0, [r2], #4
    str r2, events_last_p
    mov pc, lr
.endif
