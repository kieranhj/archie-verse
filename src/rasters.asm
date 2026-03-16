; ============================================================================
; Rasters via RasterMan.
; ============================================================================

.equ Dj3_Adjust,    -2

raster_table_p:
    .long vidc_table_1_no_adr

raster_tables:
	.long vidc_table_1_no_adr
	.long vidc_table_2_no_adr
	.long vidc_table_3_no_adr
	.long -1

rasters_default:
    .long VIDC_Col15 | 0xddd    ; VIDC_Border | 0x000

; ============================================================================

rasters_init:
    ; Configure RasterMan for future compatibility.
    mov r0, #16              ; number of VIDC reg writes
    mov r1, #0              ; number of MEMC reg writes
    mov r2, #1              ; number of scanlines between H-interrupts
    swi RasterMan_Configure

	; Init tables.
	adr r5, raster_tables
	ldmia r5, {r0-r3}
	stmfd sp!, {r0-r3}

	mov r4, #0
    ldr r6, rasters_default
	mov r7, r6
	mov r8, r6
	mov r9, r6
	mov r5, #256
.1:
	stmia r0!, {r6-r9}		        ; 4x VIDC commands per line.
	stmia r1!, {r6-r9}		        ; 4x VIDC commands per line.
	stmia r2!, {r6-r9}		        ; 4x VIDC commands per line.
	stmia r2!, {r6-r9}		        ; 4x VIDC commands per line.
    ; NB. No longer need to fill redundant buffers.
	subs r5, r5, #1
	bne .1

	ldmfd sp, {r0-r3}
	swi RasterMan_SetTables
	ldmfd sp!, {r0-r3}              ; R0=array base

    ; Make a raster table.
    mov r3, #0
    adr r10, raster_list
.2:
    ldmia r10!, {r1, r2, r5-r8}     ; R1=slot, R2=scanline, R5=repeat, R6=reg, R7=start, R8=delta
    cmp r1, #-1
    moveq pc, lr

    add r2, r0, r2, lsl #4          ; base[scanline]
    add r2, r2, r1, lsl #2          ; base[scanline][slot]

.3:
    ; Construct VIDC reg
    mov r9, r7, lsr #4
    and r9, r9, #0xf        ; red
    mov r4, r7, lsr #12
    and r4, r4, #0xf        ; green
    orr r9, r9, r4, lsl #4  ; GR
    mov r4, r7, lsr #20
    and r4, r4, #0xf        ; blue
    orr r9, r9, r4, lsl #8  ; BGR
    orr r9, r9, r6          ; VIDC_reg | BGR

    ; Store reg.
    str r9, [r2], #16

    add r7, r7, r8
    subs r5, r5, #1
    bne .3

    b .2

.if 0
rasters_tick:
	adr r5, raster_tables
	ldmia r5, {r0-r3}

    ldr r4, raster_table_p
    ldr r6, raster_table_top_p
    add r4, r4, #16             ; step 4 writes = one line
    cmp r4, r6
    movge r4, r0                ; reset to base
    str r4, raster_table_p
    mov r0, r4

    ; Update table pointers.
	swi RasterMan_SetTables
    mov pc, lr
.endif

.macro rgb12_sub reg
    tst \reg, #0x000f
    subne \reg, \reg, #0x0001
    tst \reg, #0x00f0
    subne \reg, \reg, #0x0010
    tst \reg, #0x0f00
    subne \reg, \reg, #0x0100
.endm

rasters_sub_all_to_zero:
	; Init tables.
	adr r5, raster_tables
	ldmia r5, {r0-r3}

    mov r12, #256*4
.1:
    ; Read VIDC reg write.
    ldr r4, [r0]
    rgb12_sub r4
    str r4, [r0], #4

    ldr r4, [r1]
    rgb12_sub r4
    str r4, [r1], #4

    ldr r4, [r2]
    rgb12_sub r4
    str r4, [r2], #4

    ldr r4, [r2]
    rgb12_sub r4
    str r4, [r2], #4

    subs r12, r12, #1
    bne .1

    mov pc, lr

; ============================================================================

.if 1
; R0=ptr to rgb4 array (16 entries)
; R3=ptr to vidc array
; Trashes: R1, R7, R8, R9
rasters_rgb4_pal_to_vidc:
    mov r1, #0                          ; index
