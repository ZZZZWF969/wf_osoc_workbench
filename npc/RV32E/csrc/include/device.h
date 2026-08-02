#ifndef __DEVICE_H__
#define __DEVICE_H__

#define DEVICE_BASE 0xa0000000

#define MMIO_BASE 0xa0000000

#define SERIAL_PORT     (DEVICE_BASE + 0x00003f8)
#define KBD_ADDR        (DEVICE_BASE + 0x0000060)
#define RTC_ADDR        (DEVICE_BASE + 0x0000048)
#define VGACTL_ADDR     (DEVICE_BASE + 0x0000100)
#define AUDIO_ADDR      (DEVICE_BASE + 0x0000200)
#define DISK_ADDR       (DEVICE_BASE + 0x0000300)
#define FB_ADDR         (MMIO_BASE   + 0x1000000)
#define AUDIO_SBUF_ADDR (MMIO_BASE   + 0x1200000)

// #define PAGE_SHIFT        12
// #define PAGE_SIZE         (1ul << PAGE_SHIFT)
// #define PAGE_MASK         (PAGE_SIZE - 1)

// typedef void(*io_callback_t)(uint32_t, int, bool);

// typedef struct {
// 	const char *name;
// 	paddr_t low;
// 	paddr_t high;
// 	void *space;
// 	io_callback_t callback;
// } IOMap;

// uint8_t* new_space(int size);
// void init_map();
// word_t map_read(IOMap* map, paddr_t addr, int len);
// void map_write(IOMap* map, paddr_t addr, int len, word_t data);

#endif