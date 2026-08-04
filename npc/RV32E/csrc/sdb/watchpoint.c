/***************************************************************************************
* 移植自 NEMU (nemu/src/monitor/sdb/watchpoint.c)
***************************************************************************************/

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include "../include/sdb.h"
#include "../include/state.h"

#ifdef CONFIG_NPC_WATCHPOINT

#define NR_WP 32

bool wp_delete(int NO);

typedef struct watchpoint {
  int NO;
  struct watchpoint *next;
  char monitor_expr[32];
  word_t initial_value;
} WP;

static WP wp_pool[NR_WP] = {};
static WP *head = NULL, *free_ = NULL;

void init_wp_pool() {
  int i;
  for (i = 0; i < NR_WP; i ++) {
    wp_pool[i].NO = i;
    wp_pool[i].next = (i == NR_WP - 1 ? NULL : &wp_pool[i + 1]);
    //wp_pool[i].monitor_expr = NULL;    //the watchpoint is free while expr is NULL
  }

  head = NULL;
  free_ = wp_pool;
}

WP* new_wp(){
	if (free_ == NULL) {printf("No free watchpoint availiable.\n"); assert(0);}
	WP* recent = free_;
	free_ = free_->next;
	//insert to the front of the linked list
	recent->next = head;
	head = recent;
	return recent;
}

void free_wp(WP* wp){
	strcpy(wp->monitor_expr, "");
	wp->next = free_;
	free_ = wp;
}

void wp_create(char* monitor_expr){
	printf("receive a expr: %s\n",monitor_expr);
	WP* wp = new_wp();
	strncpy(wp->monitor_expr,monitor_expr,31);
	//printf("copy finish\n");
	bool ok;
	word_t wp_value = expr(monitor_expr,&ok);
	if (ok == false){
		printf("Invalid expression.\n");
		wp_delete(wp->NO);
		return;}
	else{
		wp->initial_value = wp_value;
		printf("Successed to create a new watchpoint\n"
		"NO.%d \n"
		"expression: %s\n"
		"initial value: 0x%08x \n"
		,wp->NO, wp->monitor_expr, wp->initial_value);
	}
}

bool wp_delete(int NO){
	WP* current = head;
	WP* prev = NULL;
	while(current != NULL && current->NO != NO){
		prev = current;
		current = current->next;
	}
	if (current == NULL){
		printf("You foolish, no this watchpoint!\n");
		return false;
	}
	if (prev == NULL) head = current->next;
	else prev->next = current->next;
	free_wp(current);
	return true;
}

bool exihibit_watchpoint(){
	if (head == NULL) return false;
	WP* wp = head;
	while(wp != NULL){
		printf("NO.%d  expr.%s   original value. 0x%08x \n"
		,wp->NO, wp->monitor_expr, wp->initial_value);
		wp = wp->next;
	}
	return true;
}

void watchpoint_difftest(){
	WP* current = head; bool calculate = true;
	while (current != NULL){
		word_t now_value = expr(current->monitor_expr, &calculate);
		if (calculate == false) {printf("some intersting wrong.\n"); assert(0);}
		if (now_value != current->initial_value){
			printf("A watchpoint is triggered.\n"
			"NO.%d  expr. %s\n"
			"original value. 0x%08x \n"
			"new value. 0x%08x \n"
			,current->NO, current->monitor_expr, current->initial_value, now_value);
			if (npc_state.state != NPC_END){
				npc_state.state = NPC_STOP;}
		}
	current = current->next;
	}
}

#endif // CONFIG_NPC_WATCHPOINT
