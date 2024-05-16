; ============================================================================
; Library module data tables.
; ============================================================================

.p2align 6

; ============================================================================

.if _DEBUG
debug_font_no_adr:
;    .incbin "data/lib/BBC.bin"
    .incbin "data/lib/Spectrum.bin"
;    .incbin "data/lib/Apple2e.bin"
.endif

; ============================================================================

.if LibConfig_IncludeSine && LibSine_MakeSinusTable==0
sinus_table_no_adr:
	.incbin "data/lib/sine_8192.bin"
.endif

; ============================================================================

.if LibConfig_IncludeSqrt && LibSqrt_MakeSqrtTable==0
sqrt_table_no_adr:
;	.incbin "data/lib/sqrt_1024.bin"

    ; LARGE SQRT table goes from [1, 512*512) = [0x00001, 0x40000) (18 bits)
    ; Contains 65536 = 0x10000 entries                       (16 bits)
    ; Values are in 16.16 format.
	.incbin "data/lib/sqrt_large.bin"
.endif
.if LibConfig_IncludeSqrt
.if _SQRT_VERIFY
sqrt_table_from_file_no_adr:
	.incbin "data/lib/sqrt_large.bin"
.endif
.endif

.if LibSqrt_IncludeRsqrt
rsqrt_table_no_adr:
	.incbin "data/lib/rsqrt_1024.bin"
.endif

; ============================================================================

.if LibConfig_IncludeCircles
.include "lib/circledat.asm"
.endif

; ============================================================================
