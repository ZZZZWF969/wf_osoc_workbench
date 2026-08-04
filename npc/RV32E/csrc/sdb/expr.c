/***************************************************************************************
* 移植自 NEMU (nemu/src/monitor/sdb/expr.c)，仅替换了 ISA 相关依赖：
*   isa_reg_str2val -> reg_str2val (csrc/sdb/reg_str2val.cpp)
*   paddr_read      -> pmem_read
*   panic           -> printf + assert(0)
***************************************************************************************/

#include <regex.h>
#include <inttypes.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include "../include/sdb.h"
#include "../include/macro.h"

word_t eval(int p,int q,bool* success);
bool check_parentheses(int p, int q);
static int find_major_op_location(int p, int q);

enum {
  TK_NOTYPE = 256, TK_EQ, TK_NUM, TK_REG, TK_LOE, TK_MOE, TK_NEQ,
  TK_LT, TK_MT, TK_AND, TK_OR, TK_POT
	/*——————————————//finished?——————————————*/
};

static struct rule {
  const char *regex;
  int token_type;
} rules[] = {
   /* Pay attention to the precedence level of different rules.
   */

  {" +", TK_NOTYPE},    // space
  {"\\|\\|", TK_OR}, 	//logical or
  {"\\$[A-Za-z]+([0-9]?)+", TK_REG}, 	//register
  {"==", TK_EQ},        // equal
  {"<=", TK_LOE},		//less or equal
  {">=", TK_MOE},		//more or equal
  {"!=", TK_NEQ}, 		//not equal
  {"<", TK_LT},  		//less than
  {">", TK_MT},  		//more than
  //{"<=", TK_LOE},		//less or equal
  //{">=", TK_MOE},		//more or equal
  //{"!=", TK_NEQ}, 		//not equal
  {"&&", TK_AND},  		//logical and
  //{"\\|\\|", TK_OR}, 	//logical or
  {"\\+", '+'},         
  {"\\-", '-'},
  {"\\(", '('},
  {"\\)", ')'},
  {"\\*", '*'},
  {"\\/", '/'},
  {"0[Xx][0-9a-fA-F]+", TK_NUM},   //hexadecimal number
  {"[0-9]+", TK_NUM},
}; 

#define NR_REGEX ARRLEN(rules)

static regex_t re[NR_REGEX] = {};

/* Rules are used for many times.
 * Therefore we compile them only once before any usage.
 */
void init_regex() {
  int i;
  char error_msg[128];
  int ret;

  for (i = 0; i < NR_REGEX; i ++) {
    ret = regcomp(&re[i], rules[i].regex, REG_EXTENDED);
    if (ret != 0) {
      regerror(ret, &re[i], error_msg, 128);
      printf("regex compilation failed: %s\n%s\n", error_msg, rules[i].regex);
      assert(0);
    }
  }
}

typedef struct token {
  int type;
  char str[32];
} Token;

static Token tokens[32] __attribute__((used)) = {};
static int nr_token __attribute__((used))  = 0;

static bool is_hexadecimal(char* s){
	if (s == NULL || strlen(s) < 2) return false;
	if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) return true;
	else return false;
}

static void hex_to_dec(char* s){
	long hex_value = strtol(s, NULL, 16);
	snprintf(s, 31, "%ld", hex_value);
	//printf("hex_value: %ld\n",hex_value);
	//printf("hex_str: %s\n",s);
}

static bool make_token(char* e) {
  int position = 0;
  int i;
  regmatch_t pmatch;

  nr_token = 0;

  while (e[position] != '\0') {
    /* Try all rules one by one. */
    for (i = 0; i < NR_REGEX; i ++) {
      if (regexec(&re[i], e + position, 1, &pmatch, 0) == 0 && pmatch.rm_so == 0) {
        char *substr_start = e + position;
        int substr_len = pmatch.rm_eo;

        //Log("match rules[%d] = \"%s\" at position %d with len %d: %.*s",
        //    i, rules[i].regex, position, substr_len, substr_len, substr_start);

        position += substr_len;

        int copy_len;
        switch (rules[i].token_type) {
        	case TK_NOTYPE: break;
        	case TK_REG:
        	if (substr_len > 7){
        		printf("This name is longer than your life!\n");
        		return false;
        	}
        	else if (substr_len <= 2){
        		printf("The name is short, but maybe longer than your d**k\n");
        		return false;
        	}
        	else copy_len = substr_len;
        	strncpy(tokens[nr_token].str, substr_start, copy_len);
        	tokens[nr_token].str[copy_len] = '\0';
        	tokens[nr_token].type = TK_REG;
        	nr_token++;
        	break;
        	case TK_NUM:
        	if (nr_token >= 32) {
        		printf("Too many tokens\n");
        		return false;
        	}
        	tokens[nr_token].type = TK_NUM;
        	if (substr_len >=31) copy_len = 31;
        	else copy_len = substr_len;
        	strncpy(tokens[nr_token].str, substr_start, copy_len);
        	tokens[nr_token].str[copy_len] = '\0';
        	nr_token++;
        	break;
            default:
            	if (nr_token > 31) {
            		printf("Too many tokens\n");
            		return false;
            	}
            	tokens[nr_token].type = rules[i].token_type;
            	tokens[nr_token].str[0] = '\0';
            	nr_token++;
            	break;
        }
        //printf("now: %s",tokens[0].str);
        break;
      }
    }

    if (i == NR_REGEX) {
      printf("no match at position %d\n%s\n%*.s^\n", position, e, position, "");
      return false;
    }
  }

  return true;
}

