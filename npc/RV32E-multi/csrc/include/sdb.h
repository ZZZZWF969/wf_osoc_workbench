#ifndef __SDB_H__
#define __SDB_H__

#include <stdbool.h>
#include "word.h"
#include <generated/autoconf.h>

#ifdef __cplusplus
extern "C" {
#endif

word_t expr(char *e, bool *success);
void init_regex();
word_t reg_str2val(const char *s, bool *success);
word_t pmem_read(paddr_t addr, int len);

#ifdef CONFIG_NPC_WATCHPOINT
void init_wp_pool();
void wp_create(char *monitor_expr);
bool wp_delete(int NO);
bool exihibit_watchpoint();
void watchpoint_difftest();
#endif

#ifdef __cplusplus
}
#endif

#endif
