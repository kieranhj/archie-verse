; ============================================================================
; Scroll text text.
; ============================================================================

scroll_text_text_no_adr:
    .byte "The purveyors of minimalist demos proudly present a small 32kb announcetro "
.if !_DEBUG
    .byte "to celebrate the port of AmigaKlang to the Acorn Archimedes! "
    .byte "Virgill's Amiga soft synth generates 280+kb of sample data from just a few kb of code! "
    .byte "Now ported to ARM by kieran. TinyQTM player by Phoenix^Qtm. "
    .byte "Kieran greetz: Ate-Bit, AttentionWhore, CRTC, Inverse Phase, Logicoma, Loonies, ne7, Progen, Proxima, Pulpo Corrosivo, RiFT, Slipstream, SMFX, The Twitch Elite. "
    .byte "Virgill greetz: Haujobb, M.o.N, Rebels, S16, TEK, Rabenauge, Andromeda, Desire. "
    .byte "Rhino greetz: Spiny, Saga Musix, Pandur, Reflex, RC55, Hoffman, YM Rockerz. "
    .byte "And everyone at the party! :) "
.endif
    .byte 0 ; end.
.p2align 2
