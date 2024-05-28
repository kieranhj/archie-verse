; ============================================================================
; Outline font utils.
; All MODE 9 unless stated otherwise.
; Inbuilt into RISCOS 3:
;  Homerton.[Bold|Medium].[Oblique]
;  Corpus.  [Bold|Medium].[Oblique]
;  Trinity. [Bold|Medium].[Oblique]
; ============================================================================

.equ _OUTLINE_FONT_CENTRE_TO_SCREEN, 0
; TODO:
;  Option to justify left, right and centre to buffer.
;  Option to specify buffer width (e.g. screen width) or automatically calculate it.
;  Option to specify vertical position in buffer. - DONE
;  Option for different screen configurations (MODE 9,12,13 etc.)

; Calculate bounding box for string.
;  R0=font handle (or 0).
;  R1=ptr to string.
; Returns:
;  r11= x1 (os units)
;  r5 = y1 (os units)
;  r1 = x2 (os units)
;  r2 = y2 (os units)
;  r8 = width (os units)
;  r4 = height (os units)
outline_font_get_bounding_box:
    mov r2, #0x40020            ; bits 18 & 5 set.
    mov r3, #0x1000000
    mov r4, #0x1000000
    adr r5, outline_font_coord_block
    swi Font_ScanString

    ldr r1, outline_font_coord_block+20     ; x1
    ldr r2, outline_font_coord_block+24     ; y1
    swi Font_ConverttoOS
    mov r11, r1                             ; x1 (os units)
    mov r5, r2                              ; y1 (os units)

    ldr r1, outline_font_coord_block+28     ; x2 (os units)
    ldr r2, outline_font_coord_block+32     ; y2 (os units)
    swi Font_ConverttoOS

    ; Calculate width and height in os units.
    sub r8, r1, r11                         ; width = x2-x1 (os units)
    add r8, r8, #4                          ; inclusive so round up
    sub r4, r2, r5                          ; height = y2-y1 (os units)
    add r4, r4, #4                          ; inclusive so round up
    mov pc, lr


; Paint a string to the screen using RISCOS outline fonts.
; Then copies the bounding box of the screen data to a buffer.
; Uses the currently selected font colours.
;
; Params:
;  R0=font handle (or 0).
;  R1=ptr to string.
;  R2=ptr to sprite buffer.
;  R3=store as rows (0) or columns (<>0)
;  R4=fixed height (or 0 for bounding box height)
;  R5=y1 (or 0 for bounding box y1)
;  R12=screen base ptr.
; Returns:
;  R8=width in words.
;  R9=height in rows.
;  R10=end of sprite buffer.
; Trashes: R0-R7,R11
outline_font_paint_to_buffer:
    stmfd sp!, {r12, lr}
    str r3, [sp, #-4]!
    stmfd sp!, {r4,r5}      ; push

    ; Stash params.
    mov r6, r0
    mov r7, r1
    mov r10, r2

    bl outline_font_get_bounding_box
    ; Returns:
    ;  r11= x1 (os units)
    ;  r5 = y1 (os units)
    ;  r1 = x2 (os units)
    ;  r2 = y2 (os units)
    ;  r8 = width (os units)
    ;  r4 = height (os units)

    ldmfd sp!, {r0,r3}      ; pop
    cmp r0, #0
    movne r4, r0            ; fixed height
    cmp r3, #0
    movne r5, r3            ; fixed y1

    ; Convert os units into pixels.
    ; TODO: Keep in os units for as long as possible?
    .if Screen_Width == 640
    mov r8, r8, lsr #1                      ; pixel width.
    .else
    mov r8, r8, lsr #2                      ; pixel width.
    .endif
    mov r9, r4, lsr #2                      ; pixel height.

    ; Paint to screen.
    ; Ensure string is painted exactly in top left of the screen buffer.
    .if _OUTLINE_FONT_CENTRE_TO_SCREEN
    rsb r3, r11, #640                       ; 640-x1
    sub r3, r3, r8;, lsl #1                  ; 640-x1-(os width/2)
    mov r8, #Screen_Width                   ; screen width
    .else
    rsb r3, r11, #0                         ; 0-x1 (LEFT ADJUST)
    .endif

    mov r4, #1024
    sub r4, r4, r5                          ; 1024-y1
    sub r4, r4, r9, lsl #2                  ; 1024-y1-os height
    ;sub r4, r4, r2

    mov r0, r6                              ; font handle.
    mov r1, r7                              ; ptr to string.
    mov r2, #0x10                           ; os units.
    swi Font_Paint

    ; Assumes 4bpp here!
    add r8, r8, #7                          ; round up to full word.
    mov r8, r8, lsr #3                      ; word width.

    ; Copy screen data.
    ldr r3, [sp], #4
    cmp r3, #0
    bne .2

    ; Copy screen data to buffer as rows.
.1:
    mov r2, r9                              ; height
.11:
    mov r1, r8                              ; width
    mov r3, r12                             ; src
.12:
    ldr r0, [r12], #4
    str r0, [r10], #4                       ; dst
    subs r1, r1, #1                         ; next col.
    bne .12
    
    add r12, r3, #Screen_Stride
    subs r2, r2, #1                         ; next row.
    bne .11

    ldmfd sp!, {r12, pc}

.2:
    ; Copy screen data to buffer as columns.
    mov r1, r8                              ; width
.21:
    mov r2, r9                              ; height
    mov r3, r12                             ; src
.22:
    ldr r0, [r12], #Screen_Stride
    str r0, [r10], #4                       ; dst
    subs r2, r2, #1                         ; next row.
    bne .22
    
    add r12, r3, #4                         ; next col.
    subs r1, r1, #1
    bne .21

    ldmfd sp!, {r12, pc}


outline_font_coord_block:
    .long 0, 0, 0, 0, -1, 0, 0, 0, 0

; ============================================================================
; RISCOS Outline font definitions.
; ============================================================================

outline_font_def_homerton_bold:
    .byte "Homerton.Bold"
    .byte 0
.p2align 2

outline_font_def_homerton_regular:
    .byte "Homerton.Medium"
    .byte 0
.p2align 2

outline_font_def_homerton_italic:
    .byte "Homerton.Medium.Oblique"
    .byte 0
.p2align 2

outline_font_def_homerton_bold_italic:
    .byte "Homerton.Bold.Oblique"
    .byte 0
.p2align 2

outline_font_def_corpus_bold:
    .byte "Corpus.Bold"
    .byte 0
.p2align 2

outline_font_def_corpus_regular:
    .byte "Corpus.Medium"
    .byte 0
.p2align 2

outline_font_def_corpus_italic:
    .byte "Corpus.Medium.Oblique"
    .byte 0
.p2align 2

outline_font_def_corpus_bold_italic:
    .byte "Corpus.Bold.Oblique"
    .byte 0
.p2align 2

outline_font_def_trinity_bold:
    .byte "Trinity.Bold"
    .byte 0
.p2align 2

outline_font_def_trinity_regular:
    .byte "Trinity.Medium"
    .byte 0
.p2align 2

outline_font_def_trinity_italic:
    .byte "Trinity.Medium.Italic"
    .byte 0
.p2align 2

outline_font_def_trinity_bold_italic:
    .byte "Trinity.Bold.Italic"
    .byte 0
.p2align 2
