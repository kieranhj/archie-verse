; ============================================================================
; RISC OS SWI numbers and related constants.
; ============================================================================

.ifndef RasterMan_VersionNumber
.equ RasterMan_VersionNumber, 0.38
.endif

; ============================================================================
; OS SWI Numbers
; ============================================================================

.equ OS_WriteC,                 0x00    ; Write character to output streams
.equ OS_WriteS,                 0x01    ; Write inline string to output streams
.equ OS_Write0,                 0x02    ; Write null-terminated string
.equ OS_NewLine,                0x03    ; Write newline (CR LF)
.equ OS_ReadC,                  0x04    ; Read character from input stream (blocking)
.equ OS_CLI,                    0x05    ; Execute CLI command
.equ OS_Byte,                   0x06    ; Miscellaneous single-byte operations
.equ OS_Word,                   0x07    ; Miscellaneous multi-byte operations
.equ OS_File,                   0x08    ; File operations
.equ OS_Args,                   0x09    ; Read/write open file info
.equ OS_BGet,                   0x0a    ; Read byte from open file
.equ OS_BPut,                   0x0b    ; Write byte to open file
.equ OS_GBPB,                   0x0c    ; Read/write multiple bytes
.equ OS_Find,                   0x0d    ; Open/close file
.equ OS_ReadLine,               0x0e    ; Read line from input stream (blocking)
.equ OS_Control,                0x0f    ; Read/write environment handler addresses
.equ OS_GetEnv,                 0x10    ; Read program environment info
.equ OS_Exit,                   0x11    ; Exit program
.equ OS_SetEnv,                 0x12    ; Write program environment info
.equ OS_IntOn,                  0x13    ; Enable IRQ interrupts (SVC mode)
.equ OS_IntOff,                 0x14    ; Disable IRQ interrupts (SVC mode)
.equ OS_CallBack,               0x15    ; Set up callback handler
.equ OS_EnterOS,                0x16    ; Enter OS (SVC) mode
.equ OS_BreakPt,                0x17    ; Software breakpoint
.equ OS_BreakCtrl,              0x18    ; Set break handler
.equ OS_UnusedSWI,              0x19    ; Default handler for unknown SWIs
.equ OS_SetCallBack,            0x1b    ; Set transient callback address
.equ OS_Mouse,                  0x1c    ; Read mouse position and button state
.equ OS_Heap,                   0x1d    ; Heap management
.equ OS_Module,                 0x1e    ; Module operations
.equ OS_Claim,                  0x1f    ; Claim a vector
.equ OS_Release,                0x20    ; Release a vector
.equ OS_ReadUnsigned,           0x21    ; Read unsigned integer from string
.equ OS_GenerateEvent,          0x22    ; Generate an OS event
.equ OS_ReadVarVal,             0x23    ; Read system variable
.equ OS_SetVarVal,              0x24    ; Write system variable
.equ OS_GSInit,                 0x25    ; Initialise GS string reading
.equ OS_GSRead,                 0x26    ; Read next character from GS string
.equ OS_GSTrans,                0x27    ; Translate GS string
.equ OS_BinaryToDecimal,        0x28    ; Convert binary integer to decimal string
.equ OS_FSControl,              0x29    ; Filing system control
.equ OS_ChangeDynamicArea,      0x2a    ; Change size of dynamic area
.equ OS_GenerateError,          0x2b    ; Generate an error
.equ OS_ReadEscapeState,        0x2c    ; Read current escape state (re-entrant)
.equ OS_EvaluateExpression,     0x2d    ; Evaluate an expression
.equ OS_SpriteOp,               0x2e    ; Sprite operations
.equ OS_ReadPalette,            0x2f    ; Read palette entry
.equ OS_ServiceCall,            0x30    ; Issue a service call
.equ OS_ReadVduVariables,       0x31    ; Read VDU variables
.equ OS_ReadPoint,              0x32    ; Read colour of screen pixel
.equ OS_UpCall,                 0x33    ; Issue an UpCall
.equ OS_CallAVector,            0x34    ; Call a vector via SWI
.equ OS_ReadModeVariable,       0x35    ; Read mode variable for given mode
.equ OS_RemoveCursors,          0x36    ; Remove text cursor
.equ OS_RestoreCursors,         0x37    ; Restore text cursor
.equ OS_SWINumberToString,      0x38    ; Convert SWI number to string
.equ OS_SWINumberFromString,    0x39    ; Convert string to SWI number
.equ OS_InstallKeyHandler,      0x3e    ; Replace low-level keyboard handler
.equ OS_CheckModeValid,         0x3f    ; Check if mode number is valid
.equ OS_ChangeEnvironment,      0x40    ; Read/write environment handler
.equ OS_ReadMonotonicTime,      0x42    ; Read centisecond monotonic timer
.equ OS_SubstituteArgs,         0x43    ; Substitute command line arguments
.equ OS_PrettyPrint,            0x44    ; Print string with substitution
.equ OS_Plot,                   0x45    ; Graphics plot operation
.equ OS_WriteN,                 0x46    ; Write N bytes to output streams
.equ OS_AddToVector,            0x47    ; Add handler to vector chain
.equ OS_WriteEnv,               0x48    ; Write program environment string
.equ OS_ReadArgs,               0x49    ; Read and decode command arguments
.equ OS_ClaimDeviceVector,      0x4b    ; Claim a device vector
.equ OS_ReleaseDeviceVector,    0x4c    ; Release a device vector
.equ OS_DelinkApplication,      0x4d    ; Remove application from memory
.equ OS_RelinkApplication,      0x4e    ; Restore application to memory
.equ OS_ExitAndDie,             0x50    ; Exit and kill module
.equ OS_AddCallBack,            0x54    ; Add a transient callback to queue
.equ OS_ReadDefaultHandler,     0x55    ; Read address of default handler
.equ OS_SetECFOrigin,           0x56    ; Set ECF pattern origin
.equ OS_ReadSysInfo,            0x58    ; Read system information
.equ OS_ChangedBox,             0x5a    ; Read/reset changed bounding box
.equ OS_ReadDynamicArea,        0x5c    ; Read dynamic area info
.equ OS_PrintChar,              0x5d    ; Print character bypassing OS_WriteC
.equ OS_RemoveCallBack,         0x5f    ; Remove a transient callback from queue
.equ OS_SetColour,              0x61    ; Set colour and ECF pattern
.equ OS_Pointer,                0x64    ; Read/write pointer shape and position
.equ OS_Memory,                 0x68    ; Memory operations
.equ OS_Reset,                  0x6a    ; Perform soft reset
.equ OS_MMUControl,             0x6b    ; MMU control operations
.equ OS_WriteI,                 0x100   ; Write character with immediate operand (OS_WriteI + char)

