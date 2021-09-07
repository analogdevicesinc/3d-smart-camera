#define RED_START_POZ_X 1
#define RED_START_POZ_Y 1

#define RED 0
#define GREEN 1
#define BLUE 2

#include <stdio.h>
#include <iostream>
#include <iterator>
#include <vector>
#include <fstream>

short vertical_kernel(short** buffer, int x, int y, int width, int height)
{
    int sum = 0;
    int nr = 0;
    if (x-1>=0 && x-1<height)
    {
        sum += buffer[x-1][y];
        nr++;
    }
    if (x+1>=0 && x+1<height)
    {
        sum += buffer[x+1][y];
        nr++;
    }
    return((short)((float)sum/(float)nr));
}

short horizontal_kernel(short** buffer, int x, int y, int width, int height)
{
    int sum = 0;
    int nr = 0;
    if (y-1>=0 && y-1<width)
    {
        sum += buffer[x][y-1];
        nr++;
    }
    if (y+1>=0 && y+1<width)
    {
        sum += buffer[x][y+1];
        nr++;
    }
    return((short)((float)sum/(float)nr));
}

short plus_kernel(short** buffer, int x, int y, int width, int height)
{
    int sum = 0;
    int nr = 0;
    if (x-1>=0 && x-1<height)
    {
        sum += buffer[x-1][y];
        nr++;
    }
    if (x+1>=0 && x+1<height)
    {
        sum += buffer[x+1][y];
        nr++;
    }
    if (y-1>=0 && y-1<width)
    {
        sum += buffer[x][y-1];
        nr++;
    }
    if (y+1>=0 && y+1<width)
    {
        sum += buffer[x][y+1];
        nr++;
    }
    return((short)((float)sum/(float)nr));
}

short cross_kernel(short** buffer, int x, int y, int width, int height)
{
    int sum = 0;
    int nr = 0;
    if (x-1>=0 && x-1 < height && y-1>=0 && y-1<width)
    {
        sum += buffer[x-1][y-1];
        nr++;
    }
    if (x+1>=0 && x+1 < height && y-1>=0 && y-1<width)
    {
        sum += buffer[x+1][y-1];
        nr++;
    }
    if (x-1>=0 && x-1 < height && y+1>=0 && y+1<width)
    {
        sum += buffer[x-1][y+1];
        nr++;
    }
    if (x+1>=0 && x+1 < height && y+1>=0 && y+1<width)
    {
        sum += buffer[x+1][y+1];
        nr++;
    }
    return((short)((float)sum/(float)nr));
}

short** load_raw_file(std::string file_name, int width, int height)
{
    //allocate memory for buffer
    short** buff = (short **)malloc(height*sizeof(short*));
    for (int i=0;i<height;i++)
    {
        buff[i]=(short*)malloc(width*sizeof(short));
    }
    //open file
    FILE *stream = fopen(file_name.c_str(),"rb");
    char c1;
    char c2;
    int i=0;
    do
    {
        c1 = fgetc(stream);
        if (c1!=EOF)
        {
            c2 = fgetc(stream);
            buff[i/width][i%width] = (c2<<8 | c1);
            i++;
        }
    } while (c1 != EOF && c2 != EOF);
    
    return buff;

}

short*** raw_to_RGB(short** buffer, int width, int height)
{
    short*** rgb = (short***)malloc(3*sizeof(short**));
    for (int i=0; i<3; i++)
    {
        rgb[i] = (short **)malloc(height*sizeof(short*));
        for (int j=0;j<height;j++)
        {
            rgb[i][j]=(short*)malloc(width*sizeof(short));
        }
    }

    for (int i=0;i<height;i++)
    {
        for (int j=0;j<width;j++)
        {
            if (i%2 == RED_START_POZ_Y && j%2==RED_START_POZ_X) //red square
            {
                rgb[RED][i][j] = buffer[i][j];
                rgb[GREEN][i][j] = plus_kernel(buffer,i,j,width,height);
                rgb[BLUE][i][j] = cross_kernel(buffer,i,j,width,height);
            }
            else if (i%2 == (RED_START_POZ_Y ^ 1) && j%2 == (RED_START_POZ_X ^ 1)) //blue square
            {
                rgb[RED][i][j] = cross_kernel(buffer,i,j,width,height);
                rgb[GREEN][i][j] = plus_kernel(buffer,i,j,width,height);
                rgb[BLUE][i][j] = buffer[i][j];
            }
            else if (i%2 == (RED_START_POZ_Y ^ 1) && j%2==RED_START_POZ_X) //green pixel, blue row
            {
                rgb[RED][i][j] = vertical_kernel(buffer,i,j,width,height);
                rgb[GREEN][i][j] = buffer[i][j];
                rgb[BLUE][i][j] = horizontal_kernel(buffer,i,j,width,height);
            }
            else if (i%2 == RED_START_POZ_Y && j%2==(RED_START_POZ_X ^ 1)) // green pixel, red row
            {
                rgb[RED][i][j] = horizontal_kernel(buffer,i,j,width,height);
                rgb[GREEN][i][j] = buffer[i][j];
                rgb[BLUE][i][j] = vertical_kernel(buffer,i,j,width,height);
            }
            
        }
    }
    return rgb;
}

void save_rgb(std::string file_name, short*** rgb, int width, int height)
{
    std::ofstream fout;
    fout.open(file_name, std::ios::binary | std::ios::out);

    for (int i=0;i<height; i++)
    {
        for (int j=0;j<width;j++)
        {
            fout.write((char*) &rgb[RED][i][j], sizeof(rgb[RED][i][j]));
            fout.write((char*) &rgb[GREEN][i][j], sizeof(rgb[GREEN][i][j]));
            fout.write((char*) &rgb[BLUE][i][j], sizeof(rgb[BLUE][i][j]));
        }
    }
    fout.close();
}


int main (int argc, char* argv[]) // file_name, width, height, output_file
{
    std::string input_file = argv[1];
    int width = atoi(argv[2]);
    int height = atoi(argv[3]);
    std::string output_file = argv[4];

    //read in file
    short** buff = load_raw_file(input_file, width, height);
    short*** rgb = raw_to_RGB(buff, width, height);
    save_rgb(output_file, rgb, width, height);
    return 0;
}