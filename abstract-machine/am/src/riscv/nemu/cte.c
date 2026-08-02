#include <am.h>
#include <riscv/riscv.h>
#include <inttypes.h>
#include <klib.h>

static Context* (*user_handler)(Event, Context*) = NULL;

Context* __am_irq_handle(Context *c) {
	// printf("go in am_irq_handle\n");
	// printf("call mepc: 0x%08" PRIxPTR "\n", c->mepc);
  if (user_handler) {
	// printf("user_handler exist\n");
    Event ev = {0};
	// printf("c->mcause: %d \n",c->mcause);
    switch (c->mcause) {
		case 11: 
			if(c->GPR1 == -1){
				ev.event = EVENT_YIELD;
				c->mepc += 4;
			} else{
				ev.event = EVENT_SYSCALL;
				c->mepc +=4;
			}
			break;
    	default: ev.event = EVENT_ERROR; break;
    }

    c = user_handler(ev, c);
	// printf("return mepc: 0x%08" PRIxPTR "\n", c->mepc);
    assert(c != NULL);
  }

  return c;
}

extern void __am_asm_trap(void);

bool cte_init(Context*(*handler)(Event, Context*)) {
  // initialize exception entry
  asm volatile("csrw mtvec, %0" : : "r"(__am_asm_trap));

  // register event handler
  user_handler = handler;

  return true;
}

Context *kcontext(Area kstack, void (*entry)(void *), void *arg) {
	Context* cp = (Context*)(kstack.end - sizeof(Context));	//移动栈指针留空间
//	Context* cp = (Context*)(kstack.start + sizeof(Context));	//移动栈指针留空间
	cp->mepc = (uintptr_t)entry;
	cp->mstatus = 0x1800;
	cp->gpr[10] = (uintptr_t)(arg);
	return cp;
}

void yield() {
#ifdef __riscv_e
  asm volatile("li a5, -1; ecall");
#else
  asm volatile("li a7, -1; ecall");
#endif
}

bool ienabled() {
  return false;
}

void iset(bool enable) {
}
