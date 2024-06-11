; ============================================================================
; Scroll text text.
; ============================================================================

scroll_text_text_no_adr:
    ; NB. Can't use control code as first char because <lazy>.
    .byte "The purveyors of minimalist demos ",0xf4,"proudly present a small 32kb announcetro "
.if !_DEBUG
    .byte "to celebrate the port of AmigaKlang to the Acorn Archimedes!",0x94
    .byte 0xf4, "Virgill's soft synth generates 280+kb of sample data from just a few kb of code! ",0x94
    .byte "Now ported to ARM by kieran. TinyQTM player by Phoenix^Qtm."
    .byte 0xd0 ; full wipe
    .byte 0xf2, "Kieran greetz ", 0xf8, "Ate-Bit, AttentionWhore, CRTC, Inverse Phase, Logicoma, Loonies, ne7, Progen, Proxima, Pulpo Corrosivo, RiFT, Slipstream, SMFX, The Twitch Elite. "
    .byte 0xa8,0xf2, "Virgill greetz ", 0xf8, "Haujobb, M.o.N, Rebels, S16, TEK, Rabenauge, Andromeda, Desire. "
    .byte 0xa8,0xf2, "Rhino greetz ", 0xf8, "Spiny, Saga Musix, Pandur, Reflex, RC55, Hoffman, YM Rockerz. "
    .byte 0xf4,0xa8, "And everyone at the party! :)",0xd0
.endif
    .byte 0 ; end.
.p2align 2
