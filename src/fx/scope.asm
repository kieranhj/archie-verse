; ============================================================================
; Scope FX.
; ============================================================================

.equ Scope_StepBuffer,      1       ; otherwise truncate the buffer.
.equ LineSegments_Fixed_dx, 4       ; fixed.

.equ Scope_FixActiveYPos,   1       ; fix the 'active' scope y pos.
.equ Scope_DrawBaseLine,    (Scope_BaseLine_Len > 0 && 1)
.equ Scope_HalfBaseLine,    (_SLOW_CPU && 1)

; Legacy features.
;.equ Scope_DrawLines,      1       ; otherwise points.
;.equ Scope_Channel,        -1      ; or -1 for all four averaged

.equ Scope_XStep,           MATHS_CONST_1*320/Scope_TotalSamples
.equ Scope_YScale,          MATHS_CONST_1*0.5  ; now fixed by shift.
.equ Scope_PixelColour,     15

.if _SLOW_CPU
.equ Scope_TotalSamples,    32      ; Max samples = 208
.else
.equ Scope_TotalSamples,    64      ; Max samples = 208
.endif

.equ Scope_MaxSamples,      208
.equ Scope_SampleStep,      MATHS_CONST_1*Scope_MaxSamples/Scope_TotalSamples

.if _SLOW_CPU
.equ Scope_NumHistories,    13
.equ Scope_YStep,           9
.else
.equ Scope_NumHistories,    14
.equ Scope_YStep,           9
.endif

.equ Scope_YPos,            216     ; Position of active scope.

;.equ Scope_YTop,            88      ; Or fix YStep?
;.equ Scope_YStep,           (Scope_YPos-Scope_YTop)/Scope_NumHistories

.equ Scope_BaseLine_Len,    (Screen_Stride-(Scope_TotalSamples*LineSegments_Fixed_dx))/2

; ============================================================================

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

scope_draw_line_seg_code_ptrs:
    .long line_segments_ptrs_no_adr

scope_draw_line_seg_y_buffer:
    .long line_segments_y_buffer_no_adr

scope_yscale:
    .long Scope_YScale      ; already *MATHS_CONST_1

scope_samplestep:
    .long Scope_SampleStep  ; already *MATHS_CONST_1

; ============================================================================

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

; ============================================================================
.if 0
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
.endif
; ============================================================================

; R0=frame counter.
; R1=vsync delta.
scope_tick_with_history:
    ldr r7, scope_histories_p

.if 0
;    ands r12, r0, #15              ; could do and #7 now!
    ; TODO: DO a MOD calc not a loop that's going to get slower over time!
.3:
    subs r0, r0, #Scope_YStep
    bpl .3
    adds r12, r0, #Scope_YStep
    str r12, scope_history_offset
.else
    ldr r12, scope_history_offset
    add r12, r12, #1                ; r1 assumes frames==vsyncs at the moment.
    cmp r12, #Scope_YStep
    subge r12, r12, #Scope_YStep    ; assumes vsync delta < y step.
    str r12, scope_history_offset
    cmp r12, #0
    bne .2
.endif

    ; Ring buffer.
    add r7, r7, #Scope_TotalSamples
    ldr r11, scope_histories_top
    cmp r7, r11
    ldrge r7, scope_histories_base
    str r7, scope_histories_p

.2:
    QTMSWI QTM_DMABuffer
    ; R0 = address of last used DMA sound buffer (208 bytes per channel)
    ; Interleaved 1 byte per channel in 8-bit log format.

    ldr r5, scope_samplestep

    mov r8, r0
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
    add r10, r10, r5
    cmp r10, #Scope_MaxSamples*MATHS_CONST_1
    .else
    add r10, r10, #1
    cmp r10, #Scope_TotalSamples
    .endif
    blt .1

    mov pc, lr

scope_history_offset:
    .long -1

