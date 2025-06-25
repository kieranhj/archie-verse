; ============================================================================
; Standard script macros.
; TODO: Nice detailed descriptions of how to use each MACRO.
; ============================================================================

.macro call_0 function
    .long \function
.endm

.macro call_1 function, param1
    .long script_call_1, \function, \param1
.endm

.macro call_2 function, param1, param2
    .long script_call_2, \function, \param1, \param2
.endm

.macro call_3 function, param1, param2, param3
    .long script_call_3, \function, \param1, \param2, \param3
.endm

.macro call_4 function, param1, param2, param3, param4
    .long script_call_4, \function, \param1, \param2, \param3, \param4
.endm

.macro call_5 function, param1, param2, param3, param4, param5
    .long script_call_5, \function, \param1, \param2, \param3, \param4, \param5
.endm

.macro call_6 function, param1, param2, param3, param4, param5, param6
    .long script_call_6, \function, \param1, \param2, \param3, \param4, \param5, \param6
.endm

.macro call_7 function, param1, param2, param3, param4, param5, param6, param7
    .long script_call_7, \function, \param1, \param2, \param3, \param4, \param5, \param6, \param7
.endm

.macro call_1f function, param1
    .long script_call_1, \function, MATHS_CONST_1*\param1
.endm

.macro call_2f function, param1, param2
    .long script_call_2, \function, MATHS_CONST_1*\param1, MATHS_CONST_1*\param2
.endm

.macro call_3f function, param1, param2, param3
    .long script_call_3, \function, MATHS_CONST_1*\param1, MATHS_CONST_1*\param2, MATHS_CONST_1*\param3
.endm

.macro call_4f function, param1, param2, param3, param4
    .long script_call_4, \function, MATHS_CONST_1*\param1, MATHS_CONST_1*\param2, MATHS_CONST_1*\param3, MATHS_CONST_1*\param4
.endm

.macro call_5f function, param1, param2, param3, param4, param5
    .long script_call_5, \function, MATHS_CONST_1*\param1, MATHS_CONST_1*\param2, MATHS_CONST_1*\param3, MATHS_CONST_1*\param4, MATHS_CONST_1*\param5
.endm

.macro wait frames
    .long script_wait, \frames
.endm

; TODO: wait_secs doesn't actually wait for seconds! (Currently waits for vsyncs.)
.macro wait_secs secs
    .long script_wait, \secs*50
.endm

.macro end_script
    .long script_return
.endm

.macro end_script_if_zero address
    .long script_return_if_zero, \address
.endm

.macro write_addr address, value
    .long script_write_addr, \address, \value
.endm

.macro write_byte address, value
    .long script_write_byte, \address, \value
.endm

.macro write_fp address, fp_value
    write_addr \address, MATHS_CONST_1*\fp_value
.endm

.macro write_vec2 address, x, y
    write_addr 0+\address, MATHS_CONST_1*\x
    write_addr 4+\address, MATHS_CONST_1*\y
.endm

.macro write_vec3 address, x, y, z
    write_addr 0+\address, MATHS_CONST_1*\x
    write_addr 4+\address, MATHS_CONST_1*\y
    write_addr 8+\address, MATHS_CONST_1*\z
.endm


; NOTE: Forked program not guaranteed to be executed on this frame as the PC
;       is inserted into the first free slot in the program list. If this is
;       before the currently running program then it won't get around until
;       next tick. This could be solved by using a linked-list of programs
;       inserted into a frame array, similar to Rose.
.macro fork program
    .long script_fork, \program
.endm

; Call subroutine (for model setup etc.) that is guaranteed to be executed
; immediately. Can only be nested one call deep as uses a Link Register;
; would need a stack to support more than this.
.macro gosub routine
    .long script_gosub, \routine
.endm

.macro fork_and_wait frames, program
    .long script_fork_and_wait, \program, \frames
.endm

.macro fork_and_wait_secs secs, program
    .long script_fork_and_wait, \program, \secs*50.0
.endm

.macro goto cont
    .long script_goto, \cont
.endm

.macro yield cont
    .long script_goto_and_wait, \cont, 1
.endm

.macro call_swi swi_no, reg0, reg1
    .long script_call_swi, \swi_no, \reg0, \reg1
.endm

; ============================================================================
; Script helpers for math functions.
; ============================================================================

; ============================================================================
; Declare math functions (to be passed to particle or dynamics systems).
; ============================================================================

; v = a + b * f(c + d * i)      ; linear fn.
; Where a, b, c, d are s15.16 fixed-point values.
; Where i is an iteration integer that counts up from 0 with each call (usually frame).
; Where f is a function that takes R0 as a parameter and returns in R0.
.macro math_func a, b, f, c, d
    FLOAT_TO_FP \a
    FLOAT_TO_FP \b
    FLOAT_TO_FP \c
    FLOAT_TO_FP \d
    .long \f
.endm

