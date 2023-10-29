Basic Interface
---------------

The basic interface follows (what I think is) an AXI-lite interface. I followed the documentation provided here:
http://www.gstitt.ece.ufl.edu/courses/fall15/eel4720_5721/labs/refs/AXI4_specification.pdf

The basic mechanism is quite easy:

- There are three signals, ready, valid and data.
- If a master wants to transmit data, it raised valid and sets the data signal to the data to be transmitted.
- If a slave is ready to read the data, it raises the ready signal.
- The transaction is only commited, if valid and ready are raised (i.e. set to '1'), during a rising clock edge.

Important things to note:
- Neither master nor slave must wait for the other party to raise the valid or ready.
- After valid is raised, data must not be changed until the correct state for a commitment of a transaction happened (i.e. ready=valid='1').
- The master must not have a combinatorial logic from the slave's ready signal to its valid signal.
- The slave must not have a cominatorial logic from the master's valid signal to its ready signal.

Protocol
--------

Transmission of data to the XOF
-------------------------------

1. Transmit a command header
- Bit 31 - set to '0' selects shake.
- Bit 30 to 0 - set the requested output length in bits. 


2. For shake, the length of the next data block is transmitted as well as an "eof" flag.
- Bit 31 - eof flag
- Bit 30 to 0 - length of the next data block in bits
However, this length must not exceed rate.

3. The data itself
- Bit 31 to 0 - The message block - The byte order is little endian, i.e. the lowest significant byte is 7 to 0, the next byte 15 to 0 etc.
Note: When a little endian processor is used, the data can be just copied to the AXI bus - otherwise the byte order has to be changed before.

Continue with (3) until all data has been transmitted.


4. After loading out the initial requested data, to perform additional squeezes
- Bit 31 - set to '0' selects shake.
- Bit 30 to 0 - set the requested output length in bits. 






