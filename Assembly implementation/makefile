izvrsni: utility.o assembly_code.o
	g++ -g -static -o izvrsni utility.o assembly_code.o
	
utility.o: utilityFunctions.cpp
	g++ -c -g -o utility.o utilityFunctions.cpp
	

assembly_code.o: assembly_code.asm
	nasm -f elf64 -g -F dwarf assembly_code.asm

