; ============================================================================
; Text pool.
; Keeps a pool of text strings painted to 'sprites', i.e. pixel data.
; ============================================================================

.equ TextPool_Max,              256
.equ TextPool_PoolSize,         544*1024    ; !!
.equ TextPool_ShowProgress,     1

; ============================================================================
; Text pool vars.
; ============================================================================

text_pool_font_handle:
    .long 0

; TODO: Could have stored these as a block...
text_pool_widths:
    .skip TextPool_Max*4

text_pool_heights:
    .skip TextPool_Max*4

text_pool_pixel_ptrs:
    .skip TextPool_Max*4

text_pool_p:
    .long text_pool_base_no_adr

text_pool_top_p:
    .long text_pool_top_no_adr

text_pool_defs_p:
    .long text_pool_defs_no_adr

text_pool_total:
    .long 0


; Get bounding box for a string using the font def.
; Feels like we're leaking some abstraction here.
; R1=ptr to RISCOS font name
; R11=ptr to text def vars
; Returns:
;  r11= x1 (os units)
;  r5 = y1 (os units)
;  r1 = x2 (os units)
;  r2 = y2 (os units)
;  r8 = width (os units)
;  r4 = height (os units)
text_pool_get_bounding_box:
    ; Get font handle.
    ldmia r11!, {r2-r3}                     ; get point sizes
    mov r4, #0
    mov r5, #0
    swi Font_FindFont
    str r0, text_pool_font_handle

    ldr r2, [r11], #4                       ; get colour
    mov r1, r11                             ; text ptr
    b outline_font_get_bounding_box


; Store data in rows.
; R1=ptr to RISCOS font name
; R3=store as rows (0) or columns (<>0)
; R10=ptr to init screen for progress
; R11=ptr to text def vars
; R12=screen addr
; Returns:
;  R0=text no.
;  R11=end of text def
; Trashes: r0-r10
text_pool_make_sprite:
    str lr, [sp, #-4]!
    str r10, [sp, #-4]!

    mov r10, r3                             ; stash flag.
    mov r9, r4
    mov r8, r5

    ; Get font handle.
    ldmia r11!, {r2-r3}                     ; get point sizes
    mov r4, #0
    mov r5, #0
    swi Font_FindFont
    str r0, text_pool_font_handle

    ; Set colours for this logo.
    ldr r0, text_pool_font_handle           ; font handle.
    mov r1, #0                              ; background logical colour
    ldr r2, [r11], #4                       ; get colour
    mov r3, #0                              ; how many colours
    swi Font_SetColours

    ; Paint text to a MODE 9 buffer.
    ldr r0, text_pool_font_handle
    mov r1, r11
    ldr r2, text_pool_p
    mov r3, r10                             ; retrieve flag.
    mov r4, r9                              ; argh! refactor me.
    mov r5, r8
    bl outline_font_paint_to_buffer

    mov r11, r7
    ldr r0, text_pool_total
    .if _DEBUG
    cmp r0, #TextPool_Max
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

    .if _DEBUG
    cmp r10, r7
    adrge r0, err_bitpooloverflow
    swige OS_GenerateError
    .endif
    str r10, text_pool_p

    ; Increment total.
    mov r8, r0
    add r0, r0, #1
    str r0, text_pool_total

    ; Skip over text to next def.
.3:
    ldrb r1, [r11], #1
    cmp r1, #0
    bne .3
    add r11, r11, #3
    bic r11, r11, #3

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
    .rept Screen_Stride/32                  ; TODO: Does this need to be full screen width?
    stmia r10!, {r0-r7}
    .endr
    subs r9, r9, #1
    bpl .4

    ldr r10, [sp], #4                       ; init_screen_addr

    .if TextPool_ShowProgress
    mov r4, #Scope_YPos
    add r9, r10, r4, lsl #8
    add r9, r9, r4, lsl #6
    add r9, r9, r8, lsl #2
    mov r5, #-1
    cmp r8, #Screen_WidthWords
    strlt r5, [r9]
    .endif

    ; Return text no.
    mov r0, r8
    ldr pc, [sp], #4


; R12=screen addr.
text_pool_init:
    str lr, [sp, #-4]!

    ldr r11, text_pool_defs_p               ; TODO: Pass this in or separate?
    b .2

.1:
    mov r3, #0                              ; store as rows by default.
    mov r4, #0                              ; not fixed
    mov r5, #0                              ; not fixed
    bl text_pool_make_sprite
    ; Returns R0=sprite num.

    ; Store sprite num.
    ldr r1, [r11], #4                       ; addr?
    cmp r1, #0
    strne r0, [r1]

.2:
    ldr r1, [r11], #4                       ; ptr to font def
    cmp r1, #-1
    bne .1

    ldr pc, [sp], #4

; ============================================================================

.if _DEBUG
err_bitoutoftexts: ;The error block
.long 18
.byte "Text pool out of slots!"
.align 4
.long 0

err_bitpooloverflow: ;The error block
.long 18
.byte "Text pool buffer overflow!"
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