; X-variants: bit 17 set — errors returned in R0 rather than raised
.equ XOS_Byte,                  OS_Byte             | (1 << 17)
.equ XOS_Word,                  OS_Word             | (1 << 17)
.equ XOS_ReadVduVariables,      OS_ReadVduVariables | (1 << 17)

; ============================================================================
; OS_Convert SWIs  (0xD0 - 0xEC)
; ============================================================================

.equ OS_ConvertHex1,            0xd0
.equ OS_ConvertHex2,            0xd1
.equ OS_ConvertHex4,            0xd2
.equ OS_ConvertHex6,            0xd3
.equ OS_ConvertHex8,            0xd4
.equ OS_ConvertCardinal1,       0xd5
.equ OS_ConvertCardinal2,       0xd6
.equ OS_ConvertCardinal3,       0xd7
.equ OS_ConvertCardinal4,       0xd8
.equ OS_ConvertInteger1,        0xd9
.equ OS_ConvertInteger2,        0xda
.equ OS_ConvertInteger3,        0xdb
.equ OS_ConvertInteger4,        0xdc
.equ OS_ConvertBinary1,         0xdd
.equ OS_ConvertBinary2,         0xde
.equ OS_ConvertBinary3,         0xdf
.equ OS_ConvertBinary4,         0xe0
.equ OS_ConvertSpacedCardinal1, 0xe1
.equ OS_ConvertSpacedCardinal2, 0xe2
.equ OS_ConvertSpacedCardinal3, 0xe3
.equ OS_ConvertSpacedCardinal4, 0xe4
.equ OS_ConvertSpacedInteger1,  0xe5
.equ OS_ConvertSpacedInteger2,  0xe6
.equ OS_ConvertSpacedInteger3,  0xe7
.equ OS_ConvertSpacedInteger4,  0xe8
.equ OS_ConvertFixedNetStation, 0xe9
.equ OS_ConvertNetStation,      0xea
.equ OS_ConvertFixedFileSize,   0xeb
.equ OS_ConvertFileSize,        0xec

