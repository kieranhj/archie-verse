; ============================================================================
; Wireframe 3D rendering functions.
; Used in: Three-Dee Demo (Mikroreise)
; ============================================================================

object_colour_index:
    .long 0

object_num_edges:
    .long 0

object_edge_list_per_face_p:
    .long model_cobra_edges_per_face

object_edge_indices_p:
    .long model_cobra_edge_indices

; R4=colour index
; R12=screen addr
draw_3d_scene_wire:             ; TODO: Dedupe this code!
    str lr, [sp, #-4]!
    str r4, object_colour_index

    ; Project world space verts to screen space.
    bl scene3d_project_verts

    ; Plot faces as polys.
    mov r9, #0                  ; face count
    str r9, edge_plot_cache

    ldr r11, object_num_faces
    sub r11, r11, #1

    .2:
    ldr r9, object_face_indices_p
    ldrb r5, [r9, r11, lsl #2]   ; vertex0 of polygon N.
    
    ldr r1, transformed_verts_p
    add r1, r1, r5, lsl #3
    add r1, r1, r5, lsl #2       ; transformed_verts + index*12
    ldr r2, transformed_normals_p
    add r2, r2, r11, lsl #3      ; face_normal for polygon N.
    add r2, r2, r11, lsl #2      ; face_normal for polygon N.

    ; Backfacing culling test (vertex - camera_pos).face_normal
    ; Parameters:
    ;  R1=ptr to transformed vertex in camera relative space
    ;  R2=ptr to face normal vector
    ; Return:
    ;  R0=dot product of (v0-cp).n
    ; Trashes: r3-r8
    ; vector A = (v0 - camera_pos)
    ; vector B = face_normal

    ldmia r1!, {r3-r5}          ; [tx, ty, tz]
    adr r0, camera_pos
    ldmia r0, {r6-r8}           ; camera_pos

    sub r3, r3, r6
    sub r4, r4, r7
    sub r5, r5, r8

    bl vector_dot_product_load_B ; trashes r3-r8
    cmp r0, #0                  
    bpl .3                      ; normal facing away from the view direction.

    ; WIREFRAME
    ldr r4, object_colour_index
    ldr r5, object_edge_indices_p
    ldr r6, projected_verts_p   ; projected vertex array.
    ldr r7, object_edge_list_per_face_p
    ldr r7, [r7, r11, lsl #2]   ; edge list word for polygon N.

    stmfd sp!, {r11}
    bl plot_face_edge_list      ; trashes r0-r11
    ldmfd sp!, {r11}

    .3:
    subs r11, r11, #1
    bpl .2

    ldr pc, [sp], #4

edge_plot_cache:
    .long 0

; Plot all edges in a list.
; Parameters:
;  R12=screen addr
;  R4=colour index
;  R5=ptr to array of edge indices.
;  R6=ptr to projected vertex array (x,y) in screen coords [16.0]
;  R7=edge list word (one bit per edge to be plotted)
plot_face_edge_list:
	str lr, [sp, #-4]!			; push lr on stack

    ldr r11, edge_plot_cache
    mov r8, #0                  ; edge no.
.1:
    ; Convert edge no. to bit no.
    mov r9, #1

    ; Test edge list cache.
    tst r11, r9, lsl r8         ; already plotted?
    bne .2

    ; Test if this edge is in the face.
    tst r7, r9, lsl r8
    beq .2

    ; Look up vertex indices for edge.
    ldr r0, [r5, r8, lsl #1]    ; misaligned read!
    mov r2, r0, lsr #8          ; end index
    and r0, r0, #0xff           ; start index
    and r2, r2, #0xff

    ; Load (x,y) for start vertex
    add r9, r6, r0, lsl #3      ; projected_verts[start_index]
    ldmia r9, {r0,r1}           ; start_x, start_y

    ; Load (x,y) for end vertex
    add r9, r6, r2, lsl #3      ; projected_verts[start_index]
    ldmia r9, {r2,r3}           ; end_x, end_y

    stmfd sp!, {r5-r8}
    bl mode9_drawline_orr       ; trashes r5-r9
    ldmfd sp!, {r5-r8}

    ; Mark edge as plotted in cache.
    mov r9, #1
    orr r11, r11, r9, lsl r8

.2:
    ; Early out when edge list word is zero.
    bics r7, r7, r9, lsl r8
    beq .3

    ; Next edge no.
    add r8, r8, #1
    cmp r8, #32
    blt .1

.3:
    str r11, edge_plot_cache
    ldr pc, [sp], #4


; R4=colour index
; R12=screen addr
draw_3d_scene_outline:             ; TODO: Dedupe this code!
    str lr, [sp, #-4]!
    str r4, object_colour_index

    ; Project world space verts to screen space.
    bl scene3d_project_verts

    ldr r8, object_num_edges
    sub r8, r8, #1              ; edge no.

    ; OUTLINE
    .1:
    ldr r4, object_colour_index
    ldr r5, object_edge_indices_p
    ldr r6, projected_verts_p   ; projected vertex array.

    ; Look up vertex indices for edge.
    ldr r0, [r5, r8, lsl #1]    ; misaligned read!
    mov r2, r0, lsr #8          ; end index
    and r0, r0, #0xff           ; start index
    and r2, r2, #0xff

    ; Load (x,y) for start vertex
    add r9, r6, r0, lsl #3      ; projected_verts[start_index]
    ldmia r9, {r0,r1}           ; start_x, start_y

    ; Load (x,y) for end vertex
    add r9, r6, r2, lsl #3      ; projected_verts[start_index]
    ldmia r9, {r2,r3}           ; end_x, end_y

    stmfd sp!, {r8}
    bl mode9_drawline_with_clip       ; trashes r5-r9
    ldmfd sp!, {r8}

    subs r8, r8, #1
    bpl .1

    ldr pc, [sp], #4
