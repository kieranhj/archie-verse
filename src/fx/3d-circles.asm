; ============================================================================
; Circles 3D rendering functions.
; Plot transformed verts using Progen's fast circle plot routines.
; Used in: Mikroreise.
; ============================================================================

object_colour_index:
    .long 0

; R4=colour index
; R12=screen addr
draw_3d_object_as_circles:
    str lr, [sp, #-4]!
    str r4, object_colour_index

    ; Project world space verts to screen space.
    bl scene3d_project_verts

    ; Plot all verts as circles...
    ldr r6, projected_verts_p
    ldr r7, transformed_verts_p
    ldr r11, object_num_verts
    mov r5, #0
    ldr r4, camera_pos+8        ; camera_pos_z

    ; TODO: Would ultimately need to sort by Z. => Should have radix sorted by Z but anyway.
    ; TODO: A fixed number of sprites with radius [1,16] would be faster, i.e. vector balls!

    .2:
    ; screen_radius = VP_SCALE * world_radius / (z-cz)
    mov r0, #VIEWPORT_SCALE
    ldr r1, [r7, #8]            ; (z)
    sub r1, r1, r4              ; (z-cz)
    bl divide                   ; [s7.16] (trashes r8-r10)
    mov r2, r0, asr #13         ; radius = VP_SCALE * world_radius / (z-cz) where world_radius=8 (r<<3>>16)

    ldmia r6!, {r0,r1}          ; screen_X & screen_Y.

    ldr r9, object_colour_index
    bl circles_add_to_plot_by_Y    ; trashes r8,r12

    add r7, r7, #VECTOR3_SIZE
    add r5, r5, #1
    cmp r5, r11
    blt .2

    ldr pc, [sp], #4

; ============================================================================
; ============================================================================