; ============================================================================
; OS_Byte sub-commands  (R0 value for SWI OS_Byte)
; ============================================================================

.equ OSByte_EventDisable,       13      ; Disable OS event (R1 = event number)
.equ OSByte_EventEnable,        14      ; Enable OS event  (R1 = event number)
.equ OSByte_Vsync,              19      ; Wait for vertical sync
.equ OSByte_ClearEscape,        124     ; Clear escape condition
.equ OSByte_SetEscape,          125     ; Force escape condition
.equ OSByte_AckEscape,          126     ; Acknowledge and clear escape condition
.equ OSByte_KeyboardScan,       121     ; Scan keyboard for specific key (R1 = key EOR 0x80)
.equ OSByte_KeyboardScanAll,    122     ; Scan keyboard for any key (returns key number)
.equ OSByte_ReadKey,            129     ; Read keyboard with timeout (R1/R2 = centiseconds)
.equ OSByte_WriteVduBank,       112     ; Set VDU driver display bank
.equ OSByte_WriteDisplayBank,   113     ; Set hardware display bank

; ============================================================================
; OS_Word sub-commands  (R0 value for SWI OS_Word)
; ============================================================================

.equ OSWord_WritePalette,       12

; ============================================================================
; BBC-compatible internal key numbers for OS_Byte 121/129.
; Values are EOR &FF — pass directly as R1 to OS_Byte 121.
; Source: RISC OS PRM pp 1-849.
; ============================================================================

.equ IKey_Escape,               0x8f
.equ IKey_Return,               0xb6
.equ IKey_Space,                0x9d
.equ IKey_ArrowUp,              0xc6
.equ IKey_ArrowDown,            0xd6
.equ IKey_ArrowLeft,            0xe6
.equ IKey_ArrowRight,           0x86
.equ IKey_A,                    0xbe
.equ IKey_D,                    0xcd
.equ IKey_R,                    0xcc
.equ IKey_S,                    0xae
.equ IKey_LeftClick,            0xf6
.equ IKey_RightClick,           0xf4

; ============================================================================
; Archimedes low-level internal key numbers transmitted by IOC.
; Source: RISC OS PRM pp 1-156.
; Used by RasterMan and OS_Event Event_KeyPressed (11).
; ============================================================================

.equ RMKey_Escape,              0x00
.equ RMKey_Return,              0x47
.equ RMKey_Space,               0x5f
.equ RMKey_ArrowUp,             0x59
.equ RMKey_ArrowLeft,           0x62
.equ RMKey_ArrowDown,           0x63
.equ RMKey_ArrowRight,          0x64
.equ RMKey_PageUp,              0x21
.equ RMKey_PageDown,            0x36
.equ RMKey_LeftClick,           0x70
.equ RMKey_RightClick,          0x72
.equ RMKey_A,                   0x3c
.equ RMKey_B,                   0x52
.equ RMKey_C,                   0x50
.equ RMKey_D,                   0x3e
.equ RMKey_E,                   0x29
.equ RMKey_F,                   0x3f
.equ RMKey_G,                   0x40
.equ RMKey_H,                   0x41
.equ RMKey_I,                   0x2e
.equ RMKey_J,                   0x42
.equ RMKey_K,                   0x43
.equ RMKey_L,                   0x44
.equ RMKey_M,                   0x54
.equ RMKey_N,                   0x53
.equ RMKey_O,                   0x2f
.equ RMKey_P,                   0x30
.equ RMKey_Q,                   0x27
.equ RMKey_R,                   0x2a
.equ RMKey_S,                   0x3d
.equ RMKey_T,                   0x2b
.equ RMKey_U,                   0x2d
.equ RMKey_V,                   0x51
.equ RMKey_W,                   0x28
.equ RMKey_X,                   0x4f
.equ RMKey_Y,                   0x2c
.equ RMKey_Z,                   0x4e
.equ RMKey_1,                   0x11
.equ RMKey_2,                   0x12
.equ RMKey_3,                   0x13
.equ RMKey_4,                   0x14
.equ RMKey_5,                   0x15
.equ RMKey_6,                   0x16
.equ RMKey_7,                   0x17
.equ RMKey_8,                   0x18
.equ RMKey_9,                   0x19
.equ RMKey_0,                   0x1a

