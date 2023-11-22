; ============================================================================
; Sys req
; Produce a version of the classic 'System Requirements' Amiga screen using
; RISCOS outline fonts for minimal space.
; This might be better to implement a simple !Draw file renderer that only
; supports Text objects. See RISCOS PRMs pp4-457 for file format details.
; Main complication would be translating the bounding box coordinates so
; they can be displayed on the screen at a specified corner position.
; ============================================================================

.equ SysReq_LargePoint, 64*16
.equ SysReq_SmallPoint, 32*16
.equ SysReq_LHS, 320

sys_req_large_font:
    .long 0

sys_req_small_font:
    .long 0

sys_req_font_def:
    .byte "Homerton.Bold"
    .byte 0
.p2align 2

; R12=screen addr.
sys_req_init:
    str lr, [sp, #-4]!

    adr r1, sys_req_font_def
    mov r2, #SysReq_LargePoint
    mov r3, #SysReq_LargePoint
    mov r4, #0
    mov r5, #0
    swi Font_FindFont
    str r0, sys_req_large_font

    adr r10, sys_req_text_large
    bl sys_req_plot_strings

    adr r1, sys_req_font_def
    mov r2, #SysReq_SmallPoint
    mov r3, #SysReq_SmallPoint
    mov r4, #0
    mov r5, #0
    swi Font_FindFont
    str r0, sys_req_small_font

    adr r10, sys_req_text_small
    bl sys_req_plot_strings

    ldr pc, [sp], #4

; R0=font handle.
; R10=ptr to string list.
sys_req_plot_strings:
    mov r2, #0x10                   ; os coords.
.1:
    ldr r3, [r10], #4
    cmp r3, #0
    movlt pc, lr

    ldr r4, [r10], #4
    mov r1, r10
    swi Font_Paint

.2:
    ldrb r3, [r10], #1
    cmp r3, #0
    bne .2
    add r10, r10, #3
    bic r10, r10, #3

    b .1

sys_req_text_large:
    .long SysReq_LHS, 800
    .byte "SYSTEM", 0
    .p2align 2

    .long SysReq_LHS, 600
    .byte "OCS", 0
    .p2align 2

    .long SysReq_LHS+200, 400
    .byte "68000", 0
    .p2align 2

    .long SysReq_LHS, 100
    .byte "50Hz", 0
    .p2align 2

    .long -1

sys_req_text_small:
    .long SysReq_LHS, 730
    .byte "REQUIREMENTS", 0
    .p2align 2

    .long 700, 670
    .byte "Amiga", 0
    .p2align 2

    .long 700, 600
    .byte "A500", 0
    .p2align 2

    .long SysReq_LHS, 530
    .byte "Kickstart 1.2", 0
    .p2align 2

    .long SysReq_LHS, 470
    .byte "7.1", 0
    .p2align 2

    .long SysReq_LHS, 400
    .byte "MHz", 0
    .p2align 2

    .long SysReq_LHS, 330
    .byte "512KB Chip RAM", 0
    .p2align 2

    .long SysReq_LHS, 250
    .byte "512KB Expansion", 0
    .p2align 2

    .long 700, 170
    .byte "Angus &", 0
    .p2align 2

    .long 700, 100
    .byte "CRT Display", 0
    .p2align 2

    .long -1
