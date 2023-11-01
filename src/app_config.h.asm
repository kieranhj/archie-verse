; ============================================================================
; App config header (include at start).
; Configuration that is specific to a (final) production.
; ============================================================================

.equ AppConfig_StackSize,               1024
.equ AppConfig_LoadModFromFile,         1
.equ AppConfig_DynamicSampleSpeed,      1
.equ AppConfig_InstallIrqHandler,       0       ; otherwise uses Event_VSync.
.equ AppConfig_UseSyncTracks,           1       ; currently Luapod could also be Rocket.

; ============================================================================
; Sequence config.
; ============================================================================

.equ SeqConfig_EnableLoop, 0
.equ SeqConfig_MaxPatterns, 39

.equ SeqConfig_ProTracker_Tempo,        108
.equ SeqConfig_ProTracker_TicksPerRow,  3

.equ SeqConfig_PatternLength_Rows,      64
; TODO: Calculate dependent vars.
.equ SeqConfig_PatternLength_Secs,      4.44444
.equ SeqConfig_PatternLength_Frames,    222.222

.equ SeqConfig_MaxFrames,               65536        ; 222.222 frames per pattern.

; ============================================================================
; Audio config.
; ============================================================================

.equ AudioConfig_SampleSpeed_SlowCPU,   48		    ; ideally get this down for ARM2
.equ AudioConfig_SampleSpeed_FastCPU,   24		    ; ideally 16us for ARM250+
.equ AudioConfig_SampleSpeed_Default,   AudioConfig_SampleSpeed_SlowCPU
.equ AudioConfig_SampleSpeed_CPUThreshold, 80       ; ARM3~=20, ARM250~=70, ARM2~=108

.equ AudioConfig_StereoPos_Ch1,         -127        ; full left
.equ AudioConfig_StereoPos_Ch2,         +127        ; full right
.equ AudioConfig_StereoPos_Ch3,         +32         ; off centre R
.equ AudioConfig_StereoPos_Ch4,         -32         ; off centre L

.equ AudioConfig_VuBars_Effect,         1			; 'fake' bars
.equ AudioConfig_VuBars_Gravity,        1			; lines per vsync

; ============================================================================
; Screen config.
; ============================================================================

.equ VideoConfig_Widescreen,    0
.equ VideoConfig_ScreenBanks,   2

.equ Screen_Mode,               9
.equ Screen_Width,              320
.equ Screen_PixelsPerByte,      2

.if VideoConfig_Widescreen
.equ VideoConfig_VduMode,       97  ; MODE 9 widescreen (320x180)
									; or 96 for MODE 13 widescreen (320x180)
.equ VideoConfig_ModeHeight,    180
.equ Screen_Height,             180
.else
.equ VideoConfig_VduMode,       Screen_Mode
.equ VideoConfig_ModeHeight,    256
.equ Screen_Height,             256
.endif

.equ Screen_Stride,             Screen_Width/Screen_PixelsPerByte
.equ Screen_Bytes,              Screen_Stride*Screen_Height
.equ Mode_Bytes,                Screen_Stride*VideoConfig_ModeHeight