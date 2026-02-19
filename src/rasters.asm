; ============================================================================
; Rasters via RasterMan.
; ============================================================================

raster_table_p:
    .long vidc_table_1_no_adr

raster_tables:
	.long vidc_table_1_no_adr
	.long -1
	.long -1
	.long -1

rasters_default:
    .long VIDC_Col15 | 0xddd    ; VIDC_Border | 0x000

; ============================================================================

rasters_init:
    ; Configure RasterMan for future compatibility.
    mov r0, #4              ; number of VIDC reg writes
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
	stmia r0!, {r6-r9}		; 4x VIDC commands per line.
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

    .long 0,    236,      1,        VIDC_Col0,  0xffffff,   0x000000
    .long 0,    248,      1,        VIDC_Col0,  0x00bbcc,   0x000000
    .long 0,    249,      1,        VIDC_Col0,  0x0088aa,   0x000000
    .long 0,    250,      1,        VIDC_Col0,  0x004488,   0x000000
    .long 0,    251,      1,        VIDC_Col0,  0x001166,   0x000000
    .long 0,    252,      1,        VIDC_Col0,  0x000033,   0x000000
    .long 0,    253,      3,        VIDC_Col0,  0x000022,   0x000000
    .long 0,    255,      1,        VIDC_Col0,  0xffffff,   0x000000

    .long 1,    236,      1,        VIDC_Border,  0xffffff,   0x000000
    .long 1,    248,      1,        VIDC_Border,  0x00bbcc,   0x000000
    .long 1,    249,      1,        VIDC_Border,  0x0088aa,   0x000000
    .long 1,    250,      1,        VIDC_Border,  0x004488,   0x000000
    .long 1,    251,      1,        VIDC_Border,  0x001166,   0x000000
    .long 1,    252,      1,        VIDC_Border,  0x000033,   0x000000
    .long 1,    253,      3,        VIDC_Border,  0x000022,   0x000000
; NB. Need to fire interrupts on scanline 256 to do this!
;   .long 1,    255,      1,        VIDC_Border,  0xffffff,   0x000000

    .long 2,    240,      16,       VIDC_Col8,  0xffffff,   0xfff0f0f0

; NB. Need to fire interrupts on scanline 256 to do this!
;   .long 2,    255,      1,        VIDC_Col0,    0x000000,   0x000000
    .long 3,    255,      1,        VIDC_Border,  0x000000,   0x000000
    .long -1

    ; Looks like Bodo's Amiga screen is 258 lines long?

; ============================================================================
