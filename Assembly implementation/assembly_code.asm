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
extern allocate_temporary_image_buffer

global first_pixel_address
global image_width
global image_height
global image_pointer
global row_accumulator
global temporary_image_ptr

SECTION .data 
	blur_radius DW 5; 2 byte value enter this manually
	split DW 2; 2 byte value.This value is equal to (blur_radius-1)/2.Enter this manually
	
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
	
	tempRSP resq 1
	tempRBP resq 1
	
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
	
	mov r15w, [image_width]
	mov r14w, [image_height]
	
	mov r13, [first_pixel_address]
	
	; blur_radius and split are also used very often
	xor r11, r11
	xor r12, r12
	
	mov r12w, word [blur_radius]
	mov r11w, word [split]

	call _blur_serial
	call writePicture
	
	; blur operation done
	call _end
	
_blur_serial:
	; allocate space for temporary_image_ptr of size image_width*image_height
	
	; this call destroys the values of r12 and r11 and potentially more.Why?
	call allocate_temporary_image_buffer
	
	call _horizontal_blur_serial
	call _vertical_blur_serial
	
	ret
	
	
_horizontal_blur_serial:
	; variables: 
	; blurred image pointer -> RBX
	; row counter (y) -> ECX
	; column counter (x) -> EDI
	; leftEdge -> ESI
	; rightEdge -> EBP
	; finalIndex -> ESP
	; 3 16-bit accumulators:
		; red - r8dw
		; green - r9w 
		; blue - r10w
		
	xor r15, r15
	xor r14, r14
	xor r11, r11
	xor r12, r12
	xor r8, r8
	
	mov r15w, [image_width]
	mov r14w, [image_height]
	
	mov r13, [first_pixel_address]
	
	; blur_radius and split are also used very often

	
	mov r12w, word [blur_radius]
	mov r11w, word [split]
	
	mov [tempRSP], RSP
	mov [tempRBP], RBP
		
	; push RSP 
	; push RBP 
	mov RBX, [temporary_image_ptr]
		

	; div instruction: EDX:EAX contain the dividend, EDX must be unused (and zeroed out)
	xor RDX, RDX
	xor RSP, RSP ; used for pixel array indexing 
	xor ECX, ECX ; row counter
	xor RDI, RDI
	xor RBP, RBP
	xor RSI, RSI
	xor RAX, RAX
	
	; [row counter] loop from 0 to image_height 
	.rowLoop:
		; [column counter] loop from 0 to image_width
			xor EDI, EDI
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
						mov AL, [r13 + RSP]
						add r8w, AX ;byte [r13 + RSP] 
						
						inc RSP 
						mov AL, [r13 + RSP]
						add r9w, AX; byte [r13 + RSP ]
						
						inc RSP 
						mov AL, [r13 + RSP]
						add r10w, AX; byte [r13 + RSP]
						
						inc RSP
						
						; test .blur_loop 
						inc ESI
						cmp ESI, EBP 
						jle .blur_loop
				
				; average the accumulators
				mov RAX, r8 
				idiv r12d
				mov [RBX], AL
				inc RBX
				
				xor RDX, RDX
				
				mov RAX, r9 
				idiv r12d
				mov [RBX], AL
				inc RBX
				
				xor RDX, RDX
				
				mov RAX, r10
				idiv r12d 
				mov [RBX], AL 
				inc RBX
				
				xor RDX, RDX
				
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
	; pop RBP
	; pop RSP
	mov RSP, [tempRSP]
	mov RBP, [tempRBP]
	
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
		cmp r8w, BP
		cmovs BP, r8w; if image_width - 1 is less than column_counter + split, move r10d to ESI (right edge)
		
		jmp .doneCalculatingEdges
		; ret 
	
