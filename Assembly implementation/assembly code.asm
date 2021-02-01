; there is a problem with the way I am passing messages to the _printErrorMessage
; I am passing messages as arguments regardless of whether an error occured

; TO DO:
; allow the user to pass blur radius as argument.The program has to check if the value is odd or even (it must be odd).



; register r15d holds image_width
; register r14d holds image_height 
; register r13 is holding the address of the beginning of the picture pixels.
; register r12w is holding the variable blur_radius 
; register r11w is holding the variable split (split = (blur_radius-1)/2)


extern output_to_file ; writes blurred image to a file.Written in C - to do

SECTION .data 
	DW blur_radius ; 2 byte value enter this manually
	DW split ; 2 byte value.This value is equal to (blur_radius-1)/2.Enter this manually
	
	DW BMP_magic_number 19778 ; equals 19778
	DB unsuccessful_image_load "Image can't be loaded"
	DB invalid_magic_number "Invalid magic number"

SECTION .bss
	DQ image_pointer ; 64-bits 
	DQ first_pixel_address ; 64-bits.The address of the first pixel.
	DW image_width ; short.Will be kept in register r15d.
	DW image_height ; short.Will be kept in register r14d.
	
	DQ temporary_image_ptr ; pointer to the new image
	
SECTION .text 
global _start


_printErrorMessage:
	; print the message that was passed as argument- TO DO
	call _end
	
_end:
	; terminate the program

extern loadPicture ; written in C.Takes imagePointer as the address at which the image will be stored
_start:
	; pass imagePointer as parameter - to do 
	call loadPicture
	; check the return value of loadPicture.If it is zero, exit the program
	cmp rax, 0
	; pass unsuccessfulImageLoad as parameter - to do
	call _printErrorMessage
	
	; check the validity of magic number (2 bytes)
	mov dx, image_pointer ; this might be incorrect.Little endian SHOULD be used
	cmp [BMP_magic_number], dx ; this might be incorrect (BMP_magic_number might need to be stored in a register first)
	; pass invalid_magic_number as argument - to do
	jne _printErrorMessage
	
	
	; find first_pixel_address, image_width, image_height - to do 
	lea [first_pixel_address], qword [image_pointer + 10]
	mov r13, [first_pixel_address]
	lea RAX, [image_pointer + 18]
	mov [image_width], [RAX]
	mov [image_height], [RAX+4] ; this might not be allowed.If it isn't, image_height is at the address image_pointer + 22
	
	; check if bits per pixel in the header equals 24 - to do
	
	
	; check for consistency of header image dimensions - to do
	
	
	; since image_width and image_height will be used often, they will be loaded into registers 
	xor r15, r15
	xor r14, r14
	
	mov r15d, [image_width]
	mov r14d, [image_height]
	
	; blur_radius and split are also used very often
	xor r11d, r11d
	xor r12d, r12d
	
	mov r12w, word [blur_radius]
	mov r11w, word [split]

	call _blur_serial
	
	; blur operation done
	call _end
	
_blur_serial:
	; allocate space for temporary_image_ptr of size image_width*image_height.TO DO 
	
	call _horizontal_blur_serial
	call _vertical_blur_serial
	
	; pass arguments and call output_to_file - to do
	
	
_horizontal_blur_serial:
	; variables: 
		; row counter (y) -> ESP 
		; column counter (x) -> EBX 
		; leftEdge -> ECX
		; rightEdge -> ESI
		; 3 16-bit accumulators for pixel components
			; r10w - red 
			; r9w - green 
			; r8w - blue
		; blur loop counter (i) - ECX
		; value of 3*(y*imageWidth+i) - EDI
		; for division - RAX - only it can be used for division
		
	push RSP 
	push RBP 
	mov RBP, [temporary_image_ptr]
		

	; row counter - EAX 
	; column counter - EBX
	
	; zero out the loop counters
	xor ESP, ESP 
	xor RBX, RBX

		
		
	; div instruction: EDX:EAX contain the dividend, EDX must sit unused (and zeroed out)
	xor RDX, RDX
	
	; [row counter] loop from 0 to image_height 
	.rowLoop:
		; [column counter] loop from 0 to image_width
			.columnLoop:
				call .calculate_edges
				
				; zero out accumulators on every radius iteration
				xor r10d, r10d ; red accumulator - r10d
				xor r9d, r9d ; green accumulator - r9d
				xor r8d, r8d ; blue accumulator - r8d
				
				; [i counter] - loop from leftEdge to rightEdge (inclusive)
				.blur_loop:
						; 3*(row*image_width+i)
						mov RDI, ESP
						imul EDI, r15d
						add EDI, ECX
						imul EDI, EDI, 3
						
						; EDI now contains the address of the current pixel 
						lea RDI, [r13 + RDI]
						
						; red += pixelData + 3*(row*image_width+i)
						; green += pixelData + 3*(row*image_width+i)+1)
						; blue += pixelData + 3*(row*image_width+i)+2)
						add r10w, word [RDI]
						add r9w, word [RDI+1]
						add r8w, word [RDI+2]
						
						; test .blur_loop 
						inc ECX
						cmp ECX, ESI 
						jle .blur_loop
				
				; red /= blur_radius
				mov EAX, r10d
				div r12d
				mov r10d, EAX
				
				; green /= blur_radius 
				mov EAX, r9d
				div r12d
				mov r9d, EAX
				
				; blue /= blur_radius 
				mov EAX, r8d
				div r12d
				mov r8d, EAX
				
				
				mov EAX, ESP
				imul EAX, r15d 
				add EAX, EBX ; EAX now holds y*imageWidth + x
				
				
				mov RDX, [temporary_image_ptr]
				; address of the current pixel in the new picture
				add RDX, r11d
				
				mov [RDX], r10b ; store back new value of red component
				
				inc RDX
				mov [RDX], r9b ; store back new value of green component
				
				inc RDX
				mov [RDX], r8b ; store back new value of blue component
				
				xor RDX, RDX ; zero out because of division in the next iteration
				

			
				; check columnLoop status
				inc RDI 
				cmp RDI, r14d ; compare with image_width
				jb .columnLoop
			
		; check rowLoop status
		inc ESP
		cmp ESP, r14d ; compare with image_height
		jb .rowLoop
		
	; done
	pop RBP
	pop RSP
	
	ret 
	
	; PROBLEM!!!CMOVS might not be used correctly
	.calculate_edges:
		; leftEdge = max(0, (signed short)columnLoop - (signed short)split);
		

		sub EDI, r11
		cmp EDI, 0
		cmovs ECX, 0
		
		; image_width - 1
		lea r10d, [r15d-1]
		
		; column counter + split
		lea ESI, [EBX + r11d]
		
		; rightEdge = min(image_width - 1, column_counter + split);
		cmp r10d, ESI
		cmovs ESI, r10d; if image_width - 1 is less than column_counter + split, move r10d to ESI (right edge)
		
		ret 
	
