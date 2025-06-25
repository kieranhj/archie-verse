; ============================================================================
; App standard code.
; Hack as necessary per prod.
; ============================================================================

; ============================================================================
; App debug code.
; ============================================================================

.if _DEBUG
app_init_debug:
    str lr, [sp, #-4]!

    bl debug_init

    ; DEBUG_REGISTER_VAR debug_rm_key
    DEBUG_REGISTER_VAR_EX debug_frame_rate, debug_plot_addr_as_dec4
    DEBUG_REGISTER_VAR_EX vsync_delta, debug_plot_addr_as_dec4
    DEBUG_REGISTER_VAR music_pos
    DEBUG_REGISTER_VAR frame_counter
    .if _DEMO_PART==_PART_DONUT
;    DEBUG_REGISTER_VAR scene3d_stats_quads_plotted
    .endif
;    DEBUG_REGISTER_VAR music_pos
    DEBUG_REGISTER_VAR_EX debug_free_ram, debug_plot_addr_as_dec4
    .if _DEMO_PART==_PART_SPACE
;    DEBUG_REGISTER_VAR_EX uv_table_code_size, debug_plot_addr_as_dec4
    .endif

    DEBUG_REGISTER_KEY          RMKey_Space,      debug_toggle_main_loop_pause,  0
    DEBUG_REGISTER_KEY_WITH_VAR RMKey_A,          debug_set_byte_true,           debug_restart_flag
    DEBUG_REGISTER_KEY_WITH_VAR RMKey_S,          debug_set_byte_true,           debug_main_loop_step
    DEBUG_REGISTER_KEY_WITH_VAR RMKey_D,          debug_toggle_byte,             debug_show_info
    DEBUG_REGISTER_KEY_WITH_VAR RMKey_R,          debug_toggle_byte,             debug_show_rasters
    DEBUG_REGISTER_KEY          RMKey_ArrowRight, debug_skip_to_next_pattern,    0

;    DEBUG_REGISTER_VAR math_var_active_count
    ldr pc, [sp], #4
.endif

; ============================================================================
; App late initialisation for things that require access to the screen.
; ============================================================================

; R12=screen addr.
app_late_init:
    str lr, [sp, #-4]!

    ; Custom init for Donut.

    .if _DEMO_PART==_PART_DONUT
    ; Copy logo to static buffer.
    adr r0, app_logo_p
    ldmia r0, {r0-r3}
    mov r1, r3                  ; logical addr
    mov r2, r2, lsr #2          ; #words
    bl mem_copy_words

    mov r0, #1
    str r0, app_ready
    .endif

    ; Kick off anything that happens just before start.

    bl app_vsync_late_init

    ldr pc, [sp], #4
; TODO: Make this more generic or include in sequence?

.if _DEMO_PART==_PART_DONUT
app_logo_p:
    .long three_logo_no_adr  ; src ptr
    .long 0                 ; offset
    .long 56*Screen_Stride  ; length
    .long MEMC_PhysRam - TotalScreenSize + 192*Screen_Stride ; logical 

app_logo_phys:
    .long 192*Screen_Stride >> 4                             ; physical

app_scroller_phys:
    .long 248*Screen_Stride >> 4                             ; physical

app_scroller_logical:
    .long MEMC_PhysRam - TotalScreenSize + 248*Screen_Stride ; logical 

app_ready:
    .long 0

tipsy_r14_irq:
    .long 0
.endif

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
; App modules.
; ============================================================================

.include "src/app_vsync.asm"
.include "src/app_audio.asm"
.include "src/app_video.asm"

; ============================================================================
; FX code modules.
; ============================================================================

.if _DEMO_PART==_PART_TEST
.include "src/fx/sine-scroller.asm"
.include "src/rasters.asm"
.endif

.if _DEMO_PART==_PART_DONUT
.include "src/rasters-donut.asm"
.include "src/fx/scene-3d.asm"
.include "src/fx/tipsy-scroller.asm"
.endif

.if _DEMO_PART==_PART_SPACE
.include "src/fx/rotate.asm"
.include "src/fx/uv-table.asm"
.include "src/fx/lut-scroller.asm"
.endif

; ============================================================================
; Additional library code modules used by the FX sequence.
; ============================================================================

.include "lib/screen.asm"
.if _DEMO_PART==_PART_DONUT
.include "lib/mesh.asm"
.endif
.if _DEMO_PART==_PART_SPACE
.include "lib/lz4-decode.asm"
.endif

; ============================================================================
; ArchieKlang generated code.
; TODO: Move to app_audio module?
; ============================================================================

.if AppConfig_UseArchieKlang
.include "lib/archieklang.asm"
.endif
