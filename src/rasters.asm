; ============================================================================
; Rasters via RasterMan.
; ============================================================================

raster_table_p:
    .long vidc_table_1_no_adr

raster_table_top_p:
    .long vidc_table_1_no_adr+256*4*4

raster_tables:
	.long vidc_table_1_no_adr
	.long -1
	.long -1
	.long -1

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
	mov r6, #VIDC_Border | 0x000
	mov r7, r6
	mov r8, r6
	mov r9, r6
	mov r5, #256
.1:
	stmia r0!, {r6-r9}		; 4x VIDC commands per line.
	stmia r0!, {r6-r9}		; Double up as we're scrolling through the first buffer.
    ; NB. No longer need to fill redundant buffers.
	subs r5, r5, #1
	bne .1

	ldmfd sp, {r0-r3}
	swi RasterMan_SetTables
	ldmfd sp!, {r0-r3}

    ; Make a raster table.
    ldr r1, raster_table_top_p  ; dupe
    mov r3, #0
    adr r2, raster_list
.2:
    ldmia r2!, {r5-r8}      ; R5=repeat, R6=reg, R7=start, R8=delta
    cmp r5, #-1
    moveq pc, lr

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
    str r9, [r0], #16
    str r9, [r1], #16

    add r7, r7, r8
    subs r5, r5, #1
    bne .3

    b .2

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
    ;    Repeat    Reg,        Start       Delta
    .long 256,      VIDC_Col0,  0x000000,   0x000000
    .long -1

    ; TODO: Raster plan!

    .long 48,       VIDC_Col1,  0x0000ff,     0x000500
    .long 48,       VIDC_Col1,  0x00ffff,   0xfffffffb
    .long 32,       VIDC_Col1,  0x00ff00,     0x080000  ; make green shorter
    .long 32,       VIDC_Col1,  0xffff00,   0xfffff800  ; make green shorter
    .long 48,       VIDC_Col1,  0xff0000,     0x000005
    .long 48,       VIDC_Col1,  0xff00ff,   0xfffb0000
    .long -1

; ============================================================================