; ============================================================================
; Dynamic areas and VDU variables
; ============================================================================

.equ DynArea_Screen,            2
.equ VD_ScreenStart,            148

; ============================================================================
; Vectors and events
; ============================================================================

.equ ErrorV,                    0x01
.equ EventV,                    0x10
.equ Event_VSync,               4
.equ Event_KeyPressed,          11

; ============================================================================
; Font Manager SWIs
; ============================================================================

.equ Font_FindFont,             0x40081
.equ Font_LoseFont,             0x40082
.equ Font_Paint,                0x40086
.equ Font_ConverttoOS,          0x40088
.equ Font_SetFont,              0x4008a
.equ Font_SetColours,           0x40092
.equ Font_SetPalette,           0x40093
.equ Font_ScanString,           0x400a1

; ============================================================================
; Wimp SWIs
; ============================================================================

.equ Wimp_SlotSize,             0x400ec

; ============================================================================
; Sound SWIs
; ============================================================================

.equ Sound_Configure,           0x40140
.equ Sound_SoundLog,            0x40181

; ============================================================================
; QTM (MOD player) SWIs
; ============================================================================

.equ QTM_SwiBase,               0x47e40
.equ QTM_Load,                  0x47e40
.equ QTM_Start,                 0x47e41
.equ QTM_Stop,                  0x47e42
.equ QTM_Pause,                 0x47e43
.equ QTM_Clear,                 0x47e44
.equ QTM_Info,                  0x47e45
.equ QTM_Pos,                   0x47e46
.equ QTM_EffectControl,         0x47e47
.equ QTM_Volume,                0x47e48
.equ QTM_SetSampleSpeed,        0x47e49
.equ QTM_DMABuffer,             0x47e4a
.equ QTM_RemoveChannel,         0x47e4b
.equ QTM_RestoreChannel,        0x47e4c
.equ QTM_Stereo,                0x47e4d
.equ QTM_ReadSongLength,        0x47e4e
.equ QTM_ReadSequenceTable,     0x47e4f
.equ QTM_VUBarControl,          0x47e50
.equ QTM_ReadVULevels,          0x47e51
.equ QTM_ReadSampleTable,       0x47e52
.equ QTM_ReadSpeed,             0x47e53
.equ QTM_PlaySample,            0x47e54
.equ QTM_SongStatus,            0x47e55
.equ QTM_ReadPlayingTime,       0x47e56
.equ QTM_PlayRawSample,         0x47e57
.equ QTM_SoundControl,          0x47e58
.equ QTM_SWITableAddress,       0x47e59
.equ QTM_RegisterSample,        0x47e5a
.equ QTM_SetSpeed,              0x47e5b
.equ QTM_MusicVolume,           0x47e5c
.equ QTM_SampleVolume,          0x47e5d
.equ QTM_MusicOptions,          0x47e5e
.equ QTM_MusicInterrupt,        0x47e5f
.equ QTM_ReadChannelData,       0x47e60
.equ QTM_ReadNoteWord,          0x47e61
.equ QTM_DMAHandler,            0x47e62

.equ MusicInterrupt_SongEnded,  0

; ============================================================================
; RasterMan SWIs
; ============================================================================

.if RasterMan_VersionNumber >= 0.37
.equ RasterMan_SWIBase,         0x5a940
.else
.equ RasterMan_SWIBase,         0x47e80
.endif

