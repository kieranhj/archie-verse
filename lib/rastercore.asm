; ============================================================================
; RasterMan Core.
; RasterMan init and IRQ handling code embedded in main loop.
; All code originally written by Steve Harrison aka Phoenix^QTM.
; ============================================================================

.equ QTMblock, 44+128

; ============================================================================
; keyboard protocol codes
; ============================================================================

.equ bACK, 0b00111111    ; = 1st byte acknowleged
.equ sACK, 0b00110001    ; = keyboard scan only
.equ sMAK, 0b00110011    ; = keyboard and non-zero mouse scan
.equ HRST, 0b11111111    ; = keyboard hard reset
.equ KbAck1, 0b11111110  ; = reset response 1
.equ KbAck2, 0b11111101  ; = reset response 2

; ============================================================================
; RasterMan vars.
; ============================================================================

oldIRQa:
   .long      0
oldIRQb:
   .long      0
oldIRQbranch:
   .long      0
oldIRQaddress:
   .long      0

qtmcontrol:
   .byte      0               ;=0 if QTM sound handler not enabled
vsyncbyte:
   .byte      0
   .byte      0
   .byte      0
pagesize:
   .long      0
numpages:
   .long      0
pagefindblk:
   .long      0 ;0
   .long      0 ;4
   .long      0 ;8
   .long      0 ;12
qtmdmabuffer2:                ;buffer 2 must be immediately before buffer 1
   .long      0               ;
qtmdmabuffer1:                ;keep after buffer 2
   .long      0               ;

qtmseerror:
   .long      255
   .byte      "QTM_se failed to initialise correctly"
   .byte      0
   .p2align 2

; TODO: Don't need private stack for keyboard handling in IRQ mode.
kbd_stack:
   .long      0 ;R4
   .long      0 ;R5
   .long      0 ;R6
   .long      0 ;R7

dmabank_num:
   .long      0
physicaldma2: ;dma buffer 2 must be immediately before dma buffer 1
   .long      0   ;
physicaldma1: ;keep these together
   .long      0   ;
qtmdmasize:
   .long      0
qtmdmahandler:
   .long      0
qtmr12pointer:
   .long      0
dmaentry_r9:
   .long      0
qtmchannels:
   .long      0

;   BACK=0b00111111 = 1st byte acknowleged
;   SACK=0b00110001 = keyboard only
;   SMAK=0b00110011 = keyboard and non-zero mouse
;   HRST=0b11111111 = keyboard hard reset
; KbAck1=0b11111110 = reset response 1
; KbAck2=0b11111101 = reset response 2

keycounter:  .byte 0 ; \   -> 1 or 0, or 0x10,0x20,0x30 = reset
keybyte1:    .byte 0 ;  }_ this block of 4 bytes must keep together..
keybyte2:    .byte 0 ;  }
nextkeybyte: .byte 0 ; /

dma_in_progress:
   .byte      0
   .byte      0
   .byte      0
   .byte      0

tempr13:
   .long      0

temp_svc_stack_p:
    .long rastercore_svc_stack_no_adr

; ============================================================================
; Interrupt handling.
; ============================================================================

