; ============================================================================
; Checkerboard.
; Each line represents a distance from the camera.
; 8 copies of all rows for pixel shift from [0-7].
; Plot all 2^N combinations of rows given N layers in one 'bitplane'.
; Combine 2xN layers together by masking 'bitplanes' to screen.
; ============================================================================

.equ _ENABLE_ROCKET, 0

.equ Rows_Width_Pixels, 1024
.equ Rows_Width_Bytes, Rows_Width_Pixels/2
.equ Rows_Centre_Left_Edge, (Rows_Width_Pixels/2) - (Screen_Width/2)

.equ Check_Num_Depths, 512
.equ Check_Size_Pixels, 400
.equ Check_Depth_dx, 3276           ; 0.05<<16
.equ Layer_Centre_Top_Edge, (Check_Size_Pixels/2)

.equ Check_Layers_per_bitplane, 4
.equ Check_Total_Layers, Check_Layers_per_bitplane * 2
.equ Check_Line_Combos, (1 << Check_Layers_per_bitplane)


; ========================================================================

; Pointers to the buffers for check rows at each pixel shift.
check_rows_table:
    .long check_rows_pixel_0_no_adr
    .long check_rows_pixel_1_no_adr
    .long check_rows_pixel_2_no_adr
    .long check_rows_pixel_3_no_adr
    .long check_rows_pixel_4_no_adr
    .long check_rows_pixel_5_no_adr
    .long check_rows_pixel_6_no_adr
    .long check_rows_pixel_7_no_adr

check_depths_dx_p:
    .long check_depths_dx_no_adr

check_bitplane_0_line_combos_p:
    .long check_bitplane_0_line_combos_no_adr

check_bitplane_1_line_combos_p:
    .long check_bitplane_1_line_combos_no_adr

; ========================================================================
; Plot a row's worth of pixels for the depth given by dx, with
; pixel shift [0-7]. Centres the checks in the centre of the row.
; Plot 'Rows_Width_Pixels' pixels , i.e. 'Rows_Width_Bytes' bytes
; written into the buffer pointed to be R11.
; ========================================================================
; 
; R1=dx [16.16]
; R4=pixel shift.
; R11=buffer addr.
; Trashes: r0,r2,r3,r5,r9,r10
plot_check_row:
    ; Centre of row is centre of check.
    mov r0, #Check_Size_Pixels<<15        ; [16.16]
    mov r3, #0x0                           ; pixel
    mov r5, #Check_Size_Pixels<<16        ; [16.16]

    ; Step back half a row to find x at start.
    mov r9, #Rows_Width_Pixels/2
    sub r9, r9, r4
.3:
    add r0, r0, r1
    cmp r0, r5              ; X>check size?
    subge r0, r0, r5        ; x-=cw
    eorge r3, r3, #0xf      ; pixel^=1
    subs r9, r9, #1
    bne .3
    rsb r0, r0, r5          ; because we've been adding not subtracting dx

    ; Loop words.
    mov r10, #Rows_Width_Pixels/8  ; word count
.1:
    ; Loop pixels.
    mov r9, #8              ; pixel count
    mov r2, #0              ; accumulated word
.2:
    mov r2, r2, lsr #4      ; make room for next pixel.
    orr r2, r2, r3, lsl #28          ; insert pixel

    add r0, r0, r1          ; x+=dx
    cmp r0, r5              ; X>check size?
    subge r0, r0, r5        ; x-=cw
    eorge r3, r3, #0xf      ; pixel^=1

    subs r9, r9, #1         ; next pixel in word
    bne .2

    str r2, [r11], #4       ; write word

    subs r10, r10, #1       ; next word in row
    bne .1

    mov pc, lr