.equ RasterMan_Install,         RasterMan_SWIBase + 0x0
.equ RasterMan_Release,         RasterMan_SWIBase + 0x1
.equ RasterMan_Wait,            RasterMan_SWIBase + 0x2
.equ RasterMan_SetTables,       RasterMan_SWIBase + 0x3
.equ RasterMan_Version,         RasterMan_SWIBase + 0x4
.equ RasterMan_ReadScanline,    RasterMan_SWIBase + 0x5
.equ RasterMan_SetVIDCRegister, RasterMan_SWIBase + 0x6
.equ RasterMan_SetMEMCRegister, RasterMan_SWIBase + 0x7
.equ RasterMan_Status,          RasterMan_SWIBase + 0x8
.equ RasterMan_ScanKeyboard,    RasterMan_SWIBase + 0x9

.if RasterMan_VersionNumber <= 0.37
.equ RasterMan_ClearKeyBuffer,  RasterMan_SWIBase + 0xa
.equ RasterMan_ReadScanAddr,    RasterMan_SWIBase + 0xb
.equ RasterMan_HSyncWaitAddr,   RasterMan_SWIBase + 0xc
.equ RasterMan_Configure,       RasterMan_SWIBase + 0xd
.equ RasterMan_Mode,            RasterMan_SWIBase + 0xe
.equ RasterMan_Callback,        RasterMan_SWIBase + 0xf
.equ RasterMan_ReadSWIHandler,  RasterMan_SWIBase + 0x10
.else
.equ RasterMan_Callback,        RasterMan_SWIBase + 0xa
.equ RasterMan_ReadSWIAddress,  RasterMan_SWIBase + 0xb
.equ RasterMan_HSyncWait,       RasterMan_SWIBase + 0xc
.equ RasterMan_Configure,       RasterMan_SWIBase + 0xd
.equ RasterMan_ScreenMode,      RasterMan_SWIBase + 0xe
.endif

; ============================================================================
; VIDC1 palette and timing registers
; ============================================================================

.equ VIDC_Col0,                 0x00000000  ; Palette register: index << 26
.equ VIDC_Col1,                 0x04000000
.equ VIDC_Col2,                 0x08000000
.equ VIDC_Col3,                 0x0c000000
.equ VIDC_Col4,                 0x10000000
.equ VIDC_Col5,                 0x14000000
.equ VIDC_Col6,                 0x18000000
.equ VIDC_Col7,                 0x1c000000
.equ VIDC_Col8,                 0x20000000
.equ VIDC_Col9,                 0x24000000
.equ VIDC_Col10,                0x28000000
.equ VIDC_Col11,                0x2c000000
.equ VIDC_Col12,                0x30000000
.equ VIDC_Col13,                0x34000000
.equ VIDC_Col14,                0x38000000
.equ VIDC_Col15,                0x3c000000
.equ VIDC_Border,               0x40000000

.equ VIDC_Write,                0x03400000
.equ VIDC_HBorderStart,         0x88000000  ; (M-1)/2 pixels << 14 [odd]
.equ VIDC_HDisplayStart,        0x8c000000  ; (M-7)/2 MODE 9 pixels << 14 [x7]
.equ VIDC_HDisplayEnd,          0x90000000  ; (M-7)/2 MODE 9 pixels << 14 [x7]
.equ VIDC_HBorderEnd,           0x94000000  ; (M-1)/2 pixels << 14 [odd]
.equ VIDC_VCycle,               0xa0000000
.equ VIDC_VBorderStart,         0xa8000000  ; N-1 rasters << 14
.equ VIDC_VDisplayStart,        0xac000000  ; N-1 rasters << 14
.equ VIDC_VDisplayEnd,          0xb0000000  ; N-1 rasters << 14
.equ VIDC_VBorderEnd,           0xb4000000  ; N-1 rasters << 14

.equ MODE9_HCentrePixels,       291
.equ MODE9_VCentreRasters,      166

; ============================================================================
; MEMC registers and physical memory map
;
;  PhysRam + TotalScreenSize  +---------+ Vend
;                             |         |
;                             +---------+
;                             |  ^ MEMC |
;                             |  | DMA  |
;                             |  v      |
;       PhysRAM (0x02000000)  +---------+ Vstart / Vinit
;                    ^        |         |
;              Total |        +---------+
;             Screen |        |  ^      |
;               Size |        |  | Screen
;                    v        |  v      |
;  PhysRam - TotalScreenSize  +---------+ ScreenStart VDU variable
; ============================================================================

