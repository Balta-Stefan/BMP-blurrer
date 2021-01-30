// BMP image blur.cpp : This file contains the 'main' function. Program execution begins and ends there.
//

#include <iostream>
#include <fstream>
#include <chrono>
#include <algorithm>


/*
Coordinates of the image start from the lower left corner.
Image is read from left to right, row at a time (from the bottom)
*/

const unsigned int blurRadius = 15;

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
    for (unsigned int i = 0; i < size; i++)
    {
        pixel currentPixel = *((pixel*)(image + dataOffset + 3 * i));
        char average = ((int)currentPixel.red + currentPixel.green + currentPixel.blue) / 3;
        currentPixel.red = average;
        currentPixel.green = average;
        currentPixel.blue = average;
        grayscale[i] = currentPixel;
    }

    int totalSize = size * 3;
    memcpy(image + dataOffset, grayscale, totalSize);
    std::ofstream outputFile("grayscaled.bmp", std::ios::out | std::ios::binary);
    outputFile.write(image, totalSize+sizeof(headers));
    outputFile.close();
    delete[] grayscale;
}

void blurAVX(char* image, unsigned int pixelOffset, unsigned int imageWidth, unsigned int imageHeight)
{

}


void horizontalBlur(pixel* blurredImage, char* image, unsigned int pixelOffset, unsigned int imageWidth, unsigned int imageHeight, unsigned int startRow, unsigned int endRow, unsigned int radius, unsigned int split)
{
    for (unsigned int y = startRow; y < endRow; y++)
    {
        for (unsigned int x = 0; x < imageWidth; x++)
        {
            pixel newPixel;

            unsigned int leftEdge = std::max((unsigned int)0, x - split);
            unsigned int rightEdge = std::min(imageWidth - 1, x + split);

            int redAccumulator = 0;
            int greenAccumulator = 0;
            int blueAccumulator = 0;
            for (int i = leftEdge; i <= rightEdge; i++)
            {
                redAccumulator += ((pixel*)(image + pixelOffset + 3 * (y * imageWidth + i)))->red;
                greenAccumulator += ((pixel*)(image + pixelOffset + 3 * (y * imageWidth + i)))->green;
                blueAccumulator += ((pixel*)(image + pixelOffset + 3 * (y * imageWidth + i)))->blue;
            }
            newPixel.red = redAccumulator / radius;
            newPixel.green = greenAccumulator / radius;
            newPixel.blue = blueAccumulator / radius;

            blurredImage[y * imageWidth + x] = newPixel;
        }
    }
}

void verticalBlur(pixel* blurredImage, char* image, unsigned int pixelOffset, unsigned int imageWidth, unsigned int imageHeight, unsigned int startRow, unsigned int endRow, unsigned int radius, unsigned int split)
{
    int* rowAccumulator = new int[imageWidth * 3];
    for (unsigned int y = startRow; y < endRow; y++)
    {
        //zero out the accumulator
        std::memset(rowAccumulator, 0, imageWidth * sizeof(int) * 3);

        unsigned int upperEdge = std::max((unsigned int)0, y - split);
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
            rowAccumulator[3 * x] /= radius;
            rowAccumulator[3 * x + 1] /= radius;
            rowAccumulator[3 * x + 2] /= radius;

            image[pixelOffset + 3 * (y * imageWidth + x)] = rowAccumulator[3 * x];
            image[pixelOffset + 3 * (y * imageWidth + x) + 1] = rowAccumulator[3 * x + 1];
            image[pixelOffset + 3 * (y * imageWidth + x) + 2] = rowAccumulator[3 * x + 2];
        }
    }
    delete[] rowAccumulator;
}

void blur(char* image, unsigned int pixelOffset, unsigned int imageWidth, unsigned int imageHeight, unsigned int startRow, unsigned int endRow)
{
    //naive implementation: width * height * intensity^2
    //blurring per each dimension separately: width*height*intensity + width*height*intensity = 2*width*height*intensity
        //first blur one dimension
        //using the results from the previous point, blur the second dimension

    /*
        Benchmark:
        -radius 3:   0.15 (cache thrashing version), 0.1 (cache efficient version)
        -radius 5:   0.17 (cache thrashing version), 0.12 (cache efficient version)
        -radius 11:  0.22 (cache thrashing version), 0.18 (cache efficient version)
        -radius 15:  0.25 (cache thrashing version), 0.22 (cache efficient version)
    */

    auto start = std::chrono::high_resolution_clock::now();

    int split = (blurRadius - 1) / 2;
    unsigned int imageSize = imageWidth * imageHeight;
    pixel* blurredImage = new pixel[imageSize];

    horizontalBlur(blurredImage, image, pixelOffset, imageWidth, imageHeight, startRow, endRow, blurRadius, split);
    verticalBlur(blurredImage, image, pixelOffset, imageWidth, imageHeight, startRow, endRow, blurRadius, split);

    int totalSize = imageSize * 3;
    memcpy(image + pixelOffset, blurredImage, totalSize);
    std::ofstream outputFile("blurred.bmp", std::ios::out | std::ios::binary);
    outputFile.write(image, (std::streamsize)totalSize+sizeof(headers));
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


void blurParallel(char* image, unsigned int pixelOffset, unsigned int imageWidth, unsigned int imageHeight)
{
    //OpenMP brings very small speedup, almost insignificant

    auto start = std::chrono::high_resolution_clock::now();

    int split = (blurRadius - 1) / 2;
    unsigned int imageSize = imageWidth * imageHeight;
    pixel* blurredImage = new pixel[imageSize];

    #pragma omp parallel for
    for(int y = 0; y < imageHeight; y++)
        horizontalBlur(blurredImage, image, pixelOffset, imageWidth, imageHeight, y, y+1, blurRadius, split);

    #pragma omp parallel for
    for(int y = 0; y < imageHeight; y++)
        verticalBlur(blurredImage, image, pixelOffset, imageWidth, imageHeight, y, y+1, blurRadius, split);


    auto stop = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> elapsed = stop - start;

    std::cout << "elapsed time (parallel): " << elapsed.count(); //0.24 for cache thrashing version


    int totalSize = imageSize * 3;
    memcpy(image + pixelOffset, blurredImage, totalSize);
    std::ofstream outputFile("blurred.bmp", std::ios::out | std::ios::binary);
    outputFile.write(image, (std::streamsize)totalSize + sizeof(headers));
    outputFile.close();

}

int main()
{
    std::ifstream fileInput("test.bmp", std::ios::in | std::ios::binary);
    headers metaData;
    int a = sizeof(headers);
    if (!fileInput)
        return -1;

    //get file size by seeking to the end, and then reverting to the beginning
    fileInput.seekg(0, std::ios::end);
    int size = fileInput.tellg();
    fileInput.seekg(0);
    
    char* image = new char[size];
    //char* image = (char*)calloc(size, 1);

    if (!fileInput.read(image, size))
    {
        return -1;
    }

    fileInput.close();
    metaData = *((headers*)image);

    //fileInput.read((char*)&metaData, sizeof(headers));
   
 
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
    unsigned int imageWidth = metaData.infoHeader.width;
    unsigned int imageHeight = metaData.infoHeader.height;
    unsigned int imageSize = imageWidth * imageHeight;


    //blurParallel(image, pixelOffset, imageWidth, imageHeight);
    blur(image, pixelOffset, imageWidth, imageHeight, 0, imageHeight);
    //toGrayscale(image, pixelOffset, imageSize);
    delete[] image;
}
