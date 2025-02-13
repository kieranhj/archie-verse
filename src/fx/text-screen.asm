; ============================================================================
; Text screen.
; ============================================================================

text_screen_buffer_p:
    .long text_screen_back_buffer_no_adr

; R12=screen_addr
text_screen_init:
    str lr, [sp, #-4]!
    adr r0, text_screen_test_text_no_adr
    swi OS_WriteO

    mov r14, r12
    ldr r12, text_screen_buffer_p
    b text_screen_copy

text_screen_tick:
    mov pc, lr

; R12=screen_addr
text_screen_draw:
    str lr, [sp, #-4]!
    ldr r14, text_screen_buffer_p

text_screen_copy:
    .rept Screen_Bytes / 48
    ldmia r14!, {r0-r11}
    stmia r12!, {r0-r11}
    .endr
    ldr pc, [sp], #4

text_screen_test_text_no_adr:
    ;                1         2         3         4         5         6         7         
    ;      01234567890123456789012345678901234567890123456789012345678901234567890123456789
    .byte "+------------------------------------------------------------------------------+"        ; 0
    .byte "|                                                                              |"        ; 1
    .byte "|     HELLO WORLD!                                                             |"        ; 2
    .byte "|                                                                              |"        ; 1
    .byte "|    This will be                                                              |"        ; 4
    .byte "|    some text that                                                            |"        ; 5
    .byte "|    gets typed out                                                            |"        ; 6
    .byte "|    with amazing                                                              |"        ; 7
    .byte "|    wit etc.                                                                  |"        ; 8
    .byte "|                                                                              |"        ; 1
    .byte "|                                                                              |"        ; 1
    .byte "|                                                                              |"        ; 1
    .byte "|                                                                              |"        ; 1
    .byte "|                                                                              |"        ; 1
    .byte "|                                                                              |"        ; 1
    .byte "|                                                                              |"        ; 1
    .byte "|                                                                              |"        ; 1
    .byte "|                                                                              |"        ; 1
    .byte "|                                                                              |"        ; 1
    .byte "+------------------------------------------------------------------------------+"        ; 0
    .byte 0
.p2align 2
