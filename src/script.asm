; ============================================================================
; Script module.
; A lightweight, low assumption scripting system.
;
; Scripts are just a sequence of function pointers.
; Script fns are called with R12=ptr to script context, R10=ptr to program.
; Fn reads own parameters with a helper if needed.
;
; NB. At risk of reinventing an intepreted language here, but through macros.
;     Assess actual need and implement as necessary. Keep an eye on overhead
;     and complexity. Use proper language tools if we need a proper language..
;
; TODO: Make this a library if proven to be sufficiently useful / reuseable.
; ============================================================================

.equ ScriptContext_Ptr, 0           ; program pointer.
.equ ScriptContext_Wait, 4          ; wait frames.
                                    ; imagine we might want to add arbitrary vars into context.
                                    ; but wait until we need to do this.
                                    ; NOTE: we don't have a stack!!

.equ Script_ContextSize, 8
.equ Script_MaxScripts, 2

script_contexts:
    .skip Script_ContextSize*Script_MaxScripts
script_contexts_end:

; R12=ptr to script context.
script_tick_context:
    str lr, [sp, #-4]!

    .2:
    ldmia r12, {r10-r11}                ; load context.
    cmp r10, #0
    ldreq pc, [sp], #4                  ; no program.
    
    ; Waiting?
    cmp r11, #0
    subne r11, r11, #1
    strne r11, [r12, #ScriptContext_Wait]
    ldrne pc, [sp], #4

    ; Execute program.
    ldr r11, [r10], #4                  ; load program ptr.
    str r10, [r12, #ScriptContext_Ptr]

    ; TODO: Push R12 on the stack?

    adr lr, .2
    mov pc, r11                         ; jump to fn.

script_tick_all:
    str lr, [sp, #-4]!

    adr r12, script_contexts
.1:
    bl script_tick_context

    adr r11, script_contexts_end
    add r12, r12, #Script_ContextSize
    cmp r12, r11
    blt .1

    ldr pc, [sp], #4

; R0=ptr to program.
script_add_program:
    adr r2, script_contexts
    adr r1, script_contexts_end
.1:
    ldmia r2, {r3-r4}                ; load context
    cmp r3, #0

    ; Insert into context with NULL program ptr.
    streq r0, [r2, #ScriptContext_Ptr]
    streq r3, [r2, #ScriptContext_Wait]
    moveq pc, lr

    add r2, r2, #Script_ContextSize
    cmp r2, r1
    blt .1

    ; Assert ran out of contexts.
    .if _DEBUG
    adr r0, error_noscriptsleft
    swi OS_GenerateError

error_noscriptsleft:
	.long 0
	.byte "Ran out of script contexts!"
	.p2align 2
	.long 0
    .endif

    mov pc, lr

; R12=context.
; R10=script ptr.
script_wait:
    ldr r11, [r10], #4          ; param=wait frames
    str r11, [r12, #ScriptContext_Wait]
    str r10, [r12, #ScriptContext_Ptr]
    mov pc, lr

script_call_1:
    ldr r11, [r10], #4          ; fn ptr.
    ldr r0, [r10], #4           ; param
    str r10, [r12, #ScriptContext_Ptr]
    mov pc, r11

script_call_2:
    ldr r11, [r10], #4          ; fn ptr.
    ldmia r10!, {r0-r1}         ; params
    str r10, [r12, #ScriptContext_Ptr]
    mov pc, r11

script_call_3:
    ldr r11, [r10], #4          ; fn ptr.
    ldmia r10!, {r0-r2}         ; params
    str r10, [r12, #ScriptContext_Ptr]
    mov pc, r11

script_call_4:
    ldr r11, [r10], #4          ; fn ptr.
    ldmia r10!, {r0-r3}         ; params
    str r10, [r12, #ScriptContext_Ptr]
    mov pc, r11

; R12=context.
script_terminate:
    mov r10, #0                 ; NULL the program ptr.
    str r10, [r12, #ScriptContext_Ptr]
    str r10, [r12, #ScriptContext_Wait]
    mov pc, lr

; R12=context.
script_fork:
    ldr r0, [r10], #4           ; param=program ptr.
    str r10, [r12, #ScriptContext_Ptr]
    b script_add_program

; R12=context.
; R10=script ptr.
script_write_addr:
    ldmia r10!, {r0-r1}         ; params={address, value}
    str r1, [r0]
    str r10, [r12, #ScriptContext_Ptr]
    mov pc, lr


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

.macro wait frames
    .long script_wait, \frames
.endm

.macro wait_secs secs
    .long script_wait, \secs*50
.endm

.macro end_script
    .long script_terminate
.endm

.macro write_addr address, value
    .long script_write_addr, \address, \value
.endm

; NOTE: Forked program not guaranteed to be executed on this frame as the PC
;       is inserted into the first free slot in the program list. If this is
;       before the currently running program then it won't get around until
;       next tick. This could be solved by using a linked-list of programs
;       inserted into a frame array, similar to Rose.
.macro fork program
    .long script_fork, \program
.endm

; TODO: Call subroutine (for model setup etc.) that is guaranteed to be
;       executed there and then.
