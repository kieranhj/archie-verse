; ============================================================================
; Logo plotting.
; Make 8 shifted copies (1 per pixel) of word aligned sprite data.
; Plot word aligned data to screen with mask.
; Used in: Chipo Django musicdisk.
; ============================================================================

.equ Logo_Width, 216
.equ Logo_Height, 68
.equ Logo_Gap, Screen_Stride-Logo_Width/Screen_PixelsPerByte
.equ Logo_Stride, Logo_Width/Screen_PixelsPerByte
.equ Logo_Bytes, Logo_Stride*Logo_Height

.equ Logo_Y_Radius, 8
.equ Logo_Centre_Left, 56
.equ Logo_Centre_Top, 10

logo_data_p:
    .long logo_data_no_adr

logo_mask_p:
    .long logo_mask_no_adr

logo_data_shifted_p:
    .long logo_data_shifted_no_adr

logo_mask_shifted_p:
    .long logo_mask_shifted_no_adr

logo_data_shift_table:
    .skip 8*4

logo_mask_shift_table:
    .skip 8*4

logo_x_rads:
    .long 0

logo_y_rads:
    .long 0

logo_x_delta:
    .long 3<<7      ; period << 8

logo_y_delta:
    .long 2<<7      ; period << 8

logo_x_radius:
    .long 20

plot_logo:
    str lr, [sp, #-4]!

    ; Update x position
    ldr r0, logo_x_rads
    ldr r1, logo_x_delta
    add r0, r0, r1
    str r0, logo_x_rads

    bl sine
    ; R0=sin(x_rads)
    ldr r8, logo_x_radius
    mul r8, r0, r8
    mov r8, r8, asr #16
    mov r1, #Logo_Centre_Left
    add r8, r8, r1

    ; Update y position
    ldr r0, logo_y_rads
    ldr r1, logo_y_delta
    add r0, r0, r1
    str r0, logo_y_rads
    bl cosine
    ; R0=cos(y_rads)
    mov r1, #Logo_Y_Radius

    mul r1, r0, r1
    mov r1, r1, asr #16
    add r1, r1, #Logo_Centre_Top

    mov r0, r8

    ; Fall through!

; R0=x
; R1=y
; R12=screen address
;plot_logo_at_xy:
    mov r10, #Logo_Height
    mov r11, r12

    ; Calculate screen address.
    add r11, r12, r1, lsl #7
    add r11, r11, r1, lsl #5        ; y * 160

    and r2, r0, #7                  ; pixel shift [0-7]
    bic r0, r0, #7
    add r11, r11, r0, asr #1        ; + x / 2

    ; Locate pre-shifted data & mask.
    adr r9, logo_data_shift_table
    ldr r9, [r9, r2, lsl #2]

    adr r8, logo_mask_shift_table
    ldr r8, [r8, r2, lsl #2]

    .1:
.rept Logo_Width/32
    ldmia r11, {r0-r3}      ; 4 words of screen.
    ldmia r8!, {r4-r7}      ; 4 words of mask.
    bic r0, r0, r4
    bic r1, r1, r5
    bic r2, r2, r6
    bic r3, r3, r7
    ldmia r9!, {r4-r7}      ; 4 words of logo.
    orr r0, r0, r4
    orr r1, r1, r5
    orr r2, r2, r6
    orr r3, r3, r7
    stmia r11!, {r0-r3}     ; 4 words of screen.
.endr
.if Logo_Width == 216
    ldmia r11, {r0-r2}      ; 4 words of screen.
    ldmia r8!, {r4-r6}      ; 4 words of mask.
    bic r0, r0, r4
    bic r1, r1, r5
    bic r2, r2, r6
    ldmia r9!, {r4-r6}      ; 4 words of logo.
    orr r0, r0, r4
    orr r1, r1, r5
    orr r2, r2, r6
    stmia r11!, {r0-r2}     ; 4 words of screen.
.else
    .err "Assuming Logo_Width is 216 pixels!"
.endif

    add r11, r11, #Logo_Gap
    subs r10, r10, #1
    bne .1

    ldr pc, [sp], #4

.macro logo_shift_right_by_pixels
    mov r8, r8, lsl r10
    orr r8, r8, r7, lsr r11
    mov r7, r7, lsl r10
    orr r7, r7, r6, lsr r11
    mov r6, r6, lsl r10
    orr r6, r6, r5, lsr r11
    mov r5, r5, lsl r10
    orr r5, r5, r4, lsr r11
    mov r4, r4, lsl r10
    orr r4, r4, r3, lsr r11
    mov r3, r3, lsl r10
    orr r3, r3, r2, lsr r11
    mov r2, r2, lsl r10
    orr r2, r2, r1, lsr r11
    mov r1, r1, lsl r10
    orr r1, r1, r0, lsr r11
.endm

; R9=src address
; R12=dst address
; R10=pixel shift   [0-7]
logo_shift_image:
    str lr, [sp, #-4]!
    
    mov r10, r10, lsl #2        ; word shift
    rsb r11, r10, #32           ; reverse word shift

    mov r14, #Logo_Height
.1:
    add r9, r9, #104            ; end of src
    add r12, r12, #108          ; end of dst

    sub r9, r9, #32             ; last chunk.
    sub r12, r12, #32           ; last chunk.
    ldmia r9, {r0-r8}           ; 9 words = 68 pixels.
    logo_shift_right_by_pixels
    stmia r12, {r1-r8}          ; 8 words = 64 pixels.

    sub r9, r9, #32             ; next chunk.
    sub r12, r12, #32           ; next chunk.
    ldmia r9, {r0-r8}           ; 9 words = 68 pixels.
    logo_shift_right_by_pixels
    stmia r12, {r1-r8}          ; 8 words = 64 pixels.

    sub r9, r9, #32             ; first chunk.
    sub r12, r12, #32           ; first chunk.
    ldmia r9, {r0-r8}           ; 9 words = 68 pixels.
    logo_shift_right_by_pixels
    stmia r12, {r1-r8}          ; 8 words = 64 pixels.

    ; two words left over..
    sub r9, r9, #8              ; left over bit.
    sub r12, r12, #12           ; left over bit.
    mov r0, #0
    ldmia r9, {r1-r3}
    mov r3, r3, lsl r10
    orr r3, r3, r2, lsr r11
    mov r2, r2, lsl r10
    orr r2, r2, r1, lsr r11
    mov r1, r1, lsl r10
    orr r1, r1, r0, lsr r11
    stmia r12, {r1-r3}

    add r9, r9, #Logo_Stride
    add r12, r12, #Logo_Stride

    subs r14, r14, #1
    bne .1

    mov r10, r10, lsr #2        ; restore r10
    ldr pc, [sp], #4

logo_init:
    str lr, [sp, #-4]!

    ldr r9, logo_data_p
    str r9, logo_data_shift_table
    ldr r12, logo_data_shifted_p

    mov r10, #1
.1:
    adr r0, logo_data_shift_table
    str r12, [r0, r10, lsl #2]
    ldr r9, logo_data_p
    bl logo_shift_image         ; copies r9 into r12, shifted by r10 pixels.
    add r10, r10, #1
    cmp r10, #8
    bne .1

    ldr r9, logo_mask_p
    str r9, logo_mask_shift_table
    ldr r12, logo_mask_shifted_p

    mov r10, #1
.2:
    adr r0, logo_mask_shift_table
    str r12, [r0, r10, lsl #2]
    ldr r9, logo_mask_p
    bl logo_shift_image         ; copies r9 into r12, shifted by r10 pixels.
    add r10, r10, #1
    cmp r10, #8
    bne .2

    ldr pc, [sp], #4
