; ============================================================================
; Text pool.
; Keeps a pool of text strings painted to 'sprites', i.e. pixel data.
; ============================================================================

.equ Text_Pool_Max,         16
.equ Text_Pool_PoolSize,    Screen_Stride*64*6

; ============================================================================
; Text pool vars.
; ============================================================================

bits_font_handle:
    .long 0

; TODO: Could have stored these as a block...
text_pool_widths:
    .skip Text_Pool_Max*4

text_pool_heights:
    .skip Text_Pool_Max*4

text_pool_pixel_ptrs:
    .skip Text_Pool_Max*4

text_pool_p:
    .long text_pool_base_no_adr

text_pool_top_p:
    .long text_pool_top_no_adr

text_pool_defs_p:
    .long text_pool_defs_no_adr

text_pool_total:
    .long 0

; R12=screen addr.
text_pool_init:
    str lr, [sp, #-4]!

    ldr r11, text_pool_defs_p               ; TODO: Pass this in?
    b .2

.1:
    ; Get font handle.
    ldmia r11!, {r2-r3}                     ; get point sizes
    mov r4, #0
    mov r5, #0
    swi Font_FindFont
    str r0, bits_font_handle

    ; Set colours for this logo.
    mov r0, #0                              ; font handle.
    ldr r0, bits_font_handle
    mov r1, #0                              ; background logical colour
    ldr r2, [r11], #4                       ; get colour
    mov r3, #0                              ; how many colours
    swi Font_SetColours

    ; Paint text to a MODE 9 buffer.
    mov r0, #0
    ldr r0, bits_font_handle
    mov r1, r11
    ldr r2, text_pool_p
    bl outline_font_paint_to_buffer

    mov r11, r7
    ldr r0, text_pool_total
    .if _DEBUG
    cmp r0, #Text_Pool_Max
    adrge r0, err_bitoutoftexts
    swige OS_GenerateError
    .endif

    ; Store width & height.
    adr r1, text_pool_widths
    str r8, [r1, r0, lsl #2]
    adr r1, text_pool_heights
    str r9, [r1, r0, lsl #2]

    ; Store pixel ptr.
    .if _DEBUG
    ldr r7, text_pool_top_p
    cmp r10, r7
    adrge r0, err_bitpooloverflow
    swige OS_GenerateError
    .endif

    adr r1, text_pool_pixel_ptrs
    ldr r2, text_pool_p
    str r2, [r1, r0, lsl #2]

    ; BODGE-O-MATIC.
    mov r1, #0
    mov r2, #Screen_Stride
.5:
    str r1, [r10], #4
    subs r2, r2, #1
    bne .5
    .if _DEBUG
    cmp r10, r7
    adrge r0, err_bitpooloverflow
    swige OS_GenerateError
    .endif
    str r10, text_pool_p

    add r0, r0, #1
    str r0, text_pool_total

    ; Skip over text to next def.
.3:
    ldrb r1, [r11], #1
    cmp r1, #0
    bne .3
    add r11, r11, #3
    bic r11, r11, #3

.if 0
;    swi OS_WriteI+12
.else
    ; Clear screen of previous font stuffs.
    mov r0, #0
    mov r1, #0
    mov r2, #0
    mov r3, #0
    mov r4, #0
    mov r5, #0
    mov r6, #0
    mov r7, #0
    mov r10, r12
.4:
    .rept Screen_Stride/32
    stmia r10!, {r0-r7}
    .endr
    subs r9, r9, #1
    bpl .4
.endif

.2:
    ldr r1, [r11], #4                       ; ptr to font def
    cmp r1, #-1
    bne .1

    ldr pc, [sp], #4

; ============================================================================

.if _DEBUG
err_bitbufoverflow: ;The error block
.long 18
.byte "Bits buffer overflow!"
.align 4
.long 0

err_bitoutoftexts: ;The error block
.long 18
.byte "Out of Bits text slots!"
.align 4
.long 0

err_bitpooloverflow: ;The error block
.long 18
.byte "Bits text pool overflow!"
.align 4
.long 0
.endif

; ============================================================================

; R0=text string no.
; Returns:
;  R8=width in words.
;  R9=height in rows.
;  R11=ptr to pixel data.
text_pool_get_sprite:
    adr r11, text_pool_pixel_ptrs
    ldr r11, [r11, r0, lsl #2]
    adr r8, text_pool_widths
    ldr r8, [r8, r0, lsl #2]
    adr r9, text_pool_heights
    ldr r9, [r9, r0, lsl #2]
    mov pc, lr
