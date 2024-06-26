; ============================================================================
; Dots. (Technically "Y Sine Dots".)
; Used in: Three-Dee Demo (Mikroreise)
; ============================================================================

.equ _DOTS_ENABLE_REVEAL, 1
.equ Dots_Total, 4096                   ; needs to match dot_gen.lua

dots_y_table_1_p:
    .long dots_y_table_1_no_adr

dots_y_table_2_p:
    .long dots_y_table_2_no_adr

dots_y_t:
    .long 0

dots_total:
    .long Dots_Total

dots_screen_1_addr:
    .long 0x01ff2000                    ; 0x02000000 - 40K (MODE 9)

dots_code_p:
    .long dots_gen_code_a

.if _DOTS_ENABLE_REVEAL
dots_visible:
    .long 0

dots_return_code:
    mov pc, lr

dots_load_code:
    ldmia r9!, {r0-r7}
.endif

dots_tick:
.if _DOTS_ENABLE_REVEAL
    ldr r0, dots_visible
    ldr r1, dots_total
    mov r1, r1, lsr #3
    add r0, r0, #1
    cmp r0, r1
    strlt r0, dots_visible
.endif

    ; Scroll the y index for lookup.
    ldr r8, dots_y_t
    ldr r10, dots_total
    add r8, r8, #1
    cmp r8, r10
    movge r8, #0
    str r8, dots_y_t

    mov pc, lr

; R12=screen addr
dots_draw_all:
    str lr, [sp, #-4]!

.if _DOTS_ENABLE_REVEAL
    ldr r0, dots_visible
    ldr r1, dots_code_p                 ; 49 instructions per block 
    add r1, r1, r0, lsl #7              ; =n*128
    add r1, r1, r0, lsl #6              ; +n*64
    add r1, r1, r0, lsl #2              ; +n*4
    ldr r0, dots_return_code
    str r0, [r1]
.endif

    ; For Y reflected dots only.
    ; values are scr_base+y*320
    ; want scr_base+255*320-y*320
    ; want a-(scr_base+y*320)=scr_base+255*320-y*320
    ; therefore a=2*scr_base+255*320
    ; mov r11, r12, lsl #1
    ; add r11, r11, #Screen_Stride*(Screen_Height-1)    ; screen bottom

    ; Work out which table to lookup for this screen buffer.
    ldr r10, dots_screen_1_addr
    cmp r12, r10
    ldreq r9, dots_y_table_1_p
    ldrne r9, dots_y_table_2_p

    ; Index the y table.
    ldr r8, dots_y_t
    add r9, r9, r8, lsl #2

    ; Set colours for anaglyph.
    ; Subtract blue & green for left eye.
    mov r11, #7                 ; brightest red

    ; Subtract red for right eye.
    mov r8, #11                 ; brightest cyan

    ;bl dots_gen_code
    adr lr, .1
    ldr pc, dots_code_p         ; does this work?
    .1:

.if _DOTS_ENABLE_REVEAL
    ldr r0, dots_visible
    ldr r1, dots_total
    mov r1, r1, lsr #3
    cmp r0, r1
    ldrge pc, [sp], #4

    ldr r1, dots_code_p                 ; 49 instructions per block
    add r1, r1, r0, lsl #7              ; =n*128
    add r1, r1, r0, lsl #6              ; +n*64
    add r1, r1, r0, lsl #2              ; +n*4
    ldr r0, dots_load_code
    str r0, [r1]
.endif

    ldr pc, [sp], #4

; Generated code with X values and Y mirroring baked in.
dots_gen_code_a:
    ;.include "src/dot_plot_generated.asm"
    .incbin "build/dot_gen_code_a.bin"
    ; TODO: Generate code at init time from X table.
    mov pc, lr

; Generated code with X values and Y mirroring baked in.
dots_gen_code_b:
    ;.include "src/dot_plot_generated_b.asm"
    .incbin "build/dot_gen_code_b.bin"
    ; TODO: Generate code at init time from X table.
    mov pc, lr

