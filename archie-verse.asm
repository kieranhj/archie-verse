; ============================================================================
; Archie-Verse: a Acorn Archimedes demo/trackmo framework.
;	1. <Group> presents <demo> at <party>
;	2. 2D effect 1
;	3. 3D effect 1
;	4. Greets
;	5. 2D effect 2
;	6. 3D effect 2
;	7. Credits
;	8. Ending
; ============================================================================

.equ _DEBUG, 0
.equ _DEBUG_RASTERS, (_DEBUG && 1)
.equ _DEBUG_SHOW, (_DEBUG && 1)
.equ _CHECK_FRAME_DROP, (!_DEBUG && 1)

.equ Sample_Speed_SlowCPU, 48		; ideally get this down for ARM2
.equ Sample_Speed_FastCPU, 16		; ideally 16us for ARM250+

.equ Screen_Banks, 3
.equ Vdu_Mode, 97					; MODE 9 widescreen (320x180)
									; or 96 for MODE 13 widescreen (320x180)
.equ Screen_Mode, 9
.equ Screen_Width, 320
.equ Screen_Height, 180
.equ Mode_Height, 180
.equ Screen_PixelsPerByte, 2
.equ Screen_Stride, Screen_Width/Screen_PixelsPerByte
.equ Screen_Bytes, Screen_Stride*Screen_Height
.equ Mode_Bytes, Screen_Stride*Mode_Height

.include "lib/swis.h.asm"
.include "lib/lib_config.h.asm"

; ============================================================================
; Macros.
; ============================================================================

.macro RND seed, bit, temp
    TST    \bit, \bit, LSR #1                       ; top bit into Carry
    MOVS   \temp, \seed, RRX                        ; 33 bit rotate right
    ADC    \bit, \bit, \bit                         ; carry into lsb of R1
    EOR    \temp, \temp, \seed, LSL #12             ; (involved!)
    EOR    \seed, \temp, \temp, LSR #20             ; (similarly involved!)
.endm

.macro SET_BORDER rgb
	.if _DEBUG_RASTERS
	mov r4, #\rgb
	bl palette_set_border
	.endif
.endm

; ============================================================================
; App defines
; ============================================================================

.equ VU_Bars_Effect, 1					; 'fake' bars
.equ VU_Bars_Gravity, 1					; lines per vsync

.equ AutoPlay_Default, 1
.equ Stereo_Positions, 1		; Amiga (full) stereo positions.

.equ KeyBit_Space, 0
.equ KeyBit_Return, 1
.equ KeyBit_ArrowUp, 2
.equ KeyBit_ArrowDown, 3
.equ KeyBit_A, 4
.equ KeyBit_LeftClick, 5
.equ KeyBit_1, 6
.equ KeyBit_2, 7
.equ KeyBit_3, 8
.equ KeyBit_4, 9
.equ KeyBit_5, 10
.equ KeyBit_E, 11
.equ KeyBit_F, 12
.equ KeyBit_R, 13
.equ KeyBit_S, 14
.equ KeyBit_RightClick, 16

; TODO: Remove Timer1 split if not necessary.
.equ RasterSplitLine, 56+90			; 56 lines from vsync to screen start

; ============================================================================
; Code Start
; ============================================================================

.org 0x8000

Start:
    ldr sp, stack_p
	B main

stack_p:
	.long stack_base_no_adr

; ============================================================================
; Main
; ============================================================================

main:
	; Set screen MODE & disable cursor
	adr r0, vdu_screen_disable_cursor
	mov r1, #12
	swi OS_WriteN

	; Set screen size for number of buffers
	MOV r0, #DynArea_Screen
	SWI OS_ReadDynamicArea
	MOV r0, #DynArea_Screen
	MOV r2, #Mode_Bytes * Screen_Banks
	SUBS r1, r2, r1
	SWI OS_ChangeDynamicArea
	MOV r0, #DynArea_Screen
	SWI OS_ReadDynamicArea
	CMP r1, r2
	ADRCC r0, error_noscreenmem
	SWICC OS_GenerateError

	; Clear all screen buffers
	mov r1, #1
