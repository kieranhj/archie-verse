; ============================================================================
; Bitshifters logo.
; And bits & pieces that don't necessarily have a home or are in prototype.
; ============================================================================

.if 0 ; Push
.equ Bits_Num_Verts,        490 ; was 520

.equ Bits_Owl_Width_Pixels, 256
.equ Bits_Owl_Width_Bytes,  (Bits_Owl_Width_Pixels/8)
.equ Bits_Owl_Height_Rows,  256
.equ Bits_Owl_Mode9_Bytes,  (Bits_Owl_Width_Pixels/2)*Bits_Owl_Height_Rows

bits_logo_vert_array_p:
    .long bits_logo_vert_array_no_adr

tmt_logo_vert_array_p:
    .long tmt_logo_vert_array_no_adr

prod_logo_vert_array_p:
    .long prod_logo_vert_array_no_adr

; R12=screen addr.
bits_logo_init:
    str lr, [sp, #-4]!

    ; Has to be done after font text has been drawn, therefore
    ; can't be in the script as the first script frame is called
    ; before the late draw. TODO: Separate 'run once' script?
    mov r0, #0  ; prod name
    ldr r1, prod_logo_vert_array_p
    mov r2, #Bits_Num_Verts
    mov r3, #VECTOR2_SIZE*Bits_Num_Verts
    mov r4, #MATHS_CONST_1*2.0
    bl bits_make_verts_from_text

    mov r0, #3  ; kieran
    ldr r1, bits_logo_vert_array_p
    mov r2, #Bits_Num_Verts
    mov r3, #VECTOR2_SIZE*Bits_Num_Verts
    mov r4, #MATHS_CONST_1*2.0
    bl bits_make_verts_from_text

    mov r0, #4  ; rhino
    ldr r1, tmt_logo_vert_array_p
    mov r2, #Bits_Num_Verts
    mov r3, #VECTOR2_SIZE*Bits_Num_Verts
    mov r4, #MATHS_CONST_1*2.0
    bl bits_make_verts_from_text

    ldr pc, [sp], #4

; R0=text no.
; R1=vert array ptr
; R2=num verts
; R3=vert array size
; R4=scale [1.16]
bits_make_verts_from_text:
    str lr, [sp, #-4]!

    stmfd sp!, {r0-r4}

    ; Select N random pixels from the image.
    mov r3, r2
    adr r2, bits_text_pixel_ptrs
    ldr r2, [r2, r0, lsl #2]
    adr r1, bits_text_heights
    ldr r1, [r1, r0, lsl #2]
    adr r4, bits_text_widths
    ldr r0, [r4, r0, lsl #2]
    bl bits_logo_select_random

    ldmfd sp!, {r0-r4}

    ; Turn those marked pixels into a vertex array.
;  R0=width in words
;  R1=height in rows
;  R2=ptr to image data
;  R3=ptr to vertex array buffer
;  R4=vertex array buffer size in bytes
;  R5=scale [1.16]
    mov r5, r4
    mov r4, r3
    mov r3, r1
    adr r2, bits_text_pixel_ptrs
    ldr r2, [r2, r0, lsl #2]
    adr r1, bits_text_heights
    ldr r1, [r1, r0, lsl #2]
    adr r6, bits_text_widths
    ldr r0, [r6, r0, lsl #2]
    bl bits_create_vert_array_from_image

    ldr pc, [sp], #4
.endif

; ============================================================================

.if _DEBUG && 0
; R12=screen addr.
bits_logo_draw:
    str lr, [sp, #-4]!

    add r12, r12, #64*Screen_Stride

    ldr r1, bits_height
    ldr r9, bits_logo_p
.1:
    ldr r2, bits_width
    mov r3, r12
.2:
    ldr r0, [r9], #4
    str r0, [r12], #4
    subs r2, r2, #1
    bne .2

    add r12, r3, #Screen_Stride
    subs r1, r1, #1
    bne .1

    ldr pc, [sp], #4
.endif

; ============================================================================

.if 0
; Get a pixel from the image.
; R0=width in words (stride)
; R1=row
; R2=base ptr
; R6=column
; Returns R9=pixel value [0-15]
; Trashes: R5,R8
bits_get_pixel:
    cmp r1, r3
    blt .1

    cmp r6, r0, lsl #3
    blt .1

    mov r9, #0
    mov pc, lr
.1:

    and r8, r6, #7          ; pixel no.
    mov r8, r8, lsl #2      ; pixel shift.
    mov r5, r6, lsr #3      ; word no.

    mul r9, r0, r1          ; row*stride
    add r9, r2, r9, lsl #2  ; base+(row*stride)*4
    ldr r9, [r9, r5, lsl #2]; get word

    mov r9, r9, lsr r8     ; shift pixel down lsb
    and r9, r9, #0xf
    mov pc, lr

; Marks a pixel in the image.
; R0=width in words (stride)
; R1=row
; R2=base ptr
; R6=column
; Trashes: R5,R8,R9,R12
bits_mark_pixel:
    .if _DEBUG
    cmp r1, r3
    blt .1

    cmp r6, r0, lsl #3
    blt .1

    mov r9, #0
    mov pc, lr
.1:
    .endif

    mul r8, r0, r1          ; row*stride
    add r8, r2, r8, lsl #2  ; base+(row*stride)*4
    mov r5, r6, lsr #3      ; word no.
    add r5, r8, r5, lsl #2  ; word address

    ldr r12, [r5]           ; get word

    and r8, r6, #7          ; pixel no.
    mov r8, r8, lsl #2      ; pixel shift.

    mov r9, #0x8
    orr r12, r12, r9, lsl r8    ; mask in edge bit
    str r12, [r5]           ; store word

    mov pc, lr

; Rejection sampling of pixels inside an image.
; Mark N pixels top bit to indicate these should become verts.
; R0=width in words
; R1=height in rows
; R2=ptr to image data
; R3=number of pixels to select.
bits_logo_select_random:
    str lr, [sp, #-4]!

    .if _DEBUG
    cmp r0, #0
    adreq r0, error_invalidparams
    swieq OS_GenerateError

    cmp r1, #0
    adreq r0, error_invalidparams
    swieq OS_GenerateError

    cmp r2, #0
    adreq r0, error_invalidparams
    swieq OS_GenerateError
    .endif

    mov r4, #0              ; tries
    mov r11, r3             ; count
    mov r3, r1              ; height in pixels.
    mov r10, r0, lsl #3     ; width in pixels.
.1:
    add r4, r4, #1
    cmp r4, #0x10000
    bge .2

    ; Generate a new random position.
    ldr r8, bits_rnd_seed
    ldr r5, bits_rnd_bit
    RND r8, r5, r6
    str r8, bits_rnd_seed
    str r5, bits_rnd_bit

    mov r6, r8, lsr #16     ; top 16 bits       [0.16]
    mov r1, r8, lsl #16
    mov r1, r1, lsr #16     ; bottom 16 bits    [0.16]

    ; R6=column
    mul r6, r10, r6         ; width*rand [16.16]
    mov r6, r6, lsr #16

    ; R1=row
    mul r1, r3, r1          ; height*rand [16.16]
    mov r1, r1, lsr #16

    bl bits_get_pixel
    ; R9=pixel

    ; Reject if zero pixel.
    cmp r9, #0
    beq .1

    ; Reject if already marked.
    ands r9, r9, #8
    bne .1

    ; Mark this pixel.
    bl bits_mark_pixel

    ; NB. Could be an infinite loop so fail after N tries.
    subs r11, r11, #1
    bne .1
.2:
    .if _DEBUG
    cmp r11, #0
    adrne r0, err_randomfail
    swine OS_GenerateError
    .endif

    ldr pc, [sp], #4

bits_rnd_seed:
    .long 0xdeadbeef

bits_rnd_bit:
    .long 0x11111111
.endif

; ============================================================================

.if 0
; Create an array of vertices from an image (top-bit marked pixels).
; Params:
;  R0=width in words
;  R1=height in rows
;  R2=ptr to image data
;  R3=ptr to vertex array buffer
;  R4=vertex array buffer size in bytes
;  R5=scale [1.16]
; Returns:
;  R12=total number of verts created
bits_create_vert_array_from_image:
    str lr, [sp, #-4]!

    .if _DEBUG
    cmp r0, #0
    adreq r0, error_invalidparams
    swieq OS_GenerateError

    cmp r1, #0
    adreq r0, error_invalidparams
    swieq OS_GenerateError

    cmp r2, #0
    adreq r0, error_invalidparams
    swieq OS_GenerateError
    .endif

    mov r11, r3             ; vert_ptr
    mov r12, #0             ; vert count

    add r7, r3, r4          ; array top

    mov r4, r1              ; row count
    ; Row loop
.1:
    ; Pixel loop.
    mov r6, #0              ; pixel count.
.2:
    mov r8, r6, lsr #3      ; word no.
    ldr r9, [r2, r8, lsl #2]; get word
    and r8, r6, #7          ; pixel no.
    mov r8, r8, lsl #2      ; pixel shift.
    mov r9, r9, lsr r8      ; shift pixel down lsb

    ; Is this an edge pixel?
    ands r9, r9, #0x8        ; mask pixel
    beq .3

    ; If yes then plop a vert down.

    ; Make vert position around the origin.
    sub r8, r6, r0, lsl #2  ; x pos = pixel_x - pixel_w/2
    mul r8, r5, r8          ; x pos * scale [16.16]
;    mov r8, r8, asl #16     ; x pos = pixel count [16.16]
    sub r9, r1, r4, lsr #1  ; y pos = row - height/2
    mul r9, r5, r9          ; y pos * scale [16.16]
;    mov r9, r9, asl #16     ; y pos = (row - height) [16.16]

    ; Store vert.
    stmia r11!, {r8-r9}     ; origin

    add r12, r12, #1

    .if _DEBUG
    cmp r11, r7
    adrgt r0, err_vertarrayoverflow
    swigt OS_GenerateError
    .endif

.3:
    ; Next pixel.
    add r6, r6, #1
    cmp r6, r0, lsl #3      ; total pixels=words*8
    blt .2

    ; Next row x 2.
    add r2, r2, r0, lsl #2  ; image_ptr += words*4
    subs r1, r1, #1
    bgt .1

    ldr pc, [sp], #4

.if _DEBUG
err_vertarrayoverflow: ;The error block
.long 18
.byte "Vertex array overflow!"
.align 4
.long 0

err_randomfail:
.long 18
.byte "Failed to select all random verts."
.align 4
.long 0
.endif
.endif

; ============================================================================

.if 0
; Removes a pixel from the image.
; R0=width in words (stride)
; R1=row
; R2=base ptr
; R6=column
; Trashes: R5,R8,R9,R12
bits_remove_pixel:
    mul r8, r0, r1          ; row*stride
    add r8, r2, r8, lsl #2  ; base+(row*stride)*4
    mov r5, r6, lsr #3      ; word no.
    add r5, r8, r5, lsl #2  ; word address

    ldr r12, [r5]           ; get word

    and r8, r6, #7          ; pixel no.
    mov r8, r8, lsl #2      ; pixel shift.

    mov r9, #0xf
    bic r12, r12, r9, lsl r8    ; mask out pixel
    str r12, [r5]           ; store word

    mov pc, lr

; Convert a filled text image into an outline.
; Marks the top bit of each pixel considered on the edge of the image.
; R0=width in words
; R1=height in rows
; R2=ptr to image data
bits_logo_make_outline:
    str lr, [sp, #-4]!

    .if _DEBUG
    cmp r0, #0
    adreq r0, error_invalidparams
    swieq OS_GenerateError

    cmp r1, #0
    adreq r0, error_invalidparams
    swieq OS_GenerateError

    cmp r2, #0
    adreq r0, error_invalidparams
    swieq OS_GenerateError
    .endif

    mov r3, r1              ; height in rows.

    ; Row loop.
    mov r1, #0              ; row
.1:
    mov r7, #0              ; last pixel.

    ; Pixel loop.
    mov r6, #0              ; column
.2:
    bl bits_get_pixel
    and r9, r9, #7          ; mask out edge bit

    ; Has pixel changed?
    cmp r9, r7
    beq .3

    ; If yes then mark top bit as edge.
    movs r7, r9

    ; Is the new pixel black?
    ; If so mark pixel to the left.
    subeq r6, r6, #1
    bl bits_mark_pixel
    addeq r6, r6, #1

.3:
    ; Next pixel.
    add r6, r6, #1
    cmp r6, r0, lsl #3      ; total pixels=words*8
    blt .2

    ; Next row.
    add r1, r1, #1
    cmp r1, r3
    blt .1

    ; Column loop.
    mov r6, #0              ; pixel count.
.10:

    ; Row loop.
    mov r7, #0              ; last pixel.
    mov r1, #0              ; row count
.20:
    bl bits_get_pixel
    and r9, r9, #7          ; mask out edge bit

    ; Has pixel changed?
    cmp r9, r7
    beq .30

    ; If yes then mark top bit as edge.
    movs r7, r9

    ; Is the new pixel black?
    ; If so mark pixel on previous row.
    subeq r1, r1, #1
    bl bits_mark_pixel
    addeq r1, r1, #1

.30:
    ; Next row.
    add r1, r1, #1
    cmp r1, r3
    ble .20

    ; Next column.
    add r6, r6, #1
    cmp r6, r0, lsl #3      ; total pixels=words*8
    blt .10

    ldr pc, [sp], #4

; Convert a filled text image into an outline.
; Marks the top bit of each pixel considered on the edge of the image.
; R0=width in words
; R1=height in rows
; R2=ptr to image data
bits_logo_decimate_outline:
    str lr, [sp, #-4]!

    .if _DEBUG
    cmp r0, #0
    adreq r0, error_invalidparams
    swieq OS_GenerateError

    cmp r1, #0
    adreq r0, error_invalidparams
    swieq OS_GenerateError

    cmp r2, #0
    adreq r0, error_invalidparams
    swieq OS_GenerateError
    .endif

    mov r3, r1              ; height in rows.

.if 1
    ; Row loop.
    mov r1, #0              ; row
.1:
    mov r7, #0              ; last pixel.
    mov r4, #0              ; run count.

    ; Pixel loop.
    mov r6, #0              ; column
.2:
    bl bits_get_pixel
    and r9, r9, #8          ; mask only edge bit

    ; Has pixel changed?
    cmp r9, r7
    movne r4, #0            ; reset count.

    ; Is this pixel black?
    movs r7, r9
    beq .3

    ; Only keep every 8th pixel.
    ands r5, r4, #7
    blne bits_remove_pixel

.3:
    add r4, r4, #1          ; count++

    ; Next pixel.
    add r6, r6, #1
    cmp r6, r0, lsl #3      ; total pixels=words*8
    blt .2

    ; Next row.
    add r1, r1, #1
    cmp r1, r3
    blt .1
.endif

.if 1
    ; Column loop.
    mov r6, #0              ; pixel count.
.10:

    mov r4, #0              ; run count.

    ; Row loop.
    mov r7, #0              ; last pixel.
    mov r1, #0              ; row count
.20:
    bl bits_get_pixel
    and r9, r9, #8          ; mask only edge bit

    ; Has pixel changed?
    cmp r9, r7
    movne r4, #0            ; reset count.

    .23:
    ; Is this pixel black?
    movs r7, r9
    beq .30

    ; Only keep every 3rd pixel...
    movs r5, r4
    beq .22
    .21:
    subs r5, r5, #3
    bgt .21
    .22:

    ; Remove if not zero.
    blne bits_remove_pixel

.30:
    add r4, r4, #1          ; count++

    ; Next row.
    add r1, r1, #1
    cmp r1, r3
    ble .20

    ; Next column.
    add r6, r6, #1
    cmp r6, r0, lsl #3      ; total pixels=words*8
    blt .10
.endif

    ldr pc, [sp], #4
.endif

; ============================================================================

.if 0
bits_draw_file_test:
    str lr, [sp, #-4]!

    mov r0, #320                ; x origin [os units]
    mov r1, #32                ; y origin [os units]
    ldr r10, bits_draw_file_p
    ldr r11, bits_draw_file_end
    bl draw_file_plot_to_screen

    ldr pc, [sp], #4

bits_draw_file_p:
    .long bits_draw_file_no_adr

bits_draw_file_end:
    .long bits_draw_file_end_no_adr
.endif

; ============================================================================

bits_text_curr:
    .long 4                     ; which one to plot.

bits_text_xpos:
    FLOAT_TO_FP 0.0

bits_text_ypos:                 ; Y coordinate for centre of word.
    FLOAT_TO_FP 0.0
; TODO: Could drive address lookup per scanline with an iterator.

bits_text_colour:
    FLOAT_TO_FP 15.0
; TODO: Could drive per scanline colour with an iterator.

; Plot the current text to the screen along with a CLS.
; 
; R12=screen adrr.
bits_draw_text:
    str lr, [sp, #-4]!

    ldr r0, bits_text_curr
    bl text_pool_get_sprite
    ; Returns:
    ;  R8=width in words.
    ;  R9=height in rows.
    ;  R11=ptr to pixel data.

    ldr r10, bits_text_ypos
    mov r10, r10, asr #16
    rsb r10, r10, #0                ; flip 'cos I'm a div
    sub r10, r10, r9, lsr #1        ; top scanline where text begins.
    add r9, r10, r9                 ; bottom scanline where text ends.

    ; Bump start ptr by word offset.
    ; A bit hacky but should work for smaller shifts...
    ldr r2, bits_text_xpos
    mov r2, r2, asr #16
    sub r11, r11, r2, lsl #2

    ldr r5, bits_text_colour
    mov r5, r5, asr #16
    orr r5, r5, r5, lsl #4
    orr r5, r5, r5, lsl #8
    orr r5, r5, r5, lsl #16

    ; Handle clipping on top of the screen.
    ;       i.e. r10 < -128 and r9 > -128
    mov r7, #-128                   ; scanline.

    subs r6, r7, r10                ; -128 - ypos
    addgt r11, r11, r6, lsl #7
    addgt r11, r11, r6, lsl #5      ; add N lines to src.

.1:
    cmp r7, r10
    blt .2                          ; draw a blank line.
    
    cmp r7, r9
    bge .2                          ; draw a blank line.

    ; Copy a line to screen.
    ; Fix everything to screen width for speed.
    .rept Screen_Stride/16
    ldmia r11!, {r0-r3}
    and r0, r0, r5
    and r1, r1, r5
    and r2, r2, r5
    and r3, r3, r5
    stmia r12!, {r0-r3}
    .endr

    ; Code duplicated below.
    add r7, r7, #1
    cmp r7, #128
    blt .1
    mov pc, lr

.2:
    mov r0, #0
    mov r1, #0
    mov r2, #0
    mov r3, #0
    .rept Screen_Stride/16
    stmia r12!, {r0-r3}
    .endr

    ; Code duplicated above.
    add r7, r7, #1
    cmp r7, #128
    blt .1

    ldr pc, [sp], #4

; ============================================================================

.if 0
bits_glyphs_a:
    .long -1

; R12=screen adrr.
bits_glyphs_init:
    str lr, [sp, #-4]!

    adr r11, bits_glyph_def
    mov r0, #0
    strb r0, [r11, #17]         ; one char only.

.1:
    ldr r1, [r11], #4           ; ptr to font def
    bl text_pool_make_sprite

    ; Store index for 'A'.
    ldr r1, bits_glyphs_a
    cmp r1, #-1
    streq r0, bits_glyphs_a

    ; Increment letter.
    adr r11, bits_glyph_def
    ldrb r0, [r11, #16]         ; string offset.
    add r0, r0, #1
    strb r0, [r11, #16]         ; string offset.
    cmp r0, #91 ; 'Z'
    blt .1

    ldr pc, [sp], #4

bits_glyph_def:
    TextDef corpus_bold, 36, 36*1.2, 0xf, "AB"    ; macro needs >1 char?!

; R12=screen adrr.
bits_glyph_draw:
    str lr, [sp, #-4]!

    adr r10, bits_text
.1:
    ldrb r0, [r10], #1
    cmp r0, #0
    beq .2

    sub r0, r0, #65 ; 'A'
    bl text_pool_get_sprite
    ; Returns:
    ;  R8=width in words.
    ;  R9=height in rows.
    ;  R11=ptr to pixel data.

    ; Screen addr.
    mov r6, r12

    ; Row loop.
.3:
    ; Col loop.
    mov r7, r8
.4:
    ldr r0, [r11], #4
    str r0, [r6], #4
    subs r7, r7, #1
    bne .4

    sub r6, r6, r8, lsl #2
    add r6, r6, #Screen_Stride

    subs r9, r9, #1
    bne .3

    add r12, r12, r8, lsl #2        ; x+=width
    b .1

.2:
    ldr pc, [sp], #4

bits_text:
    .byte "BITSHIFTERS", 0
.p2align 2
.endif

; ============================================================================
