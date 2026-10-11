//仲裁器测试台专用DPI实现：本地64KB扁平内存（0x80000000起）+ 与真机同款分档随机延迟。
//独立于csrc（测试台只验证仲裁层，不依赖设备/内存模型）；rand不播种，序列固定可复现。
#include <cstdint>
#include <cstdlib>

static uint8_t tb_mem[64*1024];	//静态零初始化：未写区域读出为0，图样可预期

extern "C" unsigned int mem_read(unsigned int addr, int len){
	unsigned int ret = 0;
	for(int i = 0; i < len; i++){
		unsigned int off = (addr - 0x80000000u + i) & 0xFFFF;
		ret |= (unsigned int)tb_mem[off] << (8 * i);
	}
	return ret;
}

extern "C" void mem_write(unsigned int addr, int len, unsigned int data){
	for(int i = 0; i < len; i++){
		unsigned int off = (addr - 0x80000000u + i) & 0xFFFF;
		tb_mem[off] = (uint8_t)(data >> (8 * i));
	}
}

extern "C" unsigned int inst_fetch(unsigned int addr, int len){
	return mem_read(addr, len);
}

//分档与真机一致：取指[5,10]，数据[5,25]（单位：拍）
extern "C" unsigned char random_delay(unsigned int is_fetch){
	return is_fetch ? rand() % 6 + 5 : rand() % 21 + 5;
}