_vertical_blur_serial:
	; in order to utilize the cache more efficiently, whole rows will be scanned
	
	; tripleWidth = EBP
	; rowAccumulatorPointer (doesn't change) -> RBX
	; rowCounter (y) -> ECX
	; upperEdge -> ESI
	; lowerEdge -> EDI
	; blurredImagePixels (array) -> r8
	; columnLoop (x) -> r10d
	; rowAccumulatorPointer (array) changes because of the innermost loop -> r9
	; temporarySinglePixelAccumulator (to get value from blurredImagePixels) -> SP
	; temporarySinglePixelAccumulator2 (to get a value from rowAccumulator) -> AX

	; last loop:
		; counter -> ESI
		; y*tripleWidth -> EDI 
		; value of rowAccumulator[x] -> AX
		; image pointer -> RSP

		
		
	; allocate space for row accumulator (put the pointer to RBX)
	call allocate_row_accumulator
	xor r11, r11
	mov r11w, [split]
	mov RBX, [row_accumulator]
		
	
	; imageWidth * 3 is used very often, while imageWidth isn't needed
	; push RSP
	; push RBP 
	mov [tempRSP], RSP 
	mov [tempRBP], RBP
	
	imul EBP, r15d, 3
	
	xor RDX, RDX
	xor RAX, RAX
	xor RDI, RDI
	xor r8, r8
	xor RCX, RCX
	xor RSP, RSP
	

	; [row counter] loop from 0 to image_height
	.row_loop:
		; zero out the row_accumulator - to do 
			; std::memset(rowAccumulator, 0, imageWidth * sizeof(unsigned short) * 3);
		xor r10, r10 ; r10 will be used as zeroingLoop counter
		; mov ESI, EBP 
		; shl ESI, 1 ; ESI now contains imageWidth*3*sizeof(unsigned short)
		; mov RDI, [row_accumulator] ; RDI now contains the address of the row_accumulator
		.zeroingLoop:
			mov [RBX+2*r10], word 0
			
			; check zeroingLoop
			inc r10d 
			cmp r10d, EBP ; loop while r10d < imageWidth*3
			jl .zeroingLoop
			
		
		jmp .calculate_edges
		.edgesCalculated:
		
		; blurredImageIndex = blurredImagePixels[upperEdge * tripleWidth]
		xor r8, r8 ; this might be useless
		mov r8d, ESI ; move upperEdge into r8d
		imul r8d, EBP ; multiply r8d with tripleWidth
		mov r9, [temporary_image_ptr]
		add r8, r9
		
		; r8 will now be used as blurredImagePixels[blurredImageIndex++]
		
		
		
		; [i counter] loop from upperEdge to lowerEdge (inclusive)
		.blurLoop:
			; [column counter] loop from 0 to image_width 
			xor r10, r10 ; .columnLoop counter
			mov r9, RBX ; r9 now contains address to row_accumulator.RBX can't be used because .columnLoop has to iterate through row_accumulator
			xor RSP, RSP
			.columnLoop:
				mov SPL, [r8] ; hopefully RSP doesn't have to be cleared because SP is used below
				mov AX, [r9]
				add AX, SP
				mov [r9], AX
				
				inc r8
				add r9, 2
				mov SPL, [r8]
				mov AX, [r9]
				add AX, SP
				mov [r9], AX
				
				inc r8
				add r9, 2
				mov SPL, [r8]
				mov AX, [r9]
				add AX, SP
				mov [r9], AX 
				
				inc r8
				add r9, 2
				
				
				; test .columnLoop
				inc r10d
				cmp r10d, r15d
				jl .columnLoop
				
							
			; check .blurLoop
			inc ESI
			cmp ESI, EDI 
			jle .blurLoop
			
		xor RSI, RSI
		mov EDI, ECX ; put rowCounter (y) into EDI
		imul EDI, EBP ; EDI = y * tripleWidth
		lea RSP, [r13 + RDI] ; &image[tempIndex]
		
		
		; might need to zero out the second (higher) division register
		.averagingLoop:
		
			xor RDX, RDX
			mov AX, [RBX + 2*RSI] ; rowAccumulator[x]
			idiv r12w
			mov [RSP + RSI], AL ; store the rowAccumulator[x] / blurRadius into image[tempIndex+x]
			
			xor RDX, RDX
			mov AX, [RBX + 2*RSI + 2]
			idiv r12w 
			mov [RSP + RSI + 1], AL 
			
			xor RDX, RDX
			mov AX, [RBX + 2*RSI + 4]
			idiv r12w 
			mov [RSP + RSI + 2], AL
			
			
			; check the .averagingLoop counter 
			add ESI, 3
			cmp ESI, EBP 
			jl .averagingLoop
			
		; check row_loop
		inc ECX
		cmp ECX, r14d
		jl .row_loop
		
	; done
	; delete space reserved for row accumulator - to do 
	

	; pop RBP ; retrieve the original value of image_width
	; pop RSP
	
	mov RSP, [tempRSP] 
	mov RBP, [tempRBP]
	
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
		cmp r9d, EDI
		cmovs EDI, r9d; if row + split is less than image_height - 1...
		
		jmp .edgesCalculated
		; ret 




			
