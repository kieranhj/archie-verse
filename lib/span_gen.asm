; ============================================================================
; Fast MODE 9 span plot routines.
; Code generated at runtime.
; Kindly provided by Progen (Sarah Walker).
; ============================================================================

gen_code_pointers_p:
	.long gen_code_pointers_no_adr

; Registers used during span plotting functions.
; r0 = not used
; r1 = X end (in pixels)
; r2 = not used [typically X start (in pixels)] <= colour word
; r3 = temp [word read from screen]
; r4 = not used <= colour word
; r5 = not used <= colour word
; r6 = temp [construct word to write]
; r7 = not used
; r8 = not used [typically Y rasterline for outer loop]
; r9 = colour word [preserved]
; r10 = ptr to screen addr [updated]
; r11 = ptr to start of screen rasterline [updated]
; r12 = not used
; r13 = not used
; r14 = link address

; screen=abcdefgh
; colour=iiiiiiii

gen_first_word_1:
	LDR r3, [r10]
	AND r3, r3, #0xf
	ORR r3, r3, r9, LSL #4		; iiiiiiih
	STR r3, [r10], #4
gen_first_word_2:
	LDR r3, [r10]
	AND r3, r3, #0xff
	ORR r3, r3, r9, LSL #8		; iiiiiigh
	STR r3, [r10], #4
gen_first_word_3:
	LDR r3, [r10]
	MOV r3, r3, LSL #20
	MOV r3, r3, LSR #20
	ORR r3, r3, r9, LSL #12		; iiiiifgh
	STR r3, [r10], #4
gen_first_word_4:
	LDR r3, [r10]
	MOV r3, r3, LSL #16
	MOV r3, r3, LSR #16
	ORR r3, r3, r9, LSL #16		; iiiiefgh
	STR r3, [r10], #4
gen_first_word_5:
	LDR r3, [r10]
	MOV r3, r3, LSL #12
	MOV r3, r3, LSR #12
	ORR r3, r3, r9, LSL #20		; iiidefgh
	STR r3, [r10], #4
gen_first_word_6:
	LDR r3, [r10]
	BIC r3, r3, #0xff000000
	ORR r3, r3, r9, LSL #24		; iicdefgh
	STR r3, [r10], #4
gen_first_word_7:
	LDR r3, [r10]
	BIC r3, r3, #0xf0000000
	ORR r3, r3, r9, LSL #28		; ibcdefgh
	STR r3, [r10], #4
gen_first_word_over:

gen_first_word_table:
	.long 0
	.long gen_first_word_1
	.long gen_first_word_2
	.long gen_first_word_3
	.long gen_first_word_4
	.long gen_first_word_5
	.long gen_first_word_6
	.long gen_first_word_7
	.long gen_first_word_over

gen_same_word_0:
        AND r1, r1, #7
	MOV r1, r1, LSL #2
	RSB r1, r1, #28
	MVN r3, #0
	MOV r1, r3, LSR r1	; r1=0 => r1=0x0000000f => treats xend as inclusive.

	LDR r3, [r10]
	BIC r3, r3, r1
	AND r6, r9, r1
	ORR r3, r3, r6
	STR r3, [r10]

gen_same_word_1:
        AND r1, r1, #7
	MOV r1, r1, LSL #2
	RSB r1, r1, #28
	MVN r3, #0
	MOV r1, r3, LSR r1

	LDR r3, [r10]
	BIC r1, r1, #0xf
	BIC r3, r3, r1
	AND r6, r9, r1
	ORR r3, r3, r6
	STR r3, [r10]

gen_same_word_2:
        AND r1, r1, #7
	MOV r1, r1, LSL #2
	RSB r1, r1, #28
	MVN r3, #0
	MOV r1, r3, LSR r1

	LDR r3, [r10]
	BIC r1, r1, #0xff
	BIC r3, r3, r1
	AND r6, r9, r1
	ORR r3, r3, r6
	STR r3, [r10]

gen_same_word_3:
        AND r1, r1, #7
	MOV r1, r1, LSL #2
	RSB r1, r1, #28
	MVN r3, #0
	MOV r1, r3, LSR r1

	LDR r3, [r10]
	MOV r1, r1, LSR #12
	BIC r3, r3, r1, LSL #12
	AND r6, r9, r1, LSL #12
	ORR r3, r3, r6
	STR r3, [r10]

