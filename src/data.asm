; ============================================================================
; DATA Segment.
; Hack as necessary per prod.
; ============================================================================

.p2align 6
.data

; ===========================================================================

.p2align 2
dj_logo_no_adr:
.incbin "build/cdlogo.bin"

.if 0
.p2align 2
dj_logo_raster_pal_no_adr:
.incbin "build/cdlogo.bin.pal"
.endif

.p2align 2
dj_logo_vidc_pal_no_adr:
.incbin "build/cdlogo_vidc.bin"

.p2align 2
startlogo_no_adr:
.incbin "build/startlogo.bin"

; ============================================================================
; Dj Scroller

.p2align 2
dj_scroller_font_data_no_adr:
.incbin "build/big-font.bin"


.p2align 2
dj_scroller_text_string_no_adr:
; Add 20 blank chars so that scroller begins on RHS of the screen, as per Amiga.
.byte "                    "
.include "src/data/django/scrolltxt-final.asm"
dj_scroller_text_string_end_no_adr:
.p2align 2

; ============================================================================
; Dj Menu

.p2align 2
dj_menu_font_data_no_adr:
.incbin "build/small-font.bin"

; ============================================================================
; Library data.
; ============================================================================

.include "lib/lib_data.asm"

; ============================================================================
; QTM Embedded.
; ============================================================================

.if AppConfig_UseQtmEmbedded
.p2align 2
QtmEmbedded_Base:
.if _LOG_SAMPLES
.incbin "data/riscos/tinyQ149t2,ffa"
.else
.incbin "data/riscos/tinyQTM149,ffa"
.endif
.endif

; ============================================================================
; Sequence data (RODATA Segment - ironically).
; ============================================================================

.p2align 2
seq_main_program:
.include "src/data/sequence-data.asm"
; TODO: Reinstate dynamic load.

; ============================================================================
; Events data (TODO: Dynamic load).
; ============================================================================

.if AppConfig_UseEvents
.p2align 2
events_data_no_adr:
.if _DYNAMIC_RELOAD
.skip Events_MaxSize
.else
.incbin "build/events.bin"
.endif
.endif

; ============================================================================
; Dj3 Music

.include "build/dj3_incbins.asm"

.p2align 2
splash_mod_no_adr:
.incbin "data/music/dj3/mod.raven-stereo.mod"

; ============================================================================
; Music MOD (MUST BE LAST in DATA SEGMENT).
; ============================================================================

.if AppConfig_SysHandlesMusic
.if AppConfig_UseArchieKlang

;External_Samples_no_adr:
.incbin "data/akp/Rhino2.mod.raw"
.p2align 2

music_mod_no_adr:
.incbin "build/music.mod.trk"

.else

.if !AppConfig_LoadModFromFile

.p2align 2
;music_mod_no_adr:
.if _LOG_SAMPLES
; TODO: Move conversion to Log samples into Makefile.
.incbin "data/music/particles_15.002"
.else
.incbin "build/music.mod"
.endif

.endif
.endif
.endif

; ============================================================================
; BSS IMMEDIATELY FOLLOWS.
; ============================================================================
