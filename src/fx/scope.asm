; ============================================================================
; Scope FX.
; ============================================================================

.equ Scope_Channel,         -1      ; or -1 for all four averaged

.equ Scope_XStep,           MATHS_CONST_1*320/Scope_TotalSamples
.equ Scope_YScale,          MATHS_CONST_1*0.5
.equ Scope_PixelColour,     15
.equ Scope_TotalSamples,    64      ; Max samples = 208
; TODO: Could also step through sample buffer not truncate it?

scope_log_to_lin_p:
    .long scope_log_to_lin_no_adr

scope_dma_buffer_copy_p:
    .long scope_dma_buffer_copy_no_adr

scope_init:
    ; Get ptr to log conversion table.
    ; Much faster than using swi Sound_SoundLog!
    mov r0, #0
    mov r1, #0
    mov r2, #0
    mov r3, #0
    mov r4, #0
    swi Sound_Configure
    ldr r10, [r3, #8]   ; lin to log ptr.

    ldr r9, scope_log_to_lin_p    ; TODO: Move to bss.

    mov r1, #0          ; lin
.1:
    ldrb r0, [r10, r1, lsl #24-19-5]  ; 32-bit lin->log
    mov r2, r1, asr #5
    strb r2, [r9, r0]

    add r1, r1, #1
    cmp r1, #256<<5
    blt .1

    mov pc, lr

scope_tick:
    QTMSWI QTM_DMABuffer
    ; R0 = address of last used DMA sound buffer (208 bytes per channel)
    ; Interleaved 1 byte per channel in 8-bit log format.

    mov r8, r0
    ldr r9, scope_dma_buffer_copy_p
    mov r10, #0             ; sample and x pos.
.1:
    ldmia r8!, {r0-r7}
    stmia r9!, {r0-r7}
    add r10, r10, #8
    cmp r10, #208
    blt .1
    mov pc, lr

; R12=screen addr.
scope_draw:
    str lr, [sp, #-4]!

    ; QTMSWI QTM_DMABuffer
    ; R0 = address of last used DMA sound buffer (208 bytes per channel)
    ; Interleaved 1 byte per channel in 8-bit log format.
    ldr r0, scope_dma_buffer_copy_p
    .if Scope_Channel > 0
    add r0, r0, #Scope_Channel
    .endif

    mov r5, #Scope_PixelColour  ; plot colour.
    ldr r9, scope_log_to_lin_p

    mov r10, #0                 ; sample no.
    mov r14, #0                 ; xpos in FP
.1:
    mov r7, r14, asr #16        ; xpos FP to int.

.if Scope_Channel >= 0
    ldrb r1, [r0], #4       ; 4 channels so step over.

    ; Convert to signed linear.
    ldrb r1, [r9, r1]       ; log to lin.
    mov r1, r1, asl #24
    mov r1, r1, asr #24     ; sign extend.
.else
    ldr r1, [r0], #4        ; 4 channels so step over.

    mov r4, r1, lsr #24     ; byte 3
    ldrb r4, [r9, r4]       ; log to lin.
    mov r4, r4, asl #24
    mov r4, r4, asr #24     ; sign extend.

    mov r3, r1, asl #8
    mov r3, r3, lsr #24     ; byte 2
    ldrb r3, [r9, r3]       ; log to lin.
    mov r3, r3, asl #24
    mov r3, r3, asr #24     ; sign extend.

    mov r2, r1, asl #16
    mov r2, r2, lsr #24     ; byte 1
    ldrb r2, [r9, r2]       ; log to lin.
    mov r2, r2, asl #24
    mov r2, r2, asr #24     ; sign extend.

    mov r1, r1, asl #24
    mov r1, r1, lsr #24     ; byte 0
    ldrb r1, [r9, r1]       ; log to lin.
    mov r1, r1, asl #24
    mov r1, r1, asr #24     ; sign extend.

    ; Average all signed linear samples.
    add r1, r1, r2
    add r1, r1, r3
    add r1, r1, r4
    mov r1, r1, asr #2      ; div 4
.endif

    ; y value = sample value * scale.
    mov r6, #Scope_YScale
    mul r1, r6, r1

    mov r1, r1, asr #16
    add r1, r1, #128            ; centre

    ; Calculate plot address.
    add r11, r12, r1, lsl #7
    add r11, r11, r1, lsl #5    ; y*160
    add r11, r11, r7, asr #1    ; +x/2

    ; Plot pixel.
	ldrb r8, [r11]				; load screen byte

	tst r7, #1					; odd or even pixel?
	andeq r8, r8, #0xF0		    ; mask out left hand pixel
	orreq r8, r8, r5			; mask in colour as left hand pixel

	andne r8, r8, #0x0F		    ; mask out right hand pixel
	orrne r8, r8, r5, lsl #4	; mask in colour as right hand pixel

	strb r8, [r11]				; store screen byte

    ; Step xpos FP
    add r14, r14, #Scope_XStep

    ; Next sample.
    add r10, r10, #1
    cmp r10, #Scope_TotalSamples               ; total samples.
    blt .1

    ldr pc, [sp], #4
