; ============================================================================
; Simple events.
; Calls a script fn. when event is triggered.
; Some attempt to combine Rocket with asm scripting. :S
; ============================================================================

.equ Events_Max, 1

event_table:
    .long event_set_default_palette     ; 0
    .long event_set_cobra               ; 1
    .long event_set_cube                ; 2
    .long event_show_wireframe          ; 3
    .long event_show_twist_squares      ; 4
    .long event_show_y_sine_dots        ; 5
    .long event_show_starfield          ; 6
    .long event_show_dot_tunnel         ; 7
    .long event_show_circles            ; 8
    .long event_show_solid              ; 9

event_no:
    .long -1

event_update:
    str lr, [sp, #-4]!
    mov r0, #0          ; track #0
    bl rocket_sync_get_val
    mov r0, r1, asr #16
    ldr r1, event_no
    cmp r0, r1
    ldreq pc, [sp], #4

    ; New event triggered.
    str r0, event_no

    ; Add script for event to be called.
    adr r1, event_table
    ldr r0, [r1, r0, lsl #2]
    bl script_add_program
    ldr pc, [sp], #4
