; ============================================================================
; Sprite Utils
; All MODE 9 unless stated otherwise.
; ============================================================================

.equ SpriteSheetDef_NumSprites,     0
.equ SpriteSheetDef_WidthWords,     1
.equ SpriteSheetDef_HeightRows,     2
.equ SpriteSheetDef_Flags,          3
.equ SpriteSheetDef_SrcData,        4
.equ SpriteSheetDef_PtrTable,       8

; ============================================================================

sprite_utils_buffer_base:
    .long sprite_buffer_no_adr

sprite_utils_buffer_top:
    .long sprite_buffer_no_adr

sprite_utils_init:
    ldr r0, sprite_utils_buffer_base
    str r0, sprite_utils_buffer_top
    mov pc, lr

; ============================================================================

; Shift MODE 9 image data by N pixels to the right.
; Writes dst data one word wider than the src data.
; Params:
;  R7=src width in words. (preserved)
;  R8=src height in rows. (preserved)
;  R9=src address. (updated)
;  R10=pixel shift right [0-7] (preseved)
;  R12=dst address. (updated)
; Trashes: R0-R2, R11
sprite_utils_shift_pixel_data:
    str lr, [sp, #-4]!
    
    mov r10, r10, lsl #2        ; word shift
    rsb r11, r10, #32           ; reverse word shift

    mov r14, r8                 ; row count.
.1:

    mov r2, #0                  ; dst word.
    mov r1, r7                  ; word count.
.2:
    ldr r0, [r9], #4            ; src word.
    orr r2, r2, r0, lsl r10     ; move src pixels right N and combine with existing.

    str r2, [r12], #4           ; write dst word.
    mov r2, r0, lsr r11         ; recover src pixels falling into next word.

    subs r1, r1, #1             ; next word.
    bne .2

    str r2, [r12], #4           ; write final dst word.
    
    subs r14, r14, #1           ; next row.
    bne .1

    mov r10, r10, lsr #2        ; restore r10
    ldr pc, [sp], #4


; Make all shifted sprites and put ptrs in a table.
;  R0=src address.
;  R1=ptr to sprite table to be completed [8 entries].
;  R2=src width in words.
;  R3=src height in rows.
;  R4=dst address [buffer (width+1) x height x 8 words.]
; Trashes: R5-R11
; Returns:
;  R6=end of ptr table.
;  R9=end of src.
;  R12=end of dst buffer.
sprite_utils_make_table:
    str lr, [sp, #-4]!

    ; TODO: Renumber registers?
    mov r5, r0
    mov r6, r1
    mov r7, r2
    mov r8, r3
    mov r12, r4

    mov r10, #0                 ; pixel shift.
.1:
    mov r9, r5                  ; reset src ptr.
    str r12, [r6], #4           ; store ptr to next dst.

    bl sprite_utils_shift_pixel_data

    add r10, r10, #1
    cmp r10, #8
    bne .1

    ldr pc, [sp], #4

; Helper for sequence script.
; R0=sprite def.
; R1=sprite no.
; R2=address of table ptr to fill.
sprite_utils_set_ptr:
    .if _DEBUG
    ldrb r3, [r0, #SpriteSheetDef_NumSprites]
    cmp r1, r3
    adrge r0, err_spriteoutofrange
    swige OS_GenerateError
    .endif
    SPRITE_UTILS_GET_TABLE r0, r1, r0
    str r0, [r2]
    mov pc, lr

; R0=address of sprite sheet definition.
sprite_utils_make_shifted_sheet:
    str lr, [sp, #-4]!

    ldr r12, sprite_utils_buffer_top
    mov r11, r0

    add  r6, r11, #SpriteSheetDef_PtrTable
    ldr  r9, [r11, #SpriteSheetDef_SrcData]
    ldrb r2, [r11, #SpriteSheetDef_WidthWords]
    ldrb r3, [r11, #SpriteSheetDef_HeightRows]
    ldrb r10, [r11, #SpriteSheetDef_NumSprites]          ; num_sprites.
.1:
    mov  r0, r9                      ; src data.
    mov  r1, r6                      ; ptr table.
    mov  r4, r12                     ; dst buffer.

    stmfd sp!, {r2-r3, r10}
    bl sprite_utils_make_table
    ; Returns R6=next ptr table addr
    ;         R9=end of src.
    ;         R12=top of dst buffer.
    ldmfd sp!, {r2-r3, r10}

    .if _DEBUG
    ldr r1, sprite_utils_buffer_base
    sub r1, r12, r1                ; size=top-base
    cmp r1, #AppConfig_SpriteBufferSize
    adrgt r0, err_spriteoverflow
    swigt OS_GenerateError
    .endif

    subs r10, r10, #1
    bne .1

    str r12, sprite_utils_buffer_top
    ldr pc, [sp], #4

.if _DEBUG
err_spriteoverflow: ;The error block
.long 18
.byte "Sprite buffer overflow!"
.align 4
.long 0

err_spriteoutofrange: ;The error block
.long 18
.byte "Sprite number out of range!"
.align 4
.long 0
.endif

; ============================================================================

; Expand MODE 4 (1bpp) image data to MODE 9 (4bpp).
; Params:
;  R0=src address.
;  R1=dst address.
;  R2=src width in bytes.
;  R3=src height in rows.
;  R4=colour index.
sprite_utils_convert_mode4_to_mode9:
    ; Make colour index a colour word.
    orr r4, r4, r4, lsl #4
    orr r4, r4, r4, lsl #8
    orr r4, r4, r4, lsl #16

    ; Row loop.
.1:

    ; Byte loop.
    mov r7, r2
.2:
    ldr r5, [r0], #1
    mov r6, #0

    ; convert 1bpp byte to 4bpp word
    ; %abcdefgh
    tst r5, #0b00000001
    orrne r6, r6, #0x0000000f
    tst r5, #0b00000010
    orrne r6, r6, #0x000000f0
    tst r5, #0b00000100
    orrne r6, r6, #0x00000f00
    tst r5, #0b00001000
    orrne r6, r6, #0x0000f000
    tst r5, #0b00010000
    orrne r6, r6, #0x000f0000
    tst r5, #0b00100000
    orrne r6, r6, #0x00f00000
    tst r5, #0b01000000
    orrne r6, r6, #0x0f000000
    tst r5, #0b10000000
    orrne r6, r6, #0xf0000000

    ; Mask in colour and store word.
    and r6, r6, r4
    str r6, [r1], #4

    ; Next byte.
    subs r7, r7, #1
    bne .2

    ; Next row.
    subs r3, r3, #1
    bne .1

    mov pc, lr
