# tptriscv
Implement the RISC-V 32-bit Microprocessor on The Powder Toy.

# How to Run?
1. Copy the tptriscv folder in the src directory to the TPT data directory.
2. Copy the examples folder to the TPT data directory.
3. Run TPT, open the console, and enter the following command.
`dofile("tptriscv/main.lua")`
4. Select the DBG material, install one of the blank spaces on the canvas, and unstop the simulation to import the example file.
5. The inspection will be done automatically. Please wait a moment and we will inform you of the results. (The real-time dis-assembly will be activated while it is running, please wait as there is no abnormality.)
6. Once the operation is complete, you must save the changed memory information. Please enter a file name.
7. Compare the printed and original files with each other to see what has changed.

# Can I contribute to this project?
Yes, it is always possible, but please be careful because the source code is very unstable because it is in the early stages of development.

# What exactly are the features currently available?
It includes what appears to be a normal operation of the processor, the implementation of a compressed set of instructions, the implementation of some multiplication and division of instructions, debugging, and real-time display assembly output.

# Can I use it for other projects as well?
Yes, of course. If it's an environment where LuaJIT and BitOp libraries are supported, it can be driven. But I would like to let you know that it doesn't guarantee complete compatibility because it's being developed around TPT right now.
