#include "../include/npc.h"

typedef struct{
	char name[25];	//enough
	paddr_t device_base_addr;
	int size;
}DEVICE;

#define MAX_DEVICE_NUM 10
int devices_num = 0;
DEVICE devices[MAX_DEVICE_NUM];

void add_io_device(DEVICE device){
	if(devices_num == MAX_DEVICE_NUM){
		printf("devices overflow!\n");
		assert(0);
	}
	devices[devices_num] = device;
	devices_num++;
}

void add_serial(){
	DEVICE serial = { .name = "serial" };
	serial.device_base_addr = SERIAL_PORT;
	serial.size = SERIAL_SIZE;
	add_io_device(serial);
}

void add_rtc(){
	DEVICE rtc_clock = { .name = "rtc_clock" };
	rtc_clock.device_base_addr = RTC_ADDR;
	rtc_clock.size = RTC_SIZE;
	add_io_device(rtc_clock);
}

void add_keyboard(){
	init_keyboard();
	DEVICE keyboard = { .name = "keyboard" };
	keyboard.device_base_addr = KBD_ADDR;
	keyboard.size = KBD_SIZE;
	add_io_device(keyboard);
}

void init_device(){
	add_serial();
	add_rtc();
	add_keyboard();
}

//judge if memory address is a io device
int is_io_device(paddr_t addr){
	for(int i = 0; i < devices_num; i++){
		if(addr >= devices[i].device_base_addr \
		& addr <= devices[i].device_base_addr+devices[i].size)
			return 1;
	}
	return 0;
}

static DEVICE find_device(paddr_t addr){
	for(int i = 0; i < devices_num; i++){
		if(addr >= devices[i].device_base_addr \
		& addr <= devices[i].device_base_addr+devices[i].size){
			return devices[i];
		}
	}
	DEVICE empty_device = { .name = "empty" };
	return empty_device;
}

static void no_device(paddr_t addr){
	printf("%08x did not hit any device\n", addr);
	assert(0);
}

void io_device_write(paddr_t addr, int len, word_t data){
	assert(len >= 1 && len <=8);
	DEVICE target = find_device(addr);
	if(strcmp(target.name, "empty") == 0) no_device(addr);
	if(strcmp(target.name, "serial") == 0){
		serial_putch(data);
	}
}

word_t io_device_read(paddr_t addr, int len){
	assert(len >= 1 && len <=8);
	DEVICE target = find_device(addr);
	if(strcmp(target.name, "empty") == 0) no_device(addr);
	if(strcmp(target.name, "rtc_clock") == 0){
		//return rtc_read data
		return rtc_read(addr, len);
	}
	if(strcmp(target.name, "keyboard") == 0){
		//return keyboard data
		return kbd_read();
	}
	//actual should not reach here
	return 0;
}