.equ MEMC_PhysRam,              0x02000000
.equ MEMC_Vinit,                0x03600000  ; | (physical address >> 4) << 2
.equ MEMC_Vstart,               0x03620000  ; | (physical address >> 4) << 2
.equ MEMC_Vend,                 0x03640000  ; | (physical address >> 4) << 2

; ============================================================================
; IOC registers
; ============================================================================

.equ IOC_Write,                 0x3200000

.equ IOC_Control,               0x00
.equ IOC_Serial,                0x04
.equ IOC_IRQ_StatusA,           0x10
.equ IOC_IRQ_RequestA,          0x14    ; Read
.equ IOC_IRQ_ClearA,            0x14    ; Write
.equ IOC_IRQ_MaskA,             0x18
.equ IOC_IRQ_StatusB,           0x20
.equ IOC_IRQ_RequestB,          0x24    ; Read
.equ IOC_IRQ_ClearB,            0x24    ; Write
.equ IOC_IRQ_MaskB,             0x28
.equ IOC_FIQ_Status,            0x30
.equ IOC_FIQ_Request,           0x34
.equ IOC_FIQ_Mask,              0x38
.equ IOC_T0_CountLo,            0x40
.equ IOC_T0_CountHi,            0x44
.equ IOC_T0_Go,                 0x48
.equ IOC_T0_Latch,              0x4c
.equ IOC_T1_CountLo,            0x50
.equ IOC_T1_CountHi,            0x54
.equ IOC_T1_Go,                 0x58
.equ IOC_T1_Latch,              0x5c
.equ IOC_T2_CountLo,            0x60
.equ IOC_T2_CountHi,            0x64
.equ IOC_T2_Go,                 0x68
.equ IOC_T2_Latch,              0x6c
.equ IOC_T3_CountLo,            0x70
.equ IOC_T3_CountHi,            0x74
.equ IOC_T3_Go,                 0x78
.equ IOC_T3_Latch,              0x7c

.equ IRQA_PrinterBusy,          1 << 0
.equ IRQA_SerialPort,           1 << 1
.equ IRQA_PrinterAck,           1 << 2
.equ IRQA_Vsync,                1 << 3
.equ IRQA_PowerOn,              1 << 4
.equ IRQA_Timer0,               1 << 5
.equ IRQA_Timer1,               1 << 6

; ============================================================================
; ARM processor modes and flags (R15 / CPSR bits on ARM2/ARM250)
; ============================================================================

.equ ProcMode_User,             0b00
.equ ProcMode_FIQ,              0b01
.equ ProcMode_IRQ,              0b10
.equ ProcMode_Svc,              0b11

.equ IRQ_Disable,               1 << 27
.equ FIQ_Disable,               1 << 26

; ============================================================================
; Hardware exception vectors
; ============================================================================

.equ HwVector_Reset,            0x00    ; Reset
.equ HwVector_UndefInst,        0x04    ; Undefined instruction
.equ HwVector_SWI,              0x08    ; SWI — enters SVC mode, IRQ disabled
.equ HwVector_PrefAbort,        0x0c    ; Prefetch abort
.equ HwVector_DataAbort,        0x10    ; Data abort
.equ HwVector_AddrExcep,        0x14    ; Address exception (outside 0x00000000-0x03FFFFFF)
.equ HwVector_IRQ,              0x18    ; IRQ — enters IRQ mode, IRQ disabled
.equ HwVector_FIQ,              0x1c    ; FIQ — enters FIQ mode, IRQ and FIQ disabled

; ============================================================================
; ASCII character codes
; ============================================================================

.equ ASCII_0,                   0x30
.equ ASCII_9,                   0x39
.equ ASCII_A,                   0x41
.equ ASCII_Z,                   0x5a
.equ ASCII_a,                   0x61
.equ ASCII_i,                   0x69
.equ ASCII_z,                   0x7a
.equ ASCII_Space,               0x20
.equ ASCII_ExclamationMark,     0x21
.equ ASCII_Minus,               0x2d
.equ ASCII_Colon,               0x3a
.equ ASCII_LessThan,            0x3c
.equ ASCII_MoreThan,            0x3e

; ============================================================================
; VDU codes
; ============================================================================

.equ VDU_TextColour,            17
.equ VDU_Home,                  30
.equ VDU_SetPos,                31
