; ============================================================================
; Line Segments.
; ============================================================================

.equ LineSegments_UseYBuffer,   1

.equ LineSegments_Total_dy,     256

;.equ LineSegments_Min_dy,       -128
;.equ LineSegments_Max_dy,       127


line_segments_ptrs_p:
    .long line_segments_ptrs_no_adr

; Generate all the code combinations for drawing fixed length lines.
; R12=code gen ptr
line_segments_init:
    str lr, [sp, #-4]!
    ldr r2, line_seg_rts

    ; R11=jump table
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
    adrgt r6, line_seg_y_plus_1             ; x+=0;y+=yi
    adrle r6, line_seg_y_minus_1
    adrgt r7, line_seg_x_plus_1_y_plus_1    ; x+=1:y+=yi
    adrle r7, line_seg_x_plus_1_y_minus_1

    ; r4=error = 2*dx - abs(dy)
    rsb r4, r8, #2*LineSegments_Fixed_dx

    ; dy loop.
    mov r3, r8
.21:
    cmp r4, #0
    movle r5, r6                     ; x+=0;y+=yi
    movgt r5, r7                     ; x+=1:y+=yi
    bl line_seg_copy_code

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
    adr r6, line_seg_x_plus_1               ; x+=1:y+=0
    cmp r9, #0
    adrgt r7, line_seg_x_plus_1_y_plus_1    ; x+=1:y+=yi
    adrle r7, line_seg_x_plus_1_y_minus_1

    ; r4=error = 2*abs(dy) - dx
    mov r4, r8, asl #1
    sub r4, r4, #LineSegments_Fixed_dx

    ; dx loop.
    mov r3, #LineSegments_Fixed_dx
.31:
    ; 'Plot' pixel.
    cmp r4, #0
    movle r5, r6                     ; x+=1:y+=0
    movgt r5, r7                     ; x+=1:y+=yi
    bl line_seg_copy_code

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

    ldr pc, [sp], #4

; R5=code start
line_seg_copy_code:
.1:
    ldr r0, [r5], #4
    cmp r0, #0
    moveq pc, lr
    str r0, [r12], #4
    b .1


; R11=screen address
; R6=current y value
; R4=pixel byte
; R3=y buffer
; R2=min y value
; R1=target y value

.if !LineSegments_UseYBuffer
line_seg_x_plus_1:
    strb r4, [r11], #1
.long 0

line_seg_y_plus_1:
    strb r4, [r11], #Screen_Stride
.long 0

line_seg_y_minus_1:
    strb r4, [r11], #-Screen_Stride
.long 0

line_seg_x_plus_1_y_plus_1:
    strb r4, [r11], #Screen_Stride+1
.long 0

line_seg_x_plus_1_y_minus_1:
    strb r4, [r11], #-Screen_Stride
    add r11, r11, #1
.long 0
.else
line_seg_x_plus_1:
    cmp r6, r2
    strltb r4, [r11]
    strltb r6, [r3]
    add r11, r11, #1
    ldrb r2, [r3, #1]!
.long 0

line_seg_y_plus_1:
    cmp r6, r2
    strltb r4, [r11]
    add r11, r11, #Screen_Stride
    add r6, r6, #1
.long 0

line_seg_y_minus_1:
    cmp r6, r2
    strltb r4, [r11]
    sub r11, r11, #Screen_Stride
    sub r6, r6, #1
.long 0

line_seg_x_plus_1_y_plus_1:
    cmp r6, r2
    strltb r4, [r11]
    strltb r6, [r3]
    add r11, r11, #Screen_Stride+1
    add r6, r6, #1
    ldrb r2, [r3, #1]!
.long 0

line_seg_x_plus_1_y_minus_1:
    cmp r6, r2
    strltb r4, [r11]
    strltb r6, [r3]
    sub r11, r11, #Screen_Stride-1
    sub r6, r6, #1
    ldrb r2, [r3, #1]!
.long 0
.endif

line_seg_rts:
    mov pc, lr
