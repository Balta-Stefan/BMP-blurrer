; there is a problem with the way I am passing messages to the _printErrorMessage
; I am passing messages as arguments regardless of whether an error occured

; TO DO:
; allow the user to pass blur radius as argument.The program has to check if the value is odd or even (it must be odd).



; register r15d holds image_width
; register r14d holds image_height 
; register r13 is holding the address of the beginning of the picture pixels.
; register r12w is holding the variable blur_radius 
; register r11w is holding the variable split (split = (blur_radius-1)/2)

[bits 64]

;extern output_to_file ; writes blurred image to a file.Written in C - to do
extern loadPicture
extern allocate_row_accumulator
extern free_row_accumulator
extern writePicture

global first_pixel_address
global image_width
global image_height
global image_pointer
global row_accumulator

SECTION .data 
	blur_radius DW 3; 2 byte value enter this manually
	split DW 1; 2 byte value.This value is equal to (blur_radius-1)/2.Enter this manually
	
	BMP_magic_number DW 19778 ; equals 19778
	unsuccessful_image_load DB "Image can't be loaded"
	invalid_magic_number DB "Invalid magic number"

SECTION .bss
	image_pointer resq 1 ; 64-bits 
	first_pixel_address resq 1 ; 64-bits.The address of the first pixel.
	image_width resw 1 ; short.Will be kept in register r15d.
	image_height resw 1 ; short.Will be kept in register r14d.
	
	temporary_image_ptr resq 1 ; pointer to the new image
	row_accumulator resq 1 ; pointer to the row accumulator
	
SECTION .text 
global main


_printErrorMessage:
	; print the message that was passed as argument- TO DO
	call _end
	
_end:
	; terminate the program
	mov RDI, 0
	mov RAX, 60
	syscall

main:
	; pass imagePointer as parameter - to do 
	call loadPicture
	; check the return value of loadPicture.If it is zero, exit the program
	cmp rax, 0
	jne _end
	; pass unsuccessfulImageLoad as parameter - to do
	; call _printErrorMessage
	
	; check the validity of magic number (2 bytes)
	; mov dx, image_pointer ; this might be incorrect.Little endian SHOULD be used
	; cmp [BMP_magic_number], dx ; this might be incorrect (BMP_magic_number might need to be stored in a register first)
	; pass invalid_magic_number as argument - to do
	; jne _printErrorMessage
	
	
	; find first_pixel_address, image_width, image_height - to do 
	
	;lea RAX, [image_pointer + 10]
	;mov [first_pixel_address], RAX
	;mov r13, [first_pixel_address]
	;lea RAX, [image_pointer + 18]
	;mov CX, word [RAX]
	;mov [image_width], CX
	;mov CX, word [RAX+4]
	;mov [image_height], CX ; this might not be allowed.If it isn't, image_height is at the address image_pointer + 22
	
	; check if bits per pixel in the header equals 24 - to do
	
	
	; check for consistency of header image dimensions - to do
	
	
	; since image_width and image_height will be used often, they will be loaded into registers 
	xor r15, r15
	xor r14, r14
	
	mov r15d, [image_width]
	mov r14d, [image_height]
	
	mov r13, first_pixel_address
	
	; blur_radius and split are also used very often
	xor r11d, r11d
	xor r12d, r12d
	
	mov r12w, word [blur_radius]
	mov r11w, word [split]

	call _blur_serial
	call writePicture
	
	; blur operation done
	call _end
	
_blur_serial:
	; allocate space for temporary_image_ptr of size image_width*image_height.TO DO 
	
	call _horizontal_blur_serial
	call _vertical_blur_serial
	
	; pass arguments and call output_to_file - to do
	
	
