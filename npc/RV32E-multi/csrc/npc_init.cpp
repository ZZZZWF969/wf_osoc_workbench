#include <getopt.h>
#include "include/vmem.h"
#include "include/npc.h"
#include "include/sdb.h"
#include <generated/autoconf.h>
#include <time.h>
#include <stdlib.h>

static char* img_file = NULL;
static char* diff_so_file = NULL;
//默认日志落在multi根目录npc-log.txt（make run的工作目录即multi根目录），-l可覆盖为自定义路径
static char* log_file_path = (char*)"npc-log.txt";
IFDEF(CONFIG_NPC_DIFFTEST, static int difftest_port = 1234;)

FILE* npc_log_file = NULL;			//日志文件：itrace/mtrace全量落盘与CPI统计末行，各写入点fprintf

static const uint32_t default_img [5] = {
  0x00000297,  // auipc t0,0
  0x00028823,  // sb  zero,16(t0)
  0x0102c503,  // lbu a0,16(t0)
  0x00100073,  // ebreak (used as npc_trap)
  0xdeadbeef,  // some data
};

void init_difftest(char *ref_so_file, long img_size, int port);
void batch_mode_run();
IFDEF(CONFIG_NPC_ITRACE, void init_disasm();)
uint64_t get_boot_time();	//device/time.cpp：开机绝对时间戳，作随机数种子源

static long load_img(){
	if (img_file == NULL) {
		printf("No image given, use default image\n");
		memcpy(guest_to_host(MEM_BASE), default_img, sizeof(default_img));
		return sizeof(default_img);
	}

	FILE *fp = fopen(img_file, "rb");
	if(fp == NULL){
		printf("can not open the file\n");
		assert(0);
	}

	fseek(fp, 0, SEEK_END);
	long size = ftell(fp);

	printf("The image is %s, size = %ld\n", img_file, size);

	fseek(fp, 0, SEEK_SET);
	int ret = fread(guest_to_host(MEM_BASE), size, 1, fp);
	assert(ret == 1);

	fclose(fp);
	return size;
}

static int parse_args(int argc, char* argv[]){
    const struct option table[] = {
    {"batch"    , no_argument      , NULL, 'b'},
    {"log"      , required_argument, NULL, 'l'},
    {"diff"     , required_argument, NULL, 'd'},
    {"port"     , required_argument, NULL, 'p'},
    {"elf"      , required_argument, NULL, 'e'},
    {"help"     , no_argument      , NULL, 'h'},
    {0          , 0                , NULL,  0 },
  };
    int o;
    while ( (o = getopt_long(argc, argv, "-bhl:d:p:e:", table, NULL)) != -1){
        switch(o){
			case 'b': batch_mode_run(); break;
			case 'd': diff_so_file = optarg; printf("diff-so-file: %s\n", diff_so_file); break;
			case 'l': log_file_path = optarg; break;		//日志文件路径（原option table有声明但无case，传入会掉进default退出）
			case 'p': IFDEF(CONFIG_NPC_DIFFTEST, difftest_port = atoi(optarg);) break;	//difftest端口（仅DIFFTEST开时有意义）
			case 'e': printf("--elf is not implemented yet\n"); break;	//暂未实现，占位避免掉进default退出
            case 1: img_file = optarg; return 0;
			default:
				printf("Usage: %s [OPTION...] IMAGE [args]\n\n", argv[0]);
				printf("\t-b,--batch              run with batch mode\n");
				printf("\t-e,--elf=FILE           elf to be parsed\n");
				printf("\t-l,--log=FILE           output log to FILE\n");
				printf("\t-d,--diff=REF_SO        run DiffTest with reference REF_SO\n");
				printf("\t-p,--port=PORT          run DiffTest with port PORT\n");
				printf("\n");
				exit(0);
        }
    }
	return 0;
}

//打开日志文件并写入运行信息头：即使所有踪迹开关关闭，日志也保有本次运行的基本信息
static void open_log_file(long img_size){
	if(log_file_path == NULL) return;
	npc_log_file = fopen(log_file_path, "w");	//覆盖模式：每次运行生成一份新日志
	if(npc_log_file == NULL){
		printf("can not open log file: %s\n", log_file_path);
		return;
	}
	char time_buf[32];
	time_t now = time(NULL);
	strftime(time_buf, sizeof(time_buf), "%Y-%m-%d %H:%M:%S", localtime(&now));
	fprintf(npc_log_file, "===== NPC run info =====\n");
	fprintf(npc_log_file, "start time : %s\n", time_buf);
	fprintf(npc_log_file, "image      : %s (%ld bytes)\n",
		img_file == NULL ? "default_img(5 insts)" : img_file, img_size);
	//MUXDEF二选一：IFDEF(m,A,B)展开是"A,B"逗号表达式而非二选一，此处必须用MUXDEF
	MUXDEF(CONFIG_NPC_DIFFTEST,
		fprintf(npc_log_file, "diff ref   : %s\n", diff_so_file);,
		fprintf(npc_log_file, "diff ref   : disabled\n");)	fprintf(npc_log_file, "trace      : ITRACE %s, MTRACE %s, WAVE %s, DIFFTEST %s, WATCHPOINT %s\n",
		MUXDEF(CONFIG_NPC_ITRACE, "on", "off"),
		MUXDEF(CONFIG_NPC_MTRACE, "on", "off"),
		MUXDEF(CONFIG_NPC_WAVE, "on", "off"),
		MUXDEF(CONFIG_NPC_DIFFTEST, "on", "off"),
		MUXDEF(CONFIG_NPC_WATCHPOINT, "on", "off"));
	fprintf(npc_log_file, "=======================\n");
}

void npc_init(int argc, char *argv[]){
	printf("argc: %d\n", argc);
	printf("argv: %s\n", *argv);
	srand((unsigned int)get_boot_time());	//随机数播种：以开机绝对时间戳为种子（高熵），random_delay每次运行序列不同
	init_regex();
	IFDEF(CONFIG_NPC_ITRACE, init_disasm();)
	IFDEF(CONFIG_NPC_WATCHPOINT, init_wp_pool();)
	parse_args(argc, argv);
	create_virtual_memory();
	init_device();
	long img_size = load_img();
	open_log_file(img_size);				//载入镜像后开日志：信息头需要img名与大小
	IFDEF(CONFIG_NPC_DIFFTEST, init_difftest(diff_so_file, img_size, difftest_port);)
}