// BMP image blur.cpp : This file contains the 'main' function. Program execution begins and ends there.
//

#include <iostream>
#include <fstream>


/*
Coordinates of the image start from the lower left corner.
Image is read from left to right, row at a time (from the bottom)
*/

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

void blur(char* image, unsigned int pixelOffset, unsigned int imageWidth, unsigned int imageHeight)
{
    //naive implementation: width * height * intensity^2
    //blurring per each dimension separately: width*height*intensity + width*height*intensity = 2*width*height*intensity
        //first blur one dimension
        //using the results from the previous point, blur the second dimension


    unsigned int imageSize = imageWidth * imageHeight;
    pixel* blurredImage = new pixel[imageSize];
    int intensity = 15;

    //blur by horizontal axis first
    //blur by vertical axis, taking into account the values gained by horizontal blurring

    //optimisations: instead of using max() and min() on every step, perform calculations on the inner part of the picture that won't go out of bounds, and then
        //perform calculations using max() and min() for the rest that can go out of bounds

    int split = (intensity - 1) / 2;
    for (unsigned int y = 0; y < imageHeight; y++)
    {
        for (unsigned int x = 0; x < imageWidth; x++)
        {
            pixel newPixel;
            

            unsigned int leftEdge = std::max((unsigned int)0, x - split);
            unsigned int rightEdge = std::min(imageWidth-1, x + split);

            int redAccumulator = 0;
            int greenAccumulator = 0;
            int blueAccumulator = 0;
            for (int i = leftEdge; i <= rightEdge; i++)
            {
                redAccumulator += ((pixel*)(image + pixelOffset + 3 * (y * imageWidth + i)))->red;
                greenAccumulator += ((pixel*)(image + pixelOffset + 3 * (y * imageWidth + i)))->green;
                blueAccumulator += ((pixel*)(image + pixelOffset + 3 * (y * imageWidth + i)))->blue;
            }
            newPixel.red = redAccumulator /intensity;
            newPixel.green = greenAccumulator/intensity;
            newPixel.blue = blueAccumulator/intensity;
            
            blurredImage[y * imageWidth + x] = newPixel;
        }
    }
    //vertical blurring
    for (unsigned int x = 0; x < imageWidth; x++)
    {
        for (unsigned int y = 0; y < imageHeight; y++)
        {
            pixel newPixel;

            unsigned int upperEdge = std::max((unsigned int)0, y - split);
            unsigned int lowerEdge = std::min(imageHeight - 1, y + split);

            int redAccumulator = 0;
            int greenAccumulator = 0;
            int blueAccumulator = 0;
            for (int i = upperEdge; i <= lowerEdge; i++)
            {
                pixel tempPixel = blurredImage[i * imageWidth + x];
                redAccumulator += tempPixel.red;
                greenAccumulator += tempPixel.green;
                blueAccumulator += tempPixel.blue;
            }
            newPixel.red = redAccumulator / intensity;
            newPixel.green = greenAccumulator / intensity;
            newPixel.blue = blueAccumulator / intensity;

            
            image[pixelOffset + 3*(y * imageWidth + x)] = newPixel.red;
            image[pixelOffset + 3*(y * imageWidth + x) + 1] = newPixel.green;
            image[pixelOffset + 3*(y * imageWidth + x) + 2] = newPixel.blue;
        }
    }

        int totalSize = imageSize * 3;
        //memcpy(image + pixelOffset, blurredImage, totalSize);
        std::ofstream outputFile("blurred.bmp", std::ios::out | std::ios::binary);
        outputFile.write(image, totalSize+sizeof(headers));
        outputFile.close();
        delete[] blurredImage;
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


    blur(image, pixelOffset, imageWidth, imageHeight);
    //toGrayscale(image, pixelOffset, imageSize);
    delete[] image;
}
