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

.equ _DEBUG, 1
.equ _DEBUG_RASTERS, (_DEBUG && 1)
.equ _DEBUG_SHOW, (_DEBUG && 1)
.equ _CHECK_FRAME_DROP, (!_DEBUG && 1)

.equ _DEBUG_DEFAULT_PLAY_PAUSE, 1		; play
.equ _DEBUG_DEFAULT_SHOW_RASTERS, 1
.equ _DEBUG_DEFAULT_SHOW_INFO, 0		; slow so off by default.

.equ Sample_Speed_SlowCPU, 48		    ; ideally get this down for ARM2
.equ Sample_Speed_FastCPU, 16		    ; ideally 16us for ARM250+

.equ _WIDESCREEN, 0

.equ Screen_Banks, 2

.equ Screen_Mode, 9
.equ Screen_Width, 320
.if _WIDESCREEN
.equ Vdu_Mode, 97					; MODE 9 widescreen (320x180)
									; or 96 for MODE 13 widescreen (320x180)
.equ Screen_Height, 180
.equ Mode_Height, 180
.else
.equ Vdu_Mode, 9
.equ Screen_Height, 256
.equ Mode_Height, 256
.endif
.equ Screen_PixelsPerByte, 2
.equ Screen_Stride, Screen_Width/Screen_PixelsPerByte
.equ Screen_Bytes, Screen_Stride*Screen_Height
.equ Mode_Bytes, Screen_Stride*Mode_Height

.include "lib/swis.h.asm"
.include "lib/lib_config.h.asm"
.include "lib/maths.h.asm"
.include "lib/debug.h.asm"

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
	ldrb r0, debug_show_rasters
	cmp r0, #0
	blne palette_set_border
	.endif
.endm

; ============================================================================
; App defines
; ============================================================================

.equ VU_Bars_Effect, 1					; 'fake' bars
.equ VU_Bars_Gravity, 1					; lines per vsync

.equ AutoPlay_Default, 1
.equ Stereo_Positions, 1		; Amiga (full) stereo positions.

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

    ; Register debug vars.
    DEBUG_REGISTER_VAR vsync_count
    DEBUG_REGISTER_VAR vsync_delta
    DEBUG_REGISTER_KEY RMKey_Space,      debug_toggle_main_loop_pause,  0
    DEBUG_REGISTER_KEY RMKey_A,          debug_restart_sequence,        0
    DEBUG_REGISTER_KEY RMKey_S,          debug_set_byte_true,           debug_main_loop_step
    DEBUG_REGISTER_KEY RMKey_D,          debug_toggle_byte,             debug_show_info
    DEBUG_REGISTER_KEY RMKey_R,          debug_toggle_byte,             debug_show_rasters
    DEBUG_REGISTER_KEY RMKey_ArrowRight, debug_skip_to_next_pattern,    0
    DEBUG_REGISTER_KEY RMKey_C,          debug_toggle_palette,          0
    DEBUG_REGISTER_KEY RMKey_0,          debug_set_eye_distance,        0
    DEBUG_REGISTER_KEY RMKey_1,          debug_set_eye_distance,        1
    DEBUG_REGISTER_KEY RMKey_2,          debug_set_eye_distance,        2
    DEBUG_REGISTER_KEY RMKey_3,          debug_set_eye_distance,        3
    DEBUG_REGISTER_KEY RMKey_4,          debug_set_eye_distance,        4
    DEBUG_REGISTER_KEY RMKey_5,          debug_set_eye_distance,        5
    DEBUG_REGISTER_KEY RMKey_6,          debug_set_eye_distance,        6
    DEBUG_REGISTER_KEY RMKey_7,          debug_set_eye_distance,        7
    DEBUG_REGISTER_KEY RMKey_8,          debug_set_eye_distance,        8
    DEBUG_REGISTER_KEY RMKey_9,          debug_set_eye_distance,        9

	; Install our own IRQ handler - thanks Steve! :)
	bl install_irq_handler

	; EARLY INIT / LOAD STUFF HERE! 
	bl lib_init
	; R12=top of RAM used.

	; Bootstrap the main sequence.
	adr r0, seq_main_program
	bl script_add_program

    ; Tick script once for module init.
    bl script_tick_all

.if 0
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
.else
    mov r0, #Sample_Speed_SlowCPU
    swi QTM_SetSampleSpeed
.endif

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
	ldr r2, palette_p
	bl palette_set_block

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
	; PREPARE
	; ========================================================================

    .if _DEBUG
    bl debug_do_key_callbacks
    .endif

	.if _DEBUG
	ldrb r0, debug_main_loop_pause
	cmp r0, #0
	bne .3

	ldrb r0, debug_main_loop_step
	cmp r0, #0
	beq main_loop_skip_tick
	.3:
	.endif

	; ========================================================================
	; TICK
	; ========================================================================

	bl script_tick_all
	bl fx_tick_layers

    ; TODO: Update frame counter.

