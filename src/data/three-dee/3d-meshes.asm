; ============================================================================
; Model data: CUBE
;
;         4         5        y
;          +------+          ^  z
;         /      /|          |/
;        /      / |          +--> x
;     0 +------+ 1|
;       | 7 +  |  + 6
;       |      | /
;       |      |/
;       +------+
;      3        2
; ============================================================================

.equ Mesh_Cube_NumVerts, 8
.equ Mesh_Cube_NumFaces, 6

mesh_header_cube:
    .long  Mesh_Cube_NumVerts
    .long  Mesh_Cube_NumFaces
    .long  mesh_cube_verts
    .long  mesh_cube_face_normals
    .long  mesh_cube_face_indices
    .long  mesh_cube_colour_per_face

; !VERTEX AND NORMAL ARRAYS MUST BE CONSECUTIVE!

mesh_cube_verts:
    VECTOR3 -16.0,  16.0, -16.0
    VECTOR3  16.0,  16.0, -16.0
    VECTOR3  16.0, -16.0, -16.0
    VECTOR3 -16.0, -16.0, -16.0
    VECTOR3 -16.0,  16.0,  16.0
    VECTOR3  16.0,  16.0,  16.0
    VECTOR3  16.0, -16.0,  16.0
    VECTOR3 -16.0, -16.0,  16.0

; !VERTEX AND NORMAL ARRAYS MUST BE CONSECUTIVE!

mesh_cube_face_normals:
    VECTOR3  0.0,  0.0, -1.0
    VECTOR3  1.0,  0.0,  0.0
    VECTOR3  0.0,  1.0,  0.0
    VECTOR3  0.0,  0.0,  1.0
    VECTOR3 -1.0,  0.0,  0.0
    VECTOR3  0.0  -1.0,  0.0

; !VERTEX AND NORMAL ARRAYS MUST BE CONSECUTIVE!

; Winding order is clockwise (from outside)
mesh_cube_face_indices:
    .byte 0, 1, 2, 3
    .byte 1, 5, 6, 2
    .byte 0, 4, 5, 1
    .byte 5, 4, 7, 6
    .byte 4, 0, 3, 7
    .byte 2, 3, 7, 6

mesh_cube_colour_per_face:
    .byte 4,5,6,7,8,9,10,11

; TODO: Determine this from mesh_cube_face_indices.
; TODO: Could also calculate face normals from these...
; TODO: Handle more than 32 total edges.
mesh_cube_edges_per_face:
;            3         2         1         
;           10987654321098765432109876543210
    .long 0b00000000000000000000000000001111
    .long 0b00000000000000000000011000100010
    .long 0b00000000000000000000001100010001
    .long 0b00000000000000000000000011110000
    .long 0b00000000000000000000100110001000
    .long 0b00000000000000000000110001000100

; TODO: Determine this from mesh_cube_face_indices.
mesh_cube_edge_indices:
    .byte 0, 1              ; 0
    .byte 1, 2              ; 1
    .byte 2, 3              ; 2
    .byte 3, 0              ; 3
    .byte 4, 5              ; 4
    .byte 5, 6              ; 5
    .byte 6, 7              ; 6
    .byte 7, 4              ; 7
    .byte 0, 4              ; 8
    .byte 1, 5              ; 9
    .byte 2, 6              ; 10
    .byte 3, 7              ; 11
.p2align 2

; ============================================================================
; Model data: COBRA
; ============================================================================

.equ Mesh_Cobra_NumVerts, 22
.equ Mesh_Cobra_NumFaces, 13

mesh_header_cobra:
    .long  Mesh_Cobra_NumVerts
    .long  Mesh_Cobra_NumFaces
    .long  mesh_cobra_verts
    .long  mesh_cobra_face_normals
    .long  mesh_cobra_face_indices
    .long  mesh_cobra_colour_per_face

; !VERTEX AND NORMAL ARRAYS MUST BE CONSECUTIVE!

mesh_cobra_verts:
    VECTOR3 -19,-8,0
    VECTOR3 -19,-4.5,0
    VECTOR3 -16,-8,-1
    VECTOR3 -5,9,0
    VECTOR3 -5,-8,2
    VECTOR3 5,-8,2
    VECTOR3 0,3,-3.5
    VECTOR3 0,9,0
    VECTOR3 0,12,0
    VECTOR3 5,9,0
    VECTOR3 0,-8,-2
    VECTOR3 16,-8,-1
    VECTOR3 19,-4.5,0
    VECTOR3 19,-8,0
    VECTOR3 -5,-8,-1
    VECTOR3 -2,-8,-1
    VECTOR3 -2,-8,1.5
    VECTOR3 -5,-8,1
    VECTOR3 2,-8,-1
    VECTOR3 5,-8,-1
    VECTOR3 5,-8,1
    VECTOR3 2,-8,1.5

