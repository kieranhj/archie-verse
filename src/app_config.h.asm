; ============================================================================
; App config header (include at start).
; Configuration that is specific to a (final) production.
; ============================================================================

.equ AppConfig_StackSize,               4096

.equ AppConfig_DynamicSampleSpeed,      (_SMALL_EXE && 0)   ; Because table gen takes time at boot...
.equ AppConfig_LoadModFromFile,         (_DEBUG && 1)
.equ AppConfig_ReturnMainToCaller,      (!_DEBUG && 0)       ; desktop by default TOOD: Should be an exe config?
.equ AppConfig_UseArchieKlang,          (_SMALL_EXE && 0)
.equ AppConfig_UseEvents,               1
.equ AppConfig_UseMemcBanks,            1
.equ AppConfig_UseQtmEmbedded,          0
.equ AppConfig_UseSyncTracks,           0       ; currently Luapod could also be Rocket.

.equ AppVsyncHandler_Events,            0
.equ AppVsyncHandler_Irq,               1
.equ AppVsyncHandler_RasterMan,         2

.equ AppConfig_VsyncHandler,            AppVsyncHandler_Events
.equ AppConfig_UsingRasterMan,          AppConfig_VsyncHandler==AppVsyncHandler_RasterMan

; ============================================================================
; Machine config.
; TODO: This should really be dynamic and determined at runtime.
;       But can assume page size is 16K minimum for demos that require >1Mb.
; ============================================================================

.equ Machine_PageSize,                  16*1024     ; can assume at least this for 2Mb demos.

; ============================================================================
; Sequence config.
; ============================================================================

.equ SeqConfig_EnableLoop,              (AppConfig_UsingRasterMan || 1) ; RM version of QTM always loops
.equ SeqConfig_InitOnLoop,              1
.equ SeqConfig_MaxPatterns,             22

; TODO: Get ProTracker info out of the MOD parser.
.equ SeqConfig_ProTracker_Tempo,        125         ; Default = 125.
.equ SeqConfig_ProTracker_TicksPerRow,  3

.equ SeqConfig_PatternLength_Rows,      64
.equ SeqConfig_PatternLength_Secs,      (2.5*SeqConfig_ProTracker_TicksPerRow*SeqConfig_PatternLength_Rows)/SeqConfig_ProTracker_Tempo
.equ SeqConfig_PatternLength_Frames,    SeqConfig_PatternLength_Secs*50.0

.equ SeqConfig_MaxFrames,               SeqConfig_MaxPatterns*SeqConfig_PatternLength_Frames

; ============================================================================
; Audio config.
; ============================================================================

.equ AudioConfig_SampleSpeed_SlowCPU,   48		    ; ideally get this down for ARM2
.equ AudioConfig_SampleSpeed_FastCPU,   24		    ; ideally 24us for ARM250+
.if _SLOW_CPU
.equ AudioConfig_SampleSpeed_Default,   AudioConfig_SampleSpeed_SlowCPU
.else
.equ AudioConfig_SampleSpeed_Default,   AudioConfig_SampleSpeed_FastCPU
.endif
.equ AudioConfig_SampleSpeed_CPUThreshold, 0x140       ; ARM3~=20, ARM250~=70, ARM2~=108

.equ AudioConfig_StereoPos_Ch1,         -32         ; half left
.equ AudioConfig_StereoPos_Ch2,         +32         ; half right
.equ AudioConfig_StereoPos_Ch3,         +32         ; off centre R
.equ AudioConfig_StereoPos_Ch4,         -32         ; off centre L

.equ AudioConfig_VuBars_Effect,         1			; 'fake' bars
.equ AudioConfig_VuBars_Gravity,        1			; lines per vsync

; ============================================================================
; Screen config.
; ============================================================================

.equ VideoConfig_Widescreen,            0
.equ VideoConfig_ScreenBanks,           3

.equ Screen_Mode,                       9
.equ Screen_Width,                      320
.equ Screen_PixelsPerByte,              2

.if VideoConfig_Widescreen
.equ VideoConfig_VduMode,               97  ; MODE 9 widescreen (320x180)
									        ; or 96 for MODE 13 widescreen (320x180)
.equ VideoConfig_ModeHeight,            180
.equ Screen_Height,                     180
.else
.equ VideoConfig_VduMode,               Screen_Mode
.equ VideoConfig_ModeHeight,            256
.equ Screen_Height,                     256
.endif

; Clear screen (clipping)
.equ Cls_FirstLine,                     0               ; inclusive
.equ Cls_LastLine,                      Screen_Height-1 ; inclusive

; Derived values.
.equ Screen_Stride,                     Screen_Width/Screen_PixelsPerByte
.equ Screen_WidthWords,                 Screen_Stride/4
.equ Screen_Bytes,                      Screen_Stride*Screen_Height
.equ Mode_Bytes,                        Screen_Stride*VideoConfig_ModeHeight
.equ Cls_Bytes,                         (Cls_LastLine+1-Cls_FirstLine)*Screen_Stride

.if AppConfig_ReturnMainToCaller
.equ TotalScreenSize,                   384*1024        ; assume caller is managing screen RAM allocation.
.else
.equ TotalScreenSize,                   (Mode_Bytes*VideoConfig_ScreenBanks+Machine_PageSize-1)&~(Machine_PageSize-1)
.endif

; ============================================================================
; Library config.
; ============================================================================

; All parts.
.equ LibConfig_IncludeMem,              1
.equ LibConfig_IncludeMathVar,          1
.equ LibConfig_IncludeSine,             1
.equ LibConfig_IncludeVector,           1
.equ LibConfig_IncludeMatrix,           1
.equ LibConfig_IncludeTriangle,         1
.equ LibConfig_IncludeDivide,           1
.equ LibConfig_IncludeSqrt,             1