rastercore_install_irq_handler:
    str lr, [sp, #-4]!              ; R14_user

    ; Enter Supervisor mode.

	SWI		OS_EnterOS
	TEQP    PC,#IRQ_Disable|FIQ_Disable|ProcMode_Svc  ;jam all interrupts!
    mov r0, r0

    BL      checkQTMspecialrelease
    ADRVS   R0,qtmseerror
    swivs   OS_GenerateError

    ; ** Don't claim FIQ
    ;MOV       R0,#0x0C           ;claim FIQ
    ;SWI       XOS_ServiceCall
    ;STRVS     R0,[R13]
    ;LDMVSFD   R13!,{R0-R12,PC}

    ; reset keyboard

    MOV       R0,#0x10
    STR       R0,keycounter     ;set keycounter to 0x10=reset and clear keyboard bytes

    MOV       R0,#19
    SWI       XOS_Byte          ;added for sound sync code v0.29

    ; ** Don't own FIQs so don't enter FIQ mode.

    ; v0.29 attempt to re-sync sound to VSync

    LDR       R1,physicaldma1     ;dma2 was last read from DMABuffer but we had one VSync since then...
    LDR       R2,physicaldma2
    LDR       R3,qtmdmasize
    ADD       R4,R2,R3            ;R4=SendN for dma2
    SUB       R4,R4,#16           ; fixit ;-)
    ADD       R3,R1,R3            ;R3=SendN for dma1
    SUB       R3,R3,#16           ; fixit ;-)
    MOV       R1,R1,LSR#2         ;(dma1 Sstart/16) << 2
    MOV       R3,R3,LSR#2         ;(dma1 SendN/16) << 2
    MOV       R2,R2,LSR#2         ;(dma2 Sstart/16) << 2
    MOV       R4,R4,LSR#2         ;(dma2 SendN/16) << 2
    MOV       R0,#MEMC_Write      ;memc base
    ADD       R0,R0,#0x0080000    ;Sstart base
    ORR       R1,R1,R0            ;R1=dma1 Sstart
    ORR       R2,R2,R0            ;R2=dma2 Sstart
    ADD       R0,R0,#0x0020000    ;SendN base
    ORR       R3,R3,R0            ;R3=dma1 SendN
    ORR       R4,R4,R0            ;R4=dma2 SendN
    ADD       R0,R0,#0x0020000    ;R0=Sptr_rst

    STR       R3,[R3]             ;dma1 SendN
    STR       R1,[R1]             ;dma1 Sstart
    STR       R0,[R0]             ;force buffer swap!

    STR       R4,[R4]             ;dma2 SendN
    STR       R2,[R2]             ;dma2 Sstart set buffer 2 up for next swap

    MOV       R0,#0
    STR       R0,dmabank_num      ;0 after install = fill buffer 1 next

    ; sound buffer should now be sync'd to swap from b1 to b2 at ~VSync
    ; next sound buffer fill should be to buffer 1 after next VSync

    MOV       R1,#IOC_Write
    LDRB      R0,[R1,#IOC_IRQ_MaskA]
    STR       R0,oldIRQa
    LDRB      R0,[R1,#IOC_IRQ_MaskB]
    STR       R0,oldIRQb

    ; When installing, we will start on the next VSync, so set IRQ for VSync only
    ; and set T1 to contain 'vsyncvalue', so everything in place for VSync int...

    MOV       R0,#IRQA_Vsync
    STRB      R0,[R1,#IOC_IRQ_MaskA]    ;set IRQA mask to 0b00001000 = VSync only
    MOV       R0,#0b10000000
    STRB      R0,[R1,#IOC_IRQ_MaskB]     ;set IRQB mask to 0b10000000 = SRx only
    ;MOV       R0,#0
    ;STRB      R0,[R1,#IOC_IRQ_MaskB]    ;set IRQB mask to 0

; ** Do we need to do this?
;    STRB      R0,[R1,#IOC_FIQ_Mask]    ;set FIQ mask to 0 (disable FIQs)

    ; ** Don't set T1

    ;MOV       R0,#0xFF           ;*v0.14* set max T1 - ensure T1 doesn't trigger before first VSync!
    ;STRB      R0,[R1,#0x50+2]    ;T1 low byte, +2 for write
    ;STRB      R0,[R1,#0x54+2]    ;T1 high byte, +2 for write
    ;STRB      R1,[R1,#0x58+2]    ;T1_go = reset T1

    ;MOV       R0,#vsyncreturn_lowbyte;or ldr r8,vsyncval  - will reload with this on VSync...
    ;STRB      R0,[R1,#0x50+2]    ;T1 low byte, +2 for write
    ;MOV       R0,#vsyncreturn_highbyte;or mov r8,r8,lsr#8
    ;STRB      R0,[R1,#0x54+2]    ;T1 high byte, +2 for write

    ; ** Store current IRQ vector as branch and address.

    MOV       R0,#0
    LDR       R1,[R0,#HwVector_IRQ]      ;load current IRQ vector
    STR       R1,oldIRQbranch

    BIC       R1,R1,#0xFF000000
    MOV       R1,R1,LSL#2
    ADD       R1,R1,#HwVector_IRQ+8
    STR       R1,oldIRQaddress

    ; ** Don't poke our IRQ/FIQ code into 0x1C-0xFC

	; ** Install our IRQ handler the regular way.

	adr r1, rastercore_irq_handler
	sub r1, r1, #32
	mov r1, r1, lsr #2
	add r1, r1, #0xea000000			; B irq_handler.
	str r1, [r0, #HwVector_IRQ]

    ; ** Don't setup our FIQ registers.

    ; ** Don't need Arthur bollox.

    TEQP      PC,#ProcMode_User     ;enable IRQs and FIQs, change to USER mode
    MOV       R0,R0

    ldr pc, [sp], #4                ; R14_user

rastercore_uninstall_irq_handler:
	SWI		OS_EnterOS

   MOV       R0,#0
   LDR       R1,oldIRQbranch
   STR       R1,[R0,#HwVector_IRQ]        ;restore original IRQ controller

   MOV       R0,#0
   MOV       R1,#IOC_Write

; ** Do we need to do this?
;   STRB      R0,[R1,#IOC_FIQ_Mask]      ;set FIQ mask to 0 (disable FIQs)

   LDR       R0,oldIRQa
   STRB      R0,[R1,#IOC_IRQ_MaskA]
   LDR       R0,oldIRQb
   STRB      R0,[R1,#IOC_IRQ_MaskB]      ;restore IRQ masks

    TEQP      PC,#ProcMode_User     ;enable IRQs and FIQs, change to USER mode
    MOV       R0,R0

    mov pc, lr

; ============================================================================
; Raster Core interrupt hander.
; ============================================================================

rastercore_irq_handler:
   TEQP      PC,#IRQ_Disable|FIQ_Disable|ProcMode_IRQ ; DISABLE FIQs Stay in IRQ mode.
   MOV       R0,R0                  ;37 A8 sync IRQ registers

   STMFD     R13!,{r8,r9}

   MOV       R9,#IOC_Write
   LDRB      R8,[R9,#0x14+0]     ; 3 20 load irq_A triggers ***BUG to v0.13*** v0.14 read 0x14+0
                                 ;      was reading status at 0x10, which ignores IRQ mask!!!
   TST       R8,#0b01000000       ; 4 24 bit 3 = Vsync, bit 6 = T1 trigger (HSync)
   beq       notHSync     ; 5 28 *v0.14 if not T1, then go to VSync/Keyboard code*

    ; TIMER 1 CODE GOES HERE.

   LDMFD     R13!,{r8,r9}
   SUBS      PC,R14,#4              ;39 90 return to foreground

notHSync:
   TST       R8,#0b00001000       ;retest R8 is it bit 3 = Vsync? (bit 6 = T1 trigger/HSync)

   ; ** Don't reset T1
   ;STRNEB    R14,[R14,#0x58+2]    ;if VSync, reset T1 (latch should already have the vsyncvalue...)

   ; that's the high-priority stuff done, now we can check keyboard too...

   BEQ       checkkeyboard       ;if not VSync, check IRQ_B for SRx interrupt

; ============================================================================
; VSYNC CODE >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ============================================================================

   STRB      R8,[R9,#0x14+2]     ;if VSync, clear all IRQ_A interrupt triggers

   ; ** Don't remove Vsync as we're not using T1.

   ;MOV       R8,#0b01000000       ; (removed VSync trigger v0.05)
   ;STRB      R8,[R9,#0x18+2]     ;set IRQA mask to 0b01000000 = T1 only

   ; ** Don't need to turn on keyboard as we don't turn it off without hsync.
   ;MOV       R8,#0b10000000
   ;STRB      R8,[R9,#0x28+2]     ;set IRQB mask to 0b10000000 = SRx only

   ; ** Don't set T1.

   LDRB      R8,vsyncbyte
   RSB       R8,R8,#3
   STRB      R8,vsyncbyte

   ; ** Don't increment TIME (no BASIC).

   LDRB      R8,qtmcontrol
   TEQ       R8,#1
   LDMNEFD   R13!,{r8,r9}
   BNE       done_sound

; ============================================================================
; AUDIO CODE >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ============================================================================

    ; SET_BORDER to cyan to time QTM music player.

    .if _DEBUG_RASTERS
  	ldrb r8, debug_show_rasters
	cmp r8, #0
    beq .1
    mov r8, #VIDC_Border | 0xff0 ;
    mov r9, #VIDC_Write
    str r8, [r9]
    .1:
    ldmfd sp!, {r8,r9}
    .endif

   ; ** Already in IRQ mode.
   ;TEQP      PC,#0b11<<26 | 0b10  ;enter IRQ mode, IRQs/FIQs off
   ;MOV       R0,R0               ;sync
;
; this switches to SVC mode, to allow QTM_DMA fill code to run with IRQs enabled
; this might be critical for keypress tracking, but not confirmed yet...does
; the keyboard crash (more often?) if we run QTM_DMA with IRQs off???
; ...is there a need to issue a keyboard reset on exit from RM...?
;
   STMFD     R13!,{R14}          ;stack R14_IRQ at stack R13_IRQ
   TEQP      PC,#0b11<<26 | 0b11  ;enter SVC mode, IRQs/FIQs off
   MOV       R0,R0               ;sync

   STR       R13,tempr13         ;
   LDRB      R13,dma_in_progress ;
   TEQ       R13,#0              ;
   LDRNE     R13,tempr13         ;
   BNE       exitysoundcode      ;
   STRB      PC,dma_in_progress  ;

   ldr r13, temp_svc_stack_p     ;ADRL      R13,startofstack
   STMFD     R13!,{R14}          ;stack R14_SVC
   LDR       R14,tempr13         ;
   STMFD     R13!,{R14}          ;stack R13_SVC - we are now reentrant!!!
   BL        rastersound_1       ;call rastersound routine - enables IRQs

   MOV       R14,#0              ;...on return IRQs/FIQs will be off
   STRB      R14,dma_in_progress ;
   LDMFD     R13,{R13,R14}       ;restore R14_SVC and R13_SVC

exitysoundcode:
   TEQP      PC,#0b11<<26 | 0b10  ;back to IRQ mode
   MOV       R0,R0               ;sync
   LDMFD     R13!,{R14}

    ; SET_BORDER to black.

    .if _DEBUG_RASTERS
    stmfd sp!, {r8,r9}
  	ldrb r8, debug_show_rasters
	cmp r8, #0
    beq .1
    mov r8, #VIDC_Border | 0x000 ;
    mov r9, #VIDC_Write
    str r8, [r9]
    .1:
    ldmfd sp!, {r8,r9}
    .endif

done_sound:

; ============================================================================
; APP VSYNC CODE >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ============================================================================

   TEQP      PC,#IRQ_Disable|ProcMode_IRQ  ;back to IRQ mode but ENABLE FIQs
   MOV       R0,R0               ;sync

    stmfd sp!, {r0-r12,lr}

    ; Callback to app for vsync logic (inc. main loop where implemented).
    bl app_vsync_code

    ldmfd sp!, {r0-r12,lr}
   SUBS      PC,R14,#4           ;return to foreground

; ============================================================================
; QTM Integration - requires special release of QTM module.
; TODO: Ask Steve for a special release version of TinyQTM for embedding...
; ============================================================================

checkQTMspecialrelease:     ;*NOT* RO2 - SWI OS_FindMemMapEntries
   STMFD     R13!,{R0-R8,R14}
   ;SWI       "XQTM_SongStatus"
   ;MOVVS     R0,#0             ;if error (no QTM module) then treat as no song playing
   ;TST       R0,#0b0100
   ;MOVEQ     R0,#0
   ;STREQB    R0,qtmcontrol     ;no music playing ***but we want to start music after RM    init!***
   ;LDMEQFD   R13!,{R0-R8,PC}   ;v0.25...we shouldn't use QTM_SongStatus at all - we should use SoundControl to read if we're enabled!!!

   ; new v0.25...

   MVN       R0,#0
   MVN       R1,#0
   MVN       R2,#0
   SWI       XQTM_SoundControl  ;new v0.25, should work if no music playing
   MOVVS     R0,#0              ;no QTM module present, so set as if QTM not enabled
   CMP       R0,#0              ;QTM sound not enabled? (or QTM not present?)
   STREQ     R0,qtmcontrol      ;QTM not enabled
   LDMEQFD   R13!,{R0-R8,PC}

   STR       R0,qtmchannels

   MVN       R0,#0
   MVN       R1,#0
   MOV       R2,#123
   SWI       XQTM_Debug        ;return R0=(!QTMblock) QTM dma handler addr, R1=QTM's R12, R2=-1
   MOVVS     R0,#0
   STRVSB    R0,qtmcontrol     ;no QTM special release present
   LDMVSFD   R13!,{R0-R8,PC}   ;exit with error, because QTM present but not SE

   CMP       R0,#0
   CMPGE     R1,#0
   MOVLT     R0,#0
   STRLTB    R0,qtmcontrol     ;no QTM special release present
   LDMLTFD   R13!,{R0-R8,R14}
   ORRLTS    PC,R14,#1<<28     ;exit with error, because QTM present but not SE

   CMN       R2,#1
   MOVNE     R0,#0
   STRNEB    R0,qtmcontrol     ;no QTM special release present
   LDMNEFD   R13!,{R0-R8,R14}
   ORRNES    PC,R14,#1<<28     ;exit with error, because QTM present but not SE

   ; if we get here, QTM sound is on, QTM_Debug works and has provided two values >=0
   ; ...so we're most probably using QTM SE for RM

   SWI       XQTM_DMABuffer    ;read to R0
   MOV       R6,R0
   MOV       R7,#50            ;1 second max wait
dmabuffer:
   MOV       R0,#19
   SWI       XOS_Byte

   SWI       XQTM_DMABuffer
   CMP       R0,R6
   MOVNE     R5,R0
   BNE       gottwoDMAbuffers

   SUBS      R7,R7,#1
   BNE       dmabuffer

   ; if we get here, we failed to find two DMA buffers

   MOV       R0,#0
   STRB      R0,qtmcontrol
   LDMFD     R13!,{R0-R8,R14}  ;***should really return an error***
   ORRS      PC,R14,#1<<28

gottwoDMAbuffers:           ;in R5 and R6
   STR       R6,qtmdmabuffer1
   STR       R5,qtmdmabuffer2

   SWI       XQTM_Debug
   STR       R0,qtmdmahandler
   STR       R1,qtmr12pointer
   ADD       R1,R1,#QTMblock
   STR       R1,dmaentry_r9

   MOV       R0,#0
   MOV       R1,#0
   MOV       R2,#0
   MOV       R3,#0
   MOV       R4,#0
   SWI       Sound_Configure

   MUL       R0,R1,R0
   STR       R0,qtmdmasize     ;should be 416x4 or x8 " 48uS...(24uS, 4c = 832x4)

   ; For RISCOS version 3.0+ only

use_os_locate_DMA:
   SWI       OS_ReadMemMapInfo ;not Arthur
   STR       R0,pagesize
   STR       R1,numpages

   SUB       R4,R0,#1
   BIC       R7,R5,R4          ;page for dmabuffer2
   BIC       R8,R6,R4          ;page for dmabuffer1

   SUB       R5,R5,R7          ;offset into page
   SUB       R6,R6,R8          ;offset into page

   ADR       R0,pagefindblk
   MOV       R1,#0
   STR       R1,[R0,#0]
   STR       R1,[R0,#8]
   MVN       R1,#0
   STR       R1,[R0,#12]
   STR       R7,[R0,#4]
   SWI       XOS_FindMemMapEntries ;not RISC OS 2 or earlier
   LDR       R1,[R0,#0]
   LDR       R4,pagesize
   MUL       R1,R4,R1
   ADD       R1,R1,R5
   STR       R1,physicaldma2 ;got the correct phys addr of buf2 (R7)

   MOV       R1,#0
   STR       R1,[R0,#0]
   STR       R1,[R0,#8]
   MVN       R1,#0
   STR       R1,[R0,#12]
   STR       R8,[R0,#4]
   SWI       XOS_FindMemMapEntries ;not RISC OS 2 or earlier
   LDR       R1,[R0,#0]
   LDR       R4,pagesize
   MUL       R1,R4,R1
   ADD       R1,R1,R6
   STR       R1,physicaldma1 ;got the correct phys addr of buf1 (R8)
   ;                          ...on RO2/Arthur we assume fixed sound DMA addr

got_DMA_addr:
   MOV       R0,#1
   STRB      R0,qtmcontrol
   LDMFD     R13!,{R0-R8,PC}^

rastersound_1:                ;entered in SVC mode, with IRQs/FIQs disabled
   STMFD     R13!,{R0-R12,R14}   ;can enable IRQs, but must exit via MOVS PC,R14

      TEQP      PC,#0b00<<26 | 0b11  ;** IRQs/FIQs on
      MOV       R0,R0               ;** remove '**'d for 'NoIRQ'

      ; ***** note calling QTM in SVC mode will crash TSS (uses TEQP to return to IRQ mode!)
      ; ***** and play code if speed 0 (stop song)

   LDR       R9,dmaentry_r9      ;R9=ptr to initblock (QTMblock) = song_data+44+128
   LDR       R11,qtmchannels     ;R11=DMA gap
   LDR       R12,dmabank_num     ;0 after install
   RSBS      R12,R12,#1          ;1=bank1, 0=bank2
   STR       R12,dmabank_num

   LDREQ     R12,qtmdmabuffer2   ;R12=DMA start \_ use logical addrs
   LDRNE     R12,qtmdmabuffer1   ;R12=DMA start /  for QTM to fill...

   LDR       R10,qtmdmasize
   ADD       R10,R10,R12         ;R10=DMA end

   MOV       R14,PC
   LDR       PC,qtmdmahandler    ;R13=stack *R12* preserved

   LDR       R10,dmabank_num     ;1 or 0
   ADR       R12,physicaldma2    ;dma2 is immediately before dma1
   LDR       R12,[R12,R10,LSL#2] ;R12=DMA start

   LDR       R10,qtmdmasize
   ADD       R10,R10,R12         ;SendN
   SUB       R10,R10,#16         ; fixit ;-)

   MOV       R12,R12,LSR#2       ;(Sstart/16) << 2
   MOV       R10,R10,LSR#2       ;(SendN/16) << 2
   MOV          R0,#0x3600000     ;memc base
   ADD       R1,R0,#0x0080000     ;Sstart
   ADD       R2,R0,#0x00A0000     ;SendN
   ORR       R1,R1,R12           ;Sstart
   ORR       R2,R2,R10           ;SendN
   STR       R2,[R2]
   STR       R1,[R1]

   LDMFD     R13!,{R0-R12,PC}^   ;return to IRQ calling routine

; ============================================================================
; Direct keyboard checking from RasterMan code.
; We're in IRQ mode here not FIQ mode in RasterMan.
; ============================================================================

checkkeyboard:                ;only called during retrace
   ADR       R8,kbd_stack
   STMIA     R8,{R4-R7}          ;some regs to play with

   LDRB      R4,[R9,#0x24+0]     ;load irq_B triggers [R14=0x3200000, IOC base]
   TST       R4,#0b10000000       ;is it bit 7 = SRx? (cleared by a read from 04)
   LDMEQIA   R8,{R4-R7}          ;restore regs
   BEQ       exit_kbd_code          ;back to IRQ mode and exit

kbd_received:                    ;store key byte, and transmit ack value
   LDRB      R6,keycounter       ;0=no byte, so that 1-0=1->NE = first byte read
                                 ;If keycounter>1 then counting reset sequence 0x10,0x20,0x30...
   
   ; ~36 cycles since IRQ when we reach here, do we need a delay? RO waits 128 cycles to cover 16 uS...
   ;     we're getting several kbd crashes on ARM3, so maybe we do need to wait a bit...

   MOV       R5,#128-36          ;v0.29
kbd_RO_delay:
   SUBS      R5,R5,#5
   BGT       kbd_RO_delay

   LDRB      R5,[R9,#0x04+0]     ;load byte (clears SRx in IRQB)
   CMP       R5,#HRST            ;is it keyboard reset?
   BEQ       startkbdreset       ;...if so we've hit a protocol problem!
   CMP       R6,#1               ;if keycounter>1 then we're mid way through a reset
   BGT       midkbdreset         ;

   RSBS      R6,R6,#1            ;if =1 (NE), then this is the first byte, else (EQ)=second byte
   STRB      R6,keycounter

   STRNEB    R5,keybyte1
   STRNEB    R14,keybyte2        ;clear byte 2!!! (was key-bug until v0.20)
   MOVNE     R6,#bACK            ;if first byte, reply with bACK
   STREQB    R5,keybyte2
   MOVEQ     R6,#sMAK            ;if second byte, reply with sACK, **updated to SMAK 3/1/22**
                                 ; sACK=0b00110001 keyboard scan only
                                 ; sMAK=0b00110011 keyboard and non-zero mouse

   STRB      R6,[R9,#0x04+2]     ;transmit response
   LDMNEIA   R8,{R4-R7}          ;if not second byte, restore regs
   BNE       exit_kbd_code          ;...and back to IRQ mode and exit

;   TST       R5,#0b10000000       ;test bit 7 of 2nd byte
;   BEQ       gotmousemoved       ;...if bit 7 clear, it's MDAT!

   MOV       R5,R5,LSR#4         ;shift to top nibble of R5
   ; ** Added these two lines back in to get key up events!
   TEQ       R5,#0b1101           ;0xD=KUDA is 2nd byte the "new key up" code?
   BEQ       gotnewkeyreleased
   TEQ       R5,#0b1100           ;0xC=KDDA is 2nd byte the "new key down" code?
   LDMNEIA   R8,{R4-R7}          ;if not, restore regs
   BNE       exit_kbd_code          ;...and back to IRQ mode and exit

   ; get here if key-pressed and both bytes received

gotnewkeypressed:
   LDMIA     R8,{R4-R7}          ;restore regs
.if _DEBUG
    stmfd sp!, {r1-r2,lr}
   LDRB      R1,keybyte1         ;high nibble
   AND       R1,R1,#0xF
   LDRB      R2,keybyte2         ;low nibble
   AND       R2,R2,#0xF
   ORR       R2,R2,R1,LSL#4
    mov r1, #1                  ; key down
    bl debug_handle_keypress
    ldmfd sp!, {r1-r2,lr}
.endif
   B         exit_kbd_code          ;back to IRQ mode and exit

; TODO: Consolidate this code, decide on non_DEBUG keys inc. Escape!

gotnewkeyreleased:
   LDMIA     R8,{R4-R7}          ;restore regs
.if _DEBUG
    stmfd sp!, {r1-r2,lr}
   LDRB      R1,keybyte1         ;high nibble
   AND       R1,R1,#0xF
   LDRB      R2,keybyte2         ;low nibble
   AND       R2,R2,#0xF
   ORR       R2,R2,R1,LSL#4
    mov r1, #0                  ; key down
    bl debug_handle_keypress
    ldmfd sp!, {r1-r2,lr}
.endif
   B         exit_kbd_code          ;back to IRQ mode and exit

; keyboard protocol reset code added v0.25...
; ...but doesn't seem to stop the occasional keyboard freeze

startkbdreset:                ;we've just read 0xFF in R5, from SRx, keycounter in R6
   ;
   ; Just received unexpected HRST 0xFF from kbd, we should respond with KbAck1
   ; set keycounter to 0x10 (expecting HRST) and continue...

   MOV       R6,#0x10

midkbdreset:
   ; if keycounter=0x10 we're expecting HRST from keyboard
   ;    if R5=HRST, respond KbAck1 and set keycounter=0x20 else send HRST
   ; if keycounter=0x20 we're expecting KbAck1 from keyboard
   ;    if R5=KbAck1, respond KbAck2 and set keycounter=0x30 else send HRST and set keycounter=0x10
   ; if keycounter=0x30 we're expecting KbAck2 from keyboard to complete reset
   ;    if R5=KbAck2, respond sMAK and set keycounter=0 else send HRST and set keycounter=0x10

   CMP       R6,#0x10
   CMPEQ     R5,#HRST
   MOVEQ     R6,#0x20
   MOVEQ     R5,#KbAck1
   BEQ       exitkbdreset

   CMP       R6,#0x20
   CMPEQ     R5,#KbAck1
   MOVEQ     R6,#0x30
   MOVEQ     R5,#KbAck2
   BEQ       exitkbdreset

   CMP       R6,#0x30
   CMPEQ     R5,#KbAck2
   MOVEQ     R6,#0
   MOVEQ     R5,#sMAK

   ; reset sequence failed, so send HRST back

   MOVNE     R6,#0x10
   MOVNE     R5,#HRST
exitkbdreset:
   STRB      R6,keycounter
   STRB      R5,[R9,#0x04+2]     ;transmit response
   LDMIA     R8,{R4-R7}          ;if not second byte, restore regs
;   B         exit_kbd_code          ;...and back to IRQ mode and exit
    ; FALL THROUGH!
exit_kbd_code:
   LDMFD     R13!,{r8,r9}
   TEQP      PC,#0b000011<<26 | 0b10 ;36 A4 back to IRQ mode
   MOV       R0,R0                  ;37 A8 sync IRQ registers
   SUBS      PC,R14,#4              ;38 AC return to foreground