_horizontal_blur_serial:
	; variables: 
	; blurred image pointer -> RBX
	; row counter (y) -> ECX
	; column counter (x) -> EDI
	; leftEdge -> ESI
	; rightEdge -> EBP
	; finalIndex -> ESP
	; 3 16-bit accumulators:
		; red - r8d 
		; green - r9d 
		; blue - r10d 

		
	push RSP 
	push RBP 
	mov RBX, [temporary_image_ptr]
		

	; div instruction: EDX:EAX contain the dividend, EDX must sit unused (and zeroed out)
	xor RDX, RDX
	xor RSP, RSP ; used for pixel array indexing 
	xor ECX, ECX ; row counter
	
	; [row counter] loop from 0 to image_height 
	.rowLoop:
		; [column counter] loop from 0 to image_width
			.columnLoop:
				jmp .calculate_edges
				.doneCalculatingEdges:
				
				; zero out accumulators on every radius iteration
				xor r10d, r10d ; blue accumulator - r10d
				xor r9d, r9d ; green accumulator - r9d
				xor r8d, r8d ; red accumulator - r8d
				
				; finalIndex = y + leftEdge*3
				mov ESP, ESI
				imul ESP, ESP, 3
				add ESP, ECX 
				
				; [i counter] - loop from leftEdge to rightEdge (inclusive)
				.blur_loop:
						add r8d, [r13 + RSP] 
						
						inc RSP 
						add r9d, [r13 + RSP ]
						
						inc RSP 
						add r10d, [r13 + RSP]
						
						inc RSP
						
						; test .blur_loop 
						inc ESI
						cmp ESI, EBP 
						jle .blur_loop
				
				; average the accumulators
				mov EAX, r8d 
				idiv r12d
				mov [RBX], r8b 
				inc RBX
				
				mov EAX, r9d 
				idiv r12d
				mov [RBX], r9b
				inc RBX
				
				mov EAX, r10d
				idiv r12d 
				mov [RBX], r10b 
				inc RBX
				
				
				; check columnLoop status
				inc EDI 
				cmp EDI, r15d ; compare with image_width
				jb .columnLoop
			
		; check rowLoop status
		; row counter += 3*imageWidth
		add ECX, r15d 
		add ECX, r15d 
		add ECX, r15d 
		
		
		mov EAX, r15d 
		imul EAX, r14d
		imul EAX, EAX, 3
		cmp ECX,  EAX; compare with 3*image_height*image_width
		jb .rowLoop
		
	; done
	pop RBP
	pop RSP
	
	ret 
	
	; PROBLEM!!!CMOVS might not be used correctly
	.calculate_edges:
		; leftEdge = max(0, (signed short)columnLoop - (signed short)split);
		
		mov SI, DI
		sub SI, r11w
		cmp SI, 0
		jl .isNegative
		jmp .notNegative
		.isNegative: ; set SI to 0
			xor SI, SI
		.notNegative:
		
		mov r8w, r15w 
		dec r8w
		; lea r8w, [r15w-1]
		
		; column counter + split
		mov BP, DI 
		add BP, r11w
		; lea BP, [DI + r11w]
		
		; rightEdge = min(image_width - 1, column_counter + split);
		cmp BP, r8w
		cmovs BP, r8w; if image_width - 1 is less than column_counter + split, move r10d to ESI (right edge)
		
		jmp .doneCalculatingEdges
		; ret 
	
