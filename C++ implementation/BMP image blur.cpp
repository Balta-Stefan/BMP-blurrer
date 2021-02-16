// BMP image blur.cpp : This file contains the 'main' function. Program execution begins and ends there.
//

#include <iostream>
#include <fstream>
#include <chrono>
#include <algorithm>
#include <immintrin.h>
#include <string>

/*
Coordinates of the image start from the lower left corner.
Image is read from left to right, row at a time (from the bottom)

All summations of pixels use short because char will always overflow.
None of the vector instruction sets support integer division...This means that the only allowed radiuses must be a power of 2 so that division turns into right shifting.This is not possible because
blur radius MUST be an odd number.
*/

unsigned short blurRadius;
float blurRadiusFloat;
unsigned int imageWidth;
unsigned int imageHeight;
unsigned int split;
unsigned int pixelOffset;
unsigned int BMP_magic_number = 19778;

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

#pragma pack(1)
struct pixel
{
    unsigned char red;
    unsigned char green;
    unsigned char blue;
};



void toGrayscale(char* image, unsigned int dataOffset, unsigned int size)
{
    pixel* grayscale = new pixel[size];
    char* pixelData = image + dataOffset;

    for (unsigned int i = 0; i < size; i++)
    {
        pixel currentPixel = *((pixel*)(pixelData + 3 * i));
        char average = ((int)currentPixel.red + currentPixel.green + currentPixel.blue) / 3;
        currentPixel.red = average;
        currentPixel.green = average;
        currentPixel.blue = average;
        grayscale[i] = currentPixel;
    }

    int totalSize = size * 3;
    memcpy(pixelData, grayscale, totalSize);
    std::ofstream outputFile("grayscaled.bmp", std::ios::out | std::ios::binary);
    outputFile.write(image, totalSize + sizeof(headers));
    outputFile.close();
    delete[] grayscale;
}



void horizontalBlur(pixel* blurredImage, unsigned int imageWidth, unsigned int imageHeight, char* pixelData, unsigned int startRow, unsigned int endRow)
{
    for (unsigned int y = startRow; y < endRow; y++)
    {
        for (unsigned int x = 0; x < imageWidth; x++)
        {
            pixel newPixel;

            unsigned int leftEdge = std::max(0, (int)x - (int)split);
            unsigned int rightEdge = std::min(imageWidth - 1, x + split);

            unsigned short redAccumulator = 0;
            unsigned short greenAccumulator = 0;
            unsigned short blueAccumulator = 0;
            for (unsigned int i = leftEdge; i <= rightEdge; i++)
            {
                pixel tempPixel = *((pixel*)&pixelData[3 * (y * imageWidth + i)]);
                redAccumulator += tempPixel.red;
                greenAccumulator += tempPixel.green;
                blueAccumulator += tempPixel.blue;

                //redAccumulator += ((pixel*)(pixelData + 3 * (y * imageWidth + i)))->red;
                //greenAccumulator += ((pixel*)(pixelData + 3 * (y * imageWidth + i)))->green;
                //blueAccumulator += ((pixel*)(pixelData + 3 * (y * imageWidth + i)))->blue;
            }
            newPixel.red = redAccumulator / blurRadius;
            newPixel.green = greenAccumulator / blurRadius;
            newPixel.blue = blueAccumulator / blurRadius;

            unsigned int index = y * imageWidth + x;
            blurredImage[index] = newPixel;
            //*(blurredImage + y * imageWidth + x) = newPixel;
        }
    }
}
void verticalBlur(pixel* blurredImage, unsigned int imageWidth, unsigned int imageHeight, char* image, unsigned int startRow, unsigned int endRow, unsigned int startColumn)
{
    unsigned int tripleWidth = imageWidth * 3;
    unsigned short* rowAccumulator = new unsigned short[tripleWidth];
    unsigned char* blurredImagePixels = (unsigned char*)blurredImage;
    
    for (unsigned int y = startRow; y < endRow; y++)
    {
        //zero out the accumulator
        std::memset(rowAccumulator, 0, tripleWidth * sizeof(unsigned short));

        unsigned int upperEdge = std::max(0, (int)y - (int)split); //PROBLEM!Only signed ints must be used here.
        unsigned int lowerEdge = std::min(imageHeight - 1, y + split);

        for (unsigned int i = upperEdge; i <= lowerEdge; i++)
        {
            unsigned int sharedIndexValue = i * tripleWidth;
            for (unsigned int x = startColumn; x <= (tripleWidth - 3); x += 3)
            {
                rowAccumulator[x] += blurredImagePixels[sharedIndexValue + x];
                rowAccumulator[x + 1] += blurredImagePixels[sharedIndexValue + x + 1];
                rowAccumulator[x + 2] += blurredImagePixels[sharedIndexValue + x + 2];
            }
        }

        unsigned int sharedIndex = tripleWidth * y;
        unsigned int x = startColumn;
        for (; x <= (tripleWidth-3); x += 3)
        {   
            rowAccumulator[x] /= blurRadius;
            rowAccumulator[x + 1] /= blurRadius;
            rowAccumulator[x + 2] /= blurRadius;

            image[sharedIndex + x] = rowAccumulator[x];
            image[sharedIndex + x + 1] = rowAccumulator[x + 1];
            image[sharedIndex + x + 2] = rowAccumulator[x + 2];
        }

        if (x != tripleWidth)
        {
            for (; x < tripleWidth; x++)
            {
                rowAccumulator[x] /= blurRadius;
                image[sharedIndex + x] = rowAccumulator[x];
            }
        }
    }
    delete[] rowAccumulator;

}

