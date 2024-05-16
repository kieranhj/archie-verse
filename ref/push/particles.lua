-- Scripting for Archie checkerboard engine.

exportFile = nil -- io.open("lua_frames.txt", "w")
-- exportFile:setvbuf("no")

exportBin = nil -- io.open("lua_frames.bin", "wb")
-- exportBin:setvbuf("no")

debugFile=io.open("lua_debug.txt", "a")
debugFile:setvbuf("no")
io.output(debugFile)

framesPerRow=4*50/60.0
rowsPerPattern=64
framesPerPattern=(framesPerRow*rowsPerPattern)

BLACK={r=0,g=0,b=0}
WHITE={r=0xf,g=0xf,b=0xf}

PINK={r=0xf,g=0x8,b=0x8}
GREEN={r=0x8,g=0xf,b=0x4}
ORANGE={r=0xf,g=0xa,b=0x0}
PURPLE={r=0xc,g=0x6,b=0xf}
GREY={r=0x8,g=0x8,b=0x8}
BLUE={r=0x0,g=0x6,b=0xf}
AQUA={r=0x0,g=0xe,b=0xf}
YELLOW={r=0xf,g=0xf,b=0xa}
RED={r=0xf,g=0x0,b=0x6}

function get_pattern(frameNo)
    return frameNo // (framesPerRow * rowsPerPattern)
end

function get_row(frameNo)
    return (frameNo % (framesPerRow * rowsPerPattern)) // framesPerRow
end

emitter={pps=80,pos={x=0.0,y=10.0,z=0.0},dir={x=0.0,y=0.0,z=0.0},life=255,colour=6,radius=5.0}

f=-1
lastFrame=-1
lastPlaying=-1
function TIC()

    df=frames()-f

 if (df~=0) then
    f=frames()

    -- update emitter here.
    emitter.pos.x = 100.0 * math.sin(f/60)
    emitter.pos.y = 128.0 + 60.0 * math.cos(f/80)
    emitter.colour = (emitter.colour + 1) & 15
    emitter.radius = 8.0 + 6 * math.sin(f/10)
    emitter.dir.x = 2.0 * math.sin(f/100)
    emitter.dir.y = 1.0 + 5.0 * math.random() --0.0 * math.cos(f/100)
 end

 if (f~=lastFrame) then
    if (f>lastFrame) then
        if (exportFile) then exportFrame(exportFile) end
        if (exportBin) then exportFrameBin(exportBin) end
    end
    lastFrame=f
 end

 if (is_running()~=lastPlaying) then
    lastPlaying=is_running()
    if (exportFile) then exportFile:flush() end
    if (exportBin) then exportBin:flush() end
 end
end

function get_track_value(track_no)
 -- io.write(string.format("track=%d\n",track_no))
 if (track_no==0) then return 50.0/emitter.pps end
 if (track_no==1) then return emitter.pos.x end
 if (track_no==2) then return emitter.pos.y end
 if (track_no==3) then return emitter.pos.z end
 if (track_no==4) then return emitter.dir.x end
 if (track_no==5) then return emitter.dir.y end
 if (track_no==6) then return emitter.dir.z end
 if (track_no==7) then return emitter.life end
 if (track_no==8) then return emitter.colour end
 if (track_no==9) then return emitter.radius end

 return -1
end

function exportFrame(handle)
    handle:write(string.format("frame=%d\n", f))
end

function writeShort(handle, short)
    low_byte = short & 0xff
    high_byte = (short >> 8) & 0xff
    handle:write(string.format("%c%c",low_byte,high_byte))
end

function exportFrameBin(handle)
    -- writeShort(handle, f)
end
