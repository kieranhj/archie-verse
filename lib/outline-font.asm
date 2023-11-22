; ============================================================================
; Outline font utils.
; All MODE 9 unless stated otherwise.
; Inbuilt into RISCOS 3:
;  Homerton.[Bold|Medium].[Oblique]
;  Corpus.[Bold|Medium].[Oblique]
;  Trinity.[Bold|Medium].[Oblique]
; ============================================================================

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
; Trashes: R0-R7
outline_font_paint_to_buffer:
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

    add r8, r8, #7                          ; round up to full word.
    mov r8, r8, lsr #3                      ; word width.

    ; TODO: CLS?

    ; Paint to screen.
    mov r0, r6                              ; font handle.
    mov r1, r7                              ; ptr to string.
    mov r2, #0x10                           ; os coords.

    ; Ensure string is painted exactly in top left of the screen buffer.

    rsb r3, r11, #0                         ; 0-x1
    mov r4, #1024
    sub r4, r4, r5                          ; 1024-y1
    sub r4, r4, r9, lsl #2                  ; 1024-y1-os height
    swi Font_Paint

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

    mov pc, lr

outline_font_coord_block:
    .long 0, 0, 0, 0, -1, 0, 0, 0, 0