/*
void verticalBlur(pixel* blurredImage, char* image, unsigned int imageWidth, unsigned int imageHeight, unsigned int startRow, unsigned int endRow, unsigned int split)
{
    unsigned short* rowAccumulator = new unsigned short[imageWidth * 3];
    for (unsigned int y = startRow; y < endRow; y++)
    {
        //zero out the accumulator
        std::memset(rowAccumulator, 0, imageWidth * sizeof(unsigned short) * 3);

        unsigned int upperEdge = std::max(0, (int)y - (int)split); //PROBLEM!Only signed ints must be used here.
        unsigned int lowerEdge = std::min(imageHeight - 1, y + split);

        for (unsigned int i = upperEdge; i <= lowerEdge; i++)
        {
            for (unsigned int x = 0; x < imageWidth; x++) 
            {
                rowAccumulator[3 * x] += blurredImage[i * imageWidth + x].red;
                rowAccumulator[3 * x + 1] += blurredImage[i * imageWidth + x].green;
                rowAccumulator[3 * x + 2] += blurredImage[i * imageWidth + x].blue;
            }
        }

        for (unsigned int x = 0; x < imageWidth; x++) 
        {
            rowAccumulator[3 * x] /= blurRadius;
            rowAccumulator[3 * x + 1] /= blurRadius;
            rowAccumulator[3 * x + 2] /= blurRadius;

            image[3 * (y * imageWidth + x)] = rowAccumulator[3 * x];
            image[3 * (y * imageWidth + x) + 1] = rowAccumulator[3 * x + 1];
            image[3 * (y * imageWidth + x) + 2] = rowAccumulator[3 * x + 2];
        }
    }
    delete[] rowAccumulator;

}*/

