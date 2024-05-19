; ============================================================================
; Outline font utils.
; All MODE 9 unless stated otherwise.
; Inbuilt into RISCOS 3:
;  Homerton.[Bold|Medium].[Oblique]
;  Corpus.  [Bold|Medium].[Oblique]
;  Trinity. [Bold|Medium].[Oblique]
; ============================================================================

.equ _OUTLINE_FONT_CENTRE_TO_SCREEN, 1  ; TODO: Left, right and centre adjust.

; Paint a string to the screen using RISCOS outline fonts.
; Then copies the bounding box of the screen data to a buffer.
; Uses the currently selected font colours.
;
; Params:
;  R0=font handle (or 0).
;  R1=ptr to string.
;  R2=ptr to sprite buffer.
;  R12=screen base ptr.
; Returns:
;  R8=width in words.
;  R9=height in rows.
;  R10=end of sprite buffer.
; Trashes: R0-R7,R11
outline_font_paint_to_buffer:
    str r12, [sp, #-4]!

    ; Stash params.
    mov r6, r0
    mov r7, r1
    mov r10, r2

    ; Calculate bounding box for string.
    mov r2, #0x40020            ; bits 18 & 5 set.
    mov r3, #0x1000000
    mov r4, #0x1000000
    adr r5, outline_font_coord_block
    swi Font_ScanString

    ldr r1, outline_font_coord_block+20     ; x1
    ldr r2, outline_font_coord_block+24     ; y1
    swi Font_ConverttoOS
    mov r11, r1
    mov r5, r2

    ldr r1, outline_font_coord_block+28     ; x2
    ldr r2, outline_font_coord_block+32     ; y2
    swi Font_ConverttoOS
    sub r8, r1, r11                         ; x2-x1 os units
    add r8, r8, #4                          ; inclusive so round up
    sub r4, r2, r5                          ; y2-y1 os units
    add r4, r4, #4                          ; inclusive so round up

    mov r8, r8, lsr #2                      ; pixel width.
    mov r9, r4, lsr #2                      ; pixel height.

    ; Paint to screen.
    mov r0, r6                              ; font handle.
    mov r1, r7                              ; ptr to string.
    mov r2, #0x10                           ; os units.

    ; Ensure string is painted exactly in top left of the screen buffer.

    .if _OUTLINE_FONT_CENTRE_TO_SCREEN
    rsb r3, r11, #640                       ; 640-x1
    sub r3, r3, r8, lsl #1                  ; 6400-(x1+os width/2)
    mov r8, #Screen_Width                   ; screen width
    .else
    rsb r3, r11, #0                         ; 0-x1 (LEFT ADJUST)
    .endif
    mov r4, #1024
    sub r4, r4, r5                          ; 1024-y1
    sub r4, r4, r9, lsl #2                  ; 1024-y1-os height
    swi Font_Paint

    add r8, r8, #7                          ; round up to full word.
    mov r8, r8, lsr #3                      ; word width.

    ; Copy screen data to buffer.
    mov r2, r9
.1:
    mov r1, r8
    mov r3, r12
.2:
    ldr r0, [r12], #4
    str r0, [r10], #4
    subs r1, r1, #1
    bne .2
    
    add r12, r3, #Screen_Stride
    subs r2, r2, #1
    bne .1

    ldr r12, [sp], #4
    mov pc, lr

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
    .byte "Homerton.Oblique"
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
    .byte "Corpus.Oblique"
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
    .byte "Trinity,Medium"
    .byte 0
.p2align 2

outline_font_def_trinity_italic:
    .byte "Trinity.Oblique"
    .byte 0
.p2align 2

outline_font_def_trinity_bold_italic:
    .byte "Trinity.Bold.Oblique"
    .byte 0
.p2align 2
