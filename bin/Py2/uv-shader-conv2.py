#!/usr/bin/python
import png,argparse,math

##########################################################################
##########################################################################

def save_file(data,path):
    if path is not None:
        with open(path,'wb') as f:
            f.write(''.join([chr(x) for x in data]))

##########################################################################
##########################################################################


def main(options):
    tw=options.tex_size or 256  # max u
    th=options.tex_size or 256  # max v

    u_data=[]
    v_data=[]
    shader_data=[]

    found_shader_data=False

    png_result=png.Reader(filename=options.rgb_path).asRGBA8()

    print 'Image width: {0} height: {1}'.format(png_result[0],png_result[1])

    for row in png_result[2]:
        for i in range(0,len(row),8):
            rgba0 = [row[i+0],row[i+1],row[i+2],row[i+3]]
            rgba1 = [row[i+4],row[i+5],row[i+6],row[i+7]]

            u0=rgba0[0]
            v0=rgba0[1]
            u1=rgba1[0]
            v1=rgba1[1]

            u_data.append(u0)       # u0
            v_data.append(v0)       # v0
            u_data.append(u1)       # u1
            v_data.append(v1)       # v1

            if not found_shader_data and (rgba0[2]!=0 or rgba1[2]!=0):
                print 'Found shader data in Blue channel.'
                found_shader_data=True

    if found_shader_data:
        png_result=png.Reader(filename=options.rgb_path).asRGBA8()
        blue_mask=False
        shift_warned=False

        for row in png_result[2]:
            for i in range(0,len(row),8):
                rgba0 = [row[i+0],row[i+1],row[i+2],row[i+3]]
                rgba1 = [row[i+4],row[i+5],row[i+6],row[i+7]]

                # Special case for Blue=0xff (blue mask = black):

                if not blue_mask and (rgba0[2]==0xff or rgba1[2]==0xff):
                    print 'Found special case blue mask (deprecated).'
                    blue_mask=True

                if blue_mask:
                    b0=0
                    b1=0
                    if rgba0[2]==0xff:
                        a0=4
                    else:
                        a0=0
                    if rgba1[2]==0xff:
                        a1=4
                    else:
                        a1=0
                else:
                    a0=rgba0[2] & 0xf
                    b0=rgba0[2] >> 4
                    a1=rgba1[2] & 0xf
                    b1=rgba1[2] >> 4

                # NB. Shift of zero (a=0) means 'just LUT' and expect add of zero (b=0).

                if a0==0 and b0!=0:
                    print 'WARNING: Found B value that has add without shift (0x{0:02x})'.format(rgba0[2])

                if a1==0 and b1!=0:
                    print 'WARNING: Found B value that has add without shift (0x{0:02x})'.format(rgba1[2])

                # NB. Shift of a>=4 means 'const colour' and b is the colour.

                if a0==5:   # hack for old asset
                    a0=4
                
                if a1==5:   # hack for old asset
                    a1=4

                if a0>4 and not shift_warned:
                    print 'WARNING: Found B value that has unexpected shift (0x{0:02x})'.format(rgba0[2])
                    shift_warned=True

                if a1>4 and not shift_warned:
                    print 'WARNING: Found B value that has unexpected shift (0x{0:02x})'.format(rgba1[2])

                max0=(0xf>>a0)+b0
                max1=(0xf>>a1)+b1

                if max0>0xf:
                    print 'WARNING: Found B value that could overflow (0x{0:02x})'.format(rgba0[2])

                if max1>0xf:
                    print 'WARNING: Found B value that could overflow (0x{0:02x})'.format(rgba1[2])

                # NB. Sparse texture shift of +4 now done in runtime code gen.

                shader_data.append((b0<<4)|a0)
                shader_data.append((b1<<4)|a1)

    # Concatenate the three data blocks into one file.
    u_data.extend(v_data)
    u_data.extend(shader_data)

    save_file(u_data,options.output_path)
    print 'Wrote {0} bytes Arc data.'.format(len(u_data))


##########################################################################
##########################################################################

if __name__=='__main__':
    parser=argparse.ArgumentParser()

    parser.add_argument('-o',dest='output_path',metavar='FILE',help='output ARC data to %(metavar)s')
    parser.add_argument('--sw',type=int,help='screen width')
    parser.add_argument('--sh',type=int,help='screen height')
    parser.add_argument('--tex-size',type=int,help='size of the texture')
    parser.add_argument('rgb_path',metavar='FILE',help='use %(metavar)s RGB png as [u,v] map')

    main(parser.parse_args())
