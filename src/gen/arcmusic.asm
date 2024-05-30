; ============================================================================
; Generated with Aklang2Acorn.py v1.0, by kieran/Bitshifters 2024.
; Based on Alcatraz Amigaklang rendering core. (c) Jochen 'Virgill' Feldkötter 2020-2024.
; And Aklang2Asm by Dan/Lemon. 2021-2022.
; Input Aklang script = 'data/akp/Rhino1.mod.txt'
;
; Define macro 'AK_PROGRESS' for whatever per-instrument progress callback you require (if any).
; Define macro 'AK_FINE_PROGRESS' for whatever per-byte progress callback you require (if any).
; Define symbol 'AK_CLEAR_FIRST_2_BYTES' to true to zero out the first two bytes of each sample, Amiga style.
; Call 'AK_Generate' with the registers listed below.
; ============================================================================

.equ AK_MaxInstruments,		31
.equ AK_MaxExtSamples,		8

.equ AK_LPF,				0
.equ AK_HPF,				1
.equ AK_BPF,				2

.equ AK_CHORD1,				0
.equ AK_CHORD2,				1
.equ AK_CHORD3,				2

.equ ADSR_Attack,			0
.equ ADSR_Decay,			1
.equ ADSR_Sustain,			2
.equ ADSR_Release,			3

.equ AK_SMPLEN,				(AK_SmpLen-AK_Vars)
.equ AK_EXTSMPLEN,			(AK_ExtSmpLen-AK_Vars)
.equ AK_NOISESEEDS,			(AK_NoiseSeeds-AK_Vars)
.equ AK_SMPADDR,			(AK_SmpAddr-AK_Vars)
.equ AK_EXTSMPADDR,			(AK_ExtSmpAddr-AK_Vars)
.equ AK_OPINSTANCE,			(AK_OpInstance-AK_Vars)
.equ AK_ENVDVALUE,			(AK_EnvDValue-AK_Vars)
.equ AK_ADSRVALUES,			(AK_ADSRValues-AK_Vars)

.equ AK_SMP_LEN,			212036
.equ AK_EXT_SMP_LEN,		20384

; ============================================================================
; R8 = Sample Buffer Start Address (AK_SMP_LEN bytes)
; R9 = Temporary Work Buffer Address (AK_MaxTempBuffers * 2048 * 4 = AK_TempBufferSize bytes) (can be freed after sample rendering complete)
; R10 = External Samples Address (can be freed after sample rendering complete)
; ============================================================================

