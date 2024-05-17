; ============================================================================
; Library module config header (include at start).
; ============================================================================

; TODO: Allow configuration of more than one screen mode for code gen etc.?

.equ LibConfig_ShowInitProgress,        1

.equ LibConfig_IncludeSqrt,             0
.equ LibConfig_IncludeLine,             0
.equ LibConfig_IncludeTriangle,         0
.equ LibConfig_IncludePolygon,          0
.equ LibConfig_IncludeDivide,           1
.equ LibConfig_IncludeVector,           0
.equ LibConfig_IncludeMatrix,           0
.equ LibConfig_IncludeCircles,          0
.equ LibConfig_IncludeSprites,          0
.equ LibConfig_IncludeMathVar,          1

.equ LibConfig_IncludeSine,             (LibConfig_IncludeMatrix || 1)
.equ LibConfig_IncludeSpanGen,          (LibConfig_IncludeTriangle || LibConfig_IncludePolygon || LibConfig_IncludeCircles || 0)       ; Required for polygon & triangle & cirlces.

.equ LibConfig_IncludeLineSegments,     1

; ============================================================================

.equ LibDivide_UseRecipTable,           (LibConfig_IncludeDivide && 1)

.equ LibSpanGen_MaxSpan,                Screen_Width
.equ LibSpanGen_MultiWord,              1                                       ; Use 1, 2 or 4 words.

.equ LibCircles_MaxRadius,              20
.equ LibCircles_MaxCircles,             2                                     ; Max circles drawn in a frame (!)
.equ LibCircles_DataWords,              4                                       ; {X centre, colour word, ptr to size table, line count}

.equ LibSqrt_IncludeRsqrt,              (LibConfig_IncludeSqrt && 0)

.equ LibSqrt_MakeSqrtTable,             (LibConfig_IncludeSqrt && _SMALL_EXE)
.equ LibSine_MakeSinusTable,            (LibConfig_IncludeSine && _SMALL_EXE)

.equ LibDivide_Reciprocal_t,            16           ; Table entries = 1<<t
.equ LibDivide_Reciprocal_m,            9            ; Max value = 1<<m
.equ LibDivide_Reciprocal_s,            LibDivide_Reciprocal_t-LibDivide_Reciprocal_m    ; Table is (1<<16+s)/(x<<s)
.equ LibDivide_Reciprocal_TableSize,    1<<LibDivide_Reciprocal_t

.equ LibConfig_SpriteBufferSize,        8192

; ============================================================================