; v = a + b * (*c)
; Where a, b are s15.16 fixed-point values.
; Where c is a memory address (assumed to contain a s15.16 fixed-point value).
.macro math_func_read_addr a, b, c
    FLOAT_TO_FP \a
    FLOAT_TO_FP \b
    .long \c
    .long 0
    .long math_read_addr
.endm

; v = a
; Where a is a s15.16 fixed-point value.
.macro math_const a
    math_func \a, 0.0, 0.0, 0.0, 0
.endm

.equ math_no_func, 0

; ============================================================================
; Helpers to create math variables.
; ============================================================================

; Make a math variable: *addr = a + b * (f)(c + d * i)
; Where a, b, c, d are s15.16 fixed-point values.
; Where i is an iteration integer that counts up from 0 with each call (usually frame).
; Where f is a function that takes R0 as a parameter and returns in R0.
.macro math_make_var addr, a, b, f, c, d
    .long script_call_6, math_var_register, \addr, MATHS_CONST_1*\a, MATHS_CONST_1*\b, MATHS_CONST_1*\c, MATHS_CONST_1*\d, \f
.endm

; Make a math variable: *addr = a + (*b) * (f)(c + d * i)
; Where a, c, d are s15.16 fixed-point values.
; Where b is a memory address.
; Where i is an iteration integer that counts up from 0 with each call (usually frame).
; Where f is a function that takes R0 as a parameter and returns in R0.
.macro math_make_var2 addr, a, b, f, c, d
    .long script_call_7, math_var_register_ex, \addr, MATHS_CONST_1*\a, \b, MATHS_CONST_1*\c, MATHS_CONST_1*\d, \f, math_evaluate_func2
.endm

; Removes a math variable from the list.
.macro math_kill_var addr
    .long script_call_1, math_var_unregister, \addr
.endm

; Really what we mean is a variable goes out of scope...
.macro destroy var_name
    math_kill_var \var_name
.endm

; Make a math variable: *addr = a + b * (*c)
; Where a, b are s15.16 fixed-point values.
; Where c is a memory address.
; I.e. linearly link two variables (memory addresses) together.
.macro math_link_vars addr, a, b, c
    .long script_call_6, math_var_register, \addr, MATHS_CONST_1*\a, MATHS_CONST_1*\b, \c, 0, math_read_addr
.endm

; Make a math variable: *addr = a + (*b) * (*c)
; Where a is a s15.16 fixed-point values.
; Where b, c are memory addresses (assumed to contain s15.16 values)
; I.e. multiply two variables (memory addresses) together.
.macro math_mul_vars addr, a, b, c
    .long script_call_7, math_var_register_ex, \addr, MATHS_CONST_1*\a, \b, \c, 0, math_read_addr, math_evaluate_func2
.endm

; Make a math variable: *addr = a + (*b) * (*c)
; Where a is a s15.16 fixed-point values.
; Where b, c are memory addresses (assumed to contain s15.16 values)
; I.e. multiply two variables (memory addresses) together.
.macro math_add_vars addr, a, b, c
    .long script_call_7, math_var_register_ex, \addr, \a, MATHS_CONST_1*\b, \c, 0, math_read_addr, math_evaluate_func3
.endm

; Separate the link between two variables.
.macro math_unlink_vars addr, c
    math_kill_var \addr
.endm

; Make a math variable: V = [fx(i), fy(i), fz(i)]
; Where fx, fy, fz are math_func definitions that define linear equations:
; E.g. fx = a + b * f(c + d * i)
; Where i is an iteration integer that counts up from 0 with each call (usually frame).
.macro math_make_vec3 addr, func_x, func_y, func_z
    .long script_call_7, math_var_register_ex, \addr, \func_x, \func_y, \func_z, \addr, 0, math_evaluate_vec3
.endm

; ============================================================================
; Helpers to create RGB variables.
; ============================================================================

; Make an RGB blender: *rgb_addr = colA + (*blend_addr) * (colB - colA)
; Where colA and colB are 0x00BbGgRr
; Where blend_addr contains a fixed-point 1.16 blend value.
.macro math_make_rgb rgb_addr, colA, colB, blend_addr
    .long script_call_7, math_var_register_ex, \rgb_addr, \colA, \colB, \blend_addr, 0, 0, math_evaluate_rgb_lerp
.endm

; Removes an RGB blend address from the list.
.macro math_kill_rgb rgb_addr
    math_kill_var \rgb_addr
.endm

; Make a full 16 entry RGB palette blender.
; Where handle_addr is a handle.
; Where palette_A, palette_B and tableDst are pointers to 16 word palettes with entries in the form 0x00BbGgRr
; Where blend_addr contains a fixed-point 1.16 blend value (usually driven by another math_var).
.macro math_make_palette handle_addr, palette_A, palette_B, blend_addr, tableDst
    .long script_call_7, math_var_register_ex, \handle_addr, \palette_A, \palette_B, \blend_addr, \tableDst, 0, math_evaluate_palette_lerp
.endm
