; ============================================================================
; Sine scroller, one byte per column plotted
; ============================================================================

.equ SineScroller_NoPlotZeros,      1   ; don't plot 0 bytes.

.equ SineScroller_GlyphWidthBytes,  8
.equ SineScroller_GlyphHeight,      15
.equ SineScroller_TableSize,        1024
.equ SineScroller_Amplitude,        100
.equ SineScroller_TableStep,        (1<<16)/SineScroller_TableSize

sine_scroller_text_p:
    .long scroll_text_text_no_adr

sine_scroller_text_base_p:
    .long scroll_text_text_no_adr

sine_scroller_font_p:
    .long razor_font_no_adr

sine_scroller_y_pos:
    .long 128

sine_scroller_y_index:
    .long 0

sine_scroller_byte_col:
    .long 0

sine_scroller_wave_p:
    .long sine_wave_table_no_adr

sine_scroller_wave_top_p:
    .long sine_wave_table_no_adr + SineScroller_TableSize*4

sine_scroller_wave_base_p:
    .long sine_wave_table_no_adr

sine_scroller_init:
    str lr, [sp, #-4]!

    ldr r0, sine_scroller_text_base_p
    str r0, sine_scroller_text_p

    ; Make an interesting sine wave pattern or someting.

    ldr r8, sine_scroller_wave_base_p
    mov r10, #SineScroller_TableSize

    mov r1, #0                      ; a
.1:
    ;  R0 = radians [0.0, 1.0] at fixed point precision. [s1.16]
    mov r0, r1
    bl sine                         ; Trashes R9.
    ;  R0 = sin(2 * PI * radians)   [s1.16]
    
    mov r2, #SineScroller_Amplitude
    mul r2, r0, r2                  ; amp * sin(a)
    mov r2, r2, asr #16
    str r2, [r8], #4

    add r1, r1, #SineScroller_TableStep

    subs r10, r10, #1
    bne .1

    ldr pc, [sp], #4

sine_scroller_tick:
    ; Update column.

    ldr r0, sine_scroller_byte_col
    add r0, r0, #1
    cmp r0, #SineScroller_GlyphWidthBytes
    blt .1
    
    ; Update glyph.

    mov r0, #0
    ldr r1, sine_scroller_text_p
    ldrb r2, [r1, #1]!
    cmp r2, #0
    ldreq r1, sine_scroller_text_base_p
    str r1, sine_scroller_text_p

    .1:
    str r0, sine_scroller_byte_col

    ; Update sine wave.

    ldr r5, sine_scroller_wave_p
    ldr r6, sine_scroller_wave_top_p
    ldr r7, sine_scroller_wave_base_p
    sub r5, r5, #16  ; four back!
    cmp r5, r6
    subge r5, r5, #SineScroller_TableSize*4
    cmp r5, r7
    addlt r5, r5, #SineScroller_TableSize*4
    str r5, sine_scroller_wave_p

    mov pc, lr

; R12=screen addr.
sine_scroller_draw:
    str lr, [sp, #-4]!

    ; R12=screen base

    ; R9=glyph read addr
    ldr r9, sine_scroller_font_p
    ; R8=text ptr
    ldr r8, sine_scroller_text_p
    ldrb r0, [r8]       ; get ASCII
    sub r0, r0, #32
    add r9, r9, r0, lsl #7      ; 128 bytes per glyph.
    ; R7=current byte column
    ldr r7, sine_scroller_byte_col
    add r9, r9, r7, lsl #4      ; 16 bytes per column

    ldr r5, sine_scroller_wave_p
    ldr r4, sine_scroller_wave_top_p

    ; R6=y pos to plot column at
    ldr r6, sine_scroller_y_pos

    ; R10=byte column count
    mov r10, #Screen_Stride
.1:
    ; Load wave offset in y
    ldr r14, [r5], #4                   ; one forward!
    cmp r5, r4
    subge r5, r5, #SineScroller_TableSize*4

    ; Y pos for column.
    add r14, r14, r6                    ; base pos + offset

    ; R11=plot addr=screen base + y * 160
    add r11, r12, r14, lsl #7
    add r11, r11, r14, lsl #5

    ; Plot a column unrolled.
    ldmia r9!, {r0-r3}

    .if SineScroller_NoPlotZeros
    ands r14, r0, #0xff
    strneb r0, [r11], #Screen_Stride      ; row 0
    addeq r11, r11, #Screen_Stride
    mov r0, r0, lsr #8
    ands r14, r0, #0xff
    strneb r0, [r11], #Screen_Stride      ; row 1
    addeq r11, r11, #Screen_Stride
    mov r0, r0, lsr #8
    ands r14, r0, #0xff
    strneb r0, [r11], #Screen_Stride      ; row 2
    addeq r11, r11, #Screen_Stride
    mov r0, r0, lsr #8
    ands r14, r0, #0xff
    strneb r0, [r11], #Screen_Stride      ; row 3
    addeq r11, r11, #Screen_Stride

    ands r14, r1, #0xff
    strneb r1, [r11], #Screen_Stride      ; row 4
    addeq r11, r11, #Screen_Stride
    mov r1, r1, lsr #8
    ands r14, r1, #0xff
    strneb r1, [r11], #Screen_Stride      ; row 5
    addeq r11, r11, #Screen_Stride
    mov r1, r1, lsr #8
    ands r14, r1, #0xff
    strneb r1, [r11], #Screen_Stride      ; row 6
    addeq r11, r11, #Screen_Stride
    mov r1, r1, lsr #8
    ands r14, r1, #0xff
    strneb r1, [r11], #Screen_Stride      ; row 7
    addeq r11, r11, #Screen_Stride

    ands r14, r2, #0xff
    strneb r2, [r11], #Screen_Stride      ; row 8
    addeq r11, r11, #Screen_Stride
    mov r2, r2, lsr #8
    ands r14, r2, #0xff
    strneb r2, [r11], #Screen_Stride      ; row 9
    addeq r11, r11, #Screen_Stride
    mov r2, r2, lsr #8
    ands r14, r2, #0xff
    strneb r2, [r11], #Screen_Stride      ; row 10
    addeq r11, r11, #Screen_Stride
    mov r2, r2, lsr #8
    ands r14, r2, #0xff
    strneb r2, [r11], #Screen_Stride      ; row 11
    addeq r11, r11, #Screen_Stride

    ands r14, r3, #0xff
    strneb r3, [r11], #Screen_Stride      ; row 12
    addeq r11, r11, #Screen_Stride
    mov r3, r3, lsr #8
    ands r14, r3, #0xff
    strneb r3, [r11], #Screen_Stride      ; row 13
    addeq r11, r11, #Screen_Stride
    mov r3, r3, lsr #8
    ands r14, r3, #0xff
    strneb r3, [r11], #Screen_Stride      ; row 14
    addeq r11, r11, #Screen_Stride

    .else
    strb r0, [r11], #Screen_Stride      ; row 0
    mov r0, r0, lsr #8
    strb r0, [r11], #Screen_Stride      ; row 1
    mov r0, r0, lsr #8
    strb r0, [r11], #Screen_Stride      ; row 2
    mov r0, r0, lsr #8
    strb r0, [r11], #Screen_Stride      ; row 3

    strb r1, [r11], #Screen_Stride      ; row 4
    mov r1, r1, lsr #8
    strb r1, [r11], #Screen_Stride      ; row 5
    mov r1, r1, lsr #8
    strb r1, [r11], #Screen_Stride      ; row 6
    mov r1, r1, lsr #8
    strb r1, [r11], #Screen_Stride      ; row 7

    strb r2, [r11], #Screen_Stride      ; row 8
    mov r2, r2, lsr #8
    strb r2, [r11], #Screen_Stride      ; row 9
    mov r2, r2, lsr #8
    strb r2, [r11], #Screen_Stride      ; row 10
    mov r2, r2, lsr #8
    strb r2, [r11], #Screen_Stride      ; row 11

    strb r3, [r11], #Screen_Stride      ; row 12
    mov r3, r3, lsr #8
    strb r3, [r11], #Screen_Stride      ; row 13
    mov r3, r3, lsr #8
    strb r3, [r11], #Screen_Stride      ; row 14
    .endif

    .if SineScroller_GlyphHeight != 15
    .err "Expected SineScroller_GlyphHeight to be 15!"
    .endif
    ;mov r3, r3, lsr #8
    ;strb r3, [r11], #Screen_Stride      ; row 15

    ; Next byte column.
    add r12, r12, #1
    add r7, r7, #1
    cmp r7, #SineScroller_GlyphWidthBytes
    blge get_next_glyph

    subs r10, r10, #1
    bne .1

    ldr pc, [sp], #4

get_next_glyph:
    ldrb r0, [r8, #1]!          ; get ASCII
    cmp r0, #0
    ldreq r8, sine_scroller_text_base_p
    subeq r8, r8, #1
    beq get_next_glyph

    sub r0, r0, #32
    ldr r9, sine_scroller_font_p
    add r9, r9, r0, lsl #7      ; 128 bytes per glyph.
    mov r7, #0
    mov pc, lr


scroll_text_text_no_adr:
    .byte "          HELLO WORLD! THIS IS A SINE WAVE SCROLLER FOR AN ARCHIMEDES CRACKTRO DESTINED FOR THE BUXTON BYTES CRACKTRO SHOWCASE."
    .byte "          "
    .byte 0 ; end.
.p2align 2

