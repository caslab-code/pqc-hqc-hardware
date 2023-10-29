
/*
 * These are defines used for the Keccak design, the defines come from keccak_pkg.vhd, 
 * which was developed by Bernhard Jungk <bernhard@projectstarfire.de>
 * 
 * Copyright (C): 2019
 * Author:        Jakub Szefer <jakub.szefer@yale.edu>
 *                Xiayuan Wen <xiayuan.wen@yale.edu>
 *                Shanquan Tian <shanquan.tian@yale.edu>
 * 
 *          
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
*/

/*
Requirement, below must be power of 2:
NUM_SLICES / WIN
NUM_SUB_ROUNDS

*/



`ifndef KECCAK_PKG
`define KECCAK_PKG


// input bit width                         (fixed to 32 bit)
`define WIN                                32
// output bit width                        (fixed to 32 bit)
`define WOUT                               32
// number of rounds for Keccak-f           (fixed to 24)
`define KECCAK_ROUNDS                      24
// number of slices in Keccak-f            (fixed to 64 for Keccak-1600) FIXME can be changed?
`define NUM_SLICES                         64

// Keccak rates for shake and cshake       (possible rates 1344 (128 bit variant) and 1088 (256 bit variant)
// old definitions
// `define RATE                               1344
// `define RATE_WIDTH                         `CLOG2(`RATE-1)
`define RATE_128                           1344
`define RATE_WIDTH_128                     `CLOG2(`RATE_128+1)
`define RATE_256                           1088
`define RATE_WIDTH_256                     `CLOG2(`RATE_256+1)
`define RATE_WIDTH                         `RATE_WIDTH_128

// different prefix used for cshake128 (X"10010001a801") and cshake256 (X"100100018801")
// `define CSHAKE_PREFIX                      48'h10010001a801
`define CSHAKE_PREFIX_128                  48'h10010001a801
`define CSHAKE_PREFIX_256                  48'h100100018801

// number of slices processed in parallel  (possible values: 1,2,4,8,16,32,64) -- FIXME 64 not working yet
//`define PARALLEL_SLICES                    64
//`define PARALLEL_SLICES                     16
//`define PARALLEL_SLICES                    1
//`define PARALLEL_SLICES                    16
`define PARALLEL_SLICES                    32
//`define PARALLEL_SLICES                    64
// in data_path module, din_offset was defined as wire [`CLOG2(WIN/PARALLEL_SLICES)-1:0] din_offset;




