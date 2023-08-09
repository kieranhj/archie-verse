; ============================================================================
; Width scale.
; ============================================================================

.equ Width_Min, 64
.equ Width_Max, 216
.equ Logo_Height, 68

logo_data_p:
    .long logo_data_no_adr

plot_width_fns_p:
    .long plot_width_table

plot_width_dy_p:
    .long plot_dy_table

; R12=screen_addr
; R0=width
plot_logo_with_width:
    str lr, [sp, #-4]!
    mov r5, r12
    ldr r7, plot_width_fns_p
    ldr r7, [r7, r0, lsl #2]    ; width fn.
    ldr r4, plot_width_dy_p
    ldr r4, [r4, r0, lsl #2]    ;dy
    mov r6, #0                  ; y
.1:
    ldr r11, logo_data_p
    mov r0, r6, asr #16
    add r11, r11, r0, lsl #6    ; y*64
    add r11, r11, r0, lsl #5    ; y*32
    add r11, r11, r0, lsl #3    ; y*8
    add r11, r11, r0, lsl #2    ; y*4
                                ; =y*108 = LOGO STRIDE. Urgh!
    mov r12, r5
    adr lr, .2
    mov pc, r7   
    .2:

    add r5, r5, #Screen_Stride
    add r6, r6, r4              ; y+=dy
    cmp r6, #Logo_Height*PRECISION_MULTIPLIER
    blt .1

    ldr pc, [sp], #4

width_logo_scale:
    .long 0

width_logo_dir:
    .long 1

; R12=screen addr
width_plot_test:
    str lr, [sp, #-4]!
    ldr r0, width_logo_scale
    bl plot_logo_with_width

    ldr r0, width_logo_scale
    ldr r1, width_logo_dir
    adds r0, r0, r1
    movmi r0, #0
    movmi r1, #1
    cmp r0, #76
    movgt r0, #76
    movgt r1, #-1
    str r0, width_logo_scale
    str r1, width_logo_dir

    ldr pc, [sp], #4
