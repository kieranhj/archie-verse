; ============================================================================
; Dot Tunnel.
; Used in: Three-Dee Demo (Mikroreise)
; ============================================================================

.equ DotTunnel_Total, 512      ; ?
.equ DotTunnel_CentreX, 160
.equ DotTunnel_CentreY, 128

dot_tunnel_t:
    .long 0

dot_tunnel_speed:
    .long 1

;    -- offset to add movement to the tunnel
;    oa=(i+t*2)/50
;    ox=(math.sin(oa)*z*amp)
;    oy=(math.cos(oa/2)*z*amp)
dot_tunnel_offset_xy:
    .long dot_tunnel_offset_xy_no_adr

;    angle=i+t*3.01 -- decimal gives some rotation
;    x=math.sin(angle)*r
;    y=math.cos(angle)*r

dot_tunnel_xy:
    .long dot_tunnel_xy_no_adr

; plot dot tunnel.
; for each dot
; calculate z position (stepping into screen)
; calculate tunnel path centre (x,y) for z
; calculate dot (x,y) position on tunnel at z with radius
; calculate camera relative pos (tpx+dx, tpy+dy, z)
; apply perspective and plot to screen.

dot_tunnel_update:
    ldr r11, dot_tunnel_t
    ldr r0, dot_tunnel_speed
    add r11, r11, r0
    cmp r11, #DotTunnel_Total
    subge r11, r11, #DotTunnel_Total
    str r11, dot_tunnel_t
    mov pc, lr

