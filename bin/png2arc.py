#!/usr/bin/python
import png,argparse,sys,math,arc

##########################################################################
##########################################################################

# Read 1 byte from our input file
def get_byte(file):
    # In Python 3, file.read(1) returns a bytes object, so ord() is still needed
    return file.read(1)[0] # Changed: access the first byte of the bytes object

def save_file(data,path):
    if path is not None:
        with open(path,'wb') as f:
            f.write(bytes(data)) # Changed: write bytes directly from a list of integers

##########################################################################
##########################################################################

def get_palette(boxed_row_flat_pixel, mask_rgba):
    palette = []
    # In Python 3, iterators from png.Reader.asRGBA8() need to be converted to list for direct indexing
    for row_iter in boxed_row_flat_pixel:
        row = list(row_iter) # Changed: Convert row iterator to a list
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
    for i in range(len(palette)): # Changed: Iterate up to the actual length of the palette
        col = palette[i]
        dist = (rgb[0]-col[0])*(rgb[0]-col[0]) + (rgb[1]-col[1])*(rgb[1]-col[1]) + (rgb[2]-col[2])*(rgb[2]-col[2])
        if dist < closest_dist:
            closest_idx = i
            closest_dist = dist

    return closest_idx

#def find_closest_match(palette, rgb):
#    """
#    Finds the index of the color in the palette that is closest to the given RGB color.
#    Closeness is determined by the squared Euclidean distance.
#
#    Args:
#        palette (list): A list of RGB color tuples or lists, e.g., [(r, g, b), ...].
#        rgb (tuple): The target RGB color as a tuple or list, e.g., (r, g, b).
#
#    Returns:
#        int: The index of the closest color in the palette.
#    """
    # Use enumerate to get both the index and the color from the palette.
    # The key function calculates the squared Euclidean distance between the
    # target RGB and each color in the palette.
#    closest_idx, _ = min(
#        enumerate(palette),
#        key=lambda item: sum((c1 - c2)**2 for c1, c2 in zip(rgb, item[1]))
#    )
#    return closest_idx

##########################################################################
##########################################################################

def to_box_row_palette_indices(boxed_row_flat_pixel, palette, mask_rgba):
    pidxs = []
    # In Python 3, iterators from png.Reader.asRGBA8() need to be converted to list for direct indexing
    for row_iter in boxed_row_flat_pixel:
        row = list(row_iter) # Changed: Convert row iterator to a list
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
                except ValueError: # Changed: catch ValueError specifically for .index()
                    idx = find_closest_match(palette, rgba)
            pidxs[-1].append(idx)

    return pidxs

