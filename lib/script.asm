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
; ============================================================================

.equ ScriptContext_PC,      0       ; Program Pointer.
.equ ScriptContext_Wait,    4       ; Wait frames.
                                    ; imagine we might want to add arbitrary vars into context.
                                    ; but wait until we need to do this.
.equ ScriptContext_LR,      8       ; Link Register. NOTE: we don't have a stack!!

.equ Script_ContextSize,    12
.equ Script_MaxScripts,     16

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
    beq .4

    ldr r1, vsync_delta                 ; TODO: Pass this in.
    subs r11, r11, r1
    movlt r11, #0
    str r11, [r12, #ScriptContext_Wait]
    ldr pc, [sp], #4

    .4:
    ; Execute program.
    ldr r11, [r10], #4                  ; load program ptr.
    str r10, [r12, #ScriptContext_PC]

    ; Push R12 on the stack in case somebody uses it (ahem)...
    str r12, [sp, #-4]!
    adr lr, .3
    mov pc, r11                         ; jump to fn.
    .3:
    ldr r12, [sp], #4
    b .2

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

script_init:
    str lr, [sp, #-4]!

    mov r0, #0
    mov r1, r0
    mov r2, r0

    adr r12, script_contexts
.1:
    stmia r12, {r0-r2}
    .if Script_ContextSize!=12
    .err "Expecting Script_ContextSize == 12!"
    .endif

    adr r11, script_contexts_end
    add r12, r12, #Script_ContextSize
    cmp r12, r11
    blt .1

    ldr pc, [sp], #4

.if _DEBUG
; R2=new frame counter.
script_ffwd_to_frame:
    stmfd sp!, {r0-r12, lr}

    ldr r1, frame_counter
    subs r9, r2, r1
    ble .2
    str r2, frame_counter

    .1:
    str r9, [sp, #-4]!
    bl script_tick_all
    ldr r9, [sp], #4
    subs r9, r9, #1
    bne .1

    .2:
    ldmfd sp!, {r0-r12, pc}
.endif

; R0=ptr to program.
script_add_program:
    mov r1, #0

; R1=initial wait delay.
script_add_program_with_wait:
    adr r2, script_contexts
    adr r4, script_contexts_end
.1:
    ldr r3, [r2, #ScriptContext_PC] ; load relevant context.
    cmp r3, #0

    ; Insert into context with NULL program ptr.
    streq r0, [r2, #ScriptContext_PC]
    streq r1, [r2, #ScriptContext_Wait]
    streq r3, [r2, #ScriptContext_LR]
    moveq pc, lr

    add r2, r2, #Script_ContextSize
    cmp r2, r4
    blt .1

    .if _DEBUG
    adr r0, error_outofscripts
    swi OS_GenerateError
    .endif
    mov pc, lr

.if _DEBUG
error_outofscripts:
	.long 0
	.byte "Ran out of script contexts!"
	.p2align 2
	.long 0
.endif

; R12=context.
; R10=script ptr.
script_wait:
    ldr r11, [r10], #4          ; param=wait frames
    str r11, [r12, #ScriptContext_Wait]
    str r10, [r12, #ScriptContext_PC]
    mov pc, lr

script_call_1:
    ldr r11, [r10], #4          ; fn ptr.
    ldr r0, [r10], #4           ; param
    str r10, [r12, #ScriptContext_PC]
    mov pc, r11

script_call_2:
    ldr r11, [r10], #4          ; fn ptr.
    ldmia r10!, {r0-r1}         ; params
    str r10, [r12, #ScriptContext_PC]
    mov pc, r11

script_call_3:
    ldr r11, [r10], #4          ; fn ptr.
    ldmia r10!, {r0-r2}         ; params
    str r10, [r12, #ScriptContext_PC]
    mov pc, r11

script_call_4:
    ldr r11, [r10], #4          ; fn ptr.
    ldmia r10!, {r0-r3}         ; params
    str r10, [r12, #ScriptContext_PC]
    mov pc, r11

script_call_5:
    ldr r11, [r10], #4          ; fn ptr.
    ldmia r10!, {r0-r4}         ; params
    str r10, [r12, #ScriptContext_PC]
    mov pc, r11

script_call_6:
    ldr r11, [r10], #4          ; fn ptr.
    ldmia r10!, {r0-r5}         ; params
    str r10, [r12, #ScriptContext_PC]
    mov pc, r11

script_call_7:
    ldr r11, [r10], #4          ; fn ptr.
    ldmia r10!, {r0-r6}         ; params
    str r10, [r12, #ScriptContext_PC]
    mov pc, r11

script_return_if_zero:
    ldr r0, [r10], #4                       ; param=var address.
    str r10, [r12, #ScriptContext_PC]
    ldr r0, [r0]
    cmp r0, #0
    movne pc, lr
; FALL THROUGH!

; R12=context.
; R10=script ptr.
script_return:
    ldr r11, [r12, #ScriptContext_LR]
    str r11, [r12, #ScriptContext_PC]
    mov r11, #0
    str r11, [r12, #ScriptContext_LR]
    ; Can't be waiting if terminate command is executing.
    mov pc, lr

; R12=context.
; R10=script ptr.
script_fork:
    ldr r0, [r10], #4                       ; param=program ptr.
    str r10, [r12, #ScriptContext_PC]
    b script_add_program

; R12=context.
; R10=script ptr.
script_fork_and_wait:
    ldmia r10!, {r0-r1}                     ; params=program ptr & wait.
    str r10, [r12, #ScriptContext_PC]
    b script_add_program_with_wait

; R12=context.
; R10=script ptr.
script_gosub:
    ldr r0, [r10], #4                       ; param=program ptr.
    .if _DEBUG
    ldr r11, [r12, #ScriptContext_LR]
    cmp r11, #0
    adrne r0, error_lrused
    swine OS_GenerateError
    .endif
    str r10, [r12, #ScriptContext_LR]       ; return here.
    str r0, [r12, #ScriptContext_PC]        ; continue from here.
    mov pc, lr

; R12=context.
; R10=script ptr.
script_goto_and_wait:
    ldmia r10!, {r0-r1}                     ; params=program ptr & wait.
    str r1, [r12, #ScriptContext_Wait]
    str r0, [r12, #ScriptContext_PC]        ; continue from here.
    mov pc, lr

; R12=context.
; R10=script ptr.
script_goto:
    ldr r0, [r10], #4                       ; param=program ptr.
    str r0, [r12, #ScriptContext_PC]        ; continue from here.
    mov pc, lr

.if _DEBUG
error_lrused:
	.long 0
	.byte "Link Register already used in script!"
	.p2align 2
	.long 0
.endif

; R12=context.
; R10=script ptr.
script_write_addr:
    ldmia r10!, {r0-r1}         ; params={address, value}
    str r1, [r0]
    str r10, [r12, #ScriptContext_PC]
    mov pc, lr

; R12=context.
; R10=script ptr.
script_write_byte:
    ldmia r10!, {r0-r1}         ; params={address, value}
    strb r1, [r0]
    str r10, [r12, #ScriptContext_PC]
    mov pc, lr

; R12=context.
; R10=script ptr.
script_call_swi:
    ldr r11, [r10], #4          ; fn ptr.
    ldmia r10!, {r0-r1}         ; 2 params
    str r10, [r12, #ScriptContext_PC]

    orr r11, r11, #0xef000000   ; opcode SWI
    str r11, .1                 ; SELF-MOD!
.1:
    swi 0                       ; SELF-MOD!
    mov pc, lr
