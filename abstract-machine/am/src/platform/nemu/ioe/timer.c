#include <am.h>
#include <nemu.h>

void __am_timer_init() {
	// outl(RTC_ADDR, 0);
	// outl(RTC_ADDR+4, 0);
}

void __am_timer_uptime(AM_TIMER_UPTIME_T *uptime) {
	uptime->us = inl(RTC_ADDR+4);
	uptime->us <<= 32;
	uptime->us += inl(RTC_ADDR);
}

void __am_timer_rtc(AM_TIMER_RTC_T *rtc) {
	// read the high word first to refresh the RTC registers
	uint64_t rtc_time = inl(RTC_ADDR+12);
	rtc_time <<= 32;
	rtc_time += inl(RTC_ADDR+8);

	// unpack: low word = year(16bit) | mon(8bit) | day(8bit)
	//         high word = hour(8bit) | min(8bit) | sec(8bit)
	rtc->year   = rtc_time & 0xFFFF;
	rtc->month  = (rtc_time >> 16) & 0xFF;
	rtc->day    = (rtc_time >> 24) & 0xFF;
	rtc->hour   = (rtc_time >> 32) & 0xFF;
	rtc->minute = (rtc_time >> 40) & 0xFF;
	rtc->second = (rtc_time >> 48) & 0xFF;

//   rtc->second = 0;
//   rtc->minute = 0;
//   rtc->hour   = 0;
//   rtc->day    = 0;
//   rtc->month  = 0;
//   rtc->year   = 1900;
}
