; ============================================================================
; App config header (include at start).
; Configuration that is specific to a (final) production.
; ============================================================================

.equ AppConfig_StackSize,               1024
.equ AppConfig_LoadModFromFile,         0
.equ AppConfig_DynamicSampleSpeed,      (_SMALL_EXE && 0)   ; Because table gen takes time at boot...
.equ AppConfig_InstallIrqHandler,       0       ; otherwise uses Event_VSync.
.equ AppConfig_UseSyncTracks,           0       ; currently Luapod could also be Rocket.
.equ AppConfig_UseQtmEmbedded,          1
.equ AppConfig_UseArchieKlang,          (_SMALL_EXE && 1)

; ============================================================================
; Sequence config.
; ============================================================================

.equ SeqConfig_EnableLoop,              0
.equ SeqConfig_MaxPatterns,             18          ; inc. 2.5 patterns at 12 ticks/row.

.equ SeqConfig_ProTracker_Tempo,        114         ; Default = 125.
.equ SeqConfig_ProTracker_TicksPerRow,  6

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

.equ VideoConfig_Widescreen,    0
.equ VideoConfig_ScreenBanks,   2

.equ Screen_Mode,               12
.equ Screen_Width,              640
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
.equ Screen_WidthWords,         Screen_Stride/4
.equ Screen_Bytes,              Screen_Stride*Screen_Height
.equ Mode_Bytes,                Screen_Stride*VideoConfig_ModeHeight

; ============================================================================
; QTM Embedded entry points.
; ============================================================================

.if AppConfig_UseQtmEmbedded
.macro QTMSWI swi_no
stmfd sp!, {r11,lr}
mov r11, #\swi_no - QTM_SwiBase
mov lr, pc
ldr pc, QtmEmbedded_Swi
ldmfd sp!, {r11,lr}
.endm

.else
.macro QTMSWI swi_no
swi \swi_no
.endm
.endif
