import struct
import sys

def seed_align(seed_in, input_size_bytes, filename, endianess_change="no"):
    seed = (int(seed_in,16))
    input_size_bytes = int(input_size_bytes)
    no_of_mem_blocks = int(input_size_bytes*8/32)
    val = [0]*no_of_mem_blocks
    val[no_of_mem_blocks-1] = (seed) & (2**32 - 1)
    
    for i in range(1, no_of_mem_blocks):
        val[no_of_mem_blocks-1-i] = (seed >> 32*i) & (2**32 - 1)

    if (endianess_change == "yes"):   
        for i in range(0,no_of_mem_blocks):
            val[i] = struct.unpack("<I", struct.pack(">I", val[i]))[0]

    for i in range(0, no_of_mem_blocks):
        val[i] = (format(val[i],'032b'))

    f = open(filename, "w")
    for i in range(0,no_of_mem_blocks):
        f.write((val[i]))
        f.write("\n")
    
    
    
if __name__ == '__main__':
    seed_align(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])