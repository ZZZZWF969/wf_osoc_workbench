#include <common.h>

#ifdef CONFIG_FTRACE
#include <elf.h>

typedef struct ElfFunc {
    uint32_t addr;  // 函数起始地址
    uint32_t size;  // 函数体的大小
    char* name;  // 函数名
} ElfFunc;

static ElfFunc* elfuncs = NULL;  // 函数项数组
static int elfunc_num = 0; // 函数项的个数
static char* elfunc_strtab = NULL;  // string table

void read_elf(const char* elf_path){
    FILE* fp = fopen(elf_path, "rb");
    fseek(fp, 0, SEEK_END);
    int elf_size = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    unsigned char* elf = (unsigned char*)malloc(elf_size);
    if(fread(elf, 1, elf_size, fp) != elf_size) {
      panic("failed to read elf file %s", elf_path);
    }
    fclose(fp);
    elfunc_num = 0;
    elfuncs = NULL;
    elfunc_strtab = NULL;

    Elf32_Ehdr* elf_header = (Elf32_Ehdr*)elf;			//ELF头
    Elf32_Shdr* elf_shdrs = (Elf32_Shdr*)(elf + elf_header->e_shoff);	//节头表
    
    //遍历节头表拷贝符号名字符串表
	for (int si = 0; si < elf_header->e_shnum; si++) {
        Elf32_Shdr shdr = elf_shdrs[si];
        if (shdr.sh_type == SHT_STRTAB && si != elf_header->e_shstrndx) {
            elfunc_strtab = (char*)malloc(shdr.sh_size);
            memcpy(elfunc_strtab, elf + shdr.sh_offset, shdr.sh_size);
            break;
        }
    }

    //将函数关键信息登记入函数项数组
	for (int si = 0; si < elf_header->e_shnum; si++) {
        Elf32_Shdr shdr = elf_shdrs[si];
        if (shdr.sh_type == SHT_SYMTAB) {
            Elf32_Sym* symtab = (Elf32_Sym*)(elf + shdr.sh_offset);

            //统计函数数量
			for (int i = 0; i < shdr.sh_size / shdr.sh_entsize; i++) {
                Elf32_Sym sym = symtab[i];
                if (ELF32_ST_TYPE(sym.st_info) == STT_FUNC) {
                    elfunc_num++;
                }
            }
            
            //把全部函数的关键信息载入一个数组中
			elfuncs = (ElfFunc*)malloc(sizeof(ElfFunc) * elfunc_num);
            ElfFunc* item = elfuncs;
            for (int i = 0; i < shdr.sh_size / shdr.sh_entsize; i++) {
                Elf32_Sym sym = symtab[i];
                if (ELF32_ST_TYPE(sym.st_info) == STT_FUNC) {
                    item->addr = sym.st_value;
                    item->size = sym.st_size;
                    item->name = elfunc_strtab + sym.st_name;
                    item += 1;
                }
            }
        }
    }
    free(elf);
}

static int print_ftrace_level = 0;

void print_ftrace(uint32_t inst_addr, uint32_t func_addr, int is_enter){
    printf("0x%08x: ", inst_addr);
    if (is_enter != 1) {
      print_ftrace_level--;
    }
    for (int i = 0; i < print_ftrace_level; i++) {
        printf("    ");
    }
    if (is_enter == 1) {
        print_ftrace_level++;
        printf("call ");
    }
    else {
        printf("ret ");
    }
	//遍历函数项数组查函数名
    for (int i = 0; i < elfunc_num; i++) {
        if (func_addr >= elfuncs[i].addr && func_addr < elfuncs[i].addr + elfuncs[i].size) {
            printf("%s\n", elfuncs[i].name);
            return; 
        }
    }
    printf("???\n");
}

void ftrace_jal(uint32_t inst_addr, uint32_t func_addr, int rd){
#ifdef CONFIG_FTRACE
	if (rd == 1) {
		print_ftrace(inst_addr, func_addr, 1);
	}
#endif
}

void ftrace_jalr(uint32_t inst_addr, uint32_t func_addr, int rd, int rs1, int imm){
#ifdef CONFIG_FTRACE
	if (rd == 0 && rs1 == 1 && imm == 0) {
		print_ftrace(inst_addr, inst_addr, 0);
	}
	else if (rd == 1) {
		print_ftrace(inst_addr, func_addr, 1);
	}
#endif
}

#else
void read_elf(const char* elf_path){
    return;
}

void print_ftrace(uint32_t inst_addr, uint32_t func_addr, int is_enter){
    return;
}

void ftrace_jal(uint32_t inst_addr, uint32_t func_addr, int rd){
    return;
}

void ftrace_jalr(uint32_t inst_addr, uint32_t func_addr, int rd, int rs1, int imm){
    return;
}

#endif