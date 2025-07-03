# modparse.py
# Parse Amiga MOD files for processing.
# Eventually to split 8ch MODs into 4ch MOD + 4 event tracks.

import argparse
import sys
import os
import filecmp

MOD_TYPES=['M.K.', 'M!K!', '4CHN', '6CHN', '8CHN', 'FLT4', 'FLT8']
NUM_CHANNELS=[4, 4, 4, 6, 8, 4, 8]

class ModParser:
    def __init__(self, mod_file,) -> None:
        self._mod_file = mod_file

    def Parse(self):
        f=self._mod_file
        f.seek(1080)        # MOD type string (maybe)
        self._mod_type=f.read(4).decode('ascii')

        if self._mod_type not in MOD_TYPES:
            print(f"MOD type: '{self._mod_type} is not matched, assuming 15 samples.")
            self._num_samples=15        # default
            self._num_channels=4        # default
        else:
            self._num_samples=31
            self._num_channels=NUM_CHANNELS[MOD_TYPES.index(self._mod_type)]
        
        print(f"MOD type: '{self._mod_type}'")
        print(f"Number of channels: {self._num_channels}")
        print(f"Number of samples: {self._num_samples}")

        f.seek(0)
        self._title=f.read(20).decode().rstrip('\x00')

        print(f"MOD title: '{self._title}'")

        self._samples=[]    # list

        for s in range(0,self._num_samples):
            sample={}       # dict
            sample['name']=f.read(22).decode('ascii').rstrip('\x00')
            sample['len']=int.from_bytes(f.read(2),'big')
            sample['finetune']=int.from_bytes(f.read(1),'big')
            sample['vol']=int.from_bytes(f.read(1),'big')
            sample['rep_offset']=int.from_bytes(f.read(2),'big')
            sample['rep_len']=int.from_bytes(f.read(2),'big')
            self._samples.append(sample)

            if g_verbose:
                print(f"Sample #{s}: {sample}")

        self._sequence_len=int.from_bytes(f.read(1),'big')
        self._legacy_byte=int.from_bytes(f.read(1),'big')

        print(f"Sequence length: {self._sequence_len}")

        self._sequence=[]
        self._num_patterns=0
        for p in range(0,128):
            pattern_no=int.from_bytes(f.read(1),'big')
            if pattern_no>self._num_patterns:
                self._num_patterns=pattern_no
            self._sequence.append(pattern_no)    # pattern no.
        self._num_patterns+=1

        if g_verbose:
            print(f"Sequence: {self._sequence}")

        assert(f.read(4).decode()==self._mod_type)

        print(f"Total patterns: {self._num_patterns}")

        self._patterns=[]
        for p in range(0,self._num_patterns):
            pattern=[]
            for r in range(0,64):
                row=[]
                for c in range(0,self._num_channels):
                    word1=int.from_bytes(f.read(2),'big')
                    word2=int.from_bytes(f.read(2),'big')
                    note={}
                    note['sample']=(word1&0xf000)>>8|(word2&0xf000)>>12
                    note['period']=word1 & 0x0fff
                    note['effect']=word2 & 0x0fff
                    row.append(note)
                pattern.append(row)
            self._patterns.append(pattern)
            if g_verbose and p==0:
                print(f"Pattern #{p}: {pattern}")

        self._sample_data=[]
        for s in range(0,self._num_samples):
            self._sample_data.append(f.read(self._samples[s]['len']*2))

        print(f"Read {f.tell()} bytes total.")

    # Write out MOD file - should be byte-for-byte identical.
    def WriteMod(self, mod_file):
        mod_file.write(self._title.ljust(20, '\x00').encode('ascii'))

        for sample in self._samples:
            mod_file.write(sample['name'].ljust(22, '\x00').encode('ascii'))
            mod_file.write(sample['len'].to_bytes(2, 'big'))
            mod_file.write(sample['finetune'].to_bytes(1, 'big'))
            mod_file.write(sample['vol'].to_bytes(1, 'big'))
            mod_file.write(sample['rep_offset'].to_bytes(2, 'big'))
            mod_file.write(sample['rep_len'].to_bytes(2, 'big'))
        
        mod_file.write(self._sequence_len.to_bytes(1, 'big'))
        mod_file.write(self._legacy_byte.to_bytes(1, 'big'))
        
        for p in self._sequence:
            mod_file.write(p.to_bytes(1, 'big'))

        if self._num_samples !=15 :
            mod_file.write(self._mod_type.encode('ascii'))

        for pattern in self._patterns:
            for row in pattern:
                for note in row:
                    word1=note['period']|(note['sample']&0xf0)<<8
                    word2=note['effect']|(note['sample']&0x0f)<<12
                    mod_file.write(word1.to_bytes(2, 'big'))
                    mod_file.write(word2.to_bytes(2, 'big'))
        
        for data in self._sample_data:
            mod_file.write(data)
        

if __name__ == '__main__':
    parser = argparse.ArgumentParser(formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("input", help="MOD file")
    parser.add_argument("-o", "--output", metavar="<output>", help="Write MOD to <output> file")
    parser.add_argument("-v", "--verify", action="store_true", help="Verify output file matches input file")
    parser.add_argument("-l", "--loud", action="store_true", help="Print all the debugs")
    args = parser.parse_args()

    global g_verbose
    g_verbose=args.loud

    src = args.input
    # check for missing files
    if not os.path.isfile(src):
        print(f"ERROR: Input file '{src}' not found.")
        sys.exit(1)

    mod_file=open(src, 'rb')

    parser=ModParser(mod_file)
    print(f"Parsing MOD file '{src}'.")
    parser.Parse()

    if args.output:
        out_file=open(args.output, 'wb')
        parser.WriteMod(out_file)
        print(f"Wrote {out_file.tell()} bytes to file '{args.output}'.")
        out_file.close()

    mod_file.close()

    if args.verify:
        if filecmp.cmp(args.input, args.output, shallow=False) is not True:
            print(f"Verification failed: '{args.input}' and '{args.output}' do not match.")
        else:
            print(f"Verified mod files '{args.input}' and '{args.output}' are identical.")
