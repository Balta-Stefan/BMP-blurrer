izvrsni: utility.o assembly_code.o
	g++ -Os -static -o izvrsni utility.o assembly_code.o
	

utility.o: utilityFunctions.cpp
	g++ -Os -c -o utility.o utilityFunctions.cpp

assembly_code.o: assembly_code.asm
	nasm -f elf64 assembly_code.asm