def to_box_row_mask_pixels(boxed_row_flat_pixel, mask_rgba):
    midxs = []
    # In Python 3, iterators from png.Reader.asRGBA8() need to be converted to list for direct indexing
    for row_iter in boxed_row_flat_pixel:
        row = list(row_iter) # Changed: Convert row iterator to a list
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
    if options.mode != 9 and options.mode != 4 and options.mode != 12 and options.mode != 0:
        print('FATAL: invalid mode: {0}'.format(options.mode), file=sys.stderr) # Changed: print is a function
        sys.exit(1)

    if options.mode == 4 or options.mode == 0:
        pixels_per_byte=8
        pack=arc.pack_1bpp
        max_pal=2
    else:
        pixels_per_byte=2
        pack=arc.pack_4bpp
        max_pal=16

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
    print('Source image width: {0} height: {1}'.format(src_width,src_height)) # Changed: print is a function

    if options.mask_colour is not None:
        mask = [options.mask_colour >> 24, (options.mask_colour >> 16) & 0xff, (options.mask_colour >> 8) & 0xff, options.mask_colour & 0xff]
        print('Using mask colour: {0}'.format(mask)) # Changed: print is a function
    else:
        mask = None

    # The png_result[2] (rows iterator) can only be consumed once.
    # We need to convert it to a list if we want to iterate over it multiple times or pass it around.
    # Let's convert it here once to avoid re-reading the file multiple times for palette and then pixels.
    all_rows = list(png_result[2]) # Changed: Convert iterator to a list

    palette = get_palette(all_rows, mask) # Changed: pass the list of rows
    print('Found {0} palette entries.'.format(len(palette))) # Changed: print is a function
    
    if len(palette) > max_pal:
        print('FATAL: too many colours: {0}'.format(len(palette)), file=sys.stderr) # Changed: print is a function
        sys.exit(1)

    if options.is_index:
        palette=[]
        for i in range(max_pal):
            palette.append([i, i, i, 255])

    if options.use_palette is not None:
        # Open palette binary file.
        with open(options.use_palette, 'rb') as palette_file: # Changed: use 'with' statement for file handling
            palette=[]
            for i in range(max_pal):
                r = get_byte(palette_file)
                g = get_byte(palette_file)
                b = get_byte(palette_file)
                a = get_byte(palette_file)
                palette.append([r, g, b, 255])
    else:
        # Sort palette by intensity.
        palette.sort(key=lambda e: e[0]*e[0]+e[1]*e[1]+e[2]*e[2])

        if len(palette) < max_pal:
            # Prefer entry 0 to be black, if not already.
            if palette[0] != [0, 0, 0, 255]:
                palette.insert(0, [0, 0, 0, 255])

            # Pad end of palette with white if MODE 9:
            if options.mode == 9 or options.mode == 12:
                while len(palette) < max_pal:
                    palette.append([255, 255, 255, 255])

    if options.loud:
        print(palette) # Changed: print is a function

    # Use the already converted `all_rows` list
    pixels = to_box_row_palette_indices(all_rows, palette, mask) # Changed: pass the list of rows

    out_width=src_width/step_x if step_x != 0 else src_width # Added check for division by zero
    out_height=src_height/step_y if step_y != 0 else src_height # Added check for division by zero
    # Ensure integer division for output dimensions, as they represent pixel counts
    out_width = int(out_width) 
    out_height = int(out_height)
    print('Output image width: {0} height: {1}'.format(out_width,out_height)) # Changed: print is a function

    pixel_data=[]
    assert(len(pixels)==src_height)
    for y in range(0,src_height,step_y):
        row=pixels[y]
        assert(len(row)==src_width)
        for x in range(0,src_width,int(pixels_per_byte*step_x)):
            xs=[]
            if options.double_pixels:
                for p in range(0,int(pixels_per_byte/2)): # Changed: ensure int for range
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
    print('Wrote {0} bytes Arc data.'.format(len(pixel_data))) # Changed: print is a function

    if options.mask_path is not None:
        # Re-read the PNG or use the stored all_rows if the data structure allows it.
        # For simplicity and to match original behavior of re-reading:
        png_result=png.Reader(filename=options.input_path).asRGBA8()
        all_rows_mask = list(png_result[2]) # Changed: Convert iterator to a list
        pixel_masks = to_box_row_mask_pixels(all_rows_mask, mask) # Changed: pass the list of rows
        mask_data=[]
        assert(len(pixel_masks)==src_height)
        for y in range(0,src_height,step_y):
            row=pixel_masks[y]
            assert(len(row)==src_width)
            for x in range(0,src_width,int(pixels_per_byte*step_x)): # Changed: ensure int for range
                xs=[]
                if options.double_pixels:
                    for p in range(0,int(pixels_per_byte/2)): # Changed: ensure int for range
                        xs.append(row[x+p])
                        xs.append(row[x+p])
                else:
                    for p in range(0,pixels_per_byte):
                        xs.append(row[x+p])
                assert len(xs)==pixels_per_byte
                mask_data.append(pack(xs))

        assert(len(mask_data)==out_width*out_height/pixels_per_byte)
        save_file(mask_data,options.mask_path)
        print('Wrote {0} bytes MASK data.'.format(len(mask_data))) # Changed: print is a function

    if options.palette_path is not None:
        pal_data=[]
        for p in palette:
            warned=False
            for i in range(0,3):
                # Integer division issue: in Python 2, 0x0f and 0xf0 were integers.
                # Here, the bitwise operations are fine as integers.
                if (p[i] & 0x0f) != 0 and not warned:
                    if options.loud:
                        print('Warning: lost precision for colour',p) # Changed: print is a function
                    warned=True
                pal_data.append(p[i] & 0xf0)
            pal_data.append(0)
        assert(len(pal_data)==4*len(palette))
        save_file(pal_data,options.palette_path)
        print('Wrote {0} bytes palette data.'.format(len(pal_data))) # Changed: print is a function

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
                            print('Warning: lost precision for colour',p) # Changed: print is a function
                        warned=True
                reg=(r<<26)|(p[0]>>4)|(p[1]&0xf0)|((p[2]&0xf0)<<4) # Changed: Added parentheses for clarity in bitwise operations
                f.write('\t.long 0x{0:08x}\n'.format(reg))           
                r+=1

        print('Wrote palette data as VIDC regs to {0}.'.format(options.vidc_path)) # Changed: print is a function


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
