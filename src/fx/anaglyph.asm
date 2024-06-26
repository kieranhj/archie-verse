; ============================================================================
; Anaglyph 3D rendering functions for Three Dee demo.
; Used in: Three-Dee Demo (Mikroreise)
; ============================================================================

; R12=screen addr
anaglyph_draw_3d_scene_as_circles:             ; TODO: Dedupe this code!
    str lr, [sp, #-4]!

    ; Stash screen addr for now.
    str r12, [sp, #-4]!

	; Reset array of circles.
    bl circles_reset_for_frame

    ; Left eye.
    ldr r0, LeftEye_X_Pos
    str r0, camera_pos+0        ; camera_pos_x

    ; Subtract blue & green.
    mov r4, #7                  ; brightest red
    bl draw_3d_object_as_circles

    ; Right eye.
    ldr r0, RightEye_X_Pos
    str r0, camera_pos+0        ; camera_pos_x

    ; Subtract red.
    mov r4, #11                 ; brightest cyan
    bl draw_3d_object_as_circles

    ; Then plot all the circles.
    ldr r12, [sp], #4           ; pop screen addr
    bl plot_all_circles

    ldr pc, [sp], #4

; R12=screen addr
anaglyph_draw_3d_scene_as_wire:             ; TODO: Dedupe this code!
    str lr, [sp, #-4]!

    ; Left eye.
    ldr r0, LeftEye_X_Pos
    str r0, camera_pos+0        ; camera_pos_x

    ; Subtract blue & green.
    mov r4, #7                 ; brightest red
    ;mov r4, #8                  ; bic 0b1000
    bl draw_3d_scene_wire

    ; Right eye.
    ldr r0, RightEye_X_Pos
    str r0, camera_pos+0        ; camera_pos_x

    ; Subtract red.
    mov r4, #11                ; brightest cyan
    ;mov r4, #4                  ; bic 0b0100
    bl draw_3d_scene_wire

    ldr pc, [sp], #4

; R12=screen addr
anaglyph_draw_3d_scene_as_outline:             ; TODO: Dedupe this code!
    str lr, [sp, #-4]!

    ; Left eye.
    ldr r0, LeftEye_X_Pos
    str r0, camera_pos+0        ; camera_pos_x

    ; Subtract blue & green.
    mov r4, #7                 ; brightest red
    ;mov r4, #8                  ; bic 0b1000
    bl draw_3d_scene_outline

    ; Right eye.
    ldr r0, RightEye_X_Pos
    str r0, camera_pos+0        ; camera_pos_x

    ; Subtract red.
    mov r4, #11                ; brightest cyan
    ;mov r4, #4                  ; bic 0b0100
    bl draw_3d_scene_outline

    ldr pc, [sp], #4

; R12=screen addr
anaglyph_draw_3d_scene_as_solid:             ; TODO: Dedupe this code!
    str lr, [sp, #-4]!

    ; Left eye.
    ldr r0, LeftEye_X_Pos
    str r0, camera_pos+0        ; camera_pos_x

    ; Subtract blue & green.
    mov r4, #7                  ; brightest red
    adr r4, colour_lookup_red
    bl scene3d_draw_entity_as_solid_quads

    ; Right eye.
    ldr r0, RightEye_X_Pos
    str r0, camera_pos+0        ; camera_pos_x

    ; Subtract red.
    mov r4, #11                 ; brightest cyan
    adr r4, colour_lookup_cyan
    bl scene3d_draw_entity_as_solid_quads

    ldr pc, [sp], #4
