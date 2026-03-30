; ============================================================================
; Loader with embedded compressed exe block.
; Relocate all data to top of RAM.
; Call Shrinkler / LZ4 uncompress and return to app start at 0x8000.
; ============================================================================

.equ _DEBUG, 0

.include "../lib/swis.h.asm"

.ifndef _WIMPSLOT
.equ _WIMPSLOT, 1200*1024           ; Assumed RAM - see !Run.txt
.endif

.equ STACK_SIZE, 1024

.org 0x8000

main:
    ; Set our RAM requirement.
    ; Not sure what happens if this fails?! :S
    mov r0, #_WIMPSLOT
    swi Wimp_SlotSize

    adr r0, message_text
    mov r1, #message_end-message_text
    swi OS_WriteN

    ldr r8, reloc_to                ; reloc_to

    ; Relocate decoder.
    mov r9, r8                      ; dst
    adr r11, reloc_start            ; src
    ldr r10, reloc_end              ; end
.1:
    ldr r0, [r11], #4
    str r0, [r9], #4
    cmp r11, r10
    blt .1

    ; Relocation offset.
    adr r3, reloc_start
    sub r3, r3, r8

    ; Call decompressor.
    adr r0, compressed_demo_start
    sub r0, r0, r3                  ; source (reloc)

    mov r1, #0x8000                 ; destination

    .if _USE_SHRINKLER
    adr r2, callback
    sub r2, r2, r3                  ; callback fn (reloc)

    mov r3, #0                      ; callback arg
    .endif
    
    ; R9 = end of reloc = shrinkler contexts

    mov sp, r8                      ; reset stack top
    mov lr, #0x8000                 ; return address
    mov pc, r8                      ; jump to reloc

message_text:
    ; 59 chars across by 13 rows.
    .byte "                    _____   ___",13,10
    .byte "                ____\\_  /__(_//______  ____",13,10
    .byte " _ __________  / ___/T  __ \\--.  __ /_/ ___\\   ________ _",13,10
    .byte " __ ________/ /  \\___|  |/ |  |  Z/  /  Z/  \\ |_______ __",13,10
    .byte "-----------   \\______\\__|  !__:  /__/\\______!   ---------",13,10
    .byte "       ______          /___|  |___\\         ________",13,10
    .byte " ___  _\\  __/____. /\\   ____ _____  _____.  \\    _  \\  __",13,10
    .byte " __/ / __ \\|___  |/  \\ /  _ Y  __ \\/ ___ |   \\___/  / /__",13,10
    .byte "    /  Z|  \\ _/  :    /  T| |  Z/ |  Z/  |   __/__ <_",13,10
    .byte "--- \\______//____!    \\__||_|___  :_____/   /   Z/  / ---",13,10
    .byte "-------------- /________\\ -- /____|dS!NE7 -/_______/-----",13,10
    .byte 13,10
    .byte "....................... Decrunching ......................"
;   .byte "         1         2         3         4         5",13,10
;   .byte "12345678901234567890123456789012345678901234567890123456789",13,10
    .byte 23,1,0,0,0,0,0,0,0,0  ; turn off cursor
    .byte 0
message_end:
.p2align 2

reloc_to:
.if _USE_SHRINKLER
    .long 0x8000 + _WIMPSLOT - (reloc_end_no_adr - reloc_start) - (NUM_CONTEXTS*4) - 4
.else
    .long 0x8000 + _WIMPSLOT - (reloc_end_no_adr - reloc_start) - 4
.endif

reloc_end:
    .long reloc_end_no_adr

reloc_start:

.if _USE_SHRINKLER
	b ShrinklerDecompress

; R0=bytes written
; R1=callback arg
callback:
    movs r1, r0, lsl #22            ; every 2k
    swieq OS_WriteI+'_'
    mov pc, lr

.include "../lib/arc-shrinkler.asm"
.else
    ; b unlz4  <== code starts here anyway.
.include "../lib/lz4-decode.asm"
.endif

.p2align 2
compressed_demo_start:
.if _USE_SHRINKLER
.incbin "../build/archie-verse.shri"
.else
.incbin "../build/archie-verse.lz4"
.endif
.p2align 2
compressed_demo_end:

shrinkler_contexts:
    ; .skip (NUM_CONTEXTS*4)

reloc_end_no_adr:

; ============================================================================