gen_same_word_4:
        AND r1, r1, #7
	MOV r1, r1, LSL #2
	RSB r1, r1, #28
	MVN r3, #0
	MOV r1, r3, LSR r1

	LDR r3, [r10]
	MOV r1, r1, LSR #16
	BIC r3, r3, r1, LSL #16
	AND r6, r9, r1, LSL #16
	ORR r3, r3, r6
	STR r3, [r10]

gen_same_word_5:
        AND r1, r1, #7
	MOV r1, r1, LSL #2
	RSB r1, r1, #28
	MVN r3, #0
	MOV r1, r3, LSR r1

	LDR r3, [r10]
	MOV r1, r1, LSR #20
	BIC r3, r3, r1, LSL #20
	AND r6, r9, r1, LSL #20
	ORR r3, r3, r6
	STR r3, [r10]

gen_same_word_6:
        AND r1, r1, #7
	MOV r1, r1, LSL #2
	RSB r1, r1, #28
	MVN r3, #0
	MOV r1, r3, LSR r1

	LDR r3, [r10]
	MOV r1, r1, LSR #24
	BIC r3, r3, r1, LSL #24
	AND r6, r9, r1, LSL #24
	ORR r3, r3, r6
	STR r3, [r10]

gen_same_word_7:
        AND r1, r1, #7
	MOV r1, r1, LSL #2
	RSB r1, r1, #28
	MVN r3, #0
	MOV r1, r3, LSR r1

	LDR r3, [r10]
	MOV r1, r1, LSR #28
	BIC r3, r3, r1, LSL #28
	AND r6, r9, r1, LSL #28
	ORR r3, r3, r6
	STR r3, [r10]
gen_same_word_over:

gen_same_word_table:
	.long gen_same_word_0
	.long gen_same_word_1
	.long gen_same_word_2
	.long gen_same_word_3
	.long gen_same_word_4
	.long gen_same_word_5
	.long gen_same_word_6
	.long gen_same_word_7
	.long gen_same_word_over

gen_one_word:
	STR r9, [r10], #4
gen_one_word_end:

.if LibSpanGen_MultiWord > 1
gen_two_words:
	stmia r10!, {r5,r9}
gen_two_words_end:
.endif

.if LibSpanGen_MultiWord > 2
gen_four_words:
	stmia r10!, {r2,r4,r5,r9}
gen_four_words_end:
.endif

; screen=abcdefgh
; colour=iiiiiiii

gen_last_word_0:
	MOV r0, r0
gen_last_word_1:
	LDRB r3, [r10]
	BIC r3, r3, #0x0f
	ORR r3, r3, r9, LSR #28		; ih
	STRB r3, [r10]
gen_last_word_2:
	STRB r9, [r10]
gen_last_word_3:
	LDR r3, [r10]
	MOV r3, r3, LSR #12
	MOV r3, r3, LSL #12
	ORR r3, r3, r9, LSR #20		; abcdeiii
	STR r3, [r10]
gen_last_word_4:
	LDR r3, [r10]
	MOV r3, r3, LSR #16
	MOV r3, r3, LSL #16
	ORR r3, r3, r9, LSR #16		; abcdiiii
	STR r3, [r10]
gen_last_word_5:
	LDR r3, [r10]
	MOV r3, r3, LSR #20
	MOV r3, r3, LSL #20
	ORR r3, r3, r9, LSR #12		; abciiiii
	STR r3, [r10]
gen_last_word_6:
	LDR r3, [r10]
	AND r3, r3, #0xff000000
	ORR r3, r3, r9, LSR #8		; abiiiiii
	STR r3, [r10]
gen_last_word_7:
	LDR r3, [r10]
	AND r3, r3, #0xf0000000
	ORR r3, r3, r9, LSR #4		; aiiiiiii
	STR r3, [r10]
gen_last_word_over:

gen_last_word_table:
	.long gen_last_word_0
	.long gen_last_word_1
	.long gen_last_word_2
	.long gen_last_word_3
	.long gen_last_word_4
	.long gen_last_word_5
	.long gen_last_word_6
	.long gen_last_word_7
	.long gen_last_word_over

gen_end_code:
	mov pc, lr
; Specific to circle plot.
;	ADD r11, r11, #Screen_Stride
;	SUBS r14, r14, #1
gen_end_code_end:
; These branch instructions are patched at copy.
;	BNE circle_loop
;	.long circle_loop
;	B return_from_span_plot
;	.long return_from_span_plot

