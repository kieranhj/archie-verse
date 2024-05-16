; ============================================================================
; Sine and cosine functions.
; ============================================================================

.if LibSine_MakeSinusTable
.equ LibSine_TableBits, 14                  ; 16384
.else
.equ LibSine_TableBits, 13                  ; 8192
.endif

.equ LibSine_TableSize, 1<<LibSine_TableBits
.equ LibSine_TableShift, 32-LibSine_TableBits

sinus_table_p:
    .long sinus_table_no_adr

; Sine.
; Parameters:
;  R0 = radians [0.0, 1.0] at fixed point precision. [s1.16]
; Returns:
;  R0 = sin(2 * PI * radians)
; Trashes: R9
sine:
    ldr r9, sinus_table_p
    mov r0, r0, asl #PRECISION_BITS         ; remove integer part
    mov r0, r0, lsr #LibSine_TableShift     ; remove insignificant bits
    ldr r0, [r9, r0, lsl #2]                ; lookup word
    mov pc, lr

; Cosine.
; Parameters:
;  R0 = radians [0.0, 1.0] at fixed point precision. [s1.16]
; Returns:
;  R0 = cos(2 * PI * radians)
; Trashes: R9
cosine:
    ldr r9, sinus_table_p
    add r0, r0, #MATHS_CONST_QUARTER                    ; add PI/2
    mov r0, r0, asl #PRECISION_BITS         ; remove integer part
    mov r0, r0, lsr #LibSine_TableShift      ; remove insignificant bits
    ldr r0, [r9, r0, lsl #2]                ; lookup word
    mov pc, lr

; Sine and Cosine.
; Parameters:
;  R0 = angle in brads [0-255]
; Returns:
;  R0 = sin(angle)
;  R1 = cos(angle)
; Trashes: R9
sin_cos:
    ldr r9, sinus_table_p
    mov r0, r0, asr #8                      ; convert brads to radians
    add r1, r0, #MATHS_CONST_QUARTER                    ; add PI/2
    mov r1, r1, asl #PRECISION_BITS         ; remove integer part
    mov r1, r1, lsr #LibSine_TableShift      ; remove insignificant bits
    ldr r1, [r9, r1, lsl #2]                ; lookup word
    mov r0, r0, asl #PRECISION_BITS         ; remove integer part
    mov r0, r0, lsr #LibSine_TableShift      ; remove insignificant bits
    ldr r0, [r9, r0, lsl #2]                ; lookup word
    mov pc, lr

; ============================================================================
; Converted to ARM from https://github.com/askeksa/Rose/blob/master/engine/Sinus.S
; ============================================================================

.if LibSine_MakeSinusTable
; Makes sine values [0-0x10000]
MakeSinus:
    ldr r8, sinus_table_p
    mov r10, #LibSine_TableSize/2*4       ; offset halfway through the table.
    sub r11, r10, #4            ; #LibSine_TableSize/2*4-4

    mov r0, #0
    str r0, [r8], #4
    add r9, r8, r11             ; #LibSine_TableSize/2*4-4
    str r0, [r9]

    mov r7, #1
.1:
    mov r1, r7
    mul r1, r7, r1              ; r7 ^2
    mov r1, r1, asr #8

    mov r0, #2373
    mul r0, r1, r0
    mov r0, r0, asr #16
    rsb r0, r0, #0
    add r0, r0, #21073
    mul r0, r1, r0
    mov r0, r0, asr #16
    rsb r0, r0, #0
    add r0, r0, #51469
    mul r0, r7, r0
    mov r0, r0, asr #13

    mov r0, r0, asl #2          ; NB. Rose originally [0x0, 0x4000]

    str r0, [r8], #4
    str r0, [r9, #-4]!
    rsb r0, r0, #0
    str r0, [r9, r10]           ; #LibSine_TableSize/2*4
    str r0, [r8, r11]           ; #LibSine_TableSize/2*4-4

    add r7, r7, #1
    cmp r7, #LibSine_TableSize/4
    blt .1

    rsb r0, r0, #0
    str r0, [r9, #-4]!
    rsb r0, r0, #0
    str r0, [r9, r10]
    mov pc, lr
.endif

; ============================================================================
