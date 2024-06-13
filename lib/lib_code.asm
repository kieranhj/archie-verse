; ============================================================================
; Library code routines.
; ============================================================================

.include "lib/maths.h.asm"

.macro LIB_PROGRESS
.if LibConfig_ShowInitProgress
swi OS_WriteI+'_'               ; TODO: Define progress to app_config.h
.endif
.endm

; ============================================================================

lib_code_gen_base_p:
    .long lib_code_gen_base_no_adr

; ============================================================================

lib_init:
    str lr, [sp, #-4]!

    ; --------------------------------------------------
    ; Table generation (table space preallocated in BSS)
    ; --------------------------------------------------

    .if LibSine_MakeSinusTable
    bl MakeSinus
    LIB_PROGRESS
    .endif
    .if LibDivide_UseRecipTable
    bl MakeReciprocal
    LIB_PROGRESS
    .endif
    .if LibSqrt_MakeSqrtTable
    bl sqrt_init
    LIB_PROGRESS
    .endif
    .if LibConfig_IncludeCircles
    bl ClearCircleBuf
    LIB_PROGRESS
    .endif

    ; ------------------------------------------------
    ; Code generation (size not known at compile time)
    ; ------------------------------------------------

    ldr r12, lib_code_gen_base_p

    .if LibConfig_IncludeSpanGen
    bl gen_code
    LIB_PROGRESS
    .endif
    .if LibConfig_IncludeLineSegments
    bl line_segments_init
    LIB_PROGRESS
    .endif

    ; R12 returns top of RAM.
    ldr pc, [sp], #4

; ============================================================================

.include "lib/mem.asm"

.if LibConfig_IncludeSine
.include "lib/sine.asm"
.endif
.if LibConfig_IncludeVector
.include "lib/vector.asm"
.endif
.if LibConfig_IncludeMatrix
.include "lib/matrix.asm"
.endif
.if LibConfig_IncludeDivide
.include "lib/divide.asm"
.endif
.if LibConfig_IncludeLine
.include "lib/line.asm"
.endif
.if LibConfig_IncludePolygon
.include "lib/polygon.asm"
.endif
.if LibConfig_IncludeTriangle
.include "lib/triangle.asm"
.endif
.if LibConfig_IncludeSqrt
.include "lib/sqrt.asm"
.endif
.if LibConfig_IncludeCircles
.include "lib/circles.asm"
.endif
.if LibConfig_IncludeSpanGen
.if Screen_Mode==0
.include "lib/mode0.asm"
.endif
.if Screen_Mode==13 || Screen_Mode==12
.include "lib/mode13.asm"
.endif
.if Screen_Mode==9
.include "lib/span_gen.asm"
.endif
.endif
.if LibConfig_IncludeSprites
.include "lib/sprite_utils.asm"
.endif
.if LibConfig_IncludeMathVar
.include "lib/math-var.asm"
.endif
.if LibConfig_IncludeLineSegments
.include "lib/line-segments.asm"
.endif

; ============================================================================
