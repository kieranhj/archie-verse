; ============================================================================
; App standard code.
; Hack as necessary per prod.
; Want this file to be hackable.
; ============================================================================

.include "build/dj3_defs.asm"

.equ Mouse_Enable,				1
.equ Glitch_Time,				20 	; frames

.equ PanningPos_Full,			0
.equ PanningPos_Half,			1
.equ PanningPos_Quarter,		2
.equ PanningPos_Centre,			3	; mono
.equ PanningPos_MAX,			4

.equ PanningPos_Default,		PanningPos_Centre

;.equ AppVsync_IrqRasterLine,    56+90			; 56 lines from vsync to screen start

; ============================================================================
; App specific variables and tables.
; ============================================================================

; ============================================================================
; App debug code.
; ============================================================================

.if _DEBUG
; R12=top of RAM (preserve).
app_init_debug:
    str lr, [sp, #-4]!

    DEBUG_REGISTER_VAR_EX vsync_delta, debug_plot_addr_as_dec4
    DEBUG_REGISTER_VAR music_pos
    DEBUG_REGISTER_VAR frame_counter
    DEBUG_REGISTER_VAR_EX debug_free_ram, debug_plot_addr_as_dec4
	DEBUG_REGISTER_VAR keys_rm_code

    DEBUG_REGISTER_KEY          RMKey_Space,      debug_toggle_main_loop_pause,  0

; Don't make sense for music disc.
;    DEBUG_REGISTER_KEY_WITH_VAR RMKey_A,          debug_set_byte_true,           debug_restart_flag
;    DEBUG_REGISTER_KEY_WITH_VAR RMKey_S,          debug_set_byte_true,           debug_main_loop_step
    DEBUG_REGISTER_KEY_WITH_VAR RMKey_D,          debug_toggle_byte,             debug_show_info
    DEBUG_REGISTER_KEY_WITH_VAR RMKey_R,          debug_toggle_byte,             debug_show_rasters

    ldr pc, [sp], #4
.endif

; ============================================================================
; App early initialisation for loading stuff.
; ============================================================================

; R12=top of RAM (preserve).
app_early_init:
    str lr, [sp, #-4]!

    bl dj_font_init
    bl dj_menu_init

	.if _DEBUG
    mov r0, #0
	.else
	mov r0, #Dj_Max_Songs
	.endif
    bl play_song

    ldr pc, [sp], #4

; ============================================================================
; App late initialisation for things that require access to the screen.
; ============================================================================

startlogo_p:
	.long startlogo_no_adr

startlogo_height:
	.long 1219 - 512

startlogo_colour:
	.long 0xff

.p2align 2
app_osword_block:
    .skip 8
    ; logical colour
    ; physical colour (16)
    ; red
    ; green
    ; blue
    ; (pad)

; R3 = index
; R4 = RGBx word (actually 0x00BbGgRr) where bgr are ignored.
; Uses R0,R1 
app_set_colour:
    adrl r1, app_osword_block
    strb r3, [r1, #0]       ; logical colour
    mov r0, #16
    strb r0, [r1, #1]       ; physical colour
    and r0, r4, #0xff
    strb r0, [r1, #2]       ; red
    mov r0, r4, lsr #8
    strb r0, [r1, #3]       ; green
    mov r0, r4, lsr #16
    strb r0, [r1, #4]       ; blue
    mov r0, #12
    swi OS_Word
    mov pc,lr

; R12=screen addr.
app_late_init:
    str lr, [sp, #-4]!

.if !_DEBUG
    swi OS_WriteI+22
    swi OS_WriteI+18
    swi OS_RemoveCursors

	mov r3, #0
	mov r4, #0x00000000
	;bl app_set_colour

	ldr r8, startlogo_height
	mov r14, #2
	mov r9, #0
.2:

    ldr r12, screen_addr
	ldr r11, startlogo_p
	add r11, r11, r9, lsl #6
	add r11, r11, r9, lsl #4

	; Wait for vsync.
	mov r0, #19
	swi OS_Byte

	mov r3, #1
	ldr r2, startlogo_colour
	orr r4, r2, r2, lsl #8
	orr r4, r4, r2, lsl #16
	str r14, [sp, #-4]!
	bl app_set_colour
	ldr r14, [sp], #4

	; Copy logo to screen.
	mov r10, #640*2
.1:
	ldmia r11!, {r0-r7}
	stmia r12!, {r0-r7}
	subs r10, r10, #1
	bne .1

	; Move up/down.
	adds r9, r9, r14
	movmi r9, #0
	movmi r14, #2
	cmp r9, r8
	movgt r9, r8
	movgt r14, #-2

	; Check if fade in progress.
	ldr r4, startlogo_colour
	cmp r4, #0xff
	bne .3

	; Check for mouse button.
	.if Mouse_Enable
	swi OS_Mouse
	cmp r2, #0
	bne .3
	.endif

	; Check for keypress.
  	MOV     R0, #129
  	MOV     R1, #0      ; timeout low byte (centiseconds)
  	MOV     R2, #0      ; timeout high byte — 0,0 = return immediately
  	SWI     OS_Byte  

	cmp r2, #0xff
	beq .2

.3:
	; Start fade out here.
	subs r4, r4, #8
	str r4, startlogo_colour
	bpl .2

	; Reset to MODE 9.
    swi OS_WriteI+22
    swi OS_WriteI+9
    swi OS_RemoveCursors

	; Steve says this helps mis-aligned sound buffer "stutter" problem.
	mov r0, #19
	mov r1, #13
.4:
	swi OS_Byte
	subs r1, r1, #1
	bne .4

	mov r0, #0
	bl play_song
.endif

    ldr pc, [sp], #4

app_exit:
    mov pc, lr

; ============================================================================
; App main loop.
; ============================================================================

; Always called, regardless of tick status (add if needed).
;app_pre_tick_frame:
;    mov pc, lr

; Ditto.
;app_pre_draw_frame:
;    mov pc, lr

; ============================================================================
; App vsync callback.
; Do any app specific logic in here.
; Up to the app to call the screen bank swap and any palette logic.
; ============================================================================

; Entered in IRQ mode.
; Registers R0, R1, R11, R12 are stashed on the stack and free to use.
; They do not need to be restored before exiting.
app_vsync_callback:
    str lr, [sp, #-4]!

    bl video_display_pending_bank

    ; NB. Donut wants to set palette always.
    ; Normally only set palette when there's a new bank.
    ; Actually does it matter if we're ready from vidc_buffer[displayed_bank]?

    bl video_set_display_bank_palette

.if Mouse_Enable
	; Check mouse.
	swi OS_Mouse
	str r1, live_mouse_y
.endif

	; Read VU Bars.
	mov r0, #0
	QTMSWI QTM_ReadVULevels
	str r0, vu_bars_levels

    .if 0
    ; Custom screen split code for donut.

    ; Set Vinit to const logo addr.
    ldr r11, app_logo_phys
    mov r0, r11, lsl #2
    orr r0, r0, #MEMC_Vinit
    str r0, [r0]

    ; Set Vend to end of logo.
    ldr r0, app_scroller_phys
    sub r0, r0, #1
    mov r0, r0, lsl #2
    orr r0, r0, #MEMC_Vend
    str r0, [r0]

    ; Set Vstart to start of screen buffer.
    adr r12, screen_addr_phys
    ldr r1, displayed_bank
    ldr r0, [r12, r1, lsl #2]       ; physical RAM address of pending bank
    add r1, r0, r11                 ; size of donut area for future Vend

    mov r0, r0, lsl #2
    orr r0, r0, #MEMC_Vinit
    orr r0, r0, #MEMC_Vstart^MEMC_Vinit
    str r0, [r0]

    ; Inside donut space (line 128) set Vend to end of screen buffer.
    sub r0, r1, #1
    mov r0, r0, lsl #2
    orr r0, r0, #MEMC_Vend

    ldr r12, raster_table_memc_p
    str r0, [r12, #128*8]           ; line 128

    ; Do scrolltext?!
    ldr r0, app_ready
    cmp r0, #0
    beq .4

    ; Switch to SVC mode with IRQs enabled.
    str r14, tipsy_r14_irq
	TEQP PC,#FIQ_Disable | ProcMode_Svc
    mov r0, r0

    stmfd sp!, {r2-r10,lr}
    bl tipsy_scroller_tick
    ; Write scroller to static buffer.
    ldr r12, app_scroller_logical
    bl tipsy_scroller_draw_fast
    ldmfd sp!, {r2-r10,lr}

    ; Back to IRQ mode
	TEQP PC,#IRQ_Disable | FIQ_Disable | ProcMode_IRQ
    mov r0, r0
    ldr r14, tipsy_r14_irq
    .4:
    .endif

    ldr pc, [sp], #4

; ============================================================================
; Play the music!
; ============================================================================

song_number:
	.long -1

autoplay_flag:
	.long 1

song_timer:
	.long 0

song_pause:
	.long 0

volume_fade:
	.long 0

prev_sound_flags:
	.long 0

glitch_timer:
	.long 0

exit_fade:
	.long -1

panning_pos:
	.long PanningPos_Default

; R0=song number
play_song:
	QTMSWI QTM_Stop

	; Unload the current module.
	; Converts samples back to linear format (from LOG) so they can be played again.
	mov r1, r0
	mov r0, #-1
	QTMSWI QTM_Clear
	mov r0, r1

	; Load module.
	str r0, song_number
	adr r2, music_table
	ldr r1, [r2, r0, lsl #2]	; r0 * 4
	mov r0, #0					; load from address and use in-place.
	QTMSWI QTM_Load

	adr r2, volumeTable
	ldr r1, song_number
	ldrb r0, [r2, r1]
	QTMSWI QTM_Volume

    ; NB. According to Chipo Django 1 source:
	; This seems to help minimise how much RasterMan timing slips after QTM_Start.
	swi RasterMan_Wait

	; Play music!
	QTMSWI QTM_Start

	mov r0, #0
	str r0, song_timer
	str r0, song_pause
	str r0, volume_fade

	mov r0, #Glitch_Time
	str r0, glitch_timer
	mov pc, lr

check_autoplay:
	; Are we already transitioning to the next song?
	ldr r0, song_pause
	cmp r0, #0
	bne .3

	ldr r0, volume_fade
	cmp r0, #0
	bne .1

	; How long has the song been running?
	ldr r1, song_timer
	add r1, r1, #1
	str r1, song_timer

	; Check autoplay flag - just exit if off.
	ldr r0, autoplay_flag
	cmp r0, #0
	moveq pc, lr

	; Has the song timer gone over our autoplay duration?
	ldr r0, song_number

	adr r2, durationTable
	ldr r3, [r2, r0, lsl #2]

	adr r4, volumeTable
	ldrb r5, [r4, r0]

	sub r3, r3, r5			; so we end on Bodo's frame?
	cmp r1, r3
	movlt pc, lr

	; Kick off fade out.
	str r5, volume_fade
	mov pc, lr

	; Fade out volume.
.1:
	subs r0, r0, #1
	str r0, volume_fade
	QTMSWI QTM_Volume

	ldr r0, volume_fade
	cmp r0, #0
	movne pc, lr

	; Pause for breath between tracks.
.2:
	ldr r1, song_number
	adr r2, songpausetable
	ldr r0, [r2, r1, lsl #2]
	str r0, song_pause
	mov pc, lr

.3:
	subs r0, r0, #1
	str r0, song_pause
	movne pc, lr

	str lr, [sp, #-4]!
	ldr r0, song_number
	mov r3, r0
	add r0, r0, #1
	cmp r0, #Dj_Max_Songs
	movge, r0, #0
	bl play_song

	ldr pc, [sp], #4

; R0=autoplay flag.
set_autoplay:
	str r0, autoplay_flag
	mov pc, lr

app_fade_at_exit:
	ldr r0, exit_fade
	cmp r0, #0
	bpl .1

	; First time.
	ldr r1, song_number
	adr r2, volumeTable
	ldrb r0, [r2, r1]					; get start volume

.1:
	subs r0, r0, #2
	movlt r0, #0
	str r0, exit_fade
	QTMSWI QTM_Volume
	mov pc, lr

; R0=panning pos
app_set_panning:
	str r0, panning_pos

	adr r2, panning_table
	add r2, r2, r0, lsl #4

    mov r0, #1
	ldr r1, [r2], #4
    QTMSWI QTM_Stereo

    mov r0, #2
	ldr r1, [r2], #4
    QTMSWI QTM_Stereo

    mov r0, #3
	ldr r1, [r2], #4
    QTMSWI QTM_Stereo

    mov r0, #4
	ldr r1, [r2], #4
    QTMSWI QTM_Stereo

	mov pc, lr

; ============================================================================

panning_table:
;	.long -127, -127, -127, -127		; TEST: ALL LEFT
;	.long 127, 127, 127, 127			; TEST: ALL RIGHT
	.long -127, 127, 127, -127			; Full LRRL
	.long -64, 64, 64, -64				; Half LRRL
	.long -32, 32, 32, -32				; Quarter LRRL
	.long 0, 0, 0, 0					; Centre (mono)
.p2align 2

music_table:
.include "build/music_table.asm"
	.long splash_mod_no_adr				; shush!

.p2align 2
dj_menu_strings:
.include "build/dj_menu_strings.asm"
	.byte "autoplay off", 0
	.byte "autoplay on ", 0
	.byte "full stereo ", 0
	.byte "half stereo ", 0
	.byte "quarter sep", 0
	.byte "centred mono", 0
; End of string list.
	.byte -1

.p2align 2

; master volume of each tune
volumeTable:
.include "build/volume_table.asm"
	.byte	 64		 ; splash
	.p2align 2

durationTable:
.include "build/duration_table.asm"
	.long	 0			 ; splash

; break between tunes
songpausetable:
.include "build/song_pause_table.asm"
	.long	 0			 ; splash

; ============================================================================
; FX code modules.
; ============================================================================

.include "src/fx/dj-menu.asm"
.if AppConfig_UsingRasterMan
.include "src/rasters.asm"
.endif
.include "src/fx/vu-bars.asm"
.include "src/fx/logo-glitch.asm"
.include "src/fx/dj-scroller.asm"
.include "src/fx/dj-font.asm"
.include "lib/screen.asm"
