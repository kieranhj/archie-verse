; ============================================================================
; Line Segments.
; ============================================================================

.equ LineSegments_Fixed_dx,     5       ; fixed.
.equ LineSegments_Total_dy,     256

;.equ LineSegments_Min_dy,       -128
;.equ LineSegments_Max_dy,       127


line_segments_code_gen_p:
    .long line_segments_code_gen_no_adr

line_segments_ptrs_p:
    .long line_segments_ptrs_no_adr

; Generate all the code combinations
line_segments_init:
    ldr r2, line_seg_rts

    ; R12=code gen ptr
    ; R11=jump table
    ldr r12, line_segments_code_gen_p
    ldr r11, line_segments_ptrs_p
    mov r10, #0                 ; dy (unsigned)
.1:
    str r12, [r11], #4          ; store start of code.

    ; r9=dy (signed)
    mov r9, r10, asl #24
    movs r9, r9, asr #24

    ; r8=abs(dy)
    movpl r8, r9
    rsbmi r8, r9, #0

    cmp r8, #LineSegments_Fixed_dx
    ble .3  ; shallow line

.2:
    ; Steep line.
    ; y+=yi each iter.
    ; x+=[0|1]
    cmp r9, #0
    ldrgt r6, line_seg_y_plus_1             ; x+=0;y+=yi
    ldrle r6, line_seg_y_minus_1
    ldrgt r7, line_seg_x_plus_1_y_plus_1    ; x+=1:y+=yi
    movgt r5, #0
    ldrle r7, line_seg_x_plus_1_y_minus_1
    ldrle r5, line_seg_x_plus_1_y_minus_1+4  ; ARGH!

    ; r4=error = 2*dx - abs(dy)
    rsb r4, r8, #2*LineSegments_Fixed_dx

    ; dy loop.
    mov r3, r8
.21:
    cmp r4, #0
    strle r6, [r12], #4                     ; x+=0;y+=yi
    ble .22
    str r7, [r12], #4                     ; x+=1:y+=yi
    cmp r5, #0                              ; ARGH!
    str r5, [r12], #4                     ; x+=1:y+=yi
    .22:

    cmp r4, #0
    add r4, r4, #2*LineSegments_Fixed_dx    ; error += 2*dx
    subgt r4, r4, r8, asl #1                ; error -= 2*dy

    subs r3, r3, #1
    bne .21

    str r2, [r12], #4                       ; rts

    ; Next line.
    b .4

.3:
    ; Shallow line.
    ; x+=1 each iter.
    ; y+=[-1|0|1]
    ldr r6, line_seg_x_plus_1               ; x+=1:y+=0
    cmp r9, #0
    ldrgt r7, line_seg_x_plus_1_y_plus_1    ; x+=1:y+=yi
    movgt r5, #0
    ldrle r7, line_seg_x_plus_1_y_minus_1
    ldrle r5, line_seg_x_plus_1_y_minus_1+4  ; ARGH!

    ; r4=error = 2*abs(dy) - dx
    mov r4, r8, asl #1
    sub r4, r4, #LineSegments_Fixed_dx

    ; dx loop.
    mov r3, #LineSegments_Fixed_dx
.31:
    ; 'Plot' pixel.
    cmp r4, #0
    strle r6, [r12], #4                     ; x+=1:y+=0
    ble .32
    str r7, [r12], #4                     ; x+=1:y+=yi
    cmp r5, #0                              ; ARGH!
    str r5, [r12], #4                     ; x+=1:y+=yi
    .32:

    cmp r4, #0
    add r4, r4, r8, asl #1                  ; error += 2*abs(dy)
    subgt r4, r4, #2*LineSegments_Fixed_dx  ; error -= 2*dx

    subs r3, r3, #1
    bne .31

    str r2, [r12], #4                       ; rts

.4:
    ; Next line.
    add r10, r10, #1
    cmp r10, #LineSegments_Total_dy
    blt .1

    mov pc, lr

line_seg_x_plus_1:
    strb r4, [r11], #1

line_seg_y_plus_1:
    strb r4, [r11], #Screen_Stride

line_seg_y_minus_1:
    strb r4, [r11], #-Screen_Stride

line_seg_x_plus_1_y_plus_1:
    strb r4, [r11], #Screen_Stride+1

line_seg_x_plus_1_y_minus_1:
    strb r4, [r11], #-Screen_Stride
    add r11, r11, #1

line_seg_rts:
    mov pc, lr