.1:
    ldrb r7, [r0], #1                   ; 0x0r
    ldrb r8, [r0], #1                   ; 0xgb

    ; index<<26 | 0xbgr
    and r9, r8, #0xf0                   ; 0xg0
    orr r7, r7, r9                      ; 0xgr
    and r9, r8, #0x0f                   ; 0x0b
    orr r7, r7, r9, lsl #8              ; 0x0bgr
    orr r7, r7, r1, lsl #26             ; VIDC reg | 0x0bgr

    str r7, [r3], #4
    add r1, r1, #1
    cmp r1, #16
    blt .1
    mov pc, lr

; R0=ptr to abc pal (assumes 16 writes per line)
; R1=which scanline to start from
; R2=number of lines
; R3=initial vidc reg array
rasters_abc_pal_to_min_rasters:
    str lr, [sp, #-4]!
    str r1, [sp, #-4]!

    ; Make initial vidc reg list.
    mov r4, r3
    bl rasters_rgb4_pal_to_vidc

    ; Make a copy of that initial vidc list.
    mov r3, r4
    adr r4, rasters_abc_cur_vidc_line
    ldmia r3!, {r5-r12}
    stmia r4!, {r5-r12}
    ldmia r3!, {r5-r12}
    stmia r4!, {r5-r12}

    ; Pop start scanline.
    ldr r11, [sp], #4
    add r11, r11, #1                      ; skip first line as this will be set.

    ; Scanline loop.
    mov r12, #0                          ; max writes
.1:
	adr r3, raster_tables
	ldmia r3, {r4-r6}
    ; Offset into raster tables from starting scanline.
    add r4, r4, r11, lsl #4              ; skip N lines at 4 writes per line.
    add r5, r5, r11, lsl #4              ; skip N lines at 4 writes per line.
    add r6, r6, r11, lsl #5              ; skip N lines at 8 writes per line.

    ; Create vidc list for new line.
    adr r3, rasters_abc_new_vidc_line
    bl rasters_rgb4_pal_to_vidc

    ; Only write the registers that are different.
    adr r3, rasters_abc_cur_vidc_line
    adr r9, rasters_abc_new_vidc_line

    ; Palette index loop.
    mov r1, #0
    mov r10, #0                         ; num writes.
.2:
    ldr r8, [r3]                        ; cur reg
    ldr r7, [r9], #4                    ; new reg

    cmp r7, r8
    beq .3

    add r10, r10, #1

    ; Store reg.
    tst r10, #0b1100                   
    streq r7, [r4], #4
    beq .3
    tst r10, #0b1000
    streq r7, [r5], #4
    strne r7, [r6], #4

.3:
    str r7, [r3], #4                    ; cur reg=new reg

    add r1, r1, #1                      ; next index
    cmp r1, #16
    blt .2

    cmp r10, r12
    movgt r12, r10

    add r11, r11, #1                    ; next scanline
    subs r2, r2, #1
    bne .1
    
    ldr pc, [sp], #4

rasters_abc_cur_vidc_line:
    .skip 16*4

rasters_abc_new_vidc_line:
    .skip 16*4
.else
; Turn an abc palette-per-scanline table into VIDC registers for RasterMan:
; R0=ptr to abc pal (assumes 16 writes per line)
; R1=which scanline to start from
; R2=number of lines
rasters_abc_pal_to_rasters:
	adr r3, raster_tables
	ldmia r3, {r4-r6}
    ; Offset into raster tables from starting scanline.
    add r4, r4, r1, lsl #4              ; skip N lines at 4 writes per line.
    add r5, r5, r1, lsl #4              ; skip N lines at 4 writes per line.
    add r6, r6, r1, lsl #5              ; skip N lines at 8 writes per line.

    ; Scanline loop.
.1:

    ; Palette index loop.
    mov r1, #0
.2:
    ldrb r7, [r0], #1                   ; 0x0r
    ldrb r8, [r0], #1                   ; 0xgb

    ; index<<26 | 0xbgr

    and r9, r8, #0xf0                   ; 0xg0
    orr r7, r7, r9                      ; 0xgr
    and r9, r8, #0x0f                   ; 0x0b
    orr r7, r7, r9, lsl #8              ; 0x0bgr
    orr r7, r7, r1, lsl #26             ; VIDC reg | 0x0bgr

    tst r1, #0b1100                   
    streq r7, [r4], #4
    beq .3
    tst r1, #0b1000
    streq r7, [r5], #4
    strne r7, [r6], #4
    .3:

    add r1, r1, #1
    cmp r1, #16
    blt .2


    subs r2, r2, #1
    bne .1
    mov pc, lr
.endif

; ============================================================================

.if 0   ; if need to double-buffer raster table.
rasters_copy_table:
    adr r9, vidc_table_1
    adr r10, vidc_table_2
    adr r11, vidc_table_3

.1:
    ldmia r10!, {r0-r7}
    stmia r9!, {r0-r7}
    cmp r10, r11
    blt .1

    mov pc, lr
.endif

; ============================================================================

raster_list:
    ;     Slot  Scanline  Repeat    Reg,        Start       Delta
    ;                                           0xBbGgRr    0xBbGgRr
    .long 0,    0,        256,      VIDC_Col0,  0x000000,   0x000000
    .long 1,    0,        256,      VIDC_Border,0x000000,   0x000000

    .long 1,    81,       1,        VIDC_Col4,  0xffff00,   0x000000    ; menu item
    .long 2,    81,       1,        VIDC_Col8,  0x333333,   0x000000    ; menu selection

    .long 0,    VU_Bars_Y_Pos-VU_Bars_Gap,                  VU_Bars_Height,        VIDC_Col0,  0x330000,   0x000000
    .long 0,    VU_Bars_Y_Pos+1,                            VU_Bars_Height,        VIDC_Col0,  0x330000,   0x000000
    .long 0,    VU_Bars_Y_Pos+1+VU_Bars_Gap,                VU_Bars_Height,        VIDC_Col0,  0x330000,   0x000000
    .long 0,    VU_Bars_Y_Pos+1+VU_Bars_Gap+VU_Bars_Gap,    VU_Bars_Height,        VIDC_Col0,  0x330000,   0x000000

    .long 1,    VU_Bars_Y_Pos-VU_Bars_Gap,                  VU_Bars_Height,        VIDC_Border,  0x330000,   0x000000
    .long 1,    VU_Bars_Y_Pos+1,                            VU_Bars_Height,        VIDC_Border,  0x330000,   0x000000
    .long 1,    VU_Bars_Y_Pos+1+VU_Bars_Gap,                VU_Bars_Height,        VIDC_Border,  0x330000,   0x000000
    .long 1,    VU_Bars_Y_Pos+1+VU_Bars_Gap+VU_Bars_Gap,    VU_Bars_Height,        VIDC_Border,  0x330000,   0x000000

    .long 0,    Dj_Scroller_Y_Pos-4,      1,        VIDC_Col0,  0xffffff,   0x000000
    .long 0,    Dj_Scroller_Y_Pos+8,      1,        VIDC_Col0,  0x00bbcc,   0x000000
    .long 0,    Dj_Scroller_Y_Pos+9,      1,        VIDC_Col0,  0x0088aa,   0x000000
    .long 0,    Dj_Scroller_Y_Pos+10,      1,        VIDC_Col0,  0x004488,   0x000000
    .long 0,    Dj_Scroller_Y_Pos+11,      1,        VIDC_Col0,  0x001166,   0x000000
    .long 0,    Dj_Scroller_Y_Pos+12,      1,        VIDC_Col0,  0x000033,   0x000000
    .long 0,    Dj_Scroller_Y_Pos+13,      3,        VIDC_Col0,  0x000022,   0x000000
    .long 0,    Dj_Scroller_Y_Pos+15,      1,        VIDC_Col0,  0xffffff,   0x000000

    .long 1,    Dj_Scroller_Y_Pos-4,      1,        VIDC_Border,  0xffffff,   0x000000
    .long 1,    Dj_Scroller_Y_Pos+8,      1,        VIDC_Border,  0x00bbcc,   0x000000
    .long 1,    Dj_Scroller_Y_Pos+9,      1,        VIDC_Border,  0x0088aa,   0x000000
    .long 1,    Dj_Scroller_Y_Pos+10,      1,        VIDC_Border,  0x004488,   0x000000
    .long 1,    Dj_Scroller_Y_Pos+11,      1,        VIDC_Border,  0x001166,   0x000000
    .long 1,    Dj_Scroller_Y_Pos+12,      1,        VIDC_Border,  0x000033,   0x000000
    .long 1,    Dj_Scroller_Y_Pos+13,      3,        VIDC_Border,  0x000022,   0x000000
; NB. Need to fire interrupts on scanline 256 to do this!
   .long 1,    Dj_Scroller_Y_Pos+15,      1,        VIDC_Border,  0xffffff,   0x000000

    .long 2,    Dj_Scroller_Y_Pos,      16,       VIDC_Col8,  0xffffff,   0xfff0f0f0

; NB. Need to fire interrupts on scanline 256 to do this!
    .long 2,    Dj_Scroller_Y_Pos+16,      1,        VIDC_Col0,    0x000000,   0x000000
    .long 3,    Dj_Scroller_Y_Pos+16,      1,        VIDC_Border,  0x000000,   0x000000
    .long -1

    ; Looks like Bodo's Amiga screen is 258 lines long?

; ============================================================================
