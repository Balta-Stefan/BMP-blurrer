; there is a problem with the way I am passing messages to the _printErrorMessage
; I am passing messages as arguments regardless of whether an error occured

; TO DO:
; allow the user to pass blur radius as argument.The program has to check if the value is odd or even (it must be odd).

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
	DW image_width ; short 
	DW image_height ; short 
	
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
	
	; check if bits per pixel in the header equals 24 - to do
	
	
	; check for consistency of header image dimensions - to do
	
	; find first_pixel_address, image_width, image_height - to do 
		
	call _blur_serial
	
	; blur operation done
	call _end
	
_blur_serial:
	; allocate space for temporary_image_ptr of size image_width*image_height.TO DO 
	
	call _horizontal_blur_serial
	call _vertical_blur_serial
	
	; pass arguments and call output_to_file - to do
	
	
_horizontal_blur_serial:
	; row counter - ECX 
	; column counter - EDI
	
	; zero out the loop counters
	xor RCX, RCX 
	xor RDI, RDI
	
	; r8d - leftEdge 
	; r9d - rightEdge
		
	; r15d - number three.Used in multiplication inside .blur_loop	
	mov r15d, 3
	; r14 - image_width 
	mov r14d, [image_width]
	; r13 - image_height 
	mov r13d, [image_height]
		
	; div instruction: EDX:EAX contain the dividend, EDX must sit unused (and zeroed out)
	xor RDX, RDX
	
	; [row counter] loop from 0 to image_height 
	.rowLoop:
		; [column counter] loop from 0 to image_width
			.columnLoop:
				call .calculate_edges
				
				; zero out accumulators on every radius iteration
				xor RBX, RBX ; red accumulator - RBX
				xor RSI, RSI ; green accumulator - RSI
				xor RDI, RDI ; blue accumulator - RDI
				
				; [i counter] - loop from leftEdge to rightEdge (inclusive)
				.blur_loop:
						; 3*(row*image_width+i)
						mov r10d, ECX ; r10d now contains .rowLoop counter
						imul r10d, r14d ; multiply by image_width
						add r10d, r8d ; add .blur_loop counter
						imul r10d, r15d ; multiply by 3
						
						; r11 now contains the address of the current pixel 
						lea r11, [first_pixel_address + r10d]
						
						; EBX += pixelData + 3*(row*image_width+i)
						; ESI += pixelData + 3*(row*image_width+i)+1)
						; EDI += pixelData + 3*(row*image_width+i)+2)
						add EBX, [r11]
						add ESI, [r11+1]
						add EDI, [r11+2]
						
						
						; test .blur_loop 
						inc r8d
						cmp r8d, r9d 
						jle .blur_loop
				
				
				
				
				mov r11d, dword [blur_radius]
				; EBX /= blur_radius
				mov EAX, EBX
				div r11d
				mov EBX, EAX
				
				; ESI /= blur_radius 
				mov EAX, ESI
				div r11d
				mov ESI, EAX
				
				; EDI /= blur_radius 
				mov EAX, EDI
				div r11d
				mov EDI, EAX
				
				; r11d = newPixelIndex = 3*row*image_width + column
				mov r11d, r14d
				imul r11d, ECX 
				imul r11d, r15d
				add r11d, EDI 
				
				; address of the current pixel in the new picture
				lea r12, [temporary_image_ptr + r11d]
				
				; temporary_image_ptr[newPixelIndex+0] = BL (RBX[0-7])
				mov [r12], BL
				; temporary_image_ptr[newPixelIndex+1] = SIL (RSI[0-7])
				inc r12
				mov [r12], SIL
				; temporary_image_ptr[newPixelIndex+2] = DIL (RDI[0-7])
				inc r12
				mov [r12], DIL
			
				; check columnLoop status
				inc RDI 
				cmp RDI, r14d ; compare with image_width
				jb .columnLoop
			
		; check rowLoop status
		inc RCX
		cmp RCX, r13d ; comare with image_height
		jb .rowLoop
		
	; done
	ret 
	
	; PROBLEM!!!CMOVS might not be used correctly
	.calculate_edges:
		; leftEdge = max(0, (signed short)columnLoop - (signed short)split);
		
		mov r8d, EDI
		sub r8d, word [split]
		cmp r8d, 0
		cmovs r8d, 0; conditional move that happens if r8 - split is < 0
		
		; image_width - 1
		mov r9d, r14d
		dec r9d
		
		; column counter + split
		mov r10d, EDI
		add r10d, word [split]
		
		; rightEdge = min(image_width - 1, column_counter + split);
		cmp r10d, r9d
		cmovs r9d, r10d; if column_counter + split is less than image_width - 1
		
		ret 
	
