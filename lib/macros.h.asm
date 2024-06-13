; ============================================================================
; Macros.
; ============================================================================

; NOTE: This macro only works if rDst==rBase!!!
; TODO: Proper MLA_BY_CONST rDst, rBase, const
.macro CALC_SCANLINE_ADDR rDst, rBase, rY
.set val, Screen_Stride
.if val&256
    add \rDst, \rBase, \rY, lsl #8
    .set val, val&~256
.endif
.if val&128
    add \rDst, \rBase, \rY, lsl #7
    .set val, val&~128
.endif
.if val&64
    add \rDst, \rBase, \rY, lsl #6
    .set val, val&~64
.endif
.if val&32
    add \rDst, \rBase, \rY, lsl #5
    .set val, val&~32
.endif
.if val&16
    add \rDst, \rBase, \rY, lsl #4
    .set val, val&~16
.endif
.if val&8
    add \rDst, \rBase, \rY, lsl #3
    .set val, val&~8
.endif
.if val&4
    add \rDst, \rBase, \rY, lsl #2
    .set val, val&~4
.endif
.if val&2
    add \rDst, \rBase, \rY, lsl #1
    .set val, val&~2
.endif
.if val&1
    add \rDst, \rBase, \rY
    .set val, val&~1
.endif
.endm

.macro RND seed, bit, temp
    TST    \bit, \bit, LSR #1                       ; top bit into Carry
    MOVS   \temp, \seed, RRX                        ; 33 bit rotate right
    ADC    \bit, \bit, \bit                         ; carry into lsb of R1
    EOR    \temp, \temp, \seed, LSL #12             ; (involved!)
    EOR    \seed, \temp, \temp, LSR #20             ; (similarly involved!)
.endm

.macro SET_BORDER rgb
	.if _DEBUG_RASTERS
	mov r4, #\rgb
	ldrb r0, debug_show_rasters
	cmp r0, #0
	blne palette_set_border
	.endif
.endm

; TODO: Make this table based if code gets unwieldy.
.macro SYNC_REGISTER_VAR track, addr
    .if AppConfig_UseSyncTracks
    mov r0, #\track
    adr r1, \addr
    bl sync_register_track_var
    .endif
.endm

.macro SPRITE_UTILS_GET_TABLE def_reg, num_reg, ptr_reg
    add \ptr_reg, \def_reg, #SpriteSheetDef_PtrTable
    add \ptr_reg, \ptr_reg, \num_reg, lsl #5    ; 8 sprites * 4 bytes per ptr.
.endm

.macro SPRITE_UTILS_GETPTR def_reg, num_reg, shift_reg, ptr_reg
    SPRITE_UTILS_GET_TABLE \def_reg, \num_reg, \ptr_reg
    ldr \ptr_reg, [\ptr_reg, \shift_reg, lsl #2]          ; ptr[x_shift]
.endm

.macro SpriteSheetDef_Mode9 num_sprites, width_words, height_rows, sprite_data
    .byte \num_sprites
    .byte \width_words
    .byte \height_rows
    .byte 0                     ; flags tbd
    .long \sprite_data
    .skip \num_sprites*8*4      ; sprite ptrs.
.endm

.macro TextDef font, point, height, colour, string, addr
    .long outline_font_def_\font, \point*16, \height*16, \colour
    .byte "\string", 0
    .p2align 2
    .long \addr
.endm
