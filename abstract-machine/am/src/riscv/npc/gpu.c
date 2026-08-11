#include <am.h>
#include "include/npc.h"

void __am_gpu_init(){
	// 帧缓冲已由硬件层清零，无需初始化
}

void __am_gpu_config(AM_GPU_CONFIG_T *cfg) {
	uint32_t size = inl(VGACTL_ADDR);
	uint32_t width = (size>>16) & 0xffff;
	uint32_t height = size & 0xffff;
	*cfg = (AM_GPU_CONFIG_T) {
		.present = true, .has_accel = false,
		.width = width, .height = height,
		.vmemsz = 0
	};
}

void __am_gpu_fbdraw(AM_GPU_FBDRAW_T *ctl) {
	int x = ctl->x; int y = ctl->y; int w = ctl->w; int h = ctl->h;
	if(!ctl->sync && (w == 0 || h == 0)) return;
	uint32_t* pixels = ctl->pixels;
	uint32_t* fb = (uint32_t*)(uintptr_t)FB_ADDR;
	uint32_t screen_width = inl(VGACTL_ADDR)>>16;
	for(int i = y; i < y+h; i++){
		for (int j = x; j < x+w; j++){
			fb[screen_width*i+j] = pixels[w*(i-y)+(j-x)];
		}
	}
	if (ctl->sync) {
		outl(SYNC_ADDR, 1);
	}
}

void __am_gpu_status(AM_GPU_STATUS_T *status) {
  status->ready = true;
}