_vertical_blur_serial:
	; in order to better use the cache, whole rows will be scanned
	
	; r15d = 3
	mov r15d, 3
	; r14d = image_width
	mov r14d, [image_width]
	; r13d = image_height
	mov r13d, [image_height]
	
	; r12d = 3*image_width*sizeof(short) - since short is 2 bytes long, *2 can be done with left shift 
	; 
	imul r12d, r14d, 3
	shl r12d, 1 ; multiply by 2 (sizeof(short))
	
	; pass argument for allocate (r12d) - to do
	; the value in r12d will be used for zeroing out the row_accumulator
	
	; row_accumulator = allocate space equal to image_width*3*sizeof(short) - to do
	mov r8, RAX ; r8 now contains the pointer to the row_accumulator
	
	xor RCX, RCX ; RCX - row counter
	xor RDX, RDX ; RDX - column counter 
	xor RSI, RSI ; RSI - i counter
	
	; [row counter] loop from 0 to image_height
	.row_loop:
		; zero out the row_accumulator (arguments are r12d and the row_accumulator) - to do 
		
		call .calculate_edges
		mov ESI, r8d
		
		; [i counter] loop from upperEdge to lowerEdge (inclusive)
		.blurLoop:
			; [column counter] loop from 0 to image_width 
			.columnLoop:
				; EAX will contain 3*column
				imul EAX, EDX, 3
				; EBX will contain i*image_width+column
				mov EBX, ESI
				imul EBX, r14d
				add EBX, EDX
				
				; r11 contains address of row_accumulator[3*column]
				lea r11, []
				
				; row_accumulator[3 * column] += temporary_image_ptr[i * image_width + column].red;
                
				
				; row_accumulator[3 * column + 1] += temporary_image_ptr[i * image_width + column].green;
                inc EBX
				inc EAX
				
				; row_accumulator[3 * column + 2] += temporary_image_ptr[i * image_width + column].blue;
				inc EBX
				inc EAX
			
				; test .columnLoop
				inc EDX
				cmp EDX, r14d
				jl .columnLoop
				
			; check .blurLoop
			inc ESI
			cmp ESI, r9d 
			jle .blurLoop

		; [column counter] loop from 0 to image_width
			; row_accumulator[3 * column] /= blurRadius;
            ; row_accumulator[3 * column + 1] /= blurRadius;
            ; row_accumulator[3 * column + 2] /= blurRadius;
			
            ; image[3 * (row * imageWidth + column)] = row_accumulator[3 * column];
            ; image[3 * (row * imageWidth + column) + 1] = row_accumulator[3 * column + 1];
            ; image[3 * (row * imageWidth + column) + 2] = row_accumulator[3 * column + 2];
			
			
		; check row_loop
		inc RCX
		cmp RCX, [image_height]
			
	; free the space held by row_accumulator

	; PROBLEM!!!CMOVS might not be used correctly
	.calculate_edges:
		; upperEdge = max(0, row - split); //PROBLEM!Only signed ints must be used here.
        mov r8d, ECX
		sub word [split]
		cmp r8d, 0
		cmovs r8d, 0 ; set r8d to 0 if row - split is less than 0
		
		
		; lowerEdge = min(image_height - 1, row + split);
		
		; image_height - 1
		mov r9d, r13d
		dec r9d
		
		; row + split
		mov r10d, ECX
		add r10d, word [split]
		
		; rightEdge = min(image_height - 1, row + split);
		cmp r10d, r9d
		cmovs r9d, r10d; if row + split is less than image_height - 1
		
		ret 



	; done
		
			