; Plot 'Check_Num_Depths' check rows to the buffer pointed to
; by R11. Starting at dx=1.0 (i.e. check will be 'Check_Size_Pixels'
; wide) and step by Check_Depth_dx for each additional depth.
;
; R4 = pixel shift.
; R11 = buffer address.
make_check_rows:
    str lr, [sp, #-4]!
    mov r7, #1<<16          ; start at dx=1.0

    ldr r6, check_depths_dx_p

    ; Loop rows.
    mov r12, #Check_Num_Depths
.1:
    mov r1, r7
    str r1, [r6], #4                ; remove #4 if enabling the division below.

    .if 0                           ; to store Check_Size/dx if we need it.
    mov r0, #Check_Size_Pixels<<16
    bl divide
    add r6, r6, #Check_Num_Depths * 4
    str r0, [r6], #4
    sub r6, r6, #Check_Num_Depths * 4
    mov r1, r7
    .endif

    bl plot_check_row
    add r7, r7, #Check_Depth_dx     ; dx+=0.05

    subs r12, r12, #1
    bne .1

    ldr pc, [sp], #4

; Make all check rows for all depths at all pixel shifts [0-7].
check_rows_init:
    str lr, [sp, #-4]!

    mov r4, #0
.1:
    adr r0, check_rows_table
    ldr r11, [r0, r4, lsl #2] 
    bl make_check_rows
    add r4, r4, #1
    cmp r4, #8
    blt .1

    ldr pc, [sp], #4


; ========================================================================
; Plot a screen widths worth of checks to the destination buffer.
; ========================================================================

plot_check_combos:
    str lr, [sp, #-4]!

    ldr r12, check_bitplane_0_line_combos_p
    adr r4, check_layer_x_pos
    adr r5, check_layer_z_pos
    mov r10, #0                 ; ab << 0
    bl plot_check_combo_layers

    ldr r12, check_bitplane_1_line_combos_p
    adr r4, check_layer_x_pos + Check_Layers_per_bitplane*4
    adr r5, check_layer_z_pos + Check_Layers_per_bitplane*4
    .if Check_Layers_per_bitplane == 4
    mov r10, #0x08              ; 1abc
    .else
    mov r10, #0x02              ; ab << 2
    .endif
    bl plot_check_combo_layers

    ldr pc, [sp], #4

; R4=ptr to layer x pos table.
; R5=ptr to layer z pos table.
; R10=PF mask.
; R12=ptr to destination buffer for combo lines.
plot_check_combo_layers:
    str lr, [sp, #-4]!
    str r4, check_combos_x_table
    str r5, check_combos_z_table
    str r10, check_combos_pf_mask

    ; For each layer, plot appropriate line 2^N times.
    mov r11, #0
.2:
    ; R9=check row src.
    ; Compute from x and z for layer.
    ldr r4, check_combos_x_table
    ldr r0, [r4, r11, lsl #2]           ; [16.16]
    mov r0, r0, lsr #16                 ; [16.0]

    and r2, r0, #7                      ; pixel shift [0-7]
    bic r0, r0, #7                      ; word shift

    adr r9, check_rows_table
    ldr r9, [r9, r2, lsl #2]            ; select check rows for shift 
    add r9, r9, r0, lsr #1              ; X word

    ldr r5, check_combos_z_table
    ldr r1, [r5, r11, lsl #2]           ; [16.16]
    mov r1, r1, lsr #16

    ; Add Rows_Width * z_pos
    .if Rows_Width_Bytes == 512
    add r9, r9, r1, lsl #9              ; z * 512
    .else
    .error "Expected Rows_Width_Bytes to be 512."
    .endif

    ; Convert layer number into colour word.
    ; R10=colour word.
    add r10, r11, #1                     ; colour = layer+1
    ; Insert PF mask.
    ldr r0, check_combos_pf_mask
    .if Check_Layers_per_bitplane == 4
    orr r10, r10, r0                     ; 1abc
    .else
    mov r10, r10, lsl r0                 ; abxx or xxab
    .endif
    ; Convert into colour word.
    orr r10, r10, r10, lsl #4
    orr r10, r10, r10, lsl #8
    orr r10, r10, r10, lsl #16

    ; Plots the 2^N combo lines for layer R11 from R9 to R12 in colour R10.
    adr r8, plot_layer_fns
    adr lr, .3
    ldr pc, [r8, r11, lsl #2]       ; was bl plot_check_combo_lines
    .3:
    ; Trashes: r0-r7, r11
    
    ; Reset destination buffer ptr R12.
    sub r12, r12, #Screen_Stride

    ; Next layer.
    add r11, r11, #1
    cmp r11, #Check_Layers_per_bitplane
    blt .2

    ldr pc, [sp], #4

check_combos_pf_mask:
    .long 0

check_combos_x_table:
    .long 0

check_combos_z_table:
    .long 0


; ========================================================================
; Plot all checks to the screen based on the Y position for each
; layer. For each scanline we maintain the y value within each layer
; and therefore the 'parity' of the check. Given the parity of all
; layers we select which of the 2^N check combo lines to copy to the
; screen.
; ========================================================================
; 
calculate_scanline_bitmasks:
    str lr, [sp, #-4]!

    ; Need 6x registers for y pos.
    adr r14, check_layer_y_pos
    ldmia r14, {r0-r5}          ; r0-r5 = ypos

    ; Need 6x registers for dx.
    adr r12, check_layer_z_pos
    ldr r14, check_depths_dx_p

    ldmia r12!, {r6-r11}            ; r6-r11 = zpos

    mov r6, r6, lsr #16
    ldr r6, [r14, r6, lsl #2]      ; r6=dx for layer 0 at zpos
    mov r7, r7, lsr #16
    ldr r7, [r14, r7, lsl #2]      ; r7=dx for layer 1 at zpos
    mov r8, r8, lsr #16
    ldr r8, [r14, r8, lsl #2]      ; r8=dx for layer 2 at zpos
    mov r9, r9, lsr #16
    ldr r9, [r14, r9, lsl #2]      ; r9=dx for layer 3 at zpos
    mov r10, r10, lsr #16
    ldr r10, [r14, r10, lsl #2]    ; r10=dx for layer 4 at zpos
    mov r11, r11, lsr #16
    ldr r11, [r14, r11, lsl #2]    ; r11=dx for layer 5 at zpos
    
    ; 1x register for scanline counter - combine ?
    ; 1x register for bitmask           |
    mov r14, #0                      ; bitmask & scanline counter!!
    subs r0, r0, r6, lsl #7          ; y -= 128*dx
    bpl .1
.11:
    adds r0, r0, #Check_Size_Pixels<<16  
    eor r14, r14, #1 << 0
    bmi .11
.1:
    cmp r0, #Check_Size_Pixels<<16
    subge r0, r0, #Check_Size_Pixels<<16
    eorge r14, r14, #1 << 0
    bge .1

.if Check_Layers_per_bitplane == 4
    ; SELF MOD! Poke R6 constant into loop...
    strb r6, .60
    mov r6, r6, lsr #8
    strb r6, .61
    mov r6, r6, lsr #8
    strb r6, .62
.endif

    subs r1, r1, r7, lsl #7          ; y -= 128*dx
    bpl .2
.12:
    adds r1, r1, #Check_Size_Pixels<<16  
    eor r14, r14, #1 << 1
    bmi .12
.2:
    cmp r1, #Check_Size_Pixels<<16
    subge r1, r1, #Check_Size_Pixels<<16
    eorge r14, r14, #1 << 1
    bge .2

.if Check_Layers_per_bitplane == 4
    ; SELF MOD! Poke R7 constant into loop...
    strb r7, .70
    mov r7, r7, lsr #8
    strb r7, .71
    mov r7, r7, lsr #8
    strb r7, .72
.endif

    subs r2, r2, r8, lsl #7          ; y -= 128*dx
    bpl .3
.13:
    adds r2, r2, #Check_Size_Pixels<<16  
    eor r14, r14, #1 << 2
    bmi .13
.3:
    cmp r2, #Check_Size_Pixels<<16
    subge r2, r2, #Check_Size_Pixels<<16
    eorge r14, r14, #1 << 2
    bge .3

.if Check_Layers_per_bitplane == 4
    ; SELF MOD! Poke R8 constant into loop...
    strb r8, .80
    mov r8, r8, lsr #8
    strb r8, .81
    mov r8, r8, lsr #8
    strb r8, .82
.endif

    subs r3, r3, r9, lsl #7          ; y -= 128*dx
    bpl .4
.14:
    adds r3, r3, #Check_Size_Pixels<<16  
    eor r14, r14, #1 << 3
    bmi .14
.4:
    cmp r3, #Check_Size_Pixels<<16
    subge r3, r3, #Check_Size_Pixels<<16
    eorge r14, r14, #1 << 3
    bge .4

.if Check_Layers_per_bitplane == 4
    ; SELF MOD! Poke R9 constant into loop...
    strb r9, .90
    mov r9, r9, lsr #8
    strb r9, .91
    mov r9, r9, lsr #8
    strb r9, .92
.endif

    subs r4, r4, r10, lsl #7          ; y -= 128*dx
    bpl .5
.15:
    adds r4, r4, #Check_Size_Pixels<<16  
    eor r14, r14, #1 << 4
    bmi .15
.5:
    cmp r4, #Check_Size_Pixels<<16
    subge r4, r4, #Check_Size_Pixels<<16
    eorge r14, r14, #1 << 4
    bge .5

    subs r5, r5, r11, lsl #7          ; y -= 128*dx
    bpl .6
.16:
    adds r5, r5, #Check_Size_Pixels<<16  
    eor r14, r14, #1 << 5
    bmi .16
.6:
    cmp r5, #Check_Size_Pixels<<16
    subge r5, r5, #Check_Size_Pixels<<16
    eorge r14, r14, #1 << 5
    bge .6

.if Check_Layers_per_bitplane == 4
    ; Need 2x registers for z pos.
    ldmia r12, {r8-r9}              ; r8-r9 = zpos

    ; Can trash R12 now!
    ldr r12, check_depths_dx_p

    mov r8, r8, lsr #16
    ldr r8, [r12, r8, lsl #2]       ; r8=dx for layer 6 at zpos
    mov r9, r9, lsr #16
    ldr r9, [r12, r9, lsl #2]       ; r9=dx for layer 7 at zpos

    ; Need 2x registers for y pos.
    adr r12, check_layer_y_pos + 6*4
    ldmia r12, {r6-r7}              ; r6-r7 = ypos

    subs r6, r6, r8, lsl #7          ; y -= 128*dx
    bpl .8
.18:
    adds r6, r6, #Check_Size_Pixels<<16  
    eor r14, r14, #1 << 6
    bmi .18
.8:
    cmp r6, #Check_Size_Pixels<<16
    subge r6, r6, #Check_Size_Pixels<<16
    eorge r14, r14, #1 << 6
    bge .8

    subs r7, r7, r9, lsl #7          ; y -= 128*dx
    bpl .9
.19:
    adds r7, r7, #Check_Size_Pixels<<16  
    eor r14, r14, #1 << 7
    bmi .19
.9:
    cmp r7, #Check_Size_Pixels<<16
    subge r7, r7, #Check_Size_Pixels<<16
    eorge r14, r14, #1 << 7
    bge .9
.endif

    ; 1x register for address to write bitmask.
    ldr r12, check_scanline_bitmask_p

    ; Scanline counter is top halfword of r14.
.7:
    str r14, [r12], #4           ; store parity bitmask to table.

    ; Update all the running y positions per scanline...
.if Check_Layers_per_bitplane == 4
    .60:
    add r0, r0, #0xff << 0
    .61:
    add r0, r0, #0xff << 8
    .62:
    add r0, r0, #0xff << 16
.else
    add r0, r0, r6              ; y_pos += dx
.endif
    cmp r0, #Check_Size_Pixels<<16
    subge r0, r0, #Check_Size_Pixels<<16
    eorge r14, r14, #1 << 0

.if Check_Layers_per_bitplane == 4
    .70:
    add r1, r1, #0xff << 0
    .71:
    add r1, r1, #0xff << 8
    .72:
    add r1, r1, #0xff << 16
.else
    add r1, r1, r7              ; y_pos += dx
.endif
    cmp r1, #Check_Size_Pixels<<16
    subge r1, r1, #Check_Size_Pixels<<16
    eorge r14, r14, #1 << 1

.if Check_Layers_per_bitplane == 4
    .80:
    add r2, r2, #0xff << 0
    .81:
    add r2, r2, #0xff << 8
    .82:
    add r2, r2, #0xff << 16
.else
    add r2, r2, r8              ; y_pos += dx
.endif
    cmp r2, #Check_Size_Pixels<<16
    subge r2, r2, #Check_Size_Pixels<<16
    eorge r14, r14, #1 << 2

.if Check_Layers_per_bitplane == 4
    .90:
    add r3, r3, #0xff << 0
    .91:
    add r3, r3, #0xff << 8
    .92:
    add r3, r3, #0xff << 16
.else
    add r3, r3, r9              ; y_pos += dx
.endif
    cmp r3, #Check_Size_Pixels<<16
    subge r3, r3, #Check_Size_Pixels<<16
    eorge r14, r14, #1 << 3

    add r4, r4, r10             ; y_pos += dx
    cmp r4, #Check_Size_Pixels<<16
    subge r4, r4, #Check_Size_Pixels<<16
    eorge r14, r14, #1 << 4

    add r5, r5, r11             ; y_pos += dx
    cmp r5, #Check_Size_Pixels<<16
    subge r5, r5, #Check_Size_Pixels<<16
    eorge r14, r14, #1 << 5

.if Check_Layers_per_bitplane == 4
    add r6, r6, r8              ; y_pos += dx
    cmp r6, #Check_Size_Pixels<<16
    subge r6, r6, #Check_Size_Pixels<<16
    eorge r14, r14, #1 << 6

    add r7, r7, r9              ; y_pos += dx
    cmp r7, #Check_Size_Pixels<<16
    subge r7, r7, #Check_Size_Pixels<<16
    eorge r14, r14, #1 << 7
.endif

    ; Next scanline.
    add r14, r14, #1<<16
    cmp r14, #Screen_Height<<16
    blt .7

    ldr pc, [sp], #4

plot_checks_to_screen:
    str lr, [sp, #-4]!

    ; Now blit everything to the screen.
    mov r11, #0                 ; scanline.
.8:
    ldr r9, check_bitplane_1_line_combos_p
    sub r8, r9, #Screen_Stride * Check_Line_Combos

    ldr r10, check_scanline_bitmask_p
    ldr r7, [r10, r11, lsl #2]  ; parity bitmask
    mov r0, r7, lsr #Check_Layers_per_bitplane
    and r0, r0, #Check_Line_Combos-1

    .if Screen_Stride == 160
    add r9, r9, r0, lsl #7  ; + parity word * 128
    add r9, r9, r0, lsl #5  ; + parity word * 32
    .else
    .error "Expected Screen_Stride to be 160."
    .endif

    and r7, r7, #Check_Line_Combos-1
    add r8, r8, r7, lsl #7  ; + parity word * 128
    add r8, r8, r7, lsl #5  ; + parity word * 32

.if Check_Layers_per_bitplane == 4
    ldr r10, check_bitplane_mask
.endif

    ; 'Blit' to screen from r9 to r12.
.rept Screen_Stride / 16
    ldmia r9!, {r0-r3}      ; load 4 words of top layers (top bits set, so 0b11aa11bb11cc...)
    ; 8c
    ldmia r8!, {r4-r7}      ; load 4 words of bottom layers
    ; 8c
.if Check_Layers_per_bitplane == 4
    bic r14, r0, r10
    orr r14, r14, r14, lsr #1
    orr r14, r14, r14, lsr #2    ; turns r0 into a mask in r14
    bic r4, r4, r14         ; mask out pixels from bottom layer
    orr r4, r4, r0          ; mask in pixels from top layer

    bic r14, r1, r10
    orr r14, r14, r14, lsr #1
    orr r14, r14, r14, lsr #2    ; turns r1 into a mask in r14
    bic r5, r5, r14         ; mask out pixels from bottom layer
    orr r5, r5, r1          ; mask in pixels from top layer

    bic r14, r2, r10
    orr r14, r14, r14, lsr #1
    orr r14, r14, r14, lsr #2    ; turns r2 into a mask in r14
    bic r6, r6, r14         ; mask out pixels from bottom layer
    orr r6, r6, r2          ; mask in pixels from top layer

    bic r14, r3, r10
    orr r14, r14, r14, lsr #1
    orr r14, r14, r14, lsr #2    ; turns r3 into a mask in r14
    bic r7, r7, r14         ; mask out pixels from bottom layer
    orr r7, r7, r3          ; mask in pixels from top layer
.else
    orr r4, r4, r0          ; mask in pixels from top layer
    orr r5, r5, r1          ; mask in pixels from top layer
    orr r6, r6, r2          ; mask in pixels from top layer
    orr r7, r7, r3          ; mask in pixels from top layer
.endif
    ; 4c
    stmia r12!, {r4-r7}
    ; 8c
.endr
    ; Trashes r0-r7 (r11, r14)

    ; Next scanline.
    add r11, r11, #1
    cmp r11, #Screen_Height
    bne .8

    ldr pc, [sp], #4

check_scanline_bitmask_p:
    .long check_scanline_bitmask_no_adr

.if Check_Layers_per_bitplane == 4
check_bitplane_mask:
    .long 0x77777777        ; TODO: Just mov #imm this.
.endif

; ========================================================================

; R12=scr bank.
check_layers_set_colours:
    str lr, [sp, #-4]!

    ldr r8, palette_blocks_p
    add r8, r8, r12, lsl #6     ; scr_bank * 64.
;    str r8, palette_block_addr

    adr r9, check_layer_colour
    mov r11, #0
.1:
    ldr r4, [r9], #4        ; 0x0BGR

.if Check_Layers_per_bitplane == 4
    ; Map layer no. to index 1,2,3,4,9,10,11,12
    add r3, r11, #1         ; index = layer + 1
    cmp r11, #0x4           ; top layer?
    addge r3, r3, #4
    orr r4, r4, r3, lsl #26 ; VIDC register = index << 26 | bgr
    str r4, [r8], #4        ; store VIDC register.
.else
    ; Map layer no. to index 1,2,3,[4,5,6,7],[8,9,10,11],[12,13,14,15]
    cmp r11, #0x3
    blt .2

    sub r3, r11, #2         ; 1,2,3
    mov r3, r3, lsl #2      ; 4,8,12 ; base index
    mov r10, #0
.3:
    bic r4, r4, #0xff000000
    bic r3, r3, #0x3
    orr r3, r3, r10
    orr r4, r4, r3, lsl #26 ; VIDC register = index << 26 | bgr
    str r4, [r8], #4        ; store VIDC register.

    add r10, r10, #1
    cmp r10, #4
    blt .3
    b .4

.2:
    add r3, r11, #1         ; index = layer + 1
    orr r4, r4, r3, lsl #26 ; VIDC register = index << 26 | bgr
    str r4, [r8], #4        ; store VIDC register.
.4:
.endif

    add r11, r11, #1
    cmp r11, #Check_Total_Layers
    blt .1

.if Check_Layers_per_bitplane == 4
    mov r0, #-1
    str r0, [r8]            ; end of VIDC regs.
.endif

    ldr pc, [sp], #4

palette_blocks_p:
    .long palette_blocks_for_banks_no_adr - 64

; ========================================================================

update_check_layers:
    str lr, [sp, #-4]!

    ; TODO: A less long-hand way of achieving this.
    .if _ENABLE_ROCKET
    .set _layer, 0
    .rept Check_Total_Layers
    .set _track_base, _layer * 4
    mov r0, #_track_base + 0
    bl rocket_sync_get_val
    str r1, check_world_x_pos + _track_base

    mov r0, #_track_base + 1
    bl rocket_sync_get_val
    str r1, check_world_y_pos + _track_base

    mov r0, #_track_base + 2
    bl rocket_sync_get_val
    str r1, check_world_z_pos + _track_base

    ; TODO: Layer colour in _track_base + 3
    .set _layer, _layer + 1
    .endr
    .endif

    ; Convert world coordinates to camera relative positions.
    ; TODO: Use vector lib?

    ldr r0, camera_x_pos
    ldr r1, camera_y_pos
    ldr r2, camera_z_pos

    ; Find furthest checkerboard.
    adr r8, check_world_params + 8     ; z pos.
    mov r9, #0                  ; index.
    mov r10, #0                 ; max depth.
    mov r11, #0                 ; counter.
.1:
    ldr r5, [r8, r11, lsl #4]    ; check world z pos.
    subs r5, r5, r2              ; camera z pos.
    addmi r5, r5, #Check_Num_Depths<<16
    cmp r5, r10
    movgt r10, r5
    movgt r9, r11
    add r11, r11, #1
    cmp r11, #Check_Total_Layers
    blt .1

    adr r10, check_layer_x_pos
    adr r12, check_layer_y_pos
    adr r14, check_layer_z_pos
    adr r7, check_layer_colour

    adr r8, check_world_params
    add r8, r8, r9, lsl #4      ; &check_world_params[r9]

    ; r9 = index of furthest layer
    mov r11, #0                 ; counter.
.2:
    ldmia r8!, {r3-r6}           ; world x, y, z, colour

    ; Make X relative
    .if 0
    sub r3, r3, r0
    add r3, r3, #Rows_Centre_Left_Edge << 16
    .else
    mov r0, r5, lsr #9              ; depth / 512
    stmfd sp!, {r9, r14}            ; TODO: Register pressure.
    bl sine
    ; R0 = sin(2 * PI * depth / 512)                [s1.16]
    mov r9, #192
    mul r3, r0, r9
    ldr r0, camera_x_pos
    sub r3, r3, r0
    add r3, r3, #Rows_Centre_Left_Edge << 16        ; layer x (in screen pixels) = left_edge + 192 * sin(a)

    ldmfd sp!, {r9, r14}
    .endif

    ; Make Y relative
    .if 0
    sub r4, r4, r1
    add r4, r4, #Layer_Centre_Top_Edge << 16
    .else
    mov r0, r5, lsr #7              ; depth / 512
    stmfd sp!, {r9, r14}            ; TODO: Register pressure.
    bl cosine
    ; R0 = cos(2 * PI * depth / 512)                [s1.16]
    mov r9, #192
    mul r0, r9, r0
    add r0, r0, r1
    add r0, r0, #Layer_Centre_Top_Edge << 16        ; y in screen pixels = top_edge + 192 * cos(a)

    ; Make Z relative
    subs r5, r5, r2
    addmi r5, r5, #Check_Num_Depths<<16

    ; Convert screen pixel offset into check pixel offset at depth.
    ldr r14, check_depths_dx_p
    mov r9, r5, lsr #16
    ldr r9, [r14, r9, lsl #2]       ; r9=dx for layer at depth        [5.16]
    mov r0, r0, asr #8              ; [s9.8]
    mov r9, r9, asr #8              ; [s5.8]
    mul r4, r0, r9                  ; layer y (in check pixels) = dxn * sy  [s14.16]

    ldmfd sp!, {r9, r14}
    .endif

    ; TODO: Fade colour based on depth.

    str r3, [r10, r11, lsl #2]      ; store relative x pos.
    str r4, [r12, r11, lsl #2]      ; store relative y pos.
    str r5, [r14, r11, lsl #2]      ; store relative z pos.
    str r6, [r7, r11, lsl #2]       ; store relative colour.

    add r9, r9, #1
    cmp r9, #Check_Total_Layers
    movge r9, #0
    adrge r8, check_world_params    ; &check_world_params[0]

    add r11, r11, #1
    cmp r11, #Check_Total_Layers
    blt .2

    ; Move camera!
    add r2, r2, #1<<16
    cmp r2, #Check_Num_Depths<<16
    subge r2, r2, #Check_Num_Depths<<16
    str r2, camera_z_pos

    ldr r0, camera_frame
    add r0, r0, #1<<16
    str r0, camera_frame

.if 1
    mov r1, r0
    mov r0, r0, lsr #10          ; camera_frame / 512
    bl cosine
    ; R0 = sin(2 * PI * camera_frame / 512)
    mov r9, #160
    mul r0, r9, r0
    str r0, camera_y_pos

    mov r0, r1, lsr #10          ; camera_frame / 512
    bl sine
    ; R0 = sin(2 * PI * camera_frame / 512)
    mov r9, #160
    mul r0, r9, r0
    str r0, camera_x_pos
.endif

    ldr pc, [sp], #4

camera_frame:
    .long 0

; ========================================================================
; Camera relative X, Y, Z positions for each layer.
; ========================================================================

check_layer_x_pos:
    .long 96 << 16
    .long 96 << 16
    .long 96 << 16
    .long 96 << 16
    .long 96 << 16
    .long 96 << 16
    .long 96 << 16
    .long 96 << 16

check_layer_y_pos:
    .long 160 << 16
    .long 160 << 16
    .long 160 << 16
    .long 160 << 16
    .long 160 << 16
    .long 160 << 16
    .long 160 << 16
    .long 160 << 16

check_layer_z_pos:
    .long 511 << 16
    .long 256 << 16
    .long 128 << 16
    .long 96 << 16
    .long 64 << 16
    .long 32 << 16
    .long 16 << 16
    .long 8 << 16

check_layer_colour:
    .long 0xfff
    .long 0xfff
    .long 0xfff
    .long 0xfff
    .long 0xfff
    .long 0xfff
    .long 0xfff
    .long 0xfff

; ========================================================================
; World positions of camera & checkerboards.
; ========================================================================

camera_x_pos:
    .long 0 << 16

camera_y_pos:
    .long 0 << 16

camera_z_pos:
    .long 0 << 16

check_world_params:
    .long 0 << 16, 0 << 16, 448 << 16, 0x00f
    .long 0 << 16, 0 << 16, 384 << 16, 0x0f0
    .long 0 << 16, 0 << 16, 320 << 16, 0x0ff
    .long 0 << 16, 0 << 16, 256 << 16,  0xf00
    .long 0 << 16, 0 << 16, 128 << 16,  0xf0f
    .long 0 << 16, 0 << 16, 64 << 16,  0xff0
    .long 0 << 16, 0 << 16, 32 << 16,  0x808
    .long 0 << 16, 0 << 16, 0 << 16,   0x880

; ========================================================================

plot_layer_fns:
    .long plot_layer_0_check_lines
    .long plot_layer_1_check_lines
    .long plot_layer_2_check_lines
.if Check_Layers_per_bitplane == 4
    .long plot_layer_3_check_lines
.endif

; R9=check row source.
; R10=colour word.
; R12=dest line buffer.
; Trashes: r0-r7, r8
.p2align 6
plot_layer_0_check_lines:
.rept Screen_Stride / 32
    ldmia r9!, {r0-r7}      ; load 4 words of source (all bits set for a pixel, so 0xabcdefg where each=0x0 or 0xf)
    and r0, r0, r10        ; mask colour with source word
    and r1, r1, r10        ; mask colour with source word
    and r2, r2, r10        ; mask colour with source word
    and r3, r3, r10        ; mask colour with source word
    and r4, r4, r10        ; mask colour with source word
    and r5, r5, r10        ; mask colour with source word
    and r6, r6, r10        ; mask colour with source word
    and r7, r7, r10        ; mask colour with source word

    stmia r12, {r0-r7}      ; +0
    add r8, r12, #Screen_Stride*2
    stmia r8, {r0-r7}       ; +2
    add r8, r8, #Screen_Stride*2
    stmia r8, {r0-r7}       ; +4
    add r8, r8, #Screen_Stride*2
    stmia r8, {r0-r7}       ; +6
    .if Check_Layers_per_bitplane == 4
    add r8, r8, #Screen_Stride*2
    stmia r8, {r0-r7}       ; +8
    add r8, r8, #Screen_Stride*2
    stmia r8, {r0-r7}       ; +10
    add r8, r8, #Screen_Stride*2
    stmia r8, {r0-r7}       ; +12
    add r8, r8, #Screen_Stride*2
    stmia r8, {r0-r7}       ; +14
    .endif

    eor r0, r0, r10         ; invert colour bits
    eor r1, r1, r10         ; invert colour bits
    eor r2, r2, r10         ; invert colour bits
    eor r3, r3, r10         ; invert colour bits
    eor r4, r4, r10         ; invert colour bits
    eor r5, r5, r10         ; invert colour bits
    eor r6, r6, r10         ; invert colour bits
    eor r7, r7, r10         ; invert colour bits

    add r8, r12, #Screen_Stride
    stmia r8, {r0-r7}       ; +1
    add r8, r8, #Screen_Stride*2
    stmia r8, {r0-r7}       ; +3
    add r8, r8, #Screen_Stride*2
    stmia r8, {r0-r7}       ; +5
    add r8, r8, #Screen_Stride*2
    stmia r8, {r0-r7}       ; +7
    .if Check_Layers_per_bitplane == 4
    add r8, r8, #Screen_Stride*2
    stmia r8, {r0-r7}       ; +9
    add r8, r8, #Screen_Stride*2
    stmia r8, {r0-r7}       ; +11
    add r8, r8, #Screen_Stride*2
    stmia r8, {r0-r7}       ; +13
    add r8, r8, #Screen_Stride*2
    stmia r8, {r0-r7}       ; +15
    .endif
    add r12, r12, #32
.endr
    mov pc, lr

.macro plot_layer_16_bytes
    ldmia r12, {r4-r7}      ; load 4 words of screen
    bic r4, r4, r0          ; mask out screen pixels to be written
    and r8, r0, r10         ; mask colour with source word
    orr r4, r4, r8          ; mask in colour word
    bic r5, r5, r1          ; mask out screen pixels to be written
    and r8, r1, r10         ; mask colour with source word
    orr r5, r5, r8          ; mask in colour word
    bic r6, r6, r2          ; mask out screen pixels to be written
    and r8, r2, r10         ; mask colour with source word
    orr r6, r6, r8          ; mask in colour word
    bic r7, r7, r3          ; mask out screen pixels to be written
    and r8, r3, r10         ; mask colour with source word
    orr r7, r7, r8          ; mask in colour word
    stmia r12, {r4-r7}      ; write 4 words back to screen
.endm

plot_layer_1_check_lines:
.rept Screen_Stride / 16
    ldmia r9!, {r0-r3}      ; load 4 words of source (all bits set for a pixel, so 0xabcdefg where each=0x0 or 0xf)

    ; +0
    plot_layer_16_bytes

    ; +1
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +4
    add r12, r12, #Screen_Stride * 3
    plot_layer_16_bytes

    ; +5
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    .if Check_Layers_per_bitplane == 4
    ; +8
    add r12, r12, #Screen_Stride * 3
    plot_layer_16_bytes

    ; +9
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +12
    add r12, r12, #Screen_Stride * 3
    plot_layer_16_bytes

    ; +13
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes
    .endif

    mov r8, #0xffffffff
    eor r0, r0, r8         ; invert source bits
    eor r1, r1, r8         ; invert source bits
    eor r2, r2, r8         ; invert source bits
    eor r3, r3, r8         ; invert source bits

    ; +2
    .if Check_Layers_per_bitplane == 4
    sub r12, r12, #Screen_Stride * 11
    .else
    sub r12, r12, #Screen_Stride * 3
    .endif
    plot_layer_16_bytes

    ; +3
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +6
    add r12, r12, #Screen_Stride * 3
    plot_layer_16_bytes

    ; +7
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    .if Check_Layers_per_bitplane == 4
    ; +10
    add r12, r12, #Screen_Stride * 3
    plot_layer_16_bytes

    ; +11
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +14
    add r12, r12, #Screen_Stride * 3
    plot_layer_16_bytes

    ; +15
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +0
    sub r12, r12, #Screen_Stride * 15 - 16
    .else
    sub r12, r12, #Screen_Stride * 7 - 16
    .endif
.endr
    mov pc, lr

plot_layer_2_check_lines:
.rept Screen_Stride / 16
    ldmia r9!, {r0-r3}      ; load 4 words of source (all bits set for a pixel, so 0xabcdefg where each=0x0 or 0xf)

    ; +0
    plot_layer_16_bytes

    ; +1
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +2
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +3
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    .if Check_Layers_per_bitplane == 4
    ; +8
    add r12, r12, #Screen_Stride * 5
    plot_layer_16_bytes

    ; +9
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +10
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +11
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes
    .endif

    mov r8, #0xffffffff
    eor r0, r0, r8         ; invert source bits
    eor r1, r1, r8         ; invert source bits
    eor r2, r2, r8         ; invert source bits
    eor r3, r3, r8         ; invert source bits

    ; +4
    .if Check_Layers_per_bitplane == 4
    sub r12, r12, #Screen_Stride * 7
    .else
    add r12, r12, #Screen_Stride
    .endif
    plot_layer_16_bytes

    ; +5
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +6
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +7
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    .if Check_Layers_per_bitplane == 4
    ; +12
    add r12, r12, #Screen_Stride * 5
    plot_layer_16_bytes

    ; +13
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +14
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +15
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +0
    sub r12, r12, #Screen_Stride * 15 - 16
    .else
    sub r12, r12, #Screen_Stride * 7 - 16
    .endif
.endr
    mov pc, lr

.if Check_Layers_per_bitplane == 4
plot_layer_3_check_lines:
.rept Screen_Stride / 16
    ldmia r9!, {r0-r3}      ; load 4 words of source (all bits set for a pixel, so 0xabcdefg where each=0x0 or 0xf)

    ; +0
    plot_layer_16_bytes

    ; +1
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +2
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +3
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +4
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +5
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +6
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +7
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    mov r8, #0xffffffff
    eor r0, r0, r8         ; invert source bits
    eor r1, r1, r8         ; invert source bits
    eor r2, r2, r8         ; invert source bits
    eor r3, r3, r8         ; invert source bits

    ; +8
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +9
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +10
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +11
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +12
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +13
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +14
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +15
    add r12, r12, #Screen_Stride
    plot_layer_16_bytes

    ; +0
    sub r12, r12, #Screen_Stride * 15 - 16
.endr
    mov pc, lr
.endif