.1:
	str r1, write_bank

	; CLS bank N
	mov r0, #OSByte_WriteVDUBank
	swi OS_Byte
	SWI OS_WriteI + 12		; cls

	add r1, r1, #1
	cmp r1, #Screen_Banks
	ble .1

	; Seed RND.
	swi OS_ReadMonotonicTime
	str r0, rnd_seed

	; Install our own IRQ handler - thanks Steve! :)
	bl install_irq_handler

	; EARLY INIT / LOAD STUFF HERE!
	bl lib_init
	; R12=top of RAM used.

    ; TODO: Init these at runtime not boottime.
	bl init_3d_scene
	bl scroller_init
	bl logo_init
	bl check_rows_init

	; Count how long the init takes as a very rough estimate of CPU speed.
	ldr r1, vsync_count
	cmp r1, #80		; ARM3~=20, ARM250~=70, ARM2~=108
	movge r0, #Sample_Speed_SlowCPU
	movlt r0, #Sample_Speed_FastCPU

	; Setup QTM for our needs.
	swi QTM_SetSampleSpeed

	mov r0, #VU_Bars_Effect
	mov r1, #VU_Bars_Gravity
	swi QTM_VUBarControl

	mov r0, #0
	mov r1, #Stereo_Positions
	swi QTM_Stereo

	; Load the music.
	mov r0, #-1					; load from address and copy to RMA.
	adr r1, music_table
	ldr r1, [r1, #0]
	swi QTM_Load

	; LATE INITALISATION HERE!
	bl get_next_bank_for_writing

	; Set palette (shows screen).
	adrl r2, logo_pal_block
	bl palette_set_block

	; Bootstrap the main sequence.
	adr r0, seq_main_program
	bl script_add_program

	; Claim the Event vector.
	MOV r0, #EventV
	ADR r1, event_handler
	MOV r2, #0
	SWI OS_Claim

	; Claim the Error vector.
	MOV r0, #ErrorV
	ADR r1, error_handler
	MOV r2, #0
	SWI OS_Claim

	; Play music!
	swi QTM_Start

	; Enable key pressed event.
	mov r0, #OSByte_EventEnable
	mov r1, #Event_KeyPressed
	SWI OS_Byte

main_loop:

	; ========================================================================
	; TICK
	; ========================================================================

	bl script_tick_all
	bl fx_tick_layers

	; ========================================================================
	; VSYNC
	; ========================================================================

	; This will block if there isn't a bank available to write to.
	bl get_next_bank_for_writing

	; Useful to determine frame rate for debug.
	.if _DEBUG || _CHECK_FRAME_DROP
	ldr r1, last_vsync
	ldr r2, vsync_count
	sub r0, r2, r1
	str r2, last_vsync
	str r0, vsync_delta
	.endif

	; R0 = vsync delta since last frame.
	.if _CHECK_FRAME_DROP
	; This flashes if vsync IRQ has no pending buffer to display.
	ldr r2, last_dropped_frame
	ldr r1, last_last_dropped_frame
	cmp r2, r1
	moveq r4, #0x000000
	movne r4, #0x0000ff
	strne r2, last_last_dropped_frame
	bl palette_set_border
	.endif

	; ========================================================================
	; DRAW
	; ========================================================================

	bl fx_draw_layers

	; show debug
	.if _DEBUG_SHOW
	bl debug_write_vsync_count
	.endif

	; Swap screens!
	bl mark_write_bank_as_pending_display

	; exit if Escape is pressed
	swi OS_ReadEscapeState
	bcs exit

	; repeat!
	b main_loop

exit:
	; Disable music
	mov r0, #0
	swi QTM_Clear

	; Remove our IRQ handler
	bl uninstall_irq_handler

	; Disable key press event
	mov r0, #OSByte_EventDisable
	mov r1, #Event_KeyPressed
	swi OS_Byte

	; Release our event handler
	mov r0, #EventV
	adr r1, event_handler
	mov r2, #0
	swi OS_Release

	; Release our error handler
	mov r0, #ErrorV
	adr r1, error_handler
	mov r2, #0
	swi OS_Release

	; Display whichever bank we've just written to
	mov r0, #OSByte_WriteDisplayBank
	ldr r1, write_bank
	swi OS_Byte
	; and write to it
	mov r0, #OSByte_WriteVDUBank
	ldr r1, write_bank
	swi OS_Byte

	; Flush keyboard buffer.
	mov r0, #15
	mov r1, #1
	swi OS_Byte

	SWI OS_Exit

; ============================================================================
; Debug helpers.
; ============================================================================

.if _DEBUG
debug_print_r0:
	stmfd sp!, {r0-r2}
	adr r1, debug_string
	mov r2, #10
	swi OS_ConvertHex4	; or OS_ConvertHex8
	adr r0, debug_string
	swi OS_WriteO
	ldmfd sp!, {r0-r2}
	mov pc, lr

debug_write_vsync_count:
	str lr, [sp, #-4]!
	mov r0, #30	; home cursor
	swi OS_WriteC
	mov r0, #17	; set text colour
	swi OS_WriteC
	mov r0, #15
	swi OS_WriteC

    ; display current tracker position
	.if 0
    mov r0, #-1
    mov r1, #-1
    swi QTM_Pos

	mov r3, r1
	adr r1, debug_string
	mov r2, #8
	swi OS_ConvertHex2
	adr r0, debug_string
	swi OS_WriteO

	mov r0, r3
	adr r1, debug_string
	mov r2, #8
	swi OS_ConvertHex2
	adr r0, debug_string
	swi OS_WriteO

	swi OS_WriteI+32
	ldr r0, keyboard_pressed_mask
	adr r1, debug_string
	mov r2, #8
	swi OS_ConvertHex4
	adr r0, debug_string
	swi OS_WriteO
.endif

.if 1
	; display frame count / frame rate etc.
	ldr r0, vsync_count
	adr r1, debug_string
	mov r2, #8
	swi OS_ConvertHex4
	adr r0, debug_string
	swi OS_WriteO

	swi OS_WriteI+32
	ldr r0, vsync_delta
	adr r1, debug_string
	mov r2, #8
	swi OS_ConvertHex4
	adr r0, debug_string
	swi OS_WriteO
.endif
	ldr pc, [sp], #4

debug_string:
	.skip 16
.endif

; ============================================================================
; System stuff.
; ============================================================================

error_noscreenmem:
	.long 0
	.byte "Cannot allocate screen memory!"
	.p2align 2
	.long 0

get_screen_addr:
	str lr, [sp, #-4]!
	adrl r0, screen_addr_input
	adrl r1, screen_addr
	swi OS_ReadVduVariables
	ldr pc, [sp], #4
	
screen_addr_input:
	.long VD_ScreenStart, -1

displayed_bank:
	.long 0				; VIDC sreen bank being displayed

write_bank:
	.long 0				; VIDC screen bank being written to

pending_bank:
	.long 0				; VIDC screen to be displayed next

vsync_count:
	.long 0				; current vsync count from start of exe.

.if _DEBUG || _CHECK_FRAME_DROP
last_vsync:
	.long 0

vsync_delta:
	.long 0
.endif

.if _CHECK_FRAME_DROP
last_dropped_frame:
	.long 0

last_last_dropped_frame:
	.long 0
.endif

keyboard_pressed_mask:
	.long 0

; R0=event number
event_handler:
	cmp r0, #Event_KeyPressed
	movne pc, lr

	; R1=0 key up or 1 key down
	; R2=internal key number (RMKey_*)

	str r0, [sp, #-4]!

	ldr r0, keyboard_pressed_mask
	cmp r1, #0
	beq .2

	; Key down
	cmp r2, #RMKey_Space
	orreq r0, r0, #1<<KeyBit_Space
	cmp r2, #RMKey_Return
	orreq r0, r0, #1<<KeyBit_Return
	cmp r2, #RMKey_ArrowUp
	orreq r0, r0, #1<<KeyBit_ArrowUp
	cmp r2, #RMKey_ArrowDown
	orreq r0, r0, #1<<KeyBit_ArrowDown
	cmp r2, #RMKey_A
	orreq r0, r0, #1<<KeyBit_A
	cmp r2, #RMKey_LeftClick
	orreq r0, r0, #1<<KeyBit_LeftClick
	cmp r2, #RMKey_1
	orreq r0, r0, #1<<KeyBit_1
	cmp r2, #RMKey_2
	orreq r0, r0, #1<<KeyBit_2
	cmp r2, #RMKey_3
	orreq r0, r0, #1<<KeyBit_3
	cmp r2, #RMKey_4
	orreq r0, r0, #1<<KeyBit_4
	cmp r2, #RMKey_5
	orreq r0, r0, #1<<KeyBit_5
	cmp r2, #RMKey_E
	orreq r0, r0, #1<<KeyBit_E
	cmp r2, #RMKey_F
	orreq r0, r0, #1<<KeyBit_F
	cmp r2, #RMKey_R
	orreq r0, r0, #1<<KeyBit_R
	cmp r2, #RMKey_S
	orreq r0, r0, #1<<KeyBit_S
	cmp r2, #RMKey_RightClick
	orreq r0, r0, #1<<KeyBit_RightClick
	b .3

.2:
	; Key up
	cmp r2, #RMKey_Space
	biceq r0, r0, #1<<KeyBit_Space
	cmp r2, #RMKey_Return
	biceq r0, r0, #1<<KeyBit_Return
	cmp r2, #RMKey_ArrowUp
	biceq r0, r0, #1<<KeyBit_ArrowUp
	cmp r2, #RMKey_ArrowDown
	biceq r0, r0, #1<<KeyBit_ArrowDown
	cmp r2, #RMKey_A
	biceq r0, r0, #1<<KeyBit_A
	cmp r2, #RMKey_LeftClick
	biceq r0, r0, #1<<KeyBit_LeftClick
	cmp r2, #RMKey_1
	biceq r0, r0, #1<<KeyBit_1
	cmp r2, #RMKey_2
	biceq r0, r0, #1<<KeyBit_2
	cmp r2, #RMKey_3
	biceq r0, r0, #1<<KeyBit_3
	cmp r2, #RMKey_4
	biceq r0, r0, #1<<KeyBit_4
	cmp r2, #RMKey_5
	biceq r0, r0, #1<<KeyBit_5
	cmp r2, #RMKey_E
	biceq r0, r0, #1<<KeyBit_E
	cmp r2, #RMKey_F
	biceq r0, r0, #1<<KeyBit_F
	cmp r2, #RMKey_R
	biceq r0, r0, #1<<KeyBit_R
	cmp r2, #RMKey_S
	biceq r0, r0, #1<<KeyBit_S
	cmp r2, #RMKey_RightClick
	biceq r0, r0, #1<<KeyBit_RightClick

.3:
	str r0, keyboard_pressed_mask
	ldr r0, [sp], #4
	mov pc, lr


mark_write_bank_as_pending_display:
	; Mark write bank as pending display.
	ldr r1, write_bank

	; What happens if there is already a pending bank?
	; At the moment we block but could also overwrite
	; the pending buffer with the newer one to catch up.
	; TODO: A proper fifo queue for display buffers.
	.1:
	ldr r0, pending_bank
	cmp r0, #0
	bne .1
	str r1, pending_bank

	; Show panding bank at next vsync.
	MOV r0, #OSByte_WriteDisplayBank
	swi OS_Byte
	mov pc, lr

get_next_bank_for_writing:
	; Increment to next bank for writing
	ldr r1, write_bank
	add r1, r1, #1
	cmp r1, #Screen_Banks
	movgt r1, #1

	; Block here if trying to write to displayed bank.
	.1:
	ldr r0, displayed_bank
	cmp r1, r0
	beq .1

	str r1, write_bank

	; Now set the screen bank to write to
	mov r0, #OSByte_WriteVDUBank
	swi OS_Byte

	; Back buffer address for writing bank stored at screen_addr
	b get_screen_addr

error_handler:
	STMDB sp!, {r0-r2, lr}

	bl uninstall_irq_handler

	; Release event handler.
	MOV r0, #OSByte_EventDisable
	MOV r1, #Event_KeyPressed
	SWI OS_Byte

	MOV r0, #EventV
	ADR r1, event_handler
	mov r2, #0
	SWI OS_Release

	; Release error handler.
	MOV r0, #ErrorV
	ADR r1, error_handler
	MOV r2, #0
	SWI OS_Release

	; Write & display current screen bank.
	MOV r0, #OSByte_WriteDisplayBank
	LDR r1, write_bank
	SWI OS_Byte

	; Do these help?
	swi QTM_Stop

	LDMIA sp!, {r0-r2, lr}
	MOVS pc, lr

; ============================================================================
; Interrupt handling.
; ============================================================================

oldirqhandler:
	.long 0

oldirqjumper:
	.long 0

vsyncstartdelay:
	.long 127*RasterSplitLine  ;2000000/50.08

install_irq_handler:
	mov r1, #0x18					; IRQ vector.
	
	; Remember previous IRQ branch call.
	ldr r0, [r1]					; old IRQ handler.
	str r0, oldirqjumper

	; Calculate old IRQ hanlder address from branch opcode.
	bic r0, r0, #0xff000000
	mov r0, r0, lsl #2
	add r0, r0, #32
	str r0, oldirqhandler

	; Set Timer 1.
	SWI		OS_EnterOS
	MOV     R12,#0x3200000           ;IOC address

	TEQP    PC,#0b11<<26 | 0b11  ;jam all interrupts!

	LDR     R0,vsyncstartdelay
	STRB    R0,[R12,#0x50]
	MOV     R0,R0,LSR#8
	STRB    R0,[R12,#0x54]           ;prepare timer 1 for waiting until screen start
									;don't start timer1, done on next Vs...
	TEQP    PC,#0
	MOV     R0,R0

	; Install our IRQ handler.
	swi OS_IntOff
	adr r0, irq_handler
	sub r0, r0, #32
	mov r0, r0, lsr #2
	add r0, r0, #0xea000000			; B irq_handler.
	str r0, [r1]
	swi OS_IntOn

	mov pc, lr

uninstall_irq_handler:
	mov r1, #0x18					; IRQ vector.
	
	; Restore previous IRQ branch call.
	ldr r0, oldirqjumper
	str r0, [r1]

	mov pc, lr

irq_handler:
	STMFD   R13!,{R0-R1,R11-R12}
	MOV     R12,#0x3200000           ;IOC address
	LDRB    R0,[R12,#0x14+0]
	TST     R0,#1<<6 | (1<<3)
	BEQ     nottimer1orVs           ;not T1 or Vs, back to RISCOS

	TEQP    PC,#0b11<<26 | 0b11
	MOV     R0,R0

	MOV     R11,#VIDC_Write
	TST     R0,#1<<3
	BNE     vsync                   ;...Vs higher priority than T1

timer1:
	mov r0, #0
	str r0, vsync_bodge

	; WRITE VIDC REGS HERE!

	LDRB    R0,[R12,#0x18]
	BIC     R0,R0,#1<<6
	STRB    R0,[R12,#0x18]           ;stop T1 irq...

exittimer1:
	TEQP    PC,#0b10<<26 | 0b10
	MOV     R0,R0
	LDMFD   R13!,{R0-R1,R11-R12}
	SUBS    PC,R14,#4

vsync:
	ldr r0, vsync_bodge
	cmp r0, #0
	beq .3
	b exitVs
.3:
	mov r0, #1
	str r0, vsync_bodge

	; WRITE VIDC REGS HERE!

	STRB    R0,[R12,#0x58]           ;T1 GO (latch already set up)
	LDRB    R0,[R12,#0x18]
	ORR     R0,R0,#1<<6
	STRB    R0,[R12,#0x18]           ;enable T1 irq...
	MOV     R0,#1<<6
	STRB    R0,[R12,#0x14]           ;clear any pending T1 irq

	; Update the vsync counter
	LDR r0, vsync_count
	ADD r0, r0, #1
	STR r0, vsync_count

	; Pending bank will now be displayed.
	ldr r1, pending_bank
	cmp r1, #0
	.if _CHECK_FRAME_DROP
	streq r0, last_dropped_frame
	.endif
	beq exitVs

	str r1, displayed_bank

	; Clear pending bank.
	mov r0, #0
	str r0, pending_bank

exitVs:
	TEQP    PC,#0b10<<26 | 0b10
	MOV     R0,R0

nottimer1orVs:
	LDMFD   R13!,{R0-R1,R11-R12}
	ldr pc, oldirqhandler

vsync_bodge:
	.long 0

; ============================================================================
; Additional code modules
; ============================================================================

rnd_seed:
    .long 0x87654321

screen_addr:
	.long 0					; ptr to the current VIDC screen bank being written to.

; TODO: Some ordering of these.
.include "src/fx.asm"
.include "src/script.asm"
.include "lib/palette.asm"
.include "src/scroller.asm"
.include "src/columns.asm"
.include "src/logo.asm"
.include "lib/lz4-decode.asm"
.include "lib/lib_code.asm"
.include "src/3d-scene.asm"
.include "src/checkerboard.asm"

; ============================================================================
; Data Segment
; ============================================================================

; TODO: Hot-reload this one day?
.include "src/sequence.asm"

vdu_screen_disable_cursor:
.byte 22, Vdu_Mode, 23,1,0,0,0,0,0,0,0,0
.p2align 2

music_table:
	.long changing_waves_mod_no_adr		; 14

logo_pal_block:
.incbin "data/logo-palette-hacked.bin"

; ============================================================================

palette_blocks_for_banks_no_adr:
.rept Screen_Banks
	.long 0xffffffff
	.skip 60
.endr

; ============================================================================
; DATA Segment
; ============================================================================

.include "src/data.asm"

; ============================================================================
; BSS Segment
; ============================================================================

.include "src/bss.asm"
