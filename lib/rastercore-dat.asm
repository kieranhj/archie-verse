; ============================================================================
; RasterMan keyboard table.
; ============================================================================

.equ keycode_unknown, 0

rastercore_keytable_no_adr:
   .byte 27      ; "Esc" ;0x00
   .byte keycode_unknown ; "f1"
   .byte keycode_unknown ; "f2"
   .byte keycode_unknown ; "f3"
   .byte keycode_unknown ; "f4"
   .byte keycode_unknown ; "f5"
   .byte keycode_unknown ; "f6"
   .byte keycode_unknown ; "f7"
   .byte keycode_unknown ; "f8"
   .byte keycode_unknown ; "f9"
   .byte keycode_unknown ; "f10"
   .byte keycode_unknown ; "f11"
   .byte keycode_unknown ; "f12"
   .byte keycode_unknown ; "Prt"
   .byte keycode_unknown ; "Scl"
   .byte 27      ; "Brk" ;0x0f

   .byte "`1234567890-="               ; 0x10
   .byte keycode_unknown ;"FALSE"
   .byte 8       ; "Bks"
   .byte keycode_unknown ; "Ins"   ; 0x1f

   .byte 30      ; "Hom"   ; 0x20
   .byte keycode_unknown ; "pUp"
   .byte keycode_unknown ; "Num"
   .byte "/*#"  ; "Kp/"
   .byte 9     ; "Tab"
   .byte "QWERTYUI"         ; 0x2f

   .byte "OP[]\\"            ; 0x30
   .byte 127     ; "Del"
   .byte keycode_unknown ; "Cpy"
   .byte keycode_unknown ; "pDn"
   .byte "789-"  ; "Kp7"
   .byte keycode_unknown ; "LCt"
   .byte "ASD"              ; 0x3f
   .byte "FGHJKL;'"          ; 0x40
   .byte 13     ; "Ret"
   .byte "456+"  ; "Kp4"
   .byte keycode_unknown ; "LSh"
   .byte "ZX"               ; 0x4f
   .byte "CVBNM,./"         ; 0x50
   .byte keycode_unknown ; "RSh"
   .byte keycode_unknown ; "cUp"
   .byte "123"  ; "Kp1"
   .byte keycode_unknown ; "Cps"
   .byte keycode_unknown ; "LAl"
   .byte ASCII_Space  ; "Spc"      ; 0x5f

   .byte keycode_unknown ; "RAl"   ; 0x60
   .byte keycode_unknown ; "RCt"
   .byte keycode_unknown ; "cLf"
   .byte keycode_unknown ; "cDn"
   .byte keycode_unknown ; "cRt"
   .byte "0."  ; "Kp0"
   .byte 10     ; "Ent"    ; 0x67

   .skip 8

   .byte keycode_unknown ; "mLf"   ; 0x70
   .byte keycode_unknown ; "mMd"
   .byte keycode_unknown ; "mRt"

   .skip 256-0x73
.p2align 2