_vertical_blur_serial:
	; in order to better use the cache, whole rows will be scanned
	
	; variables:
		; row accumulator address -> RBP 
		; row counter -> ESP
		; column counter -> EBX 
		; upper edge -> ECX 
		; lower edge -> ESI
		; first blur loop (.blurLoop) -> ECX (also division loop counter)
		; second blur loop (.columnLoop) -> r10 
		; rowAccumulator[3*x] -> r9 
		; blurredImage[i*imageWidth + x] -> r8
		; division loop counter -> ECX 
		; rowAccumulator[3*x] -> r9
			; this should be intertwined with storage into image because the value is reused 
			; image[3*(y*imageWidth+x)] -> r10
		
	push RBP 
	push RSP 
	
	
	; allocate space for row accumulator - to do
	
	xor RSP, RSP
	xor RCX, RCX
	xor r10, r10
	
	; [row counter] loop from 0 to image_height
	.row_loop:
		; zero out the row_accumulator (arguments are imageWidth*2 and the row_accumulator) - to do 
		
		call .calculate_edges
		; image height isn't necessary anymore, but its register is needed to store the value of horizontally blurred pixel
		push r14
		push RSP ; RSP will be used for the accumulator value (rowAccumulator[3 * x])
		
		
		; prepare blurredImage[i * imageWidth] pointer 
		mov r8, RCX
		imul r8, r15
		add r8, [temporary_image_ptr]
		; blurredImage pointer has to be set up only before the .blurLoop, all the additions within the .columnLoop will bring is to the new row for free
		
		; [i counter] loop from upperEdge to lowerEdge (inclusive)
		.blurLoop:
			; [column counter] loop from 0 to image_width 
			mov r9, [RBP] ; this only goes from 0 to imageWidth, next loop will handle the index moving
			.columnLoop:
				; r14b will hold the pixel that is loaded from memory.That's why it was pushed on the stack, THERE ARE NO REGISTERS LEFT!!!
				
				; increment the red accumulator
				mov r14b, [r8]
				mov SP, [r9]
				add SP, r14b
				mov [r9], SP
				
				; increment the green acumulator
				inc r8
				inc r9
				mov r14b, [r8]
				mov SP, [r9]
				add SP, r14b 
				mov [r9], SP 
				
				; increment the blue accumulator
				inc r8 
				inc r9
				mov r14b, [r8]
				mov SP, [r9]
				add SP, r14b 
			    mov [r9], SP 
				
				
				; test .columnLoop
				inc r10d
				cmp r10d, r15d
				jl .columnLoop
				
				
			inc r8 ; get into the next row.Now r8 holds the first pixel of the next row
			
			; check .blurLoop
			inc ECX
			cmp ECX, ESI 
			jle .blurLoop
		
		; [column counter] loop from 0 to image_width
			; row_accumulator[3 * column] /= blurRadius;
            ; row_accumulator[3 * column + 1] /= blurRadius;
            ; row_accumulator[3 * column + 2] /= blurRadius;
			
            ; image[3 * (row * imageWidth + column)] = row_accumulator[3 * column];
            ; image[3 * (row * imageWidth + column) + 1] = row_accumulator[3 * column + 1];
            ; image[3 * (row * imageWidth + column) + 2] = row_accumulator[3 * column + 2];
			
		xor r10, r10
		.averagingLoop:
			; TO DO
			
			; check the loop counter 
			inc r10d
			cmp r10d, r15d 
			jl .averagingLoop
			
			
		pop RSP
		pop r14
		; check row_loop
		inc ESP
		cmp ESP, r14d
		jl .row_loop
		
	; done
	; delete space reserved for row accumulator - to do 
	
	pop RSP
	pop RBP
	ret
	
	

	; PROBLEM!!!CMOVS might not be used correctly
	.calculate_edges:
		; upperEdge = max(0, row - split); //PROBLEM!Only signed ints must be used here.
		
		mov ECX, ESP 
		sub ECX, r11d
		cmp 0, ECX
		
		cmovs ECX, 0 ; set ECX to 0 if row - split is less than 0
		
		
		; lowerEdge = min(image_height - 1, row + split);
		
		; image_height - 1
		mov EBX, r14d
		dec EBX
		
		; row + split
		lea ESI, [ESP + r11d]
		
		
		; this might be incorrect, check it out later.I have no clue how cmovs works.
		cmp EBX, ESI
		cmovs ESI, EBX; if row + split is less than image_height - 1
		
		ret 




			