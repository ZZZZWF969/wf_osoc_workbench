#include <SDL2/SDL.h>
#include "../include/npc.h"
#include "../include/device.h"

static uint32_t *fb = NULL;
static uint32_t vgactl_reg[2];   // [0] 分辨率配置(只读) [1] sync(guest 写 1 请求刷新)
static SDL_Renderer *renderer = NULL;
static SDL_Texture *texture = NULL;

void init_vga(){
	// 初始化 SDL 窗口
	if (SDL_Init(SDL_INIT_VIDEO) != 0){
		printf("SDL init failed: %s\n", SDL_GetError());
		assert(0);
	}
	SDL_Window *window = NULL;
	if (SDL_CreateWindowAndRenderer(VGA_W * 2, VGA_H * 2, 0, &window, &renderer) != 0){
		printf("SDL create window failed: %s\n", SDL_GetError());
		assert(0);
	}
	// 创建纹理：像素格式与 NEMU 一致（ARGB8888）
	texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888,
								SDL_TEXTUREACCESS_STATIC, VGA_W, VGA_H);
	if (texture == NULL){
		printf("SDL create texture failed: %s\n", SDL_GetError());
		assert(0);
	}
	// 分配帧缓冲并清零
	fb = (uint32_t*)calloc(VGA_W * VGA_H, sizeof(uint32_t));
	assert(fb != NULL);
	// 配置寄存器：高 16 位是宽、低 16 位是高
	vgactl_reg[0] = (VGA_W << 16) | VGA_H;
	vgactl_reg[1] = 0;
}

word_t vgactl_read(paddr_t addr, int len){
	return vgactl_reg[(addr - VGACTL_ADDR) / 4];
}

void vgactl_write(paddr_t addr, int len, word_t data){
	if (addr - VGACTL_ADDR == 4){   // sync 寄存器：guest 写 1 请求刷新
		vgactl_reg[1] = data;
		if (vgactl_reg[1]){
			// 惰性刷新：把帧缓冲送上屏幕，然后清 sync（与 NEMU 语义一致）
			SDL_UpdateTexture(texture, NULL, fb, VGA_W * sizeof(uint32_t));
			SDL_RenderClear(renderer);
			SDL_RenderCopy(renderer, texture, NULL, NULL);
			SDL_RenderPresent(renderer);
			vgactl_reg[1] = 0;
		}
	}
}

word_t fb_read(paddr_t addr, int len){
	return fb[(addr - FB_ADDR) / 4];
}

void fb_write(paddr_t addr, int len, word_t data){
	fb[(addr - FB_ADDR) / 4] = data;
}
