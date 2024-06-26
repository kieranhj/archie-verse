; ============================================================================
; Columns
; Used in: Chipo Django musicdisk as the background.
; ============================================================================

.equ Columns_Num, 5
.equ Columns_Tooth, 16      ; pixels

.macro FLOAT_TO_FP value
    .long 1<<16 * (\value)
.endm

column_y_offset:
    .skip Columns_Num * 4

column_y_speed:
    FLOAT_TO_FP 0.25
    FLOAT_TO_FP 0.5
    FLOAT_TO_FP 1
    FLOAT_TO_FP 1.5
    FLOAT_TO_FP 2

column_colours:
    .long 0xbbbbbbbb
    .long 0xcccccccc
    .long 0xdddddddd
    .long 0xeeeeeeee
    .long 0xffffffff

; R12=screen addr
plot_columns:
    str lr, [sp, #-4]!

    ; Start in the middle.
    add r11, r12, #Screen_Stride/2 + 0
    ldr r10, column_y_offset + 0
    ldr r9, column_colours + 0
    mov r4, #0  ; bg
    bl plot_rounded_column

    add r11, r12, #Screen_Stride/2 + 16
    ldr r10, column_y_offset + 4
    mov r4, r9  ; bg
    ldr r9, column_colours + 4
    bl plot_rounded_column

    add r11, r12, #Screen_Stride/2 + 32
    ldr r10, column_y_offset + 8
    mov r4, r9  ; bg
    ldr r9, column_colours + 8
    bl plot_rounded_column

    add r11, r12, #Screen_Stride/2 + 48
    ldr r10, column_y_offset + 12
    mov r4, r9  ; bg
    ldr r9, column_colours + 12
    bl plot_rounded_column

    add r11, r12, #Screen_Stride/2 + 64
    ldr r10, column_y_offset + 16
    mov r4, r9  ; bg
    ldr r9, column_colours + 16
    bl plot_rounded_column

    ldr pc, [sp], #4

update_columns:
    adr r9, column_y_offset
    adr r8, column_y_speed
    mov r7, #5
.1:
    ldr r0, [r9]
    ldr r1, [r8], #4
    add r0, r0, r1
    bic r0, r0, #0xff000000 ; assume 256
    str r0, [r9], #4
    subs r7, r7, #1
    bne .1

    mov pc, lr

; R12=screen addr
clear_left_screen:
    mov r0, #0
    mov r1, r0
    mov r2, r0
    mov r3, r0
    mov r4, r0
    mov r5, r0
    mov r6, r0
    mov r7, r0
    mov r8, r0
    mov r9, r0

.rept Screen_Height
    stmia r12!, {r0-r9}     ; 80 pixels
    stmia r12!, {r0-r9}     ; 80 pixels
    add r12, r12, #Screen_Stride/2
.endr

    mov pc, lr

; R11=screen plot pointer
; R10=y offset
; R9=colour word
; R4=bg colour
; Trashes: r3-r8
plot_rounded_column:
    ; Copy colour word.
    mov r8, r9
    mov r7, r9
    mov r6, r9

    ; Make corner word.
    bic r5, r9, #0x0000000f     ; remove leftmost pixel.
    orr r5, r5, r4, lsr #28     ; mask in a bg pixel.
    ; R5=colour word with leftmost pixel in bg.

    ; Copy bg word.
    mov r2, r4

    ; Make corner word.
    bic r3, r4, #0xf0000000     ; remove rightmost pixel.
    orr r3, r3, r9, lsl #28     ; mask in a colour pixel.
    ; R3=bg word with rightmost pixel in colour.

    ; Plot 32-Y lines, skip Y lines from start out of block of 32.
    mov r10, r10, lsr #16
    and r10, r10, #31
    adr r1, .1
    add pc, r1, r10, lsl #3     ; Y*8 = Y * (2 instructions)

.1:
.rept (Screen_Height+31)/32
    ; Each 'tooth' is 16 pixels.
    ; Assuming we're starting at parity 0 on line 0:
    stmia r11!, {r2-r3,r8-r9}   ; line 0 = bg + corner + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 1 = bg + bg + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 2 = bg + bg + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 3 = bg + bg + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 4 = bg + bg + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 5 = bg + bg + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 6 = bg + bg + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 7 = bg + bg + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 8 = bg + bg + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 9 = bg + bg + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 10 = bg + bg + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 11 = bg + bg + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 12 = bg + bg + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 13 = bg + bg + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 14 = bg + bg + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2-r3,r8-r9}   ; line 15 = bg + corner + colour + colour
    add r11, r11, #Screen_Stride-16

    ; After 16 lines we switch to parity 1 on line 16:
    stmia r11!, {r5,r6-r8}      ; line 16 = corner + colour + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 17 = colour + colour + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 18 = colour + colour + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 19 = colour + colour + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 20 = colour + colour + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 21 = colour + colour + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 22 = colour + colour + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 23 = colour + colour + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 24 = colour + colour + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 25 = colour + colour + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 26 = colour + colour + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 27 = colour + colour + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 28 = colour + colour + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 29 = colour + colour + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 30 = colour + colour + colour + colour
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r5,r6-r8}      ; line 31 = corner + colour + colour + colour
    add r11, r11, #Screen_Stride-16
.endr

    ; Plot Y lines [0-31] then rts.
    cmp r10, #0
    moveq pc, lr

    stmia r11!, {r2-r3,r8-r9}   ; line 0 = bg + corner + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 1 = bg + bg + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 2 = bg + bg + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 3 = bg + bg + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 4 = bg + bg + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 5 = bg + bg + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 6 = bg + bg + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 7 = bg + bg + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 8 = bg + bg + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 9 = bg + bg + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 10 = bg + bg + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 11 = bg + bg + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 12 = bg + bg + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 13 = bg + bg + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2,r4,r8-r9}   ; line 14 = bg + bg + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r2-r3,r8-r9}   ; line 15 = bg + corner + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16

    ; After 16 lines we switch to parity 1 on line 16:
    stmia r11!, {r5,r6-r8}      ; line 16 = corner + colour + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 17 = colour + colour + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 18 = colour + colour + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 19 = colour + colour + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 20 = colour + colour + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 21 = colour + colour + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 22 = colour + colour + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 23 = colour + colour + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 24 = colour + colour + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 25 = colour + colour + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 26 = colour + colour + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 27 = colour + colour + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 28 = colour + colour + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 29 = colour + colour + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r6-r9}         ; line 30 = colour + colour + colour + colour
    subs r10, r10, #1
    moveq pc, lr
    add r11, r11, #Screen_Stride-16
    stmia r11!, {r5,r6-r8}      ; line 31 = corner + colour + colour + colour
    
    mov pc, lr
    