#!/usr/bin/python
import png,argparse,sys,math,arc
import struct

##########################################################################
##########################################################################

def save_file(data,path):
    if path is not None:
        with open(path,'wb') as f:
            f.write(''.join([chr(x) for x in data]))

##########################################################################
##########################################################################

def get_palette(boxed_row_flat_pixel):
    palette = []
    for row in boxed_row_flat_pixel:
        for i in range(0,len(row),4):
            rgb = [row[i+0],row[i+1],row[i+2]]
            if rgb not in palette:
                palette.append(rgb)
            
    return palette

##########################################################################
##########################################################################

def to_box_row_palette_indices(boxed_row_flat_pixel, palette):
    pidxs = []
    for row in boxed_row_flat_pixel:
        pidxs.append([])
        for i in range(0,len(row),4):
            rgb = [row[i+0],row[i+1],row[i+2]]
            idx = palette.index(rgb)
            pidxs[-1].append(idx)

    return pidxs

##########################################################################
##########################################################################

def main(options):
    # Only support MODE 9 for now. MODE 13 coming later.
    if options.mode != 9:
        print>>sys.stderr,'FATAL: invalid mode: %d'%options.mode
        sys.exit(1)

    pixels_per_byte=2
    pack=arc.pack_4bpp

    # TODO: Turn step into an option if actually useful.
    step_x=1
    step_y=1
    if options.x2:
        step_x=2
        step_y=2

    png_result=png.Reader(filename=options.input_path).asRGBA8()

    src_width=png_result[0]
    src_height=png_result[1]
    print 'Source image width: {0} height: {1}'.format(src_width,src_height)

    palette = get_palette(png_result[2])
    print 'Found {0} palette entries.'.format(len(palette))
    
    if len(palette) > 16:
        print>>sys.stderr,'FATAL: too many colours: %d'%len(palette)
        sys.exit(1)

    # Sort palette by intensity.
    palette.sort(key=lambda e: e[0]*e[0]+e[1]*e[1]+e[2]*e[2])

    if len(palette) < 16:
        # Prefer entry 0 to be black, if not already.
        if palette[0] != [0, 0, 0]:
            palette.insert(0, [0, 0, 0])

        # Pad end of palette with white:
        while len(palette) < 16:
            palette.append([255, 255, 255])

    # Reading the file again seems wrong?
    png_result=png.Reader(filename=options.input_path).asRGBA8()
    pixels = to_box_row_palette_indices(png_result[2], palette)

    out_width=src_width/step_x
    out_height=src_height/step_y
    print 'Output sprite width: {0} height: {1}'.format(out_width,out_height)

    pixel_data=[]
    assert(len(pixels)==src_height)
    for y in range(0,src_height,step_y):
        row=pixels[y]
        assert(len(row)==src_width)
        for x in range(0,src_width,pixels_per_byte*step_x):
            xs=[]
            for p in range(0,pixels_per_byte):
                xs.append(row[x+p])
            assert len(xs)==pixels_per_byte
            pixel_data.append(pack(xs))

    assert(len(pixel_data)==out_width*out_height/pixels_per_byte)
    print 'Converted {0} bytes Arc sprite data.'.format(len(pixel_data))

    # Write sprite file.
    if options.output_path is not None:
        with open(options.output_path,'wb') as f:
            # TODO: Hardcoded for 32x16 sprite for now!!
            width_in_words = out_width / (4 * pixels_per_byte)
            sprite_bytes = width_in_words * 4 * out_height
            palette_bytes = len(palette) * 8    # Two words per entry.
            file_cb_bytes = 16                  # Weirdly skips first word when saving...
            sprite_cb_bytes = 44

            # Write File Control Block.
            f.write(struct.pack('L', 1))        # Number of sprites.
            f.write(struct.pack('L', file_cb_bytes))     # Byte offset to first sprite.
            f.write(struct.pack('L', file_cb_bytes + sprite_cb_bytes + palette_bytes + sprite_bytes))    # Byte offset to first free word.

            # TODO: Make a proper ArcSprite class etc. etc.
            
            # Write Sprite.
            # Write sprite control block.
            f.write(struct.pack('L', sprite_cb_bytes + palette_bytes + sprite_bytes))   # Byte offset to next sprite.
            f.write(struct.pack('12s', options.sprite_name))   # Sprite name padded with 0's.
            f.write(struct.pack('L', width_in_words - 1))       # Width in words -1.
            f.write(struct.pack('L', out_height - 1))           # Height in scanlines -1.

            f.write(struct.pack('L', 0))       # First bit used (left end of row).
            # TOOD: Handle sprites not integer mutiples of words.
            f.write(struct.pack('L', 31))      # Last bit used (right end of row).
            f.write(struct.pack('L', sprite_cb_bytes + palette_bytes))  # Byte offset to sprite data.
            f.write(struct.pack('L', sprite_cb_bytes + palette_bytes))  # Byte offset to transparency mask (if any).
            f.write(struct.pack('L', options.mode))     # Mode sprite was defined in.
            
            # Write sprite palette.
            for p in palette:
                colour_val = p[0] << 8 | p[1] << 16 | p[2] << 24
                f.write(struct.pack('L', colour_val))
                f.write(struct.pack('L', colour_val))

            # Write sprite data.
            f.write(bytearray(pixel_data))


##########################################################################
##########################################################################

if __name__=='__main__':
    parser=argparse.ArgumentParser()

    parser.add_argument('-o',dest='output_path',metavar='FILE',help='output ARC sprite file %(metavar)s')
    parser.add_argument('--name',action='store',dest='sprite_name',default='sprite',help='sprite name')
    parser.add_argument('--loud',action='store_true',help='display warnings')
    parser.add_argument('--x2',action='store_true',help='source image has 2x dimensions')
    parser.add_argument('input_path',metavar='FILE',help='load PNG data from %(metavar)s')
    parser.add_argument('mode',type=int,help='screen mode')
    main(parser.parse_args())
