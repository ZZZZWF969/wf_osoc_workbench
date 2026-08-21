#include <time.h>
#include <sys/time.h>
#include "../include/npc.h"

static uint64_t boot_time = 0;

static uint32_t rtc_port[4];

// static uint64_t get_time_internal(){
// 	// uint64_t us = ioe_read(AM_TIMER_UPTIME).us;
// 	struct timespec now;
// 	clock_gettime(CLOCK_MONOTONIC_COARSE, &now);
// 	uint64_t us = now.tv_nsec * 1000000 + now.tv_nsec / 1000;
// 	return us;
// }

static inline int RTC_allow(int offset){
	return offset == 0 || offset == 4 || offset == 8 || offset == 12;
}

uint64_t get_time(){
	if(boot_time == 0){
		struct timeval start;
		gettimeofday(&start, NULL);
		boot_time = start.tv_sec*1000000ULL + start.tv_usec;
	}
	struct timeval tv;
	uint64_t now = 0;
	if(gettimeofday(&tv, NULL) != 0){
		printf("Failed to get time\n");
	}
	now = (uint64_t)tv.tv_sec*1000000ULL + tv.tv_usec;
	return now - boot_time;
}

void rtc_io_handler(uint32_t offset, int len, bool is_write){
	assert(RTC_allow(offset));
	if(!is_write){
		if(offset == 4){
			uint64_t us = get_time();
			rtc_port[0] = (uint32_t)us;
			rtc_port[1] = us>>32;
		}else if(offset == 12){
			// get current time
			time_t now = time(NULL);
			struct tm tmbuf;
			localtime_r(&now, &tmbuf);

			//compress unnecessary bits of date info
			rtc_port[2] = (tmbuf.tm_year + 1900)
						| ((tmbuf.tm_mon + 1) << 16)
						| (tmbuf.tm_mday << 24);
			rtc_port[3] = tmbuf.tm_hour
						| (tmbuf.tm_min << 8)
						| (tmbuf.tm_sec << 16);
		}
	}
}

word_t rtc_read(paddr_t addr, int len){
	int offset = (addr - RTC_ADDR);
	rtc_io_handler(offset, len, false);
	return rtc_port[offset/4];
}

// void get_time(){
// 	time_t timep;
// 	time(&timep);
// 	printf("%s", ctime(&timep));
// }
