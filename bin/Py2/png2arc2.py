#!/usr/bin/python
import png,argparse,sys,math,arc

##########################################################################
##########################################################################

# Read 1 byte from our input file
def get_byte(file):
    return ord(file.read(1))

def save_file(data,path):
    if path is not None:
        with open(path,'wb') as f:
            f.write(''.join([chr(x) for x in data]))

##########################################################################
##########################################################################

def get_palette(boxed_row_flat_pixel, mask_rgba):
    palette = []
    for row in boxed_row_flat_pixel:
        for i in range(0,len(row),4):
            rgba = [row[i+0],row[i+1],row[i+2],row[i+3]]

            if mask_rgba is not None and rgba == mask_rgba:
                continue

            if rgba not in palette:
                palette.append(rgba)
            
    return palette

def find_closest_match(palette, rgb):
    # Do this the lame non-Pythonic way. I'm sure this could be a single line blah blah.
    closest_idx = -1
    closest_dist = 256*256
    for i in range(16):
        col = palette[i]
        dist = (rgb[0]-col[0])*(rgb[0]-col[0]) + (rgb[1]-col[1])*(rgb[1]-col[1]) + (rgb[2]-col[2])*(rgb[2]-col[2])
        if dist < closest_dist:
            closest_idx = i
            closest_dist = dist

    return closest_idx

##########################################################################
##########################################################################

def to_box_row_palette_indices(boxed_row_flat_pixel, palette, mask_rgba):
    pidxs = []
    for row in boxed_row_flat_pixel:
        pidxs.append([])
        for i in range(0,len(row),4):
            rgba = [row[i+0],row[i+1],row[i+2],row[i+3]]
            if mask_rgba is not None and rgba == mask_rgba:
                idx = 0
            else:
                # Prefer towards the end of the palette?
                # Probably unless zero?
                try:
                    idx = len(palette) - palette[::-1].index(rgba) - 1
                except:
                    idx = find_closest_match(palette, rgba)
            pidxs[-1].append(idx)

    return pidxs

def to_box_row_mask_pixels(boxed_row_flat_pixel, mask_rgba):
    midxs = []
    for row in boxed_row_flat_pixel:
        midxs.append([])
        for i in range(0,len(row),4):
            rgba = [row[i+0],row[i+1],row[i+2],row[i+3]]
            if rgba == mask_rgba:
                idx = 0
            else:
                idx = 0xf     # TODO: Fixed mask index for now.
            midxs[-1].append(idx)
    return midxs

##########################################################################
##########################################################################