AK_Generate:
	str lr, [sp, #-4]!

	; Create sample & external sample base addresses
	adr r4, AK_SmpAddr
	adr r5, AK_SmpLen
	mov r7, #AK_MaxInstruments
	mov r0, r8
SmpAdrLoop:
	str r0, [r4], #4
	ldr r1, [r5], #4
	add r0, r0, r1
	subs r7, r7, #1
	bne SmpAdrLoop
	mov r7, #AK_MaxExtSamples
	adr r4, AK_ExtSmpAddr
	adr r5, AK_ExtSmpLen
	mov r0, r10
ExSmpAdrLoop:
	str r0, [r4], #4
	ldr r1, [r5], #4
	add r0, r0, r1
	subs r7, r7, #1
	bne ExSmpAdrLoop

.if AK_EXT_SMP_LEN > 0
	; Convert external samples from stored deltas
	mov r7, #AK_EXT_SMP_LEN
	mov r6, r10
	mov r0, #0
DeltaLoop:
	ldrb r1, [r6]
	mov r1, r1, asl #24
	mov r1, r1, asr #24
	add r0, r0, r1
	mov r0, r0, asl #24
	mov r0, r0, asr #24
	strb r0, [r6], #1
	subs r7, r7, #1
	bne DeltaLoop
.endif

; ============================================================================
; r0 = v1 (final sample value)
; r1 = v2
; r2 = v3
; r3 = v4
; r4 = temp
; r5 = temp
; r6 = temp
; r7 = Sample byte count
; r8 = Sample Buffer Start Address
; r9 = AK_MaxTempBuffers*2048 word (>=65536 byte) Temporary Work Buffer Address (can be freed after sample rendering complete)
; r10 = Base of AK_Vars
; r11 = 36767 (0x7fff)
; r12 = temp
; r14 = temp
; ============================================================================

	adr r10, AK_Vars
	mov r11, #32767	; const

;----------------------------------------------------------------------------
; Instrument 1 - 'Rhino-Kick'
;----------------------------------------------------------------------------

	mov r4, #AK_MaxTempBuffers	; buffers to clear
	bl AK_ResetVars
	mov r7, #0	; Sample byte count

	AK_PROGRESS

Inst1Loop:
	; v1 = imported_sample(smp,0);
	mov r0, r7
	ldr r6, [r10, #AK_EXTSMPADDR+4*0]
	ldr r4, [r10, #AK_EXTSMPLEN+4*0]
	cmp r0, r4
	movge r0, #0
	ldrltb r0, [r6, r0]
	mov r0, r0, asl #24
	mov r0, r0, asr #16

	mov r4, r0, asr #8
	strb r4, [r8], #1

	AK_FINE_PROGRESS

	add r7, r7, #1
	ldr r4, [r10, #AK_SMPLEN+4*0]
	cmp r7, r4
	blt Inst1Loop

;----------------------------------------------------------------------------
; Instrument 2 - 'Rhino-Kick-Filter'
;----------------------------------------------------------------------------

	mov r4, #0	; buffers to clear
	bl AK_ResetVars
	mov r7, #0	; Sample byte count

	AK_PROGRESS

Inst2Loop:
	; v1 = clone(smp,0, 0);
	mov r0, r7
	ldr r6, [r10, #AK_SMPADDR+4*0]
	ldr r4, [r10, #AK_SMPLEN+4*0]
	cmp r0, r4
	movge r0, #0
	ldrltb r0, [r6, r0]
	mov r0, r0, asl #24
	mov r0, r0, asr #16

	; v1 = cmb_flt_n(1, v1, 32, 98, 128);
	ldr r6, [r10, #AK_OPINSTANCE+4*0]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 98)
	mov r14, #98
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	add r0, r0, r4
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768
	str r0, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #32
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*0]
	; v1 = vol(v1, 128)
	; NOOP -- val<<7>>7
	add r9, r9, #2048*4	; next temp buffer.

	; v1 = sv_flt_n(2, v1, 18, 0, 2);
	add r14, r10, #AK_OPINSTANCE+4*(1+AK_LPF)
	ldmia r14, {r4-r6}
	mov r14, r6, asr #7
	mov r12, #18
	mla r4, r14, r12, r4
	; r4 = clamp(r4)
	cmp r4, r11		; #32767
	movgt r4, r11	; #32767
	cmn r4, r11		; #-32768
	mvnlt r4, r11	; #-32768
	str r4, [r10, #AK_OPINSTANCE+4*(1+AK_LPF)]
	mov r12, #0
	mul r14, r12, r14
	mov r12, r0
	sub r12, r12, r4
	sub r5, r12, r14
	; r5 = clamp(r5)
	cmp r5, r11		; #32767
	movgt r5, r11	; #32767
	cmn r5, r11		; #-32768
	mvnlt r5, r11	; #-32768
	str r5, [r10, #AK_OPINSTANCE+4*(1+AK_HPF)]
	mov r14, r5, asr #7
	mov r12, #18
	mla r6, r12, r14, r6
	; r6 = clamp(r6)
	cmp r6, r11		; #32767
	movgt r6, r11	; #32767
	cmn r6, r11		; #-32768
	mvnlt r6, r11	; #-32768
	str r6, [r10, #AK_OPINSTANCE+4*(1+AK_BPF)]
	mov r0, r6

	sub r9, r9, #2048*4*1	; reset temp buffer base.
	mov r4, r0, asr #8
	strb r4, [r8], #1

	AK_FINE_PROGRESS

	add r7, r7, #1
	ldr r4, [r10, #AK_SMPLEN+4*1]
	cmp r7, r4
	blt Inst2Loop

;----------------------------------------------------------------------------
; Instrument 3 - 'Rhino-Snare'
;----------------------------------------------------------------------------

	mov r4, #1	; buffers to clear
	bl AK_ResetVars
	mov r7, #0	; Sample byte count

	AK_PROGRESS

Inst3Loop:
	; v1 = imported_sample(smp,1);
	mov r0, r7
	ldr r6, [r10, #AK_EXTSMPADDR+4*1]
	ldr r4, [r10, #AK_EXTSMPLEN+4*1]
	cmp r0, r4
	movge r0, #0
	ldrltb r0, [r6, r0]
	mov r0, r0, asl #24
	mov r0, r0, asr #16

	; v3 = enva(2, 6, 0, 128);
	ldr r6, [r10, #AK_OPINSTANCE+4*0]
	mov r2, r6, asr #8
	mov r4, #6553
	add r6, r6, r4
	cmp r6, r11, asl #8
	movgt r6, r11, asl #8
	str r6, [r10, #AK_OPINSTANCE+4*0]
	; v3 = vol(v3, 128)
	; NOOP -- val<<7>>7

	; v2 = mul(v1, v3);
	mul r1, r0, r2
	mov r1, r1, asr #15
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.

	; v2 = dly_cyc(4, v2, 1024, 52);
	mov r4, r1
	; r4 = vol(r4, 52)
	mov r14, #52
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	ldr r6, [r10, #AK_OPINSTANCE+4*1]
	str r4, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #1024
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*1]
	ldr r1, [r9, r6, lsl #2]
	add r9, r9, #2048*4	; next temp buffer.

	; v1 = add(v1, v2);
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r0, r0, r1
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768

	sub r9, r9, #2048*4*1	; reset temp buffer base.
	mov r4, r0, asr #8
	strb r4, [r8], #1

	AK_FINE_PROGRESS

	add r7, r7, #1
	ldr r4, [r10, #AK_SMPLEN+4*2]
	cmp r7, r4
	blt Inst3Loop

;----------------------------------------------------------------------------
; Instrument 4 - 'Rhino-Snare-Reverb'
;----------------------------------------------------------------------------

	mov r4, #1	; buffers to clear
	bl AK_ResetVars
	mov r7, #0	; Sample byte count

	AK_PROGRESS

Inst4Loop:
	; v1 = imported_sample(smp,1);
	mov r0, r7
	ldr r6, [r10, #AK_EXTSMPADDR+4*1]
	ldr r4, [r10, #AK_EXTSMPLEN+4*1]
	cmp r0, r4
	movge r0, #0
	ldrltb r0, [r6, r0]
	mov r0, r0, asl #24
	mov r0, r0, asr #16

	; v3 = enva(1, 6, 0, 128);
	ldr r6, [r10, #AK_OPINSTANCE+4*0]
	mov r2, r6, asr #8
	mov r4, #6553
	add r6, r6, r4
	cmp r6, r11, asl #8
	movgt r6, r11, asl #8
	str r6, [r10, #AK_OPINSTANCE+4*0]
	; v3 = vol(v3, 128)
	; NOOP -- val<<7>>7

	; v2 = mul(v1, v3);
	mul r1, r0, r2
	mov r1, r1, asr #15
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.

	; v2 = sv_flt_n(3, v2, 18, 127, 1);
	add r14, r10, #AK_OPINSTANCE+4*(1+AK_LPF)
	ldmia r14, {r4-r6}
	mov r14, r6, asr #7
	mov r12, #18
	mla r4, r14, r12, r4
	; r4 = clamp(r4)
	cmp r4, r11		; #32767
	movgt r4, r11	; #32767
	cmn r4, r11		; #-32768
	mvnlt r4, r11	; #-32768
	str r4, [r10, #AK_OPINSTANCE+4*(1+AK_LPF)]
	mov r12, #127
	mul r14, r12, r14
	mov r12, r1
	sub r12, r12, r4
	sub r5, r12, r14
	; r5 = clamp(r5)
	cmp r5, r11		; #32767
	movgt r5, r11	; #32767
	cmn r5, r11		; #-32768
	mvnlt r5, r11	; #-32768
	str r5, [r10, #AK_OPINSTANCE+4*(1+AK_HPF)]
	mov r14, r5, asr #7
	mov r12, #18
	mla r6, r12, r14, r6
	; r6 = clamp(r6)
	cmp r6, r11		; #32767
	movgt r6, r11	; #32767
	cmn r6, r11		; #-32768
	mvnlt r6, r11	; #-32768
	str r6, [r10, #AK_OPINSTANCE+4*(1+AK_BPF)]
	mov r1, r5

	; v2 = reverb(v2, 127, 16);
	ldr r6, [r10, #AK_OPINSTANCE+4*4]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 127)
	mov r14, #127
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r12, r1, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #557
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*4]
	; r12 = vol(r12, 16)
	mov r12, r12, asr #3	; val<<4>>7
	add r9, r9, #2048*4	; next temp buffer.
	mov r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*5]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 127)
	mov r14, #127
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r12, r1, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #593
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*5]
	; r12 = vol(r12, 16)
	mov r12, r12, asr #3	; val<<4>>7
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*6]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 127)
	mov r14, #127
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r12, r1, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #641
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*6]
	; r12 = vol(r12, 16)
	mov r12, r12, asr #3	; val<<4>>7
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*7]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 127)
	mov r14, #127
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r12, r1, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #677
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*7]
	; r12 = vol(r12, 16)
	mov r12, r12, asr #3	; val<<4>>7
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*8]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 127)
	mov r14, #127
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r12, r1, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #709
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*8]
	; r12 = vol(r12, 16)
	mov r12, r12, asr #3	; val<<4>>7
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*9]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 127)
	mov r14, #127
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r12, r1, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #743
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*9]
	; r12 = vol(r12, 16)
	mov r12, r12, asr #3	; val<<4>>7
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*10]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 127)
	mov r14, #127
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r12, r1, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #787
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*10]
	; r12 = vol(r12, 16)
	mov r12, r12, asr #3	; val<<4>>7
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*11]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 127)
	mov r14, #127
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r12, r1, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #809
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*11]
	; r12 = vol(r12, 16)
	mov r12, r12, asr #3	; val<<4>>7
	add r9, r9, #2048*4	; next temp buffer.
	add r1, r5, r12
	; v2 = clamp(v2)
	cmp r1, r11		; #32767
	movgt r1, r11	; #32767
	cmn r1, r11		; #-32768
	mvnlt r1, r11	; #-32768

	; v1 = add(v1, v2);
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r0, r0, r1
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768

	sub r9, r9, #2048*4*8	; reset temp buffer base.
	mov r4, r0, asr #8
	strb r4, [r8], #1

	AK_FINE_PROGRESS

	add r7, r7, #1
	ldr r4, [r10, #AK_SMPLEN+4*3]
	cmp r7, r4
	blt Inst4Loop

;----------------------------------------------------------------------------
; Instrument 4 - Loop Generator (Offset: 3228 Length: 2404)
;----------------------------------------------------------------------------

	mov r7, #2402	; BUG FIX: -2 from length to avoid reading beyond end of buffer
	ldr r6, [r10, #AK_SMPADDR+4*3]
	add r6, r6, #3230	; src1 (additional +2 offset in AmigaKlangGUI because Amiga)

	sub r4, r6, r7	; src2
	mov r0, r11, lsl #8	; 32767<<8
	mov r1, r7
	bl divide
	mov r5, r0	; delta = divs.w(32767<<8,repeat_length)
	mov r14, #0	; rampup
	mov r12, r11, lsl #8	; rampdown
LoopGen_4:
	mov r3, r14, lsr #8
	mov r2, r12, lsr #8
	ldrb r1, [r6]
	mov r1, r1, asl #24
	mov r1, r1, asr #24
	ldrb r0, [r4], #1
	mov r0, r0, asl #24
	mov r0, r0, asr #24
	mul r0, r3, r0
	mov r0, r0, asr #7
	mul r1, r2, r1
	add r0, r0, r1, asr #7
	mov r0, r0, asr #8
	strb r0, [r6], #1
	add r14, r14, r5
	sub r12, r12, r5

	AK_FINE_PROGRESS

	subs r7, r7, #1
	bne LoopGen_4

;----------------------------------------------------------------------------
; Instrument 5 - 'Rhino-Hat1'
;----------------------------------------------------------------------------

	mov r4, #8	; buffers to clear
	bl AK_ResetVars
	mov r7, #0	; Sample byte count

	AK_PROGRESS

Inst5Loop:
	; v1 = imported_sample(smp,3);
	mov r0, r7
	ldr r6, [r10, #AK_EXTSMPADDR+4*3]
	ldr r4, [r10, #AK_EXTSMPLEN+4*3]
	cmp r0, r4
	movge r0, #0
	ldrltb r0, [r6, r0]
	mov r0, r0, asl #24
	mov r0, r0, asr #16

	mov r4, r0, asr #8
	strb r4, [r8], #1

	AK_FINE_PROGRESS

	add r7, r7, #1
	ldr r4, [r10, #AK_SMPLEN+4*4]
	cmp r7, r4
	blt Inst5Loop

;----------------------------------------------------------------------------
; Instrument 6 - 'Rhino-Hat2'
;----------------------------------------------------------------------------

	mov r4, #0	; buffers to clear
	bl AK_ResetVars
	mov r7, #0	; Sample byte count

	AK_PROGRESS

Inst6Loop:
	; v1 = imported_sample(smp,4);
	mov r0, r7
	ldr r6, [r10, #AK_EXTSMPADDR+4*4]
	ldr r4, [r10, #AK_EXTSMPLEN+4*4]
	cmp r0, r4
	movge r0, #0
	ldrltb r0, [r6, r0]
	mov r0, r0, asl #24
	mov r0, r0, asr #16

	mov r4, r0, asr #8
	strb r4, [r8], #1

	AK_FINE_PROGRESS

	add r7, r7, #1
	ldr r4, [r10, #AK_SMPLEN+4*5]
	cmp r7, r4
	blt Inst6Loop

;----------------------------------------------------------------------------
; Instrument 7 - 'Rhino-Kick+Hat'
;----------------------------------------------------------------------------

	mov r4, #0	; buffers to clear
	bl AK_ResetVars
	mov r7, #0	; Sample byte count

	AK_PROGRESS

Inst7Loop:
	; v1 = imported_sample(smp,0);
	mov r0, r7
	ldr r6, [r10, #AK_EXTSMPADDR+4*0]
	ldr r4, [r10, #AK_EXTSMPLEN+4*0]
	cmp r0, r4
	movge r0, #0
	ldrltb r0, [r6, r0]
	mov r0, r0, asl #24
	mov r0, r0, asr #16

	; v2 = imported_sample(smp,3);
	mov r1, r7
	ldr r6, [r10, #AK_EXTSMPADDR+4*3]
	ldr r4, [r10, #AK_EXTSMPLEN+4*3]
	cmp r1, r4
	movge r1, #0
	ldrltb r1, [r6, r1]
	mov r1, r1, asl #24
	mov r1, r1, asr #16

	; v1 = add(v1, v2);
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r0, r0, r1
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768

	mov r4, r0, asr #8
	strb r4, [r8], #1

	AK_FINE_PROGRESS

	add r7, r7, #1
	ldr r4, [r10, #AK_SMPLEN+4*6]
	cmp r7, r4
	blt Inst7Loop

;----------------------------------------------------------------------------
; Instrument 8 - 'Rhino-Percussion-Reverb'
;----------------------------------------------------------------------------

	mov r4, #0	; buffers to clear
	bl AK_ResetVars
	mov r7, #0	; Sample byte count

	AK_PROGRESS

Inst8Loop:
	; v1 = imported_sample(smp,2);
	mov r0, r7
	ldr r6, [r10, #AK_EXTSMPADDR+4*2]
	ldr r4, [r10, #AK_EXTSMPLEN+4*2]
	cmp r0, r4
	movge r0, #0
	ldrltb r0, [r6, r0]
	mov r0, r0, asl #24
	mov r0, r0, asr #16

	; v3 = enva(1, 3, 0, 128);
	ldr r6, [r10, #AK_OPINSTANCE+4*0]
	mov r2, r6, asr #8
	mov r4, #16384
	add r6, r6, r4
	cmp r6, r11, asl #8
	movgt r6, r11, asl #8
	str r6, [r10, #AK_OPINSTANCE+4*0]
	; v3 = vol(v3, 128)
	; NOOP -- val<<7>>7

	; v2 = mul(v1, v3);
	mul r1, r0, r2
	mov r1, r1, asr #15
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.

	; v2 = sv_flt_n(3, v2, 19, 127, 1);
	add r14, r10, #AK_OPINSTANCE+4*(1+AK_LPF)
	ldmia r14, {r4-r6}
	mov r14, r6, asr #7
	mov r12, #19
	mla r4, r14, r12, r4
	; r4 = clamp(r4)
	cmp r4, r11		; #32767
	movgt r4, r11	; #32767
	cmn r4, r11		; #-32768
	mvnlt r4, r11	; #-32768
	str r4, [r10, #AK_OPINSTANCE+4*(1+AK_LPF)]
	mov r12, #127
	mul r14, r12, r14
	mov r12, r1
	sub r12, r12, r4
	sub r5, r12, r14
	; r5 = clamp(r5)
	cmp r5, r11		; #32767
	movgt r5, r11	; #32767
	cmn r5, r11		; #-32768
	mvnlt r5, r11	; #-32768
	str r5, [r10, #AK_OPINSTANCE+4*(1+AK_HPF)]
	mov r14, r5, asr #7
	mov r12, #19
	mla r6, r12, r14, r6
	; r6 = clamp(r6)
	cmp r6, r11		; #32767
	movgt r6, r11	; #32767
	cmn r6, r11		; #-32768
	mvnlt r6, r11	; #-32768
	str r6, [r10, #AK_OPINSTANCE+4*(1+AK_BPF)]
	mov r1, r5

	; v2 = reverb(v2, 112, 24);
	ldr r6, [r10, #AK_OPINSTANCE+4*4]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 112)
	mov r14, #112
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r12, r1, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #557
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*4]
	; r12 = vol(r12, 24)
	mov r14, #24
	mul r12, r14, r12
	mov r12, r12, asr #7
	mov r12, r12, asl #16
	mov r12, r12, asr #16	; Sign extend word to long.
	add r9, r9, #2048*4	; next temp buffer.
	mov r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*5]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 112)
	mov r14, #112
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r12, r1, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #593
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*5]
	; r12 = vol(r12, 24)
	mov r14, #24
	mul r12, r14, r12
	mov r12, r12, asr #7
	mov r12, r12, asl #16
	mov r12, r12, asr #16	; Sign extend word to long.
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*6]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 112)
	mov r14, #112
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r12, r1, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #641
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*6]
	; r12 = vol(r12, 24)
	mov r14, #24
	mul r12, r14, r12
	mov r12, r12, asr #7
	mov r12, r12, asl #16
	mov r12, r12, asr #16	; Sign extend word to long.
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*7]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 112)
	mov r14, #112
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r12, r1, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #677
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*7]
	; r12 = vol(r12, 24)
	mov r14, #24
	mul r12, r14, r12
	mov r12, r12, asr #7
	mov r12, r12, asl #16
	mov r12, r12, asr #16	; Sign extend word to long.
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*8]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 112)
	mov r14, #112
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r12, r1, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #709
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*8]
	; r12 = vol(r12, 24)
	mov r14, #24
	mul r12, r14, r12
	mov r12, r12, asr #7
	mov r12, r12, asl #16
	mov r12, r12, asr #16	; Sign extend word to long.
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*9]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 112)
	mov r14, #112
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r12, r1, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #743
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*9]
	; r12 = vol(r12, 24)
	mov r14, #24
	mul r12, r14, r12
	mov r12, r12, asr #7
	mov r12, r12, asl #16
	mov r12, r12, asr #16	; Sign extend word to long.
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*10]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 112)
	mov r14, #112
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r12, r1, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #787
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*10]
	; r12 = vol(r12, 24)
	mov r14, #24
	mul r12, r14, r12
	mov r12, r12, asr #7
	mov r12, r12, asl #16
	mov r12, r12, asr #16	; Sign extend word to long.
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*11]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 112)
	mov r14, #112
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r12, r1, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #809
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*11]
	; r12 = vol(r12, 24)
	mov r14, #24
	mul r12, r14, r12
	mov r12, r12, asr #7
	mov r12, r12, asl #16
	mov r12, r12, asr #16	; Sign extend word to long.
	add r9, r9, #2048*4	; next temp buffer.
	add r1, r5, r12
	; v2 = clamp(v2)
	cmp r1, r11		; #32767
	movgt r1, r11	; #32767
	cmn r1, r11		; #-32768
	mvnlt r1, r11	; #-32768

	; v1 = add(v1, v2);
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r0, r0, r1
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768

	sub r9, r9, #2048*4*8	; reset temp buffer base.
	mov r4, r0, asr #8
	strb r4, [r8], #1

	AK_FINE_PROGRESS

	add r7, r7, #1
	ldr r4, [r10, #AK_SMPLEN+4*7]
	cmp r7, r4
	blt Inst8Loop

;----------------------------------------------------------------------------
; Instrument 8 - Loop Generator (Offset: 3800 Length: 3368)
;----------------------------------------------------------------------------

	mov r7, #3366	; BUG FIX: -2 from length to avoid reading beyond end of buffer
	ldr r6, [r10, #AK_SMPADDR+4*7]
	add r6, r6, #3802	; src1 (additional +2 offset in AmigaKlangGUI because Amiga)

	sub r4, r6, r7	; src2
	mov r0, r11, lsl #8	; 32767<<8
	mov r1, r7
	bl divide
	mov r5, r0	; delta = divs.w(32767<<8,repeat_length)
	mov r14, #0	; rampup
	mov r12, r11, lsl #8	; rampdown
LoopGen_8:
	mov r3, r14, lsr #8
	mov r2, r12, lsr #8
	ldrb r1, [r6]
	mov r1, r1, asl #24
	mov r1, r1, asr #24
	ldrb r0, [r4], #1
	mov r0, r0, asl #24
	mov r0, r0, asr #24
	mul r0, r3, r0
	mov r0, r0, asr #7
	mul r1, r2, r1
	add r0, r0, r1, asr #7
	mov r0, r0, asr #8
	strb r0, [r6], #1
	add r14, r14, r5
	sub r12, r12, r5

	AK_FINE_PROGRESS

	subs r7, r7, #1
	bne LoopGen_8

;----------------------------------------------------------------------------
; Instrument 9 - 'Rhino-Percussion-Loop'
;----------------------------------------------------------------------------

	mov r4, #8	; buffers to clear
	bl AK_ResetVars
	mov r7, #0	; Sample byte count

	AK_PROGRESS

Inst9Loop:
	; v1 = imported_sample(smp,2);
	mov r0, r7
	ldr r6, [r10, #AK_EXTSMPADDR+4*2]
	ldr r4, [r10, #AK_EXTSMPLEN+4*2]
	cmp r0, r4
	movge r0, #0
	ldrltb r0, [r6, r0]
	mov r0, r0, asl #24
	mov r0, r0, asr #16

	; v1 = sh(1, v1, 2);
	ldr r6, [r10, #AK_OPINSTANCE+4*0]
	subs r6, r6, #1
	strlt r0, [r10, #AK_OPINSTANCE+4*1]
	movlt r6, #1
	str r6, [r10, #AK_OPINSTANCE+4*0]
	ldr r0, [r10, #AK_OPINSTANCE+4*1]

	; v3 = enva(2, 6, 0, 128);
	ldr r6, [r10, #AK_OPINSTANCE+4*2]
	mov r2, r6, asr #8
	mov r4, #6553
	add r6, r6, r4
	cmp r6, r11, asl #8
	movgt r6, r11, asl #8
	str r6, [r10, #AK_OPINSTANCE+4*2]
	; v3 = vol(v3, 128)
	; NOOP -- val<<7>>7

	; v2 = mul(v1, v3);
	mul r1, r0, r2
	mov r1, r1, asr #15
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.

	; v2 = cmb_flt_n(4, v2, 1024, 94, 128);
	ldr r6, [r10, #AK_OPINSTANCE+4*3]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 94)
	mov r14, #94
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r1, r1, r4
	; v2 = clamp(v2)
	cmp r1, r11		; #32767
	movgt r1, r11	; #32767
	cmn r1, r11		; #-32768
	mvnlt r1, r11	; #-32768
	str r1, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #1024
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*3]
	; v2 = vol(v2, 128)
	; NOOP -- val<<7>>7
	add r9, r9, #2048*4	; next temp buffer.

	; v1 = add(v1, v2);
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r0, r0, r1
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768

	sub r9, r9, #2048*4*1	; reset temp buffer base.
	mov r4, r0, asr #8
	strb r4, [r8], #1

	AK_FINE_PROGRESS

	add r7, r7, #1
	ldr r4, [r10, #AK_SMPLEN+4*8]
	cmp r7, r4
	blt Inst9Loop

;----------------------------------------------------------------------------
; Instrument 10 - 'Rhino-Kickbass1'
;----------------------------------------------------------------------------

	mov r4, #1	; buffers to clear
	bl AK_ResetVars
	mov r7, #0	; Sample byte count

	AK_PROGRESS

Inst10Loop:
	; v1 = clone(smp,6, 0);
	mov r0, r7
	ldr r6, [r10, #AK_SMPADDR+4*6]
	ldr r4, [r10, #AK_SMPLEN+4*6]
	cmp r0, r4
	movge r0, #0
	ldrltb r0, [r6, r0]
	mov r0, r0, asl #24
	mov r0, r0, asr #16

	; v1 = cmb_flt_n(1, v1, 512, 112, 128);
	ldr r6, [r10, #AK_OPINSTANCE+4*0]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 112)
	mov r14, #112
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	add r0, r0, r4
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768
	str r0, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #512
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*0]
	; v1 = vol(v1, 128)
	; NOOP -- val<<7>>7
	add r9, r9, #2048*4	; next temp buffer.

	; v2 = envd(2, 11, 0, 128);
	mov r4, #2048
	mul r6, r7, r4
	subs r6, r11, r6, asr #8
	movle r6, #0
	mov r1, r6
	; v2 = vol(v2, 128)
	; NOOP -- val<<7>>7

	; v2 = mul(v2, 128);
	mov r1, r1, asr #8	; val<<7>>15

	; v1 = sv_flt_n(4, v1, v2, 127, 0);
	add r14, r10, #AK_OPINSTANCE+4*(1+AK_LPF)
	ldmia r14, {r4-r6}
	mov r14, r6, asr #7
	mla r4, r1, r14, r4
	; r4 = clamp(r4)
	cmp r4, r11		; #32767
	movgt r4, r11	; #32767
	cmn r4, r11		; #-32768
	mvnlt r4, r11	; #-32768
	str r4, [r10, #AK_OPINSTANCE+4*(1+AK_LPF)]
	mov r12, #127
	mul r14, r12, r14
	mov r12, r0
	sub r12, r12, r4
	sub r5, r12, r14
	; r5 = clamp(r5)
	cmp r5, r11		; #32767
	movgt r5, r11	; #32767
	cmn r5, r11		; #-32768
	mvnlt r5, r11	; #-32768
	str r5, [r10, #AK_OPINSTANCE+4*(1+AK_HPF)]
	mov r14, r5, asr #7
	mla r6, r1, r14, r6
	; r6 = clamp(r6)
	cmp r6, r11		; #32767
	movgt r6, r11	; #32767
	cmn r6, r11		; #-32768
	mvnlt r6, r11	; #-32768
	str r6, [r10, #AK_OPINSTANCE+4*(1+AK_BPF)]
	mov r0, r4

	sub r9, r9, #2048*4*1	; reset temp buffer base.
	mov r4, r0, asr #8
	strb r4, [r8], #1

	AK_FINE_PROGRESS

	add r7, r7, #1
	ldr r4, [r10, #AK_SMPLEN+4*9]
	cmp r7, r4
	blt Inst10Loop

;----------------------------------------------------------------------------
; Instrument 11 - 'Rhino-Kickbass2'
;----------------------------------------------------------------------------

	mov r4, #1	; buffers to clear
	bl AK_ResetVars
	mov r7, #0	; Sample byte count

	AK_PROGRESS

Inst11Loop:
	; v1 = clone(smp,0, 0);
	mov r0, r7
	ldr r6, [r10, #AK_SMPADDR+4*0]
	ldr r4, [r10, #AK_SMPLEN+4*0]
	cmp r0, r4
	movge r0, #0
	ldrltb r0, [r6, r0]
	mov r0, r0, asl #24
	mov r0, r0, asr #16

	; v1 = cmb_flt_n(1, v1, 512, 112, 128);
	ldr r6, [r10, #AK_OPINSTANCE+4*0]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 112)
	mov r14, #112
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	add r0, r0, r4
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768
	str r0, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #512
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*0]
	; v1 = vol(v1, 128)
	; NOOP -- val<<7>>7
	add r9, r9, #2048*4	; next temp buffer.

	; v2 = envd(2, 11, 0, 128);
	mov r4, #2048
	mul r6, r7, r4
	subs r6, r11, r6, asr #8
	movle r6, #0
	mov r1, r6
	; v2 = vol(v2, 128)
	; NOOP -- val<<7>>7

	; v2 = mul(v2, 128);
	mov r1, r1, asr #8	; val<<7>>15

	; v3 = osc_saw(4, 512, 22);
	ldr r4, [r10, #AK_OPINSTANCE+4*1]
	add r4, r4, #512
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	str r4, [r10, #AK_OPINSTANCE+4*1]	
	; v3 = vol(v5, 22)
	mov r14, #22
	mul r2, r14, r4
	mov r2, r2, asr #7
	mov r2, r2, asl #16
	mov r2, r2, asr #16	; Sign extend word to long.

	; v1 = add(v1, v3);
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	mov r2, r2, asl #16
	mov r2, r2, asr #16	; Sign extend word to long.
	add r0, r0, r2
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768

	; v1 = sv_flt_n(6, v1, v2, 127, 0);
	add r14, r10, #AK_OPINSTANCE+4*(2+AK_LPF)
	ldmia r14, {r4-r6}
	mov r14, r6, asr #7
	mla r4, r1, r14, r4
	; r4 = clamp(r4)
	cmp r4, r11		; #32767
	movgt r4, r11	; #32767
	cmn r4, r11		; #-32768
	mvnlt r4, r11	; #-32768
	str r4, [r10, #AK_OPINSTANCE+4*(2+AK_LPF)]
	mov r12, #127
	mul r14, r12, r14
	mov r12, r0
	sub r12, r12, r4
	sub r5, r12, r14
	; r5 = clamp(r5)
	cmp r5, r11		; #32767
	movgt r5, r11	; #32767
	cmn r5, r11		; #-32768
	mvnlt r5, r11	; #-32768
	str r5, [r10, #AK_OPINSTANCE+4*(2+AK_HPF)]
	mov r14, r5, asr #7
	mla r6, r1, r14, r6
	; r6 = clamp(r6)
	cmp r6, r11		; #32767
	movgt r6, r11	; #32767
	cmn r6, r11		; #-32768
	mvnlt r6, r11	; #-32768
	str r6, [r10, #AK_OPINSTANCE+4*(2+AK_BPF)]
	mov r0, r4

	sub r9, r9, #2048*4*1	; reset temp buffer base.
	mov r4, r0, asr #8
	strb r4, [r8], #1

	AK_FINE_PROGRESS

	add r7, r7, #1
	ldr r4, [r10, #AK_SMPLEN+4*10]
	cmp r7, r4
	blt Inst11Loop

;----------------------------------------------------------------------------
; Instrument 12 - 'Rhino-Percussion-Synth'
;----------------------------------------------------------------------------

	mov r4, #1	; buffers to clear
	bl AK_ResetVars
	mov r7, #0	; Sample byte count

	AK_PROGRESS

Inst12Loop:
	; v1 = clone(smp,2, 0);
	mov r0, r7
	ldr r6, [r10, #AK_SMPADDR+4*2]
	ldr r4, [r10, #AK_SMPLEN+4*2]
	cmp r0, r4
	movge r0, #0
	ldrltb r0, [r6, r0]
	mov r0, r0, asl #24
	mov r0, r0, asr #16

	; v1 = cmb_flt_n(1, v1, 512, 112, 128);
	ldr r6, [r10, #AK_OPINSTANCE+4*0]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 112)
	mov r14, #112
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	add r0, r0, r4
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768
	str r0, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #512
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*0]
	; v1 = vol(v1, 128)
	; NOOP -- val<<7>>7
	add r9, r9, #2048*4	; next temp buffer.

	; v2 = envd(2, 11, 0, 128);
	mov r4, #2048
	mul r6, r7, r4
	subs r6, r11, r6, asr #8
	movle r6, #0
	mov r1, r6
	; v2 = vol(v2, 128)
	; NOOP -- val<<7>>7

	; v2 = mul(v2, 128);
	mov r1, r1, asr #8	; val<<7>>15

	; v1 = sv_flt_n(4, v1, v2, 127, 0);
	add r14, r10, #AK_OPINSTANCE+4*(1+AK_LPF)
	ldmia r14, {r4-r6}
	mov r14, r6, asr #7
	mla r4, r1, r14, r4
	; r4 = clamp(r4)
	cmp r4, r11		; #32767
	movgt r4, r11	; #32767
	cmn r4, r11		; #-32768
	mvnlt r4, r11	; #-32768
	str r4, [r10, #AK_OPINSTANCE+4*(1+AK_LPF)]
	mov r12, #127
	mul r14, r12, r14
	mov r12, r0
	sub r12, r12, r4
	sub r5, r12, r14
	; r5 = clamp(r5)
	cmp r5, r11		; #32767
	movgt r5, r11	; #32767
	cmn r5, r11		; #-32768
	mvnlt r5, r11	; #-32768
	str r5, [r10, #AK_OPINSTANCE+4*(1+AK_HPF)]
	mov r14, r5, asr #7
	mla r6, r1, r14, r6
	; r6 = clamp(r6)
	cmp r6, r11		; #32767
	movgt r6, r11	; #32767
	cmn r6, r11		; #-32768
	mvnlt r6, r11	; #-32768
	str r6, [r10, #AK_OPINSTANCE+4*(1+AK_BPF)]
	mov r0, r4

	sub r9, r9, #2048*4*1	; reset temp buffer base.
	mov r4, r0, asr #8
	strb r4, [r8], #1

	AK_FINE_PROGRESS

	add r7, r7, #1
	ldr r4, [r10, #AK_SMPLEN+4*11]
	cmp r7, r4
	blt Inst12Loop

;----------------------------------------------------------------------------
; Instrument 13 - 'Rhino-String-Low'
;----------------------------------------------------------------------------

	mov r4, #1	; buffers to clear
	bl AK_ResetVars
	mov r7, #0	; Sample byte count

	AK_PROGRESS

Inst13Loop:
	; v1 = imported_sample(smp,5);
	mov r0, r7
	ldr r6, [r10, #AK_EXTSMPADDR+4*5]
	ldr r4, [r10, #AK_EXTSMPLEN+4*5]
	cmp r0, r4
	movge r0, #0
	ldrltb r0, [r6, r0]
	mov r0, r0, asl #24
	mov r0, r0, asr #16

	; v1 = reverb(v1, 127, 20);
	ldr r6, [r10, #AK_OPINSTANCE+4*0]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 127)
	mov r14, #127
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	add r12, r0, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #557
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*0]
	; r12 = vol(r12, 20)
	mov r14, #20
	mul r12, r14, r12
	mov r12, r12, asr #7
	mov r12, r12, asl #16
	mov r12, r12, asr #16	; Sign extend word to long.
	add r9, r9, #2048*4	; next temp buffer.
	mov r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*1]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 127)
	mov r14, #127
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	add r12, r0, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #593
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*1]
	; r12 = vol(r12, 20)
	mov r14, #20
	mul r12, r14, r12
	mov r12, r12, asr #7
	mov r12, r12, asl #16
	mov r12, r12, asr #16	; Sign extend word to long.
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*2]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 127)
	mov r14, #127
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	add r12, r0, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #641
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*2]
	; r12 = vol(r12, 20)
	mov r14, #20
	mul r12, r14, r12
	mov r12, r12, asr #7
	mov r12, r12, asl #16
	mov r12, r12, asr #16	; Sign extend word to long.
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*3]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 127)
	mov r14, #127
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	add r12, r0, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #677
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*3]
	; r12 = vol(r12, 20)
	mov r14, #20
	mul r12, r14, r12
	mov r12, r12, asr #7
	mov r12, r12, asl #16
	mov r12, r12, asr #16	; Sign extend word to long.
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*4]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 127)
	mov r14, #127
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	add r12, r0, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #709
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*4]
	; r12 = vol(r12, 20)
	mov r14, #20
	mul r12, r14, r12
	mov r12, r12, asr #7
	mov r12, r12, asl #16
	mov r12, r12, asr #16	; Sign extend word to long.
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*5]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 127)
	mov r14, #127
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	add r12, r0, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #743
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*5]
	; r12 = vol(r12, 20)
	mov r14, #20
	mul r12, r14, r12
	mov r12, r12, asr #7
	mov r12, r12, asl #16
	mov r12, r12, asr #16	; Sign extend word to long.
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*6]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 127)
	mov r14, #127
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	add r12, r0, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #787
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*6]
	; r12 = vol(r12, 20)
	mov r14, #20
	mul r12, r14, r12
	mov r12, r12, asr #7
	mov r12, r12, asl #16
	mov r12, r12, asr #16	; Sign extend word to long.
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*7]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 127)
	mov r14, #127
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	add r12, r0, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #809
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*7]
	; r12 = vol(r12, 20)
	mov r14, #20
	mul r12, r14, r12
	mov r12, r12, asr #7
	mov r12, r12, asl #16
	mov r12, r12, asr #16	; Sign extend word to long.
	add r9, r9, #2048*4	; next temp buffer.
	add r0, r5, r12
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768

	; v2 = osc_saw(2, 2048, 37);
	ldr r4, [r10, #AK_OPINSTANCE+4*8]
	add r4, r4, #2048
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	str r4, [r10, #AK_OPINSTANCE+4*8]	
	; v2 = vol(v5, 37)
	mov r14, #37
	mul r1, r14, r4
	mov r1, r1, asr #7
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.

	; v1 = add(v1, v2);
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r0, r0, r1
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768

	; v1 = sv_flt_n(5, v1, 48, 127, 0);
	add r14, r10, #AK_OPINSTANCE+4*(9+AK_LPF)
	ldmia r14, {r4-r6}
	mov r14, r6, asr #7
	mov r12, #48
	mla r4, r14, r12, r4
	; r4 = clamp(r4)
	cmp r4, r11		; #32767
	movgt r4, r11	; #32767
	cmn r4, r11		; #-32768
	mvnlt r4, r11	; #-32768
	str r4, [r10, #AK_OPINSTANCE+4*(9+AK_LPF)]
	mov r12, #127
	mul r14, r12, r14
	mov r12, r0
	sub r12, r12, r4
	sub r5, r12, r14
	; r5 = clamp(r5)
	cmp r5, r11		; #32767
	movgt r5, r11	; #32767
	cmn r5, r11		; #-32768
	mvnlt r5, r11	; #-32768
	str r5, [r10, #AK_OPINSTANCE+4*(9+AK_HPF)]
	mov r14, r5, asr #7
	mov r12, #48
	mla r6, r12, r14, r6
	; r6 = clamp(r6)
	cmp r6, r11		; #32767
	movgt r6, r11	; #32767
	cmn r6, r11		; #-32768
	mvnlt r6, r11	; #-32768
	str r6, [r10, #AK_OPINSTANCE+4*(9+AK_BPF)]
	mov r0, r4

	; v2 = osc_sine(7, 16, 128);
	ldr r6, [r10, #AK_OPINSTANCE+4*12]
	add r6, r6, #16
	str r6, [r10, #AK_OPINSTANCE+4*12]
	sub r6, r6, #16384
	mov r6, r6, asl #16
	mov r6, r6, asr #16	; Sign extend word to long.
	movs r4, r6
	rsblt r4, r4, #0
	sub r4, r11, r4	; #32767
	mul r4, r6, r4
	mov r4, r4, asr #16
	mov r4, r4, asl #3
	; v2 = vol(v5, 128)
	mov r1, r4	; NOOP -- val<<7>>7

	; v2 = mul(v2, 42);
	mov r14, #42
	mul r1, r14, r1
	mov r1, r1, asr #15
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.

	; v2 = add(v2, 42);
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	mov r14, #42
	add r1, r1, r14
	; v2 = clamp(v2)
	cmp r1, r11		; #32767
	movgt r1, r11	; #32767
	cmn r1, r11		; #-32768
	mvnlt r1, r11	; #-32768

	; v3 = osc_tri(10, 4096, v2);
	ldr r6, [r10, #AK_OPINSTANCE+4*13]
	add r6, r6, #4096
	mov r6, r6, asl #16
	mov r6, r6, asr #16	; Sign extend word to long.
	str r6, [r10, #AK_OPINSTANCE+4*13]
	cmp r6, #0
	mvnmi r6, r6
	sub r6, r6, #16384
	mov r2, r6, asl #1
	; v3 = vol(v3, v2)
	and r14, r1, #0xff
	mul r2, r14, r2
	mov r2, r2, asr #7
	mov r2, r2, asl #16
	mov r2, r2, asr #16	; Sign extend word to long.

	; v1 = add(v1, v3);
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	mov r2, r2, asl #16
	mov r2, r2, asr #16	; Sign extend word to long.
	add r0, r0, r2
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768

	sub r9, r9, #2048*4*8	; reset temp buffer base.
	mov r4, r0, asr #8
	strb r4, [r8], #1

	AK_FINE_PROGRESS

	add r7, r7, #1
	ldr r4, [r10, #AK_SMPLEN+4*12]
	cmp r7, r4
	blt Inst13Loop

;----------------------------------------------------------------------------
; Instrument 13 - Loop Generator (Offset: 24576 Length: 24576)
;----------------------------------------------------------------------------

	mov r7, #24574	; BUG FIX: -2 from length to avoid reading beyond end of buffer
	ldr r6, [r10, #AK_SMPADDR+4*12]
	add r6, r6, #24578	; src1 (additional +2 offset in AmigaKlangGUI because Amiga)

	sub r4, r6, r7	; src2
	mov r0, r11, lsl #8	; 32767<<8
	mov r1, r7
	bl divide
	mov r5, r0	; delta = divs.w(32767<<8,repeat_length)
	mov r14, #0	; rampup
	mov r12, r11, lsl #8	; rampdown
LoopGen_13:
	mov r3, r14, lsr #8
	mov r2, r12, lsr #8
	ldrb r1, [r6]
	mov r1, r1, asl #24
	mov r1, r1, asr #24
	ldrb r0, [r4], #1
	mov r0, r0, asl #24
	mov r0, r0, asr #24
	mul r0, r3, r0
	mov r0, r0, asr #7
	mul r1, r2, r1
	add r0, r0, r1, asr #7
	mov r0, r0, asr #8
	strb r0, [r6], #1
	add r14, r14, r5
	sub r12, r12, r5

	AK_FINE_PROGRESS

	subs r7, r7, #1
	bne LoopGen_13

;----------------------------------------------------------------------------
; Instrument 14 - 'Rhino-Kickbass-Reso'
;----------------------------------------------------------------------------

	mov r4, #8	; buffers to clear
	bl AK_ResetVars
	mov r7, #0	; Sample byte count

	AK_PROGRESS

Inst14Loop:
	; v1 = clone(smp,1, 0);
	mov r0, r7
	ldr r6, [r10, #AK_SMPADDR+4*1]
	ldr r4, [r10, #AK_SMPLEN+4*1]
	cmp r0, r4
	movge r0, #0
	ldrltb r0, [r6, r0]
	mov r0, r0, asl #24
	mov r0, r0, asr #16

	; v1 = cmb_flt_n(1, v1, 256, 112, 128);
	ldr r6, [r10, #AK_OPINSTANCE+4*0]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 112)
	mov r14, #112
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	add r0, r0, r4
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768
	str r0, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #256
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*0]
	; v1 = vol(v1, 128)
	; NOOP -- val<<7>>7
	add r9, r9, #2048*4	; next temp buffer.

	; v2 = envd(2, 11, 0, 128);
	mov r4, #2048
	mul r6, r7, r4
	subs r6, r11, r6, asr #8
	movle r6, #0
	mov r1, r6
	; v2 = vol(v2, 128)
	; NOOP -- val<<7>>7

	; v2 = mul(v2, 128);
	mov r1, r1, asr #8	; val<<7>>15

	; v1 = sv_flt_n(4, v1, v2, 14, 0);
	add r14, r10, #AK_OPINSTANCE+4*(1+AK_LPF)
	ldmia r14, {r4-r6}
	mov r14, r6, asr #7
	mla r4, r1, r14, r4
	; r4 = clamp(r4)
	cmp r4, r11		; #32767
	movgt r4, r11	; #32767
	cmn r4, r11		; #-32768
	mvnlt r4, r11	; #-32768
	str r4, [r10, #AK_OPINSTANCE+4*(1+AK_LPF)]
	mov r12, #14
	mul r14, r12, r14
	mov r12, r0
	sub r12, r12, r4
	sub r5, r12, r14
	; r5 = clamp(r5)
	cmp r5, r11		; #32767
	movgt r5, r11	; #32767
	cmn r5, r11		; #-32768
	mvnlt r5, r11	; #-32768
	str r5, [r10, #AK_OPINSTANCE+4*(1+AK_HPF)]
	mov r14, r5, asr #7
	mla r6, r1, r14, r6
	; r6 = clamp(r6)
	cmp r6, r11		; #32767
	movgt r6, r11	; #32767
	cmn r6, r11		; #-32768
	mvnlt r6, r11	; #-32768
	str r6, [r10, #AK_OPINSTANCE+4*(1+AK_BPF)]
	mov r0, r4

	sub r9, r9, #2048*4*1	; reset temp buffer base.
	mov r4, r0, asr #8
	strb r4, [r8], #1

	AK_FINE_PROGRESS

	add r7, r7, #1
	ldr r4, [r10, #AK_SMPLEN+4*13]
	cmp r7, r4
	blt Inst14Loop

;----------------------------------------------------------------------------
; Instrument 15 - 'Rhino-Chord1'
;----------------------------------------------------------------------------

	mov r4, #1	; buffers to clear
	bl AK_ResetVars
	mov r7, #0	; Sample byte count

	AK_PROGRESS

Inst15Loop:
	; v1 = chordgen(0, 12, 3, 7, 10, 0);
	ldr r4, [r10, #AK_SMPADDR+4*12]
	ldr r12, [r10, #AK_SMPLEN+4*12]
	ldrb r6, [r4, r7]
	mov r6, r6, asl #24
	mov r6, r6, asr #17
	add r4, r4, #0
	sub r12, r12, #0
	ldr r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD1)]
	cmp r12, r5, lsr #16
	ldrgtb r14, [r4, r5, lsr #16]
	movle r14, #0
	add r5, r5, #77824
	str r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD1)]
	mov r14, r14, asl #24
	add r6, r6, r14, asr #17
	ldr r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD2)]
	cmp r12, r5, lsr #16
	ldrgtb r14, [r4, r5, lsr #16]
	movle r14, #0
	add r5, r5, #98048
	str r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD2)]
	mov r14, r14, asl #24
	add r6, r6, r14, asr #17
	ldr r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD3)]
	cmp r12, r5, lsr #15
	ldrgtb r14, [r4, r5, lsr #15]
	movle r14, #0
	add r5, r5, #58368
	str r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD3)]
	mov r14, r14, asl #24
	add r6, r6, r14, asr #17
	mov r0, r6
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768

	; v1 = onepole_flt(1, v1, 16, 1);
	ldr r4, [r10, #AK_OPINSTANCE+4*3]	; pole
	mov r6, r4, asr #7
	mov r14, r0, asr #7
	mov r12, #16
	mul r5, r12, r14
	mul r6, r12, r6
	sub r4, r4, r6
	add r4, r4, r5
	; r4 = clamp(r4)
	cmp r4, r11		; #32767
	movgt r4, r11	; #32767
	cmn r4, r11		; #-32768
	mvnlt r4, r11	; #-32768
	str r4, [r10, #AK_OPINSTANCE+4*3]	; pole
	sub r0, r0, r4
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768

	; v2 = osc_sine(2, 256, 64);
	ldr r6, [r10, #AK_OPINSTANCE+4*4]
	add r6, r6, #256
	str r6, [r10, #AK_OPINSTANCE+4*4]
	sub r6, r6, #16384
	mov r6, r6, asl #16
	mov r6, r6, asr #16	; Sign extend word to long.
	movs r4, r6
	rsblt r4, r4, #0
	sub r4, r11, r4	; #32767
	mul r4, r6, r4
	mov r4, r4, asr #16
	mov r4, r4, asl #3
	; v2 = vol(v5, 64)
	mov r1, r4, asr #1	; val<<6>>7

	; v1 = add(v1, v2);
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r0, r0, r1
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768

	mov r4, r0, asr #8
	strb r4, [r8], #1

	AK_FINE_PROGRESS

	add r7, r7, #1
	ldr r4, [r10, #AK_SMPLEN+4*14]
	cmp r7, r4
	blt Inst15Loop

;----------------------------------------------------------------------------
; Instrument 15 - Loop Generator (Offset: 12288 Length: 12288)
;----------------------------------------------------------------------------

	mov r7, #12286	; BUG FIX: -2 from length to avoid reading beyond end of buffer
	ldr r6, [r10, #AK_SMPADDR+4*14]
	add r6, r6, #12290	; src1 (additional +2 offset in AmigaKlangGUI because Amiga)

	sub r4, r6, r7	; src2
	mov r0, r11, lsl #8	; 32767<<8
	mov r1, r7
	bl divide
	mov r5, r0	; delta = divs.w(32767<<8,repeat_length)
	mov r14, #0	; rampup
	mov r12, r11, lsl #8	; rampdown
LoopGen_15:
	mov r3, r14, lsr #8
	mov r2, r12, lsr #8
	ldrb r1, [r6]
	mov r1, r1, asl #24
	mov r1, r1, asr #24
	ldrb r0, [r4], #1
	mov r0, r0, asl #24
	mov r0, r0, asr #24
	mul r0, r3, r0
	mov r0, r0, asr #7
	mul r1, r2, r1
	add r0, r0, r1, asr #7
	mov r0, r0, asr #8
	strb r0, [r6], #1
	add r14, r14, r5
	sub r12, r12, r5

	AK_FINE_PROGRESS

	subs r7, r7, #1
	bne LoopGen_15

;----------------------------------------------------------------------------
; Instrument 16 - 'Rhino-Chord2'
;----------------------------------------------------------------------------

	mov r4, #0	; buffers to clear
	bl AK_ResetVars
	mov r7, #0	; Sample byte count

	AK_PROGRESS

Inst16Loop:
	; v1 = chordgen(0, 12, 3, 8, 10, 0);
	ldr r4, [r10, #AK_SMPADDR+4*12]
	ldr r12, [r10, #AK_SMPLEN+4*12]
	ldrb r6, [r4, r7]
	mov r6, r6, asl #24
	mov r6, r6, asr #17
	add r4, r4, #0
	sub r12, r12, #0
	ldr r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD1)]
	cmp r12, r5, lsr #16
	ldrgtb r14, [r4, r5, lsr #16]
	movle r14, #0
	add r5, r5, #77824
	str r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD1)]
	mov r14, r14, asl #24
	add r6, r6, r14, asr #17
	ldr r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD2)]
	cmp r12, r5, lsr #15
	ldrgtb r14, [r4, r5, lsr #15]
	movle r14, #0
	add r5, r5, #51968
	str r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD2)]
	mov r14, r14, asl #24
	add r6, r6, r14, asr #17
	ldr r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD3)]
	cmp r12, r5, lsr #15
	ldrgtb r14, [r4, r5, lsr #15]
	movle r14, #0
	add r5, r5, #58368
	str r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD3)]
	mov r14, r14, asl #24
	add r6, r6, r14, asr #17
	mov r0, r6
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768

	; v1 = onepole_flt(1, v1, 16, 1);
	ldr r4, [r10, #AK_OPINSTANCE+4*3]	; pole
	mov r6, r4, asr #7
	mov r14, r0, asr #7
	mov r12, #16
	mul r5, r12, r14
	mul r6, r12, r6
	sub r4, r4, r6
	add r4, r4, r5
	; r4 = clamp(r4)
	cmp r4, r11		; #32767
	movgt r4, r11	; #32767
	cmn r4, r11		; #-32768
	mvnlt r4, r11	; #-32768
	str r4, [r10, #AK_OPINSTANCE+4*3]	; pole
	sub r0, r0, r4
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768

	; v2 = osc_sine(2, 409, 64);
	ldr r6, [r10, #AK_OPINSTANCE+4*4]
	add r6, r6, #409
	str r6, [r10, #AK_OPINSTANCE+4*4]
	sub r6, r6, #16384
	mov r6, r6, asl #16
	mov r6, r6, asr #16	; Sign extend word to long.
	movs r4, r6
	rsblt r4, r4, #0
	sub r4, r11, r4	; #32767
	mul r4, r6, r4
	mov r4, r4, asr #16
	mov r4, r4, asl #3
	; v2 = vol(v5, 64)
	mov r1, r4, asr #1	; val<<6>>7

	; v1 = add(v1, v2);
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r0, r0, r1
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768

	mov r4, r0, asr #8
	strb r4, [r8], #1

	AK_FINE_PROGRESS

	add r7, r7, #1
	ldr r4, [r10, #AK_SMPLEN+4*15]
	cmp r7, r4
	blt Inst16Loop

;----------------------------------------------------------------------------
; Instrument 16 - Loop Generator (Offset: 12288 Length: 12288)
;----------------------------------------------------------------------------

	mov r7, #12286	; BUG FIX: -2 from length to avoid reading beyond end of buffer
	ldr r6, [r10, #AK_SMPADDR+4*15]
	add r6, r6, #12290	; src1 (additional +2 offset in AmigaKlangGUI because Amiga)

	sub r4, r6, r7	; src2
	mov r0, r11, lsl #8	; 32767<<8
	mov r1, r7
	bl divide
	mov r5, r0	; delta = divs.w(32767<<8,repeat_length)
	mov r14, #0	; rampup
	mov r12, r11, lsl #8	; rampdown
LoopGen_16:
	mov r3, r14, lsr #8
	mov r2, r12, lsr #8
	ldrb r1, [r6]
	mov r1, r1, asl #24
	mov r1, r1, asr #24
	ldrb r0, [r4], #1
	mov r0, r0, asl #24
	mov r0, r0, asr #24
	mul r0, r3, r0
	mov r0, r0, asr #7
	mul r1, r2, r1
	add r0, r0, r1, asr #7
	mov r0, r0, asr #8
	strb r0, [r6], #1
	add r14, r14, r5
	sub r12, r12, r5

	AK_FINE_PROGRESS

	subs r7, r7, #1
	bne LoopGen_16

;----------------------------------------------------------------------------
; Instrument 17 - 'Rhino-Chord3'
;----------------------------------------------------------------------------

	mov r4, #0	; buffers to clear
	bl AK_ResetVars
	mov r7, #0	; Sample byte count

	AK_PROGRESS

Inst17Loop:
	; v1 = chordgen(0, 12, 2, 7, 9, 0);
	ldr r4, [r10, #AK_SMPADDR+4*12]
	ldr r12, [r10, #AK_SMPLEN+4*12]
	ldrb r6, [r4, r7]
	mov r6, r6, asl #24
	mov r6, r6, asr #17
	add r4, r4, #0
	sub r12, r12, #0
	ldr r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD1)]
	cmp r12, r5, lsr #16
	ldrgtb r14, [r4, r5, lsr #16]
	movle r14, #0
	add r5, r5, #73472
	str r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD1)]
	mov r14, r14, asl #24
	add r6, r6, r14, asr #17
	ldr r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD2)]
	cmp r12, r5, lsr #16
	ldrgtb r14, [r4, r5, lsr #16]
	movle r14, #0
	add r5, r5, #98048
	str r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD2)]
	mov r14, r14, asl #24
	add r6, r6, r14, asr #17
	ldr r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD3)]
	cmp r12, r5, lsr #15
	ldrgtb r14, [r4, r5, lsr #15]
	movle r14, #0
	add r5, r5, #55040
	str r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD3)]
	mov r14, r14, asl #24
	add r6, r6, r14, asr #17
	mov r0, r6
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768

	; v1 = onepole_flt(1, v1, 16, 1);
	ldr r4, [r10, #AK_OPINSTANCE+4*3]	; pole
	mov r6, r4, asr #7
	mov r14, r0, asr #7
	mov r12, #16
	mul r5, r12, r14
	mul r6, r12, r6
	sub r4, r4, r6
	add r4, r4, r5
	; r4 = clamp(r4)
	cmp r4, r11		; #32767
	movgt r4, r11	; #32767
	cmn r4, r11		; #-32768
	mvnlt r4, r11	; #-32768
	str r4, [r10, #AK_OPINSTANCE+4*3]	; pole
	sub r0, r0, r4
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768

	; v2 = osc_sine(2, 512, 64);
	ldr r6, [r10, #AK_OPINSTANCE+4*4]
	add r6, r6, #512
	str r6, [r10, #AK_OPINSTANCE+4*4]
	sub r6, r6, #16384
	mov r6, r6, asl #16
	mov r6, r6, asr #16	; Sign extend word to long.
	movs r4, r6
	rsblt r4, r4, #0
	sub r4, r11, r4	; #32767
	mul r4, r6, r4
	mov r4, r4, asr #16
	mov r4, r4, asl #3
	; v2 = vol(v5, 64)
	mov r1, r4, asr #1	; val<<6>>7

	; v1 = add(v1, v2);
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r0, r0, r1
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768

	mov r4, r0, asr #8
	strb r4, [r8], #1

	AK_FINE_PROGRESS

	add r7, r7, #1
	ldr r4, [r10, #AK_SMPLEN+4*16]
	cmp r7, r4
	blt Inst17Loop

;----------------------------------------------------------------------------
; Instrument 17 - Loop Generator (Offset: 12288 Length: 12288)
;----------------------------------------------------------------------------

	mov r7, #12286	; BUG FIX: -2 from length to avoid reading beyond end of buffer
	ldr r6, [r10, #AK_SMPADDR+4*16]
	add r6, r6, #12290	; src1 (additional +2 offset in AmigaKlangGUI because Amiga)

	sub r4, r6, r7	; src2
	mov r0, r11, lsl #8	; 32767<<8
	mov r1, r7
	bl divide
	mov r5, r0	; delta = divs.w(32767<<8,repeat_length)
	mov r14, #0	; rampup
	mov r12, r11, lsl #8	; rampdown
LoopGen_17:
	mov r3, r14, lsr #8
	mov r2, r12, lsr #8
	ldrb r1, [r6]
	mov r1, r1, asl #24
	mov r1, r1, asr #24
	ldrb r0, [r4], #1
	mov r0, r0, asl #24
	mov r0, r0, asr #24
	mul r0, r3, r0
	mov r0, r0, asr #7
	mul r1, r2, r1
	add r0, r0, r1, asr #7
	mov r0, r0, asr #8
	strb r0, [r6], #1
	add r14, r14, r5
	sub r12, r12, r5

	AK_FINE_PROGRESS

	subs r7, r7, #1
	bne LoopGen_17

;----------------------------------------------------------------------------
; Instrument 18 - 'Rhino-Chord4'
;----------------------------------------------------------------------------

	mov r4, #0	; buffers to clear
	bl AK_ResetVars
	mov r7, #0	; Sample byte count

	AK_PROGRESS

Inst18Loop:
	; v1 = chordgen(0, 12, 3, 8, 10, 57);
	ldr r4, [r10, #AK_SMPADDR+4*12]
	ldr r12, [r10, #AK_SMPLEN+4*12]
	ldrb r6, [r4, r7]
	mov r6, r6, asl #24
	mov r6, r6, asr #17
	add r4, r4, #57
	sub r12, r12, #57
	ldr r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD1)]
	cmp r12, r5, lsr #16
	ldrgtb r14, [r4, r5, lsr #16]
	movle r14, #0
	add r5, r5, #77824
	str r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD1)]
	mov r14, r14, asl #24
	add r6, r6, r14, asr #17
	ldr r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD2)]
	cmp r12, r5, lsr #15
	ldrgtb r14, [r4, r5, lsr #15]
	movle r14, #0
	add r5, r5, #51968
	str r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD2)]
	mov r14, r14, asl #24
	add r6, r6, r14, asr #17
	ldr r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD3)]
	cmp r12, r5, lsr #15
	ldrgtb r14, [r4, r5, lsr #15]
	movle r14, #0
	add r5, r5, #58368
	str r5, [r10, #AK_OPINSTANCE+4*(0+AK_CHORD3)]
	mov r14, r14, asl #24
	add r6, r6, r14, asr #17
	mov r0, r6
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768

	; v1 = onepole_flt(1, v1, 16, 1);
	ldr r4, [r10, #AK_OPINSTANCE+4*3]	; pole
	mov r6, r4, asr #7
	mov r14, r0, asr #7
	mov r12, #16
	mul r5, r12, r14
	mul r6, r12, r6
	sub r4, r4, r6
	add r4, r4, r5
	; r4 = clamp(r4)
	cmp r4, r11		; #32767
	movgt r4, r11	; #32767
	cmn r4, r11		; #-32768
	mvnlt r4, r11	; #-32768
	str r4, [r10, #AK_OPINSTANCE+4*3]	; pole
	sub r0, r0, r4
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768

	; v2 = osc_sine(2, 342, 64);
	ldr r6, [r10, #AK_OPINSTANCE+4*4]
	add r6, r6, #342
	str r6, [r10, #AK_OPINSTANCE+4*4]
	sub r6, r6, #16384
	mov r6, r6, asl #16
	mov r6, r6, asr #16	; Sign extend word to long.
	movs r4, r6
	rsblt r4, r4, #0
	sub r4, r11, r4	; #32767
	mul r4, r6, r4
	mov r4, r4, asr #16
	mov r4, r4, asl #3
	; v2 = vol(v5, 64)
	mov r1, r4, asr #1	; val<<6>>7

	; v1 = add(v1, v2);
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r0, r0, r1
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768

	mov r4, r0, asr #8
	strb r4, [r8], #1

	AK_FINE_PROGRESS

	add r7, r7, #1
	ldr r4, [r10, #AK_SMPLEN+4*17]
	cmp r7, r4
	blt Inst18Loop

;----------------------------------------------------------------------------
; Instrument 18 - Loop Generator (Offset: 12288 Length: 12288)
;----------------------------------------------------------------------------

	mov r7, #12286	; BUG FIX: -2 from length to avoid reading beyond end of buffer
	ldr r6, [r10, #AK_SMPADDR+4*17]
	add r6, r6, #12290	; src1 (additional +2 offset in AmigaKlangGUI because Amiga)

	sub r4, r6, r7	; src2
	mov r0, r11, lsl #8	; 32767<<8
	mov r1, r7
	bl divide
	mov r5, r0	; delta = divs.w(32767<<8,repeat_length)
	mov r14, #0	; rampup
	mov r12, r11, lsl #8	; rampdown
LoopGen_18:
	mov r3, r14, lsr #8
	mov r2, r12, lsr #8
	ldrb r1, [r6]
	mov r1, r1, asl #24
	mov r1, r1, asr #24
	ldrb r0, [r4], #1
	mov r0, r0, asl #24
	mov r0, r0, asr #24
	mul r0, r3, r0
	mov r0, r0, asr #7
	mul r1, r2, r1
	add r0, r0, r1, asr #7
	mov r0, r0, asr #8
	strb r0, [r6], #1
	add r14, r14, r5
	sub r12, r12, r5

	AK_FINE_PROGRESS

	subs r7, r7, #1
	bne LoopGen_18

;----------------------------------------------------------------------------
; Instrument 19 - 'Instrument_19'
;----------------------------------------------------------------------------

	mov r4, #0	; buffers to clear
	bl AK_ResetVars
	mov r7, #0	; Sample byte count

	AK_PROGRESS

Inst19Loop:
	mov r4, r0, asr #8
	strb r4, [r8], #1

	AK_FINE_PROGRESS

	add r7, r7, #1
	ldr r4, [r10, #AK_SMPLEN+4*18]
	cmp r7, r4
	blt Inst19Loop

;----------------------------------------------------------------------------
; Instrument 20 - 'Instrument_20'
;----------------------------------------------------------------------------

	mov r4, #0	; buffers to clear
	bl AK_ResetVars
	mov r7, #0	; Sample byte count

	AK_PROGRESS

Inst20Loop:
	mov r4, r0, asr #8
	strb r4, [r8], #1

	AK_FINE_PROGRESS

	add r7, r7, #1
	ldr r4, [r10, #AK_SMPLEN+4*19]
	cmp r7, r4
	blt Inst20Loop

;----------------------------------------------------------------------------
; Instrument 21 - 'Rhino-Pling-Reverb'
;----------------------------------------------------------------------------

	mov r4, #0	; buffers to clear
	bl AK_ResetVars
	mov r7, #0	; Sample byte count

	AK_PROGRESS

Inst21Loop:
	; v1 = imported_sample(smp,5);
	mov r0, r7
	ldr r6, [r10, #AK_EXTSMPADDR+4*5]
	ldr r4, [r10, #AK_EXTSMPLEN+4*5]
	cmp r0, r4
	movge r0, #0
	ldrltb r0, [r6, r0]
	mov r0, r0, asl #24
	mov r0, r0, asr #16

	; v1 = distortion(v1, 127);
	mov r14, #127
	mul r14, r0, r14
	mov r14, r14, asr #5
	; r14 = clamp(r14)
	cmp r14, r11		; #32767
	movgt r14, r11	; #32767
	cmn r14, r11		; #-32768
	mvnlt r14, r11	; #-32768
	mov r14, r14, asr #1
	movs r4, r14
	rsbmi r4, r4, #0	; abs(val)
	sub r4, r11, r4
	mul r4, r14, r4
	mov r4, r4, asr #16
	mov r0, r4, asl #3

	; v2 = osc_sine(2, 2048, 98);
	ldr r6, [r10, #AK_OPINSTANCE+4*0]
	add r6, r6, #2048
	str r6, [r10, #AK_OPINSTANCE+4*0]
	sub r6, r6, #16384
	mov r6, r6, asl #16
	mov r6, r6, asr #16	; Sign extend word to long.
	movs r4, r6
	rsblt r4, r4, #0
	sub r4, r11, r4	; #32767
	mul r4, r6, r4
	mov r4, r4, asr #16
	mov r4, r4, asl #3
	; v2 = vol(v5, 98)
	mov r14, #98
	mul r1, r14, r4
	mov r1, r1, asr #7
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.

	; v1 = add(v1, v2);
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	mov r1, r1, asl #16
	mov r1, r1, asr #16	; Sign extend word to long.
	add r0, r0, r1
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768

	; v3 = envd(4, 9, 0, 128);
	mov r4, #2978
	mul r6, r7, r4
	subs r6, r11, r6, asr #8
	movle r6, #0
	mov r2, r6
	; v3 = vol(v3, 128)
	; NOOP -- val<<7>>7

	; v1 = mul(v1, v3);
	mul r0, r2, r0
	mov r0, r0, asr #15
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.

	; v1 = reverb(v1, 112, 16);
	ldr r6, [r10, #AK_OPINSTANCE+4*1]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 112)
	mov r14, #112
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	add r12, r0, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #557
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*1]
	; r12 = vol(r12, 16)
	mov r12, r12, asr #3	; val<<4>>7
	add r9, r9, #2048*4	; next temp buffer.
	mov r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*2]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 112)
	mov r14, #112
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	add r12, r0, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #593
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*2]
	; r12 = vol(r12, 16)
	mov r12, r12, asr #3	; val<<4>>7
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*3]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 112)
	mov r14, #112
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	add r12, r0, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #641
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*3]
	; r12 = vol(r12, 16)
	mov r12, r12, asr #3	; val<<4>>7
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*4]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 112)
	mov r14, #112
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	add r12, r0, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #677
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*4]
	; r12 = vol(r12, 16)
	mov r12, r12, asr #3	; val<<4>>7
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*5]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 112)
	mov r14, #112
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	add r12, r0, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #709
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*5]
	; r12 = vol(r12, 16)
	mov r12, r12, asr #3	; val<<4>>7
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*6]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 112)
	mov r14, #112
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	add r12, r0, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #743
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*6]
	; r12 = vol(r12, 16)
	mov r12, r12, asr #3	; val<<4>>7
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*7]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 112)
	mov r14, #112
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	add r12, r0, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #787
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*7]
	; r12 = vol(r12, 16)
	mov r12, r12, asr #3	; val<<4>>7
	add r9, r9, #2048*4	; next temp buffer.
	add r5, r5, r12
	ldr r6, [r10, #AK_OPINSTANCE+4*8]
	ldr r4, [r9, r6, lsl #2]
	; r4 = vol(r4, 112)
	mov r14, #112
	mul r4, r14, r4
	mov r4, r4, asr #7
	mov r4, r4, asl #16
	mov r4, r4, asr #16	; Sign extend word to long.
	mov r0, r0, asl #16
	mov r0, r0, asr #16	; Sign extend word to long.
	add r12, r0, r4
	; r12 = clamp(r12)
	cmp r12, r11		; #32767
	movgt r12, r11	; #32767
	cmn r12, r11		; #-32768
	mvnlt r12, r11	; #-32768
	str r12, [r9, r6, lsl #2]
	add r6, r6, #1
	mov r14, #809
	cmp r6, r14
	movge r6, #0
	str r6, [r10, #AK_OPINSTANCE+4*8]
	; r12 = vol(r12, 16)
	mov r12, r12, asr #3	; val<<4>>7
	add r9, r9, #2048*4	; next temp buffer.
	add r0, r5, r12
	; v1 = clamp(v1)
	cmp r0, r11		; #32767
	movgt r0, r11	; #32767
	cmn r0, r11		; #-32768
	mvnlt r0, r11	; #-32768

	sub r9, r9, #2048*4*8	; reset temp buffer base.
	mov r4, r0, asr #8
	strb r4, [r8], #1

	AK_FINE_PROGRESS

	add r7, r7, #1
	ldr r4, [r10, #AK_SMPLEN+4*20]
	cmp r7, r4
	blt Inst21Loop

; ============================================================================

.if AK_CLEAR_FIRST_2_BYTES
	; Clear first 2 bytes of each sample
	adr r4, AK_SmpAddr
	mov r7, #21	; Num instruments.
	mov r0, #0
.0:
	ldr r6, [r4], #4
	strb r0, [r6]
	strb r0, [r6, #1]
	subs r7, r7, #1
	bne .0
.endif

	ldr pc, [sp], #4

; ============================================================================

AK_ResetVars:
	mov r0, #0
	mov r1, #0
	mov r2, #0
	mov r3, #0
	movs r4, r4, lsl #9	; num_buffers * 2048 * 4 / 16 = num_buffers * 512
	beq .2
	mov r6, r9	; Clear temp buffers (delay loop).
.1:
	stmia r6!, {r0-r3}
	subs r4, r4, #1
	bne .1
.2:
	add r6, r10, #AK_OPINSTANCE
	.rept 14	; Max OpInstance values.
	str r0, [r6], #4
	.endr
	; No envd values to reset.
	mov pc, lr

; ============================================================================

AK_Vars:
AK_SmpLen:
	.long 0x00000da0	; Instrument 1 Length
	.long 0x00000b00	; Instrument 2 Length
	.long 0x00000c00	; Instrument 3 Length
	.long 0x00001600	; Instrument 4 Length
	.long 0x00000400	; Instrument 5 Length
	.long 0x00000400	; Instrument 6 Length
	.long 0x00000da0	; Instrument 7 Length
	.long 0x00001c00	; Instrument 8 Length
	.long 0x00001000	; Instrument 9 Length
	.long 0x00001000	; Instrument 10 Length
	.long 0x00001000	; Instrument 11 Length
	.long 0x00001000	; Instrument 12 Length
	.long 0x0000c000	; Instrument 13 Length
	.long 0x00001000	; Instrument 14 Length
	.long 0x00006000	; Instrument 15 Length
	.long 0x00006000	; Instrument 16 Length
	.long 0x00006000	; Instrument 17 Length
	.long 0x00006000	; Instrument 18 Length
	.long 0x00000002	; Instrument 19 Length
	.long 0x00000002	; Instrument 20 Length
	.long 0x00004000	; Instrument 21 Length
	.long 0x00000000	; Instrument 22 Length
	.long 0x00000000	; Instrument 23 Length
	.long 0x00000000	; Instrument 24 Length
	.long 0x00000000	; Instrument 25 Length
	.long 0x00000000	; Instrument 26 Length
	.long 0x00000000	; Instrument 27 Length
	.long 0x00000000	; Instrument 28 Length
	.long 0x00000000	; Instrument 29 Length
	.long 0x00000000	; Instrument 30 Length
	.long 0x00000000	; Instrument 31 Length
AK_ExtSmpLen:
	.long 0x00000daa	; External Sample 1 Length
	.long 0x00000728	; External Sample 2 Length
	.long 0x000004fc	; External Sample 3 Length
	.long 0x000002f4	; External Sample 4 Length
	.long 0x00000320	; External Sample 5 Length
	.long 0x00002fbe	; External Sample 6 Length
	.long 0x00000000	; External Sample 7 Length
	.long 0x00000000	; External Sample 8 Length
AK_NoiseSeeds:
	.long 0x67452301
	.long 0xefcdab89
	.long 0x00000000
AK_SmpAddr:
	.skip AK_MaxInstruments*4
AK_ExtSmpAddr:
	.skip AK_MaxExtSamples*4
AK_OpInstance:
	.skip 14*4
AK_EnvDValue:
	; NB. Must follow AK_OpInstance!
AK_ADSRValues:

; ============================================================================

.equ AK_MaxTempBuffers, 8
.equ AK_TempBufferSize, 65536

; ============================================================================