void blur(std::string pictureName, char* image, unsigned int pixelOffset, unsigned int startRow, unsigned int endRow)
{
    //naive implementation: width * height * intensity^2
    //blurring per each dimension separately: width*height*intensity + width*height*intensity = 2*width*height*intensity
        //first blur one dimension
        //using the results from the previous point, blur the second dimension

    /*
        Benchmark:
        -radius 3:   0.15 (cache thrashing version), 0.1 (cache efficientavx version)
        -radius 5:   0.17 (cache thrashing version), 0.12 (cache efficient version)
        -radius 11:  0.22 (cache thrashing version), 0.18 (cache efficient version)
        -radius 15:  0.25 (cache thrashing version), 0.22 (cache efficient version)
    */

    auto start = std::chrono::high_resolution_clock::now();

    int split = (blurRadius - 1) / 2;
    unsigned int imageSize = imageWidth * imageHeight;
    pixel* blurredImage = new pixel[imageSize];

    horizontalBlur(blurredImage, imageWidth, imageHeight, image + pixelOffset, startRow, endRow);
    //memcpy(blurredImage, image + pixelOffset, imageSize*3);
    verticalBlur(blurredImage, imageWidth, imageHeight, image + pixelOffset, startRow, endRow, 0);

    unsigned int totalSize = imageSize * 3;

    std::string outputFileName = pictureName + "_blurred_serial.bmp";

    //memcpy(image + pixelOffset, blurredImage, totalSize);
    std::ofstream outputFile(outputFileName.c_str(), std::ios::out | std::ios::binary);
    outputFile.write(image, (std::streamsize)totalSize + sizeof(headers));
    outputFile.close();

    //blur by horizontal axis first
    //blur by vertical axis, taking into account the values gained by horizontal blurring

    //optimisations: instead of using max() and min() on every step, perform calculations on the inner part of the picture that won't go out of bounds, and then
        //perform calculations using max() and min() for the rest that can go out of bounds



    auto stop = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> elapsed = stop - start;

    std::cout << "elapsed time (serial): " << elapsed.count(); //0.24 for cache thrashing version

    delete[] blurredImage;
}


void blurParallel(std::string pictureName, char* image, unsigned int pixelOffset)
{
    auto start = std::chrono::high_resolution_clock::now();

    int split = (blurRadius - 1) / 2;
    unsigned int imageSize = imageWidth * imageHeight;
    pixel* blurredImage = new pixel[imageSize];

    #pragma omp parallel for
    for (int y = 0; y < imageHeight; y++)
        horizontalBlur(blurredImage, imageWidth, imageHeight, image + pixelOffset, y, y + 1);

    //memcpy(blurredImage, image + pixelOffset, imageSize * 3);
    #pragma omp parallel for
    for (int y = 0; y < imageHeight; y++)
        verticalBlur(blurredImage, imageWidth, imageHeight, image + pixelOffset, y, y + 1, 0);


    auto stop = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> elapsed = stop - start;

    std::cout << "elapsed time (parallel): " << elapsed.count(); 

    std::string outputFileName = pictureName + "_blurred_parallel.bmp";

    int totalSize = imageSize * 3;
    //memcpy(image + pixelOffset, blurredImage, totalSize);
    std::ofstream outputFile(outputFileName.c_str(), std::ios::out | std::ios::binary);
    outputFile.write(image, (std::streamsize)totalSize + sizeof(headers));
    outputFile.close();

}

void nullifyFloatAVXregisters(__m256 registers[], unsigned int count)
{
    for (unsigned int i = 0; i < count; i++)
        registers[i] = _mm256_setzero_ps();
}

void nullifyIntAVXregisters(__m256i registers[], unsigned int count)
{
    for (unsigned int i = 0; i < count; i++)
        registers[i] = _mm256_setzero_si256();
}

