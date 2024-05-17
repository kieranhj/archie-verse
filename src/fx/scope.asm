; ============================================================================
; Scope FX.
; ============================================================================

.equ Scope_DrawLines,       1       ; otherwise points.
.equ Scope_StepBuffer,      1       ; otherwise truncate the buffer.

.equ Scope_Channel,         -1      ; or -1 for all four averaged

.equ Scope_YPos,            128
.equ Scope_XStep,           MATHS_CONST_1*320/Scope_TotalSamples
.equ Scope_YScale,          MATHS_CONST_1*0.5
.equ Scope_PixelColour,     15
.equ Scope_TotalSamples,    64      ; Max samples = 208

.equ Scope_MaxSamples,      208
.equ Scope_SampleStep,      MATHS_CONST_1*Scope_MaxSamples/Scope_TotalSamples

.equ Scope_NumHistories,    8

scope_log_to_lin_p:
    .long scope_log_to_lin_no_adr

scope_dma_buffer_copy_p:
    .long scope_dma_buffer_copy_no_adr

scope_histories_p:
    .long scope_dma_buffer_histories_no_adr

scope_histories_base:
    .long scope_dma_buffer_histories_no_adr

scope_histories_top:
    .long scope_dma_buffer_histories_top_no_adr


scope_init:
    mov r0, #0
    mov r1, #0
    mov r2, #0
    mov r3, #0

    ; Clear history buffers.
    ldr r7, scope_histories_base
    ldr r8, scope_histories_top
