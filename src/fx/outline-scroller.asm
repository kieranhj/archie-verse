; ============================================================================
; Scroller using outline font system. It big.
; ============================================================================

.equ ScrollText_MaxSprites,     256
.equ ScrollText_MaxLength,      1024
.equ ScrollText_SpaceColumns,   4

scroll_text_text_p:
    .long scroll_text_text_no_adr

scroll_text_ptr:
    .long scroll_text_as_sprites_no_adr

scroll_text_offset:
    .long -1                         ; column in sprite.

scroll_text_fixed_height:
    .long 0

scroll_text_fixed_y:
    .long 0

scroll_text_as_sprites_p:
    .long scroll_text_as_sprites_no_adr

scroll_text_hash_values_p:
    .long scroll_text_hash_values_no_adr

scroll_text_y_pos:
    FLOAT_TO_FP 200.0

scroll_text_text_def:
    TextDef homerton_bold_italic, 64, 64*1.2, 0xf, "AbcCygtI!?AAAAAAAAAAAAAAAAAAAAAA"    ; macro needs >1 char?!

; ============================================================================

scroll_text_init:
    str lr, [sp, #-4]!

    adr r11, scroll_text_text_def
    ldr r1, [r11], #4               ; font def
    bl text_pool_get_bounding_box
    ; Returns:
    ;  r11= x1 (os units)
    ;  r5 = y1 (os units)
    ;  r1 = x2 (os units)
    ;  r2 = y2 (os units)
    ;  r8 = width (os units)
    ;  r4 = height (os units)

    ; So want to plot the string at 1024-y2 into a buffer of height to ensure all on the same line.
    str r4, scroll_text_fixed_height
    str r5, scroll_text_fixed_y

    ldr r6, scroll_text_as_sprites_p
    ldr r8, scroll_text_hash_values_p
    mov r9, #0                  ; num sprites.

    ; Convert scroll text into sprites using a dictionary to avoid repetition.
    ldr r10, scroll_text_text_p
.1:
    bl get_jenkins_hash_for_string
    ; R0=hash value.

    ; Find hash.
    mov r7, #0                  ; index
.2:
    cmp r7, r9
    bge .3                      ; not found.
    ldr r1, [r8, r7, lsl #2]
    cmp r1, r0                  ; compare hash.
    beq .30                      ; found.
    add r7, r7, #1
    b .2

    ; Hash not found.
.3:
    ; Store hash.
    str r0, [r8, r9, lsl #2]

.30:
    ; Copy string to text def.
    adr r11, scroll_text_text_def
    ldr r1, [r11], #4               ; font def
    add r2, r11, #12                ; text base
.31:
    ldrb r0, [r10], #1
    cmp r0, #0
    beq .32
    cmp r0, #ASCII_Space
    beq .32
    strb r0, [r2], #1
    b .31
.32:
    mov r0, #0
    strb r0, [r2], #1               ; terminate string.

    cmp r7, r9
    blt .4

    ; Generate new sprite.
    add r9, r9, #1
    .if _DEBUG
    cmp r9, #ScrollText_MaxSprites
    adrge r0, err_scrolltextmax
    swige OS_GenerateError    
    .endif

    stmfd sp!, {r6,r8-r10}
    mov r3, #1                      ; store as columns.
    ldr r4, scroll_text_fixed_height
    ldr r5, scroll_text_fixed_y
    bl text_pool_make_sprite
    ; Returns:
    ;  R0=text no.
    ldmfd sp!, {r6,r8-r10}

    ; TODO: index==sprite num for now
    mov r7, r0
.4:
    ; Hash found.
    strb r7, [r6], #1

    ; Continue until EOS.
    ldrb r0, [r10, #-1]
    cmp r0, #0
    bne .1

    mov r0, #-1
    strb r0, [r6], #1

    ldr pc, [sp], #4

.if _DEBUG
err_scrolltextmax: ;The error block
.long 18
.byte "Out of scrolltext sprites!"
.align 4
.long 0
.endif

; ============================================================================
; Legacy scroller routine plots sprites individually. NOT USED!
; ============================================================================

.if 0
scroll_text_tick:
    str lr, [sp, #-4]!

    ldr r10, scroll_text_ptr
    ldrb r0, [r10]
    bl text_pool_get_sprite
    ; Returns:
    ;  R8=width in words.
    ;  R9=height in rows.
    ;  R11=ptr to pixel data.
    add r8, r8, #ScrollText_SpaceColumns
    ldr r1, scroll_text_offset
    add r1, r1, #1
    cmp r1, r8
    blt .1

    ; Next sprite.
    ldrb r0, [r10, #1]!
    cmp r0, #0xff
    ldreq r10, scroll_text_as_sprites_p
    str r10, scroll_text_ptr

    ; First column.
    mov r1, #0
.1:
    str r1, scroll_text_offset
    ldr pc, [sp], #4

; R12=screen addr.
scroll_text_draw:
    str lr, [sp, #-4]!

    ; Calculate screen address.
    ldr r0, scroll_text_y_pos
    mov r0, r0, asr #16
    add r12, r12, r0, lsl #8
    add r12, r12, r0, lsl #6

    ldr r10, scroll_text_ptr
    ldrb r0, [r10]
    cmp r0, #0xff
    beq .3
    bl text_pool_get_sprite
    ; Returns:
    ;  R8=width in words.
    ;  R9=height in rows.
    ;  R11=ptr to pixel data.

    ldr r6, scroll_text_offset
    mul r0, r9, r6                  ; height * columns
    add r11, r11, r0, lsl #2        ; each column is a word.

    ; Keep column counter 0-79 for screen width.
    mov r7, #0                      ; column count.
.1:
    cmp r6, r8
    bge .3

    mov r4, r12

    ; Plot a column slowly for now.
    mov r5, r9                      ; height
.2:
    ldr r0, [r11], #4
    str r0, [r12], #Screen_Stride   ; next row.
    subs r5, r5, #1
    bne .2

    ; Next screen column.
    add r12, r4, #4
    add r7, r7, #1
    cmp r7, #Screen_Stride/4
    bge .5                          ; done if hit rhs of screen.

    ; Next sprite column.
    add r6, r6, #1
    b .1

.3:
    add r8, r8, #ScrollText_SpaceColumns

    ; Plot a standard space!
    mov r0, #0
.4:
    mov r4, r12

    ; Plot a column slowly for now.
    mov r5, r9                      ; height
.42:
    str r0, [r12], #Screen_Stride   ; next row.
    subs r5, r5, #1
    bne .42

    ; Next screen column.
    add r12, r4, #4
    add r7, r7, #1
    cmp r7, #Screen_Stride/4
    bge .5                          ; done if hit rhs of screen.

    add r6, r6, #1
    cmp r6, r8
    blt .4

    ; Next sprite!
    ldrb r0, [r10, #1]!
    cmp r0, #0xff
    beq .5
    bl text_pool_get_sprite
    ; Returns:
    ;  R8=width in words.
    ;  R9=height in rows.
    ;  R11=ptr to pixel data.
    mov r6, #0
    b .1

.5:
    ldr pc, [sp], #4
.endif

; ============================================================================
; Return non-cryptographic hash for a string.
; ============================================================================

; R10=ptr to string.
; Terminate with space or 0.
; Returns: R0=hash value
; Trashes: R1-R2
get_jenkins_hash_for_string:
    mov r0, #0  ; hash
    mov r1, #0  ; i
.1:
    ldrb r2, [r10, r1]
    cmp r2, #0
    beq .2
    cmp r2, #ASCII_Space
    beq .2

    add r0, r0, r2          ; hash += key[i++]
    add r0, r0, r0, lsl #10 ; hash += hash << 10
    eor r0, r0, r0, lsr #6  ; hash ^= hash >>6

    adds r1, r1, #1
    bne .1                  ; max 256 chars in the string.

.2:
    ; Complete the hash.
    add r0, r0, r0, lsl #3  ; hash += hash << 3
    eor r0, r0, r0, lsr #11 ; hash ^= hash >> 11
    add r0, r0, r0, lsl #15 ; hash += hash << 15
    mov pc, lr

; ============================================================================
; New scroller routine shifts screen pixels (double buffered).
; ============================================================================

.equ Scroller_Glyph_Height, 47

scroller_glyph_data_ptr:
    .long 0

scroller_speed:
    .long 2

scroller_buffer_ptr:
    .long scroller_glyph_column_buffer_1_no_adr

scroller_glyph_buffer_1_p:
    .long scroller_glyph_column_buffer_1_no_adr

scroller_glyph_buffer_2_p:
    .long scroller_glyph_column_buffer_2_no_adr

.macro scroller_copy_words count
    ldmia r11!, {r0-r\count}
    stmia r10!, {r0-r\count} ; \count +1 words
    stmia r12!, {r0-r\count} ; \count +1 words
.endm

.macro scroller_store_words count
    stmia r10!, {r0-r\count} ; \count +1 words
    stmia r12!, {r0-r\count} ; \count +1 words
.endm

scroller_tick:
    str lr, [sp, #-4]!

    ldr r10, scroll_text_ptr
    ldrb r0, [r10]
    bl text_pool_get_sprite
    ; Returns:
    ;  R8=width in words.
    ;  R9=height in rows.
    ;  R11=ptr to pixel data.
    ldr r7, scroller_glyph_data_ptr
    cmp r7, #0
    streq r11, scroller_glyph_data_ptr

    add r8, r8, #ScrollText_SpaceColumns

    ldr r1, scroll_text_offset
    cmp r1, #0
    blt .3                  ; first frame init

    ldr r2, scroller_speed
    add r1, r1, r2
    cmp r1, r8, lsl #3      ; in pixels
    blt .1

    ; Next sprite.
    ldrb r0, [r10, #1]!
    cmp r0, #0xff
    ldreq r10, scroll_text_as_sprites_p
    str r10, scroll_text_ptr

    ; Returns:
    ;  R8=width in words.
    ;  R9=height in rows.
    ;  R11=ptr to pixel data.
    bl text_pool_get_sprite
    str r11, scroller_glyph_data_ptr

.3:
    ; First column.
    mov r1, #0
.1:
    str r1, scroll_text_offset

	ands r0, r1, #7		; 8 pixels per word
    ldrne pc, [sp], #4

    ; Next slice of the glyph.
    ldr r10, scroller_glyph_buffer_1_p
    ldr r12, scroller_glyph_buffer_2_p

    ; Do space.
    sub r8, r8, #ScrollText_SpaceColumns
    cmp r1, r8, lsl #3
    bge .2

    ; Copy one column of glyph data into buffer.
    ldr r11, scroller_glyph_data_ptr

    .rept Scroller_Glyph_Height / 10
    scroller_copy_words 9        ; actually 10
    .endr
    scroller_copy_words 6;       ; actually 7
    .if Scroller_Glyph_Height != 47
    .err "Expected Scroller_Glyph_Height to be 47!"
    .endif

    str r11, scroller_glyph_data_ptr
    ldr pc, [sp], #4

.2:
    mov r0, #0
	mov r1, r0
	mov r2, r0
	mov r3, r0
	mov r4, r0
	mov r5, r0
	mov r6, r0
	mov r7, r0
	mov r8, r0
	mov r9, r0

    .rept Scroller_Glyph_Height / 10
    scroller_store_words 9        ; actually 10
    .endr
    scroller_store_words 6;       ; actually 7
    .if Scroller_Glyph_Height != 47
    .err "Expected Scroller_Glyph_Height to be 47!"
    .endif

    ldr pc, [sp], #4

; R12=screen addr
scroller_draw:
	str lr, [sp, #-4]!

    ldr r11, scroller_buffer_ptr
    bl scroller_scroll_buffer

    ldr r11, scroller_buffer_ptr
    ldr r10, scroller_glyph_buffer_1_p
    cmp r11, r10
    ldreq r10, scroller_glyph_buffer_2_p
    str r10, scroller_buffer_ptr

	ldr pc, [sp], #4

; R11=column buffer
; R12=screen addr
scroller_scroll_buffer:
	str lr, [sp, #-4]!

    ldr r0, scroll_text_y_pos
    mov r0, r0, asr #16
	add r9, r12, r0, lsl #8
	add r9, r9, r0, lsl #6

    ldr r12, scroller_speed ; speed in pixels
    mov r12, r12, lsl #3    ; pixel shift (lsr #4*n) * 2 for double buffer

	.rept Scroller_Glyph_Height
	ldr r10, [r11]	        ; r10=scroller_glyph_column_buffer[r11]
	bl scroller_scroll_line
	str r10, [r11], #4      ; scroller_glyph_column_buffer[r11]=r10
    .endr

	ldr pc, [sp], #4

.macro scroller_shift_left_by_pixels
	; shift word right 4 bits to clear left most pixel
	mov r0, r0, lsr r12
	; mask in right most pixel from next word
	orr r0, r0, r1, lsl r14
    ; etc.
	mov r1, r1, lsr r12
	orr r1, r1, r2, lsl r14
	mov r2, r2, lsr r12
	orr r2, r2, r3, lsl r14
	mov r3, r3, lsr r12
	orr r3, r3, r4, lsl r14
	mov r4, r4, lsr r12
	orr r4, r4, r5, lsl r14
	mov r5, r5, lsr r12
	orr r5, r5, r6, lsl r14
	mov r6, r6, lsr r12
	orr r6, r6, r7, lsl r14
	mov r7, r7, lsr r12
	orr r7, r7, r8, lsl r14
.endm

; R9=line address, R10=right hand word, R12=pixel shift
scroller_scroll_line:
	str lr, [sp, #-4]!
    rsb r14, r12, #32       ; reverse pixel shift (lsl #32-4*n)

    .rept (Screen_Width/64)-1
	ldmia r9, {r0-r8}		; read 9 words = 36 bytes = 72 pixels
    scroller_shift_left_by_pixels
	stmia r9!, {r0-r7}		; write 8 words = 32 bytes = 64 pixels
    .endr

    ; Last block!
	ldmia r9, {r0-r7}		; read 8 words = 32 bytes = 64 pixels
    mov r8, r10
    scroller_shift_left_by_pixels
	stmia r9!, {r0-r7}		; write 8 words = 32 bytes = 64 pixels

	mov r10, r10, lsr r12	; rotate new data word
	ldr pc, [sp], #4
