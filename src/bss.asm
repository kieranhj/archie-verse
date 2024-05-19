; ============================================================================
; BSS Segment (Uninitialised data, not stored in the exe.)
; ============================================================================

.bss
.p2align 6

; ============================================================================

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

.if 0   ; fx/scroller.asm
scroller_font_data_shifted_no_adr:
	.skip Scroller_Max_Glyphs * Scroller_Glyph_Height * 12 * 8
.endif

; ============================================================================

.if 0   ; fx/logo.asm
logo_data_shifted_no_adr:
	.skip Logo_Bytes * 7

logo_mask_shifted_no_adr:
	.skip Logo_Bytes * 7
.endif

; ============================================================================

.if 0   ; fx/starfield.asm
starfield_x_no_adr:
    .skip Starfield_Total * 4

starfield_y_no_adr:
    .skip Starfield_Total * 4
.endif

; ============================================================================

.if 0   ; fx/scene-3d.asm
transformed_verts_no_adr:
    .skip OBJ_MAX_VERTS * VECTOR3_SIZE

; !VERTEX AND NORMAL ARRAYS MUST BE CONSECUTIVE!

;transformed_normals:       ; this is dynamic depending on num_verts.
    .skip OBJ_MAX_FACES * VECTOR3_SIZE

; !VERTEX AND NORMAL ARRAYS MUST BE CONSECUTIVE!

projected_verts_no_adr:
    .skip OBJ_MAX_VERTS * VECTOR2_SIZE
.endif

; ============================================================================

.if 0   ; fx/scene-2d.asm
; All objects transformed to world space.
scene2d_object_buffer_no_adr:
    .skip Scene2D_ObjectBuffer_Size

scene2d_verts_buffer_no_adr:
    .skip Scene2D_MaxVerts * VECTOR2_SIZE
.endif

; ============================================================================

.if 0
; src/particles.asm
particles_array_no_adr:
    .skip Particle_SIZE * Particles_Max
.endif

; ============================================================================

.if 0 ; Push
; src/particle-grid.asm
particle_grid_array_no_adr:
    .skip ParticleGrid_SIZE * ParticleGrid_Max

; ============================================================================

; src/particle-dave.asm
particle_dave_array_no_adr:
    .skip ParticleDave_SIZE * ParticleDave_Max
.endif

; ============================================================================

.if 0
; src/balls.asm
balls_array_no_adr:
    .skip Ball_SIZE * Balls_Max
.endif

; ============================================================================

.if 0 ; Push
bits_logo_vert_array_no_adr:
    .skip VECTOR2_SIZE*520

tmt_logo_vert_array_no_adr:
    .skip VECTOR2_SIZE*520

prod_logo_vert_array_no_adr:
    .skip VECTOR2_SIZE*520
.endif

.skip Screen_Stride         ; BODGE IT.
text_pool_base_no_adr:
    .skip Text_Pool_PoolSize
text_pool_top_no_adr:

; ============================================================================

.if 0 ; Push
bits_owl_mode9_no_adr:
    .skip Bits_Owl_Mode9_Bytes

bits_owl_vert_array_no_adr:
    .skip VECTOR2_SIZE*520

greetz1_mode9_no_adr:
    .skip Screen_Bytes

greetz2_mode9_no_adr:
    .skip Screen_Bytes
.endif

; ============================================================================

.if 0
; src/particles.asm
additive_block_sprite_buffer_no_adr:
    .skip 8*8*8 ; width_in_bytes * rows * 8 pixel shifts

temp_sprite_ptrs_no_adr:
    .skip 4*8   ; sizeof(ptr) * 8 pixel shifts
.endif

; ============================================================================

scope_log_to_lin_no_adr:
    .skip 256

scope_dma_buffer_copy_no_adr:
    .skip Scope_MaxSamples*4

scope_dma_buffer_histories_no_adr:
    .skip Scope_TotalSamples*Scope_NumHistories
scope_dma_buffer_histories_top_no_adr:

; ============================================================================
; Library BSS (must come last)
; ============================================================================

.include "lib/lib_bss.asm"

; ============================================================================
