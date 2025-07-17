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
    for x in range(0, options.size):
        v = options.min + (options.max-options.min) * x / options.size
        value = math.sqrt(v)

        if options.recip is True:
            value = 1.0 / value

        # print '[{0}] param={1} value={2} {3}'.format(x, v,value, options.recip)

        data.extend(word_to_bytes(int(options.scale * value)))

    save_file(data,options.output_path)
    print 'Wrote {0} bytes Arc data.'.format(len(data))


##########################################################################
##########################################################################

if __name__=='__main__':
    parser=argparse.ArgumentParser()

    parser.add_argument('-o',dest='output_path',metavar='FILE',help='output ARC data to %(metavar)s')
    parser.add_argument('min',type=int,help='min value')
    parser.add_argument('max',type=int,help='max value')
    parser.add_argument('size',type=int,help='number of entries')
    parser.add_argument('scale',type=int,help='scale values by')
    parser.add_argument('--recip',action='store_true',help='reciprocal')
    main(parser.parse_args())
