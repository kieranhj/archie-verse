#!/usr/bin/python
import argparse,sys,math,arc

##########################################################################
##########################################################################

def save_file(data,path):
    if path is not None:
        with open(path,'wb') as f:
            f.write(''.join([chr(x) for x in data]))

def word_to_bytes(value):
    return [value & 0xff, (value >> 8) & 0xff, (value >> 16) & 0xff, (value >> 24) & 0xff]

##########################################################################
##########################################################################

def main(options):
    data=[]
    for x in range(0,options.size):
        angle = 2 * math.pi * x / options.size
        value = math.sin(angle) * options.scale

        data.extend(word_to_bytes(int(value)))

    assert(len(data)==options.size*4)
    save_file(data,options.output_path)
    print 'Wrote {0} bytes Arc data.'.format(len(data))


##########################################################################
##########################################################################

if __name__=='__main__':
    parser=argparse.ArgumentParser()

    parser.add_argument('-o',dest='output_path',metavar='FILE',help='output ARC data to %(metavar)s')
    parser.add_argument('size',type=int,help='size of the table')
    parser.add_argument('scale',type=int,help='scale values by')
    main(parser.parse_args())
