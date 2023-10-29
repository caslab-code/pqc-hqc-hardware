import struct
import sys

def seed_align(seed_in, filename):
    seed = (int(seed_in,16))
    val = [0]*10
    val[9] = (seed) & (2**32 - 1)
    for i in range(1, 10):
        val[9-i] = (seed >> 32*i) & (2**32 - 1)
        
    for i in range(0,10):
        val[i] = struct.unpack("<I", struct.pack(">I", val[i]))[0]

    for i in range(0, 10):
        val[i] = (format(val[i],'032b'))

    f = open(filename, "w")
    for i in range(0,10):
        f.write((val[i]))
        f.write("\n")
    
    
    
if __name__ == '__main__':
    seed_align(sys.argv[2], sys.argv[3])