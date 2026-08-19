#include <dlfcn.h>
#include "word.h"
#include "npcpp.hpp"
#include "state.h"

enum { DIFFTEST_TO_DUT, DIFFTEST_TO_REF };

typedef struct{
  word_t mcause;
  vaddr_t mepc;
  word_t mstatus;
  word_t mtvec;
}cpu_csrs;

typedef struct{
	word_t gpr[32];
	word_t pc;
	cpu_csrs csr;
}CPU_state;