`define NUM_SUB_ROUNDS                `NUM_SLICES/`PARALLEL_SLICES //=64 when PARALLEL_SLICES=1
`define MAX_SUB_ROUNDS                `NUM_SUB_ROUNDS-1// =63 when PARALLEL_SLICES=1
`define NUM_ROUND_COUNT               (`KECCAK_ROUNDS+1)*`NUM_SUB_ROUNDS//25*64=1600 when PARALLEL_SLICES=1
`define MAX_ROUND_COUNT               `NUM_ROUND_COUNT-1//=1599 when PARALLEL_SLICES=1
`define ROUND_COUNT_WIDTH             `CLOG2(`MAX_ROUND_COUNT+1)


// For win = 32 and parallel_slices = 64, we need to change the data absorption phase
`define NUM_SUB_READS_COUNT           `WIN/`PARALLEL_SLICES//= 32/ 1 = 32 when PARALLEL_SLICES=1
`define MAX_SUB_READS_COUNT           `NUM_SUB_READS_COUNT-1//=31 when PARALLEL_SLICES=1



`define SUB_READS_COUNT_WIDTH       `DIVCLOG2(`MAX_SUB_READS_COUNT+1)

//    `define SUB_READS_COUNT_WIDTH         `CLOG2(`MAX_SUB_READS_COUNT+1)// SHANQUAN's edit 32
//        `define SUB_READS_COUNT_WIDTH         0//   DEBUG

//`define SUB_READS_COUNT_WIDTH (`PARALLEL_SLICES < 32)? `CLOG2(`MAX_SUB_READS_COUNT+1) : 0

// `define NUM_READS_COUNT               `RATE/`WIN*`NUM_SUB_READS_COUNT
// `define MAX_READS_COUNT               `NUM_READS_COUNT-1
// `define COUNTER_WIDTH                 `CLOG2(`MAX_READS_COUNT)// 

`define NUM_READS_COUNT_128           `RATE_128/`WIN*`NUM_SUB_READS_COUNT//=1344/32*32=1344 when PARALLEL_SLICES=1
`define MAX_READS_COUNT_128           `NUM_READS_COUNT_128-1//=1343 when PARALLEL_SLICES=1
`define COUNTER_WIDTH_128             `CLOG2(`MAX_READS_COUNT_128+1)
`define NUM_READS_COUNT_256           `RATE_256/`WIN*`NUM_SUB_READS_COUNT//=1088/32*32=1088 when PARALLEL_SLICES=1
`define MAX_READS_COUNT_256           `NUM_READS_COUNT_256-1//=1087 when PARALLEL_SLICES=1
`define COUNTER_WIDTH_256             `CLOG2(`MAX_READS_COUNT_256+1)

`define COUNTER_WIDTH                 `COUNTER_WIDTH_128

  // constant num_write_count_per_squeeze_128  : natural := (rate_128/wout)*num_sub_rounds;
  // constant max_write_count_per_squeeze_128  : natural := num_write_count_per_squeeze_128-1;

  // constant num_write_count_per_squeeze_256  : natural := (rate_256/wout)*num_sub_rounds;
  // constant max_write_count_per_squeeze_256  : natural := num_write_count_per_squeeze_256-1;

`define DATAPATH_WIDTH                `PARALLEL_SLICES*25//=25 when PARALLEL_SLICES=1


`endif



// Parameters by Xiayuan

`ifndef rho_offset_DEFINE
`define rho_offset_DEFINE

`define RHO_SLICES_DIVIDER            `PARALLEL_SLICES


`define RHO(i) (\
    (i == 0) ? 0 :\
    (i == 1) ? 1 :\
    (i == 2) ? 62:\
    (i == 3) ? 28:\
    (i == 4) ? 27:\
    (i == 5) ? 36:\
    (i == 6) ? 44:\
    (i == 7) ? 6:\
    (i == 8) ? 55:\
    (i == 9) ? 20:\
    (i == 10) ? 3:\
    (i == 11) ? 10:\
    (i == 12) ? 43:\
    (i == 13) ? 25:\
    (i == 14) ? 39:\
    (i == 15) ? 41:\
    (i == 16) ? 45:\
    (i == 17) ? 15:\
    (i == 18) ? 21:\
    (i == 19) ? 8:\
    (i == 20) ? 18:\
    (i == 21) ? 2:\
    (i == 22) ? 61:\
    (i == 23) ? 56:\
    (i == 24) ? 14:\
    0)



`define PI(i) (\
    (i == 0) ? 0 :\
    (i == 1) ? 10 :\
    (i == 2) ? 20:\
    (i == 3) ? 5:\
    (i == 4) ? 15:\
    (i == 5) ? 16:\
    (i == 6) ? 1:\
    (i == 7) ? 11:\
    (i == 8) ? 21:\
    (i == 9) ? 6:\
    (i == 10) ? 7:\
    (i == 11) ? 17:\
    (i == 12) ? 2:\
    (i == 13) ? 12:\
    (i == 14) ? 22:\
    (i == 15) ? 23:\
    (i == 16) ? 8:\
    (i == 17) ? 18:\
    (i == 18) ? 3:\
    (i == 19) ? 13:\
    (i == 20) ? 14:\
    (i == 21) ? 24:\
    (i == 22) ? 9:\
    (i == 23) ? 19:\
    (i == 24) ? 4:\
    0)


`define INVERSE_PI(i) (\
    (i == 0) ? 0 :\
    (i == 1) ? 6 :\
    (i == 2) ? 12:\
    (i == 3) ? 18:\
    (i == 4) ? 24:\
    (i == 5) ? 3:\
    (i == 6) ? 9:\
    (i == 7) ? 10:\
    (i == 8) ? 16:\
    (i == 9) ? 22:\
    (i == 10) ? 1:\
    (i == 11) ? 7:\
    (i == 12) ? 13:\
    (i == 13) ? 19:\
    (i == 14) ? 20:\
    (i == 15) ? 4:\
    (i == 16) ? 5:\
    (i == 17) ? 11:\
    (i == 18) ? 17:\
    (i == 19) ? 23:\
    (i == 20) ? 2:\
    (i == 21) ? 8:\
    (i == 22) ? 14:\
    (i == 23) ? 15:\
    (i == 24) ? 21:\
    0)
    
//% `X  =   & (`X-1)

        
`define RHO_OFFSET(i) (\
    (i == 0) ? ((0) & (`PARALLEL_SLICES-1)) :\
    (i == 1) ? ((44) & (`PARALLEL_SLICES-1)) :\
    (i == 2) ? ((43) & (`PARALLEL_SLICES-1)) :\
    (i == 3) ? ((21) & (`PARALLEL_SLICES-1)) :\
    (i == 4) ? ((14) & (`PARALLEL_SLICES-1)) :\
    (i == 5) ? ((28) & (`PARALLEL_SLICES-1)) :\
    (i == 6) ? ((20) & (`PARALLEL_SLICES-1)) :\
    (i == 7) ? ((3) & (`PARALLEL_SLICES-1)) :\
    (i == 8) ? ((45) & (`PARALLEL_SLICES-1)) :\
    (i == 9) ? ((61) & (`PARALLEL_SLICES-1)) :\
    (i == 10) ? ((1) & (`PARALLEL_SLICES-1)) :\
    (i == 11) ? ((6) & (`PARALLEL_SLICES-1)) :\
    (i == 12) ? ((25) & (`PARALLEL_SLICES-1)) :\
    (i == 13) ? ((8) & (`PARALLEL_SLICES-1)) :\
    (i == 14) ? ((18) & (`PARALLEL_SLICES-1)) :\
    (i == 15) ? ((27) & (`PARALLEL_SLICES-1)) :\
    (i == 16) ? ((36) & (`PARALLEL_SLICES-1)) :\
    (i == 17) ? ((10) & (`PARALLEL_SLICES-1)) :\
    (i == 18) ? ((15) & (`PARALLEL_SLICES-1)) :\
    (i == 19) ? ((56) & (`PARALLEL_SLICES-1)) :\
    (i == 20) ? ((62) & (`PARALLEL_SLICES-1)) :\
    (i == 21) ? ((55) & (`PARALLEL_SLICES-1)) :\
    (i == 22) ? ((39) & (`PARALLEL_SLICES-1)) :\
    (i == 23) ? ((41) & (`PARALLEL_SLICES-1)) :\
    (i == 24) ? ((2) & (`PARALLEL_SLICES-1)) :\
    0)