; R12=start of free RAM to place generated code.
gen_code:
	STR lr, [sp, #-4]!

	LDR r11, gen_code_pointers_p
    MOV r0, #0 ;first pixel offset - 0-7
	MOV r1, #1 ;length - 1-320

gen_code_main_loop:
	ADD r12, r12, #0xc ;Align to 16 byte boundary
	BIC r12, r12, #0xc
	STR r12, [r11], #4

	MOV r5, #0     ;current pixel

	ADD r2, r0, r1
	CMP r2, #8     ;Start and end lie in same word?
	BCC gen_code_same_word

	TST r0, #7
	BEQ gen_code_no_offset

	;Copy code to generate first word
	ADRL r2, gen_first_word_table
	ADD r2, r2, r0, LSL #2
	LDMIA r2, {r2-r3} ;r2-r3 - start and end addresses of code
gen_code_first_word_copy:
	LDR r4, [r2], #4
	STR r4, [r12], #4
	CMP r2, r3
	BNE gen_code_first_word_copy

	RSB r5, r0, #8

gen_code_no_offset:

gen_code_no_offset_loop:
	SUB r2, r1, r5  ;If less than 8 pixels remaining then jump to last word
	CMP r2, #8
	BCC gen_code_last_word

.if LibSpanGen_MultiWord > 2
	cmp r2, #32
	blt .1
	; four words = 32 pixels
    adr r2, gen_four_words
	adr r3, gen_four_words_end
	add r5, r5, #32
	b gen_code_main_loop_copy
.1:
.endif
.if LibSpanGen_MultiWord > 1
	cmp r2, #16
	blt .2
	; two words = 16 pixels
    adr r2, gen_two_words
	adr r3, gen_two_words_end
	add r5, r5, #16
	b gen_code_main_loop_copy
.2:
.endif

	ADRL r2, gen_one_word
	ADRL r3, gen_one_word_end
	ADD r5, r5, #8

gen_code_main_loop_copy:
	LDR r4, [r2], #4
	STR r4, [r12], #4
	CMP r2, r3
	BNE gen_code_main_loop_copy

	B gen_code_no_offset_loop

gen_code_last_word:
	TST r2, r2
	BEQ gen_code_complete

	;Copy code to generate last word
	ADR r3, gen_last_word_table
	ADD r2, r3, r2, LSL #2
	LDMIA r2, {r2-r3} ;r2-r3 - start and end addresses of code
gen_code_last_word_copy:
	LDR r4, [r2], #4
	STR r4, [r12], #4
	CMP r2, r3
	BNE gen_code_last_word_copy

gen_code_complete:
	;End of code
	ADRL r2, gen_end_code
	ADRL r3, gen_end_code_end
gen_code_end_copy:
	LDR r4, [r2], #4
	STR r4, [r12], #4
	CMP r2, r3
	BNE gen_code_end_copy

.if 0
	; Patch branch instruction with offset.
	LDMIA r2!, {r3-r4}
	AND r3, r3, #0xff000000
	SUB r4, r4, r12
	SUB r4, r4, #8
	MOV r4, r4, LSL #6
	ORR r3, r3, r4, LSR #8
	STR r3, [r12], #4

	; Patch branch instruction with offset.
	LDMIA r2!, {r3-r4}
	AND r3, r3, #0xff000000
	SUB r4, r4, r12
	SUB r4, r4, #8
	MOV r4, r4, LSL #6
	ORR r3, r3, r4, LSR #8
	STR r3, [r12], #4
.endif

	ADD r0, r0, #1
	ANDS r0, r0, #7
	BNE gen_code_main_loop
	ADD r1, r1, #1
	CMP r1, #LibSpanGen_MaxSpan
	BLE gen_code_main_loop
	LDR pc, [sp], #4
	; Return R12=RAM top.


gen_code_same_word:
	;Copy code to generate same word
	ADRL r2, gen_same_word_table
	ADD r2, r2, r0, LSL #2
	LDMIA r2, {r2-r3} ;r2-r3 - start and end addresses of code
gen_code_same_word_copy:
	LDR r4, [r2], #4
	STR r4, [r12], #4
	CMP r2, r3
	BNE gen_code_same_word_copy

	B gen_code_complete

; ============================================================================
