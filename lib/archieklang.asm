; ============================================================================
; ArchieKlang wrapper.
; ============================================================================

.equ AK_CLEAR_FIRST_2_BYTES,    0   ; TODO: Make this a script option?

.macro AK_PROGRESS
    .if LibConfig_ShowInitProgress
    swi OS_WriteI+'_'
    .endif
.endm

.macro AK_FINE_PROGRESS
.endm

mod_track_p:
    .long music_mod_no_adr

generated_samples_p:
    .long Generated_Samples_no_adr

AK_Temp_Buffer_p:
    .long AK_Temp_Buffer_no_adr

external_samples_p:
    .long External_Samples_no_adr

.if _LOG_SAMPLES
qtm4:
    .byte "QTM4"
.endif

archieklang_init:
    str lr, [sp, #-4]!

    ldr r8, generated_samples_p
    ldr r9, AK_Temp_Buffer_p
    ldr r10, external_samples_p
    bl AK_Generate
    ; R8=end of generated sample buffer.

    .if _LOG_SAMPLES
    mov r9, r8

    ; Get ptr to log conversion table.
    ; Much faster than using swi Sound_SoundLog!
    mov r0, #0
    mov r1, #0
    mov r2, #0
    mov r3, #0
    mov r4, #0
    swi Sound_Configure
    ldr r10, [r3, #8]   ; lin to log ptr.

    ; Convert 8-bit linear sample to log.
    ldr r8, generated_samples_p
    .20:
    ldrb r0, [r8]
    ldrb r0, [r10, r0, lsl #24-19]  ; 32-bit lin->log
    strb r0, [r8], #1
    .if LibConfig_ShowInitProgress && 0
    movs r1, r8, lsl #20            ; every 8k
    swieq OS_WriteI+'.'
    .endif
    cmp r8, r9
    blt .20

    ; Poke in magic number for QTM when using samples pre-converted to log.
    ldr r1, mod_track_p
    ldr r2, qtm4
    str r2, [r1, #1080]
    .endif

    ldr pc, [sp], #4

; ============================================================================

.include "src/gen/arcmusic.asm"

; ============================================================================
