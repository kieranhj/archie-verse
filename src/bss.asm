; ============================================================================
; BSS Segment (Uninitialised data, not stored in the exe.)
; ============================================================================

.bss

; ============================================================================

.if _DEMO_PART==_PART_TEST
; fx/sine-scroller.asm
sine_wave_table_no_adr:
    .skip SineScroller_TableSize*4
.endif

; ============================================================================

.if _DEMO_PART==_PART_DONUT

; ====================================
; TORUS WITH REGULAR DRAW ORDER
; ====================================

; fx/scene-3d.asm
; !VERTEX AND NORMAL ARRAYS MUST BE CONSECUTIVE!

mesh_torus_verts_no_adr:
    .skip MeshTorus_NumVerts * VECTOR3_SIZE

; NB. Must follow verts!  <=== I'm an idiot.
mesh_torus_normals_no_adr:
    .skip MeshTorus_NumFaces * VECTOR3_SIZE

; !VERTEX AND NORMAL ARRAYS MUST BE CONSECUTIVE!

mesh_torus_faces_no_adr:
    .skip MeshTorus_NumFaces * 4

mesh_torus_colours_no_adr:
    .skip MeshTorus_NumFaces
.p2align 2

; ====================================
; TORUS WITH FLIPPED DRAW ORDER
; ====================================

; !VERTEX AND NORMAL ARRAYS MUST BE CONSECUTIVE!

mesh_torus_flipped_verts_no_adr:
    .skip MeshTorus_NumVerts * VECTOR3_SIZE

; NB. Must follow verts!  <=== I'm an idiot.
mesh_torus_flipped_normals_no_adr:
    .skip MeshTorus_NumFaces * VECTOR3_SIZE

; !VERTEX AND NORMAL ARRAYS MUST BE CONSECUTIVE!

mesh_torus_flipped_faces_no_adr:
    .skip MeshTorus_NumFaces * 4

mesh_torus_flipped_colours_no_adr:
    .skip MeshTorus_NumFaces
.p2align 2

; ====================================
; TRANSFORMED VERTICES AND NORMALS
; ====================================

; !VERTEX AND NORMAL ARRAYS MUST BE CONSECUTIVE!

transformed_verts_no_adr:
    .skip OBJ_MAX_VERTS * VECTOR3_SIZE

; !VERTEX AND NORMAL ARRAYS MUST BE CONSECUTIVE!

;transformed_normals:       ; this is dynamic depending on num_verts.
    .skip OBJ_MAX_FACES * VECTOR3_SIZE

; !VERTEX AND NORMAL ARRAYS MUST BE CONSECUTIVE!

projected_verts_no_adr:
    .skip OBJ_MAX_VERTS * VECTOR2_SIZE

.if LibTriangle_EnableFutz
futz_table_no_adr:
    .skip 512*4
.endif

.endif

; ============================================================================

.if _DEMO_PART==_PART_SPACE
uv_table_unrolled_code_no_adr:
    .skip UV_Table_CodeSize
uv_table_code_max_no_adr:

; Sometimes steal space from the code buffer for additional textures. :)

uv_table_data_no_adr:
uv_texture_data_no_adr:
    .skip UV_Table_Size*3

.if UV_Texture_MaxSize*2 > UV_Table_Size*3
    .err "Not enough space for UV texture!"
.endif
.endif

; ============================================================================

.if AppConfig_UseArchieKlang
Generated_Samples_no_adr:
.skip AK_SMP_LEN
.p2align 2

AK_Temp_Buffer_no_adr:
.skip AK_TempBufferSize
.endif

; ============================================================================

.p2align 2
stack_no_adr:
    .skip AppConfig_StackSize
stack_base_no_adr:

; ============================================================================
; Palette buffers.
; ============================================================================

vidc_buffers_no_adr:
    .skip VideoConfig_ScreenBanks * 16 * 4

; ============================================================================
; Per FX BSS.
; ============================================================================

.if AppVsync_UseRasterMan   ; TODO: Shouldn't really use this def.
.p2align 2
.if _DEMO_PART==_PART_TEST
vidc_table_1_no_adr:
	.skip 256*4*4*2     ; 4 regs per scanline.
.else
vidc_table_1_no_adr:
	.skip 256*4*4       ; 4 regs per scanline.
.endif

memc_table_no_adr:
    .skip 256*2*4       ; 2 regs per scaline.
.endif

; ============================================================================
; Library BSS (must come last)
; ============================================================================

.include "lib/lib_bss.asm"

; ============================================================================
