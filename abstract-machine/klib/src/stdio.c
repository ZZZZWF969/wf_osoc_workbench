#include <am.h>
#include <klib.h>
#include <klib-macros.h>
#include <stdarg.h>
#include <limits.h>

#if !defined(__ISA_NATIVE__) || defined(__NATIVE_USE_KLIB__)

typedef struct{
	int width;			//宽度
	bool left_align;	//选择左对齐
	bool zero_pad;		//补零
	char specifier;		//占位类型
} FormatSpecifier;

//int vsprintf(char *out, const char *fmt, va_list ap);

static int specifier_indentify(FormatSpecifier* fmspcf, const char* fmt){
	const char* start = fmt; 
	memset(fmspcf, 0, sizeof(FormatSpecifier));
	fmt++;
	if(*fmt == '-'){
		fmspcf->left_align = true;
		fmt++;
	}
	if(*fmt == '0'){
		fmspcf->zero_pad = true;
	}

	//用条件循环读宽度
	while(*fmt >= '0' && *fmt <= '9'){
		fmspcf->width *= 10;
		fmspcf->width += *fmt-'0';
		fmt++; 
	}

	//读完宽度来到最后，加载占位类型
	fmspcf->specifier = *fmt;

	if(*fmt == '0'){	//如遇结束，需返回正确长度(符合std库对printf函数的返回值要求)
		return fmt-start;
	}

	return (fmt-start);
}

int printf(const char *fmt, ...) {
	char buffer[1024];
	char* buf = buffer;
	va_list v_args;
	va_start(v_args, fmt);
	int count =  vsprintf(buf, fmt, v_args);
	int i = 0;
	while(buffer[i] != '\0'){
		putch(buffer[i]);
		i++;
	}
	va_end(v_args);
	return count;
}

int vsprintf(char *out, const char *fmt, va_list ap) {

	char* start = out;
	char num_buf[32];

	while (*fmt != '\0') {
		if (*fmt == '%') {
			if (*fmt == '\0') break;

			FormatSpecifier formatspeci;
			fmt += specifier_indentify(&formatspeci, fmt);

			switch (formatspeci.specifier){
				case '%': 
					*out++ = '%';
					break;
				case 'i':
				case 'd': {
					int num = va_arg(ap, int);
					unsigned int abs_num = (num < 0) ? (0U - (unsigned int)num)
					                                 : (unsigned int)num;

					// use the buffer backwards 倒着写
					char *p = num_buf + sizeof(num_buf) - 1;
					*p = '\0';
					do {
						*--p = '0' + abs_num % 10;
						abs_num /= 10;
					} while (abs_num);
					if (num < 0) *--p = '-';

					// padding = width - actual length of the number
					int len = num_buf + sizeof(num_buf) - 1 - p;
					int padding = formatspeci.width > len ?
					              formatspeci.width - len : 0;

					if (formatspeci.left_align) {
						memcpy(out, p, len); out += len;
						for (int i = 0; i < padding; i++) *out++ = ' ';
					} else if (formatspeci.zero_pad) {
						if (*p == '-') { *out++ = '-'; p++; len--; } //先把负号搬过去
						for (int i = 0; i < padding; i++) *out++ = '0';
						memcpy(out, p, len); out += len;
					} else {
						for (int i = 0; i < padding; i++) *out++ = ' ';
						memcpy(out, p, len); out += len;
					}
					break;
				}
					
				case 's': {
					const char *s = va_arg(ap, const char*);
					while (*s){
						*out++ = *s++;
					}
					break;
				}

				case 'c': {
					char c = va_arg(ap, int);
					int padding = formatspeci.width>1? formatspeci.width-1:0;

					if(formatspeci.left_align){
						*out++ = c;
						for(int i = 0; i < padding; i++){
							*out++ = ' ';
						}
					}else{
						for(int i = 0; i < padding; i++){
							*out++ = ' ';
						}
						*out++ = c;
					}
					break;
				}
			}
			fmt++;
		} else{
			*out++ = *fmt++;
		}
	}
		
	*out = '\0';
	va_end(ap);

	return out - start;
}


int sprintf(char *out, const char *fmt, ...) {
    va_list v_args;
    va_start(v_args, fmt);
    int count = vsprintf(out, fmt, v_args);
	va_end(v_args);
	return count;
}

int snprintf(char *out, size_t n, const char *fmt, ...) {
  panic("Not implemented");
}

int vsnprintf(char *out, size_t n, const char *fmt, va_list ap) {
  panic("Not implemented");
}

#endif
