; ============================================================================
; Math vars
; Evaluate arbitrary linear functions of the form: v = a + b * f(c + d * i)
; And poke these values into a variable at a given address.
; This happens on a per-tick basis and can be used to drive demo objects etc.
; NB. Variables are ticked in the order they are added.
; ============================================================================

.equ MathVars_MAX,      16

.equ MathVar_Next,      0
.equ MathVar_Iter,      4
.equ MathVar_Addr,      8
.equ MathVar_ParamA,    12
.equ MathVar_ParamB,    16
.equ MathVar_ParamC,    20
.equ MathVar_ParamD,    24
.equ MathVar_FuncPtr,   28
.equ MathVar_EvalFn,    32
.equ MathVar_SIZE,      36

.equ _MATH_VAR_REPLACE, 1   ; Don't barf if a variable is redefined, just replace it.

; ============================================================================

math_var_base_p:
    .long math_var_buffer_no_adr

math_var_end_p:
    .long math_var_buffer_end_no_adr

math_var_first_active_p:
    .long 0

math_var_first_free_p:
    .long 0

.if _DEBUG
math_var_active_count:
    .long 0
.endif

; ============================================================================

math_var_init:
    str lr, [sp, #-4]!

    adr r10, math_var_first_free_p  ; this
    ldr r11, math_var_base_p        ; next_p
    ldr r12, math_var_end_p

.1:
    str r11, [r10, #MathVar_Next]   ; this->next=next_p
    mov r10, r11                    ; this=next_p
    add r11, r11, #MathVar_SIZE     ; next_p++
    cmp r11, r12                    ; next_p==end?
    blt .1

    mov r11, #0
    str r11, [r10, #MathVar_Next]   ; this->next=next_p
    str r11, math_var_first_active_p
    .if _DEBUG
    str r11, math_var_active_count
    .endif
    ldr pc, [sp], #4

; R0=address of variable
; R1=param a
; R2=param b
; R3=param c
; R4=param d
; R5=math_func ptr
math_var_register:
    adreq r6, math_evaluate_func
; Fall through!

; R6=eval_func ptr
math_var_register_ex:
    ; Find end of list.
    adr r12, math_var_first_active_p    ; prev_p
.1:
    ldr r11, [r12, #MathVar_Next]       ; curr_p=prev_p->next
    cmp r11, #0                         ; curr_p=0?
    beq .2

    ; Found matching var?
    ldr r7, [r11, #MathVar_Addr]        ; curr_p->addr
    cmp r7, r0
    beq .2

    mov r12, r11                        ; prev_p=curr_p
    b .1

    ; Insert variable at the end.
.2:
    mov r7, #0

    ; If r11=0 then we reached the end of the list and need a new var.
    cmp r11, #0
    bne .3

    ldr r11, math_var_first_free_p      ; curr_p = first_free_p

    .if _DEBUG
    cmp r11, #0
    adreq r0, error_outofmathvars
    swieq OS_GenerateError
    .endif

    ldr r10, [r11, #MathVar_Next]       ; first_free_p->next
    str r10, math_var_first_free_p      ; first_free_p = first_free_p->next

    str r11, [r12, #MathVar_Next]       ; prev_p->next=this
    str r7, [r11]                       ; curr_p->next=0

    .if _DEBUG
    ldr r12, math_var_active_count
    add r12, r12, #1
    str r12, math_var_active_count
    .endif
.3:
    add r11, r11, #MathVar_Iter         ; reset iter!
    str r7, [r11], #4                   ; curr_p->iter=0
    stmia r11!, {r0-r6}                 ; store all params
    mov pc, lr

.if _DEBUG
error_dupmathvar:
	.long 0
	.byte "Math var already registered!"
	.p2align 2
	.long 0

error_outofmathvars:
	.long 0
	.byte "Out of math vars!"
	.p2align 2
	.long 0
.endif

; R0=address of variable.
math_var_unregister:
    adr r12, math_var_first_active_p    ; prev_p
.1:
    ldr r11, [r12, #MathVar_Next]       ; curr_p=prev_p->next
    cmp r11, #0                         ; end of list?
    beq .3

    ; Found matching var?
    ldr r1, [r11, #MathVar_Addr]        ; curr_p->addr
    cmp r1, r0                          ; curr_p->addr==addr?
    beq .2

    mov r12, r11                        ; prev_p=curr_p
    b .1

.2:
    ; Remove var from active list.
    ldr r10, [r11, #MathVar_Next]
    str r10, [r12, #MathVar_Next]       ; prev_p->next=curr_p->next

    ; Add var to free list.
    ldr r10, math_var_first_free_p
    str r10, [r11, #MathVar_Next]       ; curr_p->next=first_free_p
    str r11, math_var_first_free_p      ; first_free_p=curr_p

    .if _DEBUG
    ldr r12, math_var_active_count
    sub r12, r12, #1
    str r12, math_var_active_count
    .endif

.3:
    mov pc, lr

math_var_iter_add:
    .long 0

; Tick all variables.
math_var_tick:
    str lr, [sp, #-4]!
    str r0, math_var_iter_add

    ; For each var in list.
    adr r12, math_var_first_active_p    ; prev_p
.1:
    ldr r11, [r12, #MathVar_Next]       ; curr_p=prev_p->next
    cmp r11, #0                         ; end of list?
    beq .2

    ; Increment iteration value.
    ldr r10, [r11, #MathVar_Iter]
    ldr r0, math_var_iter_add
    add r10, r10, r0
    ;add r10, r10, #1                    ; TODO: Use delta value? <== YES!
    str r10, [r11, #MathVar_Iter]

    ; Evaluate the function.
    mov r0, r10
    add r10, r11, #MathVar_ParamA

    adr lr, .3
    ldr pc, [r11, #MathVar_EvalFn]      ; bl math_evaluate_func
    .3:
    
    ; Store returned value to address.
    ldr r1, [r11, #MathVar_Addr]
    str r0, [r1]

    ; Next var.
    mov r12, r11
    b .1
.2:    

    ldr pc, [sp], #4

; ============================================================================

; Evaluate the linear function v = a + b * f(c + d * i)
; Where a, b, c, d are fixed-point values. [s15.16]
; Where i is an integer iterator value that is incremented externally (usually per call).
; Params:
;  R10=ptr to func parameters [a, b, c, d, f]
;  R0=i [16.0]
; Trashes: R1-R5, R9
; Returns: R0=v
math_evaluate_func:
    str lr, [sp, #-4]!
    ldmia r10!, {r1-r5}     ; [a, b, c, d, f]

    mla r0, r4, r0, r3      ; c + d * i [16.16]

    cmp r5, #0
    beq .1
    adr lr, .1
    mov pc, r5              ; f(c + d * i)
.1:
    mov r0, r0, asr #8
    mov r2, r2, asr #8
    mla r0, r2, r0, r1      ; a + b * f(c + d * i)  [16.16]
    ldr pc, [sp], #4

; Evaluate the linear function v = a + (*b) * f(c + d * i)
; Where a, c, d are fixed-point values. [s15.16]
; Where b is the address containing a fixed-point value in [s15.16]
; Where i is an integer iterator value that is incremented externally (usually per call).
; Params:
;  R10=ptr to func parameters [a, b, c, d, f]
;  R0=i [16.0]
; Trashes: R1-R5, R9
; Returns: R0=v
math_evaluate_func2:
    str lr, [sp, #-4]!
    ldmia r10!, {r1-r5}     ; [a, b, c, d, f]

    mla r0, r4, r0, r3      ; c + d * i [16.16]

    cmp r5, #0
    beq .1
    adr lr, .1
    mov pc, r5              ; f(c + d * i)
.1:
    ldr r2, [r2]            ; b = RAM[b]
    mov r0, r0, asr #8
    mov r2, r2, asr #8
    mla r0, r2, r0, r1      ; a + b * f(c + d * i)  [16.16]
    ldr pc, [sp], #4

; Evaluate the linear function v = (*a) + b * f(c + d * i)
; Where b, c, d are fixed-point values. [s15.16]
; Where a is the address containing a fixed-point value in [s15.16]
; Where i is an integer iterator value that is incremented externally (usually per call).
; Params:
;  R10=ptr to func parameters [a, b, c, d, f]
;  R0=i [16.0]
; Trashes: R1-R5, R9
; Returns: R0=v
math_evaluate_func3:
    str lr, [sp, #-4]!
    ldmia r10!, {r1-r5}     ; [a, b, c, d, f]

    ldr r1, [r1]            ; a = RAM[a]
    mla r0, r4, r0, r3      ; c + d * i [16.16]

    cmp r5, #0
    beq .1
    adr lr, .1
    mov pc, r5              ; f(c + d * i)
.1:
    mov r0, r0, asr #8
    mov r2, r2, asr #8
    mla r0, r2, r0, r1      ; a + b * f(c + d * i)  [16.16]
    ldr pc, [sp], #4

; Evaluate the RGB lerp function v = RGB[a] + RAM[c] * (RGB[b] - RGB[a])
; Where a, b are addresses assumed to contain RGB values in the format 0x00BbGgRr.
; Where c is an address assumed to contain a blend value in fixed-point format [1.16]
; Where i is an integer iterator value that is incremented externally (usually per call).
; Params:
;  R10=ptr to func parameters [a, b, c, d, f]
;  R0=i [16.0]
; Trashes: R1-R9
; Returns: R0=v
; TODO: Replace with RGB blend in one mul: https://gist.github.com/mattiasgustavsson/c11e824e3d603d0c86e5e0dde4ecf839
;    // color1 and color2 are R4G4B4 12bit RGB color values, alpha is 0-255
;    uint16_t blend_12bit( uint16_t color1, uint16_t color2, uint8_t alpha ) {
;        uint64_t c1 = (uint64_t) color1;
;        uint64_t c2 = (uint64_t) color2;
;        uint64_t a = (uint64_t)( alpha >> 4 );
;        // bit magic to alpha blend R G B with single mul
;        c1 = ( c1 | ( c1 << 12 ) ) & 0x0f0f0f;
;        c2 = ( c2 | ( c2 << 12 ) ) & 0x0f0f0f;
;        uint32_t o = ( ( ( ( c2 - c1 ) * a ) >> 4 ) + c1 ) & 0x0f0f0f;
;        return (uint16_t) ( o | ( o >> 12 ) );
;    }
.if 0
math_evaluate_rgb_lerp:
    ldmia r10!, {r1-r3}     ; [a, b, c]

    ldr r3, [r3]            ; blend = RAM[c] [1.16]

    ; TODO: Clamp to [0,1] here?

    .err "TODO: Unpack RGB value as VIDC register format, not OS_Word!"

    ; col_a = 0x00BbGgRr
    and r4, r1, #0xff       ; col_a.r   [8.0]
    mov r5, r1, lsr #8
    and r5, r5, #0xff       ; col_a.g   [8.0]
    mov r6, r1, lsr #16     ; col_a.b   [8.0]

    ; col_b = 0x00BbGgRr
    and r7, r2, #0xff       ; col_b.r   [8.0]
    mov r8, r2, lsr #8
    and r8, r8, #0xff       ; col_b.g   [8.0]
    mov r9, r2, lsr #16     ; col_b.b   [8.0]

    ; col_b - col_a
    sub r7, r7, r4
    sub r8, r8, r5
    sub r9, r9, r6

    ; lerp
    mul r7, r3, r7      ; col_a.r + blend * (col_b.r - col_a.r)     [8.16]
    mul r8, r3, r8      ; col_a.g + blend * (col_b.g - col_a.g)     [8.16]
    mul r9, r3, r9      ; col_a.b + blend * (col_b.b - col_a.b)     [8.16]

    ; precision.
    add r4, r4, r7, asr #16
    and r4, r4, #0xff
    add r5, r5, r8, asr #16
    and r5, r5, #0xff
    add r6, r6, r9, asr #16
    and r6, r6, #0xff

    ; combine.
    orr r0, r4, r5, lsl #8
    orr r0, r0, r6, lsl #16
    
    mov pc, lr
.endif

; ============================================================================

; Super hack balls!
; Abuse the math_var functionality to lerp an entire table of RGB values.
; RGB[d] = RGB[a] + blend[c] * (RGB[b] - RGB[a])
; Where a, b, d are base addresses assumed to contain an array of 16 RGB values in the format 0x00BbGgRr.
; Where c is an address assumed to contain a blend value in fixed-point format [1.16]
; Params:
;  R10=ptr to func parameters [a, b, c, d, f]
;  R0=i [16.0]
; Trashes: R1-R9
; Returns: R0=v
math_evaluate_palette_lerp:
    ldr r3, [r10, #8]
    ldr r3, [r3]                ; blend = RAM[c] [1.16]
    ; TODO: Clamp to [0,1] here?

    ; TODO: Make the palette lerping configurable (lerp mask?)
    ; NOTE: For ArchieKlang intro we ignore colours 0 and 1.
    mov r0, #1                  ; NB. Start of palette range to lerp!
.1:
    ldmia r10, {r1-r2}          ; palette_A, palette_B

    ldr r1, [r1, r0, lsl #2]    ; col_a = palette_A[i]
    ldr r2, [r2, r0, lsl #2]    ; col_b = palette_B[i]

    ; col_a = 0x0BGR
    and r4, r1, #0x00f
    mov r4, r4, lsl #4      ; col_a.r   [8.0]
    and r5, r1, #0x0f0      ; col_a.g   [8.0]
    and r6, r1, #0xf00
    mov r6, r6, lsr #4      ; col_a.b   [8.0]

    ; col_b = 0x0BGR
    and r7, r2, #0x00f
    mov r7, r7, lsl #4      ; col_b.r   [8.0]
    and r8, r2, #0x0f0      ; col_b.g   [8.0]
    and r9, r2, #0xf00
    mov r9, r9, lsr #4      ; col_b.b   [8.0]

    ; col_b - col_a
    sub r7, r7, r4
    sub r8, r8, r5
    sub r9, r9, r6

    ; lerp
    mul r7, r3, r7      ; blend * (col_b.r - col_a.r)     [8.16]
    mul r8, r3, r8      ; blend * (col_b.g - col_a.g)     [8.16]
    mul r9, r3, r9      ; blend * (col_b.b - col_a.b)     [8.16]

    ; precision.
    add r4, r4, r7, asr #16 ; col_a.r + blend * (col_b.r - col_a.r) [8.0]
    and r4, r4, #0xff
    add r5, r5, r8, asr #16 ; col_a.g + blend * (col_b.g - col_a.g) [8.0]
    and r5, r5, #0xff
    add r6, r6, r9, asr #16 ; col_a.b + blend * (col_b.b - col_a.b) [8.0]
    and r6, r6, #0xff

    ; combine.
    and r4, r4, #0xf0   ; r     [4.0] << 4
    and r5, r5, #0xf0   ; g     [4.0] << 4
    and r6, r6, #0xf0   ; b     [4.0] << 4

    orr r4, r5, r4, lsr #4      ; 0x00GR
    orr r4, r4, r6, lsl #4      ; 0x0BGR
    orr r4, r4, r0, lsl #26     ; 0x0BGR | (index << 26)

    ; store
    ldr r5, [r10, #12]          ; dest_palette
    str r4, [r5, r0, lsl #2]
    add r0, r0, #1
    cmp r0, #16                 ; NB. End of palette range to lerp!
    blt .1
    ; NOTE: For Push intro we ignore colour 15 (orb).
    
    ; TODO: R0 gets stored in the handle - could use &dest_palette[0] as the handle..

    mov pc, lr

; Super hack balls!
; Abuse the math_var functionality to lerp an entire table of RGB values.
; RGB[d][i] = RGB[a][i+c]
; Where a, d are base addresses assumed to contain an array of 16 RGB values in the format 0x00BbGgRr.
; Where c is an address assumed to contain an offset value in fixed-point format [4.16]
; Params:
;  R10=ptr to func parameters [a, b, c, d, f]
;  R0=i [16.0]
; Trashes: R1-R9
; Returns: R0=v
math_evaluate_palette_offset:
    ldr r3, [r10, #8]
    ldr r3, [r3]                ; offset = RAM[c] [1.16]
    mov r3, r3, asr #16         ; INT(offset)

    ldr r1, [r10, #0]           ; palette_A
    ldr r5, [r10, #12]          ; dest_palette

    mov r0, #0                  ; palette index NB. Start from zero!
.1:

    adds r2, r0, r3             ; lookup_index = palette_index + offset
    movlt r2, #0                ; clamp
    cmp r2, #15
    movgt r2, #15

    ldr r4, [r1, r2, lsl #2]    ; colour = palette_A[lookup_index]
    bic r4, r4, #0xf << 26      ; mask out index A
    orr r4, r4, r0, lsl #26     ; mask in index B
    str r4, [r5, r0, lsl #2]    ; dest_palette[i] = colour

    add r0, r0, #1
    cmp r0, #16                 ; NB. End of palette range to lerp!
    blt .1
    ; TODO: R0 gets stored in the handle - could use &dest_palette[0] as the handle..

    mov pc, lr


; ============================================================================

; Super hack balls!
; Abuse the math_var functionality to update a VECTOR3.
; Where a, b, c are math_func definitions to be evaluated.
;       d is the base address of the vector.
; Params:
;  R10=ptr to func parameters [a, b, c, d, f]
;  R0=i [16.0]
; Trashes: R1-R9
; Returns: R0=v
math_evaluate_vec3:
    str lr, [sp, #-4]!

    ; Function parameters are math_func definitions for X, Y, Z componets.

    mov r8, r10
    mov r7, r0
    ldr r6, [r8, #12]       ; vector3_base

    ; Evaluate Z component.
    ldr r10, [r8, #8]       ; c=func_z definition
    bl math_evaluate_func   ; evaluate func_z
    str r0, [r6, #8]        ; store z in vector3_base[8]

    ; Evaluate Y component.
    ldr r10, [r8, #4]       ; b=func_y definition
    mov r0, r7
    bl math_evaluate_func   ; evaluate func_y
    str r0, [r6, #4]        ; store y in vector3_base[4]

    ; Evaluate X component.
    ldr r10, [r8, #0]       ; b=func_x definition
    mov r0, r7
    bl math_evaluate_func   ; evaluate func_x
    ; Return v in R0 which will store X in vector3_base[0]

    ldr pc, [sp], #4

; ============================================================================
; Math functions.
; Param: R0
; Returns: R0
; ============================================================================

.equ math_sin, sine
.equ math_cos, cosine

rnd_seed:
    .long 0x87654321

rnd_bit:
    .long 0x11111111

; R0=[0,1)
; Trashes: R3, R4
math_rand:
    ldr r0, rnd_seed
    ldr r3, rnd_bit
    RND r0, r3, r4
    str r0, rnd_seed
    str r3, rnd_bit
    mov r0, r0, lsr #16 ; [0.16]
    mov pc, lr

; R0=R0 and 15
math_and15:
    and r0, r0, #15<<16
    mov pc, lr

; R0=var address.
math_read_addr:
    ldr r0, [r0]                ; load the value.
    mov pc, lr

; R0=value
math_clamp:
    cmp r0, #0
    movlt r0, #0
    cmp r0, #MATHS_CONST_1
    movgt r0, #MATHS_CONST_1
    mov pc, lr

; R0=value
math_modfp:
    bic r0, r0, #0xff000000
    bic r0, r0, #0x00ff0000
    ; Returns fractional part only (no sign).
    mov pc, lr

; ============================================================================
