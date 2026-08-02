#include <sys/time.h>
#include <stdint.h>
#include <stdio.h>

static uint64_t boot_time = 0;

// static uint64_t get_time_internal(){
// 	// uint64_t us = ioe_read(AM_TIMER_UPTIME).us;
// 	struct timespec now;
// 	clock_gettime(CLOCK_MONOTONIC_COARSE, &now);
// 	uint64_t us = now.tv_nsec * 1000000 + now.tv_nsec / 1000;
// 	return us;
// }

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

// void get_time(){
// 	time_t timep;
// 	time(&timep);
// 	printf("%s", ctime(&timep));
// }