.2:
    stmia r7!, {r0-r3}
    cmp r7, r8
    blt .2

    ; Get ptr to log conversion table.
    ; Much faster than using swi Sound_SoundLog!
    mov r4, #0
    swi Sound_Configure
    ldr r10, [r3, #8]   ; lin to log ptr.

    ; Make log to linear table.
    ldr r9, scope_log_to_lin_p

    mov r1, #0          ; lin
.1:
    ldrb r0, [r10, r1, lsl #24-19-5]  ; 32-bit lin->log
    mov r2, r1, asr #5
    strb r2, [r9, r0]

    add r1, r1, #1
    cmp r1, #256<<5
    blt .1

    mov pc, lr

; R0=frame counter.
; R1=vsync delta.
scope_tick:
    QTMSWI QTM_DMABuffer
    ; R0 = address of last used DMA sound buffer (208 bytes per channel)
    ; Interleaved 1 byte per channel in 8-bit log format.

    mov r8, r0
    ldr r9, scope_dma_buffer_copy_p
    mov r10, #0             ; sample no.
.1:
    ldmia r8!, {r0-r7}
    stmia r9!, {r0-r7}
    add r10, r10, #8
    cmp r10, #Scope_MaxSamples
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
    mov r6, #0                  ; xpos in FP
.1:
.if Scope_Channel >= 0
    ldrb r1, [r0], #4       ; 4 channels so step over.

    ; Convert to signed linear.
    ldrb r1, [r9, r1]       ; log to lin.
    mov r1, r1, asl #24
    mov r1, r1, asr #24     ; sign extend.
.else
    .if Scope_StepBuffer
    mov r1, r10, lsr #16    ; FP to int
    ldr r1, [r0, r1, lsl #2]
    .else
    ldr r1, [r0], #4
    .endif

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
    mov r2, #Scope_YScale
    mul r1, r2, r1              ; TODO: Could be shift when final scale fixed?

    mov r1, r1, asr #16
    add r1, r1, #Scope_YPos            ; centre

    .if !Scope_DrawLines
    ; Calculate plot address.
    add r11, r12, r1, lsl #7
    add r11, r11, r1, lsl #5    ; y*160
    add r11, r11, r7, asr #1    ; +x/2

    ; Plot pixel.
	ldrb r8, [r11]				; load screen byte

    mov r7, r6, asr #16         ; xpos FP to int.
	tst r7, #1					; odd or even pixel?
	andeq r8, r8, #0xF0		    ; mask out left hand pixel
	orreq r8, r8, r5			; mask in colour as left hand pixel

	andne r8, r8, #0x0F		    ; mask out right hand pixel
	orrne r8, r8, r5, lsl #4	; mask in colour as right hand pixel

	strb r8, [r11]				; store screen byte
    .else
    stmfd sp!, {r0,r6,r9}

    mov r0, r6, asr #16         ; startx
    add r2, r6, #Scope_XStep    ; endx
    mov r2, r2, asr #16
    mov r3, r1                  ; endy
    cmp r10, #0
    movne r1, r11               ; starty
    mov r11, r3                 ; remember prev y
    mov r4, #Scope_PixelColour

    bl mode9_drawline_orr       ; TODO: Replace with custom line draw?

    ldmfd sp!, {r0,r6,r9}
    .endif

    ; Step xpos FP
    add r6, r6, #Scope_XStep

    ; Next sample.
    .if Scope_StepBuffer
    add r10, r10, #Scope_SampleStep
    cmp r10, #Scope_MaxSamples*MATHS_CONST_1
    .else
    add r10, r10, #1
    cmp r10, #Scope_TotalSamples
    .endif
    blt .1

    ldr pc, [sp], #4


; R0=frame counter.
; R1=vsync delta.
scope_tick_with_history:
    mov r12, r0

    QTMSWI QTM_DMABuffer
    ; R0 = address of last used DMA sound buffer (208 bytes per channel)
    ; Interleaved 1 byte per channel in 8-bit log format.

    mov r8, r0
    ldr r7, scope_histories_p
    ldr r9, scope_log_to_lin_p
    mov r10, #0             ; sample no.
.1:
    .if Scope_StepBuffer
    mov r1, r10, lsr #16    ; FP to int
    ldr r1, [r8, r1, lsl #2]
    .else
    ldr r1, [r8], #4
    .endif

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

    ; Store converted sample in history buffer.
    strb r1, [r7], #1

    ; Next sample.
    .if Scope_StepBuffer
    add r10, r10, #Scope_SampleStep
    cmp r10, #Scope_MaxSamples*MATHS_CONST_1
    .else
    add r10, r10, #1
    cmp r10, #Scope_TotalSamples
    .endif
    blt .1

    ands r12, r12, #15
    str r12, scope_history_offset
    movne pc, lr

    ; Ring buffer.
    ldr r11, scope_histories_top
    cmp r7, r11
    ldrge r7, scope_histories_base
    str r7, scope_histories_p

    mov pc, lr

scope_history_offset:
    .long 0

; R12=screen addr.
scope_draw_with_history:
    str lr, [sp, #-4]!

    ldr r9, scope_histories_p
    add r9, r9, #Scope_TotalSamples
    ldr r11, scope_histories_top
    cmp r9, r11
    ldrge r9, scope_histories_base

    mov r4, #16-Scope_NumHistories
    ldr r8, scope_history_offset
    rsb r8, r8, #80
.1:
    bl scope_draw_one_history

    ldr r1, scope_histories_top
    cmp r9, r1
    ldrge r9, scope_histories_base

    add r8, r8, #128/Scope_NumHistories
    add r4, r4, #1
    cmp r4, #16
    blt .1

    ldr pc, [sp], #4

scope_draw_line_seg_code_ptrs:
    .long line_segments_ptrs_no_adr

; R4=pixel colour.
; R8=y pos
; R9=history buffer ptr.
; R12=screen addr.
scope_draw_one_history:
    str lr, [sp, #-4]!

    orr r4, r4, r4, lsl #4      ; byte

    ldr r7, scope_draw_line_seg_code_ptrs

    mov r6, #0                  ; xpos in FP
    mov r10, #0                 ; sample no.
.1:
    ldrb r1, [r9], #1
    mov r1, r1, asl #24
    mov r1, r1, asr #24     ; sign extend.

    ; y value = sample value * scale.
    mov r2, #Scope_YScale
    mul r1, r2, r1              ; TODO: Could be shift when final scale fixed?

    mov r1, r1, asr #16
    add r1, r1, r8              ; ypos.

    .if 0
    cmp r10, #0
    moveq r11, r1
    beq .2

    ; Draw line.
    stmfd sp!, {r6,r8,r9,r10}

    mov r0, r6, asr #16         ; startx
    add r2, r6, #Scope_XStep    ; endx
    mov r2, r2, asr #16
    mov r3, r1                  ; endy
    mov r1, r11                 ; starty
    mov r11, r3                 ; remember prev y

    bl mode12_drawline       ; TODO: Replace with custom line draw?

    ldmfd sp!, {r6,r8,r9,r10}

    .2:
    ; Step xpos FP
    add r6, r6, #Scope_XStep
    .else
    cmp r10, #0
    addeq r11, r12, r1, lsl #8
    addeq r11, r11, r1, lsl #6  ; calc screen start address.
    beq .2

    sub r5, r1, r6              ; dy=y - prev_y
    and r5, r5, #0xff
    adr lr, .2
    ldr pc, [r7, r5, lsl #2]    ; (line_seg[dy])();
    .2:
    mov r6, r1                  ; prev y
    .endif

    ; Next sample.
    add r10, r10, #1
    cmp r10, #Scope_TotalSamples
    blt .1

    and r4, r4, #0xf

    ldr pc, [sp], #4