; !VERTEX AND NORMAL ARRAYS MUST BE CONSECUTIVE!

mesh_cobra_face_normals:
    VECTOR3 -0.316228, 0.000000, -0.948683      ; MD_SURF 0,1,2
    VECTOR3 -0.147398, 0.152857, -0.977194      ; MD_SURF 1,3,2
    VECTOR3 -0.322292, 0.262051, -0.909647      ; MD_SURF 2,3,6
    VECTOR3 -0.061808, -0.134855, -0.988936     ; MD_SURF 2,6,10
    VECTOR3 -0.000000, 0.503871, -0.863779      ; MD_SURF 3,9,6
    VECTOR3 0.061808, -0.134855, -0.988936      ; MD_SURF 10,6,11
    VECTOR3 0.322292, 0.262051, -0.909647       ; MD_SURF 6,9,11
    VECTOR3 0.147398, 0.152857, -0.977194       ; MD_SURF 11,9,12
    VECTOR3 0.316228, 0.000000, -0.948683       ; MD_SURF 11,12,13
    VECTOR3 0.140472, 0.115683, 0.983303        ; MD_SURF 13,9,5
    VECTOR3 0.000000, 0.116841, 0.993151        ; MD_SURF 5,3,4
    VECTOR3 -0.140472, 0.115683, 0.983303       ; MD_SURF 4,3,0
    VECTOR3 0.000000, -1.000000, 0.000000       ; MD_SURF 4,10,5

; !VERTEX AND NORMAL ARRAYS MUST BE CONSECUTIVE!

mesh_cobra_face_indices:
    .byte 0,1,2,0
    .byte 1,3,2,1
    .byte 2,3,6,2
    .byte 2,6,10,2
    .byte 3,9,6,3
    .byte 10,6,11,10
    .byte 6,9,11,6
    .byte 11,9,12,11
    .byte 11,12,13,11
    .byte 13,9,5,13
    .byte 5,3,4,5
    .byte 4,3,0,4
    .byte 4,10,5,4

mesh_cobra_colour_per_face:
    .byte 2,3,4,5,6,7,8,9,10,11,12,13,14
.p2align 2

mesh_cobra_edges_per_face:
    .long 0x00000007    ; 3
    .long 0x0000001C    ; 3
    .long 0x000000B0    ; 3
    .long 0x00020420    ; 3
    .long 0x000003C0    ; 4
    .long 0x00040C00    ; 3
    .long 0x00001900    ; 3
    .long 0x00007000    ; 3
    .long 0x0001C000    ; 3
    .long 0x80092000    ; 4
    .long 0xC0100240    ; 5
    .long 0x40200009    ; 4
    .long 0x3FFE8002    ; 15

mesh_cobra_edge_indices:
    .byte 0,1
    .byte 0,2
    .byte 1,2
    .byte 1,3
    .byte 2,3
    .byte 2,6
    .byte 3,9
    .byte 3,6
    .byte 6,9
    .byte 7,8
    .byte 10,6
    .byte 6,11
    .byte 9,11
    .byte 9,12
    .byte 11,12
    .byte 11,13
    .byte 12,13
    .byte 2,10
    .byte 11,10
    .byte 5,13
    .byte 4,5
    .byte 0,4
    .byte 14,15
    .byte 15,16
    .byte 16,17
    .byte 14,17
    .byte 18,19
    .byte 19,20
    .byte 20,21
    .byte 18,21
    .byte 3,4
    .byte 5,9
.p2align 2

; ============================================================================

.if 0
.macro LINE a, b
    .byte \a, \b
.endm

.include "src/obj/rab.asm"
.include "src/obj/slp.asm"
.include "src/obj/rft.asm"
.include "src/obj/prx.asm"
.include "src/obj/nva.asm"
.include "src/obj/lgc.asm"
.include "src/obj/dsr.asm"
.include "src/obj/dln.asm"
.include "src/obj/ate.asm"
.include "src/obj/ymr.asm"
.include "src/obj/smf.asm"
.include "src/obj/pro.asm"
.include "src/obj/hoo.asm"
.include "src/obj/far.asm"
.include "src/obj/crt.asm"
.include "src/obj/mst.asm"
.include "src/obj/iph.asm"
.include "src/obj/mik.asm"
.endif

; ============================================================================
