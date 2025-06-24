; ============================================================================
; Rasters via RasterMan.
; Hacked together for Megademo Donut part.
; ============================================================================

.equ RasterTable_Vidc1,     0
.equ RasterTable_Vidc2,     4
.equ RasterTable_Vidc3,     8
.equ RasterTable_Memc,      12

.equ RastersDonut_PaletteLine,  55

raster_table_p:
    .long vidc_table_1_no_adr

raster_table_top_p:
    .long vidc_table_1_no_adr+256*4*4

raster_tables:
raster_table_vidc1_p:
	.long vidc_table_1_no_adr
raster_table_vidc2_p:
	.long 0
raster_table_vidc3_p:
	.long 0
raster_table_memc_p:
	.long memc_table_no_adr

; ============================================================================

rasters_init:
    ; Configure RasterMan for future compatibility.
    mov r0, #4              ; number of VIDC reg writes
    mov r1, #2              ; number of MEMC reg writes
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
    ; NB. No longer need to fill redundant buffers.
	stmia r0!, {r6-r9}		; 4x VIDC commands per line.
    ; TODO: Some sort of assertion / auto generate this code based on #reg writes.
	;stmia r1!, {r6-r9}		; 4x VIDC commands per line.
	;stmia r2!, {r6-r9}		; 4x VIDC commands per line.
	;stmia r2!, {r6-r9}		; 4x VIDC commands per line.
    str r4, [r3], #4
    str r3, [r3], #4        ; null MEMC commands.
	subs r5, r5, #1
	bne .1

	ldmfd sp!, {r0-r3}
	swi RasterMan_SetTables
    mov pc, lr

rasters_donut_init:
    ; Copy bg fade to vidc1.
	adr r0, raster_tables
    ldr r12, [r0, #RasterTable_Memc]
    ldr r0, [r0, #RasterTable_Vidc1]

    add r0, r0, #RastersDonut_PaletteLine*16

    adr r1, raster_donut_bg
    ldmia r1!, {r2-r9}          ; 8 words
    stmia r0!, {r2-r9}
    ldmia r1!, {r2-r9}          ; 8 words
    stmia r0!, {r2-r9}

    add r0, r0, #16*(248-5-RastersDonut_PaletteLine)

    adr r1, raster_scroller_fg
    ldmia r1, {r2-r5}           ; 4 words
    stmia r0!, {r2-r5}

    adr r1, raster_scroller_bg
    ldmia r1, {r2-r9}           ; 8 words
    str r2, [r0], #16
    str r3, [r0], #16
    str r4, [r0], #16
    str r5, [r0], #16
    str r6, [r0], #16
    str r7, [r0], #16
    str r8, [r0], #16
    str r9, [r0], #16

    ; Set Vstart to fixed scroller area in the middle of the donut area.
    ldr r0, app_scroller_phys
    mov r0, r0, lsl #2
    orr r0, r0, #MEMC_Vinit
    orr r0, r0, #MEMC_Vstart^MEMC_Vinit
    str r0, [r12, #129*8]           ; line 129

    mov pc, lr

; R0=ptr to VIDC reg format table.
rasters_donut_set_palette:
    ldr r2, raster_table_vidc1_p
    add r2, r2, #RastersDonut_PaletteLine*16
    mov r3, r0

    ; Copy 16 words of VIDC registers.
    ldmia r3!, {r4-r11}
    stmia r2!, {r4-r11}
    ldmia r3!, {r4-r11}
    stmia r2!, {r4-r11}

    mov pc, lr

rasters_tick:
    ldr r0, raster_donut_palette_p
    cmp r0, #0
    bne rasters_donut_set_palette
    
    mov pc, lr

; ============================================================================

; First 56 lines for the logo are fixed palette - set in vsync?
; Next 192 lines are the donut - ?
; Last 8 lines are the scroller - set bg blend?

raster_donut_palette_p:
    .long 0

raster_donut_bg:
    .long           VIDC_Col0  | 0x000
    .long           VIDC_Col1  | 0x002
    .long           VIDC_Col2  | 0x004
    .long           VIDC_Col3  | 0x006
    .long           VIDC_Col4  | 0x008
    .long           VIDC_Col5  | 0x00a
    .long           VIDC_Col6  | 0x00c
    .long           VIDC_Col7  | 0x02e
    .long           VIDC_Col8  | 0x04e
    .long           VIDC_Col9  | 0x06e
    .long           VIDC_Col10 | 0x08e
    .long           VIDC_Col11 | 0x0ae
    .long           VIDC_Col12 | 0x0ce
    .long           VIDC_Col13 | 0x0de
    .long           VIDC_Col14 | 0xcee
    .long           VIDC_Col15 | 0xfff

raster_scroller_bg:
    .long           VIDC_Col0 | 0x111
    .long           VIDC_Col0 | 0x222
    .long           VIDC_Col0 | 0x333
    .long           VIDC_Col0 | 0x444
    .long           VIDC_Col0 | 0x555
    .long           VIDC_Col0 | 0x666
    .long           VIDC_Col0 | 0x777
    .long           VIDC_Col0 | 0x888

raster_scroller_fg:
    .long           VIDC_Col1 | 0x048
    .long           VIDC_Col2 | 0x06c
    .long           VIDC_Col3 | 0x6df
    .long           VIDC_Col4 | 0x9ef

; ============================================================================
