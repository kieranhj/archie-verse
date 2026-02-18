; ============================================================================
; Menu stuff.
; ============================================================================

.equ Mouse_Enable,			0			; TODO: Add mouse control back.

.equ Dj_Menu_MaxSprites, 		(Dj_Max_Songs+1)*2
.equ Dj_Menu_Song_Column, 		20			; aligned right.
.equ Dj_Menu_Artist_Column, 	26			; aligned left.

.equ Dj_Menu_MaxSpriteStride, 	20

.equ Dj_Menu_Top_YPos, 		94
.equ Dj_Menu_Row_Height, 		7
.equ Dj_Menu_Item_Colour, 		4
.equ Dj_Menu_Selection_Colour, 8

.equ Dj_Menu_Autoplay_Column, 	1

.if Mouse_Enable
prev_mouse_y:
	.long 0
.endif

selection_number:
	.long 0

playing_colour:
	.long 0

keyboard_prev_mask:
	.long 0

; R0=keyboard pressed mask
; R0=frame_counter
; R1=vsync delta
dj_menu_tick:
	str lr, [sp, #-4]!

.if 0
	ldr r2, keyboard_prev_mask
	mvn r2, r2				; ~old
	and r2, r0, r2			; new & ~old		; diff bits
	str r0, keyboard_prev_mask
	and r4, r2, r0			; diff bits & key down bits	

	; Update playing item colour.
    ldr r1, vsync_count
    ands r1, r1, #4
	moveq r0, #Dj_Menu_Selection_Colour
	movne r0, #Dj_Menu_Item_Colour
	str r0, playing_colour

	; check up
	tst r4, #1<<KeyBit_ArrowUp	; key changed & down?
	beq .2

	ldr r3, selection_number
	cmp r3, #0
	beq .2
	sub r3, r3, #1
	str r3, selection_number
	
.2:
	; check down
	tst r4, #1<<KeyBit_ArrowDown	; key changed & down?
	beq .3

	ldr r3, selection_number
	cmp r3, #Dj_Max_Songs
	bge .3
	add r3, r3, #1
	str r3, selection_number

.3:
	; Can't select new song if fade is active.
	ldr r0, volume_fade
	cmp r0, #0
	bne .5

	tst r4, #1<<KeyBit_A	; key changed & down?
	bne .10

	; check return & space
    .if Mouse_Enable
	tst r4, #1<<KeyBit_Return|1<<KeyBit_Space|1<<KeyBit_LeftClick	; key changed & down?
    .else
	tst r4, #1<<KeyBit_Return|1<<KeyBit_Space	; key changed & down?
	.endif
	beq .5

	; Select menu item.
	.4:
	ldr r3, song_number

	ldr r0, selection_number
	cmp r0, #Dj_Max_Songs
	blt .9

.10:
	; Toggle autplay.
	ldr r0, autoplay_flag
	eor r0, r0, #1
	bl set_autoplay

	mov r3, #Dj_Max_Songs
	b .5

	.9:
	; Don't restart current song as can be spammed.
	cmp r0, r3
	beq .5

	; Play song in R0.
	bl play_song

.5:

.if Mouse_Enable
	; Check mouse.
	swi OS_Mouse
	ldr r0, prev_mouse_y
	str r1, prev_mouse_y
	subs r0, r0, r1
	; R0=mouse delta
    rsbmi r0, r0, #0
	cmp r0, #Mouse_Sensitivity
	blt .6

    ; Absolute Y.
	mov r0, #1023
    mov r2, #Dj_Max_Songs+1
	sub r1, r0, r1
    mul r2, r1, r2
    mov r2, r2, lsr #10

	ldr r3, selection_number
	cmp r2, r3
	beq .6

    ; Absolute Y.
	mov r0, #1023
    mov r3, #Dj_Max_Songs+1
	ldr r1, prev_mouse_y
	sub r1, r0, r1
    mul r3, r1, r3
    mov r3, r3, lsr #10
	str r3, selection_number
.endif

.6:
	; Set QTM Vu Bars effect.
	tst r4, #1<<KeyBit_E|1<<KeyBit_F|1<<KeyBit_R|1<<KeyBit_1|1<<KeyBit_2|1<<KeyBit_3|1<<KeyBit_4|1<<KeyBit_5
	beq .7

	mov r0, #-1
	tst r4, #1<<KeyBit_F
	movne r0, #1			; 'fake' VU bars
	tst r4, #1<<KeyBit_E
	movne r0, #2			; 'effect' VU bars
	tst r4, #1<<KeyBit_R
	movne r0, #3			; 'real' VU bars

	mov r1, #-1
	tst r4, #1<<KeyBit_1
	movne r1, #1
	tst r4, #1<<KeyBit_2
	movne r1, #2
	tst r4, #1<<KeyBit_3
	movne r1, #3
	tst r4, #1<<KeyBit_4
	movne r1, #4
	tst r4, #1<<KeyBit_5
	movne r1, #5

	swi QTM_VUBarControl

.7:
	; check sine
	tst r4, #1<<KeyBit_S	; key changed & down?
	beq .8

	ldr r0, scroller_enable_sine
	eor r0, r0, #1
	str r0, scroller_enable_sine

.8:
.endif
	ldr pc, [sp], #4

; ============================================================================

; R7=sprite stride in bytes.
plot_dj_menu_sprite:
	ldr r0, dj_menu_sprite_code_p
	mov r7, r7, lsr #2		; sprite stride words.
	sub r7, r7, #1
	; R8=sprite no.
	; R9=sprite data ptr.
	; R10=colour word.
	; R11=screen addr.
	; R12=scanline start addr.
	ldr pc, [r0, r7, lsl #2]

; R12=screen addr.
dj_menu_draw:
	str lr, [sp, #-4]!

	; Start of line.
	mov r0, #Dj_Menu_Top_YPos
	add r12, r12, r0, lsl #7
	add r12, r12, r0, lsl #5

	; For all sprites.
	mov r8, #0
.1:
	; set colour word.
	mov r10, #Dj_Menu_Item_Colour

	; song_number = what's playing
	ldr r3, song_number
	mov r3, r3, lsl #1
	cmp r8, r3
	ldreq r10, playing_colour

	; selection_number = what's flashing
	ldr r4, selection_number
	mov r4, r4, lsl #1
	cmp r8, r4
	moveq r10, #Dj_Menu_Selection_Colour

	; set colour word.
	orr r10, r10, r10, lsl #4
	orr r10, r10, r10, lsl #8
	orr r10, r10, r10, lsl #16

	; Plot song sprite.
	adr r7, dj_menu_sprite_strides
	ldr r7, [r7, r8, lsl #2]		; sprite stride.
	adr r9, dj_menu_sprite_buffer_ptrs
	ldr r9, [r9, r8, lsl #2]		; sprite ptr.

	add r11, r12, #Dj_Menu_Song_Column*4
	sub r11, r11, r7				; right align.
	bl plot_dj_menu_sprite

	; Plot artist sprite.
	add r8, r8, #1
	adr r7, dj_menu_sprite_strides
	ldr r7, [r7, r8, lsl #2]		; sprite stride.
	adr r9, dj_menu_sprite_buffer_ptrs
	ldr r9, [r9, r8, lsl #2]		; sprite ptr.

	add r11, r12, #Dj_Menu_Artist_Column*4
	bl plot_dj_menu_sprite

	; Next menu row.
	add r12, r12, #Screen_Stride*Dj_Menu_Row_Height
	add r8, r8, #1
	cmp r8, #Dj_Max_Songs*2
	blt .1

	; Plot autoplay string.
	mov r10, #Dj_Menu_Item_Colour
	ldr r4, selection_number
	mov r4, r4, lsl #1
	cmp r8, r4
	moveq r10, #Dj_Menu_Selection_Colour

	; set colour word.
	orr r10, r10, r10, lsl #4
	orr r10, r10, r10, lsl #8
	orr r10, r10, r10, lsl #16

	; Choose correct string.
	ldr r0, autoplay_flag
	add r8, r8, r0

	adr r7, dj_menu_sprite_strides
	ldr r7, [r7, r8, lsl #2]		; sprite stride.
	adr r9, dj_menu_sprite_buffer_ptrs
	ldr r9, [r9, r8, lsl #2]		; sprite ptr.

	add r12, r12, #Screen_Stride*Dj_Menu_Row_Height
	add r11, r12, #Dj_Menu_Autoplay_Column*4
	bl plot_dj_menu_sprite
	
	ldr pc, [sp], #4	

; ============================================================================

; Pre-render all strings as 'sprites' for fast plotting.
dj_menu_init:
	str lr, [sp, #-4]!

	; R12=available RAM for generated code.
	bl gen_sprite_code

	ldr r11, dj_menu_sprite_buffer_p
	adr r1, dj_menu_strings

	mov r5, #0
.1:
	; End of string list.
	ldrb r0, [r1]
	cmp r0, #-1
	beq .2

	; Store ptr to sprite buffer.
	adr r3, dj_menu_sprite_buffer_ptrs
	str r11, [r3, r5, lsl #2]

	; Right or left adjusted?
	cmp r5, #Dj_Max_Songs*2
	movge r10, #0
	andlt r10, r5, #1
	eorlt r10, r10, #1			; for now.

	; Plot string into a sprite buffer at R11.
	bl dj_font_plot_string_as_sprite

	; Store buffer stride.
	adr r3, dj_menu_sprite_strides
	str r12, [r3, r5, lsl #2]

	; Next string.
	add r5, r5, #1
	cmp r5, #Dj_Menu_MaxSprites
	blt .1

.2:
	; TODO: Assert num strings, buffer overflow etc.

	ldr pc, [sp], #4	

; ============================================================================

dj_menu_sprite_buffer_p:
	.long dj_menu_sprite_buffer_no_adr

dj_menu_sprite_buffer_ptrs:
	.skip Dj_Menu_MaxSprites * 4

dj_menu_sprite_strides:				; in bytes
	.skip Dj_Menu_MaxSprites * 4

; ============================================================================

.p2align 2
dj_menu_strings:
	.byte "digitags", 0, "soda7", 0
	.byte "birdhouse in da houz3", 0, "slime", 0
	.byte "funky delicious", 0, "maz3", 0
	.byte "autumn mood", 0, "triace", 0
	.byte "je suis k", 0, "okeanos", 0
	.byte "square circles", 0, "ne7", 0
	.byte "cool beans", 0, "tobach", 0
	.byte "la soupe aux choux", 0, "okeanos", 0
	.byte "sajt", 0, "dalezy", 0
	.byte "bodoaxian", 0, "slash", 0
	.byte "holodash", 0, "virgill", 0
	.byte "squid ring", 0, "curt cool", 0
	.byte "lies", 0, "punnik", 0
	.byte "vectrax longplay", 0, "lord", 0
	.byte "changing waves", 0, "4mat", 0
	.byte "autoplay off", 0
	.byte "autoplay on", 0
; End of string list.
	.byte -1

.p2align 2

; ============================================================================

; R9=sprite buffer ptr.
; R10=colour word.
; R11=screen addr.
; Stride is known and baked into code.
; Preserve:
;  R8=menu entry + selection + playing (!)
;  R12=start of scanline ptr.

sprite_mask_gen_4:
	ldmia r9!, {r0-r3}		; load 4 words.
	ldmia r11, {r4-r7}
	bic r4, r4, r0
	bic r5, r5, r1
	bic r6, r6, r2
	bic r7, r7, r3
	and r0, r0, r10
	and r1, r1, r10
	and r2, r2, r10
	and r3, r3, r10
	orr r4, r4, r0
	orr r5, r5, r1
	orr r6, r6, r2
	orr r7, r7, r3
	stmia r11!, {r4-r7}
sprite_mask_gen_4_end:

sprite_mask_gen_3:
	ldmia r9!, {r0-r2}		; load 3 words.
	ldmia r11, {r4-r6}
	bic r4, r4, r0
	bic r5, r5, r1
	bic r6, r6, r2
	and r0, r0, r10
	and r1, r1, r10
	and r2, r2, r10
	orr r4, r4, r0
	orr r5, r5, r1
	orr r6, r6, r2
	stmia r11!, {r4-r6}
sprite_mask_gen_3_end:

sprite_mask_gen_2:
	ldmia r9!, {r0-r1}		; load 2 words.
	ldmia r11, {r4-r5}
	bic r4, r4, r0
	bic r5, r5, r1
	and r0, r0, r10
	and r1, r1, r10
	orr r4, r4, r0
	orr r5, r5, r1
	stmia r11!, {r4-r5}
sprite_mask_gen_2_end:

sprite_mask_gen_1:
	ldr r0, [r9], #4		; load 1 word.
	ldr r4, [r11]
	bic r4, r4, r0
	and r0, r0, r10
	orr r4, r4, r0
	str r4, [r11], #4
sprite_mask_gen_1_end:

sprite_end_of_row:
	add r11, r11, #Screen_Stride	; next line.
	sub r11, r11, #0				; sprite stride (will be baked)
sprite_end_of_row_end:

sprite_end_of_sprite:
	; TODO: Update r11?
	mov pc, lr
sprite_end_of_sprite_end:

; ============================================================================
; Generate code for plotting masked sprites using up to 4 word loads at a time.
; ============================================================================

dj_menu_sprite_code_p:
	.long dj_menu_sprite_code_pointers_no_adr

; R12=start of code.
gen_sprite_code:
	STR lr, [sp, #-4]!

	LDR r11, dj_menu_sprite_code_p

	mov r1, #1			; length in words.
.1:
	ADD r12, r12, #0xc ;Align to 16 byte boundary
	BIC r12, r12, #0xc
	STR r12, [r11], #4

	mov r6, #Dj_Font_GlyphHeight
.10:

	mov r5, r1			; remaining words.
.2:
	cmp r5, #4
	blt .3

	sub r5, r5, #4
	adr r2, sprite_mask_gen_4
	adr r3, sprite_mask_gen_4_end
	bl copy_code
	b .2

.3:
	cmp r5, #3
	blt .4

	sub r5, r5, #3
	adr r2, sprite_mask_gen_3
	adr r3, sprite_mask_gen_3_end
	bl copy_code
	b .2

.4:
	cmp r5, #2
	blt .5

	sub r5, r5, #2
	adr r2, sprite_mask_gen_2
	adr r3, sprite_mask_gen_2_end
	bl copy_code
	b .2

.5:
	cmp r5, #0
	beq .6

	sub r5, r5, #1
	adr r2, sprite_mask_gen_1
	adr r3, sprite_mask_gen_1_end
	bl copy_code

.6:
	; End of line.
	adr r2, sprite_end_of_row
	adr r3, sprite_end_of_row_end
	bl copy_code

	mov r0, r1, lsl #2		; stride in bytes
	strb r0, [r12, #-4]		; poke into lsb of prev word.

	subs r6, r6, #1
	bne .10

	; End of sprite.
	adr r2, sprite_end_of_sprite
	adr r3, sprite_end_of_sprite_end
	bl copy_code

	add r1, r1, #1
	cmp r1, #Dj_Menu_MaxSpriteStride
	ble .1

	ldr pc, [sp], #4

; R2=src
; R3=end
; R12=dst
copy_code:
	ldr r0, [r2], #4
	str r0, [r12], #4
	cmp r2, r3
	blt copy_code
	mov pc, lr

; ============================================================================
