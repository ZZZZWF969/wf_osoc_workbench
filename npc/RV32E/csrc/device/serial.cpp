#include <stdio.h>

void serial_putch(char c){
	putc(c, stderr);
}