void blurVerticalAVX(pixel* blurredImage, char* image, unsigned int imageWidth, unsigned int imageHeight, unsigned int startRow, unsigned int endRow, unsigned int split)
{
    //idea 2:
    //load 8 components into a 256-bit register.Convert that to int, and then convert to float.


    //======================

    //_mm_cvtsi32_si128 - Copy 32-bit integer a to the lower elements of dst, and zero the upper elements of dst.
    //256 bit register can hold 16 2-byte components.Pixel values have to be converted to shorts first.
    //The idea: load 16 components into a 128 bit register, and then zero expand it to 256 bits.This will effectively convert 16 chars to 16 shorts.

    //this is called after horizontal blur.Data is taken from blurredImage and stored into image.

    //__m128i _mm_load_si128 (__m128i const* mem_addr) - load 128 bits of integer data.Memory must be aligned at a 16 byte boundary.

    //__m256i _mm256_cvtepu8_epi16 (__m128i a) - zero extend chars to shorts

    unsigned short availableRegisters = 8; //there are 16 registers in total.8 of them will be used as accumulators, other 8 will receive new values

    unsigned int numOfReads = 3 * imageWidth / 128; //how many times a row can be read using 128-bit register.16 8-bit pixel components can fit into a 128-bit register.Leftovers will be handled manually
    unsigned short* leftoverAccumulator = nullptr;
    if ((3 * imageWidth) % 128 != 0)
        leftoverAccumulator = new unsigned short[3 * imageWidth - 128 * numOfReads];

    __m256i accumulators[8];
    //__m256i _radius = _mm256_set1_epi16(radius);

    unsigned short* unloadArea = (unsigned short*)_aligned_malloc(16 * sizeof(unsigned short), 32); //results from avx registers will be moved in here.It has to be aligned to a 32 byte boundary.

    char* bytePointerBlurredImage = (char*)blurredImage;

    for (unsigned int y = startRow; y < endRow; y++)
    {
        unsigned int upperEdge = std::max(0, (int)y - (int)split);
        unsigned int lowerEdge = std::min(imageHeight - 1, y + split);
        /*
            Read from upperEdge to the lowerEdge by 8 registers per row.
            Once that is complete, perform the same for the rest of the rows.
        */
        for (int avxChunk = 0; avxChunk < numOfReads; avxChunk++)
        {
            //zero out the accumulators
            nullifyIntAVXregisters(accumulators, 8);
            for (unsigned int i = upperEdge; i <= lowerEdge; i++)
            {
                //load the entire chunk of 8*128 bits (thats 8 registers * 16 pixel components = 128 pixel components per vertical scan)
                for (unsigned short j = 0; j < availableRegisters; j++)
                {
                    //This basically loads 16 pixel components into temp register.After that, it is zero expanded into shorts(which requires a 256 - bit register)
                    //__m128i temp128 = _mm_load_si128((__m128i*)(blurredImage + i*imageWidth + avxChunk*16 + j*16)); //PROBLEM: this might be wrong.
                    __m128i temp128 = _mm_load_si128((__m128i*) & bytePointerBlurredImage[3 * i * imageWidth + avxChunk * 128 + j * 16]);
                    __m256i temp256 = _mm256_cvtepu8_epi16(temp128);//convert chars to shorts

                    //add to accumulator
                    accumulators[j] = _mm256_add_epi16(accumulators[j], temp256);
                }
            }

            //divide the values in accumulators by the radius value.This will be performed manually because there are no integer division AVX instructions
            for (int i = 0; i < availableRegisters; i++)
            {
                _mm256_store_si256((__m256i*)unloadArea, accumulators[i]);
                for (unsigned int j = 0; j < 16; j++)
                {
                    //extract 16 shorts
                    //image[3 * y * imageWidth + avxChunk*16 + i*16 + i] = (unsigned char)(unloadArea[i] / blurRadius);
                    image[3 * y * imageWidth + avxChunk * 128 + i * 16 + j] = (unsigned char)(unloadArea[j] / blurRadius);

                }
                // 1  2  3  4  5  6  7  8  9  10  11  12  13  14  15  16 (register 255-0)
                //->_mm256_store_si256
                //16  15  14  13  12  11  10  9  8  7  6  5  4  3  2  1 (memory+255 - memory+0)
            }
        }
    }

    _aligned_free(unloadArea);

    //THIS HASN'T BEEN TESTED YET!!!

    //blur the leftovers manually
    if (leftoverAccumulator != nullptr)
    {
        char* tempImage = (char*)blurredImage;
        for (unsigned int row = startRow; row < endRow; row++)
        {
            memset(leftoverAccumulator, 0, 3 * imageWidth - 128 * numOfReads);

            unsigned int upperEdge = std::max(0, (int)row - (int)split);
            unsigned int lowerEdge = std::min(imageHeight - 1, row + split);

            for (unsigned int y = upperEdge; y <= lowerEdge; y++)
            {
                for (int x = numOfReads * 128; x < imageWidth; x++)
                {
                    leftoverAccumulator[x] += tempImage[y * imageWidth + x];
                }
            }
            //average them
            for (unsigned int x = 0; x < 3 * imageWidth - 128 * numOfReads; x++)
            {
                image[3 * (row * imageWidth + x)] = leftoverAccumulator[x] / blurRadius;
                image[3 * (row * imageWidth + x) + 1] = leftoverAccumulator[x] / blurRadius;
                image[3 * (row * imageWidth + x) + 2] = leftoverAccumulator[x] / blurRadius;
            }
        }
        delete[] leftoverAccumulator;
    }
}




