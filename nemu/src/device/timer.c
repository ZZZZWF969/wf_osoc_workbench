/***************************************************************************************
* Copyright (c) 2014-2024 Zihao Yu, Nanjing University
*
* NEMU is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
*
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
*
* See the Mulan PSL v2 for more details.
***************************************************************************************/

#include <device/map.h>
#include <device/alarm.h>
#include <utils.h>
#include <sys/time.h>
#include <time.h>

static inline int RTC_allow(int offset){
	return offset == 0 || offset == 4 || offset == 8 || offset == 12;
}

static uint32_t *rtc_port_base = NULL;

static void rtc_io_handler(uint32_t offset, int len, bool is_write) {
  assert(RTC_allow(offset));
  if (!is_write && offset == 4) {
    uint64_t us = get_time();
    rtc_port_base[0] = (uint32_t)us;
    rtc_port_base[1] = us >> 32;
  } else if (!is_write && (offset == 8 || offset == 12)) {
    // get current time
    time_t now = time(NULL);
    struct tm tmbuf;
    localtime_r(&now, &tmbuf);

    // compress unnecessary bits of date info
    // year is 16-bit wide, the other fields are 8-bit wide
    // low word (+8)   = year(16bit) | mon(8bit) | day(8bit)
    // high word (+12) = hour(8bit)  | min(8bit) | sec(8bit)
    rtc_port_base[2] = (tmbuf.tm_year + 1900)
                     | ((tmbuf.tm_mon + 1) << 16)
                     | (tmbuf.tm_mday << 24);
    rtc_port_base[3] = tmbuf.tm_hour
                     | (tmbuf.tm_min << 8)
                     | (tmbuf.tm_sec << 16);
  }
}

#ifndef CONFIG_TARGET_AM
static void timer_intr() {
  if (nemu_state.state == NEMU_RUNNING) {
    extern void dev_raise_intr();
    dev_raise_intr();
  }
}
#endif

void init_timer() {
//   rtc_port_base = (uint32_t *)new_space(8);
	rtc_port_base = (uint32_t *)new_space(16);
#ifdef CONFIG_HAS_PORT_IO
  add_pio_map ("rtc", CONFIG_RTC_PORT, rtc_port_base, 16, rtc_io_handler);
#else
//   add_mmio_map("rtc", CONFIG_RTC_MMIO, rtc_port_base, 8, rtc_io_handler);
	add_mmio_map("rtc", CONFIG_RTC_MMIO, rtc_port_base, 16, rtc_io_handler);
#endif
  IFNDEF(CONFIG_TARGET_AM, add_alarm_handle(timer_intr));
}
