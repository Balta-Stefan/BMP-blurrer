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
extern allocateAlignedArray

global first_pixel_address
global image_width
global image_height
global image_pointer
global row_accumulator
global temporary_image_ptr
global startAssembly
global blur_radius
global split
global serial


SECTION .data 
	blur_radius DD 1; 4 byte value enter this manually
	split DW 1; 4 byte value.This value is equal to (blur_radius-1)/2.Enter this manually
	serial DB 1
	
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
	
	temporaryValue resq 1
	
SECTION .text 
global startAssembly


_printErrorMessage:
	; print the message that was passed as argument- TO DO
	call _end
	
_end:
	; terminate the program
	mov RDI, 0
	mov RAX, 60
	syscall

startAssembly:
	; pass imagePointer as parameter - to do 
	;call loadPicture
	; check the return value of loadPicture.If it is zero, exit the program
	;cmp rax, 0
	;jne _end
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

	call _blur
	call writePicture
	
	ret
	; blur operation done
	call _end
	
	
_blur:
	; allocate space for temporary_image_ptr of size image_width*image_height
	
	; this call destroys the values of r12 and r11 and potentially more.Why?
	call allocate_temporary_image_buffer
	
	call _horizontal_blur_serial
	
	cmp byte [serial], 1
	je .isSerial
	call _vertical_blur_AVX	
	ret
	.isSerial:
		;mov [temporaryValue], qword 0
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
	xor RCX, RCX ; row counter
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
				
				xor RAX, RAX
				
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
		jl .rowLoop
		
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
	; RDI contains startingColumn parameter
	

	call allocate_row_accumulator
	
	xor r12, r12
	mov r15w, [image_width] 
	mov r12w, [blur_radius]

		
	xor r11, r11
	mov r11w, [split]
	mov RBX, [row_accumulator]
		
	
	; imageWidth * 3 is used very often, while imageWidth isn't needed
	; push RSP
	; push RBP 
	mov [tempRSP], RSP 
	mov [tempRBP], RBP
	
	xor RBP, RBP
	imul EBP, r15d, 3 ; EBP contains tripleWidth
	mov r15d, EBP 
	sub r15d, 3
	
	xor RDX, RDX
	xor RAX, RAX
	xor RDI, RDI
	xor r8, r8
	xor r10, r10
	xor RCX, RCX
	xor RSP, RSP
	xor RSI, RSI 
	

	; [row counter] loop from 0 to image_height
	.row_loop:
		; zero out the row_accumulator - to do 
			; std::memset(rowAccumulator, 0, imageWidth * sizeof(unsigned short) * 3);
		xor r10, r10 ; r10 will be used as zeroingLoop counter
		xor r8, r8
		mov ESI, EBP 
		shl ESI, 1 ; ESI now contains imageWidth*3*sizeof(unsigned short)
		; mov RDI, [row_accumulator] ; RDI now contains the address of the row_accumulator
		.zeroingLoop:
			mov [RBX+2*r10], word 0
			
			; check zeroingLoop
			inc r10d 
			cmp r10d, EBP ; loop while r10d < 3*imageWidth-startColumn (size of the row_accumulator)
			jl .zeroingLoop
			
		
		jmp .calculate_edges
		.edgesCalculated:
		
		; blurredImageIndex = blurredImagePixels[upperEdge * tripleWidth]
		xor r8, r8 ; this might be useless
		;mov r8d, ESI ; move upperEdge into r8d
		;imul r8d, EBP ; multiply r8d with tripleWidth
		;mov r9, [temporary_image_ptr]
		;add r8, r9
		
		; r8 will now be used as blurredImagePixels[blurredImageIndex++]
		
		

		
		; [i counter] loop from upperEdge to lowerEdge (inclusive)
		.blurLoop:
			; [column counter] loop from 0 to image_width 
			
			;mov r10d, ESI 
			;imul r10d, EBP
			mov r10d, [temporaryValue]
			
			; r9 should hold rowAccumulatorPointer + 2*startColumn
			mov r9, [temporaryValue]
			shl r9, 1
			add r9, RBX
			xor RSP, RSP
			; put blurredImagePixels + i*tripleImageWidth + startingColumn into r8
			mov r8, RSI
			imul r8, RBP
			; imul r8, RSI, RBP ; r8 now contains i*tripleImageWidth.This can't be done, 3 lines above do this.
			add r8, [temporary_image_ptr]
			add r8, [temporaryValue]
			.columnLoop:
				mov SPL, [r8] ; r8 is used to get blurredImagePointer data (horizontally blurred image data)
				mov AX, [r9]
				add AX, SP
				mov [r9], AX
				
				mov SPL, [r8+1]
				mov AX, [r9+2]
				add AX, SP
				mov [r9+2], AX
				
				mov SPL, [r8+2]
				mov AX, [r9+4]
				add AX, SP
				mov [r9+4], AX 
				
				add r8, 3
				add r9, 6
				
				; test .columnLoop
				add r10d, 3 
				cmp r10d, r15d
				jle .columnLoop
				
							
			; check .blurLoop
			inc ESI ; ESI is upperEdge 
			cmp ESI, EDI  ; EDI is lowerEdge
			jle .blurLoop
		
			
		xor RSI, RSI
		;mov EDI, ECX ; put rowCounter (y) into EDI
		;imul EDI, EBP ; EDI = y * tripleWidth
		;lea RSP, [r13 + RDI] ; &image[tempIndex]
		
		; put firstImagePixel + tripleImageWidth*ECX + startColumn into RSP and increment it for3 on every iteration
		mov RSP, RBP
		imul RSP, RCX
		add RSP, r13
		; lea RSP, [r13 + RBP*ECX] this can't be done, 3 lines of code above perform the same thing
		add RSP, [temporaryValue]
		
		; put rowAccumulator + 2*startColumn into r9 and increment it for 6 on every iteration 
		mov r9, [temporaryValue]
		shl r9, 1
		add r9, RBX ; r9 now holds rowAccumulator[2*startColumn]
		
		
		; put rowAccumulator + 2*startColumn into r9 and increment it for 6 on every iteration 
		; put firstImagePixel + tripleImageWidth*ECX + startColumn into RSP and increment it for 3 on every iteration
		; RSI is the counter (x)
		
		mov ESI, [temporaryValue]
		; might need to zero out the second (higher) division register
		.averagingLoop:
		
			xor RDX, RDX
			mov AX, [r9] ; rowAccumulator[x]
			idiv r12w
			mov [RSP], AL ; store the rowAccumulator[x] / blurRadius into image[tempIndex+x]
			
			xor RDX, RDX
			mov AX, [r9 + 2]
			idiv r12w 
			mov [RSP + 1], AL 
			
			xor RDX, RDX
			mov AX, [r9 + 4]
			idiv r12w 
			mov [RSP + 2], AL
			
			
			add RSP, 3 
			add r9, 6
			; check the .averagingLoop counter 
			add ESI, 3
			cmp ESI, r15d 
			jle .averagingLoop
			
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
	
	;call free_row_accumulator
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




