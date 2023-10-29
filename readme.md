# Introduction

This repository consists of hardware implementation of **Hamming Quasi-Cyclic (HQC)** Key Encapsulation Mechanism Scheme (https://pqc-hqc.org/). 



This hardware implementation is part of the research work published at **Selected Areas in Cryptography 2023**. This work is also available on eprint at https://eprint.iacr.org/2022/1183/.



# Citation 

We kindly request you to use the following citation if you use our design. 

```
@inproceedings{deshpande2023fast,
  author={Sanjay Deshpande and Chuanqi Xu and Mamuri Nawan and Kashif Nawaz and Jakub Szefer},
  title={Fast and Efficient Hardware Implementation of HQC},
  booktitle={Proceedings of the Selected Areas in Cryptography},
  series={SAC},
  year={2023},
  month={August},
}
```



# 'hardware' folder 

The **hardware** folder consists of our hardware implementation. It contains following subsections:

- **keygen** - contains key generation related verilog files, tcl script, testbench, and a python script for aligning the input to our hardware keygen module
- **encap** - contains encapsulation related verilog files, tcl script, testbench, and a python script for aligning the input to our hardware keygen module
- **decap** - contains decapsulation related verilog files, tcl script, testbench, and a python script for aligning the input to our hardware keygen module
- **common** - contains verilog files that are common among key generation, encapsulation and decapsulation modules
- **joint_design** - contains a top module file that combines and keygen, encap, and decap modules and shares several submodules for area optimization



# Makefile

We provide a makefile for easily gathering all files required for a specific target module. The makefile also has capability of simulating the modules using Xilinx Vivado. The makefile consists of following targets:



- ***build_keygen***: Gathers all verilog files required by the keygen module, tcl scripts and required memory files required for simulating the design, puts them in **keygen** folder inside the **build** folder
- ***build_encap***: Gathers all verilog files required by the encap module, tcl scripts and required memory files required for simulating the design, puts them in **encap** folder inside the **build** folder
- ***build_decap***: Gathers all verilog files required by the decap module, tcl scripts and required memory files required for simulating the design, puts them in **decap** folder inside the **build** folder
- ***run_xilinx_sim_keygen***: Creates a Xilinx Vivado project and adds the files from build/keygen and simulates the design and generates output for all parameter sets. After simulation, the generated output files are stored in build/keygen/output
- ***run_xilinx_sim_encap***: Creates a Xilinx Vivado project and adds the files from build/encap and simulates the design and generates output for all parameter sets. We note that our modules are compatible with each other. Hence, the public key required for the encapsulation operation is generated first using **run_xilinx_sim_keygen** and then supplied as input to the encapsulation module. 
- ***run_xilinx_sim_decap***: Creates a Xilinx Vivado project and adds the files from build/decap and simulates the design and generates output for all parameter sets. We again note that our modules are compatible with each other. The secret key and ciphertext required for simulating decapsulation operation is generated first using **run_xilinx_sim_keygen** and **run_xilinx_sim_encap** and supplied as input to the decapsulation module for simulation.
- ***build_joint_design***: Gathers all verilog files required to build a joint_design that combine keygen, encap, and decap module, and creates Xilinx Vivado project using the files and sets the required compiler definitions that enables the sharing of the modules.

Please note that for running  run_xilinx_sim_keygen, run_xilinx_sim_encap, run_xilinx_sim_decap, and build_joint_design you will need Xilinx Vivado installed on the machine and added to the path. 

 