main_loop_skip_tick:

    .if _DEBUG
    mov r0, #0
    strb r0, debug_main_loop_step
    .endif

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
	.if _DEBUG
    ldr r12, screen_addr
    bl debug_plot_vars
	.endif

	; Swap screens!
	bl mark_write_bank_as_pending_display

	; repeat!
	swi OS_ReadEscapeState
	bcc main_loop                   ; exit if Escape is pressed

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
debug_toggle_main_loop_pause:
	ldrb r0, debug_main_loop_pause
	eor r0, r0, #1
	strb r0, debug_main_loop_pause

    ; Toggle music.
    cmp r0, #0
    swieq QTM_Pause			    ; pause
    swine QTM_Start             ; play

    ; TODO: Stop/start script.
    mov pc, lr

debug_restart_sequence:
    ; Start music again.
    mov r1, #0
	swi QTM_Pos

    ; TODO: Start script again.
    ; TODO: Reset frame counter.
    mov pc, lr

debug_skip_to_next_pattern:
    mov r0, #-1
    mov r1, #-1
    swi QTM_Pos         ; read position.

    add r0, r0, #1
    ; TODO: Check max pattern?
    mov r1, #0
    swi QTM_Pos         ; set position.

    ; TODO: Update frame counter to match.
    mov pc, lr

debug_toggle_palette:
    stmfd sp!, {r3-r5, lr}
    ; Toggle palette.
    ldr r2, palette_p
    adr r3, palette_red_cyan
    cmp r2, r3
    adreq r2, palette_red_blue
    movne r2, r3
    str r2, palette_p
    bl palette_set_block
    ldmfd sp!, {r3-r5, pc}

debug_set_eye_distance:
    mov r0, r1
    b set_eye_distance
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

; R0=event number
event_handler:
	cmp r0, #Event_KeyPressed
	movne pc, lr

	; R1=0 key up or 1 key down
	; R2=internal key number (RMKey_*)

    .if _DEBUG
    b debug_handle_keypress
    .else
    mov pc, lr
    .endif


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

palette_p:
    .long palette_red_cyan

screen_addr:
	.long 0					; ptr to the current VIDC screen bank being written to.

.if _DEBUG
debug_main_loop_pause:
	.byte _DEBUG_DEFAULT_PLAY_PAUSE

debug_main_loop_step:
	.byte 0

debug_show_info:
	.byte _DEBUG_DEFAULT_SHOW_INFO

debug_show_rasters:
	.byte _DEBUG_DEFAULT_SHOW_RASTERS

.p2align 2
.endif

.include "lib/debug.asm"

.include "src/fx.asm"
.include "src/script.asm"
.include "src/3d-scene.asm"
.include "src/width.asm"

.include "lib/palette.asm"
.include "lib/mode9-screen.asm"
.include "lib/line.asm"
.include "lib/lib_code.asm"

.include "src/scale_plot_generated.asm"

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

; For anaglpyh want CRcr
palette_red_cyan:
    .long 0x00000000                    ; 00 = 0000 = black
    .long 0x00000077                    ; 01 = 0001 = red 1
    .long 0x00777700                    ; 02 = 0010 = cyan 1
    .long 0x00777777                    ; 03 = 0011 = white 1
    .long 0x00000099                    ; 04 = 0100 = red 2
    .long 0x000000bb                    ; 05 = 0101 = red 3
    .long 0x000000dd                    ; 06 = 0110 = red 4
    .long 0x000000ff                    ; 07 = 0111 = red 5
    .long 0x00999900                    ; 08 = 1000 = cyan 2
    .long 0x00bbbb00                    ; 09 = 1001 = cyan 3
    .long 0x00dddd00                    ; 10 = 1010 = cyan 4
    .long 0x00ffff00                    ; 11 = 1011 = cyan 5
    .long 0x00999999                    ; 12 = 1100 = white 2
    .long 0x00bbbbbb                    ; 13 = 1101 = white 3
    .long 0x00dddddd                    ; 14 = 1110 = white 4
    .long 0x00ffffff                    ; 15 = 1111 = white 5

palette_red_blue:
    .long 0x00000000                    ; 00 = 0000 = black
    .long 0x00000077                    ; 01 = 0001 = red 1
    .long 0x00770000                    ; 02 = 0010 = blue 1
    .long 0x00770077                    ; 03 = 0011 = magenta 1
    .long 0x00000099                    ; 04 = 0100 = red 2
    .long 0x000000bb                    ; 05 = 0101 = red 3
    .long 0x000000dd                    ; 06 = 0110 = red 4
    .long 0x000000ff                    ; 07 = 0111 = red 5
    .long 0x00990000                    ; 08 = 1000 = blue 2
    .long 0x00bb0000                    ; 09 = 1001 = blue 3
    .long 0x00dd0000                    ; 10 = 1010 = blue 4
    .long 0x00ff0000                    ; 11 = 1011 = blue 5
    .long 0x00990099                    ; 12 = 1100 = magenta 2
    .long 0x00bb00bb                    ; 13 = 1101 = magenta 3
    .long 0x00dd00dd                    ; 14 = 1110 = magenta 4
    .long 0x00ff00ff                    ; 15 = 1111 = magenta 5

; ============================================================================
; DATA Segment
; ============================================================================

.include "src/data.asm"

; ============================================================================
; BSS Segment
; ============================================================================

.include "src/bss.asm"