; R12=screen addr
dot_tunnel_draw_anaglyph_spiral:
    str lr, [sp, #-4]!

    ; Left eye.
    ldr r0, LeftEye_X_Pos

    ; Subtract blue & green.
    mov r4, #7                  ; brightest red
    bl dot_tunnel_draw_spiral

    ; Right eye.
    ldr r0, RightEye_X_Pos

    ; Subtract red.
    mov r4, #11                 ; brightest cyan
    bl dot_tunnel_draw_spiral

    ldr pc, [sp], #4

tunnel_skew_offset:
    .long 0

dot_tunnel_patch_to_straight:
    adr r0, dot_tunnel_patch_straight
dot_tunnel_do_patch:
    ldmia r0!, {r1-r4}
    str r1, dot_tunnel_draw_spiral_patch_1+0
    str r2, dot_tunnel_draw_spiral_patch_1+4
    str r3, dot_tunnel_draw_spiral_patch_2+0
    str r4, dot_tunnel_draw_spiral_patch_2+4
    mov pc, lr

dot_tunnel_patch_straight:
    mov r5, #0
    mov r6, #0
    mov r3, r3
    mov r4, r4

dot_tunnel_patch_to_curved:
    adr r0, dot_tunnel_patch_curved
    b dot_tunnel_do_patch

dot_tunnel_patch_curved:
    mov r5, r5
    mov r6, r6
    add r3, r0, r3                  ; x+ox
    add r4, r1, r4                  ; y+oy


; R0=eye offset.
; R4=colour index.
; R12=screen addr
dot_tunnel_draw_spiral:
    str lr, [sp, #-4]!

    mov r10, r4                     ; colour
    ldr r11, dot_tunnel_t           ; t

    ldr r9, dot_tunnel_xy
    add r9, r9, r11, lsl #3
    ldr r7, dot_tunnel_offset_xy
    add r7, r7, r11, lsl #3

    adr r14, dot_tunnel_recip_z

    ldmia r7, {r5,r6}               ; cx=ox[t]
                                    ; cy=oy[t]

dot_tunnel_draw_spiral_patch_1:
    mov r5, r5
    mov r6, r6

    add r5, r5, r0                  ; eye offset.
    mov r5, r5, asl #1              ; *2
    str r0, tunnel_skew_offset      ; TODO: Not needed if camera is forced to (0,0)

    ldr r11, dot_tunnel_xy
    mov r8, #0
dot_tunnel_draw_spiral_loop:
    ldr r2, [r14], #4               ; 80/z [7.16]

    ldmia r9!, {r3,r4}              ; x[i+t] [s8.16]
                                    ; y[i+t] [s8.16]

    ldmia r7!, {r0,r1}              ; ox[i+t]
                                    ; oy[i+t]

dot_tunnel_draw_spiral_patch_2:
    add r3, r0, r3                  ; x+ox
    add r4, r1, r4                  ; y+oy

    sub r3, r3, r5                  ; x+ox-cx
    sub r4, r4, r6                  ; y+oy-cy

    mov r2, r2, asr #8              ; [7.8]
    mov r3, r3, asr #8              ; [s8.8]
    mov r4, r4, asr #8              ; [s8.8]
    mul r0, r3, r2                  ; x/z   [s15.16]
    mul r1, r4, r2                  ; y/z   [s15.16]

    ldrb r3, Anaglyph_Enable_Skew
    cmp r3, #0
    ldrne r5, tunnel_skew_offset
    addne r0, r0, r5

    mov r0, r0, asr #16             ; [s15.0]
    mov r1, r1, asr #16             ; [s15.0]

    add r0, r0, #DotTunnel_CentreX
    add r1, r1, #DotTunnel_CentreY

    ; Clip.
    cmp r0, #0
    blt .2
    cmp r0, #Screen_Width
    bge .2
    cmp r1, #0
    blt .2
    cmp r1, #Screen_Height-1
    bge .2

    .if Screen_Mode==13
    add r3, r12, r1, lsl #8
    add r3, r3, r1, lsl #6

    ;mov r2, #0xff
    strb r2, [r3, r0]!
    ;strb r2, [r3, #1]
    ;strb r2, [r3, #Screen_Stride]!
    .else
    ; Assume MODE 9!
    add r3, r12, r1, lsl #7
    add r3, r3, r1, lsl #5
	add r3, r3, r0, lsr #1	; r10 += startx DIV 2

    ;.3:
    ;mov r4, #0xf                ; SELF-MOD!

	ldrb r2, [r3]				; load screen byte
	tst r0, #1					; odd or even pixel?
	orreq r2, r2, r10			; mask in colour as left hand pixel
	orrne r2, r2, r10, lsl #4	; mask in colour as right hand pixel
	strb r2, [r3]				; store screen byte
    .endif

.2:
    cmp r7, r11
    movge r9, r11
    ldrge r7, dot_tunnel_offset_xy

    add r8, r8, #1
    cmp r8, #DotTunnel_Total/4
    subge r10, r10, #1
    movge r8, #0

    adr r0, dot_tunnel_recip_z_end
    cmp r14, r0
    blt dot_tunnel_draw_spiral_loop

    ldr pc, [sp], #4


.if 0
.equ Dot_Circle_Gap, 32
.equ Dot_Circle_Max_Z, 1024

.macro DOT_CIRCLE_PLOT_1 op_x, reg_x, op_y, reg_y, clip_label

    ; Screen position.
    ; Clip.
    
    ; TODO: Somehow include r7(ox), r8(oy) here!

    \op_x r5, \reg_x, #160
    blt \clip_label
    cmp r5, #Screen_Width
    bge \clip_label

    \op_y r6, \reg_y, #128
    blt \clip_label
    cmp r6, #Screen_Height-1
    bge \clip_label

    add r3, r12, r6, lsl #8
    add r3, r3, r6, lsl #6
    strb r4, [r3, r5]

    \clip_label:
.endm

.macro DOT_CIRCLE_GET_XY angle
    .if 0
    ldr r3, [r9, #\angle]                ; r*cos(a0) [s8.16]
    ldr r4, [r10, #\angle]               ; r*sin(a0) [s8.16]

    mov r3, r3, asr #8              ; [s8.8]
    mov r4, r4, asr #8              ; [s8.8]

    mul r0, r3, r2                  ; x/z   [s15.16]
    mul r1, r4, r2                  ; y/z   [s15.16]

    mov r0, r0, asr #16             ; [s15.0]
    mov r1, r1, asr #16             ; [s15.0]
    .else
    ldr r3, [r9, #\angle]           ; x:y packed
    mov r4, r3, lsr #16             ; y unpacked
    mov r3, r3, lsl #16
    mov r3, r3, lsr #16             ; x unpacked

    mul r0, r3, r2                  ; x/z   [s15.16]
    mul r1, r4, r2                  ; y/z   [s15.16]

    mov r0, r0, asr #16             ; [s15.0]
    mov r1, r1, asr #16             ; [s15.0]
    .endif
.endm

.macro DOT_CIRCLE_PLOT_4a angle
    DOT_CIRCLE_GET_XY \angle

    mov r4, #0xff

    DOT_CIRCLE_PLOT_1 adds, r0, adds, r1, clip_1_\angle
    DOT_CIRCLE_PLOT_1 adds, r1, adds, r0, clip_2_\angle
    DOT_CIRCLE_PLOT_1 rsbs, r0, rsbs, r1, clip_7_\angle
    DOT_CIRCLE_PLOT_1 rsbs, r1, rsbs, r0, clip_8_\angle
.endm

.macro DOT_CIRCLE_PLOT_4b angle
    DOT_CIRCLE_GET_XY \angle

    mov r4, #0xff

    DOT_CIRCLE_PLOT_1 adds, r0, adds, r1, clip_1_\angle
    DOT_CIRCLE_PLOT_1 rsbs, r0, adds, r1, clip_3_\angle
    DOT_CIRCLE_PLOT_1 adds, r0, rsbs, r1, clip_5_\angle
    DOT_CIRCLE_PLOT_1 rsbs, r0, rsbs, r1, clip_7_\angle
.endm

.macro DOT_CIRCLE_PLOT_8 angle
    DOT_CIRCLE_GET_XY \angle

    mov r4, #0xff

    DOT_CIRCLE_PLOT_1 adds, r0, adds, r1, clip_1_\angle
    DOT_CIRCLE_PLOT_1 adds, r1, adds, r0, clip_2_\angle
    DOT_CIRCLE_PLOT_1 rsbs, r0, adds, r1, clip_3_\angle
    DOT_CIRCLE_PLOT_1 rsbs, r1, adds, r0, clip_4_\angle
    DOT_CIRCLE_PLOT_1 adds, r0, rsbs, r1, clip_5_\angle
    DOT_CIRCLE_PLOT_1 adds, r1, rsbs, r0, clip_6_\angle
    DOT_CIRCLE_PLOT_1 rsbs, r0, rsbs, r1, clip_7_\angle
    DOT_CIRCLE_PLOT_1 rsbs, r1, rsbs, r0, clip_8_\angle
.endm

; Circles every Z units.
; R12=screen addr
dot_tunnel_draw_circles:
    str lr, [sp, #-4]!

    ; z = circle_gap - (camera_z % circle_gap)
    ldr r11, dot_tunnel_t
    and r11, r11, #Dot_Circle_Gap-1
    rsb r11, r11, #Dot_Circle_Gap

    adr r9, dot_tunnel_x_octant     ; actually packed x:y
    adr r10, dot_tunnel_y_octant    ; actually packed ox:oy

    adr r14, dot_tunnel_recip_z

    ; for i=1,circles do
dot_tunnel_draw_circles_loop:
    ; TODO: get (ox,oy) for z

    ldr r7, [r10], #4      ; packed ox:oy [z]
    mov r8, r7, asr #16
    mov r7, r7, lsl #16
    mov r7, r7, asr #16

    ldr r2, [r14, r11, lsl #2]      ; 80/z [7.16]
    mov r2, r2, asr #8              ; [7.8]

    ; for j=1,points do
    ; a=j * PI / (4 * points)
    ; x=math.cos(a)*r
    ; y=math.sin(a)*r

    DOT_CIRCLE_PLOT_4a 0
    DOT_CIRCLE_PLOT_8 4
    DOT_CIRCLE_PLOT_8 8
    DOT_CIRCLE_PLOT_8 12
    DOT_CIRCLE_PLOT_8 16
    DOT_CIRCLE_PLOT_8 20
    DOT_CIRCLE_PLOT_8 24
    DOT_CIRCLE_PLOT_4b 28

    ; plot (ox+x)/z, (oy+y)/z
    ; and 7x combos.

    ; 7x8=56 points x 

    ; z += circle_gap
    add r11, r11, #Dot_Circle_Gap
    cmp r11, #Dot_Circle_Max_Z
    blt dot_tunnel_draw_circles_loop

    ; end

    ldr r11, dot_tunnel_t
    add r11, r11, #1
    cmp r11, #DotTunnel_Total
    movge r11, #0
    str r11, dot_tunnel_t

    ldr pc, [sp], #4
.endif

dot_tunnel_recip_z:
.set z, 64.0                ; distance to start of tunnel.
.rept DotTunnel_Total
    FLOAT_TO_FP (160.0/z)    ; scale to screen.
    .set z, z+2
.endr
dot_tunnel_recip_z_end:

.if 0
dot_tunnel_x_octant:
    .incbin "data/dot_tunnel_x_octant.bin"

dot_tunnel_y_octant:
    .incbin "data/dot_tunnel_y_octant.bin"
.endif
