// #include "memory.h"
// #include "ansi.h"
// #include "device.h"

// #define IO_SPACE_MAX 32*1024*1024

// typedef void(*io_callback_t)(uint32_t, int, bool);

// static uint8_t* io_space = NULL;
// static uint8_t* p_space = NULL;

// void init_map(){
// 	io_space = malloc(IO_SPACE_MAX);
// 	if(io_space = NULL){
// 		printf(ANSI_FG_RED"map initial failed\n",ANSI_NONE);
// 		assert(io_space);
// 	}
// 	p_space = io_space;
// }

// uint8_t* new_space(int size){
// 	uint8_t* p = p_space;
// 	size = (size + (PAGE_SIZE - 1)) & ~PAGE_MASK;
// 	p_space += size;
// 	assert(p_space - io_space < IO_SPACE_MAX);
// 	return p;
// }

// void check_map_bound(IOMap* map, paddr_t addr){
// 	if(map == NULL){
// 		printf(ANSI_FG_RED"addr( 0x%08x ) out of bound",ANSI_NONE, addr);
// 		assert(map);
// 	}else{
// 		if(addr <= map->low || addr >= map->high){
// 			printf(ANSI_FG_RED"addr( 0x%08x ) out of bound",ANSI_NONE, addr);
// 			assert(addr >= map->low && addr <= map->high);
// 		}
// 	}
// }

// static void invoke_callback(io_callback_t call, paddr_t offset, int len, bool is_write){
// 	if(call != NULL)
// 	call(offset, len, is_write);
// }

// word_t map_read(IOMap* map, paddr_t addr, int len){
// 	assert(len >= 1 && len <= 8);
// 	check_map_bound(map, addr);
// 	paddr_t offset = addr - map->low;
// 	invoke_callback(map->callback, offset, len, false);
// 	word_t ret = host_read(map->low, len);
// 	return ret;
// }

// void map_write(IOMap* map, paddr_t addr, int len, word_t data){
// 	assert(len >= 1 && len <= 8);
// 	check_map_bound(map,addr);
// 	paddr_t offset = addr - map->low;
// 	host_write(map->low, len, data);
// 	invoke_callback(map->callback, offset, len, true);
// }