void floatAVXvertical(pixel* blurredImage, char* image, unsigned int startRow, unsigned int endRow)
{
    //Unlike in blurVerticalAVX, all casts here are done using AVX instructions.

    //Due to all the casts, this is not much faster than the non-AVX implementation.In fact, this can even be slower than performing this without AVX.

    unsigned short availableRegisters = 7; //there are 16 registers in total.8 of them will be used as accumulators, other 8 will receive new values

    unsigned int numOfReads = 3 * imageWidth / (8*availableRegisters); //how many times a row can be read using 128-bit register.16 8-bit pixel components can fit into a 128-bit register.Leftovers will be handled manually
    //unsigned short* leftoverAccumulator = nullptr;
   

    __m256i accumulators[8];
    __m256 _radius = _mm256_set1_ps(blurRadiusFloat);

    unsigned int* unloadArea = (unsigned int*)_aligned_malloc(8 * sizeof(unsigned int), 32); //results from avx registers will be moved in here.It has to be aligned to a 32 byte boundary.

    char* bytePointerBlurredImage = (char*)blurredImage;


    for (unsigned int y = startRow; y < endRow; y++)
    {
        unsigned int upperEdge = std::max(0, (int)y - (int)split);
        unsigned int lowerEdge = std::min(imageHeight - 1, y + split);
        /*
            Read from upperEdge to the lowerEdge by 8 registers per row.
            Once that is complete, perform the same for the rest of the rows.
        */
        for (int avxChunk = 0; avxChunk < numOfReads; avxChunk++)
        {
            //zero out the accumulators
            nullifyIntAVXregisters(accumulators, 8);
            for (unsigned int i = upperEdge; i <= lowerEdge; i++)
            {
                //load the entire chunk of 8*128 bits (thats 8 registers * 16 pixel components = 128 pixel components per vertical scan)
                for (unsigned short j = 0; j < availableRegisters; j++)
                {
                    //load 8 pixel components into a 128-bit register and then zero extend them into 32-bit integers which are then stored in 256-bit register
                    __m256i temp256 = _mm256_cvtepu8_epi32(*(__m128i*) & bytePointerBlurredImage[3 * i * imageWidth + avxChunk * 8*availableRegisters + j * 8]); //PROBLEM!!!THIS MIGHT LEAD TO OUT OF BOUNDS MEMORY ACCESS.

                    //add to accumulator
                    accumulators[j] = _mm256_add_epi32(accumulators[j], temp256);
                }
            }

            //divide the values in accumulators by the radius value.This will be performed manually because there are no integer division AVX instructions
            for (int i = 0; i < availableRegisters; i++)
            {
                __m256 floatAccumulator = _mm256_cvtepi32_ps(accumulators[i]);
                floatAccumulator = _mm256_div_ps(floatAccumulator, _radius);
                accumulators[i] = _mm256_cvttps_epi32(floatAccumulator);

                _mm256_store_si256((__m256i*)unloadArea, accumulators[i]);
                for (unsigned int j = 0; j < 8; j++)
                {
                    //extract 16 shorts
                    //image[3 * y * imageWidth + avxChunk*16 + i*16 + i] = (unsigned char)(unloadArea[i] / blurRadius);
                    image[3 * y * imageWidth + avxChunk * 8*availableRegisters + i * 8 + j] = (unsigned char)(unloadArea[j]);

                }
            }
        }
    }
    _aligned_free(unloadArea);

    
    if (((3 * imageWidth) % (8*availableRegisters)) != 0)
    {
        unsigned int startColumn = numOfReads * availableRegisters * 8;
        verticalBlur(blurredImage, imageWidth, imageHeight, image, startRow, endRow, startColumn);
    }
}

