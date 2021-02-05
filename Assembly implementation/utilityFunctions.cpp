#include <iostream>
#include <fstream>
#include <cstring>

std::string pictureName;

extern "C" void startAssembly();
extern char* image_pointer;
extern char* first_pixel_address;
extern char* temporary_image_ptr;
extern unsigned short image_width;
extern unsigned short image_height;
extern unsigned short* row_accumulator;
extern int blur_radius;
extern short split;
extern char serial; //0 = perform serial computation.1 = perform computation with AVX.


extern "C" int loadPicture();
extern "C" void allocate_row_accumulator();
extern "C" void free_row_accumulator();
extern "C" void writePicture();
extern "C" void allocate_temporary_image_buffer();
extern "C" unsigned int* allocateAlignedArray();

#pragma pack(1)
struct BMP_file_header
{
    short magicNumber; //it must be equal to 0x4D42 (ASCII for MB.Because of little endian, it should be read as BM)
    unsigned int size; //size of the whole BMP file in bytes
    int reserved; //unused
    unsigned int dataOffset; //starting address of the first byte of the image data (pixel array)
};

#pragma pack(1)
struct DIB_header
{
    unsigned int size; //size of this structure in bytes (must be equal to 40)
    unsigned int width; //width in pixels
    unsigned int height; //height in pixels
    unsigned short planes; //number of planes.Must be set to 1.
    unsigned short bits_per_pixel;
    unsigned int compression; //if 0, there is no compression
    unsigned int image_size; //size of image.Set to 0 if compression is 0
    unsigned int X_pixels_per_meter; //horizontal resolution
    unsigned int Y_pixels_per_meter; //vertical resolution
    unsigned int colors_used;
    unsigned int important_colors;
};

#pragma pack(1)
struct headers
{
    BMP_file_header fileHeader;
    DIB_header infoHeader;
};

int main(int argc, char** argv)
{
	if(argc != 4)
	{
		std::cout << "Enter arguments in the following format: <blur radius> <serial flag> <name of the picture>" << std::endl;
		return -1;
	}
	
	
	try
	{
		 blur_radius = std::stoi(argv[1]);
		 if(blur_radius <= 0 || blur_radius % 2 == 0)
		 {
			 std::cout << "Blur radius must be a positive odd number" << std::endl;
			 return -1;
		 }
		 split = (blur_radius-1)/2;
	}
	catch(std::exception exc)
	{
		std::cout << "Wrong argument input" << std::endl;
		return -1;
	}
	if(argv[2][0] == '0')
		serial = 0;
	
		
	else if(argv[2][0] == '1')
		serial = 1;
	
	else 
	{
		std::cout << "Serial/AVX flag must be 0 or 1." << std::endl;
		return -1;
	}
	
	
	pictureName = argv[3];
	
	if(loadPicture() != 0)
	{
		std::cout << "Error reading the input file." << std::endl;
		return -1;
	}
	
	startAssembly();
	
	return 0;
}



extern "C"
{
	int loadPicture()
	{
		
		std::ifstream fileInput(pictureName.c_str(), std::ios::in | std::ios::binary);
		headers metaData;
		//int a = sizeof(headers);
		if (!fileInput)
			return -1;

		//get file size by seeking to the end, and then reverting to the beginning
		fileInput.seekg(0, std::ios::end);
		unsigned int size = fileInput.tellg();
		fileInput.seekg(0);
		
		image_pointer = (char*)aligned_alloc(16, size); //16 byte memory alignment
		//char* image = new char[size];
		//std::cout << "before reading file" << std::endl;
		if (!fileInput.read((char*)image_pointer, size))
		{
			return -1;
		}
		//std::cout << "after reading file" << std::endl;

		fileInput.close();
		metaData = *((headers*)image_pointer);

		//fileInput.read((char*)&metaData, sizeof(headers));
	   
		if (metaData.fileHeader.magicNumber != 19778)
		{
			std::cout << "Incorrect magic number" << std::endl;
			return -1;
		}
		if (metaData.infoHeader.bits_per_pixel != 24)
		{
			std::cout << "Image doesn't have 3 bytes per pixel" << std::endl;
			return -1;
		}
		if (3 * metaData.infoHeader.width * metaData.infoHeader.height != metaData.infoHeader.image_size)
		{
			std::cout << "Image size incosistent" << std::endl;
			return -1;
		}
		
		first_pixel_address = &image_pointer[metaData.fileHeader.dataOffset];
		image_width = metaData.infoHeader.width;
		image_height = metaData.infoHeader.height;
		
		return 0;
	}
}


extern "C"
{
	void allocate_row_accumulator()
	{
		row_accumulator = new unsigned short[3*image_width];
	}
}
extern "C"
{
	void free_row_accumulator()
	{
		delete[] row_accumulator;
	}
}

extern "C"
{
	void allocate_temporary_image_buffer()
	{
		//allocate space for temporary_image_ptr of size image_width*image_height
		temporary_image_ptr = (char*)malloc(3*image_width*image_height);
	}
}



extern "C"
{
	void writePicture()
	{
		unsigned int totalSize = image_width * image_height * 3;

		//memcpy(first_pixel_address, temporary_image_ptr, totalSize);
		std::ofstream outputFile("blurred.bmp", std::ios::out | std::ios::binary);
		outputFile.write((char*)image_pointer, (std::streamsize)totalSize+sizeof(headers));
		outputFile.close();

	}
}

extern "C"
{
	unsigned int* allocateAlignedArray()
	{
		return (unsigned int*)aligned_alloc(32, 7 * sizeof(unsigned int)); //only 7 AVX registers will be used
	}
}
