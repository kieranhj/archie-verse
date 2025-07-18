# modparse.py
# Parse Amiga MOD files for processing.
# Splits 8ch MODs into 4ch MOD + 4 event tracks.

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
    def WriteMod(self, mod_file, ch_mask):

        print(f"Writing MOD file '{mod_file.name}'.")
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

        if self._num_samples !=15:
            if ch_mask != 0xff:
                num_channels=ch_mask.bit_count()
                print(f"Channel mask: {ch_mask:08b} ({num_channels} channels)")
                if num_channels==4:
                    mod_file.write("M.K.".encode('ascii'))
                else:
                    mod_file.write(str(num_channels).encode('ascii'))
                    mod_file.write("CHN".encode('ascii'))
            else:
                mod_file.write(self._mod_type.encode('ascii'))

        for pattern in self._patterns:
            for row in pattern:
                n=1
                for note in row:
                    if ch_mask & n:
                        word1=note['period']|(note['sample']&0xf0)<<8
                        word2=note['effect']|(note['sample']&0x0f)<<12
                        mod_file.write(word1.to_bytes(2, 'big'))
                        mod_file.write(word2.to_bytes(2, 'big'))
                    n<<=1
        
        for data in self._sample_data:
            mod_file.write(data)

    def WriteEvents(self, ef, ev_mask):
        print(f"Writing event file '{ef.name}'.")
        num_channels=ev_mask.bit_count()
        print(f"Event mask: {ev_mask:08b} ({num_channels} event channels)")
        event_rows=0
        num_events=0      
        for s in range(0,self._sequence_len):
            pattern=self._patterns[self._sequence[s]]
            r=0
            for row in pattern:
                events=[]
                n=1
                for note in row:
                    if ev_mask & n:
                        event=note['effect']
                        if event !=0: 
                            events.append(event)
                    n<<=1
                
                if events:
                    if g_verbose:
                        print(f"pos=({s},{r} events={events})")

                    packed=s<<8|r
                    shift=16
                    for event in events:
                        code=(event&0xf00)>>8
                        data=event&0x0ff
                        packed|=(code|data<<4)<<shift
                        shift+=12
                    ef.write(packed.to_bytes(8,'little'))
                    event_rows+=1
                    num_events+=len(events)

                r+=1

        if event_rows>0:
            packed=0xffff       # EOF marker
            ef.write(packed.to_bytes(8,'little'))
            print(f"Found {event_rows} rows containing {num_events} events total.")
        else:
            print(f"No events found!")    


if __name__ == '__main__':
    parser = argparse.ArgumentParser(formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("input", help="MOD file")
    parser.add_argument("-o", "--output", metavar="<output>", help="Write MOD to <output> file")
    parser.add_argument("-e", "--events", metavar="<output>", help="Write effects out as an event file to <output> file")
    parser.add_argument("-v", "--verify", action="store_true", help="Verify output file matches input file")
    parser.add_argument("-l", "--loud", action="store_true", help="Print all the debugs")
    parser.add_argument("--channel-mask", type=str, default=0xff, help="Channel mask to write out.")
    parser.add_argument("--event-mask", type=str, default=0xff, help="Event mask to write out.")
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
    print(f"Parsing MOD file '{mod_file.name}'.")
    print(f"---")
    parser.Parse()
    print(f"---")
    mod_file.close()

    if args.output:
        out_file=open(args.output, 'wb')
        parser.WriteMod(out_file, int(args.channel_mask,16))
        print(f"Wrote {out_file.tell()} bytes to file '{out_file.name}'.")
        print(f"---")
        out_file.close()

    if args.events:
        events_file=open(args.events, 'wb')
        parser.WriteEvents(events_file, int(args.event_mask,16))
        print(f"Wrote {events_file.tell()} bytes to file '{events_file.name}'.")
        print(f"---")
        events_file.close()

    if args.verify:
        if filecmp.cmp(args.input, args.output, shallow=False) is not True:
            print(f"Verification failed: '{args.input}' and '{args.output}' do not match.")
        else:
            print(f"Verified mod files '{args.input}' and '{args.output}' are identical.")
        print(f"---")


# Interesting options:
#  - Write out pattern data per channel, not interleaved (swizzle)
#     (apparently compresses better according to Hoffman).
#  - Write out sample data as deltas (may compress better).
#  - Optimise? (Remove duplicate patterns etc.)
#  - Output a debug table of vsync count per pattern
#     (to do this correctly need to scan for tempo changes and pattern breaks etc.)