// /`X  = >> `CLOG2(`X)

// `define RHO_ADDR_OFFSET(i) (\
//     (i == 0) ? ((0 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 1) ? ((44 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 2) ? ((43 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 3) ? ((21 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 4) ? ((14 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 5) ? ((28 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 6) ? ((20 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 7) ? ((3 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 8) ? ((45 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 9) ? ((61 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 10) ? ((1 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 11) ? ((6 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 12) ? ((25 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 13) ? ((8 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 14) ? ((18 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 15) ? ((27 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 16) ? ((36 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 17) ? ((10 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 18) ? ((15 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 19) ? ((56 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 20) ? ((62 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 21) ? ((55 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 22) ? ((39 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 23) ? ((41 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     (i == 24) ? ((2 >> `CLOG2(`RHO_SLICES_DIVIDER)) & (`NUM_SUB_ROUNDS-1)) :\
//     0)

// /`X  = >> `CLOG2(`X) but be careful about 1! becase we used a customized clog2

`define RHO_ADDR_OFFSET(i) (\
    (i == 0) ? ((0 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 1) ? ((44 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 2) ? ((43 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 3) ? ((21 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 4) ? ((14 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 5) ? ((28 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 6) ? ((20 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 7) ? ((3 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 8) ? ((45 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 9) ? ((61 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 10) ? ((1 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 11) ? ((6 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 12) ? ((25 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 13) ? ((8 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 14) ? ((18 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 15) ? ((27 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 16) ? ((36 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 17) ? ((10 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 18) ? ((15 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 19) ? ((56 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 20) ? ((62 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 21) ? ((55 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 22) ? ((39 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 23) ? ((41 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    (i == 24) ? ((2 / `RHO_SLICES_DIVIDER) & (`NUM_SUB_ROUNDS-1)) :\
    0)



`define MOD5(i) (\
    (i == 0) ? 0 :\
    (i == 1) ? 1 :\
    (i == 2) ? 2:\
    (i == 3) ? 3:\
    (i == 4) ? 4:\
    (i == 5) ? 0:\
    (i == 6) ? 1:\
    (i == 7) ? 2:\
    (i == 8) ? 3:\
    (i == 9) ? 4:\
    (i == 10) ? 0:\
    (i == 11) ? 1:\
    (i == 12) ? 2:\
    (i == 13) ? 3:\
    (i == 14) ? 4:\
    (i == 15) ? 0:\
    (i == 16) ? 1:\
    (i == 17) ? 2:\
    (i == 18) ? 3:\
    (i == 19) ? 4:\
    (i == 20) ? 0:\
    (i == 21) ? 1:\
    (i == 22) ? 2:\
    (i == 23) ? 3:\
    (i == 24) ? 4:\
    (i == 25) ? 0:\
    0)
    


`endif









/*

use work.hash.all;
use work.keccak_math.all;

package keccak is


  -- For win = 32 and parallel_slices = 64, we need to change the squeezing phase
  constant num_sub_write_count          : natural := wout/parallel_slices;
  constant max_sub_write_count          : natural := num_sub_write_count-1;
  constant sub_write_count_width        : natural := log2(max_sub_write_count);

  constant num_write_count_per_squeeze  : natural := (rate/wout)*num_sub_rounds;
  constant max_write_count_per_squeeze  : natural := num_write_count_per_squeeze-1;


end package;

package body keccak is

end package body;

*/
