; there is a problem with the way I am passing messages to the _printErrorMessage
; I am passing messages as arguments regardless of whether an error occured

; TO DO:
; allow the user to pass blur radius as argument.The program has to check if the value is odd or even (it must be odd).

extern output_to_file ; writes blurred image to a file.Written in C - to do

segment data 
	blur_radius ; 2 byte value enter this manually
	split ; 2 byte value.This value is equal to (blur_radius-1)/2.Enter this manually
	
	BMP_magic_number ; equals 19778
	unsuccessful_image_load "Image can't be loaded"
	invalid_magic_number "Invalid magic number"

segment bss
	image_pointer ; 64-bits 
	pixel_offset ; 64-bits.The address of the first pixel.
	image_width ; integer 
	image_height ; integer 
	
	temporary_image_ptr ; pointer to the new image
	
segment text 



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
	
	; find pixel_offset, image_width, image_height - to do 
		
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
		
	; r11d - number three.Used in multiplication inside .blur_loop	
	mov r11d, 3
		

	
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
						mov r11d, [image_width]
						imul r10d, r11d
						add r10d, r8d ; r10d now contains .blur_loop counter
						imul r10d, r11d 
						
						; r11d now contains the address of the current pixel 
						lea r11d, ; is it allowed to do [pixel_offset + r10d]?
						
						; RBX += pixelData + 3*(row*image_width+i)
						; RSI += pixelData + 3*(row*image_width+i)+1)
						; RDI += pixelData + 3*(row*image_width+i)+2)
						
						; test .blur_loop 
						inc r8d
						cmp r8d, r9d 
						jle .blur_loop
				
				; RBX /= blur_radius
				; RSI /= blur_radius 
				; RDI /= blur_radius 
				
				; newPixelIndex = row*image_width + column
				; temporary_image_ptr[newPixelIndex+0] = RBX
				; temporary_image_ptr[newPixelIndex+1] = RSI
				; temporary_image_ptr[newPixelIndex+2] = RDI
			
			
				; check columnLoop status
				inc RDI 
				cmp RDI, [image_width]
				jb .columnLoop
			
		; check rowLoop status
		inc RCX
		cmp RCX, [image_height]
		jb .rowLoop
		
	; done
	ret 
	
	; PROBLEM!!!CMOVS might not be used correctly
	.calculate_edges:
		; leftEdge = max(0, (signed short)columnLoop - (signed short)split);
		
		mov r8, RDI
		cmp r8, [split]
		cmovs r8d, 0; conditional move that happens if r9 - split is < 0
		
		; image_width - 1
		mov r9, image_width
		dec r9
		
		; column counter + split
		mov r10, RDI
		add r10, split 
		
		; rightEdge = min(image_width - 1, column_counter + split);
		cmp r10d, r9d
		cmovs r9d, r10d; if column_counter + split is less than image_width - 1
		
		ret 
	
_vertical_blur_serial:
	; in order to better use the cache, whole rows will be scanned
	
	; row_accumulator = allocate space equal to image_width*3*sizeof(short)
	
	; [row counter] loop from 0 to image_height
		; zero out the row_accumulator
		; upperEdge = max(0, (int)row - (int)split); //PROBLEM!Only signed ints must be used here.
        ; lowerEdge = min(image_height - 1, row + split);
	
		; [i counter] loop from upperEdge to lowerEdge (inclusive)
			; [column counter] loop from 0 to image_width 
				; row_accumulator[3 * column] += temporary_image_ptr[i * image_width + column].red;
                ; row_accumulator[3 * column + 1] += temporary_image_ptr[i * image_width + column].green;
                ; row_accumulator[3 * column + 2] += temporary_image_ptr[i * image_width + column].blue;

		; [column counter] loop from 0 to image_width
			; row_accumulator[3 * column] /= blurRadius;
            ; row_accumulator[3 * column + 1] /= blurRadius;
            ; row_accumulator[3 * column + 2] /= blurRadius;
			
            ; image[3 * (row * imageWidth + column)] = row_accumulator[3 * column];
            ; image[3 * (row * imageWidth + column) + 1] = row_accumulator[3 * column + 1];
            ; image[3 * (row * imageWidth + column) + 2] = row_accumulator[3 * column + 2];
			
			
	; free the space held by row_accumulator

	; done
			
			
			
			