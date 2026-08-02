#include "include/npc.h"
#include "include/state.h"
#include <readline/readline.h>
#include <readline/history.h>
#include "include/memory.h"

bool is_batch_mode = false;

void batch_mode_run(){
	is_batch_mode = true;
}

void reg_display();
word_t pmem_read(paddr_t addr, int len);
static int cmd_help(char *args);

bool in_mem(paddr_t paddr){
	return paddr-MEM_BASE < MEMSIZE;
}

static char* rl_gets() {
  static char *line_read = NULL;

  if (line_read) {
    free(line_read);
    line_read = NULL;
  }

  line_read = readline("(npc) ");

  if (line_read && *line_read) {
    add_history(line_read);
  }

  return line_read;
}

static int cmd_c(char* args){
	execute(-1);
	return 0;
}

static int cmd_q(char* args){
	npc_state.state = NPC_QUIT;
	return -1;
}

static int cmd_si(char* args){
//	char* arg = strtok(args," ");
	int steps;
	if (args == NULL) steps = 1;
	else steps = atoi(args);
	execute(steps);
	printf("si %d finished\n", steps);
	return 0;
}

static int cmd_info(char* args){
//	char *arg = strtok(NULL," ");
	if(args == NULL){
		printf("'r' for register and 'w' for watchpoints \n");
		return 0;
	}
	else{
		if(strcmp(args,"r") == 0){
			reg_display();
			printf("All register have printed\n");
		}
		else if (strcmp(args,"w") == 0){
			printf("add code to implement this\n");
		}
		else{
			printf("unknow command %s\n", args);
			printf("'r' for register and 'w' for watchpoints \n");
		}
	}
	return 0;
}

static int cmd_x(char* args){
	char* str_len = strtok(args," ");
	bool success;
	char* addr_str = strtok(NULL," ");
	if (str_len == NULL || addr_str == NULL) {
		printf("Invalid input!\n");
		return -1;
		}
	int len = atoi(str_len); int addr = strtol(addr_str,NULL,16);
	//word_t address = expr(addr_str, &success); int addr = (int)address;
	if (!in_mem(addr) || !in_mem(addr + len - 1)) {
		printf("Not a valid address.\n");
		return 0;
		}
	for (int i = 0; i < len; i++){
		word_t data = pmem_read(addr + 4*i,4);
		printf("Address: 0x%08x, Data: 0x%08x\n", addr + 4*i, data);
		}
	return 0;
}

static int cmd_p(char* args){
	return 0;
}

static int cmd_w(char* args){
	return 0;
}

static int cmd_d(char* args){
	return 0;
}

static int cmd_lab(char* args){
	// print_gpr();
	return 0;
}

static struct {
  const char *name;
  const char *description;
  int (*handler) (char *);
} cmd_table [] = {
  { "help", "Display information about all supported commands", cmd_help },
  { "c", "Continue the execution of the program", cmd_c },
  { "q", "Exit NPC", cmd_q },
  { "si", "Continue the execution by n steps", cmd_si },
  { "info", "Exhibit registers or watchpoints", cmd_info },
  { "x", "Scan memory", cmd_x },
  { "p", "Calculate the expression", cmd_p },
  { "w", "Add a new watchpoint", cmd_w },
  { "d", "delete an unwanted watchpoint by NO.", cmd_d },
  { "lab", "A temporary instruction used during development and testing.", cmd_lab }
};

int NR_CMD = sizeof(cmd_table)/sizeof(cmd_table[0]);

static int cmd_help(char *args){
	/* extract the first argument */
	char *arg = strtok(NULL, " ");
	int i;

	if (arg == NULL) {
		/* no argument given */
		for (i = 0; i < NR_CMD; i ++) {
			printf("%s - %s\n", cmd_table[i].name, cmd_table[i].description);
		}
	}
	else {
		for (i = 0; i < NR_CMD; i ++) {
			if (strcmp(arg, cmd_table[i].name) == 0) {
			printf("%s - %s\n", cmd_table[i].name, cmd_table[i].description);
			return 0;
			}
		}
		printf("Unknown command '%s'\n", arg);
	}
  return 0;
}

void npc_sdb_mainloop(){
	if(is_batch_mode){
		cmd_c(NULL);
		return;
	}
	
	for (char *str; (str = rl_gets()) != NULL; ) {
		char* str_end = str + strlen(str);

		char* cmd = strtok(str, " ");
		if (cmd == NULL) { continue; }

		char* args = cmd + strlen(cmd) + 1;
		if (args >= str_end) {
			args = NULL;
		}

		int i;
		for (i = 0; i < NR_CMD; i ++) {
			if (strcmp(cmd, cmd_table[i].name) == 0) {
    			if (cmd_table[i].handler(args) < 0) return;
    			break;
    		}
		}

		if (i == NR_CMD) { printf("Unknown command '%s'\n", cmd); }
	}

}