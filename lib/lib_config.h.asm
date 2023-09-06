; ============================================================================
; Library module config header (include at start).
; ============================================================================

; TODO: Allow configuration of more than one screen mode?

.equ LibConfig_IncludeSqrt, 0
.equ LibConfig_IncludeLine, 1
.equ LibConfig_IncludeTriangle, 0
.equ LibConfig_IncludePolygon, 1
.equ LibConfig_IncludeDivide, 1
.equ LibConfig_IncludeVector, 1
.equ LibConfig_IncludeMatrix, 0
.equ LibConfig_IncludeCircles, 1

.equ LibConfig_IncludeSine, (LibConfig_IncludeMatrix || 1)
.equ LibConfig_IncludeSpanGen, (LibConfig_IncludeTriangle || LibConfig_IncludePolygon || 1)       ; Required for polygon & triangle.

; ============================================================================

.equ LibDivide_UseReciprocalTable, (LibConfig_IncludeDivide && 1)
.equ LibSine_MakeSinusTable, (LibConfig_IncludeSine && 0)           ; TODO: Put back sine table generation!
.equ LibSpanGen_MaxSpan, Screen_Width
.equ LibSpanGen_MultiWord, 2                                        ; Use 1, 2 or 4 words.

.equ LibCircles_MaxRadius, 70
.equ LibCircles_MaxCircles, 32                                     ; Max circles drawn in a frame (!)
.equ LibCircles_DataWords, 4                                        ; {X centre, colour word, ptr to size table, line count}

; ============================================================================