_vertical_blur_serial:
	; in order to better use the cache, whole rows will be scanned
	
	; tripleWidth = EBP
	; rowAccumulatorPointer (doesn't change) -> RBX
	; rowCounter (y) -> ECX
	; upperEdge -> ESI
	; lowerEdge -> EDI
	; blurredImagePixels (array) -> r9
	; columnLoop (x) -> r10d
	; rowAccumulatorPointer (array) changes because of the innermost loop -> r8
	; temporarySinglePixelAccumulator (to get value from blurredImagePixels) -> SP
	; temporarySinglePixelAccumulator2 (to get a value from rowAccumulator) -> AX

	; last loop:
		; counter -> ESI
		; y*tripleWidth -> EDI 
		; value of rowAccumulator[x] -> AX
		; image pointer -> RSP

		
		
	; allocate space for row accumulator (put the pointer to RBX) - to do
	call allocate_row_accumulator
		
	
	; imageWidth * 3 is used very often, while imageWidth isn't needed
	push RSP
	push RBP 
	imul EBP, r15d, 3
	
	xor RDX, RDX
	xor RAX, RAX
	xor RDI, RDI
	xor r8, r8
	
	

	; [row counter] loop from 0 to image_height
	.row_loop:
		; zero out the row_accumulator - to do 
			; std::memset(rowAccumulator, 0, imageWidth * sizeof(unsigned short) * 3);
		xor r10, r10 ; r10 will be used as zeroingLoop counter
		mov ESI, EBP 
		shl ESI, 1 ; ESI now contains imageWidth*3*sizeof(unsigned short)
		mov RDI, [row_accumulator] ; RDI now contains the address of the row_accumulator
		.zeroingLoop:
			mov [RDI+r10], byte 0
			
			; check zeroingLoop
			inc r10d 
			cmp r10d, ESI
			jl .zeroingLoop
			
		
		call .calculate_edges
		
		; blurredImageIndex = blurredImagePixels[upperEdge * tripleWidth]
		mov r8d, ESI 
		imul r8d, EBP
		mov r9, [temporary_image_ptr]
		add r9, r8
		
		mov r8, RBX ; rowAccumulatorPointer
		; [i counter] loop from upperEdge to lowerEdge (inclusive)
		.blurLoop:
			; [column counter] loop from 0 to image_width 
			.columnLoop:
				mov SP, [r9]
				mov AX, [r8]
				add AX, SP
				mov [r8], AX
				
				inc r8
				inc r9
				mov AX, [r8]
				add AX, SP
				mov [r8], AX
				
				inc r8
				inc r9
				mov AX, [r8]
				add AX, SP
			    mov [r8], AX
				
				inc r8
				inc r9
				
				; test .columnLoop
				inc r10d
				cmp r10d, r15d
				jl .columnLoop
				
							
			; check .blurLoop
			inc ESI
			cmp ESI, EDI 
			jle .blurLoop
		
		; [column counter] loop from 0 to image_width
			; row_accumulator[3 * column] /= blurRadius;
            ; row_accumulator[3 * column + 1] /= blurRadius;
            ; row_accumulator[3 * column + 2] /= blurRadius;
			
            ; image[3 * (row * imageWidth + column)] = row_accumulator[3 * column];
            ; image[3 * (row * imageWidth + column) + 1] = row_accumulator[3 * column + 1];
            ; image[3 * (row * imageWidth + column) + 2] = row_accumulator[3 * column + 2];
			
		xor ESI, ESI
		mov EDI, ECX 
		imul EDI, EBP ; EDI = y * tripleWidth
		lea RSP, [r13 + RDI] ; &image[tempIndex]
		
		; might need to zero out the second (higher) division register
		.averagingLoop:
			; TO DO
			mov AX, [RBX + RSI] ; rowAccumulator[x]
			idiv r12w
			mov [RSP + RSI], AL ; store the rowAccumulator[x] / blurRadius into image[tempIndex+x]
			
			mov AX, [RBX + RSI + 1]
			idiv r12w 
			mov [RSP + RSI + 1], AL 
			
			mov AX, [RBX + RSI + 2]
			idiv r12w 
			mov [RSP + RSI + 2], AL
			
			
			; check the loop counter 
			add ESI, 3
			cmp ESI, EBP 
			jl .averagingLoop
			
		; check row_loop
		inc ECX
		cmp ECX, r14d
		jl .row_loop
		
	; done
	; delete space reserved for row accumulator - to do 
	

	pop RBP ; retrieve the original value of image_width
	pop RSP
	
	call free_row_accumulator
	ret
	
	

	; PROBLEM!!!CMOVS might not be used correctly
	.calculate_edges:
		; upperEdge = max(0, row - split); //PROBLEM!Only signed ints must be used here.
		
		mov ESI, ECX 
		sub ESI, r11d
		cmp ESI, 0 
		jl .isNegative ; set SI (upperEdge) to 0 if row - split is less than 0
		jmp .notNegative
		.isNegative: ; set ESI to zero
			xor ESI, ESI
		.notNegative:
		
		; lowerEdge = min(image_height - 1, row + split);
		
		; image_height - 1
		lea EDI, [r14d-1]
		
		; row + split
		lea r9d, [ECX + r11d]
		
		
		; this might be incorrect, check it out later.I have no clue how cmovs works.
		cmp EDI, r9d
		cmovs EDI, r9d; if row + split is less than image_height - 1
		
		ret 




			
