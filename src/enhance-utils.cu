#include "common.h"
#include "enhance.h"
#include <stdio.h>
#include <stdlib.h>

// int updiv(int x, int y) { return (x + y - 1) / y; }

__global__ void RGB2HSI(int *rgb_img, int *hsi_img, int height, int width) {
  int img_x = __umul24(blockIdx.x, blockDim.x) + threadIdx.x,
      img_y = __umul24(blockIdx.y, blockDim.y) + threadIdx.y;
  int img_idx = __umul24(img_y, width) + img_x;
  if (img_x < width && img_y < height) {
    int R = tex2D(tex1, tmp_x, tmp_y) >> 16, G = (tex2D(tex1, tmp_x, tmp_y) >> 8) & 0x00FF,
        B = tex2D(tex1, tmp_x, tmp_y) & 0x0000FF;
    float theta = acosf(((R - G + R - B) / 2) /
                        sqrtf(powf(R - G, 2) + (R - B) * (G - B)));
    float H = (B <= G) ? theta : 2 * CUDART_PI_F - theta;
    H /= 2 * CUDART_PI_F;
    float S = 1 - 3.0 * fminf(R, fminf(G, B)) / (R + G + B);
    float I = (R + G + B) / (3.0 * 255);
    hsi_img[img_idx] =
        (int((H * 255)) << 16) + (int((S * 255)) << 8) + int((I * 255));
  }
}
__global__ void HSI2RGB(int *hsi_img, int *rgb_img, int height, int width) {
  int img_x = __umul24(blockIdx.x, blockDim.x) + threadIdx.x,
      img_y = __umul24(blockIdx.y, blockDim.y) + threadIdx.y;
  int img_idx = __umul24(img_y, width) + img_x;
  if (img_x < width && img_y < height) {
    float H = (tex2D(tex2, tmp_x, tmp_y) >> 16) / 255.0 * 2 * CUDART_PI_F,
          S = ((tex2D(tex2, tmp_x, tmp_y) >> 8) & 0x00FF) / 255.0,
          I = (tex2D(tex2, tmp_x, tmp_y) & 0x0000FF) / 255.0;
    int R, G, B;
    if (H >= 0 && H < 2 * CUDART_PI_F / 3) {
      B = I * (1 - S) * 255;
      R = I * (1 + S * cosf(H) / cosf(CUDART_PI_F / 3 - H)) * 255;
      G = 3 * I * 255 - (R + B);
      // printf("1 %d %d %d %f %f %f\n", R, G, B, H, S, I);
    } else if (H >= 2 * CUDART_PI_F / 3 && H < 4 * CUDART_PI_F / 3) {
      H -= CUDART_PI_F / 3 * 2;
      R = I * (1 - S) * 255;
      G = I * (1 + S * cosf(H) / cosf(CUDART_PI_F / 3 - H)) * 255;
      B = 3 * I * 255 - (R + G);
      // printf("2 %d %d %d %f %f %f\n", R, G, B, H, S, I);
    } else if (H >= 4 * CUDART_PI_F / 3 && H < 2 * CUDART_PI_F) {
      H -= CUDART_PI_F / 3 * 4;
      G = I * (1 - S) * 255;
      B = I * (1 + S * cosf(H) / cosf(CUDART_PI_F / 3 - H)) * 255;
      R = 3 * I * 255 - (G + B);
      // printf("3 %d %d %d %f %f %f\n", R, G, B, H, S, I);
    }
    R = min(R, 255);
    G = min(G, 255);
    B = min(B, 255);
    rgb_img[img_idx] = (R << 16) + (G << 8) + B;
  }
}