void blurAVX(std::string pictureName, char* image, unsigned int pixelOffset, bool serial)
{
    auto start = std::chrono::high_resolution_clock::now();

    int split = (blurRadius - 1) / 2;
    unsigned int imageSize = imageWidth * imageHeight;
    pixel* blurredImage = new pixel[imageSize];

    std::string elapsedTimeMessage;

    std::string outputFileName = pictureName + "_blurred_";
    if (serial == false)
    {
        elapsedTimeMessage = "parallel";
        outputFileName += "AVX_parallel.bmp";
        #pragma omp parallel for
        for (int y = 0; y < imageHeight; y++)
            horizontalBlur(blurredImage, imageWidth, imageHeight, image + pixelOffset, y, y + 1);

        #pragma omp parallel for
        for (int y = 0; y < imageHeight; y++)
            floatAVXvertical(blurredImage, image + pixelOffset, y, y + 1);
        //blurVerticalAVX(blurredImage, image + pixelOffset, imageWidth, imageHeight, y, y+1, split);
    }
    else
    {
        elapsedTimeMessage = "serial";
        outputFileName += "AVX_serial.bmp";
        horizontalBlur(blurredImage, imageWidth, imageHeight, image + pixelOffset, 0, imageHeight);
        floatAVXvertical(blurredImage, image + pixelOffset, 0, imageHeight);

        //blurVerticalAVX(blurredImage, image + pixelOffset, imageWidth, imageHeight, 0, imageHeight, split);
    }

    int totalSize = imageSize * 3;
    //memcpy(image + pixelOffset, blurredImage, totalSize);
    std::ofstream outputFile(outputFileName.c_str(), std::ios::out | std::ios::binary);
    outputFile.write(image, (std::streamsize)totalSize + sizeof(headers));
    outputFile.close();

    //blur by horizontal axis first
    //blur by vertical axis, taking into account the values gained by horizontal blurring

    //optimisations: instead of using max() and min() on every step, perform calculations on the inner part of the picture that won't go out of bounds, and then
        //perform calculations using max() and min() for the rest that can go out of bounds



    auto stop = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> elapsed = stop - start;

    std::cout << "elapsed time (AVX " + elapsedTimeMessage + "):" << elapsed.count(); //0.24 for cache thrashing version

    delete[] blurredImage;
}



bool loadPicture(std::string pictureName, char* &image)
{
	
	std::ifstream fileInput(pictureName.c_str(), std::ios::in | std::ios::binary);
	headers metaData;
	//int a = sizeof(headers);
	if (!fileInput)
		return false;

	//get file size by seeking to the end, and then reverting to the beginning
	fileInput.seekg(0, std::ios::end);
	unsigned int size = fileInput.tellg();
	fileInput.seekg(0);
	
	image = (char*)_aligned_malloc(size, 16); //16 byte memory alignment
	if (!fileInput.read((char*)image, size))
		return false;

	fileInput.close();
	metaData = *((headers*)image);

   
	if (metaData.fileHeader.magicNumber != BMP_magic_number)
	{
		std::cout << "Incorrect magic number" << std::endl;
		return false;
	}
	if (metaData.infoHeader.bits_per_pixel != 24)
	{
		std::cout << "Image doesn't have 3 bytes per pixel" << std::endl;
		return false;
	}
	if (3 * metaData.infoHeader.width * metaData.infoHeader.height != metaData.infoHeader.image_size)
	{
		std::cout << "Image size incosistent" << std::endl;
		return false;
	}
	
    pixelOffset = metaData.fileHeader.dataOffset;
	imageWidth = metaData.infoHeader.width;
	imageHeight = metaData.infoHeader.height;
	
	return true;
}