; R12=screen addr.
scope_draw_with_history:
    str lr, [sp, #-4]!

    ; Reset y buffer.
    mov r0, #0xffffffff
    mov r1, r0
    mov r2, r0
    mov r3, r0
    ldr r4, scope_draw_line_seg_y_buffer
    mov r5, #Screen_Stride
.2:
    stmia r4!, {r0-r3}
    subs r5, r5, #16
    bgt .2

    ; Plot all the history buffers.
    ldr r9, scope_histories_p
    mov r4, #15

    .if Scope_FixActiveYPos
    mov r8, #Scope_YPos
    bl scope_draw_one_history
    ldr r8, scope_history_offset
    rsb r8, r8, #Scope_YPos+Scope_YStep-1
    b .3
    .else
    ldr r8, scope_history_offset
    rsb r8, r8, #Scope_YPos
    .endif

.1:
    bl scope_draw_one_history

    .3:
    sub r9, r9, #Scope_TotalSamples
    ldr r1, scope_histories_base
    cmp r9, r1
    ldrle r9, scope_histories_top
    sub r9, r9, #Scope_TotalSamples

    sub r8, r8, #Scope_YStep
    sub r4, r4, #1
    cmp r4, #16-Scope_NumHistories
    bge .1

    ldr pc, [sp], #4

; R4=pixel colour.
; R8=y pos
; R9=history buffer ptr.
; R12=screen addr.
scope_draw_one_history:
    str lr, [sp, #-4]!

    orr r4, r4, r4, lsl #4      ; byte

.if Scope_DrawBaseLine
    orr r4, r4, r4, lsl #8      ; half word.
    orr r4, r4, r4, lsl #16     ; full word.

    ; Zero baseline.
    add r11, r12, r8, lsl #8
    add r11, r11, r8, lsl #6  ; calc screen start address.
    
    .if Scope_HalfBaseLine
    add r11, r11, #4*(Scope_BaseLine_Len/8)
    .rept (Scope_BaseLine_Len)/8
    str r4, [r11], #4
    .endr
    .else
    .rept (Scope_BaseLine_Len)/4
    str r4, [r11], #4
    .endr
    .endif
.endif

    ldr r0, scope_yscale

    ldr r3, scope_draw_line_seg_y_buffer
    ldr r7, scope_draw_line_seg_code_ptrs

    ldrb r2, [r3]               ; min_y[0]
    mov r6, r8                  ; prev_y (or xpos in FP)
    mov r10, #0                 ; sample no.
.1:
    ldrb r1, [r9], #1
    mov r1, r1, asl #24
    mov r1, r1, asr #24         ; sign extend [-128,127]

    ; y value = sample value * scale.
    ;mov r2, #Scope_YScale
    ;mul r1, r2, r1
    ;mov r1, r1, asr #16
    mul r1, r0, r1
    mov r1, r1, asr #16
    ; Or fix in code:    
    ;mov r1, r1, asr #1          ; div 2 [-64,63]

    add r1, r1, r8              ; ypos.

    .if 0                       ; Test with full Bresenham line draw.
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

    bl mode12_drawline

    ldmfd sp!, {r6,r8,r9,r10}

    .2:
    ; Step xpos FP
    add r6, r6, #Scope_XStep
    .else
    sub r5, r1, r6              ; dy=y - prev_y

    .if !Scope_DrawBaseLine
    cmp r10, #0
    addeq r11, r12, r1, lsl #8
    addeq r11, r11, r1, lsl #6  ; calc screen start address.
    ldreqb r2, [r3]
    beq .2
    .endif

    ; Fast line segment draw.
    and r5, r5, #0xff
    adr lr, .2
    ldr pc, [r7, r5, lsl #2]    ; (line_seg[dy])();

    .2:
    mov r6, r1                  ; new prev y
    .endif

    ; Next sample.
    add r10, r10, #1
    cmp r10, #Scope_TotalSamples
    blt .1

.if Scope_DrawBaseLine
    ; Zero baseline.
    sub r5, r8, r6              ; dy=base_y - prev_y
    and r5, r5, #0xff
    adr lr, .3
    ldr pc, [r7, r5, lsl #2]    ; (line_seg[dy])();
    .3:

    tst r11, #3
    strneb r4, [r11], #1
    tst r11, #3
    strneb r4, [r11], #1
    tst r11, #3
    strneb r4, [r11], #1

    ; TOOD: This doesn't work 100% with all combos but whatevs.
    .if Scope_HalfBaseLine
    .rept (Scope_BaseLine_Len-4)/8
    str r4, [r11], #4
    .endr
    add r11, r11, #4*(Scope_BaseLine_Len/8)
    .else
    .rept (Scope_BaseLine_Len-4)/4
    str r4, [r11], #4
    .endr
    .endif
.endif

    and r4, r4, #0xf

    ldr pc, [sp], #4
