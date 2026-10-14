#ifndef NPC_H__
#define NPC_H__

#include <klib-macros.h>
#include "/home/wf/Desktop/ysyx-workbench/abstract-machine/am/src/riscv/riscv.h"

#define DEVICE_BASE 0xa0000000
#define MMIO_BASE 0xa0000000

//修改（NPC从设备现实化·临时测试改）：putch改走NPC侧RTL UART仿真模型（0x1000_0000，$write字符输出）
//本行为临时为测试而改；原serial定义注释保留，回迁或接真SoC时按需恢复
//#define SERIAL_PORT     (DEVICE_BASE + 0x00003f8)
#define SERIAL_PORT     0x10000000
#define RTC_ADDR        (DEVICE_BASE + 0x0000048)
#define KBD_ADDR		(DEVICE_BASE + 0x0000060)
#define VGACTL_ADDR     (DEVICE_BASE + 0x0000100)
#define SYNC_ADDR       (VGACTL_ADDR + 0x4)
#define FB_ADDR         (MMIO_BASE   + 0x1000000)

extern char _pmem_start;
#define PMEM_SIZE (128 * 1024 * 1024)
#define PMEM_END  ((uintptr_t)&_pmem_start + PMEM_SIZE)
#define NPC_PADDR_SPACE \
  RANGE(&_pmem_start, PMEM_END), \
  RANGE(FB_ADDR, FB_ADDR + 0x200000), \
  RANGE(MMIO_BASE, MMIO_BASE + 0x1000) /* serial, rtc, screen, keyboard */

typedef uintptr_t PTE;

#define PGSIZE 4096

#endif