int main(int argc, char** argv)
{
	if(argc != 4)
	{
		std::cout << "Enter arguments in the following format: <blur radius> <calculation type> <name of the picture>" << std::endl;
		std::cout << "Calculation types: " << std::endl;
		std::cout << "Serial: 0" << std::endl;
		std::cout << "Paralelized: 1" << std::endl;
		std::cout << "AVX serial: 2" << std::endl;
		std::cout << "AVX parallel: 3" << std::endl;
		return -1;
	}
	
	try
	{
		 blurRadius = std::stoi(argv[1]);
		 if(blurRadius <= 0 || blurRadius % 2 == 0)
		 {
			 std::cout << "Blur radius must be a positive odd number" << std::endl;
			 return -1;
		 }
		 blurRadiusFloat = (float)blurRadius;
		 split = (blurRadius-1)/2;
	}
	catch(std::exception exc)
	{
		std::cout << "Wrong argument input" << std::endl;
		return -1;
	}
	
	unsigned char calculationType;
	if(argv[2][0] == '0')
		calculationType = 0;
	
		
	else if(argv[2][0] == '1')
		calculationType = 1;
	
	else if(argv[2][0] == '2')
		calculationType = 2;
	else if(argv[2][0] == '3')
		calculationType = 3;
	else 
	{
		std::cout << "Nonexistant calculation type" << std::endl;
		return -1;
	}
	
	
	std::string pictureName = std::string(argv[3]);
	
    char* image;
	if(loadPicture(pictureName, image) == false)
	{
		std::cout << "Error reading the input file." << std::endl;
		return -1;
	}
	
    switch (calculationType)
    {
        case 0:
            blur(pictureName, image, pixelOffset, 0, imageHeight);
            break;
        case 1:
            blurParallel(pictureName, image, pixelOffset);
            break;
        case 2:
            blurAVX(pictureName, image, pixelOffset, true); //serial
            break;
        case 3:
            blurAVX(pictureName, image, pixelOffset, false);
            break;
    }
    _aligned_free(image);
	return 0;
}
/*
int main(int argc, char** argv)
{
    std::cout << "Leftover blurring in AVX blur hasn't been tested!!!" << std::endl;
    blurRadius = 5;
    split = 2;
    blurRadiusFloat = (float)blurRadius;

    if (blurRadius % 2 == 0)
    {
        std::cout << "Blur radius must be an odd number!";
        return -1;
    }

    std::ifstream fileInput("fullHD.bmp", std::ios::in | std::ios::binary);
    headers metaData;
   
    if (!fileInput)
        return -1;

    //get file size by seeking to the end, and then reverting to the beginning
    fileInput.seekg(0, std::ios::end);
    unsigned int size = fileInput.tellg();
    fileInput.seekg(0);

    char* image = (char*)_aligned_malloc(size, 16); //16 byte memory alignment
    //char* image = new char[size];

    if (!fileInput.read(image, size))
    {
        return -1;
    }

    fileInput.close();
    metaData = *((headers*)image);

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

    std::cout << "total size of the file: " << metaData.fileHeader.size << std::endl;
    std::cout << "meta data: " << metaData.fileHeader.magicNumber << std::endl;
    std::cout << "width: " << metaData.infoHeader.width << std::endl;
    std::cout << "height: " << metaData.infoHeader.height << std::endl;
    std::cout << "compression: " << metaData.infoHeader.compression << std::endl;
    std::cout << "planes: " << metaData.infoHeader.planes << std::endl;
    std::cout << "bits per pixel: " << metaData.infoHeader.bits_per_pixel << std::endl;
    std::cout << "image size: " << metaData.infoHeader.image_size << std::endl;
    std::cout << "horizontal pixels per meter: " << metaData.infoHeader.X_pixels_per_meter << std::endl;
    std::cout << "vertical pixels per meter: " << metaData.infoHeader.Y_pixels_per_meter << std::endl;


    int pixelOffset = metaData.fileHeader.dataOffset;
    imageWidth = metaData.infoHeader.width;
    imageHeight = metaData.infoHeader.height;
    //imageSize = imageWidth * imageHeight;

    //void blur(std::string pictureName, char* image, unsigned int pixelOffset, unsigned int imageWidth, unsigned int imageHeight, unsigned int startRow, unsigned int endRow)


    //void blurParallel(std::string pictureName, char* image, unsigned int pixelOffset, unsigned int imageWidth, unsigned int imageHeight)


    std::string name = "fullHD.bmp";
    //blurAVX(name, image, pixelOffset, true); //serial
    blurAVX(name, image, pixelOffset, false); //parallel
    //blurParallel(name, image, pixelOffset);
    //blur(name, image, pixelOffset, imageWidth, imageHeight, 0, imageHeight);
    //toGrayscale(image, pixelOffset, imageSize);
    //delete[] image;
    _aligned_free(image);
}
*/