static bool is_pointer(int index){
	if (index == 0) return true;
	else{
		if (tokens[index-1].type == TK_NUM 
		 || tokens[index-1].type == ')') return false;
		 else return true;
	}
}

word_t expr(char* e, bool* success) {
	if (!make_token(e)) {
    	*success = false;
    	return 0;
	}
	//handle all the tokens needed to change their form
	for (int i = 0; i < nr_token; i ++){
	//pointer
  	if (tokens[i].type == '*'){
  		if (is_pointer(i)){
  			//printf("address: %s\n",tokens[i+1].str);
  			int address = strtol(tokens[i+1].str,NULL,16);
  			//printf("addr: %x\n",address);
  			word_t pointer_value = pmem_read(address,4);
  			snprintf(tokens[i+1].str,31,"%" PRIu32,pointer_value);
  			//printf("value: %s\n",tokens[i+1].str);
  			tokens[i].type = TK_POT;
  		}
  	}
  	//number
  	if (tokens[i].type == TK_NUM){
  		if (is_hexadecimal(tokens[i].str)) hex_to_dec(tokens[i].str);
  	}
  	//register
  	if (tokens[i].type == TK_REG){
  		//printf("reg: %s\n",tokens[i].str);
  		word_t reg_value = reg_str2val(tokens[i].str,success);
  		snprintf(tokens[i].str,31,"%" PRIu32,reg_value);
  		tokens[i].type = TK_NUM;
  	}
  }
  return eval(0,nr_token-1,success);
}

bool check_parentheses(int p, int q){
	int count = 0;           //while see a '(', count +1, and -1  while see a ')' 
	if (tokens[p].type == '(' && tokens[q].type == ')'){
		for (int i = p; i <= q; i++){
			if (tokens[i].type == '(') count++;
			if (tokens[i].type == ')') count--;
			if (count < 0) return false;
			if (count == 0) return i == q;
		}
		//if (count == 0) return true;
	}
	return false;
}

static bool logical(int token_type){
	switch(token_type){
		case TK_EQ:  case TK_LT:  case TK_MT:  case TK_LOE:
		case TK_MOE: case TK_NEQ: case TK_AND: case TK_OR:
		return true;
	default: return false;
	}
}

static int level(int token_type){
	if (logical(token_type))  return -1;
	switch(token_type){
		case '+': case '-': return 1;
		case '*': case '/': return 2;
		case TK_POT: return 3;
		case TK_NUM: return 4;
		default: return 10;
	}
}

static int find_major_op_location(int p,int q){
	int par = 0, op_level = 4,location = -1;
	for (int i = p; i <= q; i++){
		if (tokens[i].type == '(') par++;       //if it's in  parentheses
		else if (tokens[i].type == ')') par--;  //needn't consider it
		if (par != 0) continue;
		if (level(tokens[i].type) <= op_level && par == 0){
			location = i;
			op_level = level(tokens[i].type);
		}
	}
	return location;
}

static int logical_dispose(word_t val_1, word_t val_2, int op_type){
	switch(op_type){
		case TK_EQ: 
			if (val_1 == val_2) return 1;
			else return 0;
		case TK_LT:
			if (val_1 < val_2) return 1;
			else return 0;
		case TK_MT:
			if (val_1 > val_2) return 1;
			else return 0;
		case TK_LOE:
			if (val_1 <= val_2) return 1;
			else return 0;
		case TK_MOE: 
			if (val_1 >= val_2) return 1;
			else return 0;
		case TK_NEQ:
			if (val_1 != val_2) return 1;
			else return 0;
		case TK_AND:
			if (val_1 && val_2) return 1;
			else return 0;
		case TK_OR:
			if (val_1 || val_2) return 1;
			else return 0;
		default:
			printf("Maybe there are some intersting default.\n");
			return 0;
	}
}

word_t eval(int p,int q,bool* success){
	*success = true;
	if (p > q) {printf("error p: %d\n",p); printf("error q: %d\n",q);
	printf("error location\n"); *success = false; return 0;}
	else if (p == q){
		if (tokens[p].type == TK_NUM) return atoi(tokens[p].str);
		else {printf("Not a valid expression\n"); *success = false; return 0;}
	}
	else if (check_parentheses(p,q) == true) return eval(p+1,q-1,success);
	else {
		//word_t result;
		int major_op_location = find_major_op_location(p,q);
		if (tokens[major_op_location].type == TK_POT) 
			return atoi(tokens[major_op_location+1].str);
		int32_t val_1 = eval(p,major_op_location-1,success);
		int32_t val_2 = eval(major_op_location+1,q,success);
		if (logical(tokens[major_op_location].type)){
			int result = logical_dispose(val_1, val_2, tokens[major_op_location].type);
			return result;
		}
		switch (tokens[major_op_location].type){
			case '+': return val_1+val_2;
			case '-': return val_1-val_2;
			case '*': return val_1*val_2;
			case '/': 
				if (val_2 == 0) {
				*success = false;
				printf("You put a '0' behind '/', please check your expression\n");
				return 0;
				}
				else return val_1/val_2;
			default: printf("There is an unknown option\n"); return 0;
		}
	}
  return 0;
}
