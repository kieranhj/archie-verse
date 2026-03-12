; ============================================================================
; App standard code.
; Hack as necessary per prod.
; Want this file to be hackable.
; ============================================================================

.equ Dj_Max_Songs,              12
.equ Glitch_Time,				20 	; frames

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

    mov r0, #0
    bl play_song

    ldr pc, [sp], #4

; ============================================================================
; App late initialisation for things that require access to the screen.
; ============================================================================

; R12=screen addr.
app_late_init:
    str lr, [sp, #-4]!

    ldr r12, screen_addr

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

; ============================================================================

music_table:
	.long flight_gone_mod_no_adr		; 0
	.long chips_asmussen_mod_no_adr		; 1
	.long bang_for_beep_mod_no_adr	    ; 2
	.long darkside_mod_no_adr		    ; 3
	.long herr_irrtum_mod_no_adr		; 4
	.long no_mistake_mod_no_adr			; 5
	.long novel_mod_no_adr			    ; 6
	.long echoes_past_mod_no_adr		; 7
	.long chipfly_mod_no_adr			; 8
	.long rettungsgasse_mod_no_adr		; 9
	.long my_life_mod_no_adr		    ; 10
	.long take_me_back_mod_no_adr		; 11

.p2align 2
dj_menu_strings:
	.byte "flight gone", 0, "adkd", 0
    .byte "chips asmussen", 0, "andy", 0
	.byte "bang for the beep", 0, "curt cool", 0
	.byte "darkside", 0, "filippp", 0
	.byte "die nmi miamichip gang", 0, "herr irrum", 0
	.byte "wattwurmshredde", 0, "nomistake", 0
	.byte "django", 0, "novel", 0
	.byte "echoes of the past", 0, "okeanos", 0
	.byte "chipfly", 0, "slaxx", 0
	.byte "rettungsgasse", 0, "uncen20", 0
	.byte "my life in melody", 0, "wotw", 0
	.byte "take me back", 0, "crm 2021", 0
	.byte "autoplay off", 0
	.byte "autoplay on", 0
; End of string list.
	.byte -1

.p2align 2

; master volume of each tune
volumeTable:    
    .byte    64 ;60      ; digitags
    .byte    64 ;35      ; birdhouse
    .byte    64 ;50-10   ; funky delicious
    .byte    64 ;62-2  ; autumn
    .byte    64 ;51  ; je suis k
    .byte    64 ;60-2-2  ; square circles
    .byte    64 ;50+5     ; coolbeans
    .byte    64 ;54+2  ; la soupe
    .byte    64 ;56-3  ; sajt
    .byte    64 ;59-1+2  ; bodoaxian
    .byte    64 ;64    ; holodash
    .byte    64 ;39-2  ; squid ring
	.p2align 2

durationTable:
    .long    50*122      ; digitags
    .long    51*50       ; birdhouse
    .long    50*92      ; funky delicious
    .long    192*50-40      ; autumn
    .long    159*50      ; je suis k
    .long    173*50      ; square circles
    .long    145*50      ; coolbeans
    .long    120*50      ; la soupe
    .long    95*50       ; sajt
    .long    110*50      ; bodoaxian
    .long    116*50      ; holodash
    .long    174*50      ; squid ring
    
; break between tunes
songpausetable:
    .long    100+20      ; digitags
    .long    70+30      ; birdhouse
    .long    60+30      ; funky delicious
    .long    10       ; autumn
    .long    70+20      ; je suis k
    .long    80+30      ; square circles
    .long    50      ; coolbeans
    .long    80+20+30      ; la soupe
    .long    50+40      ; sajt
    .long    70      ; bodoaxian
    .long    90+20      ; holodash
    .long    90      ; squid ring

; ============================================================================
; FX code modules.
; ============================================================================

.include "src/fx/dj-menu.asm"
.if AppConfig_UsingRasterMan
.include "src/rasters.asm"
.endif
.include "src/fx/logo-glitch.asm"
.include "src/fx/vu-bars.asm"
.include "src/fx/dj-scroller.asm"
.include "src/fx/dj-font.asm"
.include "lib/screen.asm"
