#include <SDL2/SDL.h>
#include "../include/npc.h"
#include "../include/state.h"

#define KEYDOWN_MASK 0x8000
#define KEY_QUEUE_LEN 1024

// SDL 键码 → AM 键码 的映射表定义 与 AM 层 amdev.h 中的 AM_KEYS 枚举一一对应
#define NPC_KEYS(f) \
  f(ESCAPE) f(F1) f(F2) f(F3) f(F4) f(F5) f(F6) f(F7) f(F8) f(F9) f(F10) f(F11) f(F12) \
  f(GRAVE) f(1) f(2) f(3) f(4) f(5) f(6) f(7) f(8) f(9) f(0) f(MINUS) f(EQUALS) f(BACKSPACE) \
  f(TAB) f(Q) f(W) f(E) f(R) f(T) f(Y) f(U) f(I) f(O) f(P) f(LEFTBRACKET) f(RIGHTBRACKET) f(BACKSLASH) \
  f(CAPSLOCK) f(A) f(S) f(D) f(F) f(G) f(H) f(J) f(K) f(L) f(SEMICOLON) f(APOSTROPHE) f(RETURN) \
  f(LSHIFT) f(Z) f(X) f(C) f(V) f(B) f(N) f(M) f(COMMA) f(PERIOD) f(SLASH) f(RSHIFT) \
  f(LCTRL) f(APPLICATION) f(LALT) f(SPACE) f(RALT) f(RCTRL) \
  f(UP) f(DOWN) f(LEFT) f(RIGHT) f(INSERT) f(DELETE) f(HOME) f(END) f(PAGEUP) f(PAGEDOWN)

// 用宏展开生成 "NPC_KEY_键名" 的枚举常量，NPC_KEY_NONE(0) 表示"没有按键事件"
#define NPC_KEY_NAME(k) NPC_KEY_##k,
enum {
  NPC_KEY_NONE = 0,
  NPC_KEYS(NPC_KEY_NAME)
};

// 下标是 SDL 的键码，内容是 AM 的 keycode，查表即完成翻译
#define SDL_KEYMAP(k) keymap[SDL_SCANCODE_##k] = NPC_KEY_##k;
static uint32_t keymap[256] = {};

static void init_keymap(){
  NPC_KEYS(SDL_KEYMAP)
}

// 键盘事件环形队列。
static int key_queue[KEY_QUEUE_LEN] = {};
static int key_f = 0, key_r = 0;

static void key_enqueue(uint32_t am_scancode){
  key_queue[key_r] = am_scancode;
  key_r = (key_r + 1) % KEY_QUEUE_LEN;
  assert(key_r != key_f);   // 队列写满即溢出，属于异常情况
}

static uint32_t key_dequeue(){
  uint32_t key = NPC_KEY_NONE;
  if (key_f != key_r) {
    key = key_queue[key_f];
    key_f = (key_f + 1) % KEY_QUEUE_LEN;
  }
  return key;
}

// 轮询 SDL 的事件队列，把键盘事件翻译成 AM 事件存入环形队列。
static void poll_sdl_events(){
  SDL_Event event;
  while (SDL_PollEvent(&event)){
    switch (event.type) {
      case SDL_QUIT:
        npc_state.state = NPC_QUIT;
        break;
      // 键盘按下/释放事件
      case SDL_KEYDOWN:
      case SDL_KEYUP: {
        uint8_t k = event.key.keysym.scancode;
        bool is_keydown = (event.key.type == SDL_KEYDOWN);
        if (keymap[k] != NPC_KEY_NONE){
          key_enqueue(keymap[k] | (is_keydown ? KEYDOWN_MASK : 0));
        }
        break;
      }
      default: break;
    }
  }
}

void init_keyboard(){
// 下面有修改：窗口创建已合并到 vga.cpp 的 init_vga()，SDL 由 VGA 统一初始化
// 	if (SDL_Init(SDL_INIT_VIDEO) != 0){
// 		printf("SDL init failed: %s\n", SDL_GetError());
// 		assert(0);
// 	}
// 	SDL_Window *window = SDL_CreateWindow("NPC Keyboard", SDL_WINDOWPOS_CENTERED,
// 										  SDL_WINDOWPOS_CENTERED, 640, 480, 0);
// 	if (window == NULL){
// 		printf("SDL create window failed: %s\n", SDL_GetError());
// 		assert(0);
// 	}
	init_keymap();
}

// guest 读键盘寄存器时的入口：先轮询一遍 SDL 事件，再从队列取一个事件返回
word_t kbd_read(){
  poll_sdl_events();
  return key_dequeue();
}
