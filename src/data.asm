; ============================================================================
; DATA Segment.
; ============================================================================

.p2align 6
.data

; ===========================================================================

.if _DEMO_PART==_PART_TEST
; fx/sine-scroller.asm
razor_font_no_adr:
.incbin "build/razor-font.bin"
.endif

; ===========================================================================

.if _DEMO_PART==_PART_DONUT
; fx/scene-3d.asm
.include "src/data/three-dee/3d-meshes.asm"

three_logo_no_adr:
.incbin "build/three-logo.bin"

three_logo_pal_no_adr:
.include "build/three-logo.bin.asm"         ; prefer palettes as asm format now.

fine_font_no_adr:
.incbin "build/donut-font.bin"
.endif

; ===========================================================================

.if _DEMO_PART==_PART_SPACE
; fx/rotate.asm
; MODE 9 texture, 4 bpp x 2
.p2align 2
rotate_texture_no_adr:
.incbin "build/RocketIndex.lz4"         ; 16K

; fx/uv-tunnel.asm
; MODE 9 texture, 4 bpp x 2
.p2align 2
uv_cloud_texture_no_adr:
.incbin "build/CloudIndex.lz4"          ; 16K

.p2align 2
uv_disk_texture_no_adr:
.incbin "build/DiskIndex.lz4"           ; 16K

.p2align 2
uv_space_texture_no_adr:
.incbin "build/SpaceIndex.lz4"          ; 16K

.p2align 2
uv_space_512_texture_no_adr:
.incbin "build/SpaceIndex_512.lz4"      ; 64K

.p2align 2
uv_apollo_texture_no_adr:
.incbin "build/ApolloIndex.lz4"         ; 16K

.p2align 2
uv_apollo_384_texture_no_adr:
.incbin "build/ApolloIndex_384.lz4"     ; 48K

.p2align 2
uv_ship_texture_no_adr:
.incbin "build/ShipIndex.lz4"           ; 8K

.p2align 2
uv_warp_texture_no_adr:
.incbin "build/WarpIndex.lz4"           ; 2K

.p2align 2
uv_greets_texture_no_adr:
.incbin "build/GreetsIndex.lz4"         ; 8K

; ====================================

.p2align 2
uv_ship_map_no_adr:
.incbin "build/paul2_uv.lz4"          ; ship w/ shader

.p2align 2
uv_torus_map_no_adr:
.incbin "build/paul3_uv.lz4"          ; torus no shader

.p2align 2
uv_planet_map_no_adr:
.incbin "build/paul4_uv.lz4"          ; planet w/ shader

.p2align 2
uv_tunnel_map_no_adr:
.incbin "build/paul5_uv.lz4"          ; tunnel w/ shader

.p2align 2
uv_black_hole_map_no_adr:
.incbin "build/paul6_uv.lz4"          ; black hole w/ shader

.p2align 2
uv_reactor_panic_map_no_adr:
.incbin "build/paul7_uv.lz4"          ; reactor panic w/ shader

.p2align 2
uv_reactor_ok_map_no_adr:
.incbin "build/paul8_uv.lz4"          ; reactor core w/ shader

.p2align 2
uv_monolith_map_no_adr:
.incbin "build/paul9_uv.lz4"          ; monolith w/ shader

.p2align 2
uv_sun_map_no_adr:
.incbin "build/paul10_uv.lz4"          ; sun w/ shader

.p2align 2
uv_apollo_map_no_adr:
.incbin "build/paul11_uv.lz4"          ; apollo w/ shader

.p2align 2
uv_spin_map_no_adr:
.incbin "build/paul12_uv.lz4"          ; spinning ship w/ shader

.p2align 2
uv_warp_map_no_adr:
.incbin "build/paul13_uv.lz4"          ; warp w/ shader

.p2align 2
uv_greets_map_no_adr:
.incbin "build/paul14_uv.lz4"          ; greets w/ shader

.p2align 2
uv_wormhole_map_no_adr:
.incbin "build/paul15_uv.lz4"          ; wormhole w/ shader

.p2align 2
uv_fractal_map_no_adr:
.incbin "build/paul16_uv.lz4"          ; inv fractal w/ shader

.p2align 2
uv_relax_map_no_adr:
.incbin "build/paul17_uv.lz4"          ; greets w/ shader

; ====================================

.p2align 2
nasa_font_no_adr:
.incbin "build/nasa-font.lz4"

nasa_prop_no_adr:
.include "build/nasa-prop.asm"
.p2align 2
.endif

; ============================================================================
; Library data.
; ============================================================================

.include "lib/lib_data.asm"

; ============================================================================
; QTM Embedded.
; ============================================================================

.if AppConfig_UseQtmEmbedded
.p2align 2
QtmEmbedded_Base:
.if _LOG_SAMPLES
.incbin "data/riscos/tinyQ149t2,ffa"
.else
.incbin "data/riscos/tinyQTM149,ffa"
.endif
.endif

; ============================================================================
; Sequence data (RODATA Segment - ironically).
; ============================================================================

.p2align 2
seq_main_program:
.include "src/data/sequence-data.asm"
; TODO: Reinstate dynamic load.

; ============================================================================
; Music MOD (MUST BE LAST in DATA SEGMENT).
; ============================================================================

.if AppConfig_UseArchieKlang
External_Samples_no_adr:
.incbin "data/akp/Rhino2.mod.raw"
.p2align 2

music_mod_no_adr:
.incbin "build/music.mod.trk"

.else

.if !AppConfig_LoadModFromFile

.p2align 2
music_mod_no_adr:
.if _LOG_SAMPLES
.incbin "data/music/particles_15.002"
.else

; TODO: Move MOD to Makefile.
.if _DEMO_PART==_PART_SPACE
;.incbin "data/music/unused/Revision_house_06.mod"
;.incbin "data/music/Space-Trip-Runner.mod"
.incbin "data/music/space_trip_fatman_10.mod"
.endif
.if _DEMO_PART==_PART_DONUT
.incbin "data/music/ne7-hammer_on.mod"
.endif
.if _DEMO_PART==_PART_TEST
.incbin "build/music.mod"
.endif

.endif
.endif
.endif

; ============================================================================
; BSS IMMEDIATELY FOLLOWS.
; ============================================================================
