; ============================================================================
; Library module config header (include at start).
; ============================================================================

.ifndef LibConfig_ShowInitProgress
.equ LibConfig_ShowInitProgress,        0
.endif

.ifndef LibConfig_IncludeMem
.equ LibConfig_IncludeMem,              0
.endif

.ifndef LibConfig_IncludeSqrt
.equ LibConfig_IncludeSqrt,             0
.endif

.ifndef LibConfig_IncludeLine
.equ LibConfig_IncludeLine,             0
.endif

.ifndef LibConfig_IncludeTriangle
.equ LibConfig_IncludeTriangle,         0
.endif

.ifndef LibConfig_IncludePolygon
.equ LibConfig_IncludePolygon,          0
.endif

.ifndef LibConfig_IncludeDivide
.equ LibConfig_IncludeDivide,           0
.endif

.ifndef LibConfig_IncludeVector
.equ LibConfig_IncludeVector,           0
.endif

.ifndef LibConfig_IncludeMatrix
.equ LibConfig_IncludeMatrix,           0
.endif

.ifndef LibConfig_IncludeCircles
.equ LibConfig_IncludeCircles,          0
.endif

.ifndef LibConfig_IncludeSprites
.equ LibConfig_IncludeSprites,          0
.endif

.ifndef LibConfig_IncludeMathVar
.equ LibConfig_IncludeMathVar,          0
.endif

.ifndef LibConfig_IncludeLineSegments
.equ LibConfig_IncludeLineSegments,     0
.endif

.ifndef LibConfig_IncludeSine
.equ LibConfig_IncludeSine,             (LibConfig_IncludeMatrix)
.endif

.ifndef LibConfig_IncludeSpanGen
.equ LibConfig_IncludeSpanGen,          (LibConfig_IncludeTriangle || LibConfig_IncludePolygon || LibConfig_IncludeCircles)
.endif

.ifndef LibSqrt_IncludeRsqrt
.equ LibSqrt_IncludeRsqrt,              (LibConfig_IncludeSqrt && 0)
.endif

; ============================================================================

; TODO: Allow configuration of more than one screen mode for code gen etc.?

.equ LibSpanGen_MaxSpan,                Screen_Width
.equ LibSpanGen_MultiWord,              4                                       ; Use 1, 2 or 4 words.

.equ LibCircles_MaxRadius,              20
.equ LibCircles_MaxCircles,             2                                       ; Max circles drawn in a frame (!)
.equ LibCircles_DataWords,              4                                       ; {X centre, colour word, ptr to size table, line count}

.equ LibSqrt_MakeSqrtTable,             (LibConfig_IncludeSqrt && _SMALL_EXE)
.equ LibSine_MakeSinusTable,            (LibConfig_IncludeSine && _SMALL_EXE)
.equ LibDivide_UseRecipTable,           (LibConfig_IncludeDivide && 1)

.equ LibDivide_Reciprocal_t,            16           ; Table entries = 1<<t
.equ LibDivide_Reciprocal_m,            9            ; Max value = 1<<m
.equ LibDivide_Reciprocal_s,            LibDivide_Reciprocal_t-LibDivide_Reciprocal_m    ; Table is (1<<16+s)/(x<<s)
.equ LibDivide_Reciprocal_TableSize,    1<<LibDivide_Reciprocal_t

.equ LibConfig_SpriteBufferSize,        8192

; ============================================================================