_vertical_blur_AVX:

	; ymm15 -> blur_radius
	
	; registers ymm0 to ymm6 are used as accumulators
	
	
	; aligned_offload_area pointer -> RAX
	; blurredImagePixels -> r12
	; numOfReads -> EBX (= 3*imageWidth / 64)
	; rowCounter (y) -> EDI 
	; upperEdge -> ESI
	; a copy of upperEdge -> EDX
	; lowerEdge -> ECX
	; AVXchunkCounter (0, ..., numOfReads) ->r8d
	; 3 * i * imageWidth + 8*(7 * AVXchunkCounter + {0, 1, 2, ..., 7}) -> r9d, r10d
	; temp AVX register -> ymm14
	


	
	call allocateAlignedArray
	push RAX
	
	mov r12, [temporary_image_ptr]
	imul r15d, r15d, 3 ; image_width isn't needed, but 3*image_width is used multiple times
	
	xor RAX, RAX
	xor RDX, RDX
	xor RBX, RBX
	mov eax, r15d
	mov ESI, 56
	div ESI ; divide 3*imageWidth by 56
	mov EBX, EAX
	mov r13, [first_pixel_address]
	
	pop RAX
	
	
	vbroadcastss ymm15, [blur_radius] ; broadcast blur_radius to all elements of a 256-bit register
	vcvtdq2ps ymm15, ymm15 ; converts 32-bit integers into 32-bit FP data.If there are unknown issues, this might be the cause because the same register is both source and destination.
	
	
	xor RCX, RCX
	xor RSI, RSI
	xor r9, r9
	xor r10, r10
	xor r11, r11
	xor RDX, RDX
	
	mov r11w, [split]

	
	
	xor RDI, RDI
	.rowLoop:
		jmp .calculate_edges
		.edgesCalculated:
		xor r8, r8
		.AVXchunkLoop:
			jmp .zeroRegisters
			.zeroedOut:
			.blurLoop:
				; &bytePointerBlurredImage[3 * i * imageWidth + 8*(7 * AVXchunkCounter + {0, 1, ..., 7})] -> r9d, r10d
				; __m256i temp256 = _mm256_cvtepu8_epi32(*(__m128i*)&bytePointerBlurredImage[3 * i * imageWidth + 8*(7 * AVXchunkCounter + {0, 1, ..., 7})]); //PROBLEM!!!THIS MIGHT LEAD TO OUT OF BOUNDS MEMORY ACCESS.
				
				; registers ymm7 through ymm13 will be filled by doing the following using registers r9d and r10d:
					; 8*(7 * AVXchunkCounter) + 8*{0, 1, ..., 7}
					; 3 * i * imageWidth
					
				; bytePointerBlurredImage[ESI * tripleWidth + 8*r8d * 7 + {0, 8, 16, 24, 32, 40, 48}]
				xor r9, r9
				; this will be used for all 7 registers (ymm7-ymm14)
				mov r9d, r8d ; move AVXChunkCounter to r9d
				imul r9d, r9d, 56;7
				;shl r9d, 3 ; multiply by 8.r9d now contains 8*7*AVXchunkCounter 
				
				mov r10d, r15d
				imul r10d, ESI ; r10d now contains 3*i*imageWidth.Number 8 will have to be added to r9d for each next register
				
				add r9d, r10d ; r9d is now equal to 3*i*imageWidth + 8*7*AVXchunkCounter
				lea r9, [r9 + r12] ; r9 is now equal to &horizontallyBlurredImagePointer[3*i*imageWidth + 8*7*AVXchunkCounter]
				; ymm7
				movdqu xmm14, [r9]
				vpmovzxbd ymm7, xmm14; zero extend 8-bit data into 32-bit data.    
				vpaddd ymm0, ymm0, ymm7  ; add new data to accumulator.             	    WARNING: THIS INSTRUCTION SHOULD RECEIVE 3 ARGUMENTS.
				
				add r9, 8
				; ymm8
				movdqu xmm14, [r9]
				vpmovzxbd ymm8, xmm14
				vpaddd ymm1, ymm1, ymm8 
		
				add r9, 8
				; ymm9
				movdqu xmm14, [r9]
				vpmovzxbd ymm9, xmm14
				vpaddd ymm2, ymm2, ymm9 
				
				add r9, 8
				; ymm10
				movdqu xmm14, [r9]
				vpmovzxbd ymm10, xmm14
				vpaddd ymm3, ymm3, ymm10
				
				add r9, 8
				; ymm11
				movdqu xmm14, [r9]
				vpmovzxbd ymm11, xmm14
				vpaddd ymm4, ymm4, ymm11
				
				add r9, 8
				; ymm12
				movdqu xmm14, [r9]
				vpmovzxbd ymm12, xmm14
				vpaddd ymm5, ymm5, ymm12
				
				add r9, 8
				; ymm13
				movdqu xmm14, [r9]
				vpmovzxbd ymm13, xmm14
				vpaddd ymm6, ymm6, ymm13
				
				
				;check blurLoop
				inc ESI 
				cmp ESI, ECX
				jle .blurLoop
				
			mov ESI, EDX ; get the original value of upperEdge (because ESI is used as counter in the loop that iterates from upperEdge to lowerEdge)
				
			; divide the values in accumulators by the radius value.This will be performed manually because there are no integer division AVX instructions
			
			; all of the registers use 32-bit integers.They have to be converted to 32-bit floating point data
			vcvtdq2ps ymm0, ymm0
			vcvtdq2ps ymm1, ymm1
			vcvtdq2ps ymm2, ymm2
			vcvtdq2ps ymm3, ymm3
			vcvtdq2ps ymm4, ymm4
			vcvtdq2ps ymm5, ymm5
			vcvtdq2ps ymm6, ymm6
			
			; divide all the accumulators by blur_radius
			vdivps ymm0, ymm0, ymm15    ; WARNING: THIS INSTRUCTION SHOULD TAKE 3 REGISTERS.   ALSO, THE ORDER MIGHT BE WRONG
			vdivps ymm1, ymm1, ymm15
			vdivps ymm2, ymm2, ymm15
			vdivps ymm3, ymm3, ymm15
			vdivps ymm4, ymm4, ymm15
			vdivps ymm5, ymm5, ymm15
			vdivps ymm6, ymm6, ymm15

			
			; convert them back to 32-bit integers
			vcvttps2dq ymm0, ymm0
			vcvttps2dq ymm1, ymm1
			vcvttps2dq ymm2, ymm2
			vcvttps2dq ymm3, ymm3
			vcvttps2dq ymm4, ymm4
			vcvttps2dq ymm5, ymm5
			vcvttps2dq ymm6, ymm6
			
				
			; extract the data out of them
			; image[r15d * EDI + r8d * 56 + {0, 8, 16, 24, 32, 40, 48} + {0,1,2,3,4,5,6,7}] = (char)[RAX + {0, 4, 8, 12, 16, 20, 24, 28}]

			
			xor r9, r9
			mov r9d, r15d
			imul r9d, EDI ; r9d = r15d*EDI.This doesn't change for any register in the current row
			imul r10d, r8d, 56
			;shl r10d, 3 ; r10d = 8*avxChunk*7
			
			add r10d, r9d
			mov r9d, r10d ; r9d now contains 56*avxChunk + r15d*EDI.For each next register, add 8*i (0-48)
						
			; extracting all 8 pixel components from a 256-bit register:
				; mov temp8bitRegister, [RAX+{0, 4, 8, 12, 16, 20, 24, 28}]
			
			; image[r15d * EDI + r8d * 56 + {0,8,16,24,32,40,48} + {0,1,2,3,4,5,6,7}] = (unsigned char)(unloadArea[{0,4,8,12,16,20,24,28}]);
			; ymm0
			vmovdqa [RAX], ymm0
			call .unloadingUtility
					
			lea r10d, [r9d + 8]
			; ymm1
			vmovdqa [RAX], ymm1
			call .unloadingUtility
			
			lea r10d, [r9d + 16]
			; ymm2
			vmovdqa [RAX], ymm2
			call .unloadingUtility
			
			lea r10d, [r9d + 24]
			; ymm3
			vmovdqa [RAX], ymm3
			call .unloadingUtility
			
			lea r10d, [r9d + 32]
			; ymm4
			vmovdqa [RAX], ymm4
			call .unloadingUtility
			
			lea r10d, [r9d + 40]
			; ymm5
			vmovdqa [RAX], ymm5
			call .unloadingUtility
			
			lea r10d, [r9d + 48]
			; ymm6
			vmovdqa [RAX], ymm6
			call .unloadingUtility
		
		
			; check .AVXchunkLoop
			inc r8d 
			cmp r8d, EBX
			jl .AVXchunkLoop
		
		; check .rowLoop
		inc EDI 
		cmp EDI, r14d
		jl .rowLoop
	
	
	; blur the leftovers 
	; if((3*imageWidth) % 56 != 0)
	
	xor RAX, RAX
	xor RDX, RDX
	mov ESI, 56
	idiv ESI
	
	cmp EDX, 56
	jnz .leftOvers
	
	
	ret
	
	
	.leftOvers:
		; unsigned int startingColumn = numOfReads * availableRegisters * 8;
		imul EDI, EBX, 56
		mov dword [temporaryValue], EDI
		call _vertical_blur_serial
		ret
		
		;unsigned int startingColumn = numOfReads * availableRegisters * 8; //8 is the number of floats that fit into a 256-bit register
        
        ;unsigned int tripleWidth = imageWidth * 3;
        ;for (unsigned int y = 0; y < imageHeight; y++)
        ;{
            ;unsigned int tempIndex = y * tripleWidth;
            ;for (unsigned int x = startingColumn; x <= (tripleWidth - 3); x += 3) // !!!!!!!!!!!!!!!!!!!!!!!!!!!
            ;{
                ;image[tempIndex + x] = 0;
                ;image[tempIndex + x + 1] = 0;
                ;image[tempIndex + x + 2] = 0;
            ;}
        ;}
        mov r14w, [image_height]
        xor r15, r15
        mov r15w, [image_width]
        imul r15d, r15d, 3
        
        
        xor RDX, RDX
        xor RAX, RAX
		mov r13, [first_pixel_address]
        xor r8, r8
        xor r9, r9 ; y 
        
        ;imul ESI, r15d, 3 ; r15d = tripleWidth
        mov ECX, r15d
        sub ECX, 3 ; ECX = tripleWidth - 3
        .yLoop:
			mov EAX, r15d
			imul EAX, r9d ; EAX = tempIndex
			mov EDX, EDI ; EDX = x
			.xLoop:
				lea r8, [r13 + RDX] ; temp
				add r8, RAX
				mov [r8], byte 0
				mov [r8 + 1], byte 0
				mov [r8 + 2], byte 0
				; check xLoop
				add EDX, 3
				cmp EDX, ECX
				jle .xLoop
			
        
			; check yLoop
			inc r9d
			cmp r9d, r14d
			jl .yLoop

		
		ret ; for .leftOvers
	
	.calculate_edges:
		; upperEdge = max(0, row - split); //PROBLEM!Only signed ints must be used here.
		
		;xor r9, r9
		;xor rcx, rcx
		mov ESI, EDI 
		sub ESI, r11d
		cmp ESI, 0 
		jl .isNegative ; set SI (upperEdge) to 0 if row - split is less than 0
		jmp .notNegative
		.isNegative: ; set ESI to zero
			xor ESI, ESI
		.notNegative:
		
		; lowerEdge = min(image_height - 1, row + split);
		
		; image_height - 1
		lea ECX, [r14d-1]
		
		; row + split
		lea r9d, [EDI + r11d]
		
		
		; this might be incorrect, check it out later.I have no clue how cmovs works.
		cmp r9d, ECX
		cmovs ECX, r9d; if row + split is less than image_height - 1...
		mov EDX, ESI ; get a copy of upperEdge.This is needed because ECX is used as a counter so its value will be lost.
		
		jmp .edgesCalculated
	
	
	.zeroRegisters:
		vxorps ymm0, ymm0, ymm0
		vxorps ymm1, ymm1, ymm1
		vxorps ymm2, ymm2, ymm2
		vxorps ymm3, ymm3, ymm3
		vxorps ymm4, ymm4, ymm4
		vxorps ymm5, ymm5, ymm5
		vxorps ymm6, ymm6, ymm6
		jmp .zeroedOut
		
		
		
	.unloadingUtility:
			; add 1 do r10 for next register
			
			push RSI
			; 1st int
			mov SIL, [RAX]
			mov [r13+r10], SIL
			; 2nd int
			mov SIL, [RAX + 4]
			mov [r13+r10+1], SIL
			; 3rd int
			mov SIL, [RAX + 8]
			mov [r13+r10+2], SIL
			; 4th int
			mov SIL, [RAX + 12]
			mov [r13+r10+3], SIL		
			; 5th int
			mov SIL, [RAX + 16]
			mov [r13+r10+4], SIL		
			; 6th int
			mov SIL, [RAX + 20]
			mov [r13+r10+5], SIL		
			; 7th int
			mov SIL, [RAX + 24]
			mov [r13+r10+6], SIL	
			; 8th int
			mov SIL, [RAX + 28]
			mov [r13+r10+7], SIL
			
			pop RSI
			ret		