def main(options):
    # Only support MODE 9 for now. MODE 13 coming later.
    if options.mode != 9 and options.mode != 4:
        print>>sys.stderr,'FATAL: invalid mode: %d'%options.mode
        sys.exit(1)

    if options.mode == 4:
        pixels_per_byte=8
        pack=arc.pack_1bpp
    else:
        pixels_per_byte=2
        pack=arc.pack_4bpp

    step_x=1
    step_y=1
    if options.x2:
        step_x=2
        step_y=2

    if options.double_pixels:
        step_x=0.5

    png_result=png.Reader(filename=options.input_path).asRGBA8()

    src_width=png_result[0]
    src_height=png_result[1]
    print 'Source image width: {0} height: {1}'.format(src_width,src_height)

    if options.mask_colour is not None:
        mask = [options.mask_colour >> 24, (options.mask_colour >> 16) & 0xff, (options.mask_colour >> 8) & 0xff, options.mask_colour & 0xff]
        print 'Using mask colour: {0}'.format(mask)
    else:
        mask = None

    palette = get_palette(png_result[2], mask)
    print 'Found {0} palette entries.'.format(len(palette))
    
    if len(palette) > 16:
        print>>sys.stderr,'FATAL: too many colours: %d'%len(palette)
        sys.exit(1)

    if options.is_index:
        palette=[]
        for i in range(16):
            palette.append([i, i, i, 255])

    if options.use_palette is not None:
        # Open palette binary file.
        palette_file = open(options.use_palette, 'rb')

        palette=[]
        for i in range(16):
            r = get_byte(palette_file)
            g = get_byte(palette_file)
            b = get_byte(palette_file)
            a = get_byte(palette_file)
            palette.append([r, g, b, 255])
    else:
        # Sort palette by intensity.
        palette.sort(key=lambda e: e[0]*e[0]+e[1]*e[1]+e[2]*e[2])

        if len(palette) < 16:
            # Prefer entry 0 to be black, if not already.
            if palette[0] != [0, 0, 0, 255]:
                palette.insert(0, [0, 0, 0, 255])

            # Pad end of palette with white if MODE 9:
            if options.mode == 9:
                while len(palette) < 16:
                    palette.append([255, 255, 255, 255])

    if options.loud:
        print(palette)

    # Reading the file again seems wrong?
    png_result=png.Reader(filename=options.input_path).asRGBA8()
    pixels = to_box_row_palette_indices(png_result[2], palette, mask)

    out_width=src_width/step_x
    out_height=src_height/step_y
    print 'Output image width: {0} height: {1}'.format(out_width,out_height)

    pixel_data=[]
    assert(len(pixels)==src_height)
    for y in range(0,src_height,step_y):
        row=pixels[y]
        assert(len(row)==src_width)
        for x in range(0,src_width,int(pixels_per_byte*step_x)):
            xs=[]
            if options.double_pixels:
                for p in range(0,pixels_per_byte/2):
                    xs.append(row[x+p])
                    if options.as_bytes:
                        xs.append(0)
                    else:
                        xs.append(row[x+p])
            else:
                for p in range(0,pixels_per_byte):
                    xs.append(row[x+p])
            assert len(xs)==pixels_per_byte
            pixel_data.append(pack(xs))

    assert(len(pixel_data)==out_width*out_height/pixels_per_byte)
    save_file(pixel_data,options.output_path)
    print 'Wrote {0} bytes Arc data.'.format(len(pixel_data))

    if options.mask_path is not None:
        # Reading the file again seems wrong?
        png_result=png.Reader(filename=options.input_path).asRGBA8()
        pixel_masks = to_box_row_mask_pixels(png_result[2], mask)
        mask_data=[]
        assert(len(pixel_masks)==src_height)
        for y in range(0,src_height,step_y):
            row=pixel_masks[y]
            assert(len(row)==src_width)
            for x in range(0,src_width,pixels_per_byte*step_x):
                xs=[]
                if options.double_pixels:
                    for p in range(0,pixels_per_byte/2):
                        xs.append(row[x+p])
                        xs.append(row[x+p])
                else:
                    for p in range(0,pixels_per_byte):
                        xs.append(row[x+p])
                assert len(xs)==pixels_per_byte
                mask_data.append(pack(xs))

        assert(len(mask_data)==out_width*out_height/pixels_per_byte)
        save_file(mask_data,options.mask_path)
        print 'Wrote {0} bytes MASK data.'.format(len(mask_data))

    if options.palette_path is not None:
        pal_data=[]
        for p in palette:
            warned=False
            for i in range(0,3):
                if (p[i] & 0x0f) != 0 and not warned:
                    if options.loud:
                        print 'Warning: lost precision for colour',p
                    warned=True
                pal_data.append(p[i] & 0xf0)
            pal_data.append(0)
        assert(len(pal_data)==4*len(palette))
        save_file(pal_data,options.palette_path)
        print 'Wrote {0} bytes palette data.'.format(len(pal_data))

    if options.vidc_path is not None:
        pal_data=[]
        with open(options.vidc_path,'w') as f:
            r=0
            f.write('; Palette as VIDC registers from input file: {0}\n'.format(options.input_path))
            for p in palette:
                warned=False
                for i in range(0,3):
                    if (p[i] & 0x0f) != 0 and not warned:
                        if options.loud:
                            print 'Warning: lost precision for colour',p
                        warned=True
                reg=(r<<26)|p[0]>>4|p[1]&0xf0|(p[2]&0xf0)<<4
                f.write('\t.long 0x{0:08x}\n'.format(reg))           
                r+=1

        print 'Wrote palette data as VIDC regs to {0}.'.format(options.vidc_path)


##########################################################################
##########################################################################

if __name__=='__main__':
    parser=argparse.ArgumentParser()

    parser.add_argument('-o',dest='output_path',metavar='FILE',help='output ARC data to %(metavar)s')
    parser.add_argument('-p',dest='palette_path',metavar='FILE',help='output palette data to %(metavar)s')
    parser.add_argument('-m',dest='mask_path',metavar='FILE',help='output mask data to %(metavar)s')
    parser.add_argument('--loud',action='store_true',help='display warnings')
    parser.add_argument('--x2',action='store_true',help='source image has 2x dimensions')
    parser.add_argument('--double-pixels',action='store_true',help='double pixels in x')
    parser.add_argument('--as-bytes',action='store_true',help='store values as bytes regardless of bitdepth')
    parser.add_argument('--mask-colour',dest='mask_colour',default=None,type=lambda x: int(x,0),help='RGBA colour used as mask.')
    parser.add_argument('--use-palette',dest='use_palette',metavar='FILE',help='use palette binary data from %(metavar)s')
    parser.add_argument('--is-index',action='store_true',help='source image uses index values in RGB')
    parser.add_argument('--vidc-regs',dest='vidc_path',metavar='FILE',help='output palette data to %(metavar)s as vidc reg')
    parser.add_argument('input_path',metavar='FILE',help='load PNG data from %(metavar)s')
    parser.add_argument('mode',type=int,help='screen mode')
    main(parser.parse_args())
