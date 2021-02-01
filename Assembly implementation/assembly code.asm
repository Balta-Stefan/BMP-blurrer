; there is a problem with the way I am passing messages to the _printErrorMessage
; I am passing messages as arguments regardless of whether an error occured

; TO DO:
; allow the user to pass blur radius as argument.The program has to check if the value is odd or even (it must be odd).

extern output_to_file ; writes blurred image to a file.Written in C - to do

segment data 
	blur_radius ; enter this manually
	split ; integer.This value is equal to (blur_radius-1)/2.Enter this manually
	
	BMP_magic_number ; equals 19778
	unsuccessful_image_load "Image can't be loaded"
	invalid_magic_number "Invalid magic number"

segment bss
	image_pointer ; 64-bits 
	pixel_offset ; integer
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
	; row counter - RCX 
	; column counter - RDI
	
	; [row counter] loop from 0 to image_height 
		; [column counter] loop from 0 to image_width
			; leftEdge = max(0, (signed int)x - (signed int)split);
	        ; rightEdge = min(imageWidth - 1, x + split);
			
			; zero out accumulators on every radius iteration
			; red accumulator - RBX
			; green accumulator - RSI
			; blue accumulator - RDI
			
			; [i counter] - loop from leftEdge to rightEdge (inclusive)
				; RBX += pixelData + 3*(row*image_width+i)
				; RSI += pixelData + 3*(row*image_width+i+1)
				; RDI += pixelData + 3*(row*image_width+i+2)
			
			; RBX /= blur_radius
			; RSI /= blur_radius 
			; RDI /= blur_radius 
			
			; newPixelIndex = row*image_width + column
			; temporary_image_ptr[newPixelIndex+0] = RBX
			; temporary_image_ptr[newPixelIndex+1] = RSI
			; temporary_image_ptr[newPixelIndex+2] = RDI
	
	; done
	
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
